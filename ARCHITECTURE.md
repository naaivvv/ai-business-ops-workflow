# FILE: ARCHITECTURE.md

```markdown
# System Architecture

# Core Components

## 1. Entry-Point Trigger Layer

Each event source has its own dedicated entry-point workflow with a native trigger. There is no central "Event Router" — n8n workflows are trigger-bound, and a centralized dispatcher adds unnecessary indirection, debugging complexity, and wasted webhook executions.

### Entry-Point Workflows

| Workflow | Trigger Type | Event Source |
|----------|-------------|-------------|
| `EMAIL__ClassifyIncoming` | Gmail Trigger (5min poll) or Pub/Sub Webhook | New email |
| `DRIVE__ProcessUpload` | Google Drive Trigger | File uploaded to watched folder |
| `MEET__ProcessTranscript` | Google Drive Trigger | Transcript file in Meeting-Transcripts/ |
| `FORM__ProcessSubmission` | Webhook Trigger | External form submission |
| `SLACK__HandleCommand` | Webhook Trigger | Slack slash command or interaction |

### Why Not a Central Router?

- n8n workflows start with exactly one trigger node. You can't funnel Gmail, Drive, Slack, and form events into a single router without each one having its own trigger — at which point, routing through a central dispatcher is redundant.
- Sub-workflow calls via Execute Workflow node don't count toward execution quotas, but webhook-based calls between workflows do. A central router adds unnecessary webhook hops.
- When a Gmail processing fails, you should look at one self-contained workflow, not trace through router → sub-workflow chains.

---

## 2. Shared Utility Layer

Reusable sub-workflows called by all entry-point workflows via the Execute Workflow node. These handle cross-cutting concerns.

### Utility Sub-Workflows

| Workflow | Purpose |
|----------|---------|
| `UTIL__WriteAuditLog` | Write structured log entries to workflow_logs table |
| `UTIL__SendSlackMessage` | Send formatted Slack notifications to any channel |
| `UTIL__AICall` | Centralized AI API calls with rate limiting, failover, and logging |
| `UTIL__Deduplicate` | Check events table for duplicate source + payload hash |
| `UTIL__BackupWorkflows` | Export all workflows to Git repository (cron-triggered) |

### UTIL__AICall Architecture

This sub-workflow centralizes all AI provider interactions:

1. Check Redis counter for daily token budget
2. Select model based on task type (OpenRouter Llama 3.3 for fast tasks, OpenRouter Gemini 2.5 for large-context)
3. Execute API call with retry and exponential backoff
4. On failure, automatically failover to secondary provider (e.g., Llama 3.3 → Gemini 2.5)
5. Log usage (model, tokens_input, tokens_output, latency_ms, cost_usd) to workflow_logs
6. Return structured response to caller

### UTIL__Deduplicate Architecture

Prevents duplicate event processing across all entry-point workflows:

1. Receive source type + key payload fields
2. Compute SHA-256 hash of source + key fields
3. Query events table for existing hash
4. Return `{ isDuplicate: true/false }` to caller
5. If duplicate, caller skips processing and logs as duplicate

---

## 3. AI Processing Layer

Responsible for:

- Classification (email routing, urgency detection)
- Summarization (meeting transcripts, daily reports)
- Decision support (confidence-gated recommendations)
- Embeddings (document chunking and vector generation)
- Content extraction (PDF, Google Docs, transcript parsing)
- Draft generation (email replies — always as drafts, never auto-sent)

### AI Services

- OpenRouter meta-llama/llama-3.3-70b-instruct:free (classification, summarization, draft generation)
- OpenRouter google/gemini-2.5-pro:free (large-context processing, multimodal document analysis, failover)
- Hugging Face sentence-transformers/all-MiniLM-L6-v2 (embeddings — 384 dimensions)

### AI Safety Rails

- All AI-generated emails created as **drafts** only — human must approve before sending
- Confidence thresholds gate human review (low confidence → approval workflow)
- PII detection prevents sensitive information in AI outputs
- Brand/tone guidelines injected via system prompt from knowledge base
- Token budget limits prevent runaway API costs

### n8n AI Agent Nodes

For complex AI orchestration (e.g., multi-step reasoning, tool selection), leverage n8n's native AI Agent node (powered by LangChain) instead of building custom chains of HTTP Request nodes. This provides:

- Built-in conversation memory (Window Buffer Memory node)
- Tool calling (sub-workflows exposed as tools via Workflow Tool or MCP nodes)
- Structured JSON output enforcement
- Execution logs showing the agent's reasoning chain

---

## 4. State Management Layer

Persistent operational storage.

### Database

- Supabase PostgreSQL (unified workflow_logs table, events, tasks, approvals, documents, and pgvector embeddings)

### Stores

- Events (with processing status, error context, and execution_id linkage)
- Tasks (with source_event_id traceability, escalation timestamps)
- Workflow Logs (unified logging: AI calls, audits, errors — replaces separate ai_logs/audit_logs)
- Approvals (with expiration, rejection notes, decision history)
- Documents (with content hash for deduplication)
- Embeddings Metadata (chunk-level tracking, directly storing 384-dim vectors)

---

## 5. Knowledge Base Layer

Stores semantic organizational memory with incremental processing.

### Components

- Chunking pipeline (with configurable strategy: fixed-size with overlap)
- Embeddings (Hugging Face sentence-transformers/all-MiniLM-L6-v2, locked at 384 dimensions)
- Vector database (Supabase pgvector, dimension vector(384) matching embedding model)
- Retrieval workflows (webhook-based query API)

### Incremental Processing

- Content hash comparison on each ingestion run
- Skip unchanged documents, delete old vectors for changed documents
- Version tracking in documents table
- Deletion propagation from Drive to Supabase pgvector

---

# Workflow Structure

```text
01_utilities/
    UTIL__WriteAuditLog
    UTIL__SendSlackMessage
    UTIL__AICall
    UTIL__Deduplicate
    UTIL__BackupWorkflows

02_error_handling/
    ERROR__GlobalHandler

03_email/
    EMAIL__ClassifyIncoming
    EMAIL__GenerateDraft
    EMAIL__ApproveAndSend

04_meetings/
    MEET__ProcessTranscript
    MEET__ExtractActions

05_knowledge/
    KB__IngestDocument
    KB__ChunkAndEmbed
    KB__SemanticSearch

06_tasks/
    TASK__CreateFromEvent
    TASK__SendReminders
    TASK__Escalate

07_reporting/
    REPORT__DailySummary
    REPORT__WeeklyDigest

08_ai_agents/
    (Future: multi-agent orchestration using n8n AI Agent nodes)
```

---

# Recommended Workflow Naming

```text
UTIL__WriteAuditLog
UTIL__SendSlackMessage
UTIL__AICall
UTIL__Deduplicate
UTIL__BackupWorkflows
ERROR__GlobalHandler
EMAIL__ClassifyIncoming
EMAIL__GenerateDraft
EMAIL__ApproveAndSend
MEET__ProcessTranscript
MEET__ExtractActions
KB__IngestDocument
KB__ChunkAndEmbed
KB__SemanticSearch
TASK__CreateFromEvent
TASK__SendReminders
TASK__Escalate
REPORT__DailySummary
REPORT__WeeklyDigest
```

---

# Event Lifecycle

```text
Event Source (Gmail, Drive, Webhook, Cron)
    ↓
Entry-Point Workflow Trigger
    ↓
Deduplication Check (UTIL__Deduplicate)
    ↓ (skip if duplicate)
Input Validation
    ↓
AI Processing (UTIL__AICall)
    ↓
Business Logic Execution
    ↓
State Persistence (Supabase PostgreSQL + pgvector)
    ↓
Audit Logging (UTIL__WriteAuditLog)
    ↓
Notification / Action (UTIL__SendSlackMessage)
    ↓
[On Error] → ERROR__GlobalHandler → Slack + Dead Letter Queue
```

---

# Managed Queue Architecture

Since this deployment relies on **n8n Cloud**, the queue mode (main process vs. worker execution), horizontal scaling, and job persistence are completely managed. There is no need to manually deploy or configure Redis.

---

# Error Handling Strategy

Error handling is a **foundational concern** implemented in Week 1, not a hardening step in Week 7.

## Three-Layer Resilience Architecture

### Layer 1: Node-Level (Transient Failures)

- **Retry on Fail:** Enabled on all external API call nodes with exponential backoff (`Math.pow(2, $runIndex) * 1000` ms)
- **Continue on Fail:** Used for non-critical enrichment steps (e.g., optional data lookups) where failure should not stop the workflow

### Layer 2: Global Error Workflow (Catch-All)

- Dedicated `ERROR__GlobalHandler` workflow with Error Trigger node
- All production workflows configured to use this handler via Settings → Error Workflow
- Handler sends Slack notification with: workflow name, failed node name, error message, direct link to failed execution

### Layer 3: Dead Letter Queue (Visibility)

- Failed events logged to `workflow_logs` table with `log_type = 'error'`
- Raw input payload preserved for replay/debugging
- Execution ID linked for direct n8n UI navigation

## Idempotency

- All webhooks and cron jobs designed to be safe to run multiple times
- Use "Upsert" operations or deduplication checks (UTIL__Deduplicate) to prevent double-processing
- Gmail message_id checked before processing to prevent duplicates from polling overlap

---

# Security Considerations

## Recommended

- Environment variables for all secrets (never hardcode in workflows)
- Secret management via Docker secrets or vault
- OAuth integrations with production-mode tokens (testing-mode tokens expire every 7 days)
- Audit logging (all actions logged to workflow_logs)
- Role-based access (n8n user roles for workflow editing vs. execution)
- API authentication (webhook endpoints secured with HMAC signatures or bearer tokens)
- Git repository for workflow backups must be **private** (exported JSON contains credential references)
```

---
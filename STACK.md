# FILE: STACK.md

```markdown
# Technology Stack

# Core Automation

## n8n (Version2.21.7)

Purpose:

- Workflow orchestration (modular entry-point + sub-workflow architecture)
- Event automation (per-source triggers, not centralized routing)
- API integrations (Google Workspace, Slack, OpenRouter, Hugging Face)
- AI workflows (native AI Agent nodes powered by LangChain)

### n8n AI Agent Nodes

n8n includes native AI Agent nodes (powered by LangChain) for complex AI orchestration. Use these instead of building custom chains of HTTP Request nodes to AI providers.

Capabilities:

- Tool calling (expose sub-workflows as tools via Workflow Tool or MCP nodes)
- Memory management (Window Buffer Memory for conversations, Vector Store for RAG)
- Structured JSON output enforcement
- Multi-model support (OpenRouter, Hugging Face, local models)
- Execution logs showing the agent's reasoning chain

Use AI Agent nodes for:

- Complex multi-step reasoning tasks
- Scenarios where the AI needs to select and call different tools
- Conversational interfaces (chat-based knowledge queries)

Use UTIL__AICall sub-workflow for:

- Simple single-step AI calls (classification, summarization, embedding)
- Tasks requiring rate limiting and provider failover
- Cost tracking and budget enforcement

---

# Database Layer

## PostgreSQL

Purpose:

- Persistent storage (events, tasks, approvals, documents)
- Workflow state management
- Unified audit/AI/error logging (workflow_logs table)
- Task management with full traceability
- Embeddings metadata tracking

---

# Queue & Cache

## Managed n8n Cloud Queue

Purpose:

- n8n Cloud natively handles execution queuing and horizontal worker scaling without requiring a standalone Redis instance.
- Rate limiting for AI providers is enforced via internal n8n states or directly within PostgreSQL.

---

# Vector Database

## Supabase pgvector

Purpose:

- Semantic search (similarity-based document retrieval directly in PostgreSQL)
- Embeddings storage (384-dimension vectors via `vector(384)`)
- RAG pipelines (context injection for AI-generated responses)
- Unifies relational metadata and vector indices into a single managed database

### Vector Configuration

| Setting | Value | Reason |
|---------|-------|--------|
| Column type | `vector(384)` | Matches Hugging Face all-MiniLM-L6-v2 |
| Index | `hnsw` | High-performance vector similarity search |
| Distance metric | Cosine (`<=>`) | Standard for text similarity |

> **Warning:** Vector dimensions must match your embedding model. Changing models later requires re-embedding your entire knowledge base and recreating the vector column.

---

# AI Providers

## OpenRouter

Used for:

- Classification (email routing, urgency detection) — Llama 3.3 70B
- Summarization (meeting transcripts, daily reports) — Llama 3.3 70B
- Response/draft generation (email replies) — Llama 3.3 70B
- Multimodal & Large Context — Gemini 2.5 Pro

### Provider Failover Strategy

All AI calls go through the `UTIL__AICall` sub-workflow, which implements automatic failover:

```text
Primary: OpenRouter Llama 3.3 70B
    ↓ (on failure: timeout, rate limit, 5xx)
Failover: OpenRouter Gemini 2.5 Pro
    ↓ (on failure)
Error: Log to workflow_logs, alert via Slack
```

---

## Hugging Face

Used for:

- Embeddings (document vectorization) — sentence-transformers/all-MiniLM-L6-v2

### Embedding Model Selection

| Model | Dimensions | Cost | Best For |
|-------|-----------|------|----------|
| all-MiniLM-L6-v2 | 384 | Free | General purpose, cost-effective ✅ Selected |

**Selected: `all-MiniLM-L6-v2`** — best balance of being 100% free and ecosystem support for organizational document search.

---

# Infrastructure

## Cloud-Native Setup

Purpose:

- Scalable managed hosting with zero local infrastructure configuration.
- Simplified operational overhead.

### Services Overview

```text
┌─────────────────────────────────────────────┐
│               Cloud-Native                   │
│                                              │
│  ┌───────────────────┐  ┌─────────────────┐ │
│  │     n8n Cloud     │  │     Supabase    │ │
│  │ (Logic & Compute) │  │ (Data & Vectors)│ │
│  └───────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────┘
```

---

# Integrations

## Google Workspace

- Gmail (email trigger — 5-minute polling or Pub/Sub push)
- Drive (file upload trigger for transcripts and knowledge base documents)
- Docs (meeting summary and report output)
- Calendar (deadline integration for tasks)
- Meet (transcripts via Drive folder — no native n8n Meet node)
- Sheets (optional: data export and simple dashboards)

> **Note:** Google Meet does not have a native n8n node. Transcripts are processed via Google Drive trigger when files are uploaded to a designated `Meeting-Transcripts/` folder.

---

## Communication Platforms

- Slack (primary: notifications, approvals, alerts via UTIL__SendSlackMessage)
- Discord (optional: alternative notification channel)
- Microsoft Teams (optional: alternative notification channel)

---

## Optional Future Integrations

- Jira (task management synchronization)
- Notion (knowledge base alternative/supplement)
- ClickUp (project management integration)
- HubSpot (CRM data enrichment for email classification)
- Salesforce (enterprise CRM integration)
- Google Pub/Sub (near-real-time Gmail push notifications, replacing polling)
```

---
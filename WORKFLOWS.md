# FILE: WORKFLOWS.md

```markdown
# Workflow Documentation

# Utility Workflows (Built in Week 1)

---

# 1. UTIL__WriteAuditLog

## Purpose

Reusable sub-workflow for structured operational logging to the unified `workflow_logs` table.

## Trigger

Execute Workflow (called by other workflows).

## Inputs

- workflow_name (TEXT)
- execution_id (TEXT)
- log_type (TEXT: 'ai_call', 'action', 'error', 'audit')
- action (TEXT)
- input_payload (JSONB)
- output_payload (JSONB)
- model (TEXT, optional — for AI calls)
- tokens_input (INTEGER, optional)
- tokens_output (INTEGER, optional)
- latency_ms (INTEGER, optional)
- status (TEXT: 'success', 'failure')
- error_message (TEXT, optional)

## Actions

- Validate required fields (workflow_name, log_type, action)
- Insert row into `workflow_logs` table with all provided fields
- Return success/failure status to caller

---

# 2. UTIL__SendSlackMessage

## Purpose

Reusable notification workflow for sending formatted Slack messages to any channel.

## Trigger

Execute Workflow (called by other workflows).

## Inputs

- channel (TEXT: Slack channel ID or name)
- message (TEXT: message body, supports Slack markdown)
- blocks (JSONB, optional: Slack Block Kit payload for rich formatting)
- thread_ts (TEXT, optional: reply to existing thread)

## Actions

- Validate channel and message are provided
- Send via Slack API node
- Log delivery status via UTIL__WriteAuditLog
- Return message_ts (for threading follow-ups)

---

# 3. UTIL__AICall

## Purpose

Centralized AI API call handler with rate limiting, provider failover, and usage logging. All workflows use this instead of calling OpenAI/Gemini directly.

## Trigger

Execute Workflow (called by other workflows).

## Inputs

- prompt (TEXT: user/system prompt)
- system_message (TEXT, optional: system instructions)
- model_preference (TEXT: 'fast', 'large-context', 'embedding')
- output_format (TEXT: 'text', 'json')
- max_tokens (INTEGER, optional)

## Model Selection Logic

| Preference | Primary Model | Failover Model |
|-----------|--------------|----------------|
| fast | OpenAI GPT-4o | Google Gemini |
| large-context | Google Gemini | OpenAI GPT-4o |
| embedding | OpenAI text-embedding-3-small | Google text-embedding-004 |

## Actions

1. Check Redis counter for daily token budget — if exceeded, return budget error
2. Select model based on model_preference
3. Execute API call with Retry on Fail (exponential backoff, 3 retries)
4. On failure, automatically failover to secondary provider
5. Log usage to workflow_logs via UTIL__WriteAuditLog (model, tokens, latency, cost)
6. Return structured response: `{ response, model_used, tokens_input, tokens_output, latency_ms }`

---

# 4. UTIL__Deduplicate

## Purpose

Prevents duplicate event processing across all entry-point workflows.

## Trigger

Execute Workflow (called by other workflows).

## Inputs

- source (TEXT: 'gmail', 'drive', 'webhook', 'form')
- dedup_key (TEXT: unique identifier — e.g., Gmail message_id, Drive file_id)

## Actions

1. Compute SHA-256 hash of `source + dedup_key`
2. Query `events` table for existing row with matching hash
3. If found: return `{ isDuplicate: true, existing_event_id: ... }`
4. If not found: insert new event row, return `{ isDuplicate: false, event_id: ... }`

---

# 5. UTIL__BackupWorkflows

## Purpose

Automated daily backup of all n8n workflows to a Git repository.

## Trigger

Cron (daily at 2:00 AM).

## Actions

1. Use n8n API (HTTP Request node) to list all workflows
2. For each workflow, fetch full JSON definition
3. Compare hash against last backup to detect changes
4. Push changed workflows to GitHub repository (GitHub node)
5. Log backup status via UTIL__WriteAuditLog

---

# Error Handling Workflows (Built in Week 1)

---

# 6. ERROR__GlobalHandler

## Purpose

Centralized error handler for all production workflows. Catches unhandled errors and provides immediate visibility.

## Trigger

Error Trigger node.

## Configuration

All production workflows must set this workflow as their Error Workflow in Settings → Error Workflow.

## Actions

1. Extract error context: workflow name, failed node name, error message, execution ID
2. Build direct link to failed execution in n8n UI
3. Send Slack alert via UTIL__SendSlackMessage with:
   - Workflow name
   - Failed node
   - Error message
   - Direct execution link
4. Log to workflow_logs with `log_type = 'error'` and full input payload (dead letter queue)
5. If error is retriable (timeout, rate limit), optionally re-queue the event

---

# Email Workflows (Built in Week 2)

---

# 7. EMAIL__ClassifyIncoming

## Trigger

Gmail Trigger node (5-minute polling interval) or Webhook node (Google Pub/Sub push).

## Actions

1. **Deduplicate:** Call UTIL__Deduplicate with source='gmail', dedup_key=message_id
2. **Skip if duplicate** — log and exit
3. **Extract metadata:** sender, subject, body text, attachments, timestamp
4. **AI classification:** Call UTIL__AICall with model_preference='fast'
   - Classify into categories: inquiry, support, sales, internal, urgent, spam
   - Detect urgency level: high, medium, low
   - Generate confidence score (0.0–1.0)
5. **Store event:** Insert into `events` table with classification results
6. **Route notification:** Call UTIL__SendSlackMessage to appropriate department channel
7. **Low confidence gate:** If confidence < 0.7, trigger human review (inline Wait for Webhook)
8. **Conditional draft:** If category warrants a reply, call EMAIL__GenerateDraft
9. **Audit log:** Call UTIL__WriteAuditLog

---

# 8. EMAIL__GenerateDraft

## Purpose

Generate contextual AI draft replies. Never auto-sends — always creates Gmail drafts.

## Trigger

Execute Workflow (called by EMAIL__ClassifyIncoming).

## Inputs

- email_body (TEXT)
- email_subject (TEXT)
- sender (TEXT)
- classification (JSONB)
- conversation_history (JSONB, optional: previous thread messages)

## Actions

1. **Query knowledge base:** Call KB__SemanticSearch for relevant organizational context
2. **Inject brand guidelines:** Load tone/voice system prompt from knowledge base
3. **PII check:** Scan email body for sensitive information patterns
4. **Generate draft:** Call UTIL__AICall with model_preference='fast', output_format='text'
   - System prompt includes: brand guidelines, classification context, conversation history
   - Instruction: generate a professional reply draft
5. **Create Gmail draft:** Use Gmail node to create draft (NOT send)
6. **Notify reviewer:** Call UTIL__SendSlackMessage with draft preview and Gmail link
7. **Audit log:** Call UTIL__WriteAuditLog with log_type='action'

## Safety Rails

- AI replies are ALWAYS drafts — never auto-sent
- PII patterns (SSN, credit card, etc.) detected and blocked from AI context
- Confidence threshold from classification gates whether a draft is generated at all
- Human must explicitly approve and send from Gmail

---

# Meeting Workflows (Built in Week 3)

---

# 9. MEET__ProcessTranscript

## Trigger

Google Drive Trigger: new file detected in `Meeting-Transcripts/` folder.

> **Note:** n8n does not have a native Google Meet node. Transcripts are uploaded to a designated Drive folder by users, recording systems, or meeting bot services (e.g., Vexa.ai, Fireflies.ai).

## Supported Formats

- Plain text (.txt)
- Word documents (.docx)
- WebVTT subtitles (.vtt)
- SRT subtitles (.srt)
- Google Docs (native)

## Actions

1. **Deduplicate:** Call UTIL__Deduplicate with source='drive', dedup_key=file_id
2. **Skip if duplicate** — log and exit
3. **Download file:** Use Google Drive node to download transcript
4. **Extract text:** Parse content based on file type (Code node for VTT/SRT timestamp stripping)
5. **AI summarization:** Call UTIL__AICall with model_preference='large-context'
   - Generate structured summary: key discussion points, context, duration
6. **Extract actions:** Call MEET__ExtractActions sub-workflow
7. **Create summary doc:** Use Google Docs node to create formatted summary document
8. **Store event:** Insert into events table with summary reference
9. **Notify team:** Call UTIL__SendSlackMessage with summary and action item list
10. **Audit log:** Call UTIL__WriteAuditLog

---

# 10. MEET__ExtractActions

## Purpose

Extract structured action items, decisions, and risks from a meeting transcript.

## Trigger

Execute Workflow (called by MEET__ProcessTranscript).

## Inputs

- transcript_text (TEXT)
- meeting_metadata (JSONB: title, date, attendees if available)

## Actions

1. **AI extraction:** Call UTIL__AICall with model_preference='fast', output_format='json'
   - Extract: action items (with owner, deadline, description)
   - Extract: decisions made (with context)
   - Extract: risks identified (with severity)
2. **Create tasks:** For each action item, insert into `tasks` table with:
   - source_event_id linked to the meeting event
   - assigned_to parsed from AI output
   - deadline parsed from AI output
   - priority inferred from context
3. **Return structured output** to parent workflow

---

# Knowledge Base Workflows (Built in Week 4)

---

# 11. KB__IngestDocument

## Trigger

Google Drive Trigger: new or modified file detected in `Knowledge-Base/` folder.

## Actions

1. **Deduplicate:** Call UTIL__Deduplicate with source='drive', dedup_key=file_id
2. **Download and extract text:** Parse content based on file type (PDF, Google Doc, DOCX)
3. **Compute content hash:** SHA-256 of extracted text content
4. **Check documents table:** Compare content_hash against existing entry for this file
   - If hash matches (unchanged): skip processing, log as "no change"
   - If hash differs (updated): delete old vectors from Qdrant, proceed with re-embedding
   - If no existing entry (new): proceed with embedding
5. **Insert/update documents table:** title, source_type, source_url, content_hash, status='processing'
6. **Call KB__ChunkAndEmbed** sub-workflow with document_id and extracted text
7. **Update documents table:** status='completed', chunk_count, processed_at
8. **Audit log:** Call UTIL__WriteAuditLog

---

# 12. KB__ChunkAndEmbed

## Purpose

Split document text into chunks and generate vector embeddings for Qdrant storage.

## Trigger

Execute Workflow (called by KB__IngestDocument).

## Inputs

- document_id (UUID)
- text_content (TEXT)
- collection_name (TEXT, default: 'knowledge_base')

## Chunking Strategy

- Method: Fixed-size with overlap
- Chunk size: 500 tokens
- Overlap: 50 tokens (10%)
- Preserve paragraph boundaries where possible

## Actions

1. **Split text** into chunks using Text Splitter node (or Code node for custom logic)
2. **Generate embeddings:** For each chunk, call UTIL__AICall with model_preference='embedding'
3. **Upsert to Qdrant:** Use Qdrant Vector Store node (action: "Add Documents")
   - Collection: knowledge_base (1536 dimensions, matching text-embedding-3-small)
   - Payload metadata: document_id, chunk_index, source_url, title
4. **Insert embeddings_metadata rows:** For each chunk, store document_id, chunk_index, chunk_text, vector_id, collection_name, embedding_model
5. **Return chunk_count** to parent workflow

---

# 13. KB__SemanticSearch

## Purpose

Webhook-based query API for semantic search against the knowledge base.

## Trigger

Webhook (POST /api/knowledge/search).

## Inputs

- query (TEXT: natural language question)
- top_k (INTEGER, default: 5)
- collection_name (TEXT, default: 'knowledge_base')

## Actions

1. **Embed query:** Call UTIL__AICall with model_preference='embedding' to convert query to vector
2. **Search Qdrant:** Use Qdrant Vector Store node (action: "Get ranked documents")
   - Return top_k most similar chunks with similarity scores
3. **Generate answer:** Call UTIL__AICall with model_preference='fast'
   - System prompt: "Answer the question using only the provided context. If the context doesn't contain the answer, say so."
   - User prompt: query + retrieved chunks as context (RAG pattern)
4. **Return response:** query, answer, source_documents (with titles, URLs, similarity scores)
5. **Audit log:** Call UTIL__WriteAuditLog

---

# Task Workflows (Built in Week 5)

---

# 14. TASK__CreateFromEvent

## Purpose

Create tasks from any event source (email classification, meeting action items, form submissions).

## Trigger

Execute Workflow (called by other workflows).

## Inputs

- title (TEXT)
- description (TEXT)
- assigned_to (UUID or email)
- priority (TEXT: 'critical', 'high', 'medium', 'low')
- deadline (TIMESTAMP)
- source_event_id (UUID: links back to the originating event)

## Actions

1. **Resolve assigned_to:** Look up user UUID from email if needed
2. **Insert into tasks table** with all fields, status='open', created_at=NOW()
3. **Send assignment notification:** Call UTIL__SendSlackMessage to assignee
4. **Audit log:** Call UTIL__WriteAuditLog

---

# 15. TASK__SendReminders

## Purpose

Daily reminder notifications for upcoming and overdue tasks.

## Trigger

Cron (daily at 9:00 AM).

## Actions

1. **Query tasks table:** Find tasks where:
   - status = 'open' AND deadline BETWEEN NOW() AND NOW() + INTERVAL '48 hours' (upcoming)
   - status = 'open' AND deadline < NOW() (overdue)
2. **Group by assignee**
3. **For each assignee:** Call UTIL__SendSlackMessage with task list (upcoming + overdue)
4. **Audit log:** Call UTIL__WriteAuditLog

---

# 16. TASK__Escalate

## Purpose

Hourly escalation check for overdue tasks that have exceeded their deadline.

## Trigger

Cron (hourly).

## Actions

1. **Query tasks table:** Find tasks where:
   - status = 'open'
   - deadline < NOW() - INTERVAL '24 hours' (overdue by more than 24h)
   - escalated_at IS NULL (not yet escalated)
2. **For each overdue task:**
   - Update escalated_at = NOW()
   - Update priority = 'critical' (if not already)
   - Notify assignee's manager via UTIL__SendSlackMessage
   - Send escalation alert to #ops-alerts channel
3. **Audit log:** Call UTIL__WriteAuditLog

---

# Reporting Workflows (Built in Week 6)

---

# 17. REPORT__DailySummary

## Trigger

Cron (daily at 8:00 AM).

## Actions

1. **Aggregate daily metrics from PostgreSQL:**
   - Emails processed (count from events where event_type='email' and created_at > yesterday)
   - Tasks created / completed / overdue
   - AI calls made (count from workflow_logs where log_type='ai_call')
   - Errors encountered (count from workflow_logs where log_type='error')
   - Approvals pending / completed
2. **Generate AI summary:** Call UTIL__AICall with model_preference='fast'
   - Prompt: "Generate an executive summary of today's operational metrics with recommendations"
   - Input: aggregated metrics as structured JSON
3. **Create Google Doc:** Formatted daily report with metrics tables and AI insights
4. **Notify executives:** Call UTIL__SendSlackMessage to #executive-updates channel
5. **Audit log:** Call UTIL__WriteAuditLog

## Outputs

- Operational metrics dashboard
- AI-generated executive insights
- Actionable recommendations
- Error/incident summary

---

# 18. REPORT__WeeklyDigest

## Trigger

Cron (Monday at 9:00 AM).

## Actions

1. **Aggregate weekly metrics** (same categories as daily, but for 7-day window)
2. **Trend analysis:** Compare this week vs. last week
3. **Generate AI insights:** Call UTIL__AICall with model_preference='fast'
   - Prompt: "Generate a weekly operations digest with trends, highlights, and strategic recommendations"
4. **Create Google Doc:** Formatted weekly digest with charts data and AI insights
5. **Notify executives:** Call UTIL__SendSlackMessage
6. **Audit log:** Call UTIL__WriteAuditLog

---

# Approval Handling

> **Important:** Approval/wait logic must be kept in the **main workflow**, never in sub-workflows. Sub-workflows containing Wait or Human-in-the-Loop nodes do not correctly return output to the parent workflow — the parent will hang or receive empty data.

## Inline Approval Pattern (used within EMAIL__ClassifyIncoming, etc.)

1. Main workflow reaches decision point → checks AI confidence or business rule
2. If approval needed → **Wait for Webhook** node (pauses execution)
3. Write pending approval to `approvals` table with expires_at timestamp
4. Send approval request via UTIL__SendSlackMessage with:
   - Context summary
   - Unique resume URL (approve)
   - Unique resume URL (reject)
5. Reviewer clicks approve or reject link
6. Workflow resumes with reviewer's decision
7. Update approvals table: status, approved_at or rejected_at, decision_notes
8. Continue or abort based on decision

## Database-Driven Fallback Pattern

For crash recovery and audit trail:

1. Write pending approval to `approvals` table with full request_payload
2. Separate cron workflow checks for completed approvals
3. On completion, trigger the follow-up action
4. Ensures no approvals are lost if n8n restarts during a Wait
```

---
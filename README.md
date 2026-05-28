# AI Business Operations Workspace

A modular AI-powered operations automation workspace built with n8n Cloud, Supabase PostgreSQL with pgvector, Google Workspace, Slack, OpenRouter, and Hugging Face. The system acts as an AI operations layer for email intake, meeting intelligence, knowledge-base search, task orchestration, reporting, audit logging, and workflow backup.

The project is designed around small entry-point workflows and shared utility workflows. Each event source has its own trigger, while cross-cutting concerns such as AI calls, deduplication, Slack notifications, audit logging, and error handling are centralized in reusable `UTIL__*` and `ERROR__*` workflows.

## Current Deployment

| Component | Runtime | Access |
|---|---|---|
| n8n | n8n Cloud | `https://edwin-bayog.app.n8n.cloud/` |
| Database | Supabase PostgreSQL | Supabase project dashboard |
| Vector Store | Supabase pgvector | `embeddings_metadata.embedding vector(384)` |
| Document Sources | Google Drive | `Meeting-Transcripts`, `Knowledge-Base`, report folders |
| Notifications | Slack | Ops, email routing, task, and executive channels |

## Architecture

```text
Event Source (Gmail, Drive, Webhook, Cron)
    |
Entry-Point Workflow Trigger
    |
Deduplication Check (UTIL__Deduplicate)
    | (skip if duplicate)
Input Validation
    |
AI Processing (UTIL__AICall)
    |
Business Logic Execution
    |
State Persistence (Supabase PostgreSQL + pgvector)
    |
Audit Logging (UTIL__WriteAuditLog)
    |
Notification / Action (UTIL__SendSlackMessage)
    |
[On Error] -> ERROR__GlobalHandler -> Slack + Dead Letter Queue
```

```text
External Triggers
(Gmail Trigger, Drive Trigger, Webhooks, Cron)
         |
Entry-Point Workflows
(EMAIL__, MEET__, KB__, TASK__, REPORT__)
         |
    Shared Utilities
    (UTIL__*)
         |
AI Processing Layer
(UTIL__AICall with rate limiting, failover, logging)
         |
Workflow Execution
(Classification, Summarization, Task Creation)
         |
State Persistence
(Supabase PostgreSQL + pgvector)
         |
Notifications & Reporting
(Slack, Email, Google Docs)
         |
Error Handling
(ERROR__GlobalHandler -> Slack + workflow_logs)
```

There is intentionally no central event router. n8n workflows are trigger-bound, so Gmail, Drive, cron, and webhook entry points are kept separate and call shared utilities through Execute Workflow nodes.

## Features

| Feature | Status | Summary |
|---|---|---|
| Smart email intake | Implemented | Classifies incoming Gmail messages, detects urgency, stores event state, and routes notifications. |
| AI draft replies | Implemented | Generates Gmail drafts only; no AI email is auto-sent. Includes PII redaction before draft generation. |
| Meeting transcript processing | Implemented | Watches a Google Drive transcript folder, extracts text, summarizes, and creates action items. |
| Knowledge-base ingestion | Implemented | Watches a Google Drive knowledge folder, hashes content, chunks text, and embeds documents. |
| Semantic search API | Implemented | Authenticated webhook for RAG-style answers using Supabase pgvector. |
| Task creation | Implemented | Creates tracked tasks from events and links them back to source records. |
| Task reminders | Implemented | Daily cron for upcoming and overdue task reminders. |
| Task escalation | Implemented | Hourly cron upgrades overdue tasks and notifies managers/ops. |
| Daily reporting | Implemented | Aggregates operational metrics, generates AI summary, creates Google Doc, and notifies Slack. |
| Weekly digest | Implemented | Aggregates weekly metrics and trends for executive reporting. |
| Central AI gateway | Implemented | `UTIL__AICall` centralizes model selection, failover, usage logging, and embeddings. |
| Global error handling | Implemented | `ERROR__GlobalHandler` sends Slack alerts and writes error rows to `workflow_logs`. |
| Workflow backup | Implemented | Google Drive export ingestion to private GitHub backup workflow. |
| Final verification runbook | Implemented | See `FINAL_VERIFICATION.md` for local and live acceptance checks. |

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Automation | n8n Cloud | Workflow orchestration, triggers, sub-workflows, credentials, execution history. |
| Database | Supabase PostgreSQL | Events, tasks, users, approvals, workflow logs, document metadata. |
| Vector Search | Supabase pgvector | 384-dimensional semantic search using HNSW/cosine distance. |
| AI Text Models | OpenRouter | Llama 3.3 for fast tasks and Gemini 2.5 Pro for large-context/failover tasks. |
| Embeddings | Hugging Face | `sentence-transformers/all-MiniLM-L6-v2`, 384 dimensions. |
| Workspace | Google Workspace | Gmail, Drive, Docs, Calendar, and optional Sheets. |
| Notifications | Slack | Routing alerts, task notifications, approvals, and executive updates. |
| Backups | Google Drive + GitHub | Manual n8n export ingestion and private repository backups. |

## Prerequisites

- n8n Cloud workspace with access to `https://edwin-bayog.app.n8n.cloud/`.
- Supabase project with PostgreSQL and pgvector enabled.
- Google Workspace account and OAuth access for Gmail, Drive, Docs, Calendar, and optionally Sheets.
- Slack workspace and bot token with message-posting permissions.
- OpenRouter API key.
- Hugging Face API key.
- Private GitHub repository and GitHub credential for workflow backups.
- Google Drive folders for transcripts, knowledge-base documents, reports, and manual workflow exports.

## Quick Start

This repository is currently configured for a cloud-native deployment. There is no `docker-compose.yml` in the repo, so `docker compose up -d` is not part of the current runnable path. If a self-hosted n8n stack is added later, create a compose file first, then run `docker compose up -d`.

For the current n8n Cloud + Supabase setup:

1. Create or open the Supabase project.
2. Run [database/init.sql](database/init.sql) in the Supabase SQL Editor.
3. Confirm these are present in Supabase:
   - `pgcrypto`
   - `vector`
   - tables: `users`, `events`, `tasks`, `workflow_logs`, `approvals`, `documents`, `embeddings_metadata`
   - function: `match_documents`
4. Create n8n credentials:
   - Supabase account
   - Google Drive OAuth2 API
   - Gmail OAuth2
   - Google Docs OAuth2
   - Slack API
   - OpenRouter API
   - Hugging Face Inference API
   - GitHub API
   - Header Auth credential named `KB Semantic Search Bearer Token`
5. Import the workflow JSON files from `workflows/` into n8n Cloud.
6. Verify all production workflows use `ERROR__GlobalHandler` as their Error Workflow.
7. Activate the relevant entry-point workflows after credentials and folder IDs are correct.
8. Run [FINAL_VERIFICATION.md](FINAL_VERIFICATION.md) from top to bottom.

## Workflow Inventory

The architecture documents list 19 workflows. This repo now contains all 19 workflow JSON exports.

| # | Workflow | Trigger | Status | Description |
|---:|---|---|---|---|
| 1 | `UTIL__WriteAuditLog` | Execute Workflow | Exported / Implemented | Writes structured rows to `workflow_logs`. |
| 2 | `UTIL__SendSlackMessage` | Execute Workflow | Exported / Implemented | Sends Slack messages and supports reusable notification delivery. |
| 3 | `UTIL__AICall` | Execute Workflow | Exported / Implemented | Central AI gateway for OpenRouter and Hugging Face calls. |
| 4 | `UTIL__Deduplicate` | Execute Workflow | Exported / Implemented | Computes event hashes and prevents duplicate processing. |
| 5 | `UTIL__BackupWorkflows` | Google Drive Trigger | Exported / Implemented | Processes manual n8n export files and backs them up to GitHub. |
| 6 | `ERROR__GlobalHandler` | Error Trigger | Exported / Implemented | Catches workflow errors, sends Slack alerts, and logs failures. |
| 7 | `EMAIL__ClassifyIncoming` | Gmail Trigger | Exported / Implemented | Classifies email, detects urgency, stores event state, and routes Slack notifications. |
| 8 | `EMAIL__GenerateDraft` | Execute Workflow | Exported / Implemented | Generates safe Gmail draft replies and notifies reviewers. |
| 9 | `EMAIL__ApproveAndSend` | Authenticated Webhook | Exported / Implemented | Accepts approve/reject decisions, sends approved Gmail drafts, updates approvals, notifies Slack, and audits the result. |
| 10 | `MEET__ProcessTranscript` | Google Drive Trigger | Exported / Implemented | Processes uploaded meeting transcripts into summaries and action items. |
| 11 | `MEET__ExtractActions` | Execute Workflow | Exported / Implemented | Extracts action items, decisions, and risks from transcript text. |
| 12 | `KB__IngestDocument` | Google Drive Trigger | Exported / Implemented | Ingests knowledge-base documents and handles change detection. |
| 13 | `KB__ChunkAndEmbed` | Execute Workflow | Exported / Implemented | Chunks text and writes embeddings to Supabase pgvector metadata. |
| 14 | `KB__SemanticSearch` | Webhook | Exported / Implemented | Authenticated semantic-search/RAG endpoint. |
| 15 | `TASK__CreateFromEvent` | Execute Workflow | Exported / Implemented | Creates tasks from event or workflow payloads. |
| 16 | `TASK__SendReminders` | Cron | Exported / Implemented | Sends daily upcoming/overdue task reminders. |
| 17 | `TASK__Escalate` | Cron | Exported / Implemented | Escalates tasks overdue by more than 24 hours. |
| 18 | `REPORT__DailySummary` | Cron | Exported / Implemented | Creates daily operational reports and Slack updates. |
| 19 | `REPORT__WeeklyDigest` | Cron | Exported / Implemented | Creates weekly executive digest reports and Slack updates. |

## Database Schema Overview

The database is initialized by [database/init.sql](database/init.sql).

| Table | Purpose |
|---|---|
| `users` | User directory with roles, departments, managers, and Slack IDs. |
| `events` | Source event records, dedup hashes, status, execution IDs, and payloads. |
| `tasks` | Operational task tracking with assignees, deadlines, priorities, and source-event links. |
| `workflow_logs` | Unified log stream for AI calls, actions, audits, and errors. |
| `approvals` | Human-in-the-loop approval state, decisions, and expiration timestamps. |
| `documents` | Knowledge-base document metadata, hashes, versions, source IDs, and status. |
| `embeddings_metadata` | Chunk text and `embedding vector(384)` values for semantic search. |

The semantic search function is:

```sql
match_documents(
  query_embedding vector(384),
  match_threshold float,
  match_count int,
  filter_collection text DEFAULT 'knowledge_base'
)
```

The embedding model is locked to `sentence-transformers/all-MiniLM-L6-v2`. Changing embedding models requires re-embedding the knowledge base and verifying vector dimensions.

## API Endpoints

### KB__SemanticSearch

Production webhook:

```text
POST https://edwin-bayog.app.n8n.cloud/webhook/api/knowledge/search
```

Authentication:

```http
Authorization: Bearer YOUR_SECRET_TOKEN
Content-Type: application/json
```

Request body:

```json
{
  "query": "What is our escalation policy for overdue tasks?",
  "top_k": 5,
  "collection_name": "knowledge_base"
}
```

Response shape:

```json
{
  "query": "What is our escalation policy for overdue tasks?",
  "answer": "Answer generated from retrieved context.",
  "sources": [
    {
      "title": "Document abc12345",
      "url": "#",
      "similarity": 0.82,
      "excerpt": "Relevant source excerpt..."
    }
  ],
  "model_used": "meta-llama/llama-3.3-70b-instruct:free"
}
```

Unauthenticated requests should be rejected by the n8n Header Auth credential.

## Configuration

Keep local references in `.env`, but configure production secrets directly as n8n credentials.

```env
# n8n Cloud
N8N_CLOUD_URL=https://edwin-bayog.app.n8n.cloud

# Supabase
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_KEY=your-supabase-service-role-key
SUPABASE_DB_PASSWORD=your-database-password

# OpenRouter
OPENROUTER_API_KEY=sk-or-v1-your-openrouter-key
OPENROUTER_DEFAULT_MODEL=meta-llama/llama-3.3-70b-instruct:free
OPENROUTER_LARGE_CONTEXT_MODEL=google/gemini-2.5-pro:free

# Hugging Face
HUGGINGFACE_API_KEY=hf_your-huggingface-key
HUGGINGFACE_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2

# Google OAuth, if not using n8n Cloud's built-in Google OAuth
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret

# Slack
SLACK_BOT_TOKEN=xoxb-your-bot-token

# Webhook auth
KB_SEMANTIC_SEARCH_TOKEN=your-secret-token
```

Required n8n credential names used by the exports include:

| Credential | Used By |
|---|---|
| `Supabase account` | Database reads/writes, logs, tasks, documents, embeddings. |
| `Google Drive OAuth2 API` | Transcript, knowledge-base, and backup file triggers/downloads. |
| `Google Business Ops` | Gmail drafts and Google Workspace actions. |
| `Slack account` | Alerts, routing messages, reminders, and reports. |
| `KB Semantic Search Bearer Token` | Header Auth for the public semantic search webhook. |

## Backup & Recovery

### Workflow Backups

n8n workflows live in n8n Cloud, not in this Git repository by default. The project includes `UTIL__BackupWorkflows`, which watches a Google Drive folder for manual n8n export JSON files and writes workflow definitions into a private GitHub repository.

Recommended workflow:

1. Export workflows from n8n Cloud as JSON.
2. Upload the export to the `n8n-workflow-exports` Google Drive folder.
3. Confirm `UTIL__BackupWorkflows` runs.
4. Confirm the private GitHub backup repository contains updated workflow JSON.
5. Confirm a backup audit row is written.

Keep backup repositories private because exported n8n workflow JSON contains credential references.

### Database Backups

Use Supabase managed backups where available. For manual backups, run `pg_dump` against the Supabase connection pooler and store output securely.

```bash
pg_dump "postgres://postgres.[YOUR-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres" > ./backups/db/operations_$(date +'%Y-%m-%d').sql
```

For restore testing, verify table creation, indexes, pgvector extension, `match_documents`, and a sample semantic-search query.

## Security Considerations

- Never hardcode API keys or OAuth secrets in workflow nodes.
- Use n8n credentials for Supabase, Slack, Google, OpenRouter, Hugging Face, GitHub, and Header Auth.
- Keep Google OAuth in Production mode unless using n8n Cloud's built-in verified Google OAuth.
- Rotate OpenRouter, Hugging Face, and Slack keys on a regular schedule.
- Protect the `KB__SemanticSearch` webhook with Header Auth.
- Test unauthenticated webhook requests and confirm rejection.
- Set all production workflows to use `ERROR__GlobalHandler`.
- Configure n8n Cloud execution data retention in Settings -> Execution Data.
- Keep GitHub workflow backup repositories private.
- Review n8n user roles so only authorized operators can edit production workflows.
- Treat workflow exports as sensitive because they include credential IDs and operational topology.

## Verification

Use [FINAL_VERIFICATION.md](FINAL_VERIFICATION.md) for local export checks and live acceptance tests. Local checks can validate JSON structure, IDs, error-workflow wiring, webhook auth metadata, and database SQL. Full acceptance requires live n8n executions with valid Supabase, Google, Slack, OpenRouter, Hugging Face, and GitHub credentials.

## Future Roadmap

- Wire `EMAIL__GenerateDraft` Slack approval buttons to `EMAIL__ApproveAndSend`.
- Add expired approval cleanup workflow.
- Add Google Pub/Sub Gmail push notifications to reduce polling.
- Expand department routing rules and per-team Slack channels.
- Add dashboard views in Google Sheets or a BI tool.
- Add knowledge query analytics and user feedback tracking.
- Add document deletion propagation from Google Drive to pgvector.
- Add incident management tables and richer incident reports.
- Add multi-agent orchestration using n8n AI Agent nodes.
- Add optional integrations: Jira, Notion, ClickUp, HubSpot, Salesforce, Microsoft Teams, Discord.
- Add a self-hosted `docker-compose.yml` if the deployment moves away from n8n Cloud.

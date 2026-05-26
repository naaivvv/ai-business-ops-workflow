# FILE: SCHEDULE.md

```markdown
# Development Schedule

# WEEK 1 — Infrastructure Setup + Foundational Utilities

## Goals

### Infrastructure

- Install Docker and Docker Compose
- Setup n8n (main + worker in queue mode)
- Configure PostgreSQL with init.sql (all tables from DATABASE.md)
- Configure Redis for queue mode and rate limiting
- Configure Qdrant with knowledge_base collection (1536 dimensions)
- Setup Google Workspace APIs (Gmail, Drive, Docs, Calendar) with **production-mode** OAuth tokens
- Setup environment variables (.env file with all required keys)
- Setup Slack bot and workspace integration

### Foundational Workflows (Built First)

- `ERROR__GlobalHandler` — Global error workflow with Slack notifications and dead letter queue
- `UTIL__WriteAuditLog` — Unified logging to workflow_logs table
- `UTIL__SendSlackMessage` — Reusable Slack notification sub-workflow
- `UTIL__AICall` — Centralized AI API calls with rate limiting, failover, and logging
- `UTIL__Deduplicate` — Event deduplication sub-workflow

### Error Handling Configuration

- Configure Retry on Fail with exponential backoff on all HTTP/API nodes
- Set ERROR__GlobalHandler as the error workflow for all production workflows
- Test error flow end-to-end (trigger intentional failure → Slack alert)

## Deliverables

- Running local infrastructure (all 5 Docker services)
- Gmail and Drive integration verified
- Database connected with all tables created
- All 5 foundational workflows operational and tested
- Global error handling working (Slack alerts on any failure)

---

# WEEK 2 — Email Intelligence System

## Goals

- Build `EMAIL__ClassifyIncoming` workflow with Gmail trigger (5-minute polling)
  - Integrate UTIL__Deduplicate at entry point (check message_id)
  - AI email classification via UTIL__AICall (categories, urgency, confidence)
  - Database logging via UTIL__WriteAuditLog
  - Slack notifications via UTIL__SendSlackMessage (route to department channels)
  - Confidence gating: low confidence → inline Wait for Webhook (human review)
- Build `EMAIL__GenerateDraft` sub-workflow
  - AI draft generation via UTIL__AICall (never auto-send)
  - PII detection in email body
  - Brand/tone guidelines injection via system prompt
  - Create Gmail draft (NOT send)
  - Notify reviewer via Slack with draft preview
- Implement Gmail Pub/Sub push notifications (optional enhancement)
  - Setup Gmail Watch via HTTP Request node
  - Configure Google Pub/Sub topic and subscription
  - Replace polling trigger with Webhook receiver

## Deliverables

- Automated email classification and routing
- AI-generated email drafts (human approval required before sending)
- Deduplication preventing double-processing
- Full audit trail in workflow_logs

---

# WEEK 3 — Meeting Intelligence

## Goals

> **Note:** n8n does not have a native Google Meet node. Transcripts are processed via Google Drive trigger (Option B).

- Build `MEET__ProcessTranscript` workflow
  - Google Drive trigger: new file in `Meeting-Transcripts/` folder
  - Support multiple formats: TXT, DOCX, VTT, SRT, Google Docs
  - Text extraction and format normalization (Code node for VTT/SRT timestamp stripping)
  - AI summarization via UTIL__AICall with model_preference='large-context'
  - Deduplication via UTIL__Deduplicate (check file_id)
  - Create summary document in Google Docs
  - Slack notification with summary
- Build `MEET__ExtractActions` sub-workflow
  - AI extraction of action items (with owner, deadline, description)
  - AI extraction of decisions and risks
  - Create tasks in tasks table (linked via source_event_id)
  - JSON structured output enforcement

### Scope Consideration

Meeting transcript processing is more complex than a simple "trigger → summarize" pipeline due to:
- Multiple transcript format support (VTT timestamp stripping, DOCX parsing)
- OAuth scope configuration and testing for Drive access
- Handling incomplete or malformed transcripts
- AI prompt engineering for accurate action item extraction

If this exceeds one week, defer VTT/SRT format support to Week 7 and start with plain text and Google Docs only.

## Deliverables

- Automated meeting transcript processing from Google Drive
- Structured summaries in Google Docs
- Action items created as tracked tasks
- Full pipeline tested end-to-end

---

# WEEK 4 — Knowledge Base System

## Goals

### Database & Infrastructure

- Create `documents` and `embeddings_metadata` tables (if not in init.sql)
- Verify Qdrant collection configuration: `knowledge_base`, 1536 dimensions, cosine distance
- Decide chunking strategy: fixed-size (500 tokens) with overlap (50 tokens, 10%)

### Workflows

- Build `KB__IngestDocument` workflow
  - Google Drive trigger: new/modified file in `Knowledge-Base/` folder
  - Download and extract text (PDF, Google Docs, DOCX)
  - Compute content hash (SHA-256) for change detection
  - Check documents table: skip if unchanged, delete old vectors if changed
  - Insert/update documents table
  - Call KB__ChunkAndEmbed sub-workflow
- Build `KB__ChunkAndEmbed` sub-workflow
  - Split text into chunks (500 tokens, 50-token overlap)
  - Generate embeddings via UTIL__AICall (model_preference='embedding')
  - Upsert to Qdrant via Qdrant Vector Store node
  - Insert embeddings_metadata rows (document_id, chunk_index, vector_id)
- Build `KB__SemanticSearch` workflow
  - Webhook trigger (POST /api/knowledge/search)
  - Embed query via UTIL__AICall
  - Search Qdrant for top_k similar chunks
  - Generate RAG answer via UTIL__AICall
  - Return: answer, source documents with similarity scores

### Deduplication & Change Detection

- Content hash prevents re-processing identical documents
- Changed documents: delete old Qdrant vectors, re-chunk, re-embed
- Deleted documents: propagate deletion to Qdrant (manual or scheduled cleanup)

## Deliverables

- Searchable organizational memory (semantic search via Qdrant)
- Incremental document processing (only re-embed changed documents)
- Webhook-based query API for knowledge retrieval
- RAG-powered Q&A with source attribution

---

# WEEK 5 — Task Orchestration

## Goals

- Build `TASK__CreateFromEvent` sub-workflow
  - Accept task details from any calling workflow
  - Resolve assigned_to (email → UUID lookup)
  - Insert into tasks table with source_event_id linkage
  - Send assignment notification via UTIL__SendSlackMessage
- Build `TASK__SendReminders` cron workflow (daily at 9am)
  - Query tasks: upcoming (deadline within 48h) and overdue
  - Group by assignee
  - Send personalized Slack reminders
- Build `TASK__Escalate` cron workflow (hourly)
  - Query tasks: overdue by more than 24h, not yet escalated
  - Set escalated_at, upgrade priority to 'critical'
  - Notify assignee's manager via Slack
  - Send alert to #ops-alerts channel

### Approval Integration

- Implement inline approval pattern in main workflows (not sub-workflows)
  - Wait for Webhook node pauses execution
  - Slack message with approve/reject resume URLs
  - Write pending state to approvals table with expires_at
  - Handle expired approvals (cron to mark as expired)

## Deliverables

- AI-assisted operational coordination
- Automated task creation from events with full traceability
- Daily reminder system for upcoming and overdue tasks
- Escalation pipeline for persistently overdue tasks
- Human-in-the-loop approval workflow

---

# WEEK 6 — Reporting & Analytics

## Goals

- Build `REPORT__DailySummary` cron workflow (daily at 8am)
  - Aggregate daily metrics from PostgreSQL:
    - Emails processed, tasks created/completed/overdue
    - AI calls made (count, total tokens, total cost)
    - Errors encountered
    - Approvals pending/completed
  - Generate AI executive summary via UTIL__AICall
  - Create formatted Google Doc report
  - Notify executives via Slack
- Build `REPORT__WeeklyDigest` cron workflow (Monday at 9am)
  - Aggregate weekly metrics (7-day window)
  - Trend analysis: this week vs. last week
  - AI-generated strategic recommendations
  - Create Google Doc weekly digest
  - Notify executives via Slack

### Dashboard Data (Optional)

- If time permits, create a Google Sheet dashboard with:
  - Daily email volume and classification breakdown
  - Task completion rates
  - AI usage and cost tracking
  - Knowledge base growth metrics

## Deliverables

- Daily operational reporting engine
- Weekly strategic digest
- AI-generated insights and recommendations
- Executive notification pipeline

---

# WEEK 7 — Hardening & Polish

## Goals

### Infrastructure Hardening

- Verify queue mode stability under load (simulate concurrent workflow executions)
- Test worker scaling (add a second n8n-worker container)
- Configure execution data retention (30 days success, 90 days errors)
- Implement UTIL__BackupWorkflows (daily cron at 2am, push to private GitHub repo)
- Add database backup script (daily pg_dump)

### Workflow Polish

- Add VTT/SRT format support to MEET__ProcessTranscript (if deferred from Week 3)
- Implement Gmail Pub/Sub push notifications (if deferred from Week 2)
- Add expired approval cleanup cron
- Review and optimize AI prompts for accuracy
- Test all webhook endpoints with authentication (HMAC or bearer tokens)

### Security Review

- Rotate all API keys
- Verify Google OAuth is in production mode (not testing)
- Audit all webhook endpoints for authentication
- Ensure Git backup repository is private
- Review n8n user roles and access permissions

### Monitoring Setup

- Verify ERROR__GlobalHandler covers all workflows
- Test failure scenarios end-to-end
- Setup Qdrant health check monitoring
- Review Redis queue depth alerting

## Deliverables

- Production-ready architecture
- Automated backup system (workflows + database)
- All deferred features implemented
- Security audit complete
- Monitoring and alerting verified

---

# WEEK 8 — Portfolio & Documentation

## Goals

- Architecture diagrams (Mermaid or draw.io — workflow topology, data flow)
- README improvements (project overview, setup guide, architecture summary)
- Demo recording (end-to-end walkthrough of all workflows)
- Deployment guide finalization (DEPLOYMENT.md verified against actual setup)
- Technical writeups (design decisions, trade-offs, lessons learned)
- Clean up workflow naming consistency
- Export all workflows as backup (final snapshot)

## Deliverables

- Professional portfolio project
- Comprehensive documentation
- Working demo recording
- Clean, well-documented codebase
```

---
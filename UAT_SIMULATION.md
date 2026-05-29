# End-to-End UAT Simulation: "A Day in the Life of the Business"

**Date:** 2026-05-29  
**System:** AI Business Operations Workspace  
**Stack:** n8n Cloud + Supabase + OpenRouter + Hugging Face + Google Workspace + Slack

---

> [!NOTE]
> This simulation tests the entire AI Business Operations system as if you were running a real business day. Each phase triggers a cascade of automated workflows, just like production. Complete the phases in order — later phases depend on data created by earlier ones.

---

## Pre-Flight Checklist

Before starting the simulation, confirm every piece of infrastructure is ready.

### Credentials & Services

- [ ] n8n Cloud is accessible at your instance URL
- [ ] Supabase project is running with all 7 tables (`users`, `events`, `tasks`, `workflow_logs`, `approvals`, `documents`, `embeddings_metadata`)
- [ ] Supabase has `vector` and `pgcrypto` extensions enabled
- [ ] Supabase has the `match_documents` RPC function
- [ ] Google OAuth credential is valid (Gmail, Drive, Docs, Calendar)
- [ ] Slack bot is installed in your workspace with proper channel permissions
- [ ] OpenRouter API key is active
- [ ] Hugging Face API key is active

### Google Drive Folders

Confirm these folders exist (IDs from [WORKFLOW_IDs.md](WORKFLOW_IDs.md)):

| Folder | ID | Monitored By |
|--------|-----|-------------|
| Meeting-Transcripts | `1b7XjZHtgh7GyjUTgu3WmSKe4afpohkYR` | `MEET__ProcessTranscript` |
| Knowledge-Base | `1AcOJD5A3-Hap_mLJuMtWXHvn0sVx_NBd` | `KB__IngestDocument` |
| General-Uploads | `1CGfwFWsFLFIE6pgsgge57l8tjn5_sNYK` | `DRIVE__ProcessUpload` |
| Daily Operations Reports | `11916k96B3ayO6AXsuhiBEMw_OMZx9uiX` | Output folder |
| Weekly Digest Reports | `1FDviUefWBnLwtiszKdovh9yfuFU4Vzin` | Output folder |
| Business Ops Reports | `1ap6B6qWulyByVhsTQSdAnJApFj9Qk-lU` | Output folder |
| Incident Reports | `1D_xNzhV6SZBESYbDFHBjPuGdkPwm_RTv` | Output folder |

### Workflow Activation

Activate the following entry-point workflows in n8n (toggle to **Active**):

- [ ] `EMAIL__ClassifyIncoming` (`zfRtOrxAsJjJ2UXx`)
- [ ] `MEET__ProcessTranscript` (`CpXv8Are7dDLolBo`)
- [ ] `KB__IngestDocument` (`TEplz47oyEqE7CKz`)
- [ ] `DRIVE__ProcessUpload` (new — import from `workflows/08_drive/`)
- [ ] `ERROR__GlobalHandler` (`Fa1qAUIxfJj6SjfY`)

### Seed a Test User

Insert at least one test user into Supabase so task assignments and notifications work:

```sql
INSERT INTO users (email, name, role, department, slack_user_id)
VALUES
  ('ops.manager@yourdomain.com', 'Operations Manager', 'manager', 'operations', 'U_YOUR_SLACK_ID'),
  ('sarah.designer@yourdomain.com', 'Sarah Chen', 'staff', 'marketing', NULL),
  ('alex.dev@yourdomain.com', 'Alex Rivera', 'staff', 'engineering', NULL);
```

> [!IMPORTANT]
> Replace `U_YOUR_SLACK_ID` with your actual Slack Member ID so you receive notifications during the test. Find it in Slack → Profile → ⋯ → Copy member ID.

---

## Phase 1 — 8:00 AM: Knowledge Base Ingestion

**Goal:** Populate the AI's organizational memory so it has context for classification, drafting, and question answering later in the simulation.

### Actions

1. **Create a test SOP document.** In Google Docs or a `.txt` file, write:

   ```
   Company Refund Policy — Standard Operating Procedure

   1. All refund requests must be submitted within 30 days of purchase.
   2. Refunds under $100 are auto-approved by the Support team.
   3. Refunds over $100 require Billing Manager approval.
   4. Refunds for digital products are handled by the Product team.
   5. All refund communications must maintain a professional, empathetic tone.
   6. Never share customer payment details in email replies.
   7. Escalate fraud-related refund requests to the Security team immediately.
   ```

2. **Upload it** to the **Knowledge-Base** folder in Google Drive.

3. **Wait 5 minutes** for the polling trigger to detect the file.

### Expected Results

- [ ] `KB__IngestDocument` triggers (check n8n execution log)
- [ ] `UTIL__Deduplicate` marks event as new (`isDuplicate: false`)
- [ ] File is downloaded and text extracted
- [ ] Content hash is computed and stored
- [ ] `KB__ChunkAndEmbed` is called:
  - [ ] Text is chunked (~2000 chars per chunk with 200 char overlap)
  - [ ] Each chunk is sent to `UTIL__AICall` with `model_preference: 'embedding'`
  - [ ] Hugging Face returns 384-dimension vectors
  - [ ] Vectors are formatted for pgvector and inserted into `embeddings_metadata`
- [ ] `documents` table has a new row with `status = 'completed'`

### Database Verification

```sql
-- Check the document was ingested
SELECT id, title, source_type, content_hash, chunk_count, status, processed_at
FROM documents
ORDER BY created_at DESC LIMIT 1;

-- Check embeddings were stored
SELECT id, document_id, chunk_index, LEFT(chunk_text, 80) AS preview,
       embedding IS NOT NULL AS has_vector
FROM embeddings_metadata
ORDER BY created_at DESC LIMIT 5;

-- Check audit log
SELECT workflow_name, action, status, created_at
FROM workflow_logs
WHERE workflow_name = 'KB__IngestDocument'
ORDER BY created_at DESC LIMIT 3;
```

---

## Phase 2 — 8:15 AM: Semantic Search Validation

**Goal:** Confirm the knowledge base answers questions using the SOP you just uploaded.

### Actions

1. **Send a POST request** to the `KB__SemanticSearch` webhook:

   ```bash
   curl -X POST https://YOUR-N8N-INSTANCE/webhook/api/knowledge/search \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_SECRET_TOKEN" \
     -d '{"query": "What is the refund policy for orders over $100?", "top_k": 3}'
   ```

### Expected Results

- [ ] Response includes `query`, `answer`, `sources`, and `model_used`
- [ ] Answer references the Billing Manager approval requirement
- [ ] Sources include chunk excerpts with similarity scores > 0.5
- [ ] Audit log shows a `semantic_search` action

### Test Edge Cases

```bash
# Query with no relevant context
curl -X POST https://YOUR-N8N-INSTANCE/webhook/api/knowledge/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SECRET_TOKEN" \
  -d '{"query": "What is the dress code policy?", "top_k": 3}'
```

- [ ] AI responds with "I don't have enough information" (not a hallucinated answer)

```bash
# Unauthenticated request (should be rejected)
curl -X POST https://YOUR-N8N-INSTANCE/webhook/api/knowledge/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'
```

- [ ] Returns 401 or 403 (not a valid response)

---

## Phase 3 — 9:00 AM: Email Intake & AI Classification

**Goal:** Simulate incoming customer emails triggering automated classification, routing, and draft reply generation.

### Actions

Send 3 test emails from a personal email account to the monitored Gmail inbox:

**Email A — Standard Support (Should auto-classify with high confidence)**
```
Subject: Refund request for Order #7842
Body: Hi, I purchased a laptop bag 10 days ago and it arrived damaged. 
I'd like a refund of $45. My order number is #7842. Thanks!
```

**Email B — Urgent / Escalation (Should trigger high-urgency routing)**
```
Subject: URGENT: Unauthorized charges on my account
Body: I just noticed three unauthorized transactions totaling $2,500 on 
my business account. This needs immediate investigation. My account ID 
is BIZ-9921. Please escalate this to your security team NOW.
```

**Email C — Spam / Low-value (Should classify as spam or low priority)**
```
Subject: You've won a $1,000,000 prize!!!
Body: Congratulations! You have been selected as our lucky winner. 
Click here to claim your prize immediately. Act now before it expires!
```

### Expected Results — Email A

- [ ] `EMAIL__ClassifyIncoming` triggers within 5 minutes
- [ ] `UTIL__Deduplicate` marks as new
- [ ] AI classifies as: category = `support`, urgency = `medium`, confidence ≥ 0.7
- [ ] Event stored in `events` table with classification payload
- [ ] Slack notification sent to the support channel
- [ ] `EMAIL__GenerateDraft` is called:
  - [ ] Semantic search retrieves refund SOP context (from Phase 1!)
  - [ ] AI generates a professional draft reply referencing the 30-day policy
  - [ ] Draft appears in Gmail Drafts folder (NOT sent automatically)
  - [ ] Slack notification shows draft preview with Gmail link

### Expected Results — Email B

- [ ] Classified as: category = `urgent` or `support`, urgency = `high`, confidence may be < 0.7
- [ ] If confidence < 0.7: **human review triggered** via Slack with approve/reject buttons
- [ ] Slack notification sent to #ops-alerts or #urgent channel
- [ ] Event stored with `urgency: high`

### Expected Results — Email C

- [ ] Classified as: category = `spam`, urgency = `low`
- [ ] No draft generated (spam emails should not get replies)
- [ ] Event stored but no further processing

### Database Verification

```sql
-- Check classified events
SELECT id, event_type, payload->>'category' AS category,
       payload->>'urgency' AS urgency,
       payload->>'confidence' AS confidence,
       status
FROM events
WHERE event_type = 'email'
ORDER BY created_at DESC LIMIT 5;

-- Check AI usage for classification
SELECT action, model, tokens_input, tokens_output, latency_ms, status
FROM workflow_logs
WHERE workflow_name = 'EMAIL__ClassifyIncoming'
ORDER BY created_at DESC LIMIT 5;
```

---

## Phase 4 — 10:00 AM: Meeting Intelligence

**Goal:** Process a meeting transcript, generate a summary document, and auto-create tasks from extracted action items.

### Actions

1. **Create a test transcript file** named `team-standup-2026-05-29.txt`:

   ```
   Team Standup — May 29, 2026

   Attendees: Sarah Chen, Alex Rivera, Operations Manager

   Operations Manager: Good morning everyone. Let's go through updates.

   Sarah Chen: I've finished the homepage mockup. I need feedback from 
   the marketing director by Friday June 6th. Also, the social media 
   campaign assets are delayed — we need new product photos.

   Alex Rivera: The database migration script is ready for staging. 
   I'll deploy it to the staging environment by tomorrow May 30th. 
   Also, we discovered a performance issue with the search API — 
   response times are above 500ms. I'll investigate and fix it by 
   next Wednesday June 4th.

   Operations Manager: Good. Sarah, let's schedule a review meeting 
   with the marketing director. Alex, the search performance is 
   critical — please prioritize that over the migration if needed.

   Decision: Prioritize search API performance fix over database migration.
   Risk: Social media campaign may be delayed due to missing product photos.
   ```

2. **Upload it** to the **Meeting-Transcripts** folder in Google Drive.

3. **Wait 5 minutes** for the trigger to detect the file.

### Expected Results

- [ ] `MEET__ProcessTranscript` triggers
- [ ] Deduplication check passes (new file)
- [ ] File downloaded and text extracted (timestamps stripped if subtitle format)
- [ ] `UTIL__AICall` generates a structured summary (large-context model)
- [ ] `MEET__ExtractActions` extracts action items:

  | Action Item | Owner | Deadline |
  |---|---|---|
  | Get feedback on homepage mockup from marketing director | Sarah Chen | June 6, 2026 |
  | Deploy database migration script to staging | Alex Rivera | May 30, 2026 |
  | Investigate and fix search API performance issue | Alex Rivera | June 4, 2026 |

- [ ] Tasks created in `tasks` table with `source_event_id` linking to the meeting event
- [ ] Summary Google Doc created in the Meeting-Transcripts folder
- [ ] Slack notification with summary + action items posted to team channel
- [ ] Decisions and risks captured in the summary

### Database Verification

```sql
-- Check meeting event
SELECT id, event_type, payload->>'summary' IS NOT NULL AS has_summary, status
FROM events
WHERE event_type = 'meeting' OR payload->>'source' = 'drive'
ORDER BY created_at DESC LIMIT 1;

-- Check created tasks
SELECT title, description, priority, status, deadline, assigned_to
FROM tasks
ORDER BY created_at DESC LIMIT 5;
```

---

## Phase 5 — 10:30 AM: General Document Upload

**Goal:** Test the new `DRIVE__ProcessUpload` workflow for general-purpose document triage.

### Actions

1. **Create a test invoice** as a `.txt` file named `invoice-2026-05-29.txt`:

   ```
   INVOICE #INV-2026-0529

   From: Acme Cloud Services
   To: Your Company Inc.
   Date: May 29, 2026
   Due Date: June 28, 2026

   Description                    Qty    Unit Price    Total
   Cloud Hosting (May 2026)       1      $499.00       $499.00
   Additional Storage (50GB)      1      $25.00        $25.00
   SSL Certificate Renewal        1      $79.00        $79.00
                                                       --------
   Subtotal:                                           $603.00
   Tax (8%):                                           $48.24
   TOTAL DUE:                                          $651.24

   Payment Terms: Net 30
   Bank: First National Bank, Account: XXXX-4521
   ```

2. **Upload it** to the **General-Uploads** folder in Google Drive.

3. **Wait 5 minutes** for the trigger.

### Expected Results

- [ ] `DRIVE__ProcessUpload` triggers
- [ ] Deduplication passes
- [ ] File downloaded and text extracted
- [ ] AI classifies document as: `Invoice`
- [ ] AI generates a 2-sentence summary (e.g., mentions Acme, $651.24, due June 28)
- [ ] Event stored in `events` table with `event_type: 'drive_upload'`
- [ ] Slack notification posted to `#general-uploads` with classification and summary
- [ ] Audit log recorded

### Database Verification

```sql
SELECT event_type, payload->>'classification' AS classification,
       payload->>'summary' AS summary,
       payload->>'file_name' AS file_name,
       status
FROM events
WHERE event_type = 'drive_upload'
ORDER BY created_at DESC LIMIT 1;
```

---

## Phase 6 — 11:00 AM: Task Management Operations

**Goal:** Test task reminders and escalation workflows as if it were a normal business day with overdue items.

### Setup — Create Overdue Test Tasks

```sql
-- Create an upcoming task (due in 24 hours)
INSERT INTO tasks (title, description, assigned_to, priority, status, deadline, source_event_id)
SELECT
  'Review Q2 budget proposal',
  'Review and approve the Q2 budget before the board meeting',
  u.id,
  'high',
  'open',
  NOW() + INTERVAL '24 hours',
  NULL
FROM users u WHERE u.email = 'ops.manager@yourdomain.com';

-- Create an overdue task (due 36 hours ago, should trigger escalation)
INSERT INTO tasks (title, description, assigned_to, priority, status, deadline, source_event_id)
SELECT
  'Submit compliance audit report',
  'Quarterly compliance audit report is past due',
  u.id,
  'medium',
  'open',
  NOW() - INTERVAL '36 hours',
  NULL
FROM users u WHERE u.email = 'ops.manager@yourdomain.com';
```

### Actions

1. **Manually execute `TASK__SendReminders`** (`02xGHF5Lb5WrWymj`) in the n8n editor.
2. **Manually execute `TASK__Escalate`** (`c51T7RfiQp9o3BSa`) in the n8n editor.

### Expected Results — Reminders

- [ ] Query finds the upcoming task (within 48-hour window)
- [ ] Query finds the overdue task
- [ ] Slack reminders sent grouped by assignee
- [ ] Audit log recorded

### Expected Results — Escalation

- [ ] Overdue task (>24h past deadline) is detected
- [ ] Task priority updated to `critical`
- [ ] `escalated_at` timestamp set
- [ ] Manager notification sent via Slack
- [ ] Escalation alert sent to #ops-alerts channel
- [ ] Audit log recorded

### Database Verification

```sql
-- Check escalation was applied
SELECT title, priority, status, deadline, escalated_at,
       deadline < NOW() - INTERVAL '24 hours' AS should_escalate
FROM tasks
WHERE title = 'Submit compliance audit report';
```

---

## Phase 7 — 12:00 PM: Executive Reporting

**Goal:** Generate daily and weekly reports that aggregate all the activity from the simulation.

### Actions

1. **Manually execute `REPORT__DailySummary`** (`FL1osvOgkenc4cWR`).
2. **Manually execute `REPORT__WeeklyDigest`** (`q22LQULET4OoBYva`).

### Expected Results — Daily Summary

- [ ] SQL queries aggregate today's metrics:
  - Emails processed count
  - Tasks created / completed / overdue count
  - AI calls made count
  - Errors encountered count
  - Approvals pending / completed count
- [ ] `UTIL__AICall` generates executive summary with recommendations
- [ ] Google Doc created in the Daily Operations Reports folder
- [ ] Slack notification posted to #executive-updates
- [ ] Audit log recorded

### Expected Results — Weekly Digest

- [ ] Same aggregation over 7-day window
- [ ] Trend comparison (this week vs last week)
- [ ] Google Doc created in the Weekly Digest Reports folder
- [ ] Slack notification posted

### Database Verification

```sql
-- Check report generation audit trail
SELECT workflow_name, action, status, created_at
FROM workflow_logs
WHERE workflow_name IN ('REPORT__DailySummary', 'REPORT__WeeklyDigest')
ORDER BY created_at DESC LIMIT 5;
```

---

## Phase 8 — 1:00 PM: Error Handling & Resilience

**Goal:** Verify the system handles failures gracefully without losing data.

### Test A — Intentional Node Failure

1. Temporarily **invalidate** the OpenRouter API key in n8n credentials (add an extra character).
2. Trigger an AI-dependent workflow (e.g., send another test email to trigger `EMAIL__ClassifyIncoming`).
3. Wait for the execution to fail.

### Expected Results

- [ ] `UTIL__AICall` retries with exponential backoff
- [ ] After retries exhausted, failover to secondary model (if configured)
- [ ] If all retries fail, `ERROR__GlobalHandler` (`Fa1qAUIxfJj6SjfY`) catches the error
- [ ] Slack alert sent with: workflow name, failed node, error message, execution link
- [ ] Error logged to `workflow_logs` with `log_type = 'error'`
- [ ] Original input payload preserved (dead letter queue)

### Database Verification

```sql
-- Check error was logged
SELECT workflow_name, action, error_message, input_payload, status, created_at
FROM workflow_logs
WHERE log_type = 'error'
ORDER BY created_at DESC LIMIT 3;
```

4. **Restore** the correct OpenRouter API key.

### Test B — Deduplication Resilience

1. Re-upload the **same** refund SOP document from Phase 1 to the Knowledge-Base folder.

### Expected Results

- [ ] `KB__IngestDocument` triggers
- [ ] `UTIL__Deduplicate` returns `isDuplicate: true` — OR —
- [ ] Content hash comparison finds document unchanged → processing skipped
- [ ] No duplicate embeddings created in `embeddings_metadata`
- [ ] Logged as "no change" or "duplicate"

---

## Phase 9 — 2:00 PM: Workflow Backup

**Goal:** Verify the backup system preserves all workflows to GitHub.

### Actions

1. **Manually execute `UTIL__BackupWorkflows`** (`GiOkpW6AJ4rTCYPa`).

### Expected Results

- [ ] All active workflows fetched via n8n internal API
- [ ] Changed workflows pushed to private GitHub repository
- [ ] Backup audit log recorded in `workflow_logs`
- [ ] GitHub repository contains up-to-date workflow JSON files

---

## Post-Simulation Audit

After completing all phases, run these final validation queries to confirm the full system operated correctly throughout the day.

### Overall System Health

```sql
-- Total events processed today
SELECT event_type, COUNT(*) AS count, 
       COUNT(*) FILTER (WHERE status = 'completed') AS completed,
       COUNT(*) FILTER (WHERE status = 'failed') AS failed
FROM events
WHERE created_at > CURRENT_DATE
GROUP BY event_type;

-- Total AI calls made today
SELECT action, COUNT(*) AS calls,
       AVG(latency_ms)::int AS avg_latency_ms,
       SUM(tokens_input) AS total_tokens_in,
       SUM(tokens_output) AS total_tokens_out
FROM workflow_logs
WHERE log_type = 'ai_call' AND created_at > CURRENT_DATE
GROUP BY action;

-- Total errors today
SELECT workflow_name, COUNT(*) AS error_count
FROM workflow_logs
WHERE log_type = 'error' AND created_at > CURRENT_DATE
GROUP BY workflow_name;

-- Tasks created today
SELECT priority, status, COUNT(*) AS count
FROM tasks
WHERE created_at > CURRENT_DATE
GROUP BY priority, status
ORDER BY priority, status;

-- Documents in knowledge base
SELECT status, COUNT(*) AS count, SUM(chunk_count) AS total_chunks
FROM documents
GROUP BY status;

-- Embeddings stored
SELECT COUNT(*) AS total_embeddings,
       COUNT(*) FILTER (WHERE embedding IS NOT NULL) AS with_vectors
FROM embeddings_metadata;
```

---

## Simulation Results Summary

| Phase | Workflow(s) Tested | Status |
|-------|-------------------|--------|
| 1. Knowledge Base Ingestion | `KB__IngestDocument`, `KB__ChunkAndEmbed`, `UTIL__AICall` | ☐ Pass / ☐ Fail |
| 2. Semantic Search | `KB__SemanticSearch`, `UTIL__AICall` | ☐ Pass / ☐ Fail |
| 3. Email Intake & Drafting | `EMAIL__ClassifyIncoming`, `EMAIL__GenerateDraft`, `UTIL__AICall` | ☐ Pass / ☐ Fail |
| 4. Meeting Intelligence | `MEET__ProcessTranscript`, `MEET__ExtractActions`, `TASK__CreateFromEvent` | ☐ Pass / ☐ Fail |
| 5. General Document Upload | `DRIVE__ProcessUpload`, `UTIL__AICall` | ☐ Pass / ☐ Fail |
| 6. Task Reminders & Escalation | `TASK__SendReminders`, `TASK__Escalate` | ☐ Pass / ☐ Fail |
| 7. Executive Reporting | `REPORT__DailySummary`, `REPORT__WeeklyDigest` | ☐ Pass / ☐ Fail |
| 8. Error Handling | `ERROR__GlobalHandler`, `UTIL__Deduplicate` | ☐ Pass / ☐ Fail |
| 9. Backup | `UTIL__BackupWorkflows` | ☐ Pass / ☐ Fail |

### Cross-Cutting Utilities Validated

| Utility | Called During Phases | Status |
|---------|---------------------|--------|
| `UTIL__AICall` | 1, 2, 3, 4, 5, 7 | ☐ Pass / ☐ Fail |
| `UTIL__Deduplicate` | 1, 3, 4, 5, 8 | ☐ Pass / ☐ Fail |
| `UTIL__SendSlackMessage` | 3, 4, 5, 6, 7, 8 | ☐ Pass / ☐ Fail |
| `UTIL__WriteAuditLog` | 1, 2, 3, 4, 5, 6, 7, 9 | ☐ Pass / ☐ Fail |

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Trigger doesn't fire | Workflow not set to Active | Toggle Active in n8n |
| Trigger fires but duplicate skip | File was processed before | Use a new file or clear the `events` table hash |
| AI call returns empty | API key invalid or rate limited | Check credentials in n8n, check OpenRouter dashboard |
| Embedding insert fails | Vector dimension mismatch | Ensure Hugging Face returns 384-dim, check `vector(384)` column |
| Slack message not received | Wrong channel name or bot not in channel | Invite bot to channel, verify channel ID |
| Draft not in Gmail | Google OAuth expired | Re-authenticate Gmail credential in n8n |
| Task not created | `assigned_to` user doesn't exist | Insert test users into `users` table first |
| Error handler silent | Workflow not configured with error workflow | Set `ERROR__GlobalHandler` in workflow Settings |
| Webhook returns 401 | Missing or wrong auth header | Check Bearer token matches n8n credential |

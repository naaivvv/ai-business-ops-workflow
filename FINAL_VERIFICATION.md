# Final Verification Runbook

Date: 2026-05-28

This project runs on n8n Cloud and Supabase. Local verification can confirm exported workflow structure, workflow IDs, error-handler wiring, webhook authentication metadata, and database bootstrap SQL. End-to-end pass/fail still requires live n8n executions with the configured Google, Slack, Supabase, OpenRouter, Hugging Face, and GitHub credentials.

## Local Export Verification

- [x] All workflow JSON exports parse successfully.
- [x] `ERROR__GlobalHandler` export ID is `Fa1qAUIxfJj6SjfY`.
- [x] All production workflow exports set `settings.errorWorkflow` to `Fa1qAUIxfJj6SjfY`.
- [x] `MEET__ProcessTranscript` keeps workflow ID `CpXv8Are7dDLolBo`.
- [x] `EMAIL__GenerateDraft` keeps workflow ID `zFwK1eHHECz9VrHm`.
- [x] `UTIL__Deduplicate` keeps workflow ID `rIRBjduPjTFXnn81`.
- [x] `KB__SemanticSearch` Webhook node uses Header Auth.
- [x] `KB__SemanticSearch` references Header Auth credential `KB Semantic Search Bearer Token`.
- [x] `database/init.sql` creates all seven core tables: `users`, `events`, `tasks`, `workflow_logs`, `approvals`, `documents`, `embeddings_metadata`.
- [x] `database/init.sql` enables `pgcrypto`.
- [x] `database/init.sql` enables `vector`.
- [x] `database/init.sql` stores embeddings as `vector(384)`.
- [x] `database/init.sql` creates the `match_documents` pgvector function.
- [x] `WORKFLOW_IDs.md` includes the key live n8n workflow IDs.

## Infrastructure

- [x] n8n Cloud accessible at `https://edwin-bayog.app.n8n.cloud/` (`200 OK` from GET reachability check).
- [x] Supabase PostgreSQL has all seven core tables.
- [x] Supabase has `vector` extension enabled.
- [x] Supabase has `match_documents` function.
- [x] n8n Cloud can connect to Supabase with the configured credential.

Self-hosted checks are not applicable for the current deployment:

- [x] Docker container health check skipped because deployment is n8n Cloud.
- [x] Redis check skipped because queue/cache is managed by n8n Cloud or handled in PostgreSQL/internal n8n state.

## Security

- [ ] n8n credential `KB Semantic Search Bearer Token` exists.
- [ ] Header name is `Authorization`.
- [ ] Header value is `Bearer YOUR_SECRET_TOKEN` or the production secret.
- [ ] Unauthenticated `KB__SemanticSearch` webhook request is rejected.
- [ ] Authenticated `KB__SemanticSearch` webhook request succeeds.
- [ ] Google OAuth app is in Production mode, or n8n Cloud built-in Google OAuth is being used.
- [ ] OpenRouter API key rotated and old key deactivated.
- [ ] Hugging Face API key rotated and old key deactivated.
- [ ] Slack bot token rotated and old token deactivated.
- [ ] n8n Cloud execution data retention is configured in Settings -> Execution Data.

## Utility Workflows

- [ ] `ERROR__GlobalHandler`: trigger intentional failure and confirm Slack alert plus `workflow_logs` error row.
- [ ] `UTIL__WriteAuditLog`: execute with sample payload and confirm row in `workflow_logs`.
- [ ] `UTIL__SendSlackMessage`: execute with test channel and confirm Slack message.
- [ ] `UTIL__AICall`: execute fast-model prompt and confirm response plus usage logging.
- [ ] `UTIL__AICall`: execute embedding request and confirm 384-dimension embedding response.
- [ ] `UTIL__Deduplicate`: execute once and confirm `isDuplicate:false`.
- [ ] `UTIL__Deduplicate`: execute same payload again and confirm `isDuplicate:true`.

## Email Workflows

- [ ] Activate `EMAIL__ClassifyIncoming` after Gmail credential/folder settings are correct.
- [ ] Send a test email and confirm classification appears in `events`.
- [ ] Confirm classification notification appears in Slack.
- [ ] Confirm low-confidence path routes to human review when confidence is below threshold.
- [ ] Confirm eligible email calls `EMAIL__GenerateDraft`.
- [ ] Confirm draft appears in Gmail Drafts.
- [ ] Confirm draft notification appears in Slack.
- [ ] Confirm `EMAIL__ApproveAndSend` rejects unauthenticated requests.
- [ ] Confirm `EMAIL__ApproveAndSend` sends an approved Gmail draft.
- [ ] Confirm `EMAIL__ApproveAndSend` does not send a rejected Gmail draft.
- [ ] Confirm `EMAIL__ApproveAndSend` updates `approvals` when `approval_id` is provided.

## Meeting Workflows

- [ ] Activate `MEET__ProcessTranscript` after Google Drive credential/folder settings are correct.
- [ ] Upload `.txt` transcript to `Meeting-Transcripts`.
- [ ] Confirm event deduplication record is created.
- [ ] Confirm summary is created in Google Docs.
- [ ] Confirm Slack summary notification is sent.
- [ ] Confirm `MEET__ExtractActions` creates action-item tasks.

## Knowledge Base

- [ ] Activate `KB__IngestDocument` after Google Drive credential/folder settings are correct.
- [ ] Upload a test document to `Knowledge-Base`.
- [ ] Confirm document row is created or updated in `documents`.
- [ ] Confirm chunks are written to `embeddings_metadata`.
- [ ] Confirm embeddings are stored in the `embedding vector(384)` column.
- [ ] POST authenticated request to `KB__SemanticSearch`.
- [ ] Confirm response includes `query`, `answer`, `sources`, and `model_used`.
- [ ] Repeat upload unchanged document and confirm it is skipped or not duplicated.

## Task Orchestration

- [ ] Execute `TASK__CreateFromEvent` with a sample task payload.
- [ ] Confirm task row is created.
- [ ] Confirm Slack assignment notification is sent when assignee has `slack_user_id`.
- [ ] Run `TASK__SendReminders` with an upcoming/overdue test task.
- [ ] Confirm reminder message is sent.
- [ ] Run `TASK__Escalate` with a task overdue by more than 24 hours.
- [ ] Confirm task priority becomes `critical`.
- [ ] Confirm `escalated_at` is set.
- [ ] Confirm manager and ops Slack notifications are sent.

## Reporting

- [ ] Run `REPORT__DailySummary`.
- [ ] Confirm daily report Google Doc is created.
- [ ] Confirm daily report Slack notification is sent.
- [ ] Run `REPORT__WeeklyDigest`.
- [ ] Confirm weekly digest Google Doc is created.
- [ ] Confirm weekly digest Slack notification is sent.

## Backup

- [ ] Confirm private GitHub backup repository exists.
- [ ] Confirm GitHub credential exists in n8n.
- [ ] Confirm Google Drive folder `n8n-workflow-exports` exists.
- [ ] Upload manual n8n export JSON to the backup folder.
- [ ] Confirm `UTIL__BackupWorkflows` creates or updates workflow JSON files in GitHub.
- [ ] Confirm backup audit log is written.

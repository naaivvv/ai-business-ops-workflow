# FILE: DATABASE.md

```markdown
# Database Design

# Database: Supabase (PostgreSQL + pgvector)

```sql
-- Enable the pgvector extension to support embedding storage and similarity search
CREATE EXTENSION IF NOT EXISTS vector;
```

---

# users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    department TEXT,
    manager_id UUID REFERENCES users(id),
    slack_user_id TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_department ON users(department);
```

---

# events

```sql
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    source TEXT NOT NULL,
    dedup_hash TEXT,
    payload JSONB,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'skipped')),
    workflow_execution_id TEXT,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);

CREATE UNIQUE INDEX idx_events_dedup ON events(dedup_hash) WHERE dedup_hash IS NOT NULL;
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_created ON events(created_at);
```

### Notes

- `dedup_hash` stores the SHA-256 hash of `source + dedup_key` for duplicate detection (used by UTIL__Deduplicate).
- `workflow_execution_id` links to the n8n execution for debugging.
- `status` uses a CHECK constraint to prevent inconsistent values (e.g., "pending" vs "Pending" vs "PENDING").
- `processed_at` tracks when processing completed, enabling duration calculation (`processed_at - created_at`).

---

# tasks

```sql
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    assigned_to UUID REFERENCES users(id),
    priority TEXT NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')),
    source_event_id UUID REFERENCES events(id),
    deadline TIMESTAMP,
    escalated_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_deadline ON tasks(deadline);
CREATE INDEX idx_tasks_source_event ON tasks(source_event_id);
```

### Notes

- `source_event_id` provides full traceability — every task links back to the event that created it (email, meeting, form).
- `escalated_at` is set by TASK__Escalate when a task is overdue by more than 24 hours.
- `completed_at` records the exact completion time (not just a status flag change).
- `updated_at` tracks the last modification for audit purposes.

---

# workflow_logs (unified — replaces separate ai_logs and audit_logs)

```sql
CREATE TABLE workflow_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_name TEXT NOT NULL,
    execution_id TEXT,
    log_type TEXT NOT NULL
        CHECK (log_type IN ('ai_call', 'action', 'error', 'audit')),
    action TEXT,
    input_payload JSONB,
    output_payload JSONB,
    model TEXT,
    tokens_input INTEGER,
    tokens_output INTEGER,
    latency_ms INTEGER,
    cost_usd DECIMAL(10, 6),
    status TEXT DEFAULT 'success'
        CHECK (status IN ('success', 'failure')),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_workflow_logs_type ON workflow_logs(log_type);
CREATE INDEX idx_workflow_logs_workflow ON workflow_logs(workflow_name);
CREATE INDEX idx_workflow_logs_created ON workflow_logs(created_at);
CREATE INDEX idx_workflow_logs_status ON workflow_logs(status);
```

### Why Unified?

Previously, `ai_logs` stored workflow_name + prompt + response and `audit_logs` stored workflow_name + action + payload. These inevitably log overlapping events with different schemas, making querying and correlation difficult. A single `workflow_logs` table with a `log_type` discriminator gives you:

- One queryable log stream for all operational events
- Consistent schema with optional fields (`model`, `tokens_*` are NULL for non-AI logs)
- Easy filtering: `WHERE log_type = 'ai_call'` replaces querying a separate table
- Unified cost tracking across all AI providers

### Field Guide

| Field | Used By | Description |
|-------|---------|-------------|
| `workflow_name` | All types | Which workflow generated this log |
| `execution_id` | All types | n8n execution ID for direct UI navigation |
| `log_type` | All types | Discriminator: ai_call, action, error, audit |
| `action` | action, audit | What happened (e.g., 'email_classified', 'task_created') |
| `input_payload` | ai_call, error | Full input for replay/debugging (dead letter queue for errors) |
| `output_payload` | ai_call, action | AI response or action result |
| `model` | ai_call | Which AI model was used (e.g., 'gpt-4o', 'gemini-pro') |
| `tokens_input` | ai_call | Input tokens consumed |
| `tokens_output` | ai_call | Output tokens generated |
| `latency_ms` | ai_call | API call duration in milliseconds |
| `cost_usd` | ai_call | Computed cost of this AI call |
| `error_message` | error | Error description for failed operations |

---

# approvals

```sql
CREATE TABLE approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_type TEXT NOT NULL,
    source_workflow TEXT NOT NULL,
    request_payload JSONB,
    approver UUID REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
    decision_notes TEXT,
    expires_at TIMESTAMP,
    approved_at TIMESTAMP,
    rejected_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_approvals_status ON approvals(status);
CREATE INDEX idx_approvals_approver ON approvals(approver);
CREATE INDEX idx_approvals_expires ON approvals(expires_at);
```

### Notes

- `source_workflow` records which workflow requested the approval (e.g., 'EMAIL__ClassifyIncoming').
- `decision_notes` allows approvers to explain rejections or add context.
- `expires_at` prevents approvals from sitting forever — a cron can mark expired approvals.
- Both `approved_at` and `rejected_at` are tracked (the original schema only had `approved_at`).
- `created_at` is now included (was missing from the original schema).

---

# documents

```sql
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    source_type TEXT NOT NULL
        CHECK (source_type IN ('google_doc', 'pdf', 'docx', 'sop', 'policy', 'report')),
    source_url TEXT,
    source_file_id TEXT,
    content_hash TEXT NOT NULL,
    chunk_count INTEGER DEFAULT 0,
    embedding_model TEXT DEFAULT 'text-embedding-3-small',
    collection_name TEXT DEFAULT 'knowledge_base',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_documents_hash ON documents(content_hash);
CREATE INDEX idx_documents_source_file ON documents(source_file_id);
CREATE INDEX idx_documents_status ON documents(status);
```

### Notes

- `content_hash` (SHA-256 of extracted text) enables incremental processing — if the hash hasn't changed, skip re-embedding.
- `source_file_id` is the Google Drive file ID, used for deduplication and change detection.
- `embedding_model` records which model was used — changing models later requires re-embedding the entire knowledge base.
- `collection_name` logically separates documents (e.g., 'knowledge_base', 'meeting_notes') within the vector table.

---

# embeddings_metadata

```sql
CREATE TABLE embeddings_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    embedding vector(384),
    collection_name TEXT NOT NULL DEFAULT 'knowledge_base',
    embedding_model TEXT NOT NULL DEFAULT 'sentence-transformers/all-MiniLM-L6-v2',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_embeddings_document ON embeddings_metadata(document_id);
-- HNSW index for vector similarity search
CREATE INDEX idx_embeddings_vector ON embeddings_metadata USING hnsw (embedding vector_cosine_ops);
```

### Semantic Search Function (RAG)

```sql
CREATE OR REPLACE FUNCTION match_documents (
  query_embedding vector(384),
  match_threshold float,
  match_count int,
  filter_collection text DEFAULT 'knowledge_base'
)
RETURNS TABLE (
  id uuid,
  document_id uuid,
  chunk_text text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    embeddings_metadata.id,
    embeddings_metadata.document_id,
    embeddings_metadata.chunk_text,
    1 - (embeddings_metadata.embedding <=> query_embedding) AS similarity
  FROM embeddings_metadata
  WHERE 1 - (embeddings_metadata.embedding <=> query_embedding) > match_threshold
    AND embeddings_metadata.collection_name = filter_collection
  ORDER BY embeddings_metadata.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

### Notes

- `embedding` stores the 384-dimensional vector representation directly in PostgreSQL, eliminating the need for an external vector DB.
- `ON DELETE CASCADE` ensures that when a document row is deleted, all its embedding metadata rows are automatically removed.
- `chunk_text` stores the raw text for debugging and potential re-embedding without re-downloading the source document.

---

# Suggested Future Tables

- departments (department metadata, routing rules)
- workflow_runs (execution history beyond n8n's built-in retention)
- notifications (delivery tracking, read receipts)
- ai_feedback (human ratings on AI outputs for quality tracking)
- incidents (operational incident tracking beyond error logs)
- knowledge_queries (search query analytics for KB optimization)
```

---
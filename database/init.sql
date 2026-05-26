CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
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

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_department ON users(department);

CREATE TABLE IF NOT EXISTS events (
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

CREATE UNIQUE INDEX IF NOT EXISTS idx_events_dedup ON events(dedup_hash) WHERE dedup_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_created ON events(created_at);

CREATE TABLE IF NOT EXISTS tasks (
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

CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_deadline ON tasks(deadline);
CREATE INDEX IF NOT EXISTS idx_tasks_source_event ON tasks(source_event_id);

CREATE TABLE IF NOT EXISTS workflow_logs (
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

CREATE INDEX IF NOT EXISTS idx_workflow_logs_type ON workflow_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_workflow_logs_workflow ON workflow_logs(workflow_name);
CREATE INDEX IF NOT EXISTS idx_workflow_logs_created ON workflow_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_workflow_logs_status ON workflow_logs(status);

CREATE TABLE IF NOT EXISTS approvals (
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

CREATE INDEX IF NOT EXISTS idx_approvals_status ON approvals(status);
CREATE INDEX IF NOT EXISTS idx_approvals_approver ON approvals(approver);
CREATE INDEX IF NOT EXISTS idx_approvals_expires ON approvals(expires_at);

CREATE TABLE IF NOT EXISTS documents (
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

CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_hash ON documents(content_hash);
CREATE INDEX IF NOT EXISTS idx_documents_source_file ON documents(source_file_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);

CREATE TABLE IF NOT EXISTS embeddings_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    vector_id TEXT NOT NULL,
    collection_name TEXT NOT NULL DEFAULT 'knowledge_base',
    embedding_model TEXT NOT NULL DEFAULT 'text-embedding-3-small',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_embeddings_document ON embeddings_metadata(document_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON embeddings_metadata(vector_id);

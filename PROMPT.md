# PROMPT.md — n8n Workflow Build Prompts

> **How to use this file:** Each phase below contains numbered prompts. Use each prompt to build one n8n workflow (or complete one setup task). Prompts are ordered by dependency — complete them in sequence. Each prompt includes the external setup steps required before building in n8n.

---

# Deployment Mode

## Current Setup: Cloud-Native (n8n Cloud + Supabase)

| Component | Where It Runs | URL |
|-----------|--------------|-----|
| **n8n** | ☁️ n8n Cloud | `https://edwin-bayog.app.n8n.cloud/` |
| **PostgreSQL & Vectors** | ☁️ Supabase | Project Dashboard |

### What This Means

- **Workflows are built in n8n Cloud** — open `https://edwin-bayog.app.n8n.cloud/` to create and manage workflows.
- **Supabase handles all data** — PostgreSQL and pgvector embeddings are fully managed in the cloud. No local Docker containers are required.
- **Google OAuth is simpler** — n8n Cloud includes pre-verified Google integrations, so you may not need to create your own Google Cloud OAuth app. If n8n Cloud's built-in Google credential works, skip PROMPT 0.2's Google Cloud Console steps and use n8n's built-in OAuth flow instead.
- **Webhook URLs use your cloud domain** — all webhook endpoints will be at `https://edwin-bayog.app.n8n.cloud/webhook/...` (publicly accessible, no tunnel needed).
- **Execution links in Slack alerts** point to `https://edwin-bayog.app.n8n.cloud/workflow/executions/...`.

---

# PHASE 0 — External Service Setup (Before Touching n8n)

Complete ALL of these setup tasks before opening n8n. Each section is a standal## PROMPT 0.1 — Supabase Setup (Database & Vector Store)

> **Goal:** Create a Supabase project and get your PostgreSQL connection credentials.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### What to do

1. Go to [Supabase](https://supabase.com/) and create a new project.
2. Wait for the database to provision.
3. Go to **Project Settings -> Database** and copy the **Connection string (URI)**.
4. Replace `[YOUR-PASSWORD]` with the database password you created.

### .env File

Create `.env` in your project root with these values (replace placeholders):

```env
# n8n Cloud Instance
N8N_CLOUD_URL=https://edwin-bayog.app.n8n.cloud

# Supabase (PostgreSQL + pgvector)
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_KEY=your-supabase-service-role-key
SUPABASE_DB_PASSWORD=your-database-password

# OpenRouter
OPENROUTER_API_KEY=sk-or-v1-your-openrouter-key

# Hugging Face
HUGGINGFACE_API_KEY=hf_your-huggingface-key

# Slack (filled in PROMPT 0.3)
SLACK_BOT_TOKEN=
```

### Verification Checklist

- [ ] Supabase project is active
- [ ] Database connection string is saved securely

✂️ **TO HERE** ✂️] You can log into your n8n Cloud account


✂️ **TO HERE** ✂️

---

## PROMPT 0.2 — Google Cloud OAuth Setup

> **Goal:** Create Google Cloud credentials for Gmail, Drive, Docs, and Calendar access.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### Step-by-Step Setup Guide

1. **Go to Google Cloud Console:** https://console.cloud.google.com/
2. **Create a new project** (or select existing):
   - Click project dropdown → "New Project"
   - Name: `n8n-business-ops`
   - Click "Create"
3. **Enable APIs** — Go to "APIs & Services" → "Library" and enable:
   - Gmail API
   - Google Drive API
   - Google Docs API
   - Google Calendar API
   - Google Sheets API
4. **Create OAuth Consent Screen:**
   - Go to "APIs & Services" → "OAuth consent screen"
   - User Type: **External** (or Internal if using Google Workspace)
   - App name: `n8n Business Operations`
   - User support email: your email
   - Scopes: Add these scopes:
     - `https://www.googleapis.com/auth/gmail.modify`
     - `https://www.googleapis.com/auth/gmail.compose`
     - `https://www.googleapis.com/auth/drive`
     - `https://www.googleapis.com/auth/documents`
     - `https://www.googleapis.com/auth/calendar`
     - `https://www.googleapis.com/auth/spreadsheets`
   - Test users: Add your email address
   - **CRITICAL:** After testing is complete, publish the app to **Production** mode. Testing-mode tokens expire every 7 days and will silently break your Gmail/Drive triggers.
5. **Create OAuth Client ID:**
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth Client ID"
   - Application type: **Web application**
   - Name: `n8n OAuth`
   - Authorized redirect URIs:
     - **For n8n Cloud:** `https://edwin-bayog.app.n8n.cloud/rest/oauth2-credential/callback`
     - **For self-hosted (future):** `http://localhost:5678/rest/oauth2-credential/callback`
   - Click "Create"
   - Copy the **Client ID** and **Client Secret**
6. **Update your .env file:**
   ```env
   GOOGLE_CLIENT_ID=your_client_id_here
   GOOGLE_CLIENT_SECRET=your_client_secret_here
   ```

> **n8n Cloud Shortcut:** n8n Cloud includes pre-verified Google integrations. Try creating the Google credential in n8n first using the built-in OAuth flow — if it works and requests all the scopes you need (Gmail, Drive, Docs, Calendar, Sheets), you can skip steps 1–5 above entirely. Only create your own Google Cloud project if the built-in credential is missing scopes.

### Configure in n8n

1. Open n8n at `https://edwin-bayog.app.n8n.cloud/`
2. Go to **Credentials** → **Add Credential**
3. Search for "Google OAuth2 API"
4. **Try the built-in OAuth first** — if n8n Cloud offers a "Sign in with Google" button without asking for Client ID/Secret, use that.
5. **If custom credentials needed:** Enter your Client ID and Client Secret, then click **Sign in with Google**
6. Save the credential — name it `Google Business Ops`

### Verification Checklist

- [ ] OAuth consent screen is configured with all required scopes
- [ ] Client ID and Client Secret are saved in `.env`
- [ ] n8n credential "Google Business Ops" is created and authorized
- [ ] Test: Create a manual workflow with a Gmail node → it can list your inbox


✂️ **TO HERE** ✂️

---

## PROMPT 0.3 — Slack Bot Setup

> **Goal:** Create a Slack bot with permissions to post messages to any channel.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### Step-by-Step Setup Guide

1. **Go to Slack API:** https://api.slack.com/apps
2. **Create New App:**
   - Click "Create New App" → "From scratch"
   - App Name: `n8n Business Ops Bot`
   - Workspace: Select your workspace
3. **Configure Bot Token Scopes:**
   - Go to "OAuth & Permissions" in the sidebar
   - Under "Bot Token Scopes", add:
     - `chat:write` — Send messages
     - `chat:write.public` — Send to channels without joining
     - `channels:read` — List channels
     - `users:read` — Look up user info
     - `users:read.email` — Look up users by email
4. **Install to Workspace:**
   - Click "Install to Workspace" at the top of the "OAuth & Permissions" page
   - Authorize the requested permissions
   - Copy the **Bot User OAuth Token** (starts with `xoxb-`)
5. **Update your .env file:**
   ```env
   SLACK_BOT_TOKEN=xoxb-your-bot-token-here
   ```
6. **Create Slack channels** for routing:
   - `#ops-alerts` — Error notifications and escalations
   - `#email-routing` — Email classification notifications
   - `#meeting-summaries` — Meeting transcript summaries
   - `#executive-updates` — Daily/weekly reports
   - `#task-reminders` — Task reminder notifications

### Configure in n8n

1. Go to **Credentials** → **Add Credential**
2. Search for "Slack API"
3. Enter your Bot User OAuth Token
4. Save — name it `Slack Business Ops Bot`

### Verification Checklist

- [ ] Bot token (`xoxb-...`) saved in `.env`
- [ ] n8n credential "Slack Business Ops Bot" is created
- [ ] All 5 Slack channels are created
- [ ] Test: Send a test message from n8n to `#ops-alerts`


✂️ **TO HERE** ✂️

---

## PROMPT 0.4 — OpenRouter API Key Setup

> **Goal:** Get an OpenRouter API key with access to free tier models (e.g., Llama 3.3 70B, Gemini 2.5 Pro).

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### Step-by-Step Setup Guide

1. **Go to OpenRouter:** https://openrouter.ai/
2. **Create API Key:**
   - Go to "Keys" in the profile menu
   - Click "Create Key"
   - Name: `n8n-business-ops`
   - Copy the key immediately
3. **Set Usage Limits (recommended):**
   - OpenRouter allows setting credit limits to prevent unexpected charges, even when primarily using free models.
4. **Verify model access:**
   - Free models like `meta-llama/llama-3.3-70b-instruct:free` and `google/gemini-2.5-pro:free` are available without adding credits.

### Configure in n8n

1. Go to **Credentials** → **Add Credential**
2. Search for "Header Auth" (or use a custom OpenAI-compatible node)
3. Enter your API key in the value field (e.g., `Bearer sk-or-v1-...`)
4. Save — name it `OpenRouter API`

### Verification Checklist

- [ ] API key saved in `.env` as `OPENROUTER_API_KEY`
- [ ] n8n credential "OpenRouter API" is created
- [ ] Test: Create a manual workflow with an HTTP Request node → send a test prompt to OpenRouter's `/api/v1/chat/completions` endpoint


✂️ **TO HERE** ✂️

---

## PROMPT 0.5 — Hugging Face API Key Setup

> **Goal:** Get a Hugging Face API key to generate embeddings via the free Inference API.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### Step-by-Step Setup Guide

1. **Go to Hugging Face:** https://huggingface.co/settings/tokens
2. **Get API Key:**
   - Click "New token"
   - Select "Read" role
   - Name it `n8n-embeddings`
   - Copy the key
3. **Update your .env file:**
   ```env
   HUGGINGFACE_API_KEY=hf_your-huggingface-key
   ```

### Configure in n8n

1. Go to **Credentials** → **Add Credential**
2. Search for "Hugging Face Inference API"
3. Enter your Access Token
4. Save — name it `Hugging Face Embeddings`

### Verification Checklist

- [ ] API key saved in `.env`
- [ ] n8n credential "Hugging Face Embeddings" is created
- [ ] Test: Send a test prompt via Hugging Face node to generate embeddings


✂️ **TO HERE** ✂️

---

## PROMPT 0.6 — PostgreSQL Database Initialization

> **Goal:** Create all required tables from DATABASE.md in PostgreSQL.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### What to do

Execute the following SQL script in the Supabase Dashboard SQL Editor to create all necessary tables and functions.

### Supabase SQL Script

```sql
-- ============================================
-- AI Business Operations — Database Schema
-- Auto-executed on first PostgreSQL start
-- ============================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable the pgvector extension (Supabase supports this out of the box)
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- USERS
-- ============================================
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

-- ============================================
-- EVENTS
-- ============================================
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

-- ============================================
-- TASKS
-- ============================================
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

-- ============================================
-- WORKFLOW LOGS (unified: AI calls, audits, errors)
-- ============================================
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

-- ============================================
-- APPROVALS
-- ============================================
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

-- ============================================
-- DOCUMENTS (Knowledge Base)
-- ============================================
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    source_type TEXT NOT NULL
        CHECK (source_type IN ('google_doc', 'pdf', 'docx', 'sop', 'policy', 'report')),
    source_url TEXT,
    source_file_id TEXT,
    content_hash TEXT NOT NULL,
    chunk_count INTEGER DEFAULT 0,
    embedding_model TEXT DEFAULT 'sentence-transformers/all-MiniLM-L6-v2',
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

-- ============================================
-- EMBEDDINGS METADATA (pgvector)
-- ============================================
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

-- ============================================
-- SEMANTIC SEARCH FUNCTION (match_documents)
-- ============================================
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

-- ============================================
-- SEED DATA: Insert test users
-- ============================================
INSERT INTO users (email, name, role, department) VALUES
    ('admin@company.com', 'Admin User', 'admin', 'operations'),
    ('manager@company.com', 'Manager User', 'manager', 'operations');
```

### Commands

In the Supabase Dashboard, go to **SQL Editor** and paste the entire SQL block above. Click **Run** to execute the script.

### Verification Checklist

- [ ] All tables are created in Supabase (check the Table Editor)
- [ ] The `vector` extension is active
- [ ] The `match_documents` function is created
- [ ] Seed users are present


✂️ **TO HERE** ✂️



## PROMPT 0.8 — Google Drive Folder Structure

> **Goal:** Create the Drive folders that n8n will monitor for file triggers.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### What to do

In your Google Drive, create these folders:

```
My Drive/
├── Meeting-Transcripts/    ← Drop meeting transcripts here (Week 3)
└── Knowledge-Base/         ← Drop organizational docs here (Week 4)
```

### Steps

1. Open Google Drive (https://drive.google.com/)
2. Click "New" → "New folder" → Name: `Meeting-Transcripts`
3. Click "New" → "New folder" → Name: `Knowledge-Base`
4. Note the **folder IDs** from the URL bar when you open each folder:
   - URL looks like: `https://drive.google.com/drive/folders/FOLDER_ID_HERE`
   - Save both folder IDs — you'll need them for the Drive Trigger nodes

### Verification Checklist

- [ ] `Meeting-Transcripts` folder exists in Drive
- [ ] `Knowledge-Base` folder exists in Drive
- [ ] Both folder IDs are noted for later use in n8n workflows


✂️ **TO HERE** ✂️

---

## PROMPT 0.9 — n8n Credentials Configuration

> **Goal:** Set up all n8n credential entries so workflows can reference them.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### What to do

Open n8n at `https://edwin-bayog.app.n8n.cloud/` → **Credentials** and create the following:

| # | Credential Type | Name | Notes |
|---|----------------|------|-------|
| 1 | Google OAuth2 API | `Google Business Ops` | Use n8n Cloud's built-in OAuth flow, or Client ID + Secret from PROMPT 0.2 |
| 2 | Slack API | `Slack Business Ops Bot` | Bot token from PROMPT 0.3 |
| 3 | Header Auth | `OpenRouter API` | API key from PROMPT 0.4 |
| 4 | Hugging Face Inference API | `Hugging Face Embeddings` | API key from PROMPT 0.5 |
| 5 | Postgres | `Supabase API` | Use your Supabase connection string. |

### Verification Checklist

- [ ] All 5 credentials are created and showing green/valid status
- [ ] Test each by creating a quick manual workflow with the relevant node

---

# PHASE 1 — Foundational Workflows (Week 1)

Build these FIRST. Every workflow in Phases 2–6 depends on these utilities.


✂️ **TO HERE** ✂️

---

## PROMPT 1.1 — Build `ERROR__GlobalHandler`

> **Goal:** Create the global error handler that catches failures from all workflows and sends Slack alerts.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "ERROR__GlobalHandler" with the following:

TRIGGER: Error Trigger node (this fires when any workflow configured to use this error handler fails)

NODE 1 — Code node "Extract Error Context":
- Extract from the Error Trigger output:
  - workflow.name → workflowName
  - execution.id → executionId
  - node name that failed → failedNode
  - error message → errorMessage
- Build a direct link to the failed execution:
  "https://edwin-bayog.app.n8n.cloud/workflow/executions/EXECUTION_ID"
  (Self-hosted: "http://localhost:5678/workflow/executions/EXECUTION_ID")

NODE 2 — Slack node "Send Error Alert":
- Credential: Slack Business Ops Bot
- Channel: #ops-alerts
- Message format:
  "🚨 *Workflow Failed*
  *Workflow:* {{ workflowName }}
  *Failed Node:* {{ failedNode }}
  *Error:* {{ errorMessage }}
  *Execution:* {{ executionLink }}"

NODE 3 — Supabase node "Log Error to Dead Letter Queue":
- Credential: Supabase API
- Resource: Database
- Operation: Create
- Table: workflow_logs
- Map properties to JSON payload }}', 'failure')

Settings:
- This workflow should be ACTIVE
- Do NOT set an error workflow for this workflow itself (avoid infinite loop)
```

### After Building

Go to **every other workflow** you create → Settings → Error Workflow → select `ERROR__GlobalHandler`.

### Test

1. Create a temporary workflow with a Code node that throws an error: `throw new Error("Test error from Phase 1");`
2. Set its Error Workflow to `ERROR__GlobalHandler`
3. Execute it manually
4. Verify: Slack message appears in `#ops-alerts` AND a row appears in `workflow_logs` with `log_type = 'error'`


✂️ **TO HERE** ✂️

---

## PROMPT 1.2 — Build `UTIL__WriteAuditLog`

> **Goal:** Create a reusable sub-workflow that writes structured log entries to the `workflow_logs` table.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "UTIL__WriteAuditLog" with the following:

TRIGGER: "When Executed by Another Workflow" trigger
- Accept input data from the calling workflow

EXPECTED INPUT (JSON from caller):
{
  "workflow_name": "EMAIL__ClassifyIncoming",
  "execution_id": "abc123",
  "log_type": "action",        // 'ai_call', 'action', 'error', 'audit'
  "action": "email_classified",
  "input_payload": {},          // optional
  "output_payload": {},         // optional
  "model": null,                // optional, for AI calls
  "tokens_input": null,         // optional
  "tokens_output": null,        // optional
  "latency_ms": null,           // optional
  "cost_usd": null,             // optional
  "status": "success",          // 'success' or 'failure'
  "error_message": null         // optional
}

NODE 1 — Code node "Validate Input":
- Check that workflow_name, log_type, and action are present
- If missing, return error response

NODE 2 — Supabase node "Insert Log":
- Credential: Supabase API
- Resource: Database
- Operation: Create
- Table: workflow_logs
- Map properties to JSON payload
- Use parameterized query with values from the input

NODE 3 — Code node "Return Result":
- Return { success: true, log_id: result.id }

SETTINGS:
- Workflow Settings → "This workflow can be called by" → set to "Any workflow"
- Set Error Workflow to ERROR__GlobalHandler
```

### Test

1. Create a temporary workflow → Execute Workflow node → select `UTIL__WriteAuditLog`
2. Pass test data: `{ "workflow_name": "TEST", "log_type": "audit", "action": "test_entry", "status": "success" }`
3. Verify: Row appears in `workflow_logs` table


✂️ **TO HERE** ✂️

---

## PROMPT 1.3 — Build `UTIL__SendSlackMessage`

> **Goal:** Create a reusable sub-workflow for sending Slack messages from any workflow.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "UTIL__SendSlackMessage" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "channel": "#ops-alerts",
  "message": "Hello from n8n!",
  "thread_ts": null     // optional: reply to thread
}

NODE 1 — Code node "Validate Input":
- Check channel and message are provided
- Default channel to "#ops-alerts" if empty

NODE 2 — Slack node "Send Message":
- Credential: Slack Business Ops Bot
- Resource: Message
- Operation: Send
- Channel: {{ channel }}
- Text: {{ message }}
- If thread_ts is provided, set "Reply to Thread" → thread_ts

NODE 3 — Code node "Return Result":
- Return { success: true, message_ts: result.ts, channel: result.channel }

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 1.4 — Build `UTIL__AICall`

> **Goal:** Create the centralized AI API call handler with model selection, failover, and usage logging.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "UTIL__AICall" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "prompt": "Classify this email...",
  "system_message": "You are an email classifier...",
  "model_preference": "fast",       // 'fast', 'large-context', 'embedding'
  "output_format": "json",          // 'text' or 'json'
  "max_tokens": 1000                // optional
}

NODE 1 — Code node "Select Model":
- Based on model_preference:
  - "fast" → primary: "meta-llama/llama-3.3-70b-instruct:free", failover: "google/gemini-2.5-pro:free"
  - "large-context" → primary: "google/gemini-2.5-pro:free", failover: "meta-llama/llama-3.3-70b-instruct:free"
  - "embedding" → primary: "sentence-transformers/all-MiniLM-L6-v2", failover: null
- Record start timestamp for latency calculation

NODE 2 — IF node "Is Embedding?":
- Route to embedding path or chat completion path

NODE 3A (embedding path) — HTTP Request node "Generate Embedding (Hugging Face)":
- Method: POST
- URL: `https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/all-MiniLM-L6-v2`
- Authentication: Header Auth (Credential: Hugging Face Embeddings)
- Body: `{"inputs": ["{{ $json.prompt }}"]}`
- Settings: Retry on Fail = true, Max Retries = 3, Wait Between Retries = exponential

NODE 3B (chat path) — HTTP Request node "Chat Completion (OpenRouter)":
- Method: POST
- URL: `https://openrouter.ai/api/v1/chat/completions`
- Authentication: Header Auth (Credential: OpenRouter API)
- Body: 
  `{
    "model": "{{ $json.selected_model }}",
    "messages": [
      {"role": "system", "content": "{{ $json.system_message }}"},
      {"role": "user", "content": "{{ $json.prompt }}"}
    ]
  }`
- Response Format: JSON (add `"response_format": {"type": "json_object"}` to Body if output_format === 'json')
- Max Tokens: {{ max_tokens }}
- Settings: Retry on Fail = true, Max Retries = 3

NODE 4 — Code node "Calculate Usage":
- Calculate latency_ms from start timestamp
- Extract tokens from API response (usage.prompt_tokens, usage.completion_tokens)
- Calculate cost_usd based on model pricing:
  - Free models: $0.00

NODE 5 — Execute Workflow node "Log Usage":
- Call UTIL__WriteAuditLog with:
  - log_type: 'ai_call'
  - action: 'ai_completion' or 'ai_embedding'
  - model: selected model name
  - tokens_input, tokens_output, latency_ms, cost_usd

NODE 6 — Code node "Return Response":
- Return:
  {
    "response": AI_OUTPUT,
    "model_used": "{{ $json.selected_model }}",
    "tokens_input": 150,
    "tokens_output": 300,
    "latency_ms": 1200
  }

ERROR HANDLING:
- If primary model fails after 3 retries → route to failover model (HTTP Request node to OpenRouter with failover model)
- If failover also fails → return error object, do NOT throw (let caller decide)

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```

### Note on OpenRouter Failover

If the first HTTP request to OpenRouter fails, you can use the Error path of the node to trigger a second HTTP request with the `failover` model variable.


✂️ **TO HERE** ✂️

---

## PROMPT 1.5 — Build `UTIL__Deduplicate`

> **Goal:** Create the deduplication sub-workflow that checks for and prevents duplicate event processing.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "UTIL__Deduplicate" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "source": "gmail",                    // 'gmail', 'drive', 'webhook', 'form'
  "dedup_key": "msg_abc123",           // Gmail message_id, Drive file_id, etc.
  "event_type": "email_incoming"       // event type for the events table
}

NODE 1 — Code node "Compute Hash":
- Compute SHA-256 hash of: source + "|" + dedup_key
- Use Node.js crypto: require('crypto').createHash('sha256').update(source + '|' + dedup_key).digest('hex')

NODE 2 — Supabase node "Check Existing":
- Credential: Supabase API
- Operation: Execute Query
- SQL: SELECT id FROM events WHERE dedup_hash = $1
- Parameters: [computed_hash]

NODE 3 — IF node "Is Duplicate?":
- Condition: query returned rows (length > 0)

NODE 4A (duplicate path) — Code node "Return Duplicate":
- Return: { isDuplicate: true, existing_event_id: result[0].id }

NODE 4B (new event path) — Supabase node "Insert Event":
- SQL:
  INSERT INTO events (event_type, source, dedup_hash, status)
  VALUES ($1, $2, $3, 'processing')
  RETURNING id
- Parameters: [event_type, source, computed_hash]

NODE 5B — Code node "Return New":
- Return: { isDuplicate: false, event_id: result[0].id }

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```

---

# PHASE 2 — Email Intelligence (Week 2)


✂️ **TO HERE** ✂️

---

## PROMPT 2.1 — Build `EMAIL__ClassifyIncoming`

> **Goal:** Build the email classification workflow with Gmail trigger, AI classification, deduplication, and Slack routing.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "EMAIL__ClassifyIncoming" with the following:

TRIGGER: Gmail Trigger node
- Credential: Google Business Ops
- Poll Times: Every 5 Minutes
- Labels: INBOX
- Trigger on: New emails only

NODE 1 — Execute Workflow node "Deduplicate":
- Call: UTIL__Deduplicate
- Input: { source: "gmail", dedup_key: "{{ $json.id }}", event_type: "email_incoming" }

NODE 2 — IF node "Skip if Duplicate":
- Condition: $json.isDuplicate === true
- True path → end (stop processing)
- False path → continue

NODE 3 — Code node "Extract Metadata":
- Extract from Gmail message:
  - sender (from field)
  - subject
  - body (text/plain content, strip HTML)
  - receivedDate
  - messageId
  - threadId
  - hasAttachments

NODE 4 — Execute Workflow node "AI Classify":
- Call: UTIL__AICall
- Input:
  {
    "prompt": "Classify the following email.\n\nFrom: {{ sender }}\nSubject: {{ subject }}\nBody: {{ body }}\n\nRespond with JSON: { \"category\": one of [inquiry, support, sales, internal, urgent, spam], \"urgency\": one of [high, medium, low], \"confidence\": 0.0-1.0, \"summary\": brief 1-sentence summary, \"suggested_department\": one of [sales, support, engineering, management, hr] }",
    "system_message": "You are an email classifier for a business operations system. Analyze the email and classify it accurately. Be conservative with urgency — only mark 'high' for time-sensitive matters.",
    "model_preference": "fast",
    "output_format": "json"
  }

NODE 5 — Code node "Parse Classification":
- Parse the AI JSON response
- Extract: category, urgency, confidence, summary, suggested_department

NODE 6 — Supabase node "Update Event":
- SQL:
  UPDATE events SET
    payload = $1,
    status = 'completed',
    processed_at = NOW()
  WHERE id = $2
- Parameters: [JSON with classification results, event_id from dedup step]

NODE 7 — Execute Workflow node "Route Notification":
- Call: UTIL__SendSlackMessage
- Input:
  {
    "channel": map department to channel (#email-routing for all initially),
    "message": "📧 *New Email Classified*\n*From:* {{ sender }}\n*Subject:* {{ subject }}\n*Category:* {{ category }}\n*Urgency:* {{ urgency }} ({{ confidence }})\n*Summary:* {{ summary }}"
  }

NODE 8 — IF node "Low Confidence?":
- Condition: confidence < 0.7
- True path → human review (log and flag)
- False path → continue to draft generation check

NODE 9 — IF node "Should Generate Draft?":
- Condition: category is 'inquiry' OR category is 'support'
- True path → call EMAIL__GenerateDraft
- False path → end

NODE 10 — Execute Workflow node "Generate Draft":
- Call: EMAIL__GenerateDraft
- Input: { email_body, email_subject, sender, classification }

NODE 11 — Execute Workflow node "Audit Log":
- Call: UTIL__WriteAuditLog
- Input: { workflow_name: "EMAIL__ClassifyIncoming", log_type: "action", action: "email_classified", status: "success" }

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
- Activate this workflow when ready
```


✂️ **TO HERE** ✂️

---

## PROMPT 2.2 — Build `EMAIL__GenerateDraft`

> **Goal:** Build the AI email draft generation sub-workflow with safety rails.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "EMAIL__GenerateDraft" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "email_body": "...",
  "email_subject": "Re: Question about...",
  "sender": "customer@example.com",
  "classification": { "category": "inquiry", "urgency": "medium" }
}

NODE 1 — Code node "PII Check":
- Scan email_body for PII patterns:
  - SSN: /\b\d{3}-\d{2}-\d{4}\b/
  - Credit card: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/
  - Phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/
- If PII found, replace with [REDACTED] in the body passed to AI
- Flag hasPII = true

NODE 2 — Execute Workflow node "Generate Reply":
- Call: UTIL__AICall
- Input:
  {
    "prompt": "Generate a professional reply draft for this email.\n\nOriginal Email:\nFrom: {{ sender }}\nSubject: {{ email_subject }}\nBody: {{ sanitized_body }}\n\nClassification: {{ category }}, Urgency: {{ urgency }}\n\nWrite a helpful, professional reply. Keep it concise. Do not include any sensitive personal information.",
    "system_message": "You are a professional email assistant. Write clear, helpful email replies that match the business tone. Always be polite and solution-oriented. Never include information you don't have — if unsure, suggest the person contact the relevant department.",
    "model_preference": "fast",
    "output_format": "text"
  }

NODE 3 — Gmail node "Create Draft":
- Credential: Google Business Ops
- Resource: Draft
- Operation: Create
- Subject: Re: {{ email_subject }}
- To: {{ sender }}
- Body: AI generated reply text
- NOTE: This creates a DRAFT, not a sent email

NODE 4 — Execute Workflow node "Notify Reviewer":
- Call: UTIL__SendSlackMessage
- Input:
  {
    "channel": "#email-routing",
    "message": "📝 *AI Draft Ready for Review*\n*To:* {{ sender }}\n*Subject:* Re: {{ email_subject }}\n*Category:* {{ category }}\n\n*Draft Preview:*\n>>> {{ first 200 chars of draft }}\n\n✅ Review and send from your Gmail Drafts folder"
  }

NODE 5 — Execute Workflow node "Audit Log":
- Call: UTIL__WriteAuditLog
- Input: { workflow_name: "EMAIL__GenerateDraft", log_type: "action", action: "draft_created", status: "success" }

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```

---

# PHASE 3 — Meeting Intelligence (Week 3)


✂️ **TO HERE** ✂️

---

## PROMPT 3.1 — Build `MEET__ProcessTranscript`

> **Goal:** Build the meeting transcript processor triggered by Google Drive file uploads.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### External Setup Required

Ensure the `Meeting-Transcripts` folder exists in Google Drive (from PROMPT 0.8) and you have its folder ID.

### n8n Workflow Prompt

```
Create an n8n workflow named "MEET__ProcessTranscript" with the following:

TRIGGER: Google Drive Trigger node
- Credential: Google Business Ops
- Event: File Created
- Folder: Meeting-Transcripts (use folder ID from PROMPT 0.8)
- Poll Times: Every 5 Minutes

NODE 1 — Execute Workflow node "Deduplicate":
- Call: UTIL__Deduplicate
- Input: { source: "drive", dedup_key: "{{ $json.id }}", event_type: "meeting_transcript" }

NODE 2 — IF node "Skip if Duplicate":
- True (duplicate) → end
- False → continue

NODE 3 — Google Drive node "Download File":
- Credential: Google Business Ops
- Operation: Download
- File ID: {{ $json.id }}

NODE 4 — Code node "Extract Text":
- Detect file type from name/mimeType:
  - .txt → use content directly
  - .docx → extract text (use n8n's built-in binary parsing)
  - .vtt/.srt → strip timestamps using regex:
    text.replace(/\d{2}:\d{2}:\d{2}[.,]\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}[.,]\d{3}/g, '')
        .replace(/^\d+$/gm, '')
        .replace(/\n{3,}/g, '\n\n')
  - Google Doc → already in text format from Drive download
- Output: clean transcript text

NODE 5 — Execute Workflow node "Summarize":
- Call: UTIL__AICall
- Input:
  {
    "prompt": "Summarize this meeting transcript.\n\nTranscript:\n{{ transcript_text }}\n\nProvide a structured JSON response:\n{\n  \"title\": \"Meeting title inferred from content\",\n  \"duration_estimate\": \"estimated duration\",\n  \"key_points\": [\"point 1\", \"point 2\"],\n  \"summary\": \"2-3 paragraph summary\"\n}",
    "system_message": "You are a meeting analyst. Create clear, actionable summaries from meeting transcripts. Focus on decisions, action items, and key discussion points.",
    "model_preference": "large-context",
    "output_format": "json"
  }

NODE 6 — Execute Workflow node "Extract Actions":
- Call: MEET__ExtractActions
- Input: { transcript_text, meeting_metadata: { title, date: NOW(), filename } }

NODE 7 — Google Docs node "Create Summary Doc":
- Credential: Google Business Ops
- Operation: Create
- Title: "Meeting Summary — {{ title }} — {{ date }}"
- Content: Formatted summary with key points, action items, decisions, risks

NODE 8 — Execute Workflow node "Notify Team":
- Call: UTIL__SendSlackMessage
- Input:
  {
    "channel": "#meeting-summaries",
    "message": "📋 *Meeting Summary Ready*\n*Title:* {{ title }}\n*Key Points:* {{ key_points_list }}\n*Action Items:* {{ action_count }} items created\n*Doc:* {{ google_doc_link }}"
  }

NODE 9 — Execute Workflow node "Audit Log":
- Call: UTIL__WriteAuditLog

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 3.2 — Build `MEET__ExtractActions`

> **Goal:** Build the action item extraction sub-workflow.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "MEET__ExtractActions" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "transcript_text": "...",
  "meeting_metadata": { "title": "...", "date": "...", "filename": "..." }
}

NODE 1 — Execute Workflow node "AI Extract":
- Call: UTIL__AICall
- Input:
  {
    "prompt": "Extract action items, decisions, and risks from this meeting transcript.\n\nTranscript:\n{{ transcript_text }}\n\nRespond with JSON:\n{\n  \"action_items\": [\n    { \"description\": \"...\", \"owner\": \"person name or null\", \"deadline\": \"date or null\", \"priority\": \"high/medium/low\" }\n  ],\n  \"decisions\": [\n    { \"decision\": \"...\", \"context\": \"...\" }\n  ],\n  \"risks\": [\n    { \"risk\": \"...\", \"severity\": \"high/medium/low\" }\n  ]\n}",
    "system_message": "You are a meeting analyst. Extract concrete, actionable items with specific owners and deadlines when mentioned. Be precise — only extract real commitments, not vague discussions.",
    "model_preference": "fast",
    "output_format": "json"
  }

NODE 2 — Code node "Parse Results":
- Parse action_items, decisions, risks from AI response

NODE 3 — Loop node "Create Tasks":
- For each action_item:
  - Supabase node: INSERT INTO tasks (title, description, priority, source_event_id, deadline, status)
    VALUES ($1, $2, $3, $4, $5, 'open')

NODE 4 — Code node "Return Results":
- Return: { action_items_count, decisions_count, risks_count, task_ids }

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```

---

# PHASE 4 — Knowledge Base (Week 4)


✂️ **TO HERE** ✂️

---

## PROMPT 4.1 — Build `KB__IngestDocument`

> **Goal:** Build the document ingestion workflow with change detection and incremental processing.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### External Setup Required

Ensure the `Knowledge-Base` folder exists in Google Drive (from PROMPT 0.8) and Qdrant collection is configured (from PROMPT 0.7).

### n8n Workflow Prompt

```
Create an n8n workflow named "KB__IngestDocument" with the following:

TRIGGER: Google Drive Trigger node
- Credential: Google Business Ops
- Event: File Created
- Folder: Knowledge-Base (use folder ID)
- Poll Times: Every 5 Minutes

NODE 1 — Execute Workflow node "Deduplicate":
- Call: UTIL__Deduplicate
- Input: { source: "drive", dedup_key: "{{ $json.id }}", event_type: "document_ingestion" }

NODE 2 — IF "Skip if Duplicate" (true → end)

NODE 3 — Google Drive node "Download File"

NODE 4 — Code node "Extract Text":
- Detect file type and extract text content
- For PDFs: use Extract from File node (n8n built-in)
- For Google Docs: content comes as text from Drive
- For DOCX: use Extract from File node

NODE 5 — Code node "Compute Content Hash":
- const hash = require('crypto').createHash('sha256').update(text).digest('hex');
- Also extract: title from filename, source_type from mimeType

NODE 6 — Supabase node "Check Existing Document":
- SQL: SELECT id, content_hash FROM documents WHERE source_file_id = $1
- Parameters: [drive_file_id]

NODE 7 — IF node "Document Changed?":
- No existing row → new document path
- Existing row, same hash → skip (no changes)
- Existing row, different hash → update path (delete old vectors first)

NODE 8 (update path) — Supabase node "Delete Old Embeddings Metadata":
- SQL: DELETE FROM embeddings_metadata WHERE document_id = $1
- Note: This will automatically delete the vectors from pgvector since they are stored in the same table.

NODE 9 — Supabase node "Upsert Document":
- SQL:
  INSERT INTO documents (title, source_type, source_url, source_file_id, content_hash, status)
  VALUES ($1, $2, $3, $4, $5, 'processing')
  ON CONFLICT (content_hash) DO UPDATE SET
    title = EXCLUDED.title, status = 'processing', updated_at = NOW()
  RETURNING id

NODE 10 — Execute Workflow node "Chunk and Embed":
- Call: KB__ChunkAndEmbed
- Input: { document_id, text_content, collection_name: "knowledge_base" }

NODE 11 — Supabase node "Mark Complete":
- SQL: UPDATE documents SET status = 'completed', chunk_count = $1, processed_at = NOW() WHERE id = $2

NODE 12 — Execute Workflow node "Audit Log"

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 4.2 — Build `KB__ChunkAndEmbed`

> **Goal:** Build the chunking and embedding sub-workflow.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "KB__ChunkAndEmbed" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "document_id": "uuid-here",
  "text_content": "full document text...",
  "collection_name": "knowledge_base"
}

NODE 1 — Code node "Chunk Text":
- Split text into chunks of ~500 tokens (~2000 characters)
- Overlap: 50 tokens (~200 characters)
- Preserve paragraph boundaries where possible
- Algorithm:
  1. Split by paragraphs (\n\n)
  2. Accumulate paragraphs until ~2000 chars
  3. When exceeding limit, save chunk and start new chunk from overlap point
- Output: array of { chunk_index, chunk_text }

NODE 2 — Loop Over Items node "Process Each Chunk":
  For each chunk:

  NODE 2A — Execute Workflow node "Generate Embedding":
  - Call: UTIL__AICall
  - Input: { prompt: chunk_text, model_preference: "embedding" }

  NODE 2B — Supabase node "Insert Embedding":
  - Credential: Supabase API
  - Resource: Database
- Operation: Create
- Table: embeddings_metadata
- Map properties to JSON payload
  - Parameters: [document_id, chunk_index, chunk_text, '[embedding_array_from_step_2A]']

NODE 3 — Code node "Return Count":
- Return: { chunk_count: total_chunks_processed }

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 4.3 — Build `KB__SemanticSearch`

> **Goal:** Build the webhook-based knowledge base query API with RAG.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "KB__SemanticSearch" with the following:

TRIGGER: Webhook node
- HTTP Method: POST
- Path: /api/knowledge/search
- Authentication: None (add bearer token auth in Week 7 hardening)
- Response Mode: "Last Node"

EXPECTED REQUEST BODY:
{
  "query": "What is our refund policy?",
  "top_k": 5
}

NODE 1 — Code node "Validate Input":
- Check query is provided and non-empty
- Default top_k to 5 if not provided

NODE 2 — Execute Workflow node "Embed Query":
- Call: UTIL__AICall
- Input: { prompt: query, model_preference: "embedding" }

NODE 3 — Supabase node "Semantic Search (pgvector)":
- SQL: SELECT * FROM match_documents($1, 0.7, $2, 'knowledge_base')
- Parameters: ['[embedding_array_from_step_2]', top_k]

NODE 4 — Code node "Format Context":
- Extract the top_k results
- Build context string from the returned chunk_text:
  "Source 1 (similarity: 0.92): [chunk_text]\n\nSource 2 (similarity: 0.87): [chunk_text]..."

NODE 5 — Execute Workflow node "Generate Answer":
- Call: UTIL__AICall
- Input:
  {
    "prompt": "Question: {{ query }}\n\nContext from knowledge base:\n{{ context }}\n\nAnswer the question using ONLY the provided context. If the context doesn't contain enough information to answer, say 'I don't have enough information to answer this question.' and suggest who to contact.",
    "system_message": "You are a knowledgeable assistant answering questions based on organizational documents. Only use information from the provided context. Cite your sources.",
    "model_preference": "fast",
    "output_format": "text"
  }

NODE 6 — Code node "Format Response":
- Return:
  {
    "query": original_query,
    "answer": ai_response,
    "sources": [
      { "title": "...", "url": "...", "similarity": 0.92, "excerpt": "..." }
    ],
    "model_used": model_from_ai_call
  }

NODE 7 — Respond to Webhook node:
- Response Code: 200
- Response Body: formatted response from Node 6

NODE 8 — Execute Workflow node "Audit Log"

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```

---

# PHASE 5 — Task Orchestration (Week 5)


✂️ **TO HERE** ✂️

---

## PROMPT 5.1 — Build `TASK__CreateFromEvent`

> **Goal:** Build the reusable task creation sub-workflow.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n sub-workflow named "TASK__CreateFromEvent" with the following:

TRIGGER: "When Executed by Another Workflow" trigger

EXPECTED INPUT:
{
  "title": "Follow up with client on proposal",
  "description": "Client requested changes to Q3 proposal...",
  "assigned_to": "manager@company.com",
  "priority": "high",
  "deadline": "2026-06-01T09:00:00Z",
  "source_event_id": "uuid-of-originating-event"
}

NODE 1 — Supabase node "Resolve User":
- SQL: SELECT id, slack_user_id FROM users WHERE email = $1
- Parameters: [assigned_to]
- If no user found, use NULL for assigned_to UUID

NODE 2 — Supabase node "Insert Task":
- SQL:
  INSERT INTO tasks (title, description, assigned_to, priority, deadline, source_event_id, status)
  VALUES ($1, $2, $3, $4, $5, $6, 'open')
  RETURNING id

NODE 3 — IF node "User Has Slack?":
- Condition: slack_user_id is not null

NODE 4 — Execute Workflow node "Notify Assignee":
- Call: UTIL__SendSlackMessage
- Input:
  {
    "channel": "@{{ slack_user_id }}",
    "message": "📋 *New Task Assigned*\n*Title:* {{ title }}\n*Priority:* {{ priority }}\n*Deadline:* {{ deadline }}\n*Description:* {{ description }}"
  }

NODE 5 — Execute Workflow node "Audit Log"

SETTINGS:
- "This workflow can be called by" → "Any workflow"
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 5.2 — Build `TASK__SendReminders`

> **Goal:** Build the daily task reminder cron workflow.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "TASK__SendReminders" with the following:

TRIGGER: Cron node
- Expression: 0 9 * * * (every day at 9:00 AM)

NODE 1 — Supabase node "Query Upcoming Tasks":
- SQL:
  SELECT t.*, u.name, u.email, u.slack_user_id
  FROM tasks t
  LEFT JOIN users u ON t.assigned_to = u.id
  WHERE t.status = 'open'
  AND t.deadline IS NOT NULL
  AND t.deadline BETWEEN NOW() AND NOW() + INTERVAL '48 hours'
  ORDER BY t.deadline ASC

NODE 2 — Supabase node "Query Overdue Tasks":
- SQL:
  SELECT t.*, u.name, u.email, u.slack_user_id
  FROM tasks t
  LEFT JOIN users u ON t.assigned_to = u.id
  WHERE t.status = 'open'
  AND t.deadline IS NOT NULL
  AND t.deadline < NOW()
  ORDER BY t.deadline ASC

NODE 3 — Code node "Group by Assignee":
- Combine upcoming + overdue tasks
- Group by assignee's slack_user_id
- For each assignee, build a message listing their tasks

NODE 4 — Loop node "Send Reminders":
  For each assignee group:

  NODE 4A — Execute Workflow node "Send Reminder":
  - Call: UTIL__SendSlackMessage
  - Input:
    {
      "channel": "@{{ slack_user_id }}",
      "message": "⏰ *Daily Task Reminder*\n\n*Overdue ({{ overdue_count }}):*\n{{ overdue_list }}\n\n*Upcoming ({{ upcoming_count }}):*\n{{ upcoming_list }}"
    }

NODE 5 — Execute Workflow node "Audit Log"

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 5.3 — Build `TASK__Escalate`

> **Goal:** Build the hourly task escalation cron workflow.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "TASK__Escalate" with the following:

TRIGGER: Cron node
- Expression: 0 * * * * (every hour)

NODE 1 — Supabase node "Query Overdue Unescalated":
- SQL:
  SELECT t.*, u.name as assignee_name, u.email as assignee_email,
         m.slack_user_id as manager_slack_id, m.name as manager_name
  FROM tasks t
  LEFT JOIN users u ON t.assigned_to = u.id
  LEFT JOIN users m ON u.manager_id = m.id
  WHERE t.status = 'open'
  AND t.deadline < NOW() - INTERVAL '24 hours'
  AND t.escalated_at IS NULL

NODE 2 — IF node "Any Tasks to Escalate?":
- Condition: query returned rows

NODE 3 — Loop node "Escalate Each":
  For each task:

  NODE 3A — Supabase node "Mark Escalated":
  - SQL:
    UPDATE tasks SET escalated_at = NOW(), priority = 'critical', updated_at = NOW()
    WHERE id = $1

  NODE 3B — Execute Workflow node "Notify Manager":
  - Call: UTIL__SendSlackMessage (if manager_slack_id exists)
  - Input:
    {
      "channel": "@{{ manager_slack_id }}",
      "message": "🚨 *Task Escalation*\n*Task:* {{ title }}\n*Assigned to:* {{ assignee_name }}\n*Deadline:* {{ deadline }} (overdue by {{ hours_overdue }} hours)\n*Priority:* Upgraded to CRITICAL"
    }

  NODE 3C — Execute Workflow node "Alert Ops Channel":
  - Call: UTIL__SendSlackMessage
  - Input: { channel: "#ops-alerts", message: escalation summary }

NODE 4 — Execute Workflow node "Audit Log"

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```

---

# PHASE 6 — Reporting (Week 6)


✂️ **TO HERE** ✂️

---

## PROMPT 6.1 — Build `REPORT__DailySummary`

> **Goal:** Build the daily executive summary report.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "REPORT__DailySummary" with the following:

TRIGGER: Cron node
- Expression: 0 8 * * * (every day at 8:00 AM)

NODE 1 — Supabase node "Emails Processed":
- SQL: SELECT COUNT(*) as count FROM events WHERE event_type = 'email_incoming' AND created_at > NOW() - INTERVAL '24 hours'

NODE 2 — Supabase node "Tasks Metrics":
- SQL:
  SELECT
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as created,
    COUNT(*) FILTER (WHERE completed_at > NOW() - INTERVAL '24 hours') as completed,
    COUNT(*) FILTER (WHERE status = 'open' AND deadline < NOW()) as overdue
  FROM tasks

NODE 3 — Supabase node "AI Usage":
- SQL:
  SELECT
    COUNT(*) as total_calls,
    SUM(tokens_input) as total_input_tokens,
    SUM(tokens_output) as total_output_tokens,
    SUM(cost_usd) as total_cost,
    AVG(latency_ms) as avg_latency
  FROM workflow_logs
  WHERE log_type = 'ai_call' AND created_at > NOW() - INTERVAL '24 hours'

NODE 4 — Supabase node "Errors Count":
- SQL: SELECT COUNT(*) as count FROM workflow_logs WHERE log_type = 'error' AND created_at > NOW() - INTERVAL '24 hours'

NODE 5 — Supabase node "Approvals Status":
- SQL:
  SELECT
    COUNT(*) FILTER (WHERE status = 'pending') as pending,
    COUNT(*) FILTER (WHERE approved_at > NOW() - INTERVAL '24 hours') as approved
  FROM approvals

NODE 6 — Code node "Build Metrics Object":
- Combine all query results into a structured JSON metrics object

NODE 7 — Execute Workflow node "Generate AI Summary":
- Call: UTIL__AICall
- Input:
  {
    "prompt": "Generate an executive operations summary based on these daily metrics:\n{{ JSON.stringify(metrics) }}\n\nInclude:\n1. Highlights (what went well)\n2. Issues (errors, overdue tasks)\n3. AI usage efficiency\n4. Recommendations for tomorrow",
    "system_message": "You are a business operations analyst. Write concise, actionable executive summaries. Use bullet points. Highlight anything requiring immediate attention.",
    "model_preference": "fast",
    "output_format": "text"
  }

NODE 8 — Google Docs node "Create Report":
- Credential: Google Business Ops
- Operation: Create
- Title: "Daily Operations Report — {{ date }}"
- Content: Metrics tables + AI summary + recommendations

NODE 9 — Execute Workflow node "Notify Executives":
- Call: UTIL__SendSlackMessage
- Input: { channel: "#executive-updates", message: summary + doc link }

NODE 10 — Execute Workflow node "Audit Log"

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```


✂️ **TO HERE** ✂️

---

## PROMPT 6.2 — Build `REPORT__WeeklyDigest`

> **Goal:** Build the Monday morning weekly digest.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### n8n Workflow Prompt

```
Create an n8n workflow named "REPORT__WeeklyDigest" with the following:

TRIGGER: Cron node
- Expression: 0 9 * * 1 (Monday at 9:00 AM)

NODE 1–5: Same metric queries as REPORT__DailySummary but with INTERVAL '7 days'

NODE 6 — Supabase node "Last Week Comparison":
- Query the same metrics for the PREVIOUS week (8-14 days ago)
- This enables trend analysis (this week vs. last week)

NODE 7 — Code node "Calculate Trends":
- Compare this week vs. last week:
  - emails_change_pct
  - tasks_completion_rate_change
  - error_rate_change
  - ai_cost_change

NODE 8 — Execute Workflow node "Generate AI Digest":
- Call: UTIL__AICall
- Input: prompt with metrics + trends, asking for strategic weekly recommendations

NODE 9 — Google Docs node "Create Weekly Digest"

NODE 10 — Execute Workflow node "Notify Executives"

NODE 11 — Execute Workflow node "Audit Log"

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```

---

# PHASE 7 — Hardening & Backup (Week 7)


✂️ **TO HERE** ✂️

---

## PROMPT 7.1 — Build `UTIL__BackupWorkflows`

> **Goal:** Build the automated daily workflow backup to GitHub.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### External Setup Required

1. **Create a private GitHub repository:**
   - Go to https://github.com/new
   - Name: `n8n-workflow-backups`
   - Visibility: **Private** (workflow exports may contain credential references)
   - Initialize with a README

2. **Create a Personal Access Token:**
   - Go to https://github.com/settings/tokens → "Generate new token (classic)"
   - Scopes: `repo` (full access to private repositories)
   - Copy the token

3. **Configure in n8n:**
   - Credentials → Add Credential → "GitHub API"
   - Access Token: your personal access token
   - Save as `GitHub Backups`

### n8n Workflow Prompt

```
Create an n8n workflow named "UTIL__BackupWorkflows" with the following:

TRIGGER: Cron node
- Expression: 0 2 * * * (daily at 2:00 AM)

NODE 1 — HTTP Request node "List All Workflows":
- Method: GET
- URL: https://edwin-bayog.app.n8n.cloud/api/v1/workflows
  (Self-hosted: http://localhost:5678/api/v1/workflows)
- Authentication: Header Auth → X-N8N-API-KEY: your-api-key
- Note: You need to create an API key in n8n Settings → API

NODE 2 — Loop node "Process Each Workflow":
  For each workflow:

  NODE 2A — HTTP Request node "Get Full Workflow":
  - Method: GET
  - URL: https://edwin-bayog.app.n8n.cloud/api/v1/workflows/{{ workflow_id }}
    (Self-hosted: http://localhost:5678/api/v1/workflows/{{ workflow_id }})

  NODE 2B — Code node "Format for Git":
  - Convert workflow JSON to pretty-printed string
  - Generate filename: "workflows/{{ workflow_name }}.json"

  NODE 2C — GitHub node "Create or Update File":
  - Credential: GitHub Backups
  - Operation: Create or Update
  - Repository: your-username/n8n-workflow-backups
  - Path: workflows/{{ workflow_name }}.json
  - Content: pretty-printed workflow JSON
  - Commit Message: "Backup: {{ workflow_name }} — {{ date }}"

NODE 3 — Execute Workflow node "Audit Log"
- Log backup summary: workflows backed up count, any failures

SETTINGS:
- Error Workflow → ERROR__GlobalHandler
```

### n8n API Setup

1. In n8n Cloud at `https://edwin-bayog.app.n8n.cloud/`, go to **Settings** → **API**
2. Create an API key
3. Use this key in the HTTP Request node's authentication header:
   `X-N8N-API-KEY: your-api-key`

> **Note:** n8n Cloud API is available on paid plans. Check your plan includes API access. If not, you can manually export workflows from Settings → Workflows → Export All as a fallback.


✂️ **TO HERE** ✂️

---

## PROMPT 7.2 — Security Hardening Checklist

> **Goal:** Review and secure all workflows for production readiness.

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


### Checklist (manual steps, not a workflow)

```
SECURITY HARDENING — Apply to all existing workflows:

1. WEBHOOK AUTHENTICATION:
   - Open KB__SemanticSearch (webhook workflow)
   - Add Header Authentication: Authorization: Bearer YOUR_SECRET_TOKEN
   - Test that unauthenticated requests are rejected

2. GOOGLE OAUTH PRODUCTION MODE:
   - Go to Google Cloud Console → OAuth consent screen
   - Verify the app is in "Production" mode (not "Testing")
   - If still in Testing, publish the app to Production
   - This prevents 7-day token expiration

3. API KEY ROTATION:
   - Create new OpenAI API key → update n8n credential → deactivate old key
   - Create new Gemini API key → update n8n credential → deactivate old key
   - Create new Slack bot token → update n8n credential → deactivate old key

4. ERROR WORKFLOW VERIFICATION:
   - Open EVERY workflow → Settings → verify Error Workflow = ERROR__GlobalHandler
   - List of workflows to check:
     [ ] EMAIL__ClassifyIncoming
     [ ] EMAIL__GenerateDraft
     [ ] MEET__ProcessTranscript
     [ ] MEET__ExtractActions
     [ ] KB__IngestDocument
     [ ] KB__ChunkAndEmbed
     [ ] KB__SemanticSearch
     [ ] TASK__CreateFromEvent
     [ ] TASK__SendReminders
     [ ] TASK__Escalate
     [ ] REPORT__DailySummary
     [ ] REPORT__WeeklyDigest
     [ ] UTIL__BackupWorkflows

5. EXECUTION DATA RETENTION:
   - **n8n Cloud:** Go to Settings → Execution Data in the n8n Cloud UI.
     Set retention policies there (n8n Cloud manages this via the UI, not env vars).
   - **Self-hosted only — Add to .env:**
     EXECUTIONS_DATA_SAVE_ON_ERROR=all
     EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
     EXECUTIONS_DATA_PRUNE=true
     EXECUTIONS_DATA_MAX_AGE=720
   - Restart n8n containers (self-hosted only)
```

---

# PHASE 8 — Documentation & Demo (Week 8)

> This phase is manual work — no n8n workflows to build.


✂️ **TO HERE** ✂️

---

## PROMPT 8.1 — Final Verification

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


```
FINAL VERIFICATION CHECKLIST:

Infrastructure:
[ ] n8n Cloud accessible at https://edwin-bayog.app.n8n.cloud/
[ ] PostgreSQL has all 7 tables (local Docker, Supabase, or Neon)
[ ] n8n Cloud can connect to PostgreSQL (test with a Supabase node)

(Self-hosted only:)
[ ] All 5 Docker containers healthy (docker compose ps)
[ ] Redis is running and accessible

Utility Workflows (test each):
[ ] ERROR__GlobalHandler — trigger intentional failure → Slack alert received
[ ] UTIL__WriteAuditLog — log entry appears in workflow_logs
[ ] UTIL__SendSlackMessage — message appears in Slack
[ ] UTIL__AICall — returns valid AI response with usage logging
[ ] UTIL__Deduplicate — duplicate returns isDuplicate:true, new returns isDuplicate:false

Email Workflows:
[ ] EMAIL__ClassifyIncoming — send test email → classification appears in events + Slack
[ ] EMAIL__GenerateDraft — draft appears in Gmail Drafts folder + Slack notification

Meeting Workflows:
[ ] MEET__ProcessTranscript — upload .txt to Meeting-Transcripts/ → summary in Google Docs
[ ] MEET__ExtractActions — action items created in tasks table

Knowledge Base:
[ ] KB__IngestDocument — upload doc to Knowledge-Base/ → vectors in Supabase pgvector
[ ] KB__ChunkAndEmbed — embeddings_metadata populated
[ ] KB__SemanticSearch — POST to webhook → returns relevant answer with sources

Task Orchestration:
[ ] TASK__CreateFromEvent — task created + Slack notification sent
[ ] TASK__SendReminders — reminder message sent for upcoming/overdue tasks
[ ] TASK__Escalate — overdue tasks escalated + manager notified

Reporting:
[ ] REPORT__DailySummary — report created in Google Docs + Slack notification
[ ] REPORT__WeeklyDigest — weekly digest created

Backup:
[ ] UTIL__BackupWorkflows — all workflows exported to GitHub
```


✂️ **TO HERE** ✂️

---

## PROMPT 8.2 — README Structure

✂️ **COPY FROM HERE** ✂️

**System Context:** Before generating code or steps, please review the following files to understand the system architecture, logic, and schemas: PROJECT.md, ARCHITECTURE.md, WORKFLOWS.md, DATABASE.md, DEPLOYMENT.md, STACK.md, SCHEDULE.md.


```
Create a comprehensive README.md for the project with:

1. Project Title & Description
2. Architecture Diagram (paste from ARCHITECTURE.md)
3. Features List (with status: ✅ Implemented)
4. Tech Stack Table
5. Prerequisites
6. Quick Start (docker compose up -d + setup steps)
7. Workflow Inventory (table with all 19 workflows, their triggers, and descriptions)
8. Database Schema Overview
9. API Endpoints (KB__SemanticSearch webhook)
10. Configuration (.env variables reference)
11. Backup & Recovery
12. Security Considerations
13. Future Roadmap
```


✂️ **TO HERE** ✂️

---

> **Total Workflows: 19** | **Total Prompts: 22** (including setup) | **Estimated Build Time: 8 weeks**

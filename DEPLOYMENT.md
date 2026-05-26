# FILE: DEPLOYMENT.md

```markdown
# Deployment Guide

# Current Deployment: Cloud-Native Stack

## Active Setup

| Component | Where It Runs | URL / Access |
|-----------|--------------|--------------|
| **n8n** | ☁️ n8n Cloud | `https://edwin-bayog.app.n8n.cloud/` |
| **PostgreSQL & Vector Store**| ☁️ Supabase | Project Dashboard |

> **Note:** n8n Cloud manages its own execution engine, queue mode, workers, and webhook routing. Supabase provides a unified managed database containing both relational data and vector embeddings (via pgvector).

---

# Supabase Project Setup

1. Log in to [Supabase](https://supabase.com/).
2. Create a new project.
3. Once the database is provisioned, go to **Project Settings -> Database** to find your connection string and connection pooler settings.
4. Go to **Project Settings -> API** to retrieve your `service_role` secret (for API-level access if needed).

---

# Suggested Directory Structure

```text
project-root/
├── .env
├── .env.example
├── workflows/
│   ├── 01_utilities/
│   ├── 02_error_handling/
│   ├── 03_email/
│   ├── 04_meetings/
│   ├── 05_knowledge/
│   ├── 06_tasks/
│   └── 07_reporting/
├── database/
│   ├── init.sql
│   └── migrations/
├── docs/
└── backups/
    └── workflows/
```

---

# Environment Variables

Keep these locally in a `.env` file to track credentials. Configure them directly as Credentials inside your n8n Cloud instance.

## Required — Core n8n

```env
# n8n Cloud Instance
N8N_CLOUD_URL=https://edwin-bayog.app.n8n.cloud
```

## Required — Database (Supabase)

```env
# Supabase (PostgreSQL + pgvector)
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_KEY=your-supabase-service-role-key
SUPABASE_DB_PASSWORD=your-database-password
```

## Required — AI Providers

```env
# OpenRouter
OPENROUTER_API_KEY=sk-or-v1-your-openrouter-key
OPENROUTER_DEFAULT_MODEL=meta-llama/llama-3.3-70b-instruct:free
OPENROUTER_LARGE_CONTEXT_MODEL=google/gemini-2.5-pro:free

# Hugging Face (Embeddings)
HUGGINGFACE_API_KEY=hf_your-huggingface-key
HUGGINGFACE_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
```

## Required — Google Workspace

```env
# Google OAuth
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
```

> **Note:** Ensure your Google Cloud OAuth project is set to **"Production"** mode. Testing-mode tokens expire every 7 days, which will cause background triggers (Gmail, Drive) to fail unexpectedly.

## Optional — Slack

```env
# Slack
SLACK_BOT_TOKEN=xoxb-your-bot-token
```

---

# Backup Strategy

## Workflow Backups

n8n workflows are stored in the database, not as files. If the n8n Cloud instance goes down without backups, everything is lost.

### n8n Workflow-Based Backup (UTIL__BackupWorkflows)

A self-service backup workflow that runs daily at 2am:
1. Uses n8n API to fetch all workflow definitions
2. Compares hash against last backup to detect changes
3. Pushes changed workflows to a **private** GitHub repository

> **Warning:** Exported workflow JSON files contain credential references. Always use a **private** Git repository.

## Database Backups

Supabase automatically manages daily backups on their Pro tier. For the Free tier, use the Supabase CLI or `pg_dump` locally pointing to the Supabase connection string.

```bash
# Example manual PostgreSQL backup from Supabase
pg_dump "postgres://postgres.[YOUR-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres" > ./backups/db/operations_$(date +'%Y-%m-%d').sql
```

---

# Monitoring Suggestions

| What | How | Alert Threshold |
|------|-----|----------------|
| Workflow failures | ERROR__GlobalHandler → Slack | Any failure |
| API rate limits | workflow_logs analysis | >80% of daily budget |
| Database health | Supabase Dashboard | Resource limits reached |
| n8n execution data | Prune old executions | Retention policy (30 days success, 90 days errors) |

---

# Security Recommendations

- Rotate API keys on a regular schedule (quarterly minimum)
- Restrict n8n admin access to authorized operators only
- Use OAuth with production-mode tokens (testing mode expires every 7 days)
- Enable Point-in-Time Recovery (PITR) on Supabase for enterprise workloads
- Keep Git backup repositories **private** (workflow exports contain credential references)
- Set n8n execution data retention policies (prune old successful executions)
```
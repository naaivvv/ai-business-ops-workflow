# FILE: DEPLOYMENT.md

```markdown
# Deployment Guide

# Current Deployment: n8n Cloud + Supporting Services

## Active Setup

| Component | Where It Runs | URL / Access |
|-----------|--------------|--------------|
| **n8n** | ☁️ n8n Cloud | `https://edwin-bayog.app.n8n.cloud/` |
| **PostgreSQL** | Cloud DB (Supabase/Neon) or 🐳 Local Docker + tunnel | Port `5432` |
| **Qdrant** | Qdrant Cloud or 🐳 Local Docker + tunnel | Port `6333` |
| **Redis** | ❌ Not needed | n8n Cloud handles queue mode internally |

> **Note:** n8n Cloud manages its own execution engine, queue mode, workers, and webhook routing. You only need external PostgreSQL and Qdrant for your application data.

### Cloud Networking

n8n Cloud cannot reach `localhost`. To connect to your databases, either:
- **Use cloud-hosted databases** (Supabase, Neon, Qdrant Cloud) — recommended
- **Expose local services via tunnel** (ngrok, Cloudflare Tunnel, Tailscale)

---

# Self-Hosted Reference (Full Stack)

The configuration below is for a fully self-hosted deployment. Keep this as reference for future migration.

## Services (Self-Hosted)

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| n8n (main) | n8nio/n8n:latest | 5678 | UI, triggers, webhook receiver |
| n8n (worker) | n8nio/n8n:latest | — | Workflow execution (queue mode) |
| PostgreSQL | postgres:16-alpine | 5432 | Persistent storage |
| Redis | redis:7-alpine | 6379 | Queue broker, caching, rate limit counters |
| Qdrant | qdrant/qdrant:latest | 6333 | Vector database for knowledge base |

---

# Suggested Directory Structure

```text
project-root/
├── docker-compose.yml
├── docker-compose.prod.yml
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
├── scripts/
│   ├── backup.sh
│   └── restore.sh
└── backups/
    └── workflows/
```

---

# Environment Variables

## Required — Core n8n

```env
# n8n Configuration
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_ENCRYPTION_KEY=generate-a-secure-random-key-here
GENERIC_TIMEZONE=Asia/Manila
```

> **CRITICAL:** The `N8N_ENCRYPTION_KEY` must be identical across all n8n processes (main + workers). If they differ, workers cannot decrypt credentials and all workflow executions will fail silently. Generate a strong random key and never change it after initial setup.

## Required — Database

```env
# PostgreSQL
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=operations
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_PASSWORD=your_secure_password
```

## Required — Queue Mode (Redis)

```env
# Queue Mode
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=your_redis_password
```

## Required — Vector Database (Qdrant)

```env
# Qdrant
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_API_KEY=your_qdrant_api_key
QDRANT_COLLECTION_NAME=knowledge_base
QDRANT_VECTOR_DIMENSIONS=1536
```

## Required — AI Providers

```env
# OpenAI
OPENAI_API_KEY=your_openai_key
OPENAI_DEFAULT_MODEL=gpt-4o
OPENAI_EMBEDDING_MODEL=text-embedding-3-small

# Google Gemini (failover provider)
GOOGLE_GEMINI_API_KEY=your_gemini_key
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
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

---

# Docker Compose — Development

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_POSTGRESDB_DATABASE}
      POSTGRES_USER: ${DB_POSTGRESDB_USER}
      POSTGRES_PASSWORD: ${DB_POSTGRESDB_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  qdrant:
    image: qdrant/qdrant:latest
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - qdrant_data:/qdrant/storage

  n8n-main:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - EXECUTIONS_MODE=queue
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}
      - DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres
      - redis
      - qdrant
    command: n8n start

  n8n-worker:
    image: n8nio/n8n:latest
    restart: unless-stopped
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - EXECUTIONS_MODE=queue
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}
      - DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
    depends_on:
      - n8n-main
    command: n8n worker

volumes:
  postgres_data:
  redis_data:
  qdrant_data:
  n8n_data:
```

---

# Queue Mode Architecture

Queue mode separates the n8n main process (UI + triggers) from worker processes (execution). This is required for production scalability.

```text
┌──────────────┐     ┌─────────┐     ┌──────────────┐
│  n8n-main    │────▶│  Redis  │◀────│  n8n-worker  │
│ (UI/Triggers)│     │ (Queue) │     │ (Execution)  │
└──────────────┘     └─────────┘     └──────────────┘
       │                                     │
       └──────────┐             ┌────────────┘
                  ▼             ▼
             ┌──────────────────────┐
             │     PostgreSQL       │
             │  (Shared Database)   │
             └──────────────────────┘
```

### Requirements

- All n8n processes must run the **same version** of n8n
- All processes must share the **same N8N_ENCRYPTION_KEY**
- PostgreSQL is required (SQLite is incompatible with queue mode)
- Minimum 4 vCPU / 8GB RAM for production

---

# Backup Strategy

## Workflow Backups

n8n workflows are stored in the database, not as files. If PostgreSQL goes down without backups, everything is lost.

### Automated CLI Backup (cron)

```bash
#!/bin/bash
# scripts/backup.sh — Run daily via cron: 0 2 * * * /path/to/backup.sh

BACKUP_DIR="./backups/workflows"
DATE=$(date +'%Y-%m-%d')

# Export all workflows to individual JSON files
docker exec n8n-main n8n export:workflow --all --separate --output="/tmp/workflow-backup/"

# Copy from container to host
docker cp n8n-main:/tmp/workflow-backup/ $BACKUP_DIR/

# Git commit and push
cd $BACKUP_DIR
git add .
git commit -m "Automated workflow backup: $DATE"
git push origin main
```

### n8n Workflow-Based Backup (UTIL__BackupWorkflows)

A self-service backup workflow that runs daily at 2am:
1. Uses n8n API to fetch all workflow definitions
2. Compares hash against last backup to detect changes
3. Pushes changed workflows to a **private** GitHub repository

> **Warning:** Exported workflow JSON files contain credential references. Always use a **private** Git repository.

## Database Backups

```bash
# Daily PostgreSQL backup
docker exec postgres pg_dump -U postgres operations > ./backups/db/operations_$(date +'%Y-%m-%d').sql
```

---

# Production Recommendations

## Infrastructure

- VPS or cloud deployment (minimum 4 vCPU / 8GB RAM)
- Reverse proxy (Nginx or Caddy)
- HTTPS (Let's Encrypt via Certbot or Caddy automatic TLS)
- Automated backup strategy (workflows + database)
- Monitoring and alerting

---

# Recommended Production Stack

- Docker + Docker Compose
- Nginx (reverse proxy with SSL termination)
- PostgreSQL 16 (persistent storage)
- Redis 7 (queue broker)
- Qdrant (vector database)
- n8n queue mode (main + worker separation)

---

# Monitoring Suggestions

| What | How | Alert Threshold |
|------|-----|----------------|
| Workflow failures | ERROR__GlobalHandler → Slack | Any failure |
| CPU/Memory usage | Docker stats or Prometheus | >80% sustained |
| Redis queue depth | Redis CLI `LLEN` or monitoring | >100 pending jobs |
| API rate limits | workflow_logs analysis | >80% of daily budget |
| Database health | pg_isready + connection count | Connection pool exhaustion |
| Qdrant health | Qdrant health endpoint | Unavailable |
| Disk space | Host monitoring | <20% free |
| n8n execution data | Prune old executions | Retention policy (30 days success, 90 days errors) |

---

# Security Recommendations

- Rotate API keys on a regular schedule (quarterly minimum)
- Restrict n8n admin access to authorized operators only
- Use OAuth with production-mode tokens (testing mode expires every 7 days)
- Enable HTTPS for all external-facing endpoints
- Store secrets via Docker secrets or environment variables (never in workflow JSON)
- Audit all workflow executions via workflow_logs table
- Secure webhook endpoints with HMAC signatures or bearer tokens
- Keep Git backup repositories **private** (workflow exports contain credential references)
- Set n8n execution data retention policies (prune old successful executions)

---

# Execution Data Retention

Configure n8n to manage execution data storage:

```env
# Keep failed executions longer for debugging
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all

# Prune old execution data
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=720  # hours (30 days for success)
```

For high-volume instances, keep failed executions longer (90 days) while pruning successful ones at 30 days.
```

---
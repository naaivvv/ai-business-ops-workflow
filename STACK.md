# FILE: STACK.md

```markdown
# Technology Stack

# Core Automation

## n8n

Purpose:

- Workflow orchestration (modular entry-point + sub-workflow architecture)
- Event automation (per-source triggers, not centralized routing)
- API integrations (Google Workspace, Slack, OpenAI, Gemini)
- AI workflows (native AI Agent nodes powered by LangChain)

### n8n AI Agent Nodes

n8n includes native AI Agent nodes (powered by LangChain) for complex AI orchestration. Use these instead of building custom chains of HTTP Request nodes to AI providers.

Capabilities:

- Tool calling (expose sub-workflows as tools via Workflow Tool or MCP nodes)
- Memory management (Window Buffer Memory for conversations, Vector Store for RAG)
- Structured JSON output enforcement
- Multi-model support (OpenAI, Anthropic, Google, local models)
- Execution logs showing the agent's reasoning chain

Use AI Agent nodes for:

- Complex multi-step reasoning tasks
- Scenarios where the AI needs to select and call different tools
- Conversational interfaces (chat-based knowledge queries)

Use UTIL__AICall sub-workflow for:

- Simple single-step AI calls (classification, summarization, embedding)
- Tasks requiring rate limiting and provider failover
- Cost tracking and budget enforcement

---

# Database Layer

## PostgreSQL

Purpose:

- Persistent storage (events, tasks, approvals, documents)
- Workflow state management
- Unified audit/AI/error logging (workflow_logs table)
- Task management with full traceability
- Embeddings metadata tracking

---

# Queue & Cache

## Redis

Purpose:

- Queue mode (separate n8n main process from worker execution)
- Caching (reduce redundant API calls)
- Rate limiting (daily token budget counters for AI providers)
- Distributed workers (horizontal scaling)

---

# Vector Database

## Qdrant

Purpose:

- Semantic search (similarity-based document retrieval)
- Embeddings storage (1536-dimension vectors for text-embedding-3-small)
- RAG pipelines (context injection for AI-generated responses)

### Collection Configuration

| Setting | Value | Reason |
|---------|-------|--------|
| Collection name | `knowledge_base` | Default for organizational documents |
| Vector dimensions | 1536 | Matches OpenAI text-embedding-3-small |
| Distance metric | Cosine | Standard for text similarity |

> **Warning:** Vector dimensions must match your embedding model. Changing models later requires re-embedding your entire knowledge base and recreating the Qdrant collection.

---

# AI Providers

## OpenAI

Used for:

- Classification (email routing, urgency detection) — GPT-4o
- Summarization (meeting transcripts, daily reports) — GPT-4o
- Response/draft generation (email replies) — GPT-4o
- Embeddings (document vectorization) — text-embedding-3-small

### Embedding Model Selection

| Model | Dimensions | Cost | Best For |
|-------|-----------|------|----------|
| text-embedding-3-small | 1536 | $0.02/1M tokens | General purpose, cost-effective ✅ Selected |
| text-embedding-3-large | 3072 | $0.13/1M tokens | Higher accuracy, 6.5x more expensive |
| text-embedding-004 (Gemini) | 768 | Free tier available | Budget-friendly alternative |

**Selected: `text-embedding-3-small`** — best balance of cost, accuracy, and ecosystem support for organizational document search.

---

## Google Gemini

Used for:

- Multimodal AI (image and document analysis)
- Large context processing (long meeting transcripts, multi-page documents)
- Failover provider (when OpenAI is unavailable or rate-limited)

### Provider Failover Strategy

All AI calls go through the `UTIL__AICall` sub-workflow, which implements automatic failover:

```text
Primary: OpenAI GPT-4o
    ↓ (on failure: timeout, rate limit, 5xx)
Failover: Google Gemini
    ↓ (on failure)
Error: Log to workflow_logs, alert via Slack
```

---

# Infrastructure

## Docker

Purpose:

- Containerization (consistent environments across dev/staging/prod)
- Environment consistency (all services defined in docker-compose.yml)
- Simplified deployment (single `docker compose up` command)

---

## Docker Compose

Purpose:

- Multi-service orchestration (n8n-main, n8n-worker, PostgreSQL, Redis, Qdrant)
- Local development (full stack runs locally)
- Infrastructure management (volumes, networking, health checks)

### Services Overview

```text
┌─────────────────────────────────────────────┐
│              Docker Compose                  │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐ │
│  │ n8n-main │  │n8n-worker│  │ PostgreSQL│ │
│  │ :5678    │  │          │  │ :5432     │ │
│  └──────────┘  └──────────┘  └───────────┘ │
│                                              │
│  ┌──────────┐  ┌──────────┐                 │
│  │  Redis   │  │  Qdrant  │                 │
│  │  :6379   │  │  :6333   │                 │
│  └──────────┘  └──────────┘                 │
└─────────────────────────────────────────────┘
```

---

# Integrations

## Google Workspace

- Gmail (email trigger — 5-minute polling or Pub/Sub push)
- Drive (file upload trigger for transcripts and knowledge base documents)
- Docs (meeting summary and report output)
- Calendar (deadline integration for tasks)
- Meet (transcripts via Drive folder — no native n8n Meet node)
- Sheets (optional: data export and simple dashboards)

> **Note:** Google Meet does not have a native n8n node. Transcripts are processed via Google Drive trigger when files are uploaded to a designated `Meeting-Transcripts/` folder.

---

## Communication Platforms

- Slack (primary: notifications, approvals, alerts via UTIL__SendSlackMessage)
- Discord (optional: alternative notification channel)
- Microsoft Teams (optional: alternative notification channel)

---

## Optional Future Integrations

- Jira (task management synchronization)
- Notion (knowledge base alternative/supplement)
- ClickUp (project management integration)
- HubSpot (CRM data enrichment for email classification)
- Salesforce (enterprise CRM integration)
- Google Pub/Sub (near-real-time Gmail push notifications, replacing polling)
```

---
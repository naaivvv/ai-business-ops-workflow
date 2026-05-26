# AI Business Operations Workspace Documentation Pack

---

# FILE: PROJECT.md

```markdown
# AI Business Operations Workspace

## Overview

The AI Business Operations Workspace is a modular AI-powered operational automation system built using:

- n8n (with native AI Agent nodes powered by LangChain)
- Google Workspace
- Supabase (PostgreSQL + pgvector)
- OpenRouter / Hugging Face APIs

The system acts as an AI operational layer that automates:

- Email management (classification, urgency detection, AI draft generation)
- Meeting intelligence (transcript processing, action item extraction)
- Knowledge management (semantic search, RAG retrieval)
- Task orchestration (creation, reminders, escalation)
- Reporting (daily/weekly summaries, AI-generated insights)
- Approval workflows (human-in-the-loop with webhook-based review)
- Notifications (Slack, email, with centralized delivery)
- AI-assisted decision support (confidence-gated, with failover)

---

# Core Objectives

## Business Goals

- Reduce repetitive operational work
- Improve organizational coordination
- Centralize business intelligence
- Create reusable workflow automation systems
- Enable AI-powered business assistance

---

# Technical Goals

- Build modular workflow architecture with shared utility sub-workflows
- Implement event-driven systems with per-source entry-point triggers
- Create AI orchestration pipelines with rate limiting and provider failover
- Integrate multiple SaaS platforms with proper OAuth and retry handling
- Develop scalable automation infrastructure with queue mode and workers
- Implement error handling, logging, and deduplication from Day 1

---

# Core Features

## 1. Smart Email Intake System

Automatically:

- Classifies incoming emails (via AI classification sub-workflow)
- Detects urgency (high/medium/low with confidence scoring)
- Routes to departments (based on classification output)
- Generates AI draft replies (never auto-sends — always drafts first)
- Stores operational logs (unified workflow_logs table)
- Deduplicates incoming messages (checks message_id against events table)

### Email Safety Rails

- AI-generated replies are always created as **drafts**, never auto-sent
- Low-confidence classifications trigger human review via Slack
- PII detection prevents sensitive information in AI-generated content
- Brand/tone guidelines injected via system prompt from knowledge base

### Integrations

- Gmail (via 5-minute polling trigger or Google Pub/Sub push for near-real-time)
- Slack (approval notifications, urgency alerts)
- PostgreSQL (event logging, task creation)
- OpenRouter (classification, draft generation via UTIL__AICall)

### Gmail Trigger Strategy

The default Gmail Trigger node uses **polling**, which consumes ~1,440 executions/day at 1-minute intervals even when no new emails arrive. Two mitigation strategies:

- **Recommended:** Implement Google Pub/Sub push notifications — set up a Gmail "Watch" via the Gmail API that pushes to a Pub/Sub topic, then use n8n's Webhook node to receive pushes. Zero wasted executions.
- **Minimum viable:** Set polling interval to 5 minutes and add deduplication logic (check message_id against events table before processing).

---

## 2. AI Meeting Intelligence

Processes meeting transcripts that are uploaded to a designated Google Drive folder.

### Transcript Ingestion Method

> **Important:** n8n does not have a native Google Meet node. There is no direct API endpoint for "get meeting transcript."

**Approach: Google Drive Trigger (Option B)**

Users or meeting recording systems upload transcript files (TXT, DOCX, VTT, SRT) to a designated Google Drive folder. A Drive trigger detects the new file and initiates the processing pipeline.

### Processing Pipeline

1. Drive trigger detects new file in `Meeting-Transcripts/` folder
2. Download and extract text content
3. AI summarization (via UTIL__AICall sub-workflow)
4. Action item extraction with owner and deadline parsing
5. Risk/decision detection
6. Store summary in Google Docs
7. Create tasks in tasks table
8. Send Slack notification with summary and action items

### Outputs

- Structured summary document (Google Docs)
- Action items with assigned owners and deadlines
- Decisions log
- Risk flags

### Integrations

- Google Drive (trigger: new file in folder)
- Google Docs (summary output)
- Google Calendar (deadline integration)
- Slack (summary notifications)
- PostgreSQL (action item tracking)
- OpenRouter (summarization, extraction via UTIL__AICall)

---

## 3. AI Knowledge Base

Converts organizational documents into searchable semantic memory with change detection and incremental processing.

### Supported Documents

- PDFs
- Google Docs
- SOPs
- Policies
- Reports

### Capabilities

- Semantic search (via Supabase pgvector similarity)
- RAG retrieval (context injection for AI responses)
- AI question answering (webhook-based query API)
- Organizational memory (versioned, deduplicated)

### Incremental Processing

- **Change detection:** Content hash comparison on each ingestion run. If document unchanged, skip re-embedding.
- **Version tracking:** Documents table tracks which version is currently embedded in the vector store.
- **Deletion handling:** When a document is removed from Drive, corresponding vectors are deleted from Supabase pgvector.
- **Deduplication:** Content hash prevents re-processing identical documents from different sources.

### Embedding Model

Locked to **Hugging Face `sentence-transformers/all-MiniLM-L6-v2`** (384 dimensions, free).

> **Warning:** Changing embedding models later requires re-embedding the entire knowledge base. Lock your model choice early and configure your pgvector dimensions to match.

---

## 4. Task Orchestration System

Automatically:

- Creates tasks (from email events, meeting action items, form submissions)
- Assigns owners (based on department routing rules)
- Sends reminders (daily cron with configurable lead time)
- Escalates delays (hourly cron checks overdue tasks)
- Tracks completion (with timestamps, not just status flags)
- Links tasks to source events (full traceability via source_event_id)

---

## 5. Executive Reporting Engine

Generates:

- Daily operational summaries (cron at 8am)
- Weekly digest reports (cron Monday 9am)
- AI-generated recommendations and insights
- Business metrics aggregation
- Incident/error reports (from workflow_logs)

---

# High-Level Architecture

```text
External Triggers
(Gmail Trigger, Drive Trigger, Webhooks, Cron)
         ↓
Entry-Point Workflows
(EMAIL__, DRIVE__, MEET__, FORM__)
         ↓
   ┌─────┴─────┐
   │  Shared    │
   │  Utilities │
   │ (UTIL__*)  │
   └─────┬─────┘
         ↓
AI Processing Layer
(UTIL__AICall with rate limiting, failover, logging)
         ↓
Workflow Execution
(Classification, Summarization, Task Creation)
         ↓
State Persistence (Supabase PostgreSQL + pgvector)
         ↓
Notifications & Reporting
(Slack, Email, Google Docs)
         ↓
Error Handling
(ERROR__GlobalHandler → Slack + workflow_logs)
```

> **Note:** There is no central "Event Router" workflow. Each event source has its own entry-point workflow with its own trigger. Cross-cutting concerns (logging, AI calls, Slack, deduplication) are handled by shared UTIL__ sub-workflows. This is the actual n8n best practice — modular entry points with shared utilities.

---

# Recommended Stack

## Automation Layer

- n8n (with native AI Agent nodes)

## Unified Data & Vector Layer

- Supabase (PostgreSQL + pgvector)

## AI Providers

- OpenRouter (Llama 3.3 for classification/generation, Gemini 2.5 Pro for large context and failover)
- Hugging Face (all-MiniLM-L6-v2 for embeddings)

## Infrastructure

- Cloud-Native (n8n Cloud + Supabase)

---

# Architecture Principles

## Modular Workflows

Avoid massive workflows.

Each workflow should:

- Have one responsibility
- Be reusable (especially UTIL__ sub-workflows)
- Be independently testable
- Be scalable
- Target 5–10 nodes per sub-workflow; break up anything over 20 nodes

---

# Entry-Point Trigger Design

Each event source gets its own entry-point workflow with its own native trigger. Do NOT funnel multiple event types through a single "router" workflow — n8n workflows are trigger-bound and a central dispatcher creates unnecessary indirection and debugging complexity.

Examples:

- `EMAIL__ClassifyIncoming` — Gmail Trigger or Pub/Sub Webhook
- `DRIVE__ProcessUpload` — Google Drive Trigger
- `MEET__ProcessTranscript` — Google Drive Trigger (new file in Meeting-Transcripts folder)
- `FORM__ProcessSubmission` — Webhook Trigger

Each entry-point calls shared UTIL__ sub-workflows for logging, AI calls, notifications, and deduplication.

---

# Human-in-the-Loop AI

Critical decisions require approval.

Example:

- Low AI confidence (below configurable threshold)
- Financial approvals (amount exceeds threshold)
- Executive escalation (flagged by classification)

### Implementation Constraint

> **Warning:** Do NOT place Wait or Human-in-the-Loop nodes inside sub-workflows. Sub-workflows containing Wait nodes do not correctly return output to the parent workflow. Keep all approval/wait logic in the main workflow.

### Approval Pattern

1. Main workflow reaches decision point → checks AI confidence
2. If low confidence → Wait for Webhook node (pauses execution)
3. Send approval request via Slack with unique resume URL
4. Reviewer clicks approve/reject → workflow resumes
5. Pending state stored in `approvals` table for audit trail and crash recovery

---

# Error Handling Strategy

Error handling is a **foundational concern**, not a hardening step. Implemented in Week 1.

### Three-Layer Resilience

1. **Node-Level:** Retry on Fail with exponential backoff for all external API calls. Continue on Fail for non-critical enrichment steps.
2. **Global:** Dedicated `ERROR__GlobalHandler` workflow with Error Trigger node. All production workflows configured to use this error workflow.
3. **Centralized Logging:** All errors logged to `workflow_logs` table with workflow name, failed node, error message, execution link, and input payload (dead letter queue).

---

# Deduplication Strategy

All event-processing workflows include deduplication at the entry point:

1. Compute a hash of `source + key payload fields` (e.g., Gmail message_id)
2. Check the `events` table for existing hash
3. If found, skip processing (log as duplicate)
4. If not found, insert event and continue

---

# Rate Limiting & AI Provider Management

AI API calls are centralized through `UTIL__AICall` sub-workflow:

1. Checks daily API usage limit
2. Selects appropriate model (OpenRouter Llama 3.3 for fast tasks, OpenRouter Gemini 2.5 for large-context)
3. Implements retry with exponential backoff
4. Falls back to secondary provider on failure (e.g., Llama 3.3 → Gemini 2.5)
5. Logs usage (model, tokens, latency, cost) to `workflow_logs`
6. Enforces daily token budget limits

---

# Scalability Goals

Future support for:

- n8n Cloud managed queue mode (scales automatically)
- Distributed workers (scale horizontally by adding worker containers)
- Multi-tenant architecture
- API gateways
- Real-time event streams

---

# Future Expansion Ideas

- Voice AI agents
- Internal AI chat assistant
- Predictive operational analytics
- Autonomous AI task routing
- AI operational memory
- Multi-agent orchestration (leveraging n8n's native AI Agent nodes with tool calling)
```

---

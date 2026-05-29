# n8n Workflow Maintenance Agent Guide

This document serves as the operational guide and knowledge base for an AI Agent or developer tasked with maintaining, auditing, and upgrading n8n workflows in this project to align with **n8n v2.21.7** standards. 

## 🎯 Primary Objective
Ensure all `.json` workflow files in the repository adhere to the latest n8n node schemas, specifically addressing deprecated properties, missing mapping configurations, and terminology changes introduced in recent n8n versions.

---

## 📚 Core Knowledge Base: n8n Node Upgrades

### 1. Supabase Node Updates (`n8n-nodes-base.supabase`)
n8n heavily revamped the Supabase node between `typeVersion: 1` and `typeVersion: 2`. When analyzing workflows, pay close attention to the following:

#### Terminology & Operations
*   **Legacy (v1) Operations:** `insert`, `update`, `upsert`, `getAll`, `delete`, and sometimes invalidly configured as `executeQuery` (which belongs to the Postgres node).
*   **Modern (v2) Operations:** Focuses on standard REST taxonomy. The `resource` is usually `"row"`. The available operations are strictly: `create`, `delete`, `get`, `getMany`, `update`, and `Custom API Call`.
*   **Upsert Removal:** "Upsert" is removed from the default UI operations in v2. Workflows should be modeled to explicitly `update` or `create`.

#### Missing Select Conditions (The `matchColumns` Bug)
In `typeVersion: 1`, if an `update` operation is used without defining `filters`, the node **must** include a `"matchColumns"` property (e.g., `"matchColumns": "id"`). If missing, the node will throw:
> *"Problem in node ‘Update Event‘: At least one select condition must be defined."*

#### Filtering Syntax
*   **v1:** Used `filterType: "string"` and raw strings like `"status=neq.completed&escalated_at=is.null"`.
*   **v2:** Uses a structured `matchUi` object:
    ```json
    "matchUi": {
      "matchValues": [
        {
          "matchColumn": "status",
          "matchOperator": "neq",
          "matchValue": "completed"
        }
      ]
    }
    ```

### 2. Manual JSON Editing vs. UI Re-creation
*   **Simple Bug Fixes:** You can surgically edit the JSON (e.g., appending `"matchColumns": "id"`) to fix v1 nodes.
*   **Version Upgrades:** Do **not** simply increment `"typeVersion": 1` to `2` without entirely rewriting the node's `"parameters"` object, as the schema breaks backward compatibility. If heavily restructuring, sometimes it's best to configure the node in the n8n UI, export the JSON, and commit it.

### 3. Defensive JavaScript Coding (Code Nodes)
Because database nodes like `getMany` might return slightly broad result sets if filters are misconfigured, downstream Code nodes should **always** apply defensive filtering. 
*Example: Instead of blindly mapping tasks for escalation, explicitly verify `hoursOverdue >= 24` and `!task.escalated_at` within the JavaScript loop.*

---

## 🛠️ Agent Toolkit & Commands

When auditing the repository, the agent should use the following strategies:

### 1. Scan for Invalid Operations
Use `grep_search` to find Supabase nodes incorrectly using Postgres operations.
**Search Pattern:** `"operation": "executeQuery"`

### 2. Scan for Deprecated `typeVersion: 1` Nodes
Use `grep_search` to locate nodes that are technically working but overdue for an upgrade.
**Search Pattern:** `"typeVersion": 1` (Narrow down to `"n8n-nodes-base.supabase"`)

### 3. Scan for Missing `matchColumns`
If a Supabase v1 node has `"operation": "update"` but lacks `"matchColumns"` and `"filters"`, it will fail at runtime. The agent should aggressively hunt for this pattern and inject the missing field.

---

## 🚀 Execution Workflow for the Agent

When instructed to "Sync" or "Fix" workflows, follow this loop:
1. **Discover:** Search the `workflows/` directory for the target integration (e.g., Supabase, Slack, Gmail).
2. **Analyze:** Read the raw `.json` using file viewing tools to map the inputs and outputs. Check the `typeVersion` and `parameters` object.
3. **Patch:** Use file editing tools to surgically inject missing properties (like `matchColumns`) or update the schema to `typeVersion: 2`.
4. **Validate Downstream:** Ensure the `Code` node immediately following the DB node properly parses the array of items.

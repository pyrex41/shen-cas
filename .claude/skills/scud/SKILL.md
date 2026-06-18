---
name: scud-guide
description: SCUD CLI reference and workflow guide. Use when working with scud task management, running scud commands, or when the user mentions tasks, waves, DAG, or project progress.
---

# SCUD CLI Guide

SCUD is a DAG-based task manager for AI-driven development. Tasks have dependencies, priorities, and complexity scores. Work flows through parallel waves.

## Session Workflow

```bash
scud warmup              # Orient: status, git history, next task
scud next                # Find next available task (deps satisfied)
scud set-status ID in-progress
# ... do the work ...
scud commit -m "message" # Auto-prefixes [TASK-ID]
scud set-status ID done
scud stats               # Check progress
```

## Commands

| Category | Command | Description |
|----------|---------|-------------|
| **Session** | `scud warmup` | Orient with status + next task |
| **View** | `scud list [--status pending]` | List tasks |
| | `scud show ID` | Task details |
| | `scud stats` | Completion statistics |
| **Work** | `scud next` | Next ready task |
| | `scud waves` | Parallel execution waves |
| | `scud set-status ID STATUS` | Update status |
| | `scud create --title "..."` | Create a task |
| **Git** | `scud commit -m "msg"` | [TASK-ID] prefixed commit |
| **AI** | `scud parse FILE` | Generate tasks from doc |
| | `scud expand ID` | Break into subtasks |
| | `scud heavy "query"` | Multi-agent reasoning ensemble |
| **Tags** | `scud tags` | List/switch phases |
| **Server** | `scud mcp-server` | Start MCP server for tool integration |

## Heavy Ensemble

Multi-agent reasoning with per-role model control:

```bash
scud heavy "query" -v                                    # Default
scud heavy "query" --model-agents grok-4.1-fast          # Cheap agents
scud heavy "query" --mode hybrid                         # Local + web research
```

Modes: ensemble (default), native (xAI multi-agent), hybrid (both).

## MCP Server

Expose scud as tools for Cowork/Claude Code:

```json
{"mcpServers": {"scud": {"command": "scud", "args": ["mcp-server"]}}}
```

Tiers via SCUD_TOOLS: core (default, 6 tools), full (9 tools), or custom comma-separated list.

## Task Statuses

pending | in-progress | done | blocked | failed | review | expanded | deferred | cancelled

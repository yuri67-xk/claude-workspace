# Web UI Design for claude-workspace

**Date:** 2026-03-01
**Status:** Approved

## Overview

Add a `cw web` command that launches a local web server providing a browser-based GUI for managing claude-workspace workspaces. The Web UI targets users who prefer not to use a CLI while also increasing information density compared to the TUI menu.

## Goals

- Allow full CRUD operations on workspaces from a browser
- Display richer information than the current TUI (last used dates, directory counts, descriptions)
- Technically interesting: use FastAPI + HTMX as the stack
- No cloud hosting — localhost only

## Architecture

```
User
  ↓ cw web
lib/web.sh            (new)
  └ uvicorn を起動 + open browser
web/                  (new directory)
  ├ main.py           FastAPI app
  ├ templates/        Jinja2 HTML templates
  └ requirements.txt  fastapi, uvicorn

Existing data (unchanged):
  ├ ~/.claude-workspace/registry.json
  └ <workspace_path>/.workspace.json
```

FastAPI reads and writes the existing JSON files directly. The CLI and Web UI can be used concurrently without conflicts (file-based, loosely coupled).

## Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Backend | Python + FastAPI | Minimal install (`pip install`), async-ready, modern |
| Server | uvicorn | Lightweight ASGI server, ships with FastAPI |
| Frontend | HTMX + Jinja2 | Server-driven partials, minimal JavaScript, no build step |
| Styling | Tailwind CSS CDN | No build required, utility-first |

## Pages & Features

| Page | URL | Function |
|------|-----|----------|
| Dashboard | `/` | Workspace card list (name, dir count, last used) |
| Detail | `/workspace/{name}` | Dir list, description, action buttons |
| New workspace | `/new` | Form: name, description, initial directory |
| Add directory | POST `/workspace/{name}/add-dir` | Append dir to workspace (HTMX partial update) |
| Launch | POST `/workspace/{name}/launch` | Open new Terminal via `osascript` + `cw launch` |
| Forget | POST `/workspace/{name}/forget` | Remove from registry (files kept) |
| Delete | POST `/workspace/{name}/delete` | Remove from registry + delete directory |

## File Structure

```
claude-workspace/
├── bin/cw                    # Modified: add case "web"
├── lib/
│   ├── web.sh                # New: cmd_web() — starts uvicorn
│   └── ...existing files
└── web/                      # New directory
    ├── main.py               # FastAPI application
    ├── requirements.txt      # fastapi uvicorn
    └── templates/
        ├── base.html         # Base template (Tailwind CDN + HTMX CDN)
        ├── index.html        # Dashboard
        ├── workspace.html    # Detail / edit view
        └── new.html          # New workspace form
```

## `cw web` Behavior

1. Check `web/requirements.txt` → `pip install` if first run
2. Start `uvicorn web.main:app --port 8765` in background
3. Open `http://localhost:8765` in browser
4. Ctrl+C stops the server

## Installation Integration

`install.sh` copies the `web/` directory to `$CW_HOME/web/` alongside the existing `lib/` and `bin/` files.

## i18n

Add `cw web` usage text and error messages to `lib/i18n.sh` (both `en` and `ja` blocks), consistent with existing i18n patterns.

## Out of Scope (v1)

- Authentication / access control
- Remote hosting
- Real-time log streaming
- Multi-user support
- Dark mode

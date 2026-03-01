#!/usr/bin/env python3
"""claude-workspace Web UI — FastAPI application."""

import json
import os
import subprocess
from pathlib import Path

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

app = FastAPI(title="claude-workspace Web UI")

CW_DIR = Path(os.environ.get("CW_HOME", str(Path.home() / ".claude-workspace")))
REGISTRY_FILE = CW_DIR / "registry.json"
WORKSPACE_FILE = ".workspace.json"

templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))


# ─── Data helpers ─────────────────────────────────────────────────────────────

def _read_registry() -> list:
    """Return workspace list sorted by last_used descending."""
    if not REGISTRY_FILE.exists():
        return []
    with REGISTRY_FILE.open() as f:
        data = json.load(f)
    workspaces = data.get("workspaces", [])
    return sorted(workspaces, key=lambda w: w.get("last_used", ""), reverse=True)


def _write_registry(workspaces: list) -> None:
    """Overwrite registry.json with updated workspace list."""
    tmp = REGISTRY_FILE.with_suffix(".json.tmp")
    with tmp.open("w") as f:
        json.dump({"workspaces": workspaces}, f, indent=2)
    tmp.replace(REGISTRY_FILE)


def _get_workspace(name: str):
    """Return (registry_entry, workspace_path) or raise 404."""
    workspaces = _read_registry()
    entry = next((w for w in workspaces if w["name"] == name), None)
    if not entry:
        raise HTTPException(status_code=404, detail=f"Workspace not found: {name}")
    ws_path = Path(entry["path"])
    return entry, ws_path


def _read_workspace_json(ws_path: Path) -> dict:
    """Read .workspace.json from workspace directory."""
    ws_file = ws_path / WORKSPACE_FILE
    if not ws_file.exists():
        return {}
    with ws_file.open() as f:
        return json.load(f)


def _write_workspace_json(ws_path: Path, data: dict) -> None:
    """Write .workspace.json atomically."""
    ws_file = ws_path / WORKSPACE_FILE
    tmp = ws_file.with_suffix(".json.tmp")
    with tmp.open("w") as f:
        json.dump(data, f, indent=2)
    tmp.replace(ws_file)


# ─── Health check ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "registry": str(REGISTRY_FILE)}

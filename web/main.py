#!/usr/bin/env python3
"""claude-workspace Web UI — FastAPI application."""

import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

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


def _generate_claude_md(ws_path: Path, ws_data: dict) -> None:
    """Generate workspace CLAUDE.md with full template (mirrors bash _generate_workspace_claude_md)."""
    ws_name = ws_data.get("name", "")
    ws_description = ws_data.get("description", "") or "Describe this workspace here."
    dirs = ws_data.get("dirs", [])
    created_at = datetime.now().strftime("%Y-%m-%d")
    ws_name_lower = ws_name.lower().replace(" ", "-")

    dirs_rows = ""
    for d in dirs:
        path = d.get("path", "")
        role = d.get("role", "") or Path(path).name
        dirs_rows += f"| {role} | `{path}` |\n"

    content = (
        f"# Workspace: {ws_name}\n\n"
        f"> {ws_description}\n\n"
        f"Created: {created_at}\n\n"
        "---\n\n"
        "## Linked Repositories\n\n"
        "| Role | Path |\n"
        "|------|------|\n"
        f"{dirs_rows}\n"
        "## Workflow Rules\n\n"
        "- **REQUIRED**: Use the `workspace-task-manager` skill for task decomposition and management\n"
        "  - Decompose workspace goals into tasks before starting implementation\n"
        "  - Each task gets a `YYYY-MM-DD-{task-name}/` directory under this workspace\n"
        "  - Follow the superpowers workflow (brainstorming → writing-plans → execute) per task\n"
        "  - Save design docs and plans into the task directory, not `docs/plans/`\n"
        f"- Branch naming convention: `feature/ws-{ws_name_lower}-*`\n\n"
        "## Current Tasks\n\n"
        "| Status | Task | Directory | Priority |\n"
        "|--------|------|-----------|----------|\n"
        "| | (Use workspace-task-manager skill to populate) | | |\n\n"
        "## Notes\n\n"
        "Record notes and design decisions here.\n"
    )

    (ws_path / "CLAUDE.md").write_text(content)


def _install_skills(ws_path: Path) -> None:
    """Copy skills from ~/.claude-workspace/skills/ to workspace/.claude/skills/."""
    skills_src = CW_DIR / "skills"
    if not skills_src.is_dir():
        return

    skills_dst = ws_path / ".claude" / "skills"
    skills_dst.mkdir(parents=True, exist_ok=True)

    for skill_dir in skills_src.iterdir():
        if skill_dir.is_dir():
            dst = skills_dst / skill_dir.name
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(skill_dir, dst)


# ─── Health check ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "registry": str(REGISTRY_FILE)}


@app.get("/pick-folder")
def pick_folder():
    """Open macOS native folder selection dialog via osascript and return POSIX path."""
    script = (
        'try\n'
        '    set f to choose folder with prompt "Select a folder:"\n'
        '    return POSIX path of f\n'
        'on error number -128\n'
        '    return ""\n'
        'end try'
    )
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return {"path": ""}
    if result.returncode != 0:
        return {"path": ""}
    path = result.stdout.strip().rstrip("/")
    return {"path": path}


templates.env.filters["urlencode"] = lambda s: quote(str(s), safe="")
templates.env.filters["is_existing_dir"] = lambda d: Path(d["path"]).is_dir()


@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    workspaces = _read_registry()
    # Enrich with dir count from .workspace.json
    for ws in workspaces:
        ws_data = _read_workspace_json(Path(ws["path"]))
        ws["dir_count"] = len(ws_data.get("dirs", []))
    return templates.TemplateResponse("index.html", {
        "request": request,
        "workspaces": workspaces,
    })


@app.get("/workspace/{name}", response_class=HTMLResponse)
async def workspace_detail(request: Request, name: str):
    ws_entry, ws_path = _get_workspace(name)
    ws_data = _read_workspace_json(ws_path)
    return templates.TemplateResponse("workspace.html", {
        "request": request,
        "ws": ws_entry,
        "ws_data": ws_data,
    })


@app.get("/new", response_class=HTMLResponse)
async def new_workspace_form(request: Request):
    return templates.TemplateResponse("new.html", {"request": request, "error": None})


@app.post("/workspace", response_class=HTMLResponse)
async def create_workspace(
    request: Request,
    name: str = Form(...),
    description: str = Form(""),
    workspace_path: str = Form(...),
    initial_dir: str = Form(""),
):
    ws_path = Path(workspace_path).expanduser().resolve()

    # Validate name uniqueness
    workspaces = _read_registry()
    if any(w["name"] == name for w in workspaces):
        return templates.TemplateResponse("new.html", {
            "request": request,
            "error": f"Workspace '{name}' already exists.",
        }, status_code=400)

    # Create workspace directory
    ws_path.mkdir(parents=True, exist_ok=True)

    # Build dirs list
    dirs = []
    if initial_dir.strip():
        dirs.append({"path": str(Path(initial_dir.strip()).expanduser().resolve()), "role": ""})

    # Write .workspace.json
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ws_data = {
        "name": name,
        "description": description,
        "workspace_path": str(ws_path),
        "created_at": now,
        "dirs": dirs,
    }
    _write_workspace_json(ws_path, ws_data)

    # Generate CLAUDE.md with full template
    _generate_claude_md(ws_path, ws_data)

    # Install skills to .claude/skills/
    _install_skills(ws_path)

    # Register in registry
    workspaces.append({
        "name": name,
        "path": str(ws_path),
        "created_at": now,
        "last_used": now,
    })
    _write_registry(workspaces)

    return RedirectResponse(url=f"/workspace/{name}", status_code=303)


@app.post("/workspace/{name}/add-dir", response_class=HTMLResponse)
async def add_directory(
    request: Request,
    name: str,
    path: str = Form(...),
    role: str = Form(""),
):
    ws_entry, ws_path = _get_workspace(name)
    ws_data = _read_workspace_json(ws_path)

    resolved = str(Path(path.strip()).expanduser().resolve())
    dirs = ws_data.get("dirs", [])

    # Skip duplicate
    if not any(d["path"] == resolved for d in dirs):
        dirs.append({"path": resolved, "role": role.strip()})
        ws_data["dirs"] = dirs
        _write_workspace_json(ws_path, ws_data)
        _generate_claude_md(ws_path, ws_data)

    return templates.TemplateResponse("partials/dir_list.html", {
        "request": request,
        "dirs": dirs,
    })


@app.post("/workspace/{name}/launch")
async def launch_workspace(name: str):
    ws_entry, ws_path = _get_workspace(name)

    # Open new Ghostty window and run cw launch
    # Escape backslashes and double quotes for bash -c string
    safe_name = name.replace("\\", "\\\\").replace('"', '\\"')
    ghostty_bin = shutil.which("ghostty") or "/Applications/Ghostty.app/Contents/MacOS/ghostty"
    try:
        subprocess.Popen([ghostty_bin, "--", "bash", "-c", f'cw launch "{safe_name}"'])
    except FileNotFoundError:
        raise HTTPException(
            status_code=503,
            detail="Ghostty not found. Please install Ghostty from https://ghostty.org",
        )

    # Touch last_used in registry
    workspaces = _read_registry()
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for ws in workspaces:
        if ws["name"] == name:
            ws["last_used"] = now
    _write_registry(workspaces)

    return RedirectResponse(url=f"/workspace/{name}", status_code=303)


@app.post("/workspace/{name}/forget")
async def forget_workspace(name: str):
    workspaces = _read_registry()
    updated = [w for w in workspaces if w["name"] != name]
    if len(updated) == len(workspaces):
        raise HTTPException(status_code=404, detail=f"Workspace not found: {name}")
    _write_registry(updated)
    return RedirectResponse(url="/", status_code=303)


@app.post("/workspace/{name}/delete")
async def delete_workspace(name: str):
    ws_entry, ws_path = _get_workspace(name)

    # Safety check: only allow deletion of directories under WorkingProjects/
    working_projects = Path(
        os.environ.get("WORKING_PROJECTS_DIR", str(Path.home() / "WorkingProjects"))
    ).expanduser().resolve()
    if not str(ws_path).startswith(str(working_projects) + "/"):
        raise HTTPException(
            status_code=400,
            detail=f"Workspace directory is not under WorkingProjects/. Use 'forget' to remove from registry only.",
        )

    # Delete directory first, then remove from registry
    if ws_path.exists():
        shutil.rmtree(str(ws_path))

    # Then remove from registry
    workspaces = _read_registry()
    updated = [w for w in workspaces if w["name"] != name]
    _write_registry(updated)

    return RedirectResponse(url="/", status_code=303)

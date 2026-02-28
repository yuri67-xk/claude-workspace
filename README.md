# claude-workspace (cw)

> [日本語版 / Japanese](./README_ja.md)

A multi-repository workspace manager for Claude Code.

## Installation

```bash
git clone https://github.com/yuri67-xk/claude-workspace ~/.claude-workspace-src
cd ~/.claude-workspace-src
bash install.sh
```

**Dependencies**
- `jq` (`brew install jq`)
- `claude` (Claude Code CLI)

---

## Usage

### Just run `cw` from anywhere

```bash
cw
```

- **If inside a Workspace directory** → Launches Claude Code directly
- **Otherwise** → Shows an interactive menu

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  claude-workspace (cw)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Recent Workspaces:

  [1] Store360 Refactor  3 days ago
      /Users/yuri/WorkingProjects/store360-refactor

  [2] My Feature         1 week ago
      /Users/yuri/WorkingProjects/my-feature

  ────────────────────────────────────────
  [N] Create new Workspace
  [Q] Quit

  Select [1-2 / N / Q]:
```

---

### Create a new Workspace

```bash
cw new
```

Interactive setup:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Create new Workspace
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Workspace name: Store360 Refactor

  Workspace name:  Store360 Refactor
  Location:        ~/WorkingProjects/Store360-Refactor
  Create? [Y/n]:
```

- Automatically creates `~/WorkingProjects/<name>/` folder
- Proceeds to `cw setup`
- Launches Claude Code after setup

You can also pass the name as an argument:

```bash
cw new store360-refactor
```

---

### Resume an existing Workspace

```bash
cw resume   # or cw r
```

Shows a menu of registered Workspaces from anywhere.

---

### Manual Workspace setup

To register an existing directory as a Workspace:

```bash
cd ~/WorkingProjects/store360-refactor
cw setup
```

Generated files:
- `<workspace>/.workspace.json` — Workspace configuration
- `<workspace>/CLAUDE.md` — Workspace context (auto-loaded by Claude Code)
- `<repo>/CLAUDE.md` — Appends "Used by Workspaces" section to each repository

---

### Launch Claude Code

```bash
cd ~/WorkingProjects/store360-refactor
cw          # or cw launch
```

Launches Claude Code with `--add-dir` for all directories registered in `.workspace.json`.

You can also specify a name:

```bash
cw launch "Store360 Refactor"
```

---

### Add a directory later

```bash
cw add-dir ~/repos/store360-flutter-wrapper
```

---

### List Workspaces

```bash
cw list
```

Shows Workspaces sorted by last used.

---

### Show Workspace details

```bash
cw info
```

---

### Remove from registry

```bash
cd ~/WorkingProjects/store360-refactor
cw forget
```

Removes only the registry entry. Files (`.workspace.json`, `CLAUDE.md`) remain intact.

---

### Update

```bash
cw update
```

Runs `git pull` in the source directory and installs the latest libraries.

---

### Change language

```bash
cw lang ja    # Switch to Japanese
cw lang en    # Switch to English
```

---

## Command Reference

| Command | Description |
|---------|-------------|
| `cw` | Launch if in Workspace, otherwise show menu |
| `cw new [name]` | Create new Workspace in WorkingProjects/ |
| `cw resume` | Show Workspace selection menu |
| `cw setup` | Setup current directory as a Workspace |
| `cw launch [name]` | Launch Claude Code for a Workspace |
| `cw add-dir <path>` | Add a directory to current Workspace |
| `cw list` | List Workspaces (sorted by last used) |
| `cw info` | Show current Workspace details |
| `cw forget` | Remove current Workspace from registry |
| `cw scan` | Scan WorkingProjects/ for unregistered Workspaces |
| `cw update` | Update from source (git pull + copy) |
| `cw lang [en\|ja]` | Change display language |
| `cw help` | Show help |

---

## File Structure

```
~/WorkingProjects/
└── store360-refactor/
    ├── .workspace.json     ← cw configuration
    ├── CLAUDE.md           ← workspace context (auto-generated)
    └── notes/              ← notes (optional)

~/.claude-workspace/
├── registry.json           ← global registry of all Workspaces
├── source_path             ← source path for cw update
├── lang                    ← language setting (en/ja)
└── lib/                    ← cw libraries
```

### Example .workspace.json

```json
{
  "name": "Store360 Refactor",
  "description": "SDK monolith decomposition project",
  "workspace_path": "/Users/yuri/WorkingProjects/store360-refactor",
  "created_at": "2025-06-01T12:00:00Z",
  "dirs": [
    { "path": "/Users/yuri/repos/store360-ios-sdk", "role": "iOS SDK" },
    { "path": "/Users/yuri/repos/store360-android-sdk", "role": "Android SDK" },
    { "path": "/Users/yuri/repos/store360-flutter-wrapper", "role": "Flutter Wrapper" }
  ]
}
```

### Example registry.json

```json
{
  "workspaces": [
    {
      "name": "Store360 Refactor",
      "path": "/Users/yuri/WorkingProjects/store360-refactor",
      "created_at": "2025-06-01T12:00:00Z",
      "last_used": "2025-06-10T09:00:00Z"
    }
  ]
}
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CW_HOME` | `~/.claude-workspace` | cw data directory |
| `WORKING_PROJECTS_DIR` | `~/WorkingProjects` | Base directory for `cw new` / `cw list` |

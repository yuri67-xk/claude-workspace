# Design: cw Interactive Menu

**Date**: 2026-02-28
**Scope**: Replace the current cw menu with a fully interactive fzf-based menu where all operations complete within the CLI session.

---

## Problem

Currently `cw` has two modes based on the current directory:

- In a workspace directory → immediately launches Claude Code (`cmd_launch`)
- Elsewhere → shows a numbered list menu, selecting immediately launches Claude Code

There is no sub-menu after selecting a workspace, so users cannot perform actions like `add-dir`, `info`, or `forget` from the interactive flow.

---

## Goal

When `cw` is executed from anywhere, show an interactive fzf menu that allows all workspace operations to complete without leaving the CLI session.

---

## UX Flow

```
cw (from anywhere)
↓
┌─────────────────────────┬────────────────────────────────────┐
│ > ▶ Create New          │  workspace-a                       │
│   workspace-a     ◀     │  /Users/.../workspace-a            │
│   workspace-b           │  Dirs: 2  ·  3 days ago            │
│                         │  + store360-ios-demo  ✓            │
│                         │  + api-server         ✓            │
└─────────────────────────┴────────────────────────────────────┘
       ↓ select workspace
┌─────────────────────────┐
│ > ▶ Resume              │  (fzf sub-menu)
│   + Add Dir             │
│   ℹ Info                │
│   ⊙ Open in Finder      │
│   ✗ Forget              │
│   ← Back                │
└─────────────────────────┘
```

---

## Architecture

### Files to change

| File | Change |
|------|--------|
| `lib/menu.sh` | Full rewrite with fzf + preview + sub-menu |
| `cw` (main script) | Change `""` case to always call `cmd_menu` |
| `lib/i18n.sh` | Add translation keys for sub-menu actions and `press_enter` |

### No new files needed

All logic stays in `lib/menu.sh`. Existing commands (`cmd_launch`, `cmd_add_dir`, `cmd_info`) are reused as-is.

---

## Design Details

### `cw` main script change

```bash
# Before
"")
  if is_workspace "$(pwd)"; then
    cmd_launch
  else
    cmd_menu
  fi
  ;;

# After
"")  cmd_menu ;;
```

### `cmd_menu` (new implementation)

1. Build workspace list from registry (sorted by last_used desc) + filesystem scan for unregistered workspaces
2. Prepare fzf input as tab-separated `PATH\tDISPLAY_TEXT`
   - First entry: `CREATE_NEW\t▶ Create New Workspace`
   - Each workspace: `<path>\t<name>  (<relative_time>)`
3. Call fzf with:
   - `--delimiter='\t' --with-nth='2..'` (show only display text)
   - `--preview=<bash script reading {1}/.workspace.json>`
   - `--preview-window=right:40%`
4. On selection:
   - `CREATE_NEW` → `cmd_new`
   - Any workspace → `_menu_submenu <path> <name>`
5. Fallback: if fzf is not available, use current numbered input approach

### `_menu_submenu <path> <name>` (new function)

Displays an fzf action picker for the selected workspace.

Actions and their behaviors:

| Action | Behavior |
|--------|----------|
| `▶ Resume` | `cd <path>` → `exec claude --add-dir ...` (terminal) |
| `+ Add Dir` | `cd <path>` → `cmd_add_dir` → re-show `_menu_submenu` |
| `ℹ Info` | `cd <path>` → `cmd_info` → press Enter → re-show `_menu_submenu` |
| `⊙ Open in Finder` | `open <path>` → re-show `_menu_submenu` |
| `✗ Forget` | confirm prompt → `registry_remove` → back to `cmd_menu` |
| `← Back` | back to `cmd_menu` |

### `_menu_forget <path> <name>` (new helper)

Replaces `cmd_forget` for use from the menu context (avoids `pwd`-dependency).

```bash
_menu_forget() {
  local ws_path="$1"
  local ws_name="$2"
  warn "Remove '${ws_name}' from registry"
  echo "  Note: Files will not be deleted"
  read -rp "  Continue? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] && registry_remove "$ws_path" && success "Deleted: $ws_name"
  cmd_menu
}
```

### fzf preview script

The preview reads `{1}/.workspace.json` using `jq` and displays:
- Workspace name
- Description (if present)
- Full path
- Number of dirs + last used date
- Each linked directory with ✓ (exists) or ✗ (missing)

### New i18n keys

| Key | English | Japanese |
|-----|---------|----------|
| `press_enter` | `Press Enter to continue` | `Enter で続ける` |
| `menu_action_resume` | `▶ Resume` | `▶ 起動` |
| `menu_action_add_dir` | `+ Add Dir` | `+ ディレクトリを追加` |
| `menu_action_info` | `ℹ Info` | `ℹ 詳細情報` |
| `menu_action_finder` | `⊙ Open in Finder` | `⊙ Finder で開く` |
| `menu_action_forget` | `✗ Forget` | `✗ レジストリから削除` |
| `menu_action_back` | `← Back` | `← 戻る` |

---

## Fallback (no fzf)

When `fzf` is not available, fall back to the existing numbered input approach but with the sub-menu added after workspace selection. This ensures the tool remains usable without fzf.

---

## Constraints

- Do NOT modify `~/.claude-workspace` directly — only edit `~/Developer/claude-workspace/` source files
- `cmd_add_dir` and `cmd_info` use `pwd` internally — use `cd <path>` before calling them
- `exec claude` in `cmd_launch` is terminal (no return) — this is intentional for Resume
- The `((valid_count++))` bug in `launch.sh` must also be fixed in the source tree (already fixed in deployed copy)

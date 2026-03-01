# Design: Forget with Directory Deletion

**Date**: 2026-03-01
**Scope**: Extend the menu Forget action to optionally delete the workspace directory via `rm -rf`, restricted to WorkingProjects/.

---

## Problem

Currently `_menu_forget` (and `cmd_forget`) only removes a workspace from the registry. The physical directory under `WorkingProjects/` remains. Users need a way to fully delete a workspace they no longer need.

---

## Goal

When Forget is chosen in the sub-menu, show a secondary fzf picker:
- **Registry only** — current behavior, removes from registry
- **Delete directory** — removes from registry AND runs `rm -rf` on the workspace directory (restricted to WorkingProjects/)

---

## UX Flow

```
Sub-menu: ✗ Forget selected
↓
fzf (or numbered fallback):
  Registry only
  Delete directory
↓

[If "Registry only"]
  → registry_remove
  → back to main menu

[If "Delete directory" AND path is outside WorkingProjects/]
  → error: "Directory is outside WorkingProjects/ — cannot delete"
  → back to sub-menu

[If "Delete directory" AND path is inside WorkingProjects/]
  → warn: 'my-workspace' (/path/) will be permanently deleted
  → warn: This cannot be undone
  → read [y/N]
     → y: registry_remove + rm -rf → back to main menu
     → N: info(cancel) → back to sub-menu
```

---

## Files to Change

| File | Change |
|------|--------|
| `lib/menu.sh` | Extend `_menu_forget` with mode picker |
| `lib/i18n.sh` | Add 5 new translation keys |

`bin/cw`'s `cmd_forget` (the `cw forget` CLI command) is NOT changed in this iteration.

---

## `_menu_forget` Implementation Design

```bash
_menu_forget() {
  local ws_path="$1"
  local ws_name="$2"

  # Step 1: Pick mode via fzf (or numbered fallback)
  local registry_only_label delete_dir_label
  registry_only_label=$(t "forget_mode_registry")
  delete_dir_label=$(t "forget_mode_delete")

  local mode
  if command -v fzf &>/dev/null; then
    mode=$(printf '%s\n' "$registry_only_label" "$delete_dir_label" | \
      fzf --height=30% --border \
          --header="  $ws_name" \
          --header-first \
          --prompt='  Delete mode > ' \
          2>/dev/null || true)
  else
    # Numbered fallback (output to stderr)
    echo "" >&2
    echo "  1) $registry_only_label" >&2
    echo "  2) $delete_dir_label" >&2
    echo "" >&2
    local choice
    read -rp "  Select [1/2]: " choice
    case "$choice" in
      2) mode="$delete_dir_label" ;;
      *) mode="$registry_only_label" ;;
    esac
  fi

  [[ -z "$mode" ]] && return  # Esc → back to sub-menu

  if [[ "$mode" == "$registry_only_label" ]]; then
    # Registry only (current behavior)
    echo ""
    warn "\"${ws_name}\" $(t "remove_from_registry")"
    echo "  $(dim "$(t "files_remain")")"
    echo ""
    read -rp "  $(t "continue") [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      registry_remove "$ws_path"
      success "$(t "deleted"): $ws_name"
      echo ""
    else
      info "$(t "cancel")"
    fi

  elif [[ "$mode" == "$delete_dir_label" ]]; then
    # Safety check: must be under WorkingProjects/
    local wp_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
    wp_base=$(expand_path "$wp_base")
    if [[ "$ws_path" != "$wp_base"/* ]]; then
      echo ""
      error "$(t "forget_delete_outside_wp")"
      echo "  $(dim "$ws_path")"
      echo ""
      return  # back to sub-menu
    fi

    # Destructive confirmation
    echo ""
    warn "$(t "forget_delete_confirm"): \"$ws_name\""
    echo "  $(dim "$ws_path")"
    warn "$(t "irreversible")"
    echo ""
    read -rp "  $(t "continue") [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      registry_remove "$ws_path"
      rm -rf "$ws_path"
      success "$(t "forget_dir_deleted"): $ws_name"
      echo ""
    else
      info "$(t "cancel")"
    fi
  fi
}
```

---

## New i18n Keys (5 + 1 reused)

| Key | English | Japanese |
|-----|---------|----------|
| `forget_mode_registry` | `Registry only` | `レジストリのみ削除` |
| `forget_mode_delete` | `Delete directory` | `ディレクトリを削除` |
| `forget_delete_confirm` | `Permanently delete this directory` | `このディレクトリを完全に削除します` |
| `forget_delete_outside_wp` | `Directory is outside WorkingProjects/ — cannot delete` | `WorkingProjects/ 外のディレクトリは削除できません` |
| `forget_dir_deleted` | `Directory deleted` | `ディレクトリを削除しました` |
| `irreversible` | `This cannot be undone` | `この操作は取り消せません` |

---

## Safety Constraints

- `rm -rf` is only executed when `$ws_path` starts with the expanded `WorkingProjects/` path
- Two-step confirmation: mode picker → explicit [y/N] prompt
- On Esc (empty fzf selection), returns to sub-menu without any action
- `cmd_forget` (the `cw forget` CLI command) is unchanged in this iteration

---

## No New Files

All changes fit within the two existing files.

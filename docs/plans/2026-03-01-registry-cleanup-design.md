# Design: Registry Cleanup

**Date**: 2026-03-01
**Scope**: Add a "Cleanup registry" action to the main `cw` menu that removes entries for directories no longer present on disk.

---

## Problem

The registry (`~/.claude-workspace/registry.json`) accumulates stale entries when workspace directories are deleted or moved outside of `cw`. These appear as `[missing]` in the menu but there is no way to remove them all at once — only one-by-one via Forget.

---

## Goal

Add a `Cleanup registry` entry to the main workspace menu. Selecting it scans the registry for entries whose directory no longer exists, shows the list, and (after y/N confirmation) removes them all in one operation.

---

## UX Flow

```
Main menu (fzf / numbered):
  + Create new Workspace
  ~ Cleanup registry          ← new
  workspace-a  (5 min ago)
  workspace-b  [missing]
  workspace-c

↓ Select "Cleanup registry"

  ─────────────────────────────────
  (case: 0 missing entries)
    Info: "Registry is clean -- no missing entries"
    → back to main menu

  (case: N missing entries)
    Warn: "N missing entries found:"

      ✗  workspace-b   /path/to/workspace-b
      ✗  my-old-proj   /path/to/my-old-proj

    read [y/N]:
      y → registry_remove each → success "N entries removed"
            → rebuild list → back to main menu
      N → info "Cancelled" → back to main menu
  ─────────────────────────────────
```

---

## Files to Change

| File | Change |
|------|--------|
| `lib/menu.sh` | Add `CLEANUP` special entry in `_menu_fzf_pick` and `_menu_numbered_pick`; handle `CLEANUP` case in `cmd_menu`; add `_menu_cleanup` function |
| `lib/i18n.sh` | Add 4 new translation keys |

---

## `_menu_cleanup` Implementation Design

```bash
_menu_cleanup() {
  # Scan registry for missing paths
  local missing_paths=()
  local missing_names=()

  local ws_list
  ws_list=$(registry_list)

  while IFS= read -r ws; do
    local name path
    name=$(echo "$ws" | jq -r '.name')
    path=$(echo "$ws" | jq -r '.path')
    if [[ ! -d "$path" ]]; then
      missing_paths+=("$path")
      missing_names+=("$name")
    fi
  done < <(echo "$ws_list" | jq -c '.[]' 2>/dev/null)

  if [[ ${#missing_paths[@]} -eq 0 ]]; then
    echo ""
    info "$(t "cleanup_none")"
    echo ""
    return
  fi

  # Show list
  echo ""
  warn "${#missing_paths[@]} $(t "cleanup_found")"
  echo ""
  local i
  for i in "${!missing_paths[@]}"; do
    echo "  $(red "✗")  ${missing_names[$i]}  $(dim "${missing_paths[$i]}")"
  done
  echo ""
  read -rp "  $(t "continue") [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    local path
    for path in "${missing_paths[@]+${missing_paths[@]}}"; do
      registry_remove "$path"
    done
    success "${#missing_paths[@]} $(t "cleanup_done")"
    echo ""
  else
    info "$(t "cancel")"
  fi
}
```

### Changes to `cmd_menu`

After the `CREATE_NEW` block, add:

```bash
    if [[ "$selected_path" == "CLEANUP" ]]; then
      _menu_cleanup
      _cw_menu_build_list
      continue
    fi
```

### Changes to `_menu_fzf_pick`

Add after the `CREATE_NEW` entry line:

```bash
fzf_entries+=$'CLEANUP\t'$(t "menu_cleanup")$'\n'
```

### Changes to `_menu_numbered_pick`

In the footer section (alongside `[N]` and `[Q]`), add:

```bash
echo "  [C] $(t "menu_cleanup")" >&2
```

And in the `case` statement:

```bash
    [Cc]) echo "CLEANUP" ;;
```

---

## New i18n Keys (4)

| Key | English | Japanese |
|-----|---------|----------|
| `menu_cleanup` | `Cleanup registry` | `レジストリをクリーンアップ` |
| `cleanup_none` | `Registry is clean -- no missing entries` | `クリーンアップ不要: missing エントリはありません` |
| `cleanup_found` | `missing entries found` | `件の missing エントリが見つかりました` |
| `cleanup_done` | `entries removed` | `件を削除しました` |

Usage pattern with count prefix:
- `"${count} $(t "cleanup_found")"` → "3 missing entries found" / "3件の missing エントリが見つかりました"
- `"${count} $(t "cleanup_done")"` → "3 entries removed" / "3件を削除しました"

---

## Safety Constraints

- Only operates on the registry (no `rm -rf`)
- Confirmation required before any deletion
- Empty registry / no missing entries → no-op with info message
- Cancellation always available

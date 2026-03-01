# Registry Cleanup — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Cleanup registry" action to the main cw menu that removes all registry entries whose workspace directory no longer exists on disk.

**Architecture:** Two files change — `lib/i18n.sh` gets 4 new translation keys, and `lib/menu.sh` gets a new `_menu_cleanup` function plus small additions to `_menu_fzf_pick`, `_menu_numbered_pick`, and `cmd_menu`. The special token `CLEANUP` is handled the same way `CREATE_NEW` is already handled.

**Tech Stack:** Bash 3.2+, jq, fzf (optional), existing `registry_list`, `registry_remove`, `warn`, `info`, `success`, `red`, `dim` helpers.

---

## Reference

Design doc: `docs/plans/2026-03-01-registry-cleanup-design.md`
Source repo: `~/Developer/claude-workspace/`
Deployed copy: `~/.claude-workspace/lib/`

### Key patterns already in `lib/menu.sh`

- `CREATE_NEW` — special token returned from pickers, handled in `cmd_menu` before workspace-specific logic
- `_menu_fzf_pick()` — builds tab-separated fzf input; first column is the token, second column is the display text
- `_menu_numbered_pick()` — ALL UI output uses `>&2`; only return value goes to stdout
- `cmd_menu()` — `while true` loop; `continue` = back to main list, `return` = exit

---

## Task 1: Add 4 i18n keys to `lib/i18n.sh`

**Files:**
- Modify: `lib/i18n.sh` (ja section ~line 172, en section ~line 337)

### Step 1: Locate insertion points

In the **ja section**, find the last forget key (currently after `menu_action_back`):
```bash
        "irreversible") echo "この操作は取り消せません" ;;
```
Insert the 4 new ja keys immediately after it.

In the **en section**, find the last forget key:
```bash
        "irreversible") echo "This cannot be undone" ;;
```
Insert the 4 new en keys immediately after it.

### Step 2: Insert in the ja section (after `irreversible` ja line)

```bash
        "menu_cleanup") echo "レジストリをクリーンアップ" ;;
        "cleanup_none") echo "クリーンアップ不要: missing エントリはありません" ;;
        "cleanup_found") echo "件の missing エントリが見つかりました" ;;
        "cleanup_done") echo "件を削除しました" ;;
```

### Step 3: Insert in the en section (after `irreversible` en line)

```bash
        "menu_cleanup") echo "Cleanup registry" ;;
        "cleanup_none") echo "Registry is clean -- no missing entries" ;;
        "cleanup_found") echo "missing entries found" ;;
        "cleanup_done") echo "entries removed" ;;
```

### Step 4: Verify syntax

```bash
bash -n ~/Developer/claude-workspace/lib/i18n.sh
```
Expected: no output.

### Step 5: Verify keys render

```bash
cd ~/Developer/claude-workspace
source lib/utils.sh && source lib/i18n.sh
t "menu_cleanup"    # Expected: Cleanup registry
t "cleanup_none"    # Expected: Registry is clean -- no missing entries
t "cleanup_found"   # Expected: missing entries found
t "cleanup_done"    # Expected: entries removed
```

### Step 6: Deploy

```bash
cp ~/Developer/claude-workspace/lib/i18n.sh ~/.claude-workspace/lib/i18n.sh
```

### Step 7: Commit

```bash
cd ~/Developer/claude-workspace
git add lib/i18n.sh
git commit -m "feat(i18n): add 4 keys for registry-cleanup feature"
```

---

## Task 2: Extend `lib/menu.sh` with cleanup support

**Files:**
- Modify: `lib/menu.sh` — 4 changes (fzf picker, numbered picker, cmd_menu dispatch, new function)

### Step 1: Read `lib/menu.sh` to confirm exact current content

Read the file to confirm current line numbers before making changes. Key sections to find:

1. In `_menu_fzf_pick` — the `CREATE_NEW` entry line:
   ```bash
   fzf_entries+=$'CREATE_NEW\t'"$(t "menu_create_new")"$'\n'
   ```

2. In `_menu_numbered_pick` — the footer section:
   ```bash
   echo "  $(dim "────────────────────────────────────────")" >&2
   echo "  [N] $(t "menu_create_new")" >&2
   echo "  [Q] $(t "menu_quit")" >&2
   ```
   And the `case` statement:
   ```bash
   case "$choice" in
     [Nn])
       echo "CREATE_NEW"
       ;;
     [Qq]|"")
       echo ""
       ;;
   ```

3. In `cmd_menu` — the `CREATE_NEW` block:
   ```bash
   # Create new workspace
   if [[ "$selected_path" == "CREATE_NEW" ]]; then
     cmd_new
     return
   fi
   ```

4. The end of the file (after `_menu_forget`) — to know where to append `_menu_cleanup`.

### Step 2: Add `CLEANUP` entry to `_menu_fzf_pick`

After the `CREATE_NEW` entry line, add:

```bash
  fzf_entries+=$'CLEANUP\t'"$(t "menu_cleanup")"$'\n'
```

Full context (old → new):
```bash
# OLD
  fzf_entries+=$'CREATE_NEW\t'"$(t "menu_create_new")"$'\n'

# NEW
  fzf_entries+=$'CREATE_NEW\t'"$(t "menu_create_new")"$'\n'
  fzf_entries+=$'CLEANUP\t'"$(t "menu_cleanup")"$'\n'
```

### Step 3: Add `[C]` entry to `_menu_numbered_pick`

**3a.** In the footer `echo` block, add after `[N]` and before `[Q]`:
```bash
echo "  [C] $(t "menu_cleanup")" >&2
```

Full context (old → new):
```bash
# OLD
  echo "  [N] $(t "menu_create_new")" >&2
  echo "  [Q] $(t "menu_quit")" >&2

# NEW
  echo "  [N] $(t "menu_create_new")" >&2
  echo "  [C] $(t "menu_cleanup")" >&2
  echo "  [Q] $(t "menu_quit")" >&2
```

**3b.** In the `case` statement, add after `[Nn]` and before `[Qq]`:
```bash
    [Cc])
      echo "CLEANUP"
      ;;
```

Full context (old → new):
```bash
# OLD
  case "$choice" in
    [Nn])
      echo "CREATE_NEW"
      ;;
    [Qq]|"")
      echo ""
      ;;

# NEW
  case "$choice" in
    [Nn])
      echo "CREATE_NEW"
      ;;
    [Cc])
      echo "CLEANUP"
      ;;
    [Qq]|"")
      echo ""
      ;;
```

### Step 4: Add `CLEANUP` dispatch to `cmd_menu`

After the existing `CREATE_NEW` block in `cmd_menu`, add:

```bash
    # Cleanup registry
    if [[ "$selected_path" == "CLEANUP" ]]; then
      _menu_cleanup
      _cw_menu_build_list
      continue
    fi
```

Full context (old → new):
```bash
# OLD
    # Create new workspace
    if [[ "$selected_path" == "CREATE_NEW" ]]; then
      cmd_new
      return
    fi

    # Auto-register if unregistered

# NEW
    # Create new workspace
    if [[ "$selected_path" == "CREATE_NEW" ]]; then
      cmd_new
      return
    fi

    # Cleanup registry
    if [[ "$selected_path" == "CLEANUP" ]]; then
      _menu_cleanup
      _cw_menu_build_list
      continue
    fi

    # Auto-register if unregistered
```

### Step 5: Append `_menu_cleanup` function at end of file

After the `_menu_forget` function (the last function in the file), append:

```bash
# ──────────────────────────────
# Cleanup registry: remove entries for missing directories
# ──────────────────────────────
_menu_cleanup() {
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

### Step 6: Verify syntax

```bash
bash -n ~/Developer/claude-workspace/lib/menu.sh
```
Expected: no output.

### Step 7: Manual smoke test

**Test A — no missing entries:**

```bash
cw
# Select "Cleanup registry"
# Expected: "Registry is clean -- no missing entries"
# Expected: returns to main menu
```

**Test B — with a missing entry:**

```bash
# Create a temp workspace directory and register it
mkdir -p /tmp/cw_cleanup_test
cd /tmp/cw_cleanup_test
cw setup   # name: cleanup-test, press Enter through prompts
cd ~
# Now delete the directory
rm -rf /tmp/cw_cleanup_test
# Run cw — the entry should show [missing]
cw
# Select "Cleanup registry"
# Expected: list shows "✗  cleanup-test  /tmp/cw_cleanup_test"
# Type y
# Expected: "1 entries removed"
# Expected: returns to main menu without the missing entry
```

**Test C — cancel:**

```bash
# (create another missing entry as above)
cw
# Select "Cleanup registry"
# Type N (or Enter)
# Expected: "Cancelled" and returns to main menu
# Expected: the entry is still in the registry
```

### Step 8: Deploy

```bash
cp ~/Developer/claude-workspace/lib/menu.sh ~/.claude-workspace/lib/menu.sh
```

### Step 9: Commit

```bash
cd ~/Developer/claude-workspace
git add lib/menu.sh
git commit -m "feat(menu): add Cleanup registry action to main menu"
```

---

## Task 3: Update CHANGELOG

**Files:**
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/CHANGELOG_ja.md`

### Step 1: Add entry to `docs/CHANGELOG.md` under `[Unreleased] → Added`

Append to the existing `### Added` section:

```markdown
- "Cleanup registry" action in the main menu removes all registry entries whose workspace directory no longer exists on disk. Shows the list before confirming.
```

### Step 2: Add entry to `docs/CHANGELOG_ja.md` under `[Unreleased] → 追加`

```markdown
- メインメニューに「レジストリをクリーンアップ」アクションを追加。ディレクトリが存在しなくなった missing エントリをまとめて削除できる。実行前に削除対象の一覧を表示して確認する。
```

### Step 3: Commit

```bash
cd ~/Developer/claude-workspace
git add docs/CHANGELOG.md docs/CHANGELOG_ja.md
git commit -m "docs: update CHANGELOG for registry-cleanup feature"
```

# Forget with Directory Deletion — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend `_menu_forget` in the interactive menu to let users delete the workspace directory (`rm -rf`) in addition to registry removal, restricted to `WorkingProjects/` subdirectories.

**Architecture:** Two files change — `lib/i18n.sh` gets 6 new translation keys, and `_menu_forget` in `lib/menu.sh` is replaced with a new implementation that first shows a fzf (or numbered) mode picker, then a destructive-deletion confirmation. No new files are created.

**Tech Stack:** Bash 3.2+, fzf (optional; numbered fallback provided), existing `expand_path`, `registry_remove`, `warn`, `error`, `success`, `info`, `dim` utilities.

---

## Reference

Design doc: `docs/plans/2026-03-01-forget-delete-dir-design.md`
Source repo: `~/Developer/claude-workspace/`
Deployed copy: `~/.claude-workspace/lib/` (deploy manually after each task)

### Helper functions available in scope of `_menu_forget`

| Symbol | Source |
|--------|--------|
| `t "key"` | `lib/i18n.sh` |
| `registry_remove "$path"` | `lib/registry.sh` |
| `expand_path "$path"` | `lib/utils.sh` |
| `warn / error / success / info / dim` | `lib/utils.sh` |
| `WORKING_PROJECTS_DIR` env var | Defaults to `$HOME/WorkingProjects` |

---

## Task 1: Add 6 i18n keys to `lib/i18n.sh`

**Files:**
- Modify: `lib/i18n.sh:159-166` (ja section — after `menu_action_back`)
- Modify: `lib/i18n.sh:318-325` (en section — after `menu_action_back`)

### Step 1: Open `lib/i18n.sh` and locate insertion points

In the **ja** section, find:
```bash
        "menu_action_back") echo "← 戻る" ;;
```
(currently around line 166)

In the **en** section, find:
```bash
        "menu_action_back") echo "← Back" ;;
```
(currently around line 325)

### Step 2: Insert 6 keys after `menu_action_back` in the ja section

After `"menu_action_back") echo "← 戻る" ;;`, add:

```bash
        "forget_mode_registry") echo "レジストリのみ削除" ;;
        "forget_mode_delete") echo "ディレクトリを削除" ;;
        "forget_delete_confirm") echo "このディレクトリを完全に削除します" ;;
        "forget_delete_outside_wp") echo "WorkingProjects/ 外のディレクトリは削除できません" ;;
        "forget_dir_deleted") echo "ディレクトリを削除しました" ;;
        "irreversible") echo "この操作は取り消せません" ;;
```

### Step 3: Insert 6 keys after `menu_action_back` in the en section

After `"menu_action_back") echo "← Back" ;;`, add:

```bash
        "forget_mode_registry") echo "Registry only" ;;
        "forget_mode_delete") echo "Delete directory" ;;
        "forget_delete_confirm") echo "Permanently delete this directory" ;;
        "forget_delete_outside_wp") echo "Directory is outside WorkingProjects/ -- cannot delete" ;;
        "forget_dir_deleted") echo "Directory deleted" ;;
        "irreversible") echo "This cannot be undone" ;;
```

### Step 4: Verify keys render correctly

```bash
cd ~/Developer/claude-workspace
source lib/utils.sh
source lib/i18n.sh

# Test en keys
t "forget_mode_registry"    # Expected: Registry only
t "forget_mode_delete"      # Expected: Delete directory
t "forget_delete_confirm"   # Expected: Permanently delete this directory
t "forget_delete_outside_wp" # Expected: Directory is outside WorkingProjects/ -- cannot delete
t "forget_dir_deleted"      # Expected: Directory deleted
t "irreversible"            # Expected: This cannot be undone
```

To test ja keys, temporarily set `CW_DIR` to a dir containing a `lang` file with `ja`:

```bash
mkdir -p /tmp/cw-test-lang && echo "ja" > /tmp/cw-test-lang/lang
CW_DIR=/tmp/cw-test-lang source lib/i18n.sh

t "forget_mode_registry"    # Expected: レジストリのみ削除
t "forget_mode_delete"      # Expected: ディレクトリを削除
t "irreversible"            # Expected: この操作は取り消せません
```

### Step 5: Deploy to `~/.claude-workspace/lib/`

```bash
cp ~/Developer/claude-workspace/lib/i18n.sh ~/.claude-workspace/lib/i18n.sh
```

### Step 6: Commit

```bash
cd ~/Developer/claude-workspace
git add lib/i18n.sh
git commit -m "feat(i18n): add 6 keys for forget-with-directory-deletion"
```

---

## Task 2: Rewrite `_menu_forget` in `lib/menu.sh`

**Files:**
- Modify: `lib/menu.sh:393-409` (replace entire `_menu_forget` function)

### Step 1: Locate the existing function

In `lib/menu.sh`, find the block starting at (approximately) line 393:

```bash
_menu_forget() {
  local ws_path="$1"
  local ws_name="$2"

  echo ""
  warn "\"${ws_name}\" $(t "remove_from_registry")"
  ...
}
```

### Step 2: Replace the entire `_menu_forget` function

Delete lines 393-409 and replace with the following complete implementation.

**Full replacement:**

```bash
# ──────────────────────────────
# Forget workspace (no pwd dependency)
# ──────────────────────────────
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
    # Numbered fallback (output to stderr to avoid stdout pollution)
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

  [[ -z "$mode" ]] && return  # Esc -> back to sub-menu

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

### Step 3: Verify the function is syntactically valid

```bash
bash -n ~/Developer/claude-workspace/lib/menu.sh
```

Expected: no output (no syntax errors).

### Step 4: Manual smoke test — Registry only path

Prerequisites: have at least one workspace registered in the registry.

```bash
# Run the full menu
cw
```

1. Select any workspace
2. Choose "✗ Forget" (or equivalent label)
3. Verify fzf (or numbered menu) appears with two options: "Registry only" and "Delete directory"
4. Select "Registry only"
5. Confirm with `y`
6. Verify workspace is removed from registry: `cw list`
7. Verify the directory still exists on disk

### Step 5: Manual smoke test — Delete directory (inside WorkingProjects/)

Create a throwaway workspace:

```bash
mkdir -p ~/WorkingProjects/_cw_test_delete
cd ~/WorkingProjects/_cw_test_delete
cw setup   # follow prompts, name it "_cw_test_delete"
cd ~
cw
```

1. Select `_cw_test_delete` workspace
2. Choose "✗ Forget"
3. Select "Delete directory"
4. Confirm with `y`
5. Verify workspace is removed from registry AND directory is gone:

```bash
cw list | grep _cw_test_delete   # Expected: no output
ls ~/WorkingProjects/_cw_test_delete 2>&1  # Expected: "No such file or directory"
```

### Step 6: Manual smoke test — Delete directory (outside WorkingProjects/)

This test verifies the safety guard. Add a workspace from outside `WorkingProjects/`:

```bash
mkdir -p /tmp/cw_outside_test
cd /tmp/cw_outside_test
cw setup   # name it "outside-test"
cd ~
cw
```

1. Select `outside-test` workspace
2. Choose "✗ Forget"
3. Select "Delete directory"
4. Expected: error message "Directory is outside WorkingProjects/ — cannot delete" displayed
5. Verify you are returned to sub-menu (no deletion, no crash)

### Step 7: Deploy to `~/.claude-workspace/lib/`

```bash
cp ~/Developer/claude-workspace/lib/menu.sh ~/.claude-workspace/lib/menu.sh
```

### Step 8: Commit

```bash
cd ~/Developer/claude-workspace
git add lib/menu.sh
git commit -m "feat(menu): extend _menu_forget with directory deletion option"
```

---

## Task 3: Final integration check and CHANGELOG update

### Step 1: Run full integration test with deployed binary

```bash
cw
```

Walk through the complete Forget → Delete directory flow one more time using the deployed files (not just source) to confirm deployment is correct.

### Step 2: Update `docs/CHANGELOG.md` — add to Unreleased

Open `docs/CHANGELOG.md` and add under the existing `[Unreleased]` section:

```markdown
### Added
- `_menu_forget`: secondary mode picker (fzf or numbered) lets users choose between
  "Registry only" (previous behavior) and "Delete directory" (`rm -rf`, restricted
  to `WorkingProjects/` subdirectories only). Includes safety guard and two-step
  destructive confirmation.
- 6 new i18n keys for the forget-with-directory-deletion flow (`forget_mode_registry`,
  `forget_mode_delete`, `forget_delete_confirm`, `forget_delete_outside_wp`,
  `forget_dir_deleted`, `irreversible`).
```

### Step 3: Update `docs/CHANGELOG_ja.md` — add to Unreleased

```markdown
### 追加
- `_menu_forget`: fzf（またはナンバー選択）でモードを選択可能に。「レジストリのみ削除」（従来の動作）と
  「ディレクトリを削除」（`rm -rf`、`WorkingProjects/` 配下のみ対象）を選べる。
  安全ガード（パスチェック）と二段階の破壊的操作確認付き。
- forget with directory deletion フロー用の i18n キーを 6 件追加（`forget_mode_registry`、
  `forget_mode_delete`、`forget_delete_confirm`、`forget_delete_outside_wp`、
  `forget_dir_deleted`、`irreversible`）。
```

### Step 4: Commit CHANGELOG updates

```bash
cd ~/Developer/claude-workspace
git add docs/CHANGELOG.md docs/CHANGELOG_ja.md
git commit -m "docs: update CHANGELOG for forget-with-directory-deletion feature"
```

---

## Quick Reference: Safety Constraints

| Constraint | Where enforced |
|-----------|---------------|
| `rm -rf` only inside `WorkingProjects/` | `_menu_forget` path prefix check |
| Two-step confirmation | Mode picker → [y/N] prompt |
| Esc/empty fzf → return to sub-menu (no action) | `[[ -z "$mode" ]] && return` |
| `cmd_forget` (CLI) unchanged | Not touched in this plan |

# cw Interactive Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the cw menu with a fully interactive fzf-based menu where all workspace operations (Resume, Add Dir, Info, Open in Finder, Forget, Back) complete within a single CLI session.

**Architecture:** Rewrite `lib/menu.sh` with fzf for workspace selection (with right-side preview) and a sub-menu for per-workspace actions. Change `bin/cw`'s `""` case to always call `cmd_menu`. Add i18n keys for new sub-menu labels. All existing commands (`cmd_launch`, `cmd_add_dir`, `cmd_info`) are reused via `cd <path>` before calling them.

**Tech Stack:** bash, fzf, jq (all already in use)

---

## Task 1: Fix `((valid_count++))` bug in source `lib/launch.sh`

The deployed `~/.claude-workspace/lib/launch.sh` was already patched, but the source file needs the same fix.

**Files:**
- Modify: `lib/launch.sh:52`

**Step 1: Open `lib/launch.sh` and locate line 52**

```bash
# Current (buggy with set -euo pipefail):
      ((valid_count++))

# Fixed:
      valid_count=$((valid_count + 1))
```

**Step 2: Apply the change**

In `lib/launch.sh`, replace:
```bash
      ((valid_count++))
```
with:
```bash
      valid_count=$((valid_count + 1))
```

**Step 3: Verify manually**

```bash
grep -n "valid_count" lib/launch.sh
# Expected: line 40: local valid_count=0
#           line 52: valid_count=$((valid_count + 1))
```

**Step 4: Commit**

```bash
git add lib/launch.sh
git commit -m "fix(launch): use arithmetic expansion to avoid set -e exit on ((valid_count++))"
```

---

## Task 2: Add i18n keys for sub-menu actions

**Files:**
- Modify: `lib/i18n.sh`

New keys needed (add to both `ja` and `en` sections under `# === Menu ===`):

| Key | English | Japanese |
|-----|---------|----------|
| `press_enter` | `Press Enter to continue` | `Enter で続ける` |
| `menu_action_resume` | `▶ Resume` | `▶ 起動` |
| `menu_action_add_dir` | `+ Add Dir` | `+ ディレクトリを追加` |
| `menu_action_info` | `ℹ Info` | `ℹ 詳細情報` |
| `menu_action_finder` | `⊙ Open in Finder` | `⊙ Finder で開く` |
| `menu_action_forget` | `✗ Forget` | `✗ レジストリから削除` |
| `menu_action_back` | `← Back` | `← 戻る` |

**Step 1: Add to `ja` section** (after `"menu_quit"` line, around line 159)

```bash
        "press_enter") echo "Enter で続ける" ;;
        "menu_action_resume") echo "▶ 起動" ;;
        "menu_action_add_dir") echo "+ ディレクトリを追加" ;;
        "menu_action_info") echo "ℹ 詳細情報" ;;
        "menu_action_finder") echo "⊙ Finder で開く" ;;
        "menu_action_forget") echo "✗ レジストリから削除" ;;
        "menu_action_back") echo "← 戻る" ;;
```

**Step 2: Add to `en` section** (after `"menu_quit"` line, around line 311)

```bash
        "press_enter") echo "Press Enter to continue" ;;
        "menu_action_resume") echo "▶ Resume" ;;
        "menu_action_add_dir") echo "+ Add Dir" ;;
        "menu_action_info") echo "ℹ Info" ;;
        "menu_action_finder") echo "⊙ Open in Finder" ;;
        "menu_action_forget") echo "✗ Forget" ;;
        "menu_action_back") echo "← Back" ;;
```

**Step 3: Verify**

```bash
source lib/utils.sh && source lib/i18n.sh
t "menu_action_resume"   # → ▶ Resume
t "press_enter"           # → Press Enter to continue
```

**Step 4: Commit**

```bash
git add lib/i18n.sh
git commit -m "feat(i18n): add sub-menu action keys and press_enter"
```

---

## Task 3: Change `bin/cw` to always show menu

**Files:**
- Modify: `bin/cw:127-133`

**Step 1: Replace the `""` case in `main()`**

Current code (lines 127-133):
```bash
    "")
      if is_workspace "$(pwd)"; then
        cmd_launch
      else
        cmd_menu
      fi
      ;;
```

Replace with:
```bash
    "")
      cmd_menu
      ;;
```

**Step 2: Update the usage string** (line 28 area) to reflect new behavior:

```bash
  cw                    $(t "usage_launch_or_menu")
```

Change `usage_launch_or_menu` i18n key in `lib/i18n.sh`:
- English: `Show workspace menu`
- Japanese: `ワークスペースメニューを表示`

**Step 3: Verify syntax**

```bash
bash -n bin/cw
# Expected: no output (syntax OK)
```

**Step 4: Commit**

```bash
git add bin/cw lib/i18n.sh
git commit -m "feat(menu): always show interactive menu on bare cw invocation"
```

---

## Task 4: Rewrite `cmd_menu` with fzf + preview

**Files:**
- Modify: `lib/menu.sh` (replace entire `cmd_menu` function)

**Step 1: Replace `cmd_menu` with the fzf implementation**

Replace the entire `cmd_menu()` function body (keeping the function signature) with:

```bash
cmd_menu() {
  require_jq

  # ──────────────────────────────
  # Build workspace list (registry first, then filesystem)
  # ──────────────────────────────
  local menu_paths=()
  local menu_names=()
  local menu_times=()
  local menu_registered=()

  local ws_list
  ws_list=$(registry_list)

  while IFS= read -r ws; do
    local name path last_used
    name=$(echo "$ws" | jq -r '.name')
    path=$(echo "$ws" | jq -r '.path')
    last_used=$(echo "$ws" | jq -r '.last_used // ""')
    menu_paths+=("$path")
    menu_names+=("$name")
    menu_times+=("$last_used")
    menu_registered+=("true")
  done < <(echo "$ws_list" | jq -c '.[]' 2>/dev/null)

  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_dir ws_name
      ws_dir=$(dirname "$ws_file")
      ws_name=$(ws_get "$ws_file" '.name')
      local already=false
      for p in "${menu_paths[@]+"${menu_paths[@]}"}"; do
        [[ "$p" == "$ws_dir" ]] && already=true && break
      done
      $already && continue
      menu_paths+=("$ws_dir")
      menu_names+=("$ws_name")
      menu_times+=("")
      menu_registered+=("false")
    done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null | sort)
  fi

  # ──────────────────────────────
  # Launch fzf or fallback
  # ──────────────────────────────
  if command -v fzf &>/dev/null; then
    _menu_fzf menu_paths menu_names menu_times menu_registered
  else
    _menu_numbered menu_paths menu_names menu_times menu_registered
  fi
}
```

**Step 2: Verify syntax**

```bash
bash -n lib/menu.sh
# Expected: no output
```

---

## Task 5: Add `_menu_fzf` function (fzf main menu)

**Files:**
- Modify: `lib/menu.sh` (add after `cmd_menu`)

**Step 1: Add `_menu_fzf` function**

```bash
# fzf-based workspace picker
# Arguments: arrays passed by name (bash 4.3+ nameref pattern via eval)
_menu_fzf() {
  local -n _paths=$1
  local -n _names=$2
  local -n _times=$3
  local -n _registered=$4

  # Build tab-separated input: PATH\tDISPLAY
  local fzf_entries=""
  fzf_entries+=$'CREATE_NEW\t'"$(t "menu_create_new")"$'\n'

  local idx
  for idx in "${!_paths[@]}"; do
    local path="${_paths[$idx]}"
    local name="${_names[$idx]}"
    local last_used="${_times[$idx]}"
    local reg="${_registered[$idx]}"

    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    local unreg_label=""
    [[ "$reg" == "false" ]] && unreg_label="  $(yellow "[unregistered]")"

    local status_label=""
    [[ ! -d "$path" ]] && status_label="  $(red "[missing]")"

    fzf_entries+="${path}"$'\t'"${name}${time_label}${unreg_label}${status_label}"$'\n'
  done

  # Preview script: reads {1}/.workspace.json
  local preview_script
  preview_script=$(cat <<'PREVIEW'
ws_path={1}
ws_file="${ws_path}/.workspace.json"
if [[ "$ws_path" == "CREATE_NEW" ]]; then
  echo ""
  echo "  Create a new Claude Workspace"
  echo ""
  echo "  A new directory will be created under"
  echo "  ~/WorkingProjects/ and set up for cw."
elif [[ -f "$ws_file" ]]; then
  name=$(jq -r '.name // ""' "$ws_file" 2>/dev/null)
  desc=$(jq -r '.description // ""' "$ws_file" 2>/dev/null)
  created=$(jq -r '.created_at // ""' "$ws_file" 2>/dev/null)
  dir_count=$(jq '.dirs | length' "$ws_file" 2>/dev/null || echo 0)
  echo ""
  echo "  $name"
  [[ -n "$desc" ]] && echo "  $desc"
  echo ""
  echo "  $ws_path"
  echo "  Dirs: $dir_count    Created: ${created:0:10}"
  echo ""
  jq -r '.dirs[] | "  + " + (if .role != "" and .role != null then .role else (.path | split("/") | last) end) + "  \(.path)"' "$ws_file" 2>/dev/null | while IFS= read -r line; do
    dir_path=$(echo "$line" | grep -o '/[^ ]*$' || true)
    if [[ -n "$dir_path" && -d "$dir_path" ]]; then
      echo "  ✓ ${line#  + }"
    else
      echo "  ✗ ${line#  + }"
    fi
  done
else
  echo ""
  echo "  (no .workspace.json found)"
  echo "  $ws_path"
fi
PREVIEW
)

  local selected
  selected=$(printf '%s' "$fzf_entries" | \
    fzf --ansi \
        --height=70% --border \
        --delimiter=$'\t' \
        --with-nth='2..' \
        --header="  claude-workspace (cw)" \
        --header-first \
        --preview="$preview_script" \
        --preview-window='right:45%:wrap' \
        --prompt='  Workspace > ' \
        2>/dev/null || true)

  [[ -z "$selected" ]] && { echo ""; info "$(t "cmd_quit")"; return 0; }

  local selected_path
  selected_path=$(printf '%s' "$selected" | cut -f1)

  if [[ "$selected_path" == "CREATE_NEW" ]]; then
    cmd_new
    return
  fi

  # Auto-register if unregistered
  local sel_idx
  for sel_idx in "${!_paths[@]}"; do
    if [[ "${_paths[$sel_idx]}" == "$selected_path" ]]; then
      if [[ "${_registered[$sel_idx]}" == "false" ]]; then
        local sel_name="${_names[$sel_idx]}"
        registry_add "$sel_name" "$selected_path"
        success "$(t "registered"): $sel_name"
      fi
      break
    fi
  done

  if [[ ! -d "$selected_path" ]]; then
    error "$(t "dir_not_found"): $selected_path"
    exit 1
  fi

  local selected_name
  selected_name=$(jq -r '.name' "${selected_path}/${WORKSPACE_FILE}" 2>/dev/null)

  _menu_submenu "$selected_path" "$selected_name"
}
```

**Step 2: Verify syntax**

```bash
bash -n lib/menu.sh
```

---

## Task 6: Add `_menu_submenu` function

**Files:**
- Modify: `lib/menu.sh` (add after `_menu_fzf`)

**Step 1: Add `_menu_submenu` function**

```bash
# Sub-menu for a selected workspace
# Arguments: <ws_path> <ws_name>
_menu_submenu() {
  local ws_path="$1"
  local ws_name="$2"

  local actions
  actions=$(printf '%s\n' \
    "$(t "menu_action_resume")" \
    "$(t "menu_action_add_dir")" \
    "$(t "menu_action_info")" \
    "$(t "menu_action_finder")" \
    "$(t "menu_action_forget")" \
    "$(t "menu_action_back")")

  local action
  action=$(printf '%s\n' "$actions" | \
    fzf --height=40% --border \
        --header="  $ws_name" \
        --header-first \
        --prompt='  Action > ' \
        2>/dev/null || true)

  [[ -z "$action" ]] && cmd_menu && return

  local resume_label add_dir_label info_label finder_label forget_label back_label
  resume_label=$(t "menu_action_resume")
  add_dir_label=$(t "menu_action_add_dir")
  info_label=$(t "menu_action_info")
  finder_label=$(t "menu_action_finder")
  forget_label=$(t "menu_action_forget")
  back_label=$(t "menu_action_back")

  if [[ "$action" == "$resume_label" ]]; then
    cd "$ws_path"
    cmd_launch

  elif [[ "$action" == "$add_dir_label" ]]; then
    cd "$ws_path"
    cmd_add_dir
    _menu_submenu "$ws_path" "$ws_name"

  elif [[ "$action" == "$info_label" ]]; then
    cd "$ws_path"
    cmd_info
    echo ""
    read -rp "  $(t "press_enter"): " _ignored
    _menu_submenu "$ws_path" "$ws_name"

  elif [[ "$action" == "$finder_label" ]]; then
    open "$ws_path"
    _menu_submenu "$ws_path" "$ws_name"

  elif [[ "$action" == "$forget_label" ]]; then
    _menu_forget "$ws_path" "$ws_name"

  elif [[ "$action" == "$back_label" ]]; then
    cmd_menu
  fi
}
```

**Step 2: Verify syntax**

```bash
bash -n lib/menu.sh
```

---

## Task 7: Add `_menu_forget` helper and fallback `_menu_numbered`

**Files:**
- Modify: `lib/menu.sh` (add remaining helpers)

**Step 1: Add `_menu_forget`**

```bash
# Forget a workspace from the menu context (does not rely on pwd)
# Arguments: <ws_path> <ws_name>
_menu_forget() {
  local ws_path="$1"
  local ws_name="$2"

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
  cmd_menu
}
```

**Step 2: Add `_menu_numbered` (no-fzf fallback)**

This is the existing numbered menu logic, now used only when fzf is unavailable. Paste the old `cmd_menu` body (the numbered list + read -rep section) here, but with workspace selection going to `_menu_submenu` instead of directly to `cmd_launch`.

Key change in the selection handler:
```bash
# OLD (direct launch):
cd "$selected_path"
cmd_launch

# NEW (show sub-menu):
_menu_submenu "$selected_path" "$selected_name"
```

Full `_menu_numbered` function:

```bash
# Numbered fallback menu when fzf is unavailable
_menu_numbered() {
  local -n _paths=$1
  local -n _names=$2
  local -n _times=$3
  local -n _registered=$4

  echo ""
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(bold "  claude-workspace (cw)")"
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"

  if [[ ${#_paths[@]} -eq 0 ]]; then
    echo ""
    info "$(t "workspace_not_found")"
    echo ""
    _menu_prompt_new
    return
  fi

  echo ""
  echo "  $(bold "$(t "menu_recent")")"
  echo ""

  local i=0
  for idx in "${!_paths[@]}"; do
    local path="${_paths[$idx]}"
    local name="${_names[$idx]}"
    local last_used="${_times[$idx]}"
    local registered="${_registered[$idx]}"
    i=$((i + 1))

    local status_marker=""
    [[ ! -d "$path" ]] && status_marker="  $(red "✗ $(t "path_missing")")"
    [[ "$path" == "$(pwd)" ]] && status_marker="  $(green "← $(t "current_location")")"

    local unreg_label=""
    [[ "$registered" == "false" ]] && unreg_label="  $(yellow "$(t "unregistered")")"

    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    printf "  [%d] $(bold "%s")%s%s%s\n" "$i" "$name" "$time_label" "$unreg_label" "$status_marker"
    printf "      $(dim "%s")\n" "$path"
    echo ""
  done

  echo "  $(dim "────────────────────────────────────────")"
  echo "  [N] $(t "menu_create_new")"
  echo "  [Q] $(t "menu_quit")"
  echo ""

  local choice
  read -rep "  $(t "cmd_select") [1-${i} / N / Q]: " choice
  echo ""

  case "$choice" in
    [Nn]) cmd_new ;;
    [Qq]|"") info "$(t "cmd_quit")"; exit 0 ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && \
         [[ $choice -ge 1 ]] && \
         [[ $choice -le ${#_paths[@]} ]]; then

        local sel_idx=$(( choice - 1 ))
        local selected_path="${_paths[$sel_idx]}"
        local selected_name="${_names[$sel_idx]}"
        local selected_reg="${_registered[$sel_idx]}"

        if [[ ! -d "$selected_path" ]]; then
          error "$(t "dir_not_found"): $selected_path"
          exit 1
        fi

        if [[ "$selected_reg" == "false" ]]; then
          registry_add "$selected_name" "$selected_path"
          success "$(t "registered"): $selected_name"
        fi

        _menu_submenu "$selected_path" "$selected_name"
      else
        error "$(t "invalid"): $choice"
        exit 1
      fi
      ;;
  esac
}
```

**Step 3: Remove the old `_menu_prompt_new` function** if it's still present — it's only used by `_menu_numbered` now, so keep it. Actually keep it as-is.

**Step 4: Verify syntax**

```bash
bash -n lib/menu.sh
```

**Step 5: Commit**

```bash
git add lib/menu.sh
git commit -m "feat(menu): rewrite with fzf preview + workspace sub-menu (Resume/Add Dir/Info/Finder/Forget/Back)"
```

---

## Task 8: Manual smoke test

**Step 1: Run syntax check on all changed files**

```bash
bash -n bin/cw lib/menu.sh lib/launch.sh lib/i18n.sh
# Expected: no output
```

**Step 2: Test i18n keys**

```bash
source lib/utils.sh && CW_DIR="$HOME/.claude-workspace" && source lib/i18n.sh
t "menu_action_resume"    # → ▶ Resume
t "menu_action_forget"    # → ✗ Forget
t "press_enter"           # → Press Enter to continue
```

**Step 3: Deploy to test**

```bash
./install.sh
# Expected: installs to /usr/local/bin/cw and ~/.claude-workspace/lib/
```

**Step 4: Run `cw` and verify**

```bash
cd /tmp && cw
# Expected: fzf menu appears with workspace list + preview pane
# - Navigate with arrow keys, preview updates
# - Select a workspace → sub-menu appears
# - Choose "← Back" → returns to main menu
# - Press Esc or choose "← Back" → "Exiting" message
```

**Step 5: Test Resume**

```
cw → select a workspace → ▶ Resume
# Expected: Claude Code launches with --add-dir flags
```

**Step 6: Test from workspace directory**

```bash
cd ~/WorkingProjects/some-workspace && cw
# Expected: same fzf menu (NOT immediate launch)
```

---

## Task 9: Final commit and update CHANGELOG

**Step 1: Update `docs/CHANGELOG.md`** — add entry under `[Unreleased]`:

```markdown
### Added
- Interactive fzf workspace menu with right-side preview pane
- Sub-menu per workspace: Resume, Add Dir, Info, Open in Finder, Forget, Back
- All workspace operations now complete within a single `cw` CLI session

### Changed
- `cw` (bare invocation) now always shows the interactive menu regardless of current directory
```

**Step 2: Commit**

```bash
git add docs/CHANGELOG.md docs/plans/
git commit -m "docs: update CHANGELOG for interactive menu feature"
```

---

## Summary

| File | Change |
|------|--------|
| `lib/launch.sh` | Fix `((valid_count++))` → `valid_count=$((valid_count + 1))` |
| `lib/i18n.sh` | Add 7 new keys for sub-menu actions + `press_enter` |
| `bin/cw` | `""` case always calls `cmd_menu` |
| `lib/menu.sh` | Full rewrite: `cmd_menu` → `_menu_fzf` + `_menu_submenu` + `_menu_forget` + `_menu_numbered` |

Estimated implementation time: 30–45 minutes.

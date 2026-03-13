# Interactive Wizard UI (gum-based) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the linear 7-step `cw setup`/`cw new` flow with a 3-phase interactive wizard using gum, with graceful fallback to existing bash prompts when gum is not installed.

**Architecture:** A new `lib/gum.sh` abstraction layer wraps all gum calls with fallbacks; `lib/setup.sh` is rewritten into 3 named phase functions (`_setup_phase1`, `_setup_phase2`, `_setup_phase3`); `lib/launch.sh` gains an optional `[dir]` argument so Phase 3 can call it directly without relying on `pwd`.

**Tech Stack:** Bash 3.2+, gum (optional, brew install gum), fzf (optional), jq (required)

**Spec:** `docs/superpowers/specs/2026-03-13-interactive-wizard-design.md`

---

## Chunk 1: Foundation — gum.sh, i18n keys, launch.sh dir arg

### Task 1: Create `lib/gum.sh` — gum abstraction layer

**Files:**
- Create: `lib/gum.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_gum.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/gum.sh"

pass=0; fail=0
ok()   { echo "  ok: $1"; ((pass++)); }
fail() { echo "FAIL: $1"; ((fail++)); }

# _gum_available: returns false when gum not in PATH
(PATH="" _gum_available 2>/dev/null) && fail "_gum_available should be false" || ok "_gum_available false when no gum"

# _fzf_available: returns false when fzf not in PATH
(PATH="" _fzf_available 2>/dev/null) && fail "_fzf_available should be false" || ok "_fzf_available false when no fzf"

# gum_input fallback: returns default when no gum
result=$(echo "" | GUM_AVAILABLE=false gum_input "Prompt" "mydefault" 2>/dev/null || true)
# fallback uses read; pipe empty string → empty → use default
# Actually just check function exists
declare -f gum_input >/dev/null && ok "gum_input defined" || fail "gum_input not defined"
declare -f gum_confirm >/dev/null && ok "gum_confirm defined" || fail "gum_confirm not defined"
declare -f gum_spin >/dev/null && ok "gum_spin defined" || fail "gum_spin not defined"
declare -f gum_error >/dev/null && ok "gum_error defined" || fail "gum_error not defined"
declare -f gum_choose >/dev/null && ok "gum_choose defined" || fail "gum_choose not defined"
declare -f gum_path_input >/dev/null && ok "gum_path_input defined" || fail "gum_path_input not defined"

# gum_spin fallback: runs command directly, propagates exit code
gum_spin "Testing" true && ok "gum_spin passes exit 0" || fail "gum_spin exit 0"
gum_spin "Testing" false && fail "gum_spin should propagate exit 1" || ok "gum_spin propagates exit 1"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_gum.sh
```
Expected: FAIL — `lib/gum.sh` does not exist yet

- [ ] **Step 3: Implement `lib/gum.sh`**

```bash
#!/usr/bin/env bash
# lib/gum.sh — gum abstraction layer with fallbacks
# Sourced by other lib/*.sh files that need interactive UI

_gum_available() { command -v gum >/dev/null 2>&1; }
_fzf_available() { command -v fzf >/dev/null 2>&1; }

# gum_input <prompt> [default]
# Prints the entered value to stdout
gum_input() {
  local prompt="${1:-Input}"
  local default="${2:-}"
  if _gum_available; then
    local result
    result=$(gum input --placeholder "${default}" --prompt "${prompt}: ")
    echo "${result:-$default}"
  else
    local result
    if [[ -n "${default}" ]]; then
      read -rep "${prompt} [${default}]: " result || true
      echo "${result:-$default}"
    else
      read -rep "${prompt}: " result || true
      echo "${result}"
    fi
  fi
}

# gum_confirm <message>
# Returns 0 for yes, 1 for no
gum_confirm() {
  local message="${1:-Continue?}"
  if _gum_available; then
    gum confirm "${message}"
  else
    local answer
    read -rep "${message} [y/N]: " answer || true
    case "$(echo "${answer}" | tr '[:upper:]' '[:lower:]')" in
      y|yes) return 0 ;;
      *)     return 1 ;;
    esac
  fi
}

# gum_spin <title> <command> [args...]
# Runs command with spinner. Propagates exit code. bash 3.2 safe.
gum_spin() {
  local title="${1}"
  shift
  if _gum_available; then
    gum spin --title "${title}" -- "$@"
  else
    "$@"
  fi
}

# gum_error <message>
# Prints styled error. Falls back to error() if defined, else echo to stderr.
gum_error() {
  local message="${1:-Error}"
  if _gum_available; then
    gum style --foreground 196 --border normal --border-foreground 196 \
      --padding "0 1" -- "${message}" >&2
  elif declare -f error >/dev/null 2>&1; then
    error "${message}"
  else
    echo "ERROR: ${message}" >&2
  fi
}

# gum_choose <label1> <value1> [<label2> <value2> ...]
# Displays a selection menu. Prints the VALUE of the chosen option to stdout.
# Must be called with an even number of arguments (label/value pairs).
gum_choose() {
  local labels=()
  local values=()
  while [[ $# -ge 2 ]]; do
    labels+=("$1")
    values+=("$2")
    shift 2
  done

  if _gum_available; then
    local chosen
    chosen=$(printf '%s\n' "${labels[@]}" | gum choose)
    local i
    for i in "${!labels[@]}"; do
      if [[ "${labels[$i]}" == "${chosen}" ]]; then
        echo "${values[$i]}"
        return 0
      fi
    done
    echo ""
  else
    # Numbered menu fallback
    local i
    for i in "${!labels[@]}"; do
      echo "  $((i+1))) ${labels[$i]}"
    done
    local answer
    read -rep "Choice [1-${#labels[@]}]: " answer || true
    local idx=$(( answer - 1 ))
    if [[ $idx -ge 0 && $idx -lt ${#values[@]} ]]; then
      echo "${values[$idx]}"
    else
      echo ""
    fi
  fi
}

# gum_path_input <prompt> [default]
# Tool-combination-aware directory selector. Prints path to stdout.
gum_path_input() {
  local prompt="${1:-Directory}"
  local default="${2:-}"
  if _gum_available && _fzf_available; then
    # gum styles the header; fzf handles directory browsing
    gum style --foreground 111 "${prompt}:"
    local selected
    selected=$(find "${HOME}" -maxdepth 4 -type d 2>/dev/null | fzf --height 40% --prompt "> " --query "${default}")
    echo "${selected:-$default}"
  elif _gum_available; then
    gum_input "${prompt}" "${default}"
  elif _fzf_available; then
    if declare -f select_dir_with_fzf >/dev/null 2>&1; then
      select_dir_with_fzf
    else
      local selected
      selected=$(find "${HOME}" -maxdepth 4 -type d 2>/dev/null | fzf --height 40% --prompt "${prompt}: " --query "${default}")
      echo "${selected:-$default}"
    fi
  else
    local result
    if [[ -n "${default}" ]]; then
      read -rep "${prompt} [${default}]: " result || true
      echo "${result:-$default}"
    else
      read -rep "${prompt}: " result || true
      echo "${result}"
    fi
  fi
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_gum.sh
```
Expected: All tests pass, 0 failed

- [ ] **Step 5: Commit**

```bash
git add lib/gum.sh tests/test_gum.sh
git commit -m "feat: add lib/gum.sh — gum abstraction layer with fallbacks"
```

---

### Task 2: Add i18n keys to `lib/i18n.sh`

**Files:**
- Modify: `lib/i18n.sh`

- [ ] **Step 1: Write failing test**

Add to `tests/test_i18n.sh` (create if not exists):

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/i18n.sh"

pass=0; fail=0
ok()    { echo "  ok: $1"; ((pass++)); }
notok() { echo "FAIL: $1"; ((fail++)); }

check_key() {
  local key="$1"
  local result
  result=$(LANG_PREF=en t "${key}" 2>/dev/null)
  [[ -n "${result}" ]] && ok "en: ${key}" || notok "en: ${key} missing"
  result=$(LANG_PREF=ja t "${key}" 2>/dev/null)
  [[ -n "${result}" ]] && ok "ja: ${key}" || notok "ja: ${key} missing"
}

check_key "phase1_header"
check_key "phase2_header"
check_key "phase3_header"
check_key "phase3_opt_launch"
check_key "phase3_opt_create"
check_key "phase3_opt_cancel"
check_key "phase3_summary"
check_key "path_add_anyway"
check_key "dirs_added_so_far"
check_key "gum_required_hint"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_i18n.sh
```
Expected: FAIL — all 10 new keys missing

- [ ] **Step 3: Add keys to `lib/i18n.sh`**

In the `en` block, add after the last existing key:

```bash
  phase1_header="Phase 1/3: Basic Info"
  phase2_header="Phase 2/3: Directories"
  phase3_header="Phase 3/3: Confirm"
  phase3_opt_launch="Create & Launch Claude"
  phase3_opt_create="Create only"
  phase3_opt_cancel="Cancel"
  phase3_summary="Summary"
  path_add_anyway="Path does not exist. Add anyway?"
  dirs_added_so_far="Added so far:"
  gum_required_hint="Install gum for a richer UI: brew install gum"
```

In the `ja` block, add after the last existing key:

```bash
  phase1_header="フェーズ 1/3: 基本情報"
  phase2_header="フェーズ 2/3: ディレクトリ"
  phase3_header="フェーズ 3/3: 確認"
  phase3_opt_launch="作成して Claude を起動"
  phase3_opt_create="作成のみ"
  phase3_opt_cancel="キャンセル"
  phase3_summary="内容確認"
  path_add_anyway="ディレクトリが存在しません。追加しますか?"
  dirs_added_so_far="追加済み:"
  gum_required_hint="より良いUIのために gum をインストール: brew install gum"
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_i18n.sh
```
Expected: All 20 checks pass, 0 failed

- [ ] **Step 5: Commit**

```bash
git add lib/i18n.sh tests/test_i18n.sh
git commit -m "feat(i18n): add wizard phase keys for gum UI"
```

---

### Task 3: Add optional `[dir]` argument to `cmd_launch` in `lib/launch.sh`

**Files:**
- Modify: `lib/launch.sh`

- [ ] **Step 1: Read current `lib/launch.sh`**

Read the file to understand `cmd_launch` current implementation before modifying.

- [ ] **Step 2: Write failing test**

Add to `tests/test_launch.sh` (create if not exists):

```bash
#!/usr/bin/env bash
set -euo pipefail
CW_LIB_DIR="$(dirname "$0")/../lib"
source "${CW_LIB_DIR}/utils.sh"
source "${CW_LIB_DIR}/i18n.sh"
source "${CW_LIB_DIR}/registry.sh"
source "${CW_LIB_DIR}/launch.sh"

pass=0; fail=0
ok()    { echo "  ok: $1"; ((pass++)); }
notok() { echo "FAIL: $1"; ((fail++)); }

# cmd_launch should accept an absolute path as $1
# We can't actually call 'claude' in tests, but we can verify
# that when given a path that doesn't exist as a workspace dir,
# it errors rather than silently proceeding
(cmd_launch "/nonexistent/path/that/does/not/exist" 2>/dev/null) \
  && notok "cmd_launch nonexistent path should fail" \
  || ok "cmd_launch rejects nonexistent absolute path"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 3: Run test to see current behavior**

```bash
bash tests/test_launch.sh
```
Note the current behavior before modification.

- [ ] **Step 4: Modify `cmd_launch` to accept optional `[dir]` argument**

At the top of `cmd_launch`, before the existing logic that reads `workspace_dir` from `pwd`, add:

```bash
cmd_launch() {
  local target_dir=""

  # Optional first argument: absolute path to workspace directory
  if [[ -n "${1:-}" ]]; then
    if [[ "${1}" == /* ]]; then
      # Absolute path provided directly (called from Phase 3)
      target_dir="${1}"
    else
      # Named workspace — look up in registry
      local found
      found=$(_find_workspace_by_name "${1}" 2>/dev/null || true)
      if [[ -n "${found}" ]]; then
        target_dir="${found}"
      else
        error "$(t "workspace_not_found"): ${1}"
        return 1
      fi
    fi
  else
    # No argument: use current directory (existing behavior)
    target_dir="$(pwd)"
  fi

  # Validate target_dir contains a workspace
  if [[ ! -f "${target_dir}/.workspace.json" ]]; then
    error "$(t "not_a_workspace"): ${target_dir}"
    return 1
  fi

  # ... rest of existing launch logic uses target_dir instead of pwd ...
```

Replace all remaining uses of `$(pwd)` or `"$PWD"` inside `cmd_launch` with `"${target_dir}"`.

- [ ] **Step 5: Run test to verify**

```bash
bash tests/test_launch.sh
```
Expected: ok — nonexistent path correctly rejected

- [ ] **Step 6: Commit**

```bash
git add lib/launch.sh tests/test_launch.sh
git commit -m "feat(launch): accept optional [dir] argument for Phase 3 direct call"
```

---

## Chunk 2: Core — Setup wizard rewrite

### Task 4: Rewrite `lib/setup.sh` as 3-phase wizard

**Files:**
- Modify: `lib/setup.sh`

- [ ] **Step 1: Read current `lib/setup.sh` completely**

Read the full file to understand all existing functions and logic before rewriting.

- [ ] **Step 2: Write failing integration test**

Create `tests/test_setup_phases.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
CW_LIB_DIR="$(dirname "$0")/../lib"
source "${CW_LIB_DIR}/utils.sh"
source "${CW_LIB_DIR}/i18n.sh"
source "${CW_LIB_DIR}/gum.sh"
source "${CW_LIB_DIR}/setup.sh"

pass=0; fail=0
ok()    { echo "  ok: $1"; ((pass++)); }
notok() { echo "FAIL: $1"; ((fail++)); }

# Phase functions must exist
declare -f _setup_phase1 >/dev/null && ok "_setup_phase1 defined" || notok "_setup_phase1 not defined"
declare -f _setup_phase2 >/dev/null && ok "_setup_phase2 defined" || notok "_setup_phase2 not defined"
declare -f _setup_phase3 >/dev/null && ok "_setup_phase3 defined" || notok "_setup_phase3 not defined"

# Module-level state variables must be declared
declare -p _SETUP_NAME >/dev/null 2>&1 && ok "_SETUP_NAME declared" || notok "_SETUP_NAME not declared"
declare -p _SETUP_DESC >/dev/null 2>&1 && ok "_SETUP_DESC declared" || notok "_SETUP_DESC not declared"
declare -p _SETUP_DIRS >/dev/null 2>&1 && ok "_SETUP_DIRS declared" || notok "_SETUP_DIRS not declared"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bash tests/test_setup_phases.sh
```
Expected: FAIL — phase functions don't exist yet

- [ ] **Step 4: Rewrite `lib/setup.sh` with 3-phase wizard**

Keep all existing helper functions intact. Add module-level state at the top:

```bash
# Module-level wizard state
_SETUP_NAME=""
_SETUP_DESC=""
_SETUP_DIRS=()
_SETUP_ROLES=()
```

Add new phase functions:

```bash
# Phase 1: Basic Info
_setup_phase1() {
  local default_name="${1:-}"
  echo ""
  gum style --bold "$(t "phase1_header")" 2>/dev/null || echo "=== $(t "phase1_header") ==="
  echo ""
  _SETUP_NAME=$(gum_input "$(t "workspace_name")" "${default_name}")
  if [[ -z "${_SETUP_NAME}" ]]; then
    error "$(t "name_required")"
    return 1
  fi
  _SETUP_DESC=$(gum_input "$(t "workspace_desc")" "")
}

# Phase 2: Directories
_setup_phase2() {
  echo ""
  gum style --bold "$(t "phase2_header")" 2>/dev/null || echo "=== $(t "phase2_header") ==="
  echo ""
  while true; do
    # Show live list if any dirs added
    if [[ ${#_SETUP_DIRS[@]} -gt 0 ]]; then
      echo "$(t "dirs_added_so_far")"
      local i
      for i in "${!_SETUP_DIRS[@]}"; do
        local role_label=""
        if [[ -n "${_SETUP_ROLES[$i]:-}" ]]; then
          role_label="  (${_SETUP_ROLES[$i]})"
        fi
        echo "  ✓  ${_SETUP_DIRS[$i]}${role_label}"
      done
      echo ""
    fi

    local raw_path
    raw_path=$(gum_path_input "$(t "add_dir_prompt")" "" 2>/dev/null || true)

    # Empty input or Esc → finish
    if [[ -z "${raw_path}" ]]; then
      break
    fi

    local expanded_path
    expanded_path=$(eval echo "${raw_path}" 2>/dev/null || echo "${raw_path}")
    expanded_path=$(normalize_path "${expanded_path}")

    # Validate existence
    if [[ ! -d "${expanded_path}" ]]; then
      gum_error "$(t "path_add_anyway")"
      gum_confirm "$(t "path_add_anyway")" || continue
    fi

    local role
    role=$(gum_input "$(t "dir_role_prompt")" "")

    _SETUP_DIRS+=("${expanded_path}")
    _SETUP_ROLES+=("${role}")
  done
}

# Phase 3: Confirm & Launch
# Arguments: <target_dir>
# Echoes the chosen constant: LAUNCH, CREATE, or CANCEL
_setup_phase3() {
  local target_dir="${1}"
  echo ""
  gum style --bold "$(t "phase3_header")" 2>/dev/null || echo "=== $(t "phase3_header") ==="
  echo ""

  # Summary
  echo "$(t "phase3_summary"):"
  echo "  $(t "workspace_name"):  ${_SETUP_NAME}"
  if [[ -n "${_SETUP_DESC}" ]]; then
    echo "  $(t "workspace_desc"):  ${_SETUP_DESC}"
  fi
  echo "  Dirs: ${#_SETUP_DIRS[@]}"
  echo "  Path: ${target_dir}"
  echo "  Files: .workspace.json, CLAUDE.md"
  echo ""

  local choice
  choice=$(gum_choose \
    "$(t "phase3_opt_launch")" "LAUNCH" \
    "$(t "phase3_opt_create")" "CREATE" \
    "$(t "phase3_opt_cancel")" "CANCEL")
  echo "${choice}"
}
```

Rewrite `cmd_setup` to call the three phases:

```bash
cmd_setup() {
  # ... existing argument parsing preserved ...
  local target_dir
  target_dir="$(pwd)"

  # Determine default name from directory basename
  local default_name
  default_name=$(basename "${target_dir}")

  # Phase 1
  _setup_phase1 "${default_name}" || return 1

  # Phase 2
  _setup_phase2

  # Phase 3
  local choice
  choice=$(_setup_phase3 "${target_dir}")

  case "${choice}" in
    CANCEL)
      info "$(t "setup_cancelled")"
      return 0
      ;;
    LAUNCH|CREATE)
      # Write workspace files
      gum_spin "$(t "creating_workspace")" \
        _write_workspace_files "${target_dir}"

      # Install skills
      gum_spin "$(t "installing_skills")" \
        _install_skills "${target_dir}"

      # Register in global registry
      _register_workspace "${target_dir}"

      if [[ "${choice}" == "LAUNCH" ]]; then
        cmd_launch "${target_dir}"
      else
        success "$(t "setup_complete")"
      fi
      ;;
    *)
      # Esc or empty — treat as cancel
      info "$(t "setup_cancelled")"
      return 0
      ;;
  esac
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/test_setup_phases.sh
```
Expected: All checks pass, 0 failed

- [ ] **Step 6: Manual smoke test**

```bash
# Create a temp directory and run setup
tmpdir=$(mktemp -d)
cd "${tmpdir}"
cw setup
# Verify: phases display, can Esc at Phase 2, CANCEL exits cleanly
rm -rf "${tmpdir}"
```

- [ ] **Step 7: Commit**

```bash
git add lib/setup.sh tests/test_setup_phases.sh
git commit -m "feat(setup): rewrite as 3-phase interactive wizard using gum"
```

---

## Chunk 3: Polish — Global confirm replacement + install.sh gum check

### Task 5: Replace `[y/N]` prompts in `lib/menu.sh`, `lib/new.sh`, `lib/utils.sh`

**Files:**
- Modify: `lib/menu.sh`
- Modify: `lib/new.sh`
- Modify: `lib/utils.sh`

- [ ] **Step 1: Read each file to find all `[y/N]` patterns**

Search for all confirm patterns:

```bash
grep -n "y/N\|read -rep\|y/n" lib/menu.sh lib/new.sh lib/utils.sh
```

- [ ] **Step 2: Source `lib/gum.sh` in each file**

Each file that uses confirms must source `lib/gum.sh` after `lib/utils.sh`. Add near top of each file:

```bash
# shellcheck source=lib/gum.sh
source "${CW_LIB_DIR}/gum.sh"
```

- [ ] **Step 3: Replace patterns in `lib/menu.sh`**

For each `read -rep "... [y/N]"` pattern, replace with `gum_confirm`:

Before:
```bash
read -rep "$(t "confirm_forget") [y/N]: " answer
case "$(echo "${answer}" | tr '[:upper:]' '[:lower:]')" in
  y|yes) ... ;;
  *) return 0 ;;
esac
```

After:
```bash
gum_confirm "$(t "confirm_forget")" || return 0
```

- [ ] **Step 4: Replace patterns in `lib/new.sh` and `lib/utils.sh`**

Apply same pattern replacement. Each `[y/N]` confirmation block becomes a single `gum_confirm` call.

- [ ] **Step 5: Run existing manual tests**

```bash
cw forget <workspace>  # Verify gum confirm appears (or [y/N] fallback without gum)
cw add-dir <path>      # Verify path validation still works
```

- [ ] **Step 6: Commit**

```bash
git add lib/menu.sh lib/new.sh lib/utils.sh
git commit -m "feat: replace [y/N] prompts with gum_confirm across all commands"
```

---

### Task 6: Add gum availability check to `install.sh`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Read current `install.sh`**

Read the file to find where the jq check is, to insert gum check after it.

- [ ] **Step 2: Write test**

```bash
# Manual verification: run install.sh and confirm gum check appears
# (automated test not practical for install scripts)
bash install.sh --dry-run 2>&1 | grep -i gum && echo "gum check present" || echo "gum check missing"
```

- [ ] **Step 3: Add gum check after jq check in `install.sh`**

After the jq check block, add:

```bash
# Check for gum (optional — graceful degradation)
if command -v gum >/dev/null 2>&1; then
  echo "  ✓ gum found: $(gum --version 2>/dev/null || echo 'unknown version')"
else
  echo "  ○ gum not found (optional)"
  echo "    For a richer UI experience: brew install gum"
  echo "    cw works without gum using standard prompts."
fi
```

- [ ] **Step 4: Verify `install.sh` runs cleanly**

```bash
bash -n install.sh && echo "Syntax OK"
```

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat(install): add optional gum availability check with install hint"
```

---

## Final Verification

- [ ] Run full manual test checklist:

```bash
cw new TestWizard        # Should show 3 phases with gum (or fallback)
cw setup                 # Same from an existing directory
cw forget <workspace>    # gum confirm or [y/N] fallback
cw add-dir <path>        # Path validation + gum_error for nonexistent
bash install.sh          # Shows gum availability status
```

- [ ] Test fallback mode (without gum):

```bash
# Temporarily shadow gum
PATH_BACKUP="$PATH"
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v gum | tr '\n' ':')"
cw new FallbackTest       # Must work with read-based fallbacks
export PATH="$PATH_BACKUP"
```

- [ ] Commit final tag if all green:

```bash
git tag -a v0.3.0 -m "v0.3.0" 2>/dev/null || true
```

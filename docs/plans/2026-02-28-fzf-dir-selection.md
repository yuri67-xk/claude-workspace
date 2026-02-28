# fzf Directory Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add fzf-based interactive directory selection to `cw setup` Step 3 and `cw add-dir`, with graceful fallback to hand-typed input when fzf is not installed.

**Architecture:** Add a `select_dir_with_fzf()` helper to `utils.sh` that wraps fzf (or falls back to `read`). Update the two path-input sites in `setup.sh` to call this helper. Add one i18n key.

**Tech Stack:** Bash 3.2+, fzf (optional), find (BSD/GNU compatible), existing cw utils

---

## Task 1: Add `select_dir_with_fzf()` to `utils.sh`

**Files:**
- Modify: `lib/utils.sh` (append after `expand_path()` function, around line 82)

### Step 1: Open `lib/utils.sh` and locate the `expand_path()` function

It ends around line 82:
```bash
expand_path() {
  ...
}
```

### Step 2: Append the new function immediately after `expand_path()`

Add these lines after the closing `}` of `expand_path`:

```bash
# Pick a directory with fzf (if available) or fall back to read.
# Arguments: <prompt_label>
# Outputs:   absolute path echoed to stdout, or empty string if cancelled
select_dir_with_fzf() {
  local prompt="$1"
  local result=""

  if command -v fzf &>/dev/null; then
    result=$(
      find "$HOME" -maxdepth 4 -type d \
        \( -name ".git" -o -name "node_modules" -o -name ".cache" \
           -o -name "Library" -o -name "__pycache__" \) -prune \
        -o -type d -print 2>/dev/null \
      | fzf --height=40% --border \
            --prompt="$prompt > " \
            --preview="ls {}" \
            --preview-window=right:40% \
      || true
    )
  else
    read -rep "  $prompt: " result
    result=$(expand_path "$result")
  fi

  echo "$result"
}
```

**Key notes:**
- `|| true` after fzf prevents `set -e` from exiting when user presses `^C` (fzf exits non-zero on cancel)
- The fzf path is already absolute (from `find`), no need for `expand_path`
- The fallback path calls `expand_path` so `~` expansion still works

### Step 3: Verify the function is syntactically correct

```bash
bash -n lib/utils.sh
```

Expected: no output (no errors)

### Step 4: Smoke-test the function in isolation

```bash
bash -c '
  source lib/utils.sh
  source lib/i18n.sh
  echo "Test: fzf available? $(command -v fzf && echo yes || echo no)"
'
```

Expected: prints whether fzf is available (either is fine at this stage)

### Step 5: Commit

```bash
git add lib/utils.sh
git commit -m "feat(utils): add select_dir_with_fzf helper with fzf and read fallback"
```

---

## Task 2: Add `select_dir_prompt` i18n key to `i18n.sh`

**Files:**
- Modify: `lib/i18n.sh`

### Step 1: Add the key to the Japanese block

Find the `# === Directory ===` section in the `ja)` case (around line 74). After the `"path"` entry, add:

```bash
        "select_dir_prompt") echo "ディレクトリを選択" ;;
```

The section should look like:
```bash
        # === Directory ===
        "directory") echo "ディレクトリ" ;;
        ...
        "path") echo "パス" ;;
        "select_dir_prompt") echo "ディレクトリを選択" ;;   # ← add here
        "add_anyway") echo "それでも追加しますか?" ;;
```

### Step 2: Add the key to the English block

Find the `# === Directory ===` section in the `*)` (English) case (around line 225). After the `"path"` entry, add:

```bash
        "select_dir_prompt") echo "Select directory" ;;
```

### Step 3: Verify no syntax errors

```bash
bash -n lib/i18n.sh
```

Expected: no output

### Step 4: Verify the key resolves correctly in both languages

```bash
bash -c '
  CW_HOME=/tmp source lib/utils.sh
  source lib/i18n.sh
  echo "en: $(t "select_dir_prompt")"
  mkdir -p /tmp/.claude-workspace && echo "ja" > /tmp/.claude-workspace/lang
  echo "ja: $(t "select_dir_prompt")"
'
```

Expected:
```
en: Select directory
ja: ディレクトリを選択
```

### Step 5: Commit

```bash
git add lib/i18n.sh
git commit -m "feat(i18n): add select_dir_prompt key for fzf directory picker"
```

---

## Task 3: Update `cmd_setup()` Step 3 to use `select_dir_with_fzf()`

**Files:**
- Modify: `lib/setup.sh` — `cmd_setup()`, the `while true` loop (lines 66–86)

### Step 1: Locate the current path-input block in `cmd_setup()`

```bash
# Current code (lines 66-71):
while true; do
  read -rep "  $(t "path") (empty Enter to finish): " raw_path
  [[ -z "$raw_path" ]] && break

  local expanded_path
  expanded_path=$(expand_path "$raw_path")
```

### Step 2: Replace those 5 lines with the fzf call

Replace:
```bash
  read -rep "  $(t "path") (empty Enter to finish): " raw_path
  [[ -z "$raw_path" ]] && break

  local expanded_path
  expanded_path=$(expand_path "$raw_path")
```

With:
```bash
  local raw_path
  raw_path=$(select_dir_with_fzf "$(t "select_dir_prompt")")
  [[ -z "$raw_path" ]] && break

  local expanded_path="$raw_path"
```

**Why `expanded_path="$raw_path"` with no `expand_path` call:**
`select_dir_with_fzf` already returns an absolute path (fzf path: from `find`; fallback path: `expand_path` called internally).

Also remove or update the now-redundant hint text. The `echo "  $(dim "$(t "setup_path_hint")")"` line (around line 59) still makes sense as a general instruction, so leave it. The `"Example: ~/repos/my-project"` echo on line 61 can be removed since fzf makes it self-evident — but leave it for the fallback case. Either way, this is cosmetic and optional.

### Step 3: Verify syntax

```bash
bash -n lib/setup.sh
```

Expected: no output

### Step 4: Dry-run `cw setup` (manual test)

Run in a temporary directory:

```bash
mkdir -p /tmp/cw-test && cd /tmp/cw-test
# Source the env manually to test without installing
CW_HOME=/tmp/.claude-workspace-test bash -c '
  mkdir -p /tmp/.claude-workspace-test
  source /path/to/claude-workspace/lib/utils.sh
  source /path/to/claude-workspace/lib/i18n.sh
  source /path/to/claude-workspace/lib/registry.sh
  source /path/to/claude-workspace/lib/setup.sh
  cmd_setup
'
```

Expected: if fzf is installed, fzf picker opens at Step 3. If not, fallback `read` prompt appears.

**Alternative: test the whole CLI:**
```bash
cd /tmp/cw-test
cw setup
```

At Step 3, fzf should open (or fallback read). Select a directory, press Enter. Empty selection (^C or Enter with no selection) should end the loop.

### Step 5: Commit

```bash
git add lib/setup.sh
git commit -m "feat(setup): use fzf for directory selection in cw setup Step 3"
```

---

## Task 4: Update `cmd_add_dir()` to use `select_dir_with_fzf()`

**Files:**
- Modify: `lib/setup.sh` — `cmd_add_dir()` (lines 216–219)

### Step 1: Locate the current interactive path block in `cmd_add_dir()`

```bash
# Current code (lines 216-219):
local new_path="${1:-}"
if [[ -z "$new_path" ]]; then
  read -rep "  $(t "dir_add_path"): " new_path
fi
```

### Step 2: Replace the `read` with `select_dir_with_fzf()`

Replace just the `read` line inside the `if`:
```bash
  read -rep "  $(t "dir_add_path"): " new_path
```

With:
```bash
  new_path=$(select_dir_with_fzf "$(t "select_dir_prompt")")
```

The `if [[ -z "$new_path" ]]; then` block remains unchanged — this is the guard for when `cw add-dir <path>` was called with an argument (no fzf in that case).

After the `if` block, the existing code does:
```bash
local expanded_path
expanded_path=$(expand_path "$new_path")
```

This `expand_path` call is safe to keep as-is: for the fzf path it's already absolute (idempotent), for the argument path it normalizes `~` etc.

### Step 3: Verify syntax

```bash
bash -n lib/setup.sh
```

Expected: no output

### Step 4: Manual test — interactive path (no argument)

In a directory that already has `.workspace.json`:

```bash
cw add-dir
```

Expected: fzf opens (or fallback read). Select a directory. The directory is added to `.workspace.json` and CLAUDE.md is updated.

### Step 5: Manual test — CLI argument still works

```bash
cw add-dir ~/repos/some-project
```

Expected: fzf does NOT open. The argument is used directly. Existing behavior preserved.

### Step 6: Manual test — cancelled fzf (^C)

```bash
cw add-dir
# Press ^C inside fzf
```

Expected: empty string returned → `[[ -z "$expanded_path" ]]`... actually, check what happens. Current code after `expand_path`:

```bash
if [[ ! -d "$expanded_path" ]]; then
  warn "$(t "dir_not_found"): $expanded_path"
  read -rep "  $(t "add_anyway") [y/N]: " force
  [[ "$force" =~ ^[Yy]$ ]] || exit 0
fi
```

If `new_path` is empty, `expanded_path` will be empty, `[[ ! -d "" ]]` is true (empty string is not a directory), so the warning fires. This is acceptable behavior. To make it cleaner, add an early-exit after fzf selection if empty:

After the `if` block that sets `new_path`, add:
```bash
[[ -z "$new_path" ]] && { info "$(t "cancel")"; exit 0; }
```

Add this line right after the closing `fi` of the `if [[ -z "$new_path" ]]; then` block.

### Step 7: Commit

```bash
git add lib/setup.sh
git commit -m "feat(setup): use fzf for directory selection in cw add-dir"
```

---

## Task 5: End-to-End Verification

### Step 1: Full `cw setup` flow with fzf

```bash
mkdir -p /tmp/e2e-test && cd /tmp/e2e-test
cw setup
```

Walk through all steps:
- Step 1: name
- Step 2: description
- Step 3: fzf opens → select a real directory → confirm role → select another → empty selection ends loop
- Steps 4-6: automatic

Expected: `.workspace.json` and `CLAUDE.md` created with correct dirs.

Verify:
```bash
cat /tmp/e2e-test/.workspace.json
```

### Step 2: Full `cw add-dir` flow with fzf

From the setup directory:
```bash
cd /tmp/e2e-test
cw add-dir
```

Expected: fzf opens → select directory → role prompt → directory added to `.workspace.json`.

### Step 3: Fallback test (if fzf available)

Temporarily rename fzf to simulate absence:
```bash
mv "$(which fzf)" /tmp/fzf-backup
cw setup
# Step 3 should show read prompt, not fzf
mv /tmp/fzf-backup "$(which fzf)"
```

Expected: fallback `read -rep` prompt appears. Normal text input works.

### Step 4: Cleanup

```bash
rm -rf /tmp/e2e-test
```

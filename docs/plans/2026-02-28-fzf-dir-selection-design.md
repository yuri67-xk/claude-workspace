# Design: fzf-based Directory Selection for `cw setup` and `cw add-dir`

**Date**: 2026-02-28
**Status**: Approved

---

## Overview

Improve path input UX in `cw setup` (Step 3) and `cw add-dir` by integrating fzf for interactive directory selection. Falls back to existing hand-typed input when fzf is not installed.

---

## Architecture

```
utils.sh
└── select_dir_with_fzf()    # Core helper: fzf picker or read fallback

setup.sh
├── cmd_setup() Step3        # Replace read loop with select_dir_with_fzf()
└── cmd_add_dir()            # Replace read prompt with select_dir_with_fzf()
```

---

## New Function: `select_dir_with_fzf()` (utils.sh)

```bash
# Pick a directory interactively using fzf (if available), or fall back to read.
# Arguments: <prompt_label>
# Outputs:   absolute path (echoed to stdout), or empty string on cancel
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
            --preview-window=right:40%
    )
  else
    read -rep "  $prompt: " result
    result=$(expand_path "$result")
  fi

  echo "$result"
}
```

**Behavior:**
- fzf available: opens interactive picker from `$HOME`, maxdepth 4, with `ls` preview
- fzf unavailable: falls back to `read -rep` (current behavior, zero UX change)
- Returns empty string if user cancels (^C or Esc in fzf)

**Excluded directories (pruned from find):**
`.git`, `node_modules`, `.cache`, `Library`, `__pycache__`

---

## Changes to `setup.sh`

### `cmd_setup()` Step 3 — Directory input loop

**Before** (`setup.sh:67`):
```bash
read -rep "  $(t "path") (empty Enter to finish): " raw_path
[[ -z "$raw_path" ]] && break
local expanded_path
expanded_path=$(expand_path "$raw_path")
```

**After**:
```bash
raw_path=$(select_dir_with_fzf "$(t "select_dir_prompt")")
[[ -z "$raw_path" ]] && break
local expanded_path="$raw_path"
```

### `cmd_add_dir()` — Interactive path input

**Before** (`setup.sh:217-218`):
```bash
if [[ -z "$new_path" ]]; then
  read -rep "  $(t "dir_add_path"): " new_path
fi
```

**After**:
```bash
if [[ -z "$new_path" ]]; then
  new_path=$(select_dir_with_fzf "$(t "select_dir_prompt")")
fi
```

Note: when `new_path` is already set (i.e., `cw add-dir <path>` called with argument), the fzf path is skipped entirely — no change to CLI argument behavior.

---

## i18n Changes (`i18n.sh`)

Add the following keys to both `en` and `ja` blocks:

| Key | English | Japanese |
|-----|---------|----------|
| `select_dir_prompt` | `Select directory` | `ディレクトリを選択` |

---

## Constraints

- **macOS bash 3.2 compatibility**: No `${var,,}`, no associative arrays — use `tr` for case conversion
- **fzf is optional**: Always falls back gracefully
- **CLI argument passthrough unchanged**: `cw add-dir <path>` still works as before
- **No new required dependencies** beyond the existing `jq` + `claude`

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/utils.sh` | Add `select_dir_with_fzf()` function |
| `lib/setup.sh` | Update `cmd_setup()` Step 3 and `cmd_add_dir()` |
| `lib/i18n.sh` | Add `select_dir_prompt` key (en + ja) |

---

## Out of Scope

- Configurable search roots (future enhancement)
- `fd` as alternative to `find` (would add another optional dep)
- Level-by-level drill-down navigation in fzf

# Design: Interactive Wizard UI (gum-based)

**Date:** 2026-03-13
**Status:** Approved

---

## Overview

Redesign the `cw setup` / `cw new` flow from a linear 7-step prompt sequence into a 3-phase interactive wizard using [gum](https://github.com/charmbracelet/gum). Apply gum-based UI components across all commands for consistent, visually rich interactions. Maintain a fallback to the existing `read`-based UI when gum is not installed.

---

## Problem Statement

Current pain points identified:

1. **Directory selection is repetitive** — adding directories one by one with no visible running list makes the flow confusing.
2. **7-step sequence feels long** — no visible progress indicator; users don't know how far along they are.
3. **Weak input validation** — invalid paths are not flagged immediately at input time.
4. **Unclear next action after completion** — setup ends with "run `cw`" but does not offer to launch automatically.

---

## Solution

### Core: 3-Phase Wizard (`cw setup` / `cw new`)

Replace the 7-step linear flow with 3 named phases:

#### Phase 1 — Basic Info
- `gum input` for workspace name (pre-filled with directory basename for `cw setup`)
- `gum input` for description (optional)
- Phase header shows `Phase 1/3: Basic Info`

#### Phase 2 — Directories
- Display a live "Added so far" list before each prompt
- Path input uses `gum_path_input` (see Architecture) with the following tool-combination behavior:
  - gum + fzf both available: fzf for directory browsing (gum used for styling the prompt header only)
  - gum only: `gum input` (type path directly; no Tab-fzf integration — not feasible with gum input)
  - fzf only: `select_dir_with_fzf` (existing behavior)
  - neither: `read -rep` fallback
- Immediate validation: if path does not exist, show colored warning and `gum confirm "Add anyway?"` (or `[y/N]` fallback)
- `gum input` for optional role label per directory
- Loop continues until user presses Esc or submits empty input
- At least one directory is not required (user can add later with `cw add-dir`)

#### Phase 3 — Confirm & Launch
- Summary box showing: name, description, directory count, workspace path, files to be created
- `gum_choose` with three options (comparison uses internal constants, not i18n values):
  - `LAUNCH` → display label `t "phase3_opt_launch"` — create workspace files then call `cmd_launch` with explicit `target_dir`
  - `CREATE` → display label `t "phase3_opt_create"` — create files and exit (existing behavior)
  - `CANCEL` → display label `t "phase3_opt_cancel"` — abort without writing anything
- `gum_choose` returns the internal constant (e.g. `LAUNCH`); Phase 3 uses `case "$choice" in LAUNCH) ...` for branching
- When "LAUNCH" is chosen, `cmd_launch` is called with the workspace directory passed explicitly (not relying on `pwd`)

### Global UI Upgrades (all commands)

| Current pattern | Replacement |
|----------------|-------------|
| `read -rep "... [y/N]: "` | `gum confirm "..."` |
| Processing steps (file write, skill install) | `gum spin --title "..."` wrapping the operation |
| `warn "..."` / `error "..."` output | `gum style` with foreground color + border for errors |
| `cw add-dir` path prompt | `gum input` + fzf, same validation as Phase 2 |
| `cw forget` confirmation | `gum confirm` with destructive-action styling |

---

## Architecture

### New file: `lib/gum.sh`

Central gum abstraction layer. Provides wrapper functions that:
- Call gum when available (`command -v gum`)
- Fall back to existing `read`/`echo` patterns otherwise

Key functions:
```
gum_input <prompt> [default]      → gum input / read fallback
gum_confirm <message>             → gum confirm / [y/N] fallback
gum_spin <title> <command...>     → gum spin / direct execution fallback
                                     (bash 3.2 safe: uses "${@:2}" for command args)
gum_error <message>               → gum style (red border) / warn fallback
gum_choose <options...>           → gum choose / numbered menu fallback
                                     (fallback: inline numbered list via echo + read)
gum_path_input <prompt> [default] → tool-combination-aware path selector:
                                     gum+fzf: fzf browse (gum for prompt styling only)
                                     gum only: gum input (type path directly)
                                     fzf only: select_dir_with_fzf (existing)
                                     neither:  read -rep fallback
```

### Modified file: `lib/setup.sh`

- Replace 7-step sequence with `_setup_phase1`, `_setup_phase2`, `_setup_phase3` internal functions
- Call gum wrapper functions throughout
- Phase 3 result drives post-setup action (launch or exit)
- When "LAUNCH" is chosen, call `cmd_launch` with `target_dir` passed explicitly — do NOT rely on `pwd` (bash's `pwd` state is not guaranteed to match `target_dir` after subshell calls)
- `cmd_launch` will need to accept an optional `[dir]` argument; if provided, it `cd`s to that dir instead of using `pwd`
- `cw new` calls `cmd_setup` and then returns; Phase 3 inside `cmd_setup` handles the launch decision, so `cmd_new` does **not** add a separate `cmd_launch` call

### Modified file: `lib/utils.sh` / other command files

- Replace `read -rep "... [y/N]"` patterns with `gum_confirm`
- Replace processing steps with `gum_spin` wrappers where applicable

### Modified file: `install.sh`

- Add gum availability check after jq check
- If gum not found: suggest `brew install gum`, offer to install, or warn and continue
- Document gum as optional (graceful degradation)

---

## Fallback Behavior

When gum is not installed:
- `gum_input` → `read -rep`
- `gum_confirm` → `read -rep "... [y/N]: "`
- `gum_spin` → direct execution (no spinner)
- `gum_error` → existing `warn`/`error` functions
- `gum_choose` → numbered menu (existing `_menu_numbered_pick` pattern)

All existing behavior is preserved. The wrapper layer in `lib/gum.sh` is the single point of fallback logic.

---

## Out of Scope

- Full TUI dashboard (panel-based, real-time) — not in this iteration
- `cw web` UI changes — web UI is separate
- `cw list` / `cw info` output styling — low priority, can follow in a future iteration
- Windows/WSL support — not a stated requirement

---

## Success Criteria

- `cw setup` completes in 3 clear phases with visible phase indicator
- Directory list is visible throughout Phase 2
- Invalid paths show immediate colored warning
- Phase 3 offers "Create & Launch" that exits directly into Claude Code
- All `[y/N]` prompts replaced with `gum confirm` (when gum installed)
- Processing operations show spinner (when gum installed)
- Full functionality preserved when gum is not installed
- `install.sh` checks for gum and guides the user to install it

---

## Dependencies

- [gum](https://github.com/charmbracelet/gum) — optional, `brew install gum`
- No other new dependencies

---

## i18n Keys (New)

All new user-facing strings must be added to both `en` and `ja` blocks in `lib/i18n.sh`. Confirmed additions:

| Key | English | Japanese |
|-----|---------|---------|
| `phase1_header` | `Phase 1/3: Basic Info` | `フェーズ 1/3: 基本情報` |
| `phase2_header` | `Phase 2/3: Directories` | `フェーズ 2/3: ディレクトリ` |
| `phase3_header` | `Phase 3/3: Confirm` | `フェーズ 3/3: 確認` |
| `phase3_opt_launch` | `Create & Launch Claude` | `作成して Claude を起動` |
| `phase3_opt_create` | `Create only` | `作成のみ` |
| `phase3_opt_cancel` | `Cancel` | `キャンセル` |
| `phase3_summary` | `Summary` | `内容確認` |
| `path_add_anyway` | `Path does not exist. Add anyway?` | `ディレクトリが存在しません。追加しますか?` |
| `dirs_added_so_far` | `Added so far:` | `追加済み:` |
| `gum_required_hint` | `Install gum for a richer UI: brew install gum` | `より良いUIのために gum をインストール: brew install gum` |

All Phase 1–3 display strings must go through `t "key"`. No hardcoded display strings allowed.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `lib/gum.sh` | Create — gum wrapper abstraction |
| `lib/setup.sh` | Modify — rewrite to 3-phase wizard |
| `lib/utils.sh` | Modify — replace confirm patterns |
| `lib/menu.sh` | Modify — replace confirm patterns |
| `lib/new.sh` | Modify — replace confirm patterns |
| `lib/launch.sh` | Modify — add optional `[dir]` argument to `cmd_launch` for Phase 3 direct call |
| `install.sh` | Modify — add gum availability check |
| `lib/i18n.sh` | Modify — add all keys listed in i18n Keys section above |

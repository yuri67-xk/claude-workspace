# claude-workspace (cw)

Claude Code に **Workspace** の概念を持ち込む Bash CLI。
一つのパーパスを達成するために複数のリポジトリ/ディレクトリを横断して
Claude Code を起動し、コンテキストを統合管理する。

- **Version**: 0.2.0
- **Language**: Bash (macOS bash 3.2+ / Linux bash compatible)
- **Dependencies**: `jq`, `claude` (Claude Code CLI)

---

## File Structure

### Repository

```
bin/cw              # CLI entry point — command routing and version constant
lib/
  utils.sh          # Common utilities: colors, info/warn/error, jq wrappers, path normalization
  i18n.sh           # Bilingual message system (en/ja) — all user-facing strings live here
  registry.sh       # Global registry operations (~/.claude-workspace/registry.json)
  setup.sh          # cw setup, cw add-dir — .workspace.json + CLAUDE.md generation
  launch.sh         # cw launch — builds --add-dir flags and execs claude
  list.sh           # cw list — sorted by last_used
  info.sh           # cw info — workspace details
  new.sh            # cw new — creates directory under WorkingProjects/ then calls cmd_setup
  menu.sh           # cw / cw resume — interactive selection menu
  update.sh         # cw update — git pull on source directory
  lang.sh           # cw lang — language preference
install.sh
uninstall.sh
```

### Runtime (User Environment)

```
~/.claude-workspace/
  registry.json     # Global list of all workspaces
  lang              # Language setting (en / ja)
  source_path       # Source repo path for cw update

~/WorkingProjects/<name>/
  .workspace.json   # Workspace config (canonical source of truth)
  CLAUDE.md         # Context auto-loaded by Claude Code on launch
```

---

## Data Structures

### `.workspace.json`

```json
{
  "name": "Store360 Refactor",
  "description": "SDK monolith decomposition project",
  "workspace_path": "/Users/yuri/WorkingProjects/store360-refactor",
  "created_at": "2025-06-01T12:00:00Z",
  "dirs": [
    { "path": "/Users/yuri/repos/store360-ios-sdk", "role": "iOS SDK" },
    { "path": "/Users/yuri/repos/store360-android-sdk", "role": "Android SDK" }
  ]
}
```

### `registry.json`

```json
{
  "workspaces": [
    {
      "name": "Store360 Refactor",
      "path": "/Users/yuri/WorkingProjects/store360-refactor",
      "created_at": "2025-06-01T12:00:00Z",
      "last_used": "2025-06-10T09:00:00Z"
    }
  ]
}
```

---

## Coding Conventions

### Bash Style

- All files start with `set -euo pipefail`
- Always double-quote variables: `"${var}"`
- Declare function-local variables with `local`
- **macOS bash 3.2 compatibility**: avoid `${var,,}` — use `tr '[:upper:]' '[:lower:]'` instead
- Empty-safe array expansion: `"${arr[@]+"${arr[@]}"}"` pattern required

### Output Helpers (defined in `utils.sh`)

| Function | Use |
|----------|-----|
| `info "..."` | Informational message |
| `success "..."` | Success confirmation |
| `warn "..."` | Warning (stderr) |
| `error "..."` | Error + exit 1 (stderr) |
| `step "..."` | Setup step header |
| `bold/dim/green/...` | Inline styling |

### i18n Pattern

All user-facing strings are looked up via `t "key"`. Never hardcode display strings outside `i18n.sh`.

```bash
echo "$(t "workspace_name"): $ws_name"   # correct
echo "Workspace name: $ws_name"           # wrong
```

### Adding a New Command

1. Create `lib/<command>.sh` with a `cmd_<name>()` function
2. `source "$CW_LIB_DIR/<command>.sh"` in `bin/cw` (load order after `utils.sh`, `i18n.sh`)
3. Add a `case` entry in `main()` in `bin/cw`
4. Add i18n keys to `lib/i18n.sh` (both `en` and `ja` blocks)
5. Document in `usage()` in `bin/cw`

---

## Development

### Install from Source

```bash
git clone <repo> /path/to/claude-workspace-src
cd /path/to/claude-workspace-src
bash install.sh
```

### Manual Testing Checklist

```bash
cw new <name>       # Create workspace flow: mkdir → setup → launch
cw setup            # Register existing directory
cw launch           # Verify --add-dir flags are passed correctly to claude
cw list             # Registry enumeration (sorted by last_used)
cw info             # Workspace details
cw add-dir <path>   # Append dir to .workspace.json + regenerate CLAUDE.md
cw scan             # Detect unregistered workspaces under WorkingProjects/
cw forget           # Remove from registry only (files intact)
cw update           # git pull on source
cw lang ja && cw lang en  # Language toggle
```

### Version Release

1. Update `CW_VERSION` in `bin/cw`
2. Update CHANGELOG (`[Unreleased]` → `[x.y.z] - YYYY-MM-DD`)
3. Commit: `docs: update CHANGELOG for vx.y.z`
4. Tag: `git tag -a vx.y.z -m "vx.y.z"`
5. Push: `git push origin main && git push origin vx.y.z`
6. Create GitHub Release

### CHANGELOG Scope

Update CHANGELOG for changes that affect **end-user behavior**:
- New commands or options
- Behavior changes to existing commands
- Bug fixes visible to users
- Installation/uninstall changes

Do **not** update CHANGELOG for:
- Internal refactoring with no UX impact
- i18n string adjustments only
- Test or documentation-only commits

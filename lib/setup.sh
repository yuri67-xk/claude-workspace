#!/usr/bin/env bash
# setup.sh - cw setup command

# Arguments: [prefill_name]
#   prefill_name ... passed when called from cw new to skip name input
cmd_setup() {
  require_jq

  local prefill_name="${1:-}"

  local target_dir
  target_dir="$(pwd)"

  # Check if already set up as workspace
  if is_workspace "$target_dir"; then
    warn "$(t "workspace_already_setup")"
    local existing_name
    existing_name=$(ws_get "$target_dir/$WORKSPACE_FILE" '.name')
    echo "  $(t "workspace_name"): $(bold "$existing_name")"
    echo ""
    read -rep "  $(t "re_setup") [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "$(t "cancel")"; exit 0; }
    echo ""
  fi

  echo ""
  echo "$(bold "Claude Workspace Setup")"
  echo "$(dim "$(t "directory"): $target_dir")"
  echo ""

  # ──────────────────────────────
  # Step 1: Workspace name
  # ──────────────────────────────
  step "Step 1: $(t "setup_step1")"
  local ws_name
  if [[ -n "$prefill_name" ]]; then
    # Called from cw new, name already set
    ws_name="$prefill_name"
    success "$(t "workspace_name"): $ws_name"
  else
    local default_name
    default_name="$(basename "$target_dir")"
    read -rep "  $(t "workspace_name") [${default_name}]: " ws_name
    ws_name="${ws_name:-$default_name}"
    success "$(t "workspace_name"): $ws_name"
  fi

  # ──────────────────────────────
  # Step 2: Description
  # ──────────────────────────────
  step "Step 2: $(t "setup_step2")"
  read -rep "  $(t "workspace_desc"): " ws_description
  ws_description="${ws_description:-}"

  # ──────────────────────────────
  # Step 3: Add target directories
  # ──────────────────────────────
  step "Step 3: $(t "setup_step3")"
  echo "  $(dim "$(t "setup_path_hint")")"
  echo "  $(dim "Example: ~/repos/my-project")"
  echo ""

  local dirs=()
  local dir_roles=()

  while true; do
    local raw_path
    raw_path=$(select_dir_with_fzf "$(t "select_dir_prompt")")
    [[ -z "$raw_path" ]] && break

    local expanded_path="$raw_path"

    if [[ ! -d "$expanded_path" ]]; then
      warn "$(t "dir_not_found"): $expanded_path"
      read -rep "  $(t "add_anyway") [y/N]: " force
      [[ "$force" =~ ^[Yy]$ ]] || continue
    fi

    # Role label (optional)
    read -rep "  $(t "dir_add_role"): " role
    role="${role:-}"

    dirs+=("$expanded_path")
    dir_roles+=("$role")
    success "$(t "dir_added"): $expanded_path $([ -n "$role" ] && echo "(${role})")"
  done

  if [[ ${#dirs[@]} -eq 0 ]]; then
    warn "No directories specified. Use cw add-dir later to add."
  fi

  # ──────────────────────────────
  # Step 4: Generate workspace.json
  # ──────────────────────────────
  step "Step 4: $(t "setup_step4")"

  local ws_file="$target_dir/$WORKSPACE_FILE"
  local created_at
  created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build JSON
  local dirs_json="[]"
  for i in "${!dirs[@]}"; do
    local dir="${dirs[$i]}"
    local role="${dir_roles[$i]}"
    dirs_json=$(echo "$dirs_json" | jq \
      --arg path "$dir" \
      --arg role "$role" \
      '. += [{"path": $path, "role": $role}]')
  done

  jq -n \
    --arg name "$ws_name" \
    --arg description "$ws_description" \
    --arg created_at "$created_at" \
    --arg workspace_path "$target_dir" \
    --argjson dirs "$dirs_json" \
    '{
      name: $name,
      description: $description,
      workspace_path: $workspace_path,
      created_at: $created_at,
      dirs: $dirs
    }' > "$ws_file"

  success "$(t "created"): $ws_file"

  # ──────────────────────────────
  # Step 5: Generate CLAUDE.md
  # ──────────────────────────────
  step "Step 5: $(t "setup_step5")"

  local claude_md="$target_dir/$WORKSPACE_CLAUDE_MD"
  _generate_workspace_claude_md "$claude_md" "$ws_name" "$ws_description" "$ws_file"
  success "$(t "created"): $claude_md"

  # ──────────────────────────────
  # Step 6: Install skills to .claude/skills/
  # ──────────────────────────────
  step "Step 6: $(t "setup_step6")"

  if [[ -d "$CW_SKILLS_DIR" ]]; then
    local ws_skills_dir="$target_dir/.claude/skills"
    mkdir -p "$ws_skills_dir"
    for skill_dir in "$CW_SKILLS_DIR"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_name
      skill_name="$(basename "$skill_dir")"
      cp -R "$skill_dir" "$ws_skills_dir/$skill_name"
    done
    success "$(t "setup_skills_installed"): .claude/skills/"
  fi

  # ──────────────────────────────
  # Step 7: Register to global registry
  # ──────────────────────────────
  step "Step 7: $(t "setup_step7")"
  registry_add "$ws_name" "$target_dir"
  success "$(t "registered"): ~/.claude-workspace/registry.json"

  # ──────────────────────────────
  # Complete
  # ──────────────────────────────
  echo ""
  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(green "  $(t "setup_complete")")"
  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo ""
  echo "  $(t "setup_run")"
  echo "  $(bold "  cw")"
  echo ""
}

# Generate workspace CLAUDE.md template
# Arguments: <claude_md_path> <ws_name> <ws_description> <ws_file_path>
_generate_workspace_claude_md() {
  local claude_md="$1"
  local ws_name="$2"
  local ws_description="$3"
  local ws_file="$4"

  # Build Linked Repositories table rows
  local dirs_table=""
  if [[ -f "$ws_file" ]]; then
    local count
    count=$(jq '.dirs | length' "$ws_file")
    for ((i=0; i<count; i++)); do
      local path role
      path=$(jq -r ".dirs[$i].path" "$ws_file")
      role=$(jq -r ".dirs[$i].role // \"\"" "$ws_file")
      local label="${role:-$(basename "$path")}"
      dirs_table="${dirs_table}| ${label} | \`${path}\` |"$'\n'
    done
  fi

  local created_at
  created_at=$(date "+%Y-%m-%d")

  # ${ws_name,,} requires bash 4+, use tr for macOS bash 3.2 compatibility
  local ws_name_lower
  ws_name_lower=$(echo "$ws_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  # Use printf to avoid heredoc variable expansion issues
  printf '# Workspace: %s\n\n> %s\n\nCreated: %s\n\n---\n\n## Linked Repositories\n\n| Role | Path |\n|------|------|\n%s\n## Workflow Rules\n\n- **REQUIRED**: Use the `workspace-task-manager` skill for task decomposition and management\n  - Decompose workspace goals into tasks before starting implementation\n  - Each task gets a `YYYY-MM-DD-{task-name}/` directory under this workspace\n  - Follow the superpowers workflow (brainstorming → writing-plans → execute) per task\n  - Save design docs and plans into the task directory, not `docs/plans/`\n- Branch naming convention: `feature/ws-%s-*`\n\n## Current Tasks\n\n| Status | Task | Directory | Priority |\n|--------|------|-----------|----------|\n| | (Use workspace-task-manager skill to populate) | | |\n\n## Notes\n\nRecord notes and design decisions here.\n' \
    "$ws_name" \
    "${ws_description:-Describe this workspace here.}" \
    "$created_at" \
    "$dirs_table" \
    "$ws_name_lower" \
    > "$claude_md"
}

# cw add-dir command
cmd_add_dir() {
  require_jq

  local target_dir
  target_dir="$(pwd)"

  if ! is_workspace "$target_dir"; then
    error "$(t "workspace_not_found"). Run cw setup first."
    exit 1
  fi

  local ws_file="$target_dir/$WORKSPACE_FILE"
  local ws_name
  ws_name=$(ws_get "$ws_file" '.name')

  echo ""
  echo "$(bold "$(t "add_directory"): $ws_name")"
  echo ""

  local new_path="${1:-}"
  if [[ -z "$new_path" ]]; then
    new_path=$(select_dir_with_fzf "$(t "select_dir_prompt")")
  fi
  [[ -z "$new_path" ]] && { info "$(t "cancel")"; exit 0; }

  local expanded_path
  expanded_path=$(expand_path "$new_path")

  if [[ ! -d "$expanded_path" ]]; then
    warn "$(t "dir_not_found"): $expanded_path"
    read -rep "  $(t "add_anyway") [y/N]: " force
    [[ "$force" =~ ^[Yy]$ ]] || exit 0
  fi

  # Check if already registered
  if jq -e --arg p "$expanded_path" '.dirs[] | select(.path == $p)' "$ws_file" &>/dev/null; then
    warn "$(t "already_exists"): $expanded_path"
    exit 0
  fi

  read -rep "  $(t "dir_add_role"): " role

  # Add to workspace.json
  ws_set "$ws_file" \
    --arg path "$expanded_path" \
    --arg role "${role:-}" \
    '.dirs += [{"path": $path, "role": $role}]'

  # Update CLAUDE.md (regenerate Linked Repositories table)
  local claude_md="$target_dir/$WORKSPACE_CLAUDE_MD"
  local ws_description
  ws_description=$(ws_get "$ws_file" '.description')
  _generate_workspace_claude_md "$claude_md" "$ws_name" "$ws_description" "$ws_file"

  success "$(t "dir_added"): $expanded_path"
}

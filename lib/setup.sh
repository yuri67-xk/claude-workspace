#!/usr/bin/env bash
# setup.sh - cw setup command

# Module-level wizard state (shared across phase functions)
_SETUP_NAME=""
_SETUP_DESC=""
_SETUP_DIRS=()
_SETUP_ROLES=()

# Phase 1: Basic Info
# Arguments: [default_name]
_setup_phase1() {
  local default_name="${1:-}"
  echo ""
  if command -v gum >/dev/null 2>&1; then
    gum style --bold "$(t "phase1_header")" 2>/dev/null || true
  else
    echo "=== $(t "phase1_header") ==="
  fi
  echo ""
  _SETUP_NAME=$(gum_input "$(t "workspace_name")" "${default_name}")
  if [[ -z "${_SETUP_NAME}" ]]; then
    error "$(t "workspace_name") $(t "required")"
    return 1
  fi
  _SETUP_DESC=$(gum_input "$(t "workspace_desc")" "")
}

# Phase 2: Directories
_setup_phase2() {
  echo ""
  if command -v gum >/dev/null 2>&1; then
    gum style --bold "$(t "phase2_header")" 2>/dev/null || true
  else
    echo "=== $(t "phase2_header") ==="
  fi
  echo ""

  _SETUP_DIRS=()
  _SETUP_ROLES=()

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
    raw_path=$(gum_path_input "$(t "dir_add_path") ($(t "skip") = Enter)" "" 2>/dev/null || true)

    # Empty input → finish
    if [[ -z "${raw_path}" ]]; then
      break
    fi

    local expanded_path
    expanded_path=$(expand_path "${raw_path}")

    # Validate existence
    if [[ ! -d "${expanded_path}" ]]; then
      gum_error "$(t "dir_not_found"): ${expanded_path}"
      gum_confirm "$(t "path_add_anyway")" || continue
    fi

    local role
    role=$(gum_input "$(t "dir_add_role")" "")

    _SETUP_DIRS+=("${expanded_path}")
    _SETUP_ROLES+=("${role}")
    success "$(t "dir_added"): ${expanded_path}"
  done

  if [[ ${#_SETUP_DIRS[@]} -eq 0 ]]; then
    warn "No directories specified. Use cw add-dir later to add."
  fi
}

# Phase 3: Confirm & Launch
# Arguments: <target_dir>
# Returns: the chosen constant via exit code + global _SETUP_CHOICE
# Prints the choice (LAUNCH, CREATE, or CANCEL) to stdout
_setup_phase3() {
  local target_dir="${1}"
  echo ""
  if command -v gum >/dev/null 2>&1; then
    gum style --bold "$(t "phase3_header")" 2>/dev/null || true
  else
    echo "=== $(t "phase3_header") ==="
  fi
  echo ""

  # Summary
  echo "$(t "phase3_summary"):"
  echo "  $(t "workspace_name"):  ${_SETUP_NAME}"
  if [[ -n "${_SETUP_DESC}" ]]; then
    echo "  $(t "workspace_desc"):  ${_SETUP_DESC}"
  fi
  echo "  $(t "directories"):  ${#_SETUP_DIRS[@]}"
  echo "  $(t "path"):  ${target_dir}"
  echo "  Files: .workspace.json, CLAUDE.md"
  echo ""

  local launch_label create_label cancel_label
  launch_label=$(t "phase3_opt_launch")
  create_label=$(t "phase3_opt_create")
  cancel_label=$(t "phase3_opt_cancel")

  local choice
  choice=$(gum_choose \
    "${launch_label}" "LAUNCH" \
    "${create_label}" "CREATE" \
    "${cancel_label}" "CANCEL")
  echo "${choice}"
}

# Arguments: [prefill_name]
#   prefill_name ... passed when called from cw new to skip name input
cmd_setup() {
  require_jq

  local prefill_name="${1:-}"
  local target_dir
  target_dir="$(pwd)"

  # Source gum wrappers
  # shellcheck source=lib/gum.sh
  local gum_sh="${CW_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/gum.sh"
  [[ -f "${gum_sh}" ]] && source "${gum_sh}" || true

  # Check if already set up as workspace
  if is_workspace "${target_dir}"; then
    warn "$(t "workspace_already_setup")"
    local existing_name
    existing_name=$(ws_get "${target_dir}/${WORKSPACE_FILE}" '.name')
    echo "  $(t "workspace_name"): $(bold "${existing_name}")"
    echo ""
    gum_confirm "$(t "re_setup")" || { info "$(t "cancel")"; exit 0; }
    echo ""
  fi

  echo ""
  echo "$(bold "Claude Workspace Setup")"
  echo "$(dim "$(t "directory"): ${target_dir}")"
  echo ""

  # Determine default name from directory basename
  local default_name
  if [[ -n "${prefill_name}" ]]; then
    default_name="${prefill_name}"
  else
    default_name="$(basename "${target_dir}")"
  fi

  # ── Phase 1: Basic Info ──────────────────────────────────────
  _setup_phase1 "${default_name}" || return 1

  # ── Phase 2: Directories ────────────────────────────────────
  _setup_phase2

  # ── Phase 3: Confirm & Launch ───────────────────────────────
  local choice
  choice=$(_setup_phase3 "${target_dir}")

  case "${choice}" in
    CANCEL|"")
      info "$(t "cancel")"
      return 0
      ;;
    LAUNCH|CREATE)
      # Step: Generate workspace.json
      step "$(t "setup_config_file")"
      local ws_file="${target_dir}/${WORKSPACE_FILE}"
      local created_at
      created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

      local dirs_json="[]"
      for i in "${!_SETUP_DIRS[@]+"${!_SETUP_DIRS[@]}"}"; do
        local dir="${_SETUP_DIRS[$i]}"
        local role="${_SETUP_ROLES[$i]:-}"
        dirs_json=$(echo "${dirs_json}" | jq \
          --arg path "${dir}" \
          --arg role "${role}" \
          '. += [{"path": $path, "role": $role}]')
      done

      jq -n \
        --arg name "${_SETUP_NAME}" \
        --arg description "${_SETUP_DESC}" \
        --arg created_at "${created_at}" \
        --arg workspace_path "${target_dir}" \
        --argjson dirs "${dirs_json}" \
        '{
          name: $name,
          description: $description,
          workspace_path: $workspace_path,
          created_at: $created_at,
          dirs: $dirs
        }' > "${ws_file}"
      success "$(t "created"): ${ws_file}"

      # Step: Generate CLAUDE.md
      step "$(t "setup_claude_md")"
      local claude_md="${target_dir}/${WORKSPACE_CLAUDE_MD}"
      _generate_workspace_claude_md "${claude_md}" "${_SETUP_NAME}" "${_SETUP_DESC}" "${ws_file}"
      success "$(t "created"): ${claude_md}"

      # Step: Install skills
      step "$(t "setup_step6")"
      if [[ -d "${CW_SKILLS_DIR:-}" ]]; then
        gum_spin "$(t "setup_step6")" bash -c "
          ws_skills_dir='${target_dir}/.claude/skills'
          mkdir -p \"\${ws_skills_dir}\"
          for skill_dir in '${CW_SKILLS_DIR}'/*/; do
            [[ -d \"\${skill_dir}\" ]] || continue
            skill_name=\"\$(basename \"\${skill_dir}\")\"
            cp -R \"\${skill_dir}\" \"\${ws_skills_dir}/\${skill_name}\"
          done
        "
        success "$(t "setup_skills_installed"): .claude/skills/"
      fi

      # Step: Register to global registry
      step "$(t "setup_step7")"
      registry_add "${_SETUP_NAME}" "${target_dir}"
      success "$(t "registered"): ~/.claude-workspace/registry.json"

      echo ""
      echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
      echo "$(green "  $(t "setup_complete")")"
      echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
      echo ""

      if [[ "${choice}" == "LAUNCH" ]]; then
        cmd_launch "${target_dir}"
      fi
      ;;
  esac
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

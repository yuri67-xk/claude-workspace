#!/usr/bin/env bash
# launch.sh - cw launch command (Launch Claude Code)

cmd_launch() {
  require_jq

  local target_dir
  target_dir="$(pwd)"

  # If workspace name is provided as argument, find the directory
  if [[ -n "${1:-}" ]]; then
    local found
    found=$(_find_workspace_by_name "$1")
    if [[ -z "$found" ]]; then
      error "$(t "workspace_not_found"): $1"
      echo "  Registered workspaces: cw list"
      exit 1
    fi
    target_dir="$found"
  fi

  if ! is_workspace "$target_dir"; then
    error "$(t "workspace_not_found"): $target_dir"
    echo "  $(dim "$(t "launch_here")")"
    exit 1
  fi

  local ws_file="$target_dir/$WORKSPACE_FILE"
  local ws_name
  ws_name=$(ws_get "$ws_file" '.name')

  echo ""
  echo "$(bold "$(t "workspace_launch"): $ws_name")"

  # Get registered directories
  local dir_count
  dir_count=$(jq '.dirs | length' "$ws_file")

  local add_dir_flags=()
  local valid_count=0

  for ((i=0; i<dir_count; i++)); do
    local dir
    dir=$(jq -r ".dirs[$i].path" "$ws_file")
    local role
    role=$(jq -r ".dirs[$i].role // \"\"" "$ws_file")

    if [[ -d "$dir" ]]; then
      add_dir_flags+=("--add-dir" "$dir")
      local label="${role:-$(basename "$dir")}"
      info "  + $label  $(dim "$dir")"
      ((valid_count++))
    else
      warn "  $(t "skip_not_exist"): $dir"
    fi
  done

  echo ""

  if [[ $valid_count -eq 0 ]]; then
    warn "$(t "launch_valid_dirs")."
    warn "$(t "launch_use_add_dir")."
  fi

  # Check if Claude Code exists
  if ! command -v claude &>/dev/null; then
    error "$(t "error_claude_not_found")"
    echo "  Install: npm install -g @anthropic-ai/claude-code"
    exit 1
  fi

  echo "  $(dim "claude ${add_dir_flags[*]+"${add_dir_flags[*]}"}")"
  echo ""

  # Update last_used (only if registry exists)
  registry_touch "$target_dir"

  # Launch Claude Code in workspace directory
  cd "$target_dir"
  exec claude "${add_dir_flags[@]+"${add_dir_flags[@]}"}"
}

# Find workspace directory by name
# Prioritize registry, then search filesystem
_find_workspace_by_name() {
  local name="$1"

  # Check global registry first (use registry.sh function)
  local found
  found=$(registry_get_by_name "$name")
  [[ -n "$found" ]] && { echo "$found"; return; }

  # Fallback: Search under WorkingProjects
  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_name
      ws_name=$(jq -r '.name' "$ws_file" 2>/dev/null)
      if [[ "$ws_name" == "$name" ]]; then
        dirname "$ws_file"
        return
      fi
    done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null)
  fi
}

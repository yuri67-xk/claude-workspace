#!/usr/bin/env bash
# new.sh - cw new command
# Creates a new Workspace folder under WorkingProjects/ and sets it up

# Source gum wrappers (optional, graceful degradation)
_gum_sh="${CW_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/gum.sh"
[[ -f "${_gum_sh}" ]] && source "${_gum_sh}" || true

cmd_new() {
  require_jq

  # Normalize WORKING_PROJECTS_DIR to absolute path
  local raw_wp="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  local wp_dir
  wp_dir=$(expand_path "$raw_wp")

  echo ""
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(bold "  $(t "new_workspace")")"
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo ""

  # ──────────────────────────────
  # Determine Workspace name
  # ──────────────────────────────
  local ws_name="${1:-}"

  if [[ -z "$ws_name" ]]; then
    read -rep "  $(t "workspace_name"): " ws_name
    ws_name="${ws_name%"${ws_name##*[![:space:]]}"}"  # trim trailing spaces
    ws_name="${ws_name#"${ws_name%%[![:space:]]*}"}"  # trim leading spaces
    if [[ -z "$ws_name" ]]; then
      error "$(t "workspace_name") $(t "required")"
      exit 1
    fi
  fi

  # ──────────────────────────────
  # Generate folder name
  # Spaces -> hyphens, remove leading/trailing hyphens
  # ──────────────────────────────
  local folder_name
  folder_name=$(echo "$ws_name" | tr '/ \\:*?' '-' | sed 's/^-*//;s/-*$//' | sed 's/-\{2,\}/-/g')

  local target_dir="$wp_dir/$folder_name"

  echo ""
  echo "  $(bold "$(t "workspace_name")"):  $ws_name"
  echo "  $(bold "$(t "directory")"):       $target_dir"
  echo ""

  # Already exists
  if [[ -d "$target_dir" ]]; then
    if is_workspace "$target_dir"; then
      warn "$(t "already_exists")"
      if gum_confirm "$(t "launch_as_is")"; then
        cd "$target_dir"
        cmd_launch
      fi
      return
    else
      warn "$(t "directory") $(t "already_exists"): $target_dir"
      gum_confirm "$(t "workspace_setup")?" || { info "$(t "cancel")"; exit 0; }
    fi
  else
    gum_confirm "$(t "create")" || { info "$(t "cancel")"; exit 0; }

    mkdir -p "$target_dir"
    success "$(t "created"): $target_dir"
  fi

  # ──────────────────────────────
  # Move to created directory and run setup
  # (pass ws_name to skip name input)
  # ──────────────────────────────
  cd "$target_dir"
  cmd_setup "$ws_name"
}

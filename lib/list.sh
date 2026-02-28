#!/usr/bin/env bash
# list.sh - cw list command

cmd_list() {
  require_jq

  echo ""
  echo "$(bold "$(t "workspace_list")")"
  echo ""

  # ──────────────────────────────
  # Get from global registry (priority)
  # ──────────────────────────────
  local ws_list
  ws_list=$(registry_list)

  local ws_count
  ws_count=$(echo "$ws_list" | jq 'length')

  if [[ $ws_count -gt 0 ]]; then
    local found_any=false

    while IFS= read -r ws; do
      local name path last_used
      name=$(echo "$ws" | jq -r '.name')
      path=$(echo "$ws" | jq -r '.path')
      last_used=$(echo "$ws" | jq -r '.last_used // ""')

      # Check directory exists
      local status_suffix=""
      if [[ ! -d "$path" ]]; then
        status_suffix="  $(red "✗ $(t "path_missing")")"
      fi

      # Current location marker
      local marker=""
      [[ "$path" == "$(pwd)" ]] && marker="  $(green "← $(t "current_location")")"

      # Relative time
      local time_label=""
      if [[ -n "$last_used" ]]; then
        local rel
        rel=$(_relative_time "$last_used")
        [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
      fi

      # dirs count (if .workspace.json exists)
      local dir_count=0
      local ws_file="$path/$WORKSPACE_FILE"
      if [[ -f "$ws_file" ]]; then
        dir_count=$(jq '.dirs | length' "$ws_file" 2>/dev/null || echo 0)
      fi

      echo "  $(bold "$name")${marker}${status_suffix}${time_label}"
      echo "  $(dim "$path")  [${dir_count} $(t "list_dirs")]"
      echo ""
      found_any=true
    done < <(echo "$ws_list" | jq -c '.[]')

    if ! $found_any; then
      _list_empty_message
    fi
  else
    # Registry empty, fallback to filesystem search
    _list_from_filesystem
  fi
}

# ──────────────────────────────
# Fallback: Search filesystem
# ──────────────────────────────
_list_from_filesystem() {
  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  local found_any=false

  [[ -d "$search_base" ]] || { _list_empty_message; return; }

  while IFS= read -r ws_file; do
    local ws_dir ws_name ws_desc dir_count
    ws_dir=$(dirname "$ws_file")
    ws_name=$(ws_get "$ws_file" '.name')
    ws_desc=$(ws_get "$ws_file" '.description // ""')
    dir_count=$(jq '.dirs | length' "$ws_file")

    local marker=""
    [[ "$ws_dir" == "$(pwd)" ]] && marker="  $(green "← $(t "current_location")")"

    echo "  $(bold "$ws_name")${marker}"
    [[ -n "$ws_desc" ]] && echo "  $(dim "$ws_desc")"
    echo "  $(dim "$ws_dir")  [${dir_count} $(t "list_dirs")]"
    echo ""
    found_any=true
  done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null | sort)

  if ! $found_any; then
    _list_empty_message
  fi
}

_list_empty_message() {
  info "$(t "workspace_not_found")"
  echo "  $(dim "$(t "list_empty")")"
}

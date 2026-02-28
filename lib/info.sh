#!/usr/bin/env bash
# info.sh - cw info command

cmd_info() {
  require_jq

  local target_dir
  target_dir="$(pwd)"

  if ! is_workspace "$target_dir"; then
    error "$(t "workspace_not_found")"
    echo "  $(dim "Run cw setup")"
    exit 1
  fi

  local ws_file="$target_dir/$WORKSPACE_FILE"

  echo ""
  echo "$(bold "$(t "workspace_detail")")"
  echo ""

  local ws_name ws_desc ws_created
  ws_name=$(ws_get "$ws_file" '.name')
  ws_desc=$(ws_get "$ws_file" '.description // ""')
  ws_created=$(ws_get "$ws_file" '.created_at // ""')

  echo "  $(bold "$(t "info_name")"):      $ws_name"
  [[ -n "$ws_desc" ]] && echo "  $(bold "$(t "info_desc")"):      $ws_desc"
  [[ -n "$ws_created" ]] && echo "  $(bold "$(t "info_created")"):    $ws_created"
  echo "  $(bold "$(t "info_path")"):      $target_dir"
  echo ""

  local dir_count
  dir_count=$(jq '.dirs | length' "$ws_file")
  echo "  $(bold "$(t "info_registered_dirs")") (${dir_count})"
  echo ""

  for ((i=0; i<dir_count; i++)); do
    local path role status_icon
    path=$(jq -r ".dirs[$i].path" "$ws_file")
    role=$(jq -r ".dirs[$i].role // \"\"" "$ws_file")

    if [[ -d "$path" ]]; then
      status_icon=$(green "✓")
    else
      status_icon=$(red "✗")
    fi

    local label="${role:-$(basename "$path")}"
    echo "  ${status_icon}  $(bold "$label")"
    echo "     $(dim "$path")"

    # Check CLAUDE.md exists
    if [[ -f "$path/CLAUDE.md" ]]; then
      echo "     $(cyan "$(t "info_claude_md_exists")")"
    fi
    echo ""
  done
}

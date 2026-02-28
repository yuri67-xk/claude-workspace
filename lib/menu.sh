#!/usr/bin/env bash
# menu.sh - Interactive Workspace selection menu

cmd_menu() {
  require_jq

  echo ""
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(bold "  claude-workspace (cw)")"
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"

  # ──────────────────────────────
  # Build list from registry + filesystem
  # ──────────────────────────────
  local menu_paths=()
  local menu_names=()
  local menu_times=()
  local menu_registered=()  # true = registered, false = unregistered

  # 1) Get from registry (sorted by last_used desc)
  local ws_list
  ws_list=$(registry_list)

  while IFS= read -r ws; do
    local name path last_used
    name=$(echo "$ws" | jq -r '.name')
    path=$(echo "$ws" | jq -r '.path')
    last_used=$(echo "$ws" | jq -r '.last_used // ""')

    menu_paths+=("$path")
    menu_names+=("$name")
    menu_times+=("$last_used")
    menu_registered+=("true")
  done < <(echo "$ws_list" | jq -c '.[]' 2>/dev/null)

  # 2) Scan filesystem for unregistered workspaces
  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_dir ws_name
      ws_dir=$(dirname "$ws_file")
      ws_name=$(ws_get "$ws_file" '.name')

      # Check if already in registry
      local already=false
      for p in "${menu_paths[@]+"${menu_paths[@]}"}"; do
        [[ "$p" == "$ws_dir" ]] && already=true && break
      done
      $already && continue

      menu_paths+=("$ws_dir")
      menu_names+=("$ws_name")
      menu_times+=("")
      menu_registered+=("false")
    done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null | sort)
  fi

  # ──────────────────────────────
  # No workspaces found
  # ──────────────────────────────
  if [[ ${#menu_paths[@]} -eq 0 ]]; then
    echo ""
    info "$(t "workspace_not_found")"
    echo ""
    _menu_prompt_new
    return
  fi

  # ──────────────────────────────
  # Display list
  # ──────────────────────────────
  echo ""
  echo "  $(bold "$(t "menu_recent")")"
  echo ""

  local i=0
  for idx in "${!menu_paths[@]}"; do
    local path="${menu_paths[$idx]}"
    local name="${menu_names[$idx]}"
    local last_used="${menu_times[$idx]}"
    local registered="${menu_registered[$idx]}"

    i=$((i + 1))

    # Status marker
    local status_marker=""
    if [[ ! -d "$path" ]]; then
      status_marker="  $(red "✗ $(t "path_missing")")"
    elif [[ "$path" == "$(pwd)" ]]; then
      status_marker="  $(green "← $(t "current_location")")"
    fi

    # Unregistered marker
    local unreg_label=""
    [[ "$registered" == "false" ]] && unreg_label="  $(yellow "$(t "unregistered")")"

    # Relative time
    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    printf "  [%d] $(bold "%s")%s%s%s\n" \
      "$i" "$name" "$time_label" "$unreg_label" "$status_marker"
    printf "      $(dim "%s")\n" "$path"
    echo ""
  done

  # ──────────────────────────────
  # Options
  # ──────────────────────────────
  echo "  $(dim "────────────────────────────────────────")"
  echo "  [N] $(t "menu_create_new")"
  echo "  [Q] $(t "menu_quit")"
  echo ""

  local choice
  read -rep "  $(t "cmd_select") [1-${i} / N / Q]: " choice
  echo ""

  case "$choice" in
    [Nn])
      cmd_new
      ;;
    [Qq]|"")
      info "$(t "cmd_quit")"
      exit 0
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && \
         [[ $choice -ge 1 ]] && \
         [[ $choice -le ${#menu_paths[@]} ]]; then

        local sel_idx=$(( choice - 1 ))
        local selected_path="${menu_paths[$sel_idx]}"
        local selected_name="${menu_names[$sel_idx]}"
        local selected_reg="${menu_registered[$sel_idx]}"

        if [[ ! -d "$selected_path" ]]; then
          error "$(t "dir_not_found"): $selected_path"
          echo "  $(dim "cw forget")"
          exit 1
        fi

        # Auto-register if unregistered
        if [[ "$selected_reg" == "false" ]]; then
          registry_add "$selected_name" "$selected_path"
          success "$(t "registered"): $selected_name"
        fi

        cd "$selected_path"
        cmd_launch
      else
        error "$(t "invalid"): $choice"
        exit 1
      fi
      ;;
  esac
}

# ──────────────────────────────
# Prompt to create new (when 0 workspaces)
# ──────────────────────────────
_menu_prompt_new() {
  read -rep "  $(t "new_workspace")? [Y/n]: " ans
  [[ "$ans" =~ ^[Nn]$ ]] && exit 0
  cmd_new
}

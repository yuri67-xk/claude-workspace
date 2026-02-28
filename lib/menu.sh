#!/usr/bin/env bash
# menu.sh - Interactive Workspace selection menu (fzf + preview + sub-menu)

cmd_menu() {
  require_jq

  # Build workspace list (registry first, then filesystem)
  local menu_paths=()
  local menu_names=()
  local menu_times=()
  local menu_registered=()

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

  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_dir ws_name
      ws_dir=$(dirname "$ws_file")
      ws_name=$(ws_get "$ws_file" '.name')
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

  if command -v fzf &>/dev/null; then
    _menu_fzf menu_paths menu_names menu_times menu_registered
  else
    _menu_numbered menu_paths menu_names menu_times menu_registered
  fi
}

# ──────────────────────────────
# fzf main menu with preview
# ──────────────────────────────
_menu_fzf() {
  local -n _paths=$1
  local -n _names=$2
  local -n _times=$3
  local -n _registered=$4

  # Build tab-separated fzf input: PATH\tDISPLAY
  local fzf_entries=""
  fzf_entries+=$'CREATE_NEW\t'"$(t "menu_create_new")"$'\n'

  local idx
  for idx in "${!_paths[@]}"; do
    local path="${_paths[$idx]}"
    local name="${_names[$idx]}"
    local last_used="${_times[$idx]}"
    local reg="${_registered[$idx]}"

    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    local unreg_label=""
    [[ "$reg" == "false" ]] && unreg_label="  $(yellow "[unregistered]")"

    local status_label=""
    [[ ! -d "$path" ]] && status_label="  $(red "[missing]")"

    fzf_entries+="${path}"$'\t'"${name}${time_label}${unreg_label}${status_label}"$'\n'
  done

  # Preview script (reads {1}/.workspace.json via jq)
  local preview_script
  preview_script=$(cat <<'PREVIEW'
ws_path={1}
ws_file="${ws_path}/.workspace.json"
if [[ "$ws_path" == "CREATE_NEW" ]]; then
  echo ""
  echo "  Create a new Claude Workspace"
  echo ""
  echo "  A new directory will be created under"
  echo "  ~/WorkingProjects/ and set up for cw."
elif [[ -f "$ws_file" ]]; then
  name=$(jq -r '.name // ""' "$ws_file" 2>/dev/null)
  desc=$(jq -r '.description // ""' "$ws_file" 2>/dev/null)
  created=$(jq -r '.created_at // ""' "$ws_file" 2>/dev/null)
  dir_count=$(jq '.dirs | length' "$ws_file" 2>/dev/null || echo 0)
  echo ""
  echo "  $name"
  [[ -n "$desc" ]] && echo "  $desc"
  echo ""
  echo "  $ws_path"
  echo "  Dirs: $dir_count    Created: ${created:0:10}"
  echo ""
  while IFS= read -r dir_entry; do
    dir_path=$(echo "$dir_entry" | jq -r '.path' 2>/dev/null)
    dir_role=$(echo "$dir_entry" | jq -r '.role // ""' 2>/dev/null)
    label="${dir_role:-$(basename "$dir_path")}"
    if [[ -d "$dir_path" ]]; then
      echo "  ✓  $label"
    else
      echo "  ✗  $label  (missing)"
    fi
  done < <(jq -c '.dirs[]' "$ws_file" 2>/dev/null)
else
  echo ""
  echo "  (no .workspace.json found)"
  echo "  $ws_path"
fi
PREVIEW
)

  local selected
  selected=$(printf '%s' "$fzf_entries" | \
    fzf --ansi \
        --height=70% --border \
        --delimiter=$'\t' \
        --with-nth='2..' \
        --header="  claude-workspace (cw)" \
        --header-first \
        --preview="$preview_script" \
        --preview-window='right:45%:wrap' \
        --prompt='  Workspace > ' \
        2>/dev/null || true)

  [[ -z "$selected" ]] && { echo ""; info "$(t "cmd_quit")"; return 0; }

  local selected_path
  selected_path=$(printf '%s' "$selected" | cut -f1)

  if [[ "$selected_path" == "CREATE_NEW" ]]; then
    cmd_new
    return
  fi

  # Auto-register unregistered workspaces
  for idx in "${!_paths[@]}"; do
    if [[ "${_paths[$idx]}" == "$selected_path" ]]; then
      if [[ "${_registered[$idx]}" == "false" ]]; then
        local sel_name="${_names[$idx]}"
        registry_add "$sel_name" "$selected_path"
        success "$(t "registered"): $sel_name"
      fi
      break
    fi
  done

  if [[ ! -d "$selected_path" ]]; then
    error "$(t "dir_not_found"): $selected_path"
    exit 1
  fi

  local selected_name
  selected_name=$(jq -r '.name' "${selected_path}/${WORKSPACE_FILE}" 2>/dev/null)

  _menu_submenu "$selected_path" "$selected_name"
}

# ──────────────────────────────
# Action picker for selected workspace
# ──────────────────────────────
_menu_submenu() {
  local ws_path="$1"
  local ws_name="$2"

  local resume_label add_dir_label info_label finder_label forget_label back_label
  resume_label=$(t "menu_action_resume")
  add_dir_label=$(t "menu_action_add_dir")
  info_label=$(t "menu_action_info")
  finder_label=$(t "menu_action_finder")
  forget_label=$(t "menu_action_forget")
  back_label=$(t "menu_action_back")

  local action
  action=$(printf '%s\n' \
    "$resume_label" \
    "$add_dir_label" \
    "$info_label" \
    "$finder_label" \
    "$forget_label" \
    "$back_label" | \
    fzf --height=40% --border \
        --header="  $ws_name" \
        --header-first \
        --prompt='  Action > ' \
        2>/dev/null || true)

  [[ -z "$action" ]] && { cmd_menu; return; }

  if [[ "$action" == "$resume_label" ]]; then
    cd "$ws_path"
    cmd_launch

  elif [[ "$action" == "$add_dir_label" ]]; then
    cd "$ws_path"
    cmd_add_dir
    _menu_submenu "$ws_path" "$ws_name"

  elif [[ "$action" == "$info_label" ]]; then
    cd "$ws_path"
    cmd_info
    echo ""
    read -rp "  $(t "press_enter"): " _ignored
    _menu_submenu "$ws_path" "$ws_name"

  elif [[ "$action" == "$finder_label" ]]; then
    open "$ws_path"
    _menu_submenu "$ws_path" "$ws_name"

  elif [[ "$action" == "$forget_label" ]]; then
    _menu_forget "$ws_path" "$ws_name"

  elif [[ "$action" == "$back_label" ]]; then
    cmd_menu
  fi
}

# ──────────────────────────────
# Forget workspace (without pwd dependency)
# ──────────────────────────────
_menu_forget() {
  local ws_path="$1"
  local ws_name="$2"

  echo ""
  warn "\"${ws_name}\" $(t "remove_from_registry")"
  echo "  $(dim "$(t "files_remain")")"
  echo ""
  read -rp "  $(t "continue") [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    registry_remove "$ws_path"
    success "$(t "deleted"): $ws_name"
    echo ""
  else
    info "$(t "cancel")"
  fi
  cmd_menu
}

# ──────────────────────────────
# Numbered fallback (when fzf is unavailable)
# ──────────────────────────────
_menu_numbered() {
  local -n _paths=$1
  local -n _names=$2
  local -n _times=$3
  local -n _registered=$4

  echo ""
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(bold "  claude-workspace (cw)")"
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"

  if [[ ${#_paths[@]} -eq 0 ]]; then
    echo ""
    info "$(t "workspace_not_found")"
    echo ""
    _menu_prompt_new
    return
  fi

  echo ""
  echo "  $(bold "$(t "menu_recent")")"
  echo ""

  local i=0
  for idx in "${!_paths[@]}"; do
    local path="${_paths[$idx]}"
    local name="${_names[$idx]}"
    local last_used="${_times[$idx]}"
    local registered="${_registered[$idx]}"
    i=$((i + 1))

    local status_marker=""
    if [[ ! -d "$path" ]]; then
      status_marker="  $(red "✗ $(t "path_missing")")"
    elif [[ "$path" == "$(pwd)" ]]; then
      status_marker="  $(green "← $(t "current_location")")"
    fi

    local unreg_label=""
    [[ "$registered" == "false" ]] && unreg_label="  $(yellow "$(t "unregistered")")"

    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    printf "  [%d] $(bold "%s")%s%s%s\n" "$i" "$name" "$time_label" "$unreg_label" "$status_marker"
    printf "      $(dim "%s")\n" "$path"
    echo ""
  done

  echo "  $(dim "────────────────────────────────────────")"
  echo "  [N] $(t "menu_create_new")"
  echo "  [Q] $(t "menu_quit")"
  echo ""

  local choice
  read -rep "  $(t "cmd_select") [1-${i} / N / Q]: " choice
  echo ""

  case "$choice" in
    [Nn]) cmd_new ;;
    [Qq]|"") info "$(t "cmd_quit")"; exit 0 ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && \
         [[ $choice -ge 1 ]] && \
         [[ $choice -le ${#_paths[@]} ]]; then

        local sel_idx=$(( choice - 1 ))
        local selected_path="${_paths[$sel_idx]}"
        local selected_name="${_names[$sel_idx]}"
        local selected_reg="${_registered[$sel_idx]}"

        if [[ ! -d "$selected_path" ]]; then
          error "$(t "dir_not_found"): $selected_path"
          exit 1
        fi

        if [[ "$selected_reg" == "false" ]]; then
          registry_add "$selected_name" "$selected_path"
          success "$(t "registered"): $selected_name"
        fi

        _menu_submenu "$selected_path" "$selected_name"
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

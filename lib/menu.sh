#!/usr/bin/env bash
# menu.sh - Interactive Workspace selection menu

# Module-level arrays (no nameref needed, bash 3.2 compatible)
_CW_MENU_PATHS=()
_CW_MENU_NAMES=()
_CW_MENU_TIMES=()
_CW_MENU_REGISTERED=()

# ──────────────────────────────
# Build workspace list into module arrays
# ──────────────────────────────
_cw_menu_build_list() {
  _CW_MENU_PATHS=()
  _CW_MENU_NAMES=()
  _CW_MENU_TIMES=()
  _CW_MENU_REGISTERED=()

  local ws_list
  ws_list=$(registry_list)

  while IFS= read -r ws; do
    local name path last_used
    name=$(echo "$ws" | jq -r '.name')
    path=$(echo "$ws" | jq -r '.path')
    last_used=$(echo "$ws" | jq -r '.last_used // ""')
    _CW_MENU_PATHS+=("$path")
    _CW_MENU_NAMES+=("$name")
    _CW_MENU_TIMES+=("$last_used")
    _CW_MENU_REGISTERED+=("true")
  done < <(echo "$ws_list" | jq -c '.[]' 2>/dev/null)

  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_dir ws_name
      ws_dir=$(dirname "$ws_file")
      ws_name=$(ws_get "$ws_file" '.name')
      local already=false
      local p
      for p in "${_CW_MENU_PATHS[@]+"${_CW_MENU_PATHS[@]}"}"; do
        [[ "$p" == "$ws_dir" ]] && already=true && break
      done
      $already && continue
      _CW_MENU_PATHS+=("$ws_dir")
      _CW_MENU_NAMES+=("$ws_name")
      _CW_MENU_TIMES+=("")
      _CW_MENU_REGISTERED+=("false")
    done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null | sort)
  fi
}

# ──────────────────────────────
# Main entry point
# ──────────────────────────────
cmd_menu() {
  require_jq
  _cw_menu_build_list

  while true; do
    local selected_path
    if command -v fzf &>/dev/null; then
      selected_path=$(_menu_fzf_pick)
    else
      selected_path=$(_menu_numbered_pick)
    fi

    # Empty = Esc/quit
    if [[ -z "$selected_path" ]]; then
      echo ""
      info "$(t "cmd_quit")"
      return 0
    fi

    # Create new workspace
    if [[ "$selected_path" == "CREATE_NEW" ]]; then
      cmd_new
      return
    fi

    # Auto-register if unregistered
    local idx
    for idx in "${!_CW_MENU_PATHS[@]}"; do
      if [[ "${_CW_MENU_PATHS[$idx]}" == "$selected_path" ]]; then
        if [[ "${_CW_MENU_REGISTERED[$idx]}" == "false" ]]; then
          registry_add "${_CW_MENU_NAMES[$idx]}" "$selected_path"
          success "$(t "registered"): ${_CW_MENU_NAMES[$idx]}"
        fi
        break
      fi
    done

    if [[ ! -d "$selected_path" ]]; then
      error "$(t "dir_not_found"): $selected_path"
      continue
    fi

    local ws_name
    ws_name=$(jq -r '.name' "${selected_path}/${WORKSPACE_FILE}" 2>/dev/null)

    # Show submenu and handle result
    local submenu_result
    submenu_result=$(_menu_submenu_pick "$selected_path" "$ws_name")

    case "$submenu_result" in
      LAUNCH)
        cd "$selected_path"
        cmd_launch
        return
        ;;
      ADD_DIR)
        (cd "$selected_path" && cmd_add_dir) || true
        _cw_menu_build_list
        # Re-show submenu after add-dir
        submenu_result=$(_menu_submenu_pick "$selected_path" "$ws_name")
        [[ "$submenu_result" == "LAUNCH" ]] && { cd "$selected_path"; cmd_launch; return; }
        continue
        ;;
      INFO)
        (cd "$selected_path" && cmd_info) || true
        echo ""
        read -rp "  $(t "press_enter"): " _
        continue
        ;;
      FINDER)
        open "$selected_path"
        continue
        ;;
      FORGET)
        _menu_forget "$selected_path" "$ws_name"
        _cw_menu_build_list
        continue
        ;;
      *)
        # BACK or empty — loop back to main list
        continue
        ;;
    esac
  done
}

# ──────────────────────────────
# fzf picker: returns selected PATH or CREATE_NEW or empty string
# ──────────────────────────────
_menu_fzf_pick() {
  # Build tab-separated fzf input: PATH\tDISPLAY
  local fzf_entries=""
  fzf_entries+=$'CREATE_NEW\t'"$(t "menu_create_new")"$'\n'

  local idx
  for idx in "${!_CW_MENU_PATHS[@]}"; do
    local path="${_CW_MENU_PATHS[$idx]}"
    local name="${_CW_MENU_NAMES[$idx]}"
    local last_used="${_CW_MENU_TIMES[$idx]}"
    local reg="${_CW_MENU_REGISTERED[$idx]}"

    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    local extra_label=""
    [[ "$reg" == "false" ]] && extra_label+="  $(yellow "[unregistered]")"
    [[ ! -d "$path" ]] && extra_label+="  $(red "[missing]")"

    fzf_entries+="${path}"$'\t'"${name}${time_label}${extra_label}"$'\n'
  done

  # Preview script (no bash vars — uses fzf {1} placeholder)
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

  [[ -z "$selected" ]] && echo "" && return 0

  # Return the PATH (field 1, before the tab)
  printf '%s' "$selected" | cut -f1
}

# ──────────────────────────────
# Numbered picker (no fzf): returns selected PATH or CREATE_NEW or empty
# ──────────────────────────────
_menu_numbered_pick() {
  echo "" >&2
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")" >&2
  echo "$(bold "  claude-workspace (cw)")" >&2
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")" >&2

  if [[ ${#_CW_MENU_PATHS[@]} -eq 0 ]]; then
    echo "" >&2
    info "$(t "workspace_not_found")" >&2
    echo "" >&2
    read -rep "  $(t "new_workspace")? [Y/n]: " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
      echo "CREATE_NEW"
    else
      echo ""
    fi
    return 0
  fi

  echo "" >&2
  echo "  $(bold "$(t "menu_recent")")" >&2
  echo "" >&2

  local i=0
  local idx
  for idx in "${!_CW_MENU_PATHS[@]}"; do
    local path="${_CW_MENU_PATHS[$idx]}"
    local name="${_CW_MENU_NAMES[$idx]}"
    local last_used="${_CW_MENU_TIMES[$idx]}"
    local registered="${_CW_MENU_REGISTERED[$idx]}"
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

    printf "  [%d] $(bold "%s")%s%s%s\n" "$i" "$name" "$time_label" "$unreg_label" "$status_marker" >&2
    printf "      $(dim "%s")\n" "$path" >&2
    echo "" >&2
  done

  echo "  $(dim "────────────────────────────────────────")" >&2
  echo "  [N] $(t "menu_create_new")" >&2
  echo "  [Q] $(t "menu_quit")" >&2
  echo "" >&2

  local choice
  read -rep "  $(t "cmd_select") [1-${i} / N / Q]: " choice
  echo "" >&2

  case "$choice" in
    [Nn])
      echo "CREATE_NEW"
      ;;
    [Qq]|"")
      echo ""
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && \
         [[ $choice -ge 1 ]] && \
         [[ $choice -le ${#_CW_MENU_PATHS[@]} ]]; then
        local sel_idx=$(( choice - 1 ))
        echo "${_CW_MENU_PATHS[$sel_idx]}"
      else
        error "$(t "invalid"): $choice" >&2
        echo ""
      fi
      ;;
  esac
}

# ──────────────────────────────
# Submenu picker: returns action code
# Returns: LAUNCH, ADD_DIR, INFO, FINDER, FORGET, BACK, or empty
# ──────────────────────────────
_menu_submenu_pick() {
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
  if command -v fzf &>/dev/null; then
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
  else
    # Numbered submenu fallback (no fzf)
    echo ""
    echo "  $(bold "$ws_name")"
    echo ""
    echo "  1) $resume_label"
    echo "  2) $add_dir_label"
    echo "  3) $info_label"
    echo "  4) $finder_label"
    echo "  5) $forget_label"
    echo "  6) $back_label"
    echo ""
    local sub_choice
    read -rep "  Select [1-6]: " sub_choice
    case "$sub_choice" in
      1) action="$resume_label" ;;
      2) action="$add_dir_label" ;;
      3) action="$info_label" ;;
      4) action="$finder_label" ;;
      5) action="$forget_label" ;;
      6) action="$back_label" ;;
      *) action="$back_label" ;;
    esac
  fi

  if [[ -z "$action" ]] || [[ "$action" == "$back_label" ]]; then
    echo "BACK"
  elif [[ "$action" == "$resume_label" ]]; then
    echo "LAUNCH"
  elif [[ "$action" == "$add_dir_label" ]]; then
    echo "ADD_DIR"
  elif [[ "$action" == "$info_label" ]]; then
    echo "INFO"
  elif [[ "$action" == "$finder_label" ]]; then
    echo "FINDER"
  elif [[ "$action" == "$forget_label" ]]; then
    echo "FORGET"
  else
    echo "BACK"
  fi
}

# ──────────────────────────────
# Forget workspace (no pwd dependency)
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
}

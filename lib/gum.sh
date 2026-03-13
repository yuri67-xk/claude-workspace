#!/usr/bin/env bash
# lib/gum.sh — gum abstraction layer with fallbacks
# Source this file from other lib/*.sh files that need interactive UI.
# gum is optional: https://github.com/charmbracelet/gum

_gum_available() { command -v gum >/dev/null 2>&1; }
_fzf_available() { command -v fzf >/dev/null 2>&1; }

# gum_input <prompt> [default]
# Prints the entered value to stdout.
gum_input() {
  local prompt="${1:-Input}"
  local default="${2:-}"
  if _gum_available; then
    local result
    result=$(gum input --placeholder "${default}" --prompt "${prompt}: " 2>/dev/null || true)
    echo "${result:-$default}"
  else
    local result
    if [[ -n "${default}" ]]; then
      read -rep "${prompt} [${default}]: " result || true
      echo "${result:-$default}"
    else
      read -rep "${prompt}: " result || true
      echo "${result}"
    fi
  fi
}

# gum_confirm <message>
# Returns 0 for yes, 1 for no.
gum_confirm() {
  local message="${1:-Continue?}"
  if _gum_available; then
    gum confirm "${message}"
  else
    local answer
    read -rep "${message} [y/N]: " answer || true
    case "$(echo "${answer}" | tr '[:upper:]' '[:lower:]')" in
      y|yes) return 0 ;;
      *)     return 1 ;;
    esac
  fi
}

# gum_spin <title> <command> [args...]
# Runs command with a spinner. Propagates exit code. bash 3.2 safe.
gum_spin() {
  local title="${1}"
  shift
  if _gum_available; then
    gum spin --title "${title}" -- "$@"
  else
    "$@"
  fi
}

# gum_error <message>
# Prints a styled error message to stderr.
gum_error() {
  local message="${1:-Error}"
  if _gum_available; then
    gum style --foreground 196 --border normal --border-foreground 196 \
      --padding "0 1" -- "${message}" >&2
  elif declare -f error >/dev/null 2>&1; then
    error "${message}"
  else
    echo "ERROR: ${message}" >&2
  fi
}

# gum_choose <label1> <value1> [<label2> <value2> ...]
# Displays a selection menu. Prints the VALUE of the chosen option to stdout.
# Must be called with an even number of arguments (label/value pairs).
gum_choose() {
  local labels=()
  local values=()
  while [[ $# -ge 2 ]]; do
    labels+=("$1")
    values+=("$2")
    shift 2
  done

  if [[ ${#labels[@]} -eq 0 ]]; then
    return 1
  fi

  if _gum_available; then
    local chosen
    chosen=$(printf '%s\n' "${labels[@]}" | gum choose 2>/dev/null || true)
    local i
    for i in "${!labels[@]}"; do
      if [[ "${labels[$i]}" == "${chosen}" ]]; then
        echo "${values[$i]}"
        return 0
      fi
    done
    echo ""
    return 1
  else
    # Numbered menu fallback
    local i
    for i in "${!labels[@]}"; do
      echo "  $((i+1))) ${labels[$i]}" >&2
    done
    local answer
    read -rep "Choice [1-${#labels[@]}]: " answer || true
    if [[ "${answer}" =~ ^[0-9]+$ ]]; then
      local idx=$(( answer - 1 ))
      if [[ $idx -ge 0 && $idx -lt ${#values[@]} ]]; then
        echo "${values[$idx]}"
        return 0
      fi
    fi
    echo ""
    return 1
  fi
}

# gum_path_input <prompt> [default]
# Tool-combination-aware directory selector. Prints path to stdout.
gum_path_input() {
  local prompt="${1:-Directory}"
  local default="${2:-}"
  if _gum_available && _fzf_available; then
    gum style --foreground 111 "${prompt}:" 2>/dev/null || echo "${prompt}:"
    local selected
    selected=$(find "${HOME}" -maxdepth 4 -type d 2>/dev/null | \
      fzf --height 40% --prompt "> " --query "${default}" 2>/dev/null || true)
    echo "${selected:-$default}"
  elif _gum_available; then
    gum_input "${prompt}" "${default}"
  elif _fzf_available; then
    if declare -f select_dir_with_fzf >/dev/null 2>&1; then
      select_dir_with_fzf
    else
      local selected
      selected=$(find "${HOME}" -maxdepth 4 -type d 2>/dev/null | \
        fzf --height 40% --prompt "${prompt}: " --query "${default}" 2>/dev/null || true)
      echo "${selected:-$default}"
    fi
  else
    local result
    if [[ -n "${default}" ]]; then
      read -rep "${prompt} [${default}]: " result || true
      echo "${result:-$default}"
    else
      read -rep "${prompt}: " result || true
      echo "${result}"
    fi
  fi
}

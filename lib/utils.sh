#!/usr/bin/env bash
# utils.sh - Common utilities

# ──────────────────────────────
# Colors / Styles
# ──────────────────────────────
bold()    { echo -e "\033[1m$*\033[0m"; }
green()   { echo -e "\033[32m$*\033[0m"; }
yellow()  { echo -e "\033[33m$*\033[0m"; }
cyan()    { echo -e "\033[36m$*\033[0m"; }
red()     { echo -e "\033[31m$*\033[0m"; }
dim()     { echo -e "\033[2m$*\033[0m"; }

info()    { echo "  $(cyan "ℹ") $*"; }
success() { echo "  $(green "✓") $*"; }
warn()    { echo "  $(yellow "⚠") $*" >&2; }
error()   { echo "  $(red "✗") $*" >&2; }
step()    { echo ""; echo "$(bold "→ $*")"; }

# ──────────────────────────────
# Workspace file paths
# ──────────────────────────────
WORKSPACE_FILE=".workspace.json"
WORKSPACE_CLAUDE_MD="CLAUDE.md"

workspace_file() {
  echo "${1:-.}/$WORKSPACE_FILE"
}

is_workspace() {
  local dir="${1:-.}"
  [[ -f "$dir/$WORKSPACE_FILE" ]]
}

# ──────────────────────────────
# JSON operations (jq required)
# ──────────────────────────────
require_jq() {
  if ! command -v jq &>/dev/null; then
    error "$(t "error_jq_required")"
    exit 1
  fi
}

# Read workspace.json
ws_get() {
  local file="$1" key="$2"
  jq -r "$key" "$file" 2>/dev/null
}

# Update workspace.json
# Usage: ws_set <file> [--arg key val ...] <filter>
ws_set() {
  local file="$1"
  shift
  local tmp
  tmp=$(mktemp)
  jq "$@" "$file" > "$tmp" && mv "$tmp" "$file"
}

# ──────────────────────────────
# Path normalization
# ──────────────────────────────
normalize_path() {
  local path="$1"
  # Expand ~
  path="${path/#\~/$HOME}"
  # Remove trailing slash
  path="${path%/}"
  echo "$path"
}

expand_path() {
  local path
  path=$(normalize_path "$1")
  # Use realpath if available (otherwise return as is)
  if command -v realpath &>/dev/null; then
    realpath -m "$path" 2>/dev/null || echo "$path"
  else
    echo "$path"
  fi
}

# Pick a directory with fzf (if available) or fall back to read.
# Arguments: <prompt_label>
# Outputs:   absolute path echoed to stdout, or empty string if cancelled
select_dir_with_fzf() {
  local prompt="${1:-}"
  local result=""

  if command -v fzf &>/dev/null; then
    result=$(
      find "$HOME" -maxdepth 4 -type d \
        \( -name ".git" -o -name "node_modules" -o -name ".cache" \
           -o -name "Library" -o -name "__pycache__" \) -prune \
        -o -type d -print 2>/dev/null \
      | fzf --height=40% --border \
            --prompt="$prompt > " \
            --preview="ls {}" \
            --preview-window=right:40% \
      || true
    )
    [[ -n "$result" ]] && result=$(expand_path "$result")
  else
    read -rep "  $prompt: " result
    result=$(expand_path "$result")
  fi

  echo "$result"
}

# ──────────────────────────────
# Relative time display (e.g., "3 days ago")
# Arguments: <ISO8601 UTC timestamp>
# ──────────────────────────────
_relative_time() {
  local ts="$1"
  [[ -z "$ts" ]] && echo "" && return

  # Remove milliseconds (2025-06-01T12:00:00.123Z -> 2025-06-01T12:00:00Z)
  ts="${ts%%.*}Z"

  local now
  now=$(date -u +%s 2>/dev/null || echo 0)

  local then=0
  # Support both macOS (BSD date) and Linux (GNU date)
  # Use -u flag to interpret as UTC (handles Z suffix correctly)
  if then=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null); then
    : # macOS success
  elif then=$(date -u -d "${ts}" +%s 2>/dev/null); then
    : # Linux success
  else
    echo "" && return
  fi

  local diff=$(( now - then ))
  if   [[ $diff -lt 60 ]];      then t "just_now"
  elif [[ $diff -lt 3600 ]];    then echo "$(( diff / 60 ))$(t "minutes_ago")"
  elif [[ $diff -lt 86400 ]];   then echo "$(( diff / 3600 ))$(t "hours_ago")"
  elif [[ $diff -lt 604800 ]];  then echo "$(( diff / 86400 ))$(t "days_ago")"
  elif [[ $diff -lt 2592000 ]]; then echo "$(( diff / 604800 ))$(t "weeks_ago")"
  else echo "$(( diff / 2592000 ))$(t "months_ago")"
  fi
}

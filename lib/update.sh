#!/usr/bin/env bash
# update.sh - cw update command

SOURCE_PATH_FILE="${CW_DIR:-$HOME/.claude-workspace}/source_path"

cmd_update() {
  local source_dir

  # Get source path
  if [[ -f "$SOURCE_PATH_FILE" ]]; then
    source_dir=$(cat "$SOURCE_PATH_FILE")
  else
    # Fallback: environment variable or default path
    source_dir="${CW_SOURCE_DIR:-$HOME/.claude-workspace-src}"
  fi

  echo ""
  echo "$(bold "cw update")"
  echo ""

  # Check source directory exists
  if [[ ! -d "$source_dir" ]]; then
    error "$(t "error_source_not_found"): $source_dir"
    echo ""
    echo "  Reinstall with:"
    echo "  $(dim "bash install.sh")"
    echo ""
    echo "  Or set environment variable:"
    echo "  $(dim "export CW_SOURCE_DIR=/path/to/claude-workspace")"
    exit 1
  fi

  # Check .git directory
  if [[ ! -d "$source_dir/.git" ]]; then
    error "$(t "error_not_git_repo"): $source_dir"
    exit 1
  fi

  echo "  $(t "update_source"): $source_dir"
  echo ""

  # git pull
  step "$(t "update_fetching")"
  cd "$source_dir"

  local original_branch
  original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  if ! git pull --rebase 2>&1; then
    warn "$(t "error_git_pull_failed"). Please check manually."
    echo "  $(dim "cd $source_dir && git status")"
    exit 1
  fi

  success "git pull complete"
  echo ""

  # Copy lib/*.sh
  step "$(t "update_installing")"

  local cw_lib_dir="${CW_DIR:-$HOME/.claude-workspace}/lib"
  mkdir -p "$cw_lib_dir"

  local file_count=0
  for lib_file in "$source_dir/lib/"*.sh; do
    [[ -f "$lib_file" ]] || continue
    cp "$lib_file" "$cw_lib_dir/"
    file_count=$((file_count + 1))
    echo "  $(dim "Copy: $(basename "$lib_file")")"
  done

  if [[ $file_count -eq 0 ]]; then
    warn "No library files found"
    exit 1
  fi

  success "$file_count files copied"
  echo ""

  # Show version
  local version
  version=$(grep '^CW_VERSION=' "$source_dir/bin/cw" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")

  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(green "  $(t "update_complete")")"
  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo ""
  echo "  $(t "update_version"): ${version:-unknown}"
  echo ""
}

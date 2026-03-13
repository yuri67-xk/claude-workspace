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

  local cw_home="${CW_DIR:-$HOME/.claude-workspace}"
  local install_bin="${INSTALL_BIN:-/usr/local/bin}"

  mkdir -p "$cw_home/lib"

  local file_count=0
  for lib_file in "$source_dir/lib/"*.sh; do
    [[ -f "$lib_file" ]] || continue
    cp "$lib_file" "$cw_home/lib/"
    file_count=$((file_count + 1))
    echo "  $(dim "Copy: $(basename "$lib_file")")"
  done

  if [[ $file_count -eq 0 ]]; then
    warn "No library files found"
    exit 1
  fi

  success "$file_count files copied"
  echo ""

  # Copy skills/*
  if [[ -d "$source_dir/skills" ]]; then
    mkdir -p "$cw_home/skills"
    cp -r "$source_dir/skills/"* "$cw_home/skills/" 2>/dev/null || true
    echo "  $(dim "Copy: skills/")"
  fi

  # Copy web/*
  if [[ -d "$source_dir/web" ]]; then
    mkdir -p "$cw_home/web/templates/partials"
    cp -r "$source_dir/web/"* "$cw_home/web/"
    echo "  $(dim "Copy: web/")"
  fi

  # Install bin/cw (with sed path substitution)
  local tmp_cw
  tmp_cw=$(mktemp)
  sed -e "s|CW_LIB_DIR=.*|CW_LIB_DIR=\"$cw_home/lib\"|" \
      -e "s|CW_SKILLS_DIR=.*|CW_SKILLS_DIR=\"$cw_home/skills\"|" \
      -e "s|CW_WEB_DIR=.*|CW_WEB_DIR=\"$cw_home/web\"|" \
    "$source_dir/bin/cw" > "$tmp_cw"

  if [[ -w "$install_bin" ]]; then
    cp "$tmp_cw" "$install_bin/cw"
    chmod +x "$install_bin/cw"
    echo "  $(dim "Copy: bin/cw → $install_bin/cw")"
  else
    sudo cp "$tmp_cw" "$install_bin/cw"
    sudo chmod +x "$install_bin/cw"
    echo "  $(dim "Copy (sudo): bin/cw → $install_bin/cw")"
  fi
  rm -f "$tmp_cw"

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

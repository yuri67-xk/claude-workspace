#!/usr/bin/env bash
# launch.sh - cw launch コマンド（Claude Code 起動）

cmd_launch() {
  require_jq

  local target_dir
  target_dir="$(pwd)"

  # 引数で workspace 名が指定された場合は該当ディレクトリを探す
  if [[ -n "${1:-}" ]]; then
    local found
    found=$(_find_workspace_by_name "$1")
    if [[ -z "$found" ]]; then
      error "workspace が見つかりません: $1"
      echo "  登録済み workspace: cw list"
      exit 1
    fi
    target_dir="$found"
  fi

  if ! is_workspace "$target_dir"; then
    error "workspace が見つかりません: $target_dir"
    echo "  $(dim "このディレクトリで cw setup を実行してください")"
    exit 1
  fi

  local ws_file="$target_dir/$WORKSPACE_FILE"
  local ws_name
  ws_name=$(ws_get "$ws_file" '.name')

  echo ""
  echo "$(bold "Workspace: $ws_name") を起動します"

  # 登録済みディレクトリを取得
  local dir_count
  dir_count=$(jq '.dirs | length' "$ws_file")

  local add_dir_flags=()
  local valid_count=0

  for ((i=0; i<dir_count; i++)); do
    local dir
    dir=$(jq -r ".dirs[$i].path" "$ws_file")
    local role
    role=$(jq -r ".dirs[$i].role // \"\"" "$ws_file")

    if [[ -d "$dir" ]]; then
      add_dir_flags+=("--add-dir" "$dir")
      local label="${role:-$(basename "$dir")}"
      info "  + $label  $(dim "$dir")"
      ((valid_count++))
    else
      warn "  スキップ (存在しない): $dir"
    fi
  done

  echo ""

  if [[ $valid_count -eq 0 ]]; then
    warn "有効なディレクトリがありません。"
    warn "cw add-dir でディレクトリを追加してください。"
  fi

  # Claude Code が存在するか確認
  if ! command -v claude &>/dev/null; then
    error "claude コマンドが見つかりません"
    echo "  インストール: npm install -g @anthropic-ai/claude-code"
    exit 1
  fi

  echo "  $(dim "claude ${add_dir_flags[*]+"${add_dir_flags[*]}"}")"
  echo ""

  # last_used を更新（レジストリが存在する場合のみ）
  registry_touch "$target_dir"

  # workspace ディレクトリで Claude Code を起動
  cd "$target_dir"
  exec claude "${add_dir_flags[@]+"${add_dir_flags[@]}"}"
}

# workspace 名からディレクトリを検索
# レジストリを優先し、なければ filesystem を検索
_find_workspace_by_name() {
  local name="$1"

  # グローバルレジストリを優先（registry.sh の関数を使用）
  local found
  found=$(registry_get_by_name "$name")
  [[ -n "$found" ]] && { echo "$found"; return; }

  # フォールバック: WorkingProjects 配下を検索
  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_name
      ws_name=$(jq -r '.name' "$ws_file" 2>/dev/null)
      if [[ "$ws_name" == "$name" ]]; then
        dirname "$ws_file"
        return
      fi
    done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null)
  fi
}

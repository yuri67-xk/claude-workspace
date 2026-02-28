#!/usr/bin/env bash
# list.sh - cw list コマンド

cmd_list() {
  require_jq

  echo ""
  echo "$(bold "Workspace 一覧")"
  echo ""

  # ──────────────────────────────
  # グローバルレジストリから取得（優先）
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

      # ディレクトリの存在確認
      local status_suffix=""
      if [[ ! -d "$path" ]]; then
        status_suffix="  $(red "✗ パス不在")"
      fi

      # 現在地マーカー
      local marker=""
      [[ "$path" == "$(pwd)" ]] && marker="  $(green "← 現在")"

      # 相対時間
      local time_label=""
      if [[ -n "$last_used" ]]; then
        local rel
        rel=$(_relative_time "$last_used")
        [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
      fi

      # dirs 件数（.workspace.json が存在する場合）
      local dir_count=0
      local ws_file="$path/$WORKSPACE_FILE"
      if [[ -f "$ws_file" ]]; then
        dir_count=$(jq '.dirs | length' "$ws_file" 2>/dev/null || echo 0)
      fi

      echo "  $(bold "$name")${marker}${status_suffix}${time_label}"
      echo "  $(dim "$path")  [${dir_count} dirs]"
      echo ""
      found_any=true
    done < <(echo "$ws_list" | jq -c '.[]')

    if ! $found_any; then
      _list_empty_message
    fi
  else
    # レジストリが空の場合はファイルシステムにフォールバック
    _list_from_filesystem
  fi
}

# ──────────────────────────────
# フォールバック: ファイルシステムから検索
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
    [[ "$ws_dir" == "$(pwd)" ]] && marker="  $(green "← 現在")"

    echo "  $(bold "$ws_name")${marker}"
    [[ -n "$ws_desc" ]] && echo "  $(dim "$ws_desc")"
    echo "  $(dim "$ws_dir")  [${dir_count} dirs]"
    echo ""
    found_any=true
  done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null | sort)

  if ! $found_any; then
    _list_empty_message
  fi
}

_list_empty_message() {
  info "Workspace が見つかりません"
  echo "  $(dim "cw new で新規作成してください")"
}

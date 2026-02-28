#!/usr/bin/env bash
# info.sh - cw info コマンド

cmd_info() {
  require_jq

  local target_dir
  target_dir="$(pwd)"

  if ! is_workspace "$target_dir"; then
    error "workspace が見つかりません"
    echo "  $(dim "cw setup を実行してください")"
    exit 1
  fi

  local ws_file="$target_dir/$WORKSPACE_FILE"

  echo ""
  echo "$(bold "Workspace 詳細")"
  echo ""

  local ws_name ws_desc ws_created
  ws_name=$(ws_get "$ws_file" '.name')
  ws_desc=$(ws_get "$ws_file" '.description // ""')
  ws_created=$(ws_get "$ws_file" '.created_at // ""')

  echo "  $(bold "名前"):      $ws_name"
  [[ -n "$ws_desc" ]] && echo "  $(bold "説明"):      $ws_desc"
  [[ -n "$ws_created" ]] && echo "  $(bold "作成日"):    $ws_created"
  echo "  $(bold "パス"):      $target_dir"
  echo ""

  local dir_count
  dir_count=$(jq '.dirs | length' "$ws_file")
  echo "  $(bold "登録ディレクトリ") (${dir_count}件)"
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

    # CLAUDE.md 存在確認
    if [[ -f "$path/CLAUDE.md" ]]; then
      echo "     $(cyan "CLAUDE.md あり")"
    fi
    echo ""
  done
}

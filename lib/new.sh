#!/usr/bin/env bash
# new.sh - cw new コマンド
# WorkingProjects/ 配下に新規 Workspace フォルダを作成してセットアップする

cmd_new() {
  require_jq

  # WORKING_PROJECTS_DIR を絶対パスに正規化（~ や相対パスに対するフェイルセーフ）
  local raw_wp="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  local wp_dir
  wp_dir=$(expand_path "$raw_wp")

  echo ""
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(bold "  新規 Workspace を作成")"
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo ""

  # ──────────────────────────────
  # Workspace 名の決定
  # ──────────────────────────────
  local ws_name="${1:-}"

  if [[ -z "$ws_name" ]]; then
    read -rp "  Workspace 名: " ws_name
    ws_name="${ws_name%"${ws_name##*[![:space:]]}"}"  # trim trailing spaces
    ws_name="${ws_name#"${ws_name%%[![:space:]]*}"}"  # trim leading spaces
    if [[ -z "$ws_name" ]]; then
      error "Workspace 名を入力してください"
      exit 1
    fi
  fi

  # ──────────────────────────────
  # フォルダ名の生成
  # スペース → ハイフン、先頭末尾のハイフン除去
  # ──────────────────────────────
  local folder_name
  folder_name=$(echo "$ws_name" | tr ' ' '-' | sed 's/^-*//;s/-*$//')

  local target_dir="$wp_dir/$folder_name"

  echo ""
  echo "  $(bold "Workspace 名"):  $ws_name"
  echo "  $(bold "作成先"):        $target_dir"
  echo ""

  # すでに存在する場合
  if [[ -d "$target_dir" ]]; then
    if is_workspace "$target_dir"; then
      warn "このパスはすでに Workspace として登録済みです"
      read -rp "  そのまま起動しますか? [Y/n]: " ans
      if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        cd "$target_dir"
        cmd_launch
      fi
      return
    else
      warn "フォルダはすでに存在します: $target_dir"
      read -rp "  このフォルダで Workspace をセットアップしますか? [Y/n]: " ans
      [[ "$ans" =~ ^[Nn]$ ]] && { info "キャンセルしました"; exit 0; }
    fi
  else
    read -rp "  作成しますか? [Y/n]: " confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && { info "キャンセルしました"; exit 0; }

    mkdir -p "$target_dir"
    success "フォルダを作成: $target_dir"
  fi

  # ──────────────────────────────
  # 作成したディレクトリへ移動して setup 実行
  # (ws_name を引数として渡して対話の名前入力をスキップ)
  # ──────────────────────────────
  cd "$target_dir"
  cmd_setup "$ws_name"
}

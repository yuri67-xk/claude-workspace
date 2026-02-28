#!/usr/bin/env bash
# update.sh - cw update コマンド

SOURCE_PATH_FILE="${CW_DIR:-$HOME/.claude-workspace}/source_path"

cmd_update() {
  local source_dir

  # ソースパスの取得
  if [[ -f "$SOURCE_PATH_FILE" ]]; then
    source_dir=$(cat "$SOURCE_PATH_FILE")
  else
    # フォールバック: 環境変数またはデフォルトパス
    source_dir="${CW_SOURCE_DIR:-$HOME/.claude-workspace-src}"
  fi

  echo ""
  echo "$(bold "cw アップデート")"
  echo ""

  # ソースディレクトリの存在確認
  if [[ ! -d "$source_dir" ]]; then
    error "ソースディレクトリが見つかりません: $source_dir"
    echo ""
    echo "  以下のいずれかで再インストールしてください:"
    echo "  $(dim "bash install.sh")"
    echo ""
    echo "  または環境変数を設定:"
    echo "  $(dim "export CW_SOURCE_DIR=/path/to/claude-workspace")"
    exit 1
  fi

  # .git ディレクトリの確認
  if [[ ! -d "$source_dir/.git" ]]; then
    error "Git リポジトリではありません: $source_dir"
    exit 1
  fi

  echo "  ソース: $source_dir"
  echo ""

  # git pull
  step "最新版を取得中..."
  cd "$source_dir"

  local original_branch
  original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  if ! git pull --rebase 2>&1; then
    warn "git pull に失敗しました。手動で確認してください。"
    echo "  $(dim "cd $source_dir && git status")"
    exit 1
  fi

  success "git pull 完了"
  echo ""

  # lib/*.sh をコピー
  step "ライブラリをインストール中..."

  local cw_lib_dir="${CW_DIR:-$HOME/.claude-workspace}/lib"
  mkdir -p "$cw_lib_dir"

  local file_count=0
  for lib_file in "$source_dir/lib/"*.sh; do
    [[ -f "$lib_file" ]] || continue
    cp "$lib_file" "$cw_lib_dir/"
    file_count=$((file_count + 1))
    echo "  $(dim "コピー: $(basename "$lib_file")")"
  done

  if [[ $file_count -eq 0 ]]; then
    warn "ライブラリファイルが見つかりません"
    exit 1
  fi

  success "${file_count} ファイルをコピーしました"
  echo ""

  # バージョン表示
  local version
  version=$(grep '^CW_VERSION=' "$source_dir/bin/cw" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")

  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(green "  アップデート完了!")"
  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo ""
  echo "  バージョン: ${version:-unknown}"
  echo ""
}

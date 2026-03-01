#!/usr/bin/env bash
# install.sh - cw CLI のインストールスクリプト
set -euo pipefail

CW_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN="${INSTALL_BIN:-/usr/local/bin}"
CW_HOME="${CW_HOME:-$HOME/.claude-workspace}"
SHELL_RC=""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  claude-workspace (cw) インストーラー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 依存チェック
echo "→ 依存関係を確認しています..."

if ! command -v jq &>/dev/null; then
  echo "  ✗ jq が必要です"
  if command -v brew &>/dev/null; then
    read -rep "  brew install jq を実行しますか? [Y/n]: " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
      brew install jq
    else
      echo "  手動でインストールしてください: brew install jq"
      exit 1
    fi
  else
    echo "  手動でインストールしてください: https://stedolan.github.io/jq/"
    exit 1
  fi
else
  echo "  ✓ jq: $(jq --version)"
fi

if command -v claude &>/dev/null; then
  echo "  ✓ claude: $(claude --version 2>/dev/null | head -1 || echo "found")"
else
  echo "  ⚠ claude コマンドが見つかりません"
  echo "    インストール: npm install -g @anthropic-ai/claude-code"
fi

# ファイルをコピー
echo ""
echo "→ ファイルをインストールしています..."

mkdir -p "$CW_HOME/lib"
cp "$CW_REPO_DIR/lib/"*.sh "$CW_HOME/lib/"

mkdir -p "$CW_HOME/skills"
cp -r "$CW_REPO_DIR/skills/"* "$CW_HOME/skills/" 2>/dev/null || true

sed -e "s|CW_LIB_DIR=.*|CW_LIB_DIR=\"$CW_HOME/lib\"|" \
    -e "s|CW_SKILLS_DIR=.*|CW_SKILLS_DIR=\"$CW_HOME/skills\"|" \
  "$CW_REPO_DIR/bin/cw" > "/tmp/cw_install_tmp"

if [[ -w "$INSTALL_BIN" ]]; then
  cp "/tmp/cw_install_tmp" "$INSTALL_BIN/cw"
  chmod +x "$INSTALL_BIN/cw"
  echo "  ✓ インストール: $INSTALL_BIN/cw"
else
  echo "  $INSTALL_BIN への書き込み権限が必要です"
  sudo cp "/tmp/cw_install_tmp" "$INSTALL_BIN/cw"
  sudo chmod +x "$INSTALL_BIN/cw"
  echo "  ✓ インストール (sudo): $INSTALL_BIN/cw"
fi

rm -f "/tmp/cw_install_tmp"

# ソースパスを保存（cw update で使用）
echo "$CW_REPO_DIR" > "$CW_HOME/source_path"
echo "  ✓ ソースパスを保存: $CW_HOME/source_path"

# シェル設定の自動追記
echo ""
echo "→ シェル設定を更新しています..."

# RC ファイルを特定
if [[ "${SHELL}" == */zsh ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "${SHELL}" == */bash ]]; then
  SHELL_RC="$HOME/.bashrc"
  [[ -f "$HOME/.bash_profile" ]] && SHELL_RC="$HOME/.bash_profile"
else
  if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
  fi
fi

# WorkingProjects ディレクトリ
DEFAULT_WP_DIR="$HOME/WorkingProjects"
echo ""
read -rep "  WorkingProjects ディレクトリ [${DEFAULT_WP_DIR}]: " wp_dir_input
WP_DIR="${wp_dir_input:-$DEFAULT_WP_DIR}"

# ── パスを絶対パスに正規化 ──────────────────────────────
# ~ を $HOME に展開（ダブルクォート内で ~ は展開されないため手動で行う）
WP_DIR="${WP_DIR/#\~/$HOME}"
# 相対パスの場合は $HOME を基準に絶対パスへ変換
if [[ "$WP_DIR" != /* ]]; then
  WP_DIR="$HOME/$WP_DIR"
fi
# 末尾スラッシュを除去
WP_DIR="${WP_DIR%/}"
echo "  解決されたパス: $WP_DIR"

# マーカー付きブロックで管理（再インストール時に上書き）
CW_MARKER_BEGIN="# >>> claude-workspace (cw) >>>"
CW_MARKER_END="# <<< claude-workspace (cw) <<<"

# printf で構築することで変数展開の副作用を排除
CW_SHELL_BLOCK=$(printf '%s\nexport WORKING_PROJECTS_DIR="%s"\n%s' \
  "$CW_MARKER_BEGIN" "$WP_DIR" "$CW_MARKER_END")

if grep -qF "$CW_MARKER_BEGIN" "$SHELL_RC" 2>/dev/null; then
  # 既存ブロックを上書き
  awk -v begin="$CW_MARKER_BEGIN" -v end="$CW_MARKER_END" \
      -v block="$CW_SHELL_BLOCK" '
    $0 == begin { skip=1; print block; next }
    $0 == end   { skip=0; next }
    !skip
  ' "$SHELL_RC" > "${SHELL_RC}.cw_tmp" && mv "${SHELL_RC}.cw_tmp" "$SHELL_RC"
  echo "  ✓ 更新: $SHELL_RC"
else
  # 末尾に追記
  printf "\n%s\n" "$CW_SHELL_BLOCK" >> "$SHELL_RC"
  echo "  ✓ 追記: $SHELL_RC"
fi

# 完了
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  インストール完了!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  !! 重要: 以下のどちらかを実行してください !!"
echo ""
echo "  (A) 今のターミナルで即時反映:"
echo "      source $SHELL_RC"
echo ""
echo "  (B) 新しいターミナルタブを開く"
echo ""
echo "  ※ このインストーラー自体は別プロセスで動くため,"
echo "    source しても現在のシェルには反映されません。"
echo ""
echo "  使い方:"
echo "    cd ~/WorkingProjects/my-project"
echo "    cw setup    # workspace をセットアップ"
echo "    cw          # Claude Code を起動"
echo ""
echo "  ヘルプ:"
echo "    cw help"
echo ""

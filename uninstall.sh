#!/usr/bin/env bash
# uninstall.sh - cw CLI のアンインストールスクリプト
set -euo pipefail

INSTALL_BIN="${INSTALL_BIN:-/usr/local/bin}"
CW_HOME="${CW_HOME:-$HOME/.claude-workspace}"
CW_MARKER_BEGIN="# >>> claude-workspace (cw) >>>"
CW_MARKER_END="# <<< claude-workspace (cw) <<<"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  claude-workspace (cw) アンインストーラー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ──────────────────────────────
# 削除対象の確認
# ──────────────────────────────
echo "以下を削除します:"
echo ""

CW_BIN="$INSTALL_BIN/cw"
[[ -f "$CW_BIN" ]]  && echo "  ✓ バイナリ:          $CW_BIN" \
                    || echo "  - バイナリ:          $CW_BIN  (見つかりません)"

[[ -d "$CW_HOME" ]] && echo "  ✓ データディレクトリ: $CW_HOME" \
                    || echo "  - データディレクトリ: $CW_HOME  (見つかりません)"

# シェル RC ファイルを特定
SHELL_RC=""
for rc in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && grep -qF "$CW_MARKER_BEGIN" "$rc" 2>/dev/null; then
    SHELL_RC="$rc"
    break
  fi
done

if [[ -n "$SHELL_RC" ]]; then
  echo "  ✓ シェル設定ブロック: $SHELL_RC"
else
  echo "  - シェル設定ブロック: (見つかりません)"
fi

echo ""

# ──────────────────────────────
# registry.json の確認（workspace データは消さない）
# ──────────────────────────────
REGISTRY_FILE="$CW_HOME/registry.json"
if [[ -f "$REGISTRY_FILE" ]]; then
  WS_COUNT=$(jq '.workspaces | length' "$REGISTRY_FILE" 2>/dev/null || echo "?")
  echo "  ⚠ レジストリに ${WS_COUNT} 件の workspace が登録されています"
  echo "    (registry.json はデータディレクトリごと削除されます)"
  echo ""
fi

# ──────────────────────────────
# 確認プロンプト
# ──────────────────────────────
read -rep "  続けますか? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "  キャンセルしました"; exit 0; }
echo ""

# ──────────────────────────────
# 1. バイナリを削除
# ──────────────────────────────
echo "→ バイナリを削除しています..."
if [[ -f "$CW_BIN" ]]; then
  if [[ -w "$INSTALL_BIN" ]]; then
    rm -f "$CW_BIN"
  else
    sudo rm -f "$CW_BIN"
  fi
  echo "  ✓ 削除: $CW_BIN"
else
  echo "  - スキップ (見つかりません): $CW_BIN"
fi

# ──────────────────────────────
# 2. データディレクトリを削除
# ──────────────────────────────
echo ""
echo "→ データディレクトリを削除しています..."
if [[ -d "$CW_HOME" ]]; then
  rm -rf "$CW_HOME"
  echo "  ✓ 削除: $CW_HOME"
else
  echo "  - スキップ (見つかりません): $CW_HOME"
fi

# ──────────────────────────────
# 3. シェル RC のマーカーブロックを削除
# ──────────────────────────────
echo ""
echo "→ シェル設定を元に戻しています..."
if [[ -n "$SHELL_RC" ]]; then
  awk -v begin="$CW_MARKER_BEGIN" -v end="$CW_MARKER_END" '
    $0 == begin { skip=1; next }
    $0 == end   { skip=0; next }
    !skip
  ' "$SHELL_RC" > "${SHELL_RC}.cw_tmp" && mv "${SHELL_RC}.cw_tmp" "$SHELL_RC"
  echo "  ✓ 削除: $SHELL_RC のブロック"
else
  echo "  - スキップ (マーカーブロックが見つかりません)"
fi

# ──────────────────────────────
# 完了
# ──────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  アンインストール完了!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ⚠ 設定を完全に反映するには新しいターミナルタブを開くか:"
[[ -n "$SHELL_RC" ]] && echo "    source $SHELL_RC"
echo ""
echo "  各プロジェクトの .workspace.json / CLAUDE.md はそのまま残っています。"
echo "  不要な場合は手動で削除してください。"
echo ""

#!/usr/bin/env bash
# utils.sh - 共通ユーティリティ

# ──────────────────────────────
# カラー / スタイル
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
# Workspace ファイルパス
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
# JSON 操作 (jq 必須)
# ──────────────────────────────
require_jq() {
  if ! command -v jq &>/dev/null; then
    error "jq が必要です: brew install jq"
    exit 1
  fi
}

# workspace.json を読む
ws_get() {
  local file="$1" key="$2"
  jq -r "$key" "$file" 2>/dev/null
}

# workspace.json を更新
# 使い方: ws_set <file> [--arg key val ...] <filter>
ws_set() {
  local file="$1"
  shift
  local tmp
  tmp=$(mktemp)
  jq "$@" "$file" > "$tmp" && mv "$tmp" "$file"
}

# ──────────────────────────────
# パス正規化
# ──────────────────────────────
normalize_path() {
  local path="$1"
  # ~ を展開
  path="${path/#\~/$HOME}"
  # 末尾スラッシュ除去
  path="${path%/}"
  echo "$path"
}

expand_path() {
  local path
  path=$(normalize_path "$1")
  # realpath があれば使う（なければそのまま）
  if command -v realpath &>/dev/null; then
    realpath -m "$path" 2>/dev/null || echo "$path"
  else
    echo "$path"
  fi
}

# ──────────────────────────────
# 相対時間表示（例: "3日前"）
# 引数: <ISO8601 UTC タイムスタンプ>
# ──────────────────────────────
_relative_time() {
  local ts="$1"
  [[ -z "$ts" ]] && echo "" && return

  # ミリ秒部分を削除 (2025-06-01T12:00:00.123Z -> 2025-06-01T12:00:00Z)
  ts="${ts%%.*}Z"

  local now
  now=$(date -u +%s 2>/dev/null || echo 0)

  local then=0
  # macOS (BSD date) と Linux (GNU date) の両方に対応
  # -u フラグで UTC として解釈（Z サフィックスを正しく扱うため）
  if then=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null); then
    : # macOS 成功
  elif then=$(date -u -d "${ts}" +%s 2>/dev/null); then
    : # Linux 成功
  else
    echo "" && return
  fi

  local diff=$(( now - then ))
  if   [[ $diff -lt 60 ]];      then echo "たった今"
  elif [[ $diff -lt 3600 ]];    then echo "$(( diff / 60 ))分前"
  elif [[ $diff -lt 86400 ]];   then echo "$(( diff / 3600 ))時間前"
  elif [[ $diff -lt 604800 ]];  then echo "$(( diff / 86400 ))日前"
  elif [[ $diff -lt 2592000 ]]; then echo "$(( diff / 604800 ))週間前"
  else echo "$(( diff / 2592000 ))ヶ月前"
  fi
}

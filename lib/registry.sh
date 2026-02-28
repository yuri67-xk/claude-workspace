#!/usr/bin/env bash
# registry.sh - グローバル Workspace レジストリ管理
# 登録情報は $CW_DIR/registry.json に保存される

REGISTRY_FILE="${CW_DIR:-$HOME/.claude-workspace}/registry.json"

# ──────────────────────────────
# 内部: レジストリを初期化（存在しない場合）
# ──────────────────────────────
_registry_init() {
  local reg_dir
  reg_dir=$(dirname "$REGISTRY_FILE")
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    mkdir -p "$reg_dir"
    echo '{"workspaces":[]}' > "$REGISTRY_FILE"
  fi
}

# ──────────────────────────────
# Workspace をレジストリに追加/更新
# 引数: <name> <path>
# ──────────────────────────────
registry_add() {
  local name="$1"
  local path="$2"
  _registry_init

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)

  # 同じパスが既に登録済みなら更新、なければ追加
  jq --arg name "$name" --arg path "$path" --arg now "$now" '
    if any(.workspaces[]; .path == $path) then
      .workspaces = [
        .workspaces[] |
        if .path == $path then . + {name: $name, last_used: $now}
        else .
        end
      ]
    else
      .workspaces += [{name: $name, path: $path, created_at: $now, last_used: $now}]
    end
  ' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
}

# ──────────────────────────────
# last_used タイムスタンプを更新
# 引数: <path>
# ──────────────────────────────
registry_touch() {
  local path="$1"
  [[ ! -f "$REGISTRY_FILE" ]] && return

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmp
  tmp=$(mktemp)
  jq --arg path "$path" --arg now "$now" '
    .workspaces = [
      .workspaces[] |
      if .path == $path then . + {last_used: $now} else . end
    ]
  ' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
}

# ──────────────────────────────
# Workspace をレジストリから削除
# 引数: <path>
# ──────────────────────────────
registry_remove() {
  local path="$1"
  [[ ! -f "$REGISTRY_FILE" ]] && return

  local tmp
  tmp=$(mktemp)
  jq --arg path "$path" '
    .workspaces = [.workspaces[] | select(.path != $path)]
  ' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
}

# ──────────────────────────────
# 全 Workspace 一覧を返す（last_used 降順の JSON 配列）
# ──────────────────────────────
registry_list() {
  [[ ! -f "$REGISTRY_FILE" ]] && echo "[]" && return
  jq '.workspaces | sort_by(.last_used) | reverse' "$REGISTRY_FILE" 2>/dev/null || echo "[]"
}

# ──────────────────────────────
# 名前で Workspace のパスを検索
# 引数: <name>
# 戻り値: パス文字列（見つからなければ空文字）
# ──────────────────────────────
registry_get_by_name() {
  local name="$1"
  [[ ! -f "$REGISTRY_FILE" ]] && echo "" && return
  jq -r --arg name "$name" \
    '.workspaces[] | select(.name == $name) | .path' \
    "$REGISTRY_FILE" 2>/dev/null | head -1
}

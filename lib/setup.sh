#!/usr/bin/env bash
# setup.sh - cw setup コマンド

# 引数: [prefill_name]
#   prefill_name ... cw new から呼ばれるとき、あらかじめ決まった Workspace 名を渡す
cmd_setup() {
  require_jq

  local prefill_name="${1:-}"

  local target_dir
  target_dir="$(pwd)"

  # すでに workspace 設定済みか確認
  if is_workspace "$target_dir"; then
    warn "このディレクトリはすでに workspace として設定済みです"
    local existing_name
    existing_name=$(ws_get "$target_dir/$WORKSPACE_FILE" '.name')
    echo "  現在の workspace 名: $(bold "$existing_name")"
    echo ""
    read -rp "  再設定しますか? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "キャンセルしました"; exit 0; }
    echo ""
  fi

  echo ""
  echo "$(bold "Claude Workspace セットアップ")"
  echo "$(dim "ディレクトリ: $target_dir")"
  echo ""

  # ──────────────────────────────
  # Step 1: プロジェクト名
  # ──────────────────────────────
  step "Step 1: Workspace 名"
  local ws_name
  if [[ -n "$prefill_name" ]]; then
    # cw new から呼ばれた場合は名前入力済みなのでスキップ
    ws_name="$prefill_name"
    success "Workspace 名: $ws_name"
  else
    local default_name
    default_name="$(basename "$target_dir")"
    read -rp "  Workspace 名 [${default_name}]: " ws_name
    ws_name="${ws_name:-$default_name}"
    success "Workspace 名: $ws_name"
  fi

  # ──────────────────────────────
  # Step 2: 説明
  # ──────────────────────────────
  step "Step 2: Workspace の説明 (任意)"
  read -rp "  説明: " ws_description
  ws_description="${ws_description:-}"

  # ──────────────────────────────
  # Step 3: プロジェクトディレクトリの指定
  # ──────────────────────────────
  step "Step 3: 対象リポジトリ/ディレクトリの追加"
  echo "  $(dim "パスを入力して Enter。追加完了したら空 Enter。")"
  echo "  $(dim "例: ~/repos/store360-ios-sdk")"
  echo ""

  local dirs=()
  local dir_roles=()

  while true; do
    read -rp "  パス (空 Enter で完了): " raw_path
    [[ -z "$raw_path" ]] && break

    local expanded_path
    expanded_path=$(expand_path "$raw_path")

    if [[ ! -d "$expanded_path" ]]; then
      warn "ディレクトリが存在しません: $expanded_path"
      read -rp "  それでも追加しますか? [y/N]: " force
      [[ "$force" =~ ^[Yy]$ ]] || continue
    fi

    # このディレクトリの役割（任意）
    read -rp "  役割ラベル (任意, 例: iOS SDK): " role
    role="${role:-}"

    dirs+=("$expanded_path")
    dir_roles+=("$role")
    success "追加: $expanded_path $([ -n "$role" ] && echo "(${role})")"
  done

  if [[ ${#dirs[@]} -eq 0 ]]; then
    warn "ディレクトリが指定されていません。後で cw add-dir で追加できます。"
  fi

  # ──────────────────────────────
  # Step 4: workspace.json 生成
  # ──────────────────────────────
  step "Step 4: 設定ファイルを生成"

  local ws_file="$target_dir/$WORKSPACE_FILE"
  local created_at
  created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # JSON 構築
  local dirs_json="[]"
  for i in "${!dirs[@]}"; do
    local dir="${dirs[$i]}"
    local role="${dir_roles[$i]}"
    dirs_json=$(echo "$dirs_json" | jq \
      --arg path "$dir" \
      --arg role "$role" \
      '. += [{"path": $path, "role": $role}]')
  done

  jq -n \
    --arg name "$ws_name" \
    --arg description "$ws_description" \
    --arg created_at "$created_at" \
    --arg workspace_path "$target_dir" \
    --argjson dirs "$dirs_json" \
    '{
      name: $name,
      description: $description,
      workspace_path: $workspace_path,
      created_at: $created_at,
      dirs: $dirs
    }' > "$ws_file"

  success "生成: $ws_file"

  # ──────────────────────────────
  # Step 5: CLAUDE.md 生成
  # ──────────────────────────────
  step "Step 5: Workspace CLAUDE.md を生成"

  local claude_md="$target_dir/$WORKSPACE_CLAUDE_MD"
  _generate_workspace_claude_md "$claude_md" "$ws_name" "$ws_description" "$ws_file"
  success "生成: $claude_md"

  # ──────────────────────────────
  # Step 6: グローバルレジストリに登録
  # ──────────────────────────────
  step "Step 6: レジストリに登録"
  registry_add "$ws_name" "$target_dir"
  success "登録完了: ~/.claude-workspace/registry.json"

  # ──────────────────────────────
  # 完了
  # ──────────────────────────────
  echo ""
  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(green "  セットアップ完了!")"
  echo "$(green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo ""
  echo "  起動するには:"
  echo "  $(bold "  cw")"
  echo ""
}

# workspace CLAUDE.md テンプレート生成
# 引数: <claude_md_path> <ws_name> <ws_description> <ws_file_path>
_generate_workspace_claude_md() {
  local claude_md="$1"
  local ws_name="$2"
  local ws_description="$3"
  local ws_file="$4"

  # Linked Repositories テーブル行を構築
  local dirs_table=""
  if [[ -f "$ws_file" ]]; then
    local count
    count=$(jq '.dirs | length' "$ws_file")
    for ((i=0; i<count; i++)); do
      local path role
      path=$(jq -r ".dirs[$i].path" "$ws_file")
      role=$(jq -r ".dirs[$i].role // \"\"" "$ws_file")
      local label="${role:-$(basename "$path")}"
      dirs_table="${dirs_table}| ${label} | \`${path}\` |"$'\n'
    done
  fi

  local created_at
  created_at=$(date "+%Y-%m-%d")

  # ${ws_name,,} は bash 4+ の構文のため macOS bash 3.2 では動かない
  # tr で代替する
  local ws_name_lower
  ws_name_lower=$(echo "$ws_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  # printf でファイル生成（heredoc の変数展開トラブルを回避）
  printf '# Workspace: %s\n\n> %s\n\nCreated: %s\n\n---\n\n## Linked Repositories\n\n| Role | Path |\n|------|------|\n%s\n## Workflow Rules\n\n- 追加のルールをここに記述してください\n- （例）各 repo のブランチ命名規則: `feature/ws-%s-*`\n\n## Current Tasks\n\n- [ ] タスク1\n- [ ] タスク2\n\n## Notes\n\n作業メモや設計決定事項をここに記録してください。\n' \
    "$ws_name" \
    "${ws_description:-このワークスペースの説明を記述してください。}" \
    "$created_at" \
    "$dirs_table" \
    "$ws_name_lower" \
    > "$claude_md"
}

# cw add-dir コマンド
cmd_add_dir() {
  require_jq

  local target_dir
  target_dir="$(pwd)"

  if ! is_workspace "$target_dir"; then
    error "workspace が見つかりません。先に cw setup を実行してください。"
    exit 1
  fi

  local ws_file="$target_dir/$WORKSPACE_FILE"
  local ws_name
  ws_name=$(ws_get "$ws_file" '.name')

  echo ""
  echo "$(bold "ディレクトリを追加: $ws_name")"
  echo ""

  local new_path="${1:-}"
  if [[ -z "$new_path" ]]; then
    read -rp "  追加するパス: " new_path
  fi

  local expanded_path
  expanded_path=$(expand_path "$new_path")

  if [[ ! -d "$expanded_path" ]]; then
    warn "ディレクトリが存在しません: $expanded_path"
    read -rp "  それでも追加しますか? [y/N]: " force
    [[ "$force" =~ ^[Yy]$ ]] || exit 0
  fi

  # すでに登録済みか確認
  if jq -e --arg p "$expanded_path" '.dirs[] | select(.path == $p)' "$ws_file" &>/dev/null; then
    warn "すでに登録済みです: $expanded_path"
    exit 0
  fi

  read -rp "  役割ラベル (任意): " role

  # workspace.json に追加
  ws_set "$ws_file" \
    --arg path "$expanded_path" \
    --arg role "${role:-}" \
    '.dirs += [{"path": $path, "role": $role}]'

  # CLAUDE.md 更新（Linked Repositories テーブル再生成）
  local claude_md="$target_dir/$WORKSPACE_CLAUDE_MD"
  local ws_description
  ws_description=$(ws_get "$ws_file" '.description')
  _generate_workspace_claude_md "$claude_md" "$ws_name" "$ws_description" "$ws_file"

  success "追加しました: $expanded_path"
}

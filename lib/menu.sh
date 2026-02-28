#!/usr/bin/env bash
# menu.sh - インタラクティブ Workspace 選択メニュー

cmd_menu() {
  require_jq

  echo ""
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"
  echo "$(bold "  claude-workspace (cw)")"
  echo "$(bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")"

  # ──────────────────────────────
  # レジストリ + ファイルシステムを統合して一覧構築
  # ──────────────────────────────
  local menu_paths=()
  local menu_names=()
  local menu_times=()
  local menu_registered=()  # true = レジストリ登録済み, false = 未登録

  # 1) レジストリから取得（last_used 降順）
  local ws_list
  ws_list=$(registry_list)

  while IFS= read -r ws; do
    local name path last_used
    name=$(echo "$ws" | jq -r '.name')
    path=$(echo "$ws" | jq -r '.path')
    last_used=$(echo "$ws" | jq -r '.last_used // ""')

    menu_paths+=("$path")
    menu_names+=("$name")
    menu_times+=("$last_used")
    menu_registered+=("true")
  done < <(echo "$ws_list" | jq -c '.[]' 2>/dev/null)

  # 2) ファイルシステムからスキャンして未登録のものを追記
  local search_base="${WORKING_PROJECTS_DIR:-$HOME/WorkingProjects}"
  if [[ -d "$search_base" ]]; then
    while IFS= read -r ws_file; do
      local ws_dir ws_name
      ws_dir=$(dirname "$ws_file")
      ws_name=$(ws_get "$ws_file" '.name')

      # レジストリに既に存在するか確認
      local already=false
      for p in "${menu_paths[@]+"${menu_paths[@]}"}"; do
        [[ "$p" == "$ws_dir" ]] && already=true && break
      done
      $already && continue

      menu_paths+=("$ws_dir")
      menu_names+=("$ws_name")
      menu_times+=("")
      menu_registered+=("false")
    done < <(find "$search_base" -maxdepth 2 -name ".workspace.json" 2>/dev/null | sort)
  fi

  # ──────────────────────────────
  # Workspace が 1 件もない場合
  # ──────────────────────────────
  if [[ ${#menu_paths[@]} -eq 0 ]]; then
    echo ""
    info "Workspace が見つかりません"
    echo ""
    _menu_prompt_new
    return
  fi

  # ──────────────────────────────
  # 一覧の表示
  # ──────────────────────────────
  echo ""
  echo "  $(bold "Workspace:")"
  echo ""

  local i=0
  for idx in "${!menu_paths[@]}"; do
    local path="${menu_paths[$idx]}"
    local name="${menu_names[$idx]}"
    local last_used="${menu_times[$idx]}"
    local registered="${menu_registered[$idx]}"

    i=$((i + 1))

    # 状態マーカー
    local status_marker=""
    if [[ ! -d "$path" ]]; then
      status_marker="  $(red "✗ パス不在")"
    elif [[ "$path" == "$(pwd)" ]]; then
      status_marker="  $(green "← 現在地")"
    fi

    # 未登録マーカー
    local unreg_label=""
    [[ "$registered" == "false" ]] && unreg_label="  $(yellow "未登録")"

    # 相対時間
    local time_label=""
    if [[ -n "$last_used" ]]; then
      local rel
      rel=$(_relative_time "$last_used")
      [[ -n "$rel" ]] && time_label="  $(dim "$rel")"
    fi

    printf "  [%d] $(bold "%s")%s%s%s\n" \
      "$i" "$name" "$time_label" "$unreg_label" "$status_marker"
    printf "      $(dim "%s")\n" "$path"
    echo ""
  done

  # ──────────────────────────────
  # 選択肢の表示
  # ──────────────────────────────
  echo "  $(dim "────────────────────────────────────────")"
  echo "  [N] 新規 Workspace を作成"
  echo "  [Q] 終了"
  echo ""

  local choice
  read -rp "  選択 [1-${i} / N / Q]: " choice
  echo ""

  case "$choice" in
    [Nn])
      cmd_new
      ;;
    [Qq]|"")
      info "終了します"
      exit 0
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && \
         [[ $choice -ge 1 ]] && \
         [[ $choice -le ${#menu_paths[@]} ]]; then

        local sel_idx=$(( choice - 1 ))
        local selected_path="${menu_paths[$sel_idx]}"
        local selected_name="${menu_names[$sel_idx]}"
        local selected_reg="${menu_registered[$sel_idx]}"

        if [[ ! -d "$selected_path" ]]; then
          error "パスが存在しません: $selected_path"
          echo "  $(dim "登録を削除するには: cw forget")"
          exit 1
        fi

        # 未登録の場合はここで自動登録
        if [[ "$selected_reg" == "false" ]]; then
          registry_add "$selected_name" "$selected_path"
          success "レジストリに登録しました: $selected_name"
        fi

        cd "$selected_path"
        cmd_launch
      else
        error "無効な選択: $choice"
        exit 1
      fi
      ;;
  esac
}

# ──────────────────────────────
# 新規作成プロンプト（Workspace が 0 件のとき）
# ──────────────────────────────
_menu_prompt_new() {
  read -rp "  新規 Workspace を作成しますか? [Y/n]: " ans
  [[ "$ans" =~ ^[Nn]$ ]] && exit 0
  cmd_new
}

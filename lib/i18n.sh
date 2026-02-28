#!/usr/bin/env bash
# i18n.sh - Internationalization support

LANG_FILE="${CW_DIR:-$HOME/.claude-workspace}/lang"

# Get current language (default: en)
cw_lang() {
  if [[ -f "$LANG_FILE" ]]; then
    cat "$LANG_FILE"
  else
    echo "en"
  fi
}

# Set language
cw_set_lang() {
  local lang="$1"
  if [[ "$lang" != "en" && "$lang" != "ja" ]]; then
    echo "Error: Unsupported language: $lang" >&2
    return 1
  fi
  echo "$lang" > "$LANG_FILE"
}

# Message translations
# Usage: t "message_key"
t() {
  local key="$1"
  local lang
  lang=$(cw_lang)

  case "$lang" in
    ja)
      case "$key" in
        # === Common ===
        "yes") echo "はい" ;;
        "no") echo "いいえ" ;;
        "cancel") echo "キャンセルしました" ;;
        "confirm") echo "続けますか?" ;;
        "continue") echo "続けますか?" ;;
        "create") echo "作成しますか?" ;;
        "created") echo "作成しました" ;;
        "updated") echo "更新しました" ;;
        "deleted") echo "削除しました" ;;
        "not_found") echo "見つかりません" ;;
        "already_exists") echo "すでに存在します" ;;
        "invalid") echo "無効" ;;
        "invalid_command") echo "不明なコマンド" ;;
        "required") echo "が必要です" ;;
        "files") echo "件" ;;
        "skip") echo "スキップ" ;;
        "copy") echo "コピー" ;;

        # === Workspace ===
        "workspace") echo "ワークスペース" ;;
        "workspaces") echo "ワークスペース" ;;
        "new_workspace") echo "新規ワークスペースを作成" ;;
        "workspace_name") echo "ワークスペース名" ;;
        "workspace_desc") echo "説明" ;;
        "workspace_not_found") echo "ワークスペースが見つかりません" ;;
        "workspace_already_setup") echo "このディレクトリはすでにワークスペースとして設定済みです" ;;
        "workspace_setup") echo "ワークスペースをセットアップ" ;;
        "workspace_launch") echo "ワークスペースを起動します" ;;
        "workspace_current") echo "現在のワークスペース" ;;
        "workspace_detail") echo "ワークスペース詳細" ;;
        "workspace_list") echo "ワークスペース一覧" ;;
        "workspace_scan") echo "ワークスペーススキャン" ;;
        "not_a_workspace") echo "現在のディレクトリはワークスペースではありません" ;;
        "remove_from_registry") echo "レジストリから削除します" ;;
        "files_remain") echo "※ ファイル (.workspace.json, CLAUDE.md) は削除されません" ;;
        "re_setup") echo "再設定しますか?" ;;
        "launch_as_is") echo "そのまま起動しますか?" ;;

        # === Directory ===
        "directory") echo "ディレクトリ" ;;
        "directories") echo "ディレクトリ" ;;
        "add_directory") echo "ディレクトリを追加" ;;
        "dir_not_found") echo "ディレクトリが存在しません" ;;
        "dir_add_path") echo "追加するパス" ;;
        "dir_add_role") echo "役割ラベル (任意)" ;;
        "dir_added") echo "追加しました" ;;
        "search") echo "検索" ;;
        "path") echo "パス" ;;
        "select_dir_prompt") echo "ディレクトリを選択" ;;
        "add_anyway") echo "それでも追加しますか?" ;;

        # === Registry ===
        "registered") echo "登録済み" ;;
        "register") echo "登録" ;;
        "unregistered") echo "未登録" ;;
        "path_missing") echo "パス不在" ;;
        "current_location") echo "現在地" ;;
        "newly_registered") echo "新規登録しました" ;;

        # === Time ===
        "just_now") echo "たった今" ;;
        "minutes_ago") echo "分前" ;;
        "hours_ago") echo "時間前" ;;
        "days_ago") echo "日前" ;;
        "weeks_ago") echo "週間前" ;;
        "months_ago") echo "ヶ月前" ;;

        # === Commands ===
        "cmd_new") echo "新規作成" ;;
        "cmd_resume") echo "再開" ;;
        "cmd_quit") echo "終了します" ;;
        "cmd_select") echo "選択" ;;

        # === Setup ===
        "setup_complete") echo "セットアップ完了!" ;;
        "setup_step1") echo "ワークスペース名" ;;
        "setup_step2") echo "説明 (任意)" ;;
        "setup_step3") echo "リポジトリ/ディレクトリの追加" ;;
        "setup_step4") echo "設定ファイルを生成" ;;
        "setup_step5") echo "CLAUDE.md を生成" ;;
        "setup_step6") echo "レジストリに登録" ;;
        "setup_path_hint") echo "fzf でディレクトリを選択 (fzf なしの場合はパスを入力)。完了したら空選択または Esc。" ;;
        "setup_run") echo "起動するには:" ;;
        "setup_claude_md") echo "Workspace CLAUDE.md を生成" ;;
        "setup_config_file") echo "設定ファイルを生成" ;;
        "target_dirs") echo "対象リポジトリ/ディレクトリの追加" ;;

        # === Update ===
        "update_fetching") echo "最新版を取得中..." ;;
        "update_installing") echo "ライブラリをインストール中..." ;;
        "update_complete") echo "アップデート完了!" ;;
        "update_version") echo "バージョン" ;;
        "update_source") echo "ソース" ;;

        # === Launch ===
        "launch_workspace") echo "Workspace を起動します" ;;
        "launch_valid_dirs") echo "有効なディレクトリがありません" ;;
        "launch_use_add_dir") echo "cw add-dir でディレクトリを追加してください" ;;
        "launch_here") echo "このディレクトリで cw setup を実行してください" ;;
        "skip_not_exist") echo "スキップ (存在しない)" ;;

        # === List ===
        "list_dirs") echo "dirs" ;;
        "list_empty") echo "cw new で新規作成してください" ;;

        # === Info ===
        "info_name") echo "名前" ;;
        "info_desc") echo "説明" ;;
        "info_created") echo "作成日" ;;
        "info_path") echo "パス" ;;
        "info_registered_dirs") echo "登録ディレクトリ" ;;
        "info_claude_md_exists") echo "CLAUDE.md あり" ;;

        # === Errors ===
        "error_jq_required") echo "jq が必要です: brew install jq" ;;
        "error_claude_not_found") echo "claude コマンドが見つかりません" ;;
        "error_source_not_found") echo "ソースディレクトリが見つかりません" ;;
        "error_not_git_repo") echo "Git リポジトリではありません" ;;
        "error_git_pull_failed") echo "git pull に失敗しました" ;;

        # === Menu ===
        "menu_recent") echo "最近のワークスペース:" ;;
        "menu_create_new") echo "新規ワークスペースを作成" ;;
        "menu_quit") echo "終了" ;;
        "press_enter") echo "Enter で続ける" ;;
        "menu_action_resume") echo "▶ 起動" ;;
        "menu_action_add_dir") echo "+ ディレクトリを追加" ;;
        "menu_action_info") echo "ℹ 詳細情報" ;;
        "menu_action_finder") echo "⊙ Finder で開く" ;;
        "menu_action_forget") echo "✗ レジストリから削除" ;;
        "menu_action_back") echo "← 戻る" ;;

        # === Usage ===
        "usage_title") echo "Claude Code マルチリポジトリ Workspace マネージャー" ;;
        "usage") echo "使い方" ;;
        "usage_examples") echo "例" ;;
        "usage_launch_or_menu") echo "ワークスペースメニューを表示" ;;
        "usage_new") echo "新規 Workspace を作成して起動" ;;
        "usage_resume") echo "Workspace 選択メニューを表示" ;;
        "usage_setup") echo "現在のディレクトリを workspace としてセットアップ" ;;
        "usage_launch") echo "workspace を起動 (Claude Code を --add-dir 付きで起動)" ;;
        "usage_list") echo "登録済み workspace 一覧" ;;
        "usage_info") echo "workspace の詳細情報" ;;
        "usage_add_dir") echo "既存 workspace にディレクトリを追加" ;;
        "usage_forget") echo "現在の workspace をレジストリから削除" ;;
        "usage_scan") echo "WorkingProjects/ をスキャンして未登録 workspace を一括登録" ;;
        "usage_update") echo "ソースから最新版をインストール (git pull + コピー)" ;;
        "usage_lang") echo "表示言語を変更 (default: en)" ;;
        "usage_version") echo "バージョン表示" ;;
        "example_anywhere") echo "どこからでも OK: 起動 or メニュー" ;;
        "example_create_setup") echo "を作成してセットアップ" ;;

        *) echo "$key" ;;
      esac
      ;;
    *)
      # English (default)
      case "$key" in
        # === Common ===
        "yes") echo "yes" ;;
        "no") echo "no" ;;
        "cancel") echo "Cancelled" ;;
        "confirm") echo "Continue?" ;;
        "continue") echo "Continue?" ;;
        "create") echo "Create?" ;;
        "created") echo "Created" ;;
        "updated") echo "Updated" ;;
        "deleted") echo "Deleted" ;;
        "not_found") echo "not found" ;;
        "already_exists") echo "already exists" ;;
        "invalid") echo "Invalid" ;;
        "invalid_command") echo "Unknown command" ;;
        "required") echo "is required" ;;
        "files") echo "files" ;;
        "skip") echo "Skip" ;;
        "copy") echo "Copy" ;;

        # === Workspace ===
        "workspace") echo "Workspace" ;;
        "workspaces") echo "Workspaces" ;;
        "new_workspace") echo "Create new Workspace" ;;
        "workspace_name") echo "Workspace name" ;;
        "workspace_desc") echo "Description" ;;
        "workspace_not_found") echo "Workspace not found" ;;
        "workspace_already_setup") echo "This directory is already set up as a workspace" ;;
        "workspace_setup") echo "Set up workspace" ;;
        "workspace_launch") echo "Launching workspace" ;;
        "workspace_current") echo "Current workspace" ;;
        "workspace_detail") echo "Workspace details" ;;
        "workspace_list") echo "Workspace list" ;;
        "workspace_scan") echo "Workspace scan" ;;
        "not_a_workspace") echo "Current directory is not a workspace" ;;
        "remove_from_registry") echo "Remove from registry" ;;
        "files_remain") echo "Note: Files (.workspace.json, CLAUDE.md) will not be deleted" ;;
        "re_setup") echo "Reconfigure?" ;;
        "launch_as_is") echo "Launch as is?" ;;

        # === Directory ===
        "directory") echo "Directory" ;;
        "directories") echo "Directories" ;;
        "add_directory") echo "Add directory" ;;
        "dir_not_found") echo "Directory does not exist" ;;
        "dir_add_path") echo "Path to add" ;;
        "dir_add_role") echo "Role label (optional)" ;;
        "dir_added") echo "Added" ;;
        "search") echo "Search" ;;
        "path") echo "Path" ;;
        "select_dir_prompt") echo "Select directory" ;;
        "add_anyway") echo "Add anyway?" ;;

        # === Registry ===
        "registered") echo "Registered" ;;
        "register") echo "Register" ;;
        "unregistered") echo "Unregistered" ;;
        "path_missing") echo "Path missing" ;;
        "current_location") echo "Current" ;;
        "newly_registered") echo "newly registered" ;;

        # === Time ===
        "just_now") echo "just now" ;;
        "minutes_ago") echo " min ago" ;;
        "hours_ago") echo " hr ago" ;;
        "days_ago") echo " days ago" ;;
        "weeks_ago") echo " weeks ago" ;;
        "months_ago") echo " months ago" ;;

        # === Commands ===
        "cmd_new") echo "Create new" ;;
        "cmd_resume") echo "Resume" ;;
        "cmd_quit") echo "Exiting" ;;
        "cmd_select") echo "Select" ;;

        # === Setup ===
        "setup_complete") echo "Setup complete!" ;;
        "setup_step1") echo "Workspace name" ;;
        "setup_step2") echo "Description (optional)" ;;
        "setup_step3") echo "Add repositories/directories" ;;
        "setup_step4") echo "Generate configuration files" ;;
        "setup_step5") echo "Generate CLAUDE.md" ;;
        "setup_step6") echo "Register to registry" ;;
        "setup_path_hint") echo "Select a directory with fzf (or type a path if fzf is unavailable). Press Esc or empty Enter when done." ;;
        "setup_run") echo "To launch:" ;;
        "setup_claude_md") echo "Generate workspace CLAUDE.md" ;;
        "setup_config_file") echo "Generate configuration file" ;;
        "target_dirs") echo "Add target repositories/directories" ;;

        # === Update ===
        "update_fetching") echo "Fetching latest version..." ;;
        "update_installing") echo "Installing libraries..." ;;
        "update_complete") echo "Update complete!" ;;
        "update_version") echo "Version" ;;
        "update_source") echo "Source" ;;

        # === Launch ===
        "launch_workspace") echo "Launching workspace" ;;
        "launch_valid_dirs") echo "No valid directories" ;;
        "launch_use_add_dir") echo "Use cw add-dir to add directories" ;;
        "launch_here") echo "Run cw setup in this directory" ;;
        "skip_not_exist") echo "Skip (does not exist)" ;;

        # === List ===
        "list_dirs") echo "dirs" ;;
        "list_empty") echo "Use cw new to create a workspace" ;;

        # === Info ===
        "info_name") echo "Name" ;;
        "info_desc") echo "Description" ;;
        "info_created") echo "Created" ;;
        "info_path") echo "Path" ;;
        "info_registered_dirs") echo "Registered directories" ;;
        "info_claude_md_exists") echo "CLAUDE.md exists" ;;

        # === Errors ===
        "error_jq_required") echo "jq is required: brew install jq" ;;
        "error_claude_not_found") echo "claude command not found" ;;
        "error_source_not_found") echo "Source directory not found" ;;
        "error_not_git_repo") echo "Not a Git repository" ;;
        "error_git_pull_failed") echo "git pull failed" ;;

        # === Menu ===
        "menu_recent") echo "Recent Workspaces:" ;;
        "menu_create_new") echo "Create new Workspace" ;;
        "menu_quit") echo "Quit" ;;
        "press_enter") echo "Press Enter to continue" ;;
        "menu_action_resume") echo "▶ Resume" ;;
        "menu_action_add_dir") echo "+ Add Dir" ;;
        "menu_action_info") echo "ℹ Info" ;;
        "menu_action_finder") echo "⊙ Open in Finder" ;;
        "menu_action_forget") echo "✗ Forget" ;;
        "menu_action_back") echo "← Back" ;;

        # === Usage ===
        "usage_title") echo "Claude Code multi-repo workspace manager" ;;
        "usage") echo "Usage" ;;
        "usage_examples") echo "Examples" ;;
        "usage_launch_or_menu") echo "Show workspace menu" ;;
        "usage_new") echo "Create new Workspace and launch" ;;
        "usage_resume") echo "Show Workspace selection menu" ;;
        "usage_setup") echo "Setup current directory as a Workspace" ;;
        "usage_launch") echo "Launch Claude Code for Workspace" ;;
        "usage_list") echo "List registered Workspaces" ;;
        "usage_info") echo "Show Workspace details" ;;
        "usage_add_dir") echo "Add directory to Workspace" ;;
        "usage_forget") echo "Remove Workspace from registry" ;;
        "usage_scan") echo "Scan WorkingProjects/ for unregistered Workspaces" ;;
        "usage_update") echo "Update from source (git pull + copy)" ;;
        "usage_lang") echo "Change display language (default: en)" ;;
        "usage_version") echo "Show version" ;;
        "example_anywhere") echo "From anywhere: launch or menu" ;;
        "example_create_setup") echo "create and setup" ;;

        *) echo "$key" ;;
      esac
      ;;
  esac
}

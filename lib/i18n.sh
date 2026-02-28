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
        # Common
        "yes") echo "はい" ;;
        "no") echo "いいえ" ;;
        "cancel") echo "キャンセルしました" ;;
        "confirm") echo "続けますか?" ;;
        "create") echo "作成しますか?" ;;
        "created") echo "作成しました" ;;
        "updated") echo "更新しました" ;;
        "deleted") echo "削除しました" ;;
        "not_found") echo "見つかりません" ;;
        "already_exists") echo "すでに存在します" ;;
        "invalid") echo "無効です" ;;
        "required") echo "が必要です" ;;
        "install") echo "インストール" ;;
        "uninstall") echo "アンインストール" ;;

        # Workspace
        "workspace") echo "ワークスペース" ;;
        "new_workspace") echo "新規ワークスペースを作成" ;;
        "workspace_name") echo "ワークスペース名" ;;
        "workspace_desc") echo "説明" ;;
        "workspace_not_found") echo "ワークスペースが見つかりません" ;;
        "workspace_already_setup") echo "このディレクトリはすでにワークスペースとして設定済みです" ;;
        "workspace_setup") echo "ワークスペースをセットアップ" ;;
        "workspace_launch") echo "ワークスペースを起動します" ;;

        # Directory
        "directory") echo "ディレクトリ" ;;
        "add_directory") echo "ディレクトリを追加" ;;
        "dir_not_found") echo "ディレクトリが存在しません" ;;
        "dir_add_path") echo "追加するパス" ;;
        "dir_add_role") echo "役割ラベル (任意)" ;;
        "dir_added") echo "追加しました" ;;

        # Registry
        "registered") echo "登録済み" ;;
        "unregistered") echo "未登録" ;;
        "path_missing") echo "パス不在" ;;
        "current_location") echo "現在地" ;;

        # Time
        "just_now") echo "たった今" ;;
        "minutes_ago") echo "分前" ;;
        "hours_ago") echo "時間前" ;;
        "days_ago") echo "日前" ;;
        "weeks_ago") echo "週間前" ;;
        "months_ago") echo "ヶ月前" ;;

        # Commands
        "cmd_new") echo "新規作成" ;;
        "cmd_resume") echo "再開" ;;
        "cmd_quit") echo "終了" ;;
        "cmd_select") echo "選択" ;;

        # Setup
        "setup_complete") echo "セットアップ完了!" ;;
        "setup_step1") echo "ワークスペース名" ;;
        "setup_step2") echo "説明 (任意)" ;;
        "setup_step3") echo "リポジトリ/ディレクトリの追加" ;;
        "setup_step4") echo "設定ファイルを生成" ;;
        "setup_step5") echo "CLAUDE.md を生成" ;;
        "setup_step6") echo "レジストリに登録" ;;
        "setup_path_hint") echo "パスを入力して Enter。完了したら空 Enter。" ;;

        # Update
        "update_fetching") echo "最新版を取得中..." ;;
        "update_installing") echo "ライブラリをインストール中..." ;;
        "update_complete") echo "アップデート完了!" ;;
        "update_version") echo "バージョン" ;;
        "update_source") echo "ソース" ;;

        # Errors
        "error_jq_required") echo "jq が必要です: brew install jq" ;;
        "error_claude_not_found") echo "claude コマンドが見つかりません" ;;
        "error_source_not_found") echo "ソースディレクトリが見つかりません" ;;
        "error_not_git_repo") echo "Git リポジトリではありません" ;;
        "error_git_pull_failed") echo "git pull に失敗しました" ;;

        # Menu
        "menu_recent") echo "最近のワークスペース:" ;;
        "menu_create_new") echo "新規ワークスペースを作成" ;;
        "menu_quit") echo "終了" ;;

        *) echo "$key" ;;
      esac
      ;;
    *)
      # English (default)
      case "$key" in
        "just_now") echo "just now" ;;
        "minutes_ago") echo " minutes ago" ;;
        "hours_ago") echo " hours ago" ;;
        "days_ago") echo " days ago" ;;
        "weeks_ago") echo " weeks ago" ;;
        "months_ago") echo " months ago" ;;
        "cmd_new") echo "Create new" ;;
        "cmd_resume") echo "Resume" ;;
        "cmd_quit") echo "Quit" ;;
        "cmd_select") echo "Select" ;;
        "menu_recent") echo "Recent Workspaces:" ;;
        "menu_create_new") echo "Create new Workspace" ;;
        "menu_quit") echo "Quit" ;;
        "workspace_name") echo "Workspace name" ;;
        "workspace_desc") echo "Description (optional)" ;;
        "workspace_not_found") echo "Workspace not found" ;;
        "workspace_already_setup") echo "This directory is already set up as a workspace" ;;
        "workspace_setup") echo "Set up workspace" ;;
        "workspace_launch") echo "Launching workspace" ;;
        "new_workspace") echo "Create new Workspace" ;;
        "create") echo "Create?" ;;
        "created") echo "Created" ;;
        "cancel") echo "Cancelled" ;;
        "confirm") echo "Continue?" ;;
        "directory") echo "Directory" ;;
        "dir_not_found") echo "Directory does not exist" ;;
        "dir_add_path") echo "Path to add" ;;
        "dir_add_role") echo "Role label (optional)" ;;
        "dir_added") echo "Added" ;;
        "add_directory") echo "Add directory" ;;
        "registered") echo "Registered" ;;
        "unregistered") echo "Unregistered" ;;
        "path_missing") echo "Path missing" ;;
        "current_location") echo "Current" ;;
        "setup_complete") echo "Setup complete!" ;;
        "setup_step1") echo "Workspace name" ;;
        "setup_step2") echo "Description (optional)" ;;
        "setup_step3") echo "Add repositories/directories" ;;
        "setup_step4") echo "Generate configuration files" ;;
        "setup_step5") echo "Generate CLAUDE.md" ;;
        "setup_step6") echo "Register to registry" ;;
        "setup_path_hint") echo "Enter path and press Enter. Press empty Enter when done." ;;
        "update_fetching") echo "Fetching latest version..." ;;
        "update_installing") echo "Installing libraries..." ;;
        "update_complete") echo "Update complete!" ;;
        "update_version") echo "Version" ;;
        "update_source") echo "Source" ;;
        "error_jq_required") echo "jq is required: brew install jq" ;;
        "error_claude_not_found") echo "claude command not found" ;;
        "error_source_not_found") echo "Source directory not found" ;;
        "error_not_git_repo") echo "Not a Git repository" ;;
        "error_git_pull_failed") echo "git pull failed" ;;
        "required") echo "is required" ;;
        *) echo "$key" ;;
      esac
      ;;
  esac
}

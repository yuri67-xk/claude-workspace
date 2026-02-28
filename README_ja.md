# claude-workspace (cw)

> [English](./README.md)

Claude Code マルチリポジトリ Workspace マネージャー

## インストール

```bash
git clone https://github.com/yuri67-xk/claude-workspace ~/.claude-workspace-src
cd ~/.claude-workspace-src
bash install.sh
```

**依存関係**
- `jq` (`brew install jq`)
- `claude` (Claude Code CLI)

---

## 使い方

### どこからでも `cw` を実行するだけ

```bash
cw
```

- **Workspace ディレクトリにいる場合** → そのまま Claude Code を起動
- **それ以外の場所にいる場合** → インタラクティブメニューを表示

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  claude-workspace (cw)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  最近の Workspace:

  [1] Store360 Refactor  3日前
      /Users/yuri/WorkingProjects/store360-refactor

  [2] My Feature         1週間前
      /Users/yuri/WorkingProjects/my-feature

  ────────────────────────────────────────
  [N] 新規 Workspace を作成
  [Q] 終了

  選択 [1-2 / N / Q]:
```

---

### 新規 Workspace を作成

```bash
cw new
```

対話式で進みます:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  新規 Workspace を作成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Workspace 名: Store360 Refactor

  Workspace 名:  Store360 Refactor
  作成先:        ~/WorkingProjects/Store360-Refactor
  作成しますか? [Y/n]:
```

- `~/WorkingProjects/<名前>/` フォルダを自動作成
- そのまま `cw setup` に進む
- セットアップ完了後、Claude Code を起動

名前を引数で渡すことも可能:

```bash
cw new store360-refactor
```

---

### 既存 Workspace に作業再開

```bash
cw resume   # または cw r
```

どこからでも実行でき、登録済み Workspace の一覧メニューを表示します。

---

### Workspace の手動セットアップ

既存ディレクトリを Workspace として登録する場合:

```bash
cd ~/WorkingProjects/store360-refactor
cw setup
```

生成されるファイル:
- `<workspace>/.workspace.json` — workspace 設定
- `<workspace>/CLAUDE.md` — workspace コンテキスト (Claude Code が自動読み込み)
- `<repo>/CLAUDE.md` — 各リポジトリに "Used by Workspaces" セクションを追記

---

### Claude Code を起動

```bash
cd ~/WorkingProjects/store360-refactor
cw          # または cw launch
```

`.workspace.json` に登録されたすべてのディレクトリを `--add-dir` 付きで Claude Code が起動します。

名前を指定して起動することも可能:

```bash
cw launch "Store360 Refactor"
```

---

### ディレクトリを後から追加

```bash
cw add-dir ~/repos/store360-flutter-wrapper
```

---

### Workspace 一覧

```bash
cw list
```

最近使用した順に表示します。

---

### Workspace 詳細

```bash
cw info
```

---

### レジストリから削除

```bash
cd ~/WorkingProjects/store360-refactor
cw forget
```

ファイル（`.workspace.json`、`CLAUDE.md`）はそのままで、レジストリの登録だけ削除します。

---

### アップデート

```bash
cw update
```

ソースディレクトリで `git pull` を実行し、最新版のライブラリをインストールします。

---

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `cw` | Workspace なら即起動、なければメニューを表示 |
| `cw new [name]` | 新規 Workspace を WorkingProjects/ に作成して起動 |
| `cw resume` | Workspace 選択メニューを表示（どこからでも） |
| `cw setup` | 現在のディレクトリを workspace としてセットアップ |
| `cw launch [name]` | workspace の Claude Code を起動 |
| `cw add-dir <path>` | ディレクトリを追加 |
| `cw list` | workspace 一覧（最近使用順） |
| `cw info` | 現在の workspace の詳細 |
| `cw forget` | 現在の workspace をレジストリから削除 |
| `cw scan` | WorkingProjects/ をスキャンして未登録 workspace を一括登録 |
| `cw update` | ソースから最新版をインストール (git pull + コピー) |
| `cw help` | ヘルプ |

---

## ファイル構成

```
~/WorkingProjects/
└── store360-refactor/
    ├── .workspace.json     ← cw の設定ファイル
    ├── CLAUDE.md           ← workspace コンテキスト (自動生成)
    └── notes/              ← 作業メモ (任意)

~/.claude-workspace/
├── registry.json           ← 全 workspace のグローバルレジストリ
├── source_path             ← cw update 用のソースパス
└── lib/                    ← cw ライブラリ
```

### .workspace.json の例

```json
{
  "name": "Store360 Refactor",
  "description": "SDK monolith分解プロジェクト",
  "workspace_path": "/Users/yuri/WorkingProjects/store360-refactor",
  "created_at": "2025-06-01T12:00:00Z",
  "dirs": [
    { "path": "/Users/yuri/repos/store360-ios-sdk", "role": "iOS SDK" },
    { "path": "/Users/yuri/repos/store360-android-sdk", "role": "Android SDK" },
    { "path": "/Users/yuri/repos/store360-flutter-wrapper", "role": "Flutter Wrapper" }
  ]
}
```

### registry.json の例

```json
{
  "workspaces": [
    {
      "name": "Store360 Refactor",
      "path": "/Users/yuri/WorkingProjects/store360-refactor",
      "created_at": "2025-06-01T12:00:00Z",
      "last_used": "2025-06-10T09:00:00Z"
    }
  ]
}
```

---

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `CW_HOME` | `~/.claude-workspace` | cw のデータディレクトリ |
| `WORKING_PROJECTS_DIR` | `~/WorkingProjects` | `cw new` / `cw list` の基準ディレクトリ |

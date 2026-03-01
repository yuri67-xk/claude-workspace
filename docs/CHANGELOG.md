# Changelog

> [日本語版はこちら / Japanese version](./CHANGELOG_ja.md)

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Interactive fzf workspace menu with right-side preview pane showing workspace details
- Sub-menu per workspace with actions: Resume, Add Dir, Info, Open in Finder, Forget, Back
- All workspace operations now complete within a single `cw` CLI session without exiting
- Forget action now offers a secondary mode picker: "Registry only" (previous behavior) or "Delete directory" (`rm -rf`, restricted to `WorkingProjects/` subdirectories). Includes safety guard and two-step destructive confirmation.

### Changed

- `cw` (bare invocation) always shows the interactive menu regardless of current directory
- Workspace selection in non-fzf (numbered) mode also shows the sub-menu instead of launching directly

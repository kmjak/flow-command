---
name: project
description: tixforge のプロジェクト設定。init でこのプロジェクトを tixforge で使える状態にする（設定ファイル・検証コマンド・commit 規約・チケット管理（ローカル or GitHub issue）・レビュー要否・GitHub Actions を設定し、context を対話で作るか雛形だけ用意する）。/tixforge:project で明示起動する。
argument-hint: "[init]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-id.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh *)
---

# /tixforge:project — プロジェクトの設定

引数：`$ARGUMENTS`

## 現在の状態（起動時に自動で取得）

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh`

## 置き場所

- plugin：`${CLAUDE_PLUGIN_ROOT}`（手順では `<plugin>` と書く）
- スクリプト：`${CLAUDE_PLUGIN_ROOT}/scripts/`（手順では `<scripts>` と書く）

## サブコマンド

| 起動 | 内容 | 手順ファイル |
|------|------|--------------|
| `/tixforge:project init` | プロジェクトを初期化する（再実行しても安全） | `${CLAUDE_SKILL_DIR}/init.md` |
| `/tixforge:project` | init と同じ | 同上 |

それ以外の引数が渡されたら実行せず、使えるサブコマンドを示して止まる。

## 手順ファイルと参照ファイル（必須）

サブコマンドが決まったら、**作業を始める前に必ず手順ファイルを Read する**。読まずに記憶や推測で進めない。参照ファイルは、手順が読むよう指示したときだけ読む。

| 参照ファイル | 読むとき |
|--------------|----------|
| `${CLAUDE_PLUGIN_ROOT}/references/github/<名前>.md` | 手順が指示したファイルだけ（`tracker: github` のとき。`labels`・`actions`） |

以下の共通規約は、このスキルのすべてに適用する。

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh`

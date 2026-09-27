---
name: dev
description: tixforge の開発。1 つのチケットを 6 フェーズ Research → Approach → Plan → Implement → Review → PR で進める。進捗は .tixforge/<ticket-id>/state.md に集約するので、途中で止めても同じフェーズから再開できる。reset で run を捨てて最初からやり直す。/tixforge:dev で明示起動する。
argument-hint: "[<ticket-id> | reset <ticket-id>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-id.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh *)
---

# /tixforge:dev — チケットの開発

引数：`$ARGUMENTS`

## 現在の状態（起動時に自動で取得）

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh`

## 置き場所

- plugin：`${CLAUDE_PLUGIN_ROOT}`（手順では `<plugin>` と書く）
- スクリプト：`${CLAUDE_PLUGIN_ROOT}/scripts/`（手順では `<scripts>` と書く）

## サブコマンド

| 起動 | 内容 | 手順ファイル |
|------|------|--------------|
| `/tixforge:dev <ticket-id>` | 6 フェーズで実装から PR まで進める（状態ファイルがあれば、その Status から再開する） | `${CLAUDE_SKILL_DIR}/run.md` |
| `/tixforge:dev reset <ticket-id>` | run（`state.md`）を捨てて、次の dev で Research からやり直す | `${CLAUDE_SKILL_DIR}/reset.md` |
| `/tixforge:dev` | 選択肢を出す（下記） | — |

**引数の解釈：** 先頭の語が `reset` なら reset で、残りはチケット id。それ以外は引数全体をチケット id として dev で進める。

### 引数が無い場合（`/tixforge:dev`）

上の「現在の状態」にある進行中の run（`done`・`canceled` 以外）を使い、AskUserQuestion で選んでもらう（単一選択）。推測で決めない。

1. **進行中の run を再開** — 進行中の run のチケット id と Status を説明に含める。**進行中の run が無ければこの選択肢は出さない。** 複数あるなら、どれを再開するか続けて尋ねる。
2. **チケットを選んで始める** — チケット id を尋ねる（`.tixforge/*/ticket.md`、`tracker: github` なら `tixforge:todo` の issue を候補として示す）。

質問文に「run のやり直しは `/tixforge:dev reset <ticket-id>`」と添える。

## 手順ファイルと参照ファイル（必須）

サブコマンドが決まったら、**作業を始める前に必ずその手順ファイルを Read する**。読まずに記憶や推測で進めない。**他のサブコマンドの手順ファイルは読まない。** 参照ファイルは、手順が読むよう指示したときだけ読む。

| 参照ファイル | 読むとき |
|--------------|----------|
| `${CLAUDE_PLUGIN_ROOT}/references/github.md` | 手順が指示したとき（`GT-` のチケットを扱うとき。`tracker: github` の create を含む） |
| `${CLAUDE_PLUGIN_ROOT}/references/rollback.md` | チケットが変わり、進行中の run のフェーズを戻すか決めるとき（dev が指示する） |

以下の共通規約は、このスキルのすべてに適用する。

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh`

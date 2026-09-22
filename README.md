# flow-command

チケット単位でアプリ開発を回す Claude Code スキル `/flow`。

1 つのチケットを 6 フェーズで進め、進捗を 1 ファイルに集約することで「途中で止めて後から再開」できるようにする。

```
Research → Approach → Plan → Implement → Review → PR
```

## 導入

スキル本体は `skills/flow/SKILL.md`。個人スキル（全プロジェクト共通）として使うため、`~/.claude/skills/flow` にシンボリックリンクを張る。

```sh
ln -s "$(pwd)/skills/flow" ~/.claude/skills/flow
```

リンクなので、このリポジトリで `SKILL.md` を編集すればそのまま全プロジェクトに反映される。

特定のプロジェクトだけで使いたい場合は、そのプロジェクトの `.claude/skills/flow/` に `SKILL.md` をコピーする。

## 使い方

```
/flow <ticket-id>
```

- 明示起動専用（`disable-model-invocation: true`）。Claude が勝手に発火させることはない。
- チケット id は数値とは限らない（v1 はローカルのファイル名 stem）。
- 状態ファイルが既にあれば、その `Status` のフェーズから再開する。無ければ新規作成して Research から始める。
- 引数を省略すると、どのチケットか尋ねる。進行中の flow がちょうど 1 つなら、その再開を提案する。

## 規約パス（v1：ローカル docs のみ）

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**` |
| チケット | `docs/tickets/<ticket-id>.md` |
| flow 状態 | `docs/flow/<ticket-id>/main.md` |
| ブランチ名 | `<ticket-id>-<slug>` |

`setup` / `init` は無い。上記パスは固定規約。

## フェーズ

| # | フェーズ | 内容 |
|---|----------|------|
| 1 | Research | チケットと `docs/context/**`・コードを読み、要求・制約・疑問点を整理する |
| 2 | Approach | 実装方針（選択肢・採用案・トレードオフ）を決めて合意する |
| 3 | Plan | ブランチ名と順序付きの commit 分割を決める（v1 は単一ブランチ） |
| 4 | Implement | 計画どおりに実装・commit する（commit ごとには止まらない） |
| 5 | Review | 実装と Approach / Plan / チケットの乖離を両方向でチェックする |
| 6 | PR | 明示的な確認の後にだけ push して PR を作成する |

### 承認ゲート

- 全フェーズの境界で停止し、要約を出して承認を待つ。この停止点が再開点になる。
- PR の前は、前段のゲートを飛ばしてきても必ず停止する（強ゲート）。

## 状態ファイル

`docs/flow/<ticket-id>/main.md` が run の単一の真実。各フェーズが自分のセクション（英語）を書き、`Status` を更新する。

`Status` のフォーマットは `<phase>:<state>`：

- `<phase>`：`research | approach | plan | implement | review | pr`、終端は `done`
- `<state>`：`in-progress`（作業中）／`awaiting-approval`（ゲートで承認待ち）

## 注意

- `allowed-tools`（Read / Glob / Grep）の事前承認は、スキルを起動したターンにだけ有効。次のメッセージ以降は通常の許可プロンプトが出る。常時許可したい場合は `.claude/settings.json` の `permissions.allow` に追加する。
- Plan 以降は git リポジトリが、PR にはリモートと `gh` CLI が必要。

## v2 予定

- ローカル docs 以外のチケット／知識ソース（Jira / GitHub Projects・Issues / Confluence）と、それらを選ぶ `setup` / `init`
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/<subticket>.md`）

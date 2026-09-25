# flow-command

チケット単位でアプリ開発を回す Claude Code スキル `/flow`。

プロジェクト初期化（init）・チケット作成（new）・開発（dev）の 3 モードを持つ。dev では 1 つのチケットを 6 フェーズで進め、進捗を 1 ファイルに集約することで「途中で止めて後から再開」できるようにする。

```
Research → Approach → Plan → Implement → Review → PR
```

## 導入

スキル本体は `skills/flow/SKILL.md`（共通規約とモードの振り分け）と `skills/flow/modes/*.md`（各モードの手順。起動したモードの分だけ読む）。個人スキル（全プロジェクト共通）として使うため、`~/.claude/skills/flow` にシンボリックリンクを張る。

```sh
ln -sfn "$(pwd)/skills/flow" ~/.claude/skills/flow
```

`-n` を付けないと、既にリンクがある状態で再実行したときにリンク先ディレクトリの中へ `flow` という循環リンクが作られ、スキルの読み込みが壊れるので注意。

リンクなので、このリポジトリで `SKILL.md` を編集すればそのまま全プロジェクトに反映される。

dev の Review で使う reviewer agent（`agents/flow-reviewer.md`）も同じようにリンクする。agent はスキルのディレクトリに同梱できないため、別に導入が必要。

```sh
mkdir -p ~/.claude/agents
ln -sfn "$(pwd)/agents/flow-reviewer.md" ~/.claude/agents/flow-reviewer.md
```

未導入のまま Review に入ると、flow は停止して導入を案内する（別の agent で代用はしない）。

特定のプロジェクトだけで使いたい場合は、そのプロジェクトの `.claude/skills/flow/` に `skills/flow/` の中身（`SKILL.md`・`modes/`・`scripts/`）をコピーし、reviewer agent は `.claude/agents/flow-reviewer.md` にコピーする。

## 使い方

```
/flow init                # プロジェクト初期化：docs 雛形 + context 作成（対話 or 自分で書く）（最初に 1 回）
/flow new <ticket-id>     # チケット作成：docs/tickets/<ticket-id>.md を対話で作る
/flow dev <ticket-id>     # 6 フェーズで実装から PR まで進める
/flow                     # 再開 / dev / new / init を選択肢で表示（進行中の run が無ければ再開は出ない）
```

- 明示起動専用（`disable-model-invocation: true`）。Claude が勝手に発火させることはない。
- チケット id は数値とは限らない（v1 はローカルのファイル名 stem）。
- モード名を付けない `/flow <ticket-id>` は実行せず、`/flow dev <ticket-id>` のことか確認するだけ。
- dev は状態ファイルが既にあれば、その `Status` のフェーズから再開する。無ければ新規作成して Research から始める。
- 典型的な流れ：`/flow init` → `/flow new <id>` → `/flow dev <id>`
- `/flow new` は commit しない。チケットは実装 PR の最初の commit として `/flow dev` の Implement で commit される（まとめて複数作っても、各チケットは自分の PR に入る）。

## 規約パス（v1：ローカル docs のみ）

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**` |
| チケット | `docs/tickets/<ticket-id>.md` |
| flow 設定 | `docs/flow.config.yml`（git 管理） |
| commit 規約 | `docs/context/commit.md`（`Source:` に既存の規約ファイルのパス、無ければ本文に規約を書く） |
| flow 状態 | `docs/flow/<ticket-id>/main.md`（git 管理外） |
| ブランチ名 | `<ticket-id>-<slug>` |

上記パスは固定規約。`/flow init` はこの規約どおりの雛形を作るだけで、パスやソースの選択はしない。

チケット本文と `docs/context/**` は `docs/flow.config.yml` の `language` で書く。既定は日本語で、`/flow init` のときに日本語／English／その他から選ぶ。flow 状態（`main.md`）の本文と PR のタイトル・本文も同じ言語で書く（見出し・`Status` の値は英語の固定キー）。

検証コマンド（テスト・lint など）は `docs/flow.config.yml` の `commands` に書く。`/flow init` がプロジェクト（`package.json`・`Makefile`・CI 設定など）から候補を読み取り、ユーザーが確定したものだけを書く。dev は Implement の完了時と Review の開始時にこれを全て実行し、通るまでゲートに進まない。

```yaml
language: ja
commands:
  test: npm test
  lint: npm run lint
```

`docs/flow/` は `.gitignore` に入れて git 管理しない（`/flow init` が追加する）。flow 状態は個人の作業記録であり、PR に含めるとレビュアーが検討過程に引っ張られてしまうため。

## フェーズ

| # | フェーズ | 内容 |
|---|----------|------|
| 1 | Research | チケットと `docs/context/**`・コードを読み、要求・制約・疑問点を整理する |
| 2 | Approach | 実装方針（選択肢・採用案・トレードオフ）を決めて合意する |
| 3 | Plan | ブランチ名と順序付きの commit 分割を決める（v1 は単一ブランチ） |
| 4 | Implement | 計画どおりに実装・commit する（commit ごとには止まらない）。最後に検証コマンドを全て実行し、通るまで直す |
| 5 | Review | reviewer agent（`flow-reviewer`）が、実装の経緯を知らない状態で実装と Approach / Plan / チケットの乖離（相違・未実装・合意外の変更）を洗い出す。実装したセッションは指摘を消さずに推奨と根拠を添えるだけで、項目ごとに修正（→ Implement）／方針見直し（→ Approach）／受け入れをユーザーが選ぶ |
| 6 | PR | 明示的な確認の後にだけ push して PR を作成し、Approve・CI 成功・コンフリクトなしになるまで見届ける |

### 承認ゲート

- 全フェーズの境界で停止し、要約を出して承認を待つ。この停止点が再開点になる。
- PR の前は、前段のゲートを飛ばしてきても必ず停止する（強ゲート）。
- PR 作成後は `pr:awaiting-review` で止まる。`/flow dev <ticket-id>` で再開すると `skills/flow/scripts/pr-status.sh` で状況を確認し、Approve 済み・CI 成功・コンフリクトなしなら `done`。CI 失敗・コンフリクト・修正依頼があれば `pr:in-progress` に戻って対応する（push 前に確認あり）。

## 状態ファイル

`docs/flow/<ticket-id>/main.md` が run の単一の真実。各フェーズが自分のセクション（本文はドキュメント言語）を書き、`Status` を更新する。

`Status` のフォーマットは `<phase>:<state>`：

- `<phase>`：`research | approach | plan | implement | review | pr`、終端は `done`
- `<state>`：`in-progress`（作業中）／`awaiting-approval`（ゲートで承認待ち）／`awaiting-review`（`pr` のみ。PR の Approve 待ち）

## 注意

- `allowed-tools`（Read / Glob / Grep）の事前承認は、スキルを起動したターンにだけ有効。次のメッセージ以降は通常の許可プロンプトが出る。常時許可したい場合は `.claude/settings.json` の `permissions.allow` に追加する。
- Plan 以降は git リポジトリが、PR にはリモートと `gh` CLI が必要。
- `scripts/pr-status.sh` は Bash で実行するので、初回は許可プロンプトが出る。

## v2 予定

- ローカル docs 以外のチケット／知識ソース（Jira / GitHub Projects・Issues / Confluence）と、それらを選ぶ設定（`/flow init` の拡張）
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/<subticket>.md`）

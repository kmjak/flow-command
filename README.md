# flow-command

チケット単位でアプリ開発を回す Claude Code スキル `/flow`。

プロジェクト初期化（init）・チケット作成（new）・開発（dev）の 3 モードを持つ。dev では 1 つのチケットを 6 フェーズで進め、進捗を 1 ファイルに集約することで「途中で止めて後から再開」できるようにする。

```
Research → Approach → Plan → Implement → Review → PR
```

## 導入

スキル本体は `skills/flow/SKILL.md`（共通規約とモードの振り分け）と `skills/flow/modes/*.md`（各モードの手順。起動したモードの分だけ読む）、`skills/flow/references/github.md`（GitHub 連携時だけ読む）。個人スキル（全プロジェクト共通）として使うため、`~/.claude/skills/flow` にシンボリックリンクを張る。

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

特定のプロジェクトだけで使いたい場合は、そのプロジェクトの `.claude/skills/flow/` に `skills/flow/` の中身（`SKILL.md`・`modes/`・`references/`・`scripts/`）をコピーし、reviewer agent は `.claude/agents/flow-reviewer.md` にコピーする。

## 使い方

```
/flow init                # プロジェクト初期化：docs 雛形・検証コマンド・commit 規約・チケット管理の設定 + context 作成（再実行しても安全）
/flow new [作りたいもの]  # チケット作成：docs/tickets/<ticket-id>.md を対話で作る（id は自動。GitHub 連携なら issue も作る）
/flow dev <ticket-id>     # 6 フェーズで実装から PR まで進める
/flow                     # 再開 / dev / new / init を選択肢で表示（進行中の run が無ければ再開は出ない）
```

- 明示起動専用（`disable-model-invocation: true`）。Claude が勝手に発火させることはない。
- チケット id は `<prefix><0 埋めの番号>`（既定は `T000123`）。GitHub 連携なら issue 番号、ローカルなら連番から自動で決まる。dev には `T000123`・`123`・`#123` のどれを渡してもよい。
- モード名を付けない `/flow <ticket-id>` は実行せず、`/flow dev <ticket-id>` のことか確認するだけ。
- dev は状態ファイルが既にあれば、その `Status` のフェーズから再開する。無ければ新規作成して Research から始める。
- 典型的な流れ：`/flow init` → `/flow new` → `/flow dev <id>`
- `/flow new` は commit しない。チケットは実装 PR の最初の commit として `/flow dev` の Implement で commit される（まとめて複数作っても、各チケットは自分の PR に入る）。

## 規約パス

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**` |
| チケット | `docs/tickets/<ticket-id>.md`（正本。GitHub 連携時は issue がその写し） |
| flow 設定 | `docs/flow.config.yml`（git 管理） |
| commit 規約 | `docs/context/commit.md`（`Source:` に既存の規約ファイルのパス、無ければ本文に規約を書く） |
| flow 状態 | `docs/flow/<ticket-id>/main.md`（git 管理外） |
| ブランチ名 | `<ticket-id>-<slug>` |

上記パスは固定規約。`/flow init` はこの規約どおりの雛形を作るだけで、パスの選択はしない。

チケット本文と `docs/context/**` は `docs/flow.config.yml` の `language` で書く。既定は日本語で、`/flow init` のときに日本語／English／その他から選ぶ。flow 状態（`main.md`）の本文と PR のタイトル・本文も同じ言語で書く（見出し・`Status` の値は英語の固定キー）。

検証コマンド（テスト・lint など）は `docs/flow.config.yml` の `commands` に書く。`/flow init` がプロジェクト（`package.json`・`Makefile`・CI 設定など）から候補を読み取り、ユーザーが確定したものだけを書く。dev は Implement の完了時と Review の開始時にこれを全て実行し、通るまでゲートに進まない。

```yaml
language: ja
commands:
  test: npm test
  lint: npm run lint
```

`docs/flow/` は `.gitignore` に入れて git 管理しない（`/flow init` が追加する）。flow 状態は個人の作業記録であり、PR に含めるとレビュアーが検討過程に引っ張られてしまうため。

## GitHub issue 連携（任意）

`/flow init` でチケット管理に GitHub を選ぶと（`ticket.tracker: github`）、チケットが issue と連携する。チームで使うときに、誰がどのチケットをどこまで進めているかを見えるようにし、id の衝突を防ぐため。

- **一方通行**：正本はローカルのチケット。issue の本文はチケットから生成して上書きするので、手で編集しない（本文の冒頭で告知する）。コメントは自由。
- **issue に載せるもの**：チケットの「要件」「受け入れ条件」（そのままコピー）、ステータスのラベル、担当者。背景・未決事項・flow 状態は載せない。
- **id**：new で issue を作り、その番号から id を決める（#123 → `T000123`）。チケットには `Issue: #123` を書く。

| 時点 | issue |
|------|-------|
| `/flow new` | 作成、`flow:todo` |
| `/flow dev` の開始 | `flow:in-progress`、assignee に自分（他の人が assign 済みなら止まって確認） |
| PR 作成 | `flow:in-review`。PR 本文に `Closes #123` を必ず入れ、紐付けを確認する |
| マージ | 閉じる（`Closes` で閉じない Base 向けの PR でも flow が閉じる） |

チケットファイルは実装 PR に入るまで作成者の手元にしか無い。別の人が同じチケットを引き継ぐ場合は、作成者からチケットファイルを受け取る必要がある。

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

## hook による強制

`skills/flow/scripts/guard.sh` を PreToolUse hook として **`~/.claude/settings.json` に登録**すると、push・PR のゲートが指示ではなく仕組みで守られる。settings.json に登録するので、`/flow` を起動していないセッションや `--resume` で再開したセッションでも効く。flow のブランチ（`docs/flow/*/main.md` の `Branch` と一致するブランチ）でだけ判定し、それ以外のコマンド・ブランチは素通しする。

登録は `/flow init` が案内する。個人設定なので、「自分で追記する」（Claude は settings.json を読まない）か「AI に任せる」（差分を見せて確認を取ってから、バックアップを取って追記する）かを選べる。手で追記する場合は、`hooks.PreToolUse` の配列に次の要素を足す（`hooks` が無ければ作る）。反映は次に起動するセッションから。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "f=\"$HOME/.claude/skills/flow/scripts/guard.sh\"; [ -f \"$f\" ] || f=\"$CLAUDE_PROJECT_DIR/.claude/skills/flow/scripts/guard.sh\"; exec bash \"$f\""
          }
        ]
      }
    ]
  }
}
```

| ブロックするもの | 条件 |
|------------------|------|
| `gh pr create` | `Status` が `pr:awaiting-approval`（PR の確認ゲート）でない |
| `gh pr create` | チケットに issue があるのに、本文（`--body` / `--body-file`）に `Closes #<番号>` が無い |
| `git push` | `Status` が `pr:awaiting-approval`・`pr:awaiting-review`、または PR 作成済みの `pr:in-progress` 以外 |
| `git push --force` 等 | 常に（`-f`・`--force-with-lease`・`+refspec` を含む）。必要ならユーザーが `! git push --force-with-lease` で自分で実行する |

- 要 `jq`。無い場合は push / PR 作成だけを止めて、インストールを促す。
- 止めるのは Claude のツール呼び出しだけで、ユーザーが自分で実行する git / gh は止めない。
- コマンド文字列からの判定なので、完全な防御ではない（スクリプト経由の push などは検出できない）。
- 登録しない場合、ゲートは SKILL.md の指示だけで守られる。

## 注意

- `allowed-tools`（Read / Glob / Grep）の事前承認は、スキルを起動したターンにだけ有効。次のメッセージ以降は通常の許可プロンプトが出る。常時許可したい場合は `.claude/settings.json` の `permissions.allow` に追加する。
- Plan 以降は git リポジトリが、PR にはリモートと `gh` CLI が必要。GitHub 連携を使う場合は new から `gh` の認証が必要（未認証なら `! gh auth login` を案内して止まる）。
- `scripts/pr-status.sh` は Bash で実行するので、初回は許可プロンプトが出る。

## v2 予定

- GitHub issue 以外のチケット／知識ソース（Jira / GitHub Projects / Confluence）
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/<subticket>.md`）

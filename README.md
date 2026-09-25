# flow-command

チケット単位でアプリ開発を回す Claude Code スキル `/flow`。

プロジェクト初期化（init）・チケット作成（new）・編集（edit）・開発（dev）・やり直し（reset）・キャンセル（cancel）のモードを持つ。dev では 1 つのチケットを 6 フェーズで進め、進捗を 1 ファイルに集約することで「途中で止めて後から再開」できるようにする。

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
/flow edit <ticket-id>    # チケットを編集。進行中の run があれば、影響に応じてフェーズを戻す
/flow dev <ticket-id>     # 6 フェーズで実装から PR まで進める
/flow reset <ticket-id>   # run を捨てて Research からやり直す（ブランチは消すか残すか尋ねる）
/flow cancel <ticket-id>  # チケットを canceled として残し、以後操作しない（issue は not planned で閉じる）
/flow                     # 再開 / dev / new / init を選択肢で表示（進行中の run が無ければ再開は出ない）
```

- 明示起動専用（`disable-model-invocation: true`）。Claude が勝手に発火させることはない。
- チケット id は `<prefix><0 埋めの番号>`（既定は `T000123`）。GitHub 連携なら issue 番号、ローカルなら連番から自動で決まる。dev には `T000123`・`123`・`#123` のどれを渡してもよい。
- モード名を付けない `/flow <ticket-id>` は実行せず、`/flow dev <ticket-id>` のことか確認するだけ。
- dev は状態ファイルが既にあれば、その `Status` のフェーズから再開する。無ければ新規作成して Research から始める。
- 典型的な流れ：`/flow init` → `/flow new` → `/flow dev <id>`
- `done` と `canceled` のチケットは edit・reset・cancel できない（変えたいなら新しいチケットを作る）。
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
repository:
  host: github          # github | none（ローカルのみ）
  default_branch: main
```

`repository` は `/flow init` がリポジトリの状態から決める。GitHub リポジトリが無ければ、AI と対話して作る（オーナー・名前・公開範囲・説明・デフォルトブランチ、public なら LICENSE を 1 つずつ尋ねる）／自分で作る／不要（`host: none`）から選ぶ。config にはオーナー・名前・公開範囲は書かない（remote と GitHub から分かり、書くと食い違うため）。

`docs/flow/` は `.gitignore` に入れて git 管理しない（`/flow init` が追加する）。flow 状態は個人の作業記録であり、PR に含めるとレビュアーが検討過程に引っ張られてしまうため。

## GitHub issue 連携（任意）

`/flow init` でチケット管理に GitHub を選ぶと（`ticket.tracker: github`）、チケットが issue と連携する。チームで使うときに、誰がどのチケットをどこまで進めているかを見えるようにし、id の衝突を防ぐため。

- **一方通行**：正本はローカルのチケット。issue の本文はチケットから生成して上書きするので、手で編集しない（本文の冒頭で告知する）。コメントは自由。
- **issue に載せるもの**：チケットの全セクション（そのままコピー）、ステータスのラベル、担当者。flow 状態は載せない。
- **id**：new で issue を作り、その番号から id を決める（#123 → `T000123`）。チケットには `Issue: #123` を書く。

| 時点 | issue |
|------|-------|
| `/flow new` | 作成、`flow:todo` |
| `/flow dev` の開始 | `flow:in-progress`、assignee に自分（他の人が assign 済みなら止まって確認） |
| PR 作成 | `flow:in-review`。PR 本文に `Closes #123` を必ず入れ、紐付けを確認する |
| マージ | 閉じる（`Closes` で閉じない Base 向けの PR でも flow が閉じる） |

チケットファイルは実装 PR に入るまで作成者の手元にしか無いが、issue に全文が載っているので、手元から消えた場合や別の人が引き継ぐ場合は issue から復元できる（dev・edit・cancel が自動で行い、内容を確認してから書く）。`tracker: local` にはこの仕組みが無い。

## フェーズ

| # | フェーズ | 内容 |
|---|----------|------|
| 1 | Research | チケットと `docs/context/**`・コードを読み、要求・制約・疑問点を整理する |
| 2 | Approach | 実装方針（選択肢・採用案・トレードオフ）を決めて合意する |
| 3 | Plan | ブランチ名と順序付きの commit 分割を決める（v1 は単一ブランチ） |
| 4 | Implement | 計画どおりに実装・commit する（commit ごとには止まらない）。最後に検証コマンドを全て実行し、通るまで直す |
| 5 | Review | reviewer agent（`flow-reviewer`）が、実装の経緯を知らない状態で実装と Approach / Plan / チケットの乖離（相違・未実装・合意外の変更）を洗い出す。実装したセッションは指摘を消さずに推奨と根拠を添えるだけで、項目ごとに修正（→ Implement）／方針見直し（→ Approach）／受け入れをユーザーが選ぶ |
| 6 | PR | 明示的な確認の後にだけ push して PR を作成し、Approve・CI 成功・コンフリクトなしになるまで見届ける。`host: none` なら PR は出さず、確認の後に `default_branch` へ `git merge --no-ff` してブランチを削除する（コンフリクトしたら `--abort` して止まる） |

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

`skills/flow/scripts/guard.sh` を PreToolUse hook として **`~/.claude/settings.json` に登録**すると、flow のブランチでの push・PR 作成に**必ず確認画面が出る**ようになる。Claude が承認を待たずに進んでも、ユーザーが画面で許可しない限り外には出ない。settings.json に登録するので、`/flow` を起動していないセッションや `--resume` で再開したセッションでも効く。flow のブランチ（`docs/flow/*/main.md` の `Branch` と一致するブランチ）でだけ判定し、それ以外のコマンド・ブランチは素通しする。

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

| 判定 | 対象 |
|------|------|
| **deny**（ブロック。理由は Claude に届く） | force push（`-f`・`--force-with-lease`・`+refspec` を含む）。必要ならユーザーが `! git push --force-with-lease` で自分で実行する |
| **deny** | チケットに issue があるのに、本文（`--body` / `--body-file`）に `Closes #<番号>` の無い `gh pr create` |
| **ask**（確認画面。理由はユーザーにだけ表示） | それ以外のすべての push・PR 作成。フェーズを問わない（PR ゲート前なら ⚠ 付きで表示し、途中のバックアップ push もユーザーが許可すればできる） |

- `permissionDecision: "ask"` は、`permissions.allow` に `git push` を入れていても、auto モードでも確認画面を出す。確認画面には Status・ブランチ・Base・（PR なら）`Closes #<番号>` が出る。
- 検知はあえて広めにしている：正確なパターンに加えて、クォートを外したうえで `git` と `push`、`gh` と `pr create`、`gh api` と `pulls` の組み合わせを拾う（`bash -c "git push"`・`eval`・`env git push` など）。誤検知しても確認画面が出るだけ。
- `jq` が無くても flow と無関係なリポジトリ・ブランチには影響しない。flow のブランチでは、詳しく判定できないので確認画面を出す。
- 止めるのは Claude のツール呼び出しだけで、ユーザーが自分で実行する git / gh は止めない。
- **事故防止の仕組みであって、完全な防御ではない。** Claude が実行できるコマンドは、どんな検知もすり抜ける書き方ができる（スクリプトファイル経由など）。確認画面で拒否されたら言い換えて再実行しないよう、SKILL.md で指示している。
- 登録しない場合、ゲートは SKILL.md の指示だけで守られる。

### テスト

guard の判定は `tests/guard.test.sh` で確かめる（一時ディレクトリにリポジトリと状態ファイルを作り、hook と同じ JSON を流して pass / ask / deny を見る）。GitHub Actions では Linux で実行する。macOS の bash 3.2 でも動くことは手元で確かめる。

```sh
bash tests/guard.test.sh
/bin/bash tests/guard.test.sh   # macOS: bash 3.2
```

## 注意

- `allowed-tools`（Read / Glob / Grep）の事前承認は、スキルを起動したターンにだけ有効。次のメッセージ以降は通常の許可プロンプトが出る。常時許可したい場合は `.claude/settings.json` の `permissions.allow` に追加する。
- Plan 以降は git リポジトリが、PR（`host: github`）にはリモートと `gh` CLI が必要。GitHub 連携を使う場合は new から `gh` の認証が必要（未認証なら `! gh auth login` を案内して止まる）。
- `scripts/pr-status.sh` は Bash で実行するので、初回は許可プロンプトが出る。

## v2 予定

- GitHub issue 以外のチケット／知識ソース（Jira / GitHub Projects / Confluence）
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/<subticket>.md`）

## License

[MIT](LICENSE)

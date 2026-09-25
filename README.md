# flow-command

チケット単位でアプリ開発を回す Claude Code スキル `/flow`。

プロジェクト初期化（init）・チケット作成（new）・編集（edit）・開発（dev）・やり直し（reset）・キャンセル（cancel）のモードを持つ。dev では 1 つのチケットを 6 フェーズで進め、進捗を 1 ファイルに集約することで「途中で止めて後から再開」できるようにする。

```
Research → Approach → Plan → Implement → Review → PR
```

## 導入

スキル本体は `skills/flow/SKILL.md`（共通規約とモードの振り分け）と `skills/flow/modes/*.md`（各モードの手順。起動したモードの分だけ読む）、`skills/flow/references/`（GitHub 連携・フェーズの戻し方。必要なときだけ読む）、`skills/flow/scripts/`（id・状態ファイル・検証・issue 同期・hook など、結果が 1 つに決まる処理）、`skills/flow/templates/`（init が対象プロジェクトに入れる PR テンプレートと GitHub Actions）。個人スキル（全プロジェクト共通）として使うため、`~/.claude/skills/flow` にシンボリックリンクを張る。

```sh
ln -sfn "$(pwd)/skills/flow" ~/.claude/skills/flow
```

`-n` を付けないと、既にリンクがある状態で再実行したときにリンク先ディレクトリの中へ `flow` という循環リンクが作られ、スキルの読み込みが壊れるので注意。

リンクなので、このリポジトリで `SKILL.md` を編集すればそのまま全プロジェクトに反映される。

dev の Review で使う 2 つの reviewer agent（`agents/flow-reviewer.md`：合意とのズレ、`agents/flow-quality-reviewer.md`：品質）も同じようにリンクする。agent はスキルのディレクトリに同梱できないため、別に導入が必要。

```sh
mkdir -p ~/.claude/agents
ln -sfn "$(pwd)/agents/flow-reviewer.md" ~/.claude/agents/flow-reviewer.md
ln -sfn "$(pwd)/agents/flow-quality-reviewer.md" ~/.claude/agents/flow-quality-reviewer.md
```

未導入のまま Review に入ると、flow は停止して導入を案内する（別の agent で代用はしない）。

特定のプロジェクトだけで使いたい場合は、そのプロジェクトの `.claude/skills/flow/` に `skills/flow/` の中身（`SKILL.md`・`modes/`・`references/`・`scripts/`）をコピーし、reviewer agent は `.claude/agents/` にコピーする。

hook（`guard.sh`・`session-start.sh`）は `/flow init` が登録を案内する（下記「hook による強制」）。

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
- `/flow new` は commit しない。ローカル運用では、チケットは実装 PR の最初の commit として `/flow dev` の Implement で commit される（まとめて複数作っても、各チケットは自分の PR に入る）。GitHub 連携ではチケットは issue にあり、手元のファイルは commit しない。
- `/flow` を起動すると、設定と進行中の run の一覧が自動で読み込まれる（SKILL.md の `` !`…` ``）。

## 規約パス

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**` |
| チケット | `docs/tickets/<ticket-id>.md`（ローカル運用は git 管理。GitHub 連携時は issue が正本で、手元は issue から作る git 管理外のコピー） |
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
ticket:
  tracker: github       # github | local
  prefix: T
  pad: 6
repository:
  host: github          # github | none（ローカルのみ）
  default_branch: main
review:
  required: true        # PR の Approve を必須にするか（1 人なら false）
gates: [approach, plan, pr]   # 必ず止まるゲート（pr は常に止まる）
```

スクリプトは awk でこの形（2 段までの入れ子・1 行 1 キー・`#` コメント）だけを読む。値に ` #` を含めるときは `"…"` で囲む。

`repository` は `/flow init` がリポジトリの状態から決める。GitHub リポジトリが無ければ、AI と対話して作る（オーナー・名前・公開範囲・説明・デフォルトブランチ、public なら LICENSE を 1 つずつ尋ねる）／自分で作る／不要（`host: none`）から選ぶ。config にはオーナー・名前・公開範囲は書かない（remote と GitHub から分かり、書くと食い違うため）。

`docs/flow/` は `.gitignore` に入れて git 管理しない（`/flow init` が追加する）。flow 状態は個人の作業記録であり、PR に含めるとレビュアーが検討過程に引っ張られてしまうため。

## GitHub issue 連携（任意）

`/flow init` でチケット管理に GitHub を選ぶと（`ticket.tracker: github`）、チケットが issue と連携する。チームで使うときに、誰がどのチケットをどこまで進めているかを見えるようにし、id の衝突を防ぐため。

- **正本は issue**：手元の `docs/tickets/` は issue から作る作業用のコピーで、git で管理しない（`.gitignore`）。dev・edit・cancel は始めるたびに issue から作り直し、違えば issue を採用する。チケットは PR に入らず、`Closes #123` で結ぶ。
- **変更は `/flow edit` だけ**：edit は issue から取ってきたコピーを書き換えて、すぐ issue に書き戻す。issue の本文とタイトルは GitHub 上で直接編集しない（本文の冒頭で告知する）。コメントは自由。
- **直接編集の検知**：flow は本文にハッシュ（`<!-- flow:hash:… -->`）を書く。GitHub 上で直接編集されるとハッシュが合わなくなり、dev・edit が差分を示して取り込むか尋ねる。Actions の `flow-issue-guard` を入れていれば、編集した時点で `flow:out-of-sync` ラベルが付く。
- **issue に載せるもの**：チケットの全セクション（そのままコピー）とハッシュ、ステータスのラベル、担当者。cancel・reset のときは、方針とやめた理由をコメントに残す。flow 状態は載せない。
- **id**：new で issue を作り、その番号から id を決める（#123 → `T000123`）。チケットには `Issue: #123` を書く。

| 時点 | issue |
|------|-------|
| `/flow new` | 作成、`flow:todo` |
| `/flow dev` の開始 | `flow:in-progress`、assignee に自分（他の人が assign 済みなら止まって確認） |
| PR 作成 | `flow:in-review`。PR 本文に `Closes #123` を必ず入れ、紐付けを確認する |
| マージ | 閉じる（`Closes` で閉じない Base 向けの PR でも、Actions か flow が閉じる） |
| GitHub 上で直接編集 | `flow:out-of-sync`（Actions）。次の dev・edit で取り込むと外れる |

`/flow init` で、サーバー側の GitHub Actions（`skills/flow/templates/github/`）を入れるか選べる：

| workflow | 内容 |
|----------|------|
| `flow-issue-sync` | PR が開いたら issue を `flow:in-review` に、マージされたら閉じる |
| `flow-pr-link` | `<id>-` ブランチの PR に `Closes #<番号>` があるかを検査する（必須チェックにすれば、ローカルの guard を迂回されても防げる） |
| `flow-issue-guard` | `issues: edited`（GitHub 上でタイトル・本文が編集された）で本文のハッシュを確かめ、合わなければ `flow:out-of-sync` を付ける |
| `flow-ci` | 検証コマンドを CI でも実行する（init がプロジェクトに合わせて埋める） |

## フェーズ

| # | フェーズ | 内容 |
|---|----------|------|
| 1 | Research | チケットと `docs/context/**` を読み、コードの調査は Explore agent に任せて、要求・制約・疑問点を整理する |
| 2 | Approach | 実装方針（選択肢・採用案・トレードオフ）を決めて合意する（確認は 1 回） |
| 3 | Plan | ブランチ名・**受け入れ条件 → 確かめ方の対応表**（テスト名／手動確認）・順序付きの commit 分割を決める（v1 は単一ブランチ） |
| 4 | Implement | 計画どおりに実装・commit する（commit ごとには止まらない）。テストは対応表に沿って書く。最後に `verify.sh` で検証コマンドを全て実行して通るまで直し、手動確認の項目を確かめる（Claude が確認できる手段があれば任せられる） |
| 5 | Review | 2 つの reviewer agent を並列に起動する。`flow-reviewer` は実装の経緯を知らない状態で、実装と Approach / Plan（対応表）/ チケットの乖離（相違・未実装・合意外の変更）を、`flow-quality-reviewer` はバグ・セキュリティ・性能などの品質を調べる。どちらも Bash を持たず、`review-input.sh` が書き出した差分ファイルを読む。実装したセッションは指摘を消さずに推奨と根拠を添えるだけで、項目ごとに修正（→ Implement）／方針見直し（→ Approach）／受け入れをユーザーが選ぶ |
| 6 | PR | 明示的な確認の後にだけ push して PR を作成し、完了まで見届ける（flow はマージしない）。本文は PR テンプレートがあれば沿って書き、方針は結論と理由だけを書く。context と矛盾する変更なら、修正を同じ PR に入れるか尋ねる。`host: none` なら PR は出さず、確認の後に `default_branch` へ `git merge --no-ff` してブランチを削除する（コンフリクトしたら `--abort` して止まる） |

### 承認ゲート

- `gates`（既定は `[approach, plan, pr]`）に書いたフェーズでは必ず停止し、要約を出して承認を待つ。この停止点が再開点になる。
- 書いていないフェーズは、止まる条件が無ければ自動で通過する（Research：未解決の疑問、Approach：ユーザーの判断が要る、Plan：確かめ方が決まらない、Implement：手動確認が残っている、Review：指摘がある）。
- PR の前は、`gates` や前段の自動通過に関係なく必ず停止する（強ゲート）。
- PR 作成後は `pr:awaiting-review` で止まる。`/flow dev <ticket-id>` で再開すると `skills/flow/scripts/pr-status.sh` で状況を確認し、Approve 済み・CI 成功・コンフリクトなしなら `done`（`review.required: false` なら Approve 無しでも CI 成功・コンフリクトなしで `done`。マージは自分で行う）。CI 失敗・コンフリクト・修正依頼があれば `pr:in-progress` に戻って対応する（push 前に確認あり）。

## 状態ファイル

`docs/flow/<ticket-id>/main.md` が run の単一の真実。`scripts/state.sh` が作り、ヘッダ表（`Status`・`Branch`・`Base`・`Updated` など）も `state.sh` だけが書き換える（`Status` の値を検査し、`Updated` を自動で更新する）。各フェーズは自分のセクション（本文はドキュメント言語）を書く。

`Status` のフォーマットは `<phase>:<state>`、または終端の値：

- `<phase>`：`research | approach | plan | implement | review | pr`
- `<state>`：`in-progress`（作業中）／`awaiting-approval`（ゲートで承認待ち）／`awaiting-review`（`pr` のみ。PR のレビュー待ち）
- 終端：`done`（完了）／`canceled`（`/flow cancel` でキャンセル済み）

## hook による強制

`/flow init` の案内で、次の 2 つを **`~/.claude/settings.json` に登録**する。settings.json に登録するので、`/flow` を起動していないセッションや `--resume` で再開したセッションでも効く。flow の run が関わる場所でだけ判定し、それ以外のコマンド・ブランチは素通しする。

| hook | 登録先 | 内容 |
|------|--------|------|
| `scripts/guard.sh` | PreToolUse（matcher `Bash\|Edit\|Write\|MultiEdit\|NotebookEdit\|mcp__.*`） | push・PR 作成・許可リスト外の git / gh 操作に**必ず確認画面を出す**。force push と `Closes` の無い PR をブロックする。Plan の承認前に `docs/` 以外を編集しようとしたら確認画面を出す |
| `scripts/session-start.sh` | SessionStart（matcher `compact\|resume`） | 会話の要約・再開の後、進行中の run と、読み直す手順ファイル（`modes/dev.md`）を Claude に伝える |

登録は、「自分で追記する」（Claude は settings.json を読まない）か「AI に任せる」（差分を見せて確認を取ってから、バックアップを取って追記する）かを選べる。手で追記する場合の JSON は `skills/flow/modes/init.md` の「hook の登録」にある。反映は次に起動するセッションから。以前の版で `"matcher": "Bash"` として登録している場合は、matcher を上記に変える。

`guard.sh` の判定：

| 場所 | 判定 | 対象 |
|------|------|------|
| run のブランチ・進行中の run の Base | **deny**（ブロック。理由は Claude に届く） | force push（`-f`・`--force-with-lease`・`+refspec` を含む）。必要ならユーザーが `! git push --force-with-lease` で自分で実行する |
| run のブランチ | **deny** | チケットに issue があるのに、本文（`--body` / `--body-file`）に `Closes #<番号>` の無い `gh pr create` |
| run のブランチ | **ask**（確認画面。理由はユーザーにだけ表示） | それ以外のすべての push・PR 作成。フェーズを問わない（PR ゲート前なら ⚠ 付きで表示し、途中のバックアップ push もユーザーが許可すればできる） |
| run のブランチ・進行中の run の Base | **ask** | 許可リストに無い git / gh 操作（merge・rebase・reset・cherry-pick・clean・`commit --amend`・`branch -D`・`gh pr merge`・`gh issue close`・書き込みの `gh api` など）と、GitHub / git の MCP ツールの読み取り以外（`get_`・`list_`・`search_` などで始まらないもの） |
| 進行中の run の Base | **ask** | Base への commit・push（flow の作業はチケットのブランチで行う） |
| どこでも（`docs/flow/.active` の run が research・approach・plan のとき） | **ask** | リポジトリ内の `docs/` 以外のファイルへの Edit / Write（Plan の承認前に実装を始めない） |

- 許可リスト（確認画面を出さない git / gh）：`status`・`diff`・`log`・`show`・`fetch`・`switch`・`add`・`rm`・`mv`・`commit`（Base と `--amend` 以外）・`checkout -b`・`branch`（一覧・作成）・`stash`（`drop`・`clear` 以外）・`grep`・`blame` など読み取り系、`gh pr view|list|checks|diff|status`・`gh issue view|list`・`gh run view|list|watch`・読み取りの `gh api` など。flow のスクリプト（`issue-sync.sh` など）が内部で実行する gh は判定しない（手順の中で確認を取るため）。
- `permissionDecision: "ask"` は、`permissions.allow` に `git push` を入れていても、auto モードでも確認画面を出す。確認画面には Status・ブランチ・Base・（PR なら）`Closes #<番号>` が出る。
- 検知はあえて広めにしている：正確なパターンに加えて、クォートを外したうえで `git` と `push`、`gh` と `pr create`、`gh api` と `pulls` の組み合わせを拾う（`bash -c "git push"`・`eval`・`env git push` など）。誤検知しても確認画面が出るだけ。
- `jq` が無くても flow と無関係なリポジトリ・ブランチには影響しない。flow のブランチでは、詳しく判定できないので push らしいコマンドに確認画面を出す（許可リスト・MCP・編集の判定は jq が無いと行わない）。
- 止めるのは Claude のツール呼び出しだけで、ユーザーが自分で実行する git / gh は止めない。
- **事故防止の仕組みであって、完全な防御ではない。** Claude が実行できるコマンドは、どんな検知もすり抜ける書き方ができる（スクリプトファイル経由など）。また、flow のブランチかどうかはセッションの作業ディレクトリで判定するので、`cd 別のリポジトリ && git push` や `git -C 別のパス push` は、その別のリポジトリとしては判定しない。確認画面で拒否されたら言い換えて再実行しないよう、SKILL.md で指示している。サーバー側で確実に守りたいことは、Actions（`flow-pr-link`）とブランチ保護で守る。
- 登録しない場合、ゲートは SKILL.md の指示だけで守られる。

### テスト

`tests/guard.test.sh`（一時ディレクトリにリポジトリと状態ファイルを作り、hook と同じ JSON を流して pass / ask / deny を見る）と `tests/scripts.test.sh`（`ticket-id.sh`・`state.sh`・`verify.sh`・`issue-sync.sh`・`issue-label.sh`・`pr-status.sh` など。gh はスタブに置き換える）で確かめる。`scripts.test.sh` には jq が必要。GitHub Actions では Linux で実行する。macOS の bash 3.2 でも動くことは手元で確かめる。

```sh
bash tests/guard.test.sh && bash tests/scripts.test.sh
/bin/bash tests/guard.test.sh && /bin/bash tests/scripts.test.sh   # macOS: bash 3.2
```

## 注意

- `allowed-tools`（Read / Glob / Grep と、`status.sh`・`ticket-id.sh`・`state.sh` の実行）の事前承認は、スキルを起動したターンにだけ有効。次のメッセージ以降は通常の許可プロンプトが出る。常時許可したい場合は `.claude/settings.json` の `permissions.allow` に追加する。
- 起動時の `` !`bash …/status.sh` `` は、許可ルールで拒否されるとスキルの起動自体が失敗する。`deny` に `Bash(bash:*)` のような広いルールを入れている場合は注意。
- Plan 以降は git リポジトリが、PR（`host: github`）にはリモートと `gh` CLI が必要。GitHub 連携を使う場合は new から `gh` の認証が必要（未認証なら `! gh auth login` を案内して止まる）。
- `scripts/` のスクリプトは Bash で実行するので、初回は許可プロンプトが出る。

## v2 予定

- GitHub issue 以外のチケット／知識ソース（Jira / GitHub Projects / Confluence）
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/<subticket>.md`）
- バックログ（チケットの分解・依存関係・優先度・次の 1 枚の提示）
- plugin 化（skills・agents・hooks をまとめて配布し、symlink と settings.json への登録を不要にする）

## License

[MIT](LICENSE)

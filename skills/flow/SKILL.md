---
name: flow
description: チケット単位で開発を回すフレームワーク。/flow で明示起動する。モードは init（docs 雛形・検証コマンド・commit 規約・チケット管理（ローカル or GitHub issue）・レビュー要否・hook・Actions を設定し、context を対話で作るか雛形だけ用意する）、new（チケットを対話で作る。GitHub 連携時は issue を作り、issue 番号から id を決める）、edit（チケットを編集し、進行中の run はフェーズを戻す）、dev（1 チケットを 6 フェーズ Research → Approach → Plan → Implement → Review → PR で進める）、reset（run を捨てて最初からやり直す）、cancel（チケットをキャンセル済みにする）。dev の進捗は docs/flow/<ticket-id>/main.md に集約するので、途中で止めても同じフェーズから再開できる。
argument-hint: "[init | new [作りたいもの] | edit <ticket-id> | dev <ticket-id> | reset <ticket-id> | cancel <ticket-id>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash ${CLAUDE_SKILL_DIR}/scripts/status.sh), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/ticket-id.sh *), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/state.sh *)
---

# /flow — チケット駆動開発

引数：`$ARGUMENTS`

## 現在の状態（起動時に自動で取得）

!`bash ${CLAUDE_SKILL_DIR}/scripts/status.sh`

## 置き場所

- スキルのディレクトリ：`${CLAUDE_SKILL_DIR}`（各モードのファイルでは `<skill>` と書く）
- スクリプト：`${CLAUDE_SKILL_DIR}/scripts/`（各モードのファイルでは `<scripts>` と書く。実行は `bash <scripts>/<名前>.sh …`）

## モード

| 起動 | モード | 単位 | 内容 |
|------|--------|------|------|
| `/flow init` | init | プロジェクト（最初に 1 回） | docs の雛形作成と `docs/context/` の作成（対話 or 自分で書く） |
| `/flow new [作りたいもの]` | new | チケット（作るたび） | チケットを対話で作る。id は自動で決まる（共通規約） |
| `/flow edit <ticket-id>` | edit | チケット | 既存のチケットを対話で書き換える。進行中の run があれば、影響に応じてフェーズを戻す |
| `/flow dev <ticket-id>` | dev | チケット（run ごと） | 6 フェーズで実装から PR まで進める |
| `/flow reset <ticket-id>` | reset | run | run（`main.md`）を捨てて、次の dev で Research からやり直す |
| `/flow cancel <ticket-id>` | cancel | チケット | チケットを `canceled` として残し、以後どのモードからも操作しない |
| `/flow <それ以外>` | — | — | 実行しない。`/flow dev <ticket-id>` のことか確認する（下記） |
| `/flow` | — | — | モードを選ばせる（下記） |

**引数の解釈：** 先頭の語が `init` / `new` / `edit` / `dev` / `reset` / `cancel` ならそのモード。残りは、edit・dev・reset・cancel ではチケット id、new では作りたいものの説明（省略可）として扱う。
先頭の語がモード名でない場合（例：`/flow 123`）は**何も実行しない**。「`/flow dev <引数>` のことですか？」とだけ尋ねて止まる（AskUserQuestion を使い、選択肢は「はい、dev で進める」と「いいえ」）。はいなら dev モードとして続け、いいえなら `/flow` の選択肢（下記）を提示する。ファイルの読み込みや作成は、確認が取れるまで行わない。

### 引数が無い場合（`/flow`）

上の「現在の状態」にある進行中の run（`done`・`canceled` 以外）を使う。次の選択肢をユーザーに提示し（AskUserQuestion を使う）、選ばれたモードで続ける。推測で決めない。

1. **進行中の flow を再開** — 進行中の run のチケット id と Status を説明に含める。**進行中の run が無ければこの選択肢は出さない**（残りの 3 つだけを提示する）。
2. **dev：チケットを進める** — チケット id を尋ねる（`docs/tickets/*.md`、GitHub 連携なら `flow:todo` の issue を候補として示す）。
3. **new：チケットを作る** — id は自動で決まるので尋ねない。
4. **init：プロジェクトを初期化** — `docs/` が既にあれば、その旨を説明に含める。

選択肢は 4 つまでなので、edit・reset・cancel は選択肢に入れない。質問文に「チケットの編集・run のやり直し・キャンセルは `/flow edit|reset|cancel <ticket-id>`」と添える（「その他」で入力されたらそのモードで続ける）。

### 手順ファイルの読み込み（必須）

各モードの手順は別ファイルに書いてある。モードが決まったら、**そのモードの作業を始める前に必ず該当ファイルを Read する**。読まずに記憶や推測で進めない。**他のモードのファイルは読まない。** `references/` のファイルは、モードの手順が読むよう指示したときだけ読む。

| モード | ファイル |
|--------|----------|
| init | `${CLAUDE_SKILL_DIR}/modes/init.md` |
| new | `${CLAUDE_SKILL_DIR}/modes/new.md` |
| edit | `${CLAUDE_SKILL_DIR}/modes/edit.md` |
| dev | `${CLAUDE_SKILL_DIR}/modes/dev.md` |
| reset | `${CLAUDE_SKILL_DIR}/modes/reset.md` |
| cancel | `${CLAUDE_SKILL_DIR}/modes/cancel.md` |

| 参照ファイル | 読むとき |
|--------------|----------|
| `${CLAUDE_SKILL_DIR}/references/github.md` | `ticket.tracker` が `github` のとき、どのモードでも（`local` なら読まない） |
| `${CLAUDE_SKILL_DIR}/references/rollback.md` | チケットが変わり、進行中の run のフェーズを戻すか決めるとき（edit と dev が指示する） |

**会話が要約された後**（要約から再開したとき）は、続ける前に、今のモードの手順ファイルと（dev なら）`docs/flow/<ticket-id>/main.md` を Read し直す。要約には手順の細部が残らないため。SessionStart hook（plugin に同梱）が、そのことを自動で伝える。

以下の共通規約・行動原則・ガードレールは全モードに適用する。

## 共通規約

チケット id を全ての基点にする：チケットファイル名・状態フォルダ名・ブランチ接頭辞。

**チケット id の形式：** `<prefix><番号>`。番号は `pad` 桁になるよう 0 埋めする（既定は `T` と 6 桁：`T000123`）。0 埋めは、ファイル一覧やブランチ一覧で `T2` より `T11` が先に並ばないようにするため。番号が `pad` 桁を超えたら 0 埋めせずにそのまま使う。

**id は必ず `<scripts>/ticket-id.sh` で扱う**（手で 0 埋め・変換しない。シェルの算術に 0 埋めの数字を渡すと 8 進数になる）：

| 用途 | コマンド |
|------|----------|
| 指定された id の正規化（`T000123`・`123`・`#123` のどれでも） | `ticket-id.sh normalize <引数>`（終了コード 1：その id のチケットが無い旧形式、2：使えない文字を含む → 書き換えずに止まって尋ねる） |
| id → issue 番号 | `ticket-id.sh number <id>` |
| 次の id（`local` のとき） | `ticket-id.sh next` |

- 番号の決め方は `ticket.tracker` で変わる：
  - `github` — **issue 番号をそのまま使う**（new で issue を作成して得る）。サーバーが払い出すので、複数人で作っても衝突しない。
  - `local` — `ticket-id.sh next`。作業ツリーだけでなく、全てのブランチ（リモート追跡ブランチも `git fetch` してから）の `docs/tickets/`、`docs/flow/<id>/`、`<id>-` で始まるブランチ名の中の最大の番号 + 1。チケットがまだ実装ブランチにしか無い間でも番号が重複しない。
- `docs/flow.config.yml` に `ticket` が無い（古い init で作った設定）場合は `tracker: local`・`prefix: T`・`pad: 6` として扱い、`/flow init` の再実行で設定できることを伝える。

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**`（必要な分だけ読む） |
| チケット | `docs/tickets/<ticket-id>.md` — `local`：git で管理し、実装 PR の最初の commit に入る。`github`：**git で管理しない**。issue が正本で、手元は issue から作る作業用のコピー（`references/github.md`） |
| flow 設定 | `docs/flow.config.yml`（git 管理する。チーム共通） |
| flow 状態 | `docs/flow/<ticket-id>/main.md`（**git 管理外**。`<scripts>/state.sh` で作り、ヘッダを更新する） |
| ブランチ名 | `<ticket-id>-<slug>`（チケット id を接頭辞にする） |

- **`docs/flow/` は git で管理しない**（`.gitignore` に入れる）。flow 状態は各個人の作業記録であり、共有物ではない。また PR に含めるとレビュアーが検討過程に引っ張られ、実装そのものを見たレビューにならないため。`main.md` を commit・PR に含めない。PR 本文に書くのは、合意した方針の**結論と理由**（2〜3 行）だけにする。
- **ドキュメント言語**：チケット・`docs/context/**`・flow 状態（`main.md`）の本文、および PR のタイトル・本文は `docs/flow.config.yml` の `language` で書く。既定は日本語（`ja`）。設定ファイルが無ければ日本語とする。チケットと context は見出しもこの言語にする（`main.md` の見出しは英語の固定キー）。
  ```yaml
  # /flow settings (shared, committed)
  language: ja   # ja | en | その他の言語名
  commands:      # dev の検証で書いた順に実行する（init で決める。無ければ {}）
    test: npm test
    lint: npm run lint
  ticket:
    tracker: github   # github（issue と連携）| local（ローカルのみ）
    prefix: T
    pad: 6
  repository:
    host: github          # github（PR を出す）| none（ローカルのみ。PR フェーズはローカルでマージ）
    default_branch: main  # Plan の Base の既定値。host: none ではマージ先
  review:
    required: true        # PR の Approve を必須にするか。1 人で開発するなら false
  gates: [approach, plan, pr]  # 必ず止まるゲート。pr は書かなくても必ず止まる（dev.md「承認ゲート」）
  ```
  スクリプトはこの形（2 段までの入れ子・1 行 1 キー・`#` コメント）だけを読む。値に ` #` を含めるときは `"…"` で囲む。
- `repository` が無い（古い init で作った設定）場合は、`origin` が GitHub を指していれば `host: github`、そうでなければ `host: none` として扱い、`default_branch` は `git symbolic-ref --short refs/remotes/origin/HEAD` から取る（取れなければ Plan で尋ねる）。`review` が無ければ `required: true`、`gates` が無ければ `[approach, plan, pr]` として扱う。いずれも `/flow init` の再実行で設定できることを伝える。
- `ticket.tracker: github` は `repository.host: github` のときだけ使える。
- 上記パスは固定規約。`init` はこの規約どおりの雛形を作るだけで、パスの選択はしない。
- 状態はあえて**フォルダ形式**（`docs/flow/<ticket-id>/main.md`）にしている。v2 の複数ブランチ対応で兄弟ファイル `docs/flow/<ticket-id>/<subticket>.md` を足すため。v1 では兄弟ファイルを作らない。
- どのモードでも、既存ファイルを黙って上書きしない（`github` のときの作業用コピー `docs/tickets/<id>.md` は、issue から作り直すものなので例外。作り直すときは差分を示す）。
- **キャンセル済みのチケット**（チケットに `Status: canceled`、または `main.md` の `Status` が `canceled`）は、どのモードでも操作しない。その旨を伝えて止まる。

### スクリプト（`<scripts>/`）

結果が 1 つに決まる処理と、一字も変えずに写すべき処理はスクリプトに任せ、手で同じことをしない。出力は要約せずにそのまま使う。

| スクリプト | 用途 |
|------------|------|
| `ticket-id.sh` | id の正規化・issue 番号への変換・次の番号（上記） |
| `state.sh` | 状態ファイルの作成（`init`）、ヘッダの読み書き（`get` / `set`。`Status` の値を検査し、`Updated` も更新する） |
| `verify.sh` | 検証コマンドの実行と `Verification @ <hash>: …` の行の出力 |
| `review-input.sh` | Review の agent に渡す差分・commit 一覧をファイルに書き出す |
| `pr-status.sh` | PR の状況（レビュー・CI・コンフリクト）の判定 |
| `issue-sync.sh` / `issue-label.sh` | GitHub issue との同期・ラベルと担当者（`references/github.md`） |
| `status.sh` | 設定と進行中の run の一覧（起動時に上の「現在の状態」へ自動で入る） |

## 行動原則（全体を通して）

- 情報が不足・曖昧なときは**質問する**。チケットの内容・要件・存在しないファイルを勝手に作らない。
- 仮定を置いて進めるときは**その仮定を明示**し、ユーザーが直せるようにする（該当セクションにも記録する）。
- 不要な手順や成果物だと感じたら、黙ってやらず（黙って省きもせず）**指摘する**。
- 懸念や反対は**理由付きで率直に**言う。ユーザーが提案したというだけで同意しない。
- ユーザーには相手の言語で話す。チケット・context はドキュメント言語（共通規約）で書く。`main.md` のセクション本文もドキュメント言語で書く。

## ガードレール

- dev の 1 run につき 1 チケット。作業が別チケットの範囲に広がりそうなら指摘する。
- 明示的な確認なしに push / PR 作成 / マージをしない（dev の PR フェーズ）。flow は PR をマージしない（`host: none` のローカルマージだけは、確認の後に行う）。
- **hook による強制**（flow plugin の `hooks/hooks.json` に同梱。plugin を有効にしていれば、`/flow` の起動や `--resume` に関係なく全セッションで効く）：
  - `scripts/guard.sh`（PreToolUse）— flow の run が関わる場所でだけ判定する。run のブランチと、進行中の run の Base では、push・PR 作成・許可リストに無い git / gh 操作（merge・rebase・reset・`gh pr merge`・`gh api` の書き込みなど）・GitHub / git の MCP の書き込みのたびに確認画面を出し、force push と `Closes #<番号>` の無い PR 作成をブロックする。Base への commit も確認画面を出す。Plan の承認前（`research`・`approach`・`plan`）に `docs/` 以外のファイルを Edit / Write しようとしたときも確認画面を出す。
  - `scripts/session-start.sh`（SessionStart、`compact|resume`）— 会話の要約・再開の後、進行中の run と読み直すファイルを伝える。
  - 同じ hook をユーザー設定（`~/.claude/settings.json`）にも登録していると 2 回動く。`/flow init` の「古い導入の片付け」で外す。
  - **ブロックされたら、また確認画面で拒否されたら、コマンドを言い換えるなどして回避・再実行しない。** 理由（拒否なら拒否されたこと）をユーザーに伝えて指示を待つ。
  - 確認画面はチャットでの承認の代わりではない。PR フェーズのゲートでは、これまでどおりチャットで確認を得てから push / PR 作成を実行する（確認画面はその後にもう一度出る）。
- 外部システムの操作は、`ticket.tracker: github` のときの GitHub issue に対する、`references/github.md` に定めた操作だけにする。それ以外の外部システム（Jira など）にチケットを作らない。

## v1 の対象外（v2 送り）

- GitHub issue 以外のチケット／知識ソース（Jira / GitHub Projects / Confluence）。
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/` 配下の兄弟ファイル）。
- バックログ（チケットの分解・依存関係・優先度・次の 1 枚の提示）。

ユーザーがこれらを求めたら、v2 の機能であることを伝え、v1 の範囲でできることを行う。

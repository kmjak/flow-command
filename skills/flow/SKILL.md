---
name: flow
description: チケット単位で開発を回すフレームワーク。/flow で明示起動する。モードは init（docs 雛形・検証コマンド・commit 規約・チケット管理（ローカル or GitHub issue）を設定し、context を対話で作るか雛形だけ用意する）、new（チケットを対話で作る。GitHub 連携時は issue も作り、issue 番号から id を決める）、dev（1 チケットを 6 フェーズ Research → Approach → Plan → Implement → Review → PR で進める）。dev の進捗は docs/flow/<ticket-id>/main.md に集約するので、途中で止めても同じフェーズから再開できる。
argument-hint: "[init | new [作りたいもの] | dev <ticket-id>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep
---

# /flow — チケット駆動開発

引数：`$ARGUMENTS`

## モード

| 起動 | モード | 単位 | 内容 |
|------|--------|------|------|
| `/flow init` | init | プロジェクト（最初に 1 回） | docs の雛形作成と `docs/context/` の作成（対話 or 自分で書く） |
| `/flow new [作りたいもの]` | new | チケット（作るたび） | `docs/tickets/<ticket-id>.md` を対話で作る。id は自動で決まる（共通規約） |
| `/flow dev <ticket-id>` | dev | チケット（run ごと） | 6 フェーズで実装から PR まで進める |
| `/flow <それ以外>` | — | — | 実行しない。`/flow dev <ticket-id>` のことか確認する（下記） |
| `/flow` | — | — | モードを選ばせる（下記） |

**引数の解釈：** 先頭の語が `init` / `new` / `dev` ならそのモード。残りは、dev ではチケット id、new では作りたいものの説明（省略可）として扱う。
先頭の語がモード名でない場合（例：`/flow 123`）は**何も実行しない**。「`/flow dev <引数>` のことですか？」とだけ尋ねて止まる（AskUserQuestion を使い、選択肢は「はい、dev で進める」と「いいえ」）。はいなら dev モードとして続け、いいえなら `/flow` の選択肢（下記）を提示する。ファイルの読み込みや作成は、確認が取れるまで行わない。

### 引数が無い場合（`/flow`）

まず `docs/flow/*/main.md` を Glob して各 `Status` を読み、`done` 以外を進行中の run とする。
そのうえで、次の選択肢をユーザーに提示し（AskUserQuestion を使う）、選ばれたモードで続ける。推測で決めない。

1. **進行中の flow を再開** — 進行中の run のチケット id と Status を説明に含める。**進行中の run が無ければこの選択肢は出さない**（残りの 3 つだけを提示する）。
2. **dev：チケットを進める** — チケット id を尋ねる（`docs/tickets/*.md` を候補として示す）。
3. **new：チケットを作る** — id は自動で決まるので尋ねない。
4. **init：プロジェクトを初期化** — `docs/` が既にあれば、その旨を説明に含める。

### モードファイルの読み込み（必須）

各モードの手順は、このスキルのディレクトリにある別ファイルに書いてある。モードが決まったら、**そのモードの作業を始める前に必ず該当ファイルを Read する**。読まずに記憶や推測で進めない。該当モード以外のファイルは読まない。

| モード | ファイル |
|--------|----------|
| init | `modes/init.md` |
| new | `modes/new.md` |
| dev | `modes/dev.md` |

`docs/flow.config.yml` の `ticket.tracker` が `github` なら、init・new・dev のいずれでも `references/github.md` も Read する（`local` なら読まない）。

以下の共通規約・行動原則・ガードレールは全モードに適用する。

## 共通規約

チケット id を全ての基点にする：チケットファイル名・状態フォルダ名・ブランチ接頭辞。

**チケット id の形式：** `<prefix><番号>`。番号は `pad` 桁になるよう 0 埋めする（既定は `T` と 6 桁：`T000123`）。0 埋めは、ファイル一覧やブランチ一覧で `T2` より `T11` が先に並ばないようにするため。番号が `pad` 桁を超えたら 0 埋めせずにそのまま使う。

- 番号の決め方は `ticket.tracker` で変わる：
  - `github` — **issue 番号をそのまま使う**（new で issue を作成して得る）。サーバーが払い出すので、複数人で作っても衝突しない。
  - `local` — `docs/tickets/` にある `<prefix><数字>.md` の最大の番号 + 1。複数人が同時に作ると衝突しうるので、チームで使うなら `github` を勧める。
- dev では `T000123`・`123`・`#123` のどれで指定されても `<prefix><0 埋めの番号>` に正規化する。この形式に当てはまらない id でも、`docs/tickets/<id>.md` が存在すればそのまま使う（旧形式のチケット）。
- id から番号に戻すときは**文字列として**先頭の 0 を取り除く。シェルの算術式に 0 埋めの数字をそのまま渡すと 8 進数と解釈される（`$((000123))` は `83`）。
- `docs/flow.config.yml` に `ticket` が無い（古い init で作った設定）場合は `tracker: local`・`prefix: T`・`pad: 6` として扱い、`/flow init` の再実行で設定できることを伝える。

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**`（必要な分だけ読む） |
| チケット | `docs/tickets/<ticket-id>.md`（`github` のときは issue が写しになる。`references/github.md`） |
| flow 設定 | `docs/flow.config.yml`（git 管理する。チーム共通） |
| flow 状態 | `docs/flow/<ticket-id>/main.md`（**git 管理外**） |
| ブランチ名 | `<ticket-id>-<slug>`（チケット id を接頭辞にする） |

- **`docs/flow/` は git で管理しない**（`.gitignore` に入れる）。flow 状態は各個人の作業記録であり、共有物ではない。また PR に含めるとレビュアーが検討過程に引っ張られ、実装そのものを見たレビューにならないため。`main.md` を commit・PR に含めない。
- **ドキュメント言語**：チケット・`docs/context/**`・flow 状態（`main.md`）の本文、および PR のタイトル・本文は `docs/flow.config.yml` の `language` で書く。既定は日本語（`ja`）。設定ファイルが無ければ日本語とする。チケットと context は見出しもこの言語にする（`main.md` の見出しは英語の固定キー。状態ファイルの節を参照）。
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
    host: github          # github（PR を出す）| none（ローカルのみ。Phase 6 はローカルでマージ）
    default_branch: main  # Plan の Base の既定値。host: none ではマージ先
  ```
- `repository` が無い（古い init で作った設定）場合は、`origin` が GitHub を指していれば `host: github`、そうでなければ `host: none` として扱い、`default_branch` は `git symbolic-ref --short refs/remotes/origin/HEAD` から取る（取れなければ Plan で尋ねる）。`/flow init` の再実行で設定できることを伝える。
- `ticket.tracker: github` は `repository.host: github` のときだけ使える。
- 上記パスは固定規約。`init` はこの規約どおりの雛形を作るだけで、パスの選択はしない。
- 状態はあえて**フォルダ形式**（`docs/flow/<ticket-id>/main.md`）にしている。v2 の複数ブランチ対応で兄弟ファイル `docs/flow/<ticket-id>/<subticket>.md` を足すため。v1 では兄弟ファイルを作らない。
- チケット id にファイルパスや git ブランチ名に使えない文字（空白、`/`、`#`、`~`、`^`、`:` など）が含まれる場合は、勝手に書き換えず、停止してユーザーにどうするか尋ねる。
- どのモードでも、既存ファイルを黙って上書きしない。

## 行動原則（全体を通して）

- 情報が不足・曖昧なときは**質問する**。チケットの内容・要件・存在しないファイルを勝手に作らない。
- 仮定を置いて進めるときは**その仮定を明示**し、ユーザーが直せるようにする（該当セクションにも記録する）。
- 不要な手順や成果物だと感じたら、黙ってやらず（黙って省きもせず）**指摘する**。
- 懸念や反対は**理由付きで率直に**言う。ユーザーが提案したというだけで同意しない。
- ユーザーには相手の言語で話す。チケット・context はドキュメント言語（共通規約）で書く。`main.md` のセクション本文もドキュメント言語で書く。

## ガードレール

- dev の 1 run につき 1 チケット。作業が別チケットの範囲に広がりそうなら指摘する。
- 明示的な確認なしに push / PR 作成 / マージをしない（Phase 6）。
- **hook による強制**：`scripts/guard.sh` を `~/.claude/settings.json` の PreToolUse(Bash) hook として登録しておく（登録は `/flow init` で案内する）。登録すると `/flow` の起動や `--resume` に関係なく全セッションで効き、flow のブランチ（`main.md` の `Branch` と一致するブランチ）でだけ、push・PR 作成のたびにユーザーの確認画面を出し（フェーズを問わない）、force push と `Closes #<番号>` の無い PR 作成をブロックする。
  - **ブロックされたら、また確認画面で拒否されたら、コマンドを言い換えるなどして回避・再実行しない。** 理由（拒否なら拒否されたこと）をユーザーに伝えて指示を待つ。
  - 確認画面はチャットでの承認の代わりではない。Phase 6 のゲートでは、これまでどおりチャットで確認を得てから push / PR 作成を実行する（確認画面はその後にもう一度出る）。
- 外部システムの操作は、`ticket.tracker: github` のときの GitHub issue に対する、`references/github.md` に定めた操作だけにする。それ以外の外部システム（Jira など）にチケットを作らない。

## v1 の対象外（v2 送り）

- GitHub issue 以外のチケット／知識ソース（Jira / GitHub Projects / Confluence）。
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/` 配下の兄弟ファイル）。

ユーザーがこれらを求めたら、v2 の機能であることを伝え、v1 の範囲でできることを行う。

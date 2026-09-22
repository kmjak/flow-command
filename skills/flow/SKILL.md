---
name: flow
description: チケット単位で開発を回すフレームワーク。/flow で明示起動する。モードは init（プロジェクトの docs 雛形と context 下書きを作る）、new（チケットを対話で作る）、dev（1 チケットを 6 フェーズ Research → Approach → Plan → Implement → Review → PR で進める）。dev の進捗は docs/flow/<ticket-id>/main.md に集約するので、途中で止めても同じフェーズから再開できる。
argument-hint: "[init | new <ticket-id> | dev <ticket-id>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep
---

# /flow — チケット駆動開発

引数：`$ARGUMENTS`

## モード

| 起動 | モード | 単位 | 内容 |
|------|--------|------|------|
| `/flow init` | init | プロジェクト（最初に 1 回） | docs の雛形作成と `docs/context/` の下書き |
| `/flow new <ticket-id>` | new | チケット（作るたび） | `docs/tickets/<ticket-id>.md` を対話で作る |
| `/flow dev <ticket-id>` | dev | チケット（run ごと） | 6 フェーズで実装から PR まで進める |
| `/flow <それ以外>` | — | — | 実行しない。`/flow dev <ticket-id>` のことか確認する（下記） |
| `/flow` | — | — | モードを選ばせる（下記） |

**引数の解釈：** 先頭の語が `init` / `new` / `dev` ならそのモード、残りをチケット id とする。
先頭の語がモード名でない場合（例：`/flow 123`）は**何も実行しない**。「`/flow dev <引数>` のことですか？」とだけ尋ねて止まる（AskUserQuestion を使い、選択肢は「はい、dev で進める」と「いいえ」）。はいなら dev モードとして続け、いいえなら `/flow` の選択肢（下記）を提示する。ファイルの読み込みや作成は、確認が取れるまで行わない。

### 引数が無い場合（`/flow`）

まず `docs/flow/*/main.md` を Glob して各 `Status` を読み、`done` 以外を進行中の run とする。
そのうえで、次の 4 つを選択肢としてユーザーに提示し（AskUserQuestion を使う）、選ばれたモードで続ける。推測で決めない。

1. **進行中の flow を再開** — 進行中の run のチケット id と Status を説明に含める。無ければ「進行中の flow なし」と書く（選ばれたら dev と同じくチケット id を尋ねる）。
2. **dev：チケットを進める** — チケット id を尋ねる（`docs/tickets/*.md` を候補として示す）。
3. **new：チケットを作る** — チケット id を尋ねる。
4. **init：プロジェクトを初期化** — `docs/` が既にあれば、その旨を説明に含める。

## 共通規約（v1：ローカル docs のみ）

チケット id を全ての基点にする：チケットファイル名・状態フォルダ名・ブランチ接頭辞。
チケット id は不透明な文字列として扱い、**数値だと仮定しない**（v1 はローカルのファイル名 stem。将来は `PROJ-123` や issue 番号などになりうる）。

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**`（必要な分だけ読む） |
| チケット | `docs/tickets/<ticket-id>.md` |
| flow 状態 | `docs/flow/<ticket-id>/main.md` |
| ブランチ名 | `<ticket-id>-<slug>`（チケット id を接頭辞にする） |

- 上記パスは固定規約。`init` はこの規約どおりの雛形を作るだけで、パスやソースの選択はしない（ソース選択は v2 送り）。
- 状態はあえて**フォルダ形式**（`docs/flow/<ticket-id>/main.md`）にしている。v2 の複数ブランチ対応で兄弟ファイル `docs/flow/<ticket-id>/<subticket>.md` を足すため。v1 では兄弟ファイルを作らない。
- チケット id にファイルパスや git ブランチ名に使えない文字（空白、`/`、`#`、`~`、`^`、`:` など）が含まれる場合は、勝手に書き換えず、停止してユーザーにどうするか尋ねる。
- どのモードでも、既存ファイルを黙って上書きしない。

## 行動原則（全体を通して）

- 情報が不足・曖昧なときは**質問する**。チケットの内容・要件・存在しないファイルを勝手に作らない。
- 仮定を置いて進めるときは**その仮定を明示**し、ユーザーが直せるようにする（該当セクションにも記録する）。
- 不要な手順や成果物だと感じたら、黙ってやらず（黙って省きもせず）**指摘する**。
- 懸念や反対は**理由付きで率直に**言う。ユーザーが提案したというだけで同意しない。
- ユーザーには相手の言語で話す。`main.md` のセクション本文は英語で書く。

## ガードレール

- dev の 1 run につき 1 チケット。作業が別チケットの範囲に広がりそうなら指摘する。
- 明示的な確認なしに push / PR 作成をしない（Phase 6）。
- 外部システムにチケットを作らない（v1）。

---

# init モード — プロジェクト初期化

目的：このプロジェクトで `/flow` を使える状態にする。プロジェクトにつき最初に 1 回だけ実行する想定。チケット id は取らない（渡されたら無視せず、`/flow new <ticket-id>` の案内をする）。

1. 現状を確認する：`docs/context/`・`docs/tickets/`・`docs/flow/` の有無と中身、git リポジトリかどうか。
2. 作成するものを一覧で提示してから作る（既にあるものは作らない・上書きしない）：
   - `docs/context/`（下書きは手順 3）
   - `docs/tickets/.gitkeep`
   - `docs/flow/.gitkeep`
3. **context の下書き**：コードベース（README、パッケージ定義、ディレクトリ構成、主要なエントリポイントなど）を読み、`docs/context/overview.md` に下書きを書く。
   - 内容の目安：サービスの目的、主要なドメイン概念、アーキテクチャ／ディレクトリ構成、技術スタック、開発・テストの実行方法。
   - コードから読み取れた事実と、推測を分ける。推測には `(assumption)` を付け、分からないことは `Open questions` に挙げる。
   - `docs/context/` に既にファイルがある場合は新規作成せず、足りない点を提案するにとどめる。
   - 本文は英語で書く（`main.md` と揃える）。
4. 作ったものを要約し、`docs/context/overview.md` をユーザーに確認・修正してもらうよう促す。未解決の疑問点があれば質問する。
5. 次の一手として `/flow new <ticket-id>` を案内する。commit はしない（ユーザーが頼んだ場合を除く）。

---

# new モード — チケット作成

目的：`docs/tickets/<ticket-id>.md` を、ユーザーとの対話で作る。

1. チケット id が無ければ尋ねる。
2. `docs/tickets/<ticket-id>.md` が既にある場合は上書きしない。内容を示し、編集するか `/flow dev <ticket-id>` に進むかを尋ねる。
3. `docs/` が無い（init 未実行の）場合は、その旨を伝えて `/flow init` を提案する。ユーザーがこのまま進めると言えば `docs/tickets/` だけ作って続ける。
4. 何を作りたいか・なぜ必要かをユーザーに尋ね、下記テンプレートの各項目を対話で埋める。
   - **要件を捏造しない。** ユーザーが言っていないことは書かない。こちらの提案は提案として示し、合意したものだけ書く。
   - 決まらない点は削らず `Open Questions` に残す。
   - 必要なら `docs/context/**` やコードを読んで、質問を具体的にする。
5. 下書きを提示し、合意したらファイルに書く。
6. 次の一手として `/flow dev <ticket-id>` を案内する。状態ファイル（`docs/flow/...`）は作らない（dev の役目）。

チケットのテンプレート（見出しは英語、本文はユーザーの言語でよい）：

```markdown
# <ticket-id>: <title>

## Background
<!-- why this is needed -->

## Requirements
<!-- what must be done -->

## Acceptance Criteria
<!-- how we know it's done -->

## Out of Scope
<!-- what this ticket explicitly does not cover -->

## Open Questions
<!-- undecided points; resolved during /flow dev Research -->
```

---

# dev モード — 6 フェーズで進める

1 つのチケットを 6 フェーズ **Research → Approach → Plan → Implement → Review → PR** で進める。
進捗はすべて 1 つの状態ファイルに集約する。これにより、どのフェーズ境界で止めても、後から `/flow dev <ticket-id>` で再開できる。

## 起動と再開

1. **チケット id が無い**場合：尋ねる。進行中の run がちょうど 1 つなら、その再開を提案する（チケット id と Status を示す）。推測で決めない。
2. **状態ファイル `docs/flow/<ticket-id>/main.md` が存在する**場合：読んで `Status` から再開する。
   - `<phase>:awaiting-approval` → そのフェーズの要約とゲートを再提示し、停止して待つ。
   - `<phase>:in-progress` → そこまで書かれたセクションを読み直し（Implement ならブランチの `git log` / `git status` も確認）、そのフェーズを継続する。途中成果が信頼できなければやり直す。どちらにするかをユーザーに伝える。
   - `done` → run が完了済みであること（`## PR` の PR URL 付き）を伝え、どうしたいか尋ねる。勝手にフェーズをやり直さない。
3. **状態ファイルが存在しない**場合：まず `docs/tickets/<ticket-id>.md` があることを確認する（無ければ Phase 1 手順 1 のとおり停止）。あれば下記テンプレートから `Status: research:in-progress` で作成し、Phase 1 を開始する。

## 状態ファイル `docs/flow/<ticket-id>/main.md`

このファイルを run の単一の真実とする。各フェーズが自分のセクションを書き、`Status` を更新する。
下記テンプレートから生成する（見出し・セクション本文は**英語**）：

```markdown
# Flow: <ticket-id>

| Field   | Value                              |
|---------|------------------------------------|
| Status  | research:in-progress               |
| Ticket  | docs/tickets/<ticket-id>.md        |
| Branch  | —                                  |
| Updated | <YYYY-MM-DD HH:MM>                 |

## Research
<!-- Phase 1: organized understanding of the ticket + relevant context -->

## Approach
<!-- Phase 2: chosen implementation approach and key design decisions -->

## Plan
<!-- Phase 3: branch name + ordered commit breakdown -->

## Implementation Log
<!-- Phase 4: commits made and notable decisions during implementation -->

## Review
<!-- Phase 5: divergences vs Approach / Plan / ticket, or "No divergences" -->

## PR
<!-- Phase 6: title, target branch, URL -->
```

**Status のフォーマット：** `<phase>:<state>`
- `<phase>`：`research | approach | plan | implement | review | pr`、および終端の `done`（`done` には state を付けない）。
- `<state>`：`in-progress`（作業中）か `awaiting-approval`（フェーズ完了・ゲートで停止し承認待ち）。
- フェーズのセクションを書くときは、**同じ編集で**必ず `Status` と `Updated` も更新する。セクションと Status をずらさない。
- `Updated` はローカル時刻の `YYYY-MM-DD HH:MM`（`date '+%Y-%m-%d %H:%M'` で取得）。
- 承認を受けて次フェーズへ進むときは、作業を始める前に `Status` を `<次のphase>:in-progress` にする。

## 承認ゲート（＝再開点）

- **全フェーズの境界で停止する。** フェーズ完了時：セクションを書く → `Status` を `<phase>:awaiting-approval` にする → ユーザーに短い要約を出す → **止まる**。ユーザーの「続けて」等で次へ進む。この停止点が、後から `/flow dev <ticket-id>` で再開する地点になる。
- **フェーズ内では小刻みに止めない。** 特に Implement は commit ごとに確認しない（commit 分割は Plan で承認済みのため）。
- ゲートで承認ではなくフィードバックが来たら：現フェーズを修正し、セクションを書き直し、同じゲートを再提示する。
- **PR だけは必ず止まる強ゲート**（Phase 6 参照）。前段のゲートを連打で飛ばしてきても、push / PR 作成の前に必ず一度停止する。

---

## Phase 1 — Research

目的：どう実装するか決める前に、実装に必要な情報を整理する。

1. `docs/tickets/<ticket-id>.md` を読む。無ければ停止し、`/flow new <ticket-id>` で作るか尋ねる。dev モードの中でチケットの内容を捏造・作成しない。
2. `docs/context/**` の関連箇所（必要な分だけ）を読み、必要ならコードベースも見て、ドメイン／サービス知識を集める。
3. 整理する：チケットの要求、関連コンテキスト、影響しそうなコード領域、制約、未解決の疑問点。
4. 結果を `## Research` に書く。
5. `Status: research:awaiting-approval` にして要約を出し（未解決の疑問点を強調）、停止。

## Phase 2 — Approach

目的：*どう実装するか* を決めて確認する。

1. Research をもとに実装方針を決める：検討した選択肢、採用案、主要な設計判断とトレードオフ。
2. ユーザーに提示して確認し、フィードバックで調整する。
3. 合意した方針を `## Approach`（英語）に書く。
4. `Status: approach:awaiting-approval` にして要約を出し、停止。

## Phase 3 — Plan

目的：方針を具体的なブランチ＋commit 計画に落とす。

1. **ブランチ**（`<ticket-id>-<slug>`）と、**順序付きの commit 分割**（各 commit の目的とおおまかな範囲）を決める。
2. **v1 は単一ブランチ。** 1 ブランチに収まらないなら、それはサブチケットに分割すべき＝ v2 の機能。v1 では**ユーザーに指摘して**一緒にチケットを絞る。自動分割やサブチケット自動生成はしない。
3. ブランチと commit 一覧を `## Plan` に書き、ヘッダ表の `Branch` も埋める。
4. `Status: plan:awaiting-approval` にして要約を出し、停止。
5. 承認されたら：リポジトリの状態を確認する（git リポジトリであること。このチケットと無関係な未コミット変更があれば警告する）。ブランチを作成／切り替え、`Status: implement:in-progress` にして Implement へ進む。

## Phase 4 — Implement

目的：承認済みの方針と計画に沿って実装する。

1. 承認済みブランチ上で、承認済みの commit 分割に従って実装・commit する。commit ごとの承認では止めない。
2. commit を積むごとに `## Implementation Log`（commit hash とメッセージ、実装中の重要な判断）と `Updated` を更新する。
3. 承認された計画どおりに進められないと分かったら（ある commit を大きく変える必要がある、方針が誤っていた等）、停止して提起する。これは小さな確認ではなく本当の判断事項。
4. 計画した commit を全て終えたら `Status: implement:awaiting-approval` にして、作ったものを要約し、停止。

## Phase 5 — Review（乖離チェック）

目的：作ったものと意図のズレを検出する。

1. 実装した変更（例：`git diff <base>...HEAD`）を **Approach / Plan / チケット** と突き合わせる。両方向を見る：
   - 合意と違う実装になっている点
   - 合意・チケットにあるのに未実装の点
2. 結果を `## Review` に書く。乖離一覧（各対処付き）か "No divergences"。
3. 対処が必要なら提示する。必要なら Implement（以前）に戻って Status もそれに合わせ、その後 Review に戻ってくる。
4. `Status: review:awaiting-approval` にして要約を出し、停止。

## Phase 6 — PR（強ゲート）

目的：明示的な確認の後にだけ PR を出す。

1. `Status: pr:in-progress` にする。PR を準備し、取り返しのつかない操作の前に提示する：**ブランチ**・**向き先ブランチ**（ユーザーの指定が無ければリモートのデフォルトブランチ）・**PR タイトル**・変更概要（PR 本文の下書き）。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** このゲートは前段を飛ばしてきても必ず発生する。勝手に push / PR しない。
3. 確認されたら push して PR を作成する（例：`gh pr create`）。
4. PR タイトル・向き先・URL を `## PR` に書き、`Status: done` にして URL を報告する。

---

## v1 の対象外（v2 送り）

- ローカル docs 以外のチケット／知識ソース（Jira / GitHub Projects・Issues / Confluence）と、それらを選ぶ設定（`/flow init` の拡張）。
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/` 配下の兄弟ファイル）。

ユーザーがこれらを求めたら、v2 の機能であることを伝え、v1 の範囲でできることを行う。

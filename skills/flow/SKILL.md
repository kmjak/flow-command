---
name: flow
description: チケット単位で開発を回すフレームワーク。/flow <ticket-id> で明示起動する。1 チケットを 6 フェーズ（Research → Approach → Plan → Implement → Review → PR）で進め、進捗を docs/flow/<ticket-id>/main.md に集約するので、途中で止めても同じフェーズから再開できる。
argument-hint: "<ticket-id>"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep
---

# /flow — チケット駆動開発

この run のチケット id：`$ARGUMENTS`

1 つのチケットを 6 フェーズ **Research → Approach → Plan → Implement → Review → PR** で進める。
進捗はすべて 1 つの状態ファイルに集約する。これにより、どのフェーズ境界で止めても、後から `/flow <ticket-id>` で再開できる。

## 規約（v1：ローカル docs のみ）

チケット id を全ての基点にする：チケットファイル名・状態フォルダ名・ブランチ接頭辞。
チケット id は不透明な文字列として扱い、**数値だと仮定しない**（v1 はローカルのファイル名 stem。将来は `PROJ-123` や issue 番号などになりうる）。

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**`（必要な分だけ読む） |
| チケット | `docs/tickets/<ticket-id>.md` |
| flow 状態 | `docs/flow/<ticket-id>/main.md` |
| ブランチ名 | `<ticket-id>-<slug>`（チケット id を接頭辞にする） |

- 上記パスは固定規約。v1 に `setup` / `init` は無い。
- 状態はあえて**フォルダ形式**（`docs/flow/<ticket-id>/main.md`）にしている。v2 の複数ブランチ対応で兄弟ファイル `docs/flow/<ticket-id>/<subticket>.md` を足すため。v1 では兄弟ファイルを作らない。
- チケット id にファイルパスや git ブランチ名に使えない文字（空白、`/`、`#`、`~`、`^`、`:` など）が含まれる場合は、勝手に書き換えず、停止してユーザーにどうするか尋ねる。

## 起動と再開

1. **引数が無い**（`$ARGUMENTS` が空）場合：
   - `docs/flow/*/main.md` を Glob し、それぞれの `Status` を読む。`done` 以外が進行中の run。
   - 進行中の run がちょうど 1 つなら、その再開を提案する（チケット id と Status を示す）。返答を待つ。
   - それ以外は、どのチケットを進めるか尋ねる（進行中の run や `docs/tickets/*.md` を候補として示す）。推測で決めない。
2. **状態ファイル `docs/flow/<ticket-id>/main.md` が存在する**場合：読んで `Status` から再開する。
   - `<phase>:awaiting-approval` → そのフェーズの要約とゲートを再提示し、停止して待つ。
   - `<phase>:in-progress` → そこまで書かれたセクションを読み直し（Implement ならブランチの `git log` / `git status` も確認）、そのフェーズを継続する。途中成果が信頼できなければやり直す。どちらにするかをユーザーに伝える。
   - `done` → run が完了済みであること（`## PR` の PR URL 付き）を伝え、どうしたいか尋ねる。勝手にフェーズをやり直さない。
3. **状態ファイルが存在しない**場合：下記テンプレートから `Status: research:in-progress` で作成し、Phase 1 を開始する。

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

- **全フェーズの境界で停止する。** フェーズ完了時：セクションを書く → `Status` を `<phase>:awaiting-approval` にする → ユーザーに短い要約を出す → **止まる**。ユーザーの「続けて」等で次へ進む。この停止点が、後から `/flow <ticket-id>` で再開する地点になる。
- **フェーズ内では小刻みに止めない。** 特に Implement は commit ごとに確認しない（commit 分割は Plan で承認済みのため）。
- ゲートで承認ではなくフィードバックが来たら：現フェーズを修正し、セクションを書き直し、同じゲートを再提示する。
- **PR だけは必ず止まる強ゲート**（Phase 6 参照）。前段のゲートを連打で飛ばしてきても、push / PR 作成の前に必ず一度停止する。

## 行動原則（全体を通して）

- 情報が不足・曖昧なときは**質問する**。チケットの内容・要件・存在しないファイルを勝手に作らない。
- 仮定を置いて進めるときは**その仮定を明示**し、ユーザーが直せるようにする（該当セクションにも記録する）。
- 不要な手順や成果物だと感じたら、黙ってやらず（黙って省きもせず）**指摘する**。
- 懸念や反対は**理由付きで率直に**言う。ユーザーが提案したというだけで同意しない。
- ユーザーには相手の言語で話す。`main.md` のセクション本文は英語で書く。

## ガードレール

- 1 run につき 1 チケット。作業が別チケットの範囲に広がりそうなら指摘する。
- 明示的な確認なしに push / PR 作成をしない（Phase 6）。
- 外部システムにチケットを作らない（v1）。

---

## Phase 1 — Research

目的：どう実装するか決める前に、実装に必要な情報を整理する。

1. `docs/tickets/<ticket-id>.md` を読む。無ければ停止してユーザーにチケットを尋ねる。内容を捏造しない。ユーザーが明示的に頼み、内容を提供した場合を除き、チケットファイルを作らない。
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

- ローカル docs 以外のチケット／知識ソース（Jira / GitHub Projects・Issues / Confluence）と、それらを選ぶ `setup` / `init`。
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/` 配下の兄弟ファイル）。

ユーザーがこれらを求めたら、v2 の機能であることを伝え、v1 の範囲でできることを行う。

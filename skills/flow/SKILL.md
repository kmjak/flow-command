---
name: flow
description: チケット単位で開発を回すフレームワーク。/flow で明示起動する。モードは init（プロジェクトの docs 雛形を作り、context を対話で作るか雛形だけ用意する）、new（チケットを対話で作る）、dev（1 チケットを 6 フェーズ Research → Approach → Plan → Implement → Review → PR で進める）。dev の進捗は docs/flow/<ticket-id>/main.md に集約するので、途中で止めても同じフェーズから再開できる。
argument-hint: "[init | new <ticket-id> | dev <ticket-id>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep
---

# /flow — チケット駆動開発

引数：`$ARGUMENTS`

## モード

| 起動 | モード | 単位 | 内容 |
|------|--------|------|------|
| `/flow init` | init | プロジェクト（最初に 1 回） | docs の雛形作成と `docs/context/` の作成（対話 or 自分で書く） |
| `/flow new <ticket-id>` | new | チケット（作るたび） | `docs/tickets/<ticket-id>.md` を対話で作る |
| `/flow dev <ticket-id>` | dev | チケット（run ごと） | 6 フェーズで実装から PR まで進める |
| `/flow <それ以外>` | — | — | 実行しない。`/flow dev <ticket-id>` のことか確認する（下記） |
| `/flow` | — | — | モードを選ばせる（下記） |

**引数の解釈：** 先頭の語が `init` / `new` / `dev` ならそのモード、残りをチケット id とする。
先頭の語がモード名でない場合（例：`/flow 123`）は**何も実行しない**。「`/flow dev <引数>` のことですか？」とだけ尋ねて止まる（AskUserQuestion を使い、選択肢は「はい、dev で進める」と「いいえ」）。はいなら dev モードとして続け、いいえなら `/flow` の選択肢（下記）を提示する。ファイルの読み込みや作成は、確認が取れるまで行わない。

### 引数が無い場合（`/flow`）

まず `docs/flow/*/main.md` を Glob して各 `Status` を読み、`done` 以外を進行中の run とする。
そのうえで、次の選択肢をユーザーに提示し（AskUserQuestion を使う）、選ばれたモードで続ける。推測で決めない。

1. **進行中の flow を再開** — 進行中の run のチケット id と Status を説明に含める。**進行中の run が無ければこの選択肢は出さない**（残りの 3 つだけを提示する）。
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
| flow 設定 | `docs/flow.config.yml`（git 管理する。チーム共通） |
| flow 状態 | `docs/flow/<ticket-id>/main.md`（**git 管理外**） |
| ブランチ名 | `<ticket-id>-<slug>`（チケット id を接頭辞にする） |

- **`docs/flow/` は git で管理しない**（`.gitignore` に入れる）。flow 状態は各個人の作業記録であり、共有物ではない。また PR に含めるとレビュアーが検討過程に引っ張られ、実装そのものを見たレビューにならないため。`main.md` を commit・PR に含めない。
- **ドキュメント言語**：チケット・`docs/context/**`・flow 状態（`main.md`）の本文は `docs/flow.config.yml` の `language` で書く。既定は日本語（`ja`）。設定ファイルが無ければ日本語とする。チケットと context は見出しもこの言語にする（`main.md` の見出しは英語の固定キー。状態ファイルの節を参照）。
  ```yaml
  # /flow settings (shared, committed)
  language: ja   # ja | en | その他の言語名
  ```
- 上記パスは固定規約。`init` はこの規約どおりの雛形を作るだけで、パスやソースの選択はしない（ソース選択は v2 送り）。
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
- 明示的な確認なしに push / PR 作成をしない（Phase 6）。
- 外部システムにチケットを作らない（v1）。

---

# init モード — プロジェクト初期化

目的：このプロジェクトで `/flow` を使える状態にする。プロジェクトにつき最初に 1 回だけ実行する想定。チケット id は取らない（渡されたら無視せず、`/flow new <ticket-id>` の案内をする）。

1. 現状を確認する：`docs/context/`・`docs/tickets/`・`docs/flow/` の有無と中身、git リポジトリかどうか、`docs/flow/` が無視されているか（`git check-ignore -q docs/flow/x`）。
2. **ドキュメント言語を決める**（`docs/flow.config.yml` が既にあればその値を使い、尋ねない）：AskUserQuestion で「日本語（推奨・既定）」「English」を選択肢にして尋ねる（その他はユーザーが自由入力できる）。以降のチケットと `docs/context/**` はこの言語で書く。
3. 作成するものを一覧で提示してから作る（既にあるものは作らない・上書きしない）：
   - `docs/context/`（中身は手順 4）
   - `docs/tickets/.gitkeep`
   - `docs/flow.config.yml` — 手順 2 で決めた `language` を書く。
   - `.gitignore` に `docs/flow/` を追加（既に無視されていれば何もしない。`.gitignore` が無ければ作る）。`docs/flow/` 自体は dev が必要になったときに作るので、ここでは作らない。
4. **context を作る**：`docs/context/` に既にファイルがある場合は、作り方を尋ねずに既存の内容を読み、足りない点を提案するにとどめる（上書きしない）。無い場合は、AskUserQuestion で作り方を選んでもらう：
   - **対話で作る** — 下記「対話で作る場合」の手順で、各項目の内容をユーザーと一緒に決めて `docs/context/overview.md` を書く。
   - **自分で作る** — 下記テンプレートの見出しと記入ガイドだけを入れた `docs/context/overview.md` を作り、中身はユーザーが書く。こちらからは内容を埋めない。

   **対話で作る場合：**
   1. 先にコードベース（README、パッケージ定義、ディレクトリ構成、主要なエントリポイントなど）を読み、各項目についてコードから読み取れる事実を集めておく。質問を具体的にし、答えの候補を示すためであり、読み取った内容をそのまま書くためではない。
   2. テンプレートの項目を**1 つずつ**進める。項目ごとに、コードから読み取れた事実（出典のファイルを示す）と、分からない点・コードからは判断できない点を示し、ユーザーに質問する。特に「サービスの目的」と「主要なドメイン概念」はコードからは決めきれないので、ユーザーの言葉で決めてもらう。
   3. その項目の文面を提示し、ユーザーが合意してから次の項目へ進む。**合意していない内容は書かない。** コードからの推測をユーザーの確認なしに事実として書かない。
   4. その場で決まらない点は削らず「未決事項」に残す。ユーザーが「推測のままでよい」とした記述には `（推測）` を付ける。
   5. 全項目が決まったら全体を提示し、最終確認を得てからファイルに書く。

   `docs/context/overview.md` のテンプレート（日本語版。ドキュメント言語が日本語以外なら、見出しとコメントをその言語に訳して使う）：

   ```markdown
   # プロジェクト概要

   ## サービスの目的
   <!-- 何のためのサービスか。誰のどんな課題を解決するか。 -->

   ## 主要なドメイン概念
   <!-- このサービス固有の用語・概念と、その意味や関係。 -->

   ## アーキテクチャ／ディレクトリ構成
   <!-- 全体の構成と、主要なディレクトリ・モジュールの役割。 -->

   ## 技術スタック
   <!-- 言語、フレームワーク、主要なライブラリ、インフラ。 -->

   ## 開発・テストの実行方法
   <!-- セットアップ、起動、テスト、lint のコマンド。 -->

   ## 未決事項
   <!-- まだ決まっていないこと・分からないこと。 -->
   ```

   対話で作った場合、完成したファイルには記入ガイドのコメントを残さない。自分で作る場合はコメントを残す（書くときのガイドになるため）。
5. 作ったものを要約する。対話で作った場合は未決事項を示す。自分で作る場合は、`docs/context/overview.md` を埋めてから `/flow new` に進むよう促す。
6. 次の一手として `/flow new <ticket-id>` を案内する。commit はしない（ユーザーが頼んだ場合を除く）。

---

# new モード — チケット作成

目的：`docs/tickets/<ticket-id>.md` を、ユーザーとの対話で作る。

1. チケット id が無ければ尋ねる。
2. `docs/tickets/<ticket-id>.md` が既にある場合は上書きしない。内容を示し、編集するか `/flow dev <ticket-id>` に進むかを尋ねる。
3. `docs/` が無い（init 未実行の）場合は、その旨を伝えて `/flow init` を提案する。ユーザーがこのまま進めると言えば `docs/tickets/` だけ作って続ける。
4. ドキュメント言語を `docs/flow.config.yml` の `language` から読む（無ければ日本語）。
5. 何を作りたいか・なぜ必要かをユーザーに尋ね、下記テンプレートの各項目を対話で埋める。テンプレート内の HTML コメント（記入ガイド）は完成したチケットには残さない。
   - **要件を捏造しない。** ユーザーが言っていないことは書かない。こちらの提案は提案として示し、合意したものだけ書く。
   - 決まらない点は削らず「未決事項」に残す。
   - 必要なら `docs/context/**` やコードを読んで、質問を具体的にする。
6. 下書きを提示し、合意したらファイルに書く。
7. 次の一手として `/flow dev <ticket-id>` を案内する。状態ファイル（`docs/flow/...`）は作らない（dev の役目）。

チケットのテンプレート（日本語版。ドキュメント言語が日本語以外なら、見出しとコメントをその言語に訳して使う。該当しない項目も削らず「なし」と書く）：

```markdown
# <ticket-id>: <タイトル>

## 背景
<!-- なぜ必要か。解決したい問題や動機、誰が影響を受けるか。 -->

## 要件
<!-- 何をするか。1 項目 1 行の箇条書きで、実装方法ではなく振る舞いを書く。 -->

## 受け入れ条件
<!-- 何を満たせば完了か。各項目を「- [ ]」で、できた／できていないで判定できる形で書く。 -->

## 対象外
<!-- このチケットでは扱わないこと。 -->

## 未決事項
<!-- まだ決まっていないこと。/flow dev の Research で解消する。 -->
```

---

# dev モード — 6 フェーズで進める

1 つのチケットを 6 フェーズ **Research → Approach → Plan → Implement → Review → PR** で進める。
進捗はすべて 1 つの状態ファイルに集約する。これにより、どのフェーズ境界で止めても、後から `/flow dev <ticket-id>` で再開できる。

## 起動と再開

1. **チケット id が無い**場合：尋ねる。進行中の run がちょうど 1 つなら、その再開を提案する（チケット id と Status を示す）。推測で決めない。
2. **状態ファイル `docs/flow/<ticket-id>/main.md` が存在する**場合：読んで `Status` から再開する。
   - `<phase>:awaiting-approval` → そのフェーズの要約とゲートを再提示し、停止して待つ。
   - `<phase>:in-progress` → そこまで書かれたセクションを読み直し（Implement ならブランチの `git log` / `git status` も確認）、そのフェーズを継続する。途中成果が信頼できなければやり直す。どちらにするかをユーザーに伝える。`pr:in-progress` の場合は、先にそのブランチの PR が既に存在しないか確認する（Phase 6 手順 1）。
   - `pr:awaiting-review` → PR のレビュー状況を確認する（Phase 6 手順 5）。
   - `done` → run が完了済みであること（`## PR` の PR URL 付き）を伝え、どうしたいか尋ねる。勝手にフェーズをやり直さない。
3. **状態ファイルが存在しない**場合：まず `docs/tickets/<ticket-id>.md` があることを確認する（無ければ Phase 1 手順 1 のとおり停止）。次に `docs/flow/` が git で無視されているか確認する（`git check-ignore -q docs/flow/<ticket-id>/main.md`）。無視されていなければ、`.gitignore` への `docs/flow/` 追加を提案し、ユーザーの判断を待つ（理由は共通規約参照）。問題なければ下記テンプレートから `Status: research:in-progress` で作成し、Phase 1 を開始する。

## 状態ファイル `docs/flow/<ticket-id>/main.md`

このファイルを run の単一の真実とする。各フェーズが自分のセクションを書き、`Status` を更新する。
下記テンプレートから生成する。**セクション本文はドキュメント言語（既定は日本語）で書く。** 見出し・表のフィールド名・`Status` の値は英語のまま変えない（フェーズ名と対応し、このスキルが参照・再開に使う固定キーのため）：

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
<!-- Phase 5: divergences vs Approach / Plan / ticket, recorded as rounds -->

## PR
<!-- Phase 6: title, target branch, URL, review outcome -->
```

**Status のフォーマット：** `<phase>:<state>`
- `<phase>`：`research | approach | plan | implement | review | pr`、および終端の `done`（`done` には state を付けない）。
- `<state>`：`in-progress`（作業中）か `awaiting-approval`（フェーズ完了・ゲートで停止し承認待ち）。`pr` フェーズのみ、これに加えて `awaiting-review`（PR を出してレビュアーの Approve 待ち）を使う。
- フェーズのセクションを書くときは、**同じ編集で**必ず `Status` と `Updated` も更新する。セクションと Status をずらさない。
- `Updated` はローカル時刻の `YYYY-MM-DD HH:MM`（`date '+%Y-%m-%d %H:%M'` で取得）。
- 承認を受けて次フェーズへ進むときは、作業を始める前に `Status` を `<次のphase>:in-progress` にする。

## 承認ゲート（＝再開点）

- **全フェーズの境界で停止する。** フェーズ完了時：セクションを書く → `Status` を `<phase>:awaiting-approval` にする → ユーザーに短い要約を出す → **止まる**。ユーザーの「続けて」等で次へ進む。この停止点が、後から `/flow dev <ticket-id>` で再開する地点になる。
- **フェーズ内では小刻みに止めない。** 特に Implement は commit ごとに確認しない（commit 分割は Plan で承認済みのため）。
- ゲートで承認ではなくフィードバックが来たら：現フェーズを修正し、セクションを書き直し、同じゲートを再提示する。
- **PR だけは必ず止まる強ゲート**（Phase 6 参照）。前段のゲートを連打で飛ばしてきても、push / PR 作成の前に必ず一度停止する。PR 作成後はレビュアーの Approve まで `pr:awaiting-review` で待ち、Approve されて初めて `done` になる。

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
3. 合意した方針を `## Approach` に書く。
4. `Status: approach:awaiting-approval` にして要約を出し、停止。

## Phase 3 — Plan

目的：方針を具体的なブランチ＋commit 計画に落とす。

1. **ブランチ**（`<ticket-id>-<slug>`）と、**順序付きの commit 分割**（各 commit の目的とおおまかな範囲）を決める。
2. **v1 は単一ブランチ。** 1 ブランチに収まらないなら、それはサブチケットに分割すべき＝ v2 の機能。v1 では**ユーザーに指摘して**一緒にチケットを絞る。自動分割やサブチケット自動生成はしない。
3. ブランチと commit 一覧を `## Plan` に書き、ヘッダ表の `Branch` も埋める。
4. `Status: plan:awaiting-approval` にして要約を出し、停止。
5. 承認されたら、**他の作業より先に** `Status: implement:in-progress` にして Implement へ進む（ブランチ作成は Implement の手順 1 で行う。承認後・Status 更新前に作業すると、中断時に Plan のゲートが再提示されてしまうため）。

## Phase 4 — Implement

目的：承認済みの方針と計画に沿って実装する。

1. **ブランチの準備**：リポジトリの状態を確認する（git リポジトリであること。このチケットと無関係な未コミット変更があれば警告する）。承認済みブランチが無ければ作成し、既にあれば切り替えるだけにする（中断からの再開で作成済みのことがある）。既に目的のブランチ上なら何もしない。
2. 承認済みブランチ上で、承認済みの commit 分割に従って実装・commit する。commit ごとの承認では止めない。
3. commit を積むごとに `## Implementation Log`（commit hash とメッセージ、実装中の重要な判断）と `Updated` を更新する。
4. 承認された計画どおりに進められないと分かったら（ある commit を大きく変える必要がある、方針が誤っていた等）、停止して提起する。これは小さな確認ではなく本当の判断事項。
5. 計画した commit を全て終えたら `Status: implement:awaiting-approval` にして、作ったものを要約し、停止。

**Review からの差し戻しで戻ってきた場合**（Phase 5 で「修正」と決まった乖離がある）：直すのは `## Review` の最新ラウンドで「修正」とされた項目だけにする。それ以外に手を広げない。修正の commit は `## Implementation Log` に「Review Round N の修正」として記録する。終わったら Implement のゲートは挟まずに `Status: review:in-progress` にして Review へ戻る（直後に Review のゲートがあるため）。

## Phase 5 — Review（乖離チェック）

目的：作ったものと意図のズレを検出する。

1. 実装した変更（例：`git diff <base>...HEAD`）を **Approach / Plan / チケット** と突き合わせる。両方向を見る：
   - 合意と違う実装になっている点
   - 合意・チケットにあるのに未実装の点
2. 結果を `## Review` に**ラウンドとして追記する**（`### Round 1`、`### Round 2` …）。前のラウンドは書き換えない。乖離一覧か「乖離なし」。
3. 乖離があれば、項目ごとに対処をユーザーに選んでもらう（勝手に決めない。こちらの推奨があれば理由付きで示す）：
   - **修正** — 実装が合意と違う／未実装。Implement に戻って直す。
   - **方針の見直し** — Approach 自体が誤っていた。Approach に戻る。
   - **受け入れ** — 実装のほうが妥当。直さず、理由をその項目に記録する。
4. 決まった対処を各項目に記録し、次のとおり進む：
   - 「方針の見直し」が 1 つでもある → `Status: approach:in-progress` にして Phase 2 へ。以降の Plan・Implement・Review も通常どおりゲートを通り直す（既存のセクションは消さずに更新する）。
   - 「修正」がある（方針の見直しは無い） → `Status: implement:in-progress` にして Implement へ（Phase 4 の「Review からの差し戻し」）。修正後に Review へ戻り、次のラウンドを行う。
   - 乖離なし、または全て「受け入れ」 → `Status: review:awaiting-approval` にして要約を出し、停止。

## Phase 6 — PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、レビュアーの Approve まで見届ける。

1. `Status: pr:in-progress` にする。まず、そのブランチの PR が既に存在しないか確認する（`gh pr list --head <branch> --state all`）。中断からの再開で既に作成済みなら、新しく作らずに URL を `## PR` に記録し、`Status: pr:awaiting-review` にして手順 5 へ進む。
   無ければ PR を準備し、取り返しのつかない操作の前に提示する：**ブランチ**・**向き先ブランチ**（ユーザーの指定が無ければリモートのデフォルトブランチ）・**PR タイトル**・変更概要（PR 本文の下書き）。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** このゲートは前段を飛ばしてきても必ず発生する。勝手に push / PR しない。
3. 確認されたら push して PR を作成する（例：`gh pr create`）。
4. PR タイトル・向き先・URL を `## PR` に書き、`Status: pr:awaiting-review` にして URL を報告し、停止する。**この時点では `done` にしない。** レビューは人が行うので、flow は待つだけ。ユーザーには、レビューが進んだら `/flow dev <ticket-id>` で再開するよう案内する。
5. **レビュー状況の確認**（`pr:awaiting-review` から再開したとき）：`gh pr view <url> --json state,reviewDecision,reviews` で状況を確認する。
   - **Approve 済み**（`reviewDecision` が `APPROVED`。レビュー必須でないリポジトリでは `reviews` に `APPROVED` がある）、またはマージ済み → `## PR` に結果を追記し、`Status: done` にする。
   - **修正依頼あり**（`CHANGES_REQUESTED` やコメント）→ 指摘を要約して提示し、`Status: pr:in-progress` にして対応する。修正はブランチに commit し、`## Implementation Log` に「PR レビュー対応」として記録する。push の前に変更内容を提示して**停止し、確認を得てから push する**。push したら `Status: pr:awaiting-review` に戻して停止する。
   - **まだレビューされていない** → その旨を伝え、`pr:awaiting-review` のまま停止する。
   - **マージされずにクローズされた** → 報告し、どうするか尋ねる。勝手に `done` にしない。

---

## v1 の対象外（v2 送り）

- ローカル docs 以外のチケット／知識ソース（Jira / GitHub Projects・Issues / Confluence）と、それらを選ぶ設定（`/flow init` の拡張）。
- 複数ブランチ実行とサブチケット分割（`docs/flow/<ticket-id>/` 配下の兄弟ファイル）。

ユーザーがこれらを求めたら、v2 の機能であることを伝え、v1 の範囲でできることを行う。

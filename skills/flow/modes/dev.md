# dev モード — 6 フェーズで進める

1 つのチケットを 6 フェーズ **Research → Approach → Plan → Implement → Review → PR** で進める。
進捗はすべて 1 つの状態ファイルに集約する。これにより、どのフェーズ境界で止めても、後から `/flow dev <ticket-id>` で再開できる。

## 起動と再開

新規・再開のどちらでも、まず `docs/flow.config.yml` の `language` を読む（無ければ日本語）。この run の間、`main.md` のセクション本文はこの言語で書く。

1. **チケット id が無い**場合：尋ねる。進行中の run がちょうど 1 つなら、その再開を提案する（チケット id と Status を示す）。推測で決めない。
2. **状態ファイル `docs/flow/<ticket-id>/main.md` が存在する**場合：読んで `Status` から再開する。
   - `<phase>:awaiting-approval` → そのフェーズの要約とゲートを再提示し、停止して待つ。
   - `<phase>:in-progress` → そこまで書かれたセクションを読み直し（Implement ならブランチの `git log` / `git status` も確認）、そのフェーズを継続する。途中成果が信頼できなければやり直す。どちらにするかをユーザーに伝える。`pr:in-progress` の場合は、先にそのブランチの PR が既に存在しないか確認する（Phase 6 手順 1）。
   - `pr:awaiting-review` → PR の状況（レビュー・CI・コンフリクト）を確認する（Phase 6 手順 5）。
   - `done` → run が完了済みであること（`## PR` の PR URL 付き）を伝え、どうしたいか尋ねる。勝手にフェーズをやり直さない。
3. **状態ファイルが存在しない**場合：まず `docs/tickets/<ticket-id>.md` があることを確認する（無ければ Phase 1 手順 1 のとおり停止）。次に `docs/flow/` が git で無視されているか確認する（`git check-ignore -q docs/flow/<ticket-id>/main.md`）。無視されていなければ、`.gitignore` への `docs/flow/` 追加を提案し、ユーザーの判断を待つ（理由は共通規約参照）。問題なければ下記テンプレートから `Status: research:in-progress` で作成し、Phase 1 を開始する。

## 状態ファイル `docs/flow/<ticket-id>/main.md`

このファイルを run の単一の真実とする。各フェーズが自分のセクションを書き、`Status` を更新する。
下記テンプレートから生成する。**セクション本文はドキュメント言語（起動時に `docs/flow.config.yml` から読んだもの）で書く。** 見出し・表のフィールド名・`Status` の値は英語のまま変えない（フェーズ名と対応し、このスキルが参照・再開に使う固定キーのため）：

```markdown
# Flow: <ticket-id>

| Field   | Value                              |
|---------|------------------------------------|
| Status  | research:in-progress               |
| Ticket  | docs/tickets/<ticket-id>.md        |
| Branch  | —                                  |
| Base    | —                                  |
| Updated | <YYYY-MM-DD HH:MM>                 |

## Research
<!-- Phase 1: organized understanding of the ticket + relevant context -->

## Approach
<!-- Phase 2: chosen implementation approach and key design decisions -->

## Plan
<!-- Phase 3: branch name, base branch, ordered commit breakdown -->

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
- **PR だけは必ず止まる強ゲート**（Phase 6 参照）。前段のゲートを連打で飛ばしてきても、push / PR 作成の前に必ず一度停止する。PR 作成後は `pr:awaiting-review` で待ち、Approve 済みかつ CI 成功かつコンフリクトなしになって初めて `done` になる。

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

1. **ブランチ**（`<ticket-id>-<slug>`）、**Base**（分岐元であり PR の向き先。ユーザーの指定が無ければリモートのデフォルトブランチ＝`git symbolic-ref --short refs/remotes/origin/HEAD` の `origin/` を除いたもの）、**順序付きの commit 分割**（各 commit の目的とおおまかな範囲）を決める。
2. **v1 は単一ブランチ。** 1 ブランチに収まらないなら、それはサブチケットに分割すべき＝ v2 の機能。v1 では**ユーザーに指摘して**一緒にチケットを絞る。自動分割やサブチケット自動生成はしない。
   - チケットファイル（`docs/tickets/<ticket-id>.md`）が Base で未コミット（未追跡、または変更あり）なら、commit 分割の**先頭**に「チケットの追加」の commit を入れる。
3. ブランチ・Base・commit 一覧を `## Plan` に書き、ヘッダ表の `Branch` と `Base` も埋める。
4. `Status: plan:awaiting-approval` にして要約を出し、停止。
5. 承認されたら、**他の作業より先に** `Status: implement:in-progress` にして Implement へ進む（ブランチ作成は Implement の手順 1 で行う。承認後・Status 更新前に作業すると、中断時に Plan のゲートが再提示されてしまうため）。

## Phase 4 — Implement

目的：承認済みの方針と計画に沿って実装する。

1. **ブランチの準備**：リポジトリの状態を確認する（git リポジトリであること。このチケットと無関係な未コミット変更があれば警告する。ただし `docs/tickets/` 配下の他のチケットの未追跡ファイルは、まだ着手していないチケットなので警告の対象外とし、commit にも含めない）。承認済みブランチが無ければ `Base` の最新から作成し、既にあれば切り替えるだけにする（中断からの再開で作成済みのことがある）。既に目的のブランチ上なら何もしない。
2. 承認済みブランチ上で、承認済みの commit 分割に従って実装・commit する。先頭がチケットの commit なら、`docs/tickets/<ticket-id>.md` だけを commit する（他のチケットは含めない）。commit ごとの承認では止めない。
3. commit を積むごとに `## Implementation Log`（commit hash とメッセージ、実装中の重要な判断）と `Updated` を更新する。
4. 承認された計画どおりに進められないと分かったら（ある commit を大きく変える必要がある、方針が誤っていた等）、停止して提起する。これは小さな確認ではなく本当の判断事項。
5. 計画した commit を全て終えたら**検証**（下記）を行う。通ったら `Status: implement:awaiting-approval` にして、作ったもの（検証結果を含む）を要約し、停止。

**Review からの差し戻しで戻ってきた場合**（Phase 5 で「修正」と決まった乖離がある）：直すのは `## Review` の最新ラウンドで「修正」とされた項目だけにする。それ以外に手を広げない。修正の commit は `## Implementation Log` に「Review Round N の修正」として記録する。修正後に検証を行う。終わったら Implement のゲートは挟まずに `Status: review:in-progress` にして Review へ戻る（直後に Review のゲートがあるため）。

### 検証

`docs/flow.config.yml` の `commands` を、書かれた順にリポジトリのルートで全て実行する。実装の途中で個別のテストを実行するのは自由だが、ゲートの前には必ずこの全件を実行する。

- 結果を `## Implementation Log` に `Verification @ <短い commit hash>: <キー> pass | fail …` の形で記録する。
- **失敗したら**、このチケットの範囲内で原因を直して commit し（`Implementation Log` に記録）、全件を実行し直す。全て通るまでゲートに進まない。
- 次の場合は直さずに停止し、ユーザーに判断を求める：
  - `Base` でも同じく失敗する（既存の失敗。`git stash` などで作業を失わない方法で確かめる）
  - 直すのにチケットの範囲外の変更や、方針・計画の変更が必要
  - 環境の問題（依存が無い、サービスが起動していない等）で実行できない
- **テストを通すために、テストの削除・スキップ・期待値の書き換え・lint の無効化をしない。** それが本当に正しい場合は、理由を示してユーザーの承認を得る。
- `commands` が `{}` なら検証をスキップし、`Implementation Log` に「検証コマンドなし」と記録する。`commands` キー自体が無い（古い init で作った設定）場合は、`/flow init` を再実行すると追加できることを伝え、今回は検証なしで進めるか尋ねる。

## Phase 5 — Review（乖離チェック）

目的：作ったものと意図のズレを検出する。

1. **検証**（Phase 4 の「検証」）の結果を用意する。`Implementation Log` の最新の検証が現在の HEAD に対するもので全て pass ならそれを使い、そうでなければ実行し直す。失敗があれば Review に進まず、`Status: implement:in-progress` に戻して Phase 4 の検証の手順で扱う。
2. 実装した変更（`git diff <Base>...HEAD`。`Base` はヘッダ表の値）を **Approach / Plan / チケット** と突き合わせる。両方向を見る：
   - 合意と違う実装になっている点
   - 合意・チケットにあるのに未実装の点
3. 結果を `## Review` に**ラウンドとして追記する**（`### Round 1`、`### Round 2` …）。前のラウンドは書き換えない。乖離一覧か「乖離なし」。
4. 乖離があれば、項目ごとに対処をユーザーに選んでもらう（勝手に決めない。こちらの推奨があれば理由付きで示す）：
   - **修正** — 実装が合意と違う／未実装。Implement に戻って直す。
   - **方針の見直し** — Approach 自体が誤っていた。Approach に戻る。
   - **受け入れ** — 実装のほうが妥当。直さず、理由をその項目に記録する。
5. 決まった対処を各項目に記録し、次のとおり進む：
   - 「方針の見直し」が 1 つでもある → `Status: approach:in-progress` にして Phase 2 へ。以降の Plan・Implement・Review も通常どおりゲートを通り直す（既存のセクションは消さずに更新する）。
   - 「修正」がある（方針の見直しは無い） → `Status: implement:in-progress` にして Implement へ（Phase 4 の「Review からの差し戻し」）。修正後に Review へ戻り、次のラウンドを行う。
   - 乖離なし、または全て「受け入れ」 → `Status: review:awaiting-approval` にして要約を出し、停止。

## Phase 6 — PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、レビュアーの Approve まで見届ける。

1. `Status: pr:in-progress` にする。まず、そのブランチの PR が既に存在しないか確認する（`gh pr list --head <branch> --state all`）。中断からの再開で既に作成済みなら、新しく作らずに URL を `## PR` に記録し、`Status: pr:awaiting-review` にして手順 5 へ進む。
   無ければ PR を準備し、取り返しのつかない操作の前に提示する：**ブランチ**・**向き先ブランチ**（ヘッダ表の `Base`）・**PR タイトル**・変更概要（PR 本文の下書き）。タイトルと本文はドキュメント言語で書く。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** このゲートは前段を飛ばしてきても必ず発生する。勝手に push / PR しない。
3. 確認されたら push して PR を作成する（例：`gh pr create`）。
4. PR タイトル・向き先・URL を `## PR` に書き、`Status: pr:awaiting-review` にして URL を報告し、停止する。**この時点では `done` にしない。** レビューは人が行うので、flow は待つだけ。ユーザーには、レビューが進んだら `/flow dev <ticket-id>` で再開するよう案内する。
5. **PR の状況確認**（`pr:awaiting-review` から再開したとき）：このスキルのディレクトリにある `scripts/pr-status.sh <PR URL>` を実行する。1 行目が判定、2 行目以降が詳細。判定ごとに次のとおり進む（`done` にしてよいのは `approved` と `merged` だけ）：
   - `approved`（Approve 済み・CI 全て成功・コンフリクトなし）または `merged` → `## PR` に結果を追記し、`Status: done` にする。
   - `conflict`（Base とコンフリクト）→ `Status: pr:in-progress` に戻し、`Base` の最新を取り込んで解消する。取り込み方は merge を既定とする（rebase は force push が必要になるため、ユーザーが望んだ場合だけ）。
   - `ci_failing`（CI 失敗）→ `Status: pr:in-progress` に戻し、失敗したチェック（`failing_checks`）のログを確認して（`gh pr checks`・`gh run view --log-failed`）原因を直す。
   - `changes_requested`（修正依頼）→ `Status: pr:in-progress` に戻し、指摘を要約して提示してから対応する。
   - `pending`（未レビュー・CI 実行中など）→ その旨と詳細を伝え、`pr:awaiting-review` のまま停止する。`commented_by` がある（コメントだけのレビュー）場合は内容を示し、対応するかユーザーに尋ねる。
   - `closed`（マージされずにクローズ）→ 報告し、どうするか尋ねる。勝手に `done` にしない。

   `conflict`・`ci_failing`・`changes_requested` への対応はブランチに commit し、`## Implementation Log` に「PR 対応：<判定>」として記録する。push の前に**検証**（Phase 4）を行い、変更内容と検証結果を提示して**停止し、確認を得てから push する**。push したら `Status: pr:awaiting-review` に戻して停止する。対応が方針や計画の変更を伴う大きさなら、その場で直さずに停止し、Approach／Implement に戻るかユーザーに尋ねる。

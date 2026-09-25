# dev モード — 6 フェーズで進める

1 つのチケットを 6 フェーズ **Research → Approach → Plan → Implement → Review → PR** で進める。
進捗はすべて 1 つの状態ファイルに集約する。これにより、どのフェーズ境界で止めても、後から `/flow dev <ticket-id>` で再開できる。

## 起動と再開

新規・再開のどちらでも、まず `docs/flow.config.yml` の `language` を読む（無ければ日本語）。この run の間、`main.md` のセクション本文はこの言語で書く。同じく `ticket` を読み（無ければ共通規約の既定値）、指定された id を共通規約のとおり正規化する。

**GitHub 連携**（`ticket.tracker: github` で、チケットに `Issue: #<番号>` がある場合）：`references/github.md` の「事前チェック」を行い、チケットがあることを確かめた後（下記 2・3）、issue と照合する（同ファイルの「issue との照合」）。issue の内容を取り込み、進行中の run（状態ファイルがあり、`Status` が `done`・`canceled` 以外）がある場合は、`modes/edit.md` の手順 7 を Read して同じ手順でフェーズを戻すか尋ねてから再開する。以降、同ファイルの定めに従ってラベル・assignee・PR との紐付け・クローズを行う。`Issue:` 行が無いチケット（`local` の時代に作ったもの等）では issue の操作をしない。

0. **キャンセル済みのチケット**（チケットに `Status: canceled`、または `main.md` の `Status` が `canceled`）なら、理由（`Reason:`）を示して止まる。やり直したいなら、新しいチケットを `/flow new` で作るよう伝える。
1. **チケット id が無い**場合：尋ねる。進行中の run がちょうど 1 つなら、その再開を提案する（チケット id と Status を示す）。推測で決めない。
2. **状態ファイル `docs/flow/<ticket-id>/main.md` が存在する**場合：読んで `Status` から再開する。チケットが手元に無ければ、GitHub 連携で issue があれば `references/github.md` の「手元にチケットが無い場合（復元）」で復元してから再開する（無ければ停止して伝える）。
   - `<phase>:awaiting-approval` → そのフェーズの要約とゲートを再提示し、停止して待つ。
   - `<phase>:in-progress` → そこまで書かれたセクションを読み直し（Implement ならブランチの `git log` / `git status` も確認）、そのフェーズを継続する。途中成果が信頼できなければやり直す。どちらにするかをユーザーに伝える。`pr:in-progress` の場合は、先にそのブランチの PR が既に存在しないか確認する（Phase 6 手順 1）。
   - `pr:awaiting-review` → PR の状況（レビュー・CI・コンフリクト）を確認する（Phase 6 手順 5）。
   - `done` → run が完了済みであること（`## PR` の PR URL 付き）を伝え、どうしたいか尋ねる。勝手にフェーズをやり直さない（やり直すなら新しいチケットを作る）。GitHub 連携で、PR がマージ済みなのに issue が開いたままなら、閉じるか尋ねる。
3. **状態ファイルが存在しない**場合：まず `docs/tickets/<ticket-id>.md` があることを確認する（無ければ Phase 1 手順 1 のとおり停止。GitHub 連携で issue だけが存在する場合は `references/github.md` の「手元にチケットが無い場合（復元）」で復元してから続ける）。次に `docs/flow/` が git で無視されているか確認する（`git check-ignore -q docs/flow/<ticket-id>/main.md`）。無視されていなければ、`.gitignore` への `docs/flow/` 追加を提案し、ユーザーの判断を待つ（理由は共通規約参照）。問題なければ下記テンプレートから `Status: research:in-progress` で作成し（ヘッダ表の `Issue` にはチケットの `Issue:` の値を、無ければ `—` を書く）、GitHub 連携なら issue を `flow:in-progress` にして assignee に自分を追加する（他の人が assign されていたら、作成前に停止して尋ねる）。そのうえで Phase 1 を開始する。

## 状態ファイル `docs/flow/<ticket-id>/main.md`

このファイルを run の単一の真実とする。各フェーズが自分のセクションを書き、`Status` を更新する。
下記テンプレートから生成する。**セクション本文はドキュメント言語（起動時に `docs/flow.config.yml` から読んだもの）で書く。** 見出し・表のフィールド名・`Status` の値は英語のまま変えない（フェーズ名と対応し、このスキルが参照・再開に使う固定キーのため）：

```markdown
# Flow: <ticket-id>

| Field   | Value                              |
|---------|------------------------------------|
| Status  | research:in-progress               |
| Ticket  | docs/tickets/<ticket-id>.md        |
| Issue   | —                                  |
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
<!-- Phase 5: reviewer findings vs Approach / Plan / ticket, with recommendations and decisions, recorded as rounds -->

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

1. `docs/tickets/<ticket-id>.md` を読む。無ければ停止し、`/flow new` で作るか尋ねる（id は new で自動的に決まるため、指定された id のままにはならないことも伝える）。dev モードの中でチケットの内容を捏造・作成しない。
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

1. **ブランチ**（`<ticket-id>-<slug>`）、**Base**（分岐元であり PR の向き先。`host: none` ではマージ先。ユーザーの指定が無ければ `docs/flow.config.yml` の `repository.default_branch`、それも無ければ `git symbolic-ref --short refs/remotes/origin/HEAD` の `origin/` を除いたもの）、**順序付きの commit 分割**（各 commit の目的とおおまかな範囲）を決める。
   - そのブランチ名が既に存在し、この run のものでない（`/flow reset` で残した前の run のブランチなど）場合は、別の名前（例：末尾に `-2`）にする。
2. **v1 は単一ブランチ。** 1 ブランチに収まらないなら、それはサブチケットに分割すべき＝ v2 の機能。v1 では**ユーザーに指摘して**一緒にチケットを絞る。自動分割やサブチケット自動生成はしない。
   - チケットファイル（`docs/tickets/<ticket-id>.md`）が Base で未コミット（未追跡、または変更あり）なら、commit 分割の**先頭**に「チケットの追加」の commit を入れる。
3. ブランチ・Base・commit 一覧を `## Plan` に書き、ヘッダ表の `Branch` と `Base` も埋める。
4. `Status: plan:awaiting-approval` にして要約を出し、停止。
5. 承認されたら、**他の作業より先に** `Status: implement:in-progress` にして Implement へ進む（ブランチ作成は Implement の手順 1 で行う。承認後・Status 更新前に作業すると、中断時に Plan のゲートが再提示されてしまうため）。

## Phase 4 — Implement

目的：承認済みの方針と計画に沿って実装する。

1. **ブランチの準備**：リポジトリの状態を確認する（git リポジトリであること。このチケットと無関係な未コミット変更があれば警告する。ただし `docs/tickets/` 配下の他のチケットの未追跡ファイルは、まだ着手していないチケットなので警告の対象外とし、commit にも含めない）。承認済みブランチが無ければ `Base` の最新から作成し、既にあれば切り替えるだけにする（中断からの再開で作成済みのことがある）。既に目的のブランチ上なら何もしない。
2. 承認済みブランチ上で、承認済みの commit 分割に従って実装・commit する。**commit メッセージは `docs/context/commit.md` に従う**（最初の commit の前に読む。`Source:` にパスがあればそのファイルを規約として読み、本文は補足として扱う。`Language:` の言語で書く）。`commit.md` が無ければ直近の `git log` の書式に合わせ、`/flow init` の再実行で作れることを伝える。先頭がチケットの commit なら、`docs/tickets/<ticket-id>.md` だけを commit する（他のチケットは含めない）。commit ごとの承認では止めない。
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

目的：作ったものと意図のズレを検出する。実装した本人（このセッション）は自分の判断に引きずられるため、**乖離の検出は reviewer agent（`flow-reviewer`）に任せ**、このセッションは各指摘に推奨を添えるだけにする。判断はユーザーが行う。

1. **reviewer agent の確認**：利用できる agent に `flow-reviewer` があることを確認する。無ければ停止し、README の導入手順（`agents/flow-reviewer.md` を `~/.claude/agents/` に symlink するか、プロジェクトの `.claude/agents/` にコピーする）を案内する。**general-purpose など別の agent で代用しない**（レビューの基準が変わるため）。
2. **検証**（Phase 4 の「検証」）の結果を用意する。`Implementation Log` の最新の検証が現在の HEAD に対するもので全て pass ならそれを使い、そうでなければ実行し直す。失敗があれば Review に進まず、`Status: implement:in-progress` に戻して Phase 4 の検証の手順で扱う。
3. **reviewer を起動する**：`flow-reviewer` をラウンドごとに新しく起動する（前のラウンドの agent を使い回さない）。渡すのは次のものだけにする：
   - チケットのパス（`docs/tickets/<ticket-id>.md`）
   - `Base` と、比較範囲 `<Base>...HEAD`
   - `## Approach` と `## Plan` の本文（そのまま貼る）
   - 検証の結果
   - 前のラウンドまでに「受け入れ」と決まった乖離とその理由（同じ指摘を繰り返させないため）
   - ドキュメント言語

   **`## Research`・`## Implementation Log`・実装中の経緯は渡さない**（実装者の意図に引きずられず、合意と成果物だけで判定させるため）。`docs/flow/` 配下のパスも渡さない。
4. **結果を記録する**：`## Review` に**ラウンドとして追記する**（`### Round 1`、`### Round 2` …）。前のラウンドは書き換えない。各ラウンドには、検証結果と、reviewer の指摘を**全件そのまま**載せる（指摘が無ければ「乖離なし」）。
   - **reviewer の指摘を削除・統合・言い換え・並べ替えしない。** 誤検知だと思っても消さず、推奨欄でそう述べる。
   - 各指摘の下に、このセッションの**推奨**（修正／方針の見直し／受け入れ）と**根拠**を添える。根拠には `## Implementation Log` の判断や実装中の経緯を使ってよい（reviewer が知らない情報を補うのがこのセッションの役割）。
   - このセッションが別の乖離に気づいた場合は、`（実装者による追加）` と明記して別の項目として追記する。
5. 乖離があれば、項目ごとに対処をユーザーに選んでもらう（勝手に決めない。推奨は理由付きで示すだけ）：
   - **修正** — 実装が合意と違う／未実装／合意外の変更を取り除く。Implement に戻って直す。
   - **方針の見直し** — Approach 自体が誤っていた。Approach に戻る。
   - **受け入れ** — 実装のほうが妥当、または誤検知。直さず、理由をその項目に記録する。
6. 決まった対処を各項目に記録し、次のとおり進む：
   - 「方針の見直し」が 1 つでもある → `Status: approach:in-progress` にして Phase 2 へ。以降の Plan・Implement・Review も通常どおりゲートを通り直す（既存のセクションは消さずに更新する）。
   - 「修正」がある（方針の見直しは無い） → `Status: implement:in-progress` にして Implement へ（Phase 4 の「Review からの差し戻し」）。修正後に Review へ戻り、次のラウンドを行う。
   - 乖離なし、または全て「受け入れ」 → `Status: review:awaiting-approval` にして要約を出し、停止。

`## Review` のラウンドの書き方（本文はドキュメント言語。reviewer の報告をそのまま貼り、`推奨`・`決定` の行だけをこのセッションが足す）：

```markdown
### Round 1
Verification @ a1b2c3d: test pass, lint pass

- **R1 [未実装]** 受け入れ条件「…」に対応する処理が無い
  - 合意側：チケット 受け入れ条件 2
  - 実装側：該当する変更なし
  - 確度：高
  - 推奨：修正 — …
  - 決定：修正
- **R2 [合意外の変更]** …
  - 合意側：…
  - 実装側：src/foo.ts:42
  - 確度：中
  - 推奨：受け入れ — Implementation Log の判断「…」のとおり、…のため
  - 決定：受け入れ（理由：…）
```

## Phase 6 — PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、レビュアーの Approve まで見届ける。

`repository.host` が `none`（GitHub を使わない）なら、PR は出さずに下記「ローカルのみの場合」で進める。以下の手順 1〜5 は `host: github` の場合。

1. `Status: pr:in-progress` にする。まず、そのブランチの PR が既に存在しないか確認する（`gh pr list --head <branch> --state all`）。中断からの再開で既に作成済みなら、新しく作らずに URL を `## PR` に記録し、`Status: pr:awaiting-review` にして手順 5 へ進む。
   無ければ PR を準備し、取り返しのつかない操作の前に提示する：**ブランチ**・**向き先ブランチ**（ヘッダ表の `Base`）・**PR タイトル**・変更概要（PR 本文の下書き）。タイトルと本文はドキュメント言語で書く。GitHub 連携なら、本文の末尾に **`Closes #<番号>` を必ず入れ**、作成の直前に issue と照合する。照合で issue の内容を取り込んだら、PR を作らずに停止し、起動時と同じくフェーズを戻すか尋ねる（実装が変更後のチケットを満たしているとは限らないため）。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** このゲートは前段を飛ばしてきても必ず発生する。勝手に push / PR しない。
3. 確認されたら、`Status` は `pr:awaiting-approval` のまま push して PR を作成する（例：`gh pr create`。`--fill` は使わず本文を明示する）。guard hook が登録されていれば、push・PR 作成のたびにユーザーの確認画面が出る。**確認画面で拒否されたら、言い換えて再実行せず、停止して指示を待つ**（SKILL.md のガードレール）。GitHub 連携なら、作成後に issue との紐付けを確かめ（`references/github.md` の「PR との紐付け」）、issue を `flow:in-review` にする。
4. PR タイトル・向き先・URL を `## PR` に書き、`Status: pr:awaiting-review` にして URL を報告し、停止する。**この時点では `done` にしない。** レビューは人が行うので、flow は待つだけ。ユーザーには、レビューが進んだら `/flow dev <ticket-id>` で再開するよう案内する。
5. **PR の状況確認**（`pr:awaiting-review` から再開したとき）：このスキルのディレクトリにある `scripts/pr-status.sh <PR URL>` を実行する。1 行目が判定、2 行目以降が詳細。判定ごとに次のとおり進む（`done` にしてよいのは `approved` と `merged` だけ）：
   - `approved`（Approve 済み・CI 全て成功・コンフリクトなし）または `merged` → `## PR` に結果を追記し、`Status: done` にする。GitHub 連携なら `references/github.md` の「クローズ」に従う（`merged` なら閉じる。`approved` ではまだ閉じない）。
   - `conflict`（Base とコンフリクト）→ `Status: pr:in-progress` に戻し、`Base` の最新を取り込んで解消する。取り込み方は merge を既定とする（rebase は force push が必要になるため、ユーザーが望んだ場合だけ）。
   - `ci_failing`（CI 失敗）→ `Status: pr:in-progress` に戻し、失敗したチェック（`failing_checks`）のログを確認して（`gh pr checks`・`gh run view --log-failed`）原因を直す。
   - `changes_requested`（修正依頼）→ `Status: pr:in-progress` に戻し、指摘を要約して提示してから対応する。
   - `pending`（未レビュー・CI 実行中など）→ その旨と詳細を伝え、`pr:awaiting-review` のまま停止する。`commented_by` がある（コメントだけのレビュー）場合は内容を示し、対応するかユーザーに尋ねる。
   - `closed`（マージされずにクローズ）→ 報告し、どうするか尋ねる。勝手に `done` にしない。

   `conflict`・`ci_failing`・`changes_requested` への対応はブランチに commit し、`## Implementation Log` に「PR 対応：<判定>」として記録する。push の前に**検証**（Phase 4）を行い、変更内容と検証結果を提示して**停止し、確認を得てから push する**。push したら `Status: pr:awaiting-review` に戻して停止する。対応が方針や計画の変更を伴う大きさなら、その場で直さずに停止し、Approach／Implement に戻るかユーザーに尋ねる。

### ローカルのみの場合（`repository.host: none`）

push も PR も無い。Review の承認後、`Base`（`repository.default_branch`）へローカルでマージして終える。PR が無いので、マージ commit を「このチケットでまとめて入った変更」の記録にする。

1. `Status: pr:in-progress` にする。中断からの再開で、ブランチが既に `Base` にマージ済み（`git merge-base --is-ancestor <branch> <Base>`）か削除済みなら、マージ commit を探して手順 4 へ進む。そうでなければマージの内容を準備して提示する：**ブランチ**・**マージ先**（`Base`）・取り込む commit の一覧（`git log --oneline <Base>..<branch>`）・実行するコマンド。
   - `git switch <Base>` → `git merge --no-ff <branch> -m "Merge <ticket-id>: <チケットのタイトル>"` → `git branch -d <branch>`
   - `Base` に未コミットの変更があれば、先に示して止まる（勝手に stash しない）。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** マージとブランチの削除は、この 1 回の確認でまとめて承認をもらう。
3. 確認されたら実行する。
   - **コンフリクトしたら**自分で解決しない。`git merge --abort` で元に戻し、コンフリクトしたファイルを示して停止し、指示を待つ（`Status` は `pr:awaiting-approval` のまま）。
   - ブランチの削除は `git branch -d`（マージ済みでなければ失敗する安全な削除）だけを使う。`-D` は使わない。
4. `## PR` にマージ先・マージ commit の hash・削除したブランチを書き、`Status: done` にして報告する。


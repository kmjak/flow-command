# dev モード — 6 フェーズで進める

1 つのチケットを 6 フェーズ **Research → Approach → Plan → Implement → Review → PR** で進める。
進捗はすべて 1 つの状態ファイルに集約する。これにより、どのフェーズ境界で止めても、後から `/flow dev <ticket-id>` で再開できる。

## 起動と再開

`docs/flow.config.yml` の値は SKILL.md の「現在の状態」にある（`language` が無ければ日本語）。この run の間、`main.md` のセクション本文はこの言語で書く。指定された id は `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する。id が無ければ尋ねる（進行中の run がちょうど 1 つなら、その再開を提案する。推測で決めない）。

**チケットの準備**（新規・再開のどちらでも最初に行う）：

- **`tracker: github`**：`references/github.md` を Read し、「事前チェック」の後、「チケットを issue から取ってくる」を行う（手元のコピーは毎回 issue から作り直す）。「変更あり」で、進行中の run（状態ファイルがあり、`Status` が `done`・`canceled` 以外）がある場合は、`references/rollback.md` を Read してフェーズを戻すか決めてから再開する。issue が閉じていれば、下記の `done`・キャンセル済みの扱いに従い、それ以外なら止まって尋ねる。
- **`tracker: local`**：`docs/tickets/<ticket-id>.md` を読む。無い場合：
  - 状態ファイルの `Branch` のブランチ、または `git log --all --oneline -- docs/tickets/<ticket-id>.md` で見つかるブランチにチケットがあるなら、そのブランチに切り替えるか尋ねる（チケットはまだ実装ブランチにしか無い）。
  - どこにも無ければ停止し、`/flow new` で作るか尋ねる（id は new で自動的に決まるため、指定された id のままにはならないことも伝える）。dev モードの中でチケットの内容を捏造・作成しない。

続けて：

0. **キャンセル済みのチケット**（チケットに `Status: canceled`、または `main.md` の `Status` が `canceled`）なら、理由（`Reason:`）を示して止まる。やり直したいなら、新しいチケットを `/flow new` で作るよう伝える。
1. **状態ファイル `docs/flow/<ticket-id>/main.md` が存在する**場合：読んで `Status` から再開する。
   - `<phase>:awaiting-approval` → そのフェーズの要約とゲートを再提示し、停止して待つ。
   - `<phase>:in-progress` → そこまで書かれたセクションを読み直し（Implement ならブランチの `git log` / `git status` も確認）、そのフェーズを継続する。途中成果が信頼できなければやり直す。どちらにするかをユーザーに伝える。`pr:in-progress` の場合は、先にそのブランチの PR が既に存在しないか確認する（PR フェーズの「PR の準備」）。
   - `pr:awaiting-review` → PR の状況を確認する（PR フェーズの「PR の状況確認」）。
   - `done` → run が完了済みであること（`## PR` の PR URL 付き）を伝え、どうしたいか尋ねる。勝手にフェーズをやり直さない（やり直すなら新しいチケットを作る）。GitHub 連携で、PR がマージ済みなのに issue が開いたままなら、閉じるか尋ねる。
2. **状態ファイルが存在しない**場合：
   - `docs/flow/` が git で無視されているか確認する（`git check-ignore -q docs/flow/<ticket-id>/main.md`）。無視されていなければ、`.gitignore` への `docs/flow/` 追加を提案し、ユーザーの判断を待つ（理由は共通規約参照）。
   - GitHub 連携なら `issue-label.sh <番号> start` を実行する（終了コード 4：他の人が assign されている → 状態ファイルを作る前に停止して尋ねる）。
   - `bash <scripts>/state.sh init <ticket-id>` で状態ファイルを作り（`Status: research:in-progress`）、Phase 1 を開始する。

## 状態ファイル `docs/flow/<ticket-id>/main.md`

このファイルを run の単一の真実とする。`state.sh init` がテンプレートから作る。

- **ヘッダ表**（`Status`・`Ticket`・`Issue`・`Branch`・`Base`・`Updated`）は `state.sh` だけで書き換える（`bash <scripts>/state.sh set <ticket-id> <Status|Branch|Base|Issue> <値>`。`Updated` は自動で更新される）。表を手で編集しない。
- **セクション**（`## Research`・`## Approach`・`## Plan`・`## Implementation Log`・`## Review`・`## PR`）は各フェーズが Edit で書く。本文はドキュメント言語、見出しは英語の固定キーのまま変えない（このスキルが参照・再開に使うため）。
- フェーズのセクションを書いたら、**続けて** `Status` を更新する（セクション → Status の順。逆にすると、中断したときに空のセクションのまま承認待ちになる）。
- 承認を受けて（またはゲートを自動で通過して）次のフェーズへ進むときは、作業を始める前に `Status` を `<次のphase>:in-progress` にする。

**Status のフォーマット：** `<phase>:<state>`、または終端の値
- `<phase>`：`research | approach | plan | implement | review | pr`
- `<state>`：`in-progress`（作業中）か `awaiting-approval`（フェーズ完了・ゲートで停止し承認待ち）。`pr` フェーズのみ、これに加えて `awaiting-review`（PR を出してレビュー待ち）を使う。
- 終端の値（state を付けない）：`done`（完了）、`canceled`（`/flow cancel` でキャンセル済み）。
- `state.sh` はこれ以外の値を拒否する。

## 承認ゲート（＝再開点）

各フェーズの終わりがゲート。止まるかどうかは `docs/flow.config.yml` の `gates` と、下の「止まる条件」で決まる。

- **`gates` にあるフェーズ**：必ず止まる。セクションを書く → `Status` を `<phase>:awaiting-approval` にする → ユーザーに短い要約を出す → **止まる**。ユーザーの「続けて」等で次へ進む。この停止点が、後から `/flow dev <ticket-id>` で再開する地点になる。
- **`gates` に無いフェーズ**：止まる条件が無ければ**自動で通過**する。セクションの末尾に `> ゲート自動通過（gates に無く、止まる条件なし）` と書き、`Status` を `<次のphase>:in-progress` にし、ユーザーに一行で伝えて続ける（要約は次に止まるゲートでまとめて出す）。止まる条件があれば、`gates` にあるときと同じく止まる。
- **`pr` は `gates` に関係なく必ず止まる**（強ゲート。PR フェーズ参照）。
- `gates` が無い（古い設定）ときは `[approach, plan, pr]` として扱う。

| フェーズ | `gates` に無いときも止まる条件 |
|----------|------------------------------|
| research | 未解決の疑問点がある |
| approach | 採用案を決めるのにユーザーの判断が要る（拮抗する選択肢、チケットの解釈、置いた仮定） |
| plan | 確かめ方を決められない受け入れ条件がある、または 1 ブランチに収まらない |
| implement | ユーザーにしてもらう手動確認が残っている |
| review | reviewer の指摘がある（乖離・品質のどちらでも） |

- **フェーズ内では小刻みに止めない。** 特に Implement は commit ごとに確認しない（commit 分割は Plan で承認済みのため）。
- ゲートで承認ではなくフィードバックが来たら：現フェーズを修正し、セクションを書き直し、同じゲートを再提示する。
- PR 作成後は `pr:awaiting-review` で待ち、PR の状況確認で完了と判定されて初めて `done` になる。

---

## Phase 1 — Research

目的：どう実装するか決める前に、実装に必要な情報を整理する。

1. チケット（`docs/tickets/<ticket-id>.md`）を読む。
2. `docs/context/**` の関連箇所（必要な分だけ）を読む。
3. **コードの調査は Explore agent に任せる**（このセッションの文脈を、Implement の前に調査の読み込みで使い切らないため）。チケットの要約と、具体的な問い（影響しそうなコード領域・似た既存実装・テストの場所と書き方・守るべき制約など）を渡し、ファイルパス付きの要約を受け取る。Explore が使えない環境や、小さなリポジトリでは自分で調べてよい。受け取った要約のうち、判断に必要な箇所は自分でも Read して確かめる。
4. 整理する：チケットの要求、関連コンテキスト、影響しそうなコード領域、制約、未解決の疑問点。
5. 結果を `## Research` に書き、ゲート（`research`）へ。止まるなら `Status: research:awaiting-approval` にして要約を出し（未解決の疑問点を強調）、停止。

## Phase 2 — Approach

目的：*どう実装するか* を決めて確認する。

1. Research をもとに実装方針を決める：検討した選択肢、採用案、主要な設計判断とトレードオフ。
2. `## Approach` に書き、ゲート（`approach`）へ。止まるなら `Status: approach:awaiting-approval` にして方針の要約を出し、停止（確認はこの 1 回だけ。フィードバックが来たら書き直して同じゲートを再提示する）。

## Phase 3 — Plan

目的：方針を具体的なブランチ・確かめ方・commit 計画に落とす。

1. **ブランチ**（`<ticket-id>-<slug>`）と **Base**（分岐元であり PR の向き先。`host: none` ではマージ先。ユーザーの指定が無ければ `repository.default_branch`、それも無ければ `git symbolic-ref --short refs/remotes/origin/HEAD` の `origin/` を除いたもの）を決める。
   - そのブランチ名が既に存在し、この run のものでない（`/flow reset` で残した前の run のブランチなど）場合は、別の名前（例：末尾に `-2`）にする。
2. **受け入れ条件 → 確かめ方の対応表**を作る。チケットの受け入れ条件の**全項目**に 1 行ずつ、何で確かめるかを決める。Implement はこの表に沿ってテストを書き、Review はこの表で照合する。
   ```markdown
   | # | 受け入れ条件 | 確かめ方 | 種別 |
   |---|--------------|----------|------|
   | 1 | 正しいパスワードでログインできる | `tests/login.test.ts`「正しいパスワードでログインできる」 | 自動 |
   | 2 | 誤ったパスワードでエラーが表示される | ブラウザで誤ったパスワードを入れ、エラー表示を確認 | 手動 |
   ```
   - できるだけ**自動**（テスト名まで書く）にする。**手動**は、自動化が割に合わないもの（見た目・外部サービス・実機の操作など）だけにする。
   - 確かめ方を決められない条件は、止まってユーザーと決める（チケットの受け入れ条件が曖昧なら `/flow edit` を提案する）。
3. **順序付きの commit 分割**（各 commit の目的とおおまかな範囲）を決める。
   - **v1 は単一ブランチ。** 1 ブランチに収まらないなら、それはサブチケットに分割すべき＝ v2 の機能。v1 では**ユーザーに指摘して**一緒にチケットを絞る。自動分割やサブチケット自動生成はしない。
   - `tracker: local` で、チケットファイルが Base で未コミット（未追跡、または変更あり）なら、commit 分割の**先頭**に「チケットの追加」の commit を入れる。`tracker: github` ではチケットを commit しない（git 管理外）。
4. ブランチ・Base・対応表・commit 一覧を `## Plan` に書き、`state.sh set <ticket-id> Branch <ブランチ>`・`state.sh set <ticket-id> Base <Base>` でヘッダも埋める。ゲート（`plan`）へ。止まるなら `Status: plan:awaiting-approval` にして要約を出し、停止。
5. 承認されたら（または自動で通過したら）、**他の作業より先に** `Status: implement:in-progress` にして Implement へ進む（ブランチ作成は Implement の「ブランチの準備」で行う。承認後・Status 更新前に作業すると、中断時に Plan のゲートが再提示されてしまうため）。

## Phase 4 — Implement

目的：承認済みの方針と計画に沿って実装する。

1. **ブランチの準備**：リポジトリの状態を確認する（git リポジトリであること。このチケットと無関係な未コミット変更があれば警告する。ただし `docs/tickets/` 配下の他のチケットの未追跡ファイルは、まだ着手していないチケットなので警告の対象外とし、commit にも含めない）。承認済みブランチが無ければ `Base` の最新から作成し、既にあれば切り替えるだけにする（中断からの再開で作成済みのことがある）。既に目的のブランチ上なら何もしない。
2. 承認済みブランチ上で、承認済みの commit 分割に従って実装・commit する。
   - **テストは対応表に沿って書く。** 表の「自動」の行のテストを、表に書いたテスト名で作る。名前や場所を変えたら `## Implementation Log` に記録する（Review が照合できるように）。
   - **commit メッセージは `docs/context/commit.md` に従う**（最初の commit の前に読む。`Source:` にパスがあればそのファイルを規約として読み、本文は補足として扱う。`Language:` の言語で書く）。`commit.md` が無ければ直近の `git log` の書式に合わせ、`/flow init` の再実行で作れることを伝える。
   - 先頭がチケットの commit なら（`local` のみ）、`docs/tickets/<ticket-id>.md` だけを commit する（他のチケットは含めない）。
   - commit ごとの承認では止めない。
3. commit を積むごとに `## Implementation Log`（commit hash とメッセージ、実装中の重要な判断）を更新する。
4. 承認された計画どおりに進められないと分かったら（ある commit を大きく変える必要がある、方針が誤っていた等）、停止して提起する。これは小さな確認ではなく本当の判断事項。
5. 計画した commit を全て終えたら**検証**と**手動確認**（下記）を行う。通ったら `## Implementation Log` を更新し、ゲート（`implement`）へ。止まるなら `Status: implement:awaiting-approval` にして、作ったもの（検証結果・手動確認の結果を含む）を要約し、停止。止まらないなら `Status: review:in-progress` にして Review へ。

**Review からの差し戻しで戻ってきた場合**（Review で「修正」と決まった指摘がある）：直すのは `## Review` の最新ラウンドで「修正」とされた項目だけにする。それ以外に手を広げない。修正の commit は `## Implementation Log` に「Review Round N の修正」として記録する。修正後に検証（と、影響する手動確認）を行う。終わったら Implement のゲートは挟まずに `Status: review:in-progress` にして Review へ戻る（直後に Review があるため）。

### 検証

`bash <scripts>/verify.sh` を実行する（`docs/flow.config.yml` の `commands` を書かれた順に全て実行する）。実装の途中で個別のテストを実行するのは自由だが、ゲートの前には必ずこれを実行する。

- **出力の 1 行目（`Verification @ <hash>: <キー> pass | fail …`）を、そのまま `## Implementation Log` に書き写す。** 要約・言い換えをしない。
- hash の後に `+dirty` が付いたら、未コミットの変更を検証したことになる。commit してから実行し直す（検証は commit に対して記録する）。
- **終了コード 1（失敗あり）**：出力に並ぶ失敗したコマンドのログファイルを Read し、このチケットの範囲内で原因を直して commit し（`Implementation Log` に記録）、もう一度 `verify.sh` を実行する。全て通るまでゲートに進まない。
- 次の場合は直さずに停止し、ユーザーに判断を求める：
  - `Base` でも同じく失敗する（既存の失敗。`git stash` などで作業を失わない方法で確かめる）
  - 直すのにチケットの範囲外の変更や、方針・計画の変更が必要
  - 環境の問題（依存が無い、サービスが起動していない等）で実行できない
- **テストを通すために、テストの削除・スキップ・期待値の書き換え・lint の無効化をしない。** それが本当に正しい場合は、理由を示してユーザーの承認を得る。
- 出力が「検証コマンドなし」（`commands: {}`）なら、その行をそのまま記録して進む。**終了コード 3**（`commands` キーが無い、古い init で作った設定）なら、`/flow init` を再実行すると追加できることを伝え、今回は検証なしで進めるか尋ねる。

### 手動確認

対応表の「手動」の行を、検証が通った後に確かめる。

- このセッションで確かめる手段がある場合（プロジェクトにアプリを起動するスキル（`run` など）がある、ブラウザを操作するツールが使える、など）は、項目ごとに AskUserQuestion で尋ねる：「Claude が確認する」／「自分で確認する」／「今回は確認しない（理由を記録）」。
- 手段が無ければ、確認の手順（起動方法・操作・期待する結果）を示して、ユーザーに確認してもらう。ユーザーの確認が残っている間は、Implement のゲートで止まる（止まる条件）。
- 結果を `## Implementation Log` に記録する：`手動確認 @ <短い commit hash>: #2 ok（ユーザー）`・`#3 ok（Claude：スクリーンショットで確認）`・`#4 未確認（理由：…）`。
- 手動確認で問題が見つかったら、検証の失敗と同じく直してから、検証からやり直す。

## Phase 5 — Review

目的：作ったものを、意図（合意）とのズレと、品質の両面から調べる。実装した本人（このセッション）は自分の判断に引きずられるため、**検出は 2 つの reviewer agent に任せ**、このセッションは各指摘に推奨を添えるだけにする。判断はユーザーが行う。

| agent | 見るもの |
|-------|----------|
| `flow-reviewer` | 合意（チケット・Approach・Plan の対応表）と実装のズレ：相違・未実装・合意外の変更 |
| `flow-quality-reviewer` | 合意とは関係のない品質：バグ・セキュリティ・性能・エラー処理・テストの妥当性 |

1. **agent の確認**：利用できる agent に `flow-reviewer` と `flow-quality-reviewer` があることを確認する。無ければ停止し、README の導入手順（`agents/` のファイルを `~/.claude/agents/` に symlink するか、プロジェクトの `.claude/agents/` にコピーする）を案内する。**general-purpose など別の agent で代用しない**（レビューの基準が変わるため）。
2. **検証**の結果を用意する。`Implementation Log` の最新の `Verification @` が現在の HEAD（`git rev-parse --short HEAD`。`+dirty` 無し）に対するもので全て pass ならそれを使い、そうでなければ `verify.sh` を実行し直す。失敗があれば Review に進まず、`Status: implement:in-progress` に戻して Implement の「検証」で扱う。
3. **レビューの入力を書き出す**：`bash <scripts>/review-input.sh <ticket-id> <Base>` を実行する。差分・commit 一覧・変更ファイル一覧のパスが出力される（`.git/flow/review/<ticket-id>/`。`docs/flow/` の外）。差分の中身をこのセッションで読む必要はない。
4. **2 つの reviewer を並列に起動する**（1 つのメッセージで 2 つの Agent 呼び出し）。ラウンドごとに新しく起動する（前のラウンドの agent を使い回さない）。渡すのは次のものだけにする：
   - 両方に：3 のファイルのパス、検証の行、ドキュメント言語、前のラウンドまでに「受け入れ」と決まったその agent の指摘と理由（同じ指摘を繰り返させないため）
   - `flow-reviewer` にだけ：チケットのパス（`docs/tickets/<ticket-id>.md`）、`## Approach` と `## Plan` の本文（そのまま貼る。対応表を含む）、手動確認の行

   **`## Research`・`## Implementation Log` の判断・実装中の経緯は渡さない**（実装者の意図に引きずられず、合意と成果物だけで判定させるため）。`docs/flow/` 配下のパスも渡さない。
5. **結果を記録する**：`## Review` に**ラウンドとして追記する**（`### Round 1`、`### Round 2` …）。前のラウンドは書き換えない。各ラウンドには、検証の行と、両方の reviewer の指摘を**全件そのまま**載せる（指摘が無ければ「乖離なし」「問題なし」）。
   - **reviewer の指摘を削除・統合・言い換え・並べ替えしない。** 誤検知だと思っても消さず、推奨欄でそう述べる。
   - 各指摘の下に、このセッションの**推奨**（修正／方針の見直し／受け入れ）と**根拠**を添える。根拠には `## Implementation Log` の判断や実装中の経緯を使ってよい（reviewer が知らない情報を補うのがこのセッションの役割）。
   - このセッションが別の問題に気づいた場合は、`（実装者による追加）` と明記して別の項目として追記する。
6. 指摘があれば、項目ごとに対処をユーザーに選んでもらう（勝手に決めない。推奨は理由付きで示すだけ）：
   - **修正** — 実装が合意と違う／未実装／合意外の変更を取り除く／品質の問題を直す。Implement に戻って直す。
   - **方針の見直し** — Approach 自体が誤っていた。Approach に戻る。
   - **受け入れ** — 実装のほうが妥当、誤検知、または今回は直さない。直さず、理由をその項目に記録する。
7. 決まった対処を各項目に記録し、次のとおり進む：
   - 「方針の見直し」が 1 つでもある → `Status: approach:in-progress` にして Phase 2 へ。以降の Plan・Implement・Review も通常どおりゲートを通り直す（既存のセクションは消さずに更新する）。
   - 「修正」がある（方針の見直しは無い） → `Status: implement:in-progress` にして Implement へ（「Review からの差し戻し」）。修正後に Review へ戻り、次のラウンドを行う。
   - 指摘なし、または全て「受け入れ」 → ゲート（`review`）へ。止まるなら `Status: review:awaiting-approval` にして要約を出し、停止。

`## Review` のラウンドの書き方（本文はドキュメント言語。reviewer の報告をそのまま貼り、`推奨`・`決定` の行だけをこのセッションが足す）：

```markdown
### Round 1
Verification @ a1b2c3d: test pass, lint pass

#### 合意とのズレ（flow-reviewer）
- **R1 [未実装]** 受け入れ条件「…」に対応する処理が無い
  - 合意側：チケット 受け入れ条件 2
  - 実装側：該当する変更なし
  - 確度：高
  - 推奨：修正 — …
  - 決定：修正

#### 品質（flow-quality-reviewer）
- **Q1 [バグ]** 空の配列で例外になる
  - 場所：src/foo.ts:42
  - 起きること：…
  - 重大度：中
  - 確度：高
  - 推奨：修正 — …
  - 決定：受け入れ（理由：…）
```

## Phase 6 — PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、完了まで見届ける。

`repository.host` が `none`（GitHub を使わない）なら、PR は出さずに下記「ローカルのみの場合」で進める。以下は `host: github` の場合。

1. **PR の準備**：`Status: pr:in-progress` にする。まず、そのブランチの PR が既に存在しないか確認する（`gh pr list --head <branch> --state all`）。中断からの再開で既に作成済みなら、新しく作らずに URL を `## PR` に記録し、`Status: pr:awaiting-review` にして「PR の状況確認」へ進む。
   無ければ、取り返しのつかない操作の前に次を提示する：**ブランチ**・**向き先ブランチ**（ヘッダ表の `Base`）・**PR タイトル**・**PR 本文の下書き**（タイトルと本文はドキュメント言語）。
   - **本文**：リポジトリに PR テンプレート（`.github/pull_request_template.md`・`.github/PULL_REQUEST_TEMPLATE.md`・`docs/pull_request_template.md`・ルートの `pull_request_template.md` など）があれば、その見出しに沿って埋める。無ければ「概要」「方針」「受け入れ条件（対応表の確かめ方と結果）」「検証」を書く。
   - **方針**は、Approach で合意した**結論と理由を 2〜3 行**だけ書く（検討した選択肢・試行錯誤の経緯は書かない。人のレビュアーに「なぜこうしたか」を伝えるためで、検討過程に引っ張らないため）。
   - GitHub 連携なら、本文の末尾に **`Closes #<番号>` を必ず入れ**、作成の直前に issue からチケットを取ってくる（`references/github.md`「チケットを issue から取ってくる」）。変更があったら、PR を作らずに停止し、`references/rollback.md` でフェーズを戻すか尋ねる（実装が変更後のチケットを満たしているとは限らないため）。
   - **context の確認**（1 回だけ、軽く）：この変更が `docs/context/**` の記述と**矛盾する**か（ディレクトリ構成・アーキテクチャ・用語・技術スタックを変えた等）を確かめる。矛盾がある場合だけ、直す箇所を示し、この PR に最小限の修正 commit を足すか尋ねる。矛盾が無ければ何もしない（「context の更新は不要」と一行伝えるだけ）。網羅的に書き足す提案はしない（context は作ったら基本的にそれに準拠して進めるもので、頻繁な更新はコンフリクトの元になるため）。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** このゲートは `gates` の設定や前段の自動通過に関係なく必ず発生する。勝手に push / PR しない。
3. 確認されたら、`Status` は `pr:awaiting-approval` のまま push して PR を作成する（例：`gh pr create --body-file <一時ファイル>`。`--fill` は使わず本文を明示する）。guard hook が登録されていれば、push・PR 作成のたびにユーザーの確認画面が出る。**確認画面で拒否されたら、言い換えて再実行せず、停止して指示を待つ**（SKILL.md のガードレール）。GitHub 連携なら、作成後に issue との紐付けを確かめ（`references/github.md`「PR との紐付け」）、`issue-label.sh <番号> review` を実行する。
4. PR タイトル・向き先・URL を `## PR` に書き、`Status: pr:awaiting-review` にして URL を報告し、停止する。**この時点では `done` にしない。** レビューとマージは人が行うので、flow は待つだけ（flow は PR をマージしない）。ユーザーには、レビューが進んだら（1 人なら CI が通ったら）`/flow dev <ticket-id>` で再開するよう案内する。
5. **PR の状況確認**（`pr:awaiting-review` から再開したとき）：`bash <scripts>/pr-status.sh <PR URL>` を実行する。1 行目が判定、2 行目以降が詳細。`docs/flow.config.yml` の `review.required`（無ければ `true`）と合わせて、次のとおり進む：
   - `merged` → `## PR` に結果を追記し、`Status: done` にする。GitHub 連携なら `references/github.md`「クローズ」に従って issue を閉じる。
   - `approved`（Approve 済み・CI 成功・コンフリクトなし）→ `## PR` に結果を追記し、`Status: done` にする（issue はまだ閉じない）。マージはユーザーが行う。
   - `ready`（Approve は無いが、CI 成功・コンフリクトなし）→
     - `review.required: false` なら `approved` と同じく `done` にし、「マージはご自身で行ってください」と伝える。
     - `review.required: true` なら `pending` と同じ（Approve 待ち）。1 人で開発していて自分の PR を Approve できない場合は、`review.required: false` にできることを伝える。
   - `conflict`（Base とコンフリクト）→ `Status: pr:in-progress` に戻し、`Base` の最新を取り込んで解消する。取り込み方は merge を既定とする（rebase は force push が必要になるため、ユーザーが望んだ場合だけ）。
   - `ci_failing`（CI 失敗）→ `Status: pr:in-progress` に戻し、失敗したチェック（`failing_checks`）のログを確認して（`gh pr checks`・`gh run view --log-failed`）原因を直す。
   - `changes_requested`（修正依頼）→ `Status: pr:in-progress` に戻し、指摘を要約して提示してから対応する。
   - `pending`（未レビュー・CI 実行中など）→ その旨と詳細を伝え、`pr:awaiting-review` のまま停止する。`commented_by` がある（コメントだけのレビュー）場合は内容を示し、対応するかユーザーに尋ねる。
   - `closed`（マージされずにクローズ）→ 報告し、どうするか尋ねる。勝手に `done` にしない。

   `conflict`・`ci_failing`・`changes_requested` への対応はブランチに commit し、`## Implementation Log` に「PR 対応：<判定>」として記録する。push の前に**検証**を行い、変更内容と検証結果を提示して**停止し、確認を得てから push する**。push したら `Status: pr:awaiting-review` に戻して停止する。対応が方針や計画の変更を伴う大きさなら、その場で直さずに停止し、Approach／Implement に戻るかユーザーに尋ねる。

### ローカルのみの場合（`repository.host: none`）

push も PR も無い。Review の後、`Base`（`repository.default_branch`）へローカルでマージして終える。PR が無いので、マージ commit を「このチケットでまとめて入った変更」の記録にする。

1. **マージの準備**：`Status: pr:in-progress` にする。中断からの再開で、ブランチが既に `Base` にマージ済み（`git merge-base --is-ancestor <branch> <Base>`）か削除済みなら、マージ commit を探して「マージの記録」へ進む。そうでなければマージの内容を準備して提示する：**ブランチ**・**マージ先**（`Base`）・取り込む commit の一覧（`git log --oneline <Base>..<branch>`）・実行するコマンド。上の「PR の準備」と同じく **context の確認**も行う。
   - `git switch <Base>` → `git merge --no-ff <branch> -m "Merge <ticket-id>: <チケットのタイトル>"` → `git branch -d <branch>`
   - `Base` に未コミットの変更があれば、先に示して止まる（勝手に stash しない）。
2. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。** マージとブランチの削除は、この 1 回の確認でまとめて承認をもらう（guard hook を登録していれば、Base でのマージの前に確認画面も出る）。
3. 確認されたら実行する。
   - **コンフリクトしたら**自分で解決しない。`git merge --abort` で元に戻し、コンフリクトしたファイルを示して停止し、指示を待つ（`Status` は `pr:awaiting-approval` のまま）。
   - ブランチの削除は `git branch -d`（マージ済みでなければ失敗する安全な削除）だけを使う。`-D` は使わない。
4. **マージの記録**：`## PR` にマージ先・マージ commit の hash・削除したブランチを書き、`Status: done` にして報告する。

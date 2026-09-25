# init モード — プロジェクト初期化

目的：このプロジェクトで `/flow` を使える状態にする。最初に 1 回実行する想定だが、**何度実行しても安全**にする（済んでいる項目は飛ばし、足りない設定だけを足す）。設定を後から追加・修正したいときも再実行してよい。引数は取らない（チケット id が渡されたら無視せず、`/flow new` の案内をする）。

1. 現状を確認する：`docs/context/`・`docs/tickets/`・`docs/flow/` の有無と中身、git リポジトリかどうか、`docs/flow/` が無視されているか（`git check-ignore -q docs/flow/x`）。
   `docs/flow.config.yml` が既にある場合（再実行や、古い init で作った場合）は読み込み、**値があるキーは尋ねずにそのまま使う**。以降の手順は、値が無いキーについてだけ行い、既存のキーは書き換えない。
2. **リポジトリを確認する**（`repository`）：flow はブランチと commit を前提にし、PR は GitHub に出す。ここで決めた `host` によって、チケット管理（手順 6）と dev の Phase 6 の動きが変わる。
   - **git リポジトリでない**：`git init` するか尋ねる（既定ブランチ名は下の「デフォルトブランチ」と同じく尋ねる）。しないなら、flow は使えないことを伝えて init を中止する。
   - **`origin` が GitHub を指している**（`git remote get-url origin` が `github.com`）：`host: github`。`default_branch` は尋ねずに GitHub から読む（`gh repo view --json defaultBranchRef`。`gh` が使えなければ `git symbolic-ref --short refs/remotes/origin/HEAD` の `origin/` を除いたもの。どちらも取れなければ尋ねる）。
   - **GitHub 以外の remote がある**（GitLab など）：v1 の PR 作成は GitHub だけに対応していることを伝え、`host: none`（PR を出さず、ローカルでマージする）で使うか、中止するかを尋ねる。
   - **remote が無い**：AskUserQuestion で「このサービスに GitHub リポジトリは必要か」を尋ねる。
     - **AI と対話して作る** — 下記「リポジトリを作る場合」。
     - **自分で作る** — `gh repo create` か GitHub の画面で作って `git remote add origin <URL>` する手順を示し、ユーザーが済ませるのを待ってから、この手順をもう一度行う。
     - **不要（ローカルのみ）** — `host: none`。デフォルトブランチ（下記 5 と同じ聞き方）だけを尋ねる。チケット管理は `local` に決まる。

   **リポジトリを作る場合**：先に `gh` があることと `gh auth status` を確かめる（無い・未認証なら手順 6 の事前チェックと同じく案内して待つ）。次の項目を**1 つずつ**尋ね、全部決まったら、実行するコマンド（`gh repo create <owner>/<name> --<visibility> --source=. --remote=origin [--description "<説明>"]`）と作るもの（LICENSE を含む）を一覧で示して確認を得てから作る。push はここではせず、手順 12 の commit の後に行う。
   1. **オーナー** — 既定は個人アカウント（`gh api user --jq .login`）。所属 organization（`gh api user/orgs --jq '.[].login'`）を選択肢に加える。
   2. **リポジトリ名** — 既定はリポジトリのルートディレクトリ名。GitHub で使えない文字（英数字・`-`・`_`・`.` 以外）は `-` に置き換えた案を示す。`gh repo view <owner>/<name>` で同名のものが既にあれば、先に伝えて別の名前を尋ねる。
   3. **公開範囲** — 既定は **private**。public・（organization なら）internal から選ぶ。public を選んだら、コードが誰でも見られるようになることを念押しする。
   4. **説明** — 省略可。README の 1 行目があれば候補にする。
   5. **デフォルトブランチ** — 既定は今のブランチ名（commit がまだ無ければ `main`）。今のブランチ名と違う名前が選ばれたら、`git branch -m <新しい名前>` で名前を変えてよいか確認する。
   6. **LICENSE**（public のときだけ。既に LICENSE ファイルがあれば尋ねない）— MIT・Apache-2.0・GPL-3.0・付けない、から選ぶ（その他は自由入力）。「付けない」には、他の人は法的に使えない（全著作権を保持する）ことを添える。著作権者は `git config user.name`、年は今年を既定にして確認する。本文は記憶から書かず、`gh api licenses/<キー>`（例：`mit`）の `body` を使い、年と著作権者の欄を埋める。
   7. **push するか** — 既定は「する」。public のときは、先に `.env`・鍵ファイルなどの秘密情報が git で追跡されていないか確かめ、あれば示して止まる。

   `docs/flow.config.yml` には次の 2 つだけを書く。オーナー・リポジトリ名・公開範囲は書かない（remote と GitHub から分かり、書くと食い違うため）：

   ```yaml
   repository:
     host: github          # github | none（none = ローカルのみ。init の再実行で聞き直さないために書く）
     default_branch: main  # dev の Plan で Base の既定値。host: none では Phase 6 のマージ先
   ```
3. **ドキュメント言語を決める**（`language`）：AskUserQuestion で「日本語（推奨・既定）」「English」を選択肢にして尋ねる（その他はユーザーが自由入力できる）。以降のチケットと `docs/context/**` はこの言語で書く。
4. **検証コマンドを決める**（`commands`）：dev の Implement・Review で Claude が実行する、テスト・lint・型チェックなどのコマンド。
   - 先にプロジェクトから候補を読み取る（`package.json` の scripts、`Makefile`、`justfile`、`Taskfile.yml`、`pyproject.toml`、`Cargo.toml`、`go.mod`、CI 設定（`.github/workflows/*`）など）。CI で実行しているコマンドがあれば優先して候補にする。
   - 候補を出典のファイル付きで示し、どれを使うかをユーザーに確定してもらう。**確認なしに推測のコマンドを書かない。** 足りないものはユーザーに尋ねる。
   - キー名は用途を表す短い名前（`test`・`lint`・`typecheck` など）にする。書いた順に実行する。
   - 検証コマンドが無い（テストが無い等）場合は `commands: {}` と書き、その旨を伝える（dev は検証をスキップして、そのことを記録する）。
   - 新たにラッパー（Makefile 等）は作らない。既存のコマンドをそのまま書く。
5. **commit 規約を決める**（`docs/context/commit.md`。既にあれば読んで使い、尋ねない）：dev の commit はこのファイルに従う。
   - AskUserQuestion で「既存の規約ファイルがある」「無いので作る」を尋ねる。先に `CONTRIBUTING.md`・`commitlint.config.*`・`.gitmessage`・`.github/` 配下などを見て、候補があれば選択肢の説明に含める。
   - **ある場合**：パスを確定し、`Source:` にそのパスを書く。本文はコピーしない（元のファイルとずれるため）。本文欄には、flow 固有の補足（あれば）だけを書く。
   - **無い場合**：`Source:` は空欄にし、同じファイルの本文に規約を書く。直近の `git log` の書式を読んで下書きを提案し、合意したものだけを書く（履歴が無ければ、件名の形式・言語・本文の書き方の最低限を対話で決める）。
   - どちらの場合も、commit メッセージの言語を `Language:` に書く（既存の規約に書かれていればそれに合わせる）。

   テンプレート（見出しと本文はドキュメント言語、`Source:`・`Language:` は英語の固定キー）：

   ```markdown
   # commit 規約

   Source: <既存の規約ファイルのパス。無ければ空欄>
   Language: <commit メッセージの言語>

   <!-- Source が空欄なら、ここに規約本文を書く。
        Source があれば、ここには flow 固有の補足だけを書く（Source と矛盾したら Source を優先する）。 -->
   ```
6. **チケット管理を決める**（`ticket`）：`repository.host` が `none` なら尋ねずに `tracker: local` にする。`github` なら AskUserQuestion で次から選んでもらう。チームで使うなら GitHub を勧める（id が衝突せず、他の人が状況と担当者を見られるため）。
   - **GitHub issue と連携する**（`tracker: github`）— new で issue を作り、issue 番号を id にする。issue にはチケットの全文（バックアップになり、手元から消えても復元できる）・ステータス（ラベル）・担当者を載せる。public リポジトリでは背景や未決事項も公開されることを伝える（`references/github.md`）。
   - **ローカルのみ**（`tracker: local`）— 今までどおり。id はローカルの連番。チケットは実装 PR に入るまで手元にしか無く、消えても復元できない・他の人と共有できないことを伝える（GitHub 連携なら issue から復元できる）。

   `prefix` と `pad` は既定値（`T`・`6`）を書き、変えたければ config を直せばよいことを伝える（既存のチケットがある状態で変えると id の形式が混ざる点も伝える）。
   `github` の場合は（`ticket` が既に設定済みでも、再実行のたびに）`references/github.md` を Read して次を行う：
   1. **事前チェック**（`gh` があること・`gh auth status`・`gh repo view`）。`gh` が無ければインストールを、未認証なら `! gh auth login` の実行を案内し、ユーザーが済ませるのを待ってから確認し直す。どうしても済ませられなければ `local` にするか尋ねる。
   2. **ラベルを作る**：`gh label list` で既存のものを確かめ、無いものだけ（`flow:todo`・`flow:in-progress`・`flow:in-review`）を一覧で示して確認を得てから `gh label create` で作る。
   3. 既存のチケット（`Issue:` 行の無いもの）は issue を作らずそのまま使えることを伝える（issue 化したい場合の自動移行はしない）。
7. 作成するものを一覧で提示してから作る（既にあるものは作らない・上書きしない）：
   - `docs/context/`（中身は手順 8。`commit.md` は手順 5）
   - `docs/context/commit.md`（手順 5 で決めた内容）
   - `docs/tickets/.gitkeep`
   - `LICENSE`（手順 2 で選んだ場合）
   - `docs/flow.config.yml` — 手順 2・3・4・6 で決めた値を書く（既にあれば、足りないキーだけを追記する）。
   - `.gitignore` に `docs/flow/` を追加（既に無視されていれば何もしない。`.gitignore` が無ければ作る）。`docs/flow/` 自体は dev が必要になったときに作るので、ここでは作らない。
8. **context を作る**：`docs/context/` に（手順 5 の `commit.md` 以外の）ファイルが既にある場合は、作り方を尋ねずに既存の内容を読み、足りない点を提案するにとどめる（上書きしない）。無い場合は、AskUserQuestion で作り方を選んでもらう：
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
9. **reviewer agent を確認する**：利用できる agent に `flow-reviewer`（dev の Review で使う）が無ければ、README の導入手順を案内する（init を止める必要はない。dev の Review までに導入すればよい）。
10. **guard hook を登録する**：`scripts/guard.sh`（flow のブランチでの push・PR 作成に必ず確認画面を出し、force push と `Closes` の無い PR を止める hook）は、ユーザー設定 `~/.claude/settings.json` に登録して初めて有効になる。ユーザーの個人設定なので、**ユーザーが選ぶまで `~/.claude/settings.json` を読まない・書かない。** AskUserQuestion で次から選んでもらう：
   - **登録済み** — 何もしない。
   - **自分で追記する** — 下記の JSON と追記先（`~/.claude/settings.json` の `hooks.PreToolUse`。既に `hooks` があれば、その `PreToolUse` 配列に要素を 1 つ足す）を示すだけにする。ファイルは読まない。
   - **AI に任せる** — `~/.claude/settings.json` を読み、既に `guard.sh` が登録されていれば何もしない。無ければ、既存の設定を一切変えずに要素を 1 つ足した結果（差分）を示し、確認を得てから書く。書く前に `~/.claude/settings.json.bak` にバックアップを取る。ファイルが無ければ新しく作る。JSON は手で書き換えず `jq` で組み立て、書いた後に `jq empty` で壊れていないことを確かめる。
   - 後回しにする — 登録しないと push・PR の確認は指示だけで守られる（Claude が確認を飛ばしても止まらない）ことを伝える。

   どれを選んでも、登録は**次に起動するセッションから**有効になることを伝える。

   あわせて `command -v jq` で jq があるか確かめる。無ければインストール（例：`brew install jq`）を案内する。jq が無くても flow と無関係なリポジトリやブランチには影響しないが、flow のブランチでは push・PR 作成かどうかを詳しく判定できず、Bash の push らしいコマンドのたびに確認画面が出る。

   追記する要素：

   ```json
   {
     "matcher": "Bash",
     "hooks": [
       {
         "type": "command",
         "command": "f=\"$HOME/.claude/skills/flow/scripts/guard.sh\"; [ -f \"$f\" ] || f=\"$CLAUDE_PROJECT_DIR/.claude/skills/flow/scripts/guard.sh\"; exec bash \"$f\""
       }
     ]
   }
   ```
11. 作ったものを要約する。対話で作った場合は未決事項を示す。自分で作る場合は、`docs/context/overview.md` を埋めてから `/flow new` に進むよう促す。
12. **commit**：context が完成したら、init で作ったもの（`.gitignore`・`docs/flow.config.yml`・`docs/tickets/.gitkeep`・`docs/context/**`・`LICENSE`）をまとめて commit する。対象ファイルと commit メッセージ（`docs/context/commit.md` の規約に従う）を提示し、確認を得てから commit する。
   - 手順 2 でリポジトリを作り「push する」を選んだ場合だけ、commit の後に `git push -u origin <default_branch>` を行う（実行前にコマンドを示して確認を得る）。それ以外では push しない。
   - 自分で作る場合は、ユーザーが `overview.md` を書き終えてから commit するか、雛形のまま今 commit するかを尋ねる。
   - init が作ったもの以外の変更は commit に含めない。
13. 次の一手として `/flow new` を案内する。

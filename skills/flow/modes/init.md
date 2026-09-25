# init モード — プロジェクト初期化

目的：このプロジェクトで `/flow` を使える状態にする。最初に 1 回実行する想定だが、**何度実行しても安全**にする（済んでいる項目は飛ばし、足りない設定だけを足す）。設定を後から追加・修正したいときも再実行してよい。引数は取らない（チケット id が渡されたら無視せず、`/flow new` の案内をする）。

各手順は太字の名前で参照する（例：「チケット管理」）。

1. **現状の確認**：`docs/context/`・`docs/tickets/`・`docs/flow/` の有無と中身、git リポジトリかどうか、`docs/flow/` が無視されているか（`git check-ignore -q docs/flow/x`）。
   `docs/flow.config.yml` が既にある場合（再実行や、古い init で作った場合）は読み込み、**値があるキーは尋ねずにそのまま使う**。以降の手順は、値が無いキーについてだけ行い、既存のキーは書き換えない。
2. **リポジトリ**（`repository`）：flow はブランチと commit を前提にし、PR は GitHub に出す。ここで決めた `host` によって、「チケット管理」と dev の PR フェーズの動きが変わる。
   - **git リポジトリでない**：`git init` するか尋ねる（既定ブランチ名は下の「デフォルトブランチ」と同じく尋ねる）。しないなら、flow は使えないことを伝えて init を中止する。
   - **`origin` が GitHub を指している**（`git remote get-url origin` が `github.com`）：`host: github`。`default_branch` は尋ねずに GitHub から読む（`gh repo view --json defaultBranchRef`。`gh` が使えなければ `git symbolic-ref --short refs/remotes/origin/HEAD` の `origin/` を除いたもの。どちらも取れなければ尋ねる）。
   - **GitHub 以外の remote がある**（GitLab など）：v1 の PR 作成は GitHub だけに対応していることを伝え、`host: none`（PR を出さず、ローカルでマージする）で使うか、中止するかを尋ねる。
   - **remote が無い**：AskUserQuestion で「このサービスに GitHub リポジトリは必要か」を尋ねる。
     - **AI と対話して作る** — 下記「リポジトリを作る場合」。
     - **自分で作る** — `gh repo create` か GitHub の画面で作って `git remote add origin <URL>` する手順を示し、ユーザーが済ませるのを待ってから、この手順をもう一度行う。
     - **不要（ローカルのみ）** — `host: none`。デフォルトブランチ（下記と同じ聞き方）だけを尋ねる。チケット管理は `local` に決まる。

   **リポジトリを作る場合**：先に `gh` があることと `gh auth status` を確かめる（無い・未認証なら「チケット管理」の事前チェックと同じく案内して待つ）。次の項目を**1 つずつ**尋ね、全部決まったら、実行するコマンド（`gh repo create <owner>/<name> --<visibility> --source=. --remote=origin [--description "<説明>"]`）と作るもの（LICENSE を含む）を一覧で示して確認を得てから作る。push はここではせず、「commit」の後に行う。
   - **オーナー** — 既定は個人アカウント（`gh api user --jq .login`）。所属 organization（`gh api user/orgs --jq '.[].login'`）を選択肢に加える。
   - **リポジトリ名** — 既定はリポジトリのルートディレクトリ名。GitHub で使えない文字（英数字・`-`・`_`・`.` 以外）は `-` に置き換えた案を示す。`gh repo view <owner>/<name>` で同名のものが既にあれば、先に伝えて別の名前を尋ねる。
   - **公開範囲** — 既定は **private**。public・（organization なら）internal から選ぶ。public を選んだら、コードが誰でも見られるようになることを念押しする。
   - **説明** — 省略可。README の 1 行目があれば候補にする。
   - **デフォルトブランチ** — 既定は今のブランチ名（commit がまだ無ければ `main`）。今のブランチ名と違う名前が選ばれたら、`git branch -m <新しい名前>` で名前を変えてよいか確認する。
   - **LICENSE**（public のときだけ。既に LICENSE ファイルがあれば尋ねない）— MIT・Apache-2.0・GPL-3.0・付けない、から選ぶ（その他は自由入力）。「付けない」には、他の人は法的に使えない（全著作権を保持する）ことを添える。著作権者は `git config user.name`、年は今年を既定にして確認する。本文は記憶から書かず、`gh api licenses/<キー>`（例：`mit`）の `body` を使い、年と著作権者の欄を埋める。
   - **push するか** — 既定は「する」。public のときは、先に `.env`・鍵ファイルなどの秘密情報が git で追跡されていないか確かめ、あれば示して止まる。

   `docs/flow.config.yml` には次の 2 つだけを書く。オーナー・リポジトリ名・公開範囲は書かない（remote と GitHub から分かり、書くと食い違うため）：

   ```yaml
   repository:
     host: github          # github | none（none = ローカルのみ。init の再実行で聞き直さないために書く）
     default_branch: main  # dev の Plan で Base の既定値。host: none では PR フェーズのマージ先
   ```
3. **ドキュメント言語**（`language`）：AskUserQuestion で「日本語（推奨・既定）」「English」を選択肢にして尋ねる（その他はユーザーが自由入力できる）。以降のチケットと `docs/context/**` はこの言語で書く。
4. **検証コマンド**（`commands`）：dev の Implement・Review で Claude が実行する、テスト・lint・型チェックなどのコマンド。
   - 先にプロジェクトから候補を読み取る（`package.json` の scripts、`Makefile`、`justfile`、`Taskfile.yml`、`pyproject.toml`、`Cargo.toml`、`go.mod`、CI 設定（`.github/workflows/*`）など）。CI で実行しているコマンドがあれば優先して候補にする。
   - 候補を出典のファイル付きで示し、どれを使うかをユーザーに確定してもらう。**確認なしに推測のコマンドを書かない。** 足りないものはユーザーに尋ねる。
   - キー名は用途を表す短い名前（`test`・`lint`・`typecheck` など）にする。書いた順に実行する。値に ` #` を含むなら `"…"` で囲む（スクリプトがコメントと区別できるように）。
   - 検証コマンドが無い（テストが無い等）場合は `commands: {}` と書き、その旨を伝える（dev は検証をスキップして、そのことを記録する）。
   - 新たにラッパー（Makefile 等）は作らない。既存のコマンドをそのまま書く。
5. **commit 規約**（`docs/context/commit.md`。既にあれば読んで使い、尋ねない）：dev の commit はこのファイルに従う。
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
6. **チケット管理**（`ticket`）：`repository.host` が `none` なら尋ねずに `tracker: local` にする。`github` なら AskUserQuestion で次から選んでもらう。チームで使うなら GitHub を勧める（id が衝突せず、他の人が状況と担当者を見られるため）。
   - **GitHub issue と連携する**（`tracker: github`）— new で issue を作り、issue 番号を id にする。issue が正本で、チケットの全文・ステータス（ラベル）・担当者を載せる。手元の `docs/tickets/` は issue から作る作業用のコピーで、git で管理しない（`.gitignore` に入れる）。public リポジトリでは背景や未決事項も公開されることを伝える（`references/github.md`）。
   - **ローカルのみ**（`tracker: local`）— id はローカルの連番。チケットは git で管理し、実装 PR の最初の commit に入る。それまでは作成者の手元にしか無く、他の人と共有できないことを伝える。

   `prefix` と `pad` は既定値（`T`・`6`）を書き、変えたければ config を直せばよいことを伝える（既存のチケットがある状態で変えると id の形式が混ざる点も伝える）。
   `github` の場合は（`ticket` が既に設定済みでも、再実行のたびに）`references/github.md` を Read して次を行う：
   - **事前チェック**（`gh` があること・`gh auth status`・`gh repo view`）。`gh` が無ければインストールを、未認証なら `! gh auth login` の実行を案内し、ユーザーが済ませるのを待ってから確認し直す。どうしても済ませられなければ `local` にするか尋ねる。
   - **ラベルを作る**：`gh label list` で既存のものを確かめ、無いものだけ（`flow:todo`・`flow:in-progress`・`flow:in-review`・`flow:out-of-sync`）を、意味（`references/github.md`「ラベルと担当者」）と一緒に一覧で示して確認を得てから `gh label create` で作る。
   - **チケットを git の管理から外す**：`docs/tickets/` が `.gitignore` に無ければ、追加を「作るもの」に入れる。既に追跡されているチケット（`git ls-files docs/tickets`）があれば、追跡から外す commit（`git rm --cached docs/tickets/*.md`。手元のファイルは残る）を提案する（旧方式からの移行。`references/github.md`「旧形式からの移行」）。`docs/tickets/.gitkeep` は作らない。
   - 既存のチケットで `Issue:` 行の無いもの（`local` の時代に作ったもの）は issue を作らずそのまま使えることを伝える（issue 化したい場合の自動移行はしない）。
7. **レビューの要否**（`review.required`）：AskUserQuestion で「1 人で開発しますか？」と尋ねる（`host: none` なら PR が無いので尋ねずに書かない）。
   - **1 人** — 既定を `required: false` にする。GitHub では自分の PR を Approve できないため、`true` のままだと PR が完了にならないことを伝える。CI 成功・コンフリクトなしで dev は完了にし、マージはユーザーが行う。
   - **複数人** — 既定を `required: true` にする（Approve 済み・CI 成功・コンフリクトなしで完了）。
   - 人数が変わったら config の値を変えればよいことを伝える。
8. **ゲート**（`gates`）：`gates: [approach, plan, pr]` を書く（尋ねない）。書いたゲートでは必ず止まり、書いていないフェーズは、止まる条件（未解決の疑問・レビュー指摘など）が無ければ自動で通過すること、`pr` は書かなくても必ず止まることを伝える（dev.md「承認ゲート」）。全フェーズで止めたければ `[research, approach, plan, implement, review, pr]` にできる。
9. **作るもの**：一覧で提示してから作る（既にあるものは作らない・上書きしない）：
   - `docs/context/`（中身は「context」。`commit.md` は「commit 規約」）
   - `docs/context/commit.md`（「commit 規約」で決めた内容）
   - `docs/tickets/.gitkeep`（`local` のときだけ）
   - `LICENSE`（「リポジトリ」で選んだ場合）
   - `docs/flow.config.yml` — 「リポジトリ」「ドキュメント言語」「検証コマンド」「チケット管理」「レビューの要否」「ゲート」で決めた値を書く（既にあれば、足りないキーだけを追記する）。
   - `.gitignore` に `docs/flow/` を追加（`github` なら `docs/tickets/` も。既に無視されていれば何もしない。`.gitignore` が無ければ作る）。`docs/flow/` 自体は dev が必要になったときに作るので、ここでは作らない。
10. **context**：`docs/context/` に（`commit.md` 以外の）ファイルが既にある場合は、作り方を尋ねずに既存の内容を読み、足りない点を提案するにとどめる（上書きしない）。無い場合は、AskUserQuestion で作り方を選んでもらう：
    - **対話で作る** — 下記「対話で作る場合」の手順で、各項目の内容をユーザーと一緒に決めて `docs/context/overview.md` を書く。
    - **自分で作る** — 下記テンプレートの見出しと記入ガイドだけを入れた `docs/context/overview.md` を作り、中身はユーザーが書く。こちらからは内容を埋めない。

    **対話で作る場合：**
    - 先にコードベース（README、パッケージ定義、ディレクトリ構成、主要なエントリポイントなど）を読み、各項目についてコードから読み取れる事実を集めておく。質問を具体的にし、答えの候補を示すためであり、読み取った内容をそのまま書くためではない。
    - テンプレートの項目を**1 つずつ**進める。項目ごとに、コードから読み取れた事実（出典のファイルを示す）と、分からない点・コードからは判断できない点を示し、ユーザーに質問する。特に「サービスの目的」と「主要なドメイン概念」はコードからは決めきれないので、ユーザーの言葉で決めてもらう。
    - その項目の文面を提示し、ユーザーが合意してから次の項目へ進む。**合意していない内容は書かない。** コードからの推測をユーザーの確認なしに事実として書かない。
    - その場で決まらない点は削らず「未決事項」に残す。ユーザーが「推測のままでよい」とした記述には `（推測）` を付ける。
    - 全項目が決まったら全体を提示し、最終確認を得てからファイルに書く。

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
11. **CLAUDE.md**：`/flow` を起動していないセッションでも context を読めるように、`CLAUDE.md` から `docs/context/overview.md` を取り込む。
    - まずリポジトリのルートに `CLAUDE.md` があるか、既に `@docs/context/overview.md` を含むかを確かめる。含んでいれば何もしない。
    - AskUserQuestion で、取り込むかを尋ねる（「取り込む（推奨）」「取り込まない」）。
    - **取り込む・`CLAUDE.md` が無い** — 次の内容で新しく作る（見出しはドキュメント言語）。
      ```markdown
      # プロジェクトの context

      @docs/context/overview.md
      ```
    - **取り込む・`CLAUDE.md` がある** — 既存の内容は一切変えず、**末尾に**上の見出しと `@docs/context/overview.md` の行を追記する。追記する差分を示し、確認を得てから書く（上書きはしない）。
    - **取り込まない** — 何もしない。
12. **PR テンプレート**（`host: github` のときだけ）：dev の PR フェーズは、PR テンプレートがあればその見出しに沿って本文を書く。
    - まずテンプレートがあるか確かめる（`.github/pull_request_template.md`・`.github/PULL_REQUEST_TEMPLATE.md`・`.github/PULL_REQUEST_TEMPLATE/`・`docs/pull_request_template.md`・ルートの `pull_request_template.md`）。
    - AskUserQuestion で、flow 用の項目を入れるかを尋ねる（「入れる（推奨）」「入れない」）。flow 用の項目は `${CLAUDE_SKILL_DIR}/templates/pull_request_template.md`（概要・方針・受け入れ条件・検証・関連。見出しとコメントはドキュメント言語に訳す）。
    - **入れる・無い** — `.github/pull_request_template.md` として新しく作る。
    - **入れる・ある** — 既存の内容は一切変えず、既存のテンプレートに**無い見出しだけ**を末尾に追記する。追記する差分を示し、確認を得てから書く（上書きはしない）。
    - **入れない** — 何もしない。
13. **GitHub Actions**（`tracker: github` のときだけ。`references/github.md`「GitHub Actions」）：ローカルで `/flow` を実行しなくても issue の状態がずれないように、サーバー側の workflow を入れるか尋ねる。AskUserQuestion（複数選択）で、既に `.github/workflows/` にあるものを除いて尋ねる：
    - **`flow-issue-sync`（推奨）** — PR が開いたら issue を `flow:in-review` に、マージされたら閉じる。
    - **`flow-pr-link`（推奨）** — `<id>-` ブランチの PR に `Closes #<番号>` があるかを検査する。必須チェックにする場合は、ユーザーがブランチ保護で設定する（flow は設定しない）ことを伝える。
    - **`flow-issue-guard`（推奨）** — issue が GitHub 上で直接編集されたら `flow:out-of-sync` を付ける。`${CLAUDE_SKILL_DIR}/scripts/ticket-hash.sh` を `.github/flow/ticket-hash.sh` にもコピーする。
    - 選ばれたものを `${CLAUDE_SKILL_DIR}/templates/github/` から `.github/workflows/` にそのままコピーする（内容は変えない）。作るファイルを一覧で示し、確認を得てから作る。flow を更新しても、コピーした workflow は自動では更新されないことを伝える。
14. **CI**（`host: github` で `commands` が `{}` でないときだけ）：`.github/workflows/` に、検証コマンドを実行している workflow が無ければ、作るか尋ねる。CI と dev の検証を同じ内容に揃えるため。
    - 作るなら `${CLAUDE_SKILL_DIR}/templates/github/flow-ci.yml` を下敷きにして、ユーザーと一緒に埋める：`__DEFAULT_BRANCH__` は `repository.default_branch`、`__COMMANDS__` は `commands` を書いた順に 1 ステップずつ、`__SETUP__`（言語のセットアップ・依存のインストール）はプロジェクトのファイル（`package.json` のロックファイル・`.nvmrc`・`pyproject.toml`・`go.mod` など）から候補を作って確認する。**確認していないセットアップ手順を推測で書かない。**
    - 全文を示し、確認を得てから `.github/workflows/flow-ci.yml` に書く。
15. **reviewer agent**：利用できる agent に `flow-reviewer` と `flow-quality-reviewer`（dev の Review で使う）が無ければ、README の導入手順を案内する（init を止める必要はない。dev の Review までに導入すればよい）。
16. **hook の登録**：次の 2 つの hook は、ユーザー設定 `~/.claude/settings.json` に登録して初めて有効になる。ユーザーの個人設定なので、**ユーザーが選ぶまで `~/.claude/settings.json` を読まない・書かない。**
    - `scripts/guard.sh`（PreToolUse）— flow のブランチと Base での push・PR 作成・許可リスト外の git / gh 操作・GitHub MCP の書き込みに確認画面を出し、force push と `Closes` の無い PR を止める。Plan の承認前に `docs/` 以外を編集しようとしたときも確認画面を出す。
    - `scripts/session-start.sh`（SessionStart）— 会話の要約・再開の後に、進行中の run と読み直すファイルを伝える。

    AskUserQuestion で次から選んでもらう：
    - **登録済み** — 何もしない。
    - **自分で追記する** — 下記の JSON と追記先（`~/.claude/settings.json` の `hooks.PreToolUse` と `hooks.SessionStart`。既にあれば、その配列に要素を 1 つずつ足す）を示すだけにする。ファイルは読まない。
    - **AI に任せる** — `~/.claude/settings.json` を読む。既に `guard.sh` が `"matcher": "Bash"` で登録されていれば（古い登録）、matcher を下記に変える差分を示す。`session-start.sh` が無ければ足す。それ以外の設定は一切変えずに、結果（差分）を示し、確認を得てから書く。書く前に `~/.claude/settings.json.bak` にバックアップを取る。ファイルが無ければ新しく作る。JSON は手で書き換えず `jq` で組み立て、書いた後に `jq empty` で壊れていないことを確かめる。
    - **後回しにする** — 登録しないと push・PR・マージの確認は指示だけで守られる（Claude が確認を飛ばしても止まらない）ことを伝える。

    どれを選んでも、登録は**次に起動するセッションから**有効になることを伝える。

    あわせて `command -v jq` で jq があるか確かめる。無ければインストール（例：`brew install jq`）を案内する。jq が無くても flow と無関係なリポジトリやブランチには影響しないが、flow のブランチでは push・PR 作成かどうかを詳しく判定できず、Bash の push らしいコマンドのたびに確認画面が出る。許可リスト・MCP・編集の判定は jq が無いと行わない。

    追記する要素（`f=…` は、個人スキル（`~/.claude/skills/flow`）とプロジェクトのスキル（`.claude/skills/flow`）のどちらでも動くようにするため）：

    ```json
    {
      "hooks": {
        "PreToolUse": [
          {
            "matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__.*",
            "hooks": [
              {
                "type": "command",
                "command": "f=\"$HOME/.claude/skills/flow/scripts/guard.sh\"; [ -f \"$f\" ] || f=\"$CLAUDE_PROJECT_DIR/.claude/skills/flow/scripts/guard.sh\"; exec bash \"$f\""
              }
            ]
          }
        ],
        "SessionStart": [
          {
            "matcher": "compact|resume",
            "hooks": [
              {
                "type": "command",
                "command": "f=\"$HOME/.claude/skills/flow/scripts/session-start.sh\"; [ -f \"$f\" ] || f=\"$CLAUDE_PROJECT_DIR/.claude/skills/flow/scripts/session-start.sh\"; exec bash \"$f\""
              }
            ]
          }
        ]
      }
    }
    ```
17. **まとめ**：作ったものを要約する。対話で作った場合は未決事項を示す。自分で作る場合は、`docs/context/overview.md` を埋めてから `/flow new` に進むよう促す。
18. **commit**：context が完成したら、init で作ったもの・変えたもの（`.gitignore`・`docs/flow.config.yml`・`docs/tickets/.gitkeep`・`docs/context/**`・`LICENSE`・`CLAUDE.md`・PR テンプレート・`.github/workflows/flow-*.yml`・`.github/flow/ticket-hash.sh`・「チケット管理」で追跡から外したチケット）をまとめて commit する。対象ファイルと commit メッセージ（`docs/context/commit.md` の規約に従う）を提示し、確認を得てから commit する。
    - 「リポジトリ」でリポジトリを作り「push する」を選んだ場合だけ、commit の後に `git push -u origin <default_branch>` を行う（実行前にコマンドを示して確認を得る）。それ以外では push しない。
    - 自分で作る場合は、ユーザーが `overview.md` を書き終えてから commit するか、雛形のまま今 commit するかを尋ねる。
    - init が作ったもの以外の変更は commit に含めない。
19. 次の一手として `/flow new` を案内する。

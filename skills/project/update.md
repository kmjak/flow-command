# /tixforge:project update — 設定とテンプレートの更新

目的：init の後に、既にある設定の値を変える・チケット管理を切り替える・プロジェクトにコピーしたテンプレートを最新にする。init は足りない設定を足すだけで既存の値を変えないので、変えるときはこちらを使う。

`.tixforge/config.yml` が無ければ、`/tixforge:project init` を案内して止まる。

1. **何を更新するか**を AskUserQuestion で尋ねる（単一選択。引数で指定されていればそれに従う）：
   - **設定の値を変える**
   - **チケット管理を切り替える**（`LT-` ↔ `GT-`）
   - **テンプレートと Actions を最新にする**
2. 選んだものの手順（下記）に進む。どれも、変える内容を差分で示し、確認を得てから書く。書いたファイルは commit しない（一覧で示し、commit するかはユーザーに任せる。commit するなら `docs/context/commit.md` の規約に従う）。

## 設定の値を変える

- 今の `.tixforge/config.yml` を示し、何を変えたいか尋ねる。キーの意味は共通規約の設定の例を使って説明する。
- 値の決め方と確かめ方は init の同じ手順に揃える（init の手順ファイル `${CLAUDE_SKILL_DIR}/init.md` の該当手順を Read する）：
  - `repository.base_branch`・`close_issues` → 「ブランチ運用」。develop に変えるのに develop が無ければ、作るか尋ねる（`git branch develop <今の base_branch>`。push はコマンドを示して確認を得てから）。進行中の run（`state.md` の `Base`）は変わらないことを伝える。
  - `commands` → 「検証コマンド」（値は全体を囲むか囲まないか）。
  - `review.required` → 人数に合わせる（1 人なら `false`）。
  - `language`・`gates` → そのまま書き換える。
  - `repository.host` を `none` ↔ `github` に変える → 「リポジトリ」の手順で確かめ直す。
- `ticket.tracker` はここでは変えない（下の「チケット管理を切り替える」へ）。

## チケット管理を切り替える

チケットの扱いは id の接頭辞で決まるので、切り替えても**既存のチケットはそのまま使える**（`LT-` は手元のファイル、`GT-` は issue のまま）。変わるのは、この後 create が作る種類だけ。

- **ローカル → GitHub**（`tracker: local` → `github`）：
  1. `host: github` であることを確かめる（`none` なら先に「設定の値を変える」でリポジトリを設定する）。`bash <scripts>/github-preflight.sh`。
  2. init の「チケット管理」の `tracker: github` の手順（ラベル・issue フォーム）と「GitHub Actions」を行う。
  3. 完了していない `LT-` のチケット（`Status: canceled` が無く、`state.md` が無いか `done`・`canceled` 以外）を一覧で示し、**issue にするか**を 1 枚ずつ尋ねる（既定は「このまま `LT-` で続ける」）。進行中の run がある `LT-` は、run の途中で id を変えられないので、このまま続けることを伝える（選択肢に出さない）。
     - issue にするなら：`references/github/create.md` を Read し、そのチケットの内容で `issue-sync.sh create <LT- の ticket.md>` を実行する（新しい `GT-` の id になる）。元の `LT-` のチケットのヘッダに `Status: canceled` と `Reason: <GT-id> に移した` を書き足す（`LT-` はファイルが正本なので、ここに記録する）。
  4. `ticket.tracker: github` に書き換える。
- **GitHub → ローカル**（`tracker: github` → `local`）：既存の `GT-` のチケットは issue が正本のまま（edit・dev・cancel は今までどおり GitHub を使う）。以後 create は `LT-` を作る。`LT-` は手元にしか無く、他の人と共有できないことを伝えてから `ticket.tracker: local` に書き換える。

## テンプレートと Actions を最新にする

plugin を更新しても、プロジェクトにコピーしたファイルは自動では変わらない。plugin 側と比べて、古いものを更新する。

| プロジェクトのファイル | plugin 側 | 比べ方 |
|------------------------|-----------|--------|
| `.github/workflows/tixforge-issue-sync.yml`・`tixforge-pr-link.yml`・`tixforge-issue-guard.yml` | `<plugin>/templates/github/` の同名ファイル | 先頭のコメントのバージョン（`(v2)` など）と内容 |
| `.github/tixforge/ticket-hash.sh`・`messages.yml` | `<scripts>/` の同名ファイル | 内容（ハッシュの計算方法がずれると、直接編集の誤検知になる） |
| `.github/ISSUE_TEMPLATE/tixforge-ticket.yml` | `<plugin>/templates/github/ISSUE_TEMPLATE/` | バージョン（訳した見出しはプロジェクト側を保つ） |
| `.github/workflows/tixforge-ci.yml` | `<plugin>/templates/github/tixforge-ci.yml` | バージョンだけ。中身はプロジェクトに合わせて埋めたものなので置き換えない。雛形の変更点（差分）を示し、取り込むか尋ねる |

- 違うものを一覧で示し（ファイルごとに差分）、置き換えるものを選んでもらってから書く。同じものは「最新」と伝える。
- `tracker: github` で、`issue-label.sh setup` を実行して足りないラベルを作る（新しい版で増えたラベルのため）。
- プロジェクトに無いファイルは作らない（入れたいなら init の「GitHub Actions」を案内する）。

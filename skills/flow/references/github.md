# GitHub issue 連携（`ticket.tracker: github`）

`docs/flow.config.yml` の `ticket.tracker` が `github` のときだけ読む。`local` のときは読まず、ここに書いた操作もしない。

## 方針

- **正本は issue。** 手元の `docs/tickets/<ticket-id>.md` は、issue から作る**作業用のコピー**で、git で管理しない（`.gitignore` に `docs/tickets/` を入れる）。チケットを commit しないので、ブランチごとにチケットの有無が食い違うことがなく、PR にもチケットは入らない。PR と issue は `Closes #<番号>` で結ぶ。
- issue の本文には**チケットの全セクションをそのまま**載せる（背景・要件・受け入れ条件・対象外・未決事項）と、flow が書いたことを確かめるための**ハッシュ**（`<!-- flow:hash:… -->`）を載せる。
- dev・edit・cancel は、始めるたびに issue から手元のコピーを作り直す（下記「チケットを issue から取ってくる」）。手元と issue が違えば、常に issue を採用する。
- チケットの内容を変えるのは **`/flow edit` だけ**。edit は issue から取ってきたコピーを書き換えて、すぐ issue に書き戻す。**issue の本文とタイトルを GitHub 上で直接編集しない**（本文の冒頭で告知する）。
  - 直接編集されると、ハッシュが合わなくなる。flow は取ってくるときにこれを検知して（`edited`）、差分を示して取り込むか尋ねる。Actions（`flow-issue-guard`）を入れていれば、編集した時点で `flow:out-of-sync` ラベルとコメントが付く。
- **コメントは自由**で、flow はコメントを編集・削除しない。flow が投稿するコメントは、cancel・reset のときの判断の記録（下記）と、クローズのときの一言だけ。
- 載せるのは、チケットの全文・ステータス（ラベル）・担当者（assignee）・上記のコメントだけ。flow 状態（`main.md`）は載せない。
- flow が issue に対して行う操作は、下記の「作成」「チケットを issue から取ってくる」「本文の同期」「ラベルと担当者」「判断の記録」「クローズ」だけ。PR に対しては、dev の PR フェーズの作成・本文の修正と、reset・cancel でユーザーが選んだときのクローズ（`gh pr close`）だけ。それ以外（他人のコメントの編集、他の issue の操作など）はしない。

## スクリプト

issue の読み書きは次のスクリプトで行い、`gh issue edit` などを手で組み立てない（本文を一字も変えずに写す・改行を揃える・ハッシュを計算する、を確実に行うため）。

| コマンド | 内容 |
|----------|------|
| `issue-sync.sh create <ファイル>` | チケットの下書きから issue を作る（`flow:todo`）。`number:` と `url:` を出力する |
| `issue-sync.sh check <番号>` | 1 行目に判定（`in-sync`・`edited`・`no-hash`・`no-markers`）、以降に `title`・`state`・`state_reason`・`labels` |
| `issue-sync.sh pull <番号> <ファイル> [--accept-edited] [--dry-run]` | issue から手元のコピーを作り直し、差分を出力する（`created`・`unchanged`・unified diff）。`edited` の issue は `--accept-edited` が無いと拒否する（終了コード 4）。`--dry-run` は書かずに差分だけを出す |
| `issue-sync.sh push <番号> <ファイル> [--force]` | 手元のコピーで issue のタイトルと本文を書き換え、ハッシュを付け直す。`flow:out-of-sync` があれば外す。`edited`・`no-markers` の issue は `--force` が無いと拒否する（終了コード 4・3） |
| `issue-label.sh <番号> start [--force]` | `flow:in-progress` にし、assignee に自分を追加。他の人が assign されていたら拒否する（終了コード 4）。閉じていたら拒否する（終了コード 3） |
| `issue-label.sh <番号> review` | `flow:in-review` にする |
| `issue-label.sh <番号> reset` | `flow:todo` に戻し、assignee から自分を外す |

`check` の判定：

| 判定 | 意味 |
|------|------|
| `in-sync` | 本文のハッシュが、タイトルとチケットの内容に一致する（flow だけが書いた） |
| `edited` | 一致しない：GitHub 上でタイトルか本文が直接編集された |
| `no-hash` | 目印はあるがハッシュが無い（ハッシュを入れる前に作った issue）。`in-sync` と同じに扱い、次の push でハッシュが付く |
| `no-markers` | 目印（`<!-- flow:ticket:start -->`・`<!-- flow:ticket:end -->`）が無い：本文が直接編集されて壊れたか、全文を載せる前の形式の issue |

## 番号と id の変換

- id → issue 番号は `ticket-id.sh number <id>`（手で変換しない）。
- 変換した番号は、チケットの `Issue: #<番号>` の行と一致することを確かめてから使う。一致しなければ停止して尋ねる。

## 事前チェック（どのモードでも最初に行う）

1. `gh auth status` が成功すること。失敗したら停止し、ユーザーに `! gh auth login` の実行を案内する（対話式のため Claude は実行できない）。
2. `gh repo view --json nameWithOwner` でリポジトリを特定できること。できなければ停止して状況を伝える。

## 作成（new）

1. 合意したチケットの下書き（タイトル行は `# <ticket-id>: <タイトル>` のまま）を一時ファイルに書き、`issue-sync.sh create <一時ファイル>` を実行する。タイトルはチケットのタイトル（id は付けない。番号は issue 自体が持つ）。
2. 出力の `number:` から `ticket-id.sh normalize <番号>` で id を作る。
3. `issue-sync.sh pull <番号> docs/tickets/<ticket-id>.md` で手元のコピーを作る（issue から作るので、手元と issue は必ず一致する）。

## チケットを issue から取ってくる（dev・edit・cancel・PR 作成の直前）

1. `issue-sync.sh check <番号>` を実行する。issue が閉じていれば（`state: CLOSED`）、各モードの定めに従う（取ってくるのは cancel の確認などに必要な場合だけ）。
2. 判定ごとに進む：
   - **`in-sync`・`no-hash`** → `issue-sync.sh pull <番号> docs/tickets/<ticket-id>.md`。出力が `unchanged` 以外なら、何が変わったかをユーザーに一行で伝え、呼び出し元に「変更あり」として返す（進行中の run があれば、呼び出し元が `references/rollback.md` でフェーズを戻すか判断する）。
   - **`edited`**（GitHub 上で直接編集された。`flow:out-of-sync` が付いていることが多い）→ 取り込む前に `issue-sync.sh pull <番号> <ファイル> --accept-edited --dry-run` の差分を示し、AskUserQuestion で尋ねる：
     - **取り込む（推奨）** — `pull … --accept-edited` で手元を作り直し、`push <番号> <ファイル> --force` でハッシュを付け直す（`flow:out-of-sync` も外れる）。以降は「変更あり」として扱う。
     - **直接編集を取り消す** — 手元のコピーがあるときだけ出す。`push <番号> <ファイル> --force` で手元の内容に戻す。
     - **止める** — 何もせずに止める（直接編集した人に確認する）。
   - **`no-markers`** → issue の本文をそのまま示し、取り込まない。手元のコピーがあれば「手元の内容で issue を上書きする（`push --force`。目印とハッシュも戻る）」／「止める」を尋ねる。手元に無ければ止まり、全文を載せる前の形式の issue なら、本文にある「要件」「受け入れ条件」だけでチケットを組み立てて示し、確認を得てから `push --force` で issue を全文の形式に揃えることを提案する。
3. 手元のコピーは commit しない（git 管理外）。

## 本文の同期（手元 → issue）

- `/flow edit` でチケットを書き換えた直後に `issue-sync.sh push <番号> docs/tickets/<ticket-id>.md` を行う。edit は開始時に issue から取ってきているので、通常は拒否されない。拒否された（`edited`：編集中に GitHub 上で変更された）ら、上の `edited` と同じく差分を示して尋ねる。
- それ以外のときに手元から issue を書き換えない（取り込み・直接編集の取り消しで `push --force` するときを除く）。

## ラベルと担当者

| flow の時点 | ラベル | その他 |
|-------------|--------|--------|
| new で作成 | `flow:todo` | — |
| dev の開始（状態ファイルを新しく作るとき） | `flow:in-progress`（`issue-label.sh <番号> start`） | assignee に自分を追加 |
| PR を作成（`pr:awaiting-review`） | `flow:in-review`（`issue-label.sh <番号> review`） | Actions の `flow-issue-sync` も付ける |
| `done` | ラベルはそのまま | issue を閉じる（下記「クローズ」） |
| `/flow reset` | `flow:todo`（`issue-label.sh <番号> reset`） | assignee から自分を外す。判断の記録をコメントする |
| `/flow cancel` | ラベルはそのまま | `gh issue close <番号> --reason "not planned" --comment "Canceled by /flow: <理由>"`（削除はしない）。判断の記録をコメントする |
| GitHub 上で直接編集された | `flow:out-of-sync`（Actions の `flow-issue-guard` が付ける） | flow が取り込み／取り消しで同期し直すと外れる |

ラベルの意味：

| ラベル | 意味 |
|--------|------|
| `flow:todo` | チケットはあるが、誰も dev を始めていない |
| `flow:in-progress` | 誰か（assignee）が dev を進めている |
| `flow:in-review` | PR が出ていて、レビュー・マージ待ち |
| `flow:out-of-sync` | 本文かタイトルが GitHub 上で直接編集され、flow が書いた内容とずれている。次の dev・edit で差分を確認して解消する |

- `issue-label.sh start` が終了コード 4（他の人が assign されている）を返したら停止し、そのまま進めるかユーザーに尋ねる（進めるなら `--force`）。終了コード 3（閉じている）なら停止して尋ねる（勝手に開き直さない）。
- ラベルが見つからないエラーになったら、`/flow init` の再実行でラベルを作れることを伝える。
- 操作したら、スクリプトが出力した一行（例：「#123 を flow:in-progress にし、assignee に自分を追加」）をユーザーに伝える。

## 判断の記録（cancel・reset）

cancel・reset で、`main.md` の `## Approach` が書かれている run を捨てるときは、「何をしようとして、なぜやめたか」を issue のコメントに残す。後で同じチケットをやり直す人（自分を含む）が、前の方針とやめた理由を知るため。検討の過程は書かず、結論と理由だけにする。

```markdown
**/flow <cancel | reset>**（<YYYY-MM-DD>）

- 方針：<Approach の採用案を 1〜3 行で>
- やめた理由：<ユーザーから聞いた理由>
- 到達したフェーズ：<Status>（ブランチ <Branch>。<残した／削除した>）
```

投稿する内容は、他の操作と同じ一覧でユーザーに示して確認を得てから `gh issue comment <番号> --body-file <一時ファイル>` で投稿する。

## PR との紐付け（dev の PR フェーズ）

- チケットに `Issue: #<番号>` があれば、PR 本文の末尾に **`Closes #<番号>` を必ず入れる**。PR の下書きを提示する時点で入っていること。
- PR を作成した後、紐付けを確かめる：
  - `Base` がリモートのデフォルトブランチなら、`gh pr view <PR> --json closingIssuesReferences` にその番号が含まれることを確認する。含まれなければ PR 本文を直して（`gh pr edit`）もう一度確認する。
  - `Base` がデフォルトブランチ以外なら、GitHub は `Closes` で issue を自動では閉じない。本文に `Closes #<番号>` が入っていることだけ確認し、マージ後に閉じられること（Actions の `flow-issue-sync` があればマージ時に、無ければ `/flow dev` の再開時に flow が閉じる）をユーザーに伝える。

## クローズ

- `pr-status.sh` の判定が `merged` で `done` にするとき：issue がまだ開いていれば、`gh issue close <番号> --comment "Closed by /flow: <PR URL> merged"` で閉じる。
- 判定が `approved`・`ready`（まだマージされていない）で `done` にするとき：issue は閉じない。デフォルトブランチ向けならマージ時に自動で閉じる。そうでなければ、Actions の `flow-issue-sync` が閉じるか、マージ後に `/flow dev <ticket-id>` で再開すると閉じられることを伝える。
- `done` の run を再開したとき：issue が開いたままで PR がマージ済みなら、閉じるか尋ねる。

## GitHub Actions（任意。`/flow init` で入れるか尋ねる）

ローカルの flow は誰かが `/flow` を実行したときにしか動かないので、サーバー側で次の workflow を動かす。雛形は `<skill>/templates/github/`（init が対象プロジェクトの `.github/` にコピーする）。

| workflow | 起動するイベント | 内容 |
|----------|------------------|------|
| `flow-issue-sync.yml` | PR の作成・再オープン・ready for review・クローズ | 本文の `Closes #N` の issue（`flow:*` ラベル付きのものだけ）を `flow:in-review` にする。マージされたら（Base がデフォルトブランチでなくても）閉じる |
| `flow-pr-link.yml` | PR の作成・編集・push | ブランチが `<prefix><番号>-` で始まる PR の本文に `Closes #<番号>` があるかを検査する。ブランチ保護で必須チェックにすれば、ローカルの guard を迂回されても防げる |
| `flow-issue-guard.yml` | `issues: edited` | 下記 |

**`issues: edited` とは**：GitHub Actions の起動条件で、誰かが GitHub 上で issue の**タイトルか本文を編集した**ときに発生するイベント（flow の `Status` ではない）。flow 自身の `issue-sync.sh push` でも発生する。`flow-issue-guard` はそのたびに本文のハッシュを計算し直し：

- 一致しない（直接編集された、または目印が壊れた）→ `flow:out-of-sync` を付け、コメントを 1 回だけ付ける。
- 一致する（flow が同期した）→ `flow:out-of-sync` が付いていれば外す。

ハッシュの計算は、ローカルと同じ `ticket-hash.sh` を `.github/flow/ticket-hash.sh` にコピーして使う（計算方法が食い違うと誤検知するため）。雛形の先頭のコメントにバージョン（`v1`）がある。flow を更新しても、各プロジェクトにコピーした workflow は自動では更新されない。

## 旧形式からの移行

- **チケットを git で管理していた**（この方式にする前の GitHub 連携）：`/flow init` の再実行で、`.gitignore` に `docs/tickets/` を足し、追跡中のチケットを追跡から外す commit（`git rm --cached`。手元のファイルは残る）を提案する。
- **ハッシュの無い issue**（`no-hash`）：そのまま使える。次の同期でハッシュが付く。
- **全文を載せる前の形式の issue**（`no-markers`）：上記「チケットを issue から取ってくる」の `no-markers` のとおり。

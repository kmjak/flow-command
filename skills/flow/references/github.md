# GitHub issue 連携（`ticket.tracker: github`）

`docs/flow.config.yml` の `ticket.tracker` が `github` のときだけ読む。`local` のときは読まず、ここに書いた操作もしない。

## 方針

- **正本はローカルのチケット（`docs/tickets/<ticket-id>.md`）。** issue はチケットから生成する一方通行の写しで、issue から チケットへは何も取り込まない。
- issue に載せるのは、チケットの「要件」「受け入れ条件」と、ステータス（ラベル）・担当者（assignee）だけ。背景・対象外・未決事項・flow 状態（`main.md`）は載せない。
- issue の**本文**は flow が上書きする。人が編集しても次の同期で消える（本文の冒頭でそう告知する）。**コメントは自由**で、flow はコメントを編集・削除しない。
- flow が issue に対して行う操作は、下記の「作成」「本文の同期」「ラベルの付け替え」「assignee の設定」「クローズ」だけ。PR に対しては、Phase 6 の作成・本文の修正と、reset・cancel でユーザーが選んだときのクローズ（`gh pr close`）だけ。それ以外（他人のコメントの編集、タイトル以外のメタデータの変更、他の issue の操作など）はしない。

## 番号と id の変換

- id → issue 番号：id から接頭辞（`ticket.prefix`）を取り除き、残りを **10 進数の文字列として**先頭の `0` を取り除く（`T000123` → `123`）。
- **シェルの算術式に 0 埋めの数字をそのまま渡さない。** `$((000123))` は 8 進数と解釈されて `83` になり、別の issue を操作してしまう。算術が必要なら `$((10#000123))` と書く。
- 変換した番号は、チケットの `Issue: #<番号>` の行と一致することを確かめてから使う。一致しなければ停止して尋ねる。

## 事前チェック（new・dev の冒頭で行う）

1. `gh auth status` が成功すること。失敗したら停止し、ユーザーに `! gh auth login` の実行を案内する（対話式のため Claude は実行できない）。
2. `gh repo view --json nameWithOwner` でリポジトリを特定できること。できなければ停止して状況を伝える。

## 作成（new）

- タイトルはチケットのタイトル（id は付けない。番号は issue 自体が持つ）。
- 本文は下記テンプレートで、チケットの「要件」「受け入れ条件」を**そのままコピー**する（要約や言い換えをしない。同期のたびに文面が揺れないようにするため）。
- ラベル `flow:todo` を付ける。
- 例：`gh issue create --title "<タイトル>" --body-file <一時ファイル> --label flow:todo`。出力の URL から番号を得る。

本文テンプレート（見出しと告知文はドキュメント言語に訳して使う）：

```markdown
> [!NOTE]
> この issue は `/flow` がリポジトリの `docs/tickets/` のチケットから自動生成しています。本文を直接編集しないでください（次の同期で上書きされます）。議論はコメントでどうぞ。

## 要件
<チケットの「要件」をそのまま>

## 受け入れ条件
<チケットの「受け入れ条件」をそのまま>
```

## 本文の同期

チケットから本文を生成し直し、`gh issue view <番号> --json body` の本文と違えば `gh issue edit <番号> --body-file <一時ファイル>` で置き換える。同じなら何もしない。タイトルが違えばタイトルも更新する。

同期するタイミング：
- edit でチケットを編集したとき
- dev の開始時（新規・再開とも）
- Phase 6 で PR を作成する直前

## ステータス（ラベル）と担当者

| flow の時点 | ラベル | その他 |
|-------------|--------|--------|
| new で作成 | `flow:todo` | — |
| dev の開始（状態ファイルを新しく作るとき） | `flow:in-progress` | assignee に自分（`@me`）を追加 |
| Phase 6 で PR を作成（`pr:awaiting-review`） | `flow:in-review` | — |
| `done` | ラベルはそのまま | issue を閉じる（下記「クローズ」） |
| `/flow reset` | `flow:todo` に戻す | assignee から自分を外す（`gh issue edit <番号> --remove-assignee @me`） |
| `/flow cancel` | ラベルはそのまま | `gh issue close <番号> --reason "not planned" --comment "Canceled by /flow: <理由>"`（削除はしない） |

- 付け替えるときは、`gh issue view <番号> --json labels,assignees,state` で現在の値を確かめ、**付いている** `flow:*` ラベルだけを外して新しいものを付ける（`gh issue edit <番号> --remove-label <旧> --add-label <新>`）。
- **dev の開始時に、自分以外の assignee が付いていたら停止する。** 他の人が着手している可能性があるため、そのまま進めるかユーザーに尋ねる。
- issue が既に閉じていたら停止して尋ねる（勝手に開き直さない）。
- ラベルが見つからないエラーになったら、`/flow init` の再実行でラベルを作れることを伝える。
- 操作したら、何をしたか（例：「#123 を flow:in-progress にし、assignee に自分を追加」）をユーザーに一行で伝える。

## PR との紐付け（Phase 6）

- チケットに `Issue: #<番号>` があれば、PR 本文の末尾に **`Closes #<番号>` を必ず入れる**。PR の下書きを提示する時点で入っていること。
- PR を作成した後、紐付けを確かめる：
  - `Base` がリモートのデフォルトブランチなら、`gh pr view <PR> --json closingIssuesReferences` にその番号が含まれることを確認する。含まれなければ PR 本文を直して（`gh pr edit`）もう一度確認する。
  - `Base` がデフォルトブランチ以外なら、GitHub は `Closes` で issue を自動では閉じない。本文に `Closes #<番号>` が入っていることだけ確認し、マージ後に flow が閉じる（下記）ことをユーザーに伝える。

## クローズ

- `pr-status.sh` の判定が `merged` で `done` にするとき：issue がまだ開いていれば、`gh issue close <番号> --comment "Closed by /flow: <PR URL> merged"` で閉じる。
- 判定が `approved`（まだマージされていない）で `done` にするとき：issue は閉じない。デフォルトブランチ向けならマージ時に自動で閉じる。そうでなければ、マージ後に `/flow dev <ticket-id>` で再開すると閉じられることを伝える。
- `done` の run を再開したとき：issue が開いたままで PR がマージ済みなら、閉じるか尋ねる。

## 手元にチケットが無い場合

チケットはそれを実装する PR に入るまで、作成者の手元にしか無い（new は commit しない）。dev で `docs/tickets/<ticket-id>.md` が無いが issue が存在する場合は、issue からチケットを作り直さずに停止し、issue の作成者（`gh issue view <番号> --json author`）から共有を受けるよう伝える。

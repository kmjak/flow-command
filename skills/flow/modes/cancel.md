# cancel モード — チケットをやめる

目的：もう実装しないと決めたチケットを「キャンセル済み」として記録する。**消さずに残し、以後はどのモードからも操作しない。** ブランチ・リモートブランチには触らない。run だけをやり直したいなら `/flow reset` を案内する。

1. **準備**：引数のチケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる）。`tracker: github` なら `references/github.md` を Read して「事前チェック」を行う。
2. **チケットを読む**：
   - `github` — issue が開いていれば「チケットを issue から取ってくる」で手元のコピーを作り直してから読む。閉じていれば、`not planned` で閉じられていて `Canceled by /flow:` のコメントがあればキャンセル済みとして止まる。それ以外の理由で閉じているなら（完了済みなど）、状況を伝えて止まる。
   - `local` — `docs/tickets/<ticket-id>.md` を読む。無い場合、状態ファイルの `Branch`、または `git log --all --oneline -- docs/tickets/<ticket-id>.md` で見つかるブランチにあるなら、そのブランチに切り替えるか尋ねる（今のブランチにコピーを作らない）。どこにも無ければ止まって伝える。
   - 既に `Status: canceled` があれば、キャンセル済みであることを伝えて止まる。
   - `docs/flow/<ticket-id>/main.md` の `Status` が `done` なら拒否する（完了済みの作業は取り消さない）。
3. やめる理由を 1 行で尋ねる（「優先度が下がった」「T000045 に統合」など）。
4. **行うことを一覧で示し、確認を得る**：
   - `local` — チケットのヘッダ（タイトルと、あれば `Issue:` 行の下）に次の 2 行を足す。本文は変えない。`Status:`・`Reason:` は英語の固定キー。
     ```markdown
     Status: canceled
     Reason: <理由>
     ```
   - `docs/flow/<ticket-id>/main.md` があれば、`bash <scripts>/state.sh set <ticket-id> Status canceled` を実行する。
   - `github` — issue を **削除せずに** `gh issue close <番号> --reason "not planned" --comment "Canceled by /flow: <理由>"` で閉じる（開いたままだと、他の人が着手してしまうため）。手元のコピーにも上の 2 行を足す（git 管理外。issue から作り直しても、閉じた理由から同じ 2 行が復元される）。
   - `github` で、`main.md` の `## Approach` が書かれていれば、`references/github.md` の「判断の記録」のコメントを投稿する（何をしようとして、なぜやめたかを残すため）。投稿する本文もこの一覧で示す。
   - `host: github` で、このチケットのブランチに開いている PR（`gh pr list --head <Branch> --state open`）があれば、**閉じるかどうかだけ**を尋ねる（閉じるなら `gh pr close <PR> --comment "Canceled by /flow: <理由>"`）。残すと、レビュアーからは生きている PR に見えるため。
5. 確認されたら実行する。
6. 行ったことを伝える。ブランチとリモートブランチは残していること（不要なら自分で削除できること）を伝える。`local` でチケットファイルが未コミットなら、キャンセルの記録を残したければ commit するよう伝える（**cancel 自身は commit しない**）。

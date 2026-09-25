# reset モード — run を最初からやり直す

目的：チケットは残したまま、dev の run（`docs/flow/<ticket-id>/main.md`）を捨てて、次の `/flow dev <ticket-id>` で Research からやり直せるようにする。チケット自体をやめるなら `/flow cancel`、チケットの内容を直してフェーズを戻すなら `/flow edit` を案内する。

1. **準備**：引数のチケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる。SKILL.md の「現在の状態」の進行中の run を候補として示す）。`tracker: github` なら `references/github.md` を Read して「事前チェック」を行う。
2. `docs/flow/<ticket-id>/main.md` を読む。
   - 無ければ、やり直す run が無いことを伝えて止まる（`/flow dev <ticket-id>` で始められる）。
   - `Status` が `done` なら拒否する（マージ・完了済みの作業は取り消さない）。`canceled`、またはチケットに `Status: canceled` があれば拒否する（キャンセル済み）。
3. **片付けの対象を調べて一覧で示す**：
   - `Status` と、各セクションに何が書かれているか（捨てる内容）
   - `Branch` に書かれたブランチがあれば、その commit（`git log --oneline <Base>..<Branch>`）と、未コミットの変更があるか
   - `host: github` なら、リモートブランチの有無（`git ls-remote --heads origin <Branch>`）と、開いている PR（`gh pr list --head <Branch> --state open`）
4. **やり直す理由**を 1 行で尋ねる（GitHub 連携で `## Approach` が書かれているときだけ。判断の記録に使う）。
5. **ブランチの扱い**：ブランチがある場合は、AskUserQuestion で扱いを尋ねる：
   - **削除する** — commit の一覧を示したうえで、ローカルブランチを削除する。マージされていない commit は `-d` では消せないので `git branch -D` を使う（取り消せないことを伝える。guard hook の確認画面も出る）。今そのブランチにいれば、先に `Base` に切り替える（未コミットの変更があれば止まる。勝手に stash や破棄をしない）。リモートブランチがあれば、それも削除するか（`git push origin --delete <Branch>`）、開いている PR があれば閉じるか（`gh pr close <PR>`）を同じ一覧で尋ねる。
   - **残す** — ブランチには触らない。やり直した Plan では、このブランチと別の名前を付けることを伝える。開いている PR があれば、閉じるかだけを尋ねる。
6. ここまでで決まった操作（`docs/flow/<ticket-id>/` の削除・ブランチ等の片付け・issue の更新・判断の記録のコメント）を一覧で示し、**1 回の確認でまとめて承認をもらってから**実行する。
7. **実行する**：
   - `tracker: github` でチケットに `Issue:` があり、`## Approach` が書かれていれば、先に `references/github.md` の「判断の記録」のコメントを投稿する（`main.md` を消すと方針が残らないため、削除より前に行う）。
   - `docs/flow/<ticket-id>/` を削除する（中身は `main.md` だけのはず。他のファイルがあれば削除せずに止まって尋ねる）。`docs/flow/.active` がこの id を指していれば、それも削除する。
   - 「ブランチの扱い」で決めたブランチ・リモートブランチ・PR の操作。
   - `tracker: github` でチケットに `Issue:` があれば、`issue-label.sh <番号> reset` で issue を `flow:todo` に戻し、assignee から自分を外す。
8. 行ったことを要約し、`/flow dev <ticket-id>` で Research からやり直せることを案内する。チケットファイルには触らない。commit はしない。

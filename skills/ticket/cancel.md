# /tixforge:ticket cancel — チケットをやめる

目的：もう実装しないと決めたチケットを「キャンセル済み」として記録する。**消さずに残し、以後はどのサブコマンドからも操作しない。** ブランチ・リモートブランチには触らない。run だけをやり直したいなら `/tixforge:dev reset` を案内する。

1. **準備**：引数のチケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる）。id が `GT-` なら `references/github.md` を Read して「事前チェック」を行う。
2. **チケットを読む**：
   - `GT-` — issue が開いていれば「チケットを issue から取ってくる」で手元のコピーを作り直してから読む。閉じていれば、`not planned` で閉じられていて `Canceled by tixforge:` のコメントがあればキャンセル済みとして止まる。それ以外の理由で閉じているなら（完了済みなど）、状況を伝えて止まる。
   - `LT-` — `.tixforge/<ticket-id>/ticket.md` を読む。無ければ止まって伝える。
   - 読んだら「`<ticket-id>`：<タイトル>」を示す（取り違えの防止）。
   - 既に `Status: canceled` があれば、キャンセル済みであることを伝えて止まる。
   - `.tixforge/<ticket-id>/state.md` の `Status` が `done` なら拒否する（完了済みの作業は取り消さない）。
3. やめる理由を 1 行で尋ねる（「優先度が下がった」「GT-000045 に統合」など）。
4. **行うことを一覧で示し、確認を得る**：
   - `LT-` — チケットのヘッダ（タイトル行の下）に次の 2 行を足す。本文は変えない。`Status:`・`Reason:` は英語の固定キー。
     ```markdown
     Status: canceled
     Reason: <理由>
     ```
   - `.tixforge/<ticket-id>/state.md` があれば、`bash <scripts>/run-state.sh set <ticket-id> Status canceled` を実行する。
   - `GT-` — issue を **削除せずに** `gh issue close <番号> --reason "not planned" --comment "Canceled by tixforge: <理由>"` で閉じる（開いたままだと、他の人が着手してしまうため）。手元のコピーにも上の 2 行を足す（git 管理外。issue から作り直しても、閉じた理由から同じ 2 行が復元される）。
   - `GT-` で、`state.md` の `## Approach` が書かれていれば、`references/github.md` の「判断の記録」のコメントを投稿する（何をしようとして、なぜやめたかを残すため）。投稿する本文もこの一覧で示す。
   - `host: github` で、このチケットのブランチに開いている PR（`gh pr list --head <Branch> --state open`）があれば、**閉じるかどうかだけ**を尋ねる（閉じるなら `gh pr close <PR> --comment "Canceled by tixforge: <理由>"`）。残すと、レビュアーからは生きている PR に見えるため。
5. 確認されたら実行する。
6. 行ったことを伝える。ブランチとリモートブランチは残していること（不要なら自分で削除できること）を伝える。**cancel は commit しない**（チケットは git で管理しない）。

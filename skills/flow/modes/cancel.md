# cancel モード — チケットをやめる

目的：もう実装しないと決めたチケットを「キャンセル済み」として記録する。**消さずに残し、以後はどのモードからも操作しない。** ブランチ・リモートブランチ・チケットファイルの中身には触らない。run だけをやり直したいなら `/flow reset` を案内する。

1. 引数のチケット id を共通規約のとおり正規化する（無ければ尋ねる）。`docs/flow.config.yml` の `ticket` を読む。`tracker: github` なら `references/github.md` を Read して「事前チェック」を行う。
2. チケットを読む。
   - 手元に無い場合：GitHub 連携で issue があれば `references/github.md` の「手元にチケットが無い場合」で復元してから続ける。それ以外は止まって伝える。
   - 既に `Status: canceled` があれば、キャンセル済みであることを伝えて止まる。
   - `docs/flow/<ticket-id>/main.md` の `Status` が `done` なら拒否する（完了済みの作業は取り消さない）。
3. やめる理由を 1 行で尋ねる（「優先度が下がった」「T000045 に統合」など）。
4. 行うことを一覧で示し、確認を得る：
   - チケットのヘッダ（タイトルと `Issue:` 行の下）に次の 2 行を足す。本文は変えない。`Status:`・`Reason:` は英語の固定キー。
     ```markdown
     Status: canceled
     Reason: <理由>
     ```
   - `docs/flow/<ticket-id>/main.md` があれば、`Status` を `canceled` にし、`Updated` を今の時刻にする。
   - GitHub 連携でチケットに `Issue:` があれば、issue を **削除せずに** `gh issue close <番号> --reason "not planned" --comment "Canceled by /flow: <理由>"` で閉じる。開いたままだと、他の人が着手してしまうため。
   - `host: github` で、このチケットのブランチに開いている PR（`gh pr list --head <Branch> --state open`）があれば、**閉じるかどうかだけ**を尋ねる（閉じるなら `gh pr close <PR> --comment "Canceled by /flow: <理由>"`）。残すと、レビュアーからは生きている PR に見えるため。
5. 確認されたら実行する。
6. 行ったことを伝える。ブランチとリモートブランチは残していること（不要なら自分で削除できること）を伝える。チケットファイルが未コミットなら、キャンセルの記録を残したければ commit するよう伝える（**cancel 自身は commit しない**）。

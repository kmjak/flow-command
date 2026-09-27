# GitHub：チケットの変更を issue に書き戻す

`GT-` のチケットを edit で書き換えたときに読む。

- 書き換えた直後に `bash <scripts>/issue-sync.sh push <番号> .tixforge/<ticket-id>/ticket.md` を行う。
- **終了コード 5**（このコピーを取ってきた後に issue が更新された＝他の人が edit した可能性）：書き戻さない。issue から取ってき直し（`issue-sync.sh pull <番号> <ファイル> --dry-run` で差分を示す）、自分の変更を最新の内容に当て直してから、もう一度合意を得て push する。他の人の変更を消さない。
- **終了コード 4**（編集中に GitHub 上で直接編集された）：差分を示し、取り込むか尋ねる（取り込むなら `pull --accept-edited` の後に変更を当て直す）。
- それ以外のときに手元から issue を書き換えない。

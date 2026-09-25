# edit モード — チケットの編集

目的：既存のチケットの内容を、ユーザーとの対話で書き換える。進行中の dev の run があれば、変更の影響に合わせてフェーズを戻す。

1. **準備**：引数のチケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる。`docs/tickets/*.md`、GitHub 連携なら開いている `flow:*` の issue を候補として示す）。`tracker: github` なら `references/github.md` を Read して「事前チェック」を行う。
2. **チケットを読む**：
   - `github` — `references/github.md` の「チケットを issue から取ってくる」で手元のコピーを作り直してから読む（issue が正本。GitHub 上で直接編集されていたら、そこで取り込むか尋ねる）。取り込んだ変更は、「フェーズを戻す」の影響判断に含める。
   - `local` — `docs/tickets/<ticket-id>.md` を読む。無い場合、状態ファイルの `Branch`、または `git log --all --oneline -- docs/tickets/<ticket-id>.md` で見つかるブランチにあるなら、そのブランチに切り替えて編集するか尋ねる（今のブランチにコピーを作らない：後でそのブランチをマージするときに、未追跡のファイルとぶつかって失敗するため）。どこにも無ければ止まって `/flow new` を案内する。
   - **編集しないで止まる場合**：チケットに `Status: canceled` がある（キャンセル済み）／`docs/flow/<ticket-id>/main.md` の `Status` が `done` か `canceled`／GitHub 連携で issue が閉じている。完了・中止した内容を書き換えると、実装や記録と食い違うため。変えたいことがあるなら、新しいチケットを `/flow new` で作るよう勧める。
3. **対話で決める**：今の内容を示し、何を変えたいかを尋ねる。new の「対話で埋める」と同じ決まりで対話する：**要件を捏造しない**（ユーザーが言っていないことは書かない）、決まらない点は「未決事項」に残す、必要なら `docs/context/**` やコードを読んで質問を具体的にする。
   - 追加がチケットの範囲を大きく広げる（別の機能・別の受け入れ条件の塊になる）なら、このチケットに足さず、別のチケットに分けることを提案する。
4. 変更後の全文と差分を示して合意を得る。GitHub 連携なら、issue のタイトル・本文がどう変わるかも示す。
5. **書き換える**：チケットを書き換える。GitHub 連携なら、すぐに `issue-sync.sh push <番号> docs/tickets/<ticket-id>.md` で issue に書き戻す（`references/github.md`「本文の同期」）。
6. **フェーズを戻す**：進行中の run がある場合（`docs/flow/<ticket-id>/main.md` があり、`Status` が `done`・`canceled` 以外）は、`references/rollback.md` を Read して、その手順でフェーズを戻すか決める。
7. 行ったこと（GitHub 連携なら issue の URL も）を伝える。
8. **commit はしない**。`local` でチケットがすでに run のブランチで commit されている場合、この変更は未コミットの変更として残るので、dev の Implement で「チケットの更新」として commit することを伝える。`github` ではチケットは issue にあり、手元のファイルは commit しない。

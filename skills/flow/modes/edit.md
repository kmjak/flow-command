# edit モード — チケットの編集

目的：既存のチケット `docs/tickets/<ticket-id>.md` の内容を、ユーザーとの対話で書き換える。進行中の dev の run があれば、変更の影響に合わせてフェーズを戻す。

1. 引数のチケット id を共通規約のとおり正規化する（無ければ尋ねる。`docs/tickets/*.md` を候補として示す）。`docs/flow.config.yml` の `language` と `ticket` を読む。`tracker: github` なら `references/github.md` を Read して「事前チェック」を行う。
2. チケットを読む。
   - 手元に無い場合：GitHub 連携で issue があれば `references/github.md` の「手元にチケットが無い場合」で復元してから続ける。それ以外は止まって `/flow new` を案内する。
   - **編集しないで止まる場合**：チケットに `Status: canceled` がある（キャンセル済み）／`docs/flow/<ticket-id>/main.md` の `Status` が `done` か `canceled`／GitHub 連携で issue が閉じている。完了・中止した内容を書き換えると、実装や記録と食い違うため。変えたいことがあるなら、新しいチケットを `/flow new` で作るよう勧める。
3. GitHub 連携なら、issue と照合する（`references/github.md` の「issue との照合」）。issue の内容を取り込んだら、取り込んだ後のチケットを今の内容として編集を続け、手順 7 の影響判断には取り込んだ変更も含める。
4. 今の内容を示し、何を変えたいかを尋ねる。new の手順 5 と同じ決まりで対話する：**要件を捏造しない**（ユーザーが言っていないことは書かない）、決まらない点は「未決事項」に残す、必要なら `docs/context/**` やコードを読んで質問を具体的にする。
   - 追加がチケットの範囲を大きく広げる（別の機能・別の受け入れ条件の塊になる）なら、このチケットに足さず、別のチケットに分けることを提案する。
5. 変更後の全文と差分を示して合意を得る。GitHub 連携なら、同期で issue のタイトル・本文がどう変わるかも示す。
6. チケットを書き換える。GitHub 連携なら issue を同期する（`references/github.md` の「本文の同期」）。
7. **進行中の run がある場合**（`docs/flow/<ticket-id>/main.md` があり、`Status` が `done`・`canceled` 以外）：変更がどのフェーズの成果に影響するかを示す（例：受け入れ条件が変わった → Approach の方針と Plan の commit 分割を見直す必要がある。背景の言い回しだけ → 影響なし）。そのうえで AskUserQuestion で戻すフェーズを選んでもらう。選択肢は、今のフェーズ以前の Research・Approach・Plan から影響に応じて推奨を付けたものと、「戻さない」。
   - 戻す場合は `Status` を `<選んだフェーズ>:in-progress` に、`Updated` を今の時刻にする。セクションは消さず、戻したフェーズのセクションの先頭に `> チケット編集（<YYYY-MM-DD HH:MM>）：<変更点の要約>` の 1 行を足す（dev が issue から取り込んで戻す場合は `> issue から取り込み（<YYYY-MM-DD HH:MM>）：<変更点の要約>`）（再開したときに、なぜ戻ったのかが分かるように）。後のフェーズのセクションは、そのフェーズをやり直すときに書き直す。
   - ブランチや commit には触らない。run を丸ごと捨ててやり直したい場合は `/flow reset` を案内する。
8. 行ったこと（GitHub 連携なら issue の URL も）を伝え、run があれば `/flow dev <ticket-id>` で戻したフェーズから再開できることを案内する（dev から手順 7 だけを使った場合は、案内せずにそのまま再開する）。
9. **commit はしない**（new と同じ）。チケットがすでに run のブランチで commit されている場合、この変更は未コミットの変更として残るので、dev の Implement で「チケットの更新」として commit することを伝える。

# /tixforge:ticket create — チケット作成

目的：チケットを、ユーザーとの対話で作る。id は自分で決めず、共通規約のとおり自動で決める（`tracker: github` なら issue 番号から `GT-`、`local` なら連番の `LT-`）。

1. `.tixforge/config.yml` が無い（init 未実行の）場合は、その旨を伝えて `/tixforge:project init` を案内し、止まる（設定なしでは進めない）。
2. `.tixforge/config.yml` の `language`（無ければ日本語）と `ticket.tracker` を使う（SKILL.md の「現在の状態」にある）。`tracker: github` なら `references/github.md` を Read して「事前チェック」を行う。
3. **既存チケットを指していないか**を確かめる：引数を `bash <scripts>/ticket-id.sh detect "<引数>"` に渡す（自分で解釈しない）。
   - `id: <id>` なら `ticket-id.sh exists <id>` で確かめる。`ticket` か `issue` なら新規作成ではない。何もせずに、編集なら `/tixforge:ticket edit <id>`、実装なら `/tixforge:dev <id>` を案内する。`pull-request` なら、その番号は PR であることを伝える。`none` なら、そのチケットは無いことを伝え、`rest:` を説明として新しく作るか尋ねる。**既存のチケットを黙って上書きしない。**
   - `invalid: <語>` なら、正しい id の形（`LT-000123`・`GT-000123`・`#123`）を示して尋ねる。
4. `id: none` なら、`rest:` を作りたいものの説明として扱う（空なら尋ねる）。
5. **対話で埋める**：何を作りたいか・なぜ必要かをユーザーに尋ね、下記テンプレートの各項目を対話で埋める。テンプレート内の HTML コメント（記入ガイド）は完成したチケットには残さない。
   - **要件を捏造しない。** ユーザーが言っていないことは書かない。こちらの提案は提案として示し、合意したものだけ書く。
   - 決まらない点は削らず「未決事項」に残す。
   - 受け入れ条件は、dev の Plan で「何で確かめるか」を決められる形（できた／できていないを判定できる形）にする。
   - 必要なら `docs/context/**` やコードを読んで、質問を具体的にする。
6. 下書き（id はまだ決まっていないので `<ticket-id>` のまま）を提示し、合意を得る。`github` なら、同時に**作成する issue**（タイトル・本文・ラベル `tixforge:todo`）も示し、「この内容で issue を作成する」ことへの確認を得る。
7. **id を決めて書く**：
   - `github` — `references/github.md` の「作成」のとおり、下書きから issue を作り（`issue-sync.sh create`）、番号から id を作り（`ticket-id.sh normalize '#<番号>'`）、issue から手元のコピーを作る（`issue-sync.sh pull`）。決まった id のフォルダが既にあれば、pull せずに止まって尋ねる。
   - `local` — `bash <scripts>/ticket-id.sh next` で id を決め、下書きの `<ticket-id>` を置き換えて `.tixforge/<ticket-id>/ticket.md` に書く。決まった id のファイルが既に存在したら、書かずに停止して尋ねる。`.tixforge/.gitignore` が無ければ先に作る（内容は共通規約）。
8. 作った id（`github` なら issue の URL も）を伝え、次の一手として `/tixforge:dev <ticket-id>` を案内する。状態ファイル（`.tixforge/<ticket-id>/state.md`）は作らない（dev の役目）。
9. **commit はしない。** チケットは `LT-`・`GT-` どちらも git で管理しない（`LT-` は手元のファイル、`GT-` は issue が正本）。

チケットのテンプレート（日本語版。ドキュメント言語が日本語以外なら、見出しとコメントをその言語に訳して使う。該当しない項目も削らず「なし」と書く）：

```markdown
# <ticket-id>: <タイトル>

<!-- この下に入る `Status: canceled` と `Reason:` の行は /tixforge:ticket cancel だけが書く。create では書かない。
     GT- のチケットでは、最初の ## から下が全て issue の本文にそのまま載る。 -->

## 背景
<!-- なぜ必要か。解決したい問題や動機、誰が影響を受けるか。 -->

## 要件
<!-- 何をするか。1 項目 1 行の箇条書きで、実装方法ではなく振る舞いを書く。 -->

## 受け入れ条件
<!-- 何を満たせば完了か。各項目を「- [ ]」で、できた／できていないで判定できる形で書く。 -->

## 対象外
<!-- このチケットでは扱わないこと。 -->

## 未決事項
<!-- まだ決まっていないこと。/tixforge:dev の Research で解消する。 -->
```

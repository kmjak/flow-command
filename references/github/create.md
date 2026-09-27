# GitHub：issue を作る・取り込む

`tracker: github` の create で読む。

- **事前チェック**：`bash <scripts>/github-preflight.sh`。`ok:` 以外なら、出力をそのまま示して止まる。
- issue の本文にはチケットの全セクション（背景・要件・受け入れ条件・対象外・未決事項）と、tixforge が書いたことを確かめるハッシュが載る。本文とタイトルは GitHub 上で直接編集せず、`/tixforge:ticket edit` で変える（本文の冒頭で告知される）。

## 作成

1. 作成前の確認一覧に、作る issue（タイトル・本文・ラベル `tixforge:todo`）を載せる。リポジトリが public なら（`gh repo view --json visibility`）、「公開範囲：public」を 1 項目として載せる（警告の文は付けない）。
2. 合意した下書き（タイトル行は `# <ticket-id>: <タイトル>` のまま）を一時ファイルに書き、`bash <scripts>/issue-sync.sh create <一時ファイル>` を実行する。issue を作り、id（`GT-<番号>`）を決め、手元のコピー `.tixforge/<id>/ticket.md` まで作る。出力の `number:`・`url:`・`id:`・`file:` をそのまま使う。
3. 終了コード 6（その id のフォルダが既にある）なら、issue は作られている。手元のコピーは作っていないので、状況を示して尋ねる。

## GitHub 上で作られた issue を取り込む

create に渡された id が、tixforge の目印の無い issue（`issue-sync.sh check` の 1 行目が `no-markers`）なら、新しく作らずに取り込むか尋ねる。

1. `bash <scripts>/issue-sync.sh adopt <番号> .tixforge/<id>/ticket.md` で、issue の本文から手元のチケットを作る（issue フォームの `### 見出し` はチケットの `## 見出し` に、未回答は「なし」になる）。GitHub はまだ変えない。
2. できたチケットを示し、create の対話と同じ決まりで足りない項目を埋める（要件を捏造しない）。
3. 確認一覧に「issue の本文を tixforge の形式に書き換える。元の本文はコメントに残す」を載せ、合意を得てから `issue-sync.sh push <番号> <ファイル> --force --keep-original` を実行する。`tixforge:*` のラベルが無ければ `bash <scripts>/issue-label.sh <番号> reset` で `tixforge:todo` を付ける。

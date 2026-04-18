# anki-go-tmplate

**日本語** | [English](README.en.md)

囲碁の問題をAnkiで学習するためのカードテンプレートです。SGFを入力フィールドに貼り付けると、初期局面の描画・着手の検討・分岐の確認がインタラクティブに行えます。

## テンプレートの機能

SGFを入力フィールドに貼り付けます。

![フィールド入力画面](screenshots/0.png)

初期局面が描画されます。

![初期局面](screenshots/1.png)

盤面をクリックして着手を試せます。

![検討画面](screenshots/2.png)

解答を表示するとSGFの分岐が表示されます。

![解答表示](screenshots/3.png)

## サンプルデッキを使う

[Releases](../../releases/latest) からサンプルの `.apkg` をダウンロードしてAnkiにインポートしてください。

---

## ビルド・セットアップ

NimをJSにトランスパイルし、AnkiのHTMLカードテンプレートに埋め込んでいます。

```
src/ (Nim)
  └─ nim js → dist/front.html (JS埋め込み済み)
               dist/back.html
               dist/style.css
```

### ビルドコマンド

| コマンド | 説明 |
|---|---|
| `nim dev` | 開発用ビルド (`dist-dev/` に出力、ブラウザで確認可) |
| `nim release` | Anki用ビルド (`dist/` にJS埋め込みHTMLを出力) |

### スクリプト

**`scripts/setup_model.py`** — AnkiConnectを通じて「Go Problem」ノートタイプをAnkiに登録します。`dist/` のHTML/CSSをテンプレートとして設定します。

**`scripts/import_cards.py`** — `sgf/` ディレクトリを再帰的に走査し、SGFファイルをカードとしてインポートします。`sgf/` 以下のディレクトリ構造がAnkiのデッキ階層に対応します。

```sh
python scripts/import_cards.py [--dry-run]
```

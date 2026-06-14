import os
import strformat

# 開発用ビルド: dist-dev/ にJS/CSS/HTMLを出力してブラウザで確認できる状態にする
task dev, "開発用ビルド (dist-dev/)":
  withDir thisDir():
    mkDir "dist-dev"
    exec "nim js --hints:off -o:dist-dev/main.js src/main.nim"
    cpFile "assets/style.css", "dist-dev/style.css"
    cpFile "assets/dev.html",  "dist-dev/index.html"

# Anki用リリースビルド: dist/ に front.html (JS埋め込み) と style.css を出力する
task release, "Anki用ビルド (dist/)":
  withDir thisDir():
    mkDir "dist"
    mkDir "tmp"
    exec "nim js -d:release --opt:size --hints:off -o:tmp/main.js src/main.nim"
    exec "nim r --hints:off scripts/build.nim"

# SGFエディタビルド: editor/ にJS/CSS/HTMLを出力してブラウザで使える状態にする
task editor, "SGFエディタビルド (editor/)":
  withDir thisDir():
    mkDir "editor"
    exec "nim js --hints:off -o:editor/main.js src/editor/editor_main.nim"
    cpFile "assets/style.css",        "editor/style.css"
    cpFile "assets/editor_style.css", "editor/editor_style.css"
    cpFile "assets/editor.html",      "editor/index.html"

task testjs, "jsバックエンドでテスト":
  withDir thisDir():
    exec "nimble test --backend:js"

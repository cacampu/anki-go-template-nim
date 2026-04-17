## Anki用リリースビルド: card_front.html の <!-- Script --> に JS を埋め込んで dist/ へ出力する
import os, strutils

createDir("dist")
let js   = readFile("tmp/main.js")
let tmpl = readFile("assets/card_front.html")
writeFile("dist/front.html", tmpl.replace("<!-- Script -->", js))
copyFile("assets/card_back.html", "dist/back.html")
copyFile("assets/style.css", "dist/style.css")
echo "dist/front.html  (Anki front template)"
echo "dist/back.html   (Anki back template)"
echo "dist/style.css   (Anki styling)"

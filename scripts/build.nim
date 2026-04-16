import os, strutils, strformat

# 設定
const
  publicDir = "public"
  tmpDir = "tmp"
  distDir = "dist"

  templateHtml = "index.html"
  outputHtml = "front.html" # Anki用なら front.html (表面) が一般的かも？
  jsFile = "script.js"
  cssFile = "style.css"

# 1. ディレクトリ作成
createDir(distDir)

# 2. CSSのコピー
copyFile(publicDir / cssFile, distDir / cssFile)
echo "Copied CSS to " & distDir / cssFile

# 3. JSの読み込み
discard execShellCmd(&"nim js -d:release -o:{tmpDir / jsFile} --hints:off src/main.nim")
let jsContent = readFile(tmpDir / jsFile)

# 4. HTMLテンプレートの読み込みと置換
let htmlTemplate = readFile(publicDir / templateHtml)
let finalHtml = htmlTemplate.replace("<!-- Script -->", jsContent)

# 5. 結果の書き出し
writeFile(distDir / outputHtml, finalHtml)
echo "Generated " & distDir / outputHtml

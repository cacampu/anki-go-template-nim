import ../core/[board, types]
import std/[dom, strformat]

## 盤面描画の共通プリミティブ (Anki用ビューア・SGFエディタの両方から利用する)

const cell_size* = 29  ## CSS の --cell-size と合わせる (px)

## ====== DOM ヘルパー ======

proc h*(
    parent: Element,
    tag: string,
    class_name: string = "",
    attrs: openArray[(string, string)] = [],
    styles: openArray[(string, string)] = [],
    text: string = "",
): Element =
  ## 要素を作成して parent に追加する。parent が nil の場合は追加しない。
  let el = document.createElement(tag)
  if class_name.len > 0:
    el.className = cstring(class_name)
  for (key, val) in attrs:
    el.setAttribute(cstring(key), cstring(val))
  for (prop, val) in styles:
    el.style.setProperty(cstring(prop), cstring(val))
  if text.len > 0:
    el.textContent = cstring(text)
  if parent != nil:
    parent.appendChild(el)
  el

proc hNested*(parent: Element, classes: varargs[string]): Element =
  ## 入れ子の div を生成する。classes[0] が最外層で parent に追加される。
  result = parent.h("div", classes[0])
  for i in 1 ..< classes.len:
    discard result.h("div", classes[i])

proc hsvg*(
    parent: Element,
    tag: string,
    class_name: string = "",
    attrs: openArray[(string, string)] = [],
    styles: openArray[(string, string)] = [],
): Element =
  ## SVG 名前空間で要素を生成して parent に追加する。
  let el = document.createElementNS(
    cstring("http://www.w3.org/2000/svg"), cstring(tag))
  if class_name.len > 0:
    el.setAttribute(cstring("class"), cstring(class_name))
  for (key, val) in attrs:
    el.setAttribute(cstring(key), cstring(val))
  for (prop, val) in styles:
    el.style.setProperty(cstring(prop), cstring(val))
  if parent != nil:
    parent.appendChild(el)
  el

proc bbox_width*(el: Element):  float {.importjs: "#.getBBox().width".}
proc bbox_height*(el: Element): float {.importjs: "#.getBBox().height".}

proc clear*(el: Element) =
  ## 子要素をすべて削除する。
  while el.firstChild != nil:
    el.removeChild(el.firstChild)

proc set_disabled*(el: Element, v: bool) =
  if v: el.classList.add(cstring("disabled"))
  else: el.classList.remove(cstring("disabled"))

## ====== SVG スプライト ======

proc put_svg_defs*(parent: Element) =
  ## マーカー用 SVG スプライト定義を parent の非表示 div に注入する。一度だけ呼び出す。
  let wrap = parent.h("div", styles = [("display", "none")])
  wrap.innerHTML = cstring("""<svg xmlns="http://www.w3.org/2000/svg"><defs>
<symbol id="m-circle" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="30"
    fill="var(--fill-color,white)" stroke="var(--stroke-color,black)" stroke-width="9"/>
</symbol>
<symbol id="m-square" viewBox="0 0 100 100">
  <rect x="22.5" y="22.5" width="55" height="55" rx="4"
    fill="var(--fill-color,white)" stroke="var(--stroke-color,black)" stroke-width="9"/>
</symbol>
<symbol id="m-triangle" viewBox="0 0 100 100">
  <polygon points="50,17 18,72 82,72"
    fill="var(--fill-color,white)" stroke="var(--stroke-color,black)"
    stroke-width="9" stroke-linejoin="round"/>
</symbol>
<symbol id="m-cross" viewBox="0 0 100 100">
  <rect x="25" y="25" width="50" height="50" fill="var(--fill-color,white)"/>
  <line x1="24" y1="24" x2="76" y2="76"
    stroke="var(--stroke-color,black)" stroke-width="9" stroke-linecap="round"/>
  <line x1="24" y1="76" x2="76" y2="24"
    stroke="var(--stroke-color,black)" stroke-width="9" stroke-linecap="round"/>
</symbol>
</defs></svg>""")

## ====== 盤面 DOM の生成 ======

proc draw_lines*(container: Element, size: int) =
  let grid = container.h("div", "line-grid")
  for _ in 0 ..< (size - 1) * (size - 1):
    discard grid.h("div", "line-cell")
  proc star(r, c: int) =
    discard grid.h("div", "star", styles = [("grid-row", $r), ("grid-column", $c)])
  let m = (size + 1) div 2
  let d = if size >= 13: 4 else: 3
  let lr = [d, size - d]
  if size >= 8:
    for r in lr:
      for c in lr: star(r, c)
  if size > 5 and size mod 2 == 1:
    star(m, m)
  if size >= 15 and size mod 2 == 1:
    for x in lr:
      star(x, m)
      star(m, x)

## ====== 石の描画 ======

proc coord_sel*(coord: Coord): string =
  &"[data-x='{coord.x}'][data-y='{coord.y}']"

proc get_stone*(grid: Element, coord: Coord): Element =
  grid.querySelector(cstring(".stone" & coord_sel(coord)))

proc put_stone*(grid: Element, coord: Coord, color: Color) =
  if grid.get_stone(coord) != nil: return
  let cls = if color == Black: "stone black" else: "stone white"
  discard grid.h("div", cls,
    attrs  = [("data-x", $coord.x), ("data-y", $coord.y)],
    styles = [("grid-column", $coord.x), ("grid-row", $coord.y)])

proc remove_stone*(grid: Element, coord: Coord) =
  let s = grid.get_stone(coord)
  if s != nil: s.remove()

proc update_stones*(grid: Element, board: Board) =
  for y in 1 .. board.size:
    for x in 1 .. board.size:
      let coord: Coord = (x, y)
      case board[coord]
      of Black: grid.put_stone(coord, Black)
      of White: grid.put_stone(coord, White)
      of Empty: grid.remove_stone(coord)

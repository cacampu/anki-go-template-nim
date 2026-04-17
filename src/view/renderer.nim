import ../core/[board, gametree, properties, types]
import ../app/[state, handler]
import std/[dom, strformat, strutils, tables]
import results

## gametree.Node と dom.Node の名前衝突を回避するエイリアス
type GameNode* = gametree.Node

const cell_size = 29  ## CSS の --cell-size と合わせる (px)

## ====== 表示設定 ======

type ViewState* = object
  show_ans*: bool
  show_ans_ptr*: bool

## ====== showAns グローバル関数 ======

var g_on_show_ans: proc()

proc show_ans_impl() =
  if g_on_show_ans != nil: g_on_show_ans()

{.emit: "window['showAns'] = `show_ans_impl`;".}

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

proc clear*(el: Element) =
  ## 子要素をすべて削除する。
  while el.firstChild != nil:
    el.removeChild(el.firstChild)

proc set_disabled(el: Element, v: bool) =
  if v: el.setAttribute("disabled", "")
  else: el.removeAttribute("disabled")

## ====== SVG スプライト ======

proc put_svg_defs(parent: Element) =
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

proc draw_lines(container: Element, size: int) =
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

proc coord_sel(coord: Coord): string =
  &"[data-x='{coord.x}'][data-y='{coord.y}']"

proc get_stone(grid: Element, coord: Coord): Element =
  grid.querySelector(cstring(".stone" & coord_sel(coord)))

proc put_stone(grid: Element, coord: Coord, color: Color) =
  if grid.get_stone(coord) != nil: return
  let cls = if color == Black: "stone black" else: "stone white"
  discard grid.h("div", cls,
    attrs  = [("data-x", $coord.x), ("data-y", $coord.y)],
    styles = [("grid-column", $coord.x), ("grid-row", $coord.y)])

proc remove_stone(grid: Element, coord: Coord) =
  let s = grid.get_stone(coord)
  if s != nil: s.remove()

proc update_stones(grid: Element, board: Board) =
  for y in 1 .. board.size:
    for x in 1 .. board.size:
      let coord: Coord = (x, y)
      case board[coord]
      of Black: grid.put_stone(coord, Black)
      of White: grid.put_stone(coord, White)
      of Empty: grid.remove_stone(coord)

## ====== マーカーの描画 ======

proc get_marker(grid: Element, coord: Coord): Element =
  grid.querySelector(cstring(coord_sel(coord)))

proc put_marker_svg(grid: Element, symbol_id: string): Element =
  ## SVG スプライト参照のグリッドセル (<svg><use>) を生成して grid に追加する。
  ## data-x/y・grid-column/row は呼び出し元で設定する。
  result = grid.hsvg("svg", "marker",
    attrs = [("viewBox", "0 0 100 100"),
             ("width", $cell_size), ("height", $cell_size)])
  discard result.hsvg("use", attrs = [("href", "#" & symbol_id)])

proc put_marker(grid: Element, key: string, coord: Coord, text: string = ""): Element =
  if grid.get_marker(coord) != nil: return
  case key
  of "LB":          result = grid.h("div", "label", text = text)
  of "MA":          result = grid.put_marker_svg("m-cross")
  of "TR":          result = grid.put_marker_svg("m-triangle")
  of "CR":          result = grid.put_marker_svg("m-circle")
  of "SQ":          result = grid.put_marker_svg("m-square")
  of "ansPtr":      result = grid.hNested("pointer-wrapper", "pointer ans")
  of "branchPtr":   result = grid.hNested("pointer-wrapper", "pointer branch")
  of "lastMovePtr": result = grid.h("div", "pointer last-move")
  else: return
  result.setAttribute("data-x", cstring($coord.x))
  result.setAttribute("data-y", cstring($coord.y))
  result.style.setProperty("grid-column", cstring($coord.x))
  result.style.setProperty("grid-row",    cstring($coord.y))

proc update_markers(grid: Element, node: GameNode, board: Board) =
  for key in ["LB", "MA", "TR", "CR", "SQ"]:
    if key notin node.props: continue
    for v in node.props[key]:
      let parts = v.split(":")
      let coord = parseCoord(parts[0])
      let text  = if parts.len > 1: parts[1] else: ""
      let el = grid.put_marker(key, coord, text)
      if el == nil: continue
      case board[coord]
      of Black: el.classList.add(cstring("onB"))
      of White: el.classList.add(cstring("onW"))
      of Empty: discard

proc show_last_move(grid: Element, node: GameNode) =
  ## 直前の手にポインターを表示する。石の色と逆色でポインターを着色する。
  for key in ["B", "W"]:
    if key notin node.props: continue
    let el = grid.put_marker("lastMovePtr", parseCoord(node.props[key][0]))
    if el != nil:
      el.classList.add(cstring(if key == "B": "onB" else: "onW"))
    break

## ====== 分岐ポインタの描画 ======

proc make_branch_click_handler(on_click: proc(idx: int), idx: int): proc(e: Event) =
  ## for ループのクロージャキャプチャ問題を回避するため idx を引数で受け取る
  result = proc(e: Event) = on_click(idx)

proc make_branch_button(
    container: Element, pointer: Element,
    on_click: proc(idx: int), idx: int,
) =
  ## 非主分岐の "+" ボタンを生成し、対応するポインターとホバー連動させる
  let btn = container.h("button", "gb ans branch", text = "+")
  btn.addEventListener("mouseover", proc(e: Event) =
    pointer.classList.add(cstring("hover-state")))
  btn.addEventListener("mouseout", proc(e: Event) =
    pointer.classList.remove(cstring("hover-state")))
  btn.addEventListener("click", make_branch_click_handler(on_click, idx))

proc show_branches(
    grid: Element, node: GameNode,
    on_click: proc(idx: int),
    branches_cont: Element,
) =
  ## 分岐ポインタを描画し、直接イベントリスナーを設定する。
  for i, child in node.children:
    let move: Move = child.props
    if move.kind != Put: continue
    let key = if i == 0: "ansPtr" else: "branchPtr"
    let el = grid.put_marker(key, move.coord)
    if el == nil: continue
    el.setAttribute("data-branch-idx", cstring($i))
    el.addEventListener("mouseenter", proc(e: Event) =
      cast[Element](e.currentTarget).classList.add(cstring("hover-state")))
    el.addEventListener("mouseleave", proc(e: Event) =
      cast[Element](e.currentTarget).classList.remove(cstring("hover-state")))
    el.addEventListener("click", make_branch_click_handler(on_click, i))
    if i > 0:
      make_branch_button(branches_cont, el, on_click, i)

## ====== 描画 ======

proc render(board: Element, state: AppState) =
  let stone_grid  = board.querySelector(".stone-grid")
  let marker_grid = board.querySelector(".marker-grid")
  update_stones(stone_grid, state.board)
  marker_grid.clear()
  update_markers(marker_grid, state.tree.current_node(), state.board)
  show_last_move(marker_grid, state.tree.current_node())

## ====== スコープ (表示領域) ======

proc classify_range(r: array[2, int]): int =
  ## 軸の座標範囲をゾーン分類する: 0=左/上端, 1=中央, 2=右/下端, -1=全域
  if r[1] < 13:   0
  elif r[0] > 4 and r[1] < 16: 1
  elif r[0] > 7:  2
  else:           -1

proc change_scope(scope_root, container: Element, xy: XYRange) =
  ## 石・分岐の座標範囲に応じて盤面の表示スコープを設定する。
  ## scope_root に --scope-size を設定することで board-base と ui-base の両方に伝播する。
  let zx = classify_range(xy[0])
  let zy = classify_range(xy[1])
  if zx == 1 and zy == 1 or zx == -1 or zy == -1:
    scope_root.style.setProperty("--scope-size", "19")
    return
  let dx = -cell_size * 3 * zx
  let dy = -cell_size * 3 * zy
  container.style.setProperty("transform", cstring(&"translate({dx}px, {dy}px)"))

## ====== 初期化 ======

proc init*(base: Element) =
  let sgf   = $base.getAttribute("data-sgf")
  var state = initAppState(sgf)
  var view  = ViewState(show_ans: false)

  # レイアウト: card-inner (flex row) > board-side | info-side
  let card_inner = base.h("div", "card-inner")
  let board_side = card_inner.h("div", "board-side")

  # 盤面 DOM (board-side 配下)
  let board_base = board_side.h("div", "board-base")
  put_svg_defs(board_base)
  let board      = block:
    let c = board_base.h("div", "board-container")
    c.draw_lines(state.board.size)
    discard c.h("div", "grid stone-grid")
    discard c.h("div", "grid marker-grid")
    discard c.h("div", "grid pointer-grid")
    discard c.h("div", "catcher")
    c
  change_scope(board_side, board, state.tree.xy_range())

  let catcher      = board.querySelector(".catcher")
  let marker_grid  = board.querySelector(".marker-grid")
  let pointer_grid = board.querySelector(".pointer-grid")

  # UI DOM (board-side 配下)
  let ui_base  = board_side.h("div", "ui-base")
  let ana_cont = ui_base.h("div", "button-container")
  let ans_cont = ui_base.h("div", "button-container")

  var ana_btns: array[6, Element]
  var ans_btns: array[8, Element]
  for i, lbl in ["|<", "<<", "<", ">", ">>", ">|"]:
    ana_btns[i] = ana_cont.h("button", "gb ana", text = lbl)
  for i, lbl in ["|<", "<<", "<", ">", ">>", ">|", "+<", ">+"]:
    ans_btns[i] = ans_cont.h("button", "gb ans", text = lbl)
  let branches_cont = ans_cont.h("div", "branches-container")

  # 情報パネル (card-inner 右側、常に表示)
  let info_side = card_inner.h("div", "info-side")

  # 手番インジケーター (最上段左上)
  let turn_row   = info_side.h("div", "turn-row")
  let turn_stone = turn_row.h("div",
    if state.board.turn == Black: "turn-stone black"
    else: "turn-stone white")

  # コメント (常に表示、編集不可)
  let comment_box = info_side.h("div", "comment-box")

  # 解答設定パネル (showAns まで非表示)
  let ans_settings = info_side.h("div", "ans-settings")

  # 表示/非表示の切り替え: ans_cont / branches_cont / ans_settings を showAns で toggle
  proc update_visibility() =
    if view.show_ans:
      ans_cont.style.removeProperty("display")
      ans_settings.style.removeProperty("display")
    else:
      ans_cont.style.setProperty("display", "none")
      ans_settings.style.setProperty("display", "none")

  # re_render と on_branch_click は互いに参照するため var で前置宣言する
  var re_render: proc()

  # 分岐ポインタ表示トグル (ans-settings 内)
  let ptr_btn = ans_settings.h("button", "gb ans ptr-toggle", text = "分岐表示")
  ptr_btn.addEventListener("click", proc(e: Event) =
    view.show_ans_ptr = not view.show_ans_ptr
    ptr_btn.className = cstring(
      if view.show_ans_ptr: "gb ans ptr-toggle active"
      else: "gb ans ptr-toggle")
    if view.show_ans_ptr:
      pointer_grid.style.removeProperty("display")
    else:
      pointer_grid.style.setProperty("display", "none"))

  proc on_branch_click(idx: int) =
    if state.move_branch(Answer, Next, One, idx).isOk:
      re_render()

  proc update_buttons() =
    let ab = state.tree.can_prev(Analysis)
    let af = state.tree.can_next(Analysis)
    let sb = state.tree.can_prev(Answer)
    let sf = state.tree.can_next(Answer)
    for i in 0 ..< 3: ana_btns[i].set_disabled(not ab)
    for i in 3 ..< 6: ana_btns[i].set_disabled(not af)
    for idx in [0, 1, 2, 6]: ans_btns[idx].set_disabled(not sb)
    for idx in [3, 4, 5, 7]: ans_btns[idx].set_disabled(not sf)

  proc update_turn() =
    turn_stone.className = cstring(
      if state.board.turn == Black: "turn-stone black"
      else: "turn-stone white")

  proc update_comment() =
    comment_box.textContent =
      if state.tree.current_node().props.hasKey("C"):
        cstring(state.tree.current_node().props["C"][0])
      else:
        cstring("")

  re_render = proc() =
    render(board, state)
    pointer_grid.clear()
    branches_cont.clear()
    if not state.tree.in_analysis():
      show_branches(pointer_grid, state.tree.ans_current_node(), on_branch_click, branches_cont)
    update_buttons()
    update_turn()
    update_comment()

  # 盤面クリック → 検討手を打つ
  catcher.addEventListener("click", proc(e: Event) =
    let me = cast[MouseEvent](e)
    let x  = int(me.offsetX) div cell_size + 1
    let y  = int(me.offsetY) div cell_size + 1
    if view.show_ans_ptr:
      let sel = ".pointer-wrapper[data-x='" & $x & "'][data-y='" & $y & "']"
      let el = pointer_grid.querySelector(cstring(sel))
      if el != nil:
        on_branch_click(parseInt($el.getAttribute("data-branch-idx")))
        return
    let move = Move(color: state.board.turn, kind: Put, coord: (x, y))
    if state.apply_move(move).isOk:
      re_render())

  # ana ボタン: 検討手のナビゲーション
  ana_btns[0].addEventListener("click", proc(e: Event) =
    if state.move_branch(Analysis, Prev, ToEnd).isOk: re_render())
  ana_btns[1].addEventListener("click", proc(e: Event) =
    if state.move_branch(Analysis, Prev, Ten).isOk: re_render())
  ana_btns[2].addEventListener("click", proc(e: Event) =
    if state.move_branch(Analysis, Prev, One).isOk: re_render())
  ana_btns[3].addEventListener("click", proc(e: Event) =
    if state.move_branch(Analysis, Next, One).isOk: re_render())
  ana_btns[4].addEventListener("click", proc(e: Event) =
    if state.move_branch(Analysis, Next, Ten).isOk: re_render())
  ana_btns[5].addEventListener("click", proc(e: Event) =
    if state.move_branch(Analysis, Next, ToEnd).isOk: re_render())

  # ans ボタン: 解答ツリーのナビゲーション
  ans_btns[0].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Prev, ToEnd).isOk: re_render())
  ans_btns[1].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Prev, Ten).isOk: re_render())
  ans_btns[2].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Prev, One).isOk: re_render())
  ans_btns[3].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Next, One).isOk: re_render())
  ans_btns[4].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Next, Ten).isOk: re_render())
  ans_btns[5].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Next, ToEnd).isOk: re_render())
  ans_btns[6].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Prev, ToNextBranch).isOk: re_render())
  ans_btns[7].addEventListener("click", proc(e: Event) =
    if state.move_branch(Answer, Next, ToNextBranch).isOk: re_render())

  # ans[3] (>) のホバーで ansPtr をハイライト
  ans_btns[3].addEventListener("mouseover", proc(e: Event) =
    let el = pointer_grid.querySelector(cstring(".pointer-wrapper"))
    if el != nil: el.classList.add(cstring("hover-state")))
  ans_btns[3].addEventListener("mouseout", proc(e: Event) =
    let el = pointer_grid.querySelector(cstring(".pointer-wrapper"))
    if el != nil: el.classList.remove(cstring("hover-state")))

  # showAns() フック登録
  g_on_show_ans = proc() =
    view.show_ans = true
    update_visibility()
    re_render()

  pointer_grid.style.setProperty("display", "none")
  update_visibility()
  re_render()

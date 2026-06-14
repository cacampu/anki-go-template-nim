import ../core/[board, gametree, properties, types]
import ../app/[state, handler]
import ../logic/comment
import board_draw
import std/[dom, strformat, strutils, tables]
import results

## gametree.Node と dom.Node の名前衝突を回避するエイリアス
type GameNode* = gametree.Node

## ====== 表示設定 ======

type ViewState* = object
  show_ans*: bool
  show_ans_ptr*: bool

## ====== showAns グローバル関数 ======

var g_on_show_ans: proc()

proc show_ans_impl() =
  if g_on_show_ans != nil: g_on_show_ans()

{.emit: "window['showAns'] = `show_ans_impl`;".}

## ====== マーカーの描画 ======

proc get_marker(grid: Element, coord: Coord): Element =
  grid.querySelector(cstring(coord_sel(coord)))

proc put_label_svg(grid: Element, text: string): Element =
  ## LB マーカー: テキストを getBBox() で計測してフォントサイズを動的調整する。
  const init_font_size = 60.0
  const safe_area      = 80.0   # viewBox 100x100 内の安全領域
  result = grid.hsvg("svg", "marker",
    attrs = [("viewBox", "0 0 100 100"),
             ("width",   $cell_size),
             ("height",  $cell_size)])
  # 背景矩形 (グリッド線を隠す / 石の上では透明)
  discard result.hsvg("rect",
    attrs = [("x", "0"), ("y", "0"), ("width", "100"), ("height", "100"),
             ("fill", "var(--fill-color, white)")])
  # テキスト要素 (まず不可視で追加して getBBox 計測後に表示)
  let txt = result.hsvg("text",
    attrs = [("x",                "50"),
             ("y",                "50"),
             ("text-anchor",      "middle"),
             ("dominant-baseline","middle"),
             ("font-size",        $init_font_size),
             ("font-family",      "sans-serif"),
             ("font-weight",      "bold"),
             ("pointer-events",   "none")])
  txt.style.setProperty("opacity", "0")
  txt.textContent = cstring(text)
  # getBBox でテキスト幅に応じてフォントサイズをスケール
  let w = bbox_width(txt)
  let h = bbox_height(txt)
  if w > 0 and h > 0:
    let scale = min(safe_area / w, safe_area / h)
    if scale < 1.0:
      txt.setAttribute("font-size", cstring($(init_font_size * scale)))
  txt.style.removeProperty("opacity")

proc put_marker(grid: Element, key: string, coord: Coord, text: string = ""): Element =
  if grid.get_marker(coord) != nil: return
  case key
  of "LB":          result = grid.put_label_svg(text)
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
  let btn = container.h("div", "gb ans branch", text = "+")
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
  let ana_cont = ui_base.h("div", "gb-container")
  let ans_cont = ui_base.h("div", "gb-container")

  var ana_btns: array[6, Element]
  var ans_btns: array[8, Element]
  for i, lbl in ["|<", "<<", "<", ">", ">>", ">|"]:
    ana_btns[i] = ana_cont.h("div", "gb ana", text = lbl)
  for i, lbl in ["|<", "<<", "<", ">", ">>", ">|", "+<", ">+"]:
    ans_btns[i] = ans_cont.h("div", "gb ans", text = lbl)
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
  let ptr_btn = ans_settings.h("div", "gb ans ptr-toggle", text = "分岐表示")
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
        cstring(render_comment(state.tree.current_node().props["C"][0], view.show_ans))
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
    if view.show_ans:
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
    state = initAppState(sgf)
    view.show_ans = true
    view.show_ans_ptr = true
    ptr_btn.setAttribute(cstring("class"), cstring("gb ans ptr-toggle active"))
    pointer_grid.style.removeProperty("display")
    update_visibility()
    re_render()

  pointer_grid.style.setProperty("display", "none")
  update_visibility()
  re_render()

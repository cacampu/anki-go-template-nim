import ../view/board_draw
import editor_state
import std/[dom, strformat, strutils]

## SGFエディタのメイン画面
## - 左ペイン: 全問題のサムネイル一覧 (縦スクロール, 右クリックでコンテキストメニュー)
## - 右ペイン: 選択中の問題の盤面・名前編集

const
  thumb_cell_size = 8
  edit_cell_size  = 32

var state = init_editor_state()

## ====== 盤面描画 ======

proc render_board(parent: Element, p: Problem, cell_size: int): Element =
  result = parent.h("div", "board-side editor-board",
    styles = [
      ("--board-size", $p.size),
      ("--scope-size", $p.size),
      ("--cell-size", &"{cell_size}px"),
      ("--offset", "2px"),
    ])
  let base = result.h("div", "board-base")
  let container = base.h("div", "board-container")
  container.draw_lines(p.size)
  let stone_grid = container.h("div", "grid stone-grid")
  discard container.h("div", "grid")  ## marker-grid placeholder (Phase2以降)
  stone_grid.update_stones(p.to_board())

## ====== コンテキストメニュー ======

var ctx_menu: Element
var ctx_target_id: int = -1

proc hide_context_menu() =
  ctx_menu.style.setProperty(cstring("display"), cstring("none"))
  ctx_target_id = -1

proc show_context_menu(x, y: int, problem_id: int) =
  ctx_target_id = problem_id
  ctx_menu.style.setProperty(cstring("display"), cstring("block"))
  ctx_menu.style.setProperty(cstring("left"), cstring(&"{x}px"))
  ctx_menu.style.setProperty(cstring("top"), cstring(&"{y}px"))

## ====== 再描画 ======

var thumb_list, edit_pane: Element
var prefix_input, counter_value_input, counter_padding_input, name_input: Element

proc render_app()

proc render_thumb_list() =
  thumb_list.clear()
  for p in state.problems:
    let item = thumb_list.h("div", "thumb-item")
    let pid = p.id
    if pid == state.selected_id:
      item.classList.add(cstring("selected"))
    item.setAttribute("data-id", cstring($pid))
    discard item.render_board(p, thumb_cell_size)
    discard item.h("div", "thumb-label", text = p.name)
    item.addEventListener("click", proc(e: Event) =
      state.selected_id = pid
      render_app())
    item.addEventListener("contextmenu", proc(e: Event) =
      e.preventDefault()
      let me = cast[MouseEvent](e)
      show_context_menu(me.clientX, me.clientY, pid))

proc render_edit_pane() =
  edit_pane.clear()
  if state.problems.len == 0:
    discard edit_pane.h("div", "empty-message", text = "盤面がありません。「新規作成」で追加してください。")
    name_input.disabled = true
    name_input.value = cstring("")
    return
  name_input.disabled = false
  let p = state.selected()
  name_input.value = cstring(p.name)
  discard edit_pane.render_board(p, edit_cell_size)

proc render_app() =
  prefix_input.value = cstring(state.prefix)
  counter_value_input.value = cstring($state.i_counter.value)
  counter_padding_input.value = cstring($state.i_counter.padding)
  render_thumb_list()
  render_edit_pane()
  hide_context_menu()

## ====== 初期化 ======

proc init*(root: Element) =
  root.clear()

  let header = root.h("div", "editor-header")
  discard header.h("label", text = "prefix: ")
  prefix_input = header.h("input", attrs = [("type", "text"), ("size", "30")])
  discard header.h("label", text = " {i} カウンター: ")
  counter_value_input = header.h("input", attrs = [("type", "number"), ("size", "4")])
  discard header.h("label", text = " パディング: ")
  counter_padding_input = header.h("input", attrs = [("type", "number"), ("size", "2")])
  let new_btn = header.h("button", text = "+ 新規作成")

  let body = root.h("div", "editor-body")
  thumb_list = body.h("div", "thumb-list")
  let edit_main = body.h("div", "edit-main")
  let name_pane = edit_main.h("div", "edit-pane")
  name_input = name_pane.h("input", "name-input", attrs = [("type", "text")])
  edit_pane = edit_main.h("div", "edit-pane-board")

  ctx_menu = root.h("div", "context-menu", styles = [("display", "none")])
  let dup_item = ctx_menu.h("div", "context-menu-item", text = "複製")
  let del_item = ctx_menu.h("div", "context-menu-item", text = "削除")

  prefix_input.addEventListener("change", proc(e: Event) =
    state.prefix = $prefix_input.value)

  counter_value_input.addEventListener("change", proc(e: Event) =
    try:
      state.i_counter.value = parseInt($counter_value_input.value)
    except ValueError:
      discard
    render_app())

  counter_padding_input.addEventListener("change", proc(e: Event) =
    try:
      state.i_counter.padding = max(0, parseInt($counter_padding_input.value))
    except ValueError:
      discard
    render_app())

  new_btn.addEventListener("click", proc(e: Event) =
    let size = if state.problems.len > 0: state.selected().size else: default_size
    state.add_new_problem(size)
    state.sort_problems()
    render_app())

  name_input.addEventListener("change", proc(e: Event) =
    if state.problems.len == 0: return
    state.rename_problem(state.selected_id, $name_input.value)
    state.sort_problems()
    render_app())

  dup_item.addEventListener("click", proc(e: Event) =
    if ctx_target_id < 0: return
    for p in state.problems:
      if p.id == ctx_target_id:
        state.duplicate_problem(p)
        break
    state.sort_problems()
    render_app())

  del_item.addEventListener("click", proc(e: Event) =
    if ctx_target_id < 0: return
    state.remove_problem(ctx_target_id)
    render_app())

  document.addEventListener("click", proc(e: Event) =
    hide_context_menu())

  render_app()

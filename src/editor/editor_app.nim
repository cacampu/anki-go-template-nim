import ../view/board_draw
import ../core/[types, board]
import editor_state
import std/[dom, strformat, strutils]

## SGFエディタのメイン画面
## - 左ペイン: 全問題のサムネイル一覧 (縦スクロール, 右クリックでコンテキストメニュー)
## - 右ペイン: 選択中の問題の盤面・モード切替・編集UI

const
  thumb_cell_size = 8
  edit_cell_size  = 32

type
  Mode = enum
    PlayMode
    EditMode

  EditTool = enum
    StoneTool
    TrTool
    SqTool
    CrTool
    MaTool

var state = init_editor_state()
var mode = EditMode
var edit_tool = StoneTool

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
    discard item.render_board(p.initial_board(), p.root.props, thumb_cell_size)
    discard item.h("div", "thumb-label", text = p.name)
    item.addEventListener("click", proc(e: Event) =
      state.selected_id = pid
      render_app())
    item.addEventListener("contextmenu", proc(e: Event) =
      e.preventDefault()
      let me = cast[MouseEvent](e)
      show_context_menu(me.clientX, me.clientY, pid))

## ====== 編集ペイン ======

proc bind_catcher_click(catcher: Element, idx: int) =
  catcher.addEventListener("click", proc(e: Event) =
    let me = cast[MouseEvent](e)
    let x = int(me.offsetX) div edit_cell_size + 1
    let y = int(me.offsetY) div edit_cell_size + 1
    let coord: Coord = (x, y)
    template p: untyped = state.problems[idx]
    case mode
    of PlayMode:
      if p.current_board()[coord] == Empty:
        play_move(p, coord)
    of EditMode:
      case edit_tool
      of StoneTool:
        if p.current == p.root:
          cycle_stone(p, coord)
      of TrTool: toggle_mark(p.current, "TR", coord)
      of SqTool: toggle_mark(p.current, "SQ", coord)
      of CrTool: toggle_mark(p.current, "CR", coord)
      of MaTool: toggle_mark(p.current, "MA", coord)
    render_app())

proc render_mode_toggle(parent: Element, idx: int) =
  let row = parent.h("div", "mode-toggle")
  let play_btn = row.h("div", "mode-btn" & (if mode == PlayMode: " active" else: ""), text = "着手モード")
  let edit_btn = row.h("div", "mode-btn" & (if mode == EditMode: " active" else: ""), text = "編集モード")
  play_btn.addEventListener("click", proc(e: Event) =
    mode = PlayMode
    render_app())
  edit_btn.addEventListener("click", proc(e: Event) =
    mode = EditMode
    render_app())

proc render_tool_palette(parent: Element, idx: int) =
  let row = parent.h("div", "tool-palette")
  template p: untyped = state.problems[idx]
  proc tool_btn(tool: EditTool, label: string) =
    let btn = row.h("div", "tool-btn" & (if edit_tool == tool: " active" else: ""), text = label)
    btn.addEventListener("click", proc(e: Event) =
      edit_tool = tool
      render_app())
  if p.current == p.root:
    tool_btn(StoneTool, "石")
  tool_btn(TrTool, "△")
  tool_btn(SqTool, "□")
  tool_btn(CrTool, "○")
  tool_btn(MaTool, "×")

proc render_play_nav(parent: Element, idx: int) =
  let row = parent.h("div", "play-nav")
  template p: untyped = state.problems[idx]
  let turn = p.current_board().turn
  discard row.h("div",
    if turn == Black: "turn-stone black" else: "turn-stone white")
  let back_btn = row.h("button", text = "← 戻る")
  let fwd_btn  = row.h("button", text = "進む →")
  let del_btn  = row.h("button", text = "✕ このノードを削除")
  back_btn.set_disabled(p.current == p.root)
  fwd_btn.set_disabled(p.current.children.len == 0)
  del_btn.set_disabled(p.current == p.root)
  back_btn.addEventListener("click", proc(e: Event) =
    go_to_parent(state.problems[idx])
    render_app())
  fwd_btn.addEventListener("click", proc(e: Event) =
    go_to_first_child(state.problems[idx])
    render_app())
  del_btn.addEventListener("click", proc(e: Event) =
    delete_current_node(state.problems[idx])
    render_app())

proc render_comment_edit(parent: Element, idx: int) =
  template p: untyped = state.problems[idx]
  let box = parent.h("div", "comment-edit")
  discard box.h("label", text = "コメント")
  let textarea = box.h("textarea", attrs = [("rows", "3")])
  textarea.value = cstring(comment(p.current))
  textarea.addEventListener("change", proc(e: Event) =
    set_comment(state.problems[idx].current, $textarea.value))

proc render_edit_pane() =
  edit_pane.clear()
  if state.problems.len == 0:
    discard edit_pane.h("div", "empty-message", text = "盤面がありません。「新規作成」で追加してください。")
    name_input.disabled = true
    name_input.value = cstring("")
    return
  name_input.disabled = false
  let idx = state.selected_index()
  let p = state.problems[idx]
  name_input.value = cstring(p.name)

  render_mode_toggle(edit_pane, idx)
  case mode
  of EditMode: render_tool_palette(edit_pane, idx)
  of PlayMode: render_play_nav(edit_pane, idx)

  let board_el = edit_pane.h("div", "edit-pane-board")
  let result = board_el.render_board(p.current_board(), p.current.props, edit_cell_size, interactive = true)
  let catcher = result.querySelector(".catcher")
  bind_catcher_click(catcher, idx)

  render_comment_edit(edit_pane, idx)

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
  put_svg_defs(root)

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
  edit_pane = edit_main.h("div", "edit-pane-content")

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

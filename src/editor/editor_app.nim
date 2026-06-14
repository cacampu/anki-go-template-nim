import ../view/board_draw
import ../core/[types, board]
import editor_state
import std/[dom, strformat, strutils, asyncjs, jsffi]

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

  DragAction = enum
    NoAction
    PlaceBlack
    PlaceWhite
    DeleteStone

var state = init_editor_state()
var mode = EditMode
var edit_tool = StoneTool
var dragging = false
var drag_action = NoAction
var drag_last: Coord

proc event_to_coord(e: Event, cell_size, size: int): Coord =
  let me = cast[MouseEvent](e)
  let x = clamp(int(me.offsetX) div cell_size + 1, 1, size)
  let y = clamp(int(me.offsetY) div cell_size + 1, 1, size)
  (x, y)

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

proc bind_thumb_item(item: Element, pid: int) =
  ## pid をクロージャで個別に捕捉するため、ループ本体から分離したprocで束縛する
  ## (forループ内で直接addEventListenerすると、Nimのjsバックエンドで
  ## 全イテレーションが単一のクロージャ環境を共有してしまい、
  ## どのサムネイルをクリックしても最後のpidが使われてしまう)
  item.addEventListener("click", proc(e: Event) =
    state.selected_id = pid
    render_app())
  item.addEventListener("contextmenu", proc(e: Event) =
    e.preventDefault()
    let me = cast[MouseEvent](e)
    show_context_menu(me.clientX, me.clientY, pid))

proc render_thumb_list() =
  thumb_list.clear()
  for p in state.problems:
    let item = thumb_list.h("div", "thumb-item")
    let pid = p.id
    if pid == state.selected_id:
      item.classList.add(cstring("selected"))
    item.setAttribute("data-id", cstring($pid))
    discard item.render_board(p.initial_board(), p.root, thumb_cell_size, show_pointers = false)
    discard item.h("div", "thumb-label", text = p.name)
    item.bind_thumb_item(pid)

## ====== 編集ペイン ======

proc find_branch_idx(pointer_grid: Element, coord: Coord): int =
  ## coord に分岐ポインタがあれば data-branch-idx を返す。なければ -1
  let sel = &".pointer-wrapper[data-x='{coord.x}'][data-y='{coord.y}']"
  let el = pointer_grid.querySelector(cstring(sel))
  if el != nil and el.hasAttribute(cstring("data-branch-idx")):
    parseInt($el.getAttribute("data-branch-idx"))
  else:
    -1

proc bind_catcher_click(catcher: Element, pointer_grid: Element, idx: int) =
  template p: untyped = state.problems[idx]
  let sz = p.size

  catcher.addEventListener("contextmenu", proc(e: Event) =
    e.preventDefault())

  catcher.addEventListener("mousedown", proc(e: Event) =
    e.preventDefault()
    if not (mode == EditMode and edit_tool == StoneTool and p.current == p.root):
      return
    let me = cast[MouseEvent](e)
    let coord = event_to_coord(e, edit_cell_size, sz)
    let cur = p.initial_board()[coord]
    if me.button == 2:
      if cur == Empty:
        set_stone(p, coord, White)
        drag_action = PlaceWhite
        dragging = true
      else:
        set_stone(p, coord, Empty)
        drag_action = DeleteStone
        dragging = true
    else:
      if cur == Empty:
        set_stone(p, coord, Black)
        drag_action = PlaceBlack
        dragging = true
      else:
        invert_stone(p, coord)
        dragging = false
    drag_last = coord
    render_app())

  catcher.addEventListener("mousemove", proc(e: Event) =
    if not dragging: return
    let coord = event_to_coord(e, edit_cell_size, sz)
    if coord == drag_last: return
    drag_last = coord
    let cur = p.initial_board()[coord]
    case drag_action
    of PlaceBlack:
      if cur == Empty: set_stone(p, coord, Black)
    of PlaceWhite:
      if cur == Empty: set_stone(p, coord, White)
    of DeleteStone:
      if cur != Empty: set_stone(p, coord, Empty)
    of NoAction: discard
    render_app())

  catcher.addEventListener("click", proc(e: Event) =
    let coord = event_to_coord(e, edit_cell_size, sz)
    case mode
    of PlayMode:
      let branch_idx = find_branch_idx(pointer_grid, coord)
      if branch_idx >= 0:
        go_to_child(p, branch_idx)
      elif p.current_board()[coord] == Empty:
        play_move(p, coord)
    of EditMode:
      case edit_tool
      of StoneTool: discard ## mousedown で処理済み
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
  if p.current == p.root:
    let turn = p.current_board().turn
    let turn_btn = row.h("div", "tool-btn turn-toggle",
      text = (if turn == Black: "● 黒番" else: "○ 白番"))
    turn_btn.addEventListener("click", proc(e: Event) =
      toggle_turn(state.problems[idx])
      render_app())

proc render_play_nav(parent: Element, idx: int) =
  let row = parent.h("div", "play-nav")
  template p: untyped = state.problems[idx]
  let turn = p.current_board().turn
  discard row.h("div",
    if turn == Black: "turn-stone black" else: "turn-stone white")
  let back_btn = row.h("button", text = "← 戻る")
  let fwd_btn  = row.h("button", text = "進む →")
  let pass_btn = row.h("button", text = "パス")
  let up_btn   = row.h("button", text = "▲ 順序")
  let down_btn = row.h("button", text = "▼ 順序")
  let del_btn  = row.h("button", text = "✕ このノードを削除")
  back_btn.set_disabled(p.current == p.root)
  fwd_btn.set_disabled(p.current.children.len == 0)
  up_btn.set_disabled(not p.can_move_sibling(-1))
  down_btn.set_disabled(not p.can_move_sibling(1))
  del_btn.set_disabled(p.current == p.root)
  back_btn.addEventListener("click", proc(e: Event) =
    go_to_parent(state.problems[idx])
    render_app())
  fwd_btn.addEventListener("click", proc(e: Event) =
    go_to_first_child(state.problems[idx])
    render_app())
  pass_btn.addEventListener("click", proc(e: Event) =
    play_pass(state.problems[idx])
    render_app())
  up_btn.addEventListener("click", proc(e: Event) =
    move_sibling(state.problems[idx], -1)
    render_app())
  down_btn.addEventListener("click", proc(e: Event) =
    move_sibling(state.problems[idx], 1)
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

  let row = edit_pane.h("div", "edit-pane-row")
  let board_el = row.h("div", "edit-pane-board")
  let result = board_el.render_board(p.current_board(), p.current, edit_cell_size, interactive = true)
  let catcher = result.querySelector(".catcher")
  let pointer_grid = result.querySelector(".pointer-grid")
  bind_catcher_click(catcher, pointer_grid, idx)

  render_comment_edit(row, idx)

proc render_app() =
  prefix_input.value = cstring(state.prefix)
  counter_value_input.value = cstring($state.i_counter.value)
  counter_padding_input.value = cstring($state.i_counter.padding)
  render_thumb_list()
  render_edit_pane()
  hide_context_menu()

## ====== SGF書き出し (File System Access API) ======

proc hasDirectoryPicker(): bool {.importjs: "(typeof window.showDirectoryPicker === 'function')".}
proc showDirectoryPicker(): Future[JsObject] {.importjs: "window.showDirectoryPicker()".}
proc getDirectoryHandle(parent: JsObject, name: cstring): Future[JsObject] {.importjs: "#.getDirectoryHandle(#, {create: true})".}
proc getFileHandle(parent: JsObject, name: cstring): Future[JsObject] {.importjs: "#.getFileHandle(#, {create: true})".}
proc createWritable(file: JsObject): Future[JsObject] {.importjs: "#.createWritable()".}
proc writeText(w: JsObject, data: cstring): Future[JsObject] {.importjs: "#.write(#)".}
proc closeWritable(w: JsObject): Future[JsObject] {.importjs: "#.close()".}

proc export_problem(root_dir: JsObject, prefix: string, p: Problem): Future[void] {.async.} =
  var dir = root_dir
  for seg in prefix.split("::"):
    if seg.len == 0: continue
    dir = await dir.getDirectoryHandle(cstring(seg))
  let file = await dir.getFileHandle(cstring(p.name & ".sgf"))
  let writable = await file.createWritable()
  discard await writable.writeText(cstring(p.problem_sgf()))
  discard await writable.closeWritable()

proc export_all(): Future[void] {.async.} =
  if not hasDirectoryPicker():
    window.alert(cstring("このブラウザはエクスポート機能(File System Access API)に対応していません。Chrome等をご利用ください。"))
    return
  let root_dir = await showDirectoryPicker()
  for p in state.problems:
    await export_problem(root_dir, state.prefix, p)
  window.alert(cstring("書き出しが完了しました。"))

proc handle_export_error(reason: Error) =
  ## ピッカーのキャンセル(AbortError)は無視し、それ以外のエラーは表示する。
  ## (asyncjsのFuture内でNimのtry/exceptを使うとraiseDefectで再送出されてしまうため、
  ## 呼び出し側でFuture.catchを使う)
  if $reason.name != "AbortError":
    window.alert(cstring("書き出しに失敗しました: " & $reason.message))

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
  let export_btn = header.h("button", text = "SGFを書き出し")

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

  export_btn.addEventListener("click", proc(e: Event) =
    discard export_all().catch(handle_export_error))

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

  document.addEventListener("mouseup", proc(e: Event) =
    dragging = false)

  render_app()

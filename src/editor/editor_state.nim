import ../core/[types, board, gametree, properties]
import ../logic/[rules, parser]
import results
import std/[algorithm, strutils, sequtils, tables]

## SGFエディタのアプリ全体状態

const default_size* = 19

type Problem* = object
  id*: int
    ## 安定した識別子 (ソート後も選択状態を維持するために使う)
  name*: string ## "{i}" または "{i}_{j}" (例: "04", "09_1")
  root*: Node ## SGFツリーのルートノード (SZ/AB/AW/PL を保持)
  current*: Node ## 現在表示・編集中のノード

type CounterConfig* = object
  value*: int
  padding*: int

type EditorState* = object
  prefix*: string ## "隅の死活::6目型::"
  problems*: seq[Problem]
  selected_id*: int ## 選択中(編集中) Problem の id
  i_counter*: CounterConfig
  next_id: int

proc init_editor_state*(): EditorState =
  result.prefix = ""
  result.i_counter = CounterConfig(value: 1, padding: 2)
  result.next_id = 1

proc pad_number(n: int, padding: int): string =
  result = $n
  while result.len < padding:
    result = "0" & result

proc next_name(state: var EditorState): string =
  result = pad_number(state.i_counter.value, state.i_counter.padding)
  state.i_counter.value += 1

proc alloc_id(state: var EditorState): int =
  result = state.next_id
  state.next_id += 1

## ====== 盤面サイズ・局面の計算 ======

proc size*(p: Problem): int =
  if "SZ" in p.root.props:
    parseInt(p.root.props["SZ"][0])
  else:
    default_size

proc initial_board*(p: Problem): Board =
  result = initBoard(p.size)
  if "AB" in p.root.props:
    for v in p.root.props["AB"]:
      result[parseCoord(v)] = Black
  if "AW" in p.root.props:
    for v in p.root.props["AW"]:
      result[parseCoord(v)] = White
  if "PL" in p.root.props and p.root.props["PL"][0] == "W":
    result.turn = White
  else:
    result.turn = Black

proc path_from_root*(p: Problem): seq[Node] =
  ## root を含まない、root直後から current までのノードのリスト
  var n = p.current
  while n != p.root:
    result.add(n)
    n = n.parent
  result.reverse()

proc current_board*(p: Problem): Board =
  result = p.initial_board()
  for n in p.path_from_root():
    let move: Move = n.props
    let applied = apply_move(result, move)
    if applied.isOk:
      result = applied.get

proc problem_sgf*(p: Problem): string =
  ## 盤面1つ分のSGF文字列 (書き出し用)
  parser.serialize(initTree(p.root))

proc selected*(state: EditorState): Problem =
  for p in state.problems:
    if p.id == state.selected_id:
      return p

proc selected_index*(state: EditorState): int =
  for i, p in state.problems:
    if p.id == state.selected_id:
      return i
  -1

proc selected_mut*(state: var EditorState): var Problem =
  for i in 0 ..< state.problems.len:
    if state.problems[i].id == state.selected_id:
      return state.problems[i]
  state.problems[0]

## ====== 盤面の追加・複製・削除 ======

proc add_new_problem*(state: var EditorState, size: int = default_size) =
  let root = Node(props: {"SZ": @[$size]}.toOrderedTable)
  let p =
    Problem(id: state.alloc_id(), name: state.next_name(), root: root, current: root)
  state.problems.add(p)
  state.selected_id = p.id

proc reset_problem*(p: var Problem) =
  ## root ノードを盤サイズのみ保持した新規作成直後の状態に戻す
  let root = Node(props: {"SZ": @[$p.size]}.toOrderedTable)
  p.root = root
  p.current = root

proc duplicate_problem*(state: var EditorState, src: Problem) =
  var props: Properties
  for key in ["SZ", "AB", "AW", "PL"]:
    if key in src.root.props:
      props[key] = src.root.props[key]
  let root = Node(props: props)
  let p =
    Problem(id: state.alloc_id(), name: state.next_name(), root: root, current: root)
  state.problems.add(p)
  state.selected_id = p.id

proc remove_problem*(state: var EditorState, id: int) =
  let was_selected = state.selected_id == id
  let idx = block:
    var r = -1
    for i, p in state.problems:
      if p.id == id:
        r = i
        break
    r
  if idx < 0:
    return
  state.problems.delete(idx)
  if was_selected and state.problems.len > 0:
    let next_idx = min(idx, state.problems.len - 1)
    state.selected_id = state.problems[next_idx].id

proc rename_problem*(state: var EditorState, id: int, name: string) =
  for i in 0 ..< state.problems.len:
    if state.problems[i].id == id:
      state.problems[i].name = name
      return

## ====== 編集モード: 石・マーク・コメント ======

proc remove_coord(props: var Properties, key: string, coord: Coord) =
  if key in props:
    props[key] = props[key].filterIt(it != $coord)
    if props[key].len == 0:
      props.del(key)

proc add_coord(props: var Properties, key: string, coord: Coord) =
  if key in props:
    props[key].add($coord)
  else:
    props[key] = @[$coord]

proc set_stone*(p: var Problem, coord: Coord, color: PointState) =
  ## root ノードのみで有効: 初期配置 (AB/AW) を直接指定した色に設定する
  if p.current != p.root:
    return
  p.root.props.remove_coord("AB", coord)
  p.root.props.remove_coord("AW", coord)
  case color
  of Black:
    p.root.props.add_coord("AB", coord)
  of White:
    p.root.props.add_coord("AW", coord)
  of Empty:
    discard

proc invert_stone*(p: var Problem, coord: Coord) =
  ## root ノードのみで有効: 石があれば色を反転する。空点は no-op
  if p.current != p.root:
    return
  case p.initial_board()[coord]
  of Black:
    p.set_stone(coord, White)
  of White:
    p.set_stone(coord, Black)
  of Empty:
    discard

proc toggle_turn*(p: var Problem) =
  ## root ノードのみで有効: PL プロパティをトグルして手番を交代する
  if p.current != p.root:
    return
  if "PL" in p.root.props and p.root.props["PL"].len > 0 and p.root.props["PL"][0] == "W":
    p.root.props.del("PL")
  else:
    p.root.props["PL"] = @["W"]

proc toggle_mark*(node: Node, key: string, coord: Coord) =
  ## TR/SQ/CR/MA は対等かつ排他: 既に同じ種別が置かれていれば消し、
  ## 別の種別が置かれていればそれを消して新しい種別を置く
  const mark_keys = ["TR", "SQ", "CR", "MA"]
  var props = node.props
  let was_set = key in props and ($coord) in props[key]
  for k in mark_keys:
    props.remove_coord(k, coord)
  if not was_set:
    props.add_coord(key, coord)
  node.props = props

proc comment*(node: Node): string =
  if "C" in node.props and node.props["C"].len > 0:
    node.props["C"][0]
  else:
    ""

proc set_comment*(node: Node, text: string) =
  if text.len == 0:
    node.props.del("C")
  else:
    node.props["C"] = @[text]

## ====== 着手モード: ツリー操作 ======

proc add_move_node*(p: var Problem, move: Move) =
  let node = Node(props: move.toProperty())
  add_child(p.current, node)
  p.current = node

proc play_move*(p: var Problem, coord: Coord) =
  let turn = p.current_board().turn
  add_move_node(p, Move(color: turn, kind: Put, coord: coord))

proc play_pass*(p: var Problem) =
  let turn = p.current_board().turn
  add_move_node(p, Move(color: turn, kind: Pass))

proc go_to_parent*(p: var Problem) =
  if p.current != p.root:
    p.current = p.current.parent

proc go_to_first_child*(p: var Problem) =
  if p.current.children.len > 0:
    p.current = p.current.children[0]

proc go_to_child*(p: var Problem, idx: int) =
  if idx >= 0 and idx < p.current.children.len:
    p.current = p.current.children[idx]

proc can_move_sibling*(p: Problem, delta: int): bool =
  ## current ノードが親の children 内で delta (±1) 移動できるか
  if p.current == p.root:
    return false
  let siblings = p.current.parent.children
  let idx = siblings.find(p.current)
  let new_idx = idx + delta
  new_idx >= 0 and new_idx < siblings.len

proc move_sibling*(p: var Problem, delta: int) =
  ## current ノードを親の children 内で隣接要素と入れ替える (children[0] が本筋)
  if not p.can_move_sibling(delta):
    return
  var siblings = p.current.parent.children
  let idx = siblings.find(p.current)
  swap(siblings[idx], siblings[idx + delta])
  p.current.parent.children = siblings

proc delete_current_node*(p: var Problem) =
  if p.current != p.root:
    p.current = remove(p.current)

## ====== 自然順ソート ======
## "04" < "09_1" < "09_2" < "10" のように、数字部分を数値として比較する

proc split_segments(s: string): seq[string] =
  var cur = ""
  var cur_is_digit = false
  for c in s:
    let is_digit = c in {'0' .. '9'}
    if cur.len > 0 and is_digit != cur_is_digit:
      result.add(cur)
      cur = ""
    cur.add(c)
    cur_is_digit = is_digit
  if cur.len > 0:
    result.add(cur)

proc compare_natural*(a, b: string): int =
  let sa = split_segments(a)
  let sb = split_segments(b)
  for i in 0 ..< min(sa.len, sb.len):
    let (xa, xb) = (sa[i], sb[i])
    if xa.len > 0 and xb.len > 0 and xa[0] in {'0' .. '9'} and xb[0] in {'0' .. '9'}:
      let (na, nb) = (parseInt(xa), parseInt(xb))
      if na != nb:
        return cmp(na, nb)
    else:
      if xa != xb:
        return cmp(xa, xb)
  cmp(sa.len, sb.len)

proc sort_problems*(state: var EditorState) =
  state.problems.sort(
    proc(a, b: Problem): int =
      compare_natural(a.name, b.name)
  )

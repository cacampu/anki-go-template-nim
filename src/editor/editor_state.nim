import ../core/[types, board]
import std/[algorithm, strutils]

## SGFエディタのアプリ全体状態

const default_size* = 19

type Problem* = object
  id*: int             ## 安定した識別子 (ソート後も選択状態を維持するために使う)
  name*: string        ## "{i}" または "{i}_{j}" (例: "04", "09_1")
  size*: int           ## 盤サイズ
  ab*: seq[Coord]      ## 初期配置: 黒石
  aw*: seq[Coord]      ## 初期配置: 白石

type CounterConfig* = object
  value*: int
  padding*: int

type EditorState* = object
  prefix*: string        ## "隅の死活::6目型::"
  problems*: seq[Problem]
  selected_id*: int       ## 選択中(編集中) Problem の id
  i_counter*: CounterConfig
  next_id: int

proc init_editor_state*(): EditorState =
  result.prefix = ""
  result.i_counter = CounterConfig(value: 0, padding: 2)
  result.next_id = 1

proc pad_number(n: int, padding: int): string =
  result = $n
  while result.len < padding:
    result = "0" & result

proc next_name(state: var EditorState): string =
  state.i_counter.value += 1
  pad_number(state.i_counter.value, state.i_counter.padding)

proc alloc_id(state: var EditorState): int =
  result = state.next_id
  state.next_id += 1

proc to_board*(p: Problem): Board =
  result = initBoard(p.size)
  for c in p.ab:
    result[c] = Black
  for c in p.aw:
    result[c] = White

proc selected*(state: EditorState): Problem =
  for p in state.problems:
    if p.id == state.selected_id:
      return p

proc selected_index*(state: EditorState): int =
  for i, p in state.problems:
    if p.id == state.selected_id:
      return i
  -1

proc add_new_problem*(state: var EditorState, size: int = default_size) =
  let p = Problem(id: state.alloc_id(), name: state.next_name(), size: size, ab: @[], aw: @[])
  state.problems.add(p)
  state.selected_id = p.id

proc duplicate_problem*(state: var EditorState, src: Problem) =
  let p = Problem(
    id: state.alloc_id(), name: state.next_name(),
    size: src.size, ab: src.ab, aw: src.aw)
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
  if idx < 0: return
  state.problems.delete(idx)
  if was_selected and state.problems.len > 0:
    let next_idx = min(idx, state.problems.len - 1)
    state.selected_id = state.problems[next_idx].id

proc rename_problem*(state: var EditorState, id: int, name: string) =
  for i in 0 ..< state.problems.len:
    if state.problems[i].id == id:
      state.problems[i].name = name
      return

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
      if na != nb: return cmp(na, nb)
    else:
      if xa != xb: return cmp(xa, xb)
  cmp(sa.len, sb.len)

proc sort_problems*(state: var EditorState) =
  state.problems.sort(proc(a, b: Problem): int = compare_natural(a.name, b.name))

import board
import nodetree
import rules
import parser
import appstate
import results
import tables
import strutils

proc parseCoord(s: string): Coord =
  let x = s[0].toLowerAscii.ord - 'a'.ord
  let y = s[1].toLowerAscii.ord - 'a'.ord
  (x, y)

proc initBoard(node: Node): Board =
  let size = if "SZ" in node.props:
    node.props["SZ"][0].parseInt()
  else:
    19
  result = initBoard(size)
  for key, values in node.props:
    case key
    of "AB":
      for v in values:
        let coord = parseCoord(v)
        result[coord] = Black
    of "AW":
      for v in values:
        let coord = parseCoord(v)
        result[coord] = White
    of "PL":
      if values[0] == "B":
        result.turn = Black
      elif values[0] == "W":
        result.turn = White
    else:
      discard

proc initState*(sgf: string): AppState =
  result.sgf = sgf
  result.tree = initGameTree(sgf.parse())
  result.board = initBoard(result.tree.current_node())

converter toProperty(move: Move): Properties =
  let turn_color = case move.color
    of Black: "B"
    of White: "W"
  let coord = case move.kind
  of Put:
    $move.coord
  of Pass:
    ""
  of Resign:
    ""
  result[turn_color] = @[coord]
converter toMove(props: Properties): Move =
  proc is_pass(coord_str: string): bool =
    coord_str == "" or coord_str == "tt"
  if "B" in props:
    let coord_str = props["B"][0]
    if coord_str.is_pass():
      result = Move(color: Black, kind: Pass)
    else:
      let coord = parseCoord(coord_str)
      result = Move(color: Black, kind: Put, coord: coord)
  elif "W" in props:
    let coord_str = props["W"][0]
    if coord_str.is_pass():
      result = Move(color: White, kind: Pass)
    else:
      let coord = parseCoord(coord_str)
      result = Move(color: White, kind: Put, coord: coord)


proc apply_move*(state: var AppState, move: Move): Result[(), string] =
  let new_board = ?state.board.apply_move(move)
  state.moves.add(move)
  state.caches.add(state.board)
  state.board = new_board
  # Add node to the answer tree
  let props: Properties = move
  state.tree.add_ana_node(Node(props: props))
  state.tree.go_next(Analysis)
  ok(())

type
  Dir* = enum
    Prev, Next
  Ammount* = enum
    One, Five, ToEnd, ToBranch


proc move_branch_impl(state: var AppState, bk: BranchKind, dir: Dir,
    i: int = 0): Result[(), string] =
  proc reset_cahces_and_moves() =
    let len = state.tree.depth
    state.moves.setLen(len)
    state.caches.setLen(len)
  case dir
  of Prev:
    if not state.tree.can_prev(bk):
      return err("これ以上戻れません")
    state.tree.go_prev(bk)
    state.board = state.caches[state.tree.depth]
    reset_cahces_and_moves()
    ok(())
  of Next:
    if not state.tree.can_next(bk, i):
      return err("これ以上進めません")
    state.tree.go_next(bk, i)
    let prev_board = state.caches[state.tree.depth - 1]
    let move: Move = state.tree.current_node().props
    let new_board = ?prev_board.apply_move(move)
    state.board = new_board
    reset_cahces_and_moves()
    ok(())

proc move_branch*(state: var AppState, bk: BranchKind, dir: Dir, amt: Ammount,
    i: int = 0): Result[(), string] =
  case amt
  of One:
    move_branch_impl(state, bk, dir, i)
  of Five:
    for _ in 0 ..< 5:
      discard move_branch_impl(state, bk, dir, i)
    ok(())
  of ToEnd:
    while true:
      let res = move_branch_impl(state, bk, dir, i)
      if res.isErr:
        break
    ok(())
  of ToBranch:
    while true:
      let res = move_branch_impl(state, bk, dir, i)
      if state.tree.has_ans_branch() or res.isErr:
        break
    ok(())



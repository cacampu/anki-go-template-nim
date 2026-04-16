import ../core/[types, board, properties, gametree]
import ../logic/[rules, parser]
import state
import results
import tables
import strutils

proc initBoard(tree: GameTree): Board =
  let node = tree.root()
  let size =
    if "SZ" in node.props:
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

proc initAppState*(sgf: string): AppState =
  result.sgf = sgf
  result.tree = initGameTree(sgf.parse())
  result.board = initBoard(result.tree)

proc apply_move*(state: var AppState, move: Move): Result[(), string] =
  let new_board = ?state.board.apply_move(move)
  state.moves.add(move)
  state.histories.add(state.board)
  state.board = new_board
  # Add node to the analysis tree
  let props: Properties = move
  state.tree.add_ana_node(Node(props: props))
  state.tree.go_next(Analysis)
  ok(())

type
  Dir* = enum
    Prev
    Next

  Ammount* = enum
    One
    Five
    ToEnd
    ToNextBranch

proc move_branch_impl(
    state: var AppState, bk: BranchKind, dir: Dir, i: int = 0
): Result[(), string] =
  proc reset_cahces_and_moves() =
    let len = state.tree.depth
    state.moves.setLen(len)
    state.histories.setLen(len)

  case dir
  of Prev:
    if not state.tree.can_prev(bk):
      return err("これ以上戻れません")
    state.tree.go_prev(bk)
    state.board = state.histories[state.tree.depth]
    reset_cahces_and_moves()
    ok(())
  of Next:
    if not state.tree.can_next(bk, i):
      return err("これ以上進めません")
    state.tree.go_next(bk, i)
    let prev_board = state.histories[state.tree.depth - 1]
    let move: Move = state.tree.current_node().props
    let new_board = ?prev_board.apply_move(move)
    state.board = new_board
    reset_cahces_and_moves()
    ok(())

proc move_branch*(
    state: var AppState, bk: BranchKind, dir: Dir, amt: Ammount, i: int = 0
): Result[(), string] =
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
  of ToNextBranch:
    while true:
      let res = move_branch_impl(state, bk, dir, i)
      if state.tree.has_ans_branch() or res.isErr:
        break
    ok(())

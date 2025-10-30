import board
import results
import options
import sequtils

type
    MoveKind* = enum
        Put, Pass, Resign
    Move* = object
        color*: Color
        case kind*: MoveKind
        of Put:
            coord*: Coord
        of Pass:
            discard
        of Resign:
            discard

proc `+`(a: Coord, b: Coord): Coord =
    (a.x+b.x, a.y+b.y)

proc neighbors(board: Board, coord: Coord): seq[Coord] =
    let dir = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    for d in dir:
        let neighbor = coord+d
        if neighbor.in_bounds_of(board):
            result.add(neighbor)

proc put_stone(board: Board, coord: Coord, turn: Color): Result[Board, string] =
    if not coord.in_bounds_of(board):
        return err("範囲外に石を置こうとしました")
    if board.kou_pt.isSome and turn == board.turn and coord == board.kou_pt.get:
        return err("コウです")
    if board[coord] != Empty:
        return err("すでに石が置かれています")

    var board = board
    board[coord] = turn
    board.turn = turn
    board.state = Ongoing

    proc capture(coord: Coord, color: Color): bool =
        var vis = initBitBoard(board.size, color)
        proc cpt_dfs(coord: Coord): bool =
            let state = board[coord]
            if state == Empty:
                return false
            if state == color.opp:
                return true
            if vis[coord]:
                return true
            vis[coord] = true
            board.neighbors(coord).all(cpt_dfs)
        if cpt_dfs(coord):
            board.remove(vis)
            board.kou_pt = if vis.count() == 1: some(coord) else: none(Coord)
            true
        else:
            false

    let neighbors = board.neighbors(coord)
    for n in neighbors:
        if board[n] == turn.opp:
            discard capture(n, turn.opp)
    if capture(coord, turn):
        return err("自殺手です")

    proc n_cnt(state: PointState): int =
        neighbors.countIt(board[it] == state)
    if not(n_cnt(turn) == 0 and n_cnt(Empty) == 1):
        board.kou_pt = none(Coord)

    board.turn_change()
    ok(board)

proc pass(board: Board): Result[Board, string] =
    var board = board
    board.turn_change()
    case board.state
    of Ongoing:
        board.state = Passed
    of Passed:
        board.state = Finished
    else:
        assert(false)
    ok(board)

proc resign(board: Board): Result[Board, string] =
    var board = board
    board.turn_change()
    board.state = Resigned
    ok(board)



proc apply_move*(board: Board, move: Move): Result[Board, string] =
    if board.state == Resigned or board.state == Finished:
        return err("終局した盤面にmoveを適用しようとしました")
    case move.kind
    of Put:
        board.put_stone(move.coord, move.color)
    of Pass:
        board.pass()
    of Resign:
        board.resign()



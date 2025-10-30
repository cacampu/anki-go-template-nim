import std/options
import std/strformat
type
    Bits = set[1..19*19]
    Coord* = tuple[x: int, y: int]
    Color* = enum
        Black, White
    PointState* = enum
        Black, White, Empty
    GameState* = enum
        Ongoing,
        Passed,
        Finished,
        Resigned

type Board* = object
    size: int
    turn*: Color
    kou_pt*: Option[Coord]
    b_stones: Bits
    w_stones: Bits
    state*: GameState

type BitBoard* = object
    size: int
    color: Color
    bits: Bits

type Boards = concept T
    T is Board or T is BitBoard

proc opp*(color: Color): Color =
    case color
    of Black:
        White
    of White:
        Black

proc in_bounds_of*(coord: Coord, board: Boards): bool =
    let (x, y) = coord
    let rng = 1..board.size
    result = x in rng and y in rng

proc `[]`*(self: Board, coord: Coord): PointState =
    let (x, y) = coord
    if not coord.in_bounds_of(self):
        raise newException(IndexDefect, &"Index ({x}, {y}) is out of bounds")
    let idx = x + (y-1)*self.size
    result =
        if idx in self.b_stones: Black
        elif idx in self.w_stones: White
        else: Empty
proc `[]`*(self: Board, x: int, y: int): PointState =
    result = self[(x, y)]

proc `[]=`*(self: var Board, coord: Coord, state: PointState) =
    let (x, y) = coord
    if not coord.in_bounds_of(self):
        raise newException(IndexDefect, &"Index ({x}, {y}) is out of bounds")
    let idx = x + (y-1)*self.size
    case state:
    of Black:
        self.b_stones.incl(idx)
        self.w_stones.excl(idx)
    of White:
        self.b_stones.excl(idx)
        self.w_stones.incl(idx)
    of Empty:
        self.b_stones.excl(idx)
        self.w_stones.excl(idx)
proc `[]=`*(self: var Board, x: int, y: int, state: PointState) =
    self[(x, y)] = state

proc initBoard*(size: int): Board =
    Board(size: size)


proc turn_change*(self: var Board) =
    self.turn = self.turn.opp

proc size*(self: Boards): int =
    self.size

proc `$`*(board: Board): string =
    let rng = 1..board.size
    for y in rng:
        for x in rng:
            case board[x, y]:
            of Black:
                result.add("x")
            of White:
                result.add("o")
            of Empty:
                result.add(".")
        result.add("\n")
    let kou = if board.kou_pt.isSome:
        let (x, y) = board.kou_pt.get
        &"({x}, {y})"
    else:
        "none"
    result.add(&"turn_color: {board.turn}\nkou_point : {kou}\nstate     : {board.state}\n")


proc `[]`*(self: BitBoard, coord: Coord): bool =
    let (x, y) = coord
    if not coord.in_bounds_of(self):
        raise newException(IndexDefect, &"Index ({x}, {y}) is out of bounds")
    let idx = x + (y-1)*self.size
    result = idx in self.bits
proc `[]`*(self: BitBoard, x: int, y: int): bool =
    self[(x, y)]

proc `[]=`*(self: var BitBoard, coord: Coord, state: bool) =
    let (x, y) = coord
    if not coord.in_bounds_of(self):
        raise newException(IndexDefect, &"Index ({x}, {y}) is out of bounds")
    let idx = x + (y-1)*self.size
    case state:
    of true:
        self.bits.incl(idx)
    of false:
        self.bits.excl(idx)
proc `[]=`*(self: var BitBoard, x: int, y: int, state: bool) =
    self[(x, y)] = state

proc initBitBoard*(size: int, color: Color): BitBoard =
    BitBoard(size: size, color: color)


proc remove*(board: var Board, bit_board: BitBoard) =
    assert(board.size == bit_board.size, "Attempting to remove stones from a different sized board")
    case bit_board.color:
    of Black:
        board.b_stones = board.b_stones - bit_board.bits
    of White:
        board.w_stones = board.w_stones - bit_board.bits

converter toPointState*(self: Color): PointState =
    PointState(self.ord)

proc count*(self: BitBoard): int =
    self.bits.card


proc `$`*(coord: Coord): string =
    let (x, y) = coord
    proc to_char(i: int): char =
        ('a'.ord + i).chr
    result = x.to_char & y.to_char

import strutils

type
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

proc parseCoord*(s: string): Coord =
  let x = s[0].toLowerAscii.ord - 'a'.ord
  let y = s[1].toLowerAscii.ord - 'a'.ord
  (x, y)

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

type Range* = array[2, int]
type XYRange* = array[2, Range]

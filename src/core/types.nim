import strutils

type
  Coord* = tuple[x: int, y: int]
  Color* = enum
    Black
    White

  PointState* = enum
    Black
    White
    Empty

  GameState* = enum
    Ongoing
    Passed
    Finished
    Resigned

proc parseCoord*(s: string): Coord =
  let x = s[0].toLowerAscii.ord - 'a'.ord + 1
  let y = s[1].toLowerAscii.ord - 'a'.ord + 1
  (x, y)

proc `$`*(coord: Coord): string =
  let (x, y) = coord
  proc to_char(i: int): char =
    ('a'.ord + i - 1).chr
  result = x.to_char & y.to_char

type
  MoveKind* = enum
    Put
    Pass
    Resign

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

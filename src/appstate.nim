import board
import nodetree
import rules
type
  AppState* = object
    board*: Board
    caches*: seq[Board]
    moves*: seq[Move]
    tree*: GameTree
    sgf*: string



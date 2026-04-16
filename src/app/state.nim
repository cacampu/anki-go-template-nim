import ../core/[types, board, gametree]
type AppState* = object
  board*: Board
  histories*: seq[Board]
  moves*: seq[Move]
  tree*: GameTree
  sgf*: string

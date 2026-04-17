import ../core/[types, board, gametree]
type AppState* = object
  board*: Board
  history*: seq[Board]
  moves*: seq[Move]
  tree*: GameTree
  sgf*: string

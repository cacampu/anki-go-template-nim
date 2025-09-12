import board
import nodetree
import rules
type GoSysetem = object
  sgf: string
  board: Board
  tree: GameTree
  cahce: seq[Board]
  mvoes: seq[Move]

proc 
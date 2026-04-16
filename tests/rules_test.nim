import board
import rules
import results
import sequtils

let moves1 = [(3, 1), (2, 1), (2, 2), (1, 2), (1, 1), (2, 1)]
let moves2 = [(3, 1), (2, 1), (2, 2), (1, 2), (1, 3), (1, 1)]
let moves3 = [(3, 3), (4, 1), (3, 1), (3, 2), (2, 2), (2, 1)]

proc test_putmove[I](moves: array[I, Coord]) =
  var b = initBoard(9)
  for m in moves:
    let ret = b.apply_move(Move(kind: Put, coord: m, turn: b.turn))
    if ret.isOk:
      b = ret.get()
    else:
      echo "Error: ", ret.error, "  last move: ", m

  echo b

test_putmove(moves1)
test_putmove(moves2)
test_putmove(moves3)
test_putmove([(3, 3), (3, 3)])
test_putmove([(3, 42)])

let moves4 = [Pass].mapIt(Move(kind: it))
let moves5 = [Pass, Pass, Pass].mapIt(Move(kind: it))
let moves6 = [Resign, Pass].mapIt(Move(kind: it))
proc test_move(moves: seq[Move]) =
  var b = initBoard(9)
  for move in moves:
    let ret = b.apply_move(move)
    if ret.isOk:
      b = ret.get()
    else:
      echo "Error: ", ret.error
  echo b

test_move(moves4)
test_move(moves5)
test_move(moves6)

#proc test_move[I](moves: array[I, Coord]): Result[Board, string] =
#    var b = initBoard(9)
#    for m in moves:
#        let ret = b.apply_move(Move(kind: Put, coord: m, turn: b.turn))
#        if ret.isOk:
#            b = ret.get()
#        else:
#            return ret
#    ok(b)
#
#suite "Rules":
#    test "kou":
#        check(test_move(moves1) == err("コウです"))
#    test "suicide":
#        check(test_move(moves2) == err("自殺手です"))
#    test "not kou":
#        check(test_move(moves3).kou_pt == none(Coord))
#    test "twice":
#        check(test_move([(3, 3), (3, 3)]) == err("すでに石が置かれています"))
#    test "out of bounds":
#        check(test_move([(3, 42)]) == err("範囲外に石を置こうとしました"))

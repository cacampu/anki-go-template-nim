import unittest
import board
import options

var x = initBoard(9)
suite "Board":
    test "put stones":
        for i in 1..8:
          x[i, 1] = if i mod 2 == 1: PointState.Black else: Color.Black
          for j in 2..5:
            x[i, j] = if i mod 2 == 1: PointState.White else: Color.White
        check $x == "xxxxxxxx.\noooooooo.\noooooooo.\noooooooo.\noooooooo.\n.........\n.........\n.........\n.........\nturn_color: Black\nkou_point : none\n"
    test "remove stones, turn_change, set kou_pt":
        var y = initBitBoard(x.size, White)
        for i in 3..5:
          for j in 3..5:
            y[i, j] = true
        x.remove(y)
        x.turn_change()
        x.kou_pt = some((4, 5))
        check $x == "xxxxxxxx.\noooooooo.\noo...ooo.\noo...ooo.\noo...ooo.\n.........\n.........\n.........\n.........\nturn_color: White\nkou_point : (4, 5)\n"
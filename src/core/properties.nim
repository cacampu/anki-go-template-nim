import tables
import types

type Properties* = OrderedTable[string, seq[string]]

proc `+`*(a: Properties, b: Properties): Properties =
  result = a
  for k, vs in b:
    if k in result:
      result[k].add(vs)
    else:
      result[k] = vs

converter toProperty*(move: Move): Properties =
  let turn_color =
    case move.color
    of Black: "B"
    of White: "W"
  let coord =
    case move.kind
    of Put:
      $move.coord
    of Pass:
      ""
    of Resign:
      ""
  result[turn_color] = @[coord]

converter toMove*(props: Properties): Move =
  proc is_pass(coord_str: string): bool =
    coord_str == "" or coord_str == "tt"

  if "B" in props:
    let coord_str = props["B"][0]
    if coord_str.is_pass():
      result = Move(color: Black, kind: Pass)
    else:
      let coord = parseCoord(coord_str)
      result = Move(color: Black, kind: Put, coord: coord)
  elif "W" in props:
    let coord_str = props["W"][0]
    if coord_str.is_pass():
      result = Move(color: White, kind: Pass)
    else:
      let coord = parseCoord(coord_str)
      result = Move(color: White, kind: Put, coord: coord)

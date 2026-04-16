import ../core/[board, gametree, propaties]
import ../app/[state, handler]
import results
import dom

## 汎用的な要素作成関数
proc h(
    parent: Element,
    tag: string,
    attrs: openArray[(string, string)] = [],
    styles: openArray[(string, string)] = [],
): Element =
  let el = document.createElement(tag)

  for (key, val) in attrs:
    case key
    of "class", "className":
      el.className = cstring(val)
    of "id":
      el.id = cstring(val)
    else:
      el.setAttribute(cstring(key), cstring(val))

  for (prob, val) in styles:
    el.style.setProperty(cstring(prob), cstring(val))

  if parent != nil:
    parent.appendChild(el)
  return el

proc draw_lines(board_container: Element, size: int) =
  let line_grid = board_container.h("div", [("class", "line-grid")])
  for _ in 0 ..< (size - 1) * (size - 1):
    discard line_grid.h("div", [("class", "line-cell")])
  proc add_star(r, c: int) =
    discard
      line_grid.h("div", [("class", "star")], [("grid-row", $r), ("grid-column", $c)])

  let m = (size + 1) div 2
  let d = if size >= 13: 4 else: 3
  let lr = [d, size - d]

  # 隅
  if size >= 8:
    for r in lr:
      for c in lr:
        add_star(r, c)
  # 中央
  if size > 5 and size mod 2 == 1:
    add_star(m, m)
  # 辺
  if size >= 15 and size mod 2 == 1:
    for x in lr:
      add_star(x, m)
      add_star(m, x)

proc setup_board*(board_base: Element, state: AppState) =
  let board_container = board_base.h("div", [("class", "board-container")])
  board_container.draw_lines(state.board.size)
  discard board_container.h("div", [("class", "grid"), ("id", "stone-grid")])
  discard board_container.h("div", [("class", "grid"), ("id", "pointer-grid")])
  discard board_container.h("div", [("class", "grid"), ("id", "marker-grid")])
  discard board_container.h("div", [("class", "catcher")])

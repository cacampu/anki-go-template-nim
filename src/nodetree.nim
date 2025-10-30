import tables
import sequtils

type Properties* = OrderedTable[string, seq[string]]
type Node* = ref object
  parent*: Node
  children*: seq[Node]
  props*: Properties

type Tree* = object
  root: Node
  current_node: Node
  depth: int

type BranchKind* = enum
  Answer, Analysis

type GameTree* = object
  inner: array[BranchKind, Tree]

#node
proc add_child*(parent: Node, child: Node) =
  if parent != nil:
    child.parent = parent
    parent.children.add(child)
proc remove*(node: Node): Node =
  node.parent.children.keepItIf(it != node)
  node.parent

#tree
proc initTree*(root: Node = Node()): Tree =
  Tree(root: root, current_node: root, depth: 0)
proc root*(tree: Tree): Node =
  tree.root

proc can_prev(tree: Tree): bool =
  tree.current_node != tree.root
proc can_next(tree: Tree, i: int): bool =
  tree.current_node.children.len > i
proc go_prev(tree: var Tree) =
  tree.current_node = tree.current_node.parent
  tree.depth -= 1
proc go_next(tree: var Tree, i: int) =
  tree.current_node = tree.current_node.children[i]
  tree.depth += 1

proc reset(tree: var Tree) =
  tree.current_node = tree.root
  tree.root.children = @[]
  tree.depth = 0

#gametree
proc depth*(gtree: GameTree): int =
  gtree.inner.mapIt(it.depth).foldl(a+b)
proc ans_depth*(gtree: GameTree): int =
  gtree.inner[Answer].depth

proc current_node*(gtree: GameTree): Node =
  if gtree.inner[Analysis].depth > 0:
    gtree.inner[Analysis].current_node
  else:
    gtree.inner[Answer].current_node

proc reset_analysis(gtree: var GameTree) =
  gtree.inner[Analysis].reset()
proc add_ana_node*(gtree: var GameTree, node: Node) =
  gtree.inner[Analysis].current_node.children = @[node]


proc can_prev*(gtree: GameTree, bk: BranchKind): bool =
  gtree.inner[bk].can_prev()
proc can_next*(gtree: GameTree, bk: BranchKind, i: int = 0): bool =
  gtree.inner[bk].can_next(i)
proc has_ans_branch*(gtree: GameTree): bool =
  gtree.inner[Analysis].root.children.len > 1

proc go_prev*(gtree: var GameTree, bk: BranchKind) =
  if bk == Answer:
    gtree.reset_analysis()
  gtree.inner[bk].go_prev()
proc go_next*(gtree: var GameTree, bk: BranchKind, i: int = 0) =
  if bk == Answer:
    gtree.reset_analysis()
  gtree.inner[bk].go_next(i)

proc merge_to_ans*(gtree: var GameTree) =
  var ans: ptr Tree = addr gtree.inner[Answer]
  var ana: ptr Tree = addr gtree.inner[Analysis]
  if ana.root.children.len == 0:
    return
  let ana_node = ana.root.children[0]
  ans.current_node.children.add(ana_node)
  if ana.depth > 0:
    ans.current_node = ana.current_node
    ans.depth += ana.depth
  ana.reset()

proc initGameTree*(ans_tree: Tree): GameTree =
  GameTree(
    inner: [ans_tree, initTree()]
  )

proc `+`*(a: Properties, b: Properties): Properties =
  result = a
  for k, vs in b:
    if k in result:
      result[k].add(vs)
    else:
      result[k] = vs

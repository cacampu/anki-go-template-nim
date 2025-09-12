import tables
import sequtils

type Properties* = OrderedTable[string, seq[string]]
type Node* = ref object
  parent*: Node
  children*: seq[Node]
  props*: Properties

type Tree* = object
  root*: Node
  current_node*: Node

type GameTree* = object
  ans: Tree
  ana: Tree
  ans_depth: int
  ana_depth: int

proc add_node*(tree: var Tree, node: Node) =
  if tree.current_node != nil:
    node.parent = tree.current_node
    tree.current_node.children.add(node)
  tree.current_node = node
proc prev(tree: var Tree) =
  tree.current_node = tree.current_node.parent
proc next(tree: var Tree, i: int) =
  tree.current_node = tree.current_node.children[i]

proc add_child*(parent: Node, child: Node) =
  if parent != nil:
    child.parent = parent
    parent.children.add(child)
proc remove*(node: Node): Node =
  node.parent.children.keepItIf(it != node)
  node.parent
proc remove_all*(tree: var Tree) =
  tree.root = nil
  tree.current_node = nil

proc reset_analysis(gtree: var GameTree) =
  gtree.ana.root = nil
  gtree.ana.current_node = nil
  gtree.ana_depth = 0
proc add_ana_node*(gtree: var GameTree, node: Node) =
  gtree.ana.add_node(node)
  gtree.ana_depth += 1

proc ans_prev*(gtree: var GameTree) =
  gtree.reset_analysis()
  gtree.ans.prev()
  gtree.ans_depth -= 1
proc ans_next*(gtree: var GameTree, i: int) =
  gtree.reset_analysis()
  gtree.ans.next(i)
  gtree.ans_depth += 1

proc ana_prev*(gtree: var GameTree) =
  gtree.ana.prev()
  gtree.ana_depth -= 1
proc ana_next*(gtree: var GameTree, i: int) =
  gtree.ana.next(i)
  gtree.ana_depth += 1

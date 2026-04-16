import unittest
import core/gametree
import logic/parser
import tables

let sgf =
  """(;GM[1]FF[3]AB[rd][rc][qc][pc][oc][nc][pb][oa]AW[mb][nb][ob][mc][nd][od][pd][qd][re][qf]PL[W]C[White to play and kill.]AP[MultiGo:3.9.3]SZ[19]
  (; W[sd]
    (; B[rb]; W[qa]; B[pa]; W[sc]; B[sb]; W[ra])
    (; B[ra]; W[sb]; B[sc]
      (; W[pa])
      (; W[rb]))
    ( ; B[sc]; W[pa]))
  (; W[rb]TR[rb]; B[sb]; W[ra]; B[sd])
  (; W[ra]TR[ra]; B[sd]; W[sb]; B[rb]; W[qa]; B[pa]))"""
let tree = sgf.parse()

suite "Parser":
  test "parse sgf to tree":
    check tree.root.children.len == 3
    check tree.root.props.len == 8
  test "serialize tree to sgf":
    let sgf_ser = tree.serialize()
    check sgf_ser ==
      "(;GM[1]FF[3]AB[rd][rc][qc][pc][oc][nc][pb][oa]AW[mb][nb][ob][mc][nd][od][pd][qd][re][qf]PL[W]C[White to play and kill.]AP[MultiGo:3.9.3]SZ[19](;W[sd](;B[rb];W[qa];B[pa];W[sc];B[sb];W[ra])(;B[ra];W[sb];B[sc](;W[pa])(;W[rb]))(;B[sc];W[pa]))(;W[rb]TR[rb];B[sb];W[ra];B[sd])(;W[ra]TR[ra];B[sd];W[sb];B[rb];W[qa];B[pa]))"
  test "escape sgf value":
    let sgf_2 = """(;C[This is a test value with \] and \\])"""
    let ret = sgf_2.parse().serialize()
    check ret == sgf_2

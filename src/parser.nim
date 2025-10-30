import nodetree
import tables
import strutils

proc parse*(sgf: string): Tree =
  var pos = 0
  proc parse_key(): string =
    while pos < sgf.len():
      let c = sgf[pos]
      case c
      of '[':
        break
      of 'A'..'Z':
        result.add(c)
      else:
        discard
      pos += 1
  proc parse_value(): seq[string] =
    proc collect_str(): string =
      while pos < sgf.len():
        let c = sgf[pos]
        case c
        of '[':
          discard
        of ']':
          break
        of '\\':
          pos += 1
          result.add(sgf[pos])
        else:
          result.add(c)
        pos += 1
    while pos < sgf.len():
      let c = sgf[pos]
      case c
      of '[':
        result.add(collect_str())
      of Whitespace:
        discard
      else:
        break
      pos += 1

  proc parse_props(): Properties =
    while pos < sgf.len():
      let key = parse_key()
      let value = parse_value()
      result[key] = value
      if sgf[pos] in {';', '(', ')'}:
        break

  proc parse_node(): Node =
    var node = Node(props: parse_props())
    while pos < sgf.len:
      case sgf[pos]
      of ';':
        node.add_child(parse_node())
        break
      of '(':
        node.add_child(parse_node())
      of ')':
        pos += 1
        return node
      else:
        pos += 1
    node
  let root = parse_node()
  result = initTree(root)


proc serialize*(tree: Tree): string =
  proc unparsed_props(node: Node): string =
    proc escape_value(s: string): string =
      for c in s:
        case c
        of ']':
          result.add("\\]")
        of '\\':
          result.add("\\\\")
        else:
          result.add(c)
    result.add(';')
    for k, vs in node.props:
      result.add(k)
      for v in vs:
        result.add('[')
        result.add(v.escape_value())
        result.add(']')
  proc unparse(node: Node): string =
    if node == nil: return
    result.add(node.unparsed_props)
    if node.children.len == 1:
      result.add(node.children[0].unparse())
    else:
      for child in node.children:
        result.add('(')
        result.add(child.unparse())
        result.add(')')

  result.add('(')
  result.add(tree.root.unparse())
  result.add(')')











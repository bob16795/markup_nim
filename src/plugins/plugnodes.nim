import strutils
import ../output

type
  NodeKind* = enum
    nkNone,        # an empty node                 leaf
    nkBody,        # body                          branch
    nkTagDef,      # a tag                         branch
    nkTagArgs,     # args of a tag                 branch
    nkCond,        # args of a tag                 branch
    nkLine,        # a line of code                branch
  Node* = object
    start_pos*, end_pos*: position
    case kind*: NodeKind
    of nkTagDef:
      predef*: bool
      name*: string
      lines*: seq[Node]
      extra*: seq[Node]
    of nkTagArgs:
      names*: seq[string]
    of nkBody:
      Contains*: seq[Node]
    of nkLine:
      conds*: seq[Node]
      keyword*: string
      command*: string
    of nkCond:
      inv*: bool
      cKeyword*: string
      cCommand*: string
    of nkNone:
      discard

proc `$`*(nod: Node): string =
  var node_type, node_value: string
  case nod.kind:
  of nkBody:
    node_type = "Body"
  of nkTagDef:
    if nod.predef:
      node_type = "TagPreDef"
    else:
      node_type = "TagDef"
  of nkTagArgs:
    node_type = "Args"
  of nkLine:
    node_type = "Line"
  of nkCond:
    node_type = "Cond"
  of nkNone:
    node_type = "None"
  case nod.kind:
  of nkBody:
    for node in nod.Contains:
      node_value &= "\n  " & ($node).replace("\n", "\n  ")
    node_value &= "\n"
  of nkTagDef:
    node_value = nod.name & ": "
    for node in nod.lines:
      node_value &= "\n  " & ($node).replace("\n", "\n  ")
    for node in nod.extra:
      node_value &= "\n  " & ($node).replace("\n", "\n  ")
    node_value &= "\n"
  of nkTagArgs:
    for arg in nod.names:
      node_value &= arg & ", "
    node_value = node_value[0..^3]
  of nkLine:
    for node in nod.conds:
      node_value &= "\n  " & ($node).replace("\n", "\n  ")
    node_value &= "\n" & nod.keyword
    if "\n" in nod.command:
      node_value &= "\n" & nod.command
    else:
      node_value &= " " & nod.command
  of nkCond:
    if nod.inv:
      node_value = "!"
  else:
    node_value = "None"
  return ("<" & node_type & ": " & node_value & ">").replace("><", ">\n<")

import lists, strutils
   
type
  NodeKind* = enum 
    nkNone,         # an empty node                 leaf
    nkDocument,     # document                      branch
    nkprolog,       # document prolog               branch
    nkXMLDecl,      # xml declration                branch
    nkVersionInfo,  # version information           leaf
    nkSpace,        # whitespace                    leaf
  Node* = object
#    start_pos*, end_pos*: position
    case kind*: NodeKind  # the ``kind`` field is the discriminator
    of nkDocument, nkXMLDecl, nkprolog, nkVersionInfo:
      Contains*: seq[Node]
    of nkNone, nkSpace:
      discard

proc `$`*(nod: Node): string =
  var node_type, node_value: string
  case nod.kind:
  of nkDocument:
    node_type = "Document"
    for node in nod.Contains:
      node_value = node_value & $node
  of nkNone:
    node_type = "None"
    node_value = "None"
  of nkSpace:
    node_type = "Space"
    node_value = "None"
  of nkXMLDecl:
    node_type = "XMLDecl"
    for node in nod.Contains:
      node_value = node_value & $node
  of nkVersionInfo:
    node_type = "VersionInfo"
    for node in nod.Contains:
      node_value = node_value & $node
  of nkprolog:
    node_type = "prolog"
    for node in nod.Contains:
      node_value = node_value & $node
  return "<" & node_type & ": " & node_value & ">"
    

proc len*(list: SinglyLinkedList[Node]): int = 
  var i = 1
  for j in list:
    i += 1
  return i

proc `[]`*(list: SinglyLinkedList[Node]; idx: int): Node= 
  var i = -1
  for j in list:
    i += 1
    if i == idx:
      return j
  return

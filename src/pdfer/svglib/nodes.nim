import lists, strutils
   
type
  NodeKind* = enum 
    nkNone,         # an empty node                 leaf
    nkDocument,     # document                      branch
    nkprolog,       # document prolog               branch
    nkXMLDecl,      # xml declration                branch
    nkVersionInfo,  # version information           leaf
    nkVersionNum,   # version number                leaf
    nkSpace,        # whitespace                    leaf
    nkSDDecl,       # standalone declration         branch
    nkEncodingDecl, # encoding declration           branch
    nkEncodingName, # encoding name                 leaf
    nkEq,           # equal                         leaf
  Node* = object
    case kind*: NodeKind  # the ``kind`` field is the discriminator
    of nkDocument, nkXMLDecl, nkprolog, nkVersionInfo, nkEncodingDecl:
      Contains*: seq[Node]
    of nkVersionNum:
      num*: string
    of nkSDDecl:
      yon*: string
    of nkEncodingName:
      enc*: string
    of nkNone, nkSpace, nkEq:
      discard

proc `$`*(nod: Node): string =
  var node_type, node_value: string
  case nod.kind:
  of nkDocument:
    node_type = "Document"
    for node in nod.Contains:
      node_value &= $node
  of nkNone:
    node_type = "None"
    node_value = "None"
  of nkSpace:
    node_type = "S"
    node_value = "None"
  of nkEq:
    node_type = "Eq"
    node_value = "None"
  of nkXMLDecl:
    node_type = "XMLDecl"
    for node in nod.Contains:
      node_value &= $node
  of nkSDDecl:
    node_type = "SDDecl"
    node_value = nod.yon
  of nkEncodingDecl:
    node_type = "EncodingDecl"
    for node in nod.Contains:
      node_value &= $node
  of nkEncodingName:
    node_type = "EncodingName"
    node_value = nod.enc
  of nkVersionInfo:
    node_type = "VersionInfo"
    for node in nod.Contains:
      node_value &= $node
  of nkVersionNum:
    node_type = "VersionNum"
    node_value = nod.num
  of nkprolog:
    node_type = "prolog"
    for node in nod.Contains:
      node_value &= $node
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

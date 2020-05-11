import strutils
import output
   
type
  NodeKind* = enum 
    nkAlphaNumSym,  # letters, numbers, and symbols leaf
    nkBody,         # body                          branch 
    nkPropLine,     # property line                 leaf
    nkPropDiv,      # property divider              leaf
    nkPropSec,      # property section              branch
    nkTextLine,     # a line of text                leaf
    nkTextComment,  # a comment                     leaf
    nkTextParEnd,   # end of paragaph               leaf
    nkTextSec,      # a Section of text             branch
    nkTag,          # a <> tag                      leaf
    nkEquation,     # a $Equation$                  leaf
    nkHeading1,     # heading level 1               leaf
    nkHeading2,     # heading level 2               leaf
    nkHeading3,     # heading level 3               leaf
    nkList,         # list                          branch
    nkListLevel1,   # list level 1                  leaf
    nkListLevel2,   # list level 2                  leaf
    nkListLevel3,   # list level 3                  leaf
    nkTable,        # list                          branch
    nkTableRow,     # table row                     leaf
    nkTableHeader,  # table heading                 branch
    nkTableSplit,   # table heading                 leaf
    nkNone,         # an empty node                 leaf
  Node* = object
    start_pos*, end_pos*: position
    case kind*: NodeKind  # the ``kind`` field is the discriminator
    of nkEquation, nkAlphaNumSym, nkTextLine, nkTextComment, nkHeading1, nkHeading2, nkHeading3, nkListLevel1, nkListLevel2, nkListLevel3:
      text*: string
    of nkBody, nkPropSec, nkTextSec, nkList:
      Contains*: seq[Node]
    of nkTag:
      tag_name*, tag_value*: string
    of nkPropLine:
      invert*: bool
      condition*, prop*, value*: string
      start_condition*, start_statment*, end_statment*: position
    of nkTable:
      rows*: seq[Node]
    of nkTableHeader:
      ratio*: seq[int]
      total*: int
      header_columns*: seq[string]
    of nkTableRow:
      row_columns*: seq[string]
    of nkTableSplit:
      split_ratio*: seq[int]
    of nkNone, nkPropDiv, nkTextParEnd:
      discard

proc `$`*(nod: Node): string =
  var node_type, node_value: string
  case nod.kind:
  of nkAlphaNumSym:
    node_type = "AlphaNumSym"
  of nkBody:
    node_type = "Body"
  of nkNone:
    node_type = "None"
  of nkPropDiv:
    node_type = "PropDiv"
  of nkPropLine:
    node_type = "PropLine"
  of nkPropSec:
    node_type = "PropSec"
  of nkTextSec:
    node_type = "TextSec"
  of nkTextLine:
    node_type = "TextLine"
  of nkTextComment:
    node_type = "TextComment"
  of nkTextParEnd:
    node_type = "TextParEnd"
  of nkTag:
    node_type = "Tag"
  of nkEquation:
    node_type = "Equation"
  of nkHeading1:
    node_type = "Heading 1"
  of nkHeading2:
    node_type = "Heading 2"
  of nkHeading3:
    node_type = "Heading 3"
  of nkList:
    node_type = "List"
  of nkListLevel1:
    node_type = "List Level 1"
  of nkListLevel2:
    node_type = "List Level 2"
  of nkListLevel3:
    node_type = "List Level 3"
  of nkTable:
    node_type = "Table"
  of nkTableRow:
    node_type = "TableRow"
  of nkTableHeader:
    node_type = "TableHeader"
  of nkTableSplit:
    node_type = "TableSplit"
  case nod.kind:
  of nkEquation, nkAlphaNumSym, nkTextLine, nkTextComment, nkHeading1, nkHeading2, nkHeading3, nkListLevel1, nkListLevel2, nkListLevel3:
    node_value = $nod.text
  of nkBody, nkPropSec, nkList, nkTextSec:
    for node in nod.Contains:
      node_value &= "\n  " & ($node)
    node_value &= "\n"
    node_value = node_value
  of nkNone, nkPropDiv, nkTextParEnd, nkTable, nkTableRow, nkTableHeader, nkTableSplit:
    node_value = "None"
  of nkTag:
    node_value = nod.tag_name.strip() & " == " & nod.tag_value.strip()
  of nkPropLine:
    if nod.condition != "":
      node_value = nod.condition.strip() & " == " & $not(nod.invert) & " then " & nod.prop.strip() & " = " & nod.value.strip()
    else:
      node_value = nod.prop.strip() & " = " & nod.value.strip()
  return ("<" & node_type & ": " & node_value & ">").replace("><", ">\n<")
    

# proc len*(list: SinglyLinkedList[Node]): int = 
#   var i = 1
#   for j in list:
#     i += 1
#   return i

# proc `[]`*(list: SinglyLinkedList[Node]; idx: int): Node= 
#   var i = -1
#   for j in list:
#     i += 1
#     if i == idx:
#       return j
#   return

import strutils
import output

type
  NodeKind* = enum
    nkAlphaNumSym, # letters, numbers, and symbols leaf
    nkBody,        # body                          branch
    nkPropLine,    # property line                 leaf
    nkPropDiv,     # property divider              leaf
    nkPropSec,     # property section              branch
    nkTextLine,    # a line of text                branch
    nkTextBold,    # a Section of bold text        leaf
    nkTextEmph,    # a Section of italic text      leaf
    nkTextComment, # a comment                     leaf
    nkTextParEnd,  # end of paragaph               leaf
    nkTextSec,     # a Section of text             branch
    nkCodeBlock,   # a multiline section of code   leaf
    nkTag,         # a <> tag                      leaf
    nkEquation,    # a $Equation$                  leaf
    nkHeading1,    # heading level 1               leaf
    nkHeading2,    # heading level 2               leaf
    nkHeading3,    # heading level 3               leaf
    nkList,        # list                          branch
    nkListLevel1,  # list level 1                  leaf
    nkListLevel2,  # list level 2                  leaf
    nkListLevel3,  # list level 3                  leaf
    nkTable,       # list                          branch
    nkTableRow,    # table row                     leaf
    nkTableHeader, # table heading                 branch
    nkTableSplit,  # table heading                 leaf
    nkNone,        # an empty node                 leaf
  Node* = object
    start_pos*, end_pos*: position
    case kind*: NodeKind
    of nkEquation, nkAlphaNumSym, nkTextComment, nkHeading1, nkHeading2,
        nkHeading3, nkListLevel1, nkListLevel2, nkListLevel3, nkTextBold, nkTextEmph:
      text*: string
    of nkBody, nkPropSec, nkTextSec, nkList, nkTextLine:
      Contains*: seq[Node]
    of nkTag:
      tag_name*, tag_value*: string
    of nkPropLine:
      invert*: bool
      condition*, prop*, value*: string
      start_condition*, start_statment*, end_statment*: position
    of nkCodeBlock:
      code*: string
      lang*: string
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
  of nkCodeBlock:
    node_type = "CodeBlock"
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
  of nkTextBold:
    node_type = "TextBold"
  of nkTextEmph:
    node_type = "TextEmph"
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
  of nkEquation, nkAlphaNumSym, nkTextComment, nkHeading1, nkHeading2,
      nkHeading3, nkListLevel1, nkListLevel2, nkListLevel3, nkTextBold, nkTextEmph:
    node_value = $nod.text
  of nkBody, nkPropSec, nkList, nkTextSec, nkTextLine:
    for node in nod.Contains:
      node_value &= "\n  " & ($node).replace("\n", "\n  ")
    node_value &= "\n"
  of nkTableHeader:
    for i in 0..(nod.header_columns.high()):
      node_value &= $(nod.ratio[i]) & ": " & nod.header_columns[i].strip() & ", "
    node_value = node_value[0 ..< ^2]
  of nkTableRow:
    for i in 0..(nod.row_columns.high()):
      node_value &= nod.row_columns[i].strip() & ", "
    node_value = node_value[0 ..< ^2]
  of nkTable:
    for node in nod.rows:
      node_value &= "\n  " & ($node).replace("\n", "\n  ")
    node_value &= "\n"
  of nkNone, nkPropDiv, nkTextParEnd, nkTableSplit:
    node_value = "None"
  of nkCodeBlock:
    node_value = nod.lang & ": {" & nod.code & "}"
  of nkTag:
    if nod.tag_value.strip() != "":
      node_value = nod.tag_name.strip() & ": " & nod.tag_value.strip()
    else:
      node_value = nod.tag_name.strip()
  of nkPropLine:
    if nod.condition != "":
      node_value = nod.condition.strip() & ": " & $not(nod.invert) & " then " &
          nod.prop.strip() & " = " & nod.value.strip()
    else:
      node_value = nod.prop.strip() & " = " & nod.value.strip()
  return ("<" & node_type & ": " & node_value & ">").replace("><", ">\n<")

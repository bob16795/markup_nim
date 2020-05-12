import nodes, output, tokenclass
import sequtils

type
  parser* = object
    tokens: seq[Token]
    tok_idx: int
    c_tok: Token

proc advance(psr: var parser, by: int = 1) =
  psr.tok_idx = psr.tok_idx + by
  if psr.tok_idx < len(psr.tokens):
    psr.c_tok = psr.tokens[psr.tok_idx]
  else:
    var pos = psr.tokens[^1].pos_start
    psr.c_tok = initToken("tt_eof", "tt_eof", pos, pos)

proc goto(psr: var parser, to: int = 1) =
  psr.tok_idx = to
  if psr.tok_idx < len(psr.tokens):
    psr.c_tok = psr.tokens[psr.tok_idx]
  else:
    var pos = psr.tokens[^1].pos_start
    psr.c_tok = initToken("tt_eof", "tt_eof", pos, pos)


proc initParser*(tokens: seq[Token], tok_idx: int): parser =
  result.tokens = tokens
  result.tok_idx = tok_idx
  result.advance()

proc alphaNumSymParser(psr: var parser): Node =
  var text = ""
  var found = true
  var start_pos = psr.c_tok.pos_start
  while found:
    found = false
    case psr.c_tok.ttype:
    of "tt_underscore":
      found = true
      text = text & "_"
      psr.advance()
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_dollar":
      found = true
      text = text & "$"
      psr.advance()
    of "tt_exclaim":
      found = true
      text = text & "!"
      psr.advance()
    of "tt_text":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
    of "tt_num":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
  if text == "":
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkAlphaNumSym, text: text)

proc alphaNumSymTagParser(psr: var parser): Node =
  var text = ""
  var found = true
  var start_pos = psr.c_tok.pos_start
  while found:
    found = false
    case psr.c_tok.ttype:
    of "tt_lparen":
      found = true
      text = text & "("
      psr.advance()
    of "tt_rparen":
      found = true
      text = text & ")"
      psr.advance()
    of "tt_underscore":
      found = true
      text = text & "_"
      psr.advance()
    of "tt_colon":
      found = true
      text = text & ":"
      psr.advance()
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_dollar":
      found = true
      text = text & "$"
      psr.advance()
    of "tt_exclaim":
      found = true
      text = text & "!"
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_text":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
    of "tt_num":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
  if text == "":
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkAlphaNumSym, text: text)

proc alphaNumSymEquParser(psr: var parser): Node =
  var text = ""
  var found = true
  var start_pos = psr.c_tok.pos_start
  while found:
    found = false
    case psr.c_tok.ttype:
    of "tt_underscore":
      found = true
      text = text & "_"
      psr.advance()
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_exclaim":
      found = true
      text = text & "!"
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_ltag":
      found = true
      text = text & "<"
      psr.advance()
    of "tt_rtag":
      found = true
      text = text & ">"
      psr.advance()
    of "tt_lparen":
      found = true
      text = text & "("
      psr.advance()
    of "tt_rparen":
      found = true
      text = text & ")"
      psr.advance()
    of "tt_equals":
      found = true
      text = text & "="
      psr.advance()
    of "tt_text":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
    of "tt_num":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
  if text == "":
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkAlphaNumSym, text: text)

proc alphaNumSymMoreParser(psr: var parser): Node =
  var text = ""
  var found = true
  var start_pos = psr.c_tok.pos_start
  while found:
    found = false
    case psr.c_tok.ttype:
    of "tt_lparen":
      found = true
      text = text & "("
      psr.advance()
    of "tt_rparen":
      found = true
      text = text & ")"
      psr.advance()
    of "tt_lbrace":
      found = true
      text = text & "{"
      psr.advance()
    of "tt_rbrace":
      found = true
      text = text & "}"
      psr.advance()
    of "tt_underscore":
      found = true
      text = text & "_"
      psr.advance()
    of "tt_plus":
      found = true
      text = text & "+"
      psr.advance()
    of "tt_colon":
      found = true
      text = text & ":"
      psr.advance()
    of "tt_ltag":
      found = true
      text = text & "<"
      psr.advance()
    of "tt_rtag":
      found = true
      text = text & ">"
      psr.advance()
    of "tt_exclaim":
      found = true
      text = text & "!"
      psr.advance()
    of "tt_text":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
    of "tt_num":
      found = true
      text = text & psr.c_tok.value
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_dollar":
      found = true
      text = text & "$"
      psr.advance()
  if text == "":
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkAlphaNumSym, text: text)


proc tableSplitParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var error = false
  var ratio: seq[int]
  var col = 0
  while not error:
    error = true
    if psr.c_tok.ttype == "tt_bar":
      psr.advance()
      col += 1
      ratio.add(0)
      while psr.c_tok.ttype == "tt_minus":
        psr.advance()
        error = false
        ratio[^1] += 1
      if error == true:
        psr.advance(-1)
  if psr.c_tok.ttype != "tt_bar":
    return Node(kind: nkNone)
  psr.advance()
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  var end_pos = psr.c_tok.pos_start
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: end_pos,
              kind: nkTableSplit,
              split_ratio: ratio)

proc tableRowParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var error = false
  var text: seq[string]
  var node: Node
  while error == false:
    error = true
    if psr.c_tok.ttype == "tt_bar":
      psr.advance()
      node = psr.alphaNumSymParser()
      if node.kind != nkNone:
        text.add(node.text)
        error = false
      else:
         psr.advance(-1)
  if text == []:
      return Node(kind: nkNone)
  if psr.c_tok.ttype != "tt_bar":
      return Node(kind: nkNone)
  psr.advance()
  if psr.c_tok.ttype != "tt_newline":
          return Node(kind: nkNone)
  var end_pos = psr.c_tok.pos_start
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: end_pos,
              kind: nkTableRow,
              row_columns: text)

proc tableTopParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var heading = psr.tableRowParser()
  if heading.kind == nkNone:
    return Node(kind: nkNone)
  var split = psr.tableSplitParser()
  if split.kind == nkNone:
    return Node(kind: nkNone)
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkTableHeader,
              header_columns: heading.row_columns,
              ratio: split.split_ratio,
              total: (split.split_ratio.foldl(a + b)))

proc textTableParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var rows: seq[Node]
  var node = psr.tableTopParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var top = node
  while node.kind != nkNone:
    rows.add(node)
    node = psr.tableRowParser()
  if len(rows) < 2:
    return Node(kind: nkNone)
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkTable,
              rows: top & rows)

proc propLineParser(psr: var parser): Node =
  var start_condition, start_statment, end_statment = psr.c_tok.pos_start
  var invert = false
  var condition, prop, value = ""
  if psr.c_tok.ttype == "tt_exclaim":
      invert = true
      psr.advance()
      var node = psr.alphaNumSymParser()
      if node.kind == nkNone:
        return Node(kind: nkNone)
      condition = node.text
      if not(psr.c_tok.ttype == "tt_bar"):
        return Node(kind: nkNone)
      psr.advance()
  var node = psr.alphaNumSymParser()
  start_statment = psr.c_tok.pos_start
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if (not(invert)) and (psr.c_tok.ttype == "tt_bar"):
    invert = false
    condition = text
    psr.advance()
    node = psr.alphaNumSymParser()
    if node.kind == nkNone:
      return Node(kind: nkNone)
    prop = node.text
    if not(psr.c_tok.ttype == "tt_colon"):
      return Node(kind: nkNone)
    psr.advance()
    node = psr.alphaNumSymMoreParser()
    if node.kind == nkNone:
      return Node(kind: nkNone)
    value = node.text
  else:
    prop = text
    if psr.c_tok.ttype != "tt_colon":
      return Node(kind: nkNone)
    psr.advance()
    node = psr.alphaNumSymMoreParser()
    if node.kind == nkNone:
      return Node(kind: nkNone)
    value = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  end_statment = psr.c_tok.pos_start
  psr.advance()
  return Node(start_pos: start_condition,
              end_pos: psr.c_tok.pos_start,
              kind: nkPropLine,
              invert: invert,
              condition: condition,
              prop: prop,
              value: value,
              start_condition: start_condition,
              start_statment: start_statment,
              end_statment: psr.c_tok.pos_start)

proc propDivParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  for i in 1..3:
    if psr.c_tok.ttype != "tt_minus":
      return Node(kind: nkNone)
    psr.advance()
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkPropDiv)

proc propSecParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var node = psr.propDivParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var Nodes: seq[Node]
  while node.kind != nkNone:
      Nodes.add(node)
      node = psr.propLineParser()
  node = psr.propDivParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkPropSec, Contains: Nodes)

proc textLineParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var text = ""
  var node = psr.alphaNumSymMoreParser()
  while node.kind != nkNone:
    text = text & node.text
    node = psr.alphaNumSymMoreParser()
  if text == "":
    return Node(kind: nkNone)
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkTextLine, text: text)

proc textCommentParser(psr: var parser): Node =
  var start = psr.c_tok.pos_start
  if psr.c_tok.ttype != "tt_exclaim":
    return Node(kind: nkNone)
  psr.advance()
  var text = ""
  while psr.c_tok.ttype != "tt_newline" and psr.c_tok.ttype != "tt_eof":
    case psr.c_tok.ttype:
    of "tt_text", "tt_num":
      text = text & psr.c_tok.value
    of "tt_minus":
      text = text & "-"
    of "tt_colon":
      text = text & ":"
    of "tt_dollar":
      text = text & "$"
    of "tt_star":
      text = text & "*"
    of "tt_exclaim":
      text = text & "!"
    of "tt_underscore":
      text = text & "_"
    of "tt_lparen":
      text = text & "("
    of "tt_rparen":
      text = text & ")"
    psr.advance()
  psr.advance()
  return Node(kind: nkTextComment, text: text, start_pos: start, end_pos: psr.c_tok.pos_end)

proc heading1Parser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  for i in 1..1:
    if psr.c_tok.ttype != "tt_hash":
      return Node(kind: nkNone)
    psr.advance()
  var node = psr.alphaNumSymMoreParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkHeading1, text: text)

proc heading2Parser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  for i in 1..2:
    if psr.c_tok.ttype != "tt_hash":
      return Node(kind: nkNone)
    psr.advance()
  var node = psr.alphaNumSymMoreParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkHeading2, text: text)

proc heading3Parser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  for i in 1..3:
    if psr.c_tok.ttype != "tt_hash":
      return Node(kind: nkNone)
    psr.advance()
  var node = psr.alphaNumSymMoreParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkHeading3, text: text)

proc textHeadingParser(psr: var parser): Node =
  var start = psr.tok_idx
  var node = psr.heading3Parser()
  if node.kind == nkNone:
    psr.goto(start)
    node = psr.heading2Parser()
  if node.kind == nkNone:
    psr.goto(start)
    node = psr.heading1Parser()
  if node.kind == nkNone:
    psr.goto(start)
    return Node(kind: nkNone)
  return node

proc tagParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var tag_name, tag_value: string
  var node: Node

  if psr.c_tok.ttype != "tt_ltag":
    return Node(kind: nkNone)
  psr.advance()
  if psr.c_tok.ttype != "tt_text":
    return Node(kind: nkNone)
  tag_name = psr.c_tok.value
  tag_value = ""
  psr.advance()
  if psr.c_tok.ttype == "tt_colon":
    psr.advance()
    node = psr.alphaNumSymTagParser()
    if node.kind == nkNone:
      return Node(kind: nkNone)
    tag_value = node.text
  if psr.c_tok.ttype != "tt_rtag":
    return Node(kind: nkNone)
  psr.advance()
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkTag,
              tag_name: tag_name,
              tag_value: tag_value)


proc equParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var node: Node

  if psr.c_tok.ttype != "tt_dollar":
    return Node(kind: nkNone)
  psr.advance()
  node = psr.alphaNumSymEquParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  echo text
  if psr.c_tok.ttype != "tt_dollar":
    return Node(kind: nkNone)
  psr.advance()
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkEquation,
              text: text)

proc listlevel1Parser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  if psr.c_tok.ttype != "tt_minus":
    return Node(kind: nkNone)
  psr.advance()
  var node = psr.alphaNumSymMoreParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkListLevel1,
              text: text)

proc listlevel2Parser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  for i in 1..1:
    if psr.c_tok.ttype != "tt_ident":
      return Node(kind: nkNone)
    psr.advance()
  if psr.c_tok.ttype != "tt_minus":
    return Node(kind: nkNone)
  psr.advance()
  var node = psr.alphaNumSymMoreParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start, 
              kind: nkListLevel2,
              text: text)

proc listlevel3Parser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  for i in 1..2:
    if psr.c_tok.ttype != "tt_ident":
      return Node(kind: nkNone)
    psr.advance()
  if psr.c_tok.ttype != "tt_minus":
    return Node(kind: nkNone)
  psr.advance()
  var node = psr.alphaNumSymMoreParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var text = node.text
  if psr.c_tok.ttype != "tt_newline":
    return Node(kind: nkNone)
  psr.advance()
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkListLevel3, 
              text: text)

proc textListParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var Nodes: seq[Node]
  var start = psr.tok_idx
  var node = psr.listlevel3Parser()
  if node.kind == nkNone:
    psr.goto(start)
    node = psr.listlevel2Parser()
  if node.kind == nkNone:
    psr.goto(start)
    node = psr.listlevel1Parser()
  if node.kind == nkNone:
    psr.goto(start)
    return Node(kind: nkNone)
  var error = false
  while error == false:
    start = psr.tok_idx
    Nodes.add(node)
    node = psr.listlevel3Parser()
    if node.kind == nkNone:
      psr.goto(start)
      node = psr.listlevel2Parser()
    if node.kind == nkNone:
      psr.goto(start)
      node = psr.listlevel1Parser()
    if node.kind == nkNone:
      psr.goto(start)
      error = true
  if len(Nodes) == 1:
    return Node(kind: nkNone)
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkList,
              Contains: Nodes)

proc textParEndParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  if psr.c_tok.ttype in ["tt_newline", "tt_eof"]:
      psr.advance()
      while psr.c_tok.ttype == "tt_newline":
          psr.advance()
      return Node(start_pos: start_pos,
                  end_pos: psr.c_tok.pos_start, 
                  kind: nkTextParEnd)
  return Node(kind: nkNone)

proc textSecParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var node = psr.textCommentParser()
  if node.kind == nkNone:
    node = psr.equParser()
  if node.kind == nkNone:
    node = psr.tagParser()
  if node.kind == nkNone:
    node = psr.textListParser()
  if node.kind == nkNone:
    node = psr.textLineParser()
  if node.kind == nkNone:
    node = psr.textHeadingParser()
  if node.kind == nkNone:
    node = psr.textTableParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  var Nodes: seq[Node]
  while node.kind != nkNone:
    Nodes.add(node)
    node = psr.textCommentParser()
    if node.kind == nkNone:
      node = psr.equParser()
    if node.kind == nkNone:
      node = psr.tagParser()
    if node.kind == nkNone:
      node = psr.textListParser()
    if node.kind == nkNone:
      node = psr.textLineParser()
    if node.kind == nkNone:
      node = psr.textHeadingParser()
    if node.kind == nkNone:
      node = psr.textTableParser()
  node = psr.textParEndParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  Nodes.add(node)
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkTextSec,
              Contains: Nodes)

proc bodyParser(psr: var parser): Node =
  var start_pos = psr.c_tok.pos_start
  var Nodes: seq[Node]
  var node = psr.propSecParser()
  if node.kind == nkNone:
    node = psr.textSecParser()
  if node.kind == nkNone:
    return Node(kind: nkNone)
  while node.kind != nkNone:
    Nodes.add(node)
    node = psr.propSecParser()
    if node.kind == nkNone:
      node = psr.textSecParser()
  if psr.c_tok.ttype != "tt_eof":
    initError(psr.c_tok.pos_start, psr.c_tok.pos_end, "s", "ds")
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkBody,
              Contains: Nodes)


proc runParser*(psr: var parser): Node =
  return psr.bodyParser

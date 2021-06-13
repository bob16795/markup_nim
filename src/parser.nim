import nodes, output, tokenclass
import sequtils, strutils
import macros

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

proc goto(psr: var parser, by: int = 1) =
  psr.tok_idx = by
  if psr.tok_idx < len(psr.tokens):
    psr.c_tok = psr.tokens[psr.tok_idx]
  else:
    var pos = psr.tokens[^1].pos_start
    psr.c_tok = initToken("tt_eof", "tt_eof", pos, pos)

macro parse_method*(head, body: untyped): untyped =
  var parserName, parserReturn: NimNode
  if head.kind == nnkInfix and eqIdent(head[0], ">>"):
    parserName = ident(head[1].strVal & "Parser")
    parserReturn = head[2]
  else:
    error "Invalid node: " & head.lispRepr
  
  result = newStmtList()

  template parserProc(a, b, psr, node): untyped =
    proc a(psr: var parser): Node =
      var adv = 0
      template advance(num = 1): untyped =
        adv += num
        psr.advance(num)
      template ok(): untyped =
        return node
      template bad(): untyped =
        psr.advance(-adv)
        return Node(kind: nkNone)
      template test(test, stores): untyped =
        var cccc = psr.tok_idx
        if stores.kind == nkNone:
          stores = psr.test()
        if stores.kind == nkNone:
          psr.goto(cccc)
      template badifnot(t): untyped =
        if psr.c_tok.ttype != t:
          bad()
        adv += 1
        psr.advance()
      var node = Node(kind: b, start_pos: psr.c_tok.pos_start)
      
  result.add(getAst(parserProc(parserName, parserReturn, ident("psr"), ident("node"))))

  for node in body.children:
    case node.kind:
    
    of nnkTripleStrLit:
      discard
    of nnkAsgn:
      if eqIdent(node[1], "cur"):
        node[1] = newNimNode(nnkDotExpr).add(newNimNode(nnkDotExpr).add(ident("psr")).add(ident("c_tok"))).add(ident("value"))
      if node[0].strVal[0] == 'N':
        node[0] = newNimNode(nnkDotExpr).add(ident("node")).add(ident(node[0].strVal[1..^1]))
      result[0][6].add(node)
    else:
      result[0][6].add(node)

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
    of "tt_lparen":
      found = true
      text = text & "("
      psr.advance()
    of "tt_rparen":
      found = true
      text = text & ")"
      psr.advance()
    of "tt_scolon":
      found = true
      text = text & ";"
      psr.advance()
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
    of "tt_scolon":
      found = true
      text = text & ";"
      psr.advance()
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
    of "tt_plus":
      found = true
      text = text & "+"
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
    of "tt_lbrace":
      found = true
      text = text & "{"
      psr.advance()
    of "tt_rbrace":
      found = true
      text = text & "}"
      psr.advance()
    of "tt_exclaim":
      found = true
      text = text & "!"
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_plus":
      found = true
      text = text & "+"
      psr.advance()
    of "tt_scolon":
      found = true
      text = text & ";"
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

proc alphaNumSymTextParser(psr: var parser): Node =
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
    of "tt_plus":
      found = true
      text = text & "+"
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_colon":
      found = true
      text = text & ":"
      psr.advance()
    of "tt_scolon":
      found = true
      text = text & ";"
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
    of "tt_dollar":
      found = true
      text = text & "$"
      psr.advance()
  if text == "":
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkAlphaNumSym, text: text)

proc alphaNumSymLineParser(psr: var parser): Node =
  var text = ""
  var found = true
  var start_pos = psr.c_tok.pos_start
  while found:
    found = false
    case psr.c_tok.ttype:
    of "tt_equals":
      found = true
      text = text & "="
      psr.advance()
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
    of "tt_ident":
      found = true
      text = text & "  "
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
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_dollar":
      found = true
      text = text & "$"
      psr.advance()
    of "tt_hash":
      found = true
      text = text & "#"
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_newline":
      found = true
      text = text & "\n"
      psr.advance()
  if text == "":
    return Node(kind: nkNone)
  return Node(start_pos: start_pos, end_pos: psr.c_tok.pos_start, kind: nkAlphaNumSym, text: text)

proc alphaNumSymPropParser(psr: var parser): Node =
  var text = ""
  var found = true
  var start_pos = psr.c_tok.pos_start
  while found:
    found = false
    case psr.c_tok.ttype:
    of "tt_bar":
      found = true
      text = text & "|"
      psr.advance()
    of "tt_equals":
      found = true
      text = text & "="
      psr.advance()
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
    of "tt_ident":
      found = true
      text = text & "  "
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
    of "tt_star":
      found = true
      text = text & "*"
      psr.advance()
    of "tt_backtick":
      found = true
      text = text & "`"
      psr.advance()
    of "tt_dollar":
      found = true
      text = text & "$"
      psr.advance()
    of "tt_hash":
      found = true
      text = text & "#"
      psr.advance()
    of "tt_minus":
      found = true
      text = text & "-"
      psr.advance()
    of "tt_newline":
      found = true
      text = text & "\n"
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
    of "tt_bar":
      found = true
      text = text & "|"
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
    of "tt_scolon":
      found = true
      text = text & ";"
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

parse_method codeblock >> nkCodeBlock:
  """
  CODEBLOCK := '```' TEXT? '\n' CODE  '```\n'
  """
  var n: Node
  badifnot("tt_backtick")
  badifnot("tt_backtick")
  badifnot("tt_backtick")
  n = psr.alphaNumSymTextParser()
  if n.kind != nkNone:
    node.lang = n.text
  badifnot("tt_newline")
  n = psr.alphaNumSymLineParser()
  if n.kind == nkNone:
    bad()
  Ncode = n.text
  badifnot("tt_backtick")
  badifnot("tt_backtick")
  badifnot("tt_backtick")
  badifnot("tt_newline")
  ok()

parse_method boldText >> nkTextBold:
  """
  BOLDTEXT := ('__' | '**') TEXT ('__' | '**')
  """
  var n: Node
  if not(psr.c_tok.ttype in ["tt_underscore", "tt_star"]):
    bad()
  var btype = psr.c_tok.ttype
  advance()
  badifnot(btype)
  n = psr.alphaNumSymTextParser()
  if n.kind == nkNone:
    bad()
  Ntext = n.text
  badifnot(btype)
  badifnot(btype)
  ok()

parse_method emphText >> nkTextEmph:
  """
  EMPHTEXT := ('_' | '*') TEXT ('_' | '*')
  """
  var n: Node
  if not(psr.c_tok.ttype in ["tt_underscore", "tt_star"]):
    bad()
  var btype = psr.c_tok.ttype
  advance()
  n = psr.alphaNumSymTextParser()
  if n.kind == nkNone:
    bad()
  Ntext = n.text
  badifnot(btype)
  ok()

parse_method tableSplit >> nkTableSplit:
  """
  SPLIT := '|' ('-'* '|')*
  """
  var error = false
  var ratio: seq[int]
  var col = 0
  while not error:
    error = true
    if psr.c_tok.ttype == "tt_bar":
      advance()
      col += 1
      ratio.add(0)
      while psr.c_tok.ttype == "tt_minus":
        advance()
        error = false
        ratio[^1] += 1
      if error == true:
        psr.advance(-1)
  badifnot("tt_bar")
  badifnot("tt_newline")
  Nsplit_ratio = ratio
  Nend_pos = psr.c_tok.pos_start
  ok()

parse_method tableRow >> nkTableRow:
  """
  ROW := '|' (TEXT '|')*
  """
  var error = false
  var texta = @[" "]
  texta = @[]
  while error == false:
    error = true
    if psr.c_tok.ttype == "tt_bar":
      advance()
      var n = psr.alphaNumSymParser()
      if n.kind != nkNone:
        texta &= n.text
        error = false
  if texta == @[]:
    bad()
  badifnot("tt_newline")
  Nrow_columns = texta
  Nend_pos = psr.c_tok.pos_start
  ok()

parse_method tableHeader >> nkTableHeader:
  """
  HEADER := ROW SPLIT
  """
  var heading = psr.tableRowParser()
  if heading.kind == nkNone:
    bad()
  var split = psr.tableSplitParser()
  if split.kind == nkNone:
    bad()
  Nratio = split.split_ratio
  Ntotal = split.split_ratio.foldl(a + b)
  Nheader_columns = heading.row_columns
  Nend_pos = psr.c_tok.pos_start
  ok()

parse_method textTable >> nkTable:
  """
  table := HEADER ROW*
  """
  var rows: seq[Node]
  var n = psr.tableHeaderParser()
  if n.kind == nkNone:
    bad()
  var top = n
  while n.kind != nkNone:
    rows.add(n)
    n = psr.tableRowParser()
  if len(rows) < 2:
    bad()
  Nend_pos = psr.c_tok.pos_start
  Nrows = top & rows
  ok()

parse_method propLine >> nkPropLine:
  Nstart_condition = psr.c_tok.pos_start
  Nstart_statment = psr.c_tok.pos_start
  Nend_statment = psr.c_tok.pos_start
  var invert = false
  var condition, prop, value = ""
  if psr.c_tok.ttype == "tt_exclaim":
      invert = true
      advance()
      var n = psr.alphaNumSymParser()
      if n.kind == nkNone:
        bad()
      condition = n.text
      badifnot("tt_bar")
  Ncondition = condition
  var n = psr.alphaNumSymParser()
  Nstart_statment = psr.c_tok.pos_start
  if n.kind == nkNone:
    bad()
  var text = n.text
  if (not(invert)) and (psr.c_tok.ttype == "tt_bar"):
    invert = false
    condition = text
    advance()
    n = psr.alphaNumSymParser()
    if n.kind == nkNone:
      bad()
    prop = n.text
    badifnot("tt_colon")
    if psr.c_tok.ttype == "tt_scolon":
      advance()
      n = psr.alphaNumSymPropParser()
      badifnot("tt_scolon")
    else:
      n = psr.alphaNumSymMoreParser()
    if n.kind == nkNone:
      bad()
    value = n.text
  else:
    prop = text
    badifnot("tt_colon")
    if psr.c_tok.ttype == "tt_scolon":
      advance()
      n = psr.alphaNumSymPropParser()
      badifnot("tt_scolon")
    else:
      n = psr.alphaNumSymMoreParser()
    if n.kind == nkNone:
      bad()
    value = n.text
  badifnot("tt_newline")
  Nvalue = value
  Ninvert = invert
  Nprop = prop
  Nend_statment = psr.c_tok.pos_start
  Nend_pos = psr.c_tok.pos_start
  ok()

parse_method propDiv >> nkPropDiv:
  for i in 1..3:
    badifnot("tt_minus")
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  ok()

parse_method propSec >> nkPropSec:
  var n = psr.propDivParser()
  if n.kind == nkNone:
    bad()
  var nodes: seq[Node]
  while n.kind != nkNone:
      nodes.add(n)
      n = psr.propLineParser()
  n = psr.propDivParser()
  if n.kind == nkNone:
    bad()
  while psr.c_tok.ttype == "tt_newline":
    advance()
  Nend_pos = psr.c_tok.pos_start
  NContains = nodes & n
  ok()

parse_method textLine >> nkTextLine:
  var text: seq[Node] = @[]
  var nod = Node(kind: nkNone)
  test(boldTextParser, nod)
  test(emphTextParser, nod)
  test(alphaNumSymTextParser, nod)
  while nod.kind != nkNone:
    text &= nod
    nod = Node(kind: nkNone)
    test(alphaNumSymTextParser, nod)
    test(boldTextParser, nod)
    test(emphTextParser, nod)
  if text.len() == 0:
    bad()
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  NContains = text
  ok()
  
parse_method textComment >> nkTextComment:
  badifnot("tt_exclaim")
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
    advance()
  advance()
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()
  
parse_method heading1 >> nkHeading1:
  for i in 1..1:
    badifnot("tt_hash")
  var n = psr.alphaNumSymMoreParser()
  if n.kind == nkNone:
    bad()
  var text = n.text.strip()
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()

parse_method heading2 >> nkHeading2:
  for i in 1..2:
    badifnot("tt_hash")
  var n = psr.alphaNumSymMoreParser()
  if n.kind == nkNone:
    bad()
  var text = n.text.strip()
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()
  
parse_method heading3 >> nkHeading3:
  for i in 1..3:
    badifnot("tt_hash")
  var n = psr.alphaNumSymMoreParser()
  if n.kind == nkNone:
    bad()
  var text = n.text.strip()
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()
  
parse_method textHeading >> nkNone:
  test(heading3Parser, node)
  test(heading2Parser, node)
  test(heading1Parser, node)
  ok()

parse_method tag >> nkTag:
  var tag_name, tag_value: string
  var n: Node

  badifnot("tt_ltag")
  if psr.c_tok.ttype != "tt_text":
    bad()
  tag_name = psr.c_tok.value
  tag_value = ""
  advance()
  if psr.c_tok.ttype == "tt_colon":
    advance()
    n = psr.alphaNumSymTagParser()
    if n.kind == nkNone:
      bad()
    tag_value = n.text
  badifnot("tt_rtag")
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntag_name = tag_name
  Ntag_value = tag_value
  ok()


parse_method equ >> nkEquation:
  var n: Node

  badifnot("tt_dollar")
  badifnot("tt_dollar")
  n = psr.alphaNumSymEquParser()
  if n.kind == nkNone:
    bad()
  var text = n.text
  badifnot("tt_dollar")
  badifnot("tt_dollar")
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()

parse_method listLevel1 >> nkListLevel1:
  badifnot("tt_minus")
  var n = psr.alphaNumSymMoreParser()
  if n.kind == nkNone:
    bad()
  var text = n.text
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()

parse_method listLevel2 >> nkListLevel2:
  for i in 1..1:
    badifnot("tt_ident")
  badifnot("tt_minus")
  var n = psr.alphaNumSymMoreParser()
  if n.kind == nkNone:
    bad()
  var text = n.text
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()

parse_method listLevel3 >> nkListLevel3:
  for i in 1..2:
    badifnot("tt_ident")
  badifnot("tt_minus")
  var n = psr.alphaNumSymMoreParser()
  if n.kind == nkNone:
    bad()
  var text = n.text
  badifnot("tt_newline")
  Nend_pos = psr.c_tok.pos_start
  Ntext = text
  ok()

parse_method textList >> nkList:
  var nodes: seq[Node]
  var n = Node(kind: nkNone)
  test(listlevel3Parser, n)
  test(listlevel2Parser, n)
  test(listlevel1Parser, n)
  while n.kind != nkNone:
    nodes.add(n)
    n = Node(kind: nkNone)
    test(listlevel3Parser, n)
    test(listlevel2Parser, n)
    test(listlevel1Parser, n)
  if len(nodes) <= 1:
    bad()
  NContains = nodes
  Nend_pos = psr.c_tok.pos_start
  ok()

parse_method textParEnd >> nkTextParEnd:
  badifnot("tt_newline")
  while psr.c_tok.ttype == "tt_newline":
      advance()
  ok()

parse_method textSec >> nkTextSec:
  var nodes: seq[Node]
  var n = psr.textCommentParser()
  test(textListParser, n)
  test(codeblockParser, n)
  test(equParser, n)
  test(tagParser, n)
  test(textHeadingParser, n)
  test(textTableParser, n)
  test(textLineParser, n)
  while n.kind != nkNone:
    nodes.add(n)
    n = psr.textCommentParser()
    test(textListParser, n)
    test(codeblockParser, n)
    test(equParser, n)
    test(tagParser, n)
    test(textHeadingParser, n)
    test(textTableParser, n)
    test(textLineParser, n)
  if len(nodes) < 1:
    bad()
  n = psr.textParEndParser()
  if n.kind == nkNone:
    bad()
  nodes.add(n)
  NContains = nodes
  Nend_pos = psr.c_tok.pos_start
  ok()

proc bodyParser(psr: var parser): Node =
  var start = psr.tok_idx
  var start_pos = psr.c_tok.pos_start
  var Nodes: seq[Node]
  var node = psr.propSecParser()
  if node.kind == nkNone:
    psr.goto(start)
    node = psr.textSecParser()
  if node.kind == nkNone:
    return Node(kind: nkBody)
  while node.kind != nkNone:
    start = psr.tok_idx
    Nodes.add(node)
    node = psr.propSecParser()
    if node.kind == nkNone:
      psr.goto(start)
      node = psr.textSecParser()
  if psr.c_tok.ttype != "tt_eof":
    initError(psr.c_tok.pos_start, psr.c_tok.pos_end, "not at eof", "lastparsed =\n---\n" & $Nodes[^1] & "\n---")
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkBody,
              Contains: Nodes)


proc runParser*(psr: var parser): Node =
  return psr.bodyParser

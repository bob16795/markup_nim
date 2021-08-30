import plugnodes, ../output
import sequtils, strutils
import macros, tokenclass

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
        node[1] = newNimNode(nnkDotExpr).add(newNimNode(nnkDotExpr).add(ident(
            "psr")).add(ident("c_tok"))).add(ident("value"))
      if node[0].strVal[0] == 'N':
        node[0] = newNimNode(nnkDotExpr).add(ident("node")).add(ident(node[
            0].strVal[1..^1]))
      result[0][6].add(node)
    else:
      result[0][6].add(node)

proc initParser*(tokens: seq[Token], tok_idx: int): parser =
  result.tokens = tokens
  result.tok_idx = tok_idx
  result.advance()

parse_method cond >> nkCond:
  var inv = false
  if psr.c_tok.ttype == "tt_exclaim":
    advance()
    inv = true
  if psr.c_tok.ttype != "tt_text":
    bad()
  var cond = psr.c_tok.value
  advance()
  if psr.c_tok.ttype != "tt_text":
    bad()
  var cmd = psr.c_tok.value
  advance()
  NcKeyword = cond
  NcCommand = cmd
  Ninv = inv
  ok()

parse_method line >> nkLine:
  badifnot("tt_ident")
  var nod: Node
  test(condParser, nod)
  Nconds = @[nod]
  if psr.c_tok.ttype != "tt_long":
    bad()
  Nkeyword = psr.c_tok.value
  advance()
  var command = ""
  if psr.c_tok.ttype == "tt_colon":
    advance()
    if psr.c_tok.ttype == "tt_text":
      command = psr.c_tok.value & "\n"
      advance()
    badifnot("tt_newline")
    badifnot("tt_ident")
    badifnot("tt_ident")
    while true:
      var prev = ""
      while psr.c_tok.ttype != "tt_newline":
        if psr.c_tok.ttype == prev:
          command &= " "
        prev = psr.c_tok.ttype
        command &= psr.c_tok.value
        advance()
      command &= "\n"
      advance()
      var dindent = false
      var cp = psr.tok_idx
      if psr.c_tok.ttype == "tt_ident":
        advance()
        if psr.c_tok.ttype == "tt_ident":
          advance()
          dindent = true
      if not dindent:
        psr.goto(cp - 1)
        command = command[0..^2]
        break
  else:
    if psr.c_tok.ttype == "tt_text":
      command = psr.c_tok.value
      advance()
  Ncommand = command
  badifnot("tt_newline")
  ok()

parse_method tagArgs >> nkTagArgs:
  badifnot("tt_lparen")
  var names: seq[string]
  if psr.c_tok.ttype != "tt_text":
    bad()
  names &= psr.c_tok.value
  advance()
  while psr.c_tok.ttype == "tt_comma":
    advance()
    if psr.c_tok.ttype != "tt_text":
      bad()
    names &= psr.c_tok.value
    advance()
  Nnames = names
  badifnot("tt_rparen")
  ok()

parse_method tagDef >> nkTagDef:
  var n: Node
  var extra: seq[Node]
  var lines: seq[Node]
  if not(psr.c_tok.ttype in ["tt_text", "tt_lbrace"]):
    bad()
  var predef = psr.c_tok.ttype == "tt_lbrace"
  var text = ""
  if predef:
    advance()
    text = psr.c_tok.value
    advance()
    badifnot("tt_rbrace")
  else:
    text = psr.c_tok.value
    advance()
  badifnot("tt_colon")
  test(tagArgsParser, n)
  extra &= n
  badifnot("tt_newline")
  n = Node(kind: nkNone)
  test(lineParser, n)
  while n.kind != nkNone:
    lines &= @[n]
    n = Node(kind: nkNone)
    test(lineParser, n)
  Nextra = extra
  Nlines = lines
  Npredef = predef
  Nname = text
  ok()

proc bodyParser(psr: var parser): Node =
  var start = psr.tok_idx
  var start_pos = psr.c_tok.pos_start
  var Nodes: seq[Node]
  var node = psr.tagDefParser()
  if node.kind == nkNone:
    initError(psr.c_tok.pos_start, psr.c_tok.pos_end, "not at eof",
        "lastparsed =")
  while node.kind != nkNone:
    start = psr.tok_idx
    Nodes.add(node)
    node = psr.tagDefParser()
  if psr.c_tok.ttype != "tt_eof":
    initError(psr.c_tok.pos_start, psr.c_tok.pos_end, "not at eof",
        "lastparsed =\n---\n" & $Nodes[^1] & "\n---")
  return Node(start_pos: start_pos,
              end_pos: psr.c_tok.pos_start,
              kind: nkBody,
              Contains: Nodes)


proc runParser*(psr: var parser): Node =
  return psr.bodyParser

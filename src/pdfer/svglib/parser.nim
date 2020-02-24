import lists, strutils, sequtils
import nodes

type
  parser* = object
    tokens: string
    tok_idx: int
    c_tok: char

var psr: parser

proc advance(psr: var parser, by: int = 1) =
  psr.tok_idx = psr.tok_idx + by
  if psr.tok_idx < len(psr.tokens):
    psr.c_tok = psr.tokens[psr.tok_idx]
  else:
    psr.c_tok = '\b'
proc goto(psr: var parser, to: int = 1) =
  psr.tok_idx = to
  if psr.tok_idx < len(psr.tokens):
    psr.c_tok = psr.tokens[psr.tok_idx]
  else:
    psr.c_tok = '\b'


proc initParser*(tokens: string, tok_idx: int): parser =
  psr.tokens = tokens
  psr.tok_idx = tok_idx
  psr.advance()
  return psr

proc parseStringExact(psr: var parser, match: string): bool =
  var start = psr.tok_idx
  for c in match:
    if c == psr.c_tok:
      psr.advance()
    else:
      echo psr.c_tok
      psr.goto(start)
      return false
  return true

proc parseStringOrReturn(psr: var parser, match: seq[string]): string =
  var start = psr.tok_idx
  for s in match:
    if psr.parseStringExact(s):
      return s
  return ""

proc parseCharOr(psr: var parser, match: seq[char]): bool =
  var start = psr.tok_idx
  for c in match:
    if c == psr.c_tok:
      return true
  return false

proc parseCharOrReturn(psr: var parser, match: seq[char]): char =
  var start = psr.tok_idx
  for c in match:
    if c == psr.c_tok:
      return c
  return '\x00'

proc parseMatchTry(psr: var parser, trys: seq[proc]): Node =
  var node: Node
  for try_p in trys:
    node = try_p(psr)
    if node.kind != nkNone:
      return node
  return 

proc parseDocument(psr: var parser): Node 
proc parseProlog(psr: var parser): Node
proc parseXMLDecl(psr: var parser): Node
proc parseVersionInfo(psr: var parser): Node
proc parseVersionNum(psr: var parser): Node
proc parseSDDecl(psr: var parser): Node
proc parseEncodingDecl(psr: var parser): Node
proc parseEncodingName(psr: var parser): Node
proc parseMisc(psr: var parser): Node
proc parseEq(psr: var parser): Node
proc parseS(psr: var parser): Node

proc parseDocument(psr: var parser): Node =
  ## document ::= prolog element Misc*
  var nodes: seq[Node]
  nodes.add(psr.parseProlog())
  return Node(kind: nkDocument, Contains: nodes)

proc parseProlog(psr: var parser): Node =
  ## prolog ::= XMLDecl? Misc* (doctypedecl Misc*)?
  var node: Node
  var nodes: seq[Node]
  node = psr.parseMatchTry(@[parseXMLDecl])
  if node.kind != nkNone:
    nodes.add(node)
  return Node(kind: nkprolog, Contains: nodes)

proc parseXMLDecl(psr: var parser): Node =
  ## XMLDecl ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
  var nodes: seq[Node]
  var node: Node
  if not(psr.parseStringExact("<?xml")):
    return
  node = psr.parseVersionInfo()
  if node.kind == nkNone:
    return
  nodes.add(node)
  node = psr.parseEncodingDecl()
  if node.kind != nkNone:
    nodes.add(node)
  node = psr.parseSDDecl()
  if node.kind != nkNone:
    nodes.add(node)
  discard psr.parseS()
  if not(psr.parseStringExact("?>")):
    return
  return Node(kind: nkXMLDecl, Contains: nodes)

proc parseVersionInfo(psr: var parser): Node =
  ## VersionInfo ::= S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
  var nodes: seq[Node]
  var node: Node
  node = psr.parseS()
  if node.kind == nkNone:
    return
  if not(psr.parseStringExact("version")):
    return
  node = psr.parseEq()
  if node.kind == nkNone:
    return
  var quo = psr.parseStringExact("\"")
  var dquo = psr.parseStringExact("\'")
  node = psr.parseVersionNum()
  if node.kind == nkNone:
    return
  var equo = psr.parseStringExact("\"")
  var edquo = psr.parseStringExact("\'")
  if not((quo and equo) or (dquo and edquo)):
    return
  nodes.add(node)
  discard psr.parseS()
  return Node(kind: nkVersionInfo, Contains: nodes)

proc parseVersionNum(psr: var parser): Node =
  ## VersionNum  ::= '1.' [0-9]+
  var num: string
  if not(psr.parseStringExact("1.")):
    return 
  num.add("1.")
  if not(psr.parseCharOr(@['0','1','2','3','4','5','6','7','8','9'])):
    return
  num.add(psr.c_tok)
  psr.advance()
  while psr.parseCharOr(@['0','1','2','3','4','5','6','7','8','9']):
    num.add(psr.c_tok)
    psr.advance()
  return Node(kind: nkVersionNum, num: num)

proc parseSDDecl(psr: var parser): Node =
  ## SDDecl ::= S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"'))
  var node: Node
  var nodes: seq[Node]
  discard psr.parseS()
  if not(psr.parseStringExact("standalone")):
    return
  node = psr.parseEq()
  if node.kind == nkNone:
    return
  var quo = psr.parseStringExact("\"")
  var dquo = psr.parseStringExact("\'")
  var yon = psr.parseStringOrReturn(@["yes", "no"])
  if yon == "":
    return
  var equo = psr.parseStringExact("\"")
  var edquo = psr.parseStringExact("\'")
  if not((quo and equo) or (dquo and edquo)):
    return
  return Node(kind: nkSDDecl, yon: yon)

proc parseEncodingDecl(psr: var parser): Node =
  ## EncodingDecl ::= S 'encoding' Eq ('"' EncName '"' | "'" EncName "'" )
  var node: Node
  var nodes: seq[Node]
  discard psr.parseS()
  if not(psr.parseStringExact("encoding")):
    return
  node = psr.parseEq()
  if node.kind == nkNone:
    return
  var quo = psr.parseStringExact("\"")
  var dquo = psr.parseStringExact("\'")
  node = psr.parseEncodingName()
  if node.kind == nkNone:
    return
  var equo = psr.parseStringExact("\"")
  var edquo = psr.parseStringExact("\'")
  if not((quo and equo) or (dquo and edquo)):
    return
  return Node(kind: nkEncodingDecl, Contains: @[node])

proc parseEncodingName(psr: var parser): Node =
  ## EncName ::= [A-Za-z] ([A-Za-z0-9._] | '-')*
  var enc: string
  var c = psr.parsecharOrReturn(concat(toSeq('a'..'z'), toSeq('A'..'Z')))
  if c != '\x00':
    enc.add(c)
  else:
    return
  psr.advance()
  while true:
    c = psr.parsecharOrReturn(concat(toSeq('a'..'z'), toSeq('A'..'Z'), toSeq('0'..'9'), @['_', '.']))
    if c == '\x00':
      break
    else:
      enc.add(c)
      psr.advance()
  return Node(kind: nkEncodingName, enc: enc)


proc parseMisc(psr: var parser): Node =
  ## Misc ::= Comment | PI | S
  var node: Node
  node = psr.parseComment()
  if node.kind == nkNone:
    node = psr.parsePos()
  if node.kind == nkNone:
    node = psr.parseS()
  return node

proc parseEq(psr: var parser): Node =
  ## Eq ::= S? '=' S?
  discard psr.parseS()
  if not(psr.parseStringExact("=")):
    return
  discard psr.parseS()
  return Node(kind: nkEq)

  
proc parseS(psr: var parser): Node =
  ## S ::= (#x20 | #x9 | #xD | #xA)+
  if not(psr.parseCharOr(@['\x20', '\x09', '\x0D', '\x0A'])):
    return
  psr.advance()
  while psr.parseCharOr(@['\x20', '\x09', '\x0D', '\x0A']):
    psr.advance()
  return Node(kind: nkSpace)

proc runParser*(psr: var parser): Node =
  return psr.parseDocument()


var file = readFile("Let Your Heart Be Your Compass SVG Cut File.svg")
var parse = initParser(file, -1)
echo parse.runParser()

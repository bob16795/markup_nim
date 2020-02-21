import lists, strutils
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

proc parseCharOr(psr: var parser, match: seq[char]): bool =
  var start = psr.tok_idx
  for c in match:
    if c == psr.c_tok:
      return true
  return false

proc parseMatchTry(psr: var parser, trys: proc): Node =
  var node: Node
  node = trys(psr)
  if node.kind != nkNone:
    return node
  else:
    return 

proc parseDocument(psr: var parser): Node 
proc parseProlog(psr: var parser): Node
proc parseXMLDecl(psr: var parser): Node
proc parseVersionInfo(psr: var parser): Node
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
  node = psr.parseMatchTry(parseXMLDecl)
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
  # if not(psr.parseStringExact("?>")):
  #   return
  return Node(kind: nkXMLDecl, Contains: nodes)

proc parseVersionInfo(psr: var parser): Node =
  ##   VersionInfo     ::=     S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
  var nodes: seq[Node]
  var node: Node
  node = psr.parseS()
  if node.kind == nkNone:
    return
  nodes.add(node)
  return Node(kind: nkVersionInfo, Contains: nodes)

  
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

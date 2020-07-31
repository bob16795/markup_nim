import tokenclass, output

type
  lexer* = object
    text: string
    pos: position
    c_char: char

proc advanceLexer(lex: var lexer) =
  lex.pos = advancePos(lex.pos, lex.c_char)
  if lex.pos.idx < lex.text.len():
    lex.c_char = lex.text[lex.pos.idx]
  else:
    lex.c_char = '\b'

proc initLexer*(text: string, fn: string): lexer =
  result.text = "\n" & text
  if text == "":
    result.text = "\n" & result.text
  result.pos = initPos(-1, 0, -1, fn, text) 
  advanceLexer(result)

proc constructTextToken(lex: var lexer): Token =
  let EXCHARS  = "#\t*+-_:|<>(){}!$\n"#0123456789"
  var text_str = ""
  var pos_start = lex.pos
  while lex.c_char != '\b' and not(lex.c_char in EXCHARS[1..^1]):
    text_str = text_str & lex.c_char
    advanceLexer(lex)
  return initToken("tt_text", text_str, pos_start, lex.pos)

proc constructNumToken(lex: var lexer): Token =
  let DIGITS = "0123456789"
  var text_str = ""
  var pos_start = lex.pos
  while lex.c_char != '\b' and lex.c_char in DIGITS & ".":
    text_str = text_str & lex.c_char
    advanceLexer(lex)
  return initToken("tt_num", text_str, pos_start, lex.pos)

proc runLexer*(lex: var lexer): seq[Token] =
  #let DIGITS = "0123456789"
  let DIGITS = ""
  var tokens = newSeq[Token]()
  while lex.c_char != '\b':
    case lex.c_char:
    of '#':
      tokens.add(initToken("tt_hash", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '\t':
      tokens.add(initToken("tt_ident", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '*':
      tokens.add(initToken("tt_star", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '+':
      tokens.add(initToken("tt_plus", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '-':
      tokens.add(initToken("tt_minus", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '_':
      tokens.add(initToken("tt_underscore", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ':':
      tokens.add(initToken("tt_colon", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '|':
      tokens.add(initToken("tt_bar", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ' ':
      tokens.add(initToken("tt_text", " ", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '<':
      tokens.add(initToken("tt_ltag", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '>':
      tokens.add(initToken("tt_rtag", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '(':
      tokens.add(initToken("tt_lparen", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ')':
      tokens.add(initToken("tt_rparen", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '{':
      tokens.add(initToken("tt_lbrace", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '}':
      tokens.add(initToken("tt_rbrace", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '!':
      tokens.add(initToken("tt_exclaim", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '$':
      tokens.add(initToken("tt_dollar", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '\n':
      tokens.add(initToken("tt_newline", "", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
      while lex.c_char != '\b':
        if lex.c_char == ' ':
          advanceLexer(lex)
          if lex.c_char == ' ':
            tokens.add(initToken("tt_ident", "", lex.pos, advancePos(lex.pos, lex.c_char)))
            advanceLexer(lex)
          else:
            tokens.add(initToken("tt_text", $lex.c_char, lex.pos, advancePos(lex.pos, lex.c_char)))
            advanceLexer(lex)
            break
        else:
          break
    else:
      if lex.c_char in DIGITS:
        tokens.add(constructNumToken(lex))
      else:
        tokens.add(constructTextToken(lex))
  tokens.add(initToken("tt_newline", "", lex.pos, advancePos(lex.pos, lex.c_char)))
  return tokens[1..^1]

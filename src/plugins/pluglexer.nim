import tokenclass, ../output
import strutils

type
  lexer* = object
    text: string
    pos: position
    c_char: char

const longTokens: seq[string] = @["muplug", "SET", "TAG", "CODE", "EXISTSD", "EXISTSF", "EXISTS", "PROP", "RAW"]

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
  let EXCHARS = "\t:|(){}!,\n"
  var text_str = ""
  var pos_start = lex.pos
  while lex.c_char != '\b' and not(lex.c_char in EXCHARS[1..^1]):
    if lex.c_char == '\\':
      advanceLexer(lex)
    text_str = text_str & lex.c_char
    advanceLexer(lex)
  return initToken("tt_text", text_str, pos_start, lex.pos)

proc runLexer*(lex: var lexer): seq[Token] =
  var tokens = newSeq[Token]()
  while lex.c_char != '\b':
    for tok in longTokens:
      var pos = lex.pos
      block test:
        if tok[0] == lex.c_char:
          for c in 1..<tok.len:
            advanceLexer(lex)
            if lex.c_char != tok[c]:
              lex.pos = pos
              if lex.pos.idx < lex.text.len():
                lex.c_char = lex.text[lex.pos.idx]
              else:
                lex.c_char = '\b'
              break test
          tokens.add(initToken("tt_long", tok, pos, lex.pos))
          advanceLexer(lex)
    case lex.c_char:
    of '\t':
      tokens.add(initToken("tt_ident", "\t", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ':':
      tokens.add(initToken("tt_colon", ":", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ';':
      tokens.add(initToken("tt_scolon", ";", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '|':
      tokens.add(initToken("tt_bar", "|", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ' ':
      advanceLexer(lex)
    of '(':
      tokens.add(initToken("tt_lparen", "(", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ')':
      tokens.add(initToken("tt_rparen", ")", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '{':
      tokens.add(initToken("tt_lbrace", "{", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '}':
      tokens.add(initToken("tt_rbrace", "}", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of '!':
      tokens.add(initToken("tt_exclaim", "!", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    of ',':
      tokens.add(initToken("tt_comma", ",", lex.pos, advancePos(lex.pos, lex.c_char)))
      advanceLexer(lex)
    # of '\\':
    #   advanceLexer(lex)
    #   tokens.add(initToken("tt_text", $lex.c_char, lex.pos, advancePos(lex.pos, lex.c_char)))
    #   advanceLexer(lex)
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
            tokens.add(initToken("tt_text", $lex.c_char, lex.pos, advancePos(
                lex.pos, lex.c_char)))
            advanceLexer(lex)
            break
        else:
          break
      if lex.c_char == '\\':
        advanceLexer(lex)
    else:
      tokens.add(constructTextToken(lex))
  tokens.add(initToken("tt_newline", "", lex.pos, advancePos(lex.pos, lex.c_char)))
  return tokens[1..^1]

when isMainModule:
  var lex = initLexer(readFile("../../docs/examples/testplugin.mug"), "test")
  log("test", $lex.runLexer())
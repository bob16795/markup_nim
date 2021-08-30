import lists
import ../output

type
  Token* = object
    ttype*, value*: string
    pos_start*, pos_end*: position

proc initToken*(ttype: string, value: string, pos_start: position,
    pos_end: position): Token =
  result.ttype = ttype
  result.value = value

  result.pos_start = pos_start
  result.pos_end = pos_end

proc len*(list: SinglyLinkedList[Token]): int =
  var i = 1
  for j in list:
    i += 1
  return i

proc `[]`*(list: SinglyLinkedList[Token]; idx: int): Token =
  var i = -1
  for j in list:
    i += 1
    if i == idx:
      return j
  return

proc `$`*(tok: Token): string = $tok.ttype & ": " & $tok.value & $tok.pos_start

proc `$`*(toks: seq[Token]): string =
  for tok in toks:
    result &= $tok & "\n"


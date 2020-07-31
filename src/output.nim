import strutils, terminal

type
  OutputMethod* = object of RootObj
  
  LogMethod* = object of OutputMethod
    log_name, details: string
  WarningMethod* = object of OutputMethod
    log_name, details: string
  ErrorMethod* = object of OutputMethod
    error_name, details: string
    pos_start, pos_end: position

  position* = object
    idx*, ln, col: int
    fn*, ftxt: string

proc reversed(s: string): string =
  result = newString(s.len)
  for i,c in s:
    result[s.high - i] = c

proc string_with_arrows(text: string, pos_start: position, pos_end: position): string =
  result = ""
  try:
    # indexes
    var idx_start = max(pos_start.idx - reversed(text[0..<pos_start.idx]).find("\n"), 0)
    var idx_end   = idx_start + (text[idx_start + 1..<text.len].find("\n"))
    if idx_end < 0: idx_end = text.len - 1

    # lines
    var line_count = pos_end.ln - pos_start.ln + 1
    var line: string
    var col_start, col_end: int
    for i in 0..<line_count:
      # Calculate line columns
      line = text[idx_start..idx_end]
      if i == 0:
        col_start = pos_start.col
      else:
        col_start = 0
      if i == line_count - 1:
        col_end = pos_end.col
      else:
        col_end = len(line) - 1

      # Append to result
      result = result & line & "\n"
      result = result & " ".repeat(col_start) & ("^".repeat(col_end - col_start))

      # Re-calculate indices
      idx_start = idx_end
      idx_end = text.find('\n', idx_start + 1)
      if idx_end < 0: idx_end = len(text)

    result = result.replace("\t", "")
  except:
    return ""

proc `$`(obj: ErrorMethod): string =
  result =          obj.error_name & ": " & obj.details & "\n"
  result = result & "File <" & obj.pos_start.fn & ">, Line " & $(obj.pos_start.ln + 1)
  result = result & "\n\n" & string_with_arrows(obj.pos_start.ftxt, obj.pos_start, obj.pos_end) & "\n"

proc initError*(pos_start: position, pos_end: position, error_name: string, details: string) =
  var error: ErrorMethod
  error.pos_start = pos_start
  error.pos_end = pos_end
  error.error_name = error_name
  error.details = details
  log(error.pos_start.fn, $error)
  quit()

proc initPos*(idx: int, ln: int, col: int, fn: string, ftxt: string): position =
  result.idx = idx
  result.ln = ln
  result.col = col
  result.fn = fn
  result.ftxt = ftxt

proc advancePos*(pos: position, char: char): position =
  result = pos
  result.idx = pos.idx + 1
  result.col = pos.col + 1
  result.ln = pos.ln
  if char == '\n':
    result.ln = pos.ln + 1
    result.col = 0

proc `$`*(pos: position): string = "(" & $pos.ln & ", " & $pos.col & ")"

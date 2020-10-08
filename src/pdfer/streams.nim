import strformat
import strutils
import lib, math
#import ../terminal

type
  Stream* = object
    text*: string
    x*, y*, width*, height*: int
    linespace: int

proc split_paren(S: string): seq[string] =
  if S == "":
    return
  result = @[]
  var empty = true
  if "(" in S:
    var lst: seq[string] = @[]
    var prelst = S.split("(")
    var lol = ""
    for i in prelst:
      if lol == "":
        lol &= i
      elif lol[^1] == '\\':
        lol &= i
      else:
        lol &= i
        lst &= lol
        lol = ""
    lst &= lol
    for a in lst:
      #if a == "":
      #  empty = false
      #  continue
      #if result == @[]:
      #if empty:
      #  result &= a
      #else:
      var lst = a.split("\\)")
      var lol = ""
      for i in lst:
        if ") " in i:
          lol &= i.split(") ")[0]
          result &= lol
          lol = ""
          lol &= i.split(") ")[^1]
        else:
          lol &= i
        lol &= "\\)"
      lol = lol[0..^3]
      result &= lol
      #elif result[^1][^1] != '\\':
      #  var lst = a.split("\\)")
      #  var lol = ""
      #  for i in lst:
      #    if ") " in i:
      #      lol &= i.split(") ")[0]
      #      result &= lol
      #      lol = ""
      #      lol &= i.split(") ")[^1]
      #    else:
      #      lol &= i
      #    lol &= "\\)"
      #  lol = lol[0..^3]
      #  result &= lol
      #  #result &= a.split(")")[0]
      #  #result &= a.split(")")[^1].split(" ")
      #else:
      #  result &= "(" & a.split(")")[0]
      #  if ")" in a:
      #    result &= a.split(")")[^1]
      while result[^1] == "":
        if result == @[]:
          break
        result = result[0..^2]
      empty = false
  else:
    result = S.split(" ")
  while "" in result:
    for i in 0..high(result):
      if result[i] == "":
        result.delete(i)
        break

proc CleanStream(S: Stream): Stream =
  var full_text = S.text
  result.x = -1
  result.y = -1
  var font_size = ""
  var font = ""
  var lineheight, width, height, word_spacing, char_spacing: float
  width = -1
  height = -1
  var x, gx: float = 0
  var y, gy: float = 0
  for line in full_text.split("\n"):
    var commands = line.split_paren()
    if commands == @[]:
      continue
    case commands[^1]:
    of "Tf":
      if font != commands[0] or font_size != commands[1]:
        font_size = commands[1]
        font = commands[0]
        result.text &= line & "\n"
    of "Td":
      x += commands[0].parseFloat()
      y += commands[1].parseFloat()
      if commands[0].parseFloat() != 0:
        if (x.int < result.x) or (result.x == -1):
          result.x = x.int
      if commands[1].parseFloat() != 0:
        if (y.int < result.y) or (result.y == -1):
          result.y = y.int
      if commands[0].parseFloat() != 0 or commands[1].parseFloat() != 0:
        result.text &= line & "\n"
    of "TL":
      if commands[0].parseFloat() != lineheight:
        lineheight = commands[0].parseFloat()
        result.text &= line & "\n"
    of "Tj":
      if commands[0].strip != "" and len(commands) != 1:
        var size = get_text_size_spacing(commands[0].strip(), font_size.parseFloat(), "times.ttf", char_spacing, word_spacing)
        if sgn(size) == 0:
          size = 0
        if width < x + size or width == -1:
          width = x + size
        result.text &= line & "\n"
    of "Tw":
      if word_spacing != commands[0].parsefloat() and not(commands[0] in ["nan", "inf", "-inf"]):
        word_spacing = commands[0].parsefloat()
        result.text &= line & "\n"
    of "Tc":
      if char_spacing != commands[0].parsefloat() and not(commands[0] in ["nan", "inf", "-inf"]):
        char_spacing = commands[0].parsefloat()
        result.text &= line & "\n"
    of "T*":
      y += lineheight
      result.text &= line & "\n"
    of "m", "l":
      gx = commands[0].parseFloat()
      gy = commands[1].parseFloat()
      if (gx.int < result.x):
        result.x = gx.int
      if (gy.int < result.y):
        result.y = gy.int
      if (gx.int > width.int):
        width = gx - result.x.float
      if (gy.int > height.int):
        height = gy - result.y.float
      result.text &= line & "\n"
    of "re":
      result.text &= line & "\n"
    of "f", "b", "B", "S", "rg", "RG":
      result.text &= line & "\n"
    else:
      discard
    if y + lineheight > height:
      height = y + lineheight
  if font_size == "":
    font_size = "0"
  result.linespace = lineheight.int
  result.y -= (lineheight.int - font_size.parse_float().int)
  result.height = height.int - (result.y)
  result.width = width.int - result.x

proc `&`*(A, B: Stream): Stream {.gcsafe.}

proc highlightStream*(St: Stream, R, G, B: float): array[0..1, Stream] =
  var S = St.CleanStream()
  var rect = Stream()
  rect.text &= &"{R} {G} {B} RG\n"
  rect.text &= &"{R} {G} {B} rg\n"
  rect.text &= &"{S.x} {S.y} {S.width} {S.height} re\n"
  rect.text &= &"f\n"
  rect.text &= &"0 0 0 RG\n"
  rect.text &= &"0 0 0 rg\n"
  return([CleanStream(rect), S])

proc CreateTextStream*(x, y: int, size, linespacing: float, font, font_face: string, width: int, newline: bool, text: string, align: int = 1): Stream =
  result.text &= &"/{font} {size} Tf\n"
  #result.text &= &"{x} {y.float - size - linespacing} Td\n"
  result.text &= &"{x} {y.float} Td\n"
  result.text &= &"{size + linespacing} TL\n"
  for line in text.split("\n"):
    var pdf_line: seq[string]
    var out_line = "("
    for word in line.split(" "):
      if word == "\\n":
        out_line &= " ) Tj\n"
        out_line &= &"/F1 {size} Tf\n("
        continue
      elif word == "\\b":
        out_line &= " ) Tj\n"
        out_line &= &"/F2 {size} Tf\n("
        continue
      elif word == "\\e":
        out_line &= " ) Tj\n"
        out_line &= &"/F3 {size} Tf\n("
        continue
      else:
        out_line &= &" {word.addbs()}"
        pdf_line &= word
      if get_text_size(pdf_line.join(" "), size, font_face) >= width.float:
        try: out_line = out_line[0..^(len(word.addbs()) + 1)].replace("( ", "(")
        except: discard
        out_line &= ") Tj\n"
        var word_spacing: float = 1
        if (pdf_line.len - 1) != 0:
          var needs = ( width.float - get_text_size(join(pdf_line[0..^2], " ").strip(), size, font_face))
          word_spacing = (needs / (len(pdf_line[0..^3])).toFloat())
        if $word_spacing == "inf" or $word_spacing == "-inf":
          word_spacing = 0
        var char_spacing: float = 0
        if len(pdf_line) < 3:
          char_spacing = (( width.float - get_text_size(pdf_line[0], size, font_face)) / (len(pdf_line[0])).toFloat)
        result.text &= &"{word_spacing} Tw\n{char_spacing} Tc\n{out_line}\nT*\n"
        out_line = &"({word.addbs()}"
        pdf_line = @[word]
    if pdf_line != @[]:
      out_line &= " ) Tj\n"
      out_line = out_line.replace("( ", "(")
      result.text &= &"0 Tw\n0 Tc\n{out_line}"
  return(CleanStream(result))

proc CreateLineStream*(xs, ys, xe, ye: float): Stream =
  result.text &= &"{xs} {ys} m\n"
  result.text &= &"{xe} {ye} l\n"
  result.text &= &"S\n"
  return(CleanStream(result))

proc moveTo*(A: Stream, x, y, size, lineheight: float): Stream =
  var done = false
  var text = A.text
  text = A.text
  if not("Td" in A.text):
    text = &"0 0 Td\n" & A.text
  for line in text.split("\n"):
    #if done:
    #  result.text &= line & "\n"
    #else:
    var commands = line.split_paren()
    if commands == @[]:
      continue
    case commands[^1]:
    of "Td":
      if not done:
        result.text &= &"{x} {y - size - lineheight} Td\n"
      else:
        result.text &= line & "\n"
      done = true
    else:
      result.text &= line & "\n"
  return(CleanStream(result))

proc trim*(A: Stream, height: int): array[0..1, Stream] =
  var B, C: Stream
  if A.height > height:
    var full_text = A.text
    var lineheight, cheight: float
    var ov = false
    for line in full_text.split("\n"):
      if ov:
        if line != "":
          C.text &= line & "\n"
      else:
        var commands = line.split_paren()
        if commands == @[]:
          continue
        case commands[^1]:
        of "TL":
          lineheight = commands[0].parseFloat()
          C.text &= line & "\n"
          if cheight + lineheight * 2 > height.float:
            ov = true
        of "T*":
          if cheight + lineheight * 2 > height.float:
            ov = true
          else:
            cheight += lineheight
        of "Tj":
          discard
        else:
          C.text &= line & "\n"
        B.text &= line & "\n"
    return [B.CleanStream(), C.CleanStream()]
  else:
    return [A.CleanStream(), Stream()]
      
proc `&`*(A, B: Stream): Stream =
  var full_text = A.text & "\n" & B.text
  result.text = full_text
  return(CleanStream(result))

proc `$`*(A: Stream): string =
  #when DEBUG:
  #  return "BT\n" & &"%W: {A.width}\n%H: {A.height}\n" & A.text & "ET"
  #else:
  return "BT\n" & A.text & "ET"

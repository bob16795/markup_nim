import sdl2/ttf as ttf
import strutils, segfaults, tables

var faces {.threadvar.}: Table[cint, ttf.FontPtr]

const page_sizes = @[ # this is in mm
("A4", [210, 297]),
("A5", [148, 210]),
("Letter", [216, 279])
].toTable()

proc `*`(A: array[0..1, int], B: float): array[0..1, int] =
  result[0] = (A[0].toFloat() * B).toInt()
  result[1] = (A[1].toFloat() * B).toInt()

proc get_page_size*(name: string): array[0..1, int] =
  if " " in name.strip():
    return [name.strip().split(" ")[0].parseInt(), name.strip().split(" ")[1].parseInt()]
  else:
    if name.strip() in page_sizes:
      return page_sizes[name] * (72/25.4)
  return page_sizes["A4"] * (72/25.4)

proc get_text_size*(text: cstring, size: float, font_file: string): float =
  if not(ttfWasInit()):
    discard ttfinit()
  var c_intsize: cint = size.toInt.toU32()
  if not(c_intsize in faces):
    faces[c_intsize] = ttf.openFont(font_file, c_intsize)
  result = 0
  var wid: cint = 0
  var w = wid.addr
  var h: ptr cint
  try:
    discard faces[c_intsize].sizeText(text, w, h)
    result += wid.toFloat
  except:
    return 20

proc get_text_size_spacing*(text: string, size: float, font_file: string, char_spacing, word_spacing: float): float =
  if not(ttfWasInit()):
    discard ttfinit()
  var c_intsize: cint = size.cint
  if not(c_intsize in faces):
    faces[c_intsize] = ttf.openFont(font_file, c_intsize)
  var wspace = word_spacing.cint
  var h: ptr cint
  if wspace == 0:
    discard faces[c_intsize].sizeText(" ", wspace.addr, h)
  for word in text.split(" "):
    var wid: cint = 0
    discard faces[c_intsize].sizeText(word, wid.addr, h)
    result += wid.float
    result += char_spacing * (len(word).float - 1)
  result += wspace.float * (len(text.split(" ")).float - 1)

proc lib_deinit*() =
  for s, font in faces:
    close(font)
  ttfQuit()

func utf8tolatin1(text: string): string =
  var codepoint: int
  var i = 0
  while len(text) > i:
    var ch = text[i].byte
    if ch <= 0x7f:
      codepoint = ch.int
    elif ch <= 0xbf:
      codepoint = (codepoint shl 6) or (ch and 0x3f).int
    elif ch <= 0xdf:
      codepoint = ch.int and 0x1f
    elif ch <= 0xef:
      codepoint = ch.int and 0x0f
    else:
      codepoint = ch.int and 0x07
    i += 1
    try:
      if (text[i].byte and 0x0C) != 0x80 and (codepoint <= 0x10ffff):
        if codepoint <= 255:
          result &= codepoint.char
    except:
      discard
  if codepoint <= 255:
    result &= codepoint.char

func addbs*(text: string): string =
    result = text.replace("\\", "\\\\")
    result = result.replace("(", "\\(")
    result = result.replace(")", "\\)").strip()

func removebs*(text: string): string =
    result = text.replace("\\\\", "\\")
    result = result.replace("\\(", "(")
    result = result.replace("\\)", ")")

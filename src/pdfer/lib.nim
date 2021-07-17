import sdl2/ttf as ttf
import strutils, segfaults, tables
import parseutils
import ../output

var faces {.threadvar.}: Table[cint, ttf.FontPtr]
var face_names {.threadvar.}: Table[string, string]

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

proc parse_uint32(file: File): uint32 =
  var a: seq[uint8] = @[0.uint8, 0.uint8, 0.uint8, 0.uint8]
  if 4 != file.readBytes(a, 0, 4):
    return
  result = a[0].uint32 shl 24
  result += a[1].uint32 shl 16
  result += a[2].uint32 shl 8
  result += a[3].uint32 shl 0

proc parse_uint16(file: File): uint32 =
  var a: seq[uint8] = @[0.uint8, 0.uint8]
  if 2 != file.readBytes(a, 0, 2):
    return
  result = a[0].uint16 shl 8
  result += a[1].uint16 shl 0

proc parse_Tag(file: File): array[4, char] =
  var a: seq[uint8] = @[0.uint8, 0.uint8, 0.uint8, 0.uint8]
  if 4 != file.readBytes(a, 0, 4):
    return
  result[0] = a[0].char
  result[1] = a[1].char
  result[2] = a[2].char
  result[3] = a[3].char

proc getBaseFont*(file: string): string =
  if file.split("/")[^1] in face_names:
    return face_names[file.split("/")[^1]]
  debug(file, "opening font")
  var f = open(file)
  discard parse_uint32(f)
  var ftables = parse_uint16(f)
  discard parse_uint16(f)
  discard parse_uint16(f)
  discard parse_uint16(f)
  var tabs: Table[string, uint32]
  for i in 1..ftables:
    var name = parse_tag(f)
    discard parse_uint32(f)
    var offset = parse_uint32(f)
    discard parse_uint32(f)
    tabs[name.join("")] = offset
  if not("name" in tabs):
    return ""
  f.setFilePos(tabs["name"].int)
  var format = parse_uint16(f)
  var tablen = 0
  var ssoffset = 0
  var names: seq[string] = @[]
  if format == 0:
    tablen = parse_uint16(f).int
    ssoffset = parse_uint16(f).int
  for i in 1..tablen:
    discard parse_uint16(f).int
    discard parse_uint16(f).int
    discard parse_uint16(f).int
    discard parse_uint16(f).int
    var length = parse_uint16(f).int
    var offset = parse_uint16(f).int
    var a: seq[char] = @[]
    for i in 0..length:
      a &= " "
    var pos = f.getFilePos()
    f.setFilePos(tabs["name"].int + ssoffset + offset.int)
    discard f.readChars(a, 0, length)
    names &= a.join("")
    f.setFilePos(pos)
  debug(file, "name is " & names[6])
  face_names[file.split("/")[^1]] = names[6] 
  return names[6]


import sdl2/ttf as ttf
import strutils, segfaults, tables

var faces {.threadvar.}: Table[cint, ttf.FontPtr]


proc get_text_size*(text: cstring, size: float, font_file: string): float =
  if not(ttfWasInit()):
    discard ttfinit()
  var c_intsize: cint = size.toInt.toU32()
  if not(c_intsize in faces):
    faces[c_intsize] = ttf.openFont(font_file, c_intsize)
  result = 0
  var wid: cint
  var w = wid.addr
  var h: ptr cint
  discard faces[c_intsize].sizeText(text, w, h)
  result += wid.toFloat

proc lib_deinit*() =
  for s, font in faces:
    close(font)
  ttfQuit()

func addbs*(text: string): string =
    result = text.replace("\\", "\\\\")
    result = result.replace("(", "\\(")
    result = result.replace(")", "\\)")


func removebs*(text: string): string=
    result = text.replace("\\\\", "\\")
    result = result.replace("\\(", "(")
    result = result.replace("\\)", ")")

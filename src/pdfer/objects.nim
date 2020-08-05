import md5, tables, strutils, strformat, ../terminal

type
  pdf_object* = object of RootObj
    otype*: string
    dict*: Table[string, seq[string]]
    stream*: string
    str*: string

proc ident*(obj: pdf_object): string

proc `$`*(obj: pdf_object): string =
  if obj.dict != initTable[string, seq[string]]():
    result = "<<\n/Type /" & obj.otype & "\n"
    for key, value in obj.dict:
      if len(value) >= 2:
        result &= key & " [" & value.join(" ") & "]" & "\n"
      elif len(value) == 1:
        if key != "/Kids":
          result &= key & " " & value.join(" ") & "\n"
        else:
          result &= key & " [" & value.join(" ") & "]" & "\n"
    result &= ">>\n"
  else:
    result = "<</Length " & $obj.stream.len & ">>\nstream\n" & obj.stream
    if result[^1] != '\n':
      result &= "\n"
    result &= "endstream\n"

proc ident*(obj: pdf_object): string =
  if obj.dict != initTable[string, seq[string]]():
    result = "%%" & $toMD5($obj) & "%%"
  if obj.stream != "":
    result = "%%" & $toMD5($obj) & "%%"
  if obj.str != "":
    result = obj.str

proc append*(obj: var pdf_object, key: string, child: pdf_object) =
  if key in obj.dict:
    obj.dict[key].add(child.ident())
  else:
    obj.dict[key] = @[child.ident()]

proc append_text*(obj: var pdf_object, text: string) =
  obj.stream &= text


proc initCatalogObject*(): pdf_object =
  result.otype = "Catalog"
  result.dict["/Pages"] = newSeq[string]()

proc initOutlinesObject*(): pdf_object =
  result.otype = "Outline"
  result.dict[""] = newSeq[string]()

proc initPagesObject*(): pdf_object =
  result.otype = "Pages"
  result.dict["/Kids"] = newSeq[string]()

proc initPageObject*(): pdf_object =
  result.otype = "Page"
  result.dict["/Contents"] = newSeq[string]()

proc initTextObject*(): pdf_object =
  result.stream = ""

proc initStringObject*(text: string): pdf_object =
  result.str = text

proc initLineObject*(width: float, x, y: array[0..1, float]): pdf_object =
  result.stream = ""
  result.append_text(&"{width} w\n{x[0]} {y[0]} m\n{x[1]} {y[1]} l\nS")

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

#proc parse_uint8(file: File): uint32 =
#  var a: seq[uint8] = @[0.uint8]
#  if 1 != file.readBytes(a, 0, 1):
#    return
#  result = a[0].uint16 shl 0

proc parse_Tag(file: File): array[4, char] =
  var a: seq[uint8] = @[0.uint8, 0.uint8, 0.uint8, 0.uint8]
  if 4 != file.readBytes(a, 0, 4):
    return
  result[0] = a[0].char
  result[1] = a[1].char
  result[2] = a[2].char
  result[3] = a[3].char

proc getBaseFont(file: string): string =
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
  return names[6]

proc initFontFileObject*(file: string): pdf_object =
    result.stream = readFile(file)

proc initFontDescObject*(file: string, bold: bool): pdf_object =
    #/StemV 105 
    #/StemH 45 
    #/CapHeight 660 
    #/XHeight 394 
    #/Ascent 720 
    #/Descent −270 
    #/Leading 83 
    #/MaxWidth 1212 
    #/AvgWidth 478 
    result.otype = "FontDescriptor"
    result.append("/FontName", initStringObject("/HelloWorld"))
    if bold:
      result.append("/FontWeight", initStringObject("400"))
      result.append("/Flags", initStringObject("262178"))
    else:
      result.append("/FontWeight", initStringObject("700"))
    result.append("/FontFile2", initFontFileObject(file))
    result.append("/FontBBox",initStringObject("[ -177 -269 1123 866 ]"))
    result.append("/MissingWidth",initStringObject("255"))
    result.append("/MaxWidth",initStringObject("255"))

proc initFontObject*(name, file: string, bold: bool = false): pdf_object =
    discard """
    <<
    /Type/Font
    /Subtype/TrueType
    /Name/F1
    /BaseFont/BCDEEE+Calibri
    /Encoding/WinAnsiEncoding
    /FontDescriptor 6 0 R
    /FirstChar 0
    /LastChar 10000
    /Widths 18 0 R
    >>
    """
    result.otype = "Font"
    result.append("/Subtype", initStringObject("/TrueType"))
    result.append("/Name", initStringObject(name))
    result.append("/BaseFont", initStringObject("/" & getBaseFont(file)))
    result.append("/Encoding", initStringObject("/WinAnsiEncoding"))
    result.append("/FontDescriptor", initFontDescObject(file, bold))
    
    

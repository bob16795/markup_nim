import md5, tables, strutils, strformat, ../output, nimPNG/nimz
import os
import lib
import streams

type
  pdf_object* = object of RootObj
    otype*: string
    stype*: string
    dict*: Table[string, seq[string]]
    stream*: string
    str*: string

# combine 2 pdf_objects

proc ident*(obj: pdf_object): string

proc zcompress(data: string): string =
  var nz = nzDeflateInit(data)
  result = nz.zlib_compress()

proc `$`*(obj: pdf_object): string =
  if obj.dict != initTable[string, seq[string]]():
    if obj.otype == "":
      result = "<<\n/Subtype /" & obj.stype & "\n"
    else:
      result = "<<\n/Type /" & obj.otype & "\n"
    for key, value in obj.dict:
      if len(value) >= 2 or key == "/Annots":
        result &= key & " [" & value.join(" ") & "]" & "\n"
      elif len(value) == 1:
        if key != "/Kids":
          result &= key & " " & value.join(" ") & "\n"
        else:
          result &= key & " [" & value.join(" ") & "]" & "\n"
    result &= ">>\n"
  else:
    var stream = zcompress(obj.stream)
    result = "<</Length " & $stream.len & "/Filter[/FlateDecode]>>\nstream\n" & stream
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

proc replace*(obj: var pdf_object, key: string, child: pdf_object) =
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
  result.dict["/Annots"] = newSeq[string]()

proc initTextObject*(): pdf_object =
  result.stream = ""

proc initStringObject*(text: string): pdf_object =
  result.str = text

proc initLinkObject*(obj: pdf_object, uri: string): pdf_object =
  var S: Stream
  S.text = obj.stream
  S = S.CleanStream()
  result.stype = "Link"
  result.append("/Rect", initStringObject(
      &"[{S.x} {S.y} {S.width + S.x} {S.y + S.height}]"))
  result.append("/BS", initStringObject("<</W 0>>"))
  result.append("/F", initStringObject("4"))
  result.append("/A", initStringObject(&"<</Type/Action/S/URI/URI({uri}) >>"))
  result.append("/StructParent", initStringObject("0"))

proc initLineObject*(width: float, x, y: array[0..1, float]): pdf_object =
  result.stream = ""
  result.append_text(&"{width} w\n{x[0]} {y[0]} m\n{x[1]} {y[1]} l\nS")

proc initFontFileObject*(file: string): pdf_object =
  result.stream = readFile(file)

proc initFontDescObject*(file: string, bold: int): pdf_object =
  discard """
    /StemV 105 
    /StemH 45 
    /CapHeight 660 
    /XHeight 394 
    /Ascent 720 
    /Descent −270 
    /Leading 83 
    /MaxWidth 1212 
    /AvgWidth 478
    """
  result.otype = "FontDescriptor"
  result.append("/FontName", initStringObject("/HelloWorld"))
  if bold == 0:
    result.append("/FontWeight", initStringObject("400"))
    result.append("/ItalicAngle", initStringObject("0"))
    result.append("/Flags", initStringObject("0"))
  elif bold == 1:
    result.append("/FontWeight", initStringObject("700"))
    result.append("/ItalicAngle", initStringObject("0"))
    result.append("/Flags", initStringObject("262178"))
  else:
    result.append("/FontWeight", initStringObject("400"))
    result.append("/ItalicAngle", initStringObject("-30"))
    result.append("/Flags", initStringObject("0"))
  result.append("/FontFile2", initFontFileObject(file))
  result.append("/FontBBox", initStringObject("[ -177 -269 1123 866 ]"))
  result.append("/MissingWidth", initStringObject("255"))
  result.append("/MaxWidth", initStringObject("255"))

proc initFontObject*(name, file: string, bold: int = 0): pdf_object =
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



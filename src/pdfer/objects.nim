import md5, tables, sequtils, strutils

type
  pdf_object* = object of RootObj
    otype*: string
    dict*: Table[string, seq[string]]
    stream: string
    str*: string

proc ident*(obj: pdf_object): string

proc `$`*(obj: pdf_object): string =
  if obj.dict != initTable[string, seq[string]]():
    result = "<<\n/Type /" & obj.otype & "\n"
    for key, value in obj.dict:
      if len(value) >= 2:
        result = result & key & " [" & value.join(" ") & "]" & "\n"
      elif len(value) == 1:
        if key != "/Kids":
          result = result & key & " " & value.join(" ") & "\n"
        else:
          result = result & key & " [" & value.join(" ") & "]" & "\n"
    result = result & ">>\n"
  else:
    result = "<</Length " & $obj.stream.len & ">>\nstream\n" & obj.stream & "endstream\n"

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
  obj.stream = obj.stream & text


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

proc initFontObject*(name: string): pdf_object =
    discard """
    <<
    /Type/Font
    /Subtype/TrueType
    /Name/F1
    /BaseFont/BCDEEE+Calibri
    /Encoding/WinAnsiEncoding
    /FontDescriptor 6 0 R
    /FirstChar 32
    /LastChar 32
    /Widths 18 0 R
    >>
    """
    result.append("/Subtype", initStringObject("/Type1")) 
    result.append("/Name", initStringObject(name)) 
    result.append("/BaseFont", initStringObject("/Times")) 

import objects, lib
import tables, strformat, strutils
import sequtils
import algorithm
import mathus

type
  pdf_file* = object
    catalog*: pdf_object
    pages*: pdf_object
    page_objs*: seq[pdf_object]
    text_objs*: seq[pdf_object]
    outlines*: pdf_object
    level*: seq[int]
    cpt*, prt*: int
    chapters*, parts*: Table[int, string]
    line_spacing*, column_spacing*: float
    current_column*, columns*: int
    media_box*: array[0..1, int]
    title*, author*, source_file_name*: string
    font_face*, font_face_bold*: string
    font_obj*: pdf_object
    include_title_page*, include_index*, include_toc*: bool
    index*: Table[char, Table[string, seq[int]]]
    toc*: OrderedTable[string, array[0..1, int]]
    header*, footer*: seq[string]
    y*, y_start*: float
  table* = object
    data*: seq[seq[string]]
    heading*: seq[string]
    offset*: array[0..1, float]
    dims*: array[0..1, int]
    width*, height*: float
    ratio*: seq[int]
    font_face*: string

proc add_page*(file: var pdf_file, text: string = "", size: float = -1, odd: int = -1) {.gcsafe.}
proc add_index*(file: var pdf_file, offset: int = 0) {.gcsafe.}
proc get_toc_size*(file: var pdf_file): int {.gcsafe.}
proc add_space*(file: var pdf_file, space: float) {.gcsafe.}
proc make_toc*(file: var pdf_file, offset: int): pdf_file {.gcsafe.}
proc make_title(file: var pdf_file) {.gcsafe.}
proc init_pdf_file*(): pdf_file {.gcsafe.}

proc get_pdf_objs(tab: var table): seq[pdf_object] = 
  var line_y = 0.0
  for row in tab.data:
    var max_row_y = 0.0
    result.add(initLineObject(1, [tab.offset[0]+tab.width, tab.offset[0]], [tab.offset[1]-line_y, tab.offset[1]-line_y]))
    for i, cell in row:
      var cell_width = tab.width / (tab.ratio.foldl(a + b)).toFloat() * tab.ratio[i].toFloat()
      var cell_x: float
      try:
        cell_x = tab.offset[0] + (tab.width / (tab.ratio.foldl(a + b)).toFloat() * (tab.ratio[0..<i].foldl(a + b)).toFloat())
      except:
        cell_x = tab.offset[0]
      var text_obj = initTextObject()
      text_obj.append_text(&"BT\n{12 + 2.4} TL\n/F1 {12} Tf\n{cell_x + 1} {tab.offset[1] + 3.4 - line_y} Td\n")
      var line = ""
      var line_y_temp = 0.0
      var size: float
      var text: string
      for word in cell.split(" "):
        line &= word & " "
        size = lib.get_text_size(line, 12, tab.font_face)
        if size > cell_width - 2:
          line_y_temp += 14.4
          line = line[0..^2]
          text = join(line.split(" ")[0..^2],  " ")
          text_obj.append_text(&"0 0 ({text}) \"\n")
          line = word & " "
      if line != "":
        text = line[0..^2]
        text_obj.append_text(&"0 0 ({text}) \"\n%LOL\n")
        line_y_temp += 12 + 2.4
        text_obj.append_text("ET\n")
        result.add(text_obj)
      if line_y_temp > max_row_y:
        max_row_y = line_y_temp
    var x: float
    for i in 0..<tab.dims[0]:
      try:
        x =  tab.offset[0] + (tab.width / (tab.ratio.foldl(a + b)).toFloat() * (tab.ratio[0..<i].foldl(a + b)).toFloat())
      except:
        x =  tab.offset[0]
      result.add(initLineObject(1, [x+0.5, x+0.5], [tab.offset[1]-line_y, tab.offset[1]-line_y-max_row_y - 1]))
    result.add(initLineObject(1, [tab.offset[0]+tab.width - (0.5), tab.offset[0]+tab.width - (0.5)], [tab.offset[1]-line_y, tab.offset[1]-line_y-max_row_y - 1]))
    line_y += max_row_y + 1
  result.add(initLineObject(1, [tab.offset[0]+tab.width, tab.offset[0]], [tab.offset[1]-line_y, tab.offset[1]-line_y]))
  tab.height = line_y + 12

proc add_table*(file: var pdf_file, tab: var table) =
  discard tab.get_pdf_objs()
  file.y -= tab.height
  if file.y < 100:
      if file.current_column >= file.columns:
          file.current_column = 1
          file.add_page()
      else:
          file.current_column += 1
          file.y = file.y_start
      tab.offset[1] = file.y
  var column_size = ((file.media_box[0]-200) - (file.column_spacing.toInt() * (file.columns - 1))) / file.columns
  var col_x = ((column_size + file.column_spacing).toInt() * (file.current_column - 1)) + 100 
  tab.offset[0] = col_x.toFloat()
  file.y -= tab.height - 12.0
  file.text_objs.add(tab.get_pdf_objs())
  for obj in tab.get_pdf_objs():
    file.page_objs[^1].append("/Contents", obj)

proc append*(tab: var table, row: seq[string]) =
  tab.dims[1] += 1
  tab.data.add(row)

proc tocCmp(x, y: (string, array[0..1, int])): int =
  if x[1][1] < y[1][1]: -1 else: 1

proc add_header_footer(file: var pdf_file, page: int, offset: int) =
  var chapter = ("", 0)
  var part = ("", 0)
  var number = 0
  for page_num, name in file.chapters:
    number += 1
    if page_num + offset - 1 < page:
      chapter[0] = name
      chapter[1] = number
  number = 0
  for page_num, name in file.parts:
    number += 1
    if page_num + offset - 1 < page:
      part[0] = name
      part[1] = number
  var footer = false
  var text: string
  for i in [file.header, file.footer]:
    for align in 0..<3:
      if i[align] != "":
        text = i[align]
        text = text.replace("{page_number}", $(page + 1))
        text = text.replace("{page_total}", $(len(file.page_objs)))
        text = text.replace("{title}", $(file.title))
        text = text.replace("{author}", $(file.author))
        text = text.replace("{part}", $(part[0]))
        text = text.replace("{part_number}", $(part[1]))
        text = text.replace("{chapter}", $(chapter[0]))
        text = text.replace("{chapter_number}", $(chapter[1]))
        var text_size = lib.get_text_size(text, 12, file.font_face).toInt
        var x: int
        case align:
        of 1:
          x = ((file.media_box[0] - text_size) / 2).toInt()
        of 2:
          x = (file.media_box[0] - text_size - 100)
        else:
          x = 100
        var y = file.media_box[1] - 50
        if footer:
          y = 50
        var text_obj = initTextObject()
        text_obj.append_text(&"BT\n/F1 12 Tf\n{x} {y} Td\n0 0 ({text}) \"\nET")
        file.page_objs[page].dict["/Contents"] = concat(@[text_obj.ident()], file.page_objs[page].dict["/Contents"])
        file.text_objs.add(text_obj)
    footer = true

proc set_cols*(file: var pdf_file, cols: int) =
  if cols != file.columns:
    if (file.columns != 1) and (file.current_column != 1):
      file.add_page()
    file.y_start = file.y
    file.columns = cols
    file.current_column = 1

proc next_col*(file: var pdf_file) =
  if file.current_column >= file.columns:
    file.current_column = 1
  else:
    file.current_column += 1
    file.y = file.y_start

proc sequence(file: var pdf_file): seq[pdf_object] =
  result = newSeq[pdf_object]()
  result.add(file.catalog)
  result.add(file.outlines)
  result.add(file.pages)
  for page in file.page_objs:
    result.add(page)
  for text in file.text_objs:
    result.add(text)
  result.add(initFontFileObject(file.font_face))
  result.add(initFontDescObject(file.font_face))
  result.add(file.font_obj)


proc finish*(file: var pdf_file) =
  var text_obj: pdf_object
  var toc_length: int = 0
  var toc_file: pdf_file

  file.font_obj = initFontObject("/F1", file.font_face)
  if file.include_toc:
    toc_length = file.get_toc_size()
    toc_file = file.make_toc(toc_length)
    file.page_objs = concat(toc_file.page_objs, file.page_objs)
    file.text_objs = concat(toc_file.text_objs, file.text_objs)
  for i in 0..<(file.page_objs.len):
    file.add_header_footer(i, toc_length)
  if file.include_title_page:
    file.make_title()
  if file.include_index:
    file.add_index()

  for idx, page in file.page_objs:
    text_obj = initStringObject("[ 0 0 612 792 ]")
    file.page_objs[idx].append("/MediaBox", text_obj)
    text_obj = initStringObject(&"<</Font << /F1 {file.font_obj.ident()} >> >>")
    file.page_objs[idx].append("/Resources", text_obj)
    file.pages.append("/Kids", page)
  text_obj = initStringObject($len(file.page_objs))
  file.pages.append("/Count", text_obj)
  file.catalog.append("/Pages", file.pages)

proc `$`*(file: var pdf_file): string =
  file.finish()
  var objects_ordered = file.sequence()
  result = "%PDF-1.2\n"
  var footer = &"xref\n0 {len(objects_ordered) + 1}\n0000000000 65535 f\n"
  var end_file = &"trailer\n<< /Size {len(objects_ordered) - 1}\n/Root 1 0 R\n>>\nstartxref\n"
  for i, obj in (objects_ordered):
      footer &= &"{len(result):010} 00000 n\n"
      result &= &"{i + 1} 0 obj\n{$obj}endobj\n"
  for i, obj in (objects_ordered):
    result = result.replace(&"{obj.ident()}", &"{i + 1} 0 R")
  end_file &= &"{len(result)}\n%%EOF"
  result &= footer & end_file
  #lib_deinit()

proc add_equation*(file: var pdf_file, text: string) =
  if file.y - (12 + file.line_spacing) < 100:
    if file.current_column >= file.columns:
      file.current_column = 1
      file.add_page()
      file.add_equation(text)
    else:
      file.current_column += 1
      file.y = file.y_start
      file.add_equation(text)
  else:
    var column_size = ((file.media_box[0].toFloat-200.0) - (file.column_spacing * (file.columns.toFloat - 1.0))) / file.columns.toFloat
    var col_x = ((column_size + file.column_spacing) * (file.current_column.toFloat - 1.0)) + 100 
    var equation_obj: equation
    equation_obj.text = text
    file.add_space(15)
    var equation_pdf_obj = equation_obj.get_obj(col_x.toInt(), file.y.toInt(), file.font_face)
    file.add_space(15)
    file.text_objs.add(equation_pdf_obj)
    file.page_objs[^1].append("/Contents", equation_pdf_obj)

proc add_text*(file: var pdf_file, text: string, size: float, align: int = 1) =
  var full: bool = false
  if file.y - (size + file.line_spacing) < 100:
    if file.current_column >= file.columns:
      file.current_column = 1
      file.add_page(text, size)
    else:
      file.current_column += 1
      file.y = file.y_start
      file.add_text(text, size)
  else:
    var overfill = newSeq[string]()
    var text_obj = initTextObject()
    var column_size = ((file.media_box[0].toFloat-200.0) - (file.column_spacing * (file.columns.toFloat - 1.0))) / file.columns.toFloat
    var col_x = ((column_size + file.column_spacing) * (file.current_column.toFloat - 1.0)) + 100 
    text_obj.append_text(&"BT\n{size + file.line_spacing} TL\n/F1 {size} Tf\n{col_x} {file.y} Td\n")
    var bs_text = lib.addbs(text).replace("\n", "\n\t")
    if "\n" in bs_text:
      bs_text = "" & bs_text
    for line in text.split("\n"):
      var pdf_line = newSeq[string]()
      for word in line.split(" "):
        if not full:
          pdf_line.add(word)
          if get_text_size(pdf_line.join(" "), size, file.font_face) >= column_size:
            var word_spacing: float = 1
            if (pdf_line.len - 1) != 0:
              var needs = ( column_size - get_text_size(join(pdf_line[0..^2], " ").strip(), size, file.font_face))
              word_spacing = (needs / (len(pdf_line[0..^3])).toFloat())
            if $word_spacing == "inf" or $word_spacing == "-inf":
              word_spacing = 0
            var char_spacing: float = 0
            if len(pdf_line) < 3:
              char_spacing = (( column_size - get_text_size(pdf_line[0], size, file.font_face)) / (len(pdf_line[0])).toFloat)
            text_obj.append_text(&"{word_spacing} {char_spacing} ({join(pdf_line[0..^2], \" \").addbs()}) \"\n")
            file.y -= size + file.line_spacing
            pdf_line = @[word]
            if file.y - (size + file.line_spacing) < 100:
              full = true
              overfill = pdf_line
        else:
          overfill.add(word)
      if full == false:
        if pdf_line != newSeq[string]():
          case align:
          of 1:
            text_obj.append_text(&"0 0 ({join(pdf_line, \" \").addbs()}) \"\n() '\n")
          of 2:
            var offset = column_size - get_text_size(join(pdf_line, " "), size, file.font_face)
            text_obj.append_text(&"{offset} 0 Td\n0 0 ({join(pdf_line, \" \").addbs()}) \"\n() '\n")
          else:
            var offset = (column_size - get_text_size(join(pdf_line, " "), size, file.font_face))/2
            text_obj.append_text(&"{offset} 0 Td\n0 0 ({join(pdf_line, \" \").addbs()}) \"\n() '\n")
          file.y -= (size + file.line_spacing)
          file.y -= (size + file.line_spacing)
    if len(text.split("\n")) == 1:
      file.y += size + file.line_spacing
    text_obj.append_text("ET\n")
    file.text_objs.add(text_obj)
    file.page_objs[^1].append("/Contents", text_obj)
    if full:
      if file.current_column >= file.columns:
        file.current_column = 1
        file.add_page(join(overfill, " ")[0..^1].removebs(), size)
      else:
        file.current_column += 1
        file.y = file.y_start
        file.add_text(join(overfill, " ")[0..^1].removebs(), size)

proc add_page*(file: var pdf_file, text: string = "", size: float = -1, odd: int = -1) =
  file.y = 692
  file.y_start = 692
  file.current_column = 1
  var page = initPageObject()
  if odd != -1:
    if (len(file.page_objs) mod 2 == 0) == (odd == 0):
      file.page_objs.add(page)
  file.page_objs.add(page)
  if text.strip() != "":
    file.add_text(text, size)

proc add_space*(file: var pdf_file, space: float) =
  file.y -= (space)
  if file.y < 100:
    file.add_page()

proc add_line*(file: var pdf_file, padding_top, padding_bot: float, perc: float = 100) =
  file.add_space(padding_top)
  var obj = initTextObject()
  var size = file.media_box[0].toFloat() - ((file.media_box[0].toFloat()-200) * (perc / 100))
  size = size / 2
  obj.append_text(&"{size} {file.y} m\n{file.media_box[0].toFloat()-size} {file.y} l\nS")
  file.text_objs.add(obj)
  file.page_objs[^1].append("/Contents", obj)
  file.add_space(padding_bot)

proc add_heading*(file: var pdf_file, text: string, level: int) =
  var align = 1
  var col_start = file.columns
  var size = 32
  var number = ""
  var line = false
  var levels: seq[string]
  
  if level > 0:
    file.level[level-1] += 1
    for i in level..<2:
        file.level[i] = 0
    for i in file.level:
      levels.add($i)
    number = join(levels, ".") & " "
    while ".0" in number:
        number = number.replace(".0", "")
    file.toc[number & text] = [level + 1, (len(file.page_objs))]
  else:
    file.set_cols(1)
    number = ""
    file.level = @[0, 0, 0]
    if level == -1:
      file.toc[&"Chapter {file.cpt + 1} - {text}"] = [1, len(file.page_objs)]
      file.cpt += 1
      size = 12
      align = 3
      line = true
      if file.page_objs[^1].dict["/Contents"] != @[]:
        file.add_page(odd = 1)
      file.chapters[len(file.page_objs) - 1] = text
      file.add_space(250)
      file.add_text(&"Chapter {file.cpt}", 32, 3)
    if level == -2:
      file.toc[&"Part {file.prt + 1} - {text}"] = [0, len(file.page_objs)]
      file.cpt = 0
      file.prt += 1
      size = 45
      align = 3
      line = true
      if file.page_objs[^1].dict["/Contents"] != []:
        file.add_page(odd = 1)
      file.parts[len(file.page_objs) - 1] = text
      file.add_space(200)
      file.add_line(0, 0)
      file.add_text(&"Part {file.prt}", size.toFloat(), 3)
  if level == 2:
    size = 24
  if level == 3:
    size = 16
  file.add_text(&"{number}{text}", size.toFloat(), align)
  if line:
    file.add_line(10, 30)
  if level == -2:
    file.add_page()
  file.set_cols(col_start)

proc add_index_entry*(file: var pdf_file, entrys: string) =
  for entry_b in entrys.split(";"):
    var entry = entry_b.strip()
    if not(entry[0] in file.index):
      file.index[entry[0]] = initTable[string, seq[int]]()
    if not(entry in file.index[entry[0]]):
      file.index[entry[0]][entry] = @[]
    if not(len(file.page_objs) in file.index[entry[0]][entry]):
      file.index[entry[0]][entry].add(len(file.page_objs))

proc add_index*(file: var pdf_file, offset: int = 0) =
  file.add_page()
  file.set_cols(1)
  file.add_text("INDEX", 32, 3)
  file.add_line(5, 5)
  file.set_cols(3)
  var column_size = ((file.media_box[0].toFloat-200.0) - (file.column_spacing * (file.columns.toFloat - 1.0))) / file.columns.toFloat 
  for letter, words in file.index:
    file.add_text($letter, 24)
    for word, pages in words:
      var size = get_text_size(word, 12, file.font_face)
      file.add_text(word, 12.0)
      var numbers: string
      for i in pages:
        numbers &= $(i + offset) & ", "
      if (size + get_text_size(numbers[0..^3], 12, file.font_face)) < column_size:
        file.y += 12 + file.line_spacing
      file.add_text(numbers[0..^3], 12.0, align=2)
  file.index = initTable[char, Table[string, seq[int]]]()

proc get_toc_size*(file: var pdf_file): int = 
  var toc_file = file.make_toc(0)
  result = len(toc_file.page_objs)

proc make_toc*(file: var pdf_file, offset: int): pdf_file =
  var toc_file = init_pdf_file()
  toc_file.add_text("Table Of Contents", 32, 3)
  toc_file.add_line(5, 5)
  toc_file.set_cols(2)
  file.toc.sort(tocCmp)
  for heading, idx in file.toc:
      toc_file.add_text(("  ".repeat(idx[0])) & heading, 12)
      toc_file.y += 12 + toc_file.line_spacing
      toc_file.add_text($(idx[1] + offset), 12, align=2)
  return toc_file

proc make_title(file: var pdf_file) =
  var title_file = init_pdf_file()
  title_file.add_line(30, 15)
  title_file.add_text(file.title.toUpperascii(), 48, 3)
  title_file.add_line(30, 10)
  title_file.add_text(file.author, 32, 3)
  file.text_objs = concat(title_file.text_objs, file.text_objs)
  file.page_objs = concat(title_file.page_objs, file.page_objs)


proc init_pdf_file*(): pdf_file =
  result.catalog = initCatalogObject()
  result.pages = initpagesObject()
  result.outlines = initOutlinesObject()
  result.font_obj = initFontObject("/F1", "times.ttf")
  result.level = @[0, 0, 0]
  result.cpt = 0
  result.prt = 0
  result.line_spacing = 2.4
  result.column_spacing = 20
  result.current_column = 1
  result.columns = 1
  result.media_box = [612, 792]
  result.title = ""
  result.author = ""
  result.font_face = "times.ttf"
  result.font_face_bold = "times.ttf"
  result.include_title_page = false
  result.include_index = false
  result.include_toc = false
  result.header = @["{page_number}", "{part}", "{chapter}"]
  result.footer = @["{author}", "", "{title}"]
  result.add_page()

proc initTableObject*(offset_x, offset_y, width: float, y: int, ratio: seq[int]): table =
  result.data = @[]
  result.heading = @[]
  result.offset = [offset_x, offset_y]
  result.dims = [y, 0]
  result.width = width
  result.ratio = ratio[0..^1]

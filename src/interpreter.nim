import tables, strutils, re, strformat
import nodes, output, lexer, parser, nodes
import pdfer/pdfer, os, terminal

type
  int_return* = object
    file*: string
    props*: Table[string, string]
  mac* = object
    name*: string
    tags*: seq[array[0..1, string]]
  context* = object
    macros*: seq[mac]
    counters*: Table[string, int]
    wd*: string
    tab*: table

#proc to_macro(props: var Table[string, string], value: string): string =
#  result = value
#  result = result.replace("\\n", "\n")
#  # if re.match(prop, re"<*:*>"):
#  #   discard

proc initOutput(file: var pdf_file, props: var Table[string, string]): int_return =
  result.file = $file
  result.props = props


proc set_prop(props: var Table[string, string], file: var pdf_file, prop: string, value: string) =
  props[prop] = value
  case prop:
  of "font_face":
    file.font_face = value.strip()
  of "bold_font_face":
    file.font_bold_face = value.strip()
  of "index":
    file.include_index = (value.strip() == "True")
  of "title_page":
    file.include_title_page = (value.strip() == "True")
  of "toc":
    file.include_toc = (value.strip() == "True")
  of "title":
    file.title = value.strip()
  of "author":
    file.author = value.strip()
  of "header":
    file.header = value.strip().split(",")
  of "footer":
    file.footer = value.strip().split(",")
  of "prepend":
    debug(props["file_name"], "prepend set to \"" & value.strip() & "\"")

proc `[]`(ctx: context, value: string): mac =
  for mac in ctx.macros:
    if value == mac.name:
      return mac

proc `in`(value: string, ctx: context): bool =
  for mac in ctx.macros:
    if value == mac.name:
      return true
  return false

proc visit(node: Node, file: var pdf_file, props: var Table[string, string], ctx: var context, text: var string) =
  case node.kind:
  of nkPropDiv:
    discard
  of nkPropSec, nkTextSec, nkList, nkTextLine:
    for i in node.Contains:
      visit(i, file, props, ctx, text)
  of nkPropLine:
    if node.condition == "":
      props.set_prop(file, node.prop.strip(), node.value.strip())
      return
    if not(node.condition.strip() in props):
      initError(node.start_condition, node.start_condition, "Prop allready exists", "'" & node.condition.strip() & "'")
    if node.invert == (props[node.condition.strip()] == "False"):
      props.set_prop(file, node.prop.strip(), node.value.strip())
      return
  of nkTag:
    case node.tag_name:
    of "MAC":
      # <MAC: SET: lol=2;SET: nope=3;COL: 4 ;= STUFF>
      if "=" in node.tag_value:
        var amac: mac
        var name, value, text: string
        text = node.tag_value.split("=")[0..^2].join("=")
        amac.name = node.tag_value.split("=")[^1].strip()
        for tag in text.split(";"):
          name = tag.split(":")[0].strip()
          value = ""
          if ":" in tag:
            value = tag.split(":")[1].strip()
          amac.tags.add([name, value])
        if not(amac.name in ctx):
          ctx.macros.add(amac)
          echo amac
    of "CNT":
      # <CNT: Prop, by: Value>
      var value = node.tag_value.split("=")[0].strip()
      if "=" in node.tag_value:
        var to = node.tag_value.split("=")[1].strip()
        ctx.counters[value] = to.parseInt()
      else:
        ctx.counters[value] = 1
    of "SET":
      # <SET: Prop = Value>
      var value = node.tag_value.split("=")[0].strip()
      if "=" in node.tag_value:
        var to = node.tag_value.split("=")[1].strip()
        if to in props:
          to = props[to]
        props.set_prop(file, value, to)
      else:
        props.set_prop(file, value, "")
    of "CPT":
      # <CPT: Name>
      file.add_heading(node.tag_value, -1)
    of "PRT":
      # <PRT: Name>
      file.add_heading(node.tag_value, -2)
    of "PAG":
      # <PAG>
      file.add_page()
    of "LIN":
      # <PAG>
      try:
        file.add_line(10, 10, node.tag_value.strip().parseFloat())
      except:
        file.add_line(10, 10)
    of "LINEBR":
      # <LINEBR>
      file.add_text("", 12)
    of "COLBR":
      # <COLBR>
      file.next_col()
    of "IDX":
      # <IDX: entry1; entry2 ...>
      file.add_index_entry(node.tag_value)
    of "COL":
      # <COL: columns>
      try:
        file.set_cols(node.tag_value.strip().parseInt())
      except:
        file.set_cols(1)
    else:
      var maca: mac
      try:
        maca = ctx[node.tag_name.strip()]
      except:
        debug(props["file_name"], "weird tag: " & node.tag_name)
      finally:
        if maca.name == node.tag_name.strip():
          for tag in maca.tags:
            var value = tag[1]
            var i = 0
            for arg in node.tag_value.split(","):
              i += 1
              value = value.replace(&"%{i}", arg)
            var new_node = Node(kind: nkTag, tag_name: tag[0], tag_value: value)
            visit(new_node, file, props, ctx, text)
  of nkTable:
    file.add_space(12)
    visit(node.rows[0], file, props, ctx, text)
    for row in node.rows[1..^1]:
      visit(row, file, props, ctx, text)
    file.add_table(ctx.tab)
  of nkTableHeader:
    var col_size = ((file.media_box[0]-200).toFloat() - (file.column_spacing * (file.columns - 1).toFloat())) / file.columns.toFloat()
    var col_x = ((col_size + file.column_spacing) * (file.current_column - 1).toFloat()) + 100.0
    ctx.tab = initTableObject(col_x, file.y, col_size, len(node.header_columns), node.ratio)
  of nkTableRow:
    ctx.tab.append(node.row_columns)
  of nkTextComment:
    if node.text.split(":")[0] == "Inc":
      var slave_start = props["slave"]
      props["slave"] = "True"
      var pattern = node.text[4..^1].strip()
      var path = ctx.wd
      if pattern[0] == '/':
        path = "/" & join(pattern.split("/")[0..^2], "/")
      else:
        path = ctx.wd & "/" & join(pattern.split("/")[0..^2], "/")
      pattern = pattern.split("/")[^1]
      var add = false
      for file_full in walkDir(path, false):
        var file_name = file_full[1].split("/")[^1]
        if match(file_name, re(pattern)):
          add = true
          log(props["file_name"], "include " & file_name)
          var lexer_obj = initLexer(readFile(file_full[1]), file_full[1])
          var toks = runLexer(lexer_obj)
          var parser_obj = initParser(toks, -1)
          var ast = parser_obj.runParser()
          for new_node in ast.Contains:
            var wd = ctx.wd
            ctx.wd = path
            visit(new_node, file, props, ctx, text)
            ctx.wd = wd
      props["slave"] = slave_start
      if add == false:
        log(props["file_name"], "warn: `" & node.text & "` ignored")
  of nkEquation:
    file.add_equation(node.text)
    text = ""
  of nkTextParEnd:
    if text != "\b" and text != "":
      text = "[]prepend[]" & text
      for key, value in props:
        text = text.replace("[]" & key & "[]", value)
      for key, value in props:
        text = text.replace("()" & key & "()", value)
      for counter, by in ctx.counters:
        try:
          props[counter] = $(props[counter].parseInt() + by)
        except:
          props[counter] = "0"
      file.add_text(text, 12)
      text = ""
  of nkTextBold:
    if text != "\b":
      var line = node.text
      text = text & " \\b" & line
  of nkAlphaNumSym:
    if text != "\b":
      var line = node.text
      text = text & " \\n" & line
  of nkHeading1:
    file.add_heading(node.text, 1)
  of nkHeading2:
    file.add_heading(node.text, 2)
  of nkHeading3:
    file.add_heading(node.text, 3)
  of nkListLevel1:
    file.add_text("- " & node.text, 12)
  of nkListLevel2:
    file.add_text("  - " & node.text, 12)
  of nkListLevel3:
    file.add_text("    - " & node.text, 12)
  else:
    initError(node.start_pos, node.end_pos, "Not Implemented", "'visit" & $node.kind & "'")

proc visitBody*(node: Node, file_name: string, wd: string, prop_pre: Table[string, string]): int_return =
  var file: pdf_file
  var props: Table[string, string]
  var text: string
  props["output"] = ""
  props["font_face"] = ""
  props["bold_font_face"] = ""
  props["use"] = ""
  props["file_name"] = file_name
  props["ignore"] = "False"
  props["slave"] = "False"
  props["prepend"] = ""
  file = init_pdf_file()
  for k, v in prop_pre:
    props[k] = v
  text = ""
  for node in node.Contains:
    var ctx: context
    ctx.wd = wd
    visit(node, file, props, ctx, text)
  for prop, value in prop_pre:
    props.set_prop(file, prop, value)
  return initOutput(file, props)

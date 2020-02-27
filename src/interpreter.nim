import lists, tables, strutils, re, strformat
import nodes, output, lexer, parser, nodes
import pdfer/pdfer, os

type
  int_return* = object
    file*: string
    props*: Table[string, string]
  mac = object
    name: string
    tags: seq[array[0..1, string]]
  context = object
    macros: seq[mac]
    counters: Table[string, int]
    wd: string

var file: pdf_file
var props: Table[string, string]
var text: string
var visits = 0

proc to_macro(props: var Table[string, string], prop: string): string =
  result = prop
  result = result.replace("\\n", "\n")
  if re.match(prop, re"<*:*>"):
    discard

proc initOutput(file: var pdf_file, props: var Table[string, string]): int_return =
  result.file = $file
  result.props = props


proc set_prop(props: var Table[string, string], file: var pdf_file, prop: string, value: string) =
  props[prop] = value
  case prop:
  of "font_face":
    file.font_face = value.strip()
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
  # of "prepend":
  #   echo value.strip()

proc `in`(value: string, ctx: context): bool =
  for mac in ctx.macros:
    if value == mac.name:
      return true
  return false

proc visit(node: Node, file: var pdf_file, props: var Table[string, string], ctx: var context) =
  visits += 1
  case node.kind:
  of nkPropDiv:
    discard
  of nkPropSec, nkTextSec, nkList:
    for i in node.Contains:
      visit(i, file, props, ctx)
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
    of "CNT":
      # <CNT: Prop, by: Value>
      var value = node.tag_value.split("=")[0].strip
      if "=" in node.tag_value:
        var to = node.tag_value.split("=")[1].strip()
        for key, value in props:
          to = to.replace(key, value)
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
          return
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
      # <PAG>
      file.add_text("", 12)
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
      var ran = false
      for maca in ctx.macros:
        if maca.name == node.tag_name:
          ran = true
          for tag in maca.tags:
            var value = tag[1]
            var i = 0
            for arg in node.tag_value.split(","):
              i += 1
              value = value.replace(&"%{i}", arg)
              var new_node = Node(kind: nkTag, tag_name: tag[0], tag_value: value)
              visit(new_node, file, props, ctx)
      if not(ran):
        echo "weird tag: ", node.tag_name
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
      echo "pattern: ", pattern
      var add = false
      echo "PATH: ", path
      for file_full in walkDir(path, false):
        var file_name = file_full[1].split("/")[^1]
        if match(file_name, re(pattern)):
          add = true
          echo "include: " & file_name & ", " & node.text[4..len(node.text)-1].strip()
          var lexer_obj = initLexer(readFile(file_full[1]), file_full[1])
          var toks = runLexer(lexer_obj)
          var parser_obj = initParser(toks, -1)
          var ast = parser_obj.runParser()
          for new_node in ast.Contains:
            var wd = ctx.wd
            ctx.wd = path
            visit(new_node, file, props, ctx)
            ctx.wd = wd
      props["slave"] = slave_start
      if add == false:
        echo "warn: Inc followed no files"
  of nkEquation:
    file.add_equation(node.text)
    text = ""
  of nkTextParEnd:
    if text != "\b" and text != "":
      text = "[]prepend[]" & text
      for key, value in props:
        text = text.replace("[]" & key & "[]", props.toMacro(value))
      for key, value in props:
        text = text.replace("()" & key & "()", value)
      for counter, by in ctx.counters:
        # echo counter, ": ", by, " = ", props[counter]
        if counter in props:
          try:
            props[counter] = $(props[counter].parseInt() + by)
          except:
            props[counter] = "0"
        else:
          props[counter] = "0"
      file.add_text(text, 12)
      text = ""
  of nkTextLine:
    if text != "\b":
      var line = node.text
      text = text & " " & line
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
  props["output"] = ""
  props["font_face"] = ""
  props["use"] = ""
  props["file_name"] = file_name
  props["ignore"] = "False"
  props["slave"] = "False"
  props["prepend"] = ""
  file = init_pdf_file()
  text = ""
  for node in node.Contains:
    var ctx: context
    ctx.wd = wd
    visit(node, file, props, ctx)
  for prop, value in prop_pre:
    props.set_prop(file, prop, value)
  return initOutput(file, props)

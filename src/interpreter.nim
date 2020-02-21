import lists, tables, strutils, re
import nodes, output, lexer, parser, nodes
import pdfer.pdfer, os

type
  int_return* = object
    file*: string
    props*: Table[string, string]

var file: pdf_file
var props: Table[string, string]
var text: string
var visits = 0

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

proc visit(node: Node, file: var pdf_file, props: var Table[string, string], wd: string) =
  visits += 1
  case node.kind:
  of nkPropDiv:
    discard
  of nkPropSec, nkTextSec, nkList:
    for i in node.Contains:
      visit(i, file=file, props = props, wd = wd)
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
    of "SET":
      # <SET: Prop = Value>
      var value = node.tag_value.split("=")[0].strip()
      var to = node.tag_value.split("=")[1].strip()
      props[value] = to
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
      file.add_line(38, 30)
    of "IDX":
      # <IDX: entry1; entry2 ...>
      file.add_index_entry(node.tag_value)
    of "COL":
      # <COL: columns>
      file.set_cols(node.tag_value.strip().parseInt())
    else:
      echo "weird tag: ", node.tag_name
  of nkTextComment:
    if node.text.split(":")[0] == "Inc":
      var slave_start = props["slave"]
      props["slave"] = "True"
      var pattern = node.text[4..^1].strip()
      var path = wd
      if pattern[0] == '/':
        path = "/" & join(pattern.split("/")[0..^2], "/")
      else:
        path = wd & "/" & join(pattern.split("/")[0..^2], "/")
      pattern = pattern.split("/")[^1]
      var add = false
      for file_full in walkDirRec(path):
        var file_name = file_full.split("/")[^1]
        if match(file_name, re(pattern)):
          try:
            add = true
            echo "include: " & file_name & ", " & node.text[4..len(node.text)-1].strip()
            var lexer_obj = initLexer(readFile(file_full), file_full)
            var toks = runLexer(lexer_obj)
            var parser_obj = initParser(toks, -1)
            var ast = parser_obj.runParser()
            for new_node in ast.Contains:
              visit(new_node, file, props, file_full.splitFile().dir)
          except:
            echo "lol"
      props["slave"] = slave_start
      if add == false:
        echo "warn"
  of nkEquation:
    file.add_equation(node.text)
    text = ""
  of nkTextParEnd:
    if text != "\b" and text != "":
      file.add_text(text, 12)
      text = ""
  of nkTextLine:
    if text != "\b":
      var line = node.text
      for key, value in props:
        line = line.replace("()" & key & "()", value)
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
  file = init_pdf_file()
  text = ""
  for node in node.Contains:
    visit(node, file, props, wd)
    for prop, value in prop_pre:
      props.set_prop(file, prop, value)
  return initOutput(file, props)

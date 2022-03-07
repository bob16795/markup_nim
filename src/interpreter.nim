import tables, strutils, re, tempfile
import nodes, output, lexer, parser, nodes
import pdfer/pdfer, os, terminal, osproc
import plugins/plugprop
import strformat

type
  int_return* = object
    file*: string
    props*: Table[string, string]
  context* = object
    nonl*: bool
    ignore*: int
    counters*: Table[string, int]
    wd*: string
    tab*: table
    align*: int
    ident*: int
    just*: bool
    size*: int

proc initOutput(file: var pdf_file, props: var Table[string,
    string]): int_return =
  # inits an output variable
  result.file = $file
  result.props = props


proc set_prop(props: var Table[string, string], file: var pdf_file,
    prop: string, value: string, ctx: var context) =
  if value == "":
    return
  if value[0] == '+':
    ctx.counters[prop] = value[1..^1].split(".")[0].parseInt()
    return
  if value[0] == '-':
    ctx.counters[prop] = value[1..^1].split(".")[0].parseInt()
    return
  props[prop] = value
  case prop:
  of "font_face":
    file.font_face = value.strip()
  of "date":
    file.date = value.strip()
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
    debug(props["file_name"], &"prepend set to '{value.strip()}'")
  of "LineSpacing":
    file.line_spacing = value.parseFloat()
  of "geometry":
    file.set_page_size(value.strip())

proc repl_props(S: string, props: Table[string, string]): string =
  result = S
  for p, q in props:
    result = result.replace(&"(){p}()", q)
  result = result.replace(re"\(\)[^\(\)]*\(\)")

proc repl_props_bracket(S: string, props: Table[string, string],
    file: pdf_file): string =
  result = S
  for p, q in props:
    result = result.replace(&"[]{p}[]", q)
  result = result.replace("[]Y[]", $file.y)
  result = result.replace(re"\[\][^\(\)]*\[\]")

proc visit(node: Node, file: var pdf_file, props: var Table[string, string],
    ctx: var context, text: var string) {.gcsafe.}

proc visit_tag(node: Node, file: var pdf_file, props: var Table[string, string],
    ctx: var context, text: var string) {.gcsafe.} =
  if node.tag_name == "ENDIF":
    if ctx.ignore > 0:
      ctx.ignore -= 1
    return
  if ctx.ignore != 0:
    return
  var value = node.tag_value.repl_props(props).strip()
  case node.tag_name:
  of "YESNL":
    ctx.nonl = false
  of "NONL":
    ctx.nonl = true
  of "SIZE":
    ctx.size = value.strip().parseInt()
  of "RAW":
    # <RAW: text>
    # adds text to line
    value = value.repl_props_bracket(props, file)
    text &= value
  of "LOG":
    log(props["file_name"], value, level = 1)
  of "WRN", "WARN":
    log(props["file_name"], value, fgYellow, level = 1)
  of "ERR", "ERROR":
    log(props["file_name"], value, fgRed, level = 1)
    quit(1)
  of "PRS":
    # <PRS: text>
    # parses text
    value = value.repl_props_bracket(props, file)
    var lexer_obj = initLexer(value & "\n", props["file_name"] & " - PRS tag")
    var toks = runLexer(lexer_obj)
    var parser_obj = initParser(toks, -1)
    var ast = parser_obj.runParser()
    for new_node in ast.Contains:
      visit(new_node, file, props, ctx, text)
  of "PLG":
    # <PLG: text>
    # parses a plugin
    log(props["file_name"], &"Include '{value}'")
    var text = plugCompile(value, ctx.wd)
    var lexer_obj = initLexer(text & "\n", props["file_name"] & " - PLG tag")
    var toks = runLexer(lexer_obj)
    var parser_obj = initParser(toks, -1)
    var ast = parser_obj.runParser()
    for new_node in ast.Contains:
      visit(new_node, file, props, ctx, text)
  of "PRP":
    # <PRP: text>
    # parses text as prop section
    value = value.repl_props_bracket(props, file)
    var lexer_obj = initLexer(&"---\n{value}\n---", props["file_name"] & " - PRP tag")
    var toks = runLexer(lexer_obj)
    var parser_obj = initParser(toks, -1)
    var ast = parser_obj.runParser()
    for new_node in ast.Contains:
      visit(new_node, file, props, ctx, text)
  of "CPT":
    # <CPT: Name>
    # adds a chapter heading
    file.add_heading(value, -1)
  of "LNK":
    # <LNK: URL; TEXT?>
    # adds a link
    if ";" in value:
      file.add_text(value.split(";")[1], ctx.size.toFloat(), link = value.split(
          ";")[0], align = ctx.align)
    else:
      file.add_text(value, ctx.size.toFloat(), link = value, align = ctx.align)
  of "PRT":
    # <PRT: Name>
    # adds a part heading
    file.add_heading(value, -2)
  of "CENTER":
    # <CENTER>
    # Centers text
    ctx.align = 3
  of "LEFT":
    # <LEFT>
    # aligns text to the left
    ctx.align = 1
  of "INDENT":
    # <NINDENT>
    # default indent mode
    ctx.ident = 0
  of "JUST":
    # <NINDENT>
    # default indent mode
    ctx.just = true
  of "UNJUST":
    # <NINDENT>
    # default indent mode
    ctx.just = false
  of "NINDENT":
    # <NINDENT>
    # disable indent mode
    ctx.ident = 1
  of "HANGING":
    # <HANGING>
    # hanging indent mode
    ctx.ident = 2
  of "RIGHT":
    # <RIGHT>
    # aligns text to the right
    ctx.align = 2
  of "PAG":
    # <PAG>
    # adds a new page
    file.add_page()
  of "PAGW":
    # <PAGW: num>
    # sets page width
    file.media_box[0] = value.strip().parseInt()
  of "PAGH":
    # <PAGH: num>
    # sets page height
    file.media_box[1] = value.strip().parseInt()
  of "LIN", "LINE":
    # <LIN: num> | <LIN: num, num, num, num>
    # adds a line
    var args = value.strip().split(",")
    if args.len == 1:
      try:
        file.add_vrule(10, 10, args[0].strip().parseFloat())
      except:
        file.add_vrule(10, 10)
    elif args.len == 4:
      try:
        file.add_line(args[0].strip().parseFloat(), args[1].strip().parseFloat(
          ), args[2].strip().parseFloat(), args[3].strip().parseFloat())
      except:
        discard
    else:
      debug(props["file_name"], &"weird line: {node.tag_name}")
  of "VBRK":
    # <VBRK: num>
    # same as <LIN: num>
    try:
      file.add_vrule(10, 10, value.strip().parseFloat())
    except:
      file.add_vrule(10, 10)
  of "LINEBR":
    # <LINEBR>
    # adds a new line
    file.add_text("", ctx.size.toFloat(), align = ctx.align, ident = ctx.ident,
        just = ctx.just)
  of "COLBR":
    # <COLBR>
    # starts a new column
    file.next_col()
  of "IDX":
    # <IDX: entry1; entry2 ...>
    # adds an index entry
    if value != "":
      file.add_index_entry(value)
  of "SPC":
    # <SPC: size>
    # adds emptyness with a height of size pt
    if value != "":
      file.add_space(value.strip().parseFloat())
  of "IF":
    # <IF: ()VAR()>
    # if statement idk how to explain lol
    if value == "False":
      ctx.ignore += 1
  of "COL":
    # <COL: columns>
    # set the number of columns
    try:
      file.set_cols(value.strip().parseInt())
    except:
      file.set_cols(1)
  else:
    var args = value.split(",")
    var p: Table[string, string]
    if args != @[""]:
      for arg in 0..<args.len:
        p[$arg] = args[arg].strip()
    value = props[node.tag_name]
    value = value.repl_props(p)
    var lexer_obj = initLexer(value & "\n", props["file_name"] & " - PRS tag")
    var toks = runLexer(lexer_obj)
    var parser_obj = initParser(toks, -1)
    var ast = parser_obj.runParser()
    for new_node in ast.Contains:
      visit(new_node, file, props, ctx, text)

proc visit(node: Node, file: var pdf_file, props: var Table[string, string],
    ctx: var context, text: var string) {.gcsafe.} =
  props.set_prop(file, "Y", $file.y, ctx)
  if node.kind == nkTag:
    visit_tag(node, file, props, ctx, text)
    return
  if ctx.ignore != 0:
    return
  case node.kind:
  of nkPropDiv:
    discard
  of nkPropSec, nkTextSec, nkList, nkTextLine:
    for i in node.Contains:
      visit(i, file, props, ctx, text)
  of nkPropLine:
    if node.condition == "":
      props.set_prop(file, node.prop.strip(), node.value.strip(), ctx)
      return
    if not(node.condition.strip() in props):
      initError(node.start_condition, node.start_condition,
          "Prop allready exists", &"'{node.condition}'")
    if node.invert == (props[node.condition.strip()] == "False"):
      props.set_prop(file, node.prop.strip(), node.value.strip(), ctx)
      return
  of nkTable:
    file.add_space(12)
    visit(node.rows[0], file, props, ctx, text)
    for row in node.rows[1..^1]:
      visit(row, file, props, ctx, text)
    file.add_table(ctx.tab)
  of nkTableHeader:
    var col_size = ((file.media_box[0]-200).toFloat() - (file.column_spacing * (
        file.columns - 1).toFloat())) / file.columns.toFloat()
    var col_x = ((col_size + file.column_spacing) * (file.current_column -
        1).toFloat()) + 100.0
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
          log(props["file_name"], "Include " & file_name)
          var old_name = props["file_name"]
          props["file_name"] = props["file_name"] & "<-" & file_name
          var lexer_obj = initLexer(readFile(file_full[1]), file_full[1])
          var toks = runLexer(lexer_obj)
          var parser_obj = initParser(toks, -1)
          var ast = parser_obj.runParser()
          for new_node in ast.Contains:
            var wd = ctx.wd
            ctx.wd = path
            visit(new_node, file, props, ctx, text)
            ctx.wd = wd
          props["file_name"] = old_name
      props["slave"] = slave_start
      if add == false:
        log(props["file_name"], &"warn: '{node.text}' ignored")
  of nkEquation:
    file.add_equation(node.text)
    text = ""
  of nkTextParEnd:
    if not ctx.nonl:
      if text != "\b" and text != "":
        if "prepend" in props:
          text = props["prepend"].replace("||", "()").repl_props(props) & text
        for counter, by in ctx.counters:
          try:
            props[counter] = $(props[counter].parseInt() + by)
          except:
            props[counter] = "0"
        file.add_text(text, ctx.size.toFloat(), align = ctx.align,
            ident = ctx.ident, just = ctx.just)
        text = ""
  of nkTextBold:
    if text != "\b":
      var line = node.text
      text = text & " \\b " & line
  of nkTextEmph:
    if text != "\b":
      var line = node.text
      text = text & " \\e " & line
  of nkAlphaNumSym:
    if text != "\b":
      var line = node.text
      text = text & " \\n " & line
  of nkHeading1:
    file.add_heading(node.text, 1)
  of nkHeading2:
    file.add_heading(node.text, 2)
  of nkHeading3:
    file.add_heading(node.text, 3)
  of nkListLevel1:
    file.add_text("- " & node.text, 12)
  of nkListLevel2:
    file.add_text("    - " & node.text, 12)
  of nkListLevel3:
    file.add_text("        - " & node.text, 12)
  of nkCodeBlock:
    if not ctx.nonl:
      if text != "\b" and text != "":
        if "prepend" in props:
          text = props["prepend"].replace("[]", "()").repl_props(props) & text
        for counter, by in ctx.counters:
          try:
            props[counter] = $(props[counter].parseInt() + by)
          except:
            props[counter] = "0"
        file.add_text(text, ctx.size.toFloat(), align = ctx.align,
            ident = ctx.ident, just = ctx.just)
        text = ""
    else:
      text &= " "
    if match(node.lang.strip(), re"^{.*}$"):
      var (lol, tmpname) = mkstemp()
      lol.close()
      var tmpfile = tmpname.open(fmWrite)
      tmpfile.write(node.code.repl_props_bracket(props, file))
      tmpfile.close()
      let (outp, errc) = execCmdEx(node.lang.strip().strip(true, true, {'{',
          '}'}) & " " & tmpname)
      discard execCmdEx("rm " & tmpname)
      if errc != 0:
        log("Error while running code:\n" & "{outp}", props["file_name"])
        return
      var lexer_obj = initLexer(outp & "\n", props["file_name"] & " - code block")
      var toks = runLexer(lexer_obj)
      var parser_obj = initParser(toks, -1)
      var ast = parser_obj.runParser()
      for new_node in ast.Contains:
        visit(new_node, file, props, ctx, text)
    else:
      for s in node.code.strip.split("\n"):
        file.add_text("> " & s, 12, bg = color(r: 0.7, g: 0.7, b: 0.7))
  else:
    initError(node.start_pos, node.end_pos, "Not Implemented", &"'visit - {node.kind}'")

proc visitBody*(node: Node, file_name: string, wd: string, prop_pre: Table[
    string, string]): int_return =
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
  var ctx: context
  ctx.align = 1
  ctx.ident = 0
  ctx.just = true
  ctx.size = 12
  for node in node.Contains:
    ctx.wd = wd
    visit(node, file, props, ctx, text)
  for prop, value in prop_pre:
    props.set_prop(file, prop, value, ctx)
  return initOutput(file, props)

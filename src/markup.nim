import parseopt, tables, os, re
import strutils, output
import lexer, parser, nodes, tokenclass
import interpreter, threadpool, terminal

var p = initOptParser()

var files: seq[string]

var wrote: int

proc thread_check(text, cwd: string, tree: int, prop: Table[string, string]) {.gcsafe.}

proc compile(file: string, prop: Table[string, string], wd: string, tree: int) =
  # compiles a file and sub files
  # args
  # file: the file to compile
  # prop: props to start with
  # wd: working directory
  # tree: what to show
  #   0: default compiles document and returns pdf
  #   1: prints ast
  #   2: prints tokens
  #   3: compile no include
  log(file.split("/")[^1], "compiling")
  var cwd = wd
  var file_new = file
  if file == "":
    return
  if file[0] == '/':
    cwd = file.split("/")[0..^2].join("/")
    file_new = file.split("/")[^1]
  var lexer_obj = initLexer(readFile(cwd & "/" & file_new), file_new)
  var toks = runLexer(lexer_obj)
  var parser_obj = initParser(toks, -1)
  var ast = parser_obj.runParser()
  case tree:
  of 0:
    var output = visitBody(ast, file_new, cwd, prop)
    var use = output.props["use"]
    var output_file = output.props["output"]
    var ignore = output.props["ignore"]
    if ignore != "True":
      output(output.file, output_file, cwd)
      wrote += 1
    if use != "":
      if ";" in use:
        for text in use.split(";"):
          spawnX thread_check(text, cwd, tree, prop)
      else:
        thread_check(use, cwd, tree, prop)
  of 1:
    output($ast, "", cwd)
  of 2:
    output($toks, "", cwd)
  of 3:
    var output = visitBody(ast, file_new, cwd, prop)
    var output_file = output.props["output"]
    var ignore = output.props["ignore"]
    if ignore != "True":
      output(output.file, output_file, cwd)
      wrote += 1
  else:
    debug(file, "idk how your here")

proc thread_check(text, cwd: string, tree: int, prop: Table[string, string]) {.gcsafe.} =
  # check for included files
  # args
  # text: the pattern to match
  # cwd: the working directory
  # tree: same as compile()
  # prop: the props to prepend
  var pattern = text.strip()
  var path = cwd
  if pattern[0] == '/':
    path = "/" & join(pattern.split("/")[0..^2], "/")
  else:
    path = cwd & "/" & join(pattern.split("/")[0..^2], "/")
  pattern = pattern.split("/")[^1]
  var file_list: seq[string] = @[]
  for file_full in walkDirRec(path):
    var file_name = file_full.split("/")[^1]
    if match(file_name, re(pattern)):
      file_list &= file_full
  if file_list.len == 1:
    compile(file_list[0], prop, path, tree)
  else:
    for file_name in file_list:
      spawnX compile(file_name, prop, path, tree)

proc main() =
  # main function, starts the compiler
  var prev = "" # the previous argument
  var tree = 0
  var prop = initTable[string, string]()
  for kind, key, val in p.getopt():
    case kind:
    of cmdEnd: doAssert(false)
    of cmdShortOption, cmdLongOption:
      # switches without arguments
      case key:
      of "I", "no-use":
        tree = 3
      of "t", "tree":
        tree = 1
      of "k", "token-tree":
        tree = 2
      else:
        prev = key
    of cmdArgument:
      if prev == "":
        files.add(key)
      else:
        # switches with arguments
        case prev:
        of "c", "cap":
          try:
            if key.parseInt() <= 256:
              setMaxPoolSize(key.parseInt())
            else:
              badArgError("Range for cap is 0-255")
          except:
            badArgError("Cap must be a number")
        of "p", "prop":
          for value in key.split(","):
            if value.split(":").len() == 2:
              var set = value.split(":")[0].strip()
              var to = value.split(":")[1].strip()
              prop[set] = to
            else:
              badArgError("Format for prop is `Prop:Value`")
        of "h", "help":
          help(2)
        prev = ""
  if prev != "":
    case prev:
    of "p", "prop", "c", "cap":
      badArgError(prev & " switch requires arg")
    of "h", "help":
      help(2)
  if files.len < 1:
    help(1)
  if files.len < 2:
    compile(files[0], prop, getCurrentDir(), tree)
  wrote = 0
  for file in files:
    spawnX compile(file, prop, getCurrentDir(), tree)
  sync()
  log("", "DONE\n\nwrote " & $wrote & " files", fgGreen)

main()

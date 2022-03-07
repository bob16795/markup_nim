import parseopt, tables, os, re
import strutils, output
import lexer, parser, nodes, tokenclass
import interpreter, threadpool, terminal
import strformat
import plugins/plugprop

var
  p = initOptParser()
  files: seq[string]
  wrote: int
  plugin: bool

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
  log(file.split("/")[^1], "Compiling")
  if plugin:
    output(plugCompile(file, wd), "stdout", wd)
    return
  var cwd = wd
  var file_new = file
  if file == "":
    return
  if file[0] == '/':
    cwd = file.split("/")[0..^2].join("/")
    file_new = file.split("/")[^1]
  var lexer_obj = initLexer(readFile(cwd & "/" & file_new), file_new)
  var toks = lexer_obj.runLexer()
  var parser_obj = initParser(toks, -1)
  var ast = parser_obj.runParser()
  var props = prop
  case tree:
  of 0:
    if fileExists(getConfigDir() & "/markup/lib.mup"):
      var plug = plugCompile(getConfigDir() & "/markup/lib.mup", wd)
      var pluglexer = initLexer(plug, "lib.mup")
      var plugtoks = pluglexer.runLexer()
      var plugparser = initParser(plugtoks, -1)
      var plugast = plugparser.runParser()
      var plugoutput = visitBody(plugast, "lib.mup", cwd, props)
      props = plugoutput.props
    var output = visitBody(ast, file_new, cwd, props)
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
    output($ast, "stdout", cwd)
  of 2:
    output($toks, "stdout", cwd)
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
  # decides what the user wants to do
  var prev = "" # the previous argument
  var tree = 0
  var prop = initTable[string, string]()
  var std = false
  for kind, key, val in p.getopt():
    case kind:
    of cmdEnd: doAssert(false)
    of cmdShortOption, cmdLongOption:
      # switches without arguments
      case key:
      of "I", "no-use":
        tree = 3
      of "P", "plugin":
        plugin = true
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
        of "v":
          try:
            if key.parseInt() >= 0:
              verbose = key.parseInt()
            else:
              badArgError("Cant have negative verbosity")
          except:
            badArgError("verbosity must be a number")
        of "c", "cap":
          try:
            if key.parseInt() <= 256 and key.parseInt() >= 1:
              setMaxPoolSize(key.parseInt())
              setMinPoolSize(key.parseInt())
            else:
              badArgError("Range for cap is 1-255")
          except:
            badArgError("Cap must be a number")
        of "p", "prop":
          for value in key.split(","):
            if value.split(":").len() == 2:
              var set = value.split(":")[0].strip()
              var to = value.split(":")[1].strip()
              prop[set] = to
            else:
              badArgError("Format for prop is 'Prop:Value'")
        of "h", "help":
          help(2)
        else:
          InvalidArgError(&"Invalid Option: '-{prev}'")
        prev = ""
  if prev != "":
    case prev:
    of "p", "prop", "c", "cap":
      badArgError(&"The '-{prev}' switch requires argument")
    of "h", "help":
      help(2)
    else:
      InvalidArgError(&"Invalid Option: '-{prev}'")
  if files.len < 1:
    badArgError("You must include at least 1 file")
  elif files.len < 2:
    if not fileExists(files[0]):
      badArgError(&"file {files[0]} does not exist")
    compile(files[0], prop, getCurrentDir(), tree)
  else:
    wrote = 0
    for file in files:
      if not fileExists(file):
        badArgError(&"file {file} does not exist")
      spawnX compile(file, prop, getCurrentDir(), tree)
  sync()
  log("", &"DONE\n\nWrote {wrote} files", fgGreen)

main()

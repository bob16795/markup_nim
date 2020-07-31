import parseopt, tables, os, re
import strutils
import lexer, parser, nodes, tokenclass
import interpreter, threadpool, terminal
{.experimental: "parallel".}

var p = initOptParser()

var files: seq[string]

var wrote: int

proc thread_check(text, cwd: string, tree: int, prop: Table[string, string])  {.gcsafe.} 

proc compile(file: string, prop: Table[string, string], wd: string, tree: int) = 
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
      parallel:
        for text in use.split(";"):
          spawn thread_check(text, cwd, tree, prop)
  of 1:
    output($ast, "", cwd)
  of 2:
    output($toks, "", cwd)
  else:
    debug(file, "idk how your here")

proc thread_check(text, cwd: string, tree: int, prop: Table[string, string]) {.gcsafe.} =
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
  parallel:
    for file_name in file_list:
      spawn compile(file_name, prop, path, tree)

proc main() =
  var tree = 0
  var prev = ""
  var prop = initTable[string, string]()
  for kind, key, val in p.getopt():
    case kind:
    of cmdEnd: doAssert(false)
    of cmdShortOption, cmdLongOption:
      case key:
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
        case prev:
        of "p", "prop":
          for value in key.split(","):
            if value.split(":").len() == 2:
              var set = value.split(":")[0].strip()
              var to  = value.split(":")[1].strip()
              prop[set] = to
            else:
              log("root", "invalid argument " & key & value)
        of "h", "help":
          help(2)
        prev = ""
  if prev != "":
    case prev:
    of "p", "prop":
      log("root", "invalid argument " & prev)
    of "h", "help":
      help(2)
  if files.len < 1:
    help(1)
  wrote = 0
  parallel:
    for file in files:
      spawn compile(file, prop, getCurrentDir(), tree)
  log("root", "DONE\n\nwrote " & $wrote & " files")
main()

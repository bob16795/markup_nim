import parseopt, lists, tables, os, re
import strformat, strutils
import lexer, parser, nodes, tokenclass
import interpreter

var p = initOptParser()

var files: seq[string]

proc help(msg: int, app_name: string = "markup") =
  echo &"Usage: {app_name} [OPTIONS] FILES..."
  case msg:
  of 1:
    echo &"Try \"{app_name} --help\" for help."
    echo &""
    echo &"Error: Missing argument \"FILES...\"."
  of 2:
    echo ""
    echo "Options:"
    echo ""
    echo "-h,\t--help\tShow this message and exit."
    echo "-p,\t--prop\tPrepend properties to document."
    echo "-t,\t--tree\tporints the ast and exits."
    echo "-k,\t--token-tree\tporints the tokens and exits."
    echo ""
  else:
    discard
  quit()

var wrote = 0

proc compile(file: string, prop: Table[string, string], wd: string, tree: int) = 
  echo "compile: ", file, ", ", tree
  var cwd = wd
  var file_new = file
  if file[0] == '/':
    cwd = file.split("/")[0..^2].join("/")
    file_new = file.split("/")[^1]
  var lexer_obj = initLexer(readFile(cwd & "/" & file_new), file_new)
  var toks = runLexer(lexer_obj)
  var parser_obj = initParser(toks, -1)
  var ast = parser_obj.runParser()
  var output = visitBody(ast, file_new, cwd, prop)
  var use = output.props["use"]
  var output_file = output.props["output"]
  var ignore = output.props["ignore"]
  case tree:
  of 0:
    if ignore != "True":
      if output_file == "":
        echo output.file
      else:
        echo "Writing: ", output_file
        writeFile(cwd & "/" & output_file, output.file)
        wrote += 1
    if use != "":
      for text in use.split(";"):
        var pattern = text.strip()
        var path = cwd
        if pattern[0] == '/':
          path = "/" & join(pattern.split("/")[0..^2], "/")
        else:
          path = cwd & "/" & join(pattern.split("/")[0..^2], "/")
        pattern = pattern.split("/")[^1]
        var add = false
        for file_full in walkDirRec(path):
          var file_name = file_full.split("/")[^1]
          if match(file_name, re(pattern)):
            compile(file_name, prop, path, tree)
  of 1:
    echo $ast
  of 2:
    echo $toks
  else:
    echo "weirdo"

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
              echo "invalid argument ", key, value
        of "h", "help":
          help(2)
        prev = ""
  if prev != "":
    case prev:
    of "p", "prop":
      echo "invalid argument ", prev
    of "h", "help":
      help(2)
  for file in files:
    compile(file, prop, getCurrentDir(), tree)
    echo "DONE\n\nwrote ", $wrote, " files\n"
  if files.len < 1:
    help(1)
main()

import pluglexer, ../output, strutils
import plugparser, os, plugnodes
import pluginterpreter

proc plugCompile*(file: string, wd: string): string =
  # compiles a file and sub files
  # args
  # file: the file to compile
  # prop: props to start with
  # wd: working directory
  var cwd = wd
  var file_new = file
  if file == "":
    return ""
  if file[0] == '/':
    cwd = file.split("/")[0..^2].join("/")
    file_new = file.split("/")[^1]
  var lexer_obj = initLexer(readFile(cwd & "/" & file_new), file_new)
  var toks = runLexer(lexer_obj)
  var parser_obj = initParser(toks, -1)
  var ast = parser_obj.runParser()
  return visitBody(ast, file_new, ".")

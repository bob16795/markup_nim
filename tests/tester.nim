import osproc, unittest, strutils, os, sequtils, sugar
import ../src/parser

var rootDir = getCurrentDir().parentDir()
var markupPath = rootDir / "src" / addFileExt("markup", ExeExt)
const path = "../src/markup"

var (output, exitCode) = execCmdEx("nim c " & path)
echo output
doAssert exitCode == QuitSuccess

proc execMarkup(args: varargs[string]): tuple[output: string, exitCode: int] =
  var quotedArgs = @args
  quotedArgs.insert(markupPath)
  quotedArgs = quotedArgs.map((x: string) => x.quoteShell)

  let path {.used.} = getCurrentDir().parentDir() / "src"

  var cmd =
    when not defined(windows):
      "PATH=" & path & ":$PATH " & quotedArgs.join(" ")
    else:
      quotedArgs.join(" ")

  result = execCmdEx(cmd)
  checkpoint(cmd)
  checkpoint(result.output)

proc inLines(lines: seq[string], line: string): bool =
  for i in lines:
    if line.normalize in i.normalize: return true

suite "code style":
  test "only terminal.nim echos":
    var (output, exitCode) = execCmdEx("grep echo " & markupPath & " -R --exclude terminal.nim --exclude markup")
    assert output.strip() == ""

suite "cli":
  test "compile_error_nofiles":
    var (output, exitCode) = execMarkup()
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "Error: Missing argument \"FILES...\"."))
    check(not(inLines(lines, "wrote 0 files")))

  test "help":
    var (output, exitCode) = execMarkup("--help")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(not(inLines(lines, "wrote 0 files")))
    (output, exitCode) = execMarkup("-h")
    check exitCode == QuitSuccess
    let lines2 = output.strip().split("\n")
    check(lines == lines2)

  test "prop":
    var (output, exitCode) = execMarkup("--prop", "lol: fdsa, nope: lol", "cli/prop.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "(fdsa ) Tj"))
    check(inLines(lines, "(lol ) Tj"))
    (output, exitCode) = execMarkup("-p", "lol: fdsa, nope: lol", "cli/prop.mu")
    let lines2 = output.strip().split("\n")
    check(lines == lines2)

  test "tree":
    var (output, exitCode) = execMarkup("--tree", "cli/prop.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    (output, exitCode) = execMarkup("-t", "cli/prop.mu")
    let lines2 = output.strip().split("\n")
    check(lines == lines2)

  test "tokenTree":
    var (output, exitCode) = execMarkup("--tree", "cli/prop.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    (output, exitCode) = execMarkup("-t", "cli/prop.mu")
    let lines2 = output.strip().split("\n")
    check(lines == lines2)

suite "lexer":
  test "emojis":
    var (output, exitCode) = execMarkup("-k", "lexer/emojis.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "tt_text: 😁(1, 0)"))

  test "empty":
    var (output, exitCode) = execMarkup("-k", "lexer/empty.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "tt_newline: (1, 0)"))

  test "symbols":
    var (output, exitCode) = execMarkup("-k", "lexer/symbols.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "tt_hash: (1, 0)"))
    check(inLines(lines, "tt_star: (1, 3)"))
    check(inLines(lines, "tt_plus: (1, 4)"))
    check(inLines(lines, "tt_minus: (1, 5)"))
    check(inLines(lines, "tt_underscore: (1, 6)"))
    check(inLines(lines, "tt_colon: (1, 7)"))
    check(inLines(lines, "tt_bar: (1, 8)"))
    check(inLines(lines, "tt_ltag: (1, 9)"))
    check(inLines(lines, "tt_rtag: (1, 10)"))
    check(inLines(lines, "tt_lparen: (1, 11)"))
    check(inLines(lines, "tt_rparen: (1, 12)"))
    check(inLines(lines, "tt_lbrace: (1, 13)"))
    check(inLines(lines, "tt_rbrace: (1, 14)"))
    check(inLines(lines, "tt_exclaim: (1, 15)"))
    check(inLines(lines, "tt_dollar: (1, 16)"))

  test "spacesToTabs":
    var (output, exitCode) = execMarkup("-k", "lexer/spaces.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "tt_ident: (1, 1)"))
    check(inLines(lines, "tt_text: lol(1, 2)"))
    check(inLines(lines, "tt_text: l(2, 1)"))
    check(inLines(lines, "tt_text: ol(2, 2)"))
    check(inLines(lines, "tt_text: lol(3, 0)"))

suite "parser":
  test "textComment":
    var (output, exitCode) = execMarkup("-t","parser/comment.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "    <TextComment: this is a comment !!!>"))
    check(inLines(lines, "    <TextComment: Include nothing>"))

  test "textList":
    var (output, exitCode) = execMarkup("-t","parser/list.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "      <List Level 1:  one>"))
    check(inLines(lines, "      <List Level 2:  two>"))
    check(inLines(lines, "      <List Level 3:  three>"))
    check(inLines(lines, "      <List Level 1:  four>"))
    check(inLines(lines, "      <List Level 2:  five>"))
    check(inLines(lines, "      <List Level 1:  six>"))
    check(inLines(lines, "      <List Level 3:  seven>"))

  test "equ":
    var (output, exitCode) = execMarkup("-t","parser/equation.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "    <Equation: lol+nope>"))

  test "tag":
    var (output, exitCode) = execMarkup("-t","parser/tags.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "    <Tag: lol: nope>"))
    check(inLines(lines, "    <Tag: lol>"))

  test "textHeader":
    var (output, exitCode) = execMarkup("-t","parser/headings.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "    <Heading 1: lol>"))
    check(inLines(lines, "    <Heading 2: lol>"))
    check(inLines(lines, "    <Heading 3: lol>"))
    check(inLines(lines, "    <Heading 1: lol2>"))
    check(inLines(lines, "    <Heading 2: lol2>"))
    check(inLines(lines, "    <Heading 3: lol2>"))

  test "table":
    var (output, exitCode) = execMarkup("-t","parser/tables.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "    <Table:"))
    check(inLines(lines, "      <TableHeader: 3: lol, 6: nope>"))
    check(inLines(lines, "      <TableRow: hello, world>"))

suite "interpreter":
  test "yamlOverride":
    var (output, exitCode) = execMarkup("-p", "lol:fdsa","interpreter/yaml.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "(fdsa ) Tj"))
    check(inLines(lines, "(nope ) Tj"))
    check(inLines(lines, "(new ) Tj"))

  test "macros":
    var (output, exitCode) = execMarkup("interpreter/macros.mu")
    check exitCode == QuitSuccess
    # let lines = output.strip().split("\n")
    # check(inLines(lines, "( hello this is main) \""))
    # check(inLines(lines, "( hello this is file 2) \""))

  test "include":
    var (output, exitCode) = execMarkup("interpreter/include/main.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "(hello this is main ) Tj"))
    check(inLines(lines, "(hello this is file 2 ) Tj"))

  test "tagPRP":
    var (output, exitCode) = execMarkup("interpreter/tag_prp.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "(value ) Tj"))
    check(inLines(lines, "(new ) Tj"))

suite "pdfer":
  test "prepend":
    var (output, exitCode) = execMarkup("pdfer/prepend.mu")
    check exitCode == QuitSuccess
    let lines = output.strip().split("\n")
    check(inLines(lines, "(he ) Tj"))
    check(inLines(lines, "(llo ) Tj"))
    check(inLines(lines, "(cha ) Tj"))
    check(inLines(lines, "(nged ) Tj"))

suite "mathus":
  test "fractions":
    var (output, exitCode) = execMarkup("mathus/fractions.mu")
    check exitCode == QuitSuccess
    check("100 677 Td\n(z) Tj" in output)
    check("107 684 Td\n(a) Tj" in output)
    check("106 670 Td\n(b) Tj" in output)
    check("106 681 m\n114 681 l\nS\n8 6 Td\n(y) Tj" in output)

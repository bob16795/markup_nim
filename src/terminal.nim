import strformat, os, strutils

const DEBUG* = false

proc help*(msg: int, app_name: string = "markup") =
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
    echo "-k,\t--token-tree\tpoints the tokens and exits."
    echo "-I,\t--no-use\tdisables the use prop"
    echo ""
  else:
    discard
  quit()

template log*(file, message: string) =
  echo file, ": ", message.replace("\n", "\n" & file & ": ")

template debug*(file, message: string) =
  when DEBUG:
    echo "[DBG] ", message, ": ", file

template output*(text, file, cwd: string) =
  if file == "":
    echo text
  else:
    log(file.split("/")[^1], "writing")
    writeFile(cwd & "/" & file, text)

import plugnodes, strutils, strformat
import ../output

proc visit(node: Node, file_name: string, text: string,
        inside = false): string =
    result = text
    case node.kind:
    of nkTagDef:
        var args: seq[string]
        if node.extra[0].kind != nkNone:
            args = node.extra[0].names
        result &= node.name
        if node.predef:
            result &= file_name
        result &= ":;"
        var value = ""
        for n in node.lines:
            value &= "\n"
            value = visit(n, file_name, value)
        for argId in 0..<args.len:
            value = value.replace(&"[{args[argId]}]", &"(){argId}()")
        result &= value
        result &= "\n;\n"
    of nkLine:
        case node.keyword:
        of "RAW":
            result &= "\n" & node.command.replace("\n", "\n\n")
        of "SET":
            result &= "<PRP: " & node.command.replace("=", ":") & ">"
        of "TAG":
            var lol = "<" & node.command.split(" ")[0] & ": " &
                    node.command.split(" ")[1..^1].join(" ") & ">"
            result &= lol.replace(": >", ">")
        of "CODE":
            result &= "```"
            result &= "{" & node.command.split("\n")[0] & "}\n"
            result &= node.command.split("\n")[1..^1].join("\n")
            result &= "\n```"
    else: discard

proc visitBody*(node: Node, file_name: string, wd: string): string =
    var text: string
    var fn = file_name.split("/")[^1].replace(".mup", "")
    for node in node.Contains:
        text = visit(node, fn, text)
    text = "---\n" & text & "---"
    if "init" & fn in text:
        text &= &"\n!init the class\n<init{fn}>\n!done\n"
    return text

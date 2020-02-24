import objects
import lib
import strformat

type
  equation* = object
    text*: string

proc get_obj*(equ: var equation, x: int, y: int, font: string = "times.ttf"): pdf_object =
  var idx = 0
  var text, text_tmp = ""
  var pos, start_pos = 0
  result.append_text(&"BT\n/F1 12 Tf\n{x} {y} Td\n")
  while idx < len(equ.text):
    case equ.text[idx]:
    of '\\':
      if text != "":
        result.append_text(&"({text.addbs()}) Tj\n")
        pos = pos + get_text_size(text, 12, font).toInt
        text = ""
      idx += 1
      case equ.text[idx]:
      of 'f':
        echo "frac"
      of '^':
        text_tmp = ""
        idx += 1
        result.append_text("5 Ts\n/F1 7 Tf\n(")
        while idx < len(equ.text) and equ.text[idx] != '^':
          text_tmp.add(equ.text[idx])
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.append_text(text_tmp)
        pos += get_text_size(text_tmp, 7, font).toInt
        result.append_text(") Tj\n/F1 12 Tf\n0 Ts\n")
      of '_':
        text_tmp = ""
        idx += 1
        result.append_text("-5 Ts\n/F1 7 Tf\n(")
        while idx < len(equ.text) and equ.text[idx] != '_':
          text_tmp.add(equ.text[idx])  
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.append_text(text_tmp)
        pos += get_text_size(text_tmp, 7, font).toInt
        result.append_text(") Tj\n/F1 12 Tf\n0 Ts\n")
      of '<':
        start_pos = pos
        text_tmp = ""
        idx += 1
        result.append_text(&"5 Ts\n{start_pos} 0 Td\n/F1 7 Tf\n(")
        while idx < len(equ.text) and equ.text[idx] != '<':
          text_tmp.add(equ.text[idx])  
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.append_text(text_tmp)
        pos += get_text_size(text_tmp, 7, font).toInt
        text_tmp = ""
        result.append_text(&") Tj\n0 0 Td\n-5 Ts\n/F1 6 Tf\n(")
        idx += 1
        while idx < len(equ.text) and equ.text[idx] != '<':
          text_tmp.add(equ.text[idx])  
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.append_text(text_tmp)
        if pos < start_pos + get_text_size(text_tmp, 7, font).toInt:
          pos = start_pos + get_text_size(text_tmp, 7, font).toInt
        result.append_text(") Tj\n{pos-start_pos} 0 Td\n/F1 12 Tf\n0 Ts\n")
      else:
        echo "bad esc"
    else:
      text.add(equ.text[idx])
    idx += 1
  if text != "":
    result.append_text(&"({text.addbs()}) Tj\n")
    text = ""
  result.append_text("ET\n")

# var equ: equation
# lib_init()
# equ.text = "-log\\<1<2<(3.8x10\\^-10^) = 9.42"

# echo equ.get_obj(1,18, "/home/john/doc/rep/markup_nim/src/pdfer/times.ttf")

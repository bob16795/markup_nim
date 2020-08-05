import objects
import lib
import strformat, strutils

type
  equation* = object
    text*: string

proc get_obj*(equ: var equation, x: int, y: int, font: string = "times.ttf"): tuple[obj: pdf_object, size, height: int] =
  var idx = 0
  var text, text_tmp = ""
  var pos, start_pos = 0
  result.obj.append_text(&"BT\n/F1 12 Tf\n{x} {y} Td\n")
  result.height = 1
  while idx < len(equ.text):
    case equ.text[idx]:
    of '\\':
      if text != "":
        result.obj.append_text(&"({text.addbs()}) Tj\n")
        pos = pos + get_text_size(text, 12, font).toInt
        text = ""
      idx += 1
      case equ.text[idx]:
      of 'f':
        start_pos = pos
        text_tmp = ""
        idx += 1
        while idx < len(equ.text) and equ.text[idx] != 'f':
          if equ.text[idx] == '\\':
            idx += 1
          text_tmp.add(equ.text[idx])
          idx += 1
        var equt = equ
        equt.text = text_tmp
        text_tmp = ""
        idx += 1
        while idx < len(equ.text) and equ.text[idx] != 'f':
          if equ.text[idx] == '\\':
            idx += 1
          text_tmp.add(equ.text[idx])
          idx += 1
        var equb = equ
        equb.text = text_tmp
        var top_equ = get_obj(equt, x + pos, y + 6, font)
        var top_size = top_equ.size
        var bot_equ = get_obj(equb, x + pos, y - 6, font)
        var bot_size = bot_equ.size
        if top_size > bot_size:
          bot_equ = get_obj(equb, x + pos + ((top_size - bot_size) / 2).int, y - (bot_equ.height * 7), font)
          top_equ = get_obj(equt, x + pos, y + (top_equ.height * 7), font)
          result.obj.append_text(bot_equ.obj.stream.replace("ET\n").replace("BT\n"))
          result.obj.append_text(top_equ.obj.stream.replace("ET\n").replace("BT\n"))
          result.obj.append_text(&"{x + start_pos} {y + 4}. m\n{x + start_pos + top_size} {y + 4} l\nS")
          pos = start_pos + top_size
          result.obj.append_text(&"\n{pos - start_pos} -6 Td\n")
        else:
          top_equ = get_obj(equt, x + pos + ((bot_size - top_size) / 2).int, y + (top_equ.height * 7), font)
          bot_equ = get_obj(equb, x + pos, y - (bot_equ.height * 7), font)
          result.obj.append_text(top_equ.obj.stream.replace("ET\n").replace("BT\n"))
          result.obj.append_text(bot_equ.obj.stream.replace("ET\n").replace("BT\n"))
          result.obj.append_text(&"{x + start_pos} {y + 4} m\n{x + start_pos + bot_size} {y + 4} l\nS")
          pos = start_pos + bot_size
          result.obj.append_text(&"\n{pos - start_pos} 6 Td\n")
        if bot_equ.height + top_equ.height > result.height:
          result.height = bot_equ.height + top_equ.height
      of '^':
        text_tmp = ""
        idx += 1
        result.obj.append_text("5 Ts\n/F1 7 Tf\n(")
        while idx < len(equ.text) and equ.text[idx] != '^':
          text_tmp.add(equ.text[idx])
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.obj.append_text(text_tmp)
        pos += get_text_size(text_tmp, 7, font).toInt
        result.obj.append_text(") Tj\n/F1 12 Tf\n0 Ts\n")
      of '_':
        text_tmp = ""
        idx += 1
        result.obj.append_text("-2 Ts\n/F1 7 Tf\n(")
        while idx < len(equ.text) and equ.text[idx] != '_':
          text_tmp.add(equ.text[idx])
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.obj.append_text(text_tmp)
        pos += get_text_size(text_tmp, 7, font).toInt
        result.obj.append_text(") Tj\n/F1 12 Tf\n0 Ts\n")
      of '<':
        start_pos = pos
        text_tmp = ""
        idx += 1
        result.obj.append_text(&"5 Ts\n{start_pos} 0 Td\n/F1 7 Tf\n(")
        while idx < len(equ.text) and equ.text[idx] != '<':
          text_tmp.add(equ.text[idx])
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.obj.append_text(text_tmp)
        pos += get_text_size(text_tmp, 7, font).toInt
        text_tmp = ""
        result.obj.append_text(&") Tj\n0 0 Td\n-2 Ts\n/F1 7 Tf\n(")
        idx += 1
        while idx < len(equ.text) and equ.text[idx] != '<':
          text_tmp.add(equ.text[idx])
          idx += 1
          if text_tmp[^1] == '\\':
            text_tmp.add(equ.text[idx])
            idx += 1
        result.obj.append_text(text_tmp)
        if pos < start_pos + get_text_size(text_tmp, 7, font).toInt:
          pos = start_pos + get_text_size(text_tmp, 7, font).toInt
        result.obj.append_text(&") Tj\n{start_pos} 0 Td\n/F1 12 Tf\n0 Ts\n")
      else:
        discard "bad esc"
    else:
      text.add(equ.text[idx])
    idx += 1
  if text != "":
    result.obj.append_text(&"({text.addbs()}) Tj\n")
    pos += get_text_size(text, 12, font).toInt
    text = ""
  result.size = pos
  result.obj.append_text("ET\n")

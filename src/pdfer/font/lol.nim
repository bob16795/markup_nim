import os, strutils
import tables

proc parse_uint32(file: File): uint32 =
  var a: seq[uint8] = @[0.uint8, 0.uint8, 0.uint8, 0.uint8]
  if 4 != file.readBytes(a, 0, 4):
    return
  result = a[0].uint32 shl 24
  result += a[1].uint32 shl 16
  result += a[2].uint32 shl 8
  result += a[3].uint32 shl 0

proc parse_uint16(file: File): uint32 =
  var a: seq[uint8] = @[0.uint8, 0.uint8]
  if 2 != file.readBytes(a, 0, 2):
    return
  result = a[0].uint16 shl 8
  result += a[1].uint16 shl 0

proc parse_uint8(file: File): uint32 =
  var a: seq[uint8] = @[0.uint8]
  if 1 != file.readBytes(a, 0, 1):
    return
  result = a[0].uint16 shl 0

proc parse_Tag(file: File): array[4, char] =
  var a: seq[uint8] = @[0.uint8, 0.uint8, 0.uint8, 0.uint8]
  if 4 != file.readBytes(a, 0, 4):
    return
  result[0] = a[0].char
  result[1] = a[1].char
  result[2] = a[2].char
  result[3] = a[3].char

var f = open("../times.ttf")

echo "sfntVersion: ", parse_uint32(f)
var ftables =  parse_uint16(f)
echo "numTables: ", ftables
echo "searchRange: ", parse_uint16(f)
echo "entrySelector: ", parse_uint16(f)
echo "RangeShift: ", parse_uint16(f)

var tabs: Table[string, uint32]

for i in 1..ftables:
  echo "table ", i
  var name = parse_Tag(f)
  echo "  tableTag: ", name[0] & name[1] & name[2] & name[3]
  echo "  checkSum: ", parse_uint32(f)
  var offset = parse_uint32(f)
  echo "  offset: ", offset
  echo "  length: ", parse_uint32(f)
  tabs[name[0] & name[1] & name[2] & name[3]] = offset

echo "table name"
f.setFilePos(tabs["name"].int)
var format = parseuint16(f)
echo "  format: ", format
var tablen = 0
var ssoffset = 0
if format == 0:
  tablen = parseuint16(f).int
  echo "  count: ", tablen
  ssoffset = parseuint16(f).int
  echo "  ssoff: ", ssoffset
for i in 1..tablen:
  echo "  platformID: ", parseuint16(f)
  echo "  encodingID: ", parseuint16(f)
  echo "  languageID: ", parseuint16(f)
  echo "  nameID: ", parseuint16(f)
  var length = parseuint16(f)
  echo "  length: ", length
  var offset = parseuint16(f)
  echo "  offset: ", offset
  var a: seq[char] = @[' ']
  for i in 0..length:
    a &= [' ']
  var pos = f.getFilePos()
  f.setFilePos(tabs["name"].int + ssoffset + offset.int)
  discard f.readChars(a, 0, length)
  echo a.join("")
  f.setFilePos(pos)


#f.setFilePos(tabs["cmap"].int)
#echo "table cmap"
#echo "version: ", parseuint16(f)
#var tablen = parseuint16(f)
#echo "numTables: ", tablen
#for i in 0..tablen:
#  echo "platformID: ", parseuint16(f)
#  echo "encodingID: ", parseuint16(f)
#  var offset = parse_uint32(f)
#  echo "  offset: ", offset
#  #f.setFilePos(tabs["cmap"].int + offset)

  

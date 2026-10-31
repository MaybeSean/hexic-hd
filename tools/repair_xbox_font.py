#!/usr/bin/env python3
"""Rebuild the tables missing from the Xbox's xarialuni.ttf (Arial Unicode MS).

The console's copy was stripped to cmap/glyf/head/hhea/hmtx/loca/name, which
no desktop font parser accepts. The Xbox drew every Hexic HD string with it,
and its tall ascent (1.068 em vs Arial's 0.905) is why text sits a few
pixels lower on the console than with stock Arial. This adds minimal maxp,
OS/2 and post tables derived from the tables that remain; glyphs untouched.

usage: repair_xbox_font.py <xarialuni.ttf> <out.ttf> [--bold]
--bold flags the copy as the Bold style (same glyphs): the Xbox had no bold
face and drew bold text with the regular one.
"""
import struct
import sys
from pathlib import Path


def read_tables(data):
    count, = struct.unpack_from(">H", data, 4)
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        tables[tag] = bytearray(data[offset:offset + length])
    return tables


def checksum(data):
    data = bytes(data) + b"\0" * (-len(data) % 4)
    return sum(struct.unpack(f">{len(data) // 4}I", data)) & 0xFFFFFFFF


def name_table(names):
    """Format-0 name table with Windows Unicode English records."""
    records, strings = b"", b""
    for name_id, value in sorted(names.items()):
        encoded = value.encode("utf-16-be")
        records += struct.pack(">6H", 3, 1, 0x409, name_id, len(encoded), len(strings))
        strings += encoded
    return bytearray(struct.pack(">3H", 0, len(names), 6 + len(records)) + records + strings)


def write_font(tables):
    tags = sorted(tables)
    count = len(tags)
    entry_selector = count.bit_length() - 1
    search_range = (1 << entry_selector) * 16
    header = struct.pack(">IHHHH", 0x00010000, count, search_range, entry_selector, count * 16 - search_range)
    offset = len(header) + 16 * count
    directory, body = b"", b""
    tables[b"head"][8:12] = b"\0\0\0\0"  # checkSumAdjustment, fixed up below
    for tag in tags:
        data = bytes(tables[tag])
        if tag == b"head":
            head_offset = offset + len(body)
        directory += struct.pack(">4sIII", tag, checksum(data), offset + len(body), len(data))
        body += data + b"\0" * (-len(data) % 4)
    font = bytearray(header + directory + body)
    struct.pack_into(">I", font, head_offset + 8, (0xB1B0AFBA - checksum(font)) & 0xFFFFFFFF)
    return bytes(font)


def main(src, dst, bold=False):
    tables = read_tables(Path(src).read_bytes())
    head, hhea = tables[b"head"], tables[b"hhea"]
    units_per_em, = struct.unpack_from(">H", head, 18)
    x_min, y_min, x_max, y_max = struct.unpack_from(">hhhh", head, 36)
    long_loca, = struct.unpack_from(">h", head, 50)
    ascent, descent, line_gap = struct.unpack_from(">hhh", hhea, 4)
    num_glyphs = len(tables[b"loca"]) // (4 if long_loca else 2) - 1

    # maxp 1.0: numGlyphs is what parsers need; the rest are generous limits.
    tables[b"maxp"] = bytearray(struct.pack(">IHHHHHHHHHHHHHH", 0x00010000, num_glyphs,
                                            2048, 256, 2048, 256, 2, 16, 64, 64, 0, 512, 4096, 64, 4))
    # post 3.0: no glyph names.
    tables[b"post"] = bytearray(struct.pack(">IIhhIIIII", 0x00030000, 0, -205, 102, 0, 0, 0, 0, 0))
    # OS/2 version 4 with metrics mirrored from hhea/head.
    weight, selection = (700, 0x20) if bold else (400, 0x40)
    tables[b"OS/2"] = bytearray(struct.pack(
        ">HhHHHhhhhhhhhhhh10s4I4sHHHhhhHHII hhHHH".replace(" ", ""),
        4, 904, weight, 5, 0,                      # version, xAvgCharWidth, weight, width, fsType
        1434, 1331, 0, 286, 1434, 1331, 0, 983,    # subscript / superscript sizes and offsets
        102, 530, 0,                               # strikeout size/pos, family class
        bytes([2, 11, 6, 4, 2, 2, 2, 2, 2, 4]),    # PANOSE (Arial)
        0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, b"MONO",
        selection, 0x20, 0xFFFF,                   # fsSelection, first/last char index
        ascent, descent, line_gap,                 # typo metrics
        max(ascent, y_max), max(-descent, -y_min), # win ascent/descent
        0x0000003F, 0,                             # code page ranges
        1062, 1466, 0, 32, 0))                     # xHeight, capHeight, default/break char, maxContext
    # The stripped name table only kept the family name; font loaders such as
    # Ruffle's register fonts by their full name, so write the standard set.
    style = "Bold" if bold else "Regular"
    tables[b"name"] = name_table({1: "Arial Unicode MS", 2: style, 3: f"Arial Unicode MS {style} (Xbox 360)",
                                  4: "Arial Unicode MS" + (" Bold" if bold else ""), 6: "ArialUnicodeMS" + ("-Bold" if bold else "")})
    if bold:
        mac_style, = struct.unpack_from(">H", head, 44)
        struct.pack_into(">H", head, 44, mac_style | 0x1)
    # The OS/2 sub/superscript and x/cap-height values below are Arial's at 2048 units.
    assert units_per_em == 2048 and x_max > x_min, "unexpected font; OS/2 values assume Arial at 2048 upem"
    Path(dst).write_bytes(write_font(tables))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--bold"]
    main(*args[:2], bold="--bold" in sys.argv)

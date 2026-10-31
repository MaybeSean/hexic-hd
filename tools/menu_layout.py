"""Rebuild the main menu in the layout of the later Hexic HD title update.

This SWF is the original 2005 release, whose main menu has six buttons in a
panel that starts below the score bar. The title update added a Leaderboards
entry (with Achievements and Xbox Dashboard, which have no equivalent here) and
stretched the panel up to the top of the frame, logo inside its rounded top.
This moves the menu's own placements (frame 14, "Menu") to match captures of
the update, and adds a Leaderboards button cloned from Options, whose script is
patches/scripts/frame_14/PlaceObject2_586_478/.
"""
import re
import struct

from swf import SHOW_FRAME

PLACE_OBJECT2 = 26
REMOVE_OBJECT2 = 28
MENU_FRAME = 14
MENU_END_FRAME = 21  # where the menu's objects are removed

# depth: new y (twips/20), with optional new y scale. From 1280x720 captures of
# the update: panel top at 75 under the frame's rounded corners, logo 80 px
# higher, mode buttons 79 px higher, the lower group re-spaced to fit four.
PANEL, LOGO, LOGO_HD, LOGO_TEXT, DIVIDER = 430, 486, 498, 499, 500
MARATHON, TIMED, SURVIVAL = 441, 432, 450
OPTIONS, TUTORIAL, EXIT = 459, 468, 477
LEADERBOARD = 478  # free depth between Exit and the logo
PANEL_BOTTOM = 668.0
MOVES = {
    LOGO: -80, LOGO_HD: -80, LOGO_TEXT: -80,
    MARATHON: -79, TIMED: -79, SURVIVAL: -79,
    DIVIDER: -84,
}
LOWER_GROUP = {OPTIONS: 381.6, TUTORIAL: 433.6, LEADERBOARD: 485.6, EXIT: 537.6}
PANEL_TOP = 75.0


class Bits:
    def __init__(self, data, pos):
        self.data, self.bit = data, pos * 8

    def u(self, n):
        value = 0
        for _ in range(n):
            value = (value << 1) | ((self.data[self.bit // 8] >> (7 - self.bit % 8)) & 1)
            self.bit += 1
        return value

    def s(self, n):
        value = self.u(n)
        return value - (1 << n) if n and value >> (n - 1) else value

    def end(self):
        return (self.bit + 7) // 8


class BitWriter:
    def __init__(self):
        self.bits = []

    def u(self, value, n):
        self.bits += [(value >> (n - 1 - i)) & 1 for i in range(n)]

    def s(self, value, n):
        self.u(value & ((1 << n) - 1), n)

    def bytes(self):
        bits = self.bits + [0] * (-len(self.bits) % 8)
        return bytes(int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8))


def signed_bits(*values):
    return max([1] + [max(v, -v - 1).bit_length() + 1 for v in values])


def read_matrix(data, pos):
    b = Bits(data, pos)
    m = {"scale": None, "rotate": None}
    if b.u(1):
        n = b.u(5)
        m["scale"] = (b.s(n), b.s(n))
    if b.u(1):
        n = b.u(5)
        m["rotate"] = (b.s(n), b.s(n))
    n = b.u(5)
    m["tx"], m["ty"] = b.s(n), b.s(n)
    return m, b.end()


def write_matrix(m):
    w = BitWriter()
    for key in ("scale", "rotate"):
        if m[key] is None:
            w.u(0, 1)
        else:
            n = signed_bits(*m[key])
            w.u(1, 1); w.u(n, 5); w.s(m[key][0], n); w.s(m[key][1], n)
    n = signed_bits(m["tx"], m["ty"])
    w.u(n, 5); w.s(m["tx"], n); w.s(m["ty"], n)
    return w.bytes()


def parse_place2(data):
    flags, depth = data[0], struct.unpack_from("<H", data, 1)[0]
    pos, place = 3, {"flags": flags, "depth": depth, "char": None, "matrix": None, "name": None}
    if flags & 0x02:
        place["char"], = struct.unpack_from("<H", data, pos); pos += 2
    if flags & 0x04:
        place["matrix"], pos = read_matrix(data, pos)
    cx_start = pos
    if flags & 0x08:
        b = Bits(data, pos)
        add, mult, n = b.u(1), b.u(1), b.u(4)
        b.u(n * 4 * (add + mult))
        pos = b.end()
    place["cxform"] = data[cx_start:pos]
    place["ratio"] = data[pos:pos + 2] if flags & 0x10 else b""
    pos += len(place["ratio"])
    if flags & 0x20:
        end = data.index(0, pos)
        place["name"] = data[pos:end].decode("latin1"); pos = end + 1
    place["tail"] = data[pos:]  # clip depth and clip actions, untouched
    return place


def write_place2(place):
    out = bytearray([place["flags"]]) + struct.pack("<H", place["depth"])
    if place["flags"] & 0x02:
        out += struct.pack("<H", place["char"])
    if place["flags"] & 0x04:
        out += write_matrix(place["matrix"])
    out += place["cxform"] + place["ratio"]
    if place["flags"] & 0x20:
        out += place["name"].encode("latin1") + b"\0"
    return bytes(out + place["tail"])


def frame_tags(swf, frame, code):
    found, current = {}, 1
    for i, (c, data) in enumerate(swf.tags):
        if current == frame and c == code:
            found[struct.unpack_from("<H", data, 1 if code == PLACE_OBJECT2 else 0)[0]] = i
        if c == SHOW_FRAME:
            current += 1
            if current > frame:
                break
    return found


def relayout_menu(swf):
    places = frame_tags(swf, MENU_FRAME, PLACE_OBJECT2)
    removes = frame_tags(swf, MENU_END_FRAME, REMOVE_OBJECT2)

    def edit(depth, change):
        place = parse_place2(swf.tags[places[depth]][1])
        change(place)
        swf.tags[places[depth]] = (PLACE_OBJECT2, write_place2(place))

    def to_y(y):
        return lambda p: p["matrix"].__setitem__("ty", round(y * 20))

    def by(dy):
        return lambda p: p["matrix"].__setitem__("ty", p["matrix"]["ty"] + dy * 20)

    def stretch_panel(p):
        m = p["matrix"]
        top = m["ty"] / 20
        sx, sy = m["scale"]
        m["scale"] = (sx, round(sy * (PANEL_BOTTOM - PANEL_TOP) / (PANEL_BOTTOM - top)))
        m["ty"] = round(PANEL_TOP * 20)

    def name_panel(p):
        # Named so the menu script can round its top corners with a mask.
        p["flags"] |= 0x20
        p["name"] = "hexicMenuPanel"

    edit(PANEL, stretch_panel)
    edit(PANEL, name_panel)
    for depth, dy in MOVES.items():
        edit(depth, by(dy))

    # Leaderboards: a copy of the Options button at its own depth and name.
    leaderboard = parse_place2(swf.tags[places[OPTIONS]][1])
    leaderboard["depth"], leaderboard["name"] = LEADERBOARD, "btn_leaderboard"
    swf.tags.insert(places[EXIT] + 1, (PLACE_OBJECT2, write_place2(leaderboard)))
    places = frame_tags(swf, MENU_FRAME, PLACE_OBJECT2)
    for depth, y in LOWER_GROUP.items():
        edit(depth, to_y(y))

    removes = frame_tags(swf, MENU_END_FRAME, REMOVE_OBJECT2)
    swf.tags.insert(removes[EXIT] + 1, (REMOVE_OBJECT2, struct.pack("<H", LEADERBOARD)))


def patch_keymap(xml):
    """Insert Leaderboard between Tutorial and Exit in the Menu's D-pad order."""
    menu = re.search(r"<ID>Menu</ID>.*?</State>", xml, re.S)
    block = menu.group(0)
    block = re.sub(r"(<ID>Tutorial</ID>\s*<Up>Options</Up>\s*<Down>)Exit(</Down>)", r"\1Leaderboard\2", block)
    block = re.sub(r"(<ID>Exit</ID>\s*<Up>)Tutorial(</Up>)", r"\1Leaderboard\2", block)
    block = re.sub(r"(\s*)(<Object>\s*<ID>Exit</ID>)",
                   r"\1<Object>\1\t<ID>Leaderboard</ID>\1\t<Up>Tutorial</Up>\1\t<Down>Exit</Down>\1</Object>\1\2",
                   block, count=1)
    assert block.count("Leaderboard") == 3, "unexpected Menu key map layout"
    return xml[:menu.start()] + block + xml[menu.end():]


if __name__ == "__main__":
    import sys
    from pathlib import Path
    if len(sys.argv) != 3:
        sys.exit("usage: menu_layout.py <KeyMap_HXIC.xml> <out.xml>")
    Path(sys.argv[2]).write_text(patch_keymap(Path(sys.argv[1]).read_text()))

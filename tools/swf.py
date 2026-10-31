"""Minimal SWF container helpers: read/write the header and walk top-level tags."""
import struct
import zlib
from pathlib import Path

DO_ACTION = 12
SHOW_FRAME = 1
DEFINE_SOUND = 14
END = 0


class Swf:
    def __init__(self, version, header, tags):
        self.version = version
        self.header = header  # frame rect + rate + count, untouched
        self.tags = tags      # list of (code, data)

    @classmethod
    def load(cls, path):
        raw = Path(path).read_bytes()
        sig, version = raw[:3], raw[3]
        if sig not in (b"FWS", b"CWS"):
            raise ValueError(f"{path}: unsupported SWF signature {sig!r}")
        body = zlib.decompress(raw[8:]) if sig == b"CWS" else raw[8:]
        rect_bits = body[0] >> 3
        pos = (5 + 4 * rect_bits + 7) // 8 + 4
        header, tags = body[:pos], []
        while pos < len(body):
            word, = struct.unpack_from("<H", body, pos)
            code, length = word >> 6, word & 0x3F
            pos += 2
            if length == 0x3F:
                length, = struct.unpack_from("<I", body, pos)
                pos += 4
            if pos + length > len(body):
                raise ValueError(f"{path}: tag {code} at {pos} overruns the file")
            tags.append((code, body[pos:pos + length]))
            pos += length
            if code == END:
                break
        return cls(version, header, tags)

    def save(self, path):
        body = bytearray(self.header)
        for code, data in self.tags:
            body += encode_tag(code, data)
        packed = zlib.compress(bytes(body), 9)
        Path(path).write_bytes(b"CWS" + bytes([self.version]) + struct.pack("<I", len(body) + 8) + packed)

    def frame_tag_indexes(self, frame, code):
        """Indexes into self.tags of every `code` tag in 1-based main-timeline `frame`."""
        current, found = 1, []
        for i, (c, _) in enumerate(self.tags):
            if current == frame and c == code:
                found.append(i)
            if c == SHOW_FRAME:
                current += 1
                if current > frame:
                    break
        return found


def encode_tag(code, data):
    if len(data) < 0x3F and code not in (6, 20, 21, 35, 36, 90):  # bitmap tags must use long form
        return struct.pack("<H", (code << 6) | len(data)) + data
    return struct.pack("<HI", (code << 6) | 0x3F, len(data)) + data

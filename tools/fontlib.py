"""Glyphs of the MemTest+ screen: ASCII from the MiSTer console fonts (lat1-16, lat1-08), and the box drawing and block glyphs drawn here.
A glyph is a list of rows, one byte per row, bit 7 the leftmost pixel. The heights are 16 and 8."""
import gzip
import os
import struct

FONTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'usr', 'share', 'consolefonts')

# box drawing characters from their arms (up, down, left, right): 0 none, 1 single, 2 double
BOX = {
    '─': (0, 0, 1, 1), '═': (0, 0, 2, 2), '║': (2, 2, 0, 0),
    '╔': (0, 2, 0, 2), '╗': (0, 2, 2, 0), '╚': (2, 0, 0, 2), '╝': (2, 0, 2, 0),
    '╠': (2, 2, 0, 2), '╣': (2, 2, 2, 0), '╟': (2, 2, 0, 1), '╢': (2, 2, 1, 0),
}

# the cell of the maps: seven eighths wide, so that a pixel is left between neighbouring cells
CELL = '▉'


def load_psf2(name):
    d = gzip.open(os.path.join(FONTDIR, name + '.psfu.gz')).read()
    assert d[:4] == bytes([0x72, 0xb5, 0x4a, 0x86]), name
    hs, flags, length, cs, h, w = struct.unpack('<6I', d[8:32])
    assert w == 8 and cs == h
    return [list(d[hs + i * cs: hs + (i + 1) * cs]) for i in range(length)]


def box_glyph(arms, h):
    up, down, left, right = arms
    rows = [0] * h
    thick = 2 if h >= 16 else 1                      # a single horizontal line is this many rows thick
    cy = h // 2 - 1                                  # its first row
    vbits = {0: 0x00, 2: 0x24}                       # a double vertical line: columns 2 and 5

    def hrows(style):
        if style == 1:
            return [cy + i for i in range(thick)]
        if style == 2:
            return [cy - 1, cy + thick]
        return []

    hr = sorted(set(hrows(left)) | set(hrows(right)))
    y_up = max(hr) if hr else cy + thick - 1         # where the arm going up stops (it meets the horizontal line)
    y_down = min(hr) if hr else cy
    for y in range(h):
        if up and y <= y_up:
            rows[y] |= vbits[up]
        if down and y >= y_down:
            rows[y] |= vbits[down]
    for style, col0, col1 in ((left, 0, 5 if max(up, down) == 2 else 4), (right, 2 if max(up, down) == 2 else 3, 7)):
        m = 0
        for x in range(col0, col1 + 1):
            m |= 0x80 >> x
        for y in hrows(style):
            rows[y] |= m
    return rows


def graphics_glyph(ch, h):
    if ch in BOX:
        return box_glyph(BOX[ch], h)
    if ch == CELL:
        return [0xFE] * h
    return None

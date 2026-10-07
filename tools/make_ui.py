#!/usr/bin/env python3
"""Builds the text screen of the core from ui/layout.txt.

Writes to rtl/:  font16.hex font8.hex (glyphs), ui_char.hex ui_attr.hex (the screen before anything is filled in, rows 128 cells apart),
ui_ops.hex ui_strings.hex ui_strattr.hex (the fields that change while it runs and the words they choose from),
ui_ports.vh ui_conn.vh ui_src.vh ui_defs.vh ui_pal.vh (the values the screen reads, the colours),
and sim/ui_demo.vh and build/ui_preview_480.png, _240.png (the screen with the #demo values).

Layout, 28 lines of 80 cells:
  <f=name> <b=name>   foreground / background colour for what follows (names in PALETTE)
  [[name:3d]]         a number of 3 digits, leading zeros blank       [[name:2z]]  leading zeros kept
  [[name:3dc]]        the same, green from 130 and red below (a speed in MHz)    [[name:1df]]  coloured like the last c number
  [[name:10dl]]       a number, left aligned
  [[name:3db]]        a number that is not drawn at all when it is 4294967295 (c, f, l and b can be combined)
  [[name:S10]]        one of the words #str name index text[|colour] in a field of 10 cells
                      a word ending in ^ is padded with cells that are not drawn (not with blanks), so a field laid over it can show
  [[name:M64s4]]      a map of 64 cells, one every 4 cells (s4 is optional); the name starts adr or dq
  [[name:3d@22]]      a field of any kind placed at cell 22 of the line, over what is there (it does not move the cells after it)
  [[name:3d@>]]       a field that starts at the cell after the last one written before it (after the words of a string that ends in ^)
  @rule top|mid|thin|bot   a line across the screen
  #str, #demo         words and demo values (not drawn)
A line starting with a box character is closed with one at the end.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fontlib  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
COLS, ROWS, STRIDE = 80, 28, 128

PALETTE = [  # name, rgb; the background of the screen is the first
    ('navy', (9, 14, 32)), ('title', (28, 58, 120)), ('text', (226, 233, 246)), ('dim', (128, 143, 175)),
    ('cyan', (84, 204, 236)), ('green', (74, 214, 112)), ('red', (244, 84, 84)), ('amber', (252, 192, 64)),
    ('grey', (66, 77, 100)), ('border', (62, 94, 156)),
]
PAL = {n: i for i, (n, _) in enumerate(PALETTE)}
DEFAULT_FG, DEFAULT_BG = PAL['text'], PAL['navy']
RULE = {'top': ('╔', '═', '╗'), 'mid': ('╠', '═', '╣'), 'thin': ('╟', '─', '╢'), 'bot': ('╚', '═', '╝')}
KIND = {'d': 0, 'z': 1, 'S': 2, 'M': 3}
NUMFLAG = {'c': 1, 'f': 2, 'l': 4, 'b': 8}
FOLLOW = -1                                  # the place of a field that starts after the last cell written (address 0xFFF)
MAPKIND = {'adr': 1, 'dq': 2}


def die(msg):
    sys.exit('layout: ' + msg)


def place(s):
    return None if s is None else FOLLOW if s == '>' else int(s)


def tokens(ln):
    """The pieces of a layout line: ('text', ch) | ('fg', i) | ('bg', i) | ('field', dict)."""
    out = []
    i = 0
    while i < len(ln):
        m = re.match(r'<([fb])=([a-z]+)>', ln[i:])
        if m:
            if m.group(2) not in PAL:
                die('no colour %s' % m.group(2))
            out.append(('fg' if m.group(1) == 'f' else 'bg', PAL[m.group(2)]))
            i += m.end()
            continue
        m = re.match(r'\[\[([a-z0-9_]+):(\d+)([dz])([cflb]*)(?:@(\d+|>))?\]\]', ln[i:])
        if m:
            aux = sum(NUMFLAG[ch] for ch in set(m.group(4)))
            out.append(('field', dict(name=m.group(1), kind=m.group(3), width=int(m.group(2)), aux=aux, span=int(m.group(2)),
                                      at=place(m.group(5)))))
            i += m.end()
            continue
        m = re.match(r'\[\[([a-z0-9_]+):([SM])(\d+)(?:s(\d+))?(?:@(\d+|>))?\]\]', ln[i:])
        if m:
            width, stride = int(m.group(3)), int(m.group(4) or 1)
            span = width if m.group(2) == 'S' else (width - 1) * stride + 1
            out.append(('field', dict(name=m.group(1), kind=m.group(2), width=width, aux=stride, span=span,
                                      at=place(m.group(5)))))
            i += m.end()
            continue
        out.append(('text', ln[i]))
        i += 1
    return out


def parse(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    cells = [[(' ', DEFAULT_FG, DEFAULT_BG) for _ in range(COLS)] for _ in range(ROWS)]
    fields, strings, demo = [], {}, {}
    row = 0
    for ln in lines:
        if ln.startswith('//'):
            continue
        if ln.startswith('#str '):
            mm = re.match(r'#str (\S+) (\d+)(?: (.*))?$', ln)
            name, idx, text = mm.group(1), mm.group(2), mm.group(3) or ''
            colour = None
            if '|' in text:
                text, colour = text.rsplit('|', 1)
                if colour not in PAL:
                    die('no colour %s' % colour)
            skip = text.endswith('^')
            strings.setdefault(name, {})[int(idx)] = (text[:-1] if skip else text, colour, skip)
            continue
        if ln.startswith('#demo '):
            _, name, val = ln.split(' ', 2)
            demo[name] = val
            continue
        if ln.startswith('#'):
            continue
        if row >= ROWS:
            if ln.strip():
                die('more than %d lines' % ROWS)
            continue
        if ln.startswith('@rule '):
            left, mid, right = RULE[ln.split()[1]]
            for c, ch in enumerate(left + mid * (COLS - 2) + right):
                cells[row][c] = (ch, PAL['border'], DEFAULT_BG)
            row += 1
            continue
        boxed = bool(ln) and ln[0] in fontlib.BOX
        limit = COLS - 1 if boxed else COLS            # a boxed line keeps its last cell for the closing edge
        fg, bg, col = DEFAULT_FG, DEFAULT_BG, 0
        touched = set()
        for t in tokens(ln):
            if t[0] == 'bg':
                bg = t[1]
            elif t[0] == 'fg':
                fg = t[1]
            elif t[0] == 'field':
                at = t[1]['at']
                fd = dict(t[1], row=row, col=col if at is None else at, fg=fg, bg=bg)
                fields.append(fd)
                if at != FOLLOW:
                    if fd['col'] + fd['span'] > limit:
                        die('row %d: field %s runs off the line' % (row, fd['name']))
                    for c in range(fd['col'], fd['col'] + fd['span']):
                        cells[row][c] = (' ', fg, bg)
                        touched.add(c)
                if at is None:
                    col += fd['span']
            else:
                if col >= COLS:
                    die('row %d is longer than %d cells' % (row, COLS))
                cells[row][col] = (t[1], fg, bg)
                touched.add(col)
                col += 1
        if boxed:
            for c in range(1, COLS - 1):               # what the line left alone takes the colour it ended in
                if c not in touched:
                    cells[row][c] = (' ', DEFAULT_FG, bg)
            cells[row][0] = (cells[row][0][0], PAL['border'], DEFAULT_BG)
            cells[row][COLS - 1] = ('║', PAL['border'], DEFAULT_BG)
        row += 1
    return cells, fields, strings, demo


def build(cells, fields, strings):
    """Glyph codes (ASCII as it is, the rest from 0x80), the screen and the tables of the fields."""
    codes = {}
    for r in cells:
        for ch, f, b in r:
            if ord(ch) > 0x7E and ch not in codes:
                if fontlib.graphics_glyph(ch, 16) is None:
                    die('no glyph for %r' % ch)
                codes[ch] = 0x80 + len(codes)
    if fontlib.CELL not in codes:
        codes[fontlib.CELL] = 0x80 + len(codes)
    f16, f8 = fontlib.load_psf2('lat1-16'), fontlib.load_psf2('lat1-08')

    def font_rows(font, h):
        out = [font[code] if 0x20 <= code <= 0x7E else [0] * h for code in range(256)]
        for ch, code in codes.items():
            out[code] = fontlib.graphics_glyph(ch, h)
        return out

    char = [0x20] * (ROWS * STRIDE)
    attr = [(DEFAULT_BG << 4) | DEFAULT_FG] * (ROWS * STRIDE)
    for r in range(ROWS):
        for c in range(COLS):
            ch, f, b = cells[r][c]
            char[r * STRIDE + c] = codes.get(ch, ord(ch)) if ord(ch) > 0x7E else ord(ch)
            attr[r * STRIDE + c] = (b << 4) | f
    sbytes, sattr, ops, srcs = [], [], [], []
    for fd in fields:
        if fd['name'] not in srcs:
            srcs.append(fd['name'])
    for fd in fields:
        aux = fd['aux']
        if fd['kind'] == 'S':
            tab = strings.get(fd['name'])
            if not tab:
                die('no #str for %s' % fd['name'])
            aux = len(sbytes)
            for idx in range(max(tab) + 1):
                t, colour, skip = tab.get(idx, ('', None, False))
                if len(t) > fd['width']:
                    die('#str %s %d is longer than its field (%d)' % (fd['name'], idx, fd['width']))
                sbytes += [ord(x) for x in t] + [0 if skip else 0x20] * (fd['width'] - len(t))
                sattr += [(fd['bg'] << 4) | (PAL[colour] if colour else fd['fg'])] * fd['width']
        elif fd['kind'] == 'M':
            mk = next((v for k, v in MAPKIND.items() if fd['name'].startswith(k)), None)
            if mk is None:
                die('map %s must start with adr or dq' % fd['name'])
            aux = (mk << 8) | fd['aux']                # map kind and stride
        addr = 0xFFF if fd['at'] == FOLLOW else fd['row'] * STRIDE + fd['col']
        # kind[39:36] src[35:30] addr[29:18] width[17:11] aux[10:0]
        ops.append((KIND[fd['kind']] << 36) | (srcs.index(fd['name']) << 30) | (addr << 18) | (fd['width'] << 11) | aux)
    if len(ops) > 64:
        die('more than 64 fields')
    if len(sbytes) >= 2048:
        die('string table too big')
    return codes, font_rows(f16, 16), font_rows(f8, 8), char, attr, ops, sbytes, sattr, srcs


def is_map(name):
    return name.startswith(tuple(MAPKIND))


def emit(out_dir, codes, font16, font8, char, attr, ops, sbytes, sattr, srcs, demo):
    def hexfile(name, values, digits):
        with open(os.path.join(out_dir, name), 'w', newline='\n') as f:
            for v in values:
                f.write(('%0' + str(digits) + 'X\n') % v)

    def vfile(name, text):
        with open(os.path.join(out_dir, name), 'w', newline='\n') as f:
            f.write(text)

    sim = os.path.join(out_dir, '..', 'sim')
    os.makedirs(sim, exist_ok=True)
    with open(os.path.join(sim, 'ui_demo.vh'), 'w', newline='\n') as f:
        f.write('// made by tools/make_ui.py: the #demo values of the layout, as the signals the screen reads\n')
        for n in srcs:
            v = demo.get(n, '0')
            if is_map(n):
                bits = 0
                for i, ch in enumerate(v):
                    bits |= int(ch) << (2 * i)
                f.write("reg [127:0] v_%s = 128'h%032X;\n" % (n, bits))
            else:
                f.write("reg [31:0] v_%s = 32'd%d;\n" % (n, int(v or 0)))
    hexfile('font16.hex', [b for g in font16 for b in g], 2)
    hexfile('font8.hex', [b for g in font8 for b in g], 2)
    hexfile('ui_char.hex', char + [0x20] * (4096 - len(char)), 2)
    hexfile('ui_attr.hex', attr + [(DEFAULT_BG << 4) | DEFAULT_FG] * (4096 - len(attr)), 2)
    hexfile('ui_ops.hex', ops + [0] * (64 - len(ops)), 10)
    hexfile('ui_strings.hex', sbytes + [0x20] * (2048 - len(sbytes)), 2)
    hexfile('ui_strattr.hex', sattr + [(DEFAULT_BG << 4) | DEFAULT_FG] * (2048 - len(sattr)), 2)
    vfile('ui_conn.vh', '// made by tools/make_ui.py\n' + ''.join('\t.v_%s(v_%s),\n' % (n, n) for n in srcs))
    vfile('ui_ports.vh', '// made by tools/make_ui.py: the values the screen shows (maps are 2 bits a cell)\n'
          + ''.join('\tinput [%d:0] v_%s,\n' % (127 if is_map(n) else 31, n) for n in srcs))
    vfile('ui_src.vh', '// made by tools/make_ui.py: which signal each field reads\nlocalparam UI_OPS = %d;\nalways @* begin\n\tui_val = 128\'d0;\n\tcase (ui_src)\n' % len(ops)
          + ''.join(("\t\t%d: ui_val = v_%s;\n" if is_map(n) else "\t\t%d: ui_val = {96'd0, v_%s};\n") % (i, n) for i, n in enumerate(srcs))
          + "\t\tdefault: ui_val = 128'd0;\n\tendcase\nend\n")
    vfile('ui_pal.vh', '// made by tools/make_ui.py\nfunction automatic [23:0] ui_pal(input [3:0] i);\n\tcase (i)\n'
          + ''.join("\t\t4'd%d: ui_pal = 24'h%02X%02X%02X; // %s\n" % (i, r, g, b, n) for i, (n, (r, g, b)) in enumerate(PALETTE))
          + "\t\tdefault: ui_pal = 24'h000000;\n\tendcase\nendfunction\n")
    vfile('ui_defs.vh', '// made by tools/make_ui.py\nlocalparam [7:0] UI_G_CELL = 8\'h%02X;\n' % codes[fontlib.CELL]
          + ''.join("localparam [3:0] UI_C_%s = 4'd%d;\n" % (n.upper(), PAL[n]) for n in ('grey', 'green', 'red')))


def preview(cells, fields, strings, demo, codes, font16, font8, h, path):
    from PIL import Image
    font = font16 if h == 16 else font8
    img = Image.new('RGB', (720, 480 if h == 16 else 240), (0, 0, 0))
    y0 = (img.size[1] - ROWS * h) // 2
    cell = [[list(c) for c in r] for r in cells]
    hot = False
    cur = (0, 0)                                   # the cell after the last one written, where a field with @> starts
    for fd in fields:
        v = demo.get(fd['name'], '')
        r, c = cur if fd['at'] == FOLLOW else (fd['row'], fd['col'])
        if fd['kind'] in 'dz':
            n = int(v or 0)
            if n == 0xFFFFFFFF and fd['aux'] & 8:
                continue
            s = ('%0*d' if fd['kind'] == 'z' else '%*d') % (fd['width'], n)
            if n == 0xFFFFFFFF:
                s = '-' * fd['width']
            elif fd['aux'] & 4:
                s = s.strip().ljust(fd['width'])
            for i, ch in enumerate(s[-fd['width']:]):
                cell[r][c + i][0] = ch
                if fd['aux'] & 1 and n != 0xFFFFFFFF:
                    hot = n >= 130
                if fd['aux'] & 3 and n != 0xFFFFFFFF:
                    cell[r][c + i][1] = PAL['green'] if hot else PAL['red']
            cur = (r, c + fd['width'])
        elif fd['kind'] == 'S':
            t, colour, skip = strings[fd['name']].get(int(v or 0), ('', None, False))
            text = t if skip else t.ljust(fd['width'])
            for i, ch in enumerate(text):
                cell[r][c + i][0] = ch
                if colour:
                    cell[r][c + i][1] = PAL[colour]
            if text:
                cur = (r, c + len(text))
        else:
            dq = fd['name'].startswith('dq')
            for i in range(fd['width']):
                st = int(v[i]) if i < len(v) else 0
                colour = ('green' if st == 0 else 'red') if dq else ('grey', 'green', 'red')[min(st, 2)]
                cc = c + i * fd['aux']
                cell[r][cc][0] = fontlib.CELL
                cell[r][cc][1] = PAL[colour]
    for r in range(ROWS):
        for c in range(COLS):
            ch, f, b = cell[r][c]
            g = font[codes.get(ch, ord(ch)) if ord(ch) > 0x7E else ord(ch)]
            fgc, bgc = PALETTE[f][1], PALETTE[b][1]
            for y in range(h):
                for x in range(8):
                    img.putpixel((40 + c * 8 + x, y0 + r * h + y), fgc if (g[y] >> (7 - x)) & 1 else bgc)
    img.save(path)


def main():
    cells, fields, strings, demo = parse(os.path.join(ROOT, 'ui', 'layout.txt'))
    codes, f16, f8, char, attr, ops, sbytes, sattr, srcs = build(cells, fields, strings)
    emit(os.path.join(ROOT, 'rtl'), codes, f16, f8, char, attr, ops, sbytes, sattr, srcs, demo)
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    preview(cells, fields, strings, demo, codes, f16, f8, 16, os.path.join(ROOT, 'build', 'ui_preview_480.png'))
    preview(cells, fields, strings, demo, codes, f16, f8, 8, os.path.join(ROOT, 'build', 'ui_preview_240.png'))
    print('%d fields, %d glyphs of graphics, %d string bytes' % (len(fields), len(codes), len(sbytes)))


if __name__ == '__main__':
    main()

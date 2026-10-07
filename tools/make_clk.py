#!/usr/bin/env python3
"""Makes rtl/clk_steps.sv from the PLL settings of the original MemTest core (the 64 clocks it steps through, 167 MHz down to 45 MHz).
The values (the PLL's M and K counters and its C divider) are the original's, which are known to work; what is added is the clock
in tenths of a MHz, for the screen.

Usage: make_clk.py path/to/MemTest_MiSTer/memtest.sv   (github.com/MiSTer-devel/MemTest_MiSTer)"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) != 2:
    sys.exit(__doc__)
SRC = sys.argv[1]
OUT = os.path.join(HERE, '..', 'rtl', 'clk_steps.sv')

text = open(SRC, encoding='utf-8').read()
table = text[text.index("'{ //      M         K          C"):]
table = table[:table.index('};')]
rows = re.findall(r"'h([0-9A-Fa-f]+),\s*'h([0-9A-Fa-f]+),\s*'h([0-9A-Fa-f]+),\s*'h([0-9A-Fa-f]+)", table)
if len(rows) != 64:
    sys.exit('expected 64 clock steps, found %d' % len(rows))


def tenths(code):
    """The original writes the clock in BCD hex: 'h167 is 167 MHz, 'h90 is 90 MHz, 'h625 is 62.5 MHz."""
    digits = code.upper()
    if digits == '625':
        return 625
    return int(digits) * 10


f10 = [tenths(r[0]) for r in rows]
assert f10 == sorted(f10, reverse=True), 'the steps are not in falling order'
with open(OUT, 'w', newline='\n') as f:
    f.write('// made by tools/make_clk.py from the original MemTest core\'s table: the 64 clocks of the SDRAM test, 167 MHz down to 45 MHz.\n')
    f.write('// freq10 is the clock in tenths of a MHz; m, k and c are the PLL settings that make it (the PLL is reconfigured with them).\n')
    f.write('module clk_steps\n(\n\tinput       [5:0] pos,\n\toutput reg [11:0] freq10,\n\toutput reg [31:0] m,\n\toutput reg [31:0] k,\n\toutput reg [31:0] c\n);\n\n')
    f.write('always @* begin\n\tcase (pos)\n')
    for i, (code, m, k, c) in enumerate(rows):
        label = "6'd%d" % i if i < 63 else 'default'        # the last step is the default: that covers all 64 values of pos
        f.write("\t\t%s: begin freq10 = 12'd%d; m = 32'h%s; k = 32'h%s; c = 32'h%s; end\n" % (label, f10[i], m, k, c))
    f.write('\tendcase\nend\n\nendmodule\n')
print('64 steps, %.1f MHz down to %.1f MHz' % (f10[0] / 10, f10[-1] / 10))

#!/usr/bin/env python3
"""Makes sim/tb_top_ports.vh (a declaration of every port of the core's top level) and sim/tb_top_conn.vh (the connections),
from sys/emu_ports.vh, so that the testbench of the whole core does not need the list typed out."""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'sys', 'emu_ports.vh')
OUT = os.path.join(HERE, '..', 'sim')

ports = []
depth = 0
for raw in open(SRC, encoding='utf-8').read().splitlines():
    line = raw.split('//')[0].strip()
    if not line:
        continue
    if line.startswith('`ifdef') or line.startswith('`ifndef'):
        depth += 1
        continue
    if line.startswith('`endif'):
        depth -= 1
        continue
    if depth:
        continue            # (the optional features are not defined)
    m = re.match(r'(input|output|inout)\s*(\[[^\]]+\])?\s*(\w+)\s*,?$', line)
    if not m:
        raise SystemExit('cannot read: ' + raw)
    ports.append((m.group(1), m.group(2) or '', m.group(3)))

with open(os.path.join(OUT, 'tb_top_ports.vh'), 'w', newline='\n') as f:
    f.write('// made by tools/gen_sim_ports.py\n')
    for d, w, n in ports:
        if n in ('CLK_50M', 'RESET'):
            continue            # (the testbench declares these itself)
        f.write('wire %s %s%s;\n' % (w, n, ' = 0' if d == 'input' else ''))
with open(os.path.join(OUT, 'tb_top_conn.vh'), 'w', newline='\n') as f:
    f.write('// made by tools/gen_sim_ports.py\n')
    f.write(',\n'.join('\t.%s(%s)' % (n, n) for d, w, n in ports) + '\n')
print(len(ports), 'ports')

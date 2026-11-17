#!/usr/bin/env python3
"""handasm.py OBJ:SYMREGEX ... -- the instructions and bytes of hand-written assembly functions, from object files (NASM x86-64, clang for AArch64 and RISC-V).

usage: handasm.py [-q] ISA=OBJECT:REGEX ...        e.g.  x86=/tmp/x/float_dsp.o:ff_vector_fmac_scalar_(sse|avx|fma3)$

A function runs from its global symbol to the next global symbol of the object (labels with a dot in the name, the local labels of NASM's x86inc, are inside the
function).  Prints isa, symbol, instructions, bytes.  Used for docs/encoding-work/vec-forms.md."""
import re, subprocess, sys
def sh(c): return subprocess.run(c, capture_output=True, text=True, errors='replace').stdout
for arg in sys.argv[1:]:
    if arg.startswith('-'): continue
    isa, rest = arg.split('=', 1)
    obj, rx = rest.rsplit(':', 1)
    syms = []
    for ln in sh(['llvm-readelf-21', '-sW', obj]).split('\n'):
        m = re.match(r'\s*\d+:\s+([0-9a-f]+)\s+(\d+)\s+(FUNC|NOTYPE)\s+(GLOBAL|LOCAL)\s+\S+\s+(\S+)\s+(\S+)', ln)
        if m and m.group(5) not in ('UND', 'ABS') and m.group(6) and not m.group(6).startswith('$'):
            syms.append((int(m.group(1), 16), m.group(4), m.group(6), int(m.group(2))))
    ins = []
    for ln in sh(['llvm-objdump-21', '-d', '--no-show-raw-insn', obj]).split('\n'):
        m = re.match(r'\s*([0-9a-f]+):\s+(\S+)', ln)
        if m: ins.append(int(m.group(1), 16))
    ins.sort()
    glob = sorted(set(s[0] for s in syms if s[1] == 'GLOBAL' and '.' not in s[2].lstrip('_')))
    end = ins[-1] + 1 if ins else 0
    for a, b, name, sz in sorted(set(syms)):
        if b != 'GLOBAL' or not re.search(rx, name): continue
        nxt = [g for g in glob if g > a]
        e = nxt[0] if nxt else end + 16
        n = sum(1 for x in ins if a <= x < e)
        by = (sz if sz else e - a) if isa.startswith(('a64', 'rv')) else e - a
        print('%s\t%s\t%d\t%d' % (isa, name, n, by))

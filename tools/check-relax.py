#!/usr/bin/env python3
"""Join the assembler's instruction offsets (as64 --dump-lens FILE.s.lens) with the linker's map (ld64 --dump-map) into the list of instruction start
addresses of the linked executable (for tools/relaxcheck).
usage: check-relax.py MAP LENS_PREFIX_OF_OBJECT... > starts.txt      where the objects are named in MAP and OBJ.lens is next to OBJ."""
import sys, bisect
mp = sys.argv[1]
secs = {}
cur = None
for line in open(mp):
    w = line.split()
    if w[0] == 'S':
        cur = dict(name=w[1], idx=int(w[2]), base=int(w[3], 16), size=int(w[4]), now=int(w[5]), ends=[], cum=[0])
        secs[(w[1], int(w[2]))] = cur
    else:
        off, l0, l1 = int(w[1]), int(w[2]), int(w[3])
        cur['ends'].append(off + l0)
        cur['cum'].append(cur['cum'][-1] + l1 - l0)
out = []
for (name, idx), s in secs.items():
    if idx != 1:                      # the assembler's .text is section 1
        continue
    try:
        lens = open(name + '.lens')
    except OSError:
        continue
    for line in lens:
        _, n, off = line.split()
        off = int(off)
        k = bisect.bisect_right(s['ends'], off)
        out.append(s['base'] + off + s['cum'][k])
out.sort()
print('\n'.join('%x' % a for a in out))

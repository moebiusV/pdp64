#!/usr/bin/env python3
"""normlog.py MAP < LOG > NORMALISED: the log of tests/sim-enc/diff.s is a sequence of little-endian 64-bit words.  A word that points into the program
(the text, data or bss of this link) differs between the encodings by construction; it is replaced by the section and the offset in it (text: only the
section, since the instruction lengths differ).  Everything else is copied."""
import sys, re, struct
secs = []
for l in open(sys.argv[1]):
    m = re.match(r'^(text|data|bss)\s+0x([0-9a-f]+)\s+\+0x([0-9a-f]+)', l)
    if m: secs.append((m.group(1), int(m.group(2), 16), int(m.group(3), 16)))
d = sys.stdin.buffer.read()
out = []
for (v,) in struct.iter_unpack('<Q', d[:len(d) // 8 * 8]):
    for i, (n, b, sz) in enumerate(secs):
        if b <= v < b + sz:
            v = (0xA000000000000000 + (i << 56)) | (0 if n == 'text' else v - b)
            break
    out.append(struct.pack('<Q', v))
sys.stdout.buffer.write(b''.join(out) + d[len(d) // 8 * 8:])

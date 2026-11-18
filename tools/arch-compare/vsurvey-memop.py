#!/usr/bin/env python3
"""memop.py ROOT -- for NASM x86 vector arithmetic instructions of dav1d and FFmpeg: how many have a memory source operand (a '[' in the operands)
and are not plain loads/stores/moves.  Source lines, macros counted once."""
import re, sys, glob, collections
root = sys.argv[1]
pats = ['dav1d/src/x86/*.asm', 'FFmpeg/libavcodec/x86/**/*.asm', 'FFmpeg/libavutil/x86/*.asm', 'FFmpeg/libswscale/x86/*.asm', 'libjpeg-turbo/simd/x86_64/*.asm']
mv = re.compile(r'^(mova|movu|movd|movq|movh|movl|movdqa|movdqu|movaps|movups|vmov\w*|vbroadcast\w*|vpbroadcast\w*|movntdq\w*|lddqu|movddup|movhps|movlps|movss|movsd|vinserti\w+|vinsertf\w+|vextract\w+|kmov\w+)$')
vec = re.compile(r'^(v?p[a-z0-9]+|v?(add|sub|mul|min|max|and|or|xor|div|sqrt|fmadd|fnmadd|fmsub|shuf|unpck|cvt|hadd|blend|round|rcp|rsqrt)\w*(ps|pd|ss|sd)|vp\w+|fmadd\w+)$')
tot = mem = 0; byop = collections.Counter(); byop_mem = collections.Counter()
for p in pats:
    for f in glob.glob(root + '/' + p, recursive=True):
        for ln in open(f, errors='replace'):
            ln = re.sub(r';.*', '', ln).strip()
            m = re.match(r'(?:[\w.$@]+:\s*)?([a-z][a-z0-9_]*)\s+(.*)$', ln)
            if not m: continue
            op, args = m.group(1), m.group(2)
            if not vec.match(op) or mv.match(op) or op in ('pop', 'push', 'prefetchnta', 'popcnt', 'pause'): continue
            tot += 1; byop[op] += 1
            if '[' in args: mem += 1; byop_mem[op] += 1
print('vector arithmetic/shuffle instruction lines', tot, 'with a memory operand', mem, '%.1f%%' % (100.0*mem/tot))
for op, n in byop.most_common(14): print('  %-12s %5d  mem %5d  %.0f%%' % (op, n, byop_mem[op], 100.0*byop_mem[op]/n))

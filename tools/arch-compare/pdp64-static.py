#!/usr/bin/env python3
"""pdp64-static.py -- static size of the corpus for pdp64 exactly as tools/pdp64size.py does it (the compiler is build/pcc/ccom of tools/build-pcc.sh):
ccom on the aarch64-preprocessed text, as64 --stats, instruction count and instruction bytes from as64's statistics line,
.text bytes of the object (instructions + constant pools + padding).
There is one machine, so no target is named (the earlier iterations were measured with the tools of the git tag pre-single-cpu).
usage: pdp64-static.py INDIR OUTDIR CCOM AS64 [-j N]      writes OUTDIR/static.csv (nnn,status,ins,ibytes,text,cbcc_expanded,msg)
"""
import os, re, sys, struct, subprocess, tempfile, concurrent.futures as cf
indir, out, ccom, as64 = sys.argv[1:5]
jobs = int(sys.argv[6]) if len(sys.argv) > 6 else 8
os.makedirs(out, exist_ok=True)
def text_bytes(obj):
    d = open(obj, 'rb').read()
    shoff, = struct.unpack_from('<Q', d, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3A)
    sh = [struct.unpack_from('<IIQQQQ', d, shoff + i * shentsize) for i in range(shnum)]
    so = sh[shstrndx][4]
    for s in sh:
        e = d.index(b'\0', so + s[0])
        if d[so + s[0]:e] == b'.text':
            return s[5]
    return 0
def one(n):
    with tempfile.TemporaryDirectory() as w:
        s, o = w + '/x.s', w + '/x.o'
        try:
            p = subprocess.run([ccom, '%s/%s.i' % (indir, n), s], capture_output=True, text=True, errors='replace', timeout=120)
        except subprocess.TimeoutExpired:
            return [n, 'fail', 0, 0, 0, 0, 'ccom timeout']
        if p.returncode or not os.path.exists(s):
            m = [x for x in (p.stderr or p.stdout).strip().split('\n') if x.strip() and 'warning' not in x]
            return [n, 'fail', 0, 0, 0, 0, 'ccom: ' + (m[0] if m else 'exit %d' % p.returncode)[:150].replace(',', ';')]
        q = subprocess.run([as64, '--stats', '-o', o, s], capture_output=True, text=True, errors='replace')
        if q.returncode:
            return [n, 'fail', 0, 0, 0, 0, 'as64: ' + (q.stderr.strip().split('\n') or [''])[0][:150].replace(',', ';')]
        m = re.search(r'(\d+) instructions, (\d+) bytes(?: \((\d+) cbCC expanded)?', q.stderr)
        return [n, 'ok', int(m.group(1)), int(m.group(2)), text_bytes(o), int(m.group(3) or 0), '']
names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
with cf.ThreadPoolExecutor(jobs) as ex, open(out + '/static.csv', 'w') as f:
    f.write('file,status,ins,ibytes,text,cbcc_expanded,msg\n')
    for r in ex.map(one, names):
        f.write(','.join(str(x) for x in r) + '\n')

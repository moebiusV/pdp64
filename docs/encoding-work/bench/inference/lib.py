#!/usr/bin/env python3
"""lib.py: the harness of the inference study.  A program is a list of assembly lines plus the bytes the program must write to standard output; build() assembles and links it,
sim() runs it under sim64 -V at a strip and returns the model-1 and model-2 totals, and run() checks the output.  Everything runs in a scratch directory (TOOLS=dir with as64 ld64
sim64, a copy of build/), and nothing under the repository is touched."""
import os, re, struct, subprocess, tempfile, random
import numpy as np
T = os.environ.get('TOOLS', '/tmp/claude-1000/-home-matthew-claude-pdp64/832cbac5-5e29-461e-9610-ca42cce0b602/scratchpad/inf/bin')
CRT = ['\t.text', '\t.globl\t_start', '_start:', '\tcall\tmain', '\ttrap\t#0']

def rng(seed=1):
    return np.random.RandomState(seed)
def f32bits(a): return np.asarray(a, dtype=np.float32).view(np.uint32)
def bits32f(u): return np.asarray(u, dtype=np.uint32).view(np.float32)
def to_bf16(a):
    """binary32 -> bfloat16 bits, round to nearest even; a NaN stays a quiet NaN"""
    u = f32bits(a).astype(np.uint64)
    nan = (u & 0x7fffffff) > 0x7f800000
    r = ((u + 0x7fff + ((u >> 16) & 1)) >> 16) & 0xffff
    q = ((u >> 16) | 0x40) & 0xffff
    return np.where(nan, q, r).astype(np.uint16)
def from_bf16(h): return bits32f(np.asarray(h, dtype=np.uint32) << 16)
def data(name, arr, align=16):
    """emit an array as .byte/.short/.long lines"""
    arr = np.asarray(arr)
    fmt = {1: '.byte', 2: '.word', 4: '.long', 8: '.quad'}[arr.dtype.itemsize]
    flat = arr.reshape(-1)
    if arr.dtype.kind == 'f': flat = flat.view({4: np.uint32, 8: np.uint64}[arr.dtype.itemsize])
    out = ['\t.data', '\t.align %d' % align, name + ':']
    per = 16 if arr.dtype.itemsize <= 2 else 8
    for i in range(0, len(flat), per):
        out.append('\t%s\t%s' % (fmt, ','.join(str(int(v)) for v in flat[i:i + per])))
    return out
def bss(name, nbytes, align=16): return ['\t.data', '\t.align %d' % align, name + ':', '\t.space %d' % nbytes]

def sh(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode and not kw.get('ok'): raise SystemExit('%s failed: %s' % (cmd[0], (r.stderr or r.stdout)[:1500]))
    return r
def build(lines, d):
    s = d + '/p.s'; open(s, 'w').write('\n'.join(lines) + '\n')
    sh([T + '/as64', '-o', d + '/p.o', s]); sh([T + '/ld64', '-o', d + '/p.x', d + '/p.o'])
    return d + '/p.x'
def sim(x, strip=32, port=16, extra=()):
    r = subprocess.run([T + '/sim64', '-V', '-P', x + '.prof', '-S', str(strip), '--vport=%d' % port, '--vcommit=1'] + list(extra) + [x], capture_output=True)
    e = r.stderr.decode('utf-8', 'replace'); o = {'out': r.stdout, 'rc': r.returncode, 'e': e[:500]}
    m1 = re.search(r'vec model strip (\d+) port (\d+) commit (\d+): scalar (\d+) vector (\d+) \(compute (\d+) memory (\d+) memory-bound strips (\d+)\) total (\d+)', e)
    m2 = re.search(r'vec model2 latency (\w+).*?scalar (\d+) vector (\d+).*?total (\d+)', e)
    mc = re.search(r'vec blocks (\d+) strips (\d+) ops (\d+) elems (\d+)', e)
    if m1: o.update(scalar=int(m1.group(4)), vector=int(m1.group(5)), m1=int(m1.group(9)))
    if m2: o['m2'] = int(m2.group(4))
    if mc: o.update(blocks=int(mc.group(1)), strips=int(mc.group(2)), vops=int(mc.group(3)))
    if not m1: o['err'] = e[-400:]
    return o
def frame(body, datalines, outsym, outbytes):
    """_start; main = body (the lines that set the registers and call the kernel); then write outsym"""
    L = list(CRT) + ['main:'] + body
    L += ['\tmov\t#1,r0', '\tlea\t%s,r1' % outsym, '\tmov\t#%d,r2' % outbytes, '\ttrap\t#1', '\tclr\tr0', '\tret']
    return L + ['\t.text'] + [] + datalines
def measure(name, lines, expect, check, strips=(16, 32, 64), base=None, extra=()):
    """run at each strip; check(out_bytes) -> (ok, note).  returns {strip: dict}"""
    res = {}
    with tempfile.TemporaryDirectory() as d:
        x = build(lines, d)
        for s in strips:
            o = sim(x, s, extra=extra)
            ok, note = check(o['out']) if ('m1' in o and o['rc'] == 0) else (False, 'sim failed rc=%d: %s' % (o['rc'], o['e']))
            o['ok'] = ok; o['note'] = note; res[s] = o
    return res

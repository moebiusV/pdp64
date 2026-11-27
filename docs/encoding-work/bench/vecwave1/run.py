#!/usr/bin/env python3
"""run.py KERNEL VARIANT [--strip S --port P ...]: build driver.c + a kernel and run it under sim64 -V -P.
VARIANT: scalar | lv (LoopVectorize, vec blocks) | path/to/hand.s (assembly kernel; the C kernel is not linked).
Environment: TOOLS (dir with as64 ld64 sim64 llc opt, default ./bin), CLANG.  Prints one JSON line:
 pinsn (instructions executed, a vec block counts one), vops (vector instructions, one per strip), model1 total, model2 total, output hash."""
import os, re, sys, subprocess, tempfile, json
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.environ.get('TOOLS', os.path.join(HERE, 'bin'))
CF = ['-O2', '-m64', '-fno-builtin-memset', '-fno-builtin-memcpy', '-fno-stack-protector', '-mlong-double-64', '-mno-sse', '-mno-mmx', '-ffp-contract=fast',
      '-ffast-math', '-w', '-S', '-emit-llvm']
CRT = """	.text
	.globl	_start
_start:	call	main
	trap	#0
	.globl	write
write:	trap	#1
	ret
	.globl	memcpy
memcpy:	mov	r0, r3
	mcpy	r0, r1, r2
	mov	r3, r0
	ret
	.globl	memset
memset:	mov	r0, r3
	mset	r0, r1, r2
	mov	r3, r0
	ret
"""
def sh(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode and not kw.get('ok'): raise SystemExit('%s failed: %s' % (cmd[0], (r.stderr or r.stdout)[:600]))
    return r
def strip_ll(txt):
    txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M)
    return re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
def build(kernel, variant, tmp, define='K_'):
    tools = lambda n: os.path.join(T, n)
    open(tmp + '/crt.s', 'w').write(CRT); sh([tools('as64'), '-o', tmp + '/crt.o', tmp + '/crt.s'])
    def cc(src, out, vec, extra=()):
        sh(['clang'] + CF + list(extra) + (['-fno-vectorize', '-fno-slp-vectorize', '-fno-unroll-loops'] if not vec else ['-Xclang', '-disable-llvm-passes', '-fno-unroll-loops']) + ['-o', out + '.0', src])
        open(out + '.1', 'w').write(strip_ll(open(out + '.0').read()))
        if vec: sh([tools('opt'), '-mtriple=pdp64-unknown-elf', '-passes=default<O2>', '-S', out + '.1', '-o', out])
        else: os.replace(out + '.1', out)
        sh([tools('llc'), '-mtriple=pdp64-unknown-elf', '-O2', out, '-o', out[:-3] + '.s'])
        return out[:-3] + '.s'
    objs = []
    d = cc(HERE + '/driver.c', tmp + '/driver.ll', False, ['-D' + define + kernel] + [x for x in os.environ.get('DEFS', '').split() if x])
    if variant in ('scalar', 'lv'):
        k = cc(HERE + '/kern_only.c', tmp + '/kern.ll', variant == 'lv')
        srcs = [k, d]
    else:
        h = tmp + '/hand.s'; open(h, 'w').write('\t.text\n\t.globl\t%s\n' % kernel.replace('_pack', '') + open(variant).read()); srcs = [h, d]
    for s in srcs:
        sh([tools('as64'), '-o', s[:-2] + '.o', s]); objs.append(s[:-2] + '.o')
    sh([tools('ld64'), '-o', tmp + '/p.x', tmp + '/crt.o'] + objs)
    return tmp + '/p.x'
def sim(x, strip=32, port=16, commit=1, extra=()):
    r = subprocess.run([os.path.join(T, 'sim64'), '-V', '-P', x + '.prof', '-S', str(strip), '--vport=%d' % port, '--vcommit=%d' % commit] + list(extra) + [x], capture_output=True)
    e = r.stderr.decode('utf-8', 'replace'); o = {'rc': r.returncode, 'out': r.stdout.hex()}
    m = re.search(r'#?instructions\D*(\d+)', open(x + '.prof').read()) if os.path.exists(x + '.prof') else None
    m1 = re.search(r'vec model strip (\d+) port (\d+) commit (\d+): scalar (\d+) vector (\d+) \(compute (\d+) memory (\d+) memory-bound strips (\d+)\) total (\d+)', e)
    m2 = re.search(r'vec model2 latency (\w+).*?scalar (\d+) vector (\d+).*?total (\d+)', e)
    mc = re.search(r'vec blocks (\d+) strips (\d+) ops (\d+) elems (\d+)', e)
    if m1: o.update(scalar=int(m1.group(4)), vector=int(m1.group(5)), m1=int(m1.group(9)), comp=int(m1.group(6)), mem=int(m1.group(7)))
    if m2: o.update(m2=int(m2.group(4)))
    if mc: o.update(blocks=int(mc.group(1)), strips=int(mc.group(2)), vops=int(mc.group(3)), elems=int(mc.group(4)))
    if m: o['pinsn'] = int(m.group(1))
    return o, e
def measure(kernel, variant, strip=32, port=16, commit=1, extra=()):
    """kernel cost = run with the kernel minus run without (driver set-up)"""
    with tempfile.TemporaryDirectory() as t1, tempfile.TemporaryDirectory() as t2:
        x = build(kernel, variant, t1); xb = build('none', 'scalar', t2)
        a, ea = sim(x, strip, port, commit, extra); b, eb = sim(xb, strip, port, commit, extra)
        d = {k: a[k] - b[k] for k in a if isinstance(a[k], int) and k in b and k != 'rc'}
        d['out'] = a['out']; d['rc'] = a['rc']; d['text'] = os.path.getsize(x) if False else 0
        return d
if __name__ == '__main__':
    k, v = sys.argv[1], sys.argv[2]
    s = int(sys.argv[3]) if len(sys.argv) > 3 else 32
    print(json.dumps(measure(k, v, s)))

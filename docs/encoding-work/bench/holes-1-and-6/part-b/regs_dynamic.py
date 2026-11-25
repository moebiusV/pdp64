#!/usr/bin/env python3
"""Run compiled functions under sim64 and say which registers hold a changed value at the return.

For each function: a driver sets r6-r13 and r15-r31 to a distinct poison value (r0-r5 get the arguments), saves all registers except the stack pointer r14, calls the function,
saves all registers again and writes both copies to standard output; this script compares them.  A register that differs and is neither r0 (the result) nor callee-saved
(r8-r11, r13, r15, r24-r31) is one the function left holding a value of its own: what a kernel returning to the user would leak.  A callee-saved register that differs is
reported as an ABI violation (never seen).

usage: regs_dynamic.py WORKDIR BUILDDIR kern|corpus
  WORKDIR holds NAME.pcc.s and NAME.llvm.s (see compile_corpus.sh); BUILDDIR has as64, ld64, sim64.
"""
import sys, os, subprocess, struct, json, glob
CS = {8, 9, 10, 11, 13, 15} | set(range(24, 32))
SAVE = [i for i in range(32) if i != 14]
CRT = """	.text
	.globl	_start
	.globl	memcpy
memcpy:	movq	r0, r3
	mcpy	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memmove
memmove: movq	r0, r3
	mmov	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memset
memset:	movq	r0, r3
	mset	r0, r1, r2
	movq	r3, r0
	ret
	.globl	write
write:	trap	#1
	ret
"""
def driver(func, setup, extra_data=''):
    s = CRT.replace('\t.globl\t_start\n', '') + '\t.globl\t_start\n_start:\n'
    for i in list(range(6, 14)) + list(range(15, 32)):
        s += '\tmovq\t=0x5ec0de%04x%04x, r%d\n' % (i, i, i)
    s += setup
    for i in SAVE: s += '\tmovq\tr%d, ibuf+%d\n' % (i, 8 * i)
    s += '\tcall\t%s\n' % func
    for i in SAVE: s += '\tmovq\tr%d, obuf+%d\n' % (i, 8 * i)
    s += '\tmovq\t#1, r0\n\tlea\tibuf, r1\n\tmovq\t#512, r2\n\ttrap\t#1\n\tmovq\t#0, r0\n\ttrap\t#0\n'
    s += '\t.data\n\t.align\t8\nibuf:\t.space\t256\nobuf:\t.space\t256\nbuf1:\t.space\t512\nbuf2:\t.space\t512\n' + extra_data
    return s

# the calls of kern.c: (function, label, setup)
KERN = [
 ('sys_null', 'sys_null', ''),
 ('sys_getpid', 'sys_getpid', '\tlea\tbuf1, r0\n'),
 ('copyin_bytes', 'copyin_bytes 64 bytes', '\tlea\tbuf2, r0\n\tlea\tbuf1, r1\n\tmovq\t#64, r2\n'),
 ('copyin_bytes', 'copyin_bytes refused (kernel address)', '\tlea\tbuf2, r0\n\tmovq\t=0x10, r1\n\tmovq\t#64, r2\n'),
 ('copyout_words', 'copyout_words 64 bytes', '\tlea\tbuf2, r0\n\tlea\tbuf1, r1\n\tmovq\t#64, r2\n'),
 ('sys_dup', 'sys_dup bad descriptor', '\tmovq\t#70, r0\n'),
 ('sys_dup', 'sys_dup open descriptor', '\tlea\tbuf1, r1\n\tmovq\tr1, fdtab+24\n\tmovq\t#3, r0\n'),
 ('hash_lookup', 'hash_lookup miss', '\tmovq\t=12345, r0\n'),
 ('checksum', 'checksum 100 bytes', '\tlea\tbuf1, r0\n\tmovq\t#100, r1\n'),
 ('crc32', 'crc32 100 bytes', '\tlea\tbuf1, r0\n\tmovq\t#100, r1\n'),
 ('chacha_block', 'chacha_block', '\tlea\tbuf1, r0\n'),
 ('dispatch', 'dispatch -> sys_null', '\tmovq\t#0, r0\n'),
 ('dispatch', 'dispatch -> checksum', '\tmovq\t#4, r0\n\tlea\tbuf1, r1\n\tmovq\t#100, r2\n'),
 ('dispatch', 'dispatch -> copyin', '\tmovq\t#5, r0\n\tlea\tbuf2, r1\n\tlea\tbuf1, r2\n\tmovq\t#32, r3\n'),
]
def run(work, bld, comp, name, func, setup, tag, quiet=False):
    d = os.path.join(work, 'dyn'); os.makedirs(d, exist_ok=True)
    base = os.path.join(d, '%s.%s.%s' % (name, comp, tag))
    open(base + '.drv.s', 'w').write(driver(func, setup))
    try:
        for src, out in ((base + '.drv.s', base + '.drv.o'), (os.path.join(work, '%s.%s.s' % (name, comp)), base + '.fn.o')):
            subprocess.run([os.path.join(bld, 'as64'), '-o', out, src], check=True, capture_output=True)
        subprocess.run([os.path.join(bld, 'ld64'), '-o', base + '.x', base + '.drv.o', base + '.fn.o'], check=True, capture_output=True)
        r = subprocess.run([os.path.join(bld, 'sim64'), base + '.x'], capture_output=True, timeout=60)
    except Exception as e:
        return {'error': str(e)[:200]}
    if len(r.stdout) < 512: return {'error': 'no output (rc %d)' % r.returncode}
    a = struct.unpack('<32Q', r.stdout[:256]); b = struct.unpack('<32Q', r.stdout[256:512])
    changed = [i for i in SAVE if a[i] != b[i]]
    dirty = [i for i in changed if i != 0 and i not in CS]
    return {'changed': changed, 'dirty': dirty, 'n_dirty': len(dirty), 'abi_violation': [i for i in changed if i in CS], 'result': b[0]}
if __name__ == '__main__':
    work, bld, what = sys.argv[1:4]
    out = []
    if what == 'kern':
        for comp in ('pcc', 'llvm'):
            for func, label, setup in KERN:
                res = run(work, bld, comp, 'kern', func, setup, label.replace(' ', '_').replace('(', '').replace(')', ''))
                res.update(comp=comp, label=label); out.append(res)
                print(comp, label, res.get('dirty', res.get('error')), res.get('n_dirty'), 'ABI!' if res.get('abi_violation') else '')
    else:
        for f in sorted(glob.glob(os.path.join(work, '*.pcc.s'))):
            name = os.path.basename(f)[:-6]
            if name == 'kern': continue
            for comp in ('pcc', 'llvm'):
                if not os.path.exists(os.path.join(work, '%s.%s.s' % (name, comp))): continue
                res = run(work, bld, comp, name, 'test', '', 'test')
                res.update(comp=comp, label=name); out.append(res)
                print(comp, name, res.get('dirty', res.get('error')), res.get('n_dirty'), 'ABI!' if res.get('abi_violation') else '')
    json.dump(out, open(os.path.join(work, 'dyn-%s.json' % what), 'w'), indent=1)

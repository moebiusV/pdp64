#!/usr/bin/env python3
"""The system-call path under sim64: a user program makes N system calls (trap #1) to a kernel handler that calls a compiled C function and returns with RTI, in the variants
of the return path.  usage: syscall_bench.py WORKDIR BUILDDIR   (WORKDIR has kern.pcc.s, kern.llvm.s and dyn-kern.json from regs_dynamic.py)

Variants (the instruction sequence between the call of the C function and RTI):
  lazy      nothing (the hole)                         clear  one CLR for each register the function dirtied (measured set)
  frame     PUSHM before the call and POPM after it for the same set (the user's values are put back)      mask-imm   RTI with a mask: not in the instruction set; the sequence is the lazy one
  mask-reg  a load of the mask and a write of a system register (not in the instruction set: counted as lazy + 2 instructions, not run)
sim64 -K -t prints one line per instruction executed; the count is the number of lines.  The timing model of sim64 refuses -K, so cycles are estimated (1 per instruction,
1 more per register of PUSHM/POPM) and, for the cycles of a pipeline model, the same bodies are run as an ordinary function (CALL / RET instead of TRAP / RTI) under --timing.
"""
import sys, os, subprocess, json, re
work, bld = sys.argv[1:3]
dyn = json.load(open(os.path.join(work, 'dyn-kern.json')))
# the call each case makes: C function, setup in user mode (arguments in r0..), the dynamic result label
CASES = [('null', 'sys_null', '', 'sys_null'),
         ('dup', 'sys_dup', '\tlea\tbuf, r1\n\tmovq\tr1, fdtab+24\n\tmovq\t#3, r0\n', 'sys_dup open descriptor'),
         ('checksum100', 'checksum', '\tlea\tbuf, r0\n\tmovq\t#100, r1\n', 'checksum 100 bytes'),
         ('copyin64', 'copyin_bytes', '\tlea\tbuf2, r0\n\tlea\tbuf, r1\n\tmovq\t#64, r2\n', 'copyin_bytes 64 bytes'),
         ('crc32-100', 'crc32', '\tlea\tbuf, r0\n\tmovq\t#100, r1\n', 'crc32 100 bytes'),
         ('chacha', 'chacha_block', '\tlea\tbuf, r0\n', 'chacha_block')]
N = 1000
def dirty_of(comp, label):
    for r in dyn:
        if r['comp'] == comp and r['label'] == label: return r['dirty']
    raise KeyError((comp, label))
def regs_mask(rs):
    m = 0
    for r in rs: m |= 1 << r
    return m
def program(comp, func, setup, variant, dirt, user_mode_cycles=False):
    save = [r for r in dirt if r != 0]
    handler = ''
    if variant == 'frame' and save: handler += '\tpushm\t#0x%x\n' % regs_mask(save)
    handler += '\tcall\t%s\n' % func
    if variant == 'clear':
        for r in save: handler += '\tclr\tr%d\n' % r
    if variant == 'frame' and save: handler += '\tpopm\t#0x%x\n' % regs_mask(save)
    if variant == 'mask-reg': handler += '\tmovq\t#0x7fff, r12\n\tmovq\tr12, r12\n'          # two instructions standing for: load the mask, write the system register
    if user_mode_cycles:
        s = '\t.text\n\t.globl _start\n_start:\n\tmovq\t#%d, r10\n1:\n%s\tcall\th_sys\n\tsob\tr10, 1b\n\tmovq\t#0, r0\n\ttrap\t#0\nh_sys:\n%s\tret\n' % (N, setup, handler)
        return s + '\t.data\n\t.align 8\nbuf:\t.space 512\nbuf2:\t.space 512\n'
    s = '#include "pdp64-consts.h"\n\t.text\n\t.globl _start\n_start:\n\tlea\tvtab, r1\n\tmtsr\tvbr, r1\n\tlea\th_exit, r2\n\tmovq\tr2, 2048(r1)\n\tlea\th_sys, r2\n\tmovq\tr2, 2056(r1)\n'
    s += '\tlea\tustk_top, r1\n\tmtsr\tusp, r1\n\tlea\tuser, r1\n\tmtsr\tepc, r1\n\tmovq\t#((MODE_USER<<PSW_MODE)|(MODE_USER<<PSW_PREV)), r1\n\tmtsr\tepsw, r1\n\trti\n'
    s += 'user:\n\tmovq\t#%d, r10\n1:\n%s\ttrap\t#1\n\tsob\tr10, 1b\n\tmovq\t#0, r0\n\ttrap\t#0\n' % (N, setup)
    s += 'h_exit:\n\tmovq\t#0, r0\n\thalt\nh_sys:\n' + handler + '\trti\n'
    s += '\t.data\n\t.align 8\nbuf:\t.space 512\nbuf2:\t.space 512\nvtab:\t.space 4096\nustk:\t.space 512\nustk_top:\n'
    return s
def build(base, src, comp):
    pp = base + '.s'
    if '#include' in src:
        open(base + '.S', 'w').write(src)
        subprocess.run(['gcc', '-E', '-P', '-x', 'assembler-with-cpp', '-I', bld, base + '.S', '-o', pp], check=True)
    else: open(pp, 'w').write(src)
    subprocess.run([os.path.join(bld, 'as64'), '-o', base + '.o', pp], check=True, capture_output=True)
    subprocess.run([os.path.join(bld, 'as64'), '-o', base + '.fn.o', os.path.join(work, 'kern.%s.s' % comp)], check=True, capture_output=True)
    subprocess.run([os.path.join(bld, 'ld64'), '-o', base + '.x', base + '.o', base + '.fn.o'], check=True, capture_output=True)
    return base + '.x'
def count_k(x):
    r = subprocess.run([os.path.join(bld, 'sim64'), '-K', '-t', x], capture_output=True, timeout=300)
    n = len([l for l in r.stdout.decode().splitlines() + r.stderr.decode().splitlines() if re.match(r'^[0-9a-f]{8}:', l)])
    return n, r.returncode
def cycles_user(x):
    r = subprocess.run([os.path.join(bld, 'sim64'), '--timing=name=run', x], capture_output=True, timeout=300)
    t = (r.stdout + r.stderr).decode()
    m = re.search(r'cycles=([0-9]+)', t)
    return int(m.group(1)) if m else None, t.strip().splitlines()[-1] if t.strip() else ''
os.makedirs(os.path.join(work, 'sys'), exist_ok=True)
rows = []
for comp in ('pcc', 'llvm'):
    for case, func, setup, label in CASES:
        dirt = dirty_of(comp, label)
        res = {'comp': comp, 'case': case, 'dirty': dirt}
        for v in ('lazy', 'clear', 'frame', 'mask-reg'):
            base = os.path.join(work, 'sys', '%s.%s.%s' % (case, comp, v))
            x = build(base, program(comp, func, setup, v, dirt), comp)
            n, rc = count_k(x)
            res[v] = n / N; res['rc_' + v] = rc
            xu = build(base + '.u', program(comp, func, setup, v, dirt, True), comp)
            c, line = cycles_user(xu)
            res['ucyc_' + v] = c / N if c else None
        rows.append(res)
        print(comp, case, dirt, {k: res[k] for k in ('lazy', 'clear', 'frame', 'mask-reg')}, {k: res.get('ucyc_' + k) for k in ('lazy', 'clear', 'frame', 'mask-reg')}, res['rc_lazy'])
json.dump(rows, open(os.path.join(work, 'syscall-bench.json'), 'w'), indent=1)

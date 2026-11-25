#!/usr/bin/env python3
"""The return paths of the repository's hand-written kernels: which registers a handler writes and does not put back before RTI (or GENTER).
usage: handwritten.py REPO_ROOT          (preprocesses the .S files with the C preprocessor as tools/pp-asm.sh does)
A handler is a list of labels whose instructions are read together (a dispatch that falls into a handler).  Written: every register an instruction writes (regs_static.writes);
put back: registers pushed by PUSHM and popped by POPM / POP on the way out.  Left = written - put back - {r14}.  Path-insensitive, like the static count of compiled code."""
import sys, re, subprocess, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regs_static as rs
root = sys.argv[1]
def load(path):
    pp = subprocess.run(['gcc', '-E', '-P', '-x', 'assembler-with-cpp', '-I' + root + '/build', '-I' + root + '/tests/qemu', path], capture_output=True, text=True, check=True).stdout
    lines = []
    for l in pp.splitlines():
        l = l.split(';')[0].rstrip()
        l = re.sub(r'^(\s*)\d+:', r'\1', l)
        if l.strip(): lines.append(l)
    import tempfile; tf = tempfile.NamedTemporaryFile('w', suffix='.s', delete=False); tf.write('\n'.join(lines) + '\n'); tf.close()
    funcs, order = rs.parse(tf.name)
    return funcs
CASES = [
 ('tests/qemu/mini-kernel.S', 'mini-kernel system call write', ['h_write'], 'rti'),
 ('tests/qemu/mini-kernel.S', 'mini-kernel page fault', ['h_pf'], 'rti'),
 ('tests/qemu/mini-kernel.S', 'mini-kernel timer interrupt', ['h_timer'], 'rti'),
 ('tests/qemu/hv-first.S', 'guest kernel system call write', ['g_sys'], 'rti'),
 ('tests/qemu/hv-first.S', 'guest kernel timer interrupt', ['g_tick'], 'rti'),
 ('tests/qemu/hv-first.S', 'hypervisor: hypercall (print a character)', ['hx', 'hc'], 'genter'),
 ('tests/qemu/hv-first.S', 'hypervisor: write of PTBR emulated', ['hx', 'hp'], 'genter'),
 ('tests/qemu/hv-first.S', 'hypervisor: stage-2 fault, demand map', ['hx', 'hs'], 'genter'),
 ('tests/sec-open/sim/sec-regs-carry.S', 'the sec-regs-carry exception handler (hgen)', ['hgen'], 'rti'),
]
out = []
for path, name, labels, ret in CASES:
    funcs = load(os.path.join(root, path))
    W, saved, restored = set(), set(), set()
    n = 0
    for lab in labels:
        for mn, ops in funcs[lab]:
            n += 1
            w, c, r = rs.writes(mn, ops); W |= w; restored |= r
            if mn == 'pushm': saved |= rs.mask_regs(ops[0])
    back = saved & restored
    left = sorted(r for r in W if r not in back and r != 14)
    out.append((name, n, sorted(W), left))
    print('%-46s %3d instr, writes r%s; put back r%s; LEFT r%s (%d)' % (name, n, ',r'.join(map(str, sorted(W))), ',r'.join(map(str, sorted(back))) or '-', ',r'.join(map(str, left)) or '-', len(left)))

#!/usr/bin/env python3
"""
flagreliance -- prove that compiled pdp64 code does not depend on flags written by an instruction that errata 39 stops writing them.

    flagreliance.py [--asm FILE.s ...] [--dir DIR] [--ctests] [--ccom PATH] [-v]

A flag READER is a conditional branch (bCC), a `set cc,rd`, or an instruction that uses the carry (adc, sbc).  For each reader the checker walks
backwards through the straight-line code in front of it (to the label, branch or call that ends the block) and finds the nearest instruction
that writes the flags under the OLD rules (before errata 39).  The site is a RELIANCE when that instruction is one that errata 39 changes:

    a move, a load or a store (movq movl movw movb movzl movzw movzb), clr, pop, push   -- write no flags in the new rules
    cbCC in any form                                                               -- writes no flags
    shl, shr, sar with a register count (a count of 0 wrote nothing, now writes the same flags for every count) -- changed
    mscn, mscnn                                                                    -- changed (never emitted)
    call                                                                           -- the callee's flags are not the caller's

so that the value the reader sees would differ between the old and the new core.  lea, set and the instructions that write the flags in both rules
(cmp, tst, bit, add, sub, and, bis, bic, xor, mul, neg, com, inc, dec, asl, asr, shifts by a constant, fcmp, rori and the rest) are not reliances.
A reader that reaches the top of its block without finding a flag writer takes the flags from another block and is not judged.

With --ctests the C tests (tests/c and the toolchain's a64tests) are compiled with the ccom at several flag sets and checked too; with --dir the
kept .s files of a pdp64size run are checked.  The exit status is 1 if any reliance is found.
"""
import os, re, sys, glob, argparse, subprocess, tempfile

READERS = re.compile(r'^(beq|bne|bpl|bmi|bvc|bvs|bcc|bcs|bge|blt|bgt|ble|bhi|blos|bhis|blo|set|adc|sbc)\b')
MOVES = {'movq', 'movl', 'movw', 'movb', 'movzl', 'movzw', 'movzb', 'clr', 'pop', 'push'}
NEUTRAL = {'lea', 'nop', 'pushm', 'popm'}
SHIFTS = {'shl', 'shr', 'sar'}
WRITERS = {'cmp', 'tst', 'bit', 'add', 'sub', 'and', 'bic', 'bis', 'xor', 'mul', 'mulh', 'neg', 'com', 'inc', 'dec', 'asl', 'asr', 'adc', 'sbc',
           'fcmp', 'fcmp32', 'fcmp16', 'div', 'divu', 'mod', 'modu', 'rol', 'ror', 'rori', 'rori32', 'dshr', 'mulhu', 'abs', 'min', 'max', 'minu', 'maxu',
           'fadd', 'fsub', 'fmul', 'fdiv', 'fadd32', 'fsub32', 'fmul32', 'fdiv32', 'fneg'}
CB = re.compile(r'^cb(ne|eq|pl|mi|vc|vs|cc|cs|ge|lt|gt|le|hi|los)\b')
BRANCHES_END = re.compile(r'^(br|ret|jmp|call|calli|jmpi|b[a-z]+)\b')


def check_lines(lines, name):
    """lines: assembly text lines of one file. returns a list of (line number, reader, culprit)"""
    sites = []
    block = []          # (lineno, mnemonic, ops) of the instructions since the last label or branch
    for no, raw in enumerate(lines, 1):
        l = raw.split(';')[0].rstrip() if not raw.lstrip().startswith('.byte') else raw
        if not l.strip():
            continue
        if not l.startswith('\t'):
            block = []                  # a label
            continue
        t = l.strip()
        if t.startswith('.'):
            block = []
            continue
        mn, _, ops = t.partition(' ')
        ops = ops.strip()
        if READERS.match(mn):
            for (n2, m2, o2) in reversed(block):
                if m2 in NEUTRAL:
                    continue
                culprit = None
                if m2 in MOVES:
                    culprit = m2
                elif CB.match(m2):
                    culprit = m2
                elif m2 in SHIFTS and not re.match(r'#', o2.split(',')[0].strip()):
                    culprit = m2 + ' by a register'
                elif m2 in ('mscn', 'mscnn'):
                    culprit = m2
                elif m2 in ('call', 'calli'):
                    culprit = m2
                elif m2 in WRITERS or m2 in SHIFTS:
                    break
                else:
                    continue            # unknown: not a flag writer we know
                if culprit:
                    sites.append((no, '%s %s' % (mn, ops), '%s %s (line %d)' % (m2, o2, n2)))
                break
        block.append((no, mn, ops))
        if mn in ('br', 'ret', 'jmp', 'jmpi') or (BRANCHES_END.match(mn) and not READERS.match(mn) and not CB.match(mn) and mn not in ('bis', 'bic', 'bit')):
            block = []
        elif READERS.match(mn) and mn != 'set':
            pass                        # a conditional branch: the fall-through keeps the flags
        elif CB.match(mn):
            pass
    return sites


def compile_ctests(ccom, flagsets, srcdirs):
    out = []
    cpp = ['gcc', '-E', '-P', '-undef', '-D__pcc__', '-D__LP64__', '-D_LP64']
    with tempfile.TemporaryDirectory() as w:
        for d in srcdirs:
            for src in sorted(glob.glob(os.path.join(d, '*.c'))):
                i = os.path.join(w, 't.i')
                r = subprocess.run(cpp + [src], capture_output=True, text=True)
                open(i, 'w').write(r.stdout)
                for fl in flagsets:
                    s = os.path.join(w, 't.s')
                    if os.path.exists(s):
                        os.remove(s)
                    subprocess.run([ccom] + fl.split() + [i, s], capture_output=True)
                    if os.path.exists(s):
                        out.append(('%s [%s]' % (os.path.basename(src), fl or 'no flags'), open(s).read().split('\n')))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--asm', nargs='*', default=[])
    ap.add_argument('--dir', default='')
    ap.add_argument('--ctests', action='store_true')
    ap.add_argument('--ccom', default=os.environ.get('PDP64CCOM', ''))
    ap.add_argument('-v', action='store_true')
    a = ap.parse_args()
    here = os.path.dirname(os.path.abspath(__file__))
    work = []
    for f in a.asm:
        work.append((f, open(f).read().split('\n')))
    if a.dir:
        for f in sorted(glob.glob(os.path.join(a.dir, '*.s'))):
            if os.path.basename(f).startswith(('gcc-Os_', 'clang-Os_', 'amd64_')):
                continue
            work.append((f, open(f).read().split('\n')))
    if a.ctests:
        if not a.ccom:
            sys.exit('--ctests needs --ccom or PDP64CCOM')
        toolchain = os.environ.get('TOOLCHAIN', os.path.expanduser('~/claude/facetlang/pdp11/v7unix-toolchain'))
        flagsets = ['', '-xdmr', '-xtemps -xdeljumps -xinline -xdce', '-xdmr -xtemps -xdeljumps -xinline -xdce',
                    '-xdmr -xtemps -xdeljumps -xinline -xdce -xssa', '-xdmr -xtemps -xdeljumps -xinline -xdce -xabs']
        work += compile_ctests(a.ccom, flagsets, [os.path.join(here, '..', 'tests', 'c'), os.path.join(toolchain, 'tools', 'a64tests')])
    total = 0
    by = {}
    files = 0
    for name, lines in work:
        files += 1
        for no, reader, culprit in check_lines(lines, name):
            total += 1
            key = culprit.split()[0] + (' by a register' if 'by a register' in culprit else '')
            by[key] = by.get(key, 0) + 1
            if a.v and total <= 40:
                print('%s:%d: %s reads flags last written by %s' % (name, no, reader, culprit))
    print('flagreliance: %d files, %d reliance sites%s' % (files, total, (' (' + ', '.join('%s %d' % kv for kv in sorted(by.items(), key=lambda kv: -kv[1])) + ')') if by else ''))
    sys.exit(1 if total else 0)


if __name__ == '__main__':
    main()

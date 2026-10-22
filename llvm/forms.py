#!/usr/bin/env python3
"""
forms -- every mnemonic in every operand form, llvm-mc against as64.

tests/asm is a few hundred hand-worked instructions; this writes thousands more from the grammar's own mnemonic lists: each
mnemonic with each addressing mode at the edges of every field (the largest and smallest displacement of each length, an immediate
that just fits and one that just does not), symbols that are before, after, in another section and undefined, branches over
distances that straddle each length, and all the register-only instructions.  A program that one assembler accepts and the other
refuses, or that gives different bytes or relocations, is a mismatch.  Both refusing is agreement.

    forms.py [--as64 PATH] [--llvm-mc PATH] [-v] [MNEMONIC ...]
"""
import importlib.util, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
import oracle

spec = importlib.util.spec_from_file_location('gen', os.path.join(ROOT, 'tools', 'gen-llvm-td.py'))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)

# ---- the operands ------------------------------------------------------------------------------------------------------------

REG = ['r1', 'r0', 'r15', 'sp', 'fp']
BASE = ['(r2)', '0(r2)', '8(r2)', '16(r2)', '24(r2)', '32(r2)', '40(r2)', '-8(fp)', '120(sp)', '248(sp)', '256(sp)', '4(sp)', '(sp)',
        '2047(r4)', '-2048(r4)', '2048(r4)', '-2049(r4)', '100000(r4)', '-100000(r4)', '134217727(r4)', '-134217728(r4)', '134217728(r4)']
INDEX = ['(r1)(r2)', '(r1)(r2*2)', '4(r1)(r2*4)', '31(r1)(r2*8)', '-32(r1)(r2)', '32(r1)(r2)', '-33(r1)(r2)', '2097151(r1)(r2)',
         '-2097152(r1)(r2)', '2097152(r1)(r2)', '8(sp)(r3*8)', '(r1)(r2*3)']
DP = ['0(dp)', '8(dp)', '2047(dp)', '-2048(dp)', '2048(dp)', '(dp)']
IMM = ['#0', '#1', '#7', '#-8', '#8', '#-9', '#15', '#16', '#255', '#32767', '#32768', '#-32768', '#-32769', '#65535', '#2147483647',
       '#-2147483648', '#2147483648', '#-2147483649', "#'a'", '#1<<10', '#back', '#fwd', '#ext', '#ext+8', '#dat']
ABS = ['@0', '@100', '@0x7fff', '@0x8000', '@2147483647', '@-1', '@2147483648', '@ext', '@back', '@dat+8']
PCREL = ['back', 'fwd', 'dat', 'ext', 'ext+8', 'dat+4', 'back+2', '16(pc)', '-16(pc)', '100000(pc)', '(pc)', 'far']
POSTINC = ['(r1)+', '(r2)+16', '(r2)+2047', '(r2)+2048', '(r2)+0', '(sp)+']
PREDEC = ['-(r1)', '(r2)-4', '-(sp)', '(r2)-2047', '(r2)-2048']

MODES = {'R': REG, 'B': BASE, 'X': INDEX, 'D': DP, 'I': IMM, 'A': ABS, 'PC': PCREL, 'PI': POSTINC, 'PD': PREDEC}


def mem_cases():
    """(mnemonic, operand pattern, kind) for the memory-class mnemonics: pattern has {m} for the operand."""
    out = []
    for l, v in g.real('mn-mov'):
        out.append((l, '{m}, r3', 'all'))
        out.append((l, 'r3, {m}', 'store'))
    for l, v in g.real('mn-movz'):
        out.append((l, '{m}, r3', 'all'))
    out.append(('lea', '{m}, r3', 'store'))
    for l, v in g.real('mn-alu'):
        out.append((l, 'r3, {m}' if l in g.CMP_FIRST else '{m}, r3', 'all'))
    for l, v in g.real('mn-sop'):
        if l in ('pushm', 'popm'):
            continue
        out.append((l, '{m}', 'all'))
    for l, v in g.real('mn-xfer'):
        out.append((l, '{m}', 'jtag' if l == 'jtag' else 'noreg'))
    return out


def modes_for(kind):
    if kind == 'jtag':
        return INDEX
    ms = []
    for k, v in MODES.items():
        if k == 'R' and kind in ('noreg', 'store'):
            continue
        if k == 'I' and kind == 'store':
            continue
        ms += v
    return ms


# ---- running ---------------------------------------------------------------------------------------------------------------

PRE = '\t.text\n\t.globl start\nstart:\nback:\tnop\n\tnop\n\t.even\n'
POST = 'fwd:\tnop\nfar:\tnop\n\t.data\n\t.even\ndat:\t.quad 0\n'


class Ctx:
    def __init__(self, as64, mc, verbose):
        self.as64, self.mc, self.verbose = as64, mc, verbose
        self.tmp = tempfile.mkdtemp()
        self.n = self.agree = self.refused = 0
        self.mismatch = []

    def assemble(self, body, pre=PRE, post=POST):
        src = pre + body + post
        sp = os.path.join(self.tmp, 'f.s')
        open(sp, 'w').write(src)
        lf = os.path.join(self.tmp, 'l.s')
        open(lf, 'w').write(oracle.translate(src))
        ao, bo = os.path.join(self.tmp, 'a.o'), os.path.join(self.tmp, 'b.o')
        for p in (ao, bo):
            if os.path.exists(p):
                os.remove(p)
        r1 = oracle.run([self.as64, '-o', ao, sp])
        r2 = oracle.run([self.mc, '-triple=' + oracle.TRIPLE, '-filetype=obj', '-o', bo, lf])
        return r1, r2, ao, bo

    def test(self, lines, pre=PRE, post=POST, label=''):
        """lines: assembly statements.  Tests them together; if the programs disagree, line by line."""
        body = ''.join('\t' + l + '\n' for l in lines)
        r1, r2, ao, bo = self.assemble(body, pre, post)
        if r1.returncode == 0 and r2.returncode == 0:
            d = oracle.compare(oracle.Elf(ao), oracle.Elf(bo))
            if not d:
                self.n += len(lines)
                self.agree += len(lines)
                return
        if len(lines) == 1:
            self.n += 1
            if r1.returncode != 0 and r2.returncode != 0:
                self.agree += 1
                self.refused += 1
                return
            if r1.returncode != 0:
                self.mismatch.append((lines[0], 'as64 refuses, llvm-mc accepts: ' + r1.stderr.strip().split('\n')[0], label))
            elif r2.returncode != 0:
                self.mismatch.append((lines[0], 'llvm-mc refuses, as64 accepts: ' + r2.stderr.strip().split('\n')[0], label))
            else:
                self.mismatch.append((lines[0], '\n'.join(oracle.compare(oracle.Elf(ao), oracle.Elf(bo))), label))
            return
        mid = len(lines) // 2
        self.test(lines[:mid], pre, post, label)
        self.test(lines[mid:], pre, post, label)


def run_mem(ctx, only):
    for mn, pat, kind in mem_cases():
        if only and mn not in only:
            continue
        ctx.test(['%s\t%s' % (mn, pat.format(m=o)) for o in modes_for(kind)], label=mn)
    # pushm / popm
    for mn in ('pushm', 'popm'):
        if only and mn not in only:
            continue
        ctx.test(['%s #%s' % (mn, v) for v in ('0', '1', '0xff', '0x100', '0xff00', '0x1234', '0x8000', '0xffff', '0x10000', '-1', 'back')], label=mn)


def pad(n):
    return '\t.space %d\n' % n if n else ''


def run_branches(ctx, only):
    dists = [0, 2, 250, 252, 254, 256, 258, 300, 2046, 2048, 2050, 65532, 65534, 65536, 65538, 70000]
    for mn, v in g.real('mn-branch'):
        if only and mn not in only:
            continue
        for d in dists:
            ctx.test(['%s\ttgt' % mn], pre=PRE, post=pad(d) + 'tgt:\tnop\n' + POST, label='%s fwd %d' % (mn, d))
            ctx.test(['%s\ttgt' % mn], pre=PRE + 'tgt:\tnop\n' + pad(d), post=POST, label='%s back %d' % (mn, d))
        ctx.test(['%s\text' % mn, '%s\text+4' % mn, '%s\tdat' % mn, '%s\tback' % mn, '%s\tfwd' % mn], label=mn)
    for mn in ('sob',):
        if only and mn not in only:
            continue
        for d in dists:
            ctx.test(['sob\tr3, tgt'], post=pad(d) + 'tgt:\tnop\n' + POST, label='sob fwd %d' % d)
            ctx.test(['sob\tr3, tgt'], pre=PRE + 'tgt:\tnop\n' + pad(d), label='sob back %d' % d)
        ctx.test(['sob\tr3, ext', 'sob\tr3, back', 'sob\tr15, fwd'], label='sob')
    for mn, v in g.real('mn-tag'):
        if only and mn not in only:
            continue
        for d in dists:
            ctx.test(['%s\tr3, #5, tgt' % mn], post=pad(d) + 'tgt:\tnop\n' + POST, label='%s fwd %d' % (mn, d))
            ctx.test(['%s\tr3, #5, tgt' % mn], pre=PRE + 'tgt:\tnop\n' + pad(d), label='%s back %d' % (mn, d))
        ctx.test(['%s\tr%d, #%d, ext' % (mn, r, t) for r, t in ((0, 0), (15, 7), (3, 8), (3, -1), (3, 2))], label=mn)


def run_cb(ctx, only):
    imms = ['0', '5', '15', '16', '-16', '-17', '255', '32767', '-32768', '32768', '-32769']
    dists = [0, 2, 2044, 2046, 2048, 2050, 4094, 4096, 65530, 65532, 65534, 65536, 65538, 70000]
    allcc = [l for l, v in g.real('mn-cbranch')]
    for mn in allcc:
        if only and mn not in only:
            continue
        # every condition: a few cases; the distances for three of them
        ctx.test(['%s\tr3, #%s, fwd' % (mn, i) for i in imms] + ['%s\tr3, r4, fwd' % mn, '%s\tr15, r0, back' % mn, '%s\tr3, #5, ext' % mn,
                                                                   '%s\tr3, r4, ext' % mn, '%s\tr3, #5, dat' % mn, '%s\tr3, #5, back+1' % mn], label=mn)
        if mn in ('cbne', 'cbeq', 'cbhis', 'cblo'):
            for d in dists:
                for i in ('0', '15', '-16', '16', '255', '-32768', '32767'):
                    ctx.test(['%s\tr3, #%s, tgt' % (mn, i)], post=pad(d) + 'tgt:\tnop\n' + POST, label='%s #%s fwd %d' % (mn, i, d))
                    ctx.test(['%s\tr3, #%s, tgt' % (mn, i)], pre=PRE + 'tgt:\tnop\n' + pad(d), label='%s #%s back %d' % (mn, i, d))
                ctx.test(['%s\tr3, r4, tgt' % mn], post=pad(d) + 'tgt:\tnop\n' + POST, label='%s rr fwd %d' % (mn, d))
                ctx.test(['%s\tr3, r4, tgt' % mn], pre=PRE + 'tgt:\tnop\n' + pad(d), label='%s rr back %d' % (mn, d))


def run_regs(ctx, only):
    R = ['r1', 'r2', 'r3', 'r4']
    ext = ['r0', 'r15', 'sp', 'fp', 'r7']
    def regsets(n):
        return [', '.join(R[:n]), ', '.join(ext[:n]), ', '.join(reversed(R[:n]))]
    for rule in ('mn-besc', 'mn-aesc', 'mn-mblk', 'mn-fesc'):
        for l, v in g.real(rule):
            if only and l not in only:
                continue
            lines = []
            if l in g.BESC_COUNT:
                top = 31 if l == 'rori32' else 63
                for n in (0, 1, top, top + 1, -1):
                    lines.append('%s\tr1, #%d, r2' % (l, n))
            elif l == 'dshr':
                lines += ['dshr\tr1, r2, #%d, r3' % n for n in (0, 1, 63, 64)]
            elif l in g.BESC_FIELD:
                lines += ['%s\tr1, #%d, #%d, r2' % (l, p, w) for p, w in ((0, 1), (3, 8), (63, 1), (0, 64), (0, 65), (64, 1), (0, 0))]
            elif rule == 'mn-mblk':
                lines += ['%s\t%s' % (l, s) for s in (regsets(2) if l == 'mval' else regsets(3))]
            elif l in g.BESC_TWO or l in g.AESC_TWO or l in g.FESC_UNARY or l in g.FESC_BINARY or l in g.FESC_REGFIRST:
                lines += ['%s\t%s' % (l, s) for s in regsets(2)]
            elif l in g.FESC_THREE or rule in ('mn-besc', 'mn-aesc'):
                lines += ['%s\t%s' % (l, s) for s in regsets(3)]
            else:
                lines += ['%s\t%s' % (l, s) for s in regsets(4)]
            ctx.test(lines, label=l)
    # set cc, rd
    if not only or 'set' in only:
        ctx.test(['set\t%s, r%d' % (c, r) for c, _ in g.items('cc') + g.items('ccalias') for r in (1, 15)], label='set')
    # rol
    if not only or 'rol' in only:
        ctx.test(['rol\tr1, #%d, r2' % n for n in (0, 1, 63, 64, 32)], label='rol')
    # SYS
    for l, v in g.real('mn-sys-none') + g.real('mn-sysx'):
        if only and l not in only:
            continue
        ctx.test([l], label=l)
    for l, v in g.real('mn-sys'):
        if only and l not in only:
            continue
        if l in ('spl', 'trap', 'trapl'):
            ctx.test(['%s\t#%d' % (l, n) for n in (0, 1, 7, 15, 16, 255, 256, -1)], label=l)
        elif l in g.SYS_PROBE:
            ctx.test(['%s\tr1, r2' % l, '%s\tr15, r0' % l], label=l)
        else:
            ctx.test(['%s\tr1' % l, '%s\tr15' % l, '%s\tsp' % l], label=l)
    if not only or 'mfsr' in only or 'mtsr' in only:
        names = [l for l, v in g.items('sysreg')] + ['bogus']
        ctx.test(['mfsr\tr1, %s' % n for n in names] + ['mtsr\t%s, r1' % n for n in names] + ['mfsr\t%s, r1' % names[0], 'mtsr\tr1, %s' % names[0]], label='sysreg')


def main():
    args = sys.argv[1:]
    as64 = os.path.join(ROOT, os.environ.get('BUILD', 'build'), 'as64')
    mc = os.environ.get('LLVM_MC', os.path.expanduser('~/claude/llvm-build/bin/llvm-mc'))
    verbose = False
    only = set()
    while args:
        a = args.pop(0)
        if a == '--as64':
            as64 = args.pop(0)
        elif a == '--llvm-mc':
            mc = args.pop(0)
        elif a == '-v':
            verbose = True
        else:
            only.add(a)
    ctx = Ctx(as64, mc, verbose)
    run_mem(ctx, only)
    run_branches(ctx, only)
    run_cb(ctx, only)
    run_regs(ctx, only)
    print('%d programs/instructions compared: %d agree (%d of them refused by both), %d mismatch' % (ctx.n, ctx.agree, ctx.refused, len(ctx.mismatch)))
    seen = {}
    for line, why, label in ctx.mismatch:
        seen.setdefault(label.split()[0] if label else '', []).append((line, why, label))
    for lab, items in sorted(seen.items()):
        print('MISMATCH %s: %d' % (lab, len(items)))
        for line, why, label in items[: (50 if verbose else 3)]:
            print('   [%s] %s\n      %s' % (label, line, why.replace('\n', '\n      ')))
    return 1 if ctx.mismatch else 0


if __name__ == '__main__':
    sys.exit(main())

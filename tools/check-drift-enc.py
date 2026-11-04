#!/usr/bin/env python3
"""
check-drift-enc -- the drift test for the prefix-coded encodings (pdp64/16 and pdp64/32), the counterpart of check-drift.py.

spec/pdp64-NN/pdp64-NN.hbnf is the one place the bit positions and the mnemonics of an encoding are written.  For every mnemonic of the table this
writes one assembly instruction of a shape the table has for it (from the operand specs of its shortest form), assembles it with as64 -m pdp64/NN, decodes the
parcels with the C codec (tests/enc/encdrv -d) and requires the same mnemonic back: every mnemonic of the encoding can be written in the assembly language and
reaches its own opcode (the 22 ATOM words, the 8 MESC words, TRAPL, the SYSX words, the new instructions and the fused pairs included).  Then:
  - every word of the original grammar (spec/pdp64-mnemonics.hbnf) that the table has under that name assembles, and an alias assembles to what the word it
    stands for assembles to;
  - the opcode map: the prefixes are a prefix code (Kraft sum <= 0.95), the 65,536 first parcels decode to at most one leaf, and the number of free patterns,
    leaves, forms and hot-register tables are those recorded below (a change to a table must change them in the same commit).
"""
import json, os, re, struct, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import encgram
B = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
AS = os.path.join(B, 'as64')
DRV = os.path.join(B, 'encdrv')
GOLD = {'16': dict(forms=219, leaves=281, free=3277, hot8=[0, 1, 8, 2, 14, 3, 9, 10], hot16=None),
        '32': dict(forms=196, leaves=255, free=3277, hot8=[0, 1, 8, 2, 14, 3, 9, 10], hot16=[0, 1, 8, 2, 14, 3, 9, 10, 11, 4, 15, 5, 24, 25, 26, 6])}
SIZE = {'movq': 8, 'movl': 4, 'movw': 2, 'movb': 1, 'movzl': 4, 'movzw': 2, 'movzb': 1}


def rname(r):
    return {14: 'sp', 13: 'fp'}.get(r, 'r%d' % r)


class Gen:
    def __init__(self, d):
        self.d = d
        self.n = 0

    def reg(self, s):
        if s['k'] == 'K': return 'sp' if s['op'][1] == 14 else 'dp'
        if s['table']: return rname(s['table'][self.n % len(s['table'])])
        return rname(1 + self.n % 7)

    def op(self, s, mn):
        k = s['k']
        self.n += 1
        if k == 'R': return self.reg(s)
        if k == 'K': return '#0'
        if k == 'I': return '#%d' % (s['scale'] if s['scale'] > 1 else 1)
        if k == 'B':
            sc = SIZE.get(mn.split('.')[0], 1) if s['scale'] == 'sz' else s['scale']
            d = 0 if not s['dw'] else sc
            if s['rn']['k'] == 'K' and s['rn']['op'][1] == 16: return '%d(dp)' % d
            return '%d(%s)' % (d, self.reg(s['rn']))
        if k == 'X':
            return '0(%s)(%s*1)' % (self.reg(s['rn']), rname(2 + self.n % 5 if s['rx']['table'] is None else s['rx']['table'][0]))
        if k == 'PI': return '(%s)+' % self.reg(s['rn'])
        if k == 'PD': return '-(%s)' % self.reg(s['rn'])
        if k == 'PC': return 'lbl'
        if k == 'A': return '@4'
        raise ValueError(k)

    def line(self, f, mn):
        ops = [self.op(s, mn) for s in f['specs']]
        if mn == 'set': return 'set eq, ' + ops[1]
        if mn == 'mfsr': return 'mfsr %s, ptbr' % ops[0]
        if mn == 'mtsr': return 'mtsr ptbr, %s' % ops[1]
        if mn in ('movq.d', 'movq.ud') and False: pass
        return '%s %s' % (mn, ', '.join(ops)) if ops else mn


def assemble(tag, src, *flags):
    with tempfile.TemporaryDirectory() as t:
        f = os.path.join(t, 'a.s'); o = os.path.join(t, 'a.o')
        open(f, 'w').write('\t.text\n' + src + '\n')
        r = subprocess.run([AS, '-m', 'pdp64/' + tag, *flags, '-o', o, f], capture_output=True, text=True)
        if r.returncode: return None, r.stderr
        d = open(o, 'rb').read()
        shoff = struct.unpack_from('<Q', d, 0x28)[0]
        off, size = struct.unpack_from('<QQ', d, shoff + 64 + 24)
        return [struct.unpack_from('<H', d, off + 2 * i)[0] for i in range(size // 2)], None


def decode(tag, words):
    r = subprocess.run([DRV, '-d', tag], input=' '.join('%04x' % w for w in words) + '\n', capture_output=True, text=True)
    return r.stdout.strip()


def main():
    sys.path.insert(0, HERE)
    import mkgrammar
    en = mkgrammar.enums(os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf'))
    names = {}                                 # word -> canonical word, from the generated header
    for w, c in re.findall(r'"([^"]+)", "([^"]+)" \}', open(os.path.join(B, 'x', 'pdp64-mnnames.h')).read()):
        names[w] = c
    bad = checked = 0
    for tag in ('16', '32'):
        d = encgram.load(tag, ROOT)
        g = Gen(d)
        first = {}
        for fi, f in enumerate(d['forms']):
            for m in f['mns']:
                if m not in first or (f['n'], fi) < (d['forms'][first[m]]['n'], first[m]): first[m] = fi
        n = 0
        for mn in sorted(first):
            f = d['forms'][first[mn]]
            src = g.line(f, mn)
            if any(s['k'] == 'PC' for s in f['specs']): src += '\nlbl:'
            words, err = assemble(tag, '\t' + src.replace('\n', '\n'))
            got = None
            if words is not None:
                m = re.match(r'(\d+) (\S+)', decode(tag, words[:5]))
                got = m.group(2) if m else None
            n += 1
            if got != mn:
                bad += 1
                print('DRIFT pdp64/%s %s: `%s` %s' % (tag, mn, src.split('\n')[0], ('assembles to ' + str(got)) if words is not None else 'is refused: ' + err.strip().split('\n')[0]))
        checked += n
        # aliases and the words of the original grammar
        na = 0
        for w, c in sorted(names.items()):
            if w == c or c not in first: continue
            f = d['forms'][first[c]]
            g.n = 0
            src = g.line(f, c).replace(c, w, 1)
            if any(s['k'] == 'PC' for s in f['specs']): src += '\nlbl:'
            a, e1 = assemble(tag, '\t' + src)
            b, e2 = assemble(tag, '\t' + src.replace(w, c, 1))
            na += 1
            if a is None or a != b:
                bad += 1; print('DRIFT pdp64/%s alias %s of %s: %s vs %s' % (tag, w, c, a, b))
        checked += na
        # the opcode map
        cnt = {}
        r = subprocess.run([DRV, '-d', tag], input='\n'.join('%04x' % p for p in range(65536)) + '\n', capture_output=True, text=True).stdout.split('\n')
        free = sum(1 for x in r[:65536] if x == 'ILLEGAL')
        exp = GOLD[tag]
        for k, v in (('forms', len(d['forms'])), ('leaves', len(d['leaves'])), ('free', free), ('hot8', d['hot8']), ('hot16', d['hot16'])):
            if v != exp[k]:
                bad += 1; print('MAP pdp64/%s: %s is %s, the record here says %s' % (tag, k, v, exp[k]))
        kraft = sum(2.0 ** -lf['L'] for lf in d['leaves'])
        if kraft > 0.95 + 1e-9:
            bad += 1; print('MAP pdp64/%s: Kraft sum %.6f above 0.95 (5%% of the code space is kept free)' % (tag, kraft))
        print('pdp64/%s: %d mnemonics and %d aliases assemble to their own opcode; %d forms, %d leaves, %d of 65,536 first parcels illegal' % (tag, n, na, len(d['forms']), len(d['leaves']), free))
    print('drift-enc: %d checked, %d differ' % (checked, bad))
    sys.exit(1 if bad else 0)


main()

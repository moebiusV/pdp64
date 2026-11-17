#!/usr/bin/env python3
"""bounds-price.py CENSUSDIR [pdp64-static.csv] -- what each form of a bounds check costs, site by site, on the sites boundscan.py found.

Reads CENSUSDIR/sites.csv and files.csv.  A site is one check that -fsanitize=bounds inserted.  Each site is put in a class:

    const      one unsigned compare of an index with a constant bound (ult/ugt, and `eq` for a bound of 1)
    var        the same with a bound held in a variable
    offset-nuw the tested value is x +/- c that cannot wrap (add or sub nuw): one compare of x with an adjusted bound is the whole check
    band       the tested value is x +/- c that may wrap (nsw or no flag: a[i+1] with i a signed int): the check on x alone is lo <= x < hi
    combo      several checks merged by the optimiser into one condition (or/and/select/phi): counted as two compares
    signed     a signed compare

and priced, in instructions and in instruction bytes added to the program, for these forms (sizes from the grammar as J.9.13 counts them, a
register-register or register-immediate compare in the hot registers, a bound that fits an immediate):

    cbhis      CBHIS rs, rb|#imm, fail (flags untouched, a shared stub): 1 insn, 4 bytes; a band needs `lea -lo(rs), t` first: +1 insn, +4 bytes
    cmp+trap   CMP rs, rb|#imm ; TRAPCC.hs: 2 insns, 4 bytes (6 with an immediate); a band: +1 insn, +4 bytes
    CHK        a compare-and-trap, 4 bytes: 1 insn (errata 85 recorded none); a band: +1 insn, +4 bytes
    CHK2       rs, rlo, rhi: 1 insn, 4 bytes, a band included; a site that is not a band is priced as CHK
    asrt       LoongArch ASRTLE.D rj, rk: register against register only, so a constant bound is first loaded (+1 insn, +4 bytes); a band: +1
    fused      LoongArch LDLE/LDGT: the check of the address register against a bound register, fused with the access; it saves the access
               nothing and checks an address, not an index: on an index site it needs the address formed first (+1 insn) and a bound that is an address

The per-site numbers are the ones the author's open item J.9.13 uses; the totals are what the corpus would pay.  Output: a markdown table."""
import csv, sys, collections

d = sys.argv[1]
rows = list(csv.DictReader(open(d + '/sites.csv')))
files = [r for r in csv.DictReader(open(d + '/files.csv')) if r['status'] == 'ok']
cls = collections.Counter()
loop = collections.Counter()
for r in rows:
    p, b, o, l = r['pred'], r['bound'], r['offset'], r['in_loop']
    if p.startswith('combo'):
        c = 'combo'
    elif p in ('slt', 'sle', 'sgt', 'sge'):
        c = 'signed'
    elif o == 'nuw':
        c = 'offset-nuw'
    elif o in ('yes', 'nsw'):
        c = 'band'
    elif b == 'const':
        c = 'const'
    else:
        c = 'var'
    cls[c] += 1
    if l == 'yes':
        loop[c] += 1
n = sum(cls.values())
# (instructions, bytes) per site for each form and class; const classes use the immediate where the form has one
PRICE = {
    'cbhis':    {'const': (1, 4), 'var': (1, 4), 'offset-nuw': (1, 4), 'band': (2, 8), 'combo': (2, 8), 'signed': (2, 8)},
    'cmp+trap': {'const': (2, 6), 'var': (2, 4), 'offset-nuw': (2, 6), 'band': (3, 10), 'combo': (4, 10), 'signed': (3, 10)},
    'CHK':      {'const': (1, 4), 'var': (1, 4), 'offset-nuw': (1, 4), 'band': (2, 8), 'combo': (2, 8), 'signed': (2, 8)},
    'CHK2':     {'const': (1, 4), 'var': (1, 4), 'offset-nuw': (1, 4), 'band': (1, 4), 'combo': (2, 8), 'signed': (2, 8)},
    'asrt':     {'const': (2, 8), 'var': (1, 4), 'offset-nuw': (2, 8), 'band': (3, 12), 'combo': (3, 12), 'signed': (3, 12)},
}
out = ['| class | sites | share | of them in a loop |', '|---|---:|---:|---:|']
for c in ('const', 'var', 'offset-nuw', 'band', 'combo', 'signed'):
    out.append('| %s | %d | %.1f%% | %d |' % (c, cls[c], 100.0 * cls[c] / n if n else 0, loop[c]))
out.append('| all | %d | 100%% | %d |' % (n, sum(loop.values())))
out += ['', '| form | instructions added | bytes added | against cbhis (instructions) | against cbhis (bytes) |', '|---|---:|---:|---:|---:|']
base = None
for f, pr in PRICE.items():
    ti = sum(pr[c][0] * k for c, k in cls.items())
    tb = sum(pr[c][1] * k for c, k in cls.items())
    if base is None:
        base = (ti, tb)
    out.append('| %s | %d | %d | %+d | %+d |' % (f, ti, tb, ti - base[0], tb - base[1]))
tot_ins = sum(int(r['ir_insns']) for r in files)
out += ['', 'IR instructions of the sanitized build, %d files: %d; sites %d (%.3f per 100 IR instructions).' % (len(files), tot_ins, n, 100.0 * n / tot_ins if tot_ins else 0)]
if files and 'var_geps' in files[0]:
    g = sum(int(r['var_geps']) for r in files)
    out.append('Subscripts with a variable index (`getelementptr` with a non-constant index) in the same IR: %d; the sanitizer guarded %d of them (%.1f%%), the arrays whose size the compiler knows.' % (g, n, 100.0 * n / g if g else 0))
    out.append('If a language that checks every subscript (Ada, Rust, Go) guarded all %d, with the same mix of classes, option 1 (cbhis) would add about %d instructions and %d bytes before the optimiser removes the provable ones.' % (
        g, round(base[0] * g / n) if n else 0, round(base[1] * g / n) if n else 0))
print('\n'.join(out))

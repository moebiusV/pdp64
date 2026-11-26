#!/usr/bin/env python3
# summarize.py : the tables of README.md from out/*.json, out/*.run.json, out/dynmix.json
import json, re, collections, sys, csv
W = '/tmp/flags-work'
def load(n): return {x['name']: x for x in json.load(open(f'{W}/out/{n}.json'))}
base, setc, nf, llvm = load('base'), load('nosetcc'), load('nf'), load('llvm')
P = lambda a, b: 100.0 * (b - a) / a if a else 0.0
out = []
def p(s=''): out.append(s)
groups = collections.OrderedDict()
for k, x in base.items(): groups.setdefault(x['group'], []).append(k)
# T1 coverage
p('### T1. What compiled'); p()
p('| group | files | pcc compiles | LLVM compiles | both |'); p('|---|---:|---:|---:|---:|')
tt = [0, 0, 0, 0]
for g, ks in groups.items():
    a = sum('fail' not in base[k] for k in ks); b = sum('fail' not in llvm[k] for k in ks); c = sum('fail' not in base[k] and 'fail' not in llvm[k] for k in ks)
    p(f'| {g} | {len(ks)} | {a} | {b} | {c} |'); tt = [tt[0] + len(ks), tt[1] + a, tt[2] + b, tt[3] + c]
p(f'| **all** | **{tt[0]}** | **{tt[1]}** | **{tt[2]}** | **{tt[3]}** |'); p()
ok = [k for k in base if 'fail' not in base[k] and 'fail' not in nf[k] and 'fail' not in setc[k]]
def S(d, ks, f): return sum(d[k][f] for k in ks)
def expanded(d, ks): return sum(int((re.search(r'\((\d+) cbCC expanded', d[k]['stats_text']) or [0, 0])[1]) for k in ks)
# T2 static totals
p('### T2. Static totals, pcc, the files pcc compiles (%d files)' % len(ok)); p()
p('| | instructions | bytes, plain | bytes, relaxed by ld64 | cbCC the assembler turned back into CMP+Bxx |'); p('|---|---:|---:|---:|---:|')
for lab, d in (('baseline', base), ('SET given up only (no setcc idiom)', setc), ('no flags (variant)', nf)):
    p(f'| {lab} | {S(d, ok, "plain_insn")} | {S(d, ok, "plain_bytes")} | {S(d, ok, "relax_text")} | {expanded(d, ok)} |')
bi, bb, br_ = S(base, ok, 'plain_insn'), S(base, ok, 'plain_bytes'), S(base, ok, 'relax_text')
ni, nb, nr = S(nf, ok, 'plain_insn'), S(nf, ok, 'plain_bytes'), S(nf, ok, 'relax_text')
si, sb, sr = S(setc, ok, 'plain_insn'), S(setc, ok, 'plain_bytes'), S(setc, ok, 'relax_text')
p(f'| change, SET only | {si-bi:+d} ({P(bi,si):+.2f}%) | {sb-bb:+d} ({P(bb,sb):+.2f}%) | {sr-br_:+d} ({P(br_,sr):+.2f}%) | |')
p(f'| **change, no flags** | **{ni-bi:+d} ({P(bi,ni):+.2f}%)** | **{nb-bb:+d} ({P(bb,nb):+.2f}%)** | **{nr-br_:+d} ({P(br_,nr):+.2f}%)** | {expanded(nf,ok)-expanded(base,ok):+d} sites |')
ex = expanded(nf, ok) - expanded(base, ok)
fi, fb = ni + ex, nb + 4 * ex
p(f'| no flags, plus the flag-free fallback for those sites (estimate: one more instruction and four more bytes each) | {fi-bi:+d} ({P(bi,fi):+.2f}%) | {fb-bb:+d} ({P(bb,fb):+.2f}%) | {nr+4*ex-br_:+d} ({P(br_,nr+4*ex):+.2f}%) | |')
p()
# T3 by group
p('### T3. By group (pcc, plain bytes)'); p()
p('| group | files | baseline insns | variant insns | % | baseline bytes | variant bytes | % |'); p('|---|---:|---:|---:|---:|---:|---:|---:|')
for g, ks in groups.items():
    kk = [k for k in ks if k in ok]
    if not kk: continue
    a, b, c, d_ = S(base, kk, 'plain_insn'), S(nf, kk, 'plain_insn'), S(base, kk, 'plain_bytes'), S(nf, kk, 'plain_bytes')
    p(f'| {g} | {len(kk)} | {a} | {b} | {P(a,b):+.2f} | {c} | {d_} | {P(c,d_):+.2f} |')
p()
# T4 mnemonic classes
KIND = collections.OrderedDict([('CMP', ['cmp']), ('TST', ['tst', 'test']), ('flag branches (Bxx)', 'beq bne bmi bpl bvc bvs bcc bcs bge blt bgt ble bhi blos'.split()), ('SET', ['set']), ('ADC/SBC', ['adc', 'sbc']),
                                ('FCMP', ['fcmp', 'fcmp32']), ('compare-and-branch (cbCC)', 'cbeq cbne cblt cbge cbgt cble cbcs cbcc cbhi cblos'.split()), ('br/jmp', ['br', 'jmp']), ('sob', ['sob'])])
def kinds(d, ks):
    h = collections.Counter()
    for k in ks: h.update(d[k]['hist'])
    return {a: sum(h.get(m, 0) for m in ms) for a, ms in KIND.items()}, sum(h.values())
p('### T4. Static count of each kind of compare, branch and flag instruction (same %d files for the two pcc builds; LLVM on the %d files it compiles)' % (len(ok), sum('fail' not in x for x in llvm.values()))); p()
lk = [k for k in llvm if 'fail' not in llvm[k]]
kb, tb = kinds(base, ok); kn, tn = kinds(nf, ok); kl, tl = kinds(llvm, lk)
p('| kind | pcc baseline | pcc no-flags | LLVM (own files) |'); p('|---|---:|---:|---:|')
for a in KIND: p(f'| {a} | {kb[a]} | {kn[a]} | {kl[a]} |')
p(f'| all instructions (by mnemonic count) | {tb} | {tn} | {tl} |'); p()
p('The Bxx left in the no-flags build, and the CMP, follow an FCMP (floating-point compare), and are floating-point only; the LLVM ones likewise. `fcmp`, `fcmp32`: the flags remain for floating-point in both compilers.'); p()
# T5 intersection
both = [k for k in ok if 'fail' not in llvm[k]]
p('### T5. The files all three builds compile (%d files)' % len(both)); p()
p('| | instructions | bytes (plain) | bytes per instruction |'); p('|---|---:|---:|---:|')
for lab, d in (('pcc baseline', base), ('pcc no flags', nf), ('LLVM -O2', llvm)):
    a, b = S(d, both, 'plain_insn'), S(d, both, 'plain_bytes'); p(f'| {lab} | {a} | {b} | {b/a:.2f} |')
a, b = S(nf, both, 'plain_insn'), S(llvm, both, 'plain_insn'); c, d_ = S(nf, both, 'plain_bytes'), S(llvm, both, 'plain_bytes')
p(f'| LLVM against pcc no-flags | {P(a,b):+.1f}% | {P(c,d_):+.1f}% | |'); p()
# T6 dynamic
R = lambda n: {x['name']: x for x in json.load(open(f'{W}/out/{n}.run.json'))}
rb, rs, rn, rl = R('base'), R('nosetcc'), R('nf'), R('llvm')
progs = [k for k in rb if all('fail' not in r[k] for r in (rb, rn, rl))]
same = [k for k in progs if rb[k]['output'] == rn[k]['output'] == rl[k]['output']]
big = [k for k in progs if rb[k]['scalar']['insns'] >= 100000]
def dyn(title, ks):
    p(f'### {title}'); p()
    p('| program | insns base | insns no-flags | % | bytes fetched base | % | scalar cycles base | % | dual cycles base | % | LLVM insns | LLVM scalar cycles | LLVM dual cycles | output |'); p('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|')
    for k in ks:
        g = lambda r, pr, f: r[k][pr][f]
        p(f"| {k} | {g(rb,'scalar','insns')} | {g(rn,'scalar','insns')} | {P(g(rb,'scalar','insns'),g(rn,'scalar','insns')):+.2f} | {g(rb,'scalar','bytes')} | {P(g(rb,'scalar','bytes'),g(rn,'scalar','bytes')):+.2f} | {g(rb,'scalar','cycles')} | {P(g(rb,'scalar','cycles'),g(rn,'scalar','cycles')):+.2f} | {g(rb,'dual','cycles')} | {P(g(rb,'dual','cycles'),g(rn,'dual','cycles')):+.2f} | {g(rl,'scalar','insns')} | {g(rl,'scalar','cycles')} | {g(rl,'dual','cycles')} | {'equal' if k in same else 'DIFFERENT'} |")
    tot = lambda r, pr, f: sum(r[k][pr][f] for k in ks)
    p(f"| **total ({len(ks)} programs)** | {tot(rb,'scalar','insns')} | {tot(rn,'scalar','insns')} | {P(tot(rb,'scalar','insns'),tot(rn,'scalar','insns')):+.2f} | {tot(rb,'scalar','bytes')} | {P(tot(rb,'scalar','bytes'),tot(rn,'scalar','bytes')):+.2f} | {tot(rb,'scalar','cycles')} | {P(tot(rb,'scalar','cycles'),tot(rn,'scalar','cycles')):+.2f} | {tot(rb,'dual','cycles')} | {P(tot(rb,'dual','cycles'),tot(rn,'dual','cycles')):+.2f} | {tot(rl,'scalar','insns')} | {tot(rl,'scalar','cycles')} | {tot(rl,'dual','cycles')} | |")
    p()
dyn('T6. Dynamic: the programs that run on sim64 (programs of 100,000 instructions or more)', big)
p('Totals of the same programs for the other timing presets (cycles; base, no-flags, % ; LLVM):'); p()
p('| preset | baseline | no flags | % | LLVM |'); p('|---|---:|---:|---:|---:|')
for pr in ('scalar', 'dual', 'scalar-c', 'dual-c'):
    a = sum(rb[k][pr]['cycles'] for k in big); b = sum(rn[k][pr]['cycles'] for k in big); c = sum(rl[k][pr]['cycles'] for k in big)
    p(f'| {pr} | {a} | {b} | {P(a,b):+.2f} | {c} |')
p()
dyn('T7. Dynamic: all the programs (adds the 5 + 20 small test programs)', progs)
# T8 dynamic mix
dm = json.load(open(f'{W}/out/dynmix.json'))
p('### T8. Executed compare, branch and flag instructions (all %d programs, sim64 -P)' % len(progs)); p()
p('| kind | pcc baseline | pcc no flags | LLVM |'); p('|---|---:|---:|---:|')
for kname in ('cmp', 'tst', 'flag branch', 'set', 'cbCC', 'br/jmp', 'sob', 'total'):
    vals = []
    for lab in ('base', 'nf', 'llvm'):
        vals.append(sum(dm[lab][k.replace('/', '_')].get(kname, 0) for k in progs if k.replace('/', '_') in dm[lab]))
    p(f'| {kname} | {vals[0]} | {vals[1]} | {vals[2]} |')
p()
open(f'{W}/final/tables.md', 'w').write('\n'.join(out) + '\n')
# per-file csv
with open(f'{W}/final/static-per-file.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['file', 'group', 'pcc_base_insn', 'pcc_base_bytes', 'pcc_base_relaxed', 'pcc_nf_insn', 'pcc_nf_bytes', 'pcc_nf_relaxed', 'llvm_insn', 'llvm_bytes', 'llvm_relaxed', 'pcc_error', 'llvm_error'])
    for k, x in base.items():
        g = lambda d, f_: d[k].get(f_, '') if 'fail' not in d[k] else ''
        w.writerow([k, x['group'], g(base, 'plain_insn'), g(base, 'plain_bytes'), g(base, 'relax_text'), g(nf, 'plain_insn'), g(nf, 'plain_bytes'), g(nf, 'relax_text'),
                    g(llvm, 'plain_insn'), g(llvm, 'plain_bytes'), g(llvm, 'relax_text'), x.get('fail', '')[:90], llvm[k].get('fail', '')[:90]])
with open(f'{W}/final/dynamic.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['program', 'output_equal', 'variant', 'preset', 'insns', 'bytes_fetched', 'cycles'])
    for k in progs:
        for lab, r in (('pcc-base', rb), ('pcc-noflags', rn), ('llvm', rl)):
            for pr in ('scalar', 'dual', 'scalar-c', 'dual-c'):
                w.writerow([k, k in same, lab, pr, r[k][pr]['insns'], r[k][pr]['bytes'], r[k][pr]['cycles']])
print('\n'.join(out))
# per-file kinds
with open(f'{W}/final/static-kinds-per-file.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['file'] + [f'{lab}:{kk}' for lab in ('pcc_base', 'pcc_noflags', 'llvm') for kk in KIND])
    for k in base:
        row = [k]
        for d in (base, nf, llvm):
            if 'fail' in d[k]: row += [''] * len(KIND)
            else:
                kd, _ = kinds(d, [k]); row += [kd[a] for a in KIND]
        w.writerow(row)

#!/usr/bin/env python3
"""adacheck.py -- what Ada's run-time checks cost, on real Ada code: the GNAT run-time library (the .adb bodies of adainclude).

usage: adacheck.py ADAINCLUDE OUTDIR [-j N] [-n MAXFILES]

Each body is compiled to assembly twice for x86-64 with `gcc -c -O2 -gnat2022 -gnatg -gnatws`: with GNAT's default checks (index, range, overflow, length,
access, division, discriminant) and with `-gnatp` (all checks suppressed).  From the assembly:
  * instructions (lines that begin with a mnemonic) with and without the checks: the price of Ada's checks in instructions;
  * the check sites: a conditional jump whose target block calls `__gnat_rcheck_CE_<kind>` or `__gnat_rcheck_PE_<kind>`, by kind;
  * for the index and range checks, the shape of the compare: `biased` when the compared value was first reduced by a constant (lea -N, sub, add $-N: the lower
    bound is not zero, which Ada's arrays starting at 1 make the usual case, folded by an unsigned compare into one test of a band), against a `constant` or a
    `register` bound, `unbiased` otherwise.
Writes OUTDIR/ada-files.csv, ada-sites.csv and ada-summary.md.  The sites are those of x86-64 code of GCC: the shapes carry over, the counts are of this target."""
import os, re, sys, subprocess, tempfile, collections, concurrent.futures as cf

adainc, out = sys.argv[1:3]
jobs, maxn = 2, 10 ** 9
a = sys.argv[3:]
i = 0
while i < len(a):
    if a[i] == '-j': jobs = int(a[i + 1]); i += 2
    elif a[i] == '-n': maxn = int(a[i + 1]); i += 2
    else: i += 1

CALL = re.compile(r'\bcall\s+__gnat_rcheck_([A-Z]{2}_\w+)')
INS = re.compile(r'^\s+([a-z][a-z0-9]*)\b')
JCC = re.compile(r'^\s+(j(?:a|ae|b|be|g|ge|l|le|e|ne|s|ns|c|nc|nb|nbe|na|nae|ng|nge|nl|nle|z|nz|o|no))\s+(\.L\w+)')
LABEL = re.compile(r'^(\.L\w+):')


def compile_one(src, flags):
    with tempfile.TemporaryDirectory() as w:
        s = w + '/x.s'
        p = subprocess.run(['gcc-14', '-c', '-S', '-O2', '-gnat2022', '-gnatg', '-gnatws', '-I' + adainc, '-I-'] + flags + [src, '-o', s],
                           capture_output=True, text=True, errors='replace', timeout=600, cwd=w)
        if p.returncode or not os.path.exists(s):
            return None
        return open(s, errors='replace').read()


def analyse(asm):
    lines = asm.split('\n')
    ninsn = sum(1 for l in lines if INS.match(l) and not l.lstrip().startswith('.'))
    # blocks: label -> the check kind called before the next label or return
    kind_of = {}
    cold = {}
    cur = None
    for l in lines:
        m = LABEL.match(l)
        if m:
            cur = m.group(1)
            cold[cur] = 0
            continue
        if cur:
            if INS.match(l):
                cold[cur] = cold.get(cur, 0) + 1
            c = CALL.search(l)
            if c:
                kind_of[cur] = c.group(1)
                cur = None
            elif re.match(r'^\s+(ret|jmp)\b', l):
                cur = None
    sites = []
    hist = []
    coldins = sum(cold[k] for k in kind_of if 'Explicit_Raise' not in kind_of[k])			# the instructions of the cold blocks that call a check routine, each block once
    for l in lines:
        m = JCC.match(l)
        if m and m.group(2) in kind_of:
            k = kind_of[m.group(2)]
            back = [h for h in hist[-4:]]
            biased = any(re.match(r'\s+(leal?|subl?|addl?)\s+.*(-\d+|\$-?\d+)', h) and ('lea' in h or 'sub' in h or 'add' in h) for h in back[:-1])
            cmpl = next((h for h in reversed(back) if re.match(r'\s+cmp', h)), '')
            bound = 'constant' if re.search(r'\$-?\d+', cmpl) else 'register' if cmpl else 'other'
            sites.append((k, 'biased' if biased else 'unbiased', bound, m.group(1)))
        if INS.match(l):
            hist.append(l)
    return ninsn, sites, coldins


def one(src):
    base = os.path.basename(src)
    c = compile_one(src, [])
    n = compile_one(src, ['-gnatp'])
    if c is None or n is None:
        return base, None
    ic, sc, cold = analyse(c)
    inn, _, _ = analyse(n)
    return base, (ic, inn, sc, cold)


def main():
    srcs = sorted(os.path.join(adainc, f) for f in os.listdir(adainc) if f.endswith('.adb'))[:maxn]
    os.makedirs(out, exist_ok=True)
    rows, sites = [], []
    with cf.ThreadPoolExecutor(jobs) as ex:
        for base, r in ex.map(one, srcs):
            if r is None:
                rows.append((base, 'fail', 0, 0, 0, 0)); continue
            ic, inn, sc, cold = r
            rows.append((base, 'ok', ic, inn, sum(1 for s in sc if 'Explicit_Raise' not in s[0]), cold))
            sites += [(base,) + s for s in sc if 'Explicit_Raise' not in s[0]]
    with open(out + '/ada-files.csv', 'w') as f:
        f.write('file,status,ins_checked,ins_unchecked,check_sites,cold_block_ins\n')
        for r in rows:
            f.write(','.join(str(x) for x in r) + '\n')
    with open(out + '/ada-sites.csv', 'w') as f:
        f.write('file,kind,shape,bound,jump\n')
        for s in sites:
            f.write(','.join(s) + '\n')
    ok = [r for r in rows if r[1] == 'ok']
    ti, tn = sum(r[2] for r in ok), sum(r[3] for r in ok)
    kinds = collections.Counter(s[1] for s in sites)
    L = ['%d of %d bodies compiled; instructions with the default checks %s, with all checks suppressed %s: the checks add %s (%.1f%%); check sites %d (%.2f per 100 instructions)' % (
        len(ok), len(rows), '{:,}'.format(ti), '{:,}'.format(tn), '{:,}'.format(ti - tn), 100.0 * (ti - tn) / tn if tn else 0, len(sites), 100.0 * len(sites) / ti if ti else 0), '']
    cb = sum(r[5] for r in ok)
    L += ['The cold blocks that call a check routine hold %s instructions (%.1f%% of the code, %.1f per check site; a block shared by several jumps is counted once): what a table-driven trap that carries no arguments would remove.' % ('{:,}'.format(cb), 100.0 * cb / ti if ti else 0, cb / len(sites) if sites else 0), '']
    L += ['| kind | sites | share |', '|---|---:|---:|']
    for k, v in kinds.most_common():
        L.append('| %s | %d | %.1f%% |' % (k, v, 100.0 * v / len(sites)))
    ix = [s for s in sites if s[1] in ('CE_Index_Check', 'CE_Range_Check')]
    if ix:
        sh = collections.Counter((s[2], s[3]) for s in ix)
        L += ['', 'Index and range checks (%d): ' % len(ix) + ', '.join('%s, %s bound: %d (%.0f%%)' % (k[0], k[1], v, 100.0 * v / len(ix)) for k, v in sh.most_common())]
    open(out + '/ada-summary.md', 'w').write('\n'.join(L) + '\n')
    print('\n'.join(L))


if __name__ == '__main__':
    main()

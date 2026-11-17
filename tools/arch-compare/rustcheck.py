#!/usr/bin/env python3
"""rustcheck.py -- what Rust's run-time checks cost on four instruction sets: bounds, slicing, overflow, unwrap.

usage: rustcheck.py OUTDIR [-j N] FILE.rs ...

Each file is compiled by rustc 1.9x as a library at opt-level 3 with overflow checks on (`-C overflow-checks=on`, the debug-assertions
default of a checked build; the bounds checks are always on) to LLVM IR and to x86-64 assembly.  The IR is then compiled by clang (`-x ir -O2`)
for aarch64, riscv64 and loongarch64 (rustc here has only the x86-64 library, so these are LLVM's lowering of rustc's IR, not a native rustc build;
the x86-specific attributes are removed from the IR first).  From the assembly of each target:
  * instructions;
  * check sites: a conditional jump or branch whose target block calls a panic routine of the core library, by kind: bounds (`panic_bounds_check`),
    slice (`slice_*_fail`), arithmetic (`panic_const_*` overflow, divide and remainder by zero), unwrap (`unwrap_failed`, `expect_failed`), other;
  * the cold blocks: the instructions from the label of such a block to its call, each block once.
Writes OUTDIR/rust-files.csv, rust-sites.csv and rust-summary.md."""
import os, re, sys, subprocess, tempfile, collections, concurrent.futures as cf

out = sys.argv[1]
jobs = 2
files = []
a = sys.argv[2:]
i = 0
while i < len(a):
    if a[i] == '-j': jobs = int(a[i + 1]); i += 2
    else: files.append(a[i]); i += 1

TARGETS = [('x86_64', None), ('aarch64', 'aarch64-linux-gnu'), ('riscv64', 'riscv64-linux-gnu'), ('loongarch64', 'loongarch64-linux-gnu')]
KINDS = [('bounds', re.compile(r'panic_bounds_check')),
         ('slice', re.compile(r'slice_(index_order|start_index_len|end_index_len|end_index_overflow|start_index_overflow|index|len)_fail|slice_index_fail|slice_.*_fail')),
         ('arith', re.compile(r'panic_const_\w*(overflow|div_by_zero|rem_by_zero|neg)\w*|attempt_to|panic_arith')),
         ('unwrap', re.compile(r'unwrap_failed|expect_failed|unwrap_none|expect_none')),
         ('other', re.compile(r'core\w*9panicking\w*|panic_fmt|panic_display|panic_explicit|panic_nounwind|panic_str|handle_alloc_error|capacity_overflow|alloc_error'))]
LABEL = re.compile(r'^(\.L(?!pcrel|tmp|func_end)[\w$.]+|\.LBB[\w$.]+):')		# not the .Lpcrel_hi labels of RISC-V and LoongArch relocations
INS = re.compile(r'^\s+([a-z][a-z0-9_.]*)\b')
COND = re.compile(r'^\s+(j[a-z]+|b\.[a-z]+|b(?:eq|ne|lt|ge|ltu|geu|le|gt|gtu|leu|eqz|nez)|cb\w*|tb\w*|beqz|bnez)\s+(.*)$')


def run(cmd, **k):
    return subprocess.run(cmd, capture_output=True, text=True, errors='replace', timeout=1800, **k)


def kind_of_line(l):
    if not re.search(r'\b(call|callq|jmp|b|bl|tail|jalr?|jirl|blr|br)\b', l) and 'panic' not in l and 'fail' not in l:
        return None
    for k, rx in KINDS:
        if rx.search(l):
            return k
    return None


def analyse(asm):
    lines = asm.split('\n')
    cold, kinds, cur = {}, {}, None
    for l in lines:
        m = LABEL.match(l)
        if m:
            cur = m.group(1); cold[cur] = 0
            continue
        if cur:
            if INS.match(l) and not l.lstrip().startswith('.'):
                cold[cur] += 1
            k = kind_of_line(l) if INS.match(l) else None
            if k:
                kinds[cur] = k
                cur = None
            elif re.match(r'^\s+(ret|retq|jr|br\s+x30)\b', l):
                cur = None
    ninsn = sum(1 for l in lines if INS.match(l) and not l.lstrip().startswith('.'))
    sites = []
    for l in lines:
        m = COND.match(l)
        if m:
            tgt = m.group(2).split(',')[-1].strip().split()[0] if m.group(2).strip() else ''
            if tgt in kinds:
                sites.append(kinds[tgt])
    # a block reached by a fall-through of an unconditional jump is not counted as a site
    return ninsn, sites, sum(cold[k] for k in kinds), len(kinds)


def one(src):
    base = os.path.basename(src)[:-3]
    res = {}
    with tempfile.TemporaryDirectory() as w:
        ll = w + '/x.ll'; s = w + '/x.s'
        p = run(['rustc', '--edition', '2021', '--crate-type=lib', '-C', 'opt-level=3', '-C', 'overflow-checks=on', '-A', 'warnings',
                 '--emit=llvm-ir,asm', '-o', w + '/x', src])
        for f in os.listdir(w):
            if f.endswith('.ll'): ll = os.path.join(w, f)
            if f.endswith('.s'): s = os.path.join(w, f)
        if p.returncode or not os.path.exists(s):
            return base, None
        res['x86_64'] = analyse(open(s, errors='replace').read())
        ir = open(ll, errors='replace').read()
        ir = re.sub(r'"target-cpu"="[^"]*"', '', ir)
        ir = re.sub(r'"target-features"="[^"]*"', '', ir)
        ir = re.sub(r'^target (datalayout|triple) = .*$', '', ir, flags=re.M)
        open(w + '/y.ll', 'w').write(ir)
        for name, tr in TARGETS[1:]:
            q = run(['clang', '--target=' + tr, '-O2', '-x', 'ir', '-S', '-w', w + '/y.ll', '-o', '-'])
            if q.returncode == 0:
                res[name] = analyse(q.stdout)
    return base, res


def main():
    os.makedirs(out, exist_ok=True)
    rows = []
    with cf.ThreadPoolExecutor(jobs) as ex:
        for base, res in ex.map(one, files):
            rows.append((base, res))
    with open(out + '/rust-files.csv', 'w') as f:
        f.write('file,target,instructions,check_sites,cold_instructions,cold_blocks,bounds,slice,arith,unwrap,other\n')
        for base, res in rows:
            if res is None:
                f.write('%s,fail,,,,,,,,,\n' % base); continue
            for t, (n, sites, cold, nb) in res.items():
                c = collections.Counter(sites)
                f.write('%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d\n' % (base, t, n, len(sites), cold, nb, c['bounds'], c['slice'], c['arith'], c['unwrap'], c['other']))
    L = ['| target | files | instructions | check sites | per 100 instructions | cold block instructions | per site | bounds | slice | arithmetic | unwrap | other |', '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
    for t, _ in TARGETS:
        rs = [res[t] for _, res in rows if res and t in res]
        if not rs:
            continue
        n = sum(r[0] for r in rs); s = sum(len(r[1]) for r in rs); cold = sum(r[2] for r in rs)
        c = collections.Counter(k for r in rs for k in r[1])
        L.append('| %s | %d | %s | %s | %.2f | %s | %.1f | %d | %d | %d | %d | %d |' % (t, len(rs), '{:,}'.format(n), '{:,}'.format(s), 100.0 * s / n if n else 0, '{:,}'.format(cold), cold / s if s else 0, c['bounds'], c['slice'], c['arith'], c['unwrap'], c['other']))
    open(out + '/rust-summary.md', 'w').write('\n'.join(L) + '\n')
    print('\n'.join(L))


if __name__ == '__main__':
    main()

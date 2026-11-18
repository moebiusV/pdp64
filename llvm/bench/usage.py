#!/usr/bin/env python3
"""
usage.py -- which vector instructions the compiled kernels use (writes llvm/vector-usage.md; the input of the next run of the encoding optimiser).

It compiles the kernels of the study (docs/encoding-work/arch-data/vec-forms, llvm/bench/simple.c) and the test programs llvm/tests/vec/*.c with clang and
llc -pdp64-vecloop, reads the vec blocks of the assembly (the lines between the `;APP` and `;NO_APP` of the inline assembly), and counts for each mnemonic of the
vector family of the grammar (the list in llvm/target/PDP64/gen/PDP64GenLayout.h, made from spec/pdp64/pdp64.hbnf): the blocks and the functions that use it.
A word of the grammar that no kernel uses is a dud for this compiler.   usage.py [--out file]
"""
import os, re, subprocess, sys, tempfile, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
R = os.path.dirname(os.path.dirname(HERE))
LLC = os.path.join(os.path.dirname(R), 'llvm-build', 'bin', 'llc')
VF = os.path.join(R, 'docs', 'encoding-work', 'arch-data', 'vec-forms')
SRCS = [os.path.join(VF, 'kernels.c'), os.path.join(VF, 'games', 'games.c'), os.path.join(VF, 'blas', 'blas.c'), os.path.join(VF, 'seg', 'seg.c'),
        os.path.join(HERE, 'simple.c'), os.path.join(HERE, 'newk.c')] + sorted(os.path.join(R, 'llvm', 'tests', 'vec', f) for f in os.listdir(os.path.join(R, 'llvm', 'tests', 'vec')) if f.endswith('.c')) + [os.path.join(R, 'llvm', 'tests', 'vec_lane_ops.ll'), os.path.join(R, 'llvm', 'tests', 'vec_w1_scalar.ll'), os.path.join(R, 'llvm', 'tests', 'vec_w2_scalar.ll')]
CFLAGS = ['-O2', '-m64', '-fno-builtin-memset', '-fno-builtin-memcpy', '-fno-stack-protector', '-mlong-double-64', '-mno-sse', '-mno-mmx', '-fno-vectorize', '-fno-slp-vectorize',
          '-fno-unroll-loops', '-ffp-contract=fast', '-ffast-math', '-w', '-S', '-emit-llvm']

# the groups of vec-isa.md section 2, for the table
GROUPS = [
    ('block', ['vec', 'vend', 'vfin']),
    ('load, store', ['vld', 'vst']),
    ('saturating narrow', ['vsts']),
    ('strided', ['vldt', 'vstt']),
    ('segment', ['vlseg2', 'vlseg3', 'vlseg4', 'vsseg2', 'vsseg3', 'vsseg4']),
    ('lane operations', ['vadd', 'vsub', 'vsubr', 'vmul', 'vand', 'vor', 'vxor', 'vshl', 'vshr', 'vsar', 'vabd', 'vabdu', 'vmin', 'vmax', 'vminu', 'vmaxu', 'vmov', 'vneg', 'vavg', 'vavgu', 'vmulh', 'vmulhu', 'vmulhr', 'vsarr', 'vshrr']),
    ('saturating', ['vadds', 'vsubs', 'vaddsu', 'vsubsu']),
    ('multiply-add', ['vmla', 'vfma', 'vfnma', 'vfmab']),
    ('dot', ['vdot', 'vdotu', 'vdotsu', 'vdacc', 'vsad']),
    ('table lookup', ['vtbl']),
    ('compare, select, conversion (wave 2)', ['vceq', 'vcgt', 'vcgtu', 'vbsl', 'vcvt']),
    ('reductions', ['vacc', 'vmaxacc', 'vminacc']),
    ('sliding window', ['vfir']),
    ('accumulators', ['vclr']),
]

OPT = os.path.join(os.path.dirname(R), 'llvm-build', 'bin', 'opt')

def collect(variant, allmn, tmp):
    """the vec blocks of the assembly of every source, for the stage-2 recogniser of scalar loops (variant 'vecloop': clang -O2 -fno-vectorize, llc -pdp64-vecloop) or for
    LoopVectorize's output (variant 'lv': clang -O2 -Xclang -disable-llvm-passes, opt -passes='default<O2>' -mtriple=pdp64, llc)"""
    use = {}         # mnemonic -> list of (source, function)
    nfun = set()
    nblocks = 0
    for src in SRCS:
        n = os.path.basename(src).rsplit('.', 1)[0] + '.' + variant
        ll = os.path.join(tmp, n + '.ll')
        if src.endswith('.ll'):
            txt = open(src).read()
        else:
            fl = CFLAGS if variant == 'vecloop' else [f for f in CFLAGS if f not in ('-fno-vectorize', '-fno-slp-vectorize', '-fno-unroll-loops', '-O2')] + ['-O2', '-Xclang', '-disable-llvm-passes', '-fno-unroll-loops']
            r = subprocess.run(['clang'] + fl + ['-o', ll + '.0', src], capture_output=True, text=True)
            if r.returncode: continue
            txt = open(ll + '.0').read()
            txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M); txt = re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
        if variant == 'lv':
            open(ll + '.1', 'w').write(txt)
            r = subprocess.run([OPT, '-mtriple=pdp64-unknown-elf', '-passes=default<O2>', '-S', ll + '.1', '-o', ll], capture_output=True, text=True)
            if r.returncode: print('opt failed on', src, r.stderr[:200]); continue
            flags = []
        else:
            open(ll, 'w').write(txt)
            flags = ['-pdp64-vecloop']
        r = subprocess.run([LLC, '-mtriple=pdp64-unknown-elf', '-O2'] + flags + [ll, '-o', ll[:-3] + '.s'], capture_output=True, text=True)
        if r.returncode: print('llc failed on', src, r.stderr[:200]); continue
        fn = None; inasm = False
        for ln in open(ll[:-3] + '.s'):
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):', ln)
            if m and not ln.startswith('.L'): fn = m.group(1)
            if ln.strip() == ';APP': inasm = True; continue
            if ln.strip() == ';NO_APP': inasm = False; continue
            if inasm:
                w = ln.split()
                if w and (w[0] in ('vec', 'vend') or re.match(r'^(v[a-z0-9]+|gemm)\.', w[0]) or w[0] in allmn):
                    mn = w[0]
                    use.setdefault(mn, []).append((n, fn))
                    if mn == 'vec': nblocks += 1
                    nfun.add((n, fn))
    return use, nblocks, nfun

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out'); a = ap.parse_args()
    hdr = open(os.path.join(R, 'llvm', 'target', 'PDP64', 'gen', 'PDP64GenLayout.h')).read()
    allmn = re.findall(r'X\("([a-z0-9.]+)"\)', hdr[hdr.index('PDP64_VEC_MNEMONICS'):])
    tmp = tempfile.mkdtemp()
    V = {v: collect(v, allmn, tmp) for v in ('vecloop', 'lv')}
    use_all = {}
    for v in V:
        for m, l in V[v][0].items(): use_all.setdefault(m, []).extend(l)
    def base(m): return m.split('.')[0]
    out = []
    out.append('# Which vector instructions the compiled kernels use\n')
    out.append('Generated by `llvm/bench/usage.py` from the blocks in the assembly of %d programs (the kernels of `docs/encoding-work/arch-data/vec-forms/`: `kernels.c`, `games`, `blas`, `seg`; '
               '`llvm/bench/simple.c`, `llvm/bench/newk.c` (the kernels of waves 1 and 2); `llvm/tests/vec/*.c`; `llvm/tests/vec_lane_ops.ll`, `vec_w1_scalar.ll`, `vec_w2_scalar.ll`), compiled two ways: **vecloop** = the stage-2 recogniser of SCALAR loops (`clang -O2 -fno-vectorize`, `llc -pdp64-vecloop`): '
               '%d blocks in %d functions; **lv** = LLVM\'s own LoopVectorize (`clang -O2 -Xclang -disable-llvm-passes`, `opt -passes=\'default<O2>\' -mtriple=pdp64-unknown-elf`, `llc`; PDP64VecLoop lowers its '
               'vector loops): %d blocks in %d functions. The words are those of the vector family of the grammar (%d mnemonics). **A static count is a count of instructions in the blocks; the dynamic counts '
               '(vector instructions executed, elements) are in `llvm/bench/results.csv` and `llvm/README.md`.** Re-run: `llvm/bench/usage.py --out llvm/vector-usage.md`.\n'
               % (len(SRCS), V['vecloop'][1], len(V['vecloop'][2]), V['lv'][1], len(V['lv'][2]), len(allmn)))
    # by base
    def bybase_of(use):
        bb = {}
        for m, l in use.items(): bb.setdefault(base(m), []).extend(l)
        return bb
    BB = {v: bybase_of(V[v][0]) for v in V}
    BA = bybase_of(use_all)
    out.append('## By instruction (base mnemonic, all lane and memory suffixes together)\n')
    out.append('Static uses in the blocks of each build; "words used" and "functions" are for the union of the two.\n')
    out.append('| group | instruction | words in the grammar | words used | static uses: vecloop | static uses: lv | functions that use it (union) | used by |\n|---|---|---:|---:|---:|---:|---:|---|')
    duds = []
    for g, bases in GROUPS:
        for b in bases:
            words = [m for m in allmn if base(m) == b]
            used = sorted(set(m for m in use_all if base(m) == b))
            l = BA.get(b, [])
            fns = sorted(set(f for _, f in l))
            if not l: duds.append((g, b, len(words)))
            out.append('| %s | `%s` | %d | %d | %d | %d | %d | %s |' % (g, b, len(words), len(used), len(BB['vecloop'].get(b, [])), len(BB['lv'].get(b, [])), len(fns),
                       ', '.join(fns[:6]) + (' ...' if len(fns) > 6 else '') if fns else '**none: a dud for this compiler**'))
    nbase = len([1 for g, bases in GROUPS for b in bases])
    usedbase = nbase - len(duds)
    out.append('\n**Base mnemonics used: %d of %d by either build (vecloop %d, lv %d); %d never.**\n' % (usedbase, nbase,
               len([1 for g, bases in GROUPS for b in bases if BB['vecloop'].get(b)]), len([1 for g, bases in GROUPS for b in bases if BB['lv'].get(b)]), len(duds)))
    only_lv = sorted(b for g, bases in GROUPS for b in bases if BB['lv'].get(b) and not BB['vecloop'].get(b))
    only_vl = sorted(b for g, bases in GROUPS for b in bases if BB['vecloop'].get(b) and not BB['lv'].get(b))
    out.append('Used by LoopVectorize\'s build and not by the scalar recogniser: %s. Used by the scalar recogniser and not by LoopVectorize: %s.\n' %
               (', '.join('`%s`' % b for b in only_lv) or 'none', ', '.join('`%s`' % b for b in only_vl) or 'none'))
    out.append('\n## The words that are used (mnemonic with suffixes)\n')
    out.append('| word | static uses: vecloop | static uses: lv | functions (union) |\n|---|---:|---:|---:|')
    for m in sorted(use_all):
        out.append('| `%s` | %d | %d | %d |' % (m, len(V['vecloop'][0].get(m, [])), len(V['lv'][0].get(m, [])), len(set(f for _, f in use_all[m]))))
    unused_words = [m for m in allmn if m not in use_all]
    out.append('\n## Words of the grammar that no kernel uses\n')
    out.append('%d of the %d words of the family are not used by either build (%d used). By base mnemonic (words unused / words in the grammar):\n' % (len(unused_words), len(allmn), len(allmn) - len(unused_words)))
    ub = {}
    for m in allmn:
        ub.setdefault(base(m), [0, 0]); ub[base(m)][1] += 1
        if m not in use_all: ub[base(m)][0] += 1
    out.append(', '.join('`%s` %d/%d' % (b, v[0], v[1]) for b, v in sorted(ub.items())) + '\n')
    out.append('\n## Instructions no kernel used, and why (what a compiler would need)\n')
    why = {
        'vfin': 'the epilogue of a block with accumulators (errata 173): only a block that names accumulators (vclr) or uses vfmab has one, and the pass makes no accumulators',
        'vclr': 'hidden accumulation across strips: nothing reads an accumulator after the block ends (there is no vector-to-scalar move outside a block), so a block that needs one reduces inside it (`vacc` each strip), which is what both compilers do',
        'vfir': 'a window of consecutive loads times invariant taps (put8h): LoopVectorize does not vectorise it (too many live vectors), the scalar recogniser makes eight shifted streams; neither makes `vfir`',
        'vlseg2': 'LoopVectorize\'s interleaved groups with every field used ARE these (see the `lv` column); `vlseg2` is used by k_split and k_cmul', 'vlseg3': 'a three-field load group (rgb to planes): no kernel of the set has one', 'vlseg4': 'the 4-field groups of k_vtxaos (used when the build has it)',
        'vsseg2': 'as `vlseg2` (stores)', 'vsseg3': 'rgb interleave (tests/vec/lv_seg.c)', 'vsseg4': 'as `vlseg4` (stores)',
        'vdot': 'subsumed: a dot product (k_q8dot) is a reduction, and `vdacc.b` / `vdacc.w` sum a whole strip into the scalar register in ONE instruction, which `vdot` followed by `vacc` cannot beat; `vdot` writes 32-bit lanes of a vector and so keeps the strip at 8 lanes; LLVM would reach it only as a partial reduction (`llvm.vector.partial.reduce.add`, a vector accumulator that lives across strips: the block model has none)',
        'vdotu': 'same', 'vdotsu': 'same',
        'vfmab': 'the broadcast multiply-add of a GEMM micro-kernel: needs a loop nest, not an innermost loop',
        'vabdu': 'the kernels take `abs(a - b)` of widened bytes: the signed `vabd` serves (and `vsad.bu` for a sum of them)',
        'vmulhr': 'used only with the saturation written out (`min(x, 32767)`): not used if no kernel has the Q15 idiom', 'vtbl': 'a 16-byte table lookup is a gather (`c[i] = tbl[a[i] & 15]`) in IR and LoopVectorize refuses it (memory conflicts, no masked gather); there is no intrinsic: assembly only',
    }
    supported = {'vsub', 'vor', 'vmax', 'vminu', 'vmaxu', 'vneg', 'vsubs', 'vaddsu', 'vsubsu', 'vminacc', 'vsubr', 'vand', 'vxor'}
    for g, b, nw in duds:
        out.append('* `%s` (%s, %d words): %s' % (b, g, nw, why.get(b, 'the pass emits it, but no kernel of this set has the operation' if b in supported else '')))
    txt = '\n'.join(out) + '\n'
    if a.out: open(a.out, 'w').write(txt)
    else: print(txt)
main()

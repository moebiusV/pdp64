#!/usr/bin/env python3
"""vsurvey-freq.py ROOTDIR OUT.tsv -- count the vector instruction mnemonics (assembly sources) and intrinsics (C sources) of
hand-written code, for each (isa, project).  Reads text only; nothing from the sources is run.

usage: python3 -I vsurvey-freq.py SRCROOT OUT.tsv

SRCROOT holds one directory for each project (dav1d, FFmpeg, llama.cpp, OpenBLAS, libjpeg-turbo, libyuv, zlib-ng).
Output columns: isa, project, kind (asm|intr), token, count, files.
Method: assembly = the first word of each line after comments and labels are removed, case-folded; NASM and gas macro names
are therefore counted once where they are defined or used, not once for each expansion (a source count, not a
count of assembled instructions).  Intrinsics = every call of a name of the family (the type suffix is cut)."""
import os, re, sys, glob, collections

root, out = sys.argv[1], sys.argv[2]

def files(pat_list):
    r = []
    for p in pat_list:
        r += glob.glob(os.path.join(root, p), recursive=True)
    return sorted(set(f for f in r if os.path.isfile(f)))

def rd(f):
    with open(f, 'rb') as h:
        return h.read().decode('utf-8', 'replace')

def strip_c_comments(t):
    t = re.sub(r'/\*.*?\*/', ' ', t, flags=re.S)
    return t

# ---------------------------------------------------------------- assembly
def asm_tokens(f, kind):
    t = rd(f)
    if kind in ('arm', 'rv', 'la', 'ppc'):
        t = strip_c_comments(t)
    toks = []
    for ln in t.split('\n'):
        if kind == 'x86':
            ln = re.sub(r';.*', '', ln)
        else:
            ln = re.sub(r'//.*', '', ln)
            ln = re.sub(r'(^|\s)#(?!\w).*$', '', ln) if kind in ('rv', 'la') else ln
        ln = ln.strip()
        if not ln or ln[0] in '#%.@' and not ln.startswith('.macro'):
            continue
        ln = re.sub(r'^[A-Za-z_.$][\w.$]*:\s*', '', ln)     # label
        ln = re.sub(r'^\d+:\s*', '', ln)
        m = re.match(r'([A-Za-z_][\w.]*)', ln)
        if not m:
            continue
        w = m.group(1)
        if kind == 'x86':
            if w != w.lower():
                continue                                  # NASM and x86inc macros are in upper case
        if kind == 'arm':
            isv = re.search(r'\{?\b[vz]\d+\b|\{\s*[vz]\d|\b[vz]\d+\.|\bq\d+\b|\bp\d+\b|\b[vz]\d+\[', ln[m.end():]) is not None
            w = ('V:' if isv else 'S:') + w
        toks.append(w.lower() if kind != 'x86' else w)
    return toks

def norm_arm(w):
    p, w = w[:2], w[2:]
    return p + w.split('.')[0]

def norm_rv(w):
    w = w.split('.')[0]
    return w

def norm_la(w):
    return w.split('.')[0] if not w.startswith(('vld', 'xvld', 'vst', 'xvst')) else w.split('.')[0]

# ---------------------------------------------------------------- intrinsics
RE_X86 = re.compile(r'\b_mm(256|512)?_([a-z0-9_]+)\s*\(')
RE_NEON = re.compile(r'\b(v[a-z0-9]+?)(q?)((?:_high|_lane|_laneq|_n)*)_(?:[suf](?:8|16|32|64)|p(?:8|16|64)|bf16)\s*(?:_x[234])?\s*\(')
RE_NEON2 = re.compile(r'\b(vld[1-4]q?|vst[1-4]q?)(_dup|_lane)?_(?:[suf](?:8|16|32|64)|p8)(_x[234])?\s*\(')
RE_SVE = re.compile(r'\b(sv[a-z0-9]+(?:_[a-z0-9]+)*?)(?:_(?:[suf](?:8|16|32|64)|b|b8|b16|b32|b64))?(?:_[xmz])?\s*\(')
RE_RVV = re.compile(r'\b__riscv_(v[a-z0-9]+)(?:_([a-z]{1,3}))?(?:_[iuf]\d+m[f1248]|_b\d+)?(?:_tu|_tum|_tumu|_mu|_m)?\s*\(')
RE_LSX = re.compile(r'\b__lsx_(\w+?)\s*\(')
RE_LASX = re.compile(r'\b__lasx_(\w+?)\s*\(')
RE_MSA = re.compile(r'\b__msa_(\w+?)\s*\(')
RE_VEC = re.compile(r'\bvec_([a-z0-9_]+)\s*\(')
RE_MMA = re.compile(r'\b__builtin_(?:mma|vsx)_(\w+)\s*\(')

def intr(f, isa):
    t = strip_c_comments(rd(f))
    r = []
    if isa == 'x86':
        for m in RE_X86.finditer(t):
            w = {'': '128', None: '128', '256': '256', '512': '512'}[m.group(1)]
            op = m.group(2)
            op = re.sub(r'_epi(\d+)$', r'_i\1', op)
            op = re.sub(r'_epu(\d+)$', r'_u\1', op)
            op = re.sub(r'_(ps|pd|ss|sd)$', '_f', op)
            r.append(w + ':' + op)
    elif isa == 'neon':
        for m in RE_NEON2.finditer(t):
            r.append(m.group(1).rstrip('q') + (m.group(2) or ''))
        for m in RE_NEON.finditer(t):
            nm = m.group(1)
            r.append(nm + (m.group(3) or ''))
    elif isa == 'sve':
        for m in RE_SVE.finditer(t):
            r.append(m.group(1))
    elif isa == 'rvv':
        for m in RE_RVV.finditer(t):
            r.append(m.group(1) + ('.' + m.group(2) if m.group(2) else ''))
    elif isa == 'lsx':
        r = [m.group(1) for m in RE_LSX.finditer(t)]
    elif isa == 'lasx':
        r = [m.group(1) for m in RE_LASX.finditer(t)]
    elif isa == 'msa':
        r = [m.group(1) for m in RE_MSA.finditer(t)]
    elif isa in ('ppc', 's390'):
        r = [m.group(1) for m in RE_VEC.finditer(t)] + [m.group(1) for m in RE_MMA.finditer(t)]
    return r

def inline_asm_x86(f):
    """mnemonics in the quoted lines of inline assembly (OpenBLAS Haswell kernels, libyuv row_gcc.cc)"""
    t = rd(f)
    r = []
    for m in re.finditer(r'"\s*(v?[a-z][a-z0-9]*)\s+[%$\w(]', t):
        w = m.group(1)
        if re.match(r'^(v?p[a-z0-9]+|v?(mov|add|sub|mul|div|fm|fnm|max|min|and|or|xor|shuf|unpck|cvt|blend|perm|broadcast|insert|extract|zero|sqrt|rcp|rsqrt|hadd|hsub|round|cmp|dpp|gather|lddqu|andn|sad|pack|test|movmsk|abs)[a-z0-9]*)$', w):
            r.append(w)
    return r

def inline_asm_arm(f):
    t = rd(f)
    r = []
    for m in re.finditer(r'"\s*([a-z][a-z0-9]*)(?:\.[0-9a-z]+)?\s+(?:\{?[vzqdsp]\d|\{?%|[vzqdsp]\d)', t):
        r.append(m.group(1))
    return r

def inline_asm_gen(f, rx):
    t = rd(f)
    return [m.group(1).split('.')[0] for m in re.finditer(r'"\s*(' + rx + r')\s+[%\w\[(]', t)]

rows = collections.Counter()
nfiles = collections.defaultdict(set)
def add(isa, proj, kind, toks, f):
    for tk in toks:
        rows[(isa, proj, kind, tk)] += 1
        nfiles[(isa, proj, kind, tk)].add(f)

# ---------------------------------------------------------------- the source sets
SETS = [
 # (isa, project, kind, extractor, globs)
 ('x86',   'dav1d',   'asm', lambda f: asm_tokens(f, 'x86'), ['dav1d/src/x86/*.asm']),
 ('neon',  'dav1d',   'asm', lambda f: [norm_arm(w) for w in asm_tokens(f, 'arm')], ['dav1d/src/arm/64/*.S']),
 ('rvv',   'dav1d',   'asm', lambda f: [norm_rv(w) for w in asm_tokens(f, 'rv')], ['dav1d/src/riscv/64/*.S']),
 ('lsx',   'dav1d',   'asm', lambda f: [norm_la(w) for w in asm_tokens(f, 'la')], ['dav1d/src/loongarch/*.S']),
 ('x86',   'FFmpeg',  'asm', lambda f: asm_tokens(f, 'x86'), ['FFmpeg/libavcodec/x86/**/*.asm', 'FFmpeg/libavutil/x86/*.asm', 'FFmpeg/libswscale/x86/*.asm', 'FFmpeg/libswresample/x86/*.asm', 'FFmpeg/libavfilter/x86/*.asm']),
 ('neon',  'FFmpeg',  'asm', lambda f: [norm_arm(w) for w in asm_tokens(f, 'arm')], ['FFmpeg/libavcodec/aarch64/*.S', 'FFmpeg/libavutil/aarch64/*.S', 'FFmpeg/libswscale/aarch64/*.S', 'FFmpeg/libswresample/aarch64/*.S', 'FFmpeg/libavfilter/aarch64/*.S']),
 ('rvv',   'FFmpeg',  'asm', lambda f: [norm_rv(w) for w in asm_tokens(f, 'rv')], ['FFmpeg/libavcodec/riscv/*.S', 'FFmpeg/libavutil/riscv/*.S', 'FFmpeg/libswscale/riscv/*.S', 'FFmpeg/libswresample/riscv/*.S']),
 ('lsx',   'FFmpeg',  'asm', lambda f: [norm_la(w) for w in asm_tokens(f, 'la')], ['FFmpeg/libavcodec/loongarch/*.S', 'FFmpeg/libavutil/loongarch/*.S', 'FFmpeg/libswscale/loongarch/*.S']),
 ('lsx',   'FFmpeg',  'intr', lambda f: intr(f, 'lsx'), ['FFmpeg/**/loongarch/*.c', 'FFmpeg/**/loongarch/*.h']),
 ('lasx',  'FFmpeg',  'intr', lambda f: intr(f, 'lasx'), ['FFmpeg/**/loongarch/*.c', 'FFmpeg/**/loongarch/*.h']),
 ('msa',   'FFmpeg',  'intr', lambda f: intr(f, 'msa'), ['FFmpeg/**/mips/*.c', 'FFmpeg/**/mips/*.h']),
 ('ppc',   'FFmpeg',  'intr', lambda f: intr(f, 'ppc'), ['FFmpeg/libavcodec/ppc/*.c', 'FFmpeg/libavcodec/ppc/*.h', 'FFmpeg/libavutil/ppc/*.c', 'FFmpeg/libswscale/ppc/*.c', 'FFmpeg/libswscale/ppc/*.h']),
 ('x86',   'FFmpeg',  'intr', lambda f: intr(f, 'x86'), ['FFmpeg/libavcodec/x86/*.c', 'FFmpeg/libavcodec/x86/*.h', 'FFmpeg/libavutil/x86/*.c', 'FFmpeg/libswscale/x86/*.c']),
 ('neon',  'FFmpeg',  'intr', lambda f: intr(f, 'neon'), ['FFmpeg/**/aarch64/*.c', 'FFmpeg/**/arm/*.c']),
 ('rvv',   'FFmpeg',  'intr', lambda f: intr(f, 'rvv'), ['FFmpeg/**/riscv/*.c']),
 # llama.cpp / ggml
 ('x86',   'ggml',    'intr', lambda f: intr(f, 'x86'), ['llama.cpp/ggml/src/ggml-cpu/arch/x86/*.c', 'llama.cpp/ggml/src/ggml-cpu/arch/x86/*.cpp', 'llama.cpp/ggml/src/ggml-cpu/llamafile/*.cpp', 'llama.cpp/ggml/src/ggml-cpu/*.cpp']),
 ('neon',  'ggml',    'intr', lambda f: intr(f, 'neon'), ['llama.cpp/ggml/src/ggml-cpu/arch/arm/*.c', 'llama.cpp/ggml/src/ggml-cpu/arch/arm/*.cpp', 'llama.cpp/ggml/src/ggml-cpu/llamafile/*.cpp']),
 ('sve',   'ggml',    'intr', lambda f: intr(f, 'sve'), ['llama.cpp/ggml/src/ggml-cpu/arch/arm/*.c', 'llama.cpp/ggml/src/ggml-cpu/arch/arm/*.cpp', 'llama.cpp/ggml/src/ggml-cpu/kleidiai/*.cpp']),
 ('rvv',   'ggml',    'intr', lambda f: intr(f, 'rvv'), ['llama.cpp/ggml/src/ggml-cpu/arch/riscv/*.c', 'llama.cpp/ggml/src/ggml-cpu/arch/riscv/*.cpp']),
 ('lsx',   'ggml',    'intr', lambda f: intr(f, 'lsx'), ['llama.cpp/ggml/src/ggml-cpu/arch/loongarch/*.c']),
 ('lasx',  'ggml',    'intr', lambda f: intr(f, 'lasx'), ['llama.cpp/ggml/src/ggml-cpu/arch/loongarch/*.c']),
 ('ppc',   'ggml',    'intr', lambda f: intr(f, 'ppc'), ['llama.cpp/ggml/src/ggml-cpu/arch/powerpc/*.c', 'llama.cpp/ggml/src/ggml-cpu/llamafile/*.cpp']),
 ('s390',  'ggml',    'intr', lambda f: intr(f, 's390'), ['llama.cpp/ggml/src/ggml-cpu/arch/s390/*.c']),
 # OpenBLAS
 ('x86',   'OpenBLAS','asm', lambda f: asm_tokens(f, 'x86att'), []),
 ('neon',  'OpenBLAS','asm', lambda f: [norm_arm(w) for w in asm_tokens(f, 'arm')], ['OpenBLAS/kernel/arm64/*.S']),
 ('rvv',   'OpenBLAS','intr', lambda f: intr(f, 'rvv'), ['OpenBLAS/kernel/riscv64/*.c']),
 ('x86',   'OpenBLAS','intr', lambda f: intr(f, 'x86') + inline_asm_x86(f), ['OpenBLAS/kernel/x86_64/*.c', 'OpenBLAS/kernel/x86_64/*.h']),
 ('neon',  'OpenBLAS','intr', lambda f: intr(f, 'neon') + inline_asm_arm(f), ['OpenBLAS/kernel/arm64/*.c', 'OpenBLAS/kernel/arm64/*.h']),
 ('ppc',   'OpenBLAS','intr', lambda f: intr(f, 'ppc'), ['OpenBLAS/kernel/power/*.c', 'OpenBLAS/kernel/power/*.h']),
 ('s390',  'OpenBLAS','intr', lambda f: intr(f, 's390'), ['OpenBLAS/kernel/zarch/*.c']),
 ('lasx',  'OpenBLAS','asm', lambda f: [norm_la(w) for w in asm_tokens(f, 'la')], ['OpenBLAS/kernel/loongarch64/*.S']),
 ('msa',   'OpenBLAS','intr', lambda f: intr(f, 'msa'), ['OpenBLAS/kernel/mips/*.c', 'OpenBLAS/kernel/mips64/*.c']),
 # libjpeg-turbo
 ('x86',   'libjpeg-turbo','asm', lambda f: asm_tokens(f, 'x86'), ['libjpeg-turbo/simd/x86_64/*.asm', 'libjpeg-turbo/simd/nasm/*.asm']),
 ('neon',  'libjpeg-turbo','intr', lambda f: intr(f, 'neon'), ['libjpeg-turbo/simd/arm/*.c', 'libjpeg-turbo/simd/arm/*.h']),
 ('neon',  'libjpeg-turbo','asm', lambda f: [norm_arm(w) for w in asm_tokens(f, 'arm')], ['libjpeg-turbo/simd/arm/aarch64/*.S']),
 ('ppc',   'libjpeg-turbo','intr', lambda f: intr(f, 'ppc'), ['libjpeg-turbo/simd/powerpc/*.c', 'libjpeg-turbo/simd/powerpc/*.h']),
 ('msa',   'libjpeg-turbo','intr', lambda f: intr(f, 'msa'), ['libjpeg-turbo/simd/mips64/*.c']),
 # libyuv
 ('x86',   'libyuv',  'intr', lambda f: intr(f, 'x86') + inline_asm_x86(f), ['libyuv/source/*.cc']),
 ('neon',  'libyuv',  'intr', lambda f: intr(f, 'neon') + inline_asm_arm(f), ['libyuv/source/*neon*.cc', 'libyuv/source/*neon*.c']),
 ('lsx',   'libyuv',  'intr', lambda f: intr(f, 'lsx'), ['libyuv/source/*lsx*.cc']),
 ('lasx',  'libyuv',  'intr', lambda f: intr(f, 'lasx'), ['libyuv/source/*lasx*.cc']),
 ('msa',   'libyuv',  'intr', lambda f: intr(f, 'msa'), ['libyuv/source/*msa*.cc']),
 ('rvv',   'libyuv',  'asm', lambda f: inline_asm_gen(f, r'v[a-z0-9.]+'), ['libyuv/source/*rvv*.cc']),
 ('sve',   'libyuv',  'asm', lambda f: inline_asm_arm(f), ['libyuv/source/*sve*.cc']),
 # zlib-ng
 ('x86',   'zlib-ng', 'intr', lambda f: intr(f, 'x86'), ['zlib-ng/arch/x86/*.c', 'zlib-ng/arch/x86/*.h']),
 ('neon',  'zlib-ng', 'intr', lambda f: intr(f, 'neon'), ['zlib-ng/arch/arm/*.c', 'zlib-ng/arch/arm/*.h']),
 ('ppc',   'zlib-ng', 'intr', lambda f: intr(f, 'ppc'), ['zlib-ng/arch/power/*.c', 'zlib-ng/arch/power/*.h']),
 ('s390',  'zlib-ng', 'intr', lambda f: intr(f, 's390'), ['zlib-ng/arch/s390/*.c']),
 ('rvv',   'zlib-ng', 'intr', lambda f: intr(f, 'rvv'), ['zlib-ng/arch/riscv/*.c']),
 ('lsx',   'zlib-ng', 'intr', lambda f: intr(f, 'lsx'), ['zlib-ng/arch/loongarch/*.c']),
 ('lasx',  'zlib-ng', 'intr', lambda f: intr(f, 'lasx'), ['zlib-ng/arch/loongarch/*.c']),
]

for isa, proj, kind, ex, pats in SETS:
    fl = files(pats)
    if not fl:
        continue
    tot = 0
    for f in fl:
        try:
            toks = ex(f)
        except Exception as e:
            sys.stderr.write('%s: %s\n' % (f, e)); continue
        tot += len(toks)
        add(isa, proj, kind, toks, f)
    sys.stderr.write('%-5s %-14s %-4s files %4d tokens %7d\n' % (isa, proj, kind, len(fl), tot))

with open(out, 'w') as h:
    for (isa, proj, kind, tk), n in sorted(rows.items()):
        h.write('%s\t%s\t%s\t%s\t%d\t%d\n' % (isa, proj, kind, tk, n, len(nfiles[(isa, proj, kind, tk)])))

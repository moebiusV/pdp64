#!/usr/bin/env python3
"""
archcmp -- compile the pdp64 fair corpus to assembler for many architectures and compare instruction use.

    archcmp.py gen     [--arch a,b,..] [-j N] [--limit N]   compile every file for every target; keep the .s under OUT/<arch>/
    archcmp.py table                                          per-architecture totals and mnemonic shares
    archcmp.py funcs                                          function-level comparison against pdp64
    archcmp.py idioms                                         detectors for the idioms in pdp64 output (static counts, samples)
    archcmp.py all

The files and the preprocessing are tools/pdp64size.py's (same preprocessed text per header set, corpus.py's musl sysroots
and defines).  Output: OUT (default /tmp/p64opt/archcmp) holds <arch>/<file>.s and <arch>/<file>.size (text+data bytes of the
assembled object); the data files go to docs/codegen-data/archcmp/.  pdp64's own .s files are produced by
`tools/pdp64size.py --arch pdp64 --keep OUT/pdp64` (gen does this when OUT/pdp64 is missing).
"""
import os, re, sys, json, csv, glob, struct, argparse, tempfile, subprocess, collections, random, shutil
import concurrent.futures as cf

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import pdp64size as P
from pdp64size import corpus, ROOT, ARCH, run, fair_files, preprocess

OUT = os.environ.get('ARCHCMP_OUT', '/tmp/p64opt/archcmp')
DATA = os.path.join(REPO, 'docs', 'codegen-data', 'archcmp')
GCCX = os.path.join(ROOT, 'gcc-cross', 'prefix', 'bin')

# ---- the targets -------------------------------------------------------------------------------------------------------
# header groups: preprocessed text is shared by the targets of a group.  Where no musl sysroot exists for an architecture
# (ppc64, systemz) the sparc64 set is used: big-endian, LP64, the same type sizes; loongarch64 uses the aarch64 set.
ARCH['ppc64h'] = dict(musl='sparc64', cpp=['-D__LP64__', '-D_LP64'], ssa=False, clang=None, gcc=None, c2=None, asm=None)
ARCH['vaxh'] = dict(musl='i386', cpp=['-Dvax', '-D__vax__', '-D__ILP32__'], ssa=False, clang=None, gcc=None, c2=None, asm=None)
GROUP_ARCH = {  # group -> corpus.ARCH entry used for preprocessing
    'aarch64': 'aarch64', 'amd64': 'amd64', 'i386': 'i386', 'arm': 'arm', 'powerpc': 'powerpc', 'm68k': 'm68k',
    'mips64': 'mips64', 'riscv64': 'riscv64', 'sparc64': 'sparc64', 'be64': 'ppc64h', 'vax': 'vaxh',
}
COMMON = ['-std=gnu99', '-w', '-fno-asynchronous-unwind-tables', '-fno-unwind-tables', '-Os']


def _clang(triple, *extra):
    return ['clang', '--target=' + triple] + list(extra)


# name -> (group, compile command (without -S/-c/-o), comment-regex marker, kind)
T = {
    'aarch64':    ('aarch64', _clang('aarch64-linux-gnu', '-fno-pic')),
    'loongarch64': ('aarch64', _clang('loongarch64-linux-gnu', '-fno-pic')),
    'amd64-clang': ('amd64', _clang('x86_64-linux-gnu', '-fno-pic', '-fcf-protection=none')),
    'amd64-gcc':  ('amd64', ['gcc', '-m64', '-fno-pie', '-fcf-protection=none']),
    'i386-clang': ('i386', _clang('i386-linux-gnu', '-fno-pic', '-fcf-protection=none')),
    'i386-gcc':   ('i386', ['gcc', '-m32', '-fno-pie', '-fcf-protection=none']),
    'arm':        ('arm', _clang('arm-linux-gnueabi', '-fno-pic', '-marm')),
    'arm-v7':     ('arm', _clang('arm-linux-gnueabi', '-fno-pic', '-marm', '-march=armv7-a')),
    'ppc32':      ('powerpc', _clang('powerpc-linux-gnu', '-fno-pic')),
    'ppc32-gcc':  ('powerpc', ['powerpc-linux-gnu-gcc', '-fno-pie']),
    'm68k':       ('m68k', _clang('m68k-linux-gnu', '-fno-pic')),
    'mips64':     ('mips64', _clang('mips64-linux-gnuabi64', '-fno-pic', '-mno-abicalls')),
    'riscv64':    ('riscv64', _clang('riscv64-linux-gnu', '-fno-pic', '-march=rv64g')),
    'riscv64gc':  ('riscv64', _clang('riscv64-linux-gnu', '-fno-pic', '-march=rv64gc')),
    'riscv64zb':  ('riscv64', _clang('riscv64-linux-gnu', '-fno-pic', '-march=rv64gc_zba_zbb_zbs')),
    'sparcv9':    ('sparc64', _clang('sparcv9-linux-gnu', '-fno-pic')),
    'ppc64':      ('be64', _clang('powerpc64-unknown-linux-musl', '-fno-pic')),
    'systemz':    ('be64', _clang('s390x-linux-gnu', '-fno-pic')),
    'vax-gcc':    ('vax', [GCCX + '/vax-netbsdelf-gcc']),
}
PRIMARY = ['aarch64', 'loongarch64', 'amd64-clang', 'amd64-gcc', 'i386-clang', 'i386-gcc', 'arm', 'ppc32', 'm68k', 'mips64',
           'riscv64gc', 'riscv64', 'sparcv9', 'ppc64', 'systemz', 'ppc32-gcc', 'arm-v7', 'riscv64zb', 'vax-gcc']
SIZETOOL = {'vax-gcc': GCCX + '/vax-netbsdelf-size'}


def asm_cmd(name):
    """the command that assembles a .s of target `name` into an object"""
    g, cmd = T[name]
    if cmd[0] == 'clang':
        return cmd + ['-c', '-x', 'assembler']
    if name.endswith('-gcc') and name.startswith(('amd64', 'i386')):
        return cmd + ['-c', '-x', 'assembler']
    return None            # gcc: compile with -c a second time


def elf_bytes(path):
    """bytes of the SHF_ALLOC sections that have contents (what `size` calls text+data), any ELF class and endianness"""
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF':
        return None
    e = '<' if d[5] == 1 else '>'
    if d[4] == 2:
        shoff, = struct.unpack_from(e + 'Q', d, 0x28)
        shentsize, shnum, shstrndx = struct.unpack_from(e + 'HHH', d, 0x3A)
        fmt, fo = e + 'IIQQQQ', None
    else:
        shoff, = struct.unpack_from(e + 'I', d, 0x20)
        shentsize, shnum, shstrndx = struct.unpack_from(e + 'HHH', d, 0x2E)
        fmt = e + 'IIIIII'
    sh = []
    for i in range(shnum):
        name, typ, flags, addr, off, size = struct.unpack_from(fmt, d, shoff + i * shentsize)
        sh.append((name, typ, flags, off, size))
    stroff = sh[shstrndx][3]
    tot = 0
    for name, typ, flags, off, size in sh:
        nm = d[stroff + name:d.index(b'\0', stroff + name)].decode()
        if flags & 2 and typ != 8 and not nm.startswith(('.eh_frame', '.note', '.comment', '.riscv', '.ARM', '.gnu', '.MIPS', '.reginfo', '.mdebug', '.PPC', '.debug', '.sframe')):
            tot += size
    return tot


def one(job, force=False):
    """one source file, one header group: preprocess, then every target of the group"""
    corp, src, group, names = job
    sid = src.replace(ROOT + '/', '').replace('/', '_')
    todo = [n for n in names if force or not os.path.exists('%s/%s/%s.size' % (OUT, n, sid)) and not os.path.exists('%s/%s/%s.fail' % (OUT, n, sid))]
    if not todo:
        return []
    r = preprocess(corp, src, GROUP_ARCH[group], [])
    res = []
    if r.returncode:
        for n in todo:
            open('%s/%s/%s.fail' % (OUT, n, sid), 'w').write('cpp')
        return [(n, sid, 'cpp') for n in todo]
    with tempfile.TemporaryDirectory() as w:
        i = os.path.join(w, 'i.c')
        open(i, 'w').write(r.stdout)
        for n in todo:
            cmd = T[n][1]
            d = '%s/%s' % (OUT, n)
            s, o = os.path.join(w, 'x.s'), os.path.join(w, 'x.o')
            q = run(cmd + COMMON + ['-S', '-x', 'c', '-o', s, i], timeout=300)
            if q.returncode:
                m = [x for x in (q.stderr or q.stdout).strip().split('\n') if 'error' in x or 'fatal' in x]
                open('%s/%s.fail' % (d, sid), 'w').write((m[0] if m else 'exit %d' % q.returncode)[:200])
                res.append((n, sid, 'cc'))
                continue
            ac = asm_cmd(n)
            if ac:
                q = run(ac + ['-o', o, s])
            else:
                q = run(cmd + COMMON + ['-c', '-x', 'c', '-o', o, i], timeout=300)
            nb = elf_bytes(o) if q.returncode == 0 and os.path.exists(o) else None
            shutil.copy(s, '%s/%s.s' % (d, sid))
            open('%s/%s.size' % (d, sid), 'w').write(str(nb if nb is not None else -1))
            res.append((n, sid, 'ok'))
    return res


def cmd_gen(a):
    names = a.arch.split(',') if a.arch else PRIMARY
    for n in names:
        os.makedirs('%s/%s' % (OUT, n), exist_ok=True)
    files = fair_files()
    if a.limit:
        files = files[:a.limit]
    if not os.path.isdir(OUT + '/pdp64') or not glob.glob(OUT + '/pdp64/*.s'):
        sys.stderr.write('generating the pdp64 assembly (pdp64size.py --keep)\n')
        subprocess.run(['nice', '-n', '10', sys.executable, os.path.join(HERE, 'pdp64size.py'), '--arch', 'pdp64', '-j', '1',
                        '--out', OUT + '/_run/pdp64', '--keep', OUT + '/pdp64'], check=False, stdout=subprocess.DEVNULL)
    groups = collections.defaultdict(list)
    for n in names:
        groups[T[n][0]].append(n)
    jobs = [(c, f, g, ns) for c, f in files for g, ns in groups.items()]
    cnt = collections.Counter()
    with cf.ThreadPoolExecutor(max_workers=a.j) as ex:
        for k, r in enumerate(ex.map(lambda j: one(j, a.force), jobs)):
            for n, sid, st in r:
                cnt[(n, st)] += 1
            if k % 100 == 0:
                sys.stderr.write('%d / %d jobs\n' % (k, len(jobs)))
    for k, v in sorted(cnt.items()):
        print(k, v)


# ---- parsing of assembler output ------------------------------------------------------------------------------------------
COMMENT = {  # line comment starters per target family
    'pdp64': ';', 'aarch64': '//', 'loongarch64': '#', 'amd64': '#', 'i386': '#', 'arm': '@', 'ppc': '#', 'm68k': ';',
    'mips64': '#', 'riscv64': '#', 'sparc': '!', 'systemz': '#', 'vax': '#',
}


def family(name):
    for k in ('pdp64', 'aarch64', 'loongarch64', 'amd64', 'i386', 'arm', 'm68k', 'mips64', 'riscv64', 'systemz', 'vax'):
        if name.startswith(k):
            return k
    if name.startswith('ppc'):
        return 'ppc'
    if name.startswith('sparc'):
        return 'sparc'
    return name


def parse(path, name):
    """-> list of ('f', funcname) | ('l', label) | ('i', mnemonic, operand string); instructions in text sections only.
    A function is a global label in text that is not a local label (.L*, $*, L*, a number)."""
    fam = family(name)
    com = COMMENT[fam]
    items = []
    sec = 'text'
    funcs = set()
    lines = open(path, errors='replace').read().split('\n')
    for ln in lines:
        m = re.match(r'\s*\.type\s+([^,\s]+)\s*,\s*[@%#]function', ln)
        if m:
            funcs.add(m.group(1))
    for ln in lines:
        if com in ln and fam not in ('arm',) or fam == 'arm' and '@' in ln:
            q = ln.find(com)
            # do not cut inside a string
            if ln.count('"', 0, q) % 2 == 0:
                ln = ln[:q]
        if fam == 'amd64' or fam == 'i386' or fam in ('ppc', 'mips64', 'riscv64', 'systemz', 'loongarch64', 'vax'):
            pass
        ln = ln.strip()
        while True:
            m = re.match(r'^("[^"]*"|[A-Za-z_.$][\w.$@]*|\d+):\s*(.*)$', ln)
            if not m or (fam == 'sparc' and False):
                break
            lab, ln = m.group(1), m.group(2).strip()
            if sec != 'text':
                continue
            isloc = lab.startswith(('.L', '$', 'L.')) or lab.isdigit() or (lab[0] == 'L' and lab[1:].isdigit())
            if fam == 'ppc' and lab.startswith('.L.') and lab[3:] in funcs:
                items.append(('f', lab[3:]))
            elif not isloc and (lab in funcs or fam == 'pdp64'):
                items.append(('f', lab))
            elif not isloc and lab not in funcs and not funcs:
                items.append(('f', lab))
            else:
                items.append(('l', lab))
        if not ln:
            continue
        if ln.startswith('.'):
            w = ln.split()[0]
            if w in ('.text',):
                sec = 'text'
            elif w in ('.data', '.bss', '.rodata'):
                sec = 'data'
            elif w in ('.section', '.pushsection') and not w.startswith('.text'):
                sec = 'text' if re.match(r'\.(?:section|pushsection)\s+"?\.text', ln) else 'data'
            elif w == '.previous' or w == '.popsection':
                sec = 'text'
            continue
        if sec != 'text':
            continue
        if fam == 'pdp64' or True:
            w = ln.split(None, 1)
            items.append(('i', w[0], w[1].strip() if len(w) > 1 else ''))
    return items


def count_ins(items):
    return sum(1 for x in items if x[0] == 'i')


# ---- mnemonic normalisation -----------------------------------------------------------------------------------------------
X86CC = 'o no b ae e ne be a s ns p np l ge le g nae nb nc c z nz na nbe nl nge ng nle pe po ae'.split()
GENCC = 'eq ne cs cc hs lo mi pl vs vc hi ls ge lt gt le al'.split()


def norm_factory(name, observed):
    fam = family(name)
    obs = set(observed)

    def n(mn):
        m = mn.lower()
        if fam in ('amd64', 'i386'):
            if m.startswith('j') and m != 'jmp' and m[1:] in X86CC:
                return 'jcc'
            if m.startswith('cmov') and m[4:] in X86CC:
                return 'cmovcc'
            if m.startswith('set') and m[3:] in X86CC:
                return 'setcc'
            if m.startswith(('movz', 'movs')) and len(m) in (6, 5) and m not in ('movss', 'movsd', 'movsq', 'movsl', 'movsw', 'movsb'):
                return m[:4] + 'x'
            if m in ('callq', 'calll', 'retq', 'retl', 'leaveq', 'leavel', 'pushq', 'pushl', 'popq', 'popl', 'jmpq', 'jmpl'):
                return m[:-1]
            if m.startswith('cmov') and (m[4:-1] in X86CC):
                return 'cmovcc'
            if m in ('bswapl', 'bswapq'):
                return 'bswap'
            if m in ('cltq', 'cqto', 'cltd', 'cwtl', 'cwtd', 'cbtw'):
                return 'cdq'
            if m[-1] in 'bwlq' and m[:-1] in obs | {'mov', 'add', 'sub', 'and', 'or', 'xor', 'cmp', 'test', 'shl', 'shr', 'sar', 'lea', 'push', 'pop',
                                                      'imul', 'neg', 'not', 'inc', 'dec', 'adc', 'sbb', 'bt', 'rol', 'ror', 'idiv', 'div', 'mul', 'xchg', 'bsf', 'bsr', 'sal'}:
                return m[:-1]
            return m
        if fam == 'aarch64':
            return 'b.cond' if m.startswith('b.') else m
        if fam == 'arm':
            m = re.sub(r'^(vld|vst)(\w*)$', r'\1\2', m)
            for c in GENCC:
                if m.endswith(c) and len(m) > 2 and (m[:-2] in obs or m[:-2] + 's' in obs):
                    m = m[:-2]
                    break
            if m.endswith('s') and m[:-1] in ('add', 'sub', 'mov', 'and', 'orr', 'eor', 'rsb', 'adc', 'sbc', 'lsl', 'lsr', 'asr', 'mvn', 'bic', 'mul', 'ror'):
                m = m[:-1]
            return m
        if fam == 'ppc':
            m = m.rstrip('.+-')
            if m in ('bne', 'beq', 'blt', 'bge', 'bgt', 'ble', 'bso', 'bns', 'bdnz', 'bdz') and m not in ('bdnz', 'bdz'):
                return 'bcc'
            if re.match(r'^b(ne|eq|lt|ge|gt|le)(lr|ctr)?$', m):
                return 'bcc'
            return m
        if fam == 'sparc':
            m = m.split(',')[0]
            if re.match(r'^b(ne|e|g|ge|l|le|gu|leu|cc|cs|pos|neg|vc|vs)$', m):
                return 'bcc'
            if m.startswith('f') and re.match(r'^fb', m):
                return 'fbcc'
            return m
        if fam == 'm68k':
            m = re.sub(r'\.[bwl]$', '', m)
            if re.match(r'^b(ne|eq|lt|ge|gt|le|hi|ls|cc|cs|mi|pl|vc|vs)$', m):
                return 'bcc'
            if re.match(r'^s(ne|eq|lt|ge|gt|le|hi|ls|cc|cs|mi|pl|vc|vs)$', m):
                return 'scc'
            return m
        if fam == 'systemz':
            if re.match(r'^j(g)?(e|ne|l|h|le|he|nle|nhe|nl|nh|lh|nlh|o|no|z|nz|m|p|c|nc|lm|hm|nlm|nhm)$', m) or re.match(r'^j(g)?[a-z]{1,3}$', m) and m not in ('jg', 'j'):
                return 'jcc'
            return m
        if fam == 'mips64':
            return m
        if fam == 'vax':
            m = re.sub(r'^(j)(eql|neq|lss|gtr|leq|geq|lssu|gtru|lequ|gequ|eqlu|nequ)$', 'jcc', m)
            m = re.sub(r'^(\w+?)(b|w|l|q|f|d)(2|3)$', r'\1\3', m)
            m = re.sub(r'^(mov|clr|tst|cmp|inc|dec|push|mneg|mcom|cvt)(b|w|l|q|f|d)$', r'\1', m)
            return m
        if fam == 'pdp64':
            if m.startswith('cb') and m[2:] in ('eq', 'ne', 'lt', 'le', 'gt', 'ge', 'lo', 'ls', 'hi', 'hs', 'cc', 'cs', 'mi', 'pl', 'vs', 'vc', 'lt', 'bhi'):
                return 'cbcc'
            if m in ('movq', 'movl', 'movw', 'movb'):
                return 'mov'
            if m in ('movzl', 'movzw', 'movzb'):
                return 'movz'
            if re.match(r'^b(eq|ne|lt|le|gt|ge|lo|ls|hi|hs|cc|cs|mi|pl|vs|vc|los|his|lt)$', m):
                return 'bcc'
            return m
        return m
    return n


# ---- tables --------------------------------------------------------------------------------------------------------------------
def sid_list(name):
    return {os.path.basename(f)[:-2]: f for f in glob.glob('%s/%s/*.s' % (OUT, name))}


def load_size(name, sid):
    try:
        return int(open('%s/%s/%s.size' % (OUT, name, sid)).read())
    except Exception:
        return None


def pdp64_sizes():
    """pdp64 results per file id, from the kept results of pdp64size (OUT/_run/pdp64/results.json)"""
    r = json.load(open(OUT + '/_run/pdp64/results.json'))
    return {x['src'].replace('/', '_'): x for x in r if 'ins' in x}


def archs_present():
    return [n for n in PRIMARY + ['pdp64'] if glob.glob('%s/%s/*.s' % (OUT, n))]


def summarize(name):
    """per file: raw-mnemonic Counter, instruction count, {function: (instructions, bytes-unknown)}; cached"""
    import pickle
    cache = '%s/_run/sum-%s.pkl' % (OUT, name)
    try:
        S = pickle.load(open(cache, 'rb'))
    except Exception:
        S = {}
    fl = sid_list(name)
    dirty = False
    for sid, f in fl.items():
        if sid in S and S[sid]['mt'] == os.path.getmtime(f):
            continue
        it = parse(f, name)
        mn = collections.Counter(x[1] for x in it if x[0] == 'i')
        fn = {}
        cur = None
        for x in it:
            if x[0] == 'f':
                cur = x[1]
                fn.setdefault(cur, 0)
            elif x[0] == 'i' and cur is not None:
                fn[cur] += 1
        S[sid] = dict(mt=os.path.getmtime(f), mn=mn, n=sum(mn.values()), fn=fn)
        dirty = True
    if dirty:
        pickle.dump(S, open(cache, 'wb'))
    return S


def common_files():
    """files compiled by pdp64 and by every target except vax-gcc (reported on its own set)"""
    pd = pdp64_sizes()
    common = set(pd)
    for n in archs_present():
        if n in ('pdp64', 'vax-gcc'):
            continue
        ok = {sid for sid in sid_list(n) if (load_size(n, sid) or -1) >= 0}
        common &= ok
    return sorted(common), pd


def cmd_table(a):
    os.makedirs(DATA, exist_ok=True)
    common, pd = common_files()
    sys.stderr.write('files accepted by every selected compiler: %d of %d\n' % (len(common), len(pd)))
    names = [n for n in archs_present() if n != 'pdp64'] + ['pdp64']
    rows = []
    for n in names:
        S = summarize(n)
        files = common if n != 'vax-gcc' else [x for x in common if x in S]
        mn = collections.Counter()
        tot_i = tot_b = 0
        for sid in files:
            mn.update(S[sid]['mn'])
            tot_i += S[sid]['n']
            tot_b += pd[sid]['image'] if n == 'pdp64' else load_size(n, sid)
        nf = norm_factory(n, mn.keys())
        nm = collections.Counter()
        for k, v in mn.items():
            nm[nf(k)] += v
        rows.append(dict(arch=n, files=len(files), ins=tot_i, bytes=tot_b, mn=nm))
    # pdp64 on the same files as each row (vax has fewer)
    pds = summarize('pdp64')
    for r in rows:
        files = common if r['arch'] != 'vax-gcc' else [x for x in common if x in summarize('vax-gcc')]
        r['pd_ins'] = sum(pds[x]['n'] for x in files)
        r['pd_bytes'] = sum(pd[x]['image'] for x in files)
    with open(DATA + '/archcmp-totals.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['arch', 'files', 'instructions', 'bytes', 'pdp64_instructions_same_files', 'pdp64_bytes_same_files', 'ins_per_pdp64', 'bytes_per_pdp64', 'bytes_per_ins'])
        for r in rows:
            w.writerow([r['arch'], r['files'], r['ins'], r['bytes'], r['pd_ins'], r['pd_bytes'], '%.3f' % (r['ins'] / r['pd_ins']),
                        '%.3f' % (r['bytes'] / r['pd_bytes']), '%.2f' % (r['bytes'] / r['ins'])])
    with open(DATA + '/archcmp-mnemonics.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['arch', 'mnemonic', 'count', 'share'])
        for r in rows:
            tot = sum(r['mn'].values())
            for m, v in r['mn'].most_common(40):
                w.writerow([r['arch'], m, v, '%.4f' % (v / tot)])
    json.dump(common, open(DATA + '/archcmp-commonfiles.json', 'w'))
    print('| arch | files | instructions | bytes (text+data) | ins / pdp64 | bytes / pdp64 | bytes per ins |')
    print('|---|---|---|---|---|---|---|')
    for r in sorted(rows, key=lambda r: r['ins'] / r['pd_ins']):
        print('| %s | %d | %d | %d | %.3f | %.3f | %.2f |' % (r['arch'], r['files'], r['ins'], r['bytes'], r['ins'] / r['pd_ins'], r['bytes'] / r['pd_bytes'], r['bytes'] / r['ins']))
    print()
    for r in rows:
        tot = sum(r['mn'].values())
        print('### %s' % r['arch'])
        print(', '.join('%s %.1f%%' % (m, 100 * v / tot) for m, v in r['mn'].most_common(25)))
        print()


def cmd_funcs(a):
    os.makedirs(DATA, exist_ok=True)
    common, pd = common_files()
    names = [n for n in archs_present() if n not in ('pdp64',)]
    S = {n: summarize(n) for n in names + ['pdp64']}
    rows = []
    for sid in common:
        pf = S['pdp64'][sid]['fn']
        for f, n0 in pf.items():
            if n0 < 8:
                continue
            others = {}
            for n in names:
                v = S[n].get(sid, {}).get('fn', {}).get(f)
                if v:
                    others[n] = v
            if len(others) < 8:
                continue
            best = min(others, key=others.get)
            vals = sorted(others.values())
            med = vals[len(vals) // 2]
            rows.append(dict(sid=sid, func=f, pdp64=n0, best_arch=best, best=others[best], median=med, n_archs=len(others),
                             second=vals[1], ratio=n0 / others[best], ratio_med=n0 / med))
    with open(DATA + '/archcmp-functions.csv', 'w', newline='') as fh:
        w = csv.DictWriter(fh, list(rows[0].keys()))
        w.writeheader()
        for r in rows:
            r = dict(r)
            r['ratio'] = '%.2f' % r['ratio']
            r['ratio_med'] = '%.2f' % r['ratio_med']
            w.writerow(r)
    tp = sum(r['pdp64'] for r in rows)
    tb = sum(r['best'] for r in rows)
    tm = sum(r['median'] for r in rows)
    print('aligned functions: %d; pdp64 %d instructions, best-other sum %d (%.2f), median-other sum %d (%.2f)' % (len(rows), tp, tb, tp / tb, tm, tp / tm))
    cand = [r for r in rows if r['ratio'] >= 1.4 and r['best'] >= 20]
    print('functions with ratio >= 1.4 and best >= 20: %d' % len(cand))
    c2 = [r for r in cand if r['ratio_med'] >= 1.15 and r['second'] * 1.25 >= r['best'] and r['best_arch'] != 'vax-gcc']
    print('and median ratio >= 1.15, second best within 25%% of best: %d' % len(c2))
    byb = collections.Counter(r['best_arch'] for r in cand)
    print('best architecture among candidates:', byb.most_common())
    # pick 30 spread over corpora and files
    c2.sort(key=lambda r: -(r['pdp64'] - r['best']))
    pick, percorp, perfile = [], collections.Counter(), collections.Counter()
    for r in c2:
        corp = r['sid'].split('_')[0]
        if percorp[corp] >= 6 or perfile[r['sid']] >= 1:
            continue
        pick.append(r)
        percorp[corp] += 1
        perfile[r['sid']] += 1
        if len(pick) == 30:
            break
    os.makedirs(OUT + '/_run/fn', exist_ok=True)
    with open(DATA + '/archcmp-functions-picked.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['n', 'file', 'function', 'pdp64', 'best_arch', 'best', 'median', 'ratio'])
        for k, r in enumerate(pick, 1):
            w.writerow([k, r['sid'], r['func'], r['pdp64'], r['best_arch'], r['best'], r['median'], '%.2f' % r['ratio']])
            with open(OUT + '/_run/fn/%02d.txt' % k, 'w') as o:
                for n in ['pdp64', r['best_arch']] + [x for x in ('aarch64', 'amd64-gcc') if x != r['best_arch']]:
                    o.write('==== %s %s %s\n' % (n, r['sid'], r['func']))
                    o.write(extract(n, r['sid'], r['func']))
            print('%2d %-34s %-28s pdp64 %4d  best %-12s %4d  med %4d  x%.2f' % (k, r['sid'][:34], r['func'][:28], r['pdp64'], r['best_arch'], r['best'], r['median'], r['ratio']))


def extract(name, sid, func):
    it = parse('%s/%s/%s.s' % (OUT, name, sid), name)
    out, on = [], False
    for x in it:
        if x[0] == 'f':
            if on:
                break
            on = x[1] == func
        if not on:
            continue
        if x[0] == 'f' or x[0] == 'l':
            out.append('%s:\n' % x[1])
        else:
            out.append('\t%s %s\n' % (x[1], x[2]))
    return ''.join(out)


# ---- pdp64 instruction model for the detectors ---------------------------------------------------------------------------------
REGRE = re.compile(r'(?<![\w.$#])(r\d+|sp|fp)(?![\w.$])')
CALLER = {'r%d' % i for i in range(8)} | {'r12'}
CALLEE = {'r8', 'r9', 'r10', 'r11', 'r13', 'r14', 'r15'}
ARGS = {'r%d' % i for i in range(6)}
CONDS = 'eq ne lt le gt ge lo ls hi hs cc cs mi pl vs vc los his'.split()
BRANCH = {'b' + c for c in CONDS} | {'br'}
CBRANCH = {'cb' + c for c in CONDS}
MOVS = {'movq': 8, 'movl': 4, 'movw': 2, 'movb': 1, 'movzl': 4, 'movzw': 2, 'movzb': 1, 'movub': 1, 'movuw': 2, 'movul': 4, 'movuq': 8}
ALU2 = {'add', 'sub', 'bic', 'bis', 'xor', 'and', 'mul', 'mulh', 'shl', 'shr', 'sar', 'asl', 'asr'}
UNARY = {'clr', 'com', 'inc', 'dec', 'neg', 'adc', 'sbc', 'abs'}


def rn(r):
    return {'sp': 'r14', 'fp': 'r13'}.get(r, r)


def isreg(o):
    return re.fullmatch(r'r\d+|sp|fp', o) is not None


def regs_in(o):
    if o.startswith(('#', '=')):
        return set()
    return {rn(x) for x in REGRE.findall(o)}


def ismem(o):
    return not isreg(o) and not o.startswith(('#', '=')) and not re.fullmatch(r'\.?L\d+|[A-Za-z_.$][\w.$]*', o) or bool(re.match(r'^-?\d*\(', o)) or o.startswith('@')


class Ins:
    __slots__ = ('mn', 'ops', 'text', 'r', 'w', 'lab', 'kind', 'ld', 'st')

    def __init__(self, mn, ops, text=None, lab=None):
        self.mn, self.ops, self.lab = mn, ops, lab
        self.text = text if text is not None else ('\t%s %s' % (mn, ','.join(ops)))
        self.r, self.w = set(), set()
        self.ld = self.st = False
        self.kind = 'label' if lab else 'ins'
        if not lab:
            self.effects()

    def effects(self):
        mn, ops = self.mn, self.ops
        r, w = self.r, self.w

        def memop(o):
            return not isreg(o) and not o.startswith(('#', '=')) and (('(' in o) or o.startswith('@') or not re.fullmatch(r'\.?L\d+', o))
        if mn in MOVS and len(ops) == 2:
            r |= regs_in(ops[0])
            if isreg(ops[1]):
                w.add(rn(ops[1]))
            else:
                r |= regs_in(ops[1])
                self.st = True
            if memop(ops[0]):
                self.ld = True
        elif mn == 'lea' and len(ops) == 2:
            r |= regs_in(ops[0])
            w |= regs_in(ops[1])
        elif mn in ALU2 and len(ops) == 2:
            r |= regs_in(ops[0]) | regs_in(ops[1])
            w |= regs_in(ops[1])
            self.ld = memop(ops[0])
        elif mn in ('cmp', 'bit', 'tst'):
            for o in ops:
                r |= regs_in(o)
            self.ld = any(memop(o) for o in ops)
        elif mn in UNARY and len(ops) == 1:
            if mn != 'clr':
                r |= regs_in(ops[0])
            w |= regs_in(ops[0]) if isreg(ops[0]) else set()
            if not isreg(ops[0]):
                r |= regs_in(ops[0])
                self.st = True
        elif mn == 'push':
            r |= regs_in(ops[0]) | {'r14'}
            w.add('r14')
            self.st = True
        elif mn == 'pop':
            w |= regs_in(ops[0]) | {'r14'}
            r.add('r14')
            self.ld = True
        elif mn in ('pushm', 'pushm8', 'popm', 'popm8'):
            m = re.search(r'#(\w+)', ops[0]) if ops else None
            mask = int(m.group(1), 0) if m else 0
            if mn.endswith('8'):
                mask <<= 8
            rs = {'r%d' % i for i in range(16) if mask >> i & 1}
            if mn.startswith('push'):
                r |= rs | {'r14'}
                self.st = True
            else:
                w |= rs
                self.ld = True
            w.add('r14')
            r.add('r14')
        elif mn in ('call', 'calli'):
            for o in ops:
                r |= regs_in(o)
            r |= ARGS | {'r14'}
            w |= CALLER
            self.kind = 'call'
        elif mn == 'ret':
            r |= {'r0', 'r1', 'r14'} | CALLEE
            self.kind = 'ret'
        elif mn == 'jmp':
            for o in ops:
                r |= regs_in(o)
            r |= ARGS | CALLEE
            self.kind = 'ret'
        elif mn in BRANCH:
            self.kind = 'br' if mn == 'br' else 'cbr'
        elif mn in CBRANCH:
            for o in ops[:2]:
                r |= regs_in(o)
            self.kind = 'cbr'
        elif mn == 'mcpy':
            for o in ops:
                r |= regs_in(o)
            w |= {'r%s' % x[1:] for x in ops if isreg(x)}
            self.ld = self.st = True
        elif len(ops) >= 2:       # three-operand and the rest: last is the destination
            for o in ops[:-1]:
                r |= regs_in(o)
            if isreg(ops[-1]):
                w.add(rn(ops[-1]))
            else:
                r |= regs_in(ops[-1])
            self.ld = any(memop(o) for o in ops[:-1])
        else:
            for o in ops:
                r |= regs_in(o)


def pparse(path):
    """pdp64 .s -> list of functions: (name, [Ins]); labels are Ins with .lab; data and directives dropped"""
    funcs = []
    cur = None
    sec = 'text'
    for ln in open(path, errors='replace'):
        raw = ln.rstrip('\n')
        ln = ln.split(';')[0].strip() if ';' in ln and '"' not in ln else ln.strip()
        while True:
            m = re.match(r'^("[^"]*"|[A-Za-z_.$][\w.$]*|\d+):\s*(.*)$', ln)
            if not m:
                break
            lab, ln = m.group(1), m.group(2).strip()
            if sec != 'text':
                continue
            if not lab.startswith('.L'):
                cur = (lab, [])
                funcs.append(cur)
            elif cur is not None:
                cur[1].append(Ins('', [], lab=lab))
        if not ln:
            continue
        if ln.startswith('.'):
            w = ln.split()[0]
            if w == '.text':
                sec = 'text'
            elif w in ('.data', '.bss'):
                sec = 'data'
            elif w == '.section':
                sec = 'text' if '.text' in ln else 'data'
            continue
        if sec != 'text' or cur is None:
            continue
        w = ln.split(None, 1)
        cur[1].append(Ins(w[0], P.split_ops(w[1]) if len(w) > 1 else []))
    return funcs


def live_after(seq, i, reg, limit=40):
    """what happens to reg after seq[i]: 'read' | 'dead' | 'unknown' (a label, branch or the limit comes first)"""
    for k in range(i + 1, min(len(seq), i + 1 + limit)):
        x = seq[k]
        if x.kind == 'label':
            return 'unknown'
        if reg in x.r:
            return 'read'
        if reg in x.w:
            return 'dead'
        if x.kind in ('br', 'cbr'):
            return 'unknown'
        if x.kind == 'ret':
            return 'dead'
    return 'unknown'


def imm_of(o):
    m = re.fullmatch(r'#(-?(?:0x[0-9a-fA-F]+|\d+))', o)
    return int(m.group(1), 0) if m else None


def mlen(x):
    """encoded length model (bytes) of a pdp64 instruction, from the page-2 map of the ISA (no object needed); an estimate"""
    mn, ops = x.mn, x.ops
    def small(o, lo=-8, hi=7):
        v = imm_of(o)
        return v is not None and lo <= v <= hi
    def memlen(o):
        m = re.fullmatch(r'(-?\d*)\((r\d+|sp|fp)\)', o)
        if m:
            d = int(m.group(1) or 0)
            return m, d
        return None, None
    if mn in ('movq', 'movl', 'movw', 'movb', 'movzl', 'movzw', 'movzb') and len(ops) == 2:
        a, b = ops
        if isreg(a) and isreg(b):
            return 2
        if mn == 'movq' and a.startswith('#') and isreg(b):
            return 2 if small(a) else (4 if small(a, -32768, 32767) else 6)
        for o, reg in ((a, b), (b, a)):
            m, d = memlen(o)
            if m and isreg(reg):
                base = rn(m.group(2))
                if d == 0:
                    return 2
                if base == 'r14' and d % (4 if mn in ('movl', 'movzl') else 8) == 0 and 0 <= d <= (124 if mn == 'movl' else 248) and mn in ('movq', 'movl'):
                    return 2
                if o is a and mn == 'movq' and d in (8, 16, 24, 32) or mn == 'movq' and d in (8, 16) or mn == 'movl' and d in (4, 8, 12, 16) and o is a:
                    return 2
                return 4 if -2048 <= d < 2048 else 6
        return 6 if any(o and not isreg(o) and not o.startswith('#') for o in ops) else 4
    if mn in ('shl', 'shr', 'sar') and len(ops) == 2 and small(ops[0], 0, 15):
        return 2
    if mn in ('and', 'bis', 'xor', 'add') and len(ops) == 2 and small(ops[0]):
        return 2
    if mn in ALU2 and len(ops) == 2 and isreg(ops[0]) and isreg(ops[1]):
        return 2
    if mn in ('push', 'pop', 'ret') or mn in ('clr', 'inc', 'dec', 'neg', 'com') and isreg(ops[0]):
        return 2
    if mn in ('pushm8', 'popm8'):
        return 2
    if mn in ('sub', 'add') and ops[-1] == 'sp' and ops[0].startswith('#'):
        v = imm_of(ops[0])
        return 2 if v is not None and v % 8 == 0 and 0 <= v <= 2040 else 4
    if mn in ('pushm', 'popm'):
        return 2 if (ops and (imm_of(ops[0]) or 0) & 0xFF == 0 and (imm_of(ops[0]) or 0) >> 8) else 4
    if mn in ('call', 'lea') or any(o and not isreg(o) and not o.startswith('#') and '(' not in o for o in ops):
        return 6
    if mn in BRANCH:
        return 2
    return 4


SAMPLES = {}
COUNTS = collections.Counter()
BYTES = collections.Counter()
NOTE = {}


def site(name, fname, sid, seq, i, n=1, ctx=1, ins=0, nbytes=0):
    """record a site: counts, the instructions it would save and the bytes; keep the text for sampling"""
    COUNTS[name] += 1
    COUNTS[name + '#ins'] += ins
    BYTES[name] += nbytes
    lines = [x.text if x.kind != 'label' else x.lab + ':' for x in seq[max(0, i - ctx):i + n + ctx]]
    SAMPLES.setdefault(name, []).append((sid, fname, lines, i - max(0, i - ctx), n))


def nextins(seq, i, k=1):
    """the k-th instruction after i, if no label intervenes"""
    for x in seq[i + 1:i + 1 + k]:
        if x.kind == 'label':
            return None
    return seq[i + k] if i + k < len(seq) else None


def run_detectors(sid, funcs):
    for fname, seq in funcs:
        n = len(seq)
        calls_seen = False
        labels_before = {}
        for i, x in enumerate(seq):
            if x.kind == 'label':
                labels_before[x.lab] = i
        for i, x in enumerate(seq):
            if x.kind == 'label':
                continue
            COUNTS['all'] += 1
            mn, ops = x.mn, x.ops
            n1 = nextins(seq, i)
            n2 = nextins(seq, i, 2)
            # --- (a) register moves -----------------------------------------------------------------------------------------
            if mn == 'movq' and len(ops) == 2 and isreg(ops[0]) and isreg(ops[1]):
                COUNTS['movrr'] += 1
                a, b = rn(ops[0]), rn(ops[1])
                cls = 'other'
                if 'r14' in (a, b) or 'r13' in (a, b):
                    cls = 'frame'
                else:
                    # return value: b in r0/r1 and the epilogue to a ret follows
                    k, ok = i + 1, False
                    while b in ('r0', 'r1') and k < n and seq[k].kind != 'label' and k < i + 8:
                        y = seq[k]
                        if y.kind == 'ret':
                            ok = True
                            break
                        if y.mn in ('pop', 'popm', 'popm8', 'add', 'lea', 'sub') and (y.w & {'r14'}) and not (y.w - {'r14'} - CALLEE):
                            k += 1
                            continue
                        break
                    if ok:
                        cls = 'return value'
                    else:
                        # argument set-up: b in r0..r5 and a call follows before b is written
                        k, ok = i + 1, False
                        while b in ARGS and k < n and seq[k].kind != 'label' and k < i + 14:
                            y = seq[k]
                            if y.kind == 'call' or y.mn == 'jmp':
                                ok = True
                                break
                            if b in y.w or y.kind in ('br', 'cbr', 'ret'):
                                break
                            k += 1
                        if ok:
                            cls = 'argument for a call'
                        elif i > 0 and seq[i - 1].kind == 'call' and a in ('r0', 'r1'):
                            cls = 'call result kept'
                        elif all(q.kind == 'label' or (q.mn == 'movq' and len(q.ops) == 2 and isreg(q.ops[0]) and isreg(q.ops[1])) or q.mn in ('push', 'pushm', 'pushm8', 'sub') for q in seq[:i]) and a in ARGS:
                            cls = 'parameter moved at function entry'
                        elif a in ARGS and b in {'r8', 'r9', 'r10', 'r11', 'r15'} and not calls_seen:
                            cls = 'parameter kept in a saved register'
                        elif a in CALLER and b in {'r8', 'r9', 'r10', 'r11', 'r15'}:
                            cls = 'value kept in a saved register'
                        else:
                            # two-address copy: the next instructions modify b, and a is still wanted
                            y = n1
                            if y is not None and y.kind == 'ins' and b in y.w and y.mn in ALU2 | UNARY and y.ops and ops[1] in (y.ops[-1],) and a not in y.w:
                                lv = live_after(seq, i + 1, a)
                                cls = 'two-address copy, source read later' if lv == 'read' else (
                                    'two-address copy, source dead after' if lv == 'dead' else 'two-address copy, source liveness unknown (block ends)')
                            elif y is None or y.kind in ('br',) or (i > 0 and seq[i - 1].kind in ('br', 'label')) or (i + 1 < n and seq[i + 1].kind == 'label'):
                                cls = 'copy at a control-flow join (loop-carried value / phi)'
                            elif y is not None and y.kind == 'ins' and y.mn in ('movq', 'movl', 'movzl', 'movzb', 'movzw') and False:
                                cls = 'other'
                if cls == 'other':
                    # b is read by the next instruction only as a source
                    pass
                site('mov: ' + cls, fname, sid, seq, i, 1, 2)
            if mn in ('call', 'calli'):
                calls_seen = True
            # --- (a2) three-operand ALU: movq a,b ; OP c,b ------------------------------------------------------------------
            if mn == 'movq' and len(ops) == 2 and isreg(ops[0]) and isreg(ops[1]) and ops[0] != ops[1] and n1 is not None and n1.kind == 'ins':
                a, b = ops
                y = n1
                if y.mn in ALU2 and len(y.ops) == 2 and y.ops[1] == b and y.ops[0] != b and 'r14' not in (rn(a), rn(b)) and 'r13' not in (rn(a), rn(b)):
                    c = y.ops[0]
                    kind = 'imm' if c.startswith('#') else ('reg' if isreg(c) else 'mem')
                    bytes_before = 2 + mlen(y)
                    bytes_after = {'reg': 4, 'imm': 6 if not (imm_of(c) is not None and -8 <= imm_of(c) <= 15) else 4, 'mem': 6}[kind]
                    lv = live_after(seq, i + 1, rn(a))
                    site('3op: %s %s' % (y.mn, kind), fname, sid, seq, i, 2, 1, 1, bytes_before - bytes_after)
                    COUNTS['3op: all'] += 1
                    COUNTS['3op: all#ins'] += 1
                    BYTES['3op: all'] += bytes_before - bytes_after
                    COUNTS['3op: source %s' % lv] += 1
                    if y.mn == 'add' and kind in ('reg', 'imm') and (kind == 'reg' or -32768 <= imm_of(c) <= 32767):
                        site('3op: add coverable by lea (needs flags dead)', fname, sid, seq, i, 2, 1, 1, 0)
                    if y.mn == 'sub' and kind == 'imm' and -32768 < imm_of(c) <= 32768:
                        site('3op: sub #imm coverable by lea', fname, sid, seq, i, 2, 1, 1, 0)
                elif y.mn in UNARY and y.mn != 'clr' and y.ops == [b]:
                    site('2op unary after copy: ' + y.mn, fname, sid, seq, i, 2, 1, 1, 0)
            # --- (b) load/store pairs ----------------------------------------------------------------------------------------
            if mn in ('movq', 'movl') and len(ops) == 2 and n1 is not None and n1.mn == mn and len(n1.ops) == 2:
                w = MOVS[mn]
                def mo(ins_):
                    for k, o in enumerate(ins_.ops):
                        m = re.fullmatch(r'(-?\d*)\((r\d+|sp|fp)\)', o)
                        if m and isreg(ins_.ops[1 - k]):
                            return ('ld' if k == 0 else 'st', rn(m.group(2)), int(m.group(1) or 0), rn(ins_.ops[1 - k]))
                    return None
                A, B = mo(x), mo(n1)
                if A and B and A[0] == B[0] and A[1] == B[1] and abs(A[2] - B[2]) == w and A[3] != B[3]:
                    if not (A[0] == 'ld' and A[3] == A[1]):
                        nb = mlen(x) + mlen(n1) - 4
                        site('pair: %s %s' % ('load' if A[0] == 'ld' else 'store', mn), fname, sid, seq, i, 2, 1, 1, nb)
            # --- (c) auto-increment ---------------------------------------------------------------------------------------
            if mn in MOVS and len(ops) == 2:
                for k, o in enumerate(ops):
                    m = re.fullmatch(r'(-?\d*)\((r\d+|sp|fp)\)', o)
                    if not m or not isreg(ops[1 - k]) or (k == 0 and rn(ops[1]) == rn(m.group(2))):
                        continue
                    base, d, sz = rn(m.group(2)), int(m.group(1) or 0), MOVS[mn]
                    if base in ('r14', 'r13'):
                        continue
                    # look ahead for the update of base
                    for t in range(i + 1, min(n, i + 6)):
                        y = seq[t]
                        if y.kind == 'label' or y.kind in ('br', 'cbr', 'call', 'ret'):
                            break
                        upd = None
                        if y.mn == 'lea' and len(y.ops) == 2 and re.fullmatch(r'(-?\d+)\(%s\)' % base, y.ops[0]) and y.ops[1] == base:
                            upd = int(re.match(r'(-?\d+)', y.ops[0]).group(1))
                        elif y.mn == 'add' and len(y.ops) == 2 and y.ops[1] == base and imm_of(y.ops[0]) is not None:
                            upd = imm_of(y.ops[0])
                        elif y.mn == 'sub' and len(y.ops) == 2 and y.ops[1] == base and imm_of(y.ops[0]) is not None:
                            upd = -imm_of(y.ops[0])
                        elif y.mn == 'inc' and y.ops == [base]:
                            upd = 1
                        elif y.mn == 'dec' and y.ops == [base]:
                            upd = -1
                        if upd is not None:
                            gap = t - i - 1
                            kind = 'post-increment (access, then base += size)' if d == 0 and upd == sz else (
                                'writeback with another step (access at d, base += d)' if d == upd else None)
                            if kind and all(base not in seq[u].r | seq[u].w for u in range(i + 1, t)):
                                site('autoinc: ' + kind + (', adjacent' if gap == 0 else ', within 5'), fname, sid, seq, i, t - i + 1, 1, 1, 0)
                            break
                        if base in y.r | y.w:
                            break
                    # update first, then the access at 0 (pre-increment/decrement)
                    if i > 0 and seq[i - 1].kind == 'ins':
                        y = seq[i - 1]
                        upd = None
                        if y.mn == 'lea' and len(y.ops) == 2 and y.ops[1] == base and re.fullmatch(r'(-?\d+)\(%s\)' % base, y.ops[0]):
                            upd = int(re.match(r'(-?\d+)', y.ops[0]).group(1))
                        elif y.mn == 'dec' and y.ops == [base]:
                            upd = -1
                        elif y.mn == 'inc' and y.ops == [base]:
                            upd = 1
                        elif y.mn in ('add', 'sub') and len(y.ops) == 2 and y.ops[1] == base and imm_of(y.ops[0]) is not None:
                            upd = imm_of(y.ops[0]) * (1 if y.mn == 'add' else -1)
                        if upd is not None and d == 0 and (upd == -sz or upd == sz):
                            site('autoinc: pre-%s (base +-= size, then access)' % ('decrement' if upd < 0 else 'increment'), fname, sid, seq, i - 1, 2, 1, 1, 0)
            # --- (d) bit fields -------------------------------------------------------------------------------------------------
            if mn == 'shr' and len(ops) == 2 and imm_of(ops[0]) is not None and isreg(ops[1]) and n1 is not None:
                if n1.mn == 'and' and n1.ops[1] == ops[1] and imm_of(n1.ops[0]) is not None and imm_of(n1.ops[0]) > 0 and imm_of(n1.ops[0]) & (imm_of(n1.ops[0]) + 1) == 0:
                    w_ = imm_of(n1.ops[0]).bit_length()
                    site('field: unsigned extract, shr #n ; and #2^w-1', fname, sid, seq, i, 2, 1, 1, mlen(x) + mlen(n1) - 6)
                    if i > 0 and seq[i - 1].mn in ('movzl', 'movl') and len(seq[i - 1].ops) == 2 and seq[i - 1].ops[1] == ops[1] and isreg(seq[i - 1].ops[0]):
                        site('field: ... preceded by movzl (32-bit field of an unsigned int; extzb replaces all three)', fname, sid, seq, i - 1, 3, 1, 2, mlen(seq[i - 1]) + mlen(x) + mlen(n1) - 6)
                    if i > 0 and seq[i - 1].mn == 'movq' and seq[i - 1].ops[1] == ops[1] and isreg(seq[i - 1].ops[0]):
                        site('field: ... preceded by a copy (3 instructions to 1)', fname, sid, seq, i - 1, 3, 1, 2, mlen(seq[i - 1]) + mlen(x) + mlen(n1) - 6)
                elif n1.mn in ('movzb', 'movzw', 'movzl') and n1.ops == [ops[1], ops[1]]:
                    site('field: shr #n ; movzb/movzw/movzl (byte or word of a value)', fname, sid, seq, i, 2, 1, 1, mlen(x) + mlen(n1) - 6)
                    if i > 0 and seq[i - 1].mn in ('movzl', 'movl') and len(seq[i - 1].ops) == 2 and seq[i - 1].ops[1] == ops[1]:
                        site('field: ... preceded by movzl (extzb replaces all three)', fname, sid, seq, i - 1, 3, 1, 2, mlen(seq[i - 1]) + mlen(x) + mlen(n1) - 6)
            if mn == 'shl' and len(ops) == 2 and imm_of(ops[0]) is not None and isreg(ops[1]) and n1 is not None and n1.mn in ('sar', 'shr') and n1.ops[1] == ops[1] and imm_of(n1.ops[0]) is not None:
                site('field: %s extract, shl ; %s' % ('signed' if n1.mn == 'sar' else 'unsigned', n1.mn), fname, sid, seq, i, 2, 1, 1, mlen(x) + mlen(n1) - 6)
            if mn == 'bic' and len(ops) == 2 and imm_of(ops[0]) is not None and isreg(ops[1]):
                for t in range(i + 1, min(n, i + 6)):
                    y = seq[t]
                    if y.kind != 'ins':
                        break
                    if y.mn == 'bis' and y.ops[1] == ops[1] and isreg(y.ops[0]):
                        site('field: insert, bic #mask,rd ... bis rs,rd', fname, sid, seq, i, t - i + 1, 1, 2, 0)
                        break
            # --- (e) conditional skip over one or two simple instructions ---------------------------------------------------------
            if x.kind == 'cbr' and mn != 'br' and ops:
                tgt = ops[-1]
                for L in (1, 2, 3):
                    if i + L + 1 < n and seq[i + L + 1].kind == 'label' and seq[i + L + 1].lab == tgt:
                        body = seq[i + 1:i + 1 + L]
                        if all(b.kind == 'ins' and not b.st and b.mn not in ('mcpy', 'push', 'pop') for b in body):
                            kinds = ','.join(sorted({('mov' if b.mn in MOVS or b.mn == 'lea' else ('clr' if b.mn == 'clr' else 'alu')) for b in body}))
                            site('select: bCC over %d simple instruction%s (%s)' % (L, 's' if L > 1 else '', kinds), fname, sid, seq, i, L + 2, 1, L, 0)
                        break
                # diamond: bCC L1 ; I ; br L2 ; L1: J ; L2:
                if i + 4 < n and seq[i + 2].kind == 'br' and seq[i + 3].kind == 'label' and seq[i + 3].lab == tgt and seq[i + 1].kind == 'ins' and seq[i + 4].kind == 'ins' and i + 5 < n and seq[i + 5].kind == 'label' and seq[i + 5].lab == seq[i + 2].ops[0] and not seq[i + 1].st and not seq[i + 4].st and seq[i + 1].w == seq[i + 4].w and len(seq[i + 1].w) == 1:
                    arms = {seq[i + 1].mn + ' ' + ','.join(seq[i + 1].ops[:1]), seq[i + 4].mn + ' ' + ','.join(seq[i + 4].ops[:1])}
                    if arms == {'movq #1', 'clr r' + seq[i + 1].ops[-1][1:]} or arms == {'movq #1', 'clr ' + seq[i + 1].ops[-1]} or ({a_.split()[0] for a_ in arms} == {'movq', 'clr'} and any(a_ == 'movq #1' for a_ in arms)):
                        site('select: diamond that materialises a boolean (movq #1 / clr): `set cc` exists', fname, sid, seq, i, 6, 0, 2, 0)
                    else:
                        site('select: diamond, two one-instruction arms writing the same register (other values)', fname, sid, seq, i, 6, 0, 1, 0)
            # --- (f) test bit and branch --------------------------------------------------------------------------------------------
            if mn == 'and' and len(ops) == 2 and imm_of(ops[0]) is not None and isreg(ops[1]) and n1 is not None and n1.kind == 'cbr' and n1.mn in ('cbne', 'cbeq') and n1.ops[0] == ops[1] and n1.ops[1] == '#0':
                v = imm_of(ops[0])
                dead = live_after(seq, i + 1, rn(ops[1]))
                if v > 0 and v & (v - 1) == 0:
                    site('bit test: and #2^k,rX ; cbeq/cbne rX,#0 (single bit, rX %s afterwards)' % ('dead' if dead == 'dead' else 'maybe live'), fname, sid, seq, i, 2, 1, 1, 0)
                else:
                    site('mask test: and #mask,rX ; cbeq/cbne rX,#0 (several bits)', fname, sid, seq, i, 2, 1, 0, 0)
                if i > 0 and seq[i - 1].mn == 'movq' and seq[i - 1].ops[1] == ops[1] and isreg(seq[i - 1].ops[0]):
                    site('mask test: ... preceded by a copy (movq a,b ; and #m,b ; cbCC b,#0)', fname, sid, seq, i - 1, 3, 1, 1, 0)
            if mn == 'shr' and len(ops) == 2 and imm_of(ops[0]) is not None and n1 is not None and n1.mn == 'and' and n1.ops == ['#1', ops[1]] and n2 is not None and n2.kind == 'cbr':
                site('bit test: shr #k ; and #1 ; branch', fname, sid, seq, i, 3, 1, 2, 0)
            if mn == 'tst' or mn == 'bit':
                COUNTS['tst/bit emitted: ' + mn] += 1
            # --- (g) loops ----------------------------------------------------------------------------------------------------------------
            if x.kind == 'cbr' and mn != 'br' and ops and ops[-1] in labels_before and labels_before[ops[-1]] < i:
                COUNTS['loop: backward conditional branches'] += 1
                p = seq[i - 1] if i > 0 and seq[i - 1].kind == 'ins' else None
                pp = seq[i - 2] if i > 1 and seq[i - 1].kind == 'label' and seq[i - 2].kind == 'ins' else None   # a label between: the loop is entered at the test
                for q in (p, pp):
                    if q is None:
                        continue
                    r_ = None
                    if q.mn in ('dec', 'inc') and len(q.ops) == 1 and isreg(q.ops[0]):
                        r_ = (q.ops[0], q.mn)
                    elif q.mn in ('add', 'sub') and len(q.ops) == 2 and imm_of(q.ops[0]) is not None and isreg(q.ops[1]):
                        r_ = (q.ops[1], 'add' if q.mn == 'add' else 'sub')
                    elif q.mn == 'lea' and len(q.ops) == 2 and q.ops[1] and re.fullmatch(r'-?\d+\(%s\)' % re.escape(q.ops[1]), q.ops[0]):
                        r_ = (q.ops[1], 'add')
                    if r_ and (x.ops[0] == r_[0] or (len(x.ops) > 1 and x.ops[1] == r_[0])):
                        step = 'dec' if r_[1] in ('dec', 'sub') else 'inc'
                        if q is pp:
                            site('loop: step ; LABEL ; cbCC (loop entered at its test; fusing needs loop rotation) [%s]' % step, fname, sid, seq, i - 2, 3, 0, 1, 0)
                        elif step == 'dec' and mn in ('cbne',) and x.ops[1] == '#0':
                            site('loop: dec rX ; cbne rX,#0 -> sob', fname, sid, seq, i - 1, 2, 1, 1, 0)
                        elif step == 'dec':
                            site('loop: count down by dec/sub, other test (cbCC rX,#k or rY)', fname, sid, seq, i - 1, 2, 1, 1, 0)
                        else:
                            site('loop: count up, inc/add then cbCC rX,{rY|#k} (aoblss/acbl)', fname, sid, seq, i - 1, 2, 1, 1, 0)
                        break
            # --- (h) shift-add / scaled operands ---------------------------------------------------------------------------------------------
            if mn in ('shl', 'asl') and len(ops) == 2 and imm_of(ops[0]) is not None and isreg(ops[1]) and n1 is not None and n1.mn == 'add' and len(n1.ops) == 2 and n1.ops[0] == ops[1] and isreg(n1.ops[1]) and n1.ops[1] != ops[1]:
                sh = imm_of(ops[0])
                dead = live_after(seq, i + 1, rn(ops[1])) != 'read'
                site('shift-add: shl #%s,rT ; add rT,rY (%s)' % (sh if sh in (1, 2, 3) else 'n>3', 'rT dead' if dead else 'rT read later'), fname, sid, seq, i, 2, 1, 1 if dead else 0, 0)
            if mn == 'mul' and len(ops) == 2 and isreg(ops[1]) and n1 is not None and n1.mn == 'add' and n1.ops[0] == ops[1] and n1.ops[1] != ops[1]:
                site('multiply-add: mul ; add', fname, sid, seq, i, 2, 1, 1, 0)
            if mn == 'lea' and len(ops) == 2 and '*' in ops[0]:
                COUNTS['scaled lea emitted'] += 1
            if mn in MOVS:
                for o in ops:
                    if '*' in o:
                        COUNTS['scaled-index memory operand emitted'] += 1
            # --- (i) extensions ----------------------------------------------------------------------------------------------------------------
            if mn in ('movl', 'movzl', 'movw', 'movzw', 'movb', 'movzb') and len(ops) == 2 and isreg(ops[0]) and isreg(ops[1]):
                COUNTS['ext: total (%s r,r)' % mn] += 1
                src = rn(ops[0])
                prev = None
                for t in range(i - 1, max(-1, i - 6), -1):
                    if seq[t].kind == 'label':
                        break
                    if src in seq[t].w:
                        prev = seq[t]
                        break
                if prev is None:
                    c = 'value from before the block/argument'
                elif prev.kind == 'call':
                    c = 'after a call (result)'
                elif prev.ld and prev.mn in MOVS:
                    c = 'after a load (fusible into the load)' if MOVS.get(prev.mn, 8) >= {'movl': 4, 'movzl': 4, 'movw': 2, 'movzw': 2, 'movb': 1, 'movzb': 1}[mn] else 'after a narrower load'
                elif prev.mn in ALU2 or prev.mn in UNARY or prev.mn == 'lea':
                    c = 'after an ALU result (a 32-bit ALU form would absorb it)'
                elif prev.mn in MOVS:
                    c = 'after another move/extension'
                else:
                    c = 'after ' + prev.mn
                site('ext: ' + c, fname, sid, seq, i, 1, 2, 0, 0)
            # --- (k) call, then only an epilogue, then ret ---------------------------------------------------------------------------------------
            if mn == 'call':
                k, ok = i + 1, True
                while k < n and seq[k].kind != 'label' and seq[k].kind != 'ret' and k < i + 6:
                    y = seq[k]
                    if y.mn in ('pop', 'popm', 'popm8', 'add', 'lea', 'sub') and 'r14' in y.w and not (y.w - {'r14'} - CALLEE):
                        k += 1
                        continue
                    ok = False
                    break
                if ok and k < n and seq[k].kind == 'ret' and seq[k].mn == 'ret' and k > i + 1:
                    taken = any((y.mn == 'lea' and y.ops and 'sp' in y.ops[0]) or (y.mn == 'movq' and y.ops and y.ops[0] == 'sp' and y.ops[1] != 'fp') for y in seq)
                    site('tail call missed: call f ; epilogue ; ret, %s' % ('address of the frame is taken (not legal)' if taken else 'no frame address taken (legal)'), fname, sid, seq, i, k - i + 1, 0, 0 if taken else 1, 0 if taken else 2)
            # --- (m) memory operand ---------------------------------------------------------------------------------------------------------------
            if mn == 'movq' and len(ops) == 2 and isreg(ops[1]) and not isreg(ops[0]) and not ops[0].startswith(('#', '=')) and n1 is not None and n1.kind == 'ins':
                t = rn(ops[1])
                y = n1
                if y.mn in ('add', 'sub', 'and', 'bis', 'xor', 'bic', 'mul', 'cmp', 'bit') and len(y.ops) == 2 and y.ops[0] == ops[1] and y.ops[1] != ops[1] and not (y.ld):
                    if t not in regs_in(ops[0]) or True:
                        lv = live_after(seq, i + 1, t)
                        tag = {'dead': 'temp dead afterwards', 'read': 'temp read again', 'unknown': 'temp liveness unknown (block ends)'}[lv]
                        if lv != 'read':
                            site('mem operand: movq mem,rT ; %s rT,rD (%s)' % (y.mn, tag), fname, sid, seq, i, 2, 1, 1 if lv == 'dead' else 0, mlen(x) + mlen(y) - 4 if lv == 'dead' else 0)
                        else:
                            COUNTS['mem operand: temp read again (not removable)'] += 1
                elif y.mn in ('cbeq', 'cbne', 'cblt', 'cbge', 'cbgt', 'cble', 'cbcs', 'cbcc', 'cbhi', 'cblos') and y.ops[0] == ops[1] and len(y.ops) == 3:
                    site('mem operand: movq mem,rT ; cbCC rT,... (compare with memory in a fused branch needs a new form)', fname, sid, seq, i, 2, 1, 0, 0)
            if mn == 'movq' and len(ops) == 2 and isreg(ops[1]) and x.ld and n2 is not None and n1 is not None and n1.kind == 'ins' and n2.kind == 'ins' and n2.mn == 'movq' and n2.ops == [ops[1], ops[0]] and n1.mn in ('add', 'sub', 'bis', 'bic', 'inc', 'dec', 'xor', 'and', 'neg', 'com') and n1.ops[-1] == ops[1]:
                lv = live_after(seq, i + 2, rn(ops[1]))
                site('read-modify-write: movq M,rT ; op ,rT ; movq rT,M (%s)' % ('rT dead' if lv != 'read' else 'rT read later'), fname, sid, seq, i, 3, 1, 2 if lv != 'read' else 0, 0)
            # --- (n) constants --------------------------------------------------------------------------------------------------------------------------
            if mn == 'movq' and len(ops) == 2 and isreg(ops[1]) and ops[0].startswith('='):
                COUNTS['const: movq =K (pool)'] += 1
            elif mn == 'movq' and len(ops) == 2 and imm_of(ops[0]) is not None and isreg(ops[1]):
                v = imm_of(ops[0])
                COUNTS['const: movq #imm, %s' % ('4-bit' if -8 <= v <= 7 else ('16-bit' if -32768 <= v <= 32767 else ('32-bit' if -2**31 <= v < 2**31 else '64-bit')))] += 1
            elif mn == 'clr' and ops and isreg(ops[0]):
                COUNTS['const: clr reg'] += 1
            # --- (l) carries and wide arithmetic ---------------------------------------------------------------------------------------------------
            if mn == 'add' and len(ops) == 2 and isreg(ops[0]) and isreg(ops[1]) and n1 is not None and n1.kind in ('cbr', 'ins'):
                for y in (n1, n2):
                    if y is None or y.kind != 'cbr' or y.mn not in ('cbcs', 'cbcc', 'cblos', 'cbhi'):
                        continue
                    if len(y.ops) == 3 and {y.ops[0], y.ops[1]} == {ops[0], ops[1]} and (y is n1 or n1.w <= {rn(ops[1])}):
                        site('carry: add a,b ; cbCS/cbLOS b,a (carry tested by comparing the sum)', fname, sid, seq, i, 2 if y is n1 else 3, 1, 1, 2)
                        break
            if mn == 'call' and ops and re.match(r'__\w*(ti3|ti2|di3|si3)\w*$', ops[0]):
                COUNTS['helper call: ' + ops[0]] += 1
        # ---- functions: prologue and epilogue
        pro = epi = 0
        probytes = epibytes = 0
        k = 0
        FR = lambda y: y.kind == 'ins' and (y.mn in ('push', 'pushm', 'pushm8') or (y.mn in ('sub', 'lea') and y.ops[-1] in ('sp', 'r14') and y.ops[0].startswith(('#', '-'))) or y.mn == 'movq' and y.ops == ['sp', 'fp'])
        while k < n and FR(seq[k]) or (k < n and seq[k].kind == 'label'):
            if seq[k].kind == 'ins':
                pro += 1
                probytes += mlen(seq[k])
            k += 1
        COUNTS['frame: functions'] += 1
        COUNTS['frame: prologue instructions'] += pro
        BYTES['frame: prologue'] += probytes
        has_call = any(y.kind == 'call' for y in seq)
        COUNTS['frame: functions with no call (leaf)'] += 0 if has_call else 1
        for t, y in enumerate(seq):
            if y.kind == 'ret' and y.mn == 'ret':
                e = 0
                eb = 0
                u = t - 1
                while u >= 0 and seq[u].kind == 'ins' and (seq[u].mn in ('pop', 'popm', 'popm8') or (seq[u].mn in ('add', 'lea') and seq[u].ops[-1] in ('sp', 'r14')) or seq[u].mn == 'movq' and seq[u].ops == ['fp', 'sp']):
                    e += 1
                    eb += mlen(seq[u])
                    u -= 1
                COUNTS['frame: epilogue instructions (without ret)'] += e
                BYTES['frame: epilogue'] += eb
                COUNTS['frame: ret'] += 1
            elif y.kind == 'ret':
                COUNTS['frame: tail jmp'] += 1
        COUNTS['calls: call'] += sum(1 for y in seq if y.mn == 'call')
        COUNTS['calls: calli'] += sum(1 for y in seq if y.mn == 'calli')


# ---- instruction classes across architectures (where do the extra instructions come from?) ------------------------------------
def split_top(o):
    return P.split_ops(o)


def iclass(fam, mn, ops):
    """a coarse class for an instruction of the target family: const, move, load, store, ext, alu, cmpbr (compare and/or branch), call, ret, frame, other"""
    m = mn.lower()
    o = [x.strip() for x in split_top(ops)] if isinstance(ops, str) else ops
    if fam in ('amd64', 'i386'):
        if m.startswith('call'):
            return 'call'
        if m.startswith(('ret', 'leave')):
            return 'ret'
        if m.startswith('j') or m in ('loop',):
            return 'cmpbr'
        if m.startswith(('cmp', 'test', 'bt')) or m in ('ucomisd', 'comisd', 'ucomiss', 'comiss'):
            return 'cmpbr'
        if m.startswith(('push', 'pop')):
            return 'frame'
        if m.startswith(('movz', 'movs')) and len(m) <= 6 and m not in ('movss', 'movsd') or m in ('cltq', 'cqto', 'cltd', 'cwtl', 'movslq'):
            return 'ext'
        if re.match(r'^mov(?!aps|ups|dq|ap|up|d$|q$)', m) or m in ('movq', 'movd'):
            if len(o) == 2:
                src, dst = o
                if '(' in dst or dst.startswith('%gs') or (not dst.startswith('%') and not dst.startswith('$')):
                    return 'store'
                if '(' in src or (not src.startswith(('%', '$'))):
                    return 'load'
                if src.startswith('$'):
                    return 'const'
                return 'move'
        if m.startswith(('movaps', 'movups', 'movdqa', 'movdqu', 'movq', 'movd')):
            return 'store' if len(o) == 2 and '(' in o[1] else ('load' if len(o) == 2 and '(' in o[0] else 'move')
        if m.startswith('cmov') or m.startswith('set'):
            return 'alu'
        return 'alu'
    if fam == 'aarch64':
        if m in ('bl', 'blr'):
            return 'call'
        if m in ('ret',):
            return 'ret'
        if m.startswith('b.') or m in ('b', 'br', 'cbz', 'cbnz', 'tbz', 'tbnz'):
            return 'cmpbr'
        if m in ('cmp', 'cmn', 'tst', 'ccmp', 'ccmn', 'fcmp', 'fcmpe'):
            return 'cmpbr'
        if m in ('mov', 'movz', 'movn', 'movk', 'movi', 'mvn', 'fmov'):
            return 'const' if len(o) == 2 and o[1].startswith('#') else 'move'
        if m.startswith(('ldr', 'ldur', 'ldp', 'ldn', 'ld1', 'ldar', 'ldxr', 'ldaxr', 'ldrsw')):
            return 'load'
        if m.startswith(('str', 'stur', 'stp', 'stn', 'st1', 'stlr', 'stxr', 'stlxr')):
            return 'store'
        if m in ('sxtw', 'sxtb', 'sxth', 'uxtb', 'uxth', 'ubfx', 'sbfx', 'ubfiz', 'sbfiz', 'bfi', 'bfxil', 'bfm', 'ubfm', 'sbfm'):
            return 'ext'
        if m in ('adrp',):
            return 'const'
        return 'alu'
    if fam == 'riscv64':
        if m in ('call', 'jal', 'jalr', 'tail') and not (m == 'jalr' and len(o) == 1 and o[0] == 'ra' and False):
            return 'call' if m == 'call' or (m in ('jal', 'jalr') and o and o[0] == 'ra') else 'cmpbr'
        if m == 'ret':
            return 'ret'
        if m in ('j', 'jr') or m.startswith(('b', 'c.b')) and m not in ('bset', 'bclr', 'binv', 'bext'):
            return 'cmpbr'
        if m.startswith(('slt', 'sgt', 'seqz', 'snez', 'sltz', 'sgtz')):
            return 'cmpbr'
        if m in ('li', 'lui', 'auipc'):
            return 'const'
        if m in ('mv', 'c.mv'):
            return 'move'
        if re.match(r'^(l[bhwd]u?|fl[wd]|c\.l[wd]|c\.fld)', m) and '(' in ops:
            return 'load'
        if re.match(r'^(s[bhwd]|fs[wd]|c\.s[wd])$', m):
            return 'store'
        if m in ('sext.w', 'zext.b', 'zext.h', 'zext.w', 'sext.b', 'sext.h', 'addiw') and (m != 'addiw' or o[-1] == '0'):
            return 'ext'
        return 'alu'
    if fam == 'arm':
        base = re.sub(r'(eq|ne|hs|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le)$', '', m)
        if base in ('bl', 'blx'):
            return 'call'
        if m == 'bx' and o == ['lr']:
            return 'ret'
        if base in ('b', 'bx', 'cbz', 'cbnz', 'cmp', 'cmn', 'tst', 'teq') or base.startswith(('cmp', 'tst')):
            return 'cmpbr'
        if base in ('push', 'pop'):
            return 'frame'
        if base in ('mov', 'movw', 'movt', 'mvn'):
            return 'const' if len(o) == 2 and o[1].startswith('#') else 'move'
        if re.match(r'^(ldr|ldm|ldrd|ldrb|ldrh|ldrsb|ldrsh)', base):
            return 'load'
        if re.match(r'^(str|stm|strd|strb|strh)', base):
            return 'store'
        if base in ('uxtb', 'uxth', 'sxtb', 'sxth', 'ubfx', 'sbfx', 'bfi', 'bfc', 'uxtab'):
            return 'ext'
        return 'alu'
    if fam == 'ppc':
        if m in ('bl', 'bctrl', 'blrl', 'bla'):
            return 'call'
        if m in ('blr',):
            return 'ret'
        if m.startswith('b') and m not in ('bswap',) or m.startswith(('cmp', 'bc')):
            return 'cmpbr'
        if m in ('li', 'lis'):
            return 'const'
        if m in ('mr', 'mtctr', 'mtlr', 'mflr', 'mfctr', 'mcrf'):
            return 'move'
        if re.match(r'^l[bhwd]z?[ux]?x?$|^lha|^lwa|^lfd|^lfs|^lmw|^lbz|^lhz|^lwz|^ld', m):
            return 'load'
        if re.match(r'^st[bhwd][ux]*x?$|^stfd|^stfs|^stmw|^std', m):
            return 'store'
        if m.startswith(('ext', 'clrl', 'clrr', 'rldic', 'rlwin', 'rlwim', 'rldim')) or m.startswith('rl') and False:
            return 'ext'
        return 'alu'
    if fam == 'vax':
        if m in ('calls', 'callg', 'jsb', 'bsbw', 'bsbb'):
            return 'call'
        if m == 'ret' or m == 'rsb':
            return 'ret'
        if m.startswith('j') or m.startswith(('cmp', 'tst', 'bit', 'sob', 'aob', 'acb', 'bb', 'case')):
            return 'cmpbr'
        if m.startswith('push'):
            return 'frame'
        if m.startswith(('mov', 'clr', 'cvt', 'mneg', 'mcom')):
            if m.startswith(('movz', 'cvt')):
                return 'ext'
            if len(o) == 2:
                if re.search(r'\(|^[-\w.]+$|^\*', o[1]) and not re.fullmatch(r'%?r\d+|%?ap|%?fp|%?sp', o[1]):
                    return 'store'
                if '(' in o[0] or (not o[0].startswith(('$', '%')) and not re.fullmatch(r'r\d+', o[0])):
                    return 'load'
                return 'const' if o[0].startswith('$') else 'move'
            return 'const' if m.startswith('clr') else 'move'
        return 'alu'
    return 'alu'


def pclass(x):
    mn, ops = x.mn, x.ops
    if x.kind == 'call':
        return 'call'
    if x.kind == 'ret':
        return 'ret' if mn == 'ret' else 'cmpbr'
    if x.kind in ('br', 'cbr') or mn in ('cmp', 'bit', 'tst', 'fcmp', 'fcmp32'):
        return 'cmpbr'
    if mn in ('push', 'pop', 'pushm', 'popm', 'pushm8', 'popm8'):
        return 'frame'
    if mn in ('movzl', 'movzw', 'movzb', 'movl', 'movw', 'movb') and len(ops) == 2 and isreg(ops[0]) and isreg(ops[1]):
        return 'ext'
    if mn in MOVS and len(ops) == 2:
        if x.st:
            return 'store'
        if x.ld:
            return 'load'
        if ops[0].startswith(('#', '=')):
            return 'const'
        return 'move'
    if mn == 'clr':
        return 'const'
    if mn == 'lea' and len(ops) == 2 and '(' not in ops[0] and not isreg(ops[0]):
        return 'const'          # address of a symbol
    if mn == 'mcpy':
        return 'other'
    return 'alu'


def cmd_classes(a):
    os.makedirs(DATA, exist_ok=True)
    common, pd = common_files()
    sel = ['pdp64', 'amd64-gcc', 'amd64-clang', 'aarch64', 'riscv64gc', 'arm', 'ppc32', 'vax-gcc']
    cats = ['move', 'const', 'load', 'store', 'ext', 'alu', 'cmpbr', 'call', 'ret', 'frame', 'other']
    tab = {}
    for n in sel:
        cnt = collections.Counter()
        files = common if n != 'vax-gcc' else [x for x in common if os.path.exists('%s/%s/%s.s' % (OUT, n, x))]
        for sid in files:
            if n == 'pdp64':
                for fname, seq in pparse('%s/pdp64/%s.s' % (OUT, sid)):
                    for x in seq:
                        if x.kind != 'label':
                            cnt[pclass(x)] += 1
            else:
                fam = family(n)
                for x in parse('%s/%s/%s.s' % (OUT, n, sid), n):
                    if x[0] == 'i':
                        cnt[iclass(fam, x[1], x[2])] += 1
        tab[n] = cnt
    with open(DATA + '/archcmp-classes.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['arch'] + cats + ['total'])
        for n in sel:
            w.writerow([n] + [tab[n][c] for c in cats] + [sum(tab[n].values())])
    print('| class | ' + ' | '.join(sel) + ' |')
    print('|---|' + '---|' * len(sel))
    for c in cats + ['total']:
        print('| %s | ' % c + ' | '.join(str(sum(tab[n].values()) if c == 'total' else tab[n][c]) for n in sel) + ' |')


FEATURES = {
    # feature -> {family-prefix: (mnemonic regex, optional operand regex)}
    'load/store pair or multiple': {'aarch64': (r'^(ldp|stp|ldnp|stnp)$', None), 'arm': (r'^(ldm\w*|stm\w*|ldrd|strd|push|pop|vldm\w*|vstm\w*)$', None), 'ppc': (r'^(lmw|stmw)$', None),
                                   'systemz': (r'^(lmg|stmg|lm|stm)$', None), 'm68k': (r'^movem', None), 'sparc': (r'^(ldd|std|ldx2)$', None),
                                   'riscv64': (r'^$', None), 'mips64': (r'^$', None), 'amd64': (r'^$', None), 'loongarch64': (r'^$', None), 'vax': (r'^$', None)},
    'auto-increment / writeback access': {'aarch64': (r'^(ldr|str|ldp|stp)\w*$', r'\]!|\],\s*#'), 'arm': (r'^(ldr|str)\w*$', r'\]!|\],\s*[#r+-]'), 'ppc': (r'^(l|st)[bhwdf]\w*u(x)?$', None),
                                         'm68k': (r'^move', r'\)\+|-\('), 'vax': (r'^', r'\)\+|-\(r'), 'riscv64': (r'^$', None), 'mips64': (r'^$', None), 'amd64': (r'^$', None),
                                         'systemz': (r'^$', None), 'loongarch64': (r'^$', None), 'sparc': (r'^$', None)},
    'bit-field extract/insert': {'aarch64': (r'^(ubfx|sbfx|bfi|bfxil|ubfiz|sbfiz|bfc|bfm|ubfm|sbfm)$', None), 'arm': (r'^(ubfx|sbfx|bfi|bfc)$', None), 'ppc': (r'^(rlwinm|rlwimi|rldic\w*|rldimi|rlwnm|clrl\w+|clrr\w+|extr\w+|srwi|slwi|srdi|sldi|insrwi|extrwi)\.?$', None),
                                 'systemz': (r'^(risbg\w*|rnsbg|rosbg|rxsbg)$', None), 'm68k': (r'^bf', None), 'vax': (r'^(extv|extzv|insv|cmpv|cmpzv)$', None),
                                 'loongarch64': (r'^(bstrpick\.\w|bstrins\.\w)$', None), 'mips64': (r'^(ext|ins|dext|dextm|dextu|dins|dinsm|dinsu)$', None), 'riscv64': (r'^(bext|bexti|bclr\w*|bset\w*|binv\w*)$', None),
                                 'amd64': (r'^(bextr\w*|pext\w*|pdep\w*|bzhi\w*)$', None), 'sparc': (r'^$', None)},
    'conditional select/move/set': {'aarch64': (r'^(csel|csinc|csinv|csneg|cset|csetm|fcsel|ccmp|ccmn)$', None), 'arm': (r'^(mov|add|sub|and|orr|eor|rsb|mvn|ldr\w*|str\w*|bic|cmp|tst)(eq|ne|hs|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le)$', None),
                                    'amd64': (r'^(cmov\w+|set\w+)$', None), 'ppc': (r'^(isel|setb|iseleq|iselgt|isellt)$', None), 'systemz': (r'^(loc\w*|selgr|sel\w*|lochi\w*)$', None),
                                    'mips64': (r'^(movn|movz|movt|movf|slt\w*|sltu\w*)$', None), 'riscv64': (r'^(czero\.\w+|slt\w*|sltu\w*|seqz|snez|sltz|sgtz)$', None),
                                    'loongarch64': (r'^(maskeqz|masknez|slt\w*|sltu\w*|sltui|slti)$', None), 'sparc': (r'^(mov(e|ne|g|l|ge|le|gu|leu|cc|cs|pos|neg|vc|vs)|movr\w+|fmov\w+cc)$', None), 'm68k': (r'^s(ne|eq|lt|ge|gt|le|hi|ls|cc|cs|mi|pl|vc|vs)$', None), 'vax': (r'^$', None)},
    'test-bit-and-branch': {'aarch64': (r'^(tbz|tbnz)$', None), 'amd64': (r'^(bt|btl|btq|bts\w?|btr\w?|btc\w?)$', None), 'vax': (r'^(bbs\w*|bbc\w*|blbs|blbc)$', None), 'm68k': (r'^btst', None),
                            'systemz': (r'^(tm\w*)$', None), 'arm': (r'^(tst|tbb|tbh)(eq|ne)?$', None), 'ppc': (r'^$', None), 'riscv64': (r'^(bexti|bext)$', None), 'mips64': (r'^$', None), 'loongarch64': (r'^(bstrpick\.\w)$', None), 'sparc': (r'^$', None)},
    'counted-loop branch': {'ppc': (r'^(bdnz\w*|bdz\w*)$', None), 'm68k': (r'^(db\w+)$', None), 'vax': (r'^(sob\w+|aob\w+|acb\w+)$', None), 'systemz': (r'^(brct\w*|brx\w+|bct\w*|brxle\w*)$', None),
                            'amd64': (r'^(loop\w*)$', None), 'aarch64': (r'^$', None), 'arm': (r'^$', None), 'riscv64': (r'^$', None), 'mips64': (r'^$', None), 'loongarch64': (r'^$', None), 'sparc': (r'^$', None)},
    'shifted / scaled operand in ALU or address': {'aarch64': (r'^(add|sub|adds|subs|and|orr|eor|bic|orn|cmp|cmn|ldr|str|ldrb|strb|ldrh|strh|ldrsw|ldrsb|ldrsh|mvn|neg)$', r'(lsl|lsr|asr|ror|uxtw|sxtw|uxtb|uxth|sxtb|sxth) #?\d*\]?$'),
                                                   'arm': (r'^(add|sub|and|orr|eor|rsb|bic|cmp|mvn|mov|ldr|str|ldrb|strb|adds|subs)\w*$', r'(lsl|lsr|asr|ror) #\d+\]?$'), 'amd64': (r'^(lea\w*)$', r',\s*[248]\)'),
                                                   'riscv64': (r'^(sh[123]add\w*)$', None), 'loongarch64': (r'^(alsl\.\w+|ldx\.\w+|stx\.\w+)$', None), 'systemz': (r'^(la|lay|lg|llgc|llgh|stg|stc|sty|lgf|llgf|ag|sg)$', r'\(%r\d+,%r\d+\)|,\d*\(%r\d+,'), 'ppc': (r'^(lbzx|lhzx|lwzx|ldx|stbx|sthx|stwx|stdx|lbzux|lwzux|lhax|lwax)$', None),
                                                   'm68k': (r'^$', None), 'mips64': (r'^$', None), 'vax': (r'^$', r'\[r\d+\]'), 'sparc': (r'^$', None)},
    'multiply-add': {'aarch64': (r'^(madd|msub|smaddl|umaddl|smsubl|umsubl|mneg|smull|umull)$', None), 'arm': (r'^(mla|mls|smlal|umlal|smla\w+|umaal)\w*$', None), 'ppc': (r'^(maddld|maddhd\w*)$', None),
                     'systemz': (r'^(msg|msgr|maeb|madb|mlgr|ml)$', None), 'riscv64': (r'^$', None), 'amd64': (r'^$', None), 'mips64': (r'^(madd\w*|msub\w*|dmadd\w*)$', None), 'loongarch64': (r'^$', None), 'vax': (r'^$', None), 'sparc': (r'^$', None), 'm68k': (r'^$', None)},
    'carry chain (add/sub with carry)': {'aarch64': (r'^(adc|adcs|sbc|sbcs|ngc|ngcs)$', None), 'arm': (r'^(adc|adcs|sbc|sbcs|rsc|rscs)\w*$', None), 'amd64': (r'^(adc\w?|sbb\w?|adcx|adox)$', None),
                                         'ppc': (r'^(adde|addze|addc|addme|subfe|subfc|subfze|subfme)\.?$', None), 'systemz': (r'^(alcgr|slbgr|alc\w*|slb\w*|algr|slgr|alg|slg|alcr|slbr)$', None), 'sparc': (r'^(addx\w*|subx\w*|addc\w*|subc\w*)$', None),
                                         'm68k': (r'^(addx|subx|negx)\.?\w*$', None), 'vax': (r'^(adwc|sbwc)$', None), 'riscv64': (r'^$', None), 'mips64': (r'^$', None), 'loongarch64': (r'^$', None)},
    'high half of a multiply': {'aarch64': (r'^(umulh|smulh)$', None), 'arm': (r'^(umull|smull|umlal|smlal)\w*$', None), 'amd64': (r'^(mul\w?|imul\w?|mulx\w?)$', r'^[^,]*$'), 'ppc': (r'^(mulhd\w*|mulhw\w*|mulhdu|mulhwu)\.?$', None),
                                'systemz': (r'^(mlgr|mlg|mgrk|msgr)$', None), 'riscv64': (r'^(mulh|mulhu|mulhsu)$', None), 'loongarch64': (r'^(mulh\.\w+|mulh\.du|mulh\.d)$', None), 'mips64': (r'^(dmultu|dmult|mfhi|dmulhu|dmuh\w*|dmulu)$', None), 'sparc': (r'^(umul\w*|smul\w*|umulxhi|rdy)$', None), 'm68k': (r'^(mulu\.l|muls\.l)$', None), 'vax': (r'^(emul|emodd)$', None)},
    'immediate construction (extra instructions)': {'aarch64': (r'^(movz|movk|movn)$', None), 'arm': (r'^(movw|movt)$', None), 'riscv64': (r'^(lui)$', None), 'ppc': (r'^(lis|addis)$', None), 'mips64': (r'^(lui|ori|dsll|dsll32|lui)$', None), 'loongarch64': (r'^(lu12i\.w|lu32i\.d|lu52i\.d|ori|pcalau12i|pcaddu18i)$', None),
                                                    'sparc': (r'^(sethi|or)$', None), 'systemz': (r'^(llihf|iihf|llilf|iilf|llihh|llihl|iihh|iihl)$', None), 'amd64': (r'^$', None), 'm68k': (r'^$', None), 'vax': (r'^$', None)},
    'calls (all kinds)': {'amd64': (r'^call\w?$', None), 'aarch64': (r'^(bl|blr)$', None), 'arm': (r'^(bl|blx)\w*$', None), 'ppc': (r'^(bl|bctrl|blrl|bla)$', None), 'riscv64': (r'^(call|jal|jalr)$', r'^(ra|\.|ra,)'),
                          'mips64': (r'^(jal|jalr|bal)$', None), 'loongarch64': (r'^(bl|jirl)$', r'^(\$ra|\$r1)'), 'sparc': (r'^(call|jmpl)$', None), 'systemz': (r'^(brasl|basr|bras|bas)$', None), 'm68k': (r'^(jsr|bsr)\w*$', None), 'vax': (r'^(calls|callg|jsb|bsbw)$', None)},
}


def cmd_features(a):
    common, pd = common_files()
    sel = [n for n in archs_present() if n != 'pdp64']
    out = {}
    for n in sel:
        fam = family(n)
        files = common if n != 'vax-gcc' else [x for x in common if os.path.exists('%s/%s/%s.s' % (OUT, n, x))]
        pre = {k: v.get(fam if fam != 'amd64' or True else fam) for k, v in FEATURES.items()}
        if fam == 'i386':
            pre = {k: v.get('amd64') for k, v in FEATURES.items()}
        cnt = collections.Counter()
        for sid in files:
            for x in parse('%s/%s/%s.s' % (OUT, n, sid), n):
                if x[0] != 'i':
                    continue
                for k, spec in pre.items():
                    if spec and re.search(spec[0], x[1].lower()) and (spec[1] is None or re.search(spec[1], x[2])):
                        cnt[k] += 1
        out[n] = cnt
    with open(DATA + '/archcmp-features.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['feature'] + sel)
        for k in FEATURES:
            w.writerow([k] + [out[n][k] for n in sel])
    print('| feature | ' + ' | '.join(sel) + ' |')
    print('|---|' + '---|' * len(sel))
    for k in FEATURES:
        print('| %s | ' % k + ' | '.join(str(out[n][k]) for n in sel) + ' |')


def cmd_idioms(a):
    os.makedirs(DATA, exist_ok=True)
    common, pd = common_files()
    if os.environ.get('IDIOMS_ALL'):
        common = sorted(pd)
    random.seed(a.seed)
    for sid in common:
        run_detectors(sid, pparse('%s/pdp64/%s.s' % (OUT, sid)))
    tot = COUNTS['all']
    print('pdp64 instructions parsed: %d (pdp64size.py counts %d for the same files)' % (tot, sum(pd[s]['ins'] for s in common)))
    res = {}
    for k in sorted(COUNTS):
        if k.endswith('#ins'):
            continue
        res[k] = dict(sites=COUNTS[k], instructions_saved=COUNTS.get(k + '#ins', 0), bytes_saved=BYTES.get(k, 0))
    json.dump(res, open(DATA + '/archcmp-idioms.json', 'w'), indent=1, sort_keys=True)
    with open(DATA + '/archcmp-idioms.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['idiom', 'sites', 'instructions_saved', 'bytes_saved'])
        for k, v in res.items():
            w.writerow([k, v['sites'], v['instructions_saved'], v['bytes_saved']])
    os.makedirs(OUT + '/_run/samples', exist_ok=True)
    for name, lst in sorted(SAMPLES.items()):
        smp = random.sample(lst, min(15, len(lst)))
        with open(OUT + '/_run/samples/%s.txt' % re.sub(r'[^\w]+', '_', name)[:80], 'w') as o:
            o.write('%s: %d sites\n' % (name, len(lst)))
            for sid, f, lines, off, n in smp:
                o.write('---- %s %s\n' % (sid, f))
                for q, l in enumerate(lines):
                    o.write(('>> ' if off <= q < off + n else '   ') + l.strip() + '\n')
    for k, v in res.items():
        print('%-110s %7d  ins %6d  bytes %7d' % (k[:110], v['sites'], v['instructions_saved'], v['bytes_saved']))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['gen', 'table', 'classes', 'features', 'funcs', 'idioms', 'all'])
    ap.add_argument('--arch', default='')
    ap.add_argument('-j', type=int, default=2)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--seed', type=int, default=1)
    a = ap.parse_args()
    for c in (['gen', 'table', 'classes', 'features', 'funcs', 'idioms'] if a.cmd == 'all' else [a.cmd]):
        globals()['cmd_' + c](a)

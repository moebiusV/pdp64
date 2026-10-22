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
    """pdp64 image bytes per file id from the kept results of pdp64size (OUT/_run/pdp64/results.json)"""
    r = json.load(open(OUT + '/_run/pdp64/results.json'))
    return {x['src'].replace('/', '_'): x for x in r if 'ins' in x}


def archs_present():
    return [n for n in PRIMARY + ['pdp64'] if glob.glob('%s/%s/*.s' % (OUT, n))]


def cmd_table(a):
    os.makedirs(DATA, exist_ok=True)
    pd = pdp64_sizes()
    names = [n for n in archs_present() if n != 'pdp64']
    ok = {}   # name -> {sid: (ins, bytes)}
    parsed = {}
    for n in names:
        ok[n] = {}
        for sid, f in sid_list(n).items():
            b = load_size(n, sid)
            if sid in pd:
                ok[n][sid] = (f, b)
    ref = ['amd64-clang', 'amd64-gcc', 'aarch64', 'riscv64gc']
    common = set(pd)
    for n in names:
        if n in ('vax-gcc',):
            continue
        common &= set(ok[n])
    sys.stderr.write('files accepted by all selected compilers: %d (pdp64: %d)\n' % (len(common), len(pd)))
    rows = []
    mn_tab = {}
    for n in names + ['pdp64']:
        tot_i = tot_b = 0
        mn = collections.Counter()
        nb_missing = 0
        files = common
        items_all = []
        for sid in sorted(files):
            if n == 'pdp64':
                f = '%s/pdp64/%s.s' % (OUT, sid)
                tot_b += pd[sid]['image']
            else:
                f = ok[n][sid][0]
                b = ok[n][sid][1]
                if b is None or b < 0:
                    nb_missing += 1
                else:
                    tot_b += b
            it = parse(f, n)
            ins = [x for x in it if x[0] == 'i']
            tot_i += len(ins)
            mn.update(x[1] for x in ins)
        nf = norm_factory(n, mn.keys())
        nm = collections.Counter()
        for k, v in mn.items():
            nm[nf(k)] += v
        mn_tab[n] = nm
        rows.append(dict(arch=n, files=len(files), ins=tot_i, bytes=tot_b, bytes_missing=nb_missing, mn=nm))
    pdi = next(r for r in rows if r['arch'] == 'pdp64')
    with open(DATA + '/archcmp-totals.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['arch', 'files', 'instructions', 'bytes', 'files_without_size', 'ins_per_pdp64', 'bytes_per_pdp64', 'bytes_per_ins'])
        for r in rows:
            w.writerow([r['arch'], r['files'], r['ins'], r['bytes'], r['bytes_missing'], '%.3f' % (r['ins'] / pdi['ins']),
                        '%.3f' % (r['bytes'] / pdi['bytes']), '%.2f' % (r['bytes'] / r['ins'])])
    with open(DATA + '/archcmp-mnemonics.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['arch', 'mnemonic', 'count', 'share'])
        for r in rows:
            tot = sum(r['mn'].values())
            for m, v in r['mn'].most_common(60):
                w.writerow([r['arch'], m, v, '%.4f' % (v / tot)])
    json.dump({'common': sorted(common)}, open(DATA + '/archcmp-commonfiles.json', 'w'))
    print('| arch | files | instructions | bytes (text+data) | ins / pdp64 | bytes / pdp64 | bytes per ins |')
    print('|---|---|---|---|---|---|---|')
    for r in sorted(rows, key=lambda r: r['ins']):
        print('| %s | %d | %d | %d | %.3f | %.3f | %.2f |' % (r['arch'], r['files'], r['ins'], r['bytes'], r['ins'] / pdi['ins'], r['bytes'] / pdi['bytes'], r['bytes'] / r['ins']))
    print()
    for r in rows:
        tot = sum(r['mn'].values())
        print('### %s' % r['arch'])
        print(', '.join('%s %.1f%%' % (m, 100 * v / tot) for m, v in r['mn'].most_common(25)))
        print()


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['gen', 'table', 'funcs', 'idioms', 'all'])
    ap.add_argument('--arch', default='')
    ap.add_argument('-j', type=int, default=2)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--seed', type=int, default=1)
    a = ap.parse_args()
    for c in (['gen', 'table', 'funcs', 'idioms'] if a.cmd == 'all' else [a.cmd]):
        globals()['cmd_' + c](a)

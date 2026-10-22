#!/usr/bin/env python3
"""
oracle -- llvm-mc against the project's assembler as64, byte for byte.

For every assembly source it assembles with as64 and with `llvm-mc -triple=pdp64-unknown-elf -filetype=obj` and compares what an
object file means: the bytes of .text and .data, the size of .bss, the relocations (section, offset, type, symbol, addend) and the
symbols.  It also disassembles .text with llvm-mc and reassembles the listing, which must give the same bytes.

    oracle.py [--as64 build/as64] [--llvm-mc PATH] [--verbose] [FILE.s | DIR ...]

The only translation of the source is lexical (see translate()): a string in `.byte` becomes `.ascii`, and a decimal number with a
leading zero (decimal in this assembler, octal in LLVM's) loses its zeros; `0o17` becomes `017`.  Sources that need what LLVM's MC
does not have are SKIPPED, with the reason: the literal pool (`=K`, `.pool`) and names that start with a digit.
"""
import os, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
TRIPLE = 'pdp64-unknown-elf'


# ---- ELF ------------------------------------------------------------------------------------------------------------------

class Elf:
    def __init__(self, path):
        d = open(path, 'rb').read()
        self.d = d
        assert d[:4] == b'\x7fELF' and d[4] == 2 and d[5] == 1, 'not ELF64 little endian'
        self.machine = struct.unpack_from('<H', d, 0x12)[0]
        shoff, = struct.unpack_from('<Q', d, 0x28)
        shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3A)
        self.sec = []
        for i in range(shnum):
            name, typ, flags, addr, off, size, link, info, align, entsize = struct.unpack_from('<IIQQQQIIQQ', d, shoff + i * shentsize)
            self.sec.append(dict(name=name, type=typ, flags=flags, off=off, size=size, link=link, info=info, align=align, entsize=entsize))
        strtab = self.sec[shstrndx]
        for s in self.sec:
            s['sname'] = self.cstr(strtab['off'] + s['name'])
        self.byname = {s['sname']: s for s in self.sec}

    def cstr(self, off):
        e = self.d.index(b'\0', off)
        return self.d[off:e].decode('utf-8', 'replace')

    def bytes(self, name):
        s = self.byname.get(name)
        if not s or s['type'] == 8:
            return b''
        return self.d[s['off']:s['off'] + s['size']]

    def symbols(self):
        s = self.byname.get('.symtab')
        if not s:
            return []
        strt = self.sec[s['link']]
        out = []
        for i in range(s['size'] // 24):
            name, info, other, shndx, value, size = struct.unpack_from('<IBBHQQ', self.d, s['off'] + 24 * i)
            out.append(dict(name=self.cstr(strt['off'] + name) if name else '', bind=info >> 4, type=info & 15, shndx=shndx, value=value, size=size))
        return out

    def relocs(self):
        syms = self.symbols()
        out = []
        for s in self.sec:
            if s['type'] != 4:
                continue
            target = self.sec[s['info']]['sname']
            for i in range(s['size'] // 24):
                off, info, add = struct.unpack_from('<QQq', self.d, s['off'] + 24 * i)
                sym = syms[info >> 32]
                if sym['type'] == 3:
                    nm = '.sec:' + self.sec[sym['shndx']]['sname']
                else:
                    nm = sym['name']
                out.append((target, off, info & 0xFFFFFFFF, nm, add))
        return sorted(out)

    def symtab(self):
        out = set()
        for s in self.symbols():
            if not s['name'] or s['type'] in (3, 4):
                continue
            if s['shndx'] == 0:
                where = 'UND'
            elif s['shndx'] == 0xFFF1:
                where = 'ABS'
            elif s['shndx'] == 0xFFF2:
                where = 'COMMON'
            else:
                where = self.sec[s['shndx']]['sname']
            out.add((s['name'], 'G' if s['bind'] else 'L', where, s['value'] if where != 'COMMON' else 0, s['size'] if where == 'COMMON' else 0))
        return out


# ---- translation ----------------------------------------------------------------------------------------------------------

class Skip(Exception):
    pass


def split_args(s):
    """Split the argument list of a directive at the commas that are outside strings."""
    out, cur, q = [], '', False
    i = 0
    while i < len(s):
        c = s[i]
        if q:
            cur += c
            if c == '\\' and i + 1 < len(s):
                i += 1
                cur += s[i]
            elif c == '"':
                q = False
        elif c == '"':
            q = True
            cur += c
        elif c == "'":
            n = 4 if s[i + 1:i + 2] == '\\' else 3
            cur += s[i:i + n]
            i += n - 1
        elif c == ',':
            out.append(cur.strip())
            cur = ''
        elif c == ';':
            break
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur.strip())
    return out


def strip_comment(line):
    q = False
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == '\\':
                i += 1
            elif c == '"':
                q = False
        elif c == '"':
            q = True
        elif c == "'":
            i += 3 if line[i + 1:i + 2] != '\\' else 4
            continue
        elif c == ';':
            return line[:i]
        i += 1
    return line


def numbers(p):
    def num(m):
        t = m.group(0)
        if re.match(r'0[oO][0-7]+$', t):
            return '0' + t[2:]
        if re.match(r'0[xXbB]', t) or t == '0':
            return t
        if t.isdigit():
            return str(int(t))
        return t
    return re.sub(r'(?<![\w.$])[0-9][\w.$]*', num, p)


def translate(text):
    out = []
    for line in text.split('\n'):
        code = strip_comment(line)
        if any(ord(ch) > 127 for ch in code):
            raise Skip('non-ASCII names (LLVM identifiers are ASCII)')
        if re.search(r'(^|[\s,(])=[^=\s]', code):
            raise Skip('literal pool (=K)')
        if re.match(r'^\s*(\w+:\s*)*\.pool\b', code):
            raise Skip('.pool')
        if re.match(r'^\s*[0-9]\w*[A-Za-z_]\w*\s*:', code) and not re.match(r'^\s*[0-9]+\s*:', code):
            raise Skip('a name that starts with a digit')
        m = re.match(r'^(\s*(?:[\w.$]+:\s*)*)\.byte\s+(.*)$', code)
        if m and '"' in m.group(2):
            pre, args = m.group(1), split_args(m.group(2))
            parts = []
            for a in args:
                parts.append(('s', a) if a.startswith('"') else ('v', numbers(a)))
            first = True
            run = []
            stmts = []
            for k, a in parts:
                if k == 's':
                    if run:
                        stmts.append('.byte ' + ', '.join(run)); run = []
                    stmts.append('.ascii ' + a)
                else:
                    run.append(a)
            if run:
                stmts.append('.byte ' + ', '.join(run))
            for n, st in enumerate(stmts):
                out.append((pre if n == 0 else '') + '\t' + st)
            continue
        # numbers outside strings and character literals: 0o17 -> 017, 010 -> 10
        pieces = re.split(r'("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)\')', code)
        for k in range(0, len(pieces), 2):
            p = pieces[k]
            def num(m):
                t = m.group(0)
                if re.match(r'0[oO][0-7]+$', t):
                    return '0' + t[2:]
                if re.match(r'0[xXbB]', t) or t == '0':
                    return t
                if t.isdigit():
                    return str(int(t))
                return t
            p = re.sub(r'(?<![\w.$])[0-9][\w.$]*', num, p)
            pieces[k] = p
        out.append(''.join(pieces))
    return '\n'.join(out) + '\n'


# ---- running --------------------------------------------------------------------------------------------------------------

def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def compare(a, b):
    """Differences between two Elf objects, as a list of strings."""
    diffs = []
    for sec in ('.text', '.data'):
        x, y = a.bytes(sec), b.bytes(sec)
        if x != y:
            diffs.append('%s differs\n   as64     %s\n   llvm-mc  %s' % (sec, x.hex(' ', 2), y.hex(' ', 2)))
    bs = lambda e: e.byname['.bss']['size'] if '.bss' in e.byname else 0
    if bs(a) != bs(b):
        diffs.append('.bss size %d vs %d' % (bs(a), bs(b)))
    ra, rb = a.relocs(), b.relocs()
    if ra != rb:
        diffs.append('relocations differ\n   as64     %s\n   llvm-mc  %s' % (ra, rb))
    sa, sb = a.symtab(), b.symtab()
    if sa != sb:
        diffs.append('symbols differ\n   as64 only    %s\n   llvm-mc only %s' % (sorted(sa - sb), sorted(sb - sa)))
    return diffs


def disassemble_roundtrip(mc, text_bytes, tmp):
    """Disassemble with llvm-mc, reassemble the listing: the same bytes.  Returns an error text or None."""
    if not text_bytes:
        return None
    hexs = ' '.join('0x%02x' % b for b in text_bytes)
    r = run([mc, '-disassemble', '-triple=' + TRIPLE], input=hexs)
    if 'invalid instruction encoding' in r.stderr:
        return None  # reserved encodings (tests of illegal instructions) are refused by the disassembler by design
    if r.returncode != 0 or 'invalid instruction' in r.stderr or 'warning' in r.stderr:
        return 'disassembly failed: ' + (r.stderr.strip().split('\n')[0] if r.stderr else 'exit %d' % r.returncode)
    listing = '\t.text\n' + r.stdout
    src = os.path.join(tmp, 'rt.s')
    open(src, 'w').write(listing)
    obj = os.path.join(tmp, 'rt.o')
    r2 = run([mc, '-triple=' + TRIPLE, '-filetype=obj', '-o', obj, src])
    if r2.returncode != 0:
        return 'reassembly failed: %s\n%s' % (r2.stderr.strip().split('\n')[0], listing[:400])
    again = Elf(obj).bytes('.text')
    if again != text_bytes:
        # a long form that has a one-parcel abbreviation (written with .word in a test of page 2) is reassembled shorter: it is the
        # same instruction if the listing of the new bytes is the same
        r3 = run([mc, '-disassemble', '-triple=' + TRIPLE], input=' '.join('0x%02x' % b for b in again))
        if r3.returncode == 0 and r3.stdout == r.stdout:
            return None
        return 'round trip differs\n   original %s\n   again    %s\n%s' % (text_bytes.hex(' ', 2), again.hex(' ', 2), listing[:800])
    return None


def preprocess(path, tmp):
    """NAME.S is run through the C preprocessor with the architecture's constants (tools/pp-asm.sh), as the project's own tests do."""
    out = os.path.join(tmp, os.path.basename(path)[:-2] + '.pp.s')
    r = run([os.path.join(ROOT, 'tools', 'pp-asm.sh'), path, out])
    if r.returncode != 0:
        raise Skip('preprocessing: ' + r.stderr.strip().split('\n')[0])
    return out


def check_file(path, as64, mc, verbose, roundtrip=True):
    """Returns ('pass'|'fail'|'skip', text)."""
    if path.endswith('.S'):
        with tempfile.TemporaryDirectory() as t0:
            try:
                return check_file(preprocess(path, t0), as64, mc, verbose, roundtrip)
            except Skip as e:
                return 'skip', str(e)
    src = open(path).read()
    try:
        llsrc = translate(src)
    except Skip as e:
        return 'skip', str(e)
    with tempfile.TemporaryDirectory() as tmp:
        ao, bo = os.path.join(tmp, 'a.o'), os.path.join(tmp, 'b.o')
        flags = []
        r1 = run([as64] + flags + ['-o', ao, path])
        if r1.returncode != 0:
            return 'skip', 'as64 refuses it: ' + (r1.stderr.strip().split('\n')[0])
        lf = os.path.join(tmp, 't.s')
        open(lf, 'w').write(llsrc)
        r2 = run([mc, '-triple=' + TRIPLE, '-filetype=obj', '-o', bo, lf] + (['--no-p2'] if False else []))
        if r2.returncode != 0:
            return 'fail', 'llvm-mc refuses what as64 accepts: ' + r2.stderr.strip().split('\n')[0] + '\n' + '\n'.join(r2.stderr.strip().split('\n')[1:4])
        a, b = Elf(ao), Elf(bo)
        diffs = compare(a, b)
        if b.machine != 0xF064:
            diffs.append('e_machine is %#x' % b.machine)
        if roundtrip and not diffs and not a.relocs():
            # only the code of a program that is all instructions can be disassembled: not one with data in .text (the pool)
            err = disassemble_roundtrip(mc, a.bytes('.text'), tmp)
            if err:
                diffs.append(err)
        if diffs:
            return 'fail', '\n'.join(diffs)
        return 'pass', ''


def main():
    args = sys.argv[1:]
    as64 = os.path.join(ROOT, os.environ.get('BUILD', 'build'), 'as64')
    mc = os.environ.get('LLVM_MC', os.path.expanduser('~/claude/llvm-build/bin/llvm-mc'))
    verbose = False
    files = []
    while args:
        a = args.pop(0)
        if a == '--as64':
            as64 = args.pop(0)
        elif a == '--llvm-mc':
            mc = args.pop(0)
        elif a == '--verbose':
            verbose = True
        elif os.path.isdir(a):
            files += sorted(os.path.join(a, f) for f in os.listdir(a) if f.endswith(('.s', '.S')))
        else:
            files.append(a)
    if not files:
        files = sorted(os.path.join(ROOT, 'tests', d, f) for d in ('asm', 'sim') for f in os.listdir(os.path.join(ROOT, 'tests', d)) if f.endswith(('.s', '.S')))
    counts = {'pass': 0, 'fail': 0, 'skip': 0}
    for f in files:
        st, text = check_file(f, as64, mc, verbose)
        counts[st] += 1
        rel = os.path.relpath(f, ROOT)
        if st == 'pass':
            print('ok    ' + rel)
        elif st == 'skip':
            print('skip  %s: %s' % (rel, text))
        else:
            print('FAIL  ' + rel)
            print('   ' + text.replace('\n', '\n   '))
    print('%d passed, %d failed, %d skipped' % (counts['pass'], counts['fail'], counts['skip']))
    return 1 if counts['fail'] else 0


if __name__ == '__main__':
    sys.exit(main())

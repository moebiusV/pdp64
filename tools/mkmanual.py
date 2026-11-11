#!/usr/bin/env python3
"""Generate the instruction dictionary of the manual (docs/manual/dictionary/).

Every number comes from spec/pdp64-mnemonics.hbnf, the one place the architecture's numbers are written, so the dictionary
cannot drift from the assembler and the simulators; the words (operation, flags, exceptions) are in tools/manual/isa_entries.py.
Whether an instruction is implemented in the reference executor is read from common/pdp64exec.c.

    tools/mkmanual.py                  write the manual of the pdp64 into docs/manual/: the hand-written text of docs/manual-src/ (tools/manual/assemble.py),
                                       the instruction entries, the dictionary and the figures; the bit layouts are read from the grammar of the encoding
    tools/mkmanual.py --check          exit 1 if a mnemonic has no entry, an entry names a mnemonic that does not exist, a committed file differs, a section
                                       or statement number is not contiguous, or a link or a section reference has no target
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'manual'))
import isa_entries as D
import assemble as ASM
import memberprose as MP
import isa_enc as ENCPROSE

MANUAL = os.path.join(ROOT, 'docs', 'manual')             # the manual of the pdp64
SRCDIR = os.path.join(ROOT, 'docs', 'manual-src')         # the hand-written text, once (docs/manual-src/README.md)
HBNF = os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf')
EXEC = os.path.join(ROOT, 'common', 'pdp64exec.c')


def num(s):
    return int(s, 0)


def parse_spec(path=None):
    t = open(path or HBNF).read()
    groups = {}
    for g, body in re.findall(r'(?m)^([a-z0-9-]+)\s*=(.*?)(?=^\S|\Z)', t, re.S):
        body = re.sub(r';[^\n]*', '', body)
        groups[g] = [(m, num(n)) for m, n in re.findall(r'"([A-Za-z0-9_.#]+)"@(\S+)', body)]
    return groups


SPEC = parse_spec()
SYS = parse_spec(os.path.join(ROOT, 'spec', 'pdp64-system.hbnf'))
OPGROUP = dict(SPEC['opgroup'])                    # lea 0x0B, besc 0x0C ... sob 0x3F
# mnemonic group -> (spec group, kind). The kind selects the encoding diagram.
KIND = {'mn-ext': 'ext', 'mn-mov': 'mem', 'mn-movz': 'mem', 'mn-lea': 'mem', 'mn-alu': 'mem', 'mn-branch': 'br', 'mn-cbranch': 'cb',
        'mn-sob': 'sob', 'mn-tag': 'tag', 'mn-sop': 'sop', 'mn-xfer': 'xfer', 'mn-besc': 'besc', 'mn-mblk': 'mblk',
        'mn-aesc': 'aesc', 'mn-fesc': 'fesc', 'mn-atom': 'atom', 'mn-mesc': 'mesc', 'mn-sys-none': 'sysn',
        'mn-sysx': 'sysx', 'mn-sysreg': 'sysreg', 'mn-sys': 'sys', 'subop': 'aesc'}
GROUPNAME = {'ext': 'Added by the prefix-coded encoding', 'mem': 'Moves, address formation and the ALU', 'br': 'Branches', 'cb': 'Branches', 'sob': 'Branches',
             'tag': 'Branches', 'sop': 'Single operand (SOP)', 'xfer': 'Indirect transfers (XFER)', 'besc': 'Bits and fields (BESC)',
             'mblk': 'Block memory (MBLK)', 'aesc': 'Arithmetic (AESC)', 'fesc': 'Floating point (FESC)',
             'atom': 'Atomics (ATOM)', 'mesc': 'Memory escape (MESC)', 'sysn': 'System (SYS)', 'sysx': 'System (SYS)',
             'sysreg': 'System (SYS)', 'sys': 'System (SYS)'}
ESC_OPC = {'besc': 'besc', 'mblk': 'mblk', 'aesc': 'aesc', 'mesc': 'mesc', 'fesc': 'fesc', 'atom': 'atom', 'xfer': 'xfer',
           'sop': 'sop', 'sys': 'sys', 'sysn': 'sys', 'sysx': 'sys', 'sysreg': 'sys', 'tag': 'tag', 'sob': 'sob'}


def mnemonics():
    """name -> dict(group, kind, value, alias_of)"""
    out = {}
    for g, items in SPEC.items():
        if g not in KIND:
            continue
        base = {m: v for m, v in items}
        for m, v in items:
            alias = None
            if v >= 0x100:
                tgt = [k for k, x in items if x == v - 0x100]
                alias = tgt[0] if tgt else None
            out[m] = dict(group=g, kind=KIND[g], value=v, alias_of=alias)
    return out


MN_BASE = mnemonics()                               # the words of spec/pdp64-mnemonics.hbnf
MN = MN_BASE                                        # the words of the manual (build() sets it)
CH = None                                           # its charts (class Charts)
EXECTEXT = open(EXEC).read()
EXECENC = open(os.path.join(ROOT, 'common', 'pdp64exec_enc.inc')).read()
ENC_IMPL = set(re.findall(r'\{ "([a-z0-9_.]+)", H_(?!UNIMPL)', EXECENC))       # the words the prefix-coded front end of the executor has a case for


def manual_mn():
    """The words of the manual: those of spec/pdp64-mnemonics.hbnf and the words of group mn-ext, from the grammar of the encoding."""
    mn = dict(MN_BASE)
    for i, w in enumerate(LAY.enc().d['ext']):
        mn[w] = dict(group='mn-ext', kind='ext', value=i, alias_of=None)
    return mn


def implemented(name):
    """Does the reference executor have a case for this mnemonic?"""
    return name in ENC_IMPL


def bits(v, w):
    return format(v, '0%db' % w)


FIGS = {}                                     # file name -> svg text (build() resets it)
import layouts as LAY
import busfigs as BUSFIGS
import gfxfigs as GFXFIGS
import kernfigs as KERNFIGS
import bootfigs as BOOTFIGS
import drvfigs as DRVFIGS
import introfigs as INTROFIGS
import vecfigs as VECFIGS
import smpfigs as SMPFIGS


def fig(name, alt, rows):
    """Record a figure and return the Markdown that shows it."""
    FIGS[name + '.svg'] = LAY.svg_rows(rows)
    return '![%s](figures/%s.svg)' % (alt, name)


def opcode_of(name):
    m = MN[name]
    k = m['kind']
    v = m['value']
    if k == 'mem':
        if m['group'] == 'mn-lea':
            return OPGROUP['lea'], None
        return v, None
    if k == 'br':
        return v, None
    if k == 'cb':
        return OPGROUP['cbr'], v
    return OPGROUP[ESC_OPC[k]], v


# ---------------------------------------------------------------- the charts
class Charts:
    """The bit-layout charts, from the grammar of the encoding (tools/manual/layouts.py): charts (a list of dicts, see layouts.py), byname (mnemonic -> [(chart id, chart)])."""

    def __init__(self):
        self.enc = LAY.enc()
        self.charts = self.enc.charts
        self.byname = {n: [(cid, ch) for cid, ch, _ in v] for n, v in self.enc.byname.items()}
        self.byid = {c['id']: c for c in self.charts}


def wslug(name):
    return re.sub(r'[^a-z0-9]', '-', name)


WORDCH = {}                                   # word -> [(caption, rows, bytes)], one SVG each: figures/w/WORD/NN.svg


def chart_files(CH):
    for ch in CH.charts:
        FIGS[ch['id'] + '.svg'] = LAY.svg_rows(ch['rows'])
    # a chart for every instruction word, with its own fixed bits (aliases have the chart of the word they stand for): one SVG for each word, the charts of its forms one under the other
    WORDCH.clear()
    slugs = {}
    for n, m in MN.items():
        if m['alias_of']:
            continue
        items = CH.enc.word_charts(n)
        if not items:
            raise SystemExit('the word %s has no layout in the grammar' % n)
        if wslug(n) in slugs:
            raise SystemExit('the words %s and %s have the same file name' % (n, slugs[wslug(n)]))
        slugs[wslug(n)] = n
        WORDCH[n] = items
        for k, (cap, rows, nb) in enumerate(items, 1):
            FIGS['w/%s/%02d.svg' % (wslug(n), k)] = LAY.svg_stack([(cap, rows)])


def encoding(entry):
    """The Encoding part of an entry: the chart of the first (shortest) layout of its first instruction and the list of all layouts, which are in the dictionary page by-encoding.md."""
    names = [n for n in entry['names'] if not MN[n]['alias_of']]
    L = []
    cs = []
    for n in names:
        for cid, ch in CH.byname.get(n, []):
            if cid not in [c for c, _ in cs]:
                cs.append((cid, ch))
    if not cs:
        raise SystemExit('entry %s: no bit layout in the grammar' % entry['id'])
    first = cs[0][0]
    L.append('![Encoding of %s](figures/%s.svg)' % (entry['id'], first))
    FIGS.setdefault(first + '.svg', LAY.svg_rows(CH.byid[first]['rows']))
    ch = CH.byid[first]
    L.append('The chart is the leaf `%s`, %s. ' % (first, ch['title']) + ' '.join(ch['legend']))
    links = ', '.join('[`%s`](dictionary/by-encoding.md#%s)' % (cid, cid) for cid, _ in cs)
    L.append('**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): %s.' % links)
    return '\n\n'.join(L)


def sysreg_table():
    ro = {n for n, _ in SPEC['sysreg-ro']}
    rows = ['| Name | Number | Access |', '|---|---|---|']
    for n, v in SPEC['sysreg']:
        rows.append('| `%s` | %d | %s |' % (n.upper(), v, 'read only' if n in ro else 'read and write'))
    return '\n'.join(rows)


def length_note(entry):
    return entry.get('lengths', '')


def B(v, w):
    return format(v, '0%db' % w)


def BH(v, w):
    """A value in binary with its hexadecimal value in brackets behind it."""
    return '%s (0x%0*X)' % (B(v, w), (w + 3) // 4, v)


def uni(t):
    """Pseudocode in Unicode: assignment, comparison and arithmetic use their proper characters, not ASCII spellings."""
    t = t.replace('<-', '\u2190').replace('!=', '\u2260').replace('>=', '\u2265').replace('<=', '\u2264').replace('==', '=')
    t = re.sub(r'(?<=[A-Za-z0-9)\]]) \* (?=[A-Za-z0-9(\-])', ' \u00d7 ', t)
    t = re.sub(r'(?<=[A-Za-z0-9)\]])\*(?=[A-Za-z0-9(])', '\u00d7', t)
    t = re.sub(r'(?<=[A-Za-z0-9)\]]) / (?=[A-Za-z0-9(\-])', ' \u00f7 ', t)
    return t


DROPPED = {}                                  # entry id -> sentences of the text written for the original encoding that are left out


def prose(e, field):
    """The text of a field of an entry"""
    t = e.get(field) if field != 'story' else D.STORY.get(e['id'], '')
    if e.get('only') or not t:
        return t
    over = {'notes': ENCPROSE.NOTES, 'exc': ENCPROSE.EXC, 'story': ENCPROSE.STORY}.get(field, {})
    if e['id'] in over:
        return over[e['id']]
    dr = []
    t = MP.for_enc(t, dr)
    for x in dr:
        if x not in DROPPED.setdefault(e['id'], []):
            DROPPED[e['id']].append(x)
    return t


def forms_block(name):
    """every layout form of one word, each as a chart of its own (one SVG for each form, in the order of the grammar, grouped by length in bytes)"""
    items = WORDCH[name]
    out = []
    for k, (cap, rows, nb) in sorted(enumerate(items, 1), key=lambda t: -t[1][2]):
        out += ['![%s](figures/w/%s/%02d.svg)' % (cap.replace(']', ')').replace('[', '('), wslug(name), k), '']
    return out


def words_section(e, real):
    """The layout forms of the mnemonics of an entry: an entry of one mnemonic shows them in place; an entry of several gives each mnemonic its own sub-entry (its syntax, its numbers, its forms) after the shared text, and each alias a line"""
    names = e['names']
    out = []
    if len(real) == 1:
        for a in names:
            if MN[a]['alias_of']:
                out += ['<a id="w-%s"></a>' % wslug(a), '**`%s`** is an alias of `%s`: the assembler writes it as that word.' % (a.upper(), MN[a]['alias_of'].upper()), '']
        return out
    for n in names:
        out.append('<a id="w-%s"></a>' % wslug(n))
        if MN[n]['alias_of']:
            out += ['#### %s' % n.upper(), '', 'An alias of [`%s`](#w-%s): the assembler writes it as that word.' % (MN[n]['alias_of'].upper(), wslug(MN[n]['alias_of'])), '']
            continue
        syn = [l.split(';')[0].rstrip() for l in e['syntax'] if re.match(r'\s*%s\b' % re.escape(n.upper()), l)]
        out += ['#### %s' % n.upper(), ''] + forms_block(n)
        if syn:
            out += ['```', uni('\n'.join(syn)), '```', '']
        out += ['Operation, flags and exceptions as for the entry %s above; %d layout form%s, each a chart of its own (above).' % (e['id'], len(WORDCH[n]), '' if len(WORDCH[n]) == 1 else 's'), '']
    return out


def render_entry(e):
    names = e['names']
    real = [n for n in names if not MN[n]['alias_of']]
    heads = ', '.join('`%s`' % n.upper().rstrip('_').replace('XOR_', 'XOR_') for n in names if not MN[n]['alias_of'])
    out = []
    if len(real) == 1 or e.get('alias'):
        out += ['<a id="w-%s"></a>' % wslug(n) for n in names]
    out += ['### %s: %s' % (e['id'], e['title']), '']
    if len(real) == 1 and not e.get('alias'):
        out += forms_block(real[0])
    out.append('**Mnemonics:** ' + heads + (('  (aliases: ' + ', '.join('`%s`' % n.upper() for n in names if MN[n]['alias_of']) + ')') if any(MN[n]['alias_of'] for n in names) else ''))
    out.append('')
    if e.get('alias'):
        out.append('**Alias** *(D)* ' + e['alias'])
        out.append('')
    out.append('**Syntax**\n')
    out.append('```\n' + uni('\n'.join(e['syntax'])) + '\n```')
    out.append('')
    if e.get('alias'):
        out.append('**Encoding** None of its own: the assembler expands an alias into other instructions. Open: the expansion ([J.9.1](appendix-j-open.md#j91)).')
    else:
        out.append('**Encoding**\n')
        out.append(encoding(e))
    out.append('')
    out.append('**Operation**\n')
    out.append('```\n' + uni(e['op'].strip('\n')) + '\n```')
    out.append('')
    out.append('**Flags** ' + e['flags'])
    out.append('')
    out.append('**Exceptions** ' + prose(e, 'exc'))
    out.append('')
    if prose(e, 'notes'):
        out.append(prose(e, 'notes').replace('{{SYSREGS}}', sysreg_table()))
        out.append('')
    if prose(e, 'story'):
        out.append('**Why it is here.** ' + prose(e, 'story'))
        out.append('')
    if e.get('cf'):
        out.append('**Cf.** ' + e['cf'])
        out.append('')
    if not e.get('alias'):
        out += words_section(e, real)
    return '\n'.join(out)


def page_for(e):
    return e['page']



VEC = {'reset': 'processor reset: the first instruction fetch', 'machine-check': 'an unrecoverable error (a posted write that timed out, an uncorrectable memory error, a failed vector fetch); not restartable',
       'illegal': 'a reserved or undefined opcode, a reserved encoding or an unassigned system register', 'privileged': 'a system instruction executed outside kernel mode',
       'misaligned': 'a data access whose address is not a multiple of its size (the `MOVU` forms excepted)', 'noncanonical': 'a virtual address whose bits 63 to 39 differ from bit 38',
       'ifault': 'instruction fetch from a page that is not mapped', 'lfault': 'load from a page that is not mapped', 'sfault': 'store to a page that is not mapped',
       'iprot': 'instruction fetch denied by the page permissions', 'lprot': 'load denied by the page permissions', 'sprot': 'store denied by the page permissions',
       'divzero': 'division by zero (`DIV`, `DIVU`, `MOD`, `MODU`)', 'busfault': 'a read of non-existent memory (a precise abort)', 'lpad': 'an indirect transfer that did not land on `LPAD` (enforcement off in ABI version 1)',
       'bpt': 'the `BPT` instruction', 'irq-base': 'the first interrupt vector', 'timer': 'the timer interrupt (level 6)', 'console-in': 'console receive interrupt (level 4)',
       'console-out': 'console transmit interrupt (level 4)', 'trap-base': '`TRAP #n` and `TRAPL #n` enter vector 256 + n', 'count': 'the number of vectors; the table has this many eight-byte entries'}
PSWD = {'c': 'carry (borrow after a subtract)', 'v': 'signed overflow', 'z': 'zero', 'n': 'negative', 't': 'trace: take a trace trap after the next instruction', 'pri': 'interrupt priority level, 0 to 7', 'mode': 'current mode', 'prev': 'previous mode (the mode before the last exception)'}
PTED = {'v': 'valid', 'r': 'readable', 'w': 'writable', 'x': 'executable', 'u': 'accessible from user mode', 'g': 'global: ignores the ASID', 'a': 'accessed (managed by software)', 'd': 'dirty (managed by software)', 'mt': 'memory type', 'ppn': 'physical page number: physical address bits 12 to 39, in place'}


def constants_page():
    w = dict(SYS['psw-width'])
    L = ['# Appendix: the architectural constants', '', '[← dictionary index](index.md)', '',
         'The numbers of the processor status word, the modes, the exception vectors, the page-table entry, the memory types, the translation geometry, the system registers, the addressing modes and the condition codes, each read from the machine-readable specification (`spec/pdp64-system.hbnf` and `spec/pdp64-mnemonics.hbnf`).', '',
         '*Generated by `tools/mkmanual.py`; do not edit.*', '', '## The processor status word (16 bits)', '', '| Field | Bit | Width | Meaning |', '|---|---|---|---|']
    for n, v in SYS['psw']:
        L.append('| `%s` | %d | %d | %s |' % (n.upper(), v, w.get(n, 1), PSWD[n]))
    L.append('')
    L.append('Bits 12 to 15 are reserved and read as zero. Bit 12 is the user-memory guard `UA`.')
    L += ['', '## The modes', '', '| Mode | Value |', '|---|---|'] + ['| %s | %d |' % (n, v) for n, v in SYS['mode']]
    L.append('')
    L.append('Value 2 is reserved: loading it into either mode field of the status word is an illegal instruction.')
    L += ['', '## The exception vectors', '', 'The table has 512 entries of eight bytes at the physical address `VBR + 8 * vector`; `ECAUSE` equals the vector number.', '', '| Vector | Number | Cause |', '|---|---|---|']
    for n, v in SYS['vector']:
        L.append('| `%s` | %d | %s |' % (n.upper().replace('-', '_'), v, VEC[n]))
    L += ['', '## The page-table entry (64 bits)', '', '| Field | Bit | Width | Meaning |', '|---|---|---|---|']
    pw = dict(SYS['pte-width'])
    for n, v in SYS['pte']:
        L.append('| `%s` | %d | %d | %s |' % (n.upper(), v, pw.get(n, 1), PTED[n]))
    L.append('')
    L.append('A non-leaf entry has `V` = 1 and `R` = `W` = `X` = 0 and points to the next table. Every bit not named is zero.')
    L += ['', '## The memory types (`MT`)', '', '| Type | Value |', '|---|---|'] + ['| %s | %d |' % (n.replace('-', ' '), v) for n, v in SYS['mt']]
    L += ['', '## The translation geometry', '', '| Quantity | Value |', '|---|---|'] + ['| %s | %d |' % (n.replace('-', ' '), v) for n, v in SYS['mmu']]
    L += ['', '## The system registers (`MFSR`, `MTSR`)', '', sysreg_table()]
    L += ['', '## The addressing modes', '', '| Mode | Value |', '|---|---|'] + ['| %s | `%s` |' % (n, bits(v, 4)) for n, v in SPEC['amode']]
    L.append('')
    L.append('Modes `1000` to `1111` are reserved. The syntax and the parcel layout of each mode are in section 9.5.')
    L += ['', '## The condition codes', '', '| Name | Number | Aliases |', '|---|---|---|']
    al = {}
    for n, v in SPEC['ccalias']:
        al.setdefault(v, []).append(n)
    for n, v in SPEC['cc']:
        L.append('| `%s` | %d | %s |' % (n, v, ', '.join('`%s`' % a for a in al.get(v, [])) or ''))
    L.append('')
    return '\n'.join(L)


HOME = {}
for _i in 'MOV MOVZ LEA MOVU'.split(): HOME[_i] = ('09-isa.md', '9.6')
for _i in 'ADD SUB CMP MUL MULH ADDM INC DEC NEG ADC SBC DIV MULHU ABS MINMAX SET'.split(): HOME[_i] = ('09-isa.md', '9.7')
for _i in 'BIC BIS BIT XOR AND SHIFT CLR COM TST ASL ASR'.split(): HOME[_i] = ('09-isa.md', '9.8')
for _i in 'COUNT POPCNT BSWAP BITREV ROR RORI RORI32 DSHR EXTB INSB XNORPOP CLMUL UTF8LEN UTF8DEC UTF8ENC'.split(): HOME[_i] = ('09-isa.md', '9.9')
for _i in 'BCC SOB CBCC BTAG JMP CALL JMPI JTAG'.split(): HOME[_i] = ('09-isa.md', '9.10')
for _i in 'PUSH POP PUSHM POPM MCPY MSET MCMP MSCN MVAL'.split(): HOME[_i] = ('09-isa.md', '9.11')
for _i in 'FADD FCMP FDIV FSINGLE FMADD FMADD32 FSIGN FMIN FCLASS FRINT FCVT FSFLAGS FHALF FCVTH'.split(): HOME[_i] = ('09-isa.md', '9.12')
for _i in 'CAS SWAP XADD XAND XMAX LLSC'.split(): HOME[_i] = ('09-isa.md', '9.13')
for _i in ('NOP RTI RET HALT BPT FENCE WFE SEV TLBA PUSHX ISYNC HINT MFSR MTPS SPL TRAP TLBI MTASID MTDP MTDMW MFCPUID ICINV PROBE').split(): HOME[_i] = ('09-isa.md', '9.14')


for _i in 'MOV2 MOVQL MOVD MOVUSER MOVUSERD'.split(): HOME[_i] = ('09-isa.md', '9.6')
for _i in 'MASK OVF'.split(): HOME[_i] = ('09-isa.md', '9.7')
for _i in 'BSEL AESR AESK SHA256 SHA512'.split(): HOME[_i] = ('09-isa.md', '9.9')
for _i in 'MOVCALL POPRET POPMRET'.split(): HOME[_i] = ('09-isa.md', '9.10')
for _i in 'MSHA MAESCTR'.split(): HOME[_i] = ('09-isa.md', '9.11')
for _i in 'TRAPCC SYSPG'.split(): HOME[_i] = ('09-isa.md', '9.14')


def notation():
    """The notation paragraph of chapter 9, with the registers and the masks of PUSHM and POPM."""
    t = D.NOTATION_ENC
    d = LAY.enc().d
    rn = lambda rs: ' '.join('`R%d`' % r if r != 14 else '`SP`' for r in rs)
    t += ("\n\n**Registers.** The pdp64 has %d registers, `R0` to `R%d`. A register field of an instruction is %s; the entries that name `R0` to `R15` apply to `R16` to `R31` too; the hot-register tables are part of the ABI: the 3-bit fields hold, in order, %s%s."
          % (d['registers'], d['registers'] - 1,
             'the full number of bits (%d), or fewer where the field names one of the hot registers' % (d['registers'].bit_length() - 1),
             rn(d['hot8']), ('; the 4-bit fields hold, in order, ' + rn(d['hot16'])) if d['hot16'] else ''))
    t += " `PUSHM` and `POPM` take a 32-bit mask (errata 87)."
    return t


def slug(heading):
    return re.sub(r'[^a-z0-9 -]', '', heading.lower()).replace(' ', '-')


def section_bounds(text, num):
    m = re.search(r'(?m)^## %s .*$' % re.escape(num), text)
    if not m:
        raise SystemExit('no section %s' % num)
    nxt = re.search(r'(?m)^## ', text[m.end():])
    end = m.end() + nxt.start() if nxt else len(text)
    return m, end


def embed(text, key, body, after_heading=False):
    """Put `body` between the markers of `key` in the section; create the markers at the end of the section (or just after the heading)."""
    num = key.split(':')[-1] if ':' in key else key
    open_m, close_m = '<!-- %s -->' % key, '<!-- /%s -->' % key
    block = '%s\n%s\n%s' % (open_m, body.strip('\n'), close_m)
    if open_m in text:
        a = text.index(open_m)
        b = text.index(close_m) + len(close_m)
        return text[:a] + block + text[b:]
    sec = key.split(':')[1] if key.startswith('entries:') else '9.6'
    m, end = section_bounds(text, sec)
    if after_heading:
        return text[:m.end()] + '\n\n' + block + text[m.end():]
    head = text[:end].rstrip('\n')
    return head + '\n\n' + block + '\n\n' + text[end:]


def sources():
    """The hand-written text: every file of docs/manual-src/."""
    out = {}
    for fn in sorted(os.listdir(SRCDIR)):
        if not fn.endswith('.md') or fn == 'README.md':
            continue
        t = open(os.path.join(SRCDIR, fn)).read()
        out[fn] = ASM.resolve(t, 'docs/manual-src/' + fn)
    # appendices H (proposed), I (deferred) and J (open items): assembled from the fragments of docs/manual-src/appendix-parts/, one file per chapter and kind
    pdir = os.path.join(SRCDIR, 'appendix-parts')
    frags = {fn: open(os.path.join(pdir, fn)).read() for fn in sorted(os.listdir(pdir))} if os.path.isdir(pdir) else {}
    probs = ASM.assemble_parts(out, frags)
    if probs:
        raise SystemExit('\n'.join(probs))
    return out


def held_chart_ids():
    """the charts whose mnemonics are all held back (proposed or stub entries, isa_entries.HELD): they are not shown"""
    return {cid for cid in {c for v in CH.byname.values() for c, _ in v}
            if all(n in D.HELD_NAMES for n, v in CH.byname.items() if any(c == cid for c, _ in v))}


def by_encoding_page():
    """dictionary/by-encoding.md: a chart for every opcode (every distinct layout), generated from the grammar, with the index of the mnemonics."""
    L = ['# The bit layouts of every opcode', '', '[← dictionary index](index.md)', '']
    L += ['Every leaf of the encoding has a chart here. A leaf is a prefix of 3 to 16 bits of the first parcel, a sub-opcode that selects one of its mnemonics, and the pieces of its operands; '
          'there is no `len` field, because the prefix decides the length. The charts are generated by `tools/mkmanual.py` from the grammars `spec/pdp64-enc.hbnf` and `spec/pdp64/pdp64.hbnf`, '
          'read by `tools/encgram.py`; changing a field in a grammar changes the chart.']
    L += ['', '**How to read a chart.** Each row is one 16-bit parcel, bit 15 on the left, the bit numbers above the boxes. A shaded box has a fixed value, written in it; a white box is a field of the instruction. '
          'Fields are named `opN.part` for the part of the Nth operand of the assembly syntax (`op1.d` is the displacement of the first operand); a field the layout splits is `name[1]`, `name[2]` from the top. '
          'A register field of 3 or 4 bits holds an index into the hot-register table of the ABI, not a register number.', '']
    d = LAY.enc().d
    rn = lambda r: 'SP' if r == 14 else 'R%d' % r
    L += ['## The hot-register tables', '', 'The part of the ABI on which the encoding depends: a 3-bit register field holds, in order, `%s`' % ' '.join(rn(r) for r in d['hot8'])
          + ('; a 4-bit field holds `%s`' % ' '.join(rn(r) for r in d['hot16']) if d['hot16'] else '') + '. The fused instructions of the encoding are `%s`.' % '`, `'.join(d['fused']), '',
          '## The operand shapes', '', 'The widths and the reach of the immediates and displacements of each shape the forms use (the shapes are rules of the grammar):', '', '| Shape | Meaning |', '|---|---|']
    for nm, desc in sorted(LAY.enc().shapes_used().items()):
        L.append('| `%s` | %s |' % (nm, desc))
    L.append('')
    L += ['## The charts', '']
    held_charts = held_chart_ids()
    order = sorted(range(len(CH.charts)), key=lambda i: (CH.charts[i]['parcels'], CH.charts[i]['L'], i))
    cur = None
    for i in order:
        ch = CH.charts[i]
        if ch['id'] in held_charts:
            continue
        if ch['parcels'] != cur:
            cur = ch['parcels']
            L += ['### Instructions of %d parcel%s (%d bytes)' % (cur, '' if cur == 1 else 's', 2 * cur), '']
        L += chart_block(ch)
    L += ['## The index of the mnemonics', '', 'For every mnemonic, the charts in which it is a sub-opcode or the whole leaf.', '']
    for n in sorted(MN):
        if MN[n]['alias_of'] or n in D.HELD_NAMES:
            continue
        refs = []
        for cid, ch in CH.byname.get(n, []):
            refs.append('[%s](#%s)' % (cid, cid))
        L.append('* <a id="mn-%s"></a>`%s`: %s' % (re.sub(r'[^a-z0-9]', '-', n), n.upper(), ', '.join(refs)))
    L += ['', '*Generated by `tools/mkmanual.py`; do not edit.*', '']
    return '\n'.join(L).replace('](figures/', '](../figures/')


def chart_block(ch):
    cid = ch['id']
    out = ['<a id="%s"></a>' % cid, '#### %s: %s' % (cid, ch['title']), '', '![Layout %s](figures/%s.svg)' % (cid, cid), '']
    for line in ch['legend']:
        out += [line, '']
    out += ['Fields: ' + ' '.join('`%s`' % f for f in ch['fields'].split()), '']
    return out


def build():
    global FIGS, MN, CH
    FIGS = {}
    MN = manual_mn()
    CH = Charts()
    chart_files(CH)
    # a chart for every opcode: no mnemonic without a layout, no chart without a mnemonic, and (prefix-coded) a chart for every leaf of the grammar
    nochart = [n for n, m in MN.items() if not m['alias_of'] and not CH.byname.get(n)]
    if nochart:
        raise SystemExit('mnemonics with no bit layout in the grammar: ' + ' '.join(sorted(nochart)))
    used = {cid for v in CH.byname.values() for cid, _ in v}
    orphan = [c['id'] for c in CH.charts if c['id'] not in used and c['kind'] != 'p2']
    if orphan:
        raise SystemExit('charts for no mnemonic: ' + ' '.join(orphan))
    if CH.enc and len(CH.charts) != len(CH.enc.d['leaves']):
        raise SystemExit('%d charts for %d leaves' % (len(CH.charts), len(CH.enc.d['leaves'])))
    files = {}
    chapters = {}
    allents = D.ENTRIES
    ents = [e for e in allents if e['id'] not in D.HELD]   # a proposed or stub entry is held back (isa_entries.HELD): its text is in appendix-parts/09-proposed.md or 09-open.md
    seen = {}
    for e in ents:
        for n in e['names']:
            if n not in MN:
                raise SystemExit('entry %s names %r, which is not in the specification' % (e['id'], n))
            if n in seen:
                raise SystemExit('%r is in entries %s and %s' % (n, seen[n], e['id']))
            seen[n] = e['id']
        e['kind'] = MN[[x for x in e['names'] if not MN[x]['alias_of']][0]]['kind']
        if e['id'] not in HOME:
            raise SystemExit('entry %s has no home section' % e['id'])
    badstory = set(D.STORY) - {e['id'] for e in allents}
    if badstory:
        raise SystemExit('stories for entries that do not exist: ' + ' '.join(sorted(badstory)))
    unused = set(HOME) - {e['id'] for e in allents}
    if unused:
        raise SystemExit('home sections for entries that do not exist: ' + ' '.join(sorted(unused)))
    missing = [n for n, m in MN.items() if n not in seen and n not in D.HELD_NAMES and not (m['alias_of'] and m['alias_of'] in seen)]
    if missing:
        raise SystemExit('mnemonics with no entry: ' + ' '.join(sorted(missing)))
    alias_of = {n: m['alias_of'] for n, m in MN.items() if m['alias_of']}
    for e in ents:
        e['aliases'] = [a for a, t in alias_of.items() if t in e['names'] and a not in e['names']]
    # the entries, into the sections of the chapters
    texts = sources()
    heads = {}
    for e in ents:
        fn, sec = HOME[e['id']]
        e2 = dict(e)
        e2['names'] = e['names'] + e['aliases']
        heads.setdefault((fn, sec), []).append(render_entry(e2))
    for (fn, sec), parts in sorted(heads.items()):
        texts[fn] = embed(texts[fn], 'entries:' + sec, '\n\n'.join(p.strip('\n') + '\n' for p in parts))
    texts['09-isa.md'] = embed(texts['09-isa.md'], 'notation', notation(), after_heading=True)
    # the official entries live in the instruction chapter; the chapters that give the rationale list them and link to them
    for fn, sec, home in (('06-kernel.md', '6.13', '9.14'), ('07-smp.md', '7.4', '9.13')):
        rows = ['**The instruction entries for this section are in chapter 9, section %s:** each entry there is complete (syntax, encoding diagram, operation, flags, exceptions, status); the commentary above gives the reasons and the use.' % home, '',
                '| Entry | Mnemonics |', '|---|---|']
        for e in ents:
            if HOME[e['id']] == ('09-isa.md', home):
                mn = ', '.join('`%s`' % n.upper().rstrip('_') for n in e['names'] if not MN[n]['alias_of'])
                rows.append('| [%s](09-isa.md#%s) | %s |' % (e['title'], anchor_for(e), mn))
        texts[fn] = embed(texts[fn], 'entries:' + sec, '\n'.join(rows))
    chapters = texts
    # slugs of the sections, for links
    def sec_link(fn, sec):
        m = re.search(r'(?m)^## %s (.*)$' % re.escape(sec), texts[fn])
        return '../%s#%s' % (fn, slug('%s %s' % (sec, m.group(1))))
    # aliases
    A = ['# Assembler aliases and alternative spellings', '', '[← dictionary index](index.md)', '',
         'A mnemonic that assembles to another instruction. One mnemonic is one instruction (section 9.18); the disassembler never prints an alias.', '',
         '*Generated by `tools/mkmanual.py` from `spec/pdp64-mnemonics.hbnf`; do not edit.*', '', '| Written | Assembles to | Group |', '|---|---|---|']
    for n, m in sorted(MN.items()):
        if m['alias_of']:
            A.append('| `%s` | `%s` | `%s` |' % (n.upper(), m['alias_of'].upper(), m['group'][3:]))
    A.append('| `ROL rs, #n, rd` | `RORI rs, #(64-n), rd` | assembler, immediate count only |')
    A.append('')
    files['aliases.md'] = '\n'.join(A)
    # by mnemonic
    byid = {e['id']: e for e in ents}
    by = ['# The mnemonics, alphabetically', '', '[← dictionary index](index.md)', '',
          '*Generated by `tools/mkmanual.py`; do not edit.*', '']
    by += ['| Mnemonic | Entry | Layouts | Group |', '|---|---|---|---|']
    for n in sorted(MN):
        if n in D.HELD_NAMES:
            continue
        m = MN[n]
        tgt = m['alias_of'] or n
        eid = seen.get(n) or seen.get(tgt)
        e = byid[eid]
        fn, sec = HOME[eid]
        head = '`%s`%s | [%s](%s) (section %s)' % (n.upper(), ' (alias of `%s`)' % tgt.upper() if m['alias_of'] else '', eid, '../%s#%s' % (fn, anchor_for(e)), sec)
        nl = len(CH.byname.get(tgt, []))
        lay = '[%d](by-encoding.md#mn-%s), [entry](../%s#w-%s)' % (nl, re.sub(r'[^a-z0-9]', '-', tgt), HOME[eid][0], wslug(tgt))
        by.append('| %s | %s | %s |' % (head, lay, GROUPNAME[m['kind']]))
    by.append('')
    files['by-mnemonic.md'] = '\n'.join(by)
    files['by-encoding.md'] = by_encoding_page()
    files['constants.md'] = constants_page()
    # index
    I = ['# The instruction reference tables', '', '[← manual index](../00-index.md)', '', D.INDEX_INTRO_ENC, '', '## Where the entries are', '']
    where = {}
    for e in ents:
        where.setdefault(HOME[e['id']], []).append(e)
    for (fn, sec), es in sorted(where.items(), key=lambda kv: [int(x) for x in kv[0][1].split('.')] + [0]):
        m = re.search(r'(?m)^## %s (.*)$' % re.escape(sec), texts[fn])
        I.append('* [Section %s, %s](%s): %s' % (sec, m.group(1), sec_link(fn, sec), ', '.join('`%s`' % e['names'][0].upper() for e in es)))
    I.append('')
    I.append('## The tables')
    I.append('')
    I.append('* [Assembler aliases and alternative spellings](aliases.md)')
    I.append('* [The architectural constants](constants.md)')
    I.append('* [The mnemonics, alphabetically](by-mnemonic.md)')
    I.append('* [The bit layouts of every opcode](by-encoding.md): a chart for each layout, generated from the grammar')
    I.append('')
    vis = {n: m for n, m in MN.items() if n not in D.HELD_NAMES}
    n_real = sum(1 for m in vis.values() if not m['alias_of'])
    n_alias = sum(1 for m in vis.values() if m['alias_of'])
    n_ext = sum(1 for m in vis.values() if m['kind'] == 'ext')
    wch = {n: v for n, v in WORDCH.items() if n not in D.HELD_NAMES}
    I.append('The specification of the pdp64 has %d mnemonic words (%d instructions and %d aliases)%s. There are %d instruction entries, %d bit-layout charts of the layouts, and an entry for each of the %d instructions with a chart of each of its %d forms.'
             % (len(vis), n_real, n_alias, (', %d of them added by the prefix-coded encoding' % n_ext) if n_ext else '',
                len(ents), len(CH.charts) - len(held_chart_ids()), len(wch), sum(len(v) for v in wch.values())))
    I.append('')
    I.append('*Generated by `tools/mkmanual.py`; do not edit.*')
    I.append('')
    files['index.md'] = '\n'.join(I)
    # the figures of chapter 9 that the text refers to by name, drawn from the grammars (the status word from spec/pdp64-system.hbnf)
    used = '\n'.join(texts.values())
    if 'figures/psw.svg' in used:
        fig('psw', 'The processor status word', LAY.psw_chart(SYS))
    for fname, (_alt, draw) in list(BUSFIGS.FIGURES.items()) + list(GFXFIGS.FIGURES.items()) + list(KERNFIGS.FIGURES.items()) + list(BOOTFIGS.FIGURES.items()) + list(DRVFIGS.FIGURES.items()) + list(INTROFIGS.FIGURES.items()) + list(VECFIGS.FIGURES.items()) + list(SMPFIGS.FIGURES.items()):     # the box-and-arrow figures of chapters 2 to 6 (tools/manual/busfigs.py, gfxfigs.py, bootfigs.py, drvfigs.py, kernfigs.py, vecfigs.py, smpfigs.py); not instruction encodings
        if 'figures/%s.svg' % fname in used:
            FIGS[fname + '.svg'] = draw()
    return files, chapters


def anchor_for(e):
    return slug('%s: %s' % (e['id'], e['title']))


def main():
    check = '--check' in sys.argv
    bad = False
    files, chapters = build()
    if '--dropped' in sys.argv:
        for k, v in sorted(DROPPED.items()):
            print('%s: %d sentences of the original text left out' % (k, len(v)))
    base = MANUAL
    rel = {}
    for name, text in files.items():
        rel['dictionary/' + name] = text
    for name, text in chapters.items():
        rel[name] = text
    for name, text in FIGS.items():
        rel['figures/' + name] = text
    for pr in ASM.verify(rel, set(rel), base):
        print(pr)
        bad = True
    # what is on disk and not generated
    on_disk = set()
    if os.path.isdir(base):
        for d, _, fs in os.walk(base):
            for f in fs:
                on_disk.add(os.path.relpath(os.path.join(d, f), base))
    for name, text in sorted(rel.items()):
        p = os.path.join(base, name)
        if check:
            if not os.path.exists(p) or open(p).read() != text:
                print('stale: ' + os.path.relpath(p, ROOT))
                bad = True
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, 'w').write(text)
    for name in sorted(on_disk - set(rel)):
        if check:
            print('stale (no longer generated): ' + os.path.relpath(os.path.join(base, name), ROOT))
            bad = True
        else:
            os.remove(os.path.join(base, name))
    if not check:
        print('pdp64: wrote %d dictionary pages, %d figures and %d chapters' % (len(files), len(FIGS), len(chapters)))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()

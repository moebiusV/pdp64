#!/usr/bin/env python3
"""Generate the instruction dictionary of the manual (docs/manual/dictionary/).

Every number comes from spec/grammars.d, the one place the architecture's numbers are written, so the dictionary
cannot drift from the assembler and the simulators; the words (operation, exceptions) are in tools/manual/isa_entries.py.
Whether an instruction is implemented in the reference executor is read from common/pdp64exec.c.

    tools/mkmanual.py                  write the manual of the pdp64 into docs/manual/: the hand-written text of docs/manual-src/ (tools/manual/assemble.py),
                                       the instruction entries, the dictionary and the figures; the bit layouts are read from the grammar of the encoding; and the design notes
                                       of docs/design/src/ into docs/design/
    tools/mkmanual.py --check          exit 1 if a mnemonic has no entry, an entry names a mnemonic that does not exist, a committed file differs, a section
                                       or statement number is not contiguous, or a link or a section reference has no target
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'manual'))
import isa_entries as D
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import grammars_d
import assemble as ASM
import bookrefs as BR
import memberprose as MP
import isa_enc as ENCPROSE

MANUAL = os.path.join(ROOT, 'docs', 'manual')             # the manual of the pdp64
MEASURE_FILE = os.path.join(ROOT, 'docs', 'encoding-work', 'bench', 'flags', 'results-final.txt')   # written by tools/measure-flags.sh


def measured():
    """the numbers of the flags measurement, key = value lines of MEASURE_FILE (a number in the manual is never typed: @@MEASURE:key@@)"""
    if not os.path.exists(MEASURE_FILE):
        raise SystemExit('%s is missing: run tools/measure-flags.sh' % os.path.relpath(MEASURE_FILE, ROOT))
    out = {}
    for line in open(MEASURE_FILE):
        if line.strip() and not line.startswith('#'):
            k, _, v = line.partition(' = ')
            out[k.strip()] = v.strip()
    return out


def resolve_measures(text, name):
    """replace every @@MEASURE:key@@ by its value in the measurement file; a key that is not there is an error"""
    m = measured() if '@@MEASURE:' in text else {}
    def one(mt):
        if mt.group(1) not in m:
            raise SystemExit('%s: @@MEASURE:%s@@ is not a key of %s' % (name, mt.group(1), os.path.relpath(MEASURE_FILE, ROOT)))
        return m[mt.group(1)]
    return re.sub(r'@@MEASURE:([\w.-]+)@@', one, text)
SRCDIR = os.path.join(ROOT, 'docs', 'manual-src')         # the hand-written text, once (docs/manual-src/README.md)
DESIGN = os.path.join(ROOT, 'docs', 'design')             # the design notes (decisions pending, evolution, proposed, deferred, open items), outside the manual
DESIGNSRC = os.path.join(DESIGN, 'src')                   # their sources: the five notes and appendix-parts/ (docs/design/README.md)
# source file of each design note -> the generated file in docs/design/
DESIGNFILES = {'appendix-b-decisions-pending.md': 'decisions-pending.md', 'appendix-g-evolution.md': 'evolution.md', 'appendix-h-proposed.md': 'proposed.md',
               'appendix-i-deferred.md': 'deferred.md', 'appendix-j-open.md': 'open-items.md'}
EXEC = os.path.join(ROOT, 'common', 'pdp64exec.c')

BOOK = BR.Book(os.path.join(ROOT, 'book', 'outline.txt'), os.path.join(ROOT, 'book', 'sources.txt'))   # the numbers of the manual (tools/manual/bookrefs.py)


def raw_sources():
    """The files of docs/manual-src/ in the order of the book, with their tokens; BOOK.defs has the number of every section, statement and figure."""
    out = {}
    for fn in sorted(os.listdir(SRCDIR)):
        if fn.endswith('.md') and fn != 'README.md':
            out[fn] = ASM.resolve(open(os.path.join(SRCDIR, fn)).read(), 'docs/manual-src/' + fn)
    order = [os.path.basename(f) for f in BOOK.file_uuid]
    out = {fn: out[fn] for fn in sorted(out, key=lambda f: (order.index(f) if f in order else len(order), f))}
    BOOK.number(out)
    return out


def labels():
    """file name of the manual -> its chapter number or appendix letter, from the outline (book/outline.txt, book/sources.txt)"""
    return {fn: BOOK.chapter_label(fn) for fn in os.listdir(SRCDIR) if BOOK.chapter_label(fn)}


def R(name):
    """the number of a section or a numbered statement of the manual, as a string, by its name: the order of the text decides (the home sections of the entries are named here)"""
    if not BOOK.defs:
        raw_sources()
    if name not in BOOK.defs:
        raise SystemExit('no section or statement named %s in docs/manual-src/' % name)
    return BOOK.defs[name]['num']


def num(s):
    return int(s, 0)


def parse_spec(target='asm'):
    """{rule: [(word, number)]} of the hand-written parts of spec/grammars.d/ that name `target` (asm: the words, the registers, the system registers; spec: System v1)"""
    t = grammars_d.text(ROOT, target, generated=False)
    groups = {}
    for g, body in re.findall(r'(?m)^([a-z0-9-]+)\s*=(.*?)(?=^\S|\Z)', t, re.S):
        body = re.sub(r';[^\n]*', '', body)
        groups[g] = [(m, num(n)) for m, n in re.findall(r'"([A-Za-z0-9_.#-]+)"@(\S+)' if target == 'spec' else r'"([A-Za-z0-9_.#]+)"@(\S+)', body)]
    return groups


SPEC = parse_spec('asm')
SYS = parse_spec('spec')
OPGROUP = dict(SPEC['opgroup'])                    # lea 0x0B, besc 0x0C ... sob 0x3F
# mnemonic group -> (spec group, kind). The kind selects the encoding diagram.
KIND = {'mn-ext': 'ext', 'mn-mov': 'mem', 'mn-movz': 'mem', 'mn-lea': 'mem', 'mn-alu': 'mem', 'mn-branch': 'br', 'mn-cbranch': 'cb',
        'mn-sob': 'sob', 'mn-tag': 'tag', 'mn-sop': 'sop', 'mn-xfer': 'xfer', 'mn-besc': 'besc', 'mn-mblk': 'mblk',
        'mn-aesc': 'aesc', 'mn-fesc': 'fesc', 'mn-atom': 'atom', 'mn-mesc': 'mesc', 'mn-sys-none': 'sysn',
        'mn-sysx': 'sysx', 'mn-tlbx': 'tlbx', 'mn-sysreg': 'sysreg', 'mn-sys': 'sys', 'subop': 'aesc'}
GROUPNAME = {'ext': 'Added by the prefix-coded encoding', 'mem': 'Moves, address formation and the ALU', 'br': 'Branches', 'cb': 'Branches', 'sob': 'Branches',
             'tag': 'Branches', 'sop': 'Single operand (SOP)', 'xfer': 'Indirect transfers (XFER)', 'besc': 'Bits and fields (BESC)',
             'mblk': 'Block memory (MBLK)', 'aesc': 'Arithmetic (AESC)', 'fesc': 'Floating point (FESC)',
             'atom': 'Atomics (ATOM)', 'mesc': 'Memory escape (MESC)', 'sysn': 'System (SYS)', 'sysx': 'System (SYS)', 'tlbx': 'System (SYS)',
             'sysreg': 'System (SYS)', 'sys': 'System (SYS)'}
ESC_OPC = {'besc': 'besc', 'mblk': 'mblk', 'aesc': 'aesc', 'mesc': 'mesc', 'fesc': 'fesc', 'atom': 'atom', 'xfer': 'xfer',
           'sop': 'sop', 'sys': 'sys', 'sysn': 'sys', 'sysx': 'sys', 'tlbx': 'sys', 'sysreg': 'sys', 'tag': 'tag', 'sob': 'sob'}


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


MN_BASE = mnemonics()                               # the words of spec/grammars.d
MN = MN_BASE                                        # the words of the manual (build() sets it)
CH = None                                           # its charts (class Charts)
import marks as MK                                  # the rows of spec/grammars.d/61-asm-suffixes.hbnf: the spellings of the width and kind suffixes, and the words of the older notations
ROWS = MK.rows()                                    # [(spelling, word of the encoding, flags, printed)]
SHOWN = MK.shown()                                  # word of the encoding -> the spelling that is printed for it (movq is mov, movb is mov.s8, fadd32 is fadd.f32)
INTERNAL = set(MK.words())                          # the words that are not words of the assembly language: the encoding's own names (movb, aaddl, fadd32, fcvtds) and the letters of the older notations
SPELLINGS = [r[0] for r in ROWS]                    # the spellings the assembler takes besides the words of the groups: mov, mov.s8, aadd.s32, fadd.f32, fcvt.s32.f32 ...


def wlabel(n):
    """how a word of the encoding is shown in the headings of its layouts: as the assembly language writes it, in capitals (movb is MOV.S8)"""
    return SHOWN.get(n, n).upper()


def disp_words(names):
    """the words of the assembly language that stand for these words of the encoding, once each, in order"""
    out = []
    for n in names:
        w = wlabel(n)
        if w not in out: out.append(w)
    return out
EXECTEXT = open(EXEC).read()
EXECENC = open(os.path.join(ROOT, 'common', 'pdp64exec_enc.inc')).read()
ENC_IMPL = set(re.findall(r'\{ "([a-z0-9_.]+)", H_(?!UNIMPL)', EXECENC))       # the words the prefix-coded front end of the executor has a case for


def manual_mn():
    """The words of the manual: those of spec/grammars.d and the words of group mn-ext, from the grammar of the encoding."""
    mn = dict(MN_BASE)
    for i, w in enumerate(LAY.enc().d['ext']):
        mn[w] = dict(group='mn-ext', kind='ext', value=i, alias_of=None)
    for a_, t_ in (('min', 'setlt'), ('minu', 'setlos'), ('max', 'setgt'), ('maxu', 'sethi')):    # assembler aliases that expand to a sequence; the word they are numbered by is the first instruction's
        mn[a_] = dict(group='mn-ext', kind='ext', value=0x1000 + LAY.enc().d['ext'].index(t_), alias_of=t_)
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
                out += ['<a id="w-%s"></a>' % wslug(a), '**`%s`** is an alias of `%s`: the assembler writes it as that word.' % (wlabel(a), wlabel(MN[a]['alias_of'])), '']
        return out
    for n in names:
        out.append('<a id="w-%s"></a>' % wslug(n))
        if MN[n]['alias_of']:
            out += ['#### %s' % wlabel(n), '', 'An alias of [`%s`](#w-%s): the assembler writes it as that word.' % (wlabel(MN[n]['alias_of']), wslug(MN[n]['alias_of'])), '']
            continue
        syn = [l.split(';')[0].rstrip() for l in e['syntax'] if re.match(r'\s*%s(?![\w.])' % re.escape(wlabel(n)), l)]
        out += ['#### %s' % wlabel(n), ''] + forms_block(n)
        if syn:
            out += ['```', uni('\n'.join(syn)), '```', '']
        out += ['Operation and exceptions as for the entry %s above; %d layout form%s, each a chart of its own (above).' % (e['id'], len(WORDCH[n]), '' if len(WORDCH[n]) == 1 else 's'), '']
    return out


def render_entry(e):
    names = e['names']
    real = [n for n in names if not MN[n]['alias_of']]
    heads = ', '.join('`%s`' % w for w in disp_words([n for n in names if e.get('alias') or not MN[n]['alias_of']]))
    out = []
    if len(real) == 1 or e.get('alias'):
        out += ['<a id="w-%s"></a>' % wslug(n) for n in names]
    out += ['### %s: %s' % (e['id'], e['title']), '']
    if len(real) == 1 and not e.get('alias'):
        out += forms_block(real[0])
    out.append('**Mnemonics:** ' + heads + (('  (aliases: ' + ', '.join('`%s`' % w for w in disp_words([n for n in names if MN[n]['alias_of']])) + ')') if not e.get('alias') and any(MN[n]['alias_of'] for n in names) else ''))
    out.append('')
    if e.get('alias'):
        out.append('**Alias** *(D)* ' + e['alias'])
        out.append('')
    out.append('**Syntax**\n')
    out.append('```\n' + uni('\n'.join(e['syntax'])) + '\n```')
    out.append('')
    if e.get('alias'):
        out.append('**Encoding** None of its own: the assembler expands an alias into other instructions.')
    else:
        out.append('**Encoding**\n')
        out.append(encoding(e))
    out.append('')
    out.append('**Operation**\n')
    out.append('```\n' + uni(e['op'].strip('\n')) + '\n```')
    out.append('')
    if e['flags']:
        out.append(('**Exception flags** ' if ('FPSR' in e['flags'] or 'exception flag' in e['flags']) else '**Result** ') + e['flags'])
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
       'misaligned': 'an atomic, `PUSHX`, `POPX` or the operand of a vector block at an address that is not a multiple of its size (a plain load or store has no alignment fault)', 'noncanonical': 'a virtual address whose bits 63 to 39 differ from bit 38',
       'ifault': 'instruction fetch from a page that is not mapped', 'lfault': 'load from a page that is not mapped', 'sfault': 'store to a page that is not mapped',
       'iprot': 'instruction fetch denied by the page permissions', 'lprot': 'load denied by the page permissions', 'sprot': 'store denied by the page permissions',
       'divzero': 'division by zero (`DIV`, `DIVU`, `MOD`, `MODU`)', 'busfault': 'a read of non-existent memory (a precise abort)', 'lpad': 'an indirect transfer that did not land on `LPAD` (enforcement off in ABI version 1)',
       'bpt': 'the `BPT` instruction', 'check': 'a failed run-time check (the compare-and-trap, `CHK2`, `ADDV`, `SUBV`, `MULV`)', 'irq-base': 'the first interrupt vector', 'timer': 'the timer interrupt (level 6)', 'console-in': 'console receive interrupt (level 4)',
       'console-out': 'console transmit interrupt (level 4)',
       'pcie-inta': 'PCI Express interrupt pin A of the model host bridge (level 5)', 'pcie-intb': 'PCI Express interrupt pin B (level 5)', 'pcie-intc': 'PCI Express interrupt pin C (level 5)', 'pcie-intd': 'PCI Express interrupt pin D (level 5)',
       'hexit': 'the instruction exit of a guest, in the hypervisor\'s vector table only ({{r:exit-enters-the-hypervisor-through}})', 'gifault': 'a guest-physical instruction fault (stage 2), in the hypervisor\'s table only',
       'glfault': 'a guest-physical load fault (stage 2), in the hypervisor\'s table only', 'gsfault': 'a guest-physical store fault (stage 2), in the hypervisor\'s table only',
       'iommu': 'the IOMMU unit\'s own interrupt, a wired line (level 5; {{r:unit-own-interrupt}})', 'trap-base': '`TRAP #n` enters vector 256 + n', 'count': 'the number of vectors; the table has this many eight-byte entries'}
PSWD = {'t': 'trace: take a trace trap after the next instruction', 'pri': 'interrupt priority level, 0 to 7', 'mode': 'current mode', 'prev': 'previous mode (the mode before the last exception)'}
PTED = {'v': 'valid', 'r': 'readable', 'w': 'writable', 'x': 'executable', 'u': 'accessible from user mode', 'g': 'global: ignores the ASID', 'a': 'accessed (managed by software)', 'd': 'dirty (managed by software)', 'mt': 'memory type', 'ppn': 'physical page number: physical address bits 12 to 39, in place'}


IOMMU_MEANING = {
    'reg': 'the registers of the unit, a byte offset each ({{r:registers-are-64-bits-wide}}); the first eight are the common device pattern',
    'id': 'the value of the unit type and of the version in the ID register', 'id-field': 'the fields of the ID register',
    'control': 'the bits of CONTROL', 'status': 'the bits of STATUS (cmd-error, overflow and table-error are sticky: write one to clear)',
    'device': 'the fields of DEVICE, the device-table pointer', 'device-width': 'the width of the mode field', 'caps-width': 'the widths of the fields of CAPS that are wider than one bit', 'mode': 'the values of the mode field of DEVICE (blocked at reset)',
    'caps': 'the fields of CAPS', 'caps-value': 'the values the model reports in CAPS',
    'dir': 'the field of a directory entry (the rest: the page number of the leaf, `pte` field `ppn`)', 'table': 'the geometry of the device table ({{r:device-is-identified}})', 'dte-word': 'the byte offsets of the four words of a device entry ({{r:device-entry-is-32-bytes}})',
    'dte': 'the fields of word 0 of the device entry', 'dte-width': 'the widths of the fields of word 0 that are wider than one bit', 'stages': 'the values of the stages field',
    'cmd': 'the fields of word 0 of a command ({{r:unit-cached-translations}})', 'cmd-width': 'the widths of those fields', 'cmd-bytes': 'the size of a command and the value that sync writes',
    'op': 'the operations of a command', 'fault': 'the fields of word 0 of a fault record ({{r:unit-refuses-a-device}})', 'fault-width': 'the widths of those fields',
    'fault-word': 'the byte offsets of the words of a fault record', 'fault-who': 'the fields of word 1 of a fault record', 'fault-bytes': 'the size of a fault record',
    'stage': 'the values of the stage field of a fault record', 'cause': 'the values of the cause field of a fault record'}
DMATEST_MEANING = {'reg': 'the registers of the test function, a byte offset each', 'ctl': 'the bits of CONTROL', 'status': 'the bits of STATUS (write one to clear)', 'irq': 'the bit of IRQ',
                   'map': 'the layout of its base address register window', 'id': 'its PCI identification'}


HV_MEANING = {
    'htrap': 'the bits of HTRAP, the trap-control register: a set bit sends the event to the hypervisor as an exit; `mask` is the position of the 8-bit hypercall mask, bit k routing `TRAP #n` for n from 32k to 32k + 31',
    'htrap-width': 'the width of the hypercall mask', 'htrap-reset': 'the value of HTRAP after a machine reset (`WFE` and `SEV` set)', 'hcall': 'the hypercall mask: one bit covers 32 trap numbers, as a shift',
    'xcode': 'the exit-reason codes (bits 7 to 0 of HEXITR)', 'xflag': 'the flag bits of HEXITR (a stage-2 fault on a page-table read; on the vector fetch)',
    'gtbr': 'the fields of GTBR: stage-2 enable, root page number, guest tag', 'gtbr-width': 'the widths of the root and the tag',
    'virq': 'the virtual interrupt lines: the number of lines, and the width of the vector field of each line in VIVEC'}


def hypervisor_section():
    L = ['', '## The hypervisor mode ({{r:hypervisor-mode-the-rules}})', '',
         'The numbers of the exit-reason codes, the trap-control bits and the stage-2 register, from `spec/grammars.d/52-hypervisor-v1.hbnf`; the registers themselves are in the table of {{r:registers-of-the-hypervisor}} and in the table of the system registers above, and the new vectors 17 to 20 in the table of the exception vectors. A number is a position, a width or a value, as the description of its rule says.', '',
         '| Rule | Name | Number | What the rule is |', '|---|---|---|---|']
    for rule, items in SYS.items():
        if rule not in HV_MEANING:
            continue
        for k, (n, v) in enumerate(items):
            L.append('| `%s` | `%s` | %s | %s |' % (rule, n, '0x%x' % v if v > 9999 else v, HV_MEANING[rule] if k == 0 else ''))
    return L


def iommu_section():
    L = ['', '## The IOMMU ({{r:iommu-a-page-table-per-device}}) and the DMA test function of the model', '',
         'The registers, bit numbers, command codes and fault codes of the unit, from `spec/grammars.d/51-iommu-v1.hbnf`. A number is a position, a width, a byte offset or a value, as the description of its rule says. The page-table entry of a device is the processor\'s (`pte` above).', '',
         '| Rule | Name | Number | What the rule is |', '|---|---|---|---|']
    for rule, items in SYS.items():
        if not (rule.startswith('iommu-') or rule.startswith('dmatest-')):
            continue
        kind, key = rule.split('-', 1)
        text = (IOMMU_MEANING if kind == 'iommu' else DMATEST_MEANING)[key]
        for k, (n, v) in enumerate(items):
            L.append('| `%s` | `%s` | %s | %s |' % (rule, n, '0x%x' % v if v > 9999 else v, text if k == 0 else ''))
    return L


def constants_page():
    w = dict(SYS['psw-width'])
    L = ['# Appendix: the architectural constants', '', '[← dictionary index](index.md)', '',
         'The numbers of the processor status word, the modes, the exception vectors, the page-table entry, the memory types, the translation geometry, the system registers, and the addressing modes, each read from the machine-readable specification (`spec/grammars.d/50-system-v1.hbnf` and `spec/grammars.d`).', '',
         '*Generated by `tools/mkmanual.py`; do not edit.*', '', '## The processor status word (16 bits)', '', '| Field | Bit | Width | Meaning |', '|---|---|---|---|']
    for n, v in SYS['psw']:
        L.append('| `%s` | %d | %d | %s |' % (n.upper(), v, w.get(n, 1), PSWD[n]))
    L.append('')
    L.append('Bits 0 to 3 and 12 to 15 are reserved and read as zero: the machine has no condition codes.')
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
    L += hypervisor_section()
    L += iommu_section()
    L.append('')
    return '\n'.join(L)


HOME = {}
for _i in 'MOV LEA'.split(): HOME[_i] = ('09-isa.md', 'moves-conversions-and-address-formation')
for _i in 'ADD SUB MUL MULH ADDM INC DEC NEG DIV ABS MINMAX SETCC'.split(): HOME[_i] = ('09-isa.md', 'integer-arithmetic')
for _i in 'BIC BIS XOR AND SHIFT CLR COM ASL ASR'.split(): HOME[_i] = ('09-isa.md', 'logic-shifts-and-rotates')
for _i in 'COUNT POPCNT BSWAP BITREV ROR DSHR EXTB INSB XNORPOP CLMUL UTF8LEN UTF8DEC UTF8ENC'.split(): HOME[_i] = ('09-isa.md', 'bits-bytes-and-text')
for _i in 'BR SOB CBCC FCBCC BTAG JMP CALL JMPI JTAG'.split(): HOME[_i] = ('09-isa.md', 'branches-and-control-flow')
for _i in 'PUSH POP PUSHM POPM MCPY MSET MCMP MSCN MVAL'.split(): HOME[_i] = ('09-isa.md', 'stack-and-block-operations')
for _i in 'FADD FDIV FSINGLE FMADD FMADD32 FSIGN FMIN FCLASS FRINT FCVT FSFLAGS'.split(): HOME[_i] = ('09-isa.md', 'floating-point')
for _i in 'CAS SWAP AADD AAND AMAX LLSC'.split(): HOME[_i] = ('09-isa.md', 'atomics-and-ordering')
for _i in ('NOP RTI RET HALT BPT FENCE WFE SEV TLBA PUSHX ISYNC HINT GENTER MFSR MTPS SPL TRAP TLBI TLBIAS MTDP ICINV PROBE').split(): HOME[_i] = ('09-isa.md', 'isa-system-instructions-exceptions')


for _i in 'MOV2 MCPYU'.split(): HOME[_i] = ('09-isa.md', 'moves-conversions-and-address-formation')
for _i in 'MASK OVF'.split(): HOME[_i] = ('09-isa.md', 'integer-arithmetic')
for _i in 'BSEL AESR AESK SHA256 SHA512'.split(): HOME[_i] = ('09-isa.md', 'bits-bytes-and-text')
for _i in 'MOVCALL POPRET POPMRET'.split(): HOME[_i] = ('09-isa.md', 'branches-and-control-flow')
for _i in 'MSHA MAESCTR'.split(): HOME[_i] = ('09-isa.md', 'stack-and-block-operations')
for _i in 'CT CHK2'.split(): HOME[_i] = ('09-isa.md', 'isa-system-instructions-exceptions')


def notation():
    """The notation paragraph of chapter 9, with the registers and the masks of PUSHM and POPM."""
    t = D.NOTATION_ENC
    d = LAY.enc().d
    rn = lambda rs: ' '.join('`R%d`' % r if r != 14 else '`SP`' for r in rs)
    t += ("\n\n**Registers.** The pdp64 has %d registers, `R0` to `R%d`. A register field of an instruction is %s; the entries that name `R0` to `R15` apply to `R16` to `R31` too; the hot-register tables are part of the ABI: the 3-bit fields hold, in order, %s%s."
          % (d['registers'], d['registers'] - 1,
             'the full number of bits (%d), or fewer where the field names one of the hot registers' % (d['registers'].bit_length() - 1),
             rn(d['hot8']), ('; the 4-bit fields hold, in order, ' + rn(d['hot16'])) if d['hot16'] else ''))
    t += " `PUSHM` and `POPM` take a 32-bit mask."
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
    sec = key.split(':')[1] if key.startswith('entries:') else R('moves-conversions-and-address-formation')
    m, end = section_bounds(text, sec)
    if after_heading:
        return text[:m.end()] + '\n\n' + block + text[m.end():]
    head = text[:end].rstrip('\n')
    return head + '\n\n' + block + '\n\n' + text[end:]


def sources():
    """The hand-written text of the manual: every file of docs/manual-src/, with its numbers and citations resolved."""
    return {fn: BOOK.resolve(x, 'docs/manual-src/' + fn) for fn, x in raw_sources().items()}


def design_notes(manual):
    """The design notes: the hand-written text of docs/design/src/, proposed, deferred and open items assembled from the fragments of docs/design/src/appendix-parts/ (one file
    per chapter and kind, titled from the chapters and appendices of `manual`).  Returns {file of docs/design/: text}."""
    out = {}
    for fn in sorted(os.listdir(DESIGNSRC)):
        if fn.endswith('.md'):
            out[fn] = BOOK.resolve(ASM.resolve(open(os.path.join(DESIGNSRC, fn)).read(), 'docs/design/src/' + fn), 'docs/design/src/' + fn)
    pdir = os.path.join(DESIGNSRC, 'appendix-parts')
    frags = {fn: BOOK.resolve(open(os.path.join(pdir, fn)).read(), 'docs/design/src/appendix-parts/' + fn) for fn in sorted(os.listdir(pdir))} if os.path.isdir(pdir) else {}
    probs = ASM.assemble_parts(out, frags, manual, labels())
    if probs:
        raise SystemExit('\n'.join(probs))
    unknown = set(out) - set(DESIGNFILES)
    if unknown:
        raise SystemExit('docs/design/src/: no output name for ' + ' '.join(sorted(unknown)))
    return {DESIGNFILES[fn]: t for fn, t in out.items()}


def held_chart_ids():
    """the charts whose mnemonics are all held back (proposed or stub entries, isa_entries.HELD): they are not shown"""
    return {cid for cid in {c for v in CH.byname.values() for c, _ in v}
            if all(n in D.HELD_NAMES for n, v in CH.byname.items() if any(c == cid for c, _ in v))}


def by_encoding_page():
    """dictionary/by-encoding.md: a chart for every opcode (every distinct layout), generated from the grammar, with the index of the mnemonics."""
    L = ['# The bit layouts of every opcode', '', '[← dictionary index](index.md)', '']
    L += ['Every leaf of the encoding has a chart here. A leaf is a prefix of 3 to 16 bits of the first parcel, a sub-opcode that selects one of its mnemonics, and the pieces of its operands; '
          'there is no `len` field, because the prefix decides the length. The charts are generated by `tools/mkmanual.py` from the grammar `spec/pdp64/pdp64.hbnf` (the parts of `spec/grammars.d/`), '
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
        L.append('* <a id="mn-%s"></a>`%s`: %s' % (re.sub(r'[^a-z0-9]', '-', n), wlabel(n), ', '.join(refs)))
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
    global FIGS, DFIGS, MN, CH
    FIGS = {}
    DFIGS = {}
    MN = manual_mn()
    CH = Charts()
    chart_files(CH)
    # a chart for every opcode: no mnemonic without a layout, no chart without a mnemonic, and (prefix-coded) a chart for every leaf of the grammar
    nochart = [n for n, m in MN.items() if not m['alias_of'] and not CH.byname.get(n)]
    if nochart:
        raise SystemExit('mnemonics with no bit layout in the grammar: ' + ' '.join(sorted(nochart)))
    used = {cid for v in CH.byname.values() for cid, _ in v}
    orphan = [c['id'] for c in CH.charts if c['id'] not in used]
    if orphan:
        raise SystemExit('charts for no mnemonic: ' + ' '.join(orphan))
    if CH.enc and len(CH.charts) != len(CH.enc.d['leaves']):
        raise SystemExit('%d charts for %d leaves' % (len(CH.charts), len(CH.enc.d['leaves'])))
    files = {}
    chapters = {}
    allents = D.ENTRIES
    ents = [e for e in allents if e['id'] not in D.HELD]   # a proposed or stub entry is held back (isa_entries.HELD): its text is in docs/design/src/appendix-parts/09-proposed.md or 09-open.md
    seen = {}
    for e in ents:
        for n in e['names']:
            if n not in MN:
                raise SystemExit('entry %s names %r, which is not in the specification' % (e['id'], n))
            if n in seen:
                raise SystemExit('%r is in entries %s and %s' % (n, seen[n], e['id']))
            seen[n] = e['id']
        e['kind'] = MN[([x for x in e['names'] if not MN[x]['alias_of']] or e['names'])[0]]['kind']
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
        fn, sec = HOME[e['id']][0], R(HOME[e['id']][1])
        e2 = dict(e)
        e2['names'] = e['names'] + e['aliases']
        heads.setdefault((fn, sec), []).append(render_entry(e2))
    for (fn, sec), parts in sorted(heads.items()):
        texts[fn] = embed(texts[fn], 'entries:' + sec, '\n\n'.join(p.strip('\n') + '\n' for p in parts))
    texts['09-isa.md'] = embed(texts['09-isa.md'], 'notation', notation(), after_heading=True)
    # the counts of the instruction set are never typed: @@COUNT:words@@, @@COUNT:leaves@@ and @@COUNT:vector@@ in the chapters
    _vec = [n for e in D.ENTRIES if e in D.isa_vec.ENTRIES for n in e['names'] if not MN[n]['alias_of']]
    _count = {'words': sum(1 for m in MN.values() if not m['alias_of']), 'leaves': len(CH.charts), 'vector': len(_vec)}
    for _fn in texts:
        texts[_fn] = re.sub(r'@@COUNT:(\w+)@@', lambda m: '{:,}'.format(_count[m.group(1)]) if m.group(1) in _count else m.group(0), texts[_fn])
    # the official entries live in the instruction chapter; the chapters that give the rationale list them and link to them
    for fn, sec, home in (('06-kernel.md', R('kernel-system-instructions-exceptions'), 'isa-system-instructions-exceptions'), ('07-smp.md', R('atomic-operations'), 'atomics-and-ordering')):
        rows = ['**The instruction entries for this section are in chapter {{c:id01009|n}}, section %s:** each entry there is complete (syntax, encoding diagram, operation, exceptions, status); the commentary above gives the reasons and the use.' % R(home), '',
                '| Entry | Mnemonics |', '|---|---|']
        for e in ents:
            if HOME[e['id']] == ('09-isa.md', home):
                mn = ', '.join('`%s`' % w.rstrip('_') for w in disp_words([n for n in e['names'] if not MN[n]['alias_of']]))
                rows.append('| [%s](09-isa.md#%s) | %s |' % (e['title'], anchor_for(e), mn))
        texts[fn] = embed(texts[fn], 'entries:' + sec, '\n'.join(rows))
    chapters = texts
    # slugs of the sections, for links
    def sec_link(fn, sec):
        m = re.search(r'(?m)^## %s (.*)$' % re.escape(sec), texts[fn])
        return '../%s#%s' % (fn, slug('%s %s' % (sec, m.group(1))))
    # aliases
    EXPANDS = {'rol': ' with the count `#n` complemented to `#(64-n)` (a constant count only)'}
    SEQ = {'abs': '`MOV Rs, R12`, `SAR #63, R12`, `MOV Rs, Rd` (left out when `Rd` is `Rs`), `XOR R12, Rd`, `SUB R12, Rd`',
           'min': '`SETLT Ra, Rb, R12`, `NEG R12`, `BSEL R12, Ra, Rb, Rd`', 'minu': '`SETLO Ra, Rb, R12`, `NEG R12`, `BSEL R12, Ra, Rb, Rd`',
           'max': '`SETGT Ra, Rb, R12`, `NEG R12`, `BSEL R12, Ra, Rb, Rd`', 'maxu': '`SETHI Ra, Rb, R12`, `NEG R12`, `BSEL R12, Ra, Rb, Rd`'}
    A = ['# Assembler aliases', '', '[← dictionary index](index.md)', '',
         'A mnemonic that assembles to another instruction (`FNEG.F32` and `FABS.F32` to an instruction with an operand of their own, and a `MOV` before it when the registers differ; `ROL` to `ROR` with the count complemented) or to a short fixed sequence of instructions (`ABS`, `MIN.S64`, `MIN.U64`, `MAX.S64` and `MAX.U64`, which write the scratch register `R12`). One mnemonic is one instruction (section {{r:idioms-restored-lost-and-replaced}}); the disassembler never prints an alias. A width and kind suffix (`MOV.S8`, `AADD.S32`, `ROR.S32`) is not an alias: it is the notation of the width and kind of one operation. The table ends with the explicit spellings that say what the bare name says (`MOV.S64` is `MOV`), and the spellings where the kind means nothing (`MOV.U8` as a store is `MOV.S8`).', '',
         '*Generated by `tools/mkmanual.py` from `spec/grammars.d`; do not edit.*', '', '| Written | Assembles to | Group |', '|---|---|---|']
    A.append('| `FNEG.F32` | `XOR` with the operand `#-2147483648` (after `MOV Rs, Rd` if the registers differ) | `alu` |')
    A.append('| `FABS.F32` | `AND` with the operand `#0x7FFFFFFF` (after `MOV Rs, Rd` if the registers differ) | `alu` |')
    for n, m in sorted(MN.items()):
        if n in INTERNAL and n not in SEQ: continue
        if m['alias_of']:
            if n in SEQ: A.append('| `%s` | the sequence %s | `%s` |' % (wlabel(n), SEQ[n], m['group'][3:]))
            else: A.append('| `%s` | `%s`%s | `%s` |' % (n.upper(), wlabel(m['alias_of']), EXPANDS.get(n, ''), m['group'][3:]))
    for sp, w, fl, shown in ROWS:
        if not shown and w in MN and sp != wlabel(w).lower() and w not in INTERNAL | {'minu', 'maxu'}:
            A.append('| `%s` | `%s` | `%s` |' % (sp.upper(), wlabel(w), MN[w]['group'][3:]))
        elif not shown and w in MN:
            A.append('| `%s` | `%s` | `%s` |' % (sp.upper(), wlabel(w), MN[w]['group'][3:]))
    A.append('')
    files['aliases.md'] = '\n'.join(A)
    # by mnemonic
    byid = {e['id']: e for e in ents}
    by = ['# The mnemonics, alphabetically', '', '[← dictionary index](index.md)', '',
          '*Generated by `tools/mkmanual.py`; do not edit.*', '']
    by += ['| Mnemonic | Entry | Layouts | Group |', '|---|---|---|---|']
    spell_rows = [(sp.upper(), w) for sp, w, fl, shown in ROWS if w in MN]
    for label, n in sorted([(wlabel(n), n) for n in MN if n not in INTERNAL or n in SEQ] + spell_rows):
        if n in D.HELD_NAMES:
            continue
        m = MN[n]
        tgt = m['alias_of'] or n
        eid = seen.get(n) or seen.get(tgt)
        e = byid[eid]
        fn, sec = HOME[eid][0], R(HOME[eid][1])
        head = '`%s`%s | [%s](%s) (section %s)' % (label, (' (assembler alias, a sequence)' if n in SEQ else ' (alias of `%s`)' % wlabel(tgt)) if m['alias_of'] else (' (the same instruction as `%s`)' % wlabel(n)) if label != wlabel(n) and label != n.upper() else '', eid, '../%s#%s' % (fn, anchor_for(e)), sec)
        nl = len(CH.byname.get(tgt, []))
        lay = '[%d](by-encoding.md#mn-%s), [entry](../%s#w-%s)' % (nl, re.sub(r'[^a-z0-9]', '-', tgt), HOME[eid][0], wslug(tgt))
        if n in SEQ: lay = '[entry](../%s#w-%s)' % (HOME[eid][0], wslug(n))
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
    for (fn, home), es in sorted(where.items(), key=lambda kv: [int(x) for x in R(kv[0][1]).split('.')] + [0]):
        sec = R(home)
        m = re.search(r'(?m)^## %s (.*)$' % re.escape(sec), texts[fn])
        I.append('* [Section %s, %s](%s): %s' % (sec, m.group(1), sec_link(fn, sec), ', '.join('`%s`' % disp_words(e['names'])[0] for e in es)))
    I.append('')
    I.append('## The tables')
    I.append('')
    I.append('* [Assembler aliases](aliases.md)')
    I.append('* [The architectural constants](constants.md)')
    I.append('* [The mnemonics, alphabetically](by-mnemonic.md)')
    I.append('* [The bit layouts of every opcode](by-encoding.md): a chart for each layout, generated from the grammar')
    I.append('')
    vis = {n: m for n, m in MN.items() if n not in D.HELD_NAMES and n not in INTERNAL}
    for sp, w, fl, shown in ROWS:				# a spelling that is printed for its word is the instruction; the other spellings (the explicit 64-bit ones, the unsigned stores) are aliases
        if w in MN and sp not in vis: vis[sp] = dict(alias_of=None if shown else w, kind=MN[w]['kind'])
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
    # the figures of chapter 9 that the text refers to by name, drawn from the grammars (the status word from spec/grammars.d/50-system-v1.hbnf)
    used = '\n'.join(texts.values())
    usedD = '\n'.join(design_notes(texts).values())      # a figure that only a design note shows is written beside it, in docs/design/figures/
    if 'figures/psw.svg' in used:
        fig('psw', 'The processor status word', LAY.psw_chart(SYS))
    for fname, (_alt, draw) in list(BUSFIGS.FIGURES.items()) + list(GFXFIGS.FIGURES.items()) + list(KERNFIGS.FIGURES.items()) + list(BOOTFIGS.FIGURES.items()) + list(DRVFIGS.FIGURES.items()) + list(INTROFIGS.FIGURES.items()) + list(VECFIGS.FIGURES.items()) + list(SMPFIGS.FIGURES.items()):     # the box-and-arrow figures of chapters 2 to 6 (tools/manual/busfigs.py, gfxfigs.py, bootfigs.py, drvfigs.py, kernfigs.py, vecfigs.py, smpfigs.py); not instruction encodings
        if 'figures/%s.svg' % fname in used:
            FIGS[fname + '.svg'] = draw()
        elif 'figures/%s.svg' % fname in usedD:
            DFIGS[fname + '.svg'] = draw()
    for d in (files, chapters, FIGS, DFIGS):             # the tokens of the generated text (the entries, the dictionary, the figures)
        for k in d:
            d[k] = resolve_measures(d[k], k)
            if '@@MEASURE' in d[k]:
                raise SystemExit('%s: a @@MEASURE token that is not written correctly' % k)
            d[k] = BOOK.resolve(d[k], k)
            m = re.search(r'\{\{[#rcuan]\b.{0,40}', d[k])
            if m:
                raise SystemExit('%s: a token of the numbering syntax that is not written correctly: %s' % (k, m.group(0)))
    return files, chapters


def anchor_for(e):
    return slug('%s: %s' % (e['id'], e['title']))


def anchors_of(text):
    """the anchors of the headings and of the `<a id>` marks of a page (as assemble.verify finds them)"""
    a, fence = set(), False
    for line in text.split('\n'):
        if line.startswith('```'):
            fence = not fence
        if not fence:
            h = re.match(r'^#{1,6} (.*)$', line)
            if h:
                a.add(ASM.slug(h.group(1).strip()))
    return a | set(re.findall(r'<a id="([^"]+)"', text))


def sync(base, rel, check, keep=None):
    """write the files of `rel` (relative name -> text) under `base`, or with check say which differ; files that are on disk and no longer generated are removed (keep: a test of the
    relative names that are generated, for a directory that also holds hand-written files).  Returns True if a check failed."""
    bad = False
    on_disk = set()
    if os.path.isdir(base):
        for d, _, fs in os.walk(base):
            for f in fs:
                r = os.path.relpath(os.path.join(d, f), base)
                if keep is None or keep(r):
                    on_disk.add(r)
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
    return bad


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
    for pr in ASM.verify(rel, set(rel), base, labels=labels()):
        print(pr)
        bad = True
    # the design notes: their numbers contiguous, their links and references with targets (the links into the manual too)
    design = design_notes(sources())
    foreign = {'../manual/' + n: anchors_of(t) for n, t in rel.items() if n.endswith('.md')}
    drel = dict(design)
    for name, text in DFIGS.items():
        drel['figures/' + name] = text
    for pr in ASM.verify(design, set(drel), DESIGN, design=True, foreign=foreign):
        print('docs/design/' + pr)
        bad = True
    bad |= sync(base, rel, check)
    bad |= sync(DESIGN, drel, check, keep=lambda r: r in DESIGNFILES.values() or r.startswith('figures/'))
    if not check:
        print('pdp64: wrote %d dictionary pages, %d figures and %d chapters; %d design notes' % (len(files), len(FIGS), len(chapters), len(design)))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    try:
        main()
    except BR.RefError as e:              # an unknown or doubly defined name, a marker where it has no number: the message says which file and line
        print('mkmanual: ' + str(e))
        sys.exit(1)

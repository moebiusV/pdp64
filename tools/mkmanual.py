#!/usr/bin/env python3
"""Generate the instruction dictionary of the manual (docs/streamlined/dictionary/).

Every number comes from spec/pdp64-mnemonics.hbnf, the one place the architecture's numbers are written, so the dictionary
cannot drift from the assembler and the simulators; the words (operation, flags, exceptions) are in tools/manual/isa_entries.py.
Whether an instruction is implemented in the reference executor is read from common/pdp64exec.c.

    tools/mkmanual.py            write the dictionary
    tools/mkmanual.py --check    exit 1 if a mnemonic has no entry, an entry names a mnemonic that does not exist, or the files differ
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'manual'))
import isa_entries as D

OUT = os.path.join(ROOT, 'docs', 'streamlined', 'dictionary')
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
KIND = {'mn-mov': 'mem', 'mn-movz': 'mem', 'mn-lea': 'mem', 'mn-alu': 'mem', 'mn-branch': 'br', 'mn-cbranch': 'cb',
        'mn-sob': 'sob', 'mn-tag': 'tag', 'mn-sop': 'sop', 'mn-xfer': 'xfer', 'mn-besc': 'besc', 'mn-mblk': 'mblk',
        'mn-aesc': 'aesc', 'mn-fesc': 'fesc', 'mn-atom': 'atom', 'mn-mesc': 'mesc', 'mn-sys-none': 'sysn',
        'mn-sysx': 'sysx', 'mn-sysreg': 'sysreg', 'mn-sys': 'sys', 'subop': 'aesc'}
GROUPNAME = {'mem': 'Moves, address formation and the ALU', 'br': 'Branches', 'cb': 'Branches', 'sob': 'Branches',
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


MN = mnemonics()
EXECTEXT = open(EXEC).read()


def implemented(name):
    """Does the reference executor have a case for this mnemonic?"""
    m = MN[name]
    g = m['group'][3:].upper().replace('-', '_')
    pat = {'mn-sys-none': 'MN_SYS_NONE_', 'mn-sysx': 'MN_SYSX_', 'mn-sysreg': 'MN_SYSREG_', 'mn-sys': 'MN_SYS_'}.get(m['group'], 'MN_%s_' % g)
    key = pat + name.upper().replace('_', '_')
    if name in ('mfsr', 'mtsr'):
        key = 'MN_SYSREG_' + name.upper()
    if key in EXECTEXT or (name == 'set' and 'SUBOP_SET' in EXECTEXT):
        return True
    if m['kind'] in ('mem',) and m['group'] in ('mn-mov', 'mn-movz', 'mn-lea'):
        return True
    if m['kind'] in ('br', 'cb', 'sob', 'tag'):
        return True
    return False


def bits(v, w):
    return format(v, '0%db' % w)


FIGDIR = os.path.join(ROOT, 'docs', 'streamlined', 'figures')
FIGS = {}                                     # file name -> svg text, written by main()


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def svg_rows(rows):
    """rows: [(row label, [(field label, width in bits, value or None), ...]), ...]; each row is one 16-bit parcel.
    Draws the parcel as a row of boxes, widths proportional to the bits, bit numbers above, the fixed values shaded."""
    unit, left, top, rh, gap = 38, 74, 16, 36, 16
    width = left + 16 * unit + 8
    out = []
    y = 4
    for lab, fields in rows:
        pos = 15
        out.append('<text x="%d" y="%d" font-size="11" text-anchor="end" fill="#444">%s</text>' % (left - 8, y + top + rh // 2 + 4, esc(lab)))
        for fl, w, val in fields:
            x = left + (15 - pos) * unit
            hi, lo = pos, pos - w + 1
            fixed = val is not None and re.match(r'^(0x|\d)', str(val)) is not None
            fill = '#e8e8e8' if fixed else '#ffffff'
            out.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s" stroke="#222" stroke-width="1.2"/>' % (x, y + top, w * unit, rh, fill))
            out.append('<text x="%d" y="%d" font-size="9" fill="#555" text-anchor="start">%d</text>' % (x + 2, y + top - 4, hi))
            if lo != hi:
                out.append('<text x="%d" y="%d" font-size="9" fill="#555" text-anchor="end">%d</text>' % (x + w * unit - 2, y + top - 4, lo))
            cx = x + w * unit / 2
            if val is None:
                out.append('<text x="%.1f" y="%d" font-size="13" text-anchor="middle" font-family="DejaVu Sans, sans-serif">%s</text>' % (cx, y + top + rh // 2 + 5, esc(fl)))
            else:
                out.append('<text x="%.1f" y="%d" font-size="10" text-anchor="middle" font-family="DejaVu Sans, sans-serif" fill="#333">%s</text>' % (cx, y + top + 14, esc(fl)))
                out.append('<text x="%.1f" y="%d" font-size="12" text-anchor="middle" font-family="DejaVu Sans Mono, monospace" font-weight="bold">%s</text>' % (cx, y + top + 29, esc(str(val))))
            pos -= w
        y += top + rh + gap - 4
    h = y + 4
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="DejaVu Sans, sans-serif">\n%s\n</svg>\n'
            % (width, h, width, h, '\n'.join(out)))


def fig(name, alt, rows):
    """Record a figure and return the Markdown that shows it."""
    FIGS[name + '.svg'] = svg_rows(rows)
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


def encoding(entry):
    """The Encoding part of an entry: a figure of the parcels and the numbers of this entry's words."""
    k = entry['kind']
    eid = entry['id'].lower()
    L = []
    names = [n for n in entry['names'] if not MN[n]['alias_of']]
    first = names[0]
    opc, sub = opcode_of(first)
    one = len(names) == 1
    U = lambda x: x.upper()

    def table(head, rows):
        if len(rows) > 1:
            L.append('| Mnemonic | %s |\n|---|---|\n' % head + '\n'.join(rows))

    if k == 'mem':
        o = OPGROUP['lea'] if MN[first]['group'] == 'mn-lea' else opc
        L.append(fig(eid, 'Encoding of %s' % entry['id'], [('parcel 0', [('len', 2, None), ('opcode', 6, B(o, 6) if one else B(o, 6) + '..'), ('reg', 4, None), ('low', 4, None)])]))
        L.append('`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00`, where the instruction is two bytes. At `len = 01` or `10`, `low` is the addressing mode and parcel 1 (and 2) carry the operand (section 9.5).')
        table('Opcode (the load or direct form)', ['| `%s` | `%s` |' % (U(n), BH(MN[n]['value'] if MN[n]['group'] != 'mn-lea' else OPGROUP['lea'], 6)) for n in names])
        if entry.get('names') and any(MN[n]['group'] == 'mn-mov' for n in names):
            L.append('The store form of each move has the opcode of its load form plus 1: ' + ', '.join('`%s` `%s`' % (U(n), BH(MN[n]['value'] + 1, 6)) for n in names if MN[n]['group'] == 'mn-mov') + '.')
    elif k == 'br':
        L.append(fig(eid, 'Encoding of the conditional branches', [('len = 00', [('len', 2, '00'), ('opcode', 6, '110000..111110'), ('displacement', 8, None)]),
                                                                   ('len = 01', [('displacement (16 bits, parcel 1)', 16, None)])]))
        L.append('The displacement is signed and counts 2-byte parcels from the first parcel of the instruction: 8 bits at `len = 00` (about ±256 bytes), 16 bits at `len = 01` (±64 KB), 32 bits in parcels 1 and 2 at `len = 10` (±4 GB).')
        table('Opcode', ['| `%s` | `%s` (condition %d) |' % (U(n), BH(MN[n]['value'], 6), MN[n]['value'] & 15) for n in names])
    elif k == 'cb':
        L.append(fig(eid + '-cbcc', 'Encoding of CBCC', [('parcel 0', [('len', 2, '01'), ('opcode', 6, '101000'), ('reg', 4, 'Rd'), ('low', 4, 'cond')]),
                                                       ('parcel 1', [('imm', 5, None), ('disp', 11, None)])]))
        L.append('`CBCC` (opcode `101000 (0x28)`), four bytes: a signed 5-bit immediate (-16 to 15) and an 11-bit displacement in parcels. At `len = 10` (six bytes) parcel 1 is `imm(5) disp(26..16)` and parcel 2 `disp(15..0)`.')
        L.append(fig(eid + '-cbw', 'Encoding of CBW', [('parcel 0', [('len', 2, '10'), ('opcode', 6, '101001'), ('reg', 4, 'Rd'), ('low', 4, 'cond')]),
                                                     ('parcel 1', [('imm16', 16, None)]), ('parcel 2', [('disp16', 16, None)])]))
        L.append('`CBW` (opcode `101001 (0x29)`), six bytes: a 16-bit immediate and a 16-bit displacement in parcels.')
        L.append(fig(eid + '-cbrr', 'Encoding of CBRR', [('parcel 0', [('len', 2, '01'), ('opcode', 6, '101010'), ('reg', 4, 'Ra'), ('low', 4, 'Rb')]),
                                                       ('parcel 1', [('cond', 4, None), ('disp', 12, None)])]))
        L.append('`CBRR` (opcode `101010 (0x2A)`), four bytes (six at `len = 10`, with a 28-bit displacement): compares two registers. The condition numbers are those of the branches: `al` 0, `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. There is no `len = 00` form.')
    elif k == 'sob':
        L.append(fig(eid, 'Encoding of SOB', [('parcel 0', [('len', 2, None), ('opcode', 6, '111111'), ('reg', 4, 'Rn'), ('low', 4, '0')]), ('parcel 1', [('displacement (parcels)', 16, None)])]))
        L.append('From `len = 01`; the signed displacement is 16 bits (32 at `len = 10`).')
    elif k == 'tag':
        L.append(fig(eid, 'Encoding of BTAG and BNTAG', [('parcel 0', [('len', 2, '01'), ('opcode', 6, '010101'), ('reg', 4, 'Rn'), ('low', 1, 'sense'), ('tag', 3, None)]), ('parcel 1', [('displacement (parcels)', 16, None)])]))
        L.append('`sense` is 0 for `BTAG` and 1 for `BNTAG`; `tag` is the 3-bit tag. The displacement is 16 bits (32 at `len = 10`).')
    elif k in ('sop', 'xfer'):
        L.append(fig(eid, 'Encoding of %s' % entry['id'], [('parcel 0', [('len', 2, None), ('opcode', 6, B(opc, 6)), ('reg', 4, B(MN[first]['value'], 4) if one else None), ('low', 4, None)])]))
        L.append('The `reg` field is the sub-opcode; `rm` and the mode give the single operand, at any length (section 9.5).')
        table('`reg` (sub-opcode)', ['| `%s` | `%s` |' % (U(n), BH(MN[n]['value'], 4)) for n in names])
    elif k in ('besc', 'aesc', 'fesc', 'atom'):
        rows = [('parcel 0', [('len', 2, None), ('opcode', 6, B(opc, 6)), ('reg', 4, 'Rd'), ('low', 4, 'Rs')])]
        if entry['id'] in ('RORI', 'RORI32'):
            rows.append(('parcel 1', [('sub-opcode', 8, B(MN[first]['value'], 8)), ('count', 8, None)]))
        elif entry['id'] in ('EXTB', 'INSB', 'DSHR'):
            rows.append(('parcel 1', [('sub-opcode', 8, B(MN[first]['value'], 8) if one else None), ('t', 4, 'Rt'), ('x', 4, None)]))
            rows.append(('parcel 2', [('pos' if entry['id'] != 'DSHR' else 'count', 8, None), ('width' if entry['id'] != 'DSHR' else 'unused', 8, None)]))
        else:
            rows.append(('parcel 1', [('sub-opcode', 8, B(MN[first]['value'], 8) if one else None), ('t', 4, 'Rt'), ('x', 4, None)]))
        L.append(fig(eid, 'Encoding of %s' % entry['id'], rows))
        L.append('From `len = 01`. In this group `low` is a register, never a mode. ' + entry.get('xnote', ''))
        table('Sub-opcode', ['| `%s` | `%s` |' % (U(n), BH(MN[n]['value'], 8)) for n in names])
    elif k == 'mblk':
        L.append(fig(eid, 'Encoding of %s' % entry['id'], [('parcel 0', [('len', 2, None), ('opcode', 6, '001101'), ('reg', 4, 'Rd'), ('low', 4, 'Rs')]),
                                                           ('parcel 1', [('sub-opcode', 8, B(MN[first]['value'], 8) if one else None), ('t', 4, 'Rn'), ('x', 4, 'flags')])]))
        L.append('`reg` is the destination pointer, `low` the source pointer (or the value register `Rv`), parcel 1 `t` the count register `Rn`.')
        table('Sub-opcode', ['| `%s` | `%s` |' % (U(n), BH(MN[n]['value'], 8)) for n in names])
    elif k == 'mesc':
        L.append(fig(eid, 'Encoding of %s' % entry['id'], [('parcel 0', [('len', 2, None), ('opcode', 6, '001111'), ('reg', 4, 'Rs/Rd'), ('low', 4, 'mode')]),
                                                           ('parcel 1', [('sub', 4, None), ('rm', 4, None), ('disp', 8, None)])]))
        L.append("Parcel 0's `low` is an addressing mode, as in the ordinary memory format; parcel 1 is `sub(4) rm(4) disp(8)` (16 more displacement bits per further parcel).")
        table('Sub-opcode', ['| `%s` | `%s` |' % (U(n), BH(MN[n]['value'], 4)) for n in names])
    elif k in ('sysn', 'sysx', 'sysreg', 'sys'):
        L.append(fig(eid, 'Encoding of %s' % entry['id'], [('parcel 0', [('len', 2, None), ('opcode', 6, '010100'), ('reg', 4, 'class'), ('low', 4, 'rm / minor')])]))
        L.append('The `reg` field is the **class**. Class 0 takes a minor opcode from `low`; the other classes take a register or a 4-bit immediate from `low`.')
        rows = []
        for n in names:
            m = MN[n]
            if m['kind'] == 'sysn':
                rows.append('| `%s` | 0 | `%s` |' % (U(n), BH(m['value'], 4)))
            elif m['kind'] == 'sysx':
                rows.append('| `%s` | 0 | `1111 (0xF)` (`SYSX`), sub-opcode `%d` in parcel 1 |' % (U(n), m['value']))
            elif m['kind'] == 'sysreg':
                rows.append('| `%s` | 0 | `%s`, system register number in parcel 1 |' % (U(n), BH(m['value'], 4)))
            else:
                rows.append('| `%s` | `%s` | operand in `low` |' % (U(n), BH(m['value'], 4)))
        L.append('| Mnemonic | Class (`reg`) | Minor (`low`) |\n|---|---|---|\n' + '\n'.join(rows))
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


def render_entry(e):
    names = e['names']
    real = [n for n in names if not MN[n]['alias_of']]
    heads = ', '.join('`%s`' % n.upper().rstrip('_').replace('XOR_', 'XOR_') for n in names if not MN[n]['alias_of'])
    out = ['### %s: %s' % (e['id'], e['title']), '']
    out.append('**Mnemonics:** ' + heads + (('  (aliases: ' + ', '.join('`%s`' % n.upper() for n in names if MN[n]['alias_of']) + ')') if any(MN[n]['alias_of'] for n in names) else ''))
    out.append('')
    out.append('**Syntax**\n')
    out.append('```\n' + '\n'.join(e['syntax']) + '\n```')
    out.append('')
    out.append('**Encoding**\n')
    out.append(encoding(e))
    out.append('')
    out.append('**Operation**\n')
    out.append('```\n' + uni(e['op'].strip('\n')) + '\n```')
    out.append('')
    out.append('**Flags** ' + e['flags'])
    out.append('')
    out.append('**Exceptions** ' + e['exc'])
    out.append('')
    if e.get('notes'):
        out.append(e['notes'].replace('{{SYSREGS}}', sysreg_table()))
        out.append('')
    impl = [n for n in real if implemented(n)]
    if len(impl) == len(real):
        st = 'implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU)'
    elif not impl:
        st = 'specified; **not yet implemented** in the reference executor'
    else:
        st = 'implemented in the reference executor for ' + ', '.join('`%s`' % n.upper() for n in impl) + '; not yet for the others'
    if D.STORY.get(e['id']):
        out.append('**Why it is here.** ' + D.STORY[e['id']])
        out.append('')
    if e.get('cf'):
        out.append('**Cf.** ' + e['cf'])
        out.append('')
    out.append('**Status** ' + st + '.')
    out.append('')
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
    L.append('Bits 12 to 15 are reserved and read as zero. Bit 12 is the user-memory guard `UA` of errata 43 (not yet in the specification file).')
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
    L.append('Modes `1000` to `1111` are reserved. The syntax and the parcel layout of each mode are in the book, section 9.5.')
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
CHAPDIR = os.path.join(ROOT, 'docs', 'streamlined')


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


def build():
    files = {}
    chapters = {}
    ents = D.ENTRIES
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
    badstory = set(D.STORY) - {e['id'] for e in ents}
    if badstory:
        raise SystemExit('stories for entries that do not exist: ' + ' '.join(sorted(badstory)))
    unused = set(HOME) - {e['id'] for e in ents}
    if unused:
        raise SystemExit('home sections for entries that do not exist: ' + ' '.join(sorted(unused)))
    missing = [n for n, m in MN.items() if n not in seen and not (m['alias_of'] and m['alias_of'] in seen)]
    if missing:
        raise SystemExit('mnemonics with no entry: ' + ' '.join(sorted(missing)))
    alias_of = {n: m['alias_of'] for n, m in MN.items() if m['alias_of']}
    for e in ents:
        e['aliases'] = [a for a, t in alias_of.items() if t in e['names'] and a not in e['names']]
    # the entries, into the sections of the chapters
    texts = {}
    heads = {}
    for e in ents:
        fn, sec = HOME[e['id']]
        if fn not in texts:
            texts[fn] = open(os.path.join(CHAPDIR, fn)).read()
        e2 = dict(e)
        e2['names'] = e['names'] + e['aliases']
        heads.setdefault((fn, sec), []).append(render_entry(e2))
    for (fn, sec), parts in sorted(heads.items()):
        texts[fn] = embed(texts[fn], 'entries:' + sec, '\n\n'.join(p.strip('\n') + '\n' for p in parts))
    texts['09-isa.md'] = embed(texts['09-isa.md'], 'notation', D.NOTATION, after_heading=True)
    # the official entries live in the instruction chapter; the chapters that give the rationale list them and link to them
    for fn, sec, home in (('06-kernel.md', '6.7', '9.14'), ('07-smp.md', '7.12', '9.13')):
        rows = ['**The instruction entries for this section are in chapter 9, section %s:** each entry there is complete (syntax, encoding diagram, operation, flags, exceptions, status); this chapter gives the reasons, the history and the use.' % home, '',
                '| Entry | Mnemonics |', '|---|---|']
        for e in ents:
            if HOME[e['id']] == ('09-isa.md', home):
                mn = ', '.join('`%s`' % n.upper().rstrip('_') for n in e['names'] if not MN[n]['alias_of'])
                rows.append('| [%s](09-isa.md#%s) | %s |' % (e['title'], anchor_for(e), mn))
        if fn not in texts:
            texts[fn] = open(os.path.join(CHAPDIR, fn)).read()
        texts[fn] = embed(texts[fn], 'entries:' + sec, '\n'.join(rows))
    chapters = texts
    # slugs of the sections, for links
    def sec_link(fn, sec):
        m = re.search(r'(?m)^## %s (.*)$' % re.escape(sec), texts[fn])
        return '../%s#%s' % (fn, slug('%s %s' % (sec, m.group(1))))
    # page 2
    P2 = ['# The second page: one-parcel abbreviations', '', '[← dictionary index](index.md)', '', D.P2_INTRO, '',
          '*Generated by `tools/mkmanual.py` from `spec/pdp64-mnemonics.hbnf` and `tools/manual/isa_entries.py`; do not edit.*', '',
          fig('page2', 'Layout of a page-2 instruction', [('parcel 0', [('len', 2, '11'), ('opc', 6, None), ('reg', 4, None), ('low', 4, None)])]), '',
          '| Opcode | Name | Operation | `reg` | `low` | Long form it abbreviates |', '|---|---|---|---|---|---|']
    p2 = SPEC['p2op']
    pnames = {n for n, _ in p2}
    miss2 = pnames - set(D.P2)
    if miss2:
        raise SystemExit('page-2 opcodes with no description: ' + ' '.join(sorted(miss2)))
    extra2 = set(D.P2) - pnames
    if extra2:
        raise SystemExit('page-2 descriptions for opcodes that do not exist: ' + ' '.join(sorted(extra2)))
    for n, v in p2:
        op, reg, low, longf = D.P2[n]
        P2.append('| `%s` | `%s` | %s | %s | %s | %s |' % (BH(v, 6), n, op, reg, low, longf))
    P2.append('')
    P2.append('Every page-2 opcode not listed (`001111 (0x0F)` and `101110 (0x2E)` to `111111 (0x3F)`, %d of 64) is reserved; a reserved page-2 opcode is an illegal-instruction abort.' % (64 - len(p2)))
    P2.append('')
    P2.append('## Why there is a second page')
    P2.append('')
    P2.append(D.P2_STORY)
    P2.append('')
    files['page2.md'] = '\n'.join(P2).replace('](figures/', '](../figures/')
    # aliases
    A = ['# Assembler aliases and old spellings', '', '[← dictionary index](index.md)', '',
         'A mnemonic that assembles to another instruction. One mnemonic is one instruction (book section 9.18); the disassembler never prints an alias.', '',
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
          '*Generated by `tools/mkmanual.py`; do not edit.*', '', '| Mnemonic | Entry | Opcode | Sub | Group |', '|---|---|---|---|---|']
    for n in sorted(MN):
        m = MN[n]
        tgt = m['alias_of'] or n
        eid = seen.get(n) or seen.get(tgt)
        e = byid[eid]
        fn, sec = HOME[eid]
        o, s = opcode_of(tgt)
        sub = '' if s is None else ('`%s`' % BH(s, 4 if m['kind'] in ('sop', 'xfer', 'sysn', 'sysx', 'sysreg', 'sys') else 8))
        by.append('| `%s`%s | [%s](%s) (section %s) | `%s` | %s | %s |' % (n.upper(), ' (alias of `%s`)' % tgt.upper() if m['alias_of'] else '', eid, '../%s#%s' % (fn, anchor_for(e)), sec, BH(o, 6), sub, GROUPNAME[m['kind']]))
    by.append('')
    files['by-mnemonic.md'] = '\n'.join(by)
    # by opcode
    bo = ['# The opcodes, in order', '', '[← dictionary index](index.md)', '',
          '*Generated by `tools/mkmanual.py`; do not edit.*', '', '## Page 1', '', '| Opcode | Use |', '|---|---|']
    use = {}
    for n, m in MN.items():
        if m['alias_of']:
            continue
        o, s = opcode_of(n)
        use.setdefault(o, []).append((n, s, m))
    for o in range(64):
        if o in use:
            names = use[o]
            if len(names) > 6:
                text = ', '.join('`%s`' % n.upper() for n, _, _ in names[:5]) + ' and %d more (sub-opcodes in the entries)' % (len(names) - 5)
            else:
                text = ', '.join('`%s`' % n.upper() for n, _, _ in names)
            bo.append('| `%s` | %s |' % (BH(o, 6), text))
        else:
            reserved = {0x23: 'spare ALU slot (decodes, traps)'}.get(o, 'reserved')
            bo.append('| `%s` | %s |' % (BH(o, 6), reserved))
    bo.append('')
    bo.append('## Page 2')
    bo.append('')
    bo.append('| Opcode | Name |')
    bo.append('|---|---|')
    for n, v in SPEC['p2op']:
        bo.append('| `%s` | `%s` |' % (BH(v, 6), n))
    bo.append('')
    files['by-opcode.md'] = '\n'.join(bo)
    files['constants.md'] = constants_page()
    # index
    I = ['# The instruction reference tables', '', '[← manual index](../00-index.md)', '', D.INDEX_INTRO, '', '## Where the entries are', '']
    where = {}
    for e in ents:
        where.setdefault(HOME[e['id']], []).append(e)
    for (fn, sec), es in sorted(where.items(), key=lambda kv: [int(x) for x in kv[0][1].split('.')] + [0]):
        m = re.search(r'(?m)^## %s (.*)$' % re.escape(sec), texts[fn])
        I.append('* [Section %s, %s](%s): %s' % (sec, m.group(1), sec_link(fn, sec), ', '.join('`%s`' % e['names'][0].upper() for e in es)))
    I.append('')
    I.append('## The tables')
    I.append('')
    I.append('* [The second page: one-parcel abbreviations](page2.md)')
    I.append('* [Assembler aliases and old spellings](aliases.md)')
    I.append('* [The architectural constants](constants.md)')
    I.append('* [The mnemonics, alphabetically](by-mnemonic.md)')
    I.append('* [The opcodes, in order](by-opcode.md)')
    I.append('')
    n_real = sum(1 for m in MN.values() if not m['alias_of'])
    n_alias = sum(1 for m in MN.values() if m['alias_of'])
    n_impl = sum(1 for n, m in MN.items() if not m['alias_of'] and implemented(n))
    I.append('The specification has %d mnemonic words (%d instructions and %d aliases) and %d page-2 opcodes; the reference executor implements %d of the %d instructions; the rest are specified and have entries marked as not yet implemented.' % (len(MN), n_real, n_alias, len(SPEC['p2op']), n_impl, n_real))
    I.append('')
    I.append('*Generated by `tools/mkmanual.py`; do not edit.*')
    I.append('')
    files['index.md'] = '\n'.join(I)
    # the figures of the instruction format in chapter 9 (the chapter refers to them by name)
    fig('format-parcel0', 'The first parcel of every instruction', [('parcel 0', [('len', 2, None), ('opcode', 6, None), ('reg', 4, None), ('low (mode / rm)', 4, None)])])
    fig('format-extension', 'The extension parcels and the second page', [
        ('len = 01, parcel 1', [('rm', 4, None), ('displacement (11..0)', 12, None)]),
        ('len = 10, parcel 1', [('rm', 4, None), ('displacement (27..16)', 12, None)]),
        ('len = 10, parcel 2', [('displacement (15..0)', 16, None)]),
        ('len = 11 (page 2)', [('len', 2, '11'), ('opc', 6, None), ('reg', 4, None), ('low', 4, None)])])
    fig('psw', 'The processor status word', [('PSW', [('reserved', 3, None), ('UA', 1, None), ('prev', 2, None), ('mode', 2, None), ('priority', 3, None), ('T', 1, None), ('N', 1, None), ('Z', 1, None), ('V', 1, None), ('C', 1, None)])])
    return files, chapters


def anchor_for(e):
    return slug('%s: %s' % (e['id'], e['title']))


def main():
    files, chapters = build()
    check = '--check' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(FIGDIR, exist_ok=True)
    bad = False
    targets = {}
    for name, text in files.items():
        targets[os.path.join(OUT, name)] = text
    for fn, text in chapters.items():
        targets[os.path.join(CHAPDIR, fn)] = text
    for name, text in FIGS.items():
        targets[os.path.join(FIGDIR, name)] = text
    for p, text in targets.items():
        if check:
            if not os.path.exists(p) or open(p).read() != text:
                print('stale: ' + os.path.relpath(p, ROOT))
                bad = True
        else:
            open(p, 'w').write(text)
    # figures and dictionary pages that nothing generates any more
    for d, keep in ((FIGDIR, set(FIGS)), (OUT, set(files))):
        for f in os.listdir(d):
            if f not in keep:
                if check:
                    print('stale (no longer generated): ' + os.path.relpath(os.path.join(d, f), ROOT))
                    bad = True
                else:
                    os.remove(os.path.join(d, f))
    if check:
        sys.exit(1 if bad else 0)
    print('wrote %d dictionary pages, %d figures and %d chapters' % (len(files), len(FIGS), len(chapters)))


if __name__ == '__main__':
    main()

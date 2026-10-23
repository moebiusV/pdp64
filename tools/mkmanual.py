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


def parse_spec():
    t = open(HBNF).read()
    groups = {}
    for g, body in re.findall(r'(?m)^([a-z0-9-]+)\s*=(.*?)(?=^\S|\Z)', t, re.S):
        body = re.sub(r';[^\n]*', '', body)
        groups[g] = [(m, num(n)) for m, n in re.findall(r'"([A-Za-z0-9_.#]+)"@(\S+)', body)]
    return groups


SPEC = parse_spec()
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


def diag(fields):
    """fields: list of (label, width, value-or-None). Draws bit numbers and a box."""
    top = ''
    row = ''
    pos = 15
    for lab, w, val in fields:
        cell = (lab if val is None else '%s=%s' % (lab, val))
        cw = max(len(cell) + 2, w * 2)
        hi = pos
        lo = pos - w + 1
        tag = ('%d' % hi) if w == 1 else ('%d..%d' % (hi, lo))
        top += tag.center(cw + 1)
        row += '|' + cell.center(cw)
        pos -= w
    return ' ' + top.rstrip() + '\n' + row + '|'


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
    """Text of the Encoding section: the layout of the group plus the numbers of this entry's words."""
    k = entry['kind']
    L = []
    names = [n for n in entry['names'] if not MN[n]['alias_of']]
    first = names[0]
    opc, sub = opcode_of(first)
    if k == 'mem':
        st = entry.get('store')
        d = diag([('len', 2, None), ('opcode', 6, '0x%02X' % opc), ('reg', 4, 'Rd'), ('low', 4, 'rm/Rs')])
        L.append('```\n' + d + '\n```')
        L.append('`len = 00`: `low` is a second register (`Rs`) and the instruction is two bytes. `len = 01` or `10`: `low` is the addressing mode and parcel 1 (and 2) carry the operand (section 9.5).')
        rows = []
        for n in names:
            o = MN[n]['value']
            rows.append('| `%s` | `0x%02X` |%s' % (n.upper(), o if MN[n]['group'] != 'mn-lea' else OPGROUP['lea'], ''))
        if len(names) > 1:
            L.append('| Mnemonic | Opcode (load or direct form) |\n|---|---|\n' + '\n'.join(r.rstrip('|') + '|' if not r.endswith('|') else r for r in rows))
        if entry.get('store'):
            L.append('The store form of each move has the opcode of its load form plus 1: ' + ', '.join('`%s` `0x%02X`' % (n.upper(), MN[n]['value'] + 1) for n in names if MN[n]['group'] == 'mn-mov') + '.')
    elif k == 'br':
        L.append('```\n' + diag([('len', 2, None), ('opcode', 6, '0x30..0x3E'), ('displacement', 8, None)]) + '\n```')
        L.append('`len = 00`: displacement in bits 7..0 (8 bits, signed, counted in 2-byte parcels from the first parcel of the instruction), reach about ±256 bytes. `len = 01`: a 16-bit displacement in parcel 1 (±64 KB). `len = 10`: a 32-bit displacement in parcels 1 and 2 (±4 GB).')
        L.append('| Mnemonic | Opcode | Condition number |\n|---|---|---|\n' + '\n'.join('| `%s` | `0x%02X` | %d |' % (n.upper(), MN[n]['value'] & 0xFF if MN[n]['value'] < 0x100 else MN[n]['value'] - 0x100, (MN[n]['value'] if MN[n]['value'] < 0x100 else MN[n]['value'] - 0x100) & 15) for n in names))
    elif k == 'cb':
        L.append('Three encodings, chosen by the assembler (the shortest that holds the immediate and the displacement):\n\n'
                 '```\nCBCC (0x28), len=01, four bytes:\n' + diag([('len', 2, '01'), ('opcode', 6, '0x28'), ('reg', 4, 'Rd'), ('low', 4, 'cond')]) + '\n' +
                 diag([('imm', 5, None), ('disp', 11, None)]) + '\n\nCBCC (0x28), len=10, six bytes: parcel 1 = imm(5) disp(26..16); parcel 2 = disp(15..0)\n\n'
                 'CBW (0x29), len=10, six bytes:\n' + diag([('len', 2, '10'), ('opcode', 6, '0x29'), ('reg', 4, 'Rd'), ('low', 4, 'cond')]) + '\n' +
                 diag([('imm16', 16, None)]) + '\n' + diag([('disp16', 16, None)]) + '\n\n'
                 'CBRR (0x2A), len=01, four bytes:\n' + diag([('len', 2, '01'), ('opcode', 6, '0x2A'), ('reg', 4, 'Ra'), ('low', 4, 'Rb')]) + '\n' +
                 diag([('cond', 4, None), ('disp', 12, None)]) + '\n(len=10: six bytes, a 28-bit displacement)\n```')
        L.append('The condition numbers are those of the branches (`al` 0, `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14). The displacement counts 2-byte parcels from the first parcel of the instruction. There is no `len = 00` form.')
    elif k == 'sob':
        L.append('```\n' + diag([('len', 2, None), ('opcode', 6, '0x3F'), ('reg', 4, 'Rn'), ('low', 4, '0')]) + '\n```\nFrom `len = 01`: parcel 1 (and 2) is the signed displacement in parcels, 16 or 32 bits. Four bytes at least.')
    elif k == 'tag':
        L.append('```\n' + diag([('len', 2, '01'), ('opcode', 6, '0x15'), ('reg', 4, 'Rn'), ('low', 4, 's ttt')]) + '\n' + diag([('disp', 16, None)]) + '\n```\n`low` holds the sense `s` in its top bit (`BTAG` 0, `BNTAG` 1) and the 3-bit tag `ttt` below it. Parcel 1 is a 16-bit displacement in parcels (32 bits at `len = 10`).')
    elif k in ('sop', 'xfer'):
        d = diag([('len', 2, None), ('opcode', 6, '0x%02X' % opc), ('reg', 4, ('0x%X' % MN[first]['value']) if len(names) == 1 else 'sub-opcode'), ('low', 4, 'rm')])
        L.append('```\n' + d + '\n```\nThe `reg` field is the sub-opcode; `rm` and the mode give the single operand, at any length (section 9.5).')
        if len(names) > 1:
            L.append('| Mnemonic | `reg` (sub-opcode) |\n|---|---|\n' + '\n'.join('| `%s` | `0x%X` |' % (n.upper(), MN[n]['value']) for n in names))
    elif k in ('besc', 'aesc', 'fesc', 'atom'):
        L.append('```\n' + diag([('len', 2, None), ('opcode', 6, '0x%02X' % opc), ('reg', 4, 'Rd'), ('low', 4, 'Rs')]) + '\n' +
                 diag([('sub-opcode', 8, ('0x%02X' % MN[first]['value']) if len(names) == 1 else None), ('t', 4, 'Rt'), ('x', 4, None)]) + '\n```\n' +
                 'From `len = 01`. `low` is a register in this group (never a mode). ' + entry.get('xnote', ''))
        if len(names) > 1:
            L.append('| Mnemonic | Sub-opcode |\n|---|---|\n' + '\n'.join('| `%s` | `0x%02X` |' % (n.upper(), MN[n]['value']) for n in names))
    elif k == 'mblk':
        L.append('```\n' + diag([('len', 2, None), ('opcode', 6, '0x0D'), ('reg', 4, 'Rd'), ('low', 4, 'Rs')]) + '\n' +
                 diag([('sub-opcode', 8, ('0x%02X' % MN[first]['value']) if len(names) == 1 else None), ('t', 4, 'Rn'), ('x', 4, 'flags')]) + '\n```\n`reg` is the destination pointer, `low` the source pointer (or the value register `Rv`), parcel 1 `t` the count register `Rn`.')
        if len(names) > 1:
            L.append('| Mnemonic | Sub-opcode |\n|---|---|\n' + '\n'.join('| `%s` | `0x%02X` |' % (n.upper(), MN[n]['value']) for n in names))
    elif k == 'mesc':
        L.append('```\n' + diag([('len', 2, None), ('opcode', 6, '0x0F'), ('reg', 4, 'Rs/Rd'), ('low', 4, 'mode')]) + '\n' +
                 diag([('sub', 4, None), ('rm', 4, None), ('disp', 8, None)]) + '\n```\nParcel 0\'s `low` is an addressing mode, as in the ordinary memory format; parcel 1 is `sub(4) rm(4) disp(8)` (16 more displacement bits per further parcel).')
        L.append('| Mnemonic | Sub-opcode |\n|---|---|\n' + '\n'.join('| `%s` | `0x%X` |' % (n.upper(), MN[n]['value']) for n in names))
    elif k in ('sysn', 'sysx', 'sysreg', 'sys'):
        L.append('```\n' + diag([('len', 2, None), ('opcode', 6, '0x14'), ('reg', 4, 'class'), ('low', 4, 'rm/minor')]) + '\n```\nThe `reg` field is the **class**. Class 0 takes a minor opcode from `low`; the other classes take a register or a 4-bit immediate from `low`.')
        rows = []
        for n in names:
            m = MN[n]
            if m['kind'] == 'sysn':
                rows.append('| `%s` | 0 | `0x%X` |' % (n.upper(), m['value']))
            elif m['kind'] == 'sysx':
                rows.append('| `%s` | 0 | `0xF` (`SYSX`), sub-opcode `%d` in parcel 1 |' % (n.upper(), m['value']))
            elif m['kind'] == 'sysreg':
                rows.append('| `%s` | 0 | `0x%X`, system register number in parcel 1 |' % (n.upper(), m['value']))
            else:
                rows.append('| `%s` | `0x%X` | operand in `low` |' % (n.upper(), m['value']))
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
    out.append('```\n' + e['op'].strip('\n') + '\n```')
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
    if e.get('cf'):
        out.append('**Cf.** ' + e['cf'])
        out.append('')
    out.append('**Status** ' + st + '. **Book** section %s.' % e['sect'])
    out.append('')
    return '\n'.join(out)


def page_for(e):
    return e['page']


def build():
    files = {}
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
    # every mnemonic must be covered: an alias is covered by the entry of its target
    missing = [n for n, m in MN.items() if n not in seen and not (m['alias_of'] and m['alias_of'] in seen)]
    if missing:
        raise SystemExit('mnemonics with no entry: ' + ' '.join(sorted(missing)))
    # aliases whose target is covered: add to that entry's alias list for the index
    alias_of = {n: m['alias_of'] for n, m in MN.items() if m['alias_of']}
    for e in ents:
        e['aliases'] = [a for a, t in alias_of.items() if t in e['names'] and a not in e['names']]
    pages = {}
    for e in ents:
        pages.setdefault(e['page'], []).append(e)
    order = [p for p, _ in D.PAGES]
    for p, title in D.PAGES:
        es = pages.get(p, [])
        L = ['# %s' % title, '', '[← dictionary index](index.md)', '', D.PAGE_INTRO.get(p, ''), '']
        L.append('*Generated by `tools/mkmanual.py` from `spec/pdp64-mnemonics.hbnf` and `tools/manual/isa_entries.py`; do not edit.*')
        L.append('')
        for e in es:
            # an alias list is part of the entry; entries rendered from their own names plus the aliases of their targets
            e2 = dict(e)
            e2['names'] = e['names'] + e['aliases']
            L.append(render_entry(e2))
        files[p + '.md'] = '\n'.join(L).rstrip() + '\n'
    # page 2
    P2 = ['# The second page: one-parcel abbreviations', '', '[← dictionary index](index.md)', '', D.P2_INTRO, '',
          '*Generated by `tools/mkmanual.py` from `spec/pdp64-mnemonics.hbnf` and `tools/manual/isa_entries.py`; do not edit.*', '',
          '```\n' + diag([('len', 2, '11'), ('opc', 6, None), ('reg', 4, None), ('low', 4, None)]) + '\n```', '',
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
        P2.append('| `0x%02X` | `%s` | %s | %s | %s | %s |' % (v, n, op, reg, low, longf))
    P2.append('')
    P2.append('Every page-2 opcode not listed (`0x0F` and `0x2E` to `0x3F`, %d of 64) is reserved; a reserved page-2 opcode is an illegal-instruction abort.' % (64 - len(p2)))
    P2.append('')
    files['page2.md'] = '\n'.join(P2)
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
    by = ['# Appendix: the mnemonics, alphabetically', '', '[← dictionary index](index.md)', '',
          '*Generated by `tools/mkmanual.py`; do not edit.*', '', '| Mnemonic | Entry | Opcode | Sub | Group |', '|---|---|---|---|---|']
    for n in sorted(MN):
        m = MN[n]
        tgt = m['alias_of'] or n
        eid = seen.get(n) or seen.get(tgt)
        page = [e['page'] for e in ents if e['id'] == eid][0]
        o, s = opcode_of(tgt)
        sub = '' if s is None else ('`0x%X`' % s)
        by.append('| `%s`%s | [%s](%s.md#%s) | `0x%02X` | %s | %s |' % (n.upper(), ' (alias of `%s`)' % tgt.upper() if m['alias_of'] else '', eid, page, anchor(eid), o, sub, GROUPNAME[m['kind']]))
    by.append('')
    files['by-mnemonic.md'] = '\n'.join(by)
    # by opcode
    bo = ['# Appendix: the opcodes, in order', '', '[← dictionary index](index.md)', '',
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
            bo.append('| `0x%02X` | %s |' % (o, text))
        else:
            reserved = {0x23: 'spare ALU slot (decodes, traps)'}.get(o, 'reserved')
            bo.append('| `0x%02X` | %s |' % (o, reserved))
    bo.append('')
    bo.append('## Page 2')
    bo.append('')
    bo.append('| Opcode | Name |')
    bo.append('|---|---|')
    for n, v in SPEC['p2op']:
        bo.append('| `0x%02X` | `%s` |' % (v, n))
    bo.append('')
    files['by-opcode.md'] = '\n'.join(bo)
    # index
    I = ['# The instruction dictionary', '', '[← manual index](../00-index.md)', '', D.INDEX_INTRO, '', '## The pages', '']
    for p, title in D.PAGES:
        es = pages.get(p, [])
        I.append('* [%s](%s.md): %s' % (title, p, ', '.join('`%s`' % ' '.join(x.upper() for x in e['names'][:1]) for e in es)[:200]))
    I.append('* [The second page: one-parcel abbreviations](page2.md)')
    I.append('* [Assembler aliases and old spellings](aliases.md)')
    I.append('* [Appendix: the mnemonics, alphabetically](by-mnemonic.md)')
    I.append('* [Appendix: the opcodes, in order](by-opcode.md)')
    I.append('')
    n_real = sum(1 for m in MN.values() if not m['alias_of'])
    n_alias = sum(1 for m in MN.values() if m['alias_of'])
    n_impl = sum(1 for n, m in MN.items() if not m['alias_of'] and implemented(n))
    I.append('The specification has %d mnemonic words (%d instructions and %d aliases) and %d page-2 opcodes; the reference executor implements %d of the %d instructions; the rest are specified and have entries marked as not yet implemented.' % (len(MN), n_real, n_alias, len(SPEC['p2op']), n_impl, n_real))
    I.append('')
    I.append('*Generated by `tools/mkmanual.py`; do not edit.*')
    I.append('')
    files['index.md'] = '\n'.join(I)
    return files


def anchor(eid):
    return re.sub(r'[^a-z0-9 -]', '', eid.lower() + ': ').replace(' ', '-')


def anchor_for(e):
    return re.sub(r'[^a-z0-9 -]', '', ('%s: %s' % (e['id'], e['title'])).lower()).replace(' ', '-')


def main():
    files = build()
    # fix anchors: GitHub slugs are made from the whole heading
    byid = {e['id']: e for e in D.ENTRIES}
    for k, v in list(files.items()):
        def fix(m):
            eid = m.group(2)
            return '](%s.md#%s)' % (m.group(1), anchor_for(byid[eid]))
        files[k] = re.sub(r'\]\(([a-z0-9-]+)\.md#[^)]*\)', lambda m: m.group(0), v)
    # by-mnemonic uses anchor(eid), replace with the real slug
    bm = files['by-mnemonic.md']
    def repl(m):
        eid = m.group(1)
        e = byid[eid]
        return '[%s](%s.md#%s)' % (eid, e['page'], anchor_for(e))
    bm = re.sub(r'\[([A-Z0-9_.]+)\]\([a-z0-9-]+\.md#[^)]*\)', repl, bm)
    files['by-mnemonic.md'] = bm
    check = '--check' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    bad = False
    for name, text in files.items():
        p = os.path.join(OUT, name)
        if check:
            if not os.path.exists(p) or open(p).read() != text:
                print('stale: dictionary/' + name)
                bad = True
        else:
            open(p, 'w').write(text)
    if check:
        sys.exit(1 if bad else 0)
    print('wrote %d files to %s' % (len(files), OUT))


if __name__ == '__main__':
    main()

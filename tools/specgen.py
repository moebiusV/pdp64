#!/usr/bin/env python3
"""
specgen -- check spec/pdp64.json and generate the tables the tools share.

    specgen.py check            run every structural check of the spec (exit 1 on failure)
    specgen.py c   > pdp64-spec.h   C tables for the assembler, linker, simulator and QEMU
    specgen.py map              print the opcode map (ISA 4.16) from the spec

The checks are the ones the ISA and the FPGA plan ask for: the 64 opcodes are
all accounted for and none repeats, the escape and sub-opcode groups sit where
ISA 4.3.1 says, every mode's payload is exactly the width of the parcels it
occupies (ISA 3.3), and no escape sub-opcode needs more extension parcels
than `len` declares (ISA 4.14).
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.path.join(HERE, '..', 'spec', 'pdp64.json')


def load():
    with open(SPEC) as f:
        return json.load(f)


def num(x):
    return int(x, 0) if isinstance(x, str) else x


def expand_reserved(items):
    out = set()
    for it in items:
        if '-' in it:
            a, b = it.split('-')
            out.update(range(num(a), num(b) + 1))
        else:
            out.add(num(it))
    return out


def fieldwidth(spec):
    """bits in a p1 layout string like 'rm4 rx4 s2 d' (d is the free-width tail)"""
    fixed = 0
    free = False
    for tok in spec.split():
        m = re.match(r'([a-z]+)(\d+)$', tok)
        if m:
            fixed += int(m.group(2))
        elif tok == 'd':
            free = True
        else:
            raise ValueError(tok)
    return fixed, free


def check(S):
    errs = []

    def err(m):
        errs.append(m)

    # parcel 0 fields cover 16 bits exactly
    bits = set()
    for name, (hi, lo) in S['fields'].items():
        for b in range(lo, hi + 1):
            if b in bits:
                err('parcel 0 field %s overlaps' % name)
            bits.add(b)
    if bits != set(range(16)):
        err('parcel 0 fields do not cover 16 bits')

    # the opcode map: 64 slots, each assigned once or reserved
    seen = {}
    for e in S['top']:
        o = num(e['opc'])
        if not 0 <= o < 64:
            err('opcode %s out of range' % e['opc'])
        if o in seen:
            err('opcode 0x%02X used twice (%s, %s)' % (o, seen[o]['name'], e['name']))
        seen[o] = e
    res = expand_reserved(S['reserved_top'])
    for o in res:
        if o in seen:
            err('opcode 0x%02X is both assigned and reserved' % o)
    missing = [o for o in range(64) if o not in seen and o not in res]
    if missing:
        err('opcodes neither assigned nor reserved: %s' % ' '.join('0x%02X' % o for o in missing))
    assigned = len(seen)
    # ISA 4.16 says "fifty-six assigned, eight reserved"; the map it prints has 55 assigned, the spare ALU
    # slot 0x23 and the eight at 0x28-0x2F (12 + 6 + 4 + 13 + 4 + 16 = 55).  See docs/errata.md.
    if assigned != 55:
        err('expected 55 assigned opcodes; spec has %d' % assigned)
    if res != {0x23} | set(range(0x28, 0x30)):
        err('expected 0x23 and 0x28-0x2F reserved')

    # layout rules of ISA 4.3.1
    esc = sorted(num(e['opc']) for e in S['top'] if e['fmt'] == 'esc')
    if esc != list(range(0x0C, 0x12)):
        err('the parcel-1 escapes must be contiguous at 0x0C-0x11, found %s' % esc)
    sub = sorted(num(e['opc']) for e in S['top'] if e['fmt'] in ('sub', 'sys'))
    if sub != [0x12, 0x13, 0x14]:
        err('the reg-as-sub-opcode groups must be 0x12-0x14, found %s' % sub)
    mov = sorted(num(e['opc']) for e in S['top'] if e['fmt'] == 'mem' and e['dir'] in ('ld', 'st', 'lea'))
    if mov != list(range(0x00, 0x0C)):
        err('moves and LEA must occupy 0x00-0x0B')
    alu = sorted(num(e['opc']) for e in S['top'] if e['fmt'] == 'mem' and e['dir'] == 'alu' and num(e['opc']) < 0x24)
    if alu != list(range(0x16, 0x23)):
        err('ALU must occupy 0x16-0x22 (0x23 is the spare slot), found %s' % alu)
    br = sorted(num(e['opc']) for e in S['top'] if e['fmt'] in ('br', 'sob'))
    if br != list(range(0x30, 0x40)):
        err('the sixteen branch slots must be 0x30-0x3F')

    # modes: payload is exactly the width of the parcels it occupies
    for m, md in S['modes'].items():
        fixed, free = fieldwidth(md['p1'])
        for i, db in enumerate(md['dbits']):
            ln = i + 1
            if not free:
                err('mode %s has no displacement' % m)
                continue
            # parcel 1 contributes (16 - fixed) displacement bits, every further parcel 16
            want = (16 - fixed) + 16 * (ln - 1)
            # mode 3 (dp): the 4 bits parcel 1 leaves over are padding, not payload
            if md['p1'].startswith('pad'):
                want = db
                fx, _ = fieldwidth(md['p1'])
                want = (16 - fx) + 16 * (ln - 1)
            if db != want:
                err('mode %s len=%d: dbits %d but the parcels hold %d' % (m, ln, db, want))
        if md['reclaims_rm'] and fixed != 0:
            err('mode %s reclaims rm but still has fixed fields in parcel 1' % m)

    # reach table of ISA 3.3: 12/28/44 and 16/32/48
    if S['modes']['0']['dbits'] != [12, 28, 44]:
        err('base-register displacement must be 12/28/44')
    if S['modes']['2']['dbits'] != [16, 32, 48]:
        err('pc-relative displacement must be 16/32/48')

    # sub-opcode groups: unique and in range
    for g, d in S['sub'].items():
        vals = list(d['ops'].values())
        if len(set(vals)) != len(vals):
            err('%s has a repeated mnemonic' % g)
        for k in d['ops']:
            if not 0 <= int(k) < 16:
                err('%s sub-opcode %s does not fit the 4-bit reg field' % (g, k))
    # SOP: PUSH/POP and JMP/CALL stay where ISA 4.5 puts them
    sop = S['sub']['SOP']['ops']
    for k, v in {'12': 'JMP', '13': 'CALL', '14': 'PUSH', '15': 'POP', '0': 'CLR', '1': 'COM'}.items():
        if sop.get(k) != v:
            err('SOP slot %s must be %s (ISA 4.5)' % (k, v))

    # escape groups: ISA 4.14
    for g, d in S['esc'].items():
        p1fixed, _ = fieldwidth(d['p1'].replace('op8', 'o8').replace('sub4', 's4'))
        if p1fixed != 16:
            err('%s parcel 1 layout %r is %d bits, not 16' % (g, d['p1'], p1fixed))
        names = set()
        keys = set()
        for k, op in d['ops'].items():
            kk = num(k)
            if kk in keys:
                err('%s sub-opcode %s repeated' % (g, k))
            keys.add(kk)
            width = 0xF if g == 'MESC' else 0xFF
            if kk > width:
                err('%s sub-opcode %s does not fit' % (g, k))
            nm = (op['name'], op.get('dir', ''))
            if nm in names:
                err('%s repeats %s' % (g, nm))
            names.add(nm)
            ml = op.get('minlen', 1)
            need = 1 + (1 if op.get('p2') else 0)
            if need > 3 or ml < need:
                err('%s.%s needs %d extension parcels but minlen is %d (ISA 4.14)' % (g, op['name'], need, ml))
            if op.get('p2'):
                fx, _ = fieldwidth(op['p2'])
                if fx != 16:
                    err('%s.%s parcel 2 layout is %d bits' % (g, op['name'], fx))
    # MESC takes a mode in parcel 0, the others a register (ISA 4.14, second rule)
    for e in S['top']:
        if e['fmt'] == 'esc':
            want = 'mode' if e['name'] == 'MESC' else 'reg'
            if e['nibble'] != want:
                err('%s: parcel 0 low nibble must be a %s' % (e['name'], want))

    # SYS: classes 0..15, minor names unique
    cls = S['sys']['classes']
    if sorted(int(k) for k in cls) != list(range(16)):
        err('SYS must define all sixteen classes')
    names = []
    for k, c in cls.items():
        if 'minor' in c:
            for n in c['minor'].values():
                names.append(n)
        else:
            names.append(c['name'])
    if len(names) != len(set(names)):
        err('SYS repeats a mnemonic')
    # aliases must not collide with real mnemonics
    real = set(e['name'] for e in S['top'])
    for g in S['esc'].values():
        real.update(o['name'] for o in g['ops'].values())
    for g in S['sub'].values():
        real.update(g['ops'].values())
    real.update(names)
    for a in S['aliases']:
        if a['name'] in real:
            err('alias %s is also a real mnemonic' % a['name'])
        if a['is'] not in real:
            err('alias %s points at unknown %s' % (a['name'], a['is']))
    return errs


def cmd_map(S):
    for o in range(64):
        e = next((x for x in S['top'] if num(x['opc']) == o), None)
        print('0x%02X  %s' % (o, (e['name'] + ('/' + e['dir'] if e.get('dir') in ('ld', 'st') else '')) if e else '----'))


def cname(n):
    return re.sub(r'\W', '_', n)


def cmd_c(S):
    out = ['/* generated by tools/specgen.py from spec/pdp64.json -- do not edit */',
           '#ifndef PDP64_SPEC_H', '#define PDP64_SPEC_H', '']
    out.append('enum pdp64_top {')
    for e in S['top']:
        sfx = {'ld': '_LD', 'st': '_ST'}.get(e.get('dir'), '')
        out.append('\tOP_%s%s = %s,' % (cname(e['name']), sfx, e['opc']))
    out.append('};')
    for g, d in S['sub'].items():
        out.append('enum pdp64_%s {' % g.lower())
        for k, v in d['ops'].items():
            out.append('\t%s_%s = %s,' % (g, cname(v), k))
        out.append('};')
    for g, d in S['esc'].items():
        out.append('enum pdp64_%s {' % g.lower())
        for k, op in d['ops'].items():
            sfx = {'ld': '_LD', 'st': '_ST'}.get(op.get('dir'), '')
            out.append('\t%s_%s%s = %s,' % (g, cname(op['name']), sfx, k))
        out.append('};')
    out.append('enum pdp64_sys_class {')
    for k, c in S['sys']['classes'].items():
        out.append('\tSYS_C_%s = %s,' % (cname(c['name']), k))
    out.append('};')
    out.append('static const char *const pdp64_top_name[64] = {')
    by = {num(e['opc']): e for e in S['top']}
    for o in range(64):
        out.append('\t"%s",' % (by[o]['name'] if o in by else '?'))
    out.append('};')
    out.append('#endif')
    print('\n'.join(out))


def main():
    S = load()
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    if cmd == 'check':
        errs = check(S)
        for e in errs:
            print('spec: ' + e)
        print('spec: %s (%d top-level opcodes assigned) -- %s' %
              (S['spec_revision'], len(S['top']), 'FAILED, %d problem(s)' % len(errs) if errs else 'ok'))
        sys.exit(1 if errs else 0)
    elif cmd == 'map':
        cmd_map(S)
    elif cmd == 'c':
        cmd_c(S)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()

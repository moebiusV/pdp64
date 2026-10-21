#!/usr/bin/env python3
"""
mkgrammar -- the numbers of the architecture are written once, as the enum rules of spec/pdp64-mnemonics.hbnf.  This reads them and writes

    build/pdp64.hbnf       from spec/pdp64.hbnf.in, with every @NAME@ replaced by that number
    build/pdp64-consts.h   one #define per enumerator, for the C that needs a number by name (as64, sim64, ld64)

An enumerator "cmp"@0b011010 of the rule mn-alu is MN_ALU_CMP.  An enumerator without a number is the one before plus one, as in hbnf.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')


def enums(path):
    text = open(path).read()
    out = {}
    cur = None
    nxt = 0
    for line in text.split('\n'):
        line = re.sub(r';.*$', '', line)           # no quote in these files holds a ;
        m = re.match(r'^([A-Za-z][\w-]*)\s*=(?!/)\s*(.*)$', line)
        if m:
            cur, body = m.group(1), m.group(2)
            out[cur] = []
            nxt = 0
        elif cur and re.match(r'^\s+\|', line):
            body = line
        else:
            if line.strip() == '':
                cur = None
            continue
        for lit, num in re.findall(r'"([^"]+)"(?:@(0[xbo][0-9A-Fa-f]+|\d+))?', body):
            if num:
                nxt = int(num, 0)
            out[cur].append((lit, nxt))
            nxt += 1
    return {k: v for k, v in out.items() if v}


def longest_first(text):
    """hbnf matches the words of an enum in the order written, so a word that begins another must come after it.  The sources are written
    in numeric order for people; the copy hbnf reads has every enum rule of numbered words sorted longest first, each with its number
    written out (the numbers are the encodings and do not change)."""
    lines = text.split('\n')
    out, i = [], 0
    while i < len(lines):
        m = re.match(r'^([A-Za-z][\w-]*)\s*=(?![=/])\s*(.*)$', re.sub(r';.*$', '', lines[i]))
        if not m:
            out.append(lines[i]); i += 1; continue
        j = i + 1
        body = [m.group(2)]
        while j < len(lines) and re.match(r'^\s+\|', lines[j]):
            body.append(re.sub(r';.*$', '', lines[j])); j += 1
        joined = ' '.join(body)
        items = re.findall(r'"([^"]+)"(?:@(0[xbo][0-9A-Fa-f]+|\d+))?', joined)
        residue = re.sub(r'"[^"]+"(?:@(?:0[xbo][0-9A-Fa-f]+|\d+))?', '', joined).replace('|', '').strip()
        if len(items) > 1 and not residue and all(re.match(r'^[A-Za-z_]', it[0]) for it in items):
            nxt, numbered = 0, []
            for lit, num in items:
                if num:
                    nxt = int(num, 0)
                numbered.append((lit, nxt)); nxt += 1
            numbered.sort(key=lambda t: (-len(t[0]), t[1]))
            out.append('%s = ' % m.group(1) + ' | '.join('"%s"@%d' % t for t in numbered))
        else:
            out.extend(lines[i:j])
        i = j
    return '\n'.join(out)


def group_order(en):
    """The mn- groups in an order where no group comes before another that holds a longer word it begins."""
    groups = [g for g in en if g.startswith('mn-')]
    after = {g: set() for g in groups}          # after[a] = groups that must come before a
    for a in groups:
        for b in groups:
            if a != b and any(y.startswith(x) and y != x for x, _ in en[a] for y, _ in en[b]):
                after[a].add(b)
    order, left = [], list(groups)
    while left:
        ready = [g for g in left if not (after[g] & set(left))]
        if not ready:
            sys.exit('mkgrammar: mnemonic groups begin each other\'s words in a cycle: %s' % left)
        order.append(ready[0]); left.remove(ready[0])
    return order


def main():
    en = enums(os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf'))
    const = {}
    for rule, items in en.items():
        for lit, v in items:
            const[re.sub(r'\W', '_', rule).upper() + '_' + re.sub(r'\W', '_', lit).upper()] = v
    # the template
    t = open(os.path.join(ROOT, 'spec', 'pdp64.hbnf.in')).read()
    macros = {}
    def take(m):
        macros[m.group(1)] = m.group(2).strip()
        return ''
    t = re.sub(r'^%define (\w+) (.*)\n', take, t, flags=re.M)
    for _ in range(4):                                      # macros may use macros
        t = re.sub(r'@(\w+)@', lambda m: macros.get(m.group(1), m.group(0)), t)
    def sub(m):
        if m.group(1) not in const:
            sys.exit('mkgrammar: no enumerator %s' % m.group(1))
        return '0x%X' % const[m.group(1)]
    g = re.sub(r'@([A-Z0-9_]+)@', sub, t)
    g = g.replace('\n; This file is a template: ', '\n; GENERATED from pdp64.hbnf.in by tools/mkgrammar.py; this file was a template: ', 1) if False else g
    bd = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
    os.makedirs(bd, exist_ok=True)
    open(os.path.join(bd, 'pdp64.hbnf'), 'w').write(g)
    # the grammars hbnf reads: enums longest-first, and the mnemonic rule in a safe order
    bd = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
    mn = longest_first(open(os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf')).read())
    mn += '\n; written by tools/mkgrammar.py: the groups, those whose words begin another group\'s words last\nmnemonic = ' + '\n         | '.join(group_order(en)) + '\n'
    open(os.path.join(bd, 'pdp64-mnemonics.hbnf'), 'w').write(mn)
    open(os.path.join(bd, 'pdp64-asm.hbnf'), 'w').write(longest_first(open(os.path.join(ROOT, 'spec', 'pdp64-asm.hbnf')).read()))
    for name in ('common.hbnf', 'ascii.hbnf', 'elf.hbnf'):
        open(os.path.join(bd, name), 'w').write(open(os.path.join(ROOT, 'spec', name)).read())
    order = group_order(en)
    names = [g[3:].replace('-', '_').upper() for g in order]
    with open(os.path.join(bd, 'pdp64-groups.h'), 'w') as f:
        f.write('/* generated by tools/mkgrammar.py -- do not edit.  The groups of mnemonics in the order of the alternatives of `mnemonic`. */\n')
        f.write('enum mn_group {\n')
        for k, n in enumerate(names):
            f.write('\tMG_%s = %d,\n' % (n, k + 1))
        f.write('};\n/* the number of the mnemonic that the parser matched, from the member of that group (single-word groups have no member: their number is the opcode) */\n')
        f.write('#define MNEMONIC_NUMBER(m, out) do { switch ((m)->_alt) { \\\n')
        for k, g in enumerate(order):
            if len(en[g]) == 1:
                key = 'OPGROUP_' + g[3:].replace('-', '_').upper()
                val = 'OPGROUP_%s' % g[3:].replace('-', '_').upper() if key in const else '0'
                f.write('\tcase %d: (out) = %s; break; \\\n' % (k + 1, val))
            else:
                f.write('\tcase %d: (out) = (m)->%s; break; \\\n' % (k + 1, g.replace('-', '_')))
        f.write('\t} } while (0)\n')
    # the header
    b = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
    os.makedirs(b, exist_ok=True)
    with open(os.path.join(b, 'pdp64-consts.h'), 'w') as f:
        f.write('/* generated by tools/mkgrammar.py from spec/pdp64-mnemonics.hbnf -- do not edit */\n#ifndef PDP64_CONSTS_H\n#define PDP64_CONSTS_H\n')
        for k in sorted(const, key=lambda k: (k.split('_')[0], const[k], k)):
            f.write('#define %-28s %d\n' % (k, const[k]))
        f.write('#endif\n')


if __name__ == '__main__':
    main()

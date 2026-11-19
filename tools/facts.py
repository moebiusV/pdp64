#!/usr/bin/env python3
"""facts.py -- the facts about the base mnemonics, read from spec/facts/*.toml (errata 183).

The grammar is the source of truth for names, encodings and operand shapes; the files of spec/facts/ hold what a grammar cannot, one table for each base mnemonic, the
base mnemonic being the key.  A tool that needs a fact calls load('vec'); the module checks that the keys and the grammar agree:

    tools/facts.py --check     every base mnemonic of each family in the grammar has a table, and every table names a base of the grammar; exit 1 if not
    tools/facts.py vec         print the keys of spec/facts/vec.toml, one a line
"""
import os, re, sys, tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import grammars_d

FACTS = os.path.join(ROOT, 'spec', 'facts')
# the groups: file name -> the families of the encoding grammar ("; family NAME:" lines of the generated forms part) whose words belong to it
GROUPS = {'vec': {'VBEG', 'VBEG2', 'VEND', 'VFIN', 'VOP.VVV', 'VOP.VVR', 'VOP.VVI', 'VDACC', 'VTBLM', 'VOP.VV', 'VBSL', 'VOP.VR', 'VOP.VI', 'VFMAB', 'VACC', 'VFIR', 'VCLR',
                'VLD.PI', 'VLD.B', 'VST.PI', 'VST.B', 'VLDT', 'VSTT', 'VSTS.R'}}


def load(group):
    """the tables of spec/facts/GROUP.toml, in file order: {base: {field: value}}"""
    with open(os.path.join(FACTS, group + '.toml'), 'rb') as f:
        return tomllib.load(f)


def grammar_words(group):
    """the quoted words of the families of the group in the grammar, each once (sorted)"""
    words, fam = set(), None
    for line in grammars_d.text(ROOT, 'enc').split('\n'):
        m = re.match(r'; family (\S+):', line)
        if m:
            fam = m.group(1)
            continue
        if fam in GROUPS[group]:
            words.update(re.findall(r'"(v[a-z0-9]+(?:\.[a-z]+)*)"', line))
    return sorted(words)


def grammar_bases(group):
    return sorted({w.split('.')[0] for w in grammar_words(group)})


def problems(group):
    have, want = set(load(group)), set(grammar_bases(group))
    out = ['%s: the grammar has the base %s and spec/facts/%s.toml has no table for it' % (group, b, group) for b in sorted(want - have)]
    out += ['%s: spec/facts/%s.toml has a table for %s, which the grammar does not have' % (group, group, b) for b in sorted(have - want)]
    return out


def main(argv):
    if len(argv) == 2 and argv[1] == '--check':
        bad = [p for g in GROUPS for p in problems(g)]
        for p in bad:
            print('facts: ' + p)
        if not bad:
            print('facts: ok (%s)' % ', '.join('%s: %d bases' % (g, len(load(g))) for g in GROUPS))
        return 1 if bad else 0
    if len(argv) == 2 and argv[1] in GROUPS:
        print('\n'.join(load(argv[1])))
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))

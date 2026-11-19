#!/usr/bin/env python3
"""facts.py -- the facts about the base mnemonics, read from spec/facts/*.toml (errata 183).

The grammar is the source of truth for names, encodings and operand shapes; the files of spec/facts/ hold what a grammar cannot, one table for each base mnemonic, the
base mnemonic being the key.  A tool that needs a fact calls load('vec'); the module checks that the keys and the grammar agree:

    tools/facts.py --check     every base mnemonic of each family in the grammar has a table, and every table names a base of the grammar; and the tables are complete and
                               true to the rest of the tree (see `problems`): the fields, a manual entry, an executor handler, a test that runs it, the compiler path; exit 1 if not
    tools/facts.py vec         print the keys of spec/facts/vec.toml, one a line
"""
import glob, importlib.util, os, re, sys, tomllib

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


# the fields every table of a group has
REQUIRED = {'vec': ('wave', 'meaning', 'llvm', 'exec', 'asm', 'group', 'entry')}
# where a test that runs a word lives (a word is run by a test if it is a mnemonic of a source there: tests/asm and tests/enc only assemble and encode it)
TESTS = {'vec': ['tests/sim/*.s', 'tests/sim/*.S', 'tests/qemu/*.S', 'tests/qemu/*.s']}
COMPILER_DIR = os.path.join('llvm', 'target', 'PDP64')


def _gen_vec_names():
    spec = importlib.util.spec_from_file_location('gen_vec_names', os.path.join(ROOT, 'tools', 'gen-vec-names.py'))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def tested_bases(group):
    """the base mnemonics that are a mnemonic (first word of a line, after a label) of a source of the test directories"""
    seen = set()
    for pat in TESTS[group]:
        for path in glob.glob(os.path.join(ROOT, pat)):
            for line in open(path, errors='replace'):
                m = re.match(r'\s*(?:[A-Za-z_.][\w.]*:)?\s*(v[a-z0-9]+)(?:\.|\s|$)', line)
                if m:
                    seen.add(m.group(1))
    return seen


# words the gate tools name that are not a base of the family: ordinary words that start with v, and words removed from the family (the gather, errata 170), whose rows
# of the gate tables are kept as the record of what was measured
NOT_BASES = {'vector', 'vmemlat'}
REMOVED = {'vldx'}


def gate_words():
    """(file, word) for each word that looks like a mnemonic in the labels of the rows of tools/gates/silicon-total.py and in the descriptions of the classes of tools/gates/lat-table.py"""
    out = []
    t = open(os.path.join(ROOT, 'tools', 'gates', 'silicon-total.py')).read()
    for lab in re.findall(r"^row\('((?:[^'\\]|\\.)*)'", t, re.M):
        out += [('tools/gates/silicon-total.py', w) for w in re.findall(r'\bv[a-z][a-z0-9]*\b', lab)]
    t = open(os.path.join(ROOT, 'tools', 'gates', 'lat-table.py')).read()
    a, b = t.index('CLASSES = ['), t.index(']\nSCALAR')
    for line in t[a:b].split('\n'):
        m = re.match(r"\s*\('(\w+)',\s*'\w+',\s*\[.*\],\s*'(.*)'\),?$", line)
        if m:
            out += [('tools/gates/lat-table.py', w) for w in re.findall(r'\bv[a-z][a-z0-9]*\b', m.group(2))]
    return out


def problems(group):
    F = load(group)
    have, want = set(F), set(grammar_bases(group))
    out = ['%s: the grammar has the base %s and spec/facts/%s.toml has no table for it' % (group, b, group) for b in sorted(want - have)]
    out += ['%s: spec/facts/%s.toml has a table for %s, which the grammar does not have' % (group, group, b) for b in sorted(have - want)]
    for b, t in F.items():
        for f in REQUIRED[group]:
            if f not in t:
                out.append('%s: the table of %s has no field %s' % (group, b, f))
    # the manual: every base names an entry, and the entry is defined once (its first base carries the text)
    leads = {}
    for b, t in F.items():
        if 'title' in t:
            if t.get('entry') in leads:
                out.append('%s: the entry %s has its text on two bases (%s, %s)' % (group, t['entry'], leads[t['entry']], b))
            leads[t.get('entry')] = b
            for f in ('entry_seq', 'syntax', 'op', 'notes'):
                if f not in t:
                    out.append('%s: the lead base %s of the entry %s has no field %s' % (group, b, t['entry'], f))
    for b, t in F.items():
        if t.get('entry') not in leads:
            out.append('%s: the base %s names the manual entry %s, which no base defines' % (group, b, t.get('entry')))
    # the executor: every exec is handled by a case, every case belongs to a base (tools/gen-vec-names.py)
    if group == 'vec':
        out += ['%s: %s' % (group, p) for p in _gen_vec_names().problems()]
    # a test that runs the word
    ran = tested_bases(group)
    out += ['%s: no test of %s runs the base %s (it is only assembled)' % (group, ' or '.join(TESTS[group][:2]), b) for b in F if b not in ran]
    # the compiler: where a record says the back end selects the base, the file exists and names the base
    for b, t in F.items():
        c = t.get('compiler')
        if c is None:
            continue
        path = os.path.join(ROOT, COMPILER_DIR, c)
        if not os.path.exists(path):
            out.append('%s: the base %s names the compiler file %s, which does not exist' % (group, b, os.path.join(COMPILER_DIR, c)))
            continue
        name = re.sub(r'\d$', '', b) if re.match(r'v[ls]seg\d$', b) else b
        if not re.search(r'"%s[ ."]' % name, open(path).read()):
            out.append('%s: the base %s names the compiler file %s, which has no string that spells it' % (group, b, c))
    # the gate tools: every word a row of the silicon and latency tables names is a base (or one of the words listed above)
    if group == 'vec':
        out += ['%s: %s names %s, which is not a base of the family (nor in NOT_BASES, REMOVED of tools/facts.py)' % (group, f, w)
                for f, w in sorted(set(gate_words())) if w not in F and w not in NOT_BASES and w not in REMOVED]
    # and the other way: the compiler's measured use (llvm/vector-usage.md) of a base that has no record of it
    try:
        for line in open(os.path.join(ROOT, 'llvm', 'vector-usage.md')):
            m = re.match(r'\| [^|]+ \| `(v[a-z0-9]+)` \| (\d+) \| (\d+) \|', line)
            if m and m.group(1) in F and int(m.group(3)) > 0 and 'compiler' not in F[m.group(1)]:
                out.append('%s: llvm/vector-usage.md says the compiler emits %s and its table has no field compiler' % (group, m.group(1)))
    except FileNotFoundError:
        pass
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

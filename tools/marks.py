#!/usr/bin/env python3
"""marks.py -- the width and kind suffixes of the assembly language, for the tools that write or read assembly source (the checks, the generators of the tests, the analyses, the dictionary of the manual).

The width and the kind of an operation are a dotted suffix of the mnemonic (`mov.s8`, `aadd.s32`, `fadd.f32`; a conversion, which has two formats, writes them on its operands, `fcvt r1.f16, r2.f32`); the encoding has a word for each (movb, aaddl, fadd32, fcvtds).  The rows of
spec/grammars.d/61-asm-suffixes.hbnf say, for each accepted spelling, the word of the encoding it is, and which spelling is the one that is printed for a word (tools/mkgrammar.py reads them; as64,
tools/encdis.c, pcc's table and the dictionary use the same rows).  A tool that thinks in the words of the encoding (a generator of tests, an analysis of the instruction mix) writes or reads them
through this module: `spell(word, operands)` is the source line's operation and operands for a word of the encoding (the operands do not change: the suffix is on the word; only a conversion with no short form, fcvtds, gets a mark on each of its two); `unspell(op, operands)` is the other direction.

    python3 tools/marks.py WORD OPERAND...      print the spelling, for a try
"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mkgrammar

_ROWS = None
_MARKS = None
_SHOWN = None
_MARKED = None


def rows(root=None):
    """[(spelling, word of the encoding, flags, printed)] of the rows of 61-asm-suffixes.hbnf"""
    global _ROWS
    if _ROWS is None:
        _ROWS = mkgrammar.surface_rows(root)
    return _ROWS


def shown(root=None):
    """{word of the encoding: the spelling that is printed for it}: the 64-bit words print bare (movq is mov), the others with their suffix (movb is mov.s8, fadd32 is fadd.f32); a word with no entry is printed as it is"""
    global _SHOWN
    if root is None and _SHOWN is not None:
        return _SHOWN
    out = {w: sp for sp, w, fl, p in rows(root) if p}
    if root is None:
        _SHOWN = out
    return out


def words(root=None):
    """the words of the older notations and of the encoding that no spelling stands for: unknown mnemonics in the assembly language (movb, aaddl, faddf, fadd32, fcvtds ...)"""
    return mkgrammar.withdrawn_words(root)


def conversions(root=None):
    """{word of the encoding: (mark of the first operand, mark of the second)} of the operands of fcvt (map-marks): `fcvt r1.f16, r2.f32`, the source first and the destination last"""
    global _MARKS
    if _MARKS is None:
        _MARKS = {w: (a, b) for w, a, b in mkgrammar.mark_rows(root)}
    return _MARKS


def marked(root=None):
    """{word of the encoding: (mark, mark)} of the conversions that are printed in the operand form: the ones with no short form (fcvtds, but not fcvtqd, which is fcvt.s64)"""
    global _MARKED
    if root is None and _MARKED is not None:
        return _MARKED
    sh = shown(root)
    out = {w: m for w, m in conversions(root).items() if w not in sh}
    if root is None:
        _MARKED = out
    return out


def display(word, upper=True, root=None):
    """a word of the encoding as the manual names it: the spelling that is printed for it (movb is MOV.s8); a conversion is named by its official form, the format on each operand, source
    first (fcvtds is `FCVT Rs.f64, Rd.f32`), even where it has a short form"""
    cv = conversions(root).get(word)
    if cv:
        return 'FCVT Rs.%s, Rd.%s' % cv if upper else 'fcvt rs.%s, rd.%s' % cv
    sp = shown(root).get(word, word)
    if not upper:
        return sp
    stem, dot, rest = sp.partition('.')
    return stem.upper() + dot + rest       # the mnemonic is upper case, its suffixes are not: MOV.s8, FADD.f32


def spellings(root=None):
    """{accepted spelling: word of the encoding}"""
    return {sp: w for sp, w, fl, p in rows(root)}


REG = re.compile(r'^(%?r\d+|%?sp|%?fp)$')


def isreg(o): return bool(REG.match(o))
def isimm(o): return o[:1] in '#$='


def split_ops(s):
    """the operands of an instruction's text, split at the commas outside parentheses and quotes"""
    ops, depth, cur, q = [], 0, '', None
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in '"\'`': q = ch; cur += ch; continue
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0: ops.append(cur.strip()); cur = ''; continue
        cur += ch
    if cur.strip(): ops.append(cur.strip())
    return ops


def spell(word, ops):
    """(operation, operands) for a word of the encoding and its operands (strings): the operation is the spelling printed for the word; the operands are as they are"""
    mk = marked().get(word)
    if mk and len(ops) == 2:
        return 'fcvt', [ops[0] + '.' + mk[0], ops[1] + '.' + mk[1]]
    return shown().get(word, word), list(ops)


def unspell(op, ops):
    """the other direction: the word of the encoding and the operands, for an operation as the assembly language writes it.  An operation that is not a suffixed spelling is returned as it is."""
    if op == 'fcvt' and len(ops) == 2:
        m = re.match(r'^(.*)\.([su][0-9]+|f[0-9]+)$', ops[0]), re.match(r'^(.*)\.([su][0-9]+|f[0-9]+)$', ops[1])
        if m[0] and m[1]:
            for w, mk in conversions().items():
                if mk == (m[0].group(2), m[1].group(2)): return w, [m[0].group(1), m[1].group(1)]
    return spellings().get(op, op), list(ops)


def spell_comment(text):
    """a comment that names words of the encoding that the assembly language does not have: the names are replaced by their spelling"""
    sh = {w: sp for w, sp in shown().items() if w != sp}
    pat = re.compile(r'(?<![\w.$])(%s)(?![\w.$])' % '|'.join(re.escape(w) for w in sorted(sh, key=len, reverse=True)))
    return pat.sub(lambda m: sh[m.group(1)], text)


def spell_line(text):
    """a line of source `word operands` (a mnemonic of the encoding at its start, after any labels) written with the spelling of the assembly language; other lines as they are"""
    m = re.match(r'^(\s*(?:[\w.$]+:\s*)*)([a-z][a-z0-9.]*)(?=\s|$)(.*)$', text)
    if not m: return text
    sh = shown()
    mk = marked().get(m.group(2))
    if mk:								# a conversion with no short form: the format on each operand
        rest, semi, com = m.group(3).partition(';')
        ops = split_ops(rest)
        if len(ops) == 2: return m.group(1) + 'fcvt ' + ', '.join((ops[0] + '.' + mk[0], ops[1] + '.' + mk[1])) + (' ' + semi + com if semi else '')
    if m.group(2) not in sh: return text
    return m.group(1) + sh[m.group(2)] + m.group(3)


def spell_text(text):
    """a program of source lines: each line that starts with a word of the encoding that the assembly language spells otherwise is written with its spelling (a generator of tests describes an
    instruction by the word of the encoding and the operands; this is the one place that turns it into source)"""
    out = []
    for l in text.split('\n'):
        code, com = l, ''
        q = None
        for k, ch in enumerate(l):				# the comment starts at a ; outside quotes
            if q:
                if ch == q: q = None
            elif ch in '"\'`': q = ch
            elif ch == ';': code, com = l[:k], l[k:]; break
        out.append(spell_line(code) + spell_comment(com))
    return '\n'.join(out)


if __name__ == '__main__':
    op, ops = spell(sys.argv[1], sys.argv[2:])
    print(op, ', '.join(ops))

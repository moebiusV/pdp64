#!/usr/bin/env python3
"""marks.py -- the width marks of the assembly language, for the tools that write assembly source (the checks, the generators of the tests, the dictionary of the manual).

The rows of spec/grammars.d/61-asm-marks.hbnf say, for each word of the encoding that the assembly language does not have (movb, aaddl, fadd32, fcvtds ...), the operation that
is written instead and the marks of its operands (tools/mkgrammar.py reads them; as64 and tools/encdis.c use the same rows).  `spell(word, operands)` is the other direction of
`as64`: from a word of the encoding and its operands to the source line's operation and operands, with the marks put on.

    python3 tools/marks.py WORD OPERAND...      print the spelling, for a try
"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mkgrammar

_ROWS = None


def rows(root=None):
    """{word of the encoding: (operation, spec)}"""
    global _ROWS
    if _ROWS is None:
        r, _ = mkgrammar.marks_rows(root)
        _ROWS = {w: (op, spec) for w, op, spec in r}
    return _ROWS


def words(root=None):
    """the words of the encoding that are not words of the assembly language"""
    return mkgrammar.marks_rows(root)[1]


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


class NoSpelling(Exception):
    pass


def spell(word, ops):
    """(operation, operands) for a word of the encoding and its operands (strings): the marks on the operands the row names.  A word with no row is returned as it is."""
    r = rows().get(word)
    if r is None: return word, list(ops)
    op, spec = r
    ops = list(ops)
    if not spec:
        return (op if word in words() else word), ops		# movq stays a word of the assembly language; movq.u is `mov.u`
    k = spec[0]
    if k == 'm':
        mem = [i for i, o in enumerate(ops) if not isreg(o) and not isimm(o)]
        if mem: i = mem[-1]
        elif ops and isreg(ops[0]): i = 0
        else: raise NoSpelling('%s %s: the width of a constant has no mark' % (word, ', '.join(ops)))
        if isimm(ops[i]): raise NoSpelling('%s %s' % (word, ', '.join(ops)))
        ops[i] += '.' + spec[1:].replace('u', 'u')
    elif k == 's':
        ops[0] += '.' + spec[1:]
    elif k == 'f':
        for i, o in enumerate(ops):
            if isreg(o): ops[i] = o + '.' + spec[1:]
    elif k == 'c':
        s, d = spec[2:].split(':')
        ops = [ops[0] + ('' if s == 'i' else '.' + s), ops[1] + ('' if d == 'i' else '.' + d)]
    return op, ops


_MARK = re.compile(r'\.[us]?(?:8|16|32|64)$')


def unspell(op, ops):
    """the other direction: the word of the encoding and the operands without marks, for an operation and operands as the assembly language writes them (a tool that reads the assembly a
    compiler or the disassembler wrote and thinks in the words of the encoding).  An operation that no row names is returned as it is."""
    plain = [_MARK.sub('', o) if _MARK.search(o) else o for o in ops]
    for w, (rop, spec) in rows().items():
        if rop != op: continue
        try:
            if spell(w, plain)[1] == list(ops) and (spec or plain == list(ops)):
                return w, plain
        except NoSpelling:
            pass
    return op, list(ops)


def phrase(word):
    """the words of a sentence for a word of the encoding (a comment that names it): `lll` is `ll .32`; None for a word with no mark"""
    r = rows().get(word)
    if r is None or not r[1]: return None
    op, spec = r
    if spec[0] == 'm': return '%s .%s' % (op, spec[1:])
    if spec[0] in 'sf': return '%s .%s' % (op, spec[1:])
    s, d = spec[2:].split(':')
    return 'fcvt from %s to %s' % ('an integer' if s == 'i' else s, 'an integer' if d == 'i' else d)


def spell_comment(text):
    """a comment that names words of the encoding that the assembly language does not have: the names are replaced by the operation and its mark"""
    pat = re.compile(r'(?<![\w.$])(%s)(?![\w.$])' % '|'.join(re.escape(w) for w in sorted(words(), key=len, reverse=True)))
    return pat.sub(lambda m: phrase(m.group(1)) or m.group(1), text)


def spell_line(text):
    """a line of source `word operands` (a mnemonic of the encoding at its start, after any labels) written with marks; other lines as they are"""
    m = re.match(r'^(\s*(?:[\w.$]+:\s*)*)([a-z][a-z0-9.]*)(\s+)(.*)$', text)
    if not m or m.group(2) not in rows(): return text
    op, ops = spell(m.group(2), split_ops(m.group(4)))
    return m.group(1) + op + m.group(3) + ', '.join(ops)


def spell_text(text):
    """a program of source lines: each line that starts with a word of the encoding that the assembly language writes with marks is written with them (a generator of tests describes an
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
        out.append(spell_line(code) + code[len(code.rstrip()):] + spell_comment(com))
    return '\n'.join(out)


if __name__ == '__main__':
    op, ops = spell(sys.argv[1], sys.argv[2:])
    print(op, ', '.join(ops))

"""The bit-layout charts of the manual, generated from the grammars.

    pdp64/r20      spec/pdp64.hbnf.in (the bit rules: the fields of parcel 0 and the guarded alternatives of the body), spec/pdp64-mnemonics.hbnf
                   (every number), spec/pdp64-system.hbnf (the status word), spec/pdp64-layout.hbnf (what a field is called in each class)
    pdp64/16, /32  spec/pdp64-NN/pdp64-NN.hbnf and spec/pdp64-enc.hbnf, read by tools/encgram.py

No layout is written in this file: a chart is what the grammar says for that opcode, so changing a field in a grammar changes the chart.  The drawing
(boxes, bit numbers, shading of the fixed fields) is the only thing here.  A chart is a dict

    id, title, rows [(row label, [(field label, width, value or None), ...]), ...], legend (the lines printed under it), mns [(mnemonic, {column: value})]
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import encgram, mkgrammar


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


# ---------------------------------------------------------------- drawing
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
            room = w * unit - 4
            if val is None:
                fs = max(7, min(13, room / (0.62 * max(1, len(fl)))))
                out.append('<text x="%.1f" y="%d" font-size="%.1f" text-anchor="middle" font-family="DejaVu Sans, sans-serif">%s</text>' % (cx, y + top + rh // 2 + 5, fs, esc(fl)))
            else:
                fs = max(7, min(10, room / (0.62 * max(1, len(fl)))))
                vs = max(7, min(12, room / (0.7 * max(1, len(str(val))))))
                out.append('<text x="%.1f" y="%d" font-size="%.1f" text-anchor="middle" font-family="DejaVu Sans, sans-serif" fill="#333">%s</text>' % (cx, y + top + 14, fs, esc(fl)))
                out.append('<text x="%.1f" y="%d" font-size="%.1f" text-anchor="middle" font-family="DejaVu Sans Mono, monospace" font-weight="bold">%s</text>' % (cx, y + top + 29, vs, esc(str(val))))
            pos -= w
        y += top + rh + gap - 4
    h = y + 4
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="DejaVu Sans, sans-serif">\n%s\n</svg>\n'
            % (width, h, width, h, '\n'.join(out)))


def parcel_rows(flat, first_label=None):
    """flat: [(label, width, value-or-None)] in record order (the top bit of parcel 0 first) -> rows of 16 bits.  A field that crosses a parcel boundary is cut."""
    rows, cur, used = [], [], 0
    for lab, w, val in flat:
        first = True
        while w > 0:
            take = min(w, 16 - used)
            if take == w:
                part = (lab, take, val)
            else:
                part = (lab, take, None if val is None else str(val)[:take])
            if not first:
                part = (lab + ' (cont.)', part[1], part[2])
            if val is not None and take < w:
                val = str(val)[take:]
            cur.append(part)
            used += take
            w -= take
            first = False
            if used == 16:
                rows.append(('parcel %d' % len(rows), cur))
                cur, used = [], 0
    if cur:
        raise ValueError('a layout of %d bits is not a whole number of parcels' % (16 * len(rows) + used))
    return rows


# ---------------------------------------------------------------- the r20 grammar
def consts():
    en = mkgrammar.enums(os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf'))
    syst = mkgrammar.enums(os.path.join(ROOT, 'spec', 'pdp64-system.hbnf'))
    const = {}
    for rule, items in list(en.items()) + list(syst.items()):
        for lit, v in items:
            const[re.sub(r'\W', '_', rule).upper() + '_' + re.sub(r'\W', '_', lit).upper()] = v
    return en, syst, const


def balanced(s, i):
    """s[i] is '(': the index after the matching ')'"""
    d = 0
    for j in range(i, len(s)):
        if s[j] == '(':
            d += 1
        elif s[j] == ')':
            d -= 1
            if d == 0:
                return j + 1
    raise ValueError('unbalanced: ' + s[i:i + 40])


def pyexpr(s):
    s = s.replace('&&', ' and ').replace('||', ' or ')
    return re.sub(r'!(?!=)', ' not ', s)


class R20Grammar:
    """spec/pdp64.hbnf.in: the head of the instruction and the alternatives of its body, with the guards evaluable."""

    def __init__(self):
        self.en, self.syst, const = consts()
        t = open(os.path.join(ROOT, 'spec', 'pdp64.hbnf.in')).read()
        t = re.sub(r';[^\n]*', '', t)
        macros = {}

        def take(m):
            macros[m.group(1)] = m.group(2).strip()
            return ''
        t = re.sub(r'(?m)^%define (\w+) (.*)\n', take, t)
        for _ in range(4):
            t = re.sub(r'@(\w+)@', lambda m: macros.get(m.group(1), m.group(0)), t)
        t = re.sub(r'@([A-Z0-9_]+)@', lambda m: '0x%X' % const[m.group(1)], t)
        m = re.search(r'insn\s*=\s*((?:\w+:\d+\s+)+)body:\(', t)
        self.head = [(a, int(b)) for a, b in re.findall(r'(\w+):(\d+)', m.group(1))]
        body = t[m.end():]
        end = balanced('(' + body, 0)
        body = body[:end - 2]
        alts, depth, cur = [], 0, ''
        for i, ch in enumerate(body):
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            if ch == '|' and depth == 0 and body[i - 1:i + 2] != '||' and body[i:i + 2] != '||':
                alts.append(cur)
                cur = ''
            else:
                cur += ch
        alts.append(cur)
        self.alts = [self.tokens(a) for a in alts if a.strip()]
        self.opgroup = dict(self.en['opgroup'])
        self.amode = {v: n for n, v in self.en['amode']}

    @staticmethod
    def tokens(a):
        out, i = [], 0
        while i < len(a):
            if a[i].isspace():
                i += 1
            elif a.startswith('?(', i):
                j = balanced(a, i + 1)
                out.append(('guard', compile(pyexpr(a[i + 2:j - 1]), '<guard>', 'eval')))
                i = j
            else:
                m = re.compile(r'(\w+):(?:bits\(|(\d+))').match(a, i)
                if not m:
                    raise ValueError('cannot read: ' + a[i:i + 40])
                if m.group(2):
                    out.append(('field', m.group(1), int(m.group(2)), None))
                    i = m.end()
                else:
                    j = balanced(a, m.end() - 1)
                    out.append(('field', m.group(1), None, compile(pyexpr(a[m.end():j - 1]), '<w>', 'eval')))
                    i = j
        return out

    def body(self, **env):
        """The fields [(name, width)] of the body for these values of len, opc, reg, low, sub, or None when no alternative accepts them."""
        env = dict(env, pad=0)
        for alt in self.alts:
            fields, ok = [], True
            for tk in alt:
                if tk[0] == 'guard':
                    if not eval(tk[1], {}, env):
                        ok = False
                        break
                else:
                    w = tk[2] if tk[2] is not None else eval(tk[3], {}, env)
                    if w:
                        fields.append((tk[1], w))
            if ok:
                return fields
        return None


# ---------------------------------------------------------------- the roles file
def read_layout_file():
    t = '\n'.join(encgram.strip_comment(l) for l in open(os.path.join(ROOT, 'spec', 'pdp64-layout.hbnf')).read().split('\n'))
    out = {}
    for rule, body in re.findall(r'(?m)^([a-z-]+)\s*=(.*?)(?=^\S|\Z)', t, re.S):
        out[rule] = re.findall(r'"((?:[^"\\]|\\.)*)"', body)
    return out


LAYOUT = read_layout_file()
ROLE = {}
for _x in LAYOUT['layout-role']:
    _k, _v = _x.split('=', 1)
    ROLE[_k] = _v
NOTE = dict(x.split(':', 1) for x in LAYOUT['layout-note'])
MERGE = {}
for _x in LAYOUT['layout-merge']:
    _k, _v = _x.split('=', 1)
    MERGE[_k] = _v
SPLIT = {}
for _x in LAYOUT['layout-split']:
    _k, _v = _x.split('=', 1)
    SPLIT[_k] = [(p.split(':')[0], int(p.split(':')[1])) for p in _v.split(',')]

_G = None


def grammar():
    global _G
    if _G is None:
        _G = R20Grammar()
    return _G


def role(kind, field, ln):
    return ROLE.get('%s:%s@%d' % (kind, field, ln)) or ROLE.get('%s:%s' % (kind, field)) or field


def b(v, w):
    return format(v, '0%db' % w)


def r20_constraints(name, m, G):
    """The values of the fields of parcel 0 that the mnemonic fixes: lists of (opc, reg, low, sub) alternatives (None = free)."""
    k, v, grp = m['kind'], m['value'], m['group']
    og = G.opgroup
    if k == 'mem':
        if grp == 'mn-lea':
            return [dict(opc=og['lea'])]
        if grp == 'mn-mov':
            return [dict(opc=v), dict(opc=v + 1)]
        return [dict(opc=v)]
    if k == 'br':
        return [dict(opc=v)]
    if k == 'cb':
        return [dict(opc=og['cbr'], low=v), dict(opc=og['cbw'], low=v), dict(opc=og['cbrr'], low=v)]
    if k == 'sob':
        return [dict(opc=og['sob'])]
    if k == 'tag':
        return [dict(opc=og['tag'], sense=v)]
    if k in ('sop', 'xfer'):
        return [dict(opc=og[k], reg=v)]
    if k in ('besc', 'mblk', 'aesc', 'fesc', 'atom', 'mesc'):
        return [dict(opc=og[k], sub=v)]
    if k == 'sysn':
        return [dict(opc=og['sys'], reg=0, low=v)]
    if k == 'sysx':
        return [dict(opc=og['sys'], reg=0, low=15, sub=v)]
    if k == 'sysreg':
        return [dict(opc=og['sys'], reg=0, low=v)]
    if k == 'sys':
        return [dict(opc=og['sys'], reg=v)]
    raise ValueError(k)


def r20_charts(MN):
    """The charts of pdp64/r20: one for every distinct layout (class, length, body) of the instructions of the specification.
    MN: name -> dict(kind, group, value, alias_of).  Returns (charts, by mnemonic: name -> [(chart id, {column: value})])."""
    G = grammar()
    hw = dict(G.head)
    lens = (0, 1, 2)
    charts = {}
    order = []
    for name, m in MN.items():
        if m['alias_of'] or m['kind'] == 'ext':
            continue
        for c in r20_constraints(name, m, G):
            sub = c.get('sub', 0)
            seen = {}
            for ln in lens:
                for reg in ([c['reg']] if 'reg' in c else range(16)):
                    for low in ([c['low']] if 'low' in c else range(16)):
                        f = G.body(len=ln, opc=c['opc'], reg=reg, low=low, sub=sub)
                        if f is None:
                            continue
                        key = (m['kind'], ln, tuple(f))
                        e = seen.setdefault(key, [set(), set()])
                        e[0].add(low)
                        e[1].add(reg)
            for key, (lows, regs) in seen.items():
                ch = charts.get(key)
                if ch is None:
                    ch = charts[key] = dict(kind=m['kind'], len=key[1], body=key[2], lows=set(), mns={})
                    order.append(key)
                ch['lows'] |= lows
                ch['mns'].setdefault(name, []).append(dict(c, sub=c.get('sub')))
    out = []
    byname = {}
    counters = {}
    for key in sorted(order, key=lambda k: (list(MN_KINDS).index(k[0]), k[1], order.index(k))):
        ch = charts[key]
        kind, ln = ch['kind'], ch['len']
        n = counters.get((kind, ln), 0) + 1
        counters[(kind, ln)] = n
        cid = 'r20-%s-%d%s' % (kind, ln, '' if n == 1 else '-%d' % n)
        build_r20_chart(ch, cid, hw, G)
        out.append(ch)
        for name, cs in ch['mns'].items():
            byname.setdefault(name, []).append((cid, ch))
    # page 2
    p2 = dict(id='r20-page2', kind='p2', len=3, title='Page 2: a one-parcel instruction with its own opcode map', mns={}, legend=[],
              rows=[('parcel 0', [('len', hw['len'], b(3, hw['len'])), ('opc', hw['opc'], None), ('reg', hw['reg'], None), ('low', hw['low'], None)])])
    assert G.body(len=3, opc=0, reg=0, low=0, sub=0) == []
    out.append(p2)
    return out, byname


MN_KINDS = ['mem', 'br', 'cb', 'sob', 'tag', 'sop', 'xfer', 'besc', 'mblk', 'aesc', 'fesc', 'atom', 'mesc', 'sysn', 'sysx', 'sysreg', 'sys']


def build_r20_chart(ch, cid, hw, G):
    kind, ln = ch['kind'], ch['len']
    cons = [c for cs in ch['mns'].values() for c in cs]
    if kind == 'cb' and {c['opc'] for c in cons} == {G.opgroup['cbrr']}:
        kind = 'cbrr'

    def common(f, width):
        vals = {c.get(f) for c in cons}
        if len(vals) == 1 and None not in vals:
            return b(vals.pop(), width)
        return None
    opc = common('opc', hw['opc'])
    reg = common('reg', hw['reg'])
    low = common('low', hw['low'])
    sub = common('sub', dict(ch['body']).get('sub', 8))
    # parcel 0
    p0 = [('len', hw['len'], b(ln, hw['len'])), ('opcode', hw['opc'], opc)]
    key = '%s:reg+low' % kind
    flds = []
    if '%s@%d' % (key, ln) in MERGE:
        p0.append((MERGE['%s@%d' % (key, ln)], hw['reg'] + hw['low'], None))
    else:
        lw = hw['low']
        p0.append((role(kind, 'reg', ln), hw['reg'], reg))
        sp = SPLIT.get('%s:low' % kind)
        if sp:
            p0.append((sp[0][0], sp[0][1], None))
            p0.append((sp[1][0], sp[1][1], None))
        else:
            lab = role(kind, 'low', ln)
            p0.append((lab, lw, low if low is not None else None))
    flat = list(p0)
    for nm, w in ch['body']:
        v = sub if nm == 'sub' else None
        if nm == 'pad':
            v = b(0, w)
        flat.append((role(kind, nm, ln), w, v))
    # the 'more' field is the rest of the instruction: whole parcels
    rows = parcel_rows(flat)
    ch['id'] = cid
    ch['rows'] = rows
    modes = sorted(ch['lows'])
    leg = []
    if kind in ('mem', 'sop', 'xfer', 'mesc') and ln >= 1:
        leg.append('Addressing modes (`low`) that use this layout: ' + ', '.join('`%s` %s' % (G.amode[x], b(x, 4)) for x in modes if x in G.amode) + '.')
    ch['legend'] = leg
    if NOTE.get(kind):
        ch['legend'].append(NOTE[kind])
    lens = {0: 'one parcel', 1: 'two parcels', 2: 'three parcels'}
    ch['title'] = '%s, %s (`len = %s`)' % (KINDTITLE[kind], lens[ln], b(ln, 2))


KINDTITLE = {'mem': 'Moves, address formation and the ALU', 'br': 'Conditional branches', 'cb': 'Compare and branch', 'sob': 'SOB', 'tag': 'Tag branches',
             'sop': 'Single operand (SOP)', 'xfer': 'Indirect transfers (XFER)', 'besc': 'Bits and fields (BESC)', 'mblk': 'Block memory (MBLK)',
             'aesc': 'Arithmetic (AESC)', 'fesc': 'Floating point (FESC)', 'atom': 'Atomics (ATOM)', 'mesc': 'Memory escape (MESC)',
             'sysn': 'System, no operand', 'sysx': 'System, SYSX', 'sysreg': 'System registers (MFSR, MTSR)', 'sys': 'System'}


def r20_mn_columns(MN, ch):
    """for a chart: the rows [(mnemonic, opcode, reg, low, sub)] of the numbers that differ between its mnemonics (binary)"""
    rows = []
    kind = ch['kind']
    hw = dict(grammar().head)
    cols = {'opcode': hw['opc'], 'reg': hw['reg'], 'low': hw['low'], 'sub': dict(ch['body']).get('sub', 8 if kind != 'mesc' else 4)}
    keyname = {'opcode': 'opc', 'reg': 'reg', 'low': 'low', 'sub': 'sub'}
    for name in ch['mns']:
        for c in ch['mns'][name]:
            r = {}
            for col, w in cols.items():
                v = c.get(keyname[col])
                r[col] = None if v is None else b(v, w)
            rows.append((name, r))
    return rows


# ---------------------------------------------------------------- the PSW and the common figures of chapter 9 (from the grammars)
def psw_chart(SYS):
    """the status word: the positions and the widths of spec/pdp64-system.hbnf (rules psw and psw-width); the gaps are reserved bits"""
    pos = dict(SYS['psw'])
    wid = dict(SYS['psw-width'])
    flat, top = [], 15
    for v, n, w in sorted(((v, n, wid.get(n, 1)) for n, v in pos.items()), reverse=True):
        if v + w - 1 < top:
            flat.append(('reserved', top - (v + w - 1), None))
        flat.append(({'pri': 'priority'}.get(n, n.upper() if len(n) <= 2 else n), w, None))
        top = v - 1
    if top >= 0:
        flat.append(('reserved', top + 1, None))
    return [('PSW', parcel_rows(flat)[0][1])]


def head_rows(G):
    return [('parcel 0', [(n if n != 'low' else 'low (mode / rm)', w, None) for n, w in G.head])]


# ---------------------------------------------------------------- pdp64/16 and pdp64/32
def _mangle(n):
    return re.sub(r'[./_]', '-', n)


def shape_describe(s):
    k = s['k']

    def reg(r):
        if r['k'] == 'K':
            return 'implicit register'
        return 'register, %d bits%s' % (r['w'], ' (an index into the hot-register table)' if r['table'] else '')
    sc = lambda x: 'the size of the access' if x == 'sz' else str(x)
    if k == 'R':
        return reg(s)
    if k == 'K':
        op = s['op']
        return 'implicit %s' % ('register r%d' % op[1] if op[0] == 'R' else 'constant %d' % op[1])
    if k == 'I':
        w = s['w']
        lo, hi = (-(1 << (w - 1)), (1 << (w - 1)) - 1) if s['signed'] else (0, (1 << w) - 1)
        return '%s %d-bit immediate%s, %d to %d' % ('signed' if s['signed'] else 'unsigned', w, '' if s['scale'] == 1 else ' times %d' % s['scale'], lo * s['scale'], hi * s['scale'])
    if k == 'B':
        base = 'sp' if s['rn']['k'] == 'K' and s['rn']['op'][1] == 14 else 'dp' if s['rn']['k'] == 'K' else 'base ' + reg(s['rn'])
        if not s['dw']:
            return 'memory at (%s)' % base
        w = s['dw']
        sca = s['scale']
        rng = ''
        if sca != 'sz':
            lo, hi = (-(1 << (w - 1)), (1 << (w - 1)) - 1) if s['signed'] else (0, (1 << w) - 1)
            rng = ', %d to %d bytes' % (lo * sca, hi * sca)
        return 'memory at %s + %s %d-bit displacement times %s%s' % (base, 'signed' if s['signed'] else 'unsigned', w, sc(sca), rng)
    if k == 'X':
        return 'memory at base + (index << scale)%s; base %s, index %s' % (' + %s %d-bit displacement' % ('signed' if s['signed'] else 'unsigned', s['dw']) if s['dw'] else '', reg(s['rn']), reg(s['rx']))
    if k in ('PI', 'PD'):
        return '%s of a base register (%s)%s' % ('post-increment' if k == 'PI' else 'pre-decrement', reg(s['rn']), ', %d-bit stride (0: the size of the access)' % s['dw'] if s['dw'] else '')
    if k == 'PC':
        return 'pc-relative, %d bits counted in %d-byte units (%d to %d bytes)' % (s['w'], s['unit'], -(1 << (s['w'] - 1)) * s['unit'], ((1 << (s['w'] - 1)) - 1) * s['unit'])
    if k == 'A':
        return 'absolute address, %d bits' % s['w']
    return k


class Enc:
    """One prefix-coded member: its charts, built from the grammar."""

    def __init__(self, tag):
        self.tag = tag
        self.d = encgram.load(tag, ROOT)
        d = self.d
        path = os.path.join(ROOT, 'spec', 'pdp64-' + tag, 'pdp64-%s.hbnf' % tag)
        self.rules, _ = encgram.read_rules(path)
        self.name = d['name']
        self.words = [m for f in d['forms'] for m in f['mns']]
        self.ext = set(d['ext'])
        self.charts = []
        self.byname = {}
        counts = {}
        for i, lf in enumerate(d['leaves']):
            f = d['forms'][lf['form']]
            counts[lf['form']] = counts.get(lf['form'], 0) + 1
            k = counts[lf['form']]
            cid = '%s-%s-%d' % (tag, _mangle(f['name']), k)
            ch = self.chart(lf, f, cid, k)
            self.charts.append(ch)
            for j, mn in enumerate(lf['mns']):
                self.byname.setdefault(mn, []).append((cid, ch, j))

    def operands(self, f):
        body = self.rules['form-' + _mangle(f['name'])][0].strip()
        if body == 'noop':
            return []
        return [t.split(':', 1)[1] for t in body.split()]

    def chart(self, lf, f, cid, k):
        d = self.d
        L = lf['L']
        items = encgram.leaf_pieces(lf, f['specs'])
        flat = [('prefix', L, format(lf['prefix'], '0%db' % L))]
        pos = L
        desc = []
        for p, nm, w, key in items:
            assert p == pos, (cid, p, pos)
            pos += w
            if nm.startswith('o'):
                lab = re.sub(r'^o(\d+)-', r'op\1.', nm)
                lab = re.sub(r'-(\d+)$', r'[\1]', lab) if re.search(r'-\d+$', nm) else lab
            else:
                lab = nm
            flat.append((lab, w, None))
        rows = parcel_rows(flat)
        shapes = self.operands(f)
        leg = []
        for i, sh in enumerate(shapes):
            leg.append('`op%d` is `%s`: %s.' % (i + 1, sh, shape_describe(f['specs'][i])))
        if lf['subbits']:
            nb = len(lf['subbits'])
            leg.append('`sub` (%d bit%s) selects the mnemonic: ' % (nb, '' if nb == 1 else 's') + ', '.join('`%s` %s' % (mn, format(j, '0%db' % nb)) for j, mn in enumerate(lf['mns'])) + '.')
        elif any(x[3] == ('xsub',) for x in items):
            leg.append('`xsub` selects the mnemonic.')
        return dict(id=cid, kind='enc', rows=rows, legend=leg, form=f['name'], L=L, prefix=format(lf['prefix'], '0%db' % L), parcels=f['n'],
                    mns=lf['mns'], title='%s, prefix `%s`' % (f['name'], format(lf['prefix'], '0%db' % L)), leaf=lf, formd=f, k=k,
                    fields=self.fieldpos(lf, f))

    @staticmethod
    def fieldpos(lf, f):
        out = []
        for p, nm, w, key in encgram.leaf_pieces(lf, f['specs']):
            hi = 15 - p % 16
            out.append('%s=p%d[%d:%d]' % (nm.replace('o', 'op', 1).replace('-', '.', 1) if nm.startswith('o') else nm, p // 16, hi, hi - w + 1 if (p % 16) + w <= 16 else 0))
        return ' '.join(out)

    def shapes_used(self):
        """name -> description for every operand shape the forms use, from the grammar"""
        seen = {}
        for f in self.d['forms']:
            for nm, spec in zip(self.operands(f), f['specs']):
                seen.setdefault(nm, shape_describe(spec))
        return seen

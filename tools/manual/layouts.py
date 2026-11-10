"""The bit-layout charts of the manual, generated from the grammars.

    the encoding   spec/pdp64-32/pdp64-32.hbnf and spec/pdp64-enc.hbnf, read by tools/encgram.py; spec/pdp64-mnemonics.hbnf (every number),
                   spec/pdp64-system.hbnf (the status word), spec/pdp64-layout.hbnf (what a field is called in each class)

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
def _rows_body(rows, y):
    """the SVG elements of the rows, the first row at height y; returns (elements, the next y)"""
    unit, left, top, rh, gap = 38, 74, 16, 36, 16
    out = []
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
    return out, y


WIDTH = 74 + 16 * 38 + 8


def svg_rows(rows):
    """rows: [(row label, [(field label, width in bits, value or None), ...]), ...]; each row is one 16-bit parcel.
    Draws the parcel as a row of boxes, widths proportional to the bits, bit numbers above, the fixed values shaded."""
    out, y = _rows_body(rows, 4)
    h = y + 4
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="DejaVu Sans, sans-serif">\n%s\n</svg>\n'
            % (WIDTH, h, WIDTH, h, '\n'.join(out)))


def svg_stack(items):
    """items: [(caption, rows)]: the charts one under the other, each under a caption line (the charts of one instruction word, one for each form it has)"""
    out, y = [], 4
    for cap, rows in items:
        out.append('<text x="8" y="%d" font-size="13" font-weight="bold" fill="#111">%s</text>' % (y + 14, esc(cap)))
        el, y = _rows_body(rows, y + 18)
        out += el
        y += 14
    h = y
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="DejaVu Sans, sans-serif">\n%s\n</svg>\n'
            % (WIDTH, h, WIDTH, h, '\n'.join(out)))


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

def role(kind, field, ln):
    return ROLE.get('%s:%s@%d' % (kind, field, ln)) or ROLE.get('%s:%s' % (kind, field)) or field


def b(v, w):
    return format(v, '0%db' % w)


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


# ---------------------------------------------------------------- the prefix-coded encoding
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

    def word_charts(self, name):
        """The charts of one word: for every leaf that has it, the leaf with the prefix and the sub-opcode of the word filled in: [(caption, rows)]"""
        out = []
        for cid, ch, j in self.byname[name]:
            lf, f = ch['leaf'], ch['formd']
            nb = len(lf['subbits']) or len(lf['place'][0][2] if lf['place'] and lf['place'][0][0] == -1 else [])
            bitsj = format(j, '0%db' % nb) if nb else ''
            flat = [('prefix', lf['L'], format(lf['prefix'], '0%db' % lf['L']))]
            used = 0
            for p, nm, w, key in encgram.leaf_pieces(lf, f['specs']):
                if nm.startswith('o'):
                    lab = re.sub(r'^o(\d+)-', r'op\1.', nm)
                    lab = re.sub(r'-(\d+)$', r'[\1]', lab) if re.search(r'-\d+$', nm) else lab
                    flat.append((lab, w, None))
                else:
                    flat.append((re.sub(r'-\d+$', '', nm), w, bitsj[used:used + w]))
                    used += w
            ops = ', '.join(self.operands(f)) or 'no operand'
            cap = '%s: %s, prefix %s%s; operands %s; %d bytes' % (name.upper(), f['name'], format(lf['prefix'], '0%db' % lf['L']), (', sub-opcode ' + bitsj) if bitsj else '', ops, 2 * f['n'])
            out.append((cap, parcel_rows(flat), 2 * f['n']))
        return out

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
        """`name=pK[hi:lo]` for each field, in record order; a field that crosses a parcel boundary is `pK[hi:0]+pK+1[15:lo]`"""
        out = []
        for p, nm, w, key in encgram.leaf_pieces(lf, f['specs']):
            segs, start, left = [], p, w
            while left:
                k, off = start // 16, start % 16
                take = min(left, 16 - off)
                hi = 15 - off
                segs.append('p%d[%d:%d]' % (k, hi, hi - take + 1) if take > 1 else 'p%d[%d]' % (k, hi))
                start += take
                left -= take
            label = re.sub(r'^o(\d+)-', r'op\1.', nm) if nm.startswith('o') else nm
            out.append('%s=%s' % (label, '+'.join(segs)))
        return ' '.join(out)

    def shapes_used(self):
        """name -> description for every operand shape the forms use, from the grammar"""
        seen = {}
        for f in self.d['forms']:
            for nm, spec in zip(self.operands(f), f['specs']):
                seen.setdefault(nm, shape_describe(spec))
        return seen


class _EncCache(dict):
    def __missing__(self, tag):
        self[tag] = Enc(tag)
        return self[tag]


ENC = _EncCache()

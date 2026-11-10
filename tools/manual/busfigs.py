"""The memory-layout figures of chapter 2 (the bus): boxes and arrows, as a textbook draws a linked list.

These are not instruction encodings, so they are not generated from the grammar; they are drawn here, by hand-written code, and
tools/mkmanual.py writes the ones the text names (figures/bus-NAME.svg) into the figures directory of every member's manual.
Every field offset and size drawn here is one of the checked facts listed in chapter 2 (section 2.12): the descriptor, the rings,
the configuration-space header, the base-address register, the MSI-X table entry.
All figures are 690 units wide, as the other figures of the manual are.
"""

W = 690
INK = '#222'
GREY = '#e6e6e6'
SOFT = '#f4f4f4'
BLUE = '#dce9f7'
FONT = 'DejaVu Sans, sans-serif'
MONO = 'DejaVu Sans Mono, monospace'


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


class Canvas:
    def __init__(self, h):
        self.h = h
        self.o = []

    def text(self, x, y, s, size=12, anchor='middle', fill='#111', mono=False, bold=False):
        self.o.append('<text x="%.1f" y="%.1f" font-size="%s" text-anchor="%s" fill="%s" font-family="%s"%s>%s</text>'
                      % (x, y, size, anchor, fill, MONO if mono else FONT, ' font-weight="bold"' if bold else '', esc(s)))

    def box(self, x, y, w, h, label='', fill='#fff', size=12, mono=False, bold=False, dash=False, sub=None):
        self.o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="%s" stroke-width="1.2"%s/>'
                      % (x, y, w, h, fill, INK, ' stroke-dasharray="4 3"' if dash else ''))
        if label:
            if sub:
                self.text(x + w / 2, y + h / 2 - 1, label, size, mono=mono, bold=bold)
                self.text(x + w / 2, y + h / 2 + 11, sub, 9, fill='#555')
            else:
                self.text(x + w / 2, y + h / 2 + size * 0.35, label, size, mono=mono, bold=bold)

    def line(self, pts, arrow=True, dash=False, width=1.4):
        d = ' '.join('%s%.1f,%.1f' % ('M' if i == 0 else 'L', x, y) for i, (x, y) in enumerate(pts))
        self.o.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s"%s/>' % (d, INK, width, ' stroke-dasharray="5 3"' if dash else ''))
        if arrow:
            (x0, y0), (x1, y1) = pts[-2], pts[-1]
            dx, dy = x1 - x0, y1 - y0
            n = (dx * dx + dy * dy) ** 0.5 or 1
            ux, uy = dx / n, dy / n
            px, py = -uy, ux
            a = 8
            self.o.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>'
                          % (x1, y1, x1 - ux * a + px * 3.6, y1 - uy * a + py * 3.6, x1 - ux * a - px * 3.6, y1 - uy * a - py * 3.6, INK))

    def svg(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="%s">\n%s\n</svg>\n'
                % (W, self.h, W, self.h, FONT, '\n'.join(self.o)))


def fig_unibus():
    """The PDP-11 address space and the registers of an RK11 in the I/O page (2.11BSD pdp driver text), next to the way a driver reaches them."""
    c = Canvas(300)
    # the address space, high addresses at the top
    x, w = 70, 150
    c.text(x + w / 2, 18, 'the 18-bit Unibus address space', 12, bold=True)
    c.box(x, 28, w, 56, 'I/O page', GREY, 13, sub='top 8 KB: 0760000-0777777')
    c.box(x, 84, w, 120, 'memory', '#fff', 13, sub='up to 0757777')
    c.box(x, 204, w, 30, 'interrupt vectors', SOFT, 11, sub='0-0377')
    c.text(x - 6, 36, '0777777', 9, 'end', '#555', True)
    c.text(x - 6, 240, '0', 9, 'end', '#555', True)
    # zoom into the I/O page: the six registers of the RK11
    rx, rw = 330, 120
    c.text(rx + 150, 18, 'an RK11 disk: six words at a fixed place', 12, bold=True)
    regs = [('RKDS', 'drive status (read only)'), ('RKER', 'error bits'), ('RKCS', 'control, status: GO, RDY, IDE'),
            ('RKWC', 'word count (negative)'), ('RKBA', 'bus address of the buffer'), ('RKDA', 'disk address')]
    for i, (n, d) in enumerate(regs):
        y = 28 + i * 32
        c.box(rx, y, rw, 32, n, '#fff', 12, mono=True, bold=True)
        c.text(rx + rw + 8, y + 20, d, 9, 'start', '#333')
    c.line([(x + w, 56), (rx - 16, 56), (rx - 16, 100), (rx - 2, 100)], arrow=True, dash=True)
    c.text(x, 270, 'a driver holds one pointer, the address of RKDS; each register is a field', 10, 'start', '#333')
    c.text(x, 286, '(the wiring, the vector and the CSR address, was set by switches on the card)', 10, 'start', '#555')
    return c.svg()


def fig_desc_chain():
    """Three descriptors chained into one request, drawn as the boxes of a linked list."""
    c = Canvas(380)
    xs = [30, 270, 510]
    cw, rh, top = 150, 26, 60
    names = [('desc[2]', 'request header'), ('desc[0]', 'data'), ('desc[4]', 'status')]
    vals = [
        [('addr', '0x...A000'), ('len', '16'), ('flags', 'NEXT'), ('next', '0')],
        [('addr', '0x...B000'), ('len', '512'), ('flags', 'NEXT|WRITE'), ('next', '4')],
        [('addr', '0x...C000'), ('len', '1'), ('flags', 'WRITE'), ('next', '-')],
    ]
    c.text(W / 2, 16, 'one request = one chain of descriptors, a linked list through the table', 12, bold=True)
    bufs = [('header', '16 bytes: type, ioprio, sector'), ('data', '512 bytes: the device writes it'), ('status', '1 byte: the device writes it')]
    for k, x in enumerate(xs):
        c.text(x + 2, top - 10, names[k][0], 11, 'start', bold=True, mono=True)
        for i, (f, v) in enumerate(vals[k]):
            y = top + i * rh
            c.box(x, y, 52, rh, f, GREY, 10)
            c.box(x + 52, y, cw - 52, rh, v, '#fff', 11, mono=True)
        # the buffer
        by = top + 4 * rh + 40
        bh = [40, 64, 26][k]
        c.box(x + 30, by, cw - 30, bh, bufs[k][0], '#fff' if k != 1 else BLUE, 11)
        c.text(x + 30, by + bh + 13, bufs[k][1], 9, 'start', '#555')
        # addr arrow: left of the card, down into the buffer
        c.line([(x, top + rh / 2), (x - 14, top + rh / 2), (x - 14, by + bh / 2), (x + 30, by + bh / 2)])
        # next arrow over the top to the next card
        if k < 2:
            ny = top + 3 * rh + rh / 2
            nx = xs[k + 1] + 100
            c.line([(x + cw, ny), (x + cw + 18, ny), (x + cw + 18, top - 24), (nx, top - 24), (nx, top - 2)])
    c.text(xs[2] + 75, top + 4 * rh + 12, '(end of chain: NEXT clear)', 10, fill='#555')
    c.text(W / 2, 372, 'The cards are not in the table in order: the chain 2, 0, 4 is the order of the links, as in any linked list. Indices are examples.', 10, fill='#555')
    return c.svg()


def fig_rings():
    """Descriptor table in the middle, the available ring on the left (driver writes), the used ring on the right (device writes)."""
    c = Canvas(330)
    c.text(W / 2, 16, 'the three structures of a virtqueue of size 4', 12, bold=True)
    # available ring
    ax, aw = 20, 190
    c.text(ax + aw / 2, 44, 'available ring', 12, bold=True)
    c.text(ax + aw / 2, 58, 'the driver writes, the device reads', 9, fill='#555')
    rows = [('flags', '16 bits'), ('idx', '16 bits: next slot to fill'), ('ring[0]', '2'), ('ring[1]', ''), ('ring[2]', ''), ('ring[3]', '')]
    for i, (n, v) in enumerate(rows):
        y = 66 + i * 30
        c.box(ax, y, 62, 30, n, GREY, 11, mono=True)
        c.box(ax + 62, y, aw - 62, 30, v, '#fff', 10 if i < 2 else 12, mono=(i >= 2))
    # descriptor table
    dx, dw = 255, 180
    c.text(dx + dw / 2, 44, 'descriptor table', 12, bold=True)
    c.text(dx + dw / 2, 58, '16 bytes a slot', 9, fill='#555')
    for i in range(4):
        y = 66 + i * 45
        c.box(dx, y, 50, 45, 'desc[%d]' % i, GREY, 10, mono=True)
        c.box(dx + 50, y, dw - 50, 45, 'addr len flags next', '#fff' if i == 2 else SOFT, 10)
    # used ring
    ux, uw = 480, 190
    c.text(ux + uw / 2, 44, 'used ring', 12, bold=True)
    c.text(ux + uw / 2, 58, 'the device writes, the driver reads', 9, fill='#555')
    rows = [('flags', '16 bits'), ('idx', '16 bits: next slot to fill'), ('ring[0]', 'id 2  len 513'), ('ring[1]', ''), ('ring[2]', ''), ('ring[3]', '')]
    for i, (n, v) in enumerate(rows):
        y = 66 + i * 30
        c.box(ux, y, 62, 30, n, GREY, 11, mono=True)
        c.box(ux + 62, y, uw - 62, 30, v, '#fff', 10 if i < 2 else 11, mono=(i >= 2))
    # arrows: avail.ring[0] -> desc[2]; desc[2] -> used.ring[0]
    ya, yd = 66 + 2 * 30 + 15, 66 + 2 * 45 + 22
    c.line([(ax + aw, ya), (dx - 18, ya), (dx - 18, yd), (dx, yd)])
    c.line([(dx + dw, yd), (dx + dw + 22, yd), (dx + dw + 22, ya), (ux, ya)])
    c.text(W / 2, 266, 'The driver offers a chain by writing its head into ring[idx mod size] and then adding 1 to idx.', 10, fill='#333')
    c.text(W / 2, 282, 'The device reports it done by writing (head, bytes written) into the used ring and then adding 1 to its idx.', 10, fill='#333')
    c.text(W / 2, 298, 'Each side keeps its own private count of how far it has read the other side\'s ring. Indices are examples.', 10, fill='#555')
    return c.svg()


def fig_config_header():
    """The 64-byte header of a configuration space (type 0), and the capability list as a linked list."""
    rows = [
        (0x00, [('Device ID', 16), ('Vendor ID', 16)]),
        (0x04, [('Status', 16), ('Command', 16)]),
        (0x08, [('Class code', 24), ('Rev', 8)]),
        (0x0C, [('BIST', 8), ('Header type', 8), ('Latency', 8), ('Cache line', 8)]),
        (0x10, [('BAR0', 32)]), (0x14, [('BAR1', 32)]), (0x18, [('BAR2', 32)]),
        (0x1C, [('BAR3', 32)]), (0x20, [('BAR4', 32)]), (0x24, [('BAR5', 32)]),
        (0x28, [('CardBus CIS pointer', 32)]),
        (0x2C, [('Subsystem ID', 16), ('Subsystem vendor ID', 16)]),
        (0x30, [('Expansion ROM base address', 32)]),
        (0x34, [('Capabilities pointer', 8), ('reserved', 24)]),
        (0x38, [('reserved', 32)]),
        (0x3C, [('(other fields)', 16), ('Int pin', 8), ('Int line', 8)]),
    ]
    rh, top = 22, 40
    c = Canvas(top + len(rows) * rh + 34)
    c.text(20, 18, 'configuration space header, 64 bytes (the first 256 of the 4096 of a PCI Express function)', 12, 'start', bold=True)
    x0, w32 = 60, 360
    c.text(x0, top - 6, 'bit 31', 9, 'start', '#555')
    c.text(x0 + w32, top - 6, '0', 9, 'end', '#555')
    for i, (off, fl) in enumerate(rows):
        y = top + i * rh
        c.text(x0 - 6, y + 15, '%02X' % off, 10, 'end', '#555', True)
        x = x0
        for (name, bits) in fl:
            w = w32 * bits / 32
            fill = BLUE if name.startswith('BAR') else (SOFT if name.startswith('reserved') or name.startswith('(') else '#fff')
            if name == 'Capabilities pointer':
                fill = '#fbe9c8'
            c.box(x, y, w, rh, name.replace('Capabilities pointer', 'Cap. pointer'), fill, 9 if w < 80 else 10)
            x += w
    # capability list
    cx, cw = 470, 205
    cap_y = [top + 3 * rh, top + 8 * rh, top + 13 * rh]
    caps = [('MSI-X capability', 'id 0x11 | next', 'table: BAR, offset'), ('virtio capability', 'id 0x09 | next | len', 'cfg_type 1 = common'), ('virtio capability', 'id 0x09 | next=0 | len', 'cfg_type 2 = notify')]
    for k in range(3):
        y = cap_y[k]
        c.box(cx, y, cw, 56, '', '#fbe9c8')
        c.text(cx + cw / 2, y + 14, caps[k][0], 11, bold=True)
        c.text(cx + cw / 2, y + 31, caps[k][1], 10, mono=True)
        c.text(cx + cw / 2, y + 47, caps[k][2], 9, fill='#555')
        if k < 2:
            c.line([(cx + 12, y + 56), (cx + 12, cap_y[k + 1])])
    # arrow from the capabilities pointer (row 0x34) to the first record
    py = top + 13 * rh + rh / 2
    c.line([(x0 + w32, py), (x0 + w32 + 20, py), (x0 + w32 + 20, top + 2 * rh + 8), (cx + 60, top + 2 * rh + 8), (cx + 60, cap_y[0])])
    c.text(cx + cw / 2, top - 6, 'capability list: records linked by "next"', 9, fill='#555')
    return c.svg()


def fig_bar_window():
    """A base-address register, the sizing trick, and the window in the physical address map."""
    c = Canvas(350)
    c.text(20, 18, 'a base-address register (BAR) and the window it places in the physical address space', 12, 'start', bold=True)
    # BAR register, 32 bits
    x0, w = 20, 400
    fields = [('base address bits 31..4', 28), ('P', 1), ('type', 2), ('S', 1)]
    c.text(x0, 42, 'bit 31', 9, 'start', '#555')
    c.text(x0 + w, 42, '0', 9, 'end', '#555')
    x = x0
    for name, bits in fields:
        fw = w * bits / 32
        if bits == 28:
            fw = w - 3 * 36
        else:
            fw = 36
        c.box(x, 48, fw, 34, name, '#fff' if bits == 28 else GREY, 10 if bits == 28 else 11)
        x += fw
    c.text(x0, 98, 'S: 0 = memory, 1 = I/O port    type: 00 = 32-bit, 10 = 64-bit    P: prefetchable', 9, 'start', '#555')
    # sizing example
    c.box(x0, 112, 400, 62, '', SOFT)
    c.text(x0 + 8, 128, 'size it: write all ones, read it back, clear the low four bits', 10, 'start', bold=True)
    c.text(x0 + 8, 144, 'write 0xFFFFFFFF  ->  read 0xFFFFC000', 10, 'start', mono=True)
    c.text(x0 + 8, 160, 'size = (not 0xFFFFC000) + 1 = 0x4000 = 16 KB', 10, 'start', mono=True)
    # the address map
    mx, mw = 500, 170
    c.text(mx + mw / 2, 42, 'physical address space', 11, bold=True)
    segs = [('top: 2^N, N = 40 to 64', None, 20), ('free', '#fff', 40), ('window of device B', BLUE, 40), ('free', '#fff', 30), ('window of device A', BLUE, 40),
            ('free / RAM', '#fff', 70), ('first few pages:', GREY, 30)]
    y = 50
    for name, fill, h in segs:
        if fill is None:
            c.text(mx + mw / 2, y + 12, name, 9, fill='#555')
            y += h
            continue
        sub = None
        if name.startswith('window'):
            sub = 'a whole number of pages'
        if name.startswith('first'):
            c.box(mx, y, mw, h, 'boot code and data', fill, 10)
        else:
            c.box(mx, y, mw, h, name, fill, 10, sub=sub)
        y += h
    c.text(mx - 6, y, '0', 9, 'end', '#555', True)
    # arrow from BAR register to window A
    wa_y = 50 + 20 + 40 + 40 + 30 + 20
    c.line([(x0 + w, 66), (mx - 30, 66), (mx - 30, wa_y), (mx, wa_y)])
    c.text(x0 + 4, 192, 'The firmware or kernel writes the base it chooses; the device then', 10, 'start', '#333')
    c.text(x0 + 4, 206, 'answers base .. base+size-1 and no others. A window may sit anywhere', 10, 'start', '#333')
    c.text(x0 + 4, 220, 'except the first few pages (errata 97, 102). The drawing is an example;', 10, 'start', '#333')
    c.text(x0 + 4, 234, 'where the windows really sit is not decided.', 10, 'start', '#333')
    c.text(x0 + 4, 262, 'a 64-bit BAR: two consecutive BARs, the low half first', 10, 'start', bold=True)
    c.box(x0, 270, 200, 28, 'BAR2: low 32 bits (type = 10)', GREY, 10)
    c.box(x0 + 200, 270, 200, 28, 'BAR3: high 32 bits', '#fff', 10)
    c.text(x0 + 4, 316, 'Sizing rule as in the header comment of pci_regs.h.', 9, 'start', '#555')
    return c.svg()


def fig_msix():
    """The MSI-X capability, the table it points at (in a BAR), and one entry: the message that the device writes."""
    c = Canvas(350)
    c.text(20, 18, 'MSI-X: an interrupt is a table entry the device turns into one memory write', 12, 'start', bold=True)
    # capability
    cx, cw = 20, 200
    c.text(cx + cw / 2, 44, 'MSI-X capability (in config space)', 10, bold=True)
    cap = [('id 0x11 | next', ''), ('Message control', 'enable | mask all | table size - 1'), ('Table offset | BIR', 'which BAR, where in it'), ('PBA offset | BIR', 'pending bits: same idea')]
    for i, (a, b) in enumerate(cap):
        c.box(cx, 52 + i * 40, cw, 40, a, '#fbe9c8', 11, mono=True, sub=b or None)
    # table
    tx, tw = 275, 150
    c.text(tx + tw / 2, 44, 'the table (in a BAR)', 10, bold=True)
    for i in range(4):
        c.box(tx, 52 + i * 34, tw, 34, 'entry %d' % i if i < 3 else 'entry N-1', BLUE if i == 1 else '#fff', 11, mono=True)
    c.line([(cx + cw, 52 + 2 * 40 + 20), (tx - 22, 52 + 2 * 40 + 20), (tx - 22, 52 + 14), (tx, 52 + 14)])
    # an entry
    ex, ew = 475, 190
    c.text(ex + ew / 2, 44, 'one entry, 16 bytes', 10, bold=True)
    ent = [('0x0', 'Message address, low 32 bits'), ('0x4', 'Message address, high 32 bits'), ('0x8', 'Message data, 32 bits'), ('0xC', 'Vector control: bit 0 = masked')]
    for i, (o, d) in enumerate(ent):
        y = 52 + i * 34
        c.box(ex, y, 34, 34, o, GREY, 10, mono=True)
        c.box(ex + 34, y, ew - 34, 34, d, '#fff' if i < 3 else SOFT, 10)
    c.line([(tx + tw, 52 + 34 + 17), (ex - 14, 52 + 34 + 17), (ex - 14, 52 + 17), (ex, 52 + 17)], arrow=False, dash=True)
    # the write
    c.text(W / 2, 232, 'When the device has something to report on vector 1 and the entry is not masked, it performs', 11, fill='#111')
    c.box(80, 244, 530, 34, 'memory write:  address = (high, low)   data = Message data', '#fff', 12, mono=True)
    c.text(W / 2, 300, 'The address is a location the interrupt controller watches; no wire, no vector number from the card, no BR level.', 10, fill='#333')
    c.text(W / 2, 316, 'If the entry is masked the device sets the vector\'s bit in the pending-bit array and sends nothing until it is unmasked.', 10, fill='#555')
    c.text(W / 2, 332, 'Offsets and bit positions as in pci_regs.h (PCI_MSIX_*). The entry numbers are examples.', 9, fill='#555')
    return c.svg()


def fig_hierarchy():
    """The tree: root complex, root ports, bridge/switch, endpoints, with bus numbers."""
    c = Canvas(300)
    c.text(20, 18, 'a PCI Express tree: a bus of point-to-point links, not a shared set of wires', 12, 'start', bold=True)
    c.box(260, 34, 170, 44, 'CPU + memory', SOFT, 12, bold=True, sub='the host')
    c.box(240, 100, 210, 44, 'root complex', GREY, 12, bold=True, sub='bus 0: the root of the tree')
    c.line([(345, 78), (345, 100)], arrow=False)
    # endpoints and bridge
    c.box(20, 196, 150, 44, 'virtio-blk', BLUE, 12, mono=True, sub='bus 1, endpoint')
    c.box(200, 196, 150, 44, 'virtio-net', BLUE, 12, mono=True, sub='bus 2, endpoint')
    c.box(420, 160, 150, 34, 'bridge / switch', GREY, 11, bold=True, sub=None)
    c.box(370, 224, 130, 44, 'USB', BLUE, 11, mono=True, sub='host controller, bus 3')
    c.box(530, 224, 130, 44, 'any other card', '#fff', 11, sub='bus 3, endpoint')
    c.line([(290, 144), (290, 170), (95, 170), (95, 196)], arrow=False)
    c.line([(290, 170), (275, 170), (275, 196)], arrow=False)
    c.line([(400, 144), (400, 152), (495, 152), (495, 160)], arrow=False)
    c.line([(495, 194), (495, 208), (435, 208), (435, 224)], arrow=False)
    c.line([(495, 208), (595, 208), (595, 224)], arrow=False)
    c.text(20, 284, 'each line is a link: one or more lanes, each a pair of one-way wire pairs', 10, 'start', '#555')
    c.text(20, 297, 'Bus numbers and the shape are examples.', 9, 'start', '#555')
    return c.svg()


FIGURES = {
    'bus-unibus': ('The Unibus: address space and the registers of a disk', fig_unibus),
    'bus-tree': ('A PCI Express tree', fig_hierarchy),
    'bus-config-header': ('The configuration-space header and the capability list', fig_config_header),
    'bus-bar-window': ('A base-address register and its window', fig_bar_window),
    'bus-desc-chain': ('A chain of descriptors', fig_desc_chain),
    'bus-rings': ('The descriptor table, the available ring and the used ring', fig_rings),
    'bus-msix': ('An MSI-X table entry', fig_msix),
}

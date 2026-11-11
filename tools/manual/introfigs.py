"""The box-and-arrow figures of chapter 1 (the introduction): the machine and where the chapters describe it, one instruction word of the
PDP-11 beside one of the pdp64, and the road from the PDP-11 in three tracks (the processor, the bus, the terminal); and of chapter 10
(the conclusion): the estimated transistor budget of a core and the path to the finish line.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/intro-NAME.svg) into the figures directory of the manual.
What is drawn is what chapter 1 states and what the other chapters decide: the PDP-11 word is read in the PDP-11/70 handbook
(section 3.2: a four-bit operation code and two six-bit operand fields, each a three-bit mode and a three-bit register); the pdp64
word is the leaf LDF.PI12 of the grammar (prefix 011111, a four-bit sub-opcode, a base register of five bits split over the two
parcels, a destination register of five bits, a stride of twelve bits).  All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE
from kernfigs import PINK, GREEN, YELLOW


def fig_machine():
    """The pdp64 as a system: cores, memory, the PCI Express bus and the standard devices, each with the chapter that describes it."""
    c = Canvas(450)
    c.text(W / 2, 16, 'the pdp64 as a system, with the chapter that describes each part', 12, bold=True)
    cx, cw = 20, 270
    c.box(cx, 34, cw, 24, 'cores: at least four, all the same (chapter 7)', GREY, 11, bold=True)
    for i, n in enumerate(['core 0', 'core 1', 'core 2', 'core 3']):
        x = cx + (i % 2) * 138
        y = 66 + (i // 2) * 92
        c.box(x, y, 132, 86, '', '#fff')
        c.text(x + 66, y + 15, n, 10, bold=True)
        for j, t in enumerate(['32 registers of 64 bits', 'status word, modes (6)', 'translation buffer (6)', 'instructions of 2, 4, 6 bytes (9)']):
            c.text(x + 66, y + 30 + j * 14, t, 8.5)
    c.box(cx, 262, cw, 44, 'memory: one address space, shared by every core', BLUE, 11, sub='sequentially consistent between cores (7); page tables (6)')
    c.line([(cx + cw / 2, 250), (cx + cw / 2, 262)])
    bx = 340
    c.box(bx, 34, 330, 24, 'PCI Express: the one bus (chapter 2)', YELLOW, 11, bold=True)
    devs = [('virtio-blk: the disk', 'the boot ROM reads block 0 from it (4, 5)'), ('virtio-net: the network card', 'chapter 5'),
            ('virtio-gpu: the display', 'HDMI or another standard output (3)'), ('virtio-snd: the sound device', 'chapter 3'),
            ('USB controller', 'keyboard and mouse (5)'), ('any other PCI Express card', 'found by enumeration (2)'),
            ('accelerators for vector work', 'devices, not units of the processor (8)')]
    for i, (a, b) in enumerate(devs):
        y = 68 + i * 40
        c.box(bx + 24, y, 306, 34, a, PINK, 10.5, sub=b)
        c.line([(bx + 8, y + 17), (bx + 24, y + 17)], arrow=False)
    c.line([(bx + 8, 58), (bx + 8, 68 + 6 * 40 + 17)], arrow=False)
    c.line([(cx + cw, 158), (bx + 8, 158)], arrow=False)
    c.text(cx + cw + 24, 150, 'loads and stores', 8.5, 'middle', '#555')
    c.line([(cx + cw, 284), (bx + 8, 284)], arrow=False)
    c.text(cx + cw + 24, 276, 'DMA (2)', 8.5, 'middle', '#555')
    y0 = 360
    c.text(20, y0, 'A device is a few memory locations that ordinary loads and stores reach (2.3): the PDP-11 had no input or output instructions either.', 9, 'start', '#333')
    c.text(20, y0 + 16, 'Every standard device is a virtio device or a USB controller (5.3); the driver finds it by identifier, not by a switch setting (2.4).', 9, 'start', '#333')
    c.text(20, y0 + 32, 'Starting: a ROM reads block 0 and jumps to it (4); the kernel then runs the machine (6); the instruction set is chapter 9.', 9, 'start', '#333')
    c.text(20, y0 + 56, 'A box is a part and a line joins two parts that talk; this is the architecture as it is to be decided (section 1.2).', 9, 'start', '#555')
    return c.svg()


def bits(c, x, y, widths, labels, fills, h=34, unit=24, size=10):
    """A row of fields: widths in bits, drawn unit units to a bit."""
    for w, lab, f in zip(widths, labels, fills):
        c.box(x, y, w * unit, h, lab, f, size)
        x += w * unit
    return x


def fig_words():
    """One PDP-11 instruction word and the pdp64 instruction that does the same load, field by field."""
    c = Canvas(300)
    c.text(W / 2, 16, 'one instruction word of the PDP-11, and the same kind of instruction on the pdp64', 12, bold=True)
    u = 19
    x0 = 20
    c.text(x0, 40, 'PDP-11:  mov (r1)+,(r0)+   = 012120 octal, 16 bits, memory to memory', 10.5, 'start', bold=True, mono=True)
    bits(c, x0, 50, [4, 3, 3, 3, 3], ['opcode 01', 'mode 2', 'reg 1', 'mode 2', 'reg 0'], [GREY, YELLOW, PINK, YELLOW, PINK], unit=u)
    c.text(x0, 100, 'source: mode 2 is autoincrement, register 1;  destination: mode 2, register 0;  an extra word follows only for the modes 6 and 7,', 9, 'start', '#333')
    c.text(x0, 112, 'and for modes 2 and 3 on register 7 (immediate, absolute); so the length, 2, 4 or 6 bytes, depends on both six-bit fields.', 9, 'start', '#333')
    c.text(x0, 144, 'pdp64:  movq (r1)+, r0   = 2 parcels of 16 bits (4 bytes), one memory operand', 10.5, 'start', bold=True, mono=True)
    bits(c, x0, 154, [6, 4, 1, 5], ['prefix 011111', 'sub-op', 'b', 'rd: 5'], [GREY, BLUE, PINK, PINK], unit=u)
    bits(c, x0 + 16 * u + 20, 154, [4, 12], ['b: 4', 'stride: 12'], [PINK, YELLOW], unit=u)
    c.text(x0 + 8 * u, 204, 'first parcel', 9, 'middle', '#555')
    c.text(x0 + 16 * u + 20 + 8 * u, 204, 'second parcel', 9, 'middle', '#555')
    c.text(x0, 226, 'prefix: a bit pattern that no other prefix begins; it alone says which instruction this is and that it is two parcels long (9.1).', 9, 'start', '#333')
    c.text(x0, 238, 'sub-op: which of the sixteen operations of this form (here movq); b: the five bits of the base register, one in the first parcel and four in the second;', 9, 'start', '#333')
    c.text(x0, 250, 'rd: the destination register, five bits because there are thirty-two; stride: how far the base register moves afterwards, 0 meaning the size of the access.', 9, 'start', '#333')
    c.text(x0, 272, 'The PDP-11 word is read from the handbook (11/70, section 3.2); the pdp64 fields are the leaf LDF.PI12 of the grammar (dictionary/by-encoding.md).', 9, 'start', '#555')
    c.text(x0, 288, 'The assembler spells the pdp64 instruction as shown in the heading of this figure (appendix E).', 9, 'start', '#555')
    return c.svg()


def fig_road():
    """Three tracks from the PDP-11 to the pdp64: the processor, the bus, the terminal."""
    c = Canvas(380)
    c.text(W / 2, 16, 'the road from the PDP-11: each step and what it gave', 12, bold=True)
    tracks = [
        ('the processor', [('PDP-11', 'orthogonal modes, PC, SP'), ('VAX-11', '32 bits, virtual memory'),
                           ('68000, x86, RISC', 'restart and encoding lessons'), ('pdp64', '64 bits, 32 registers, restartable')]),
        ('the bus', [('Unibus', 'devices are memory, CSR, DMA'), ('VAX nexus', 'devices found by scanning'),
                     ('PCI', 'devices describe themselves'), ('PCI Express + virtio', 'one transport for every device')]),
        ('the terminal', [('teletype', 'a stream of characters'), ('VT52', 'a screen addressed by position'),
                          ('Blit, C64', 'text, sprites, sound by stores'), ('virtio-gpu + HDMI', 'the same, modern depth')]),
    ]
    bw, gap = 150, 23
    for r, (name, steps) in enumerate(tracks):
        y = 34 + r * 112
        c.text(20, y + 4, name, 10.5, 'start', bold=True)
        for i, (a, b) in enumerate(steps):
            x = 20 + i * (bw + gap)
            fill = GREEN if i == 3 else (GREY if i == 0 else SOFT)
            c.box(x, y + 10, bw, 56, a, fill, 11, bold=True, sub=b)
            if i < 3:
                c.line([(x + bw, y + 38), (x + bw + gap, y + 38)])
    c.text(20, 364, 'Chapters: processor 9 and 6; bus 2 and 5; terminal 3.  Steps between are named in the chapters; the author\'s dated record is appendix G.', 9, 'start', '#555')
    return c.svg()


def fig_budget():
    """The transistor estimate of 10.2, one bar a block, drawn to scale."""
    rows = [('register file, 16 x 64 (earlier estimate)', 6000), ('ALU, shifter, address adder', 15000), ('decode and sequencer', 6500),
            ('bit unit', 3500), ('block-move sequencer', 1500), ('UTF-8 decode and validity', 1200),
            ('translation buffer, walker, windows', 19000), ('floating-point unit with fused multiply-add', 34000),
            ('control, status word, exceptions, undo buffer', 5500)]
    c = Canvas(60 + len(rows) * 26 + 50)
    c.text(W / 2, 16, 'the estimated transistors of a core, excluding caches (about 92,000, an estimate)', 12, bold=True)
    scale = 330 / 34000.0
    for i, (n, v) in enumerate(rows):
        y = 34 + i * 26
        c.text(20, y + 15, n, 10, 'start')
        c.box(300, y + 3, max(2, v * scale), 18, '', BLUE if v in (3500, 1500, 1200) else GREY)
        c.text(300 + v * scale + 6, y + 16, '%s' % format(v, ','), 9.5, 'start', '#333')
    y = 34 + len(rows) * 26 + 10
    c.text(20, y + 8, 'The three blue bars (bit unit, block moves, UTF-8) add up to 6,200: under 7% of the total (10.2.2).', 9.5, 'start', '#333')
    c.text(20, y + 24, 'A 32-register file would about double the first bar (inference); the decoder for the prefix code is not re-estimated.', 9.5, 'start', '#555')
    return c.svg()


def fig_finish():
    """The five things of 10.5.1 and how they depend on each other, ending in the ssh test."""
    c = Canvas(340)
    c.text(W / 2, 16, 'the finish line: what builds what, and the test', 12, bold=True)
    c.box(20, 40, 150, 46, 'assembler', GREY, 12, bold=True, sub='source to object')
    c.box(200, 40, 150, 46, 'linker', GREY, 12, bold=True, sub='objects to a program')
    c.box(380, 40, 290, 46, 'LLVM back end and clang', GREY, 12, bold=True, sub='OpenBSD builds with clang (unverified)')
    c.line([(170, 63), (200, 63)])
    c.line([(350, 63), (380, 63)])
    c.box(20, 140, 220, 56, 'emulator: a machine model', BLUE, 12, bold=True, sub='with virtio devices: disk and network')
    c.box(380, 140, 290, 56, 'OpenBSD: kernel and userland', PINK, 12, bold=True, sub='built by the tools above, with sshd')
    c.line([(525, 86), (525, 140)])
    c.line([(240, 168), (380, 168)])
    c.text(310, 160, 'runs it', 9, 'middle', '#555')
    c.box(380, 250, 290, 46, 'ssh to the machine gives a login shell', GREEN, 12, bold=True, sub='the test of the finish line')
    c.line([(525, 196), (525, 250)])
    c.box(20, 250, 220, 46, 'then the same system on the FPGA', SOFT, 11, sub='and after it, silicon')
    c.line([(380, 273), (240, 273)])
    c.text(20, 322, 'If OpenBSD proves too hard, a port of Unix/32V is the fallback; it would give a shell on the emulator and no ssh (10.5.3).', 9.5, 'start', '#333')
    return c.svg()


FIGURES = {
    'intro-machine': ('The pdp64 as a system, with the chapter that describes each part', fig_machine),
    'intro-words': ('One instruction word of the PDP-11 and the pdp64 compared', fig_words),
    'intro-road': ('The road from the PDP-11 in three tracks', fig_road),
    'conc-budget': ('The estimated transistors of a core', fig_budget),
    'conc-finish': ('The finish line: what builds what, and the test', fig_finish),
}

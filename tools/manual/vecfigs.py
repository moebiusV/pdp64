"""The box-and-arrow figures of chapter 8 (vector work and accelerators): the state each machine adds for floating-point and
vector work, four ways to add two arrays, and the route of a request to an accelerator device.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/vec-NAME.svg) into the figures directory of the manual.
What is drawn is what chapter 8 states: the V7 floating-point state (read in the V7 sources on this machine: user.h, mch.s),
the register counts in the Linux 2.6.33.2 headers (read), the unverified machines marked as such, and, for the device route, an
illustration of a descriptor whose format is open (8.4.4).  All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE
from kernfigs import PINK, GREEN, YELLOW


def lines(c, x, y, ss, size=9, anchor='start', fill='#222', gap=12, mono=False):
    for i, s in enumerate(ss):
        c.text(x, y + i * gap, s, size, anchor, fill, mono)


def fig_state():
    """The bytes of floating-point or vector register state that a process owns, drawn to one scale."""
    c = Canvas(300)
    c.text(20, 16, 'floating-point and vector state that a context switch has to save, to one scale', 12, 'start', bold=True)
    rows = [
        ('PDP-11, V7 (FP11)', 50, 'status word + six 8-byte accumulators: 50 bytes (user.h, mch.s)', SOFT),
        ('pdp64', 0, 'no register file of its own; the flags in FPSR (9.12.3)', GREEN),
        ('x86, SSE', 256, '16 registers of 16 bytes = 256 bytes (Linux processor.h: xmm_space)', BLUE),
        ('PowerPC, AltiVec', 512, '32 registers of 16 bytes = 512 bytes, and two more (Linux processor.h)', BLUE),
        ('VAX 6000, vector facility', 8192, '16 registers of 64 elements of 8 bytes = 8192 bytes (unverified)', PINK),
    ]
    x0, scale = 170, 400.0 / 8192
    for i, (name, n, note, fill) in enumerate(rows):
        y = 40 + i * 44
        c.text(x0 - 8, y + 15, name, 10, 'end', bold=True)
        w = max(n * scale, 2)
        c.box(x0, y, w, 22, '', fill)
        c.text(x0 + w + 6, y + 15, '%d' % n if n else '0 extra', 10, 'start', bold=True)
        c.text(x0, y + 36, note, 8, 'start', '#555')
    lines(c, 20, 276, ['A bar is the number of bytes that the kernel must save at a switch and restore when the process runs again.',
                       'Sizes of the VAX facility and of the SSE and AltiVec register counts as the notes in 8.2 say; the V7 and Linux figures were read.'], 8, fill='#555', gap=12)
    return c.svg()


def fig_shapes():
    """Four ways to add two arrays of 64 numbers: scalar loop, SIMD register, vector register, device."""
    c = Canvas(440)
    c.text(20, 16, 'c = a + b over 64 numbers: four shapes', 12, 'start', bold=True)

    def cells(x, y, n, w, h, fill):
        for k in range(n):
            c.box(x + k * w, y, w, h, '', fill)
    # 1 scalar
    c.text(20, 40, '1. scalar loop (PDP-11 with the FP11)', 10, 'start', bold=True)
    cells(20, 48, 16, 14, 18, SOFT)
    c.text(250, 61, '... 64 passes: load, add, store, count down; one number each', 9, 'start')
    # 2 SIMD
    c.text(20, 92, '2. SIMD (MMX, SSE, AltiVec, NEON): one instruction, a fixed number of lanes', 10, 'start', bold=True)
    c.box(20, 100, 112, 22, 'register of 4 lanes (128 bits)', BLUE, 8)
    for k in range(4):
        c.box(24 + k * 27, 124, 25, 14, '', BLUE)
    c.text(150, 118, '64 numbers need 16 such adds, and a different instruction for 8 lanes (AVX) or 16 (AVX-512)', 9, 'start')
    c.text(150, 132, 'the width is in the instruction, so a wider generation is a new instruction set', 9, 'start')
    # 3 vector machine
    c.text(20, 172, '3. vector machine (Cray-1, VAX vector facility): one instruction, a length in a register', 10, 'start', bold=True)
    for k in range(32):
        c.box(20 + k * 8, 180, 8, 18, '', PINK)
    c.text(290, 190, 'a register holds 64 numbers; VL says how many to use', 9, 'start')
    c.text(290, 203, 'vadd v2, v0, v1 does all 64; a longer array is cut into pieces of 64', 9, 'start')
    # 4 device
    c.text(20, 240, '4. device: a descriptor in memory names the operation, the arrays and the length', 10, 'start', bold=True)
    c.box(20, 250, 150, 56, '', YELLOW)
    lines(c, 28, 266, ['op: add', 'a, b, c: addresses', 'n = 64 (or 64 million)', 'status: 0'], 9)
    c.box(210, 250, 110, 56, 'device', GREEN, 12, bold=True, sub='reads a and b, writes c')
    c.line([(170, 278), (210, 278)])
    c.text(340, 268, 'no register file in the processor; the length is a field,', 9, 'start')
    c.text(340, 282, 'so one descriptor serves any size (8.5.4)', 9, 'start')
    c.text(340, 296, 'the price: a descriptor to build and a status to wait for', 9, 'start')
    lines(c, 20, 340, ['The descriptor drawn is an illustration; its format is open (8.4.4).'], 8, fill='#555')
    lines(c, 20, 354, ['Machines 1 and 2 as described in 8.1 and 8.2: the V7 sources and the Linux headers were read, the rest is unverified.'], 8, fill='#555')
    return c.svg()


def fig_route():
    """One request to an accelerator: the six steps between the processor, memory and the device."""
    c = Canvas(380)
    c.text(20, 16, 'the route of one request to an accelerator device (an illustration of 8.4)', 12, 'start', bold=True)
    c.box(20, 56, 150, 60, 'processor', GREY, 12, bold=True, sub='ordinary loads and stores')
    c.box(270, 48, 200, 150, '', SOFT)
    c.text(370, 64, 'RAM (uncached for the device)', 10, 'middle', bold=True)
    c.box(280, 72, 180, 40, 'descriptor', YELLOW, 11, bold=True, sub='op, array addresses, length, status')
    c.box(280, 122, 84, 66, 'arrays a, b', BLUE, 10, sub='the inputs')
    c.box(376, 122, 84, 66, 'array c', BLUE, 10, sub='the result')
    c.box(580, 56, 90, 60, 'device', GREEN, 12, bold=True, sub='the accelerator')
    c.line([(170, 80), (270, 80)])
    c.text(220, 74, '1 fill', 9)
    c.line([(95, 56), (95, 34), (625, 34), (625, 56)], dash=True)
    c.text(360, 29, '3 doorbell: a store to an address of the device', 9)
    c.line([(470, 90), (580, 90)])
    c.text(525, 84, '4 device reads', 9)
    c.line([(580, 150), (470, 150)])
    c.text(525, 144, '5 device writes', 9)
    c.line([(270, 104), (170, 104)], dash=True)
    c.text(220, 120, '6 reads status', 9)
    c.text(20, 140, '2 FENCE: the descriptor is', 9, 'start', bold=True)
    c.text(20, 153, 'visible before the doorbell', 9, 'start', bold=True)
    lines(c, 20, 226, ['PDP-11: the same shape as the RK11 with its registers replaced by a record in memory (5.1): the program',
                       '   fills it, starts the device, and learns by the RDY bit or an interrupt.',
                       'pdp64: the record is in memory and can chain; the device reads it and the arrays by DMA (direct memory access:',
                       '   the device moves data without the processor) and writes the result and a status.',
                       'The processor owes the device two things: memory the device sees in order, and FENCE (8.4.3).',
                       'The instruction set is unchanged. Whether the record is a virtio descriptor, or one that points at it, is open (8.4.4).'], 9, gap=15)
    lines(c, 20, 342, ['Sources: V7 rk.c (read), chapter 5 (5.4, 5.10), chapter 2 (2.5).'], 8, fill='#555')
    return c.svg()


FIGURES = {
    'vec-state': ('The state that floating-point and vector work adds, to one scale', fig_state),
    'vec-shapes': ('Four ways to add two arrays', fig_shapes),
    'vec-route': ('The route of one request to an accelerator', fig_route),
}

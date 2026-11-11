"""The box-and-arrow figures of chapter 7 (several processors): two cores racing for a lock, the store buffer and the
store-buffering litmus test, a snooping cache invalidating the other cores' copies, the per-CPU pointer, and a translation shootdown
beside the broadcast invalidate.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/smp-NAME.svg) into the figures directory of the manual.
The facts drawn are the decided ones of chapter 7 (sequential consistency, the atomics, the three-state snooping of the first device,
the banked DP, the broadcast TLBI with TLBSYNC); the Linux 2.6.33 shootdown on the right of the last figure is read in
arch/x86/mm/tlb.c of that tree (section 7.14 of the chapter).  All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE

PINK = '#f7e3dc'
GREEN = '#e1f0dd'
YELLOW = '#fbf2cf'


def fig_lock_race():
    """The V7 test-then-set lock on two cores, and the same lock taken with one atomic exchange."""
    c = Canvas(262)
    c.text(165, 16, 'V7 plock(), test then set: two cores', 12, bold=True)
    c.text(520, 16, 'one atomic exchange: the test and the set are one step', 12, bold=True)
    c.text(75, 40, 'core 0', 11, bold=True)
    c.text(215, 40, 'core 1', 11, bold=True)
    c.text(430, 40, 'core 0', 11, bold=True)
    c.text(590, 40, 'core 1', 11, bold=True)
    rows = [52, 94, 136, 178]
    left = [(0, 'ILOCK is clear', GREY), (1, 'ILOCK is clear', GREY), (0, 'set ILOCK, use the inode', YELLOW), (1, 'set ILOCK, use the inode', PINK)]
    for (col, lab, fill), y in zip(left, rows):
        c.box(20 + col * 140, y, 130, 30, lab, fill, 10)
    right = [(0, 'old = 0: owns it', GREEN), (1, 'old = 1: waits', GREY), (0, 'lock = 0 (release)', GREY), (1, 'old = 0: owns it', GREEN)]
    for (col, lab, fill), y in zip(right, rows):
        c.box(365 + col * 160, y, 140, 30, lab, fill, 10)
    c.line([(12, 52), (12, 208)], arrow=True)
    c.text(12, 222, 'time', 9, 'middle', '#555')
    c.line([(352, 52), (352, 208)], arrow=True)
    c.line([(345, 24), (345, 245)], arrow=False, dash=True, width=0.8)
    c.text(165, 236, 'both cores now hold the lock', 10, 'middle', '#a33', bold=True)
    c.text(520, 236, 'exactly one core holds it at any time', 10, 'middle', '#2a6a2a', bold=True)
    c.text(165, 254, 'correct on one core only because nothing runs between the test and the set', 9, 'middle', '#555')
    c.text(520, 254, 'SWAP (or CAS) on the lock word; the memory system makes it indivisible', 9, 'middle', '#555')
    return c.svg()


def fig_store_buffer():
    """The store-buffering litmus test: a plain store buffer allows r0 = r1 = 0, sequential consistency does not."""
    c = Canvas(300)
    c.text(345, 16, 'store buffering: x = y = 0 at the start', 12, bold=True)
    for k, (x0, name, prog, wr, rd, other) in enumerate([(30, 'core 0', ['x = 1', 'r0 = y'], 'x = 1', 'reads y: 0', 'y'),
                                                          (390, 'core 1', ['y = 1', 'r1 = x'], 'y = 1', 'reads x: 0', 'x')]):
        c.box(x0, 30, 270, 128, '', SOFT)
        c.text(x0 + 135, 46, name, 11, bold=True)
        c.box(x0 + 12, 54, 110, 26, prog[0], BLUE, 11, mono=True)
        c.box(x0 + 12, 84, 110, 26, prog[1], BLUE, 11, mono=True)
        c.box(x0 + 148, 54, 108, 26, 'store buffer: ' + wr, YELLOW, 10, mono=False)
        c.text(x0 + 202, 98, 'not yet in memory', 9, 'middle', '#555')
        c.box(x0 + 148, 108, 108, 26, rd, PINK, 10)
        c.line([(x0 + 122, 67), (x0 + 148, 67)], arrow=True)
        c.line([(x0 + 122, 97), (x0 + 148, 121)], arrow=True, dash=True)
    c.box(250, 190, 190, 34, 'memory: x = 0, y = 0', GREY, 11)
    c.line([(165, 158), (165, 207), (250, 207)], arrow=True, dash=True)
    c.line([(525, 158), (525, 207), (440, 207)], arrow=True, dash=True)
    c.text(345, 244, 'the outcome r0 = 0 and r1 = 0 needs both loads to pass both stores', 10, 'middle', '#333')
    c.text(345, 260, 'a plain store buffer lets them: that is total store order (x86, SPARC)', 10, 'middle', '#a33', bold=True)
    c.text(345, 276, 'the pdp64 forbids it: a load waits for older stores, or is replayed (7.5.2, 7.7.3)', 10, 'middle', '#2a6a2a', bold=True)
    return c.svg()


def fig_coherence():
    """Snooping with three states: a write invalidates the other cores' copies; a DMA buffer is outside it."""
    c = Canvas(330)
    c.text(345, 16, 'three-state snooping (modified, shared, invalid) on the four cores of the first device', 12, bold=True)
    for row, (y0, title, states, fills) in enumerate([
            (30, 'before: all four cores read the line holding x', ['S x=5', 'S x=5', 'S x=5', 'I'], [BLUE, BLUE, BLUE, GREY]),
            (130, 'after core 0 executes x = 6', ['M x=6', 'I', 'I', 'I'], [YELLOW, GREY, GREY, GREY])]):
        c.text(20, y0 + 6, title, 10, 'start', '#333', bold=True)
        for k in range(4):
            x = 20 + k * 120
            c.box(x, y0 + 16, 100, 22, 'core %d' % k, SOFT, 10)
            c.box(x, y0 + 38, 100, 26, states[k], fills[k], 10, mono=True)
    c.text(20, 224, 'the write puts an invalidate on the bus; every other cache that holds the line drops it,', 10, 'start', '#333')
    c.text(20, 238, 'and the next read of x by core 1 is a miss that is served by core 0 (the line is modified there)', 10, 'start', '#333')
    c.line([(70, 196), (570, 196)], arrow=False, width=2.2)
    c.text(630, 200, 'snoop bus', 10, 'start', '#555')
    for k in range(4):
        c.line([(70 + k * 120, 194), (70 + k * 120, 196)], arrow=False)
    c.line([(70, 164), (70, 196)], arrow=True)
    c.box(20, 262, 150, 40, 'memory', GREY, 11)
    c.line([(95, 196), (95, 262)], arrow=False)
    c.box(210, 262, 210, 40, 'virtio device (DMA)', GREEN, 11, sub='buffers uncached; explicit hand-off')
    c.line([(315, 196), (315, 262)], arrow=False, dash=True)
    c.text(440, 275, 'a device is not snooped: its buffers are', 9, 'start', '#555')
    c.text(440, 288, 'uncached and handed over by a fence (7.6.2)', 9, 'start', '#555')
    return c.svg()


def fig_percpu():
    """The kernel's DP on each core points at that core's own structure; the user DP points at a thread block."""
    c = Canvas(286)
    c.text(345, 16, 'banked DP: the per-CPU pointer in kernel mode, the thread pointer in user mode', 12, bold=True)
    c.text(95, 38, 'cores', 10, 'middle', '#555')
    c.text(335, 38, 'kernel mode: DP', 10, 'middle', '#555')
    c.text(575, 38, 'memory', 10, 'middle', '#555')
    for k in range(3):
        y = 48 + k * 58
        c.box(20, y, 150, 44, 'core %d' % k, SOFT, 11, bold=True)
        c.box(185, y + 4, 90, 17, 'DP (kernel)', YELLOW, 9, mono=True)
        c.box(185, y + 23, 90, 17, 'DP (user)', GREY, 9, mono=True)
        c.box(440, y + 4, 230, 17, 'per-CPU structure of core %d' % k, BLUE, 10)
        c.box(440, y + 23, 230, 17, 'thread block of the thread now on core %d' % k, GREY, 9)
        c.line([(275, y + 12), (440, y + 12)], arrow=True)
        c.line([(275, y + 31), (440, y + 31)], arrow=True, dash=True)
    c.text(20, 234, 'a field of this core\'s structure: MOVQ d(DP), Rd, a six-byte load; no search, no swapgs, no reserved register', 10, 'start', '#333')
    c.text(20, 250, 'an interrupt that arrives in user mode finds this core\'s kernel R14 and DP already in place (7.8.4, 6.2)', 10, 'start', '#333')
    c.text(20, 266, 'MFCPUID gives the core number, which no program can compute (7.8.1)', 10, 'start', '#333')
    return c.svg()


def fig_shootdown():
    """A translation shootdown by inter-processor interrupt (Linux 2.6.33) beside the pdp64's broadcast invalidate."""
    c = Canvas(262)
    c.text(165, 16, 'by software: Linux 2.6.33, x86', 12, bold=True)
    c.text(520, 16, 'pdp64: broadcast and wait', 12, bold=True)
    c.line([(345, 24), (345, 255)], arrow=False, dash=True, width=0.8)
    steps_l = ['1  change the page-table entry', '2  take the lock of one of 8 IPI vectors', '3  write the mm and address, set the mask of cores',
               '4  send an inter-processor interrupt to them', '5  each core runs its handler: invalidate, clear its bit', '6  spin until the mask is empty; unlock']
    for i, s in enumerate(steps_l):
        c.box(20, 30 + i * 36, 310, 28, s, YELLOW if i in (3, 5) else GREY, 10)
    steps_r = ['1  change the page-table entry', '2  TLBI rN   (every core drops the translation)', '3  TLBSYNC   (wait until every core has)']
    for i, s in enumerate(steps_r):
        c.box(365, 30 + i * 36, 305, 28, s, GREEN if i else GREY, 10, mono=(i > 0))
    c.text(365, 156, 'three lines of kernel code, no interrupt, no lock, no handler', 10, 'start', '#2a6a2a', bold=True)
    c.text(365, 174, 'a core that is running with interrupts masked is still', 9, 'start', '#555')
    c.text(365, 187, 'reached: the hardware delivers the invalidate, not an interrupt', 9, 'start', '#555')
    c.text(365, 215, 'the kernel half is global or window-mapped, so a kernel', 9, 'start', '#555')
    c.text(365, 228, 'mapping never takes part in a shootdown (7.8.3)', 9, 'start', '#555')
    return c.svg()


FIGURES = {
    'smp-lock-race': ('Two cores taking a lock: test then set, and one atomic exchange', fig_lock_race),
    'smp-store-buffer': ('The store-buffering litmus test', fig_store_buffer),
    'smp-coherence': ('Three-state snooping and the uncached DMA buffer', fig_coherence),
    'smp-percpu': ('DP as the per-CPU pointer and the thread pointer', fig_percpu),
    'smp-shootdown': ('A translation shootdown beside the broadcast invalidate', fig_shootdown),
}

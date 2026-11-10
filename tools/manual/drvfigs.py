"""The box-and-arrow figures of chapter 5 (drivers): the structure of a driver on the PDP-11 and on the pdp64, the life of one block
request, the layers from a system call to the device, the interrupt path, and the console and timer as the options stand.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/drv-NAME.svg) into the figures directory of every member's manual.
What is drawn is what chapter 5 states: the V7 and 2.11BSD facts of 5.1 (read in the sources on this machine), the decided and
proposed statements of 5.3 to 5.11, and, in the last figure, options that are open (5.7).  No pdp64 driver exists: the pdp64 side
of the figures is an illustration of the design.  All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE
from kernfigs import PINK, GREEN, YELLOW


def lines(c, x, y, ss, size=9, anchor='start', fill='#222', gap=12, mono=False):
    for i, s in enumerate(ss):
        c.text(x, y + i * gap, s, size, anchor, fill, mono)


def fig_structures():
    """The four parts of a driver on the PDP-11, and the same four on the pdp64."""
    c = Canvas(400)
    c.text(20, 16, 'the structure of a driver: the PDP-11 (V7, 2.11BSD) beside the pdp64', 12, 'start', bold=True)
    c.text(20, 38, 'PDP-11', 11, 'start', bold=True)
    c.text(360, 38, 'pdp64 (an illustration: no driver exists)', 11, 'start', bold=True)
    # left
    c.box(20, 48, 300, 48, 'bdevsw[6]: rkopen, rkclose, rkstrategy, ...', GREY, 10, mono=True, sub='the device switch: the major number picks the row')
    c.box(20, 116, 300, 40, 'rkstrategy, rkstart', PINK, 11, bold=True, sub='queue the buf, load the registers')
    c.box(20, 176, 300, 108, '', '#fff')
    lines(c, 28, 192, ['registers at 0177400 (set by switches):', '  RKDS  RKER  RKCS  RKWC  RKBA  RKDA', '', 'RKCS: GO 01, IDE 0100, RDY 0200, ERR 0100000'], 9, mono=True)
    c.box(20, 304, 300, 40, 'vector 0220: rkintr, priority 5', YELLOW, 11, mono=True, sub='the device supplies it; BR5')
    c.line([(170, 96), (170, 116)])
    c.line([(170, 156), (170, 176)])
    c.line([(170, 284), (170, 304)], dash=True)
    # right
    c.box(360, 48, 310, 48, 'match, attach, strategy, intr (OpenBSD cfattach)', GREY, 10, mono=True, sub='found by vendor and device ID: 0x1AF4, 0x1040 + type')
    c.box(360, 116, 310, 40, 'transport + class driver', PINK, 11, bold=True, sub='handshake, queues, requests')
    c.box(360, 176, 150, 108, '', '#fff')
    lines(c, 366, 192, ['a PCI Express function', 'common configuration:', ' device_status 0x14', ' queue_select 0x16', ' queue_desc 0x20 ...', 'ordinary loads, stores'], 9)
    c.box(530, 176, 140, 108, '', SOFT)
    lines(c, 536, 192, ['queues in memory:', ' descriptor table', ' available ring', ' used ring', '(uncached, 5.10)'], 9)
    c.line([(510, 230), (530, 230)], arrow=True, dash=True)
    c.box(360, 304, 310, 40, 'MSI-X entry: address, data, per queue', YELLOW, 11, mono=True, sub='a write; the vector number is the controller\'s (open, R1)')
    c.line([(515, 96), (515, 116)])
    c.line([(515, 156), (515, 176)])
    c.line([(515, 284), (515, 304)], dash=True)
    c.text(20, 370, 'What a driver was told on the PDP-11 (the address, the vector, the level) it asks or reads on the pdp64; what it knew (the register bits) it negotiates.', 9, 'start', '#444')
    c.text(20, 384, 'Sources: V7 rk.c, 2.11BSD rkreg.h, pdp/conf.c, pdp/scb.s (read); virtio_pci.h, OpenBSD vioblk.c (read); chapter 2.', 8, 'start', '#555')
    return c.svg()


def fig_block_request():
    """One virtio-blk request: the chain, the buffers, the two rings, and the six steps in order."""
    c = Canvas(420)
    c.text(20, 16, 'the life of one block request (a read of one sector) on the pdp64', 12, 'start', bold=True)
    # buffers
    c.text(20, 40, 'the two rings', 10, 'start', bold=True)
    xs = [20, 250, 480]
    names = [('header (16 bytes)', ['type 0 = read', 'ioprio 0', 'sector 12'], GREY), ('data buffer (512 bytes)', ['the device writes it', '(WRITE flag set)', ''], YELLOW), ('status (1 byte)', ['0 OK, 1 I/O error', '2 unsupported', ''], GREEN)]
    for x, (n, ls, f) in zip(xs, names):
        c.box(x, 330, 190, 56, '', f)
        c.text(x + 95, 343, n, 10, bold=True)
        lines(c, x + 10, 357, [l for l in ls if l], 9, gap=11)
    # descriptor table
    descs = [('desc[0]', 'len 16, NEXT', 'next = 1'), ('desc[1]', 'len 512, NEXT|WRITE', 'next = 2'), ('desc[2]', 'len 1, WRITE', 'end')]
    for x, (n, a, b) in zip(xs, descs):
        c.box(x, 230, 190, 52, '', '#fff')
        c.text(x + 95, 246, n + ': addr, len, flags, next', 9, bold=True, mono=False)
        c.text(x + 10, 262, a, 9, 'start', '#222', True)
        c.text(x + 10, 275, b, 9, 'start', '#222', True)
        c.line([(x + 95, 282), (x + 95, 330)])
    c.line([(210, 256), (250, 256)], arrow=True)
    c.line([(440, 256), (480, 256)], arrow=True)
    c.text(20, 220, 'the descriptor table (three descriptors chained by next) and the buffers they point to', 10, 'start', bold=True)
    # rings
    c.box(20, 52, 300, 46, '', SOFT)
    c.text(30, 68, 'available ring (the driver writes)', 10, 'start', bold=True)
    c.text(30, 84, 'idx = 1    ring[0] = 0  (head: desc[0])', 9, 'start', '#222', True)
    c.box(370, 52, 300, 46, '', SOFT)
    c.text(380, 68, 'used ring (the device writes)', 10, 'start', bold=True)
    c.text(380, 84, 'idx = 1    ring[0] = { id 0, len 513 }', 9, 'start', '#222', True)
    # steps
    steps = ['1  the driver fills the header and the three descriptors', '2  it writes the head (0) into the available ring, executes FENCE, then adds 1 to its idx',
             '3  it writes the queue\'s notification address (the doorbell; FENCE ordered)', '4  the device reads the chain, moves the sector into the buffer, writes the status byte',
             '5  it writes { id, len } in the used ring, then adds 1 to the used idx', '6  an interrupt (or the driver polling used.idx) lets the driver read the status, free the chain, iodone(bp)']
    lines(c, 20, 120, steps, 9.5, gap=15)
    c.text(20, 408, 'Sizes and flags as in chapter 2 (2.7.5 to 2.7.7) and virtio_blk.h; the numbers 12 and 513 are an example.  The data is written before the used entry before the used idx (5.10.3).', 8, 'start', '#555')
    return c.svg()


def fig_layers():
    """The layers a read crosses, PDP-11 and pdp64."""
    c = Canvas(380)
    c.text(20, 16, 'from a system call to the device: the layers, on both machines', 12, 'start', bold=True)
    left = [('read(fd, buf, n)', '#fff', 'a user program'), ('file system, buffer cache (bread)', GREY, 'bdevsw[major].d_strategy(bp)'), ('rkstrategy: queue the buf', PINK, 'spl5 ... spl0'),
            ('rkstart: write RKDA, RKBA, RKWC, RKCS', PINK, 'one transfer at a time'), ('RK11 and the RK05 disk', YELLOW, 'interrupt: rkintr, iodone')]
    right = [('read(fd, buf, n)', '#fff', 'a user program'), ('file system, buffer cache (bread)', GREY, 'bdevsw[major].d_strategy(bp)  (sd)'), ('sdstrategy -> SCSI layer: scsi_xs_exec', PINK, 'OpenBSD scsi/sd.c, scsi_base.c'),
             ('vioblk_scsi_cmd: header, data, status descriptors', PINK, 'post(q, head): FENCE, doorbell'), ('virtio-blk device; queue in memory', YELLOW, 'MSI-X vector: vioblk_vq_done, iodone')]
    for x0, col, title in ((20, left, 'PDP-11 (V7, 2.11BSD)'), (360, right, 'pdp64 (OpenBSD vioblk; an illustration)')):
        c.text(x0, 38, title, 11, 'start', bold=True)
        for i, (t, f, s) in enumerate(col):
            y = 48 + i * 58
            c.box(x0, y, 310, 40, t, f, 10, sub=s)
            if i < 4:
                c.line([(x0 + 155, y + 40), (x0 + 155, y + 58)])
    c.text(20, 350, 'The raw interface skips the cache: rawrw -> physio -> strategy; on the pdp64 physio pins the pages and gives one descriptor per page (5.6, 5.10.2).', 9, 'start', '#444')
    c.text(20, 364, 'Sources: V7 rk.c, 2.11BSD conf.c and vm_swp.c (read); OpenBSD vioblk.c, sd.c, conf.c (read).  Each layer of the right column is OpenBSD code; none is built for the pdp64.', 8, 'start', '#555')
    return c.svg()


def fig_interrupt_path():
    """The interrupt from the device to the handler, on both machines."""
    c = Canvas(330)
    c.text(20, 16, 'the interrupt path from the device to the handler', 12, 'start', bold=True)
    c.text(20, 38, 'PDP-11', 11, 'start', bold=True)
    row1 = [('RK11 done', 'asserts BR5', GREY), ('processor', 'priority below 5?', GREY), ('vector 0220', 'new PC and PS (br5)', YELLOW), ('rkintr', 'reads RKCS, iodone', PINK), ('RTI', 'old PC and PS back', GREY)]
    bw, gap = 108, 22
    for i, (a, b, f) in enumerate(row1):
        x = 20 + i * (bw + gap)
        c.box(x, 48, bw, 44, a, f, 10, sub=b)
        if i < 4:
            c.line([(x + bw, 70), (x + bw + gap, 70)])
    c.text(20, 132, 'pdp64', 11, 'start', bold=True)
    row2 = [('device writes', 'address, data (MSI-X)', GREY), ('interrupt controller', 'not specified (R1)', SOFT), ('core: vector n', 'ECAUSE = n; priority 7', YELLOW), ('handler at VBR+8n', 'reads the used ring', PINK), ('RTI', 'EPC, EPSW back', GREY)]
    for i, (a, b, f) in enumerate(row2):
        x = 20 + i * (bw + gap)
        c.box(x, 142, bw, 44, a, f, 10, sub=b, dash=(i == 1))
        if i < 4:
            c.line([(x + bw, 164), (x + bw + gap, 164)])
    lines(c, 20, 218, ['PDP-11: a wire and a level shared by every device on it; the vector was set by switches on the card; the handler asks the CSR what happened.',
                       'pdp64: a memory write that cannot pass the data written before it (5.9.4); one vector for each queue; the handler asks the used ring.',
                       'The dashed box is open: which unit receives the write, how a core is chosen and how the vector number is made are decision R1 (appendix B, 2.6.3).'], 9, gap=15)
    c.text(20, 290, 'Sources: 2.11BSD pdp/scb.s (DEVTRAP(220, rkintr, br5)); chapter 6 (6.3.1 to 6.3.6) for the entry; chapter 2 (2.6) for MSI-X.', 8, 'start', '#555')
    c.text(20, 304, 'The priority of 7 on entry is the PDP-11\'s own habit (errata 40); the handler lowers it with SPL.', 8, 'start', '#555')
    return c.svg()


def fig_console_timer():
    """The console, the timer and the entropy source as the options stand: all open (5.7.1)."""
    c = Canvas(380)
    c.text(20, 16, 'the console, timer and entropy source: the options (OPEN, 5.7.1; nothing decided)', 12, 'start', bold=True)
    cols = [('console', [('fixed registers (KL11 shape)', 'a fixed device with a few registers', SOFT), ('virtio-console, queues 0 and 1', 'plus emerg_wr: one-character write', SOFT), ('16550-style UART', 'a common serial chip', SOFT)]),
            ('timer', [('fixed counter + compare', 'a fixed device with a vector of its own', SOFT), ('counter and compare in the core', 'system registers', SOFT), ('virtio clock / rtc', 'read and alarm requests; no tick', SOFT)]),
            ('entropy', [('virtio-rng, one queue', 'the device fills a buffer', SOFT), ('absorb-and-squeeze pool', 'errata 85; a fixed device', SOFT), ('software and a boot seed only', 'no entropy hardware', SOFT)])]
    cw, gap = 210, 20
    for j, (title, items) in enumerate(cols):
        x = 20 + j * (cw + gap)
        c.box(x, 32, cw, 28, title, GREY, 12, bold=True)
        for i, (a, b, f) in enumerate(items):
            y = 70 + i * 62
            c.box(x, y, cw, 52, a, f, 10, sub=b, dash=(f == SOFT))
    c.box(20, 262, 650, 30, '', '#fff')
    lines(c, 28, 276, ['Every box is a candidate; none is chosen.'], 9)
    lines(c, 28, 288, ['Whether these three follow "virtio across the board" (errata 95) is part of what is open.'], 9)
    lines(c, 20, 314, ['A virtio-console needs the bus and a queue before it can print; its emergency write needs the bus and no queue.  A fixed console needs neither.',
                       'Sources: spec/pdp64-system.hbnf, qemu/hw-pdp64, virtio_console.h, virtio_rtc.h, QEMU virtio-rng.c (read)'], 8, fill='#555', gap=14)
    return c.svg()


FIGURES = {
    'drv-structures': ('The structure of a driver: the PDP-11 and the pdp64', fig_structures),
    'drv-block-request': ('The life of one block request', fig_block_request),
    'drv-layers': ('The layers from a system call to the device', fig_layers),
    'drv-interrupt-path': ('The interrupt path from the device to the handler', fig_interrupt_path),
    'drv-console-timer': ('The console, the timer and the entropy source: the options', fig_console_timer),
}

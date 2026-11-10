"""The box-and-arrow figures of chapter 4 (boot): the chain of stages, memory when block 0 is loaded, the disk layout, the
boot-information block, the start of the other cores as a time line, the PC's path beside the pdp64's, and the place of a UEFI shim.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/boot-NAME.svg) into the figures directory of the manual.
What is drawn is what chapter 4 states: the decided and proposed statements of 4.3 to 4.10 and the V7M and 2.11BSD facts of 4.1
(checked against the sources on this machine, section 4.12).  Arrangements marked 'example' or 'not specified' in a figure are
illustrations: the boot-information block's field order and widths, the load address of block 0 and the size of the
first few pages are not decided (4.6, 4.4, 4.13).  The PC half of the sixth figure is general knowledge, unverified (4.12).
All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE
from kernfigs import PINK, GREEN, YELLOW


def lines(c, x, y, ss, size=9, anchor='start', fill='#222', gap=12, mono=False):
    for i, s in enumerate(ss):
        c.text(x, y + i * gap, s, size, anchor, fill, mono)


def fig_stages():
    """The four stages as a chain, with what each knows and what it hands on."""
    c = Canvas(330)
    c.text(20, 16, 'the boot stages: each is small, knows one more thing than the one before, and hands on a little', 12, 'start', bold=True)
    cols = [('boot ROM', 'in the controller chip', GREY,
             ['knows: a boot device,', 'how to read one block', 'from a virtio-blk disk', '', 'does not know: partitions,', 'files, a label, a kernel']),
            ('block 0', 'first stage: one block', PINK,
             ['knows: where the second', 'stage lies on the disk', 'and how to read it', '', 'does not know: a file', 'system, a kernel']),
            ('second stage', 'a C program, any size', YELLOW,
             ['knows: the disk, the file', 'system, how to find the', 'kernel by name', '', 'is an ordinary program']),
            ('kernel', '/bsd, an ELF file', GREEN,
             ['knows: everything else:', 'enumerates the bus,', 'attaches the drivers', '', 'owns the machine'])]
    cw, gap, x0 = 140, 32, 20
    for i, (name, sub, fill, ss) in enumerate(cols):
        x = x0 + i * (cw + gap)
        c.box(x, 36, cw, 44, name, fill, 12, bold=True, sub=sub)
        c.box(x, 80, cw, 116, '', '#fff')
        lines(c, x + 8, 98, ss, 9)
        if i < 3:
            c.line([(x + cw, 58), (x + cw + gap, 58)], arrow=True)
    hand = [('block 0 is read into', 'low memory; core 0', 'starts at it'), ('the first stage loads', 'the second stage', ''),
            ('the kernel gets a', 'boot-information', 'block')]
    for i, hs in enumerate(hand):
        cx = x0 + i * (cw + gap) + cw + gap / 2
        c.line([(cx, 200), (cx, 214)], arrow=False, dash=True, width=0.8)
        lines(c, cx, 226, hs, 9, 'middle', '#333')
    c.text(20, 284, 'Stage sizes are the reason for the stages: the ROM and the first block are the smallest code that can be made to find the next,', 9, 'start', '#444')
    c.text(20, 297, 'and only the second stage is big enough to read a file system.', 9, 'start', '#444')
    c.text(20, 316, 'The kernel is OpenBSD (errata 41 and 47).', 9, 'start', '#555')
    return c.svg()


def fig_block0_memory():
    """Memory at the moment block 0 has been loaded, and the registers core 0 starts with."""
    c = Canvas(380)
    c.text(20, 16, 'the instant core 0 starts: block 0 is in memory, one core runs, the rest are in reset', 12, 'start', bold=True)
    x, w = 130, 230
    c.box(x, 30, w, 30, 'RAM, and the windows of devices', '#fff', 10, sub='no window in the first few pages')
    c.box(x, 60, w, 40, 'loaded later: second stage, kernel', SOFT, 10, sub='above the first 64 KB (illustration)')
    c.box(x, 100, w, 50, 'stack', GREEN, 11, bold=True, sub='r14 = the top of the first 64 KB; grows down')
    c.box(x, 150, w, 36, 'boot-information block', YELLOW, 11, bold=True, sub='r1 points here; place not specified')
    c.box(x, 186, w, 42, 'block 0: 512 bytes from the disk', PINK, 11, bold=True, sub='0x1000 (an address still to be chosen)')
    c.box(x, 228, w, 74, 'vector table: one page', BLUE, 11, bold=True, sub='512 x 8 bytes = 4096 bytes; VBR = 0')
    c.text(x - 8, 108, '0x10000', 9, 'end', '#555', True)
    c.text(x - 8, 197, '0x1200', 9, 'end', '#555', True)
    c.text(x - 8, 232, '0x1000', 9, 'end', '#555', True)
    c.text(x - 8, 308, '0', 9, 'end', '#555', True)
    c.line([(x - 54, 150), (x - 62, 150), (x - 62, 302), (x - 54, 302)], arrow=False, width=1.2)
    c.text(x - 68, 222, 'the first', 9, 'end', '#222')
    c.text(x - 68, 234, 'few pages', 9, 'end', '#222')
    # registers of core 0
    rx = 420
    c.text(rx, 40, 'core 0 at that instant', 11, 'start', bold=True)
    regs = [('PC', '0x1000', 'the first instruction of block 0'), ('r0', 'device', 'the boot device number'), ('r1', 'address', 'of the boot-information block'),
            ('r14', '0x10000', 'top of the first 64 KB'), ('others', '0', 'zero')]
    for i, (n, v, d) in enumerate(regs):
        y = 50 + i * 26
        c.box(rx, y, 50, 24, n, GREY, 10, mono=True, bold=True)
        c.box(rx + 50, y, 70, 24, v, '#fff', 10, mono=True)
        c.text(rx + 128, y + 16, d, 9, 'start', '#333')
    lines(c, rx, 198, ['mode: kernel, priority 7, translation off:', 'every address is a physical address;', 'the user-memory guard is clear'], 9, fill='#222')
    c.line([(x + w + 10, 207), (rx - 6, 207), (rx - 6, 66), (rx - 2, 66)], arrow=True, dash=True, width=0.9)
    lines(c, rx, 252, ['the other cores: held in reset by the', 'controller until core 0 writes their', 'start registers (4.7)'], 9, fill='#222')
    c.text(20, 340, '0x1000 and the 64 KB stack top follow the proposal of 4.4 and the figure of chapter 6; how many pages are reserved is not decided (errata 102).', 9, 'start', '#444')
    c.text(20, 354, 'Not to scale.  The ROM itself is not in this memory: it sits in the controller chip, outside the address space the kernel uses.', 9, 'start', '#444')
    c.text(20, 368, 'On the PDP-11 the vectors sat at 0 to 0377 and the bootstrap was loaded elsewhere, often high in memory (4.1).', 9, 'start', '#555')
    return c.svg()


def fig_disk_layout():
    """The disk: protective MBR, GPT, partitions, and inside the OpenBSD partition the boot area and the label."""
    c = Canvas(430)
    c.text(20, 16, 'one disk, three zooms: the whole disk, block 0, and the pdp64 partition', 12, 'start', bold=True)
    # row 1: the disk
    c.text(20, 32, 'the disk', 10, 'start', bold=True)
    c.text(84, 32, 'each cell is a run of 512-byte sectors, not to scale; sector counts are 64-bit (4.5.4)', 9, 'start', '#555')
    segs = [('LBA 0', 'protective', 'MBR', PINK, 66), ('LBA 1', 'GPT', 'header', GREY, 50), ('LBA 2..', 'GPT partition', 'entries', GREY, 82),
            ('', 'OpenBSD-type partition', 'holds the label', YELLOW, 190),
            ('', 'other partitions', '(any system)', '#fff', 130), ('end', 'backup', 'GPT', GREY, 62)]
    x = 20
    pos = []
    for lba, a, b, fill, w in segs:
        c.box(x, 48, w, 56, a, fill, 9, bold=True, sub=b)
        if lba:
            c.text(x + 2, 44, lba, 8, 'start', '#555', True)
        pos.append((x, w))
        x += w
    # row 2: block 0
    c.text(20, 148, 'block 0, the protective MBR: 512 bytes', 10, 'start', bold=True)
    c.line([(pos[0][0] + 10, 104), (30, 156)], arrow=False, dash=True, width=0.8)
    c.line([(pos[0][0] + 56, 104), (670, 156)], arrow=False, dash=True, width=0.8)
    bx, bw = 20, 650
    c.box(bx, 158, bw * 446 / 512, 40, 'boot code: 446 bytes', PINK, 11, bold=True, sub='the boot code area of the MBR format')
    c.box(bx + bw * 446 / 512, 158, bw * 64 / 512, 40, 'table', GREY, 10, bold=True, sub='64 bytes')
    c.box(bx + bw * 510 / 512, 158, bw * 2 / 512, 40, '', BLUE)
    c.text(bx + bw, 212, 'table: four entries; a GPT disk has one, of type 0xEE ("the whole disk is in use")', 8, 'end', '#333')
    c.text(bx + bw, 224, 'last two bytes: 0x55AA, the signature', 8, 'end', '#222')
    c.text(bx, 212, 'byte 0', 8, 'start', '#555', True)
    c.text(bx + bw * 446 / 512, 190, '', 8)
    c.text(bx, 224, 'byte 446 starts the table', 8, 'start', '#555', True)
    # row 3: the OpenBSD partition
    c.text(20, 250, 'inside the OpenBSD-type partition (the yellow cell above; 4.5.3)', 10, 'start', bold=True)
    inner = [('sector 0', 'boot block', PINK, 96), ('sector 1', 'disk label', YELLOW, 96), ('sectors 2 to 15', 'rest of the 8 KB boot area', GREY, 190),
             ('sector 16 on', 'the file system; its superblock at byte 8192', GREEN, 268)]
    x = 20
    for a, b, fill, w in inner:
        c.box(x, 262, w, 46, a, fill, 10, bold=True, sub=b)
        x += w
    c.text(20, 326, 'The label (offset 0 of sector 1) has the magic number 0x82564557 and names up to 16 partitions (root, swap, ...);', 9, 'start', '#222')
    c.text(20, 339, 'its sizes carry high fields beyond 32 bits.  The kernel is a file in the root file system, which the second stage finds.', 9, 'start', '#222')
    c.text(20, 360, 'On the PDP-11 there was no such table: V7 compiled eight (size, first cylinder) pairs into each disk driver (hp_sizes[8] in hp.c).', 9, 'start', '#444')
    c.text(20, 374, 'In 2.11BSD block 0 held the 512-byte bootstrap and block 1 the disk label: the same two places as here.', 9, 'start', '#444')
    c.text(20, 396, 'The MBR and GPT layouts are as the OpenBSD header disklabel.h has them (4.12); the 8 KB area and sector 1 are decided (4.5.3).', 9, 'start', '#555')
    return c.svg()


def fig_bootinfo():
    """The boot-information block as a struct in memory, with r1 pointing at it.  Field order and widths are an illustration."""
    c = Canvas(400)
    c.text(20, 16, 'the boot-information block: a struct the second stage fills in and r1 points at', 12, 'start', bold=True)
    c.box(20, 36, 70, 28, 'r1', YELLOW, 12, mono=True, bold=True, sub='at entry')
    x, w = 250, 230
    rows = [('version', 'which layout this is', GREY), ('size', 'bytes in the block', GREY), ('checksum', 'over the whole block', GREY),
            ('memory range count', 'n', SOFT), ('range[0]', 'base, length', SOFT), ('range[1]', 'base, length', SOFT), ('...', '', SOFT),
            ('core count', '', BLUE), ('root complex', 'physical address', BLUE), ('boot device', 'its identity', BLUE), ('console', 'its identity', BLUE),
            ('video base, size', 'if set up: 4.6.3', GREEN), ('video pitch, format', '', GREEN), ('command line', 'a string: -s, root ...', PINK)]
    rh = 20
    for i, (n, d, fill) in enumerate(rows):
        y = 40 + i * rh
        c.box(x, y, 120, rh, n, fill, 10, mono=True)
        c.box(x + 120, y, w - 120, rh, d, '#fff', 9)
        if i:
            c.text(x - 8, y + 14, '+%d' % (i * 8), 8, 'end', '#555', True)
    c.line([(90, 50), (x - 2, 50)], arrow=True)
    bx = x + w + 12
    groups = [(0, 3, 'header: the reader checks', 'the version and the sum first'), (3, 7, 'what the memory is', 'ranges, not one size'),
              (7, 11, 'what the machine is', 'cores; the bus controller;', 'where it booted from'), (11, 13, 'the screen'), (13, 14, 'the human')]
    for a, b, *t in groups:
        y0, y1 = 40 + a * rh + 2, 40 + b * rh - 2
        c.line([(bx, y0), (bx + 6, y0), (bx + 6, y1), (bx, y1)], arrow=False, width=1)
        lines(c, bx + 12, (y0 + y1) / 2 + 3 - 6 * (len(t) - 1), t, 9, fill='#222', gap=11)
    c.text(20, 340, 'Each row is one 64-bit word in this drawing (the offsets are bytes).  The contents are statements 4.6.2 and 4.6.3;', 9, 'start', '#444')
    c.text(20, 353, 'the offsets, the widths and the order drawn are an example, not specified.', 9, 'start', '#444')
    c.text(20, 370, 'Defined once in a grammar from which the headers are generated, so the loader and the kernel cannot disagree (4.6.3).', 9, 'start', '#444')
    c.text(20, 383, 'The devices are found by enumerating the bus (2.4), so the block stays short.', 9, 'start', '#444')
    c.text(20, 398, 'The VAX and Alpha passed similar blocks, a restart parameter block each (from the boot review, unverified, 4.12).', 9, 'start', '#555')
    return c.svg()

def fig_smp_timeline():
    """Time runs to the right: core 0 boots and starts core 1 and core 2; the controller's start registers; the x86 ladder beneath."""
    c = Canvas(380)
    c.text(20, 16, 'starting the other cores: one register write each, then the core is a core', 12, 'start', bold=True)
    lanes = [('core 0', 44), ('controller', 100), ('core 1', 156), ('core 2', 212)]
    for n, y in lanes:
        c.text(20, y + 22, n, 10, 'start', bold=True, mono=True)
        c.line([(86, y + 28), (672, y + 28)], arrow=False, width=0.5, dash=True)
    # core 0
    c.box(86, 46, 70, 26, 'ROM', GREY, 10, sub='reads block 0')
    c.box(160, 46, 70, 26, 'block 0', PINK, 10)
    c.box(234, 46, 90, 26, 'second stage', YELLOW, 10)
    c.box(328, 46, 150, 26, 'kernel: tables, bus, clock', GREEN, 10)
    c.box(482, 46, 90, 26, 'write start', BLUE, 10, bold=True, sub='register 1')
    c.box(576, 46, 96, 26, 'write start', BLUE, 10, bold=True, sub='register 2')
    # controller
    c.box(86, 102, 200, 26, 'every core but core 0 held in reset', GREY, 10)
    c.box(482, 102, 90, 26, 'release core 1', SOFT, 10, sub='entry, argument')
    c.box(576, 102, 96, 26, 'release core 2', SOFT, 10, sub='entry, argument')
    # core 1 and core 2
    c.box(86, 158, 396, 26, 'in reset: not running, no state', '#fff', 10, dash=True)
    c.box(482, 158, 90, 26, 'kernel mode', GREEN, 10, bold=True, sub='r0 = 1, r1 = arg')
    c.box(86, 214, 490, 26, 'in reset', '#fff', 10, dash=True)
    c.box(576, 214, 96, 26, 'kernel mode', GREEN, 10, bold=True, sub='r0 = 2, r1 = arg')
    c.line([(527, 72), (527, 102)], arrow=True)
    c.line([(624, 72), (624, 102)], arrow=True)
    c.line([(527, 128), (527, 158)], arrow=True)
    c.line([(624, 128), (624, 214)], arrow=True)
    c.text(86, 258, 'time runs to the right (not to scale); priority 7 on entry.  The entry address is where the kernel\'s per-core', 9, 'start', '#222')
    c.text(86, 270, 'code starts; the argument is a pointer to that core\'s own structure.  A core that sticks is reset by a write to', 9, 'start', '#222')
    c.text(86, 282, 'a core-reset register of the controller and started again (4.7.2).', 9, 'start', '#222')
    c.text(20, 306, 'x86, for comparison (general knowledge and Linux smpboot.c, 4.7): the boot core sends INIT and START-UP signals through the interrupt controller;', 9, 'start', '#444')
    c.text(20, 317, 'the other core wakes in 16-bit real mode at an address below 1 MB, and a trampoline must walk it through protected mode into 64-bit mode.', 9, 'start', '#444')
    c.text(20, 340, 'The pdp64 has no such ladder: a core starts in its normal mode at any address.  What the start registers look like is proposed, not decided (4.7.1);', 9, 'start', '#555')
    c.text(20, 353, 'the register block\'s address is open (4.13); the SMP chapter (7.8.1) names r0 only, where 4.7.1 loads r1 too.', 9, 'start', '#555')
    return c.svg()


def fig_pc_vs_pdp64():
    """The PC's two paths, BIOS and UEFI, beside the pdp64's chain."""
    c = Canvas(428)
    c.text(20, 16, 'three ways to start a machine: the PC with a BIOS, the PC with UEFI, the pdp64', 12, 'start', bold=True)

    def row(y, tag, items, note):
        c.text(20, y - 6, tag, 10, 'start', bold=True)
        n = len(items)
        bw = (650 - (n - 1) * 24) / n
        for i, (a, b, fill) in enumerate(items):
            x = 20 + i * (bw + 24)
            c.box(x, y, bw, 56, a, fill, 10, bold=True, sub=b)
            if i < n - 1:
                c.line([(x + bw, y + 28), (x + bw + 24, y + 28)], arrow=True)
        c.text(20, y + 74, note, 9, 'start', '#444')
    row(44, 'PC with a BIOS (since 1981)', [('firmware in flash', 'self-test, setup', GREY), ('BIOS services', 'INT 13h, INT 10h', SOFT),
                                          ('boot sector', 'MBR: 446 bytes', PINK), ('boot loader', 'GRUB, NTLDR', YELLOW), ('kernel', '', GREEN)],
        'the loader calls the BIOS for every disk read, in 16-bit real mode, and has no drivers of its own')
    row(150, 'PC with UEFI (since about 2005)', [('firmware in flash', 'a firmware stack', GREY), ('boot services', 'files, memory, ...', SOFT),
                                                ('GPT and FAT', 'firmware reads files', PINK), ('loader.efi', 'a PE/COFF program', YELLOW), ('kernel', 'ExitBootServices', GREEN)],
        'no boot sector: the firmware parses the GPT and the FAT file system, runs the loader file, which calls the services and then gives them up')
    row(256, 'the pdp64', [('boot ROM', 'in the controller chip', GREY), ('block 0', 'the first stage', PINK), ('second stage', 'an ordinary program', YELLOW), ('kernel', '/bsd', GREEN)],
        'every stage after the ROM is an ordinary program built by the project\'s compiler')
    c.text(20, 358, 'The PDP-11 chain was the pdp64\'s: ROM or front panel, block 0, boot, unix (4.1).', 9, 'start', '#555')
    c.text(20, 371, 'Both PC chains are general knowledge, unverified (4.12), except where the OpenBSD loaders show it: the amd64 tree', 9, 'start', '#555')
    c.text(20, 384, 'on this machine has both, biosboot (862 lines) with boot (189), and efiboot (4,593 lines), measured (4.12).', 9, 'start', '#555')
    c.text(20, 399, 'Years are general knowledge, unverified.  Real UEFI firmware has more phases than drawn,', 9, 'start', '#555')
    c.text(20, 412, 'and keeps some code resident that the operating system cannot see.', 9, 'start', '#555')
    return c.svg()


def fig_shim():
    """Where a UEFI shim would sit: the second stage that offers a services table to a PE/COFF loader and runs it over virtio."""
    c = Canvas(420)
    c.text(20, 16, 'a UEFI shim (4.9): a second stage that looks like firmware to a loader, and is virtio underneath', 12, 'start', bold=True)
    items = [('boot ROM', GREY, 90), ('block 0', PINK, 90), ('the shim', YELLOW, 130), ('loader.efi', BLUE, 130), ('kernel', GREEN, 90)]
    x = 20
    pos = []
    for a, fill, w in items:
        c.box(x, 34, w, 30, a, fill, 11, bold=True)
        pos.append((x, w))
        x += w + 30
    for i in range(len(pos) - 1):
        c.line([(pos[i][0] + pos[i][1], 49), (pos[i + 1][0], 49)], arrow=True)
    c.text(pos[2][0] + 65, 80, 'second stage in the pdp64 chain', 9, 'middle', '#555')
    lx, lw = 20, 400
    c.box(lx, 100, lw, 46, 'the loader: an existing UEFI program', BLUE, 11, bold=True, sub='built as a PE/COFF image for the pdp64 (4.9); OpenBSD efiboot is one')
    c.box(lx, 146, lw, 86, '', '#fff')
    c.text(lx + lw / 2, 162, 'the shim\'s services table: function pointers', 11, bold=True)
    svc = ['allocate and free pages; get the memory map', 'read a file from the boot partition', 'console in and out; graphics output (a framebuffer)',
           'exit boot services (stop using the services)', 'runtime: the clock, reset']
    lines(c, lx + 14, 178, svc, 9, fill='#222', gap=11)
    c.box(lx, 232, lw, 38, 'the shim\'s own code', YELLOW, 10, bold=True, sub='a PE loader, a heap, virtio-blk and FAT readers, a console')
    c.box(lx, 270, lw, 38, 'virtio devices (chapter 2): blk, gpu, console', GREEN, 11, bold=True, sub='found by bus enumeration; drivers the second stage has anyway')
    rx = 450
    c.box(rx, 100, 220, 46, 'the loader calls the table', SOFT, 10, bold=True, sub='through the pointers')
    c.line([(lx + lw, 123), (rx, 123)], arrow=True, dash=True, width=0.9)
    c.box(rx, 160, 220, 46, 'exit boot services', PINK, 10, bold=True, sub='the loader now owns memory')
    c.box(rx, 220, 220, 88, '', GREEN)
    c.text(rx + 110, 236, 'hand-off to the kernel', 10, bold=True)
    lines(c, rx + 110, 252, ['the boot-information block (4.6), or', 'a device tree or tables made from it,', 'and the memory map in the form', 'the loader expects'], 9, 'middle', '#222', gap=12)
    c.text(20, 332, 'The loader needs the services table, a PE/COFF image of its own and a machine-type number for the pdp64 that the owners of the UEFI', 9, 'start', '#444')
    c.text(20, 345, 'specification would have to assign (unverified, 4.12).  The shim is a few services over drivers that already exist; it is not a firmware', 9, 'start', '#444')
    c.text(20, 358, 'stack: no PEI, DXE or driver model, no variable store, no setup screen.  This illustrates the size of the job (4.9).', 9, 'start', '#444')
    c.text(20, 380, 'The services named are those OpenBSD\'s efiboot loaders call (measured, 4.12): 17 (amd64) or 18 (arm64, riscv64) boot and runtime services, counted.', 9, 'start', '#555')
    c.text(20, 393, 'Which of them a given loader needs is for the person who writes the shim to find by reading that loader.', 9, 'start', '#555')
    return c.svg()

def fig_five_boots():
    """The five boots the author named, and the pdp64's, as chains with what each stage knows."""
    c = Canvas(470)
    c.text(20, 16, 'five boots and the pdp64: who runs, in what order, and what each stage knows', 12, 'start', bold=True)
    rows = [
        ('a  PDP-11', [('keys or ROM', 'a few dozen words', GREY), ('block 0', 'reads a name: #', PINK), ('boot', 'C program: ":"', YELLOW), ('unix', 'registers (2.11BSD)', GREEN)]),
        ('b  VAX', [('console processor', 'self-test, console', GREY), ('boot block', 'block 0; loads 7.5 KB', PINK), ('boot', 'C program: ":"', YELLOW), ('vmunix', 'r10, r11 hand-off', GREEN)]),
        ('c  Commodore 64', [('reset vector', 'at 0xFFFC, in ROM', GREY), ('KERNAL init', 'chips, RAM, screen', SOFT), ('CBM80 at 0x8000?', 'yes: cartridge runs', PINK), ('BASIC, READY.', 'you LOAD and RUN', GREEN)]),
        ('d  x86, BIOS, MBR', [('firmware', 'POST, option ROMs', GREY), ('MBR', '446 B at 0x7C00', PINK), ('boot record', 'of the active part.', YELLOW), ('OS loader', 'calls INT 13h', BLUE), ('kernel', 'memory map', GREEN)]),
        ('e  GPT and UEFI', [('firmware', 'boot manager, NVRAM', GREY), ('GPT + FAT', 'ESP: files by name', PINK), ('loader.efi', 'PE/COFF program', YELLOW), ('exit services', 'map and tables', BLUE), ('kernel', 'ACPI or tree', GREEN)]),
        ('f  pdp64', [('boot ROM', 'virtio-blk read', GREY), ('block 0', 'the first stage', PINK), ('second stage', 'finds the kernel', YELLOW), ('kernel /bsd', 'boot information', GREEN)]),
    ]
    for r, (tag, items) in enumerate(rows):
        y = 34 + r * 70
        c.text(20, y + 6, tag, 10, 'start', bold=True)
        n = len(items)
        bw = (650 - (n - 1) * 20) / 5.0 if n == 5 else (650 - (n - 1) * 20) / 5.0
        x = 20
        for i, (a, b, fill) in enumerate(items):
            c.box(x, y + 12, bw, 40, a, fill, 10 if len(a) < 16 else 9, bold=True, sub=b)
            if i < n - 1:
                c.line([(x + bw, y + 32), (x + bw + 20, y + 32)], arrow=True)
            x += bw + 20
    c.text(20, 462, 'Sources: a and b read in V7M, 2.11BSD and 4.3BSD-Tahoe; d and e partly read in OpenBSD; c, and the rest of b, d and e, are general knowledge, unverified (4.12).', 8, 'start', '#555')
    return c.svg()


FIGURES = {
    'boot-stages': ('The boot stages as a chain', fig_stages),
    'boot-block0-memory': ('Memory when block 0 is loaded', fig_block0_memory),
    'boot-disk-layout': ('The protective MBR, the GPT and the disk label', fig_disk_layout),
    'boot-bootinfo': ('The boot-information block', fig_bootinfo),
    'boot-smp-timeline': ('Starting the other cores', fig_smp_timeline),
    'boot-pc-vs-pdp64': ('The PC path beside the pdp64 path', fig_pc_vs_pdp64),
    'boot-shim': ('The place of a UEFI shim', fig_shim),
    'boot-five-boots': ('Five boots and the pdp64', fig_five_boots),
}

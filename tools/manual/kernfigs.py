"""The box-and-arrow figures of chapter 6 (the kernel): the KT11 beside the page-table walk, the tree of tables, the page-table entry,
the translation buffer, the exception entry, a context switch, the layout of an address space, the first pages of physical memory.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/kern-NAME.svg) into the figures directory of every member's manual.
The numbers drawn are the decided ones of chapter 6 (the page-table entry bits, the vector table, the system registers, the sizes of the levels);
the arrangements marked 'example' or 'open' in a figure are not specified by the architecture (section 6.14 of the chapter lists them).
The PDP-11 side of the first figure uses what the 2.11BSD and V7 sources on this machine show (section 6.14).  All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE

PINK = '#f7e3dc'
GREEN = '#e1f0dd'
YELLOW = '#fbf2cf'


def fig_kt11_walk():
    """The PDP-11's eight page registers of one mode beside the pdp64's walk."""
    c = Canvas(340)
    c.text(165, 16, 'PDP-11, KT11: the whole map is in registers', 12, bold=True)
    c.text(520, 16, 'pdp64: the map is a tree of tables in memory', 12, bold=True)
    # PDP-11: 16-bit virtual address
    c.box(20, 30, 40, 26, 'APF', BLUE, 11, bold=True, sub='3 bits')
    c.box(60, 30, 220, 26, 'displacement in the segment', SOFT, 11, sub='13 bits: up to 8 KB')
    c.text(110, 70, 'virtual address, 16 bits', 9, 'start', '#555')
    # eight PAR/PDR rows
    c.text(20, 90, 'the eight active page registers of the current mode', 10, 'start', bold=True)
    for i in range(8):
        y = 96 + i * 20
        c.box(20, y, 30, 20, str(i), '#fff', 10, mono=True)
        c.box(50, y, 110, 20, 'PAR (where)', GREY if i != 3 else YELLOW, 10)
        c.box(160, y, 120, 20, 'PDR (length, access)', GREY if i != 3 else YELLOW, 10)
    c.line([(30, 56), (30, 78), (10, 78), (10, 166), (18, 166)], arrow=True)
    c.text(288, 160, 'PAR x 64', 10, 'start', '#333')
    c.text(288, 173, '+ displacement', 10, 'start', '#333')
    c.text(288, 186, '= 18-bit', 10, 'start', '#333')
    c.text(288, 199, 'physical address', 10, 'start', '#333')
    c.text(20, 268, 'loaded whole at every process switch (sureg: 8 pairs,', 9, 'start', '#555')
    c.text(20, 280, '16 with separate instruction and data space);', 9, 'start', '#555')
    c.text(20, 292, 'a mapping error is a segmentation fault; no table, no miss', 9, 'start', '#555')
    # pdp64
    x0 = 360
    c.box(x0, 30, 40, 26, 'L2', BLUE, 11, bold=True, sub='9')
    c.box(x0 + 40, 30, 40, 26, 'L1', BLUE, 11, bold=True, sub='9')
    c.box(x0 + 80, 30, 40, 26, 'L0', BLUE, 11, bold=True, sub='9')
    c.box(x0 + 120, 30, 100, 26, 'offset in page', SOFT, 11, sub='12 bits: 4 KB')
    c.text(x0, 70, 'virtual address, 39 bits (three levels)', 9, 'start', '#555')
    c.box(x0 + 230, 30, 90, 26, 'PTBR', YELLOW, 11, mono=True, bold=True, sub='register')
    tiers = [(96, 'level-2 table'), (150, 'level-1 table'), (204, 'level-0 table')]
    for y, lab in tiers:
        c.box(x0 + 60, y, 130, 36, lab, GREY, 11, sub='512 entries of 8 bytes')
    c.box(x0 + 230, 150, 90, 70, 'page', GREEN, 11, bold=True, sub='4 KB frame')
    c.line([(x0 + 275, 56), (x0 + 275, 78), (x0 + 125, 78), (x0 + 125, 96)], arrow=True)
    c.line([(x0 + 190, 114), (x0 + 215, 114), (x0 + 215, 130), (x0 + 125, 130), (x0 + 125, 150)], arrow=True)
    c.line([(x0 + 190, 168), (x0 + 215, 168), (x0 + 215, 186), (x0 + 125, 186), (x0 + 125, 204)], arrow=True)
    c.line([(x0 + 190, 222), (x0 + 210, 222), (x0 + 230, 200)], arrow=True)
    c.text(x0, 260, 'a walk: one memory read per level, three to five;', 9, 'start', '#555')
    c.text(x0, 272, 'a translation buffer remembers the answers, so most', 9, 'start', '#555')
    c.text(x0, 284, 'accesses do not walk; a missing entry is a page fault', 9, 'start', '#555')
    c.line([(345, 24), (345, 320)], arrow=False, dash=True, width=0.8)
    return c.svg()


def fig_pagetree():
    """Three levels of 512-entry tables and the fields of a 39-bit virtual address."""
    c = Canvas(440)
    c.text(20, 16, 'a 39-bit virtual address and the three tables it walks', 12, 'start', bold=True)
    fx, fy = 20, 26
    fields = [('bits 38-30', 'index into level 2'), ('bits 29-21', 'index into level 1'), ('bits 20-12', 'index into level 0'), ('bits 11-0', 'offset in the page')]
    for k, (lab, sub) in enumerate(fields):
        c.box(fx + 130 * k, fy, 130, 38, lab, BLUE if k < 3 else SOFT, 11, bold=True, sub=sub)
    c.text(fx + 530, fy + 24, '= 39 bits', 10, 'start', '#555')
    names = ['level 2 (top)', 'level 1', 'level 0']
    tops = [110, 180, 250]
    xs = [30, 160, 290]
    for i in range(3):
        x, t = xs[i], tops[i]
        c.box(x, t, 110, 18, names[i], GREY, 10, bold=True)
        for r in range(5):
            lab = ['entry 0', 'entry 1', 'entry n', 'entry 510', 'entry 511'][r]
            if r == 2:
                lab = 'entry n: pointer' if i < 2 else 'entry n: leaf'
            c.box(x, t + 18 + r * 22, 110, 22, lab, YELLOW if r == 2 else '#fff', 10)
        # the field's arrow into the table's header
        c.line([(85 + 130 * i, fy + 38), (85 + 130 * i, t - 2)], arrow=True)
    c.box(20, 74, 62, 22, 'PTBR', YELLOW, 11, mono=True, bold=True)
    c.line([(51, 96), (51, 108)], arrow=True)
    # pointers to the next table
    for i in range(2):
        x, t = xs[i], tops[i]
        c.line([(x + 110, t + 73), (x + 120, t + 73), (x + 120, tops[i + 1] + 29), (x + 130, tops[i + 1] + 29)], arrow=True)
    c.box(440, 290, 160, 70, 'page frame', GREEN, 12, bold=True, sub='4 KB of data')
    c.line([(400, 323), (440, 323)], arrow=True)
    c.line([(475, fy + 38), (475, 288)], arrow=True, dash=True)
    c.text(482, 200, 'the offset is used as it is:', 9, 'start', '#444')
    c.text(482, 213, 'frame address + bits 11-0', 9, 'start', '#444')
    c.text(20, 396, 'Each table is 512 entries x 8 bytes = 4 KB.  PTBR holds the physical address of the top table.', 9, 'start', '#444')
    c.text(20, 410, 'With four levels bits 47-39 index a level-3 table above these; with five, bits 56-48 index a level-4 table above that.', 9, 'start', '#444')
    c.text(20, 424, 'A leaf found at level 1 maps 2 MB and ends the walk there; a leaf at level 2 maps 1 GB.', 9, 'start', '#444')
    return c.svg()


def fig_pte():
    """The 64-bit page-table entry, every bit."""
    c = Canvas(300)
    c.text(20, 16, 'a page-table entry: 64 bits, the physical page number in place', 12, 'start', bold=True)
    # fields: (hi, lo, label, fill, width)
    fields = [(63, 40, 'reserved, zero', GREY, 118), (39, 12, 'physical page number (PPN)', GREEN, 190), (11, 10, 'rsvd', GREY, 38),
              (9, 8, 'MT', BLUE, 38), (7, 7, 'D', PINK, 24), (6, 6, 'A', PINK, 24), (5, 5, 'G', YELLOW, 24), (4, 4, 'U', YELLOW, 24),
              (3, 3, 'X', YELLOW, 24), (2, 2, 'W', YELLOW, 24), (1, 1, 'R', YELLOW, 24), (0, 0, 'V', YELLOW, 24)]
    x = 20
    y = 56
    tot = sum(f[4] for f in fields)
    for hi, lo, lab, fill, w in fields:
        w = w * 650.0 / tot
        c.box(x, y, w, 40, lab, fill, 11 if w > 40 else 12, bold=(w < 40))
        c.text(x + w / 2, y - 6, str(hi) if hi == lo else '%d-%d' % (hi, lo) if w > 40 else str(hi), 9, fill='#555')
        if hi != lo and w <= 40:
            c.text(x + w / 2, y + 52, '%d' % lo, 9, fill='#555')
        x += w
    d = [('V', 'valid: the entry means something; clear is a page fault'),
         ('R W X', 'read, write, execute; all three clear means "pointer to the next table"; W without R is reserved'),
         ('U', 'user: user mode may touch it (kernel mode may read and write a user page, never execute one)'),
         ('G', 'global: the entry ignores the address-space number'),
         ('A  D', 'accessed, dirty: set by the kernel, never by the hardware; a clear bit is a page fault'),
         ('MT', 'memory type: 0 normal cached, 1 normal uncached, 2 device strongly ordered, 3 device weakly ordered'),
         ('rsvd', 'bits 10-11 and 40-63 must be zero; a set bit is a page fault (for 40-bit physical addresses; wider ones are open, 6.7.1)')]
    for i, (k, v) in enumerate(d):
        c.text(24, 132 + i * 22, k, 11, 'start', bold=True, mono=True)
        c.text(90, 132 + i * 22, v, 10, 'start', '#222')
    c.text(20, 292, 'Bit positions are those of statement 6.7.1; bits 0 to 7 are in the same places as in RISC-V.', 9, 'start', '#555')
    return c.svg()


def fig_tlb():
    """A translation buffer: its entries, and what a hit and a miss do."""
    c = Canvas(340)
    c.text(20, 16, 'the translation buffer (TLB): a cache of finished translations', 12, 'start', bold=True)
    cols = [('ASID', 56), ('G', 24), ('virtual page', 112), ('physical page', 112), ('R W X U', 70), ('A D MT', 62)]
    x = 20
    cx = []
    for lab, w in cols:
        c.box(x, 28, w, 22, lab, BLUE, 10, bold=True)
        cx.append((x, w))
        x += w
    rows = [('7', '0', '0x00000412', '0x0003a1', 'R W . U', 'A D 0'), ('7', '0', '0x00000413', '0x0007c2', 'R . X U', 'A . 0'),
            ('-', '1', '0xFFFFFC001', '0x000100', 'R W X .', 'A D 0'), ('12', '0', '0x00000412', '0x0009ff', 'R W . U', 'A D 0')]
    for r, vals in enumerate(rows):
        for (xx, w), v in zip(cx, vals):
            c.box(xx, 50 + r * 20, w, 20, v, '#fff', 9, mono=True)
    c.text(20, 142, 'the same virtual page 0x412 appears twice, for address spaces 7 and 12: that is what the ASID is for;', 9, 'start', '#444')
    c.text(20, 154, 'the global entry (G) answers for every address space and has no ASID.', 9, 'start', '#444')
    # flow
    c.box(20, 180, 120, 34, 'virtual address', SOFT, 11, bold=True, sub='from a load, store or fetch')
    c.box(210, 180, 120, 34, 'look in the TLB', YELLOW, 11, bold=True, sub='(page, ASID, G)')
    c.line([(140, 197), (210, 197)], arrow=True)
    c.box(400, 180, 130, 34, 'HIT', GREEN, 12, bold=True, sub='use the physical page')
    c.line([(330, 197), (400, 197)], arrow=True)
    c.text(365, 190, 'found', 9, fill='#333')
    c.box(560, 180, 110, 34, 'physical address', SOFT, 11, bold=True, sub='to the memory system')
    c.line([(530, 197), (560, 197)], arrow=True)
    c.box(210, 252, 120, 34, 'MISS: the walker', PINK, 11, bold=True, sub='reads the tables')
    c.line([(270, 214), (270, 252)], arrow=True)
    c.text(262, 240, 'not found', 9, 'end', '#333')
    c.box(400, 252, 150, 34, 'memory', GREY, 11, bold=True, sub='3 to 5 reads, one per level')
    c.line([(330, 269), (400, 269)], arrow=True)
    c.line([(440, 252), (440, 232), (300, 232), (300, 215)], arrow=True, dash=True)
    c.text(446, 242, 'fill, then retry', 9, 'start', '#333')
    c.box(20, 252, 150, 34, 'page fault', PINK, 11, bold=True, sub='no valid entry, or A/D clear')
    c.line([(210, 269), (170, 269)], arrow=True, dash=True)
    c.text(20, 312, 'TLBI rN drops the entry for one page (this ASID and the global ones); TLBIA drops all; both reach every core; TLBSYNC waits until all have finished.', 9, 'start', '#444')
    c.text(20, 326, 'The size and organisation are the implementation\'s: the FPGA plan assumes 4-way, 64 entries (section 6.14).', 9, 'start', '#444')
    return c.svg()


def fig_exception():
    """What entry to an exception does to registers, and where the new program counter comes from."""
    c = Canvas(360)
    c.text(20, 16, 'entering the kernel: only registers are written, then one memory read', 12, 'start', bold=True)
    c.text(20, 38, 'before', 10, 'start', bold=True)
    c.box(20, 44, 120, 30, 'PSW', SOFT, 11, mono=True, bold=True, sub='mode, priority, flags')
    c.box(20, 80, 120, 30, 'PC', SOFT, 11, mono=True, bold=True, sub='this or next instruction')
    c.box(20, 116, 120, 30, 'address', SOFT, 11, bold=True, sub='(aborts only)')
    c.box(20, 152, 120, 30, 'vector number', SOFT, 11, bold=True, sub='what happened')
    c.text(205, 38, 'saved in', 10, 'start', bold=True)
    c.box(200, 44, 90, 30, 'EPSW', YELLOW, 11, mono=True, bold=True)
    c.box(200, 80, 90, 30, 'EPC', YELLOW, 11, mono=True, bold=True)
    c.box(200, 116, 90, 30, 'EVA', YELLOW, 11, mono=True, bold=True)
    c.box(200, 152, 90, 30, 'ECAUSE', YELLOW, 11, mono=True, bold=True)
    for y in (59, 95, 131, 167):
        c.line([(140, y), (200, y)], arrow=True)
    c.text(20, 206, 'the new PSW:', 10, 'start', bold=True)
    c.text(20, 220, 'current mode = kernel; previous mode = the old current mode;', 9, 'start', '#222')
    c.text(20, 232, 'priority = 7; trace bit, flags and the user-access guard cleared', 9, 'start', '#222')
    c.text(20, 252, 'the new PC = the 64-bit word at VBR + 8 x vector', 10, 'start', bold=True)
    c.text(20, 268, 'the hardware pushes nothing; a handler that may be interrupted', 9, 'start', '#222')
    c.text(20, 280, 'saves EPC and EPSW with PUSHX, lowers the priority with SPL,', 9, 'start', '#222')
    c.text(20, 292, 'and leaves with POPX and RTI (PC from EPC, PSW from EPSW).', 9, 'start', '#222')
    # vector table
    vx = 350
    c.text(vx + 170, 36, 'the vector table: 512 entries x 8 bytes = 4096 bytes', 10, bold=True)
    c.box(vx, 44, 90, 28, 'VBR', YELLOW, 11, mono=True, bold=True, sub='system register')
    rows = [('0', 'reset'), ('1', 'machine check'), ('2-5', 'illegal, privileged, align, non-canon.'), ('6-8', 'instruction, load, store page fault'),
            ('9-11', 'protection violation'), ('12-15', 'divide, bus fault, landing pad, break'), ('32-63', 'interrupts (32 timer, 33-34 console)'),
            ('256+n', 'TRAP #n  (system calls)')]
    for i, (n, d) in enumerate(rows):
        y = 90 + i * 28
        c.box(vx + 90, y, 50, 28, n, '#fff', 10, mono=True)
        c.box(vx + 140, y, 200, 28, d, GREY if i % 2 else '#fff', 9)
    c.line([(vx + 90, 58), (vx + 115, 58), (vx + 115, 88)], arrow=True)
    c.text(vx + 90, 326, 'entry n is at VBR + 8 x n; ECAUSE = n', 9, 'start', '#444')
    c.text(vx + 90, 339, 'the vectors in full: statement 6.3.6', 9, 'start', '#444')
    return c.svg()


def fig_ctxswitch():
    """What a process switch touches on the pdp64, beside what it cost on the PDP-11."""
    c = Canvas(380)
    c.text(20, 16, 'switching from process A to process B, in the kernel, at priority 7', 12, 'start', bold=True)
    # A and B memory
    c.box(20, 34, 150, 60, 'A: kernel stack', GREY, 11, bold=True, sub='callee-saved registers, saved')
    c.box(20, 100, 150, 40, 'A: trap frame', GREY, 11, bold=True, sub='EPC, EPSW (PUSHX), registers')
    c.box(520, 34, 150, 60, 'B: kernel stack', GREEN, 11, bold=True, sub='callee-saved registers, to load')
    c.box(520, 100, 150, 40, 'B: trap frame', GREEN, 11, bold=True, sub='EPC, EPSW, registers')
    c.box(190, 34, 310, 106, '', '#fff')
    steps = ['1  push callee-saved registers on A\'s stack',
             '    A.ksp = R14 ; A.usp = MFSR USP',
             '2  R14 = B.ksp; pop B\'s callee-saved registers',
             '3  if B has another address space:',
             '       MTSR PTBR, B.root     MTASID B.asid',
             '       ISYNC     (the new base takes effect)',
             '4  return (into B, in the kernel)']
    for i, s in enumerate(steps):
        c.text(198, 50 + i * 13, s, 9, 'start', '#111', True)
    # user side
    c.text(20, 170, 'then, on the way out to user mode in B', 10, 'start', bold=True)
    c.box(20, 180, 150, 30, 'MTSR USP, B.usp', YELLOW, 10, mono=True, sub='the user stack pointer')
    c.box(200, 180, 150, 30, 'POPX', YELLOW, 10, mono=True, sub='EPC, EPSW from B\'s frame')
    c.box(380, 180, 130, 30, 'RTI', YELLOW, 10, mono=True, sub='PC, PSW from EPC, EPSW')
    c.line([(170, 195), (200, 195)], arrow=True)
    c.line([(350, 195), (380, 195)], arrow=True)
    c.text(530, 190, 'B runs, in user mode', 10, 'start', bold=True)
    # TLB
    c.box(20, 236, 330, 44, 'translation buffer: nothing flushed', BLUE, 11, bold=True, sub='entries of ASID A and B sit side by side')
    c.box(380, 236, 290, 44, 'the kernel\'s own pages: global, no ASID', SOFT, 11, bold=True, sub='they answer in every address space')
    # PDP-11
    c.box(20, 300, 650, 60, '', '#fff', dash=True)
    c.text(30, 318, 'On the PDP-11 the same switch (resume, then sureg) loaded the new page registers:', 10, 'start', bold=True)
    c.text(30, 334, 'for each of 8 pairs (16 with separate instruction and data space): write PAR, write PDR:', 9, 'start', '#222')
    c.text(30, 348, '16 (or 32) register writes; the old map was overwritten, and there was no cache of it to flush.', 9, 'start', '#222')
    return c.svg()


def fig_layout():
    """An example address-space layout: the user half, the kernel half, windows, devices.  Arrangement not specified."""
    c = Canvas(410)
    c.text(20, 16, 'the 39-bit virtual space of three levels: one example arrangement', 12, 'start', bold=True)
    x, w = 150, 270
    y = 30
    # kernel half
    c.box(x, y, w, 24, 'kernel stacks, per-CPU data', GREY, 10)
    c.box(x, y + 24, w, 30, 'device windows (memory type: device)', BLUE, 10, sub='mapped by page entries, MT 2 or 3')
    c.box(x, y + 54, w, 30, 'direct-mapping windows DMW0, DMW1', YELLOW, 10, sub='kernel only; format open (6.9.2)')
    c.box(x, y + 84, w, 34, 'kernel text and data', GREY, 10, sub='global pages, in every address space')
    c.text(x - 8, y + 10, '0xFFFFFFFFFFFFFFFF', 8, 'end', '#555', True)
    c.text(x - 8, y + 128, '0xFFFFFFC000000000', 8, 'end', '#555', True)
    c.text(x + w + 10, y + 50, 'upper half: bit 38 set', 10, 'start', bold=True)
    c.text(x + w + 10, y + 64, 'walked from KTBR, in kernel mode only', 9, 'start', '#222')
    c.text(x + w + 10, y + 77, 'one table for the whole system', 9, 'start', '#222')
    # gap
    gy = y + 122
    c.box(x, gy, w, 40, 'not canonical: every address here faults', '#fff', 10, dash=True, sub='bits 63-39 are not all equal to bit 38 (ECAUSE 5)')
    # user half
    uy = gy + 44
    c.box(x, uy, w, 34, 'stack', PINK, 10, sub='grows down')
    c.box(x, uy + 34, w, 34, 'mapped files, shared libraries', '#fff', 10)
    c.box(x, uy + 68, w, 26, 'heap', GREEN, 10, sub='grows up')
    c.box(x, uy + 94, w, 24, 'data', GREEN, 10)
    c.box(x, uy + 118, w, 24, 'text (code)', GREEN, 10)
    c.box(x, uy + 142, w, 18, 'page 0: never mapped (null pointers fault)', GREY, 9)
    c.text(x - 8, uy + 10, '0x0000003FFFFFFFFF', 8, 'end', '#555', True)
    c.text(x - 8, uy + 166, '0', 8, 'end', '#555', True)
    c.text(x + w + 10, uy + 70, 'lower half: bit 38 clear', 10, 'start', bold=True)
    c.text(x + w + 10, uy + 84, 'walked from PTBR: one table per', 9, 'start', '#222')
    c.text(x + w + 10, uy + 97, 'process, and the ASID selects it', 9, 'start', '#222')
    c.text(x + w + 10, uy + 110, 'a user program never sees the upper half', 9, 'start', '#222')
    c.text(20, 384, 'The halves are decided; what goes in them is not specified.  Each half is 2^38 bytes = 256 GB with three levels, 128 TB with four, 64 PB with five.', 9, 'start', '#444')
    c.text(20, 398, 'The order, the sizes of the regions and the placement of the windows are the kernel\'s choice; nothing here is tested.', 9, 'start', '#444')
    return c.svg()


def fig_firstpages():
    """The first pages of physical memory, as the boot chapter and this chapter state them."""
    c = Canvas(340)
    c.text(20, 16, 'the first pages of physical memory after reset', 12, 'start', bold=True)
    x, w = 120, 250
    c.box(x, 28, w, 40, 'RAM and device windows', '#fff', 11, sub='a window may go anywhere except the first few pages')
    c.box(x, 68, w, 28, 'the second stage and kernel are loaded above', SOFT, 10)
    c.box(x, 96, w, 44, 'stack, first 64 KB', GREEN, 11, sub='r14 starts at the top of the first 64 KB')
    c.box(x, 140, w, 34, 'boot-information block', YELLOW, 11, sub='r1 points at it; size and place not specified')
    c.box(x, 174, w, 34, 'block 0: the first 512 bytes of the disk', PINK, 11, sub='0x1000 (an address still to be chosen)')
    c.box(x, 208, w, 70, 'vector table: page 0', BLUE, 11, bold=True, sub='512 entries x 8 bytes = 4096 bytes, VBR = 0 at reset')
    c.text(x - 8, 284, '0x0000', 9, 'end', '#555', True)
    c.text(x - 8, 215, '0x1000', 9, 'end', '#555', True)
    c.text(x - 8, 104, '0x10000', 9, 'end', '#555', True)
    c.line([(x + w + 8, 278), (x + w + 8, 140)], arrow=False, dash=True, width=1.2)
    c.text(x + w + 18, 206, 'the first few pages:', 10, 'start', bold=True)
    c.text(x + w + 18, 220, 'boot code and boot data; no device', 9, 'start', '#222')
    c.text(x + w + 18, 233, 'window is placed here (how many', 9, 'start', '#222')
    c.text(x + w + 18, 246, 'pages is not decided)', 9, 'start', '#222')
    c.text(20, 300, '(not to scale; the place and size of the boot-information block are not specified)', 9, 'start', '#444')
    c.text(20, 314, 'After reset: kernel mode, priority 7, translation off (every address physical), VBR 0, guard clear.', 9, 'start', '#444')
    c.text(20, 328, 'The PDP-11 kept its vectors in the low few hundred bytes (V7 goes past octal 0224) and booted from elsewhere; here the table is one whole page at 0.', 9, 'start', '#444')
    return c.svg()


FIGURES = {
    'kern-kt11-walk': ('The KT11 beside the pdp64 walk', fig_kt11_walk),
    'kern-pagetree': ('The tree of page tables', fig_pagetree),
    'kern-pte': ('The page-table entry', fig_pte),
    'kern-tlb': ('The translation buffer', fig_tlb),
    'kern-exception': ('Exception entry and the vector table', fig_exception),
    'kern-ctxswitch': ('A context switch', fig_ctxswitch),
    'kern-layout': ('The layout of an address space', fig_layout),
    'kern-firstpages': ('The first pages of physical memory', fig_firstpages),
}

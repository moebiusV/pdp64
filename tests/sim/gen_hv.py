#!/usr/bin/env python3
"""Generate the tests of the hypervisor mode (errata 195, 196; docs/encoding-work/hypervisor-design.md) that run on sim64 -H and on QEMU (-M pdp64-virt,kernel-mode=on,hypervisor=on):

  hv-regs.S    the registers at H = 1: reset values, the widths and the read-only rules, the aliases and the guest's banked registers, the unassigned numbers, the hypervisor's own exception
               (HEPC, HEPSW, HCAUSE, exit code 0, the guest's EPC untouched), RTI, PUSHX and POPX at H = 1.
  hv-switch.S  GENTER and the exits: the status word loaded and saved, the banks of R14 and DP, a reserved mode in HEPSW, the clear of the naming of the vector accumulators.
  hv-exits.S   one table-driven program: every event of the design (1.5, 1.6) as a guest instruction, with the bit of HTRAP set and clear, in kernel and user mode; the log of the exits
               (HEXITR, HCAUSE, HEPC, HEPSW, whether HINSN is the instruction, HEVA|HGPA, the guest's EPC and ECAUSE, r1) is compared with the expected log, entry by entry.
  hv-off.S     the machine with no hypervisor (sim64 -K, no strap): every hypervisor register and GENTER is an illegal instruction.

usage: gen_hv.py OUTDIR     (writes the four files)"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with the width suffixes (tools/marks.py)
import os
import sys

MODE_KERNEL, MODE_USER = 0, 3
PSW_PRI, PSW_MODE, PSW_PREV = 5, 8, 10
PSW_VALID = 0x0ff0
GTBR_VALID = 0xffff00fffffff001
KPSW = 0                                   # kernel mode, priority 0
UPSW = (MODE_USER << PSW_MODE) | (MODE_USER << PSW_PREV)   # user mode, priority 0
ENTRY_K = (MODE_KERNEL << PSW_MODE) | (MODE_KERNEL << PSW_PREV) | (7 << PSW_PRI)   # the status word after an exception entry in a kernel-mode guest
ENTRY_U = (MODE_KERNEL << PSW_MODE) | (MODE_USER << PSW_PREV) | (7 << PSW_PRI)     # ... of a user-mode guest

SYSREGS = dict(htrap=128, hexitr=129, hepc=130, hepsw=131, heva=132, hcause=133, hgpa=134, hinsn=135, hvbr=136, gtbr=137, virq=138, vivec=139, vtoff=140, vcpuid=141,
               geva=142, gecause=143, gksp=144, gkdp=145, gsdp=146, gudp=147)
RO = ['hexitr', 'heva', 'hcause', 'hgpa', 'hinsn']
HEADER = '#include "pdp64-consts.h"\n'


class Prog:
    """a little assembler front: checks that jump to a numbered failure that exits with its number in r0 (halt at H = 1 exits with r0)"""

    def __init__(s):
        s.t = []
        s.n = 0
        s.lab = 0

    def e(s, line):
        s.t.append(line)

    def label(s, p='L'):
        s.lab += 1
        return '%s%d' % (p, s.lab)

    def cbne(s, a, b):
        """fail (exit with the number of the check in r0) unless a == b; a register or #n for b.  The failure is inline, so that no branch is far (a compare-and-branch reaches a short way)"""
        s.n += 1
        assert s.n < 250
        s.e('\tcbeq\t%s, %s, 1f\n\tmovq\t#%d, r0\n\thalt\n1:' % (a, b, s.n))

    def eq(s, reg, val):
        """fail unless reg == val (a number or an expression)"""
        s.e('\tmovq\t=(%s), r11' % val)
        s.cbne(reg, 'r11')

    def trailer(s):
        s.e('\tmovq\t#0, r0\n\thalt')

    def text(s):
        return '\n'.join(s.t) + '\n'


def write(outdir, name, body):
    with open(os.path.join(outdir, name), 'w') as f:
        f.write(marks.spell_text(body))


# ---------------------------------------------------------------------------------------------------------------------------------------
# a handler for the hypervisor's own illegal instruction: counts, saves HCAUSE, HEXITR and HEPC, resumes at r4 (the hypervisor sets r4, resets r10)
def h_ill(p):
    p.e('h_ill:\tmfsr\tr6, hcause\n\tmfsr\tr7, hexitr\n\tmfsr\tr8, hepc\n\tadd\t#1, r10\n\tmtsr\thepc, r4\n\trti\t#RTIMASK_ALL')


def expect_illegal(p, insn, what=''):
    """execute insn at H = 1: it must be an illegal instruction taken at H = 1 (HCAUSE 2, exit code 0, HEPC the instruction), and then execution resumes after it"""
    a, b = p.label('I'), p.label('R')
    p.e('\tmovq\t#0, r10')
    p.e('\tlea\t%s, r4' % b)
    p.e('%s:\t%s\t\t\t; %s' % (a, insn, what or 'illegal at H = 1'))
    p.e('%s:' % b)
    p.eq('r10', 1)
    p.eq('r6', 'VECTOR_ILLEGAL')
    p.eq('r7', 'XCODE_TAKEN_AT_H')
    p.e('\tlea\t%s, r11' % a)
    p.cbne('r8', 'r11')


def patched_illegal(p, tmpl, num, vector='VECTOR_ILLEGAL', handler_regs=('r6', 'r8')):
    """execute the word of the template (tmplr: mfsr r1, ptbr; tmplw: mtsr ptbr, r1) with the system-register number replaced by num, from the buffer ubuf (the assembler refuses a write to a read-only register and a number
    that is not a name): it must be the illegal-instruction exception, once, with the vector in r6 and the address of the instruction in r8; the buffer holds the word and then a RET, so the handler resumes at ubuf+4"""
    p.e('\tmovl\t%s, r2\n\tmovq\t=(%d<<16), r3\n\tbis\tr3, r2\n\tmovl\tr2, (r15)' % (tmpl, num))
    p.e('\tmovq\t#0, r10\n\tlea\tubuf+4, r4\n\tcall\tubuf')
    p.eq('r10', 1)
    p.eq('r6', vector)
    p.e('\tlea\tubuf, r11')
    p.cbne('r8', 'r11')


def htab(p, nvec=512):
    p.e('\t.data\n\t.align\t8\nhtab:\t.space\t%d' % (8 * nvec))


# ---------------------------------------------------------------------------------------------------------------------------------------
def gen_regs(outdir):
    p = Prog()
    p.e('; GENERATED by tests/sim/gen_hv.py: do not edit.  The hypervisor registers at H = 1 (errata 195, 196; design 1.3, 1.4, 1.11, 1.12): sim64 -H and QEMU hypervisor=on.')
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    # reset values (before anything is written): HTRAP is WFE | SEV, everything else zero
    p.e('\t; --- the reset values')
    for name, num in sorted(SYSREGS.items(), key=lambda kv: kv[1]):
        want = '(1<<HTRAP_WFE)|(1<<HTRAP_SEV)' if name == 'htrap' else '0'
        p.e('\tmfsr\tr2, %s' % name)
        p.eq('r2', want)
    for name in ['ptbr', 'epc', 'eva', 'ecause', 'usp', 'ssp', 'epsw', 'vbr', 'mmuctl', 'asid', 'cpuid']:
        p.e('\tmfsr\tr2, %s' % name)
        p.eq('r2', '0')
    p.e('\tmfdp\tr2')
    p.eq('r2', '0')                                   # the hypervisor's own DP
    p.e('\tmfsr\tr2, hvbr\n\tlea\thtab, r1\n\tmtsr\thvbr, r1\n\tlea\th_ill, r3\n\tlea\thtab+8*VECTOR_ILLEGAL, r2\n\tmovq\tr3, (r2)')
    p.e('\tmovq\tr14, r12\t\t\t; the hypervisor\'s stack pointer, to be unchanged by the guest\'s banks below')
    # round trips
    p.e('\t; --- write and read back: the widths')
    trips = [('htrap', '0xff7fff', '0xff7fff'), ('htrap', '0', '0'), ('htrap', '0x7fff', '0x7fff'), ('htrap', '0xff0000', '0xff0000'), ('htrap', '3', '3'),
             ('hepc', '0x123456789abcdef0', '0x123456789abcdef0'), ('hepsw', '0x%x' % PSW_VALID, '0x%x' % PSW_VALID), ('hepsw', '0x0120', '0x0120'),
             ('hvbr', '0xfedcba9876543210', '0xfedcba9876543210'), ('gtbr', '0x%x' % GTBR_VALID, '0x%x' % GTBR_VALID), ('gtbr', '0x0000003456789001', '0x0000003456789001'),
             ('virq', '0xfe', '0xfe'), ('virq', '0x20', '0x20'), ('vivec', '0x00ffffffffffffff', '0x00ffffffffffffff'), ('vivec', '0x0022232425262728', '0x0022232425262728'),
             ('vtoff', '0xffffffffffffffff', '0xffffffffffffffff'), ('vcpuid', '0xffff', '0xffff'), ('vcpuid', '0x1234', '0x1234'),
             ('geva', '0x1111222233334444', '0x1111222233334444'), ('gecause', '0x5555666677778888', '0x5555666677778888'),
             ('gksp', '0xaaaa000000000001', '0xaaaa000000000001'), ('gkdp', '0xaaaa000000000002', '0xaaaa000000000002'), ('gsdp', '0xaaaa000000000003', '0xaaaa000000000003'),
             ('gudp', '0xaaaa000000000004', '0xaaaa000000000004')]
    for name, w, r in trips:
        p.e('\tmovq\t=%s, r2\n\tmtsr\t%s, r2\n\tmfsr\tr3, %s' % (w, name, name))
        p.eq('r3', r)
    p.e('\t; --- the aliases: GEVA and GECAUSE write what EVA and ECAUSE read (those are read only)')
    p.e('\tmfsr\tr3, eva')
    p.eq('r3', '0x1111222233334444')
    p.e('\tmfsr\tr3, ecause')
    p.eq('r3', '0x5555666677778888')
    p.e('\t; --- the banks of the guest: independent of one another, of USP and SSP, and of the hypervisor\'s own R14 and DP')
    p.e('\tmovq\t=0xbbbb000000000005, r2\n\tmtsr\tusp, r2\n\tmovq\t=0xbbbb000000000006, r2\n\tmtsr\tssp, r2')
    for name, v in [('gksp', 0xaaaa000000000001), ('gkdp', 0xaaaa000000000002), ('gsdp', 0xaaaa000000000003), ('gudp', 0xaaaa000000000004), ('usp', 0xbbbb000000000005), ('ssp', 0xbbbb000000000006)]:
        p.e('\tmfsr\tr3, %s' % name)
        p.eq('r3', '0x%x' % v)
    p.e('\tmovq\t=0xcccc000000000007, r2\n\tmtdp\tr2\n\tmfdp\tr3')
    p.eq('r3', '0xcccc000000000007')
    for name, v in [('gkdp', 0xaaaa000000000002), ('gsdp', 0xaaaa000000000003), ('gudp', 0xaaaa000000000004)]:
        p.e('\tmfsr\tr3, %s' % name)
        p.eq('r3', '0x%x' % v)
    p.cbne('r14', 'r12')                                  # the hypervisor's R14 is not one of the guest's
    p.e('\tmovq\t#0, r2\n\tmtdp\tr2')
    p.e('\tlea\thtab, r1\n\tmtsr\thvbr, r1\t\t\t; the round trip wrote HVBR: back to the table')
    # EPC, EPSW are the guest's and writable; the exit registers are read only
    p.e('\t; --- the read-only registers refuse a write (illegal instruction at H = 1), the registers are unchanged')
    p.e('\tlea\tubuf, r15\n\tmovzw\tretw, r2\n\tmovw\tr2, 4(r15)\n\tmovq\t=0x7777, r2')
    for name in RO + ['cpuid', 'eva', 'ecause']:
        num = SYSREGS.get(name, {'cpuid': 12, 'eva': 2, 'ecause': 3}.get(name))
        patched_illegal(p, 'tmplw', num)
    for name in RO:
        p.e('\tmfsr\tr3, %s' % name)
        if name in ('hexitr', 'hcause'):
            continue                                      # these hold the last exception of the hypervisor itself
        p.eq('r3', '0')
    p.e('\t; --- a one in a reserved bit of HTRAP is an illegal instruction, and nothing is written')
    p.e('\tmovq\t#3, r2\n\tmtsr\thtrap, r2')
    for bit in (15, 24, 40, 63):
        p.e('\tmovq\t=(3|(1<<%d)), r2' % bit if bit < 63 else '\tmovq\t=(3|0x8000000000000000), r2')
        expect_illegal(p, 'mtsr\thtrap, r2', 'bit %d of HTRAP is reserved' % bit)
        p.e('\tmfsr\tr3, htrap')
        p.eq('r3', '3')
    # unassigned numbers at H = 1, through a patched copy of an instruction (the assembler refuses a number that is not a name)
    p.e('\t; --- an unassigned number is an illegal instruction at H = 1 as well (4, 5, 13 and 127 below the block, 148 and 255 above it); MFSR and MTSR')
    for num in (4, 5, 13, 127, 148, 255):
        for tmpl in ('tmplr', 'tmplw'):
            patched_illegal(p, tmpl, num)
    # the hypervisor's own exception: HEPC, HEPSW, HEVA, HCAUSE, exit code 0; the guest's registers are not touched
    p.e('\t; --- the exception of the hypervisor itself writes HEPC, HEPSW, HEVA, HCAUSE and HEXITR (code 0) and not the guest\'s EPC, EPSW, EVA, ECAUSE')
    p.e('\tmovq\t=0x13572468, r2\n\tmtsr\tepc, r2\n\tmovq\t=0x0ab0, r2\n\tmtsr\tepsw, r2\n\tmovq\t=0x24681357, r2\n\tmtsr\tgeva, r2\n\tmovq\t=0x99, r2\n\tmtsr\tgecause, r2')
    patched_illegal(p, 'tmplw', 129)
    p.e('\tmfsr\tr3, epc')
    p.eq('r3', '0x13572468')
    p.e('\tmfsr\tr3, epsw')
    p.eq('r3', '0x0ab0')
    p.e('\tmfsr\tr3, eva')
    p.eq('r3', '0x24681357')
    p.e('\tmfsr\tr3, ecause')
    p.eq('r3', '0x99')
    p.e('\tmfsr\tr3, hcause')
    p.eq('r3', 'VECTOR_ILLEGAL')
    p.e('\tmfsr\tr3, hexitr')
    p.eq('r3', 'XCODE_TAKEN_AT_H')
    p.e('\tmfsr\tr3, hinsn\n\tmfsr\tr5, hgpa')
    p.eq('r5', '0')
    # RTI, PUSHX and POPX name HEPC and HEPSW at H = 1; EPC and EPSW stay the guest's
    p.e('\t; --- PUSHX and POPX at H = 1 use HEPC and HEPSW, and the guest\'s EPC and EPSW are not touched')
    p.e('\tmovq\t=0x1111aaaa, r2\n\tmtsr\thepc, r2\n\tmovq\t=0x0550, r2\n\tmtsr\thepsw, r2\n\tpushx')
    p.e('\tmovq\t(r14), r3')
    p.eq('r3', '0x0550')
    p.e('\tmovq\t8(r14), r3')
    p.eq('r3', '0x1111aaaa')
    p.e('\tmovq\t#0, r2\n\tmtsr\thepc, r2\n\tmtsr\thepsw, r2\n\tpopx\n\tmfsr\tr3, hepc')
    p.eq('r3', '0x1111aaaa')
    p.e('\tmfsr\tr3, hepsw')
    p.eq('r3', '0x0550')
    p.e('\tmfsr\tr3, epc')
    p.eq('r3', '0x13572468')
    p.e('\tmfsr\tr3, epsw')
    p.eq('r3', '0x0ab0')
    p.cbne('r14', 'r12')
    p.trailer()
    h_ill(p)
    p.e('\t.data\n\t.align\t8')
    p.e('ubuf:\t.space\t16')
    p.e('\t.text')
    p.e('\t.align\t4\ntmplr:\tmfsr\tr1, ptbr\ntmplw:\tmtsr\tptbr, r1\nretw:\tret')
    htab(p)
    write(outdir, 'hv-regs.S', p.text())


# ---------------------------------------------------------------------------------------------------------------------------------------
def gen_reserved(outdir):
    """hv-reserved.S: a one written to an unused bit of a hypervisor register, and a virtual-line vector below 32 written to VIVEC, are illegal instructions at H = 1 (hole 4 of the rejudged list):
    nothing is written, the bit reads zero.  Each case writes a known good value first and reads it back after the refusal; the control (a good value is accepted) is in the same list."""
    p = Prog()
    p.e('; GENERATED by tests/sim/gen_hv.py: do not edit.  Unused bits of the hypervisor registers and the vectors of the virtual lines (errata 195, 196): sim64 -H and QEMU hypervisor=on.')
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    p.e('\tlea\thtab, r1\n\tmtsr\thvbr, r1\n\tlea\th_ill, r3\n\tlea\thtab+8*VECTOR_ILLEGAL, r2\n\tmovq\tr3, (r2)')
    p.e('\t; --- a one in an unused bit of a hypervisor register is an illegal instruction at H = 1: nothing is written, the bit reads zero')
    refused = [('hepsw', 'HEPSW', ['0x%x' % (1 << b) for b in (0, 3, 13, 15, 16, 40, 63)], '0x0120'),
               ('gtbr', 'GTBR', ['0x%x' % (1 << b) for b in (1, 11, 40, 47)], '0x0000003456789001'),
               ('virq', 'VIRQ', ['1', '0x100', '0x8000000000000000'], '0x20'),
               ('vivec', 'VIVEC', ['0x0100000000000000', '0x8000000000000000'], '0x0022232425262728'),
               ('vcpuid', 'VCPUID', ['0x10000', '0x8000000000000000'], '0x1234')]
    for name, up, vals, keep in refused:
        for v in vals:
            p.e('\tmovq\t=%s, r2\n\tmtsr\t%s, r2' % (keep, name))
            p.e('\tmovq\t=%s, r2' % (v if name != 'hepsw' else '(0x0120|%s)' % v))
            expect_illegal(p, 'mtsr\t%s, r2' % name, 'a one in an unused bit of %s' % up)
            if name != 'hepsw':                               # the illegal instruction itself writes HEPSW (the status word it was taken in): no read back
                p.e('\tmfsr\tr3, %s' % name)
                p.eq('r3', keep)
    p.e('\t; --- a vector below 32 in a field of VIVEC is refused at once (zero is "no vector"); 32 is accepted')
    for line in range(7):
        for v in (1, 2, 31):
            p.e('\tmovq\t=0x0022232425262728, r2\n\tmtsr\tvivec, r2')
            p.e('\tmovq\t=(0x0022232425262728 & ~(0xff << %d) | (%d << %d)), r2' % (8 * line, v, 8 * line))
            expect_illegal(p, 'mtsr\tvivec, r2', 'vector %d for virtual line %d' % (v, line + 1))
            p.e('\tmfsr\tr3, vivec')
            p.eq('r3', '0x0022232425262728')
    for v in ('0x0020202020202020', '0x0000000000000020', '0'):
        p.e('\tmovq\t=%s, r2\n\tmtsr\tvivec, r2\n\tmfsr\tr3, vivec' % v)
        p.eq('r3', v)
    p.trailer()
    h_ill(p)
    htab(p)
    write(outdir, 'hv-reserved.S', p.text())


# ---------------------------------------------------------------------------------------------------------------------------------------
def gen_switch(outdir):
    p = Prog()
    p.e('; GENERATED by tests/sim/gen_hv.py: do not edit.  GENTER and the exits (errata 195, 196; design 2.1, 2.2, 1.12): the status word, the banks, a reserved mode, the clear at the world switch.')
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    p.e('\tlea\thtab, r1\n\tmtsr\thvbr, r1\n\tlea\txh, r2\n\tmovq\t#512, r3\nfill1:\tmovq\tr2, (r1)+\n\tsob\tr3, fill1')
    p.e('\tlea\tgvtab, r1\n\tmtsr\tvbr, r1\n\tlea\tgh, r2\n\tmovq\t#512, r3\nfill2:\tmovq\tr2, (r1)+\n\tsob\tr3, fill2')
    p.e('\tlea\thstk_top, r14\t\t\t; the hypervisor\'s stack')
    gu = (MODE_USER << PSW_MODE) | (MODE_USER << PSW_PREV)
    enter = lambda lab, back, psw: p.e('\tlea\t%s, r2\n\tmtsr\thepc, r2\n\tmovq\t=(%s), r2\n\tmtsr\thepsw, r2\n\tlea\t%s, r20\n\tmovq\t#99, r0\n\tgenter\t#RTIMASK_ALL' % (lab, psw, back))
    p.e('\t; --- 1. GENTER loads the status word from HEPSW and PC from HEPC; the guest\'s MFPS sees it; the exit (HALT is a trap) saves it in HEPSW and the next PC in HEPC; the hypervisor\'s own')
    p.e('\t; status word is kernel mode, previous mode the guest\'s current mode, priority 7')
    gp = (MODE_KERNEL << PSW_MODE) | (MODE_USER << PSW_PREV) | (3 << PSW_PRI)     # kernel, previous user, priority 3 (bits 3 to 0 are reserved and read zero)
    p.e('\tmovq\t#0, r1')
    enter('g1', 'back1', '0x%x' % gp)
    p.e('g1:\tmfps\tr1\n\thalt\ng1e:\nback1:')
    p.eq('r1', '0x%x' % gp)
    p.e('\tmfsr\tr2, hepc\n\tlea\tg1e, r3')
    p.cbne('r2', 'r3')
    p.e('\tmfsr\tr2, hepsw')
    p.eq('r2', '0x%x' % gp)
    p.e('\tmfsr\tr2, hexitr')
    p.eq('r2', 'XCODE_HALT')
    p.e('\tmfsr\tr2, hcause')
    p.eq('r2', 'VECTOR_HEXIT')
    p.e('\tmfps\tr2')
    p.eq('r2', '(MODE_KERNEL<<PSW_MODE)|(MODE_KERNEL<<PSW_PREV)|(7<<PSW_PRI)')
    p.e('\t; --- 2. an exit from a user-mode guest leaves its mode as the previous mode (SEV is not privileged and HTRAP resets with SEV set)')
    enter('g2', 'back2', '0x%x' % gu)
    p.e('g2:\tsev\n\thalt\nback2:')
    p.e('\tmfps\tr2')
    p.eq('r2', '(MODE_KERNEL<<PSW_MODE)|(MODE_USER<<PSW_PREV)|(7<<PSW_PRI)')
    p.e('\tmfsr\tr2, hepsw')
    p.eq('r2', '0x%x' % gu)
    p.e('\tmfsr\tr2, hexitr')
    p.eq('r2', 'XCODE_SEV')
    p.e('\t; --- 2b. the guest\'s own exception (a system call, no hypercall routed) does not exit: its handler halts, and the guest\'s EPC, EPSW, ECAUSE are written, not the hypervisor\'s')
    enter('g2b', 'back2b', '0x%x' % gu)
    p.e('g2b:\ttrap\t#0\ng2be:\nback2b:')
    p.e('\tmfsr\tr2, hepsw')
    p.eq('r2', '(MODE_KERNEL<<PSW_MODE)|(MODE_USER<<PSW_PREV)|(7<<PSW_PRI)')
    p.e('\tmfsr\tr2, ecause')
    p.eq('r2', 'VECTOR_TRAP_BASE+0')
    p.e('\tmfsr\tr2, epsw')
    p.eq('r2', '0x%x' % gu)
    p.e('\tmfsr\tr2, epc\n\tlea\tg2be, r3')
    p.cbne('r2', 'r3')
    p.e('\t; --- 3. the banks of R14 and DP: the guest in kernel mode has GKSP and GKDP, changes them, the exit shows the changes, the hypervisor\'s own R14 and DP are as they were')
    p.e('\tmovq\t=0x1000, r2\n\tmtsr\tgksp, r2\n\tmovq\t=0x2000, r2\n\tmtsr\tgkdp, r2\n\tmovq\t=0x3000, r2\n\tmtsr\tgsdp, r2\n\tmovq\t=0x4000, r2\n\tmtsr\tgudp, r2')
    p.e('\tmovq\t=0x5000, r2\n\tmtsr\tusp, r2\n\tmovq\t=0x6000, r2\n\tmtsr\tssp, r2')
    p.e('\tmovq\t=0x9000, r2\n\tmtdp\tr2\n\tmovq\tr14, r12')
    enter('g3', 'back3', '0')
    p.e('g3:\tmovq\tr14, r1\n\tmfdp\tr2\n\tmovq\t=0x1111, r3\n\tmtdp\tr3\n\tmovq\t=0x2222, r14\n\thalt\nback3:')
    p.eq('r1', '0x1000')
    p.eq('r2', '0x2000')
    for name, v in (('gksp', 0x2222), ('gkdp', 0x1111), ('gsdp', 0x3000), ('gudp', 0x4000), ('usp', 0x5000), ('ssp', 0x6000)):
        p.e('\tmfsr\tr2, %s' % name)
        p.eq('r2', '0x%x' % v)
    p.e('\tmfdp\tr2')
    p.eq('r2', '0x9000')
    p.cbne('r14', 'r12')
    p.e('\t; --- 3b. a guest in user mode: its R14 is USP and its DP is GUDP; its exception entry (trap #1, no hypercall routed) switches to the kernel bank, which holds what the guest left there')
    enter('g3u', 'back3u', '0x%x' % gu)
    p.e('g3u:\tmovq\tr14, r1\n\tmfdp\tr2\n\tmovq\t=0x7777, r14\n\tmovq\t=0x8888, r3\n\tmtdp\tr3\n\ttrap\t#1\nback3u:')
    p.eq('r1', '0x5000')
    p.eq('r2', '0x4000')
    for name, v in (('usp', 0x7777), ('gudp', 0x8888), ('gksp', 0x2222), ('gkdp', 0x1111)):
        p.e('\tmfsr\tr2, %s' % name)
        p.eq('r2', '0x%x' % v)
    p.e('\t; --- 3c. a guest in supervisor mode: SSP and GSDP (HALT is privileged there: the guest\'s own exception, then its handler halts)')
    enter('g3s', 'back3s', '(MODE_SUPERVISOR<<PSW_MODE)|(MODE_SUPERVISOR<<PSW_PREV)')
    p.e('g3s:\tmovq\tr14, r1\n\tmfdp\tr2\n\thalt\nback3s:')
    p.eq('r1', '0x6000')
    p.eq('r2', '0x3000')
    p.e('\t; --- 4. a reserved mode (2) in either mode field of HEPSW: GENTER is an illegal instruction at H = 1 and changes nothing: the next instruction is the hypervisor\'s')
    p.e('\tlea\th_ill, r3\n\tlea\thtab+8*VECTOR_ILLEGAL, r2\n\tmovq\tr3, (r2)')
    for psw in ('(2<<PSW_MODE)', '(2<<PSW_PREV)'):
        a, b = p.label('I'), p.label('R')
        p.e('\tmovq\t=(%s), r2\n\tmtsr\thepsw, r2\n\tlea\tg4, r2\n\tmtsr\thepc, r2\n\tmovq\t#0, r10\n\tlea\t%s, r4' % (psw, b))
        p.e('%s:\tgenter\t#RTIMASK_ALL\n%s:' % (a, b))
        p.eq('r10', '1')
        p.eq('r6', 'VECTOR_ILLEGAL')
    p.e('\t; --- 5. the naming of the vector accumulators (what VCLR sets) is cleared by an exit and by GENTER (6.14.9).  Control: with no world switch the naming makes the sums run.')
    p.e('\tcall\tclear_dst\n\tvclr.l\tv0, #1\n\tcall\truns\n\tcall\texpect_copy')
    p.cbne('r0', '#1')
    p.e('\t; 5a. the guest names accumulators and halts (an exit): the hypervisor\'s block is an ordinary block')
    p.e('\tcall\tclear_dst')
    enter('g5', 'back5', '0')
    p.e('g5:\tvclr.l\tv0, #1\n\thalt\nback5:\tcall\truns\n\tcall\texpect_copy')
    p.cbne('r0', '#0')
    p.e('\t; 5b. the hypervisor names accumulators and enters: GENTER cleared the naming, the guest\'s block is an ordinary block')
    p.e('\tcall\tclear_dst\n\tvclr.l\tv0, #1\n\tlea\tgstk_top, r2\n\tmtsr\tgksp, r2')
    enter('g6', 'back6', '0')
    p.e('g6:\tcall\truns\n\thalt\nback6:\tcall\texpect_copy')
    p.cbne('r0', '#0')
    p.trailer()
    p.e('clear_dst:\n\tlea\tdst, r1\n\tmovq\t#0xa5, r2\n\tmovq\t#32, r3\n\tmset\tr1, r2, r3\n\tret')
    p.e('runs:\n\tlea\tsrc, r1\n\tlea\tsrc+32, r5\n\tlea\tdst, r3\n\tvec\tr1, r5\n\tvld.l\tv8, (r1)+\n\tvadd.l\tv0, v0, v8\n\tvst.l\tv0, (r3)+\n\tvend\n\tret')
    p.e('expect_copy:\n\tlea\tsrc, r1\n\tlea\tdst, r2\n\tmovq\t#32, r3\n1:\tmovzb\t(r1)+, r4\n\tmovzb\t(r2)+, r5\n\tcbne\tr4, r5, 2f\n\tsob\tr3, 1b\n\tmovq\t#0, r0\n\tret\n2:\tmovq\t#1, r0\n\tret')
    p.e('g4:\n\thalt\nxh:\tjmp\tr20\t\t\t; every exit: back to the hypervisor\'s continuation (the guest does not use r20)')
    p.e('gh:\thalt')
    p.e('h_ill:\tmfsr\tr6, hcause\n\tadd\t#1, r10\n\tmtsr\thepc, r4\n\trti\t#RTIMASK_ALL')
    p.e('\t.data\n\t.align\t8\nhtab:\t.space\t4096\ngvtab:\t.space\t4096\nhstk:\t.space\t512\nhstk_top:\n\t.space\t512\ngstk_top:')
    p.e('src:\t.long\t1, 2, 3, 4, 5, 6, 7, 8\ndst:\t.space\t32')
    write(outdir, 'hv-switch.S', p.text())


# ---------------------------------------------------------------------------------------------------------------------------------------
# the table of exits
class Case:
    def __init__(s, name, insns, htrap=0, mode='K', r3=0, exits=(), epc=0, ecause=0, r1=0, vcpuid=0x1234, psw_end=None):
        s.name, s.insns, s.htrap, s.mode, s.r3, s.exits = name, insns, htrap, mode, r3, list(exits)
        s.epc, s.ecause, s.r1, s.psw_end = epc, ecause, r1, psw_end
        s.entry = None


B = dict(wfe=0, sev=1, pause=2, prio=3, tlbi=4, tlbia=5, tlbsync=6, asid=7, ptbr=8, mmuctl=9, vbr=10, cpuid=11, icinv=12, bpt=13, step=14)


def bit(*names):
    v = 0
    for n in names:
        v |= 1 << B[n]
    return v


def mask(*blocks):
    v = 0
    for k in blocks:
        v |= 1 << (16 + k)
    return v


def cases():
    cs = []
    X = lambda code, vec, at, **kw: dict(code=code, vec=vec, at=at, **kw)    # an exit: HEXITR code, HCAUSE vector, HEPC at the label after instruction number `at` (1-based)
    HALT = lambda at, **kw: X('XCODE_HALT', 'VECTOR_HEXIT', at, **kw)        # the end of the case: the guest's HALT exit
    ALL = 0xff3fff                                                           # every bit but STEP

    def add(*a, **kw):
        c = Case(*a, **kw)
        cs.append(c)
        return c

    def pair(name, insn, bitname, code, mode='K', insns=None, untrapped_exits=None, untrapped_kw=None, trapped_kw=None):
        """the instruction with its bit set: an exit; with it clear (and the others set): no exit; with every other bit set: no exit"""
        ins = insns or [insn]
        add(name + '/trap', ins, bit(bitname), mode, exits=[X(code, 'VECTOR_HEXIT', 1), HALT(2)], **(trapped_kw or {}))
        add(name + '/clear', ins, ALL & ~bit(bitname), mode, exits=untrapped_exits or [HALT(2)], **(untrapped_kw or {}))
    # the privileged-instruction events: the bit of HTRAP
    pair('sev', 'sev', 'sev', 'XCODE_SEV')
    pair('hint1', 'hint\t#1', 'pause', 'XCODE_PAUSE')
    add('hint0/bit', ['hint\t#0'], ALL, exits=[HALT(2)])
    add('hint2/bit', ['hint\t#2'], ALL, exits=[HALT(2)])
    add('wfe/trap', ['wfe'], bit('wfe'), exits=[X('XCODE_WFE', 'VECTOR_HEXIT', 1), HALT(2)])
    add('wfe/otherbits', ['wfe'], bit('wfe') | bit('sev', 'pause'), exits=[X('XCODE_WFE', 'VECTOR_HEXIT', 1), HALT(2)])
    pair('spl', 'spl\t#3', 'prio', 'XCODE_PRIO', untrapped_kw=dict(psw_end=3 << PSW_PRI))
    add('mtps/prio', ['mtps\tr3'], bit('prio'), r3=2 << PSW_PRI, exits=[X('XCODE_PRIO', 'VECTOR_HEXIT', 1), HALT(2)])
    add('mtps/same', ['mtps\tr3'], bit('prio'), r3=0, exits=[HALT(2)])
    add('mtps/clear', ['mtps\tr3'], ALL & ~bit('prio'), r3=2 << PSW_PRI, exits=[HALT(2)], psw_end=2 << PSW_PRI)
    pair('tlbi', 'tlbi\tr2', 'tlbi', 'XCODE_TLB')
    pair('tlbias', 'tlbias\tr2', 'tlbi', 'XCODE_TLB')
    pair('tlbia', 'tlbia', 'tlbia', 'XCODE_TLB')
    pair('tlbsync', 'tlbsync', 'tlbsync', 'XCODE_TLB')
    pair('mtsr-asid', 'mtsr\tasid, r2', 'asid', 'XCODE_ASID')
    pair('mfsr-asid', 'mfsr\tr1, asid', 'asid', 'XCODE_ASID')
    pair('mtsr-ptbr', 'mtsr\tptbr, r2', 'ptbr', 'XCODE_PTBR')
    add('mfsr-ptbr/read', ['mfsr\tr1, ptbr'], bit('ptbr'), exits=[HALT(2)])            # a read of PTBR is not trapped
    pair('mtsr-mmuctl', 'mtsr\tmmuctl, r2', 'mmuctl', 'XCODE_MMUCTL')
    add('mfsr-mmuctl/read', ['mfsr\tr1, mmuctl'], bit('mmuctl'), exits=[HALT(2)])
    pair('mtsr-vbr', 'mtsr\tvbr, r2', 'vbr', 'XCODE_VBR')
    add('mfsr-vbr/read', ['mfsr\tr1, vbr'], bit('vbr'), exits=[HALT(2)], r1='gvtab')
    pair('icinv', 'icinv\tr2', 'icinv', 'XCODE_ICINV')
    pair('icinva', 'icinva', 'icinv', 'XCODE_ICINV')
    pair('bpt', 'bpt', 'bpt', 'XCODE_BPT', untrapped_exits=[HALT('gh')], untrapped_kw=dict(epc='A1', ecause='VECTOR_BPT'))
    # MFSR CPUID: the virtual core number, or the exit
    pair('mfsr-cpuid', 'mfsr\tr1, cpuid', 'cpuid', 'XCODE_CPUID', untrapped_kw=dict(r1=0x1234))
    # the single step
    add('step', ['movq\t#1, r1', 'movq\t#2, r3'], bit('step'), exits=[X('XCODE_STEP', 'VECTOR_HEXIT', 1, r1=1), X('XCODE_STEP', 'VECTOR_HEXIT', 2, r1=1), HALT(3, r1=1)], r1=1)
    # the hypercall: bit k of the mask routes the numbers 32k to 32k + 31
    for n in (0, 31, 32, 63, 64, 100, 128, 223, 224, 255):
        k = n >> 5
        add('trap%d/routed' % n, ['trap\t#%d' % n], mask(k), exits=[X('XCODE_HYPERCALL', 'VECTOR_TRAP_BASE+%d' % n, 1), HALT(2)])
        add('trap%d/other' % n, ['trap\t#%d' % n], mask(*[j for j in range(8) if j != k]) | ALL & 0xffff, exits=[HALT('gh')], epc='A1', ecause='VECTOR_TRAP_BASE+%d' % n)
    add('trap/user-routed', ['trap\t#40'], mask(1), 'U', exits=[X('XCODE_HYPERCALL', 'VECTOR_TRAP_BASE+40', 1), HALT(2)])
    add('trap/user-unrouted', ['trap\t#40'], mask(0, 2, 3, 4, 5, 6, 7) | ALL & 0xffff, 'U', exits=[HALT('gh')], epc='A1', ecause='VECTOR_TRAP_BASE+40')
    add('trap/mask-zero', ['trap\t#40'], ALL & 0xffff, exits=[HALT('gh')], epc='A1', ecause='VECTOR_TRAP_BASE+40')
    # the events with no bit: they always exit, with every bit clear and every bit set
    for ht, tag in ((0, '0'), (ALL, 'all')):
        add('halt/%s' % tag, ['nop'], ht, exits=[HALT(2)])
        for nm, ins in (('mfsr-htrap', 'mfsr\tr1, htrap'), ('mtsr-hvbr', 'mtsr\thvbr, r2'), ('mtsr-gtbr', 'mtsr\tgtbr, r2'), ('mfsr-gudp', 'mfsr\tr1, gudp'),
                        ('mtsr-vtoff', 'mtsr\tvtoff, r2'), ('mfsr-hexitr', 'mfsr\tr1, hexitr'), ('mtsr-geva', 'mtsr\tgeva, r2'), ('mtsr-virq', 'mtsr\tvirq, r2'), ('genter', 'genter\t#RTIMASK_ALL'), ('tlbigp', 'tlbigp\tr2')):
            add('%s/%s' % (nm, tag), [ins], ht, exits=[X('XCODE_HVREG', 'VECTOR_HEXIT', 1), HALT(2)])
    # the privilege check comes first (decision 10): in user mode the guest's own privileged-instruction exception, no exit
    priv = lambda nm, ins, ht, **kw: add('user/' + nm, [ins], ht, 'U', exits=[HALT('gh')], epc='I1', ecause='VECTOR_PRIVILEGED', **kw)
    priv('wfe', 'wfe', bit('wfe'))
    priv('mtsr-ptbr', 'mtsr\tptbr, r2', ALL)
    priv('mfsr-htrap', 'mfsr\tr1, htrap', ALL)
    priv('mtsr-gtbr', 'mtsr\tgtbr, r2', ALL)
    priv('genter', 'genter\t#RTIMASK_ALL', ALL)
    priv('mfsr-cpuid', 'mfsr\tr1, cpuid', ALL)
    priv('tlbia', 'tlbia', ALL)
    priv('tlbi', 'tlbi\tr2', ALL)
    priv('tlbias', 'tlbias\tr2', ALL)
    priv('tlbigp', 'tlbigp\tr2', ALL)
    priv('spl', 'spl\t#2', ALL)
    priv('mtsr-asid', 'mtsr\tasid, r2', ALL)
    priv('halt', 'halt', ALL)
    priv('tlbsync', 'tlbsync', ALL)
    # the unprivileged instructions of a user guest exit if the bit is set
    for nm, ins, b, code in (('sev', 'sev', 'sev', 'XCODE_SEV'), ('hint1', 'hint\t#1', 'pause', 'XCODE_PAUSE'), ('icinva', 'icinva', 'icinv', 'XCODE_ICINV'),
                             ('icinv', 'icinv\tr2', 'icinv', 'XCODE_ICINV'), ('bpt', 'bpt', 'bpt', 'XCODE_BPT')):
        add('user/%s/trap' % nm, [ins], bit(b), 'U', exits=[X(code, 'VECTOR_HEXIT', 1), HALT(2)])
    # an unassigned number is an illegal instruction in the guest (and not an exit), through a patched copy of mfsr and mtsr
    for num in (4, 5, 13, 127, 148, 255):
        for kind in ('r', 'w'):
            add('unassigned%d%s' % (num, kind), ['PATCH%d%s' % (num, kind)], ALL, exits=[HALT('gh')], epc='I1', ecause='VECTOR_ILLEGAL')
    return cs


def gen_exits(outdir):
    cs = cases()
    p = Prog()
    p.e('; GENERATED by tests/sim/gen_hv.py: do not edit.  Every event of the design (1.5, 1.6) as a guest instruction, in a table; the log of the exits is compared with the expected log.')
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    p.e('\tlea\thtab, r1\n\tmtsr\thvbr, r1\n\tlea\txh, r2\n\tmovq\t#512, r3\nfill1:\tmovq\tr2, (r1)+\n\tsob\tr3, fill1')
    p.e('\tlea\tgvtab, r1\n\tmtsr\tvbr, r1\n\tlea\tgh, r2\n\tmovq\t#512, r3\nfill2:\tmovq\tr2, (r1)+\n\tsob\tr3, fill2')
    p.e('\tmovq\t=0x1234, r1\n\tmtsr\tvcpuid, r1')
    patched = []
    for c in cs:
        for ins in c.insns:
            if ins.startswith('PATCH'):
                patched.append(ins)
    for ins in patched:
        num, kind = int(ins[5:-1]), ins[-1]
        tmpl = 'tmplr' if kind == 'r' else 'tmplw'
        p.e('\tmovl\t%s, r1\n\tmovq\t=(%d<<16), r2\n\tbis\tr2, r1\n\tmovl\tr1, ub%d%s\n\tmovzw\tretw, r1\n\tmovw\tr1, ub%d%s+4' % (tmpl, num, num, kind, num, kind))
    p.e('\tlea\tlog, r27\n\tlea\tcases, r28\n\tmovq\t#%d, r29' % len(cs))
    p.e('next:\tmovq\t(r28)+, r1\n\tmtsr\thtrap, r1\n\tmovq\t(r28)+, r1\n\tmtsr\thepc, r1\n\tmovq\t(r28)+, r1\n\tmtsr\thepsw, r1\n\tmovq\t(r28)+, r3')
    p.e('\tlea\tgvtab, r2\n\tmovq\t#0, r1\n\tmtsr\tepc, r1\n\tmtsr\tgecause, r1\n\tmtsr\tgeva, r1\n\tmtsr\tasid, r1\n\tmtsr\tptbr, r1\n\tmtsr\tmmuctl, r1\n\tmovq\t#99, r0\t\t\t; a HALT that stops the machine (not an exit) ends the run with a status that is not 0\n\tgenter\t#RTIMASK_ALL')
    # the exit handler: log nine words, then the next case after the guest's HALT, else back into the guest
    p.e('xh:\tmfsr\tr20, hexitr\n\tmfsr\tr21, hcause\n\tmfsr\tr22, hepc\n\tmfsr\tr23, hepsw\n\tmfsr\tr24, hinsn')
    p.e('\tmovzw\t-2(r22), r11\n\tmovzw\t-4(r22), r12\n\tshl\t#16, r12\n\tbis\tr11, r12\n\tshl\t#16, r11\n\tmovq\t#0, r25')
    p.e('\tcbne\tr24, r12, 1f\n\tmovq\t#1, r25\n1:\tcbne\tr24, r11, 1f\n\tmovq\t#1, r25\n1:')
    p.e('\tmovzw\t-4(r22), r11\n\tmovzw\t-6(r22), r12\n\tshl\t#16, r12\n\tbis\tr11, r12\n\tcbne\tr24, r12, 1f\n\tmovq\t#1, r25\n1:\t\t\t; a three-parcel instruction (genter #mask): HINSN is its first two parcels')
    p.e('\tmfsr\tr15, heva\n\tmfsr\tr16, hgpa\n\tbis\tr16, r15\n\tmfsr\tr17, epc\n\tmfsr\tr18, ecause')
    p.e('\tmovq\tr20, (r27)+\n\tmovq\tr21, (r27)+\n\tmovq\tr22, (r27)+\n\tmovq\tr23, (r27)+\n\tmovq\tr25, (r27)+\n\tmovq\tr15, (r27)+\n\tmovq\tr17, (r27)+\n\tmovq\tr18, (r27)+\n\tmovq\tr1, (r27)+')
    p.e('\tcbeq\tr20, #XCODE_HALT, 2f\n\tgenter\t#RTIMASK_ALL\n2:\tsob\tr29, next')
    p.e('\tbr\tcompare')
    # the guest: the case snippets
    p.e('\t.align\t2')
    for ci, c in enumerate(cs):
        lab = 'c%d' % ci
        c.entry = lab
        k = 0
        p.e('%s:' % lab)
        for ins in c.insns:
            k += 1
            if ins.startswith('PATCH'):
                num, kind = int(ins[5:-1]), ins[-1]
                p.e('\tjmp\tub%d%s' % (num, kind))               # the instruction is in the data, patched at the start; it is the first instruction
                # the unassigned instruction is at ub: its address is the guest's EPC
                p.e('%sa%d:' % (lab, k))
                continue
            p.e('%si%d:\t%s' % (lab, k, ins))
            p.e('%sa%d:' % (lab, k))
        p.e('\thalt')
        p.e('%sa%d:' % (lab, k + 1))
    # the guest's exception handler
    p.e('gh:\thalt\ngha:')
    p.e('compare:\n\tlea\tlog, r1\n\tlea\texp, r2\n\tmovq\t#1, r6\nce:\tmovq\t#9, r3\ncw:\tmovq\t(r1)+, r4\n\tmovq\t(r2)+, r5\n\tcbne\tr4, r5, bad\n\tsob\tr3, cw')
    nent = sum(len(c.exits) for c in cs)
    p.e('\tadd\t#1, r6\n\tcbne\tr6, #%d, ce\n\tmovq\t#0, r0\n\thalt\nbad:\tmovq\tr6, r0\n\thalt' % (nent + 1))
    p.e('\t.align\t4\ntmplr:\tmfsr\tr1, ptbr\ntmplw:\tmtsr\tptbr, r1\nretw:\tret')
    # data
    p.e('\t.data\n\t.align\t8')
    p.e('cases:')
    for c in cs:
        mode = UPSW if c.mode == 'U' else KPSW
        p.e('\t.quad\t0x%x, %s, 0x%x, 0x%x\t\t\t; %s' % (c.htrap, c.entry, mode, c.r3, c.name))
    p.e('exp:')
    for ci, c in enumerate(cs):
        mode = UPSW if c.mode == 'U' else KPSW
        entry_psw = ENTRY_U if c.mode == 'U' else ENTRY_K
        for xi, x in enumerate(c.exits):
            at = x['at']
            user_halt = c.mode == 'U' and x['code'] == 'XCODE_HALT' and at != 'gh'     # HALT is privileged: in user mode the trailing halt is the guest's own privileged-instruction exception, and its handler halts
            if user_halt:
                at = 'gh'
            hepc = 'gha' if at == 'gh' else 'c%da%d' % (ci, at)
            # status word at the exit: the guest's own if no exception was taken before, else the entry's
            if at == 'gh':
                psw = entry_psw
            else:
                psw = mode
                if c.psw_end is not None and xi == len(c.exits) - 1:
                    psw |= c.psw_end
            if user_halt:
                epc, ecause = 'c%da%d' % (ci, len(c.insns)), 'VECTOR_PRIVILEGED'
            elif at == 'gh':
                epc = 'c%d%s' % (ci, {'I1': 'i1', 'A1': 'a1'}[c.epc]) if isinstance(c.epc, str) else 0
                ecause = c.ecause
                if c.epc == 'I1':
                    epc = 'c%di1' % ci
                if c.name.startswith('unassigned'):
                    epc = 'ub%s' % c.name[len('unassigned'):]
            else:
                epc, ecause = 0, 0
            # the guest's EPC and ECAUSE are what the guest's last exception left; an HALT exit at 'gh' follows one
            r1 = x.get('r1', c.r1 if xi == len(c.exits) - 1 or 'r1' in x else 0)
            if isinstance(r1, str):
                r1 = r1
            p.e('\t.quad\t%s, %s, %s, 0x%x, 1, 0, %s, %s, %s\t\t; %s exit %d' % (x['code'], x['vec'], hepc, psw, epc, ecause, r1, c.name, xi + 1))
    p.e('\t.align\t8\nlog:\t.space\t%d\nhtab:\t.space\t4096\ngvtab:\t.space\t4096\n\t.space\t512\ngstk_top:' % (nent * 9 * 8 + 64))
    for ins in patched:
        num, kind = int(ins[5:-1]), ins[-1]
        p.e('\t.align\t8\nub%d%s:\t.space\t8' % (num, kind))
    write(outdir, 'hv-exits.S', p.text())
    return nent




# ---------------------------------------------------------------------------------------------------------------------------------------
# virtual interrupts (design 1.8): seven lines, the hardware clears the line at delivery, the guest's priority masks them
VEC = {1: 33, 2: 64, 3: 100, 4: 150, 5: 200, 6: 250, 7: 255}


def gen_virq(outdir):
    p = Prog()
    p.e('; GENERATED by tests/sim/gen_hv.py: do not edit.  The virtual interrupt lines VIRQ and VIVEC (errata 195, 196; design 1.8; decision 16): seven lines, one for each priority level 1 to 7, delivered between two')
    p.e('; instructions of a guest as its own exception entry when the line is above the guest\'s priority, cleared by the hardware at delivery; the guest\'s SPL masks them and does not exit; WFE ends for a masked line.')
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    p.e('\tlea\thtab, r1\n\tmtsr\thvbr, r1\n\tlea\txh, r2\n\tmovq\t#512, r3\nfill1:\tmovq\tr2, (r1)+\n\tsob\tr3, fill1')
    p.e('\tlea\tgvtab, r1\n\tmtsr\tvbr, r1\n\tlea\tgh, r2\n\tmovq\t#512, r3\nfill2:\tmovq\tr2, (r1)+\n\tsob\tr3, fill2')
    p.e('\tlea\tlog, r28\n\tlea\tgstk_top, r2\n\tmtsr\tgksp, r2')
    vivec = 0
    for l, v in VEC.items():
        vivec |= v << (8 * (l - 1))
    cases = []

    def case(name, psw, virq, code, exits, vivec=vivec, mode='K', final='halt', htrap=0, xcode=2):
        cases.append(dict(name=name, psw=psw, virq=virq, code=code, exits=exits, vivec=vivec, final=final, htrap=htrap, xcode=xcode))
    KP = lambda pri: pri << PSW_PRI
    HPSW = lambda mode, prev, pri: (mode << PSW_MODE) | (prev << PSW_PREV) | (pri << PSW_PRI)
    for l in range(1, 8):
        case('line%d' % l, KP(0), 1 << l, ['nop', 'nop'], [dict(vec=VEC[l], epc='a0', epsw=KP(0))], )
    case('masked/5:{2,5}', KP(5), (1 << 2) | (1 << 5), ['nop', 'nop'], [])
    case('masked/5:{5,6}', KP(5), (1 << 5) | (1 << 6), ['nop', 'nop'], [dict(vec=VEC[6], epc='a0', epsw=KP(5))])
    case('masked/7:{7}', KP(7), 1 << 7, ['nop', 'nop'], [])
    case('window/spl2', KP(7), 1 << 3, ['nop', 'spl\t#2', 'nop', 'nop'], [dict(vec=VEC[3], epc='a2', epsw=KP(2))])
    case('window/order', KP(7), (1 << 3) | (1 << 4), ['spl\t#0', 'nop', 'nop'], [dict(vec=VEC[4], epc='a1', epsw=KP(0)), dict(vec=VEC[3], epc='a1', epsw=KP(0))])
    case('window/spl3-masks3', KP(7), (1 << 3), ['spl\t#3', 'nop'], [])
    case('user', HPSW(MODE_USER, MODE_USER, 0), 1 << 4, ['nop', 'nop'], [dict(vec=VEC[4], epc='a0', epsw=HPSW(MODE_USER, MODE_USER, 0))], mode='U', final='sev', htrap=1 << 1, xcode=4)
    case('wfe/masked', KP(7), 1 << 3, ['wfe', 'nop'], [])
    case('badvec', KP(0), 1 << 5, ['nop', 'nop'], [], vivec=vivec & ~(0xff << 32))
    case('twice', KP(0), 1 << 2, ['nop', 'nop'], [dict(vec=VEC[2], epc='a0', epsw=KP(0))])
    p.e('\tlea\tcases, r26\n\tmovq\t#%d, r29' % len(cases))
    p.e('next:\tmovq\t(r26)+, r1\n\tmtsr\thepc, r1\n\tmovq\t(r26)+, r1\n\tmtsr\thepsw, r1\n\tmovq\t(r26)+, r1\n\tmtsr\tvirq, r1\n\tmovq\t(r26)+, r1\n\tmtsr\tvivec, r1\n\tmovq\t(r26)+, r1\n\tmtsr\thtrap, r1')
    p.e('\tmovq\t#0, r1\n\tmtsr\tepc, r1\n\tmtsr\tgecause, r1\n\tmovq\t#99, r0\n\tgenter\t#RTIMASK_ALL')
    p.e('xh:\tmfsr\tr22, hexitr\n\tmfsr\tr20, virq\n\tmovq\t#0x7e57, r21\n\tmovq\tr21, (r28)+\n\tmovq\tr22, (r28)+\n\tmovq\tr20, (r28)+\n\tsob\tr29, next\n\tbr\tcompare')
    # the guest's handler: log the vector, EPC, EPSW and the status word inside, and return
    p.e('gh:\tmfsr\tr20, ecause\n\tmfsr\tr21, epc\n\tmfsr\tr22, epsw\n\tmfps\tr23\n\tbic\t#15, r23\n\tbic\t#15, r22\n\tmovq\tr20, (r28)+\n\tmovq\tr21, (r28)+\n\tmovq\tr22, (r28)+\n\tmovq\tr23, (r28)+\n\trti\t#RTIMASK_ALL')
    p.e('\t.align\t2')
    for ci, c in enumerate(cases):
        p.e('c%d:' % ci)
        p.e('c%da0:' % ci)
        for k, ins in enumerate(c['code']):
            p.e('\t%s\nc%da%d:' % (ins, ci, k + 1))
        p.e('\t%s' % c['final'])
    p.e('compare:\n\tlea\tlog, r1\n\tlea\texp, r2\n\tmovq\t#1, r6\ncw:\tmovq\t(r1)+, r4\n\tmovq\t(r2)+, r5\n\tcbne\tr4, r5, bad\n\tadd\t#1, r6\n\tcbne\tr6, #(NWORDS+1), cw\n\tmovq\t#0, r0\n\thalt\nbad:\tmovq\tr6, r0\n\thalt')
    nwords = 0
    exp = []
    for ci, c in enumerate(cases):
        for e in c['exits']:
            ent = (HPSW(MODE_KERNEL, MODE_USER if c['name'] == 'user' else MODE_KERNEL, 7))
            exp.append('%d, c%d%s, 0x%x, 0x%x' % (e['vec'], ci, e['epc'], e['epsw'], ent))
            nwords += 4
        left = c['virq']
        for e in c['exits']:
            left &= ~(1 << [l for l, v in VEC.items() if v == e['vec']][0])
        exp.append('0x7e57, %d, 0x%x' % (c['xcode'], left))
        nwords += 3
    text = '\n'.join(p.t).replace('NWORDS', str(nwords))
    text += '\n\t.data\n\t.align\t8\ncases:\n'
    for ci, c in enumerate(cases):
        text += '\t.quad\tc%d, 0x%x, 0x%x, 0x%x, 0x%x\t\t; %s\n' % (ci, c['psw'], c['virq'], c['vivec'], c['htrap'], c['name'])
    text += 'exp:\n' + ''.join('\t.quad\t%s\n' % e for e in exp)
    text += '\t.align\t8\nlog:\t.space\t%d\nhtab:\t.space\t4096\ngvtab:\t.space\t4096\n\t.space\t512\ngstk_top:\n' % (nwords * 8 + 64)
    write(outdir, 'hv-virq.S', text + '\n')
    return nwords


# ---------------------------------------------------------------------------------------------------------------------------------------
def gen_off(outdir):
    p = Prog()
    p.e('; GENERATED by tests/sim/gen_hv.py: do not edit.  The machine with no hypervisor strap (sim64 -K; QEMU kernel-mode=on): every register of the hypervisor block and GENTER is an illegal instruction (vector 2,')
    p.e('; EPC the instruction), in kernel mode, and the existing system registers work as before.')
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    p.e('\tlea\tvtab, r1\n\tmtsr\tvbr, r1\n\tlea\tubuf, r15\n\tmovzw\tretw, r2\n\tmovw\tr2, 4(r15)')
    p.e('\tmfsr\tr2, cpuid\n\tmfsr\tr3, vbr')
    p.eq('r2', '0')
    for name in sorted(SYSREGS, key=lambda n: SYSREGS[n]):
        for tmpl in ('tmplr', 'tmplw'):
            patched_illegal(p, tmpl, SYSREGS[name])
    for num in (13, 148, 255):
        for tmpl in ('tmplr', 'tmplw'):
            patched_illegal(p, tmpl, num)
    for ins in ('genter\t#RTIMASK_ALL', 'tlbigp\tr2'):
        a, b = p.label('I'), p.label('R')
        p.e('\tmovq\t#0, r10\n\tlea\t%s, r4' % b)
        p.e('%s:\t%s' % (a, ins))
        p.e('%s:' % b)
        p.eq('r10', 1)
        p.eq('r6', 'VECTOR_ILLEGAL')
        p.e('\tlea\t%s, r11' % a)
        p.cbne('r8', 'r11')
    p.trailer()
    p.e('h_ill:\tmfsr\tr6, ecause\n\tmfsr\tr8, epc\n\tadd\t#1, r10\n\tmtsr\tepc, r4\n\trti\t#RTIMASK_ALL')
    p.e('\t.align\t4\ntmplr:\tmfsr\tr1, ptbr\ntmplw:\tmtsr\tptbr, r1\nretw:\tret')
    p.e('\t.data\n\t.align\t8\nubuf:\t.space\t16\nvtab:\t.space\t16\n\t.quad\th_ill\n\t.space\t4072')
    write(outdir, 'hv-off.S', p.text())


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    gen_regs(out)
    gen_reserved(out)
    gen_switch(out)
    n = gen_exits(out)
    gen_off(out)
    gen_virq(out)
    print('gen_hv: hv-regs.S hv-reserved.S hv-switch.S hv-exits.S (%d exits) hv-off.S hv-virq.S in %s' % (n, out))

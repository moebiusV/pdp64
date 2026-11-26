#!/usr/bin/env python3
"""Generate the probes of the security corpus that are programs of regular shape (docs/security-corpus.md; errata 201):

   usage: gen_sec.py OUTDIR      writes every file below into OUTDIR (tests/sim, or tests/sec-open/sim, ...: the caller copies them where the index says)

Every probe exits 0 when the implementation does NOT have the hole it looks for and with the number of the first failed check otherwise (the check list is in the program)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from secgen import *

SYSREGS = ['ptbr', 'epc', 'eva', 'ecause', 'usp', 'ssp', 'epsw', 'vbr', 'mmuctl', 'asid', 'cpuid']
RO = ['eva', 'ecause', 'cpuid']
OUT = {}


def user_case(p, insn_lines, label, expect_vec, sentinel=None):
    """a case of a user-mode program: the instruction (lines) is at `label`; the handler resumes after it (r13).  Checks: one exception, the vector, EPC, and the sentinel register unchanged"""
    p.e('\tlea\tN%s, r13' % label)
    p.e('\tmovq\t=(cnt_base%s), r11' % label if False else '\tmovq\tcnt, r10')
    for l in insn_lines[:-1]:
        p.e(l)
    p.e('%s:' % label)
    p.e(insn_lines[-1])
    p.e('N%s:' % label)
    p.e('\tmovq\tcnt, r11\n\tsub\tr10, r11')
    p.eq('r11', '1', 'exactly one exception for ' + label)
    p.e('\tmovq\tlast_cause, r11')
    p.eq('r11', expect_vec, 'vector of ' + label)
    p.e('\tlea\t%s, r11\n\tmovq\tlast_epc, r12' % label)
    p.chk('r12', 'r11', 'EPC of ' + label)
    if sentinel:
        p.eq(sentinel, '0x5a5a5a5a5a5a', 'destination of %s unchanged' % label)


def gen_user_sysregs():
    """SEC-P03: every system register and every unassigned number from user mode: privileged (vector 3), the destination unchanged, no effect"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC + ENTER_USER + 'user:')
    for nm in SYSREGS:
        user_case(p, ['\tmovq\t=0x5a5a5a5a5a5a, r2', '\tmfsr\tr2, %s' % nm], 'r_%s' % nm, 'VECTOR_PRIVILEGED', 'r2')
    for nm in SYSREGS:
        if nm in RO:
            continue
        user_case(p, ['\tmovq\t=0x5a5a5a5a5a5a, r2', '\tmtsr\t%s, r2' % nm], 'w_%s' % nm, 'VECTOR_PRIVILEGED')
    # numbers the assembler will not name (read-only registers written, unassigned numbers): a patched copy of mfsr/mtsr in the buffer ubuf
    for kind, tmpl in (('r', 'tmplr'), ('w', 'tmplw')):
        for num in ([2, 3, 12] if kind == 'w' else []) + [4, 5, 13, 14, 63, 127, 128, 147, 148, 200, 255]:
            lab = 'p%s%d' % (kind, num)
            p.e('\tmovl\t%s, r2\n\tmovq\t=(%d<<16), r3\n\tbis\tr3, r2\n\tlea\tubuf, r4\n\tmovl\tr2, (r4)' % (tmpl, num))
            p.e('\tlea\tN%s, r13\n\tmovq\tcnt, r10\n\tmovq\t=0x5a5a5a5a5a5a, r2\n\tjmp\tr4' % lab)
            p.e('N%s:\tmovq\tcnt, r11\n\tsub\tr10, r11' % lab)
            p.eq('r11', '1', 'one exception for the patched %s of number %d' % ('mfsr' if kind == 'r' else 'mtsr', num))
            p.e('\tmovq\tlast_cause, r11')
            p.eq('r11', 'VECTOR_PRIVILEGED', 'a user program gets vector 3 for number %d (it cannot learn which numbers are assigned)' % num)
    p.done()
    p.e('\t.align\t4\ntmplr:\tmfsr\tr1, ptbr\ntmplw:\tmtsr\tptbr, r1\n\t.align 4')
    return ['every system register and every unassigned system-register number, read and written from USER mode (SEC-P03): the privileged-instruction exception (vector 3, EPC the',
            'instruction, the destination unchanged), the same vector for a number no register has (the program learns nothing about which registers exist).  Failed check n: exit n.'], \
        p.text() + KHANDLERS + KDATA


def gen_user_return():
    """SEC-P01: the returns that take a mask, and the two new invalidates, are privileged: from user mode vector 3, nothing changes (a user program cannot give itself a mode or kill a translation)"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC + ENTER_USER + 'user:')
    for nm, ins, vec in (('rti', 'rti\t#0', 'VECTOR_PRIVILEGED'), ('rti_all', 'rti\t#RTIMASK_ALL', 'VECTOR_PRIVILEGED'), ('rtt', 'rtt\t#0', 'VECTOR_PRIVILEGED'),
                         ('tlbias', 'tlbias\tr3', 'VECTOR_PRIVILEGED'),
                         ('genter', 'genter\t#0', 'VECTOR_ILLEGAL'), ('tlbigp', 'tlbigp\tr3', 'VECTOR_ILLEGAL')):      # no hypervisor strap: the hypervisor's instructions are illegal for everyone
        user_case(p, ['\tmovq\t=0x5a5a5a5a5a5a, r2', '\tmovq\tr2, r3', ins, ], 'x_%s' % nm, vec, 'r2')
    p.done()
    return ['RTI #mask, RTT #mask, GENTER #mask, TLBIAS and TLBIGP from USER mode (SEC-P01): the privileged-instruction exception (vector 3, EPC the instruction) for RTI, RTT and TLBIAS, the illegal-instruction exception',
            '(vector 2) for GENTER and TLBIGP, which the machine without the hypervisor strap does not have; no effect (a user program cannot return into another mode, enter a guest or invalidate translations).  Failed check n: exit n.'], p.text() + KHANDLERS + KDATA


def gen_user_mtps():
    """SEC-P04: MTPS from user mode is refused and cannot raise the privilege, the priority, the trace bit or the user-access guard"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC + ENTER_USER + 'user:')
    vals = ['0', '0xf', '0x1f', '0xe0', '0x300', '0xc00', '0x1000', '0x1fff', '0xffff', '0xffffffffffffffff', '(7<<PSW_PRI)|(MODE_KERNEL<<PSW_MODE)', '0x1000|(1<<PSW_T)']
    for i, v in enumerate(vals):
        p.e('\tlea\tNm%d, r13\n\tmovq\tcnt, r10\n\tmovq\t=(%s), r1\n\tmtps\tr1' % (i, v))
        p.e('Nm%d:\tmovq\tcnt, r11\n\tsub\tr10, r11' % i)
        p.eq('r11', '1', 'mtps of %s from user mode faults (one exception)' % v)
        p.e('\tmovq\tlast_cause, r11')
        p.eq('r11', 'VECTOR_PRIVILEGED', 'the fault of mtps of %s is the privileged-instruction vector' % v)
        p.e('\tmfps\tr5')
        p.eq('r5', '(MODE_USER<<PSW_MODE)|(MODE_USER<<PSW_PREV)', 'after mtps of %s the mode, previous mode, priority, T and the reserved low bits are unchanged' % v)
    # no trace trap came (T was not set): the count of exceptions is exactly the one above
    p.done()
    return ['MTPS from USER mode (SEC-P04, audit 3.1 and 3.3): it is a privileged instruction: a value with the kernel mode, the priority 7, the trace bit or the reserved bits faults with the privileged-instruction',
            'vector and changes nothing: the mode is still user (MFPS), a privileged instruction still faults, and no trace exception comes.  Failed check n: exit n.'], p.text() + KHANDLERS + KDATA


def gen_eva_stale():
    """SEC-B02: after an exception that has no address, EVA and ECAUSE do not hold what an earlier exception (another context's) left"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC + ENTER_USER + 'user:')
    p.e('\tlea\tN0, r13\n\tmovq\t=MAP_DEV_END, r2\n\tmovq\t(r2), r3')           # a load of an address nothing answers: EVA is the address
    p.e('N0:\tmovq\tlast_eva, r4')
    p.e('\tmovq\t=MAP_DEV_END, r5')
    p.chk('r4', 'r5', 'control: the faulting load left its address in EVA')
    p.e('\tmovq\tlast_cause, r4')
    p.eq('r4', 'VECTOR_BUSFAULT', 'control: the bus fault')
    cases = [('priv', '\tmfsr\tr3, cpuid', 'VECTOR_PRIVILEGED'), ('bpt', '\tbpt', 'VECTOR_BPT'), ('trap', '\ttrap\t#5', 'VECTOR_TRAP_BASE+5'), ('div', '\tmovq\t#0, r2\n\tmovq\t#7, r3\n\tdiv\tr1, r2, r3', 'VECTOR_DIVZERO'),
             ('ill', '\t.word\t0xffff', 'VECTOR_ILLEGAL')]
    for nm, ins, vec in cases:
        p.e('\tlea\tN_%s, r13' % nm)
        p.e(ins)
        p.e('N_%s:\tmovq\tlast_eva, r4' % nm)
        p.e('\tmovq\t=MAP_DEV_END, r5')
        p.chkne('r4', 'r5', 'EVA after %s is not the stale address of the earlier fault' % nm)
        p.e('\tmovq\tlast_cause, r4')
        p.eq('r4', vec, 'ECAUSE after %s is exactly the vector (no stale bit)' % nm)
        # and a fault of the user-access kind earlier would leave bit 15: not set here
    p.done()
    return ['EVA and ECAUSE after an exception that has no address (SEC-B02): a load that nothing answers leaves its address in EVA; the exceptions that follow (privileged, bpt, trap, divide by zero,',
            'illegal) must not leave that address (it is another context\'s data) and ECAUSE is the vector exactly.  Failed check n: exit n.'], p.text() + KHANDLERS + KDATA


SCALARS = [n for n in range(32) if n != 14]          # R14 is the stack pointer of the mode returned to: never cleared, and mask bit 14 is the vector registers and the floating-point flags


def secret(n):
    return '0x5ec0de0000%02x' % n


def set_secrets(p, regs):
    for n in regs:
        p.e('\tmovq\t=%s, r%d' % (secret(n), n))


def kept_mask(keep, vector=True):
    return sum(1 << n for n in keep) | ((1 << 14) if vector else 0)


def snap_offset(n):
    """the offset from the stack pointer of the register n in the image PUSHM #0xffffbfff makes (R0 pushed first, so the highest register is on top)"""
    return 8 * (len(SCALARS) - 1 - SCALARS.index(n))


def check_snapshot(p, base, keep, what):
    """the registers kept by the mask hold the kernel's value in the image at `base` (an address expression of r12's source), all the others are zero"""
    p.e('\tlea\t%s, r12' % base)
    for n in SCALARS:
        if n in keep:
            continue
        p.e('\tmovq\t%d(r12), r13' % snap_offset(n))
        p.chk('r13', '#0', 'r%d is zero after %s (not the %s it held before)' % (n, what, 'kernel value' if True else ''))
    for n in SCALARS:
        if n not in keep:
            continue
        p.e('\tmovq\t%d(r12), r13' % snap_offset(n))
        p.eq('r13', secret(n), 'r%d, named by the mask, keeps its value across %s (the control)' % (n, what))


KEEP = [0, 8, 13, 15, 24, 31]


def gen_regs_carry():
    """SEC-B04: the kernel's registers are cleared by the return to user mode except those the mask of RTI names"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC)
    set_secrets(p, SCALARS)
    p.e(enter_user('0x%x' % kept_mask(KEEP), clear_r1=False) + 'user:')
    for n in SCALARS:
        if n not in KEEP:
            p.chk('r%d' % n, '#0', 'r%d is zero in user mode after RTI (kernel data is not visible)' % n)
    for n in KEEP:
        if n != 17:
            p.eq('r%d' % n, secret(n), 'r%d, named by the mask, keeps its value (the control: the probe can see a register)' % n)
    p.done()
    return ['The scalar registers across RTI (SEC-B04): the kernel fills every scalar register with a secret and returns to user mode with RTI #mask, the mask naming r0, r8, r13, r15, r24, r31; the user',
            'reads them.  The hardware clears every register whose bit of the mask is zero in the return itself, so the kernel cannot forget one; the named ones keep their value (the control).',
            'Failed check n: exit n.'], p.text() + KHANDLERS + KDATA


def gen_rtt_clear():
    """SEC-B04: RTT (return and trace) clears like RTI"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC)
    set_secrets(p, SCALARS)
    p.e('\tlea\tNext, r13')                                      # the trace trap after the user's first instruction (the PUSHM) resumes at r13: the mask keeps it
    p.e(enter_user('0x%x' % kept_mask([13]), clear_r1=False).replace('\trti\t#', '\trtt\t#') + 'user:')
    p.e('\tpushm\t#0xffffbfff')
    p.e('Next:\tmovq\tr14, r16')
    p.e('\tadd\t#%d, r14\t\t\t; the image is on the stack: take it off' % (8 * len(SCALARS)))
    for n in SCALARS:
        if n in (12, 13, 16):
            continue                                              # r12 and r11 are the handler's, r13 the resume address the mask keeps, r16 holds the image address
        p.e('\tmovq\t%d(r16), r12' % snap_offset(n))
        p.chk('r12', '#0', 'r%d is zero after RTT (kernel data is not visible)' % n)
    p.e('\tmovq\t%d(r16), r12' % snap_offset(13))
    p.e('\tlea\tNext, r17')
    p.chk('r12', 'r17', 'control: r13, named by the mask, keeps its value (the resume address) across RTT')
    p.e('\tmovq\tcnt, r12')
    p.eq('r12', '1', 'control: the trace trap was taken once (RTT sets T), so the image was made by the first user instruction')
    p.done()
    return ['The registers across RTT (SEC-B04): the kernel fills every scalar register with a secret and returns to user mode with RTT #mask (the mask names only r13, the resume address of the',
            'trace trap); the user\'s first instruction PUSHM makes an image of the registers before the trace trap is taken; all but r13 must be zero.  Failed check n: exit n.'], \
        p.text() + KHANDLERS.replace('\tmtsr\tepc, r13\n', '\tmtsr\tepc, r13\n\tmfsr\tr12, epsw\n\tbic\t#(1<<PSW_T), r12\n\tmtsr\tepsw, r12\n') + KDATA


def gen_rti_same_mode():
    """SEC-B04: a return to the same mode keeps every register whatever the mask says"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC)
    p.e('\tlea\tNext, r13')
    keep = [n for n in SCALARS if n not in (11, 12, 13)]
    set_secrets(p, keep)
    p.e('\ttrap\t#4')
    p.e('Next:')
    for n in keep:
        if n != 17:
            p.eq('r%d' % n, secret(n), 'r%d keeps its value across a return to the same mode (the mask is ignored)' % n)
    p.eq('r17', secret(17), 'r17 keeps its value across a return to the same mode (the mask is ignored)')
    p.e('\tmovq\tcnt, r12')
    p.eq('r12', '1', 'control: the exception was taken once, so there was a return')
    p.done()
    body = p.text() + KHANDLERS.replace('rti\t#RTIMASK_ALL', 'rti\t#RTIMASK_NONE') + KDATA
    return ['A return to the same mode (SEC-B04): the kernel fills its registers with secrets, a TRAP enters the kernel handler and the handler returns with RTI #0 to the same mode: nothing is a',
            'lesser mode, so no register is cleared (the mask is ignored).  Failed check n: exit n.'], body


def gen_fpsr_carry():
    """SEC-B05: the sticky floating-point flags set by one context are not visible to the next"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC + ENTER_USER + 'user:')
    scen = [('RTI with the mask bit 14 clear', 0), ('a write of ASID', 0), ('a write of PTBR', 0), ('the control: a write of SSP, return with every register kept', 0x1f)]
    for k, (what, want) in enumerate(scen):
        p.e('\tmovq\t#0x1f, r1\n\tfsflags\tr1, r2')                    # context A sets all five flags
        p.e('\ttrap\t#3')                                                # the kernel "switches" to context B by the way of scenario k
        p.e('\tmovq\t#0, r1\n\tfsflags\tr1, r2')                         # context B reads and clears them
        p.eq('r2', '0x%x' % want, 'context B finds the floating-point flags %s after %s' % ('as A left them' if want else 'clear', what))
    p.done()
    sw = r"""h_sw:	movq	scen, r12
	add	#1, r12
	movq	r12, scen
	movq	#0, r11
	cbeq	r12, #1, s1
	cbeq	r12, #2, s2
	cbeq	r12, #3, s3
	mtsr	ssp, r11
	rti	#RTIMASK_ALL
s1:	rti	#(RTIMASK_ALL & ~(1<<RTIMASK_VECTOR))
s2:	mtsr	asid, r11
	rti	#RTIMASK_ALL
s3:	mtsr	ptbr, r11
	rti	#RTIMASK_ALL
"""
    body = p.text() + KHANDLERS.replace('hgen:', sw + 'hgen:') + KDATA.replace('cnt:', 'scen:\t\t.quad\t0\ncnt:')
    body = body.replace('\tmovq\tr2, 2056(r1)', '\tmovq\tr2, 2056(r1)\n\tlea\th_sw, r2\n\tmovq\tr2, 2072(r1)')
    return ['The sticky floating-point flags (fpsr) across a context switch (SEC-B05): user context A sets the five flags and traps; the kernel switches to context B in four ways (a return whose',
            'mask clears bit 14; a write of ASID; a write of PTBR; and, as the control, a write of SSP with every register kept) and B reads the flags with fsflags.  The flags belong to',
            'the process: in the first three B finds them clear, in the control it finds what A left.  Failed check n: exit n.'], body


def gen_fpsr_gtbr():
    """SEC-B05: a write of GTBR clears the floating-point flags (the hypervisor switches guests)"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:')
    p.e('\tmovq\t#0x1f, r1\n\tfsflags\tr1, r2')
    p.e('\tmovq\t#0, r1\n\tmtsr\tvtoff, r1')
    p.e('\tmovq\t#0, r1\n\tfsflags\tr1, r2')
    p.eq('r2', '0x1f', 'control: a write of VTOFF leaves the floating-point flags (the probe sees them)')
    p.e('\tmovq\t#0x1f, r1\n\tfsflags\tr1, r2')
    p.e('\tmovq\t#0, r1\n\tmtsr\tgtbr, r1')
    p.e('\tmovq\t#0, r1\n\tfsflags\tr1, r2')
    p.eq('r2', '0', 'the floating-point flags are clear after a write of GTBR')
    p.done()
    return ['The floating-point flags across a write of GTBR (SEC-B05): the hypervisor sets the flags, writes VTOFF (the control: they stay) and then GTBR (the guest tag): they are cleared.',
            'sim64 -H; QEMU hypervisor=on.  Failed check n: exit n.'], p.text()


def gen_genter_regs():
    """SEC-B04: GENTER #mask clears the hypervisor's registers except those named"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + HVSETUP.replace('\tlea\thstk_top, r14\n', '\tlea\thstk_top, r14\n'))
    p.e('\tlea\tgstk_top, r2\n\tmtsr\tgksp, r2')
    p.e('\tlea\tg1, r2\n\tmtsr\thepc, r2\n\tmovq\t#0, r2\n\tmtsr\thepsw, r2')
    keep = [3, 8, 15, 24]
    set_secrets(p, SCALARS)
    p.e('\tgenter\t#0x%x' % kept_mask(keep))
    p.e('g1:\tpushm\t#0xffffbfff\n\thalt')
    p.e('back1:')
    check_snapshot(p, 'gstk_top-%d' % (8 * len(SCALARS)), keep, 'GENTER')
    p.done()
    tail = HVTAIL.replace('xh:\tjmp\tr20', 'xh:\tlea\tback1, r1\n\tjmp\tr1').replace('hstk_top:', 'hstk_top:\n\t.space\t512\ngstk_top:')
    return ['The hypervisor\'s registers across GENTER (SEC-B04): the hypervisor fills every scalar register with a secret and enters a guest with GENTER #mask (the mask names r3, r8, r15, r24);',
            'the guest\'s first instruction, PUSHM, makes an image of its registers; the hypervisor reads it after the exit: all but the named ones are zero.  sim64 -H; QEMU hypervisor=on.  Failed check n: exit n.'], \
        p.text() + tail


SRC = '\t.long\t1, 2, 3, 4, 10, 20, 30, 40\n\t.long\t100, 200, 300, 400, 1000, 2000, 3000, 4000\n'


def zero_check(p, label, nq, what):
    """fail unless nq quadwords at label are zero"""
    p.e('\tlea\t%s, r4\n\tmovq\t#%d, r6' % (label, nq))
    p.e('zc%d:\tmovq\t(r4)+, r5' % (p.n + 1))
    p.e('\tcbeq\tr5, #0, 1f\n%s\n1:' % p.fail(p.n + 1))
    p.n += 1
    p.e('\tsob\tr6, zc%d' % p.n)
    p.t[-3] = p.t[-3] + '\t; check %d %s' % (p.n, what)


def gen_vec_bleed():
    """SEC-B06: a vector register that the program did not write, and an accumulator named by vclr, hold nothing of another context"""
    p = Prog(user=True)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC)
    # the kernel runs a block that leaves values in v3, v5 (an accumulator: vclr then sums) and v9
    p.e('\tlea\tsrc, r1\n\tlea\tsrc+32, r5\n\tlea\tdst, r3\n\tvec\tr1, r5\n\tvclr.l\tv5, #1\n\tvld.l\tv3, (r1)+\n\tvadd.l\tv5, v5, v3\n\tvadd.l\tv9, v3, v3\n\tvst.l\tv3, (r3)+\n\tvend')
    p.e(ENTER_USER + 'user:')
    # control: a block that loads v3 stores it (the block works, the registers are not simply dead)
    p.e('\tlea\tsrc, r1\n\tlea\tsrc+32, r5\n\tlea\tdst, r3\n\tvec\tr1, r5\n\tvld.l\tv3, (r1)+\n\tvst.l\tv3, (r3)+\n\tvend')
    p.e('\tlea\tdst, r4\n\tmovq\t(r4), r5\n\tmovq\tsrc_q, r6')
    p.chk('r5', 'r6', 'control: a loaded register stores what was loaded')
    for nm, reg in (('v3 (the kernel left data in it)', 'v3'), ('v5 (an accumulator of the kernel)', 'v5'), ('v9 (computed by the kernel)', 'v9')):
        p.e('\tlea\tdst, r3\n\tmovq\t=0xa5a5a5a5a5a5a5a5, r2\n\tmovq\tr2, (r3)\n\tmovq\tr2, 8(r3)\n\tmovq\tr2, 16(r3)\n\tmovq\tr2, 24(r3)')
        p.e('\tlea\tsrc, r1\n\tlea\tsrc+32, r5\n\tvec\tr1, r5\n\tvld.l\tv8, (r1)+\n\tvst.l\t%s, (r3)+\n\tvend' % reg)
        zero_check(p, 'dst', 4, 'a user block stores %s that it never wrote: zero' % nm)
    # an accumulator named outside a block is zero
    p.e('\tvclr.l\tv5, #1\n\tlea\tdst, r3\n\tmovq\t=0xa5a5a5a5a5a5a5a5, r2\n\tmovq\tr2, (r3)\n\tmovq\tr2, 8(r3)\n\tmovq\tr2, 16(r3)\n\tmovq\tr2, 24(r3)')
    p.e('\tlea\tsrc, r1\n\tlea\tsrc+32, r5\n\tvec\tr1, r5\n\tvld.l\tv8, (r1)+\n\tvst.l\tv5, (r3)+\n\tvend')
    zero_check(p, 'dst', 4, 'an accumulator named by vclr starts at zero, not at the kernel\'s sums')
    p.done()
    data = KDATA.replace('ubuf:', 'ubuf:') + '\t.align 8\nsrc_q:\t.quad\t0x0000000200000001\nsrc:\n' + SRC + 'dst:\t.space\t32\n'
    return ['Vector registers across contexts (SEC-B06; audit 3.4, vec-isa 1): the kernel runs a block that leaves data in v3, a vclr accumulator in v5 and a result in v9; the user, with no',
            'load of its own, stores v3, v5 and v9 in a block and an accumulator named by vclr: all must be zero (the registers are hidden; none shows another context\'s data).  Failed check n: exit n.'], \
        p.text() + KHANDLERS + data


def vec_two(p):
    pass


def gen_vec_hole_a():
    """SEC-V01 (FOUND): an interrupt between vclr and vec changes the result of the program"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC)
    # run twice: without and with an exception between the vclr and the vec; the program's result must be the same
    for k, trap in ((0, False), (1, True)):
        p.e('\tlea\tdst%d, r3\n\tvclr.l\tv0, #1' % k)
        if trap:
            p.e('\tlea\tNx, r13\n\ttrap\t#7\nNx:')
        p.e('\tlea\tsrc, r1\n\tlea\tsrc+32, r5\n\tvec\tr1, r5\n\tvld.l\tv8, (r1)+\n\tvadd.l\tv0, v0, v8\n\tvst.l\tv0, (r3)+\n\tvend')
    p.e('\tlea\tdst0, r1\n\tlea\tdst1, r2\n\tmovq\t#4, r3')
    p.e('cmpl:\tmovq\t(r1)+, r4\n\tmovq\t(r2)+, r5')
    p.n += 1
    p.e('\tcbeq\tr4, r5, 1f\n%s\n1:\tsob\tr3, cmpl\t; check %d: the result with an exception between vclr and vec equals the result without' % (p.fail(p.n), p.n))
    p.e('\tmovq\t#0, r0\n\thalt')
    # the handler of trap #7 (vector 263) only returns
    body = p.text().replace('\tlea\tvtab, r1\n\tlea\th_ok, r2', '\tlea\tvtab, r1\n\tlea\th_ok, r2') + KHANDLERS
    body = body.replace('hgen:', 'h_ret:\trti\t#RTIMASK_ALL\nhgen:')
    body = body.replace('\tmovq\tr2, 2056(r1)', '\tmovq\tr2, 2056(r1)\n\tlea\th_ret, r2\n\tmovq\tr2, 2104(r1)', 1)
    data = KDATA + '\t.align 8\nsrc:\n' + SRC + 'dst0:\t.space\t32\ndst1:\t.space\t32\n'
    return ['An exception between VCLR and VEC (SEC-V01; best-of-breed-vector, the accumulator naming across an exception): the same block is run once straight after the vclr and once with an',
            'exception (a trap whose handler only returns: an interrupt is the same) between them.  A program cannot see an interrupt, so the two results must be equal.  The current rule clears the',
            'naming at every exception entry and return, so the second run gives plain registers, not running sums: the probe FINDS that.  Failed check n: exit n.'], body + data


def gen_vec_inplace(epilogue=False):
    """SEC-V02 (FOUND): a block with accumulators that reads and writes the same stream repeats the stores of the strips already done when it is restarted after a fault"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + FSETUP)
    # control: an ordinary in-place block across a page boundary (the second page faults): every lane is 1
    for k, (addr, hidden) in enumerate((('0x800ff0', False), ('0x802ff0', True))):
        p.e('\tmovq\t=(0x800000+%d), r6\n\tmovzb\t(r6), r7' % (0x2000 * k))          # touch the first page of the pair: it is mapped; the next one faults inside the block
        p.e('\tmovq\t=(%s), r1\n\tmovq\tr1, r3\n\tadd\t#32, r3\n\tmovq\tcnt, r10' % addr)
        p.e('\tvec\tr1, r3')
        if hidden:
            p.e('\tvclr.l\tv4, #1')
        p.e('\tvld.l\tv0, 0(r1)\n\tvadd.l\tv1, v0, #1')
        if hidden:
            p.e('\tvadd.l\tv4, v4, v1')
        p.e('\tvst.l\tv1, (r1)+\n\tvend')
        p.e('\tmovq\tcnt, r11\n\tsub\tr10, r11')
        p.chkne('r11', '#0', 'the page fault happened (the probe is not vacuous)')
        p.e('\tmovq\t=(%s), r4\n\tmovq\t#8, r6\n\tmovq\t#0, r8' % addr)
        p.e('lw%d:\tmovl\t(r4)+, r5\n\tcbeq\tr5, #1, 1f\n\tadd\t#1, r8\n1:\tsob\tr6, lw%d' % (k, k))
        p.chk('r8', '#0', 'lanes that are not 1 after the %s block' % ('hidden (accumulator)' if hidden else 'ordinary'))
    p.done()
    body = p.text() + FHANDLERS + FDATA + ftables()
    return ['An accumulator block that updates memory in place, restarted after a page fault (SEC-V02; best-of-breed-vector hole B): the block adds 1 to 8 lanes that straddle a page',
            'boundary.  The ordinary block is the control (all lanes 1).  With a vclr the block restarts from its entry after the fault and adds 1 again to the lanes the first strip had stored:',
            'half the lanes are 2, silently.  Check 2 numbers: control then accumulator block.  sim64 -K -x 0x800000:0xa00000; on QEMU the same program uses real page tables.'], body


def gen_vec_stale_record():
    """SEC-V03 (FOUND): the record of an aborted block is keyed by the address of the vec, not by the context"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + FSETUP)
    p.e('\tlea\tustack_top, sp')
    # control: context B alone: dst == src
    p.e('\tmovq\t#0, r6\n\tlea\tsrcB, r1\n\tlea\tdstB, r3\n\tcall\tF')
    cmp_ = lambda lab, what: None
    p.e('\tlea\tsrcB, r1\n\tlea\tdstB, r2\n\tmovq\t#4, r3\n\tmovq\t#0, r8')
    p.e('cB0:\tmovq\t(r1)+, r4\n\tmovq\t(r2)+, r5\n\tcbeq\tr4, r5, 1f\n\tadd\t#1, r8\n1:\tsob\tr3, cB0')
    p.chk('r8', '#0', 'control: context B alone computes dst == src')
    p.e('\tlea\tdstB, r1\n\tmovq\t=0xa5a5a5a5a5a5a5a5, r2\n\tmovq\tr2, (r1)\n\tmovq\tr2, 8(r1)\n\tmovq\tr2, 16(r1)\n\tmovq\tr2, 24(r1)')
    # context A: the hidden block faults in its second strip (the data straddles the window page); the handler switches to B
    p.e('\tmovq\t=0x800000, r6\n\tmovzb\t(r6), r7')
    p.e('\tlea\tBstart, r6\n\tmovq\tr6, redirect')
    p.e('\tmovq\t#1, r6\n\tmovq\t=0x800ff0, r1\n\tlea\tdstA, r3\n\tcall\tF')
    p.e('\tmovq\t#97, r0\n\thalt')                                       # not reached: the fault switched away
    p.e('Bstart:\tlea\tustack_top, sp\n\tmovq\t#0, r6\n\tlea\tsrcB, r1\n\tlea\tdstB, r3\n\tcall\tF')
    p.e('\tlea\tsrcB, r1\n\tlea\tdstB, r2\n\tmovq\t#4, r3\n\tmovq\t#0, r8')
    p.e('cB1:\tmovq\t(r1)+, r4\n\tmovq\t(r2)+, r5\n\tcbeq\tr4, r5, 1f\n\tadd\t#1, r8\n1:\tsob\tr3, cB1')
    p.chk('r8', '#0', 'context B, running the very same vec address after A was aborted, computes dst == src (it inherits nothing of A)')
    p.done()
    p.e('\t.align\t2\nF:\tcbeq\tr6, #0, skipclr\n\tvclr.l\tv4, #1\nskipclr:')
    p.e('\tlea\tsrcB+32, r5\n\tmovq\tr1, r2\n\tadd\t#32, r2\n\tcbeq\tr6, #0, 1f\n\tmovq\tr2, r5\n\tbr\t2f\n1:\tlea\tsrcB+32, r5\n2:')
    p.e('\tvec\tr1, r5\n\tvld.l\tv8, (r1)+\n\tvadd.l\tv4, v4, v8\n\tvst.l\tv4, (r3)+\n\tvend\n\tret')
    body = p.text() + FHANDLERS + FDATA + ftables()
    body = body.replace('l1:\n', 'l1:\n', 1)
    body += '\t.data\n\t.align\t8\nsrcB:\n' + SRC + 'dstB:\t.space\t32\ndstA:\t.space\t32\n'
    return ['The hidden record of an aborted block (SEC-V03; best-of-breed-vector hole D): context A runs a block with an accumulator (vclr) at address F, faults in its second strip and is switched',
            'away; context B then runs the same code at the same address with no vclr.  The record of the aborted block is found by the address of the vec, not by the context, so B\'s block is',
            'given A\'s accumulator naming and gives running sums instead of a copy.  Check 1 is the control (B alone).  sim64 -K -x 0x800000:0xa00000; QEMU with its tables.'], body


HVSETUP = r"""
	lea	htab, r1
	mtsr	hvbr, r1
	lea	xh, r2
	movq	#512, r3
hfill:	movq	r2, (r1)+
	sob	r3, hfill
	lea	gvtab, r1
	mtsr	vbr, r1
	lea	gh, r2
	movq	#512, r3
gfill:	movq	r2, (r1)+
	sob	r3, gfill
	lea	hstk_top, r14
"""
HVTAIL = r"""
xh:	jmp	r20
gh:	halt
	.data
	.align	8
htab:	.space	4096
gvtab:	.space	4096
hstk:	.space	512
hstk_top:
"""


def gen_restart_scalar():
    """SEC-R01: a faulting scalar instruction (load or store with auto-increment or auto-decrement, push) leaves no architectural effect: registers and memory as before, EPC the instruction"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + FSETUP)
    p.e('\tlea\tustack_top, sp')
    SENT = '0x5a5a5a5a5a5a5a5a'
    cases = [('load (r1)+', 0x810000, '\tmovq\t(r1)+, r3', 0x810008, 0),
             ('store -(r1)', 0x811008, '\tmovq\tr3, -(r1)', 0x811000, 0x1122334455667788),
             ('push', 0x812008, '\tpush\tr3', 0x812000, 0x1122334455667788)]
    for i, (nm, start, ins, final, val) in enumerate(cases):
        p.e('\tmovq\t=(%s), r3\n\tmovq\t=(%s), r1' % (SENT if val == 0 else hex(val), hex(start)))
        if nm == 'push':
            p.e('\tmovq\tr14, r9\n\tmovq\tr1, r14')
        p.e('\tmovq\t#0, r10\n\tmovq\tr10, cnt\n\tmovq\t#0, r12\n\tmovq\t=0x7777, r4')
        p.e('p%d:%s' % (i, ins))
        p.e('\tmovq\tcnt, r11')
        p.eq('r11', '1', '%s: one fault' % nm)
        p.e('\tlea\tp%d, r11\n\tmovq\tlast_epc, r12' % i)
        p.chk('r12', 'r11', '%s: EPC is the instruction' % nm)
        want_r1 = start
        p.e('\tmovq\ths_r1, r12\n\tmovq\t=(%s), r11' % hex(want_r1))
        p.chk('r12', 'r11', '%s: at the fault the pointer register is as before the instruction' % nm)
        if nm == 'push':
            p.e('\tmovq\tr9, r14')
        p.e('\tmovq\ths_r3, r12\n\tmovq\t=(%s), r11' % (SENT if val == 0 else hex(val)))
        p.chk('r12', 'r11', '%s: at the fault the other register is as before' % nm)
        if nm == 'load (r1)+':
            p.e('\tmovq\t=(%s), r11' % hex(final))
            p.chk('r1', 'r11', 'load: after the restart the pointer moved once')
            p.chk('r3', '#0', 'load: the register holds the (zero) memory')
        elif nm == 'store -(r1)':
            p.e('\tmovq\t=(%s), r11' % hex(final))
            p.chk('r1', 'r11', 'store: after the restart the pointer moved once')
            p.e('\tmovq\t(r1), r12')
            p.chk('r12', 'r3', 'store: the value is in memory')
        else:
            p.e('\tmovq\t=(0x812000), r4\n\tmovq\t(r4), r12')
            p.chk('r12', 'r3', 'push: the value is in memory once the page is mapped')
    p.done()
    body = p.text() + FHANDLERS.replace('h_fault:\n', 'h_fault:\n\tmovq\tr1, hs_r1\n\tmovq\tr3, hs_r3\n', 1) \
        + FDATA.replace('redirect:\t.quad\t0', 'redirect:\t.quad\t0\nhs_r1:\t.quad\t0\nhs_r3:\t.quad\t0') + ftables()
    return ['Precise faults of scalar instructions (SEC-R01): a load with (r1)+, a store with -(r1) and a push whose page is not present (the first touch faults; the handler maps it and returns).  At',
            'the fault the pointer and the other register are as before the instruction and EPC is the instruction; after the restart the effect happens once.  sim64 -K -x 0x810000:0x813000',
            'style window; QEMU with its tables.  Failed check n: exit n.'], body


def gen_tlb_mode():
    """SEC-T01: a translation cached by one mode is not used by the other: a kernel-filled entry of a kernel page does not serve user mode; a user-filled entry of a user page does not serve the kernel"""
    p = Prog(user=False)
    p.e(HEADER + '#define RWX (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)\n\t.text\n\t.globl\t_start\n_start:' + KVEC)
    p.e('\tlea\tl2, r1\n\tmtsr\tptbr, r1\n\tmovq\t#1, r1\n\tmtsr\tmmuctl, r1\n\tisync')
    # kernel touches the kernel-only page (low address): the translation is cached with kernel rights
    p.e('\tmovq\tkdata, r5')
    # to user mode at the alias of the code (0x80000000 + the address)
    p.e('\tmovq\t=0x80000000, r6\n\tlea\tuser, r1\n\tadd\tr6, r1\n\tmtsr\tepc, r1')
    p.e('\tlea\tustack_top, r1\n\tadd\tr6, r1\n\tmtsr\tusp, r1')
    p.e('\tmovq\t#((MODE_USER<<PSW_MODE)|(MODE_USER<<PSW_PREV)), r1\n\tmtsr\tepsw, r1\n\trti\t#RTIMASK_ALL')
    p.user = True
    p.e('user:\tmovq\t=0x80000000, r6')
    p.e('\tlea\tkdata, r4\n\tsub\tr6, r4')                      # the low (kernel-only) address of kdata
    p.e('\tlea\tNu1, r13\n\tmovq\tcnt, r10\n\tmovq\t=0x2222, r5')
    p.e('\tmovq\t(r4), r5')
    p.e('Nu1:\tmovq\tcnt, r11\n\tsub\tr10, r11')
    p.eq('r11', '1', 'user mode: a load of a kernel page whose translation the kernel just cached faults')
    p.e('\tmovq\tlast_cause, r11')
    p.eq('r11', 'VECTOR_LPROT', 'user mode: it is a load protection fault')
    p.eq('r5', '0x2222', 'user mode: the kernel page\'s data did not arrive in the register')
    p.e('\tlea\tudata, r7\n\tmovq\t(r7), r5\n\ttrap\t#2')       # fills the user translation of the user page, then back to the kernel
    p.user = False
    p.e('kern2:\tmovq\t=0x80000000, r6\n\tlea\tudata, r7\n\tadd\tr6, r7')
    p.e('\tlea\tNk, r13\n\tmovq\tcnt, r10\n\tmovq\t=0x2468, r5')
    p.e('\tmovq\t(r7), r5')
    p.e('Nk:\tmovq\tcnt, r11\n\tsub\tr10, r11')
    p.eq('r11', '1', 'kernel mode: a load of a user page whose translation user mode just cached faults')
    p.e('\tmovq\tlast_cause, r11')
    p.eq('r11', 'VECTOR_LPROT', 'kernel mode: it is a load protection fault')
    p.eq('r5', '0x2468', 'kernel mode: the register is unchanged')
    p.done()
    body = p.text() + KHANDLERS.replace('hgen:', 'h_sw:\tlea\tkern2, r12\n\tmtsr\tepc, r12\n\tmovq\t#0, r12\n\tmtsr\tepsw, r12\n\trti\t#RTIMASK_ALL\nhgen:')
    body = body.replace('\tmtsr\tepc, r13\n\trti\t#RTIMASK_ALL\nh_ok', '\tmtsr\tepc, r13\n\trti\t#RTIMASK_ALL\nh_ok')
    body = body.replace('\tlea\th_fail, r2\n\tmovq\tr2, 2056(r1)', '\tlea\th_fail, r2\n\tmovq\tr2, 2056(r1)')
    data = KDATA + '\t.align\t4096\nl2:\n\t.quad\t0 + RWX\n\t.space\t8\n\t.quad\t0 + RWX|(1<<PTE_U)\n\t.space\t4072\n\t.align\t8\nkdata:\t.quad\t0x1357\nudata:\t.quad\t0x2469\n'
    body = body.replace('\tmovq\tr2, 2056(r1)\n', '\tmovq\tr2, 2056(r1)\n', 1)
    return ['A translation cached in one mode is not used in the other (SEC-T01; manual 6.8, 6.10): the kernel loads a kernel-only page, then user mode loads the same address (must fault, vector 10);',
            'user mode loads a user page (at the alias 0x80000000 of memory), then the kernel loads it (must fault).  Failed check n: exit n.'], body.replace('h_fail, r2\n\tmovq\tr2, 2056(r1)', 'h_fail, r2\n\tmovq\tr2, 2056(r1)\n\tlea\th_sw, r2\n\tmovq\tr2, 2064(r1)') + data


def gen_hv_reset_inplace(write_mmuctl=False, tlbigp=False):
    """SEC-H01 (FOUND): a guest reset in place (same stage-2 root, translation already off, the stage-2 contents rewritten) leaves the guest's cached translations"""
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'qemu', 'hv-stage2.S')).read().split('\n')
    i = [k for k, l in enumerate(src) if l.startswith('#include')][0]
    j = [k for k, l in enumerate(src) if '--- T1:' in l][0]
    pre = '\n'.join(src[i:j]) + '\n'
    k = [k for k, l in enumerate(src) if l.startswith('xh:')][0]
    post = '\n'.join(src[k:]) + '\n'
    p = Prog(user=False)
    p.n = 200
    L = []

    def enter(back):
        L.append('\tlea\tg9, r22\n\tmtsr\thepc, r22\n\tmovq\t#0, r22\n\tmtsr\thepsw, r22\n\tlea\t%s, r20\n\tmovq\t#99, r0\n\tgenter\t#RTIMASK_ALL\n%s:' % (back, back))
    p.e('\tmovq\t=(PHYS(0x40a000)), r25\n\tmovq\t=0xaaaa, r26\n\tmovq\tr26, (r25)')
    p.e('\tmovq\t=(PHYS(0x40c000)), r25\n\tmovq\t=0xcccc, r26\n\tmovq\tr26, (r25)')
    p.e('\tlea\ts2l0+80, r25\n\tmovq\t=(PHYS(0x40a000)|LEAF), r26\n\tmovq\tr26, (r25)\n\ttlbia')
    enter('R1')
    p.e('\n'.join(L)); L.clear()
    p.eq('r1', '0xaaaa', 'control: the guest reads the first page')
    # the hypervisor resets the guest IN PLACE: rewrites the stage-2 entry, writes the guest's MMUCTL as 0 (it is 0), writes GTBR with the same value
    p.e('\tlea\ts2l0+80, r25\n\tmovq\t=(PHYS(0x40c000)|LEAF), r26\n\tmovq\tr26, (r25)')
    if write_mmuctl:
        p.e('\tmovq\t#0, r22\n\tmtsr\tmmuctl, r22')               # the one reset event the architecture has: MMUCTL written as 0 (it is 0: no change)
    if tlbigp:
        p.e('\tmovq\t=0x40a000, r22\n\ttlbigp\tr22')                # the invalidate by the guest-physical page of the entry that was rewritten
    p.e('\tmovq\t#0, r1')
    enter('R2')
    p.e('\n'.join(L)); L.clear()
    p.eq('r1', '0xcccc', 'after the reset in place the guest sees the new stage-2 page, not a cached translation of the old one')
    p.done()
    g9 = '\t.align\t8\ng9:\tmovq\t=0x40a000, r13\n\tmovq\t(r13), r1\n\thalt\n'
    body = pre + '\t.text\n' + p.text() + g9 + post
    if tlbigp:
        return ['TLBIGP after a stage-2 entry is rewritten (SEC-B26; errata 178): the hypervisor rewrites a stage-2 entry of a guest whose translation is off, invalidates the guest-physical page',
                'it changed with TLBIGP and enters the guest again: the guest must see the new page.  (The same program without the TLBIGP is SEC-B14: it finds the old page.)  QEMU hypervisor=on',
                'only.  Failed check n: exit n (200 and up).'], body
    if write_mmuctl:
        return ['A guest reset in place that writes MMUCTL as 0 (SEC-H01; best-of-breed-mmu-virt hole H1, errata 178): the hypervisor rewrites a stage-2 entry of a guest whose translation is already',
                'off, writes the guest\'s MMUCTL as 0 (no change of value) and enters the guest again: the guest must see the new page.  The rule of 6.8.4 only requires a discard when the bit changes;',
                'the model discards on every write, so this passes (a stricter implementation than the rule).  QEMU hypervisor=on only.  Failed check n: exit n (200 and up).'], body
    return ['A guest reset in place that does nothing but rewrite stage 2 and enter again (SEC-H02; best-of-breed-mmu-virt hole H1, errata 178): the hardware has no guest-reset event that',
            'discards the guest\'s cached translations (only a change of MMUCTL, the stage-2 root or its enable, a TLBIA or TLBI does), so a hypervisor that forgets the TLBIA leaves the guest',
            'a translation of the old page: the probe FINDS that.  QEMU hypervisor=on only.  Failed check n: exit n (200 and up).'], body


IOMMU_UP = r"""#include "iommu-lib.h"
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	call	lib_unit_up
	movq	#0, r30
	lea	ts_a, r1
	call	lib_tbl_clear
	lea	ts_a, r1
	lea	ts_a, r5
	call	lib_tbl_init
	movq	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
"""


def gen_dma_devspace():
    """SEC-D01: a device with a mapping onto another device's registers writes them (DMA into device space)"""
    t = IOMMU_UP
    t += r"""	; the kernel maps device address 0x1000 onto the page of the timer (a mistake, or a hostile guest's request through a virtual unit): the unit must not let the write reach the timer
	lea	ts_a, r1
	movq	#0x1000, r2
	movq	=(MAP_TIMER|RWL), r3
	call	lib_map
	movq	=MAP_TIMER, r13
	movq	#0, r6
	movq	r6, TIMER_REG_COMPARE(r13)
	movq	=DMATEST_MAP_BUFFER, r26
	add	r12, r26
	movq	=0x6b6c6d6e6f707172, r27
	movq	r27, (r26)
	movq	=(0x1000+TIMER_REG_COMPARE), r1
	movq	#8, r2
	call	lib_dma_w
	movq	TIMER_REG_COMPARE(r13), r6
	cbeq	r6, #0, 1f
	movq	#1, r0			; check 1: the DMA write reached the timer's compare register
	halt
1:	movq	#0, r0
	halt
	.text
#include "iommu-lib.inc"
"""
    return ['DMA into device space (SEC-D01; best-of-breed-iommu-irq-atomics hole H2 and the DMA class): a device whose table maps a device address onto the timer\'s page writes the timer\'s',
            'compare register through the unit.  The unit translates addresses and checks only R and W; nothing says that a DMA may not reach another device\'s window.  Failed check n: exit n.'], t


def gen_dma_nomap():
    """SEC-D02: a device with no entry (blocked unit) and a device whose mapping was removed reach nothing; no register or memory changes"""
    t = IOMMU_UP
    t += r"""	lea	ts_a, r1
	movq	#0x1000, r2
	lea	pgd, r3
	bis	#RWL, r3
	call	lib_map
	movq	#0x1010, r1
	lea	pgd, r2
	add	#0x10, r2
	movq	#9, r3
	call	lib_chk_ok_w		; control: the mapping works
	; the mapping is removed and the unit told: a stale translation must not be used
	lea	ts_a, r1
	movq	#0x1000, r2
	movq	#0, r3
	call	lib_map
	movq	=CMD(IOMMU_OP_INV_ALL, 0, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	lea	pgd, r4
	movq	#0, r6
	movq	r6, 0x10(r4)
	movq	=DMATEST_MAP_BUFFER, r26
	add	r12, r26
	movq	=0x6b6c6d6e6f707172, r27
	movq	r27, (r26)
	movq	#0x1010, r1
	movq	#8, r2
	call	lib_dma_w
	lea	pgd, r4
	movq	0x10(r4), r6
	cbeq	r6, #0, 1f
	movq	#1, r0			; check 1: the write reached the page after its mapping was removed and invalidated
	halt
1:	movq	#0, r0
	halt
	.data
	.align	4096
pgd:	.space	4096
	.text
#include "iommu-lib.inc"
"""
    return ['A device whose mapping was removed (SEC-D02; manual 2.11.7, errata 194): the mapping works (control, check 9 of the library); the entry is cleared, the unit is told (invalidate all),',
            'and the device writes again: nothing may reach the page.  Failed check n: exit n.'], t


def gen_kernel_sysregs():
    """SEC-U01: system-register numbers no register has, and writes of the read-only registers, from KERNEL mode on a machine with no hypervisor: the illegal-instruction exception, nothing read or written"""
    p = Prog(user=False)
    p.e(HEADER + '\t.text\n\t.globl\t_start\n_start:' + KVEC)
    for kind, tmpl in (('r', 'tmplr'), ('w', 'tmplw')):
        for num in ([2, 3, 12] if kind == 'w' else []) + [13, 14, 63, 127, 128, 129, 147, 148, 200, 255]:
            lab = 'p%s%d' % (kind, num)
            p.e('\tmovl\t%s, r2\n\tmovq\t=(%d<<16), r3\n\tbis\tr3, r2\n\tlea\tubuf, r4\n\tmovl\tr2, (r4)' % (tmpl, num))
            p.e('\tlea\tN%s, r13\n\tmovq\tcnt, r10\n\tmovq\t=0x5a5a5a5a5a5a, r1\n\tjmp\tr4' % lab)
            p.e('N%s:\tmovq\tcnt, r11\n\tsub\tr10, r11' % lab)
            p.eq('r11', '1', 'one exception for the patched %s of number %d' % ('mfsr' if kind == 'r' else 'mtsr', num))
            p.e('\tmovq\tlast_cause, r11')
            p.eq('r11', 'VECTOR_ILLEGAL', 'number %d is an illegal instruction' % num)
            p.e('\tlea\tubuf, r11\n\tmovq\tlast_epc, r12')
            p.chk('r12', 'r11', 'EPC of number %d is the instruction' % num)
            if kind == 'r':
                p.eq('r1', '0x5a5a5a5a5a5a', 'the destination register of the read of number %d is unchanged' % num)
    p.done()
    p.e('\t.align\t4\ntmplr:\tmfsr\tr1, ptbr\ntmplw:\tmtsr\tptbr, r1\n\t.align 4')
    return ['System-register numbers that no register has, and writes of the read-only registers (EVA, ECAUSE, CPUID), from KERNEL mode with no hypervisor strap (SEC-U01): each is the',
            'illegal-instruction exception (vector 2, EPC the instruction), the destination of a read unchanged.  The hypervisor numbers 128 to 147 are unassigned here.  Failed check n: exit n.'], \
        p.text() + KHANDLERS + KDATA


# name, generator, flags (sim64 flags of tests/sim; QEMU ignores -x), where: sim = tests/sim (runs on sim64 and on QEMU), qemu = tests/qemu (QEMU only)
TESTS = [
    ('sec-user-sysregs', gen_user_sysregs, '-K', 'sim'),
    ('sec-kernel-sysregs', gen_kernel_sysregs, '-K', 'sim'),
    ('sec-user-mtps', gen_user_mtps, '-K', 'sim'),
    ('sec-user-return', gen_user_return, '-K', 'sim'),
    ('sec-eva-stale', gen_eva_stale, '-K', 'sim'),
    ('sec-regs-carry', gen_regs_carry, '-K', 'sim'),
    ('sec-rtt-clear', gen_rtt_clear, '-K', 'sim'),
    ('sec-rti-same-mode', gen_rti_same_mode, '-K', 'sim'),
    ('sec-fpsr-carry', gen_fpsr_carry, '-K', 'sim'),
    ('sec-fpsr-gtbr', gen_fpsr_gtbr, '-H', 'sim'),
    ('sec-genter-regs', gen_genter_regs, '-H', 'sim'),
    ('sec-vec-bleed', gen_vec_bleed, '-K', 'sim'),
    ('sec-vec-clear-interrupt', gen_vec_hole_a, '-K', 'sim'),
    ('sec-vec-inplace', gen_vec_inplace, '-K -x 0x800000:0xa00000', 'sim'),
    ('sec-vec-stale-record', gen_vec_stale_record, '-K -x 0x800000:0xa00000', 'sim'),
    ('sec-restart-scalar', gen_restart_scalar, '-K -x 0x800000:0xa00000', 'sim'),
    ('sec-tlb-mode', gen_tlb_mode, None, 'qemu'),
    ('sec-dma-devspace', gen_dma_devspace, None, 'qemu'),
    ('sec-dma-revoked', gen_dma_nomap, None, 'qemu'),
    ('sec-hv-reset-mmuctl', lambda: gen_hv_reset_inplace(True), '-H', 'qemu'),
    ('sec-hv-reset-inplace', gen_hv_reset_inplace, '-H', 'qemu'),
    ('sec-hv-tlbigp', lambda: gen_hv_reset_inplace(False, True), '-H', 'qemu'),
]


# the probes that FIND a hole on the current implementation live in tests/sec-open (run by tools/check-sec.sh, which reports them and exits 0); every other probe is in tests/sim or
# tests/qemu and is run by tools/check-sim64.sh and tools/check-qemu.sh.  When an implementation stops having a hole its probe moves to tests/sim or tests/qemu (add it to FIXED below).
OPEN = {'sec-vec-clear-interrupt', 'sec-vec-inplace', 'sec-vec-stale-record', 'sec-hv-reset-inplace', 'sec-dma-devspace'}


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    if len(sys.argv) > 1:
        root = sys.argv[1]
    for name, fn, flags, kind in TESTS:
        hdr, body = fn()
        d = os.path.join(root, 'sec-open' if name in OPEN else '', kind) if name in OPEN else os.path.join(root, kind)
        os.makedirs(d, exist_ok=True)
        write(os.path.join(d, name + '.S'), hdr, body)
        if flags:
            open(os.path.join(d, name + '.flags'), 'w').write(flags + '\n')
        if name == 'sec-vec-bleed':
            open(os.path.join(d, name + '.strips'), 'w').write('16 32 64\n')
        if name.startswith('sec-dma'):
            open(os.path.join(d, name + '.qargs'), 'w').write('-device pdp64-dmatest,addr=2\n')


if __name__ == '__main__':
    main()

; Two user processes and a kernel that switches between them on the timer: the one thing the repository's kernels do not do (they have one process).  Written for the study of
; RTI #mask reuse (docs/encoding-work/bench-rti-mask-reuse.md) from tests/qemu/mini-kernel.S, same machine, same system call (trap #1 = write(r1 = buffer, r2 = length), trap #0 = exit(r0)).
; Each process has its own kernel stack; the timer handler saves the user's r1..r9 and the exception state on the current process's kernel stack (pushx, pushm), stores the kernel stack
; pointer in the process's block, loads the other's, and returns with popm, popx, rti: to the other process's user code (a return to user mode after a context switch) or, if that process was
; stopped inside a system call, to its kernel code (a return to the same mode).  A process that has not run yet is started by rti with fresh state.  The system call handler lowers the
; priority while it copies, so the timer can switch processes in the middle of a system call.
; Each process keeps a counter in r8 and a checksum in r9 across its system calls; at the end it checks the checksum and exits with 0, or with 1 if a register was lost.
#include "pdp64-consts.h"
USER_PAGES = 16
PERIOD = 1200				; timer ticks between interrupts
LIMIT = 300				; system calls per process
DEVVA = 0xC0000000
TIMER_VA = DEVVA + MAP_TIMER - MAP_DEV
CONSOLE_VA = DEVVA + MAP_CONSOLE - MAP_DEV
	.text
	.globl	_start
_start:
	; ---- page tables (translation is off: addresses are physical) ----
	lea	l2, r2
	movq	#(1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D), r3
	movq	r3, (r2)				; l2[0]: the first gigabyte maps itself, kernel only
	lea	l1a, r3
	bis	#(1<<PTE_V), r3
	movq	r3, 8(r2)				; l2[1] -> l1a (0x40000000: the user's region)
	movq	#(1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D), r3
	movq	r3, 16(r2)				; l2[2]: the user alias of the first gigabyte
	movq	=(MAP_DEV | 1<<PTE_V | 1<<PTE_R | 1<<PTE_W | 1<<PTE_A | 1<<PTE_D | MT_DEVICE<<PTE_MT), r3
	movq	r3, 24(r2)				; l2[3]: device space (physical bit 39 set, memory type device), kernel only
	lea	l1a, r2
	lea	l0a, r3
	bis	#(1<<PTE_V), r3
	movq	r3, (r2)				; l1a[0] -> l0a; its 16 entries start invalid
	lea	pool, r2
	movq	r2, nextpg
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	movq	#(1<<MMUCTL_ENABLE), r1
	mtsr	mmuctl, r1
	lea	pcb0, r1
	movq	r1, cur
	lea	kstkA_top, r1
	movq	r1, sp
	; ---- the timer ----
	movq	=TIMER_VA, r13
	movq	(r13), r2
	add	#PERIOD, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	; ---- to user mode: process A ----
	lea	userA, r1
	movq	=0x80000000, r2
	add	r2, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1		; priority 0: the timer can interrupt the user
	mtsr	epsw, r1
	rti

; ---- the handlers ----
h_exit:	halt					; exit(r0)
h_write:					; write(r1 = buffer, r2 = length); the entry has set the priority to 7
	pushx
	pushm	#0x3E				; r1..r5
	spl	#0
	stua
	movq	r2, r0
	movq	=CONSOLE_VA, r3
1:	cmp	r2, #0
	beq	3f
	movb	(r1)+, r4
2:	movq	CONSOLE_REG_TXCS(r3), r5
	and	#(1<<CONSOLE_CSR_READY), r5
	beq	2b
	movq	r4, CONSOLE_REG_TXDB(r3)
	sub	#1, r2
	br	1b
3:	clua
	spl	#7
	popm	#0x3E
	popx
	rti
h_pf:	movq	#99, r0				; no page fault is expected: stop
	halt
h_timer:					; level 6: count, set the next compare, and switch to the other process
	pushx
	pushm	#0x3FF				; r0..r9: the user's registers (or the kernel's, if a system call was interrupted)
	movq	=TIMER_VA, r1
	movq	TIMER_REG_COMPARE(r1), r2
	add	#PERIOD, r2
	movq	r2, TIMER_REG_COMPARE(r1)
	movq	ticks, r2
	add	#1, r2
	movq	r2, ticks
	movq	cur, r1				; the block of the process that was running
	movq	sp, (r1)			; its kernel stack pointer
	lea	pcb1, r2
	cbeq	r1, r2, 1f
	movq	r2, r1				; A was running: B is next
	br	2f
1:	lea	pcb0, r1			; B was running: A is next
2:	movq	r1, cur
	movq	(r1), r2
	cbeq	r2, #0, start_b			; B has never run
	movq	r2, sp				; the other process's kernel stack
	popm	#0x3FF
	popx
	rti
start_b:
	lea	kstkB_top, r2
	movq	r2, sp
	lea	userB, r1
	movq	=0x80000000, r2
	add	r2, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti

; ---- the user programs (at the alias address) ----
userA:	movq	#LIMIT, r8
	movq	#0, r9
1:	lea	bufA, r1
	movq	#1, r2
	trap	#1
	add	#3, r9
	sub	#1, r8
	bne	1b
	cmp	r9, #(3*LIMIT)
	bne	bad
	movq	#0, r0
	trap	#0
userB:	movq	#LIMIT, r8
	movq	#0, r9
1:	lea	bufB, r1
	movq	#1, r2
	trap	#1
	add	#5, r9
	sub	#1, r8
	bne	1b
	cmp	r9, #(5*LIMIT)
	bne	bad
	movq	#0, r0
	trap	#0
bad:	movq	#1, r0
	trap	#0

	.data
bufA:	.ascii	"a"
bufB:	.ascii	"b"
	.align	8
ticks:	.quad	0
nextpg:	.quad	0
cur:	.quad	0
pcb0:	.quad	0
pcb1:	.quad	0
	.align	8
	.space	1024
kstkA_top:
	.space	1024
kstkB_top:
	.data
	.align	8
vtab:
	.space	48
	.quad	h_pf
	.quad	h_pf
	.quad	h_pf
	.space	184
	.quad	h_timer
	.space	1784
	.quad	h_exit
	.quad	h_write
	.space	2032
	.align	4096
l2:	.space	4096
l1a:	.space	4096
l0a:	.space	4096
pool:	.space	65536

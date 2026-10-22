; A tiny kernel (the smoke test for the 32V port): it boots in kernel mode, builds page tables at run time and enables the MMU, installs a vector
; table, starts the timer, and enters user mode with rti.  The user program (running at the user alias of memory, a 1 GB U page at 0x80000000):
;   trap #1  write(r1 = buffer, r2 = length) to the console, trap #0 exit(r0).
;   a store to a page that is not mapped: the page fault handler maps a fresh page (demand paging), tlbi, and the retry succeeds.
;   it waits until the timer has ticked three times (the kernel's tick count is in a word the user can read).
; The system call and fault handlers save the exception state with pushx and restore it with popx, raise and lower the priority around it, and are
; therefore interruptible by the timer once they lower the priority (the entry sets it to 7).  The kernel shuts the machine down with halt (status r0).  Expected output is in mini-kernel.out.
#include "pdp64-consts.h"
USER_PAGES = 16				; the user's demand-paged region: 16 pages at 0x40000000
PERIOD = 200000				; timer ticks between interrupts (20 ms)
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
	; ---- the timer ----
	movq	#(MAP_TIMER), r13
	movq	(r13), r2
	add	#PERIOD, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	; ---- to user mode ----
	lea	ustk_top, r1
	movq	=0x80000000, r2
	add	r2, r1
	mtsr	usp, r1
	lea	user, r1
	add	r2, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1		; priority 0: the timer can interrupt the user
	mtsr	epsw, r1
	rti

; ---- the handlers ----
h_exit:	halt					; exit(r0)
h_write:					; write(r1 = buffer, r2 = length); the entry has set the priority to 7
	pushx					; EPSW and EPC on the kernel stack: after the spl #0 below the handler may be interrupted
	pushm	#0x3E				; r1..r5
	spl	#0
	movq	r2, r0
	movq	#(MAP_CONSOLE), r3
1:	cmp	r2, #0
	beq	3f
	movb	(r1)+, r4			; the user's byte: the kernel may read U pages
2:	movq	CONSOLE_REG_TXCS(r3), r5
	and	#(1<<CONSOLE_CSR_READY), r5
	beq	2b
	movq	r4, CONSOLE_REG_TXDB(r3)
	sub	#1, r2
	br	1b
3:	spl	#7
	popm	#0x3E
	popx
	rti
h_pf:						; a page fault: the user's region maps a fresh page; anything else ends the machine
	pushx
	pushm	#0x0E				; r1..r3
	spl	#0
	mfsr	r1, eva
	movq	#(0x40000000), r2
	sub	r2, r1
	shr	#12, r1
	cmp	r1, #USER_PAGES
	bhis	kill
	shl	#3, r1
	lea	l0a, r2
	add	r2, r1				; the address of the page-table entry
	movq	nextpg, r2
	movq	r2, r3
	bis	#(1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_A|1<<PTE_D), r3
	movq	r3, (r1)
	add	#4096, r2
	movq	r2, nextpg
	mfsr	r1, eva
	tlbi	r1
	spl	#7
	popm	#0x0E
	popx
	rti
kill:	movq	#99, r0
	halt
h_timer:					; level 6: counts a tick and sets the next compare.  EPC and EPSW are not touched by anything that can interrupt it (it runs at priority 6).
	pushm	#0x06				; r1, r2
	movq	#(MAP_TIMER), r1
	movq	TIMER_REG_COMPARE(r1), r2
	add	#PERIOD, r2
	movq	r2, TIMER_REG_COMPARE(r1)
	movq	ticks, r2
	add	#1, r2
	movq	r2, ticks
	popm	#0x06
	rti

; ---- the user program (at the alias address) ----
user:
	lea	msg1, r1
	movq	#(msg1_end - msg1), r2
	trap	#1
	; demand paging: this page is not mapped; the store faults, the kernel maps a page, the store is retried
	movq	=0x40003000, r3
	movq	#0x42, r5
	movq	r5, (r3)
	movq	(r3), r6
	cmp	r6, #0x42
	bne	bad
	lea	msg2, r1
	movq	#(msg2_end - msg2), r2
	trap	#1
	; wait for three ticks of the timer (the kernel's counter is a word in memory)
1:	movq	ticks, r4
	cmp	r4, #3
	blo	1b
	lea	msg3, r1
	movq	#(msg3_end - msg3), r2
	trap	#1
	movq	#0, r0
	trap	#0
bad:	movq	#1, r0
	trap	#0

	.data
msg1:	.ascii	"hello from user mode\n"
msg1_end:
msg2:	.ascii	"page fault handled\n"
msg2_end:
msg3:	.ascii	"timer ticked\n"
msg3_end:
	.align	8
ticks:	.quad	0
nextpg:	.quad	0
	.align	8
ustk:	.space	512
ustk_top:
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

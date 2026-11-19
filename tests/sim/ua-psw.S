; the user-access guard bit UA (status word bit 12), STUA and CLUA (errata 43, 190; manual 6.10.1, 6.13.7), on the kernel-mode machine (sim64 -K, which has no MMU:
; the effect of UA on an access is tested on QEMU, tests/qemu/mmu-ua.S).  Reset: UA clear.  STUA sets it and CLUA clears it, no other bit changes; MTPS writes it from
; kernel mode; exception entry clears it in the new status word and EPSW keeps the old value; RTI restores it; both instructions are privileged.
#include "pdp64-consts.h"
#define UA (1<<PSW_UA)
#define KBASE (MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE)		; reset: UA clear, nothing else changed
	bne	F1
	stua
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE|UA)		; STUA sets UA and only UA
	bne	F2
	stua
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE|UA)		; and again
	bne	F3
	clua
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE)		; CLUA clears it
	bne	F4
	clua
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE)
	bne	F5
	movq	#(KBASE|UA), r1		; MTPS writes UA from kernel mode
	mtps	r1
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE|UA)
	bne	F6
	movq	#(KBASE), r1
	mtps	r1
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE)
	bne	F7
	movq	#0, r8
	movq	#0, r9
	stua
	trap	#1			; entry: the handler sees UA clear, EPSW holds UA set, and RTI brings it back
	mfps	r5
	bic	#15, r5
	cmp	r5, #(KBASE|UA)
	bne	F8
	bic	#15, r8
	cmp	r8, #(KBASE|UA)
	bne	F9
	cmp	r9, #(KBASE)
	bne	F10
	clua
	movq	#0, r8
	movq	#0, r9
	trap	#1			; with UA clear at the entry EPSW holds it clear
	bic	#15, r8
	cmp	r8, #(KBASE)
	bne	F11
	stua
	lea	user, r1		; into user mode with UA set in EPSW: user mode does not change it and cannot write it
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE|UA), r1
	mtsr	epsw, r1
	movq	#0, r10
	lea	ustack_top, r1
	mtsr	usp, r1
	rti
user:
	lea	pr0, r4
pi0:
	stua
pr0:
	cmp	r10, #1
	bne	F12
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F13
	lea	pi0, r11
	cmp	r6, r11
	bne	F14
	lea	pr1, r4
pi1:
	clua
pr1:
	cmp	r10, #2
	bne	F15
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F16
	lea	pi1, r11
	cmp	r6, r11
	bne	F17
	movq	#(MODE_USER<<PSW_MODE|UA), r1	; MTPS in user mode writes the flags only
	mtps	r1
	mfps	r5
	bic	#15, r5
	cmp	r5, #(MODE_USER<<PSW_MODE|UA)	; the user-mode MTPS changed nothing, UA as it was
	bne	F18
	trap	#0
F1:	movq	#1, r0
	trap	#2
F2:	movq	#2, r0
	trap	#2
F3:	movq	#3, r0
	trap	#2
F4:	movq	#4, r0
	trap	#2
F5:	movq	#5, r0
	trap	#2
F6:	movq	#6, r0
	trap	#2
F7:	movq	#7, r0
	trap	#2
F8:	movq	#8, r0
	trap	#2
F9:	movq	#9, r0
	trap	#2
F10:	movq	#10, r0
	trap	#2
F11:	movq	#11, r0
	trap	#2
F12:	movq	#12, r0
	trap	#2
F13:	movq	#13, r0
	trap	#2
F14:	movq	#14, r0
	trap	#2
F15:	movq	#15, r0
	trap	#2
F16:	movq	#16, r0
	trap	#2
F17:	movq	#17, r0
	trap	#2
F18:	movq	#18, r0
	trap	#2
h_priv:	mfsr	r6, epc
	mfsr	r8, ecause
	add	#1, r10
	mtsr	epc, r4
	rti
h_trap1: mfsr	r8, epsw
	mfps	r9
	bic	#15, r9
	rti
h_ok:	movq	#0, r0
h_fail:	halt
	.data
	.align	8
vtab:
	.space	24
	.quad	h_priv
	.space	2016
	.quad	h_ok
	.quad	h_trap1
	.quad	h_fail
	.space	2000
	.align	8
ustack:	.space	256
ustack_top:

; System v1: mfps, mtps, spl and the PSW fields in kernel mode; the reserved bits; spl #8 is illegal; mtps from the kernel can enter user mode. A failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	#0, r10
	mfps	r1
	cbne r1, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F1 ; check 1
	mov	#(3<<PSW_PRI|0xA), r1
	mtps	r1
	mfps	r5
	cbne r5, #(3<<PSW_PRI|MODE_KERNEL<<PSW_PREV), F6 ; check 6
	mov	#(3<<PSW_PRI|0xA), r1
	mtps	r1
	spl	#2
	mfps	r5
	cbne r5, #(2<<PSW_PRI|MODE_KERNEL<<PSW_PREV), F7 ; check 7
	mov	#(2<<PSW_PRI|0xF), r1	; the four low bits are reserved: they read as zero
	mtps	r1
	mfps	r5
	cbne r5, #(2<<PSW_PRI|MODE_KERNEL<<PSW_PREV), F8 ; check 8
	mov	#0xF000, r1
	mtps	r1
	mfps	r5
	cbne r5, #0, F9 ; check 9
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	lea	r1x, r4
sp8:
	spl	#8
r1x:
	cbne r10, #(1), F10 ; check 10
	lea	sp8, r11
	cbne r6, r11, F11 ; check 11
	cbne r8, #(VECTOR_ILLEGAL), F12 ; check 12
	lea	ustack_top, r1
	mtsr	usp, r1
	mov	#(MODE_USER<<PSW_MODE|MODE_USER<<PSW_PREV), r1
	lea	user, r2
	mov	sp, ksp
	mtps	r1
user:
	mfps	r5
	cbne r5, #(MODE_USER<<PSW_MODE|MODE_USER<<PSW_PREV), F13 ; check 13
	lea	ustack_top, r11
	cbne sp, r11, F14 ; check 14
	trap	#9
F1:	mov	#1, r0
	halt
F2:	mov	#2, r0
	halt
F3:	mov	#3, r0
	halt
F4:	mov	#4, r0
	halt
F5:	mov	#5, r0
	halt
F6:	mov	#6, r0
	halt
F7:	mov	#7, r0
	halt
F8:	mov	#8, r0
	halt
F9:	mov	#9, r0
	halt
F10:	mov	#10, r0
	halt
F11:	mov	#11, r0
	halt
F12:	mov	#12, r0
	halt
F13:	mov	#13, r0
	halt
F14:	mov	#14, r0
	halt
h_gen:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	add	#1, r10
	cbeq	r4, #0, 1f
	mtsr	epc, r4
1:	rti	#RTIMASK_ALL
h_end:	mov	sp, r1
	mov	ksp, r2
	cbne r1, r2, 2f
	mfsr	r1, epsw
	cbne r1, #(MODE_USER<<PSW_MODE|MODE_USER<<PSW_PREV), 2f
	mov	#0, r0
	halt
2:	mov	#99, r0
	halt
	.data
	.align	8
vtab:
	.space	16
	.quad	h_gen
	.space	2096
	.quad	h_end
	.space	1968
	.align 8
ksp:	.quad 0
	.space 256
ustack_top:


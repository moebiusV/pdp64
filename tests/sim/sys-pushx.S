; System v1, pushx and popx (errata 37): EPSW and EPC on the stack of the current mode; SP moves by 16 and is untouched by an abort; no flags; the refusals. Generated; a failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	stk_top, sp
	movq	sp, r13
	movq	#0x1234, r1
	mtsr	epc, r1
	movq	#0xFFFF, r1
	mtsr	epsw, r1
	pushx
	sub	sp, r13
	movq	r13, r5
	cmp	r5, #(16)
	bne	F1	; check 1
	movq	0(sp), r5
	cmp	r5, #((1<<PSW_C|1<<PSW_V|1<<PSW_Z|1<<PSW_N)|1<<PSW_T|7<<PSW_PRI|3<<PSW_MODE|3<<PSW_PREV)
	bne	F2	; check 2
	movq	8(sp), r5
	cmp	r5, #(4660)
	bne	F3	; check 3
	movq	#0, r1
	mtsr	epc, r1
	mtsr	epsw, r1
	movq	#-1, r1
	movq	r1, 0(sp)
	movq	#0x5678, r1
	movq	r1, 8(sp)
	popx
	mfsr	r5, epc
	cmp	r5, #(22136)
	bne	F4	; check 4
	mfsr	r5, epsw
	cmp	r5, #((1<<PSW_C|1<<PSW_V|1<<PSW_Z|1<<PSW_N)|1<<PSW_T|7<<PSW_PRI|3<<PSW_MODE|3<<PSW_PREV)
	bne	F5	; check 5
	lea	stk_top, r1
	cmp	sp, r1
	beq	1f
	br	F6
1:
	cmp	r1, r1
	pushx
	popx
	beq	1f
	br	F7
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	stk_top, sp
	add	#4, sp
	movq	sp, r13
	lea	r1x, r4
mis:
	pushx
r1x:
	cmp	r10, #(1)
	bne	F8	; check 8
	lea	mis, r11
	cmp	r6, r11
	bne	F9	; check 9
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F10	; check 10
	cmp	sp, r13
	bne	F11	; check 11
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	r2x, r4
mis2:
	popx
r2x:
	cmp	r10, #(1)
	bne	F12	; check 12
	lea	mis2, r11
	cmp	r6, r11
	bne	F13	; check 13
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F14	; check 14
	cmp	sp, r13
	bne	F15	; check 15
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=MAP_DEV_END, sp
	lea	r3x, r4
un:
	pushx
r3x:
	cmp	r10, #(1)
	bne	F16	; check 16
	lea	un, r11
	cmp	r6, r11
	bne	F17	; check 17
	cmp	r8, #(VECTOR_BUSFAULT)
	bne	F18	; check 18
	movq	=MAP_DEV_END, r2
	cmp	sp, r2
	bne	F19	; check 19
	lea	stk_top, sp
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	bad0x, r4
bad0:
	.word	0x540f, 0x0400
bad0x:
	cmp	r10, #(1)
	bne	F20	; check 20
	lea	bad0, r11
	cmp	r6, r11
	bne	F21	; check 21
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F22	; check 22
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	bad1x, r4
bad1:
	.word	0x540f, 0x0001
bad1x:
	cmp	r10, #(1)
	bne	F23	; check 23
	lea	bad1, r11
	cmp	r6, r11
	bne	F24	; check 24
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F25	; check 25
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	bad2x, r4
bad2:
	.word	0xea01
bad2x:
	cmp	r10, #(1)
	bne	F26	; check 26
	lea	bad2, r11
	cmp	r6, r11
	bne	F27	; check 27
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F28	; check 28
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	bad3x, r4
bad3:
	.word	0xeb10
bad3x:
	cmp	r10, #(1)
	bne	F29	; check 29
	lea	bad3, r11
	cmp	r6, r11
	bne	F30	; check 30
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F31	; check 31
	movq	#0, r0
	halt
F1:	movq	#1, r0
	halt
F2:	movq	#2, r0
	halt
F3:	movq	#3, r0
	halt
F4:	movq	#4, r0
	halt
F5:	movq	#5, r0
	halt
F6:	movq	#6, r0
	halt
F7:	movq	#7, r0
	halt
F8:	movq	#8, r0
	halt
F9:	movq	#9, r0
	halt
F10:	movq	#10, r0
	halt
F11:	movq	#11, r0
	halt
F12:	movq	#12, r0
	halt
F13:	movq	#13, r0
	halt
F14:	movq	#14, r0
	halt
F15:	movq	#15, r0
	halt
F16:	movq	#16, r0
	halt
F17:	movq	#17, r0
	halt
F18:	movq	#18, r0
	halt
F19:	movq	#19, r0
	halt
F20:	movq	#20, r0
	halt
F21:	movq	#21, r0
	halt
F22:	movq	#22, r0
	halt
F23:	movq	#23, r0
	halt
F24:	movq	#24, r0
	halt
F25:	movq	#25, r0
	halt
F26:	movq	#26, r0
	halt
F27:	movq	#27, r0
	halt
F28:	movq	#28, r0
	halt
F29:	movq	#29, r0
	halt
F30:	movq	#30, r0
	halt
F31:	movq	#31, r0
	halt
h_gen:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	mfsr	r9, eva
	add	#1, r10
	cbeq	r4, #0, 1f
	mtsr	epc, r4
1:	rti

	.data
	.align	8
vtab:
	.space	16
	.quad	h_gen
	.space	8
	.quad	h_gen
	.space	64
	.quad	h_gen
	.space	3984
	.align 8
	.space 256
stk_top:
	.space 64


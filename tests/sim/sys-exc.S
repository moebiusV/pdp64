; System v1 exceptions in kernel mode (sim64 -K): illegal instruction, divide by zero, misaligned and unmapped access, bpt, trap, trapl, the reserved mode, a nested exception.
; Each handler records EPC (r6), EPSW (r7), ECAUSE (r8), EVA (r9) and the PSW inside (r12); a failed check n halts with status n.  Generated; the checks are worked out from section 15.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res1, r4
	cmp	r1, r1
ill1:
	.word	0x540d, 0x0011
res1:
	bne	FZ
	cmp	r10, #(1)
	bne	F1	; check 1
	lea	ill1, r11
	cmp	r6, r11
	bne	F2	; check 2
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)|1<<PSW_Z)
	bne	F3	; check 3
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F4	; check 4
	cmp	r9, #(0)
	bne	F5	; check 5
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F6	; check 6
	br	2f
FZ:	movq	#90, r0
	halt
2:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#5, r1
	movq	#0, r2
	movq	#77, r3
	lea	res2, r4
dz:
	div	r1, r2, r3
res2:
	cmp	r10, #(1)
	bne	F7	; check 7
	lea	dz, r11
	cmp	r6, r11
	bne	F8	; check 8
	cmp	r8, #(VECTOR_DIVZERO)
	bne	F9	; check 9
	cmp	r3, #(77)
	bne	F10	; check 10
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#1, r3
	movq	#99, r5
	lea	resm0, r4
mis0:
	movq	(r3), r5
resm0:
	cmp	r10, #(1)
	bne	F11	; check 11
	lea	mis0, r11
	cmp	r6, r11
	bne	F12	; check 12
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F13	; check 13
	cmp	r9, #(1)
	bne	F14	; check 14
	cmp	r3, #(1)
	bne	F15	; check 15
	cmp	r5, #(99)
	bne	F16	; check 16
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#3, r3
	movq	#99, r5
	lea	resm1, r4
mis1:
	movq	(r3)+, r5
resm1:
	cmp	r10, #(1)
	bne	F17	; check 17
	lea	mis1, r11
	cmp	r6, r11
	bne	F18	; check 18
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F19	; check 19
	cmp	r9, #(3)
	bne	F20	; check 20
	cmp	r3, #(3)
	bne	F21	; check 21
	cmp	r5, #(99)
	bne	F22	; check 22
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#11, r3
	movq	#99, r5
	lea	resm2, r4
mis2:
	movq	-(r3), r5
resm2:
	cmp	r10, #(1)
	bne	F23	; check 23
	lea	mis2, r11
	cmp	r6, r11
	bne	F24	; check 24
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F25	; check 25
	cmp	r9, #(3)
	bne	F26	; check 26
	cmp	r3, #(11)
	bne	F27	; check 27
	cmp	r5, #(99)
	bne	F28	; check 28
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#5, r3
	movq	#99, r5
	lea	resm3, r4
mis3:
	movq	r5, (r3)+
resm3:
	cmp	r10, #(1)
	bne	F29	; check 29
	lea	mis3, r11
	cmp	r6, r11
	bne	F30	; check 30
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F31	; check 31
	cmp	r9, #(5)
	bne	F32	; check 32
	cmp	r3, #(5)
	bne	F33	; check 33
	cmp	r5, #(99)
	bne	F34	; check 34
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#13, r3
	movq	#99, r5
	lea	resm4, r4
mis4:
	movq	r5, -(r3)
resm4:
	cmp	r10, #(1)
	bne	F35	; check 35
	lea	mis4, r11
	cmp	r6, r11
	bne	F36	; check 36
	cmp	r8, #(VECTOR_MISALIGNED)
	bne	F37	; check 37
	cmp	r9, #(5)
	bne	F38	; check 38
	cmp	r3, #(13)
	bne	F39	; check 39
	cmp	r5, #(99)
	bne	F40	; check 40
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#(MAP_DEV_END), r3
	lea	res4, r4
un:
	movq	(r3), r5
res4:
	cmp	r10, #(1)
	bne	F41	; check 41
	lea	un, r11
	cmp	r6, r11
	bne	F42	; check 42
	cmp	r8, #(VECTOR_BUSFAULT)
	bne	F43	; check 43
	cmp	r9, #(MAP_DEV_END)
	bne	F44	; check 44
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r4
	bpt
afterbpt:
	cmp	r10, #(1)
	bne	F45	; check 45
	lea	afterbpt, r11
	cmp	r6, r11
	bne	F46	; check 46
	cmp	r8, #(VECTOR_BPT)
	bne	F47	; check 47
	bic	#15, r7
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F48	; check 48
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#3
aftertrap:
	cmp	r10, #(1)
	bne	F49	; check 49
	lea	aftertrap, r11
	cmp	r6, r11
	bne	F50	; check 50
	cmp	r8, #(VECTOR_TRAP_BASE+3)
	bne	F51	; check 51
	cmp	r9, #(0)
	bne	F52	; check 52
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#200
aftertrapl:
	cmp	r10, #(1)
	bne	F53	; check 53
	lea	aftertrapl, r11
	cmp	r6, r11
	bne	F54	; check 54
	cmp	r8, #(VECTOR_TRAP_BASE+200)
	bne	F55	; check 55
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#15
afterfifteen:
	cmp	r10, #(1)
	bne	F56	; check 56
	cmp	r8, #(VECTOR_TRAP_BASE+15)
	bne	F57	; check 57
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#(2<<PSW_MODE), r1
	lea	res6, r4
badmtps:
	mtps	r1
res6:
	cmp	r10, #(1)
	bne	F58	; check 58
	lea	badmtps, r11
	cmp	r6, r11
	bne	F59	; check 59
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F60	; check 60
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	mtsr	epsw, r1
	lea	res7, r4
	lea	res7, r2
	mtsr	epc, r2
badrti:
	rti
res7:
	cmp	r10, #(1)
	bne	F61	; check 61
	lea	badrti, r11
	cmp	r6, r11
	bne	F62	; check 62
	cmp	r8, #(VECTOR_ILLEGAL)
	bne	F63	; check 63
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#4
afternest:
	lea	afternest, r11
	cmp	r6, r11
	bne	F64	; check 64
	lea	inner_after, r11
	cmp	r7, r11
	bne	F65	; check 65
	lea	inner_after, r11
	cmp	r9, r11
	bne	F66	; check 66
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
F32:	movq	#32, r0
	halt
F33:	movq	#33, r0
	halt
F34:	movq	#34, r0
	halt
F35:	movq	#35, r0
	halt
F36:	movq	#36, r0
	halt
F37:	movq	#37, r0
	halt
F38:	movq	#38, r0
	halt
F39:	movq	#39, r0
	halt
F40:	movq	#40, r0
	halt
F41:	movq	#41, r0
	halt
F42:	movq	#42, r0
	halt
F43:	movq	#43, r0
	halt
F44:	movq	#44, r0
	halt
F45:	movq	#45, r0
	halt
F46:	movq	#46, r0
	halt
F47:	movq	#47, r0
	halt
F48:	movq	#48, r0
	halt
F49:	movq	#49, r0
	halt
F50:	movq	#50, r0
	halt
F51:	movq	#51, r0
	halt
F52:	movq	#52, r0
	halt
F53:	movq	#53, r0
	halt
F54:	movq	#54, r0
	halt
F55:	movq	#55, r0
	halt
F56:	movq	#56, r0
	halt
F57:	movq	#57, r0
	halt
F58:	movq	#58, r0
	halt
F59:	movq	#59, r0
	halt
F60:	movq	#60, r0
	halt
F61:	movq	#61, r0
	halt
F62:	movq	#62, r0
	halt
F63:	movq	#63, r0
	halt
F64:	movq	#64, r0
	halt
F65:	movq	#65, r0
	halt
F66:	movq	#66, r0
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

h_nest:	cbne	r10, #0, nested
	add	#1, r10
	mfsr	r6, epc
	trap	#5
inner_after:
	mfsr	r7, epc
	mtsr	epc, r6
	rti
nested:	mfsr	r9, epc
	rti
	.data
	.align	8
vtab:
	.space	16
	.quad	h_gen
	.space	8
	.quad	h_gen
	.space	56
	.quad	h_gen
	.quad	h_gen
	.space	8
	.quad	h_gen
	.space	1944
	.quad	h_gen
	.quad	h_nest
	.quad	h_nest
	.space	72
	.quad	h_gen
	.space	1472
	.quad	h_gen
	.space	440


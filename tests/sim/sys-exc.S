; System v1 exceptions in kernel mode (sim64 -K): illegal instruction, divide by zero, unmapped access (low addresses, which no longer fault as misaligned: a plain access works at any address), bpt, trap (a small and a large vector number), the reserved mode, a nested exception.
; Each handler records EPC (r6), EPSW (r7), ECAUSE (r8), EVA (r9) and the PSW inside (r12); a failed check n halts with status n.  Generated; the checks are worked out from section 15.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res1, r4
ill1:
	.word	0xffff		; an illegal instruction (no leaf has this first parcel)
res1:
	cbne r10, $(1), F1 ; check 1
	lea	ill1, r11
	cbne r6, r11, F2 ; check 2
	cbne r7, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F3 ; check 3
	cbne r8, $(VECTOR_ILLEGAL), F4 ; check 4
	cbne r9, $(0), F5 ; check 5
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F6 ; check 6
		mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$5, r1
	mov	$0, r2
	mov	$77, r3
	lea	res2, r4
dz:
	div	r1, r2, r3
res2:
	cbne r10, $(1), F7 ; check 7
	lea	dz, r11
	cbne r6, r11, F8 ; check 8
	cbne r8, $(VECTOR_DIVZERO), F9 ; check 9
	cbne r3, $(77), F10 ; check 10
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=(MAP_DEV_END+1), r3
	mov	$99, r5
	lea	resm0, r4
mis0:
	mov	(r3), r5
resm0:
	cbne r10, $(1), F11 ; check 11
	lea	mis0, r11
	cbne r6, r11, F12 ; check 12
	cbne r8, $(VECTOR_BUSFAULT), F13 ; check 13
	mov	=(MAP_DEV_END+1), r2
	cbne r9, r2, F14 ; check 14
	mov	=(MAP_DEV_END+1), r2
	cbne r3, r2, F15 ; check 15
	cbne r5, $(99), F16 ; check 16
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=(MAP_DEV_END+3), r3
	mov	$99, r5
	lea	resm1, r4
mis1:
	mov	(r3)+, r5
resm1:
	cbne r10, $(1), F17 ; check 17
	lea	mis1, r11
	cbne r6, r11, F18 ; check 18
	cbne r8, $(VECTOR_BUSFAULT), F19 ; check 19
	mov	=(MAP_DEV_END+3), r2
	cbne r9, r2, F20 ; check 20
	mov	=(MAP_DEV_END+3), r2
	cbne r3, r2, F21 ; check 21
	cbne r5, $(99), F22 ; check 22
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=(MAP_DEV_END+11), r3
	mov	$99, r5
	lea	resm2, r4
mis2:
	mov	-(r3), r5
resm2:
	cbne r10, $(1), F23 ; check 23
	lea	mis2, r11
	cbne r6, r11, F24 ; check 24
	cbne r8, $(VECTOR_BUSFAULT), F25 ; check 25
	mov	=(MAP_DEV_END+3), r2
	cbne r9, r2, F26 ; check 26
	mov	=(MAP_DEV_END+11), r2
	cbne r3, r2, F27 ; check 27
	cbne r5, $(99), F28 ; check 28
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=(MAP_DEV_END+5), r3
	mov	$99, r5
	lea	resm3, r4
mis3:
	mov	r5, (r3)+
resm3:
	cbne r10, $(1), F29 ; check 29
	lea	mis3, r11
	cbne r6, r11, F30 ; check 30
	cbne r8, $(VECTOR_BUSFAULT), F31 ; check 31
	mov	=(MAP_DEV_END+5), r2
	cbne r9, r2, F32 ; check 32
	mov	=(MAP_DEV_END+5), r2
	cbne r3, r2, F33 ; check 33
	cbne r5, $(99), F34 ; check 34
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=(MAP_DEV_END+13), r3
	mov	$99, r5
	lea	resm4, r4
mis4:
	mov	r5, -(r3)
resm4:
	cbne r10, $(1), F35 ; check 35
	lea	mis4, r11
	cbne r6, r11, F36 ; check 36
	cbne r8, $(VECTOR_BUSFAULT), F37 ; check 37
	mov	=(MAP_DEV_END+5), r2
	cbne r9, r2, F38 ; check 38
	mov	=(MAP_DEV_END+13), r2
	cbne r3, r2, F39 ; check 39
	cbne r5, $(99), F40 ; check 40
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=MAP_DEV_END, r3
	lea	res4, r4
un:
	mov	(r3), r5
res4:
	cbne r10, $(1), F41 ; check 41
	lea	un, r11
	cbne r6, r11, F42 ; check 42
	cbne r8, $(VECTOR_BUSFAULT), F43 ; check 43
	mov	=MAP_DEV_END, r2
	cbne r9, r2, F44 ; check 44
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r4
	bpt
afterbpt:
	cbne r10, $(1), F45 ; check 45
	lea	afterbpt, r11
	cbne r6, r11, F46 ; check 46
	cbne r8, $(VECTOR_BPT), F47 ; check 47
	cbne r7, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F48 ; check 48
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	trap	$3
aftertrap:
	cbne r10, $(1), F49 ; check 49
	lea	aftertrap, r11
	cbne r6, r11, F50 ; check 50
	cbne r8, $(VECTOR_TRAP_BASE+3), F51 ; check 51
	cbne r9, $(0), F52 ; check 52
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	trap	$200
aftertrap200:
	cbne r10, $(1), F53 ; check 53
	lea	aftertrap200, r11
	cbne r6, r11, F54 ; check 54
	cbne r8, $(VECTOR_TRAP_BASE+200), F55 ; check 55
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	trap	$15
afterfifteen:
	cbne r10, $(1), F56 ; check 56
	cbne r8, $(VECTOR_TRAP_BASE+15), F57 ; check 57
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$(2<<PSW_MODE), r1
	lea	res6, r4
badmtps:
	mtps	r1
res6:
	cbne r10, $(1), F58 ; check 58
	lea	badmtps, r11
	cbne r6, r11, F59 ; check 59
	cbne r8, $(VECTOR_ILLEGAL), F60 ; check 60
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mtsr	epsw, r1
	lea	res7, r4
	lea	res7, r2
	mtsr	epc, r2
badrti:
	rti	$RTIMASK_ALL
res7:
	cbne r10, $(1), F61 ; check 61
	lea	badrti, r11
	cbne r6, r11, F62 ; check 62
	cbne r8, $(VECTOR_ILLEGAL), F63 ; check 63
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	trap	$4
afternest:
	lea	afternest, r11
	cbne r6, r11, F64 ; check 64
	lea	inner_after, r11
	cbne r7, r11, F65 ; check 65
	lea	inner_after, r11
	cbne r9, r11, F66 ; check 66
	mov	$0, r0
	halt
F1:	mov	$1, r0
	halt
F2:	mov	$2, r0
	halt
F3:	mov	$3, r0
	halt
F4:	mov	$4, r0
	halt
F5:	mov	$5, r0
	halt
F6:	mov	$6, r0
	halt
F7:	mov	$7, r0
	halt
F8:	mov	$8, r0
	halt
F9:	mov	$9, r0
	halt
F10:	mov	$10, r0
	halt
F11:	mov	$11, r0
	halt
F12:	mov	$12, r0
	halt
F13:	mov	$13, r0
	halt
F14:	mov	$14, r0
	halt
F15:	mov	$15, r0
	halt
F16:	mov	$16, r0
	halt
F17:	mov	$17, r0
	halt
F18:	mov	$18, r0
	halt
F19:	mov	$19, r0
	halt
F20:	mov	$20, r0
	halt
F21:	mov	$21, r0
	halt
F22:	mov	$22, r0
	halt
F23:	mov	$23, r0
	halt
F24:	mov	$24, r0
	halt
F25:	mov	$25, r0
	halt
F26:	mov	$26, r0
	halt
F27:	mov	$27, r0
	halt
F28:	mov	$28, r0
	halt
F29:	mov	$29, r0
	halt
F30:	mov	$30, r0
	halt
F31:	mov	$31, r0
	halt
F32:	mov	$32, r0
	halt
F33:	mov	$33, r0
	halt
F34:	mov	$34, r0
	halt
F35:	mov	$35, r0
	halt
F36:	mov	$36, r0
	halt
F37:	mov	$37, r0
	halt
F38:	mov	$38, r0
	halt
F39:	mov	$39, r0
	halt
F40:	mov	$40, r0
	halt
F41:	mov	$41, r0
	halt
F42:	mov	$42, r0
	halt
F43:	mov	$43, r0
	halt
F44:	mov	$44, r0
	halt
F45:	mov	$45, r0
	halt
F46:	mov	$46, r0
	halt
F47:	mov	$47, r0
	halt
F48:	mov	$48, r0
	halt
F49:	mov	$49, r0
	halt
F50:	mov	$50, r0
	halt
F51:	mov	$51, r0
	halt
F52:	mov	$52, r0
	halt
F53:	mov	$53, r0
	halt
F54:	mov	$54, r0
	halt
F55:	mov	$55, r0
	halt
F56:	mov	$56, r0
	halt
F57:	mov	$57, r0
	halt
F58:	mov	$58, r0
	halt
F59:	mov	$59, r0
	halt
F60:	mov	$60, r0
	halt
F61:	mov	$61, r0
	halt
F62:	mov	$62, r0
	halt
F63:	mov	$63, r0
	halt
F64:	mov	$64, r0
	halt
F65:	mov	$65, r0
	halt
F66:	mov	$66, r0
	halt
h_gen:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	mfsr	r9, eva
	add	$1, r10
	cbeq	r4, $0, 1f
	mtsr	epc, r4
1:	rti	$RTIMASK_ALL

h_nest:	cbne	r10, $0, nested
	add	$1, r10
	mfsr	r6, epc
	trap	$5
inner_after:
	mfsr	r7, epc
	mtsr	epc, r6
	rti	$RTIMASK_ALL
nested:	mfsr	r9, epc
	rti	$RTIMASK_ALL
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


; System v1 system registers epsw, vbr, mmuctl, asid, cpuid (kernel mode, sim64 -k or the QEMU machine with kernel=on): widths and reserved bits. Generated; a failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	movq	#0xFFFF, r1
	mtsr	epsw, r1
	mfsr	r2, epsw
	cmp	r2, #((1<<PSW_C|1<<PSW_V|1<<PSW_Z|1<<PSW_N)|1<<PSW_T|7<<PSW_PRI|3<<PSW_MODE|3<<PSW_PREV)
	bne	F1	; check 1
	movq	#-1, r1
	shl	#9, r1
	bis	#77, r1
	mtsr	vbr, r1
	mfsr	r2, vbr
	cmp	r2, r1
	bne	F2
	movq	#0x12345, r1
	mtsr	asid, r1
	mfsr	r2, asid
	cmp	r2, #(9029)
	bne	F3	; check 3
	movq	#0x2, r1
	mtsr	mmuctl, r1
	mfsr	r2, mmuctl
	cmp	r2, #(0)
	bne	F4	; check 4
	mfsr	r2, cpuid
	cmp	r2, #(0)
	bne	F5	; check 5
	movq	#5, r1
	mtsr	epsw, r1
	mfsr	r2, vbr
	cmp	r2, #77
	bne	1f
	br	F6
1:
	mfsr	r2, epsw
	cmp	r2, #(5)
	bne	F7	; check 7
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

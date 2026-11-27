; System v1 system registers epsw, vbr, mmuctl, asid, cpuid (kernel mode, sim64 -k or the QEMU machine with kernel=on): widths and reserved bits. A failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	mov	$0xFFFF, r1
	mtsr	epsw, r1
	mfsr	r2, epsw
	cbne r2, $(1<<PSW_T|7<<PSW_PRI|3<<PSW_MODE|3<<PSW_PREV), F1 ; check 1
	mov	$-1, r1
	shl	$9, r1
	bis	$77, r1
	mtsr	vbr, r1
	mfsr	r2, vbr
	cbne r2, r1, F2
	mov	$0x12345, r1
	mtsr	asid, r1
	mfsr	r2, asid
	cbne r2, $(9029), F3 ; check 3
	mov	$0x2, r1
	mtsr	mmuctl, r1
	mfsr	r2, mmuctl
	cbne r2, $(0), F4 ; check 4
	mfsr	r2, cpuid
	cbne r2, $(0), F5 ; check 5
	mov	$5, r1
	mtsr	epsw, r1
	mfsr	r2, vbr
	cbne r2, $77, 1f
	br	F6
1:
	mfsr	r2, epsw
	cbne r2, $(0), F7 ; check 7: the old flag bits are reserved and read as zero
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

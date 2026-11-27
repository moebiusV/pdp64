; System v1: the T bit.  After an instruction that began with T set the trace trap is taken (vector 15, EPC the next instruction); rti loads T from EPSW, rtt sets it after the return. A failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	$0, r10
	mov	$0, r2
	mov	$0, r3
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	lea	tgt, r1
	mtsr	epc, r1
	mov	$((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)|1<<PSW_T), r1
	mtsr	epsw, r1
	rti	$RTIMASK_ALL
tgt:
	add	$1, r2
tr2:
	add	$1, r2
tr3:
	add	$1, r2
tr4:
	add	$1, r2
	cbne r10, $(3), F1 ; check 1
	cbne r2, $(4), F2 ; check 2
	lea	tr2, r11
	cbne r8, r11, F3 ; check 3
	lea	tr3, r11
	cbne r7, r11, F4 ; check 4
	lea	tr4, r11
	cbne r6, r11, F5 ; check 5
	mfps	r1
	cbne r1, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F6 ; check 6
	mov	$2, r10
	lea	tgt2, r1
	mtsr	epc, r1
	mov	$((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), r1
	mtsr	epsw, r1
	rtt	$RTIMASK_ALL
tgt2:
	add	$1, r3
t22:
	add	$1, r3
	add	$1, r3
	cbne r10, $(3), F7 ; check 7
	cbne r3, $(3), F8 ; check 8
	lea	t22, r11
	cbne r6, r11, F9 ; check 9
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
h_trace:	mov	r7, r8
	mov	r6, r7
	mfsr	r6, epc
	add	$1, r10
	cblt r10, $3, 1f
	mfsr	r9, epsw
	bic	$(1<<PSW_T), r9
	mtsr	epsw, r9
1:	rti	$RTIMASK_ALL
	.data
	.align	8
vtab:
	.space	120
	.quad	h_trace
	.space	3968


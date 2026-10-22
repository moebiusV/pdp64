; System v1 MMU: the TLB: a changed PTE is not seen until tlbi/tlbia; a write to ptbr, asid or mmuctl flushes (the QEMU model).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	movq	#1, r1
	mtsr	mmuctl, r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#2, r0	; check 1
	halt
1:
	lea	pgdata2, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#3, r0	; check 2
	halt
1:
	movq	=1073745920, r3
	tlbi	r3
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	=1073741824, r3
	tlbi	r3
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	lea	l0a, r1
	movq	#0, r2
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#6, r0	; check 5
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073741824, r3
	tlbi	r3
	movq	#0, r5
	lea	res_u, r4
ins_u:
	movq	8(r3), r5
res_u:
	cmp	r10, #(1)
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	lea	pgdata, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	lea	pgdata2, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	tlbia
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	lea	pgdata, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	lea	l2b, r1
	mtsr	ptbr, r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	lea	l2, r1
	mtsr	ptbr, r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	lea	pgdata2, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	movq	#7, r1
	mtsr	asid, r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r1
	mtsr	mmuctl, r1
	lea	res_o, r4
	movq	=1073741824, r3
ins_o:
	movq	8(r3), r5
res_o:
	movq	#1, r1
	mtsr	mmuctl, r1
	cmp	r10, #(1)
	beq	1f
	movq	#16, r0	; check 15
	halt
1:
	cmp	r8, #(VECTOR_BUSFAULT)
	beq	1f
	movq	#17, r0	; check 16
	halt
1:
	cmp	r9, #(1073741832)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r5, #(22136)
	beq	1f
	movq	#19, r0	; check 18
	halt
1:
	movq	#0, r0
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
h_ok:	movq	#0, r0
h_fail:	halt
	.data
	.align	4096
l2:
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	l1a + (1<<PTE_V)
	.space	4080

	.align	4096
l1a:
	.quad	l0a + (1<<PTE_V)
	.space	4088

	.align	4096
l0a:
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.space	4080

	.align	4096
l2b:
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	l1b + (1<<PTE_V)
	.space	4080

	.align	4096
l1b:
	.quad	l0b + (1<<PTE_V)
	.space	4088

	.align	4096
l0b:
	.quad	pgdata2 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.space	4088

	.align	4096
pgdata:	.word	0x1403
	.space	6
	.quad	0x1234
	.space	4080

	.align	4096
pgdata2:	.word	0x1403
	.space	6
	.quad	0x5678
	.space	4080
pgx:	.space	4094
	.word	0x540d

	.data
	.align	8
vtab:
	.space	16
	.quad	h_gen
	.space	8
	.quad	h_gen
	.quad	h_gen
	.quad	h_gen
	.quad	h_gen
	.quad	h_gen
	.quad	h_gen
	.quad	h_gen
	.quad	h_gen
	.space	8
	.quad	h_gen
	.space	1936
	.quad	h_ok
	.quad	h_fail
	.space	8
	.quad	h_gen
	.space	2016


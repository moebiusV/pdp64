; System v1 MMU: the TLB: a changed PTE is not seen until tlbi/tlbia; a write to ptbr, asid or mmuctl flushes (the QEMU model).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	mov	#1, r1
	mtsr	mmuctl, r1
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(4660), 1f
	mov	#2, r0	; check 1
	halt
1:
	lea	pgdata2, r2
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	mov	r2, 0(r1)
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(4660), 1f
	mov	#3, r0	; check 2
	halt
1:
	mov	=1073745920, r3
	tlbi	r3
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(4660), 1f
	mov	#4, r0	; check 3
	halt
1:
	mov	=1073741824, r3
	tlbi	r3
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#5, r0	; check 4
	halt
1:
	lea	l0a, r1
	mov	#0, r2
	mov	r2, 0(r1)
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#6, r0	; check 5
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073741824, r3
	tlbi	r3
	mov	#0, r5
	lea	res_u, r4
ins_u:
	mov	8(r3), r5
res_u:
	cbeq r10, #(1), 1f
	mov	#7, r0	; check 6
	halt
1:
	cbeq r8, #(VECTOR_LFAULT), 1f
	mov	#8, r0	; check 7
	halt
1:
	lea	pgdata, r2
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	mov	r2, 0(r1)
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(4660), 1f
	mov	#9, r0	; check 8
	halt
1:
	lea	pgdata2, r2
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	mov	r2, 0(r1)
	tlbia
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#10, r0	; check 9
	halt
1:
	lea	pgdata, r2
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	mov	r2, 0(r1)
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#11, r0	; check 10
	halt
1:
	lea	l2b, r1
	mtsr	ptbr, r1
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#12, r0	; check 11
	halt
1:
	lea	l2, r1
	mtsr	ptbr, r1
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(4660), 1f
	mov	#13, r0	; check 12
	halt
1:
	lea	pgdata2, r2
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	mov	r2, 0(r1)
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(4660), 1f
	mov	#14, r0	; check 13
	halt
1:
	mov	#7, r1
	mtsr	asid, r1
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#15, r0	; check 14
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	#0, r1
	mtsr	mmuctl, r1
	lea	res_o, r4
	mov	=1073741824, r3
ins_o:
	mov	8(r3), r5
res_o:
	mov	#1, r1
	mtsr	mmuctl, r1
	cbeq r10, #(1), 1f
	mov	#16, r0	; check 15
	halt
1:
	cbeq r8, #(VECTOR_BUSFAULT), 1f
	mov	#17, r0	; check 16
	halt
1:
	mov	=1073741832, r2
	cbeq r9, r2, 1f
	mov	#18, r0	; check 17
	halt
1:
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r5, #(22136), 1f
	mov	#19, r0	; check 18
	halt
1:
	mov	#0, r0
	halt
h_gen:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	mfsr	r9, eva
	add	#1, r10
	cbeq	r4, #0, 1f
	mtsr	epc, r4
1:	rti	#RTIMASK_ALL
h_ok:	mov	#0, r0
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
pgdata:	ret
	.space	6
	.quad	0x1234
	.space	4080

	.align	4096
pgdata2:	ret
	.space	6
	.quad	0x5678
	.space	4080
pgx:	.space	4094
	add	#1000, r1	; four bytes: the first parcel ends the page, its second parcel is on the next page

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


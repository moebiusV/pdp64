; System v1 MMU: software accessed and dirty bits: the page fault of the kind of access, the handler sets the bit, tlbi, the retry succeeds.
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
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073741824, r3
	movq	8(r3), r5
	cmp	r10, #(1)
	beq	1f
	movq	#2, r0	; check 1
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#3, r0	; check 2
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	cmp	r9, #(1073741832)
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	lea	l0a, r2
	movq	0(r2), r5
	lea	pgdata, r13
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cmp	r5, r13
	beq	1f
	movq	#6, r0	; check 5 (pte 0)
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
	movq	8(r3), r5
	cmp	r10, #(0)
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073745920, r3
	movq	#0x1234, r5
	movq	r5, 8(r3)
	cmp	r10, #(1)
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	lea	l0a, r2
	movq	8(r2), r5
	lea	pgdata, r13
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cmp	r5, r13
	beq	1f
	movq	#11, r0	; check 10 (pte 1)
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073750016, r3
	movq	8(r3), r5
	cmp	r10, #(0)
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	movq	#0x1234, r5
	movq	r5, 8(r3)
	cmp	r10, #(1)
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	cmp	r9, #(1073750024)
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	lea	l0a, r2
	movq	16(r2), r5
	lea	pgdata, r13
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cmp	r5, r13
	beq	1f
	movq	#16, r0	; check 15 (pte 2)
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073754112, r3
	movq	#0x1234, r5
	movq	r5, 8(r3)
	cmp	r10, #(1)
	beq	1f
	movq	#17, r0	; check 16
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	lea	l0a, r2
	movq	24(r2), r5
	lea	pgdata, r13
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cmp	r5, r13
	beq	1f
	movq	#19, r0	; check 18 (pte 3)
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073758208, r3
	call	r3
	cmp	r10, #(1)
	beq	1f
	movq	#20, r0	; check 19
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#21, r0	; check 20
	halt
1:
	cmp	r9, #(1073758208)
	beq	1f
	movq	#22, r0	; check 21
	halt
1:
	lea	l0a, r2
	movq	32(r2), r5
	lea	pgdata, r13
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_A)), r1
	add	r1, r13
	cmp	r5, r13
	beq	1f
	movq	#23, r0	; check 22 (pte 4)
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073762304, r3
	movq	#0x1234, r5
	movq	r5, 8(r3)
	cmp	r10, #(1)
	beq	1f
	movq	#24, r0	; check 23
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#25, r0	; check 24
	halt
1:
	lea	l0a, r2
	movq	40(r2), r5
	lea	pgdata, r13
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cmp	r5, r13
	beq	1f
	movq	#26, r0	; check 25 (pte 5)
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
h_ad:	add	#1, r10
	mfsr	r8, ecause
	mfsr	r9, eva
	movq	r9, r1
	movq	=1073741824, r2
	sub	r2, r1
	shr	#12, r1
	shl	#3, r1
	lea	l0a, r2
	add	r2, r1
	movq	(r1), r2
	bis	#(1<<PTE_A), r2
	cmp	r8, #(VECTOR_SFAULT)
	bne	1f
	bis	#(1<<PTE_D), r2
1:	movq	r2, (r1)
	movq	r9, r1
	tlbi	r1
	rti
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
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_D)
	.space	4048

	.align	4096
pgdata:	.word	0x1403
	.space	6
	.quad	0x1234
	.space	4080

	.data
	.align	8
vtab:
	.space	16
	.quad	h_gen
	.space	8
	.quad	h_gen
	.quad	h_gen
	.quad	h_ad
	.quad	h_ad
	.quad	h_ad
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


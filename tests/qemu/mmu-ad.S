; System v1 MMU: software accessed and dirty bits: the page fault of the kind of access, the handler sets the bit, tlbi, the retry succeeds.
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
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073741824, r3
	mov	8(r3), r5
	cbeq r10, #(1), 1f
	mov	#2, r0	; check 1
	halt
1:
	cbeq r8, #(VECTOR_LFAULT), 1f
	mov	#3, r0	; check 2
	halt
1:
	cbeq r5, #(4660), 1f
	mov	#4, r0	; check 3
	halt
1:
	mov	=1073741832, r2
	cbeq r9, r2, 1f
	mov	#5, r0	; check 4
	halt
1:
	lea	l0a, r2
	mov	0(r2), r5
	lea	pgdata, r13
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cbeq r5, r13, 1f
	mov	#6, r0	; check 5 (pte 0)
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
	mov	8(r3), r5
	cbeq r10, #(0), 1f
	mov	#7, r0	; check 6
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073745920, r3
	mov	#0x1234, r5
	mov	r5, 8(r3)
	cbeq r10, #(1), 1f
	mov	#8, r0	; check 7
	halt
1:
	cbeq r8, #(VECTOR_SFAULT), 1f
	mov	#9, r0	; check 8
	halt
1:
	cbeq r5, #(4660), 1f
	mov	#10, r0	; check 9
	halt
1:
	lea	l0a, r2
	mov	8(r2), r5
	lea	pgdata, r13
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cbeq r5, r13, 1f
	mov	#11, r0	; check 10 (pte 1)
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073750016, r3
	mov	8(r3), r5
	cbeq r10, #(0), 1f
	mov	#12, r0	; check 11
	halt
1:
	mov	#0x1234, r5
	mov	r5, 8(r3)
	cbeq r10, #(1), 1f
	mov	#13, r0	; check 12
	halt
1:
	cbeq r8, #(VECTOR_SFAULT), 1f
	mov	#14, r0	; check 13
	halt
1:
	mov	=1073750024, r2
	cbeq r9, r2, 1f
	mov	#15, r0	; check 14
	halt
1:
	lea	l0a, r2
	mov	16(r2), r5
	lea	pgdata, r13
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cbeq r5, r13, 1f
	mov	#16, r0	; check 15 (pte 2)
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073754112, r3
	mov	#0x1234, r5
	mov	r5, 8(r3)
	cbeq r10, #(1), 1f
	mov	#17, r0	; check 16
	halt
1:
	cbeq r8, #(VECTOR_SFAULT), 1f
	mov	#18, r0	; check 17
	halt
1:
	lea	l0a, r2
	mov	24(r2), r5
	lea	pgdata, r13
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cbeq r5, r13, 1f
	mov	#19, r0	; check 18 (pte 3)
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073758208, r3
	call	r3
	cbeq r10, #(1), 1f
	mov	#20, r0	; check 19
	halt
1:
	cbeq r8, #(VECTOR_IFAULT), 1f
	mov	#21, r0	; check 20
	halt
1:
	mov	=1073758208, r2
	cbeq r9, r2, 1f
	mov	#22, r0	; check 21
	halt
1:
	lea	l0a, r2
	mov	32(r2), r5
	lea	pgdata, r13
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_A)), r1
	add	r1, r13
	cbeq r5, r13, 1f
	mov	#23, r0	; check 22 (pte 4)
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073762304, r3
	mov	#0x1234, r5
	mov	r5, 8(r3)
	cbeq r10, #(1), 1f
	mov	#24, r0	; check 23
	halt
1:
	cbeq r8, #(VECTOR_SFAULT), 1f
	mov	#25, r0	; check 24
	halt
1:
	lea	l0a, r2
	mov	40(r2), r5
	lea	pgdata, r13
	mov	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r13
	cbeq r5, r13, 1f
	mov	#26, r0	; check 25 (pte 5)
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
h_ad:	add	#1, r10
	mfsr	r8, ecause
	mfsr	r9, eva
	mov	r9, r1
	mov	=1073741824, r2
	sub	r2, r1
	shr	#12, r1
	shl	#3, r1
	lea	l0a, r2
	add	r2, r1
	mov	(r1), r2
	bis	#(1<<PTE_A), r2
	cbne r8, #(VECTOR_SFAULT), 1f
	bis	#(1<<PTE_D), r2
1:	mov	r2, (r1)
	mov	r9, r1
	tlbi	r1
	rti	#RTIMASK_ALL
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
pgdata:	ret
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


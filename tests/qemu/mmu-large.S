; System v1 MMU: 2 MB and 1 GB leaf pages, a 2 MB page with D=0, tlbi inside it.
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
	movq	=1075838976, r3
	movq	=0xABCD, r5
	movq	r5, 8(r3)
	movq	r5, 0x1F8008(r3)
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=0x400008, r3
	movq	(r3), r6
	cmp	r6, #(43981)
	beq	1f
	movq	#2, r0	; check 1
	halt
1:
	movq	=0x5F8008, r3
	movq	(r3), r6
	cmp	r6, #(43981)
	beq	1f
	movq	#3, r0	; check 2
	halt
1:
	movq	=0xC3000010, r3
	movq	#0x55, r5
	movq	r5, 0(r3)
	movq	=0x3000010, r3
	movq	(r3), r6
	cmp	r6, #(85)
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	=0xC3000010, r3
	movq	(r3), r6
	cmp	r6, #(85)
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1077940224, r3
	movq	(r3), r6
	cmp	r10, #(0)
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
	lea	res_L1, r4
	movq	=1077940224, r3
ins_L1:
	movq	r5, (r3)
res_L1:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	lea	ins_L1, r11
	cmp	r6, r11
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	movq	=1077940224, r2
	cmp	r9, r2
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_L2, r4
	movq	=1079508992, r3
ins_L2:
	movq	r5, (r3)
res_L2:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	lea	ins_L2, r11
	cmp	r6, r11
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	movq	=1079508992, r2
	cmp	r9, r2
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	lea	l1a, r1
	movq	16(r1), r2
	bis	#(1<<PTE_D), r2
	movq	r2, 16(r1)
	movq	=1077944320, r3
	tlbi	r3
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1079508992, r3
	movq	#0x99, r5
	movq	r5, (r3)
	cmp	r10, #(0)
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	movq	=0x780000, r3
	movq	(r3), r6
	cmp	r6, #(153)
	beq	1f
	movq	#16, r0	; check 15
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
	.space	8
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.space	4064

	.align	4096
l1a:
	.space	8
	.quad	0x400000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	0x600000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A)
	.space	4072

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


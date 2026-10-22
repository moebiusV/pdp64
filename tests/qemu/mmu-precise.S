; System v1 MMU: precise faults: (rN)+ and -(rN), a read-modify-write, pushm, pushx and popx across a page boundary, an instruction whose second parcel is on an invalid page.
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
	lea	res_a, r4
	movq	=1073745920, r3
ins_a:
	movq	(r3)+, r5
res_a:
	movq	r7, r1
	bic	#15, r7
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
	lea	ins_a, r11
	cmp	r6, r11
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	=1073745920, r2
	cmp	r9, r2
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	movq	=1073745920, r2
	cmp	r3, r2
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
	lea	res_b, r4
	movq	=1073745928, r3
ins_b:
	movq	-(r3), r5
res_b:
	movq	r7, r1
	bic	#15, r7
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
	lea	ins_b, r11
	cmp	r6, r11
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	movq	=1073745920, r2
	cmp	r9, r2
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	movq	=1073745928, r2
	cmp	r3, r2
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	lea	pgdata, r2
	movq	(r2), r13
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_c, r4
	movq	=1073750016, r3
	cmp	r3, r3
ins_c:
	inc	(r3)+
res_c:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	lea	ins_c, r11
	cmp	r6, r11
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	movq	=1073750016, r2
	cmp	r9, r2
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	movq	=1073750016, r2
	cmp	r3, r2
	beq	1f
	movq	#16, r0	; check 15
	halt
1:
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	beq	1f
	movq	#17, r0	; check 16
	halt
1:
	and	#15, r1
	cmp	r1, #(1<<PSW_Z)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	lea	pgdata, r2
	movq	(r2), r5
	cmp	r5, r13
	beq	1f
	movq	#19, r0	; check 18
	halt
1:
	movq	sp, r15
	movq	=1073762312, sp
	movq	sp, r12
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_d, r4
ins_d:
	pushm	#7
res_d:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#20, r0	; check 19
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#21, r0	; check 20
	halt
1:
	lea	ins_d, r11
	cmp	r6, r11
	beq	1f
	movq	#22, r0	; check 21
	halt
1:
	movq	=1073762296, r2
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 22
	halt
1:
	movq	=1073762312, r2
	cmp	sp, r2
	beq	1f
	movq	#24, r0	; check 23
	halt
1:
	lea	pgdata, r2
	movq	(r2), r13
	movq	4088(r2), r12
	movq	=1073762312, sp
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_e1, r4
ins_e1:
	pushx
res_e1:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#25, r0	; check 24
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#26, r0	; check 25
	halt
1:
	lea	ins_e1, r11
	cmp	r6, r11
	beq	1f
	movq	#27, r0	; check 26
	halt
1:
	movq	=1073762296, r2
	cmp	r9, r2
	beq	1f
	movq	#28, r0	; check 27
	halt
1:
	movq	=1073762312, r2
	cmp	sp, r2
	beq	1f
	movq	#29, r0	; check 28
	halt
1:
	lea	pgdata, r2
	movq	(r2), r5
	cmp	r5, r13
	beq	1f
	movq	#30, r0	; check 29
	halt
1:
	movq	=1073745928, sp
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_e2, r4
ins_e2:
	pushx
res_e2:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#31, r0	; check 30
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#32, r0	; check 31
	halt
1:
	lea	ins_e2, r11
	cmp	r6, r11
	beq	1f
	movq	#33, r0	; check 32
	halt
1:
	movq	=1073745920, r2
	cmp	r9, r2
	beq	1f
	movq	#34, r0	; check 33
	halt
1:
	movq	=1073745928, r2
	cmp	sp, r2
	beq	1f
	movq	#35, r0	; check 34
	halt
1:
	lea	pgdata, r2
	movq	4088(r2), r5
	movq	4088(r2), r12
	cmp	r5, #(0)
	beq	1f
	movq	#36, r0	; check 35
	halt
1:
	movq	#0x1111, r1
	mtsr	epc, r1
	movq	#0x22, r1
	mtsr	epsw, r1
	movq	=1073745912, sp
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_f, r4
ins_f:
	popx
res_f:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#37, r0	; check 36
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#38, r0	; check 37
	halt
1:
	lea	ins_f, r11
	cmp	r6, r11
	beq	1f
	movq	#39, r0	; check 38
	halt
1:
	movq	=1073745920, r2
	cmp	r9, r2
	beq	1f
	movq	#40, r0	; check 39
	halt
1:
	movq	=1073745912, r2
	cmp	sp, r2
	beq	1f
	movq	#41, r0	; check 40
	halt
1:
	mfsr	r5, epc
	mfsr	r13, epsw
	lea	stk_top, sp
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073758206, r3
	lea	res_g, r4
ins_g:
	call	r3
res_g:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#42, r0	; check 41
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#43, r0	; check 42
	halt
1:
	movq	=1073758206, r2
	cmp	r6, r2
	beq	1f
	movq	#44, r0	; check 43
	halt
1:
	movq	=1073758208, r2
	cmp	r9, r2
	beq	1f
	movq	#45, r0	; check 44
	halt
1:
	movq	r15, sp
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
	.space	8
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_A|1<<PTE_D)
	.quad	pgx + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.space	8
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.space	4048

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

	.align 8
	.space 512
stk_top:


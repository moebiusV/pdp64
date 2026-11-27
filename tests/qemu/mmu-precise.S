; System v1 MMU: precise faults: (rN)+ and -(rN), a read-modify-write, pushm, pushx and popx across a page boundary, an instruction whose second parcel is on an invalid page.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	mov	$1, r1
	mtsr	mmuctl, r1
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_a, r4
	mov	=1073745920, r3
ins_a:
	mov	(r3)+, r5
res_a:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$2, r0	; check 1
	halt
1:
	cbeq r8, $(VECTOR_LFAULT), 1f
	mov	$3, r0	; check 2
	halt
1:
	lea	ins_a, r11
	cbeq r6, r11, 1f
	mov	$4, r0	; check 3
	halt
1:
	mov	=1073745920, r2
	cbeq r9, r2, 1f
	mov	$5, r0	; check 4
	halt
1:
	mov	=1073745920, r2
	cbeq r3, r2, 1f
	mov	$6, r0	; check 5
	halt
1:
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_b, r4
	mov	=1073745928, r3
ins_b:
	mov	-(r3), r5
res_b:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$7, r0	; check 6
	halt
1:
	cbeq r8, $(VECTOR_LFAULT), 1f
	mov	$8, r0	; check 7
	halt
1:
	lea	ins_b, r11
	cbeq r6, r11, 1f
	mov	$9, r0	; check 8
	halt
1:
	mov	=1073745920, r2
	cbeq r9, r2, 1f
	mov	$10, r0	; check 9
	halt
1:
	mov	=1073745928, r2
	cbeq r3, r2, 1f
	mov	$11, r0	; check 10
	halt
1:
	lea	pgdata, r2
	mov	(r2), r13
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_c, r4
	mov	=1073750016, r3
ins_c:
	inc	(r3)+
res_c:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$12, r0	; check 11
	halt
1:
	cbeq r8, $(VECTOR_SPROT), 1f
	mov	$13, r0	; check 12
	halt
1:
	lea	ins_c, r11
	cbeq r6, r11, 1f
	mov	$14, r0	; check 13
	halt
1:
	mov	=1073750016, r2
	cbeq r9, r2, 1f
	mov	$15, r0	; check 14
	halt
1:
	mov	=1073750016, r2
	cbeq r3, r2, 1f
	mov	$16, r0	; check 15
	halt
1:
	cbeq r7, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), 1f
	mov	$17, r0	; check 16
	halt
1:
	and	$15, r1		; bits 3 to 0 of the saved status word are reserved: zero
	cbeq r1, $0, 1f
	mov	$18, r0	; check 17
	halt
1:
	lea	pgdata, r2
	mov	(r2), r5
	cbeq r5, r13, 1f
	mov	$19, r0	; check 18
	halt
1:
	mov	sp, r15
	mov	=1073762312, sp
	mov	sp, r12
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_d, r4
ins_d:
	pushm	$7
res_d:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$20, r0	; check 19
	halt
1:
	cbeq r8, $(VECTOR_SFAULT), 1f
	mov	$21, r0	; check 20
	halt
1:
	lea	ins_d, r11
	cbeq r6, r11, 1f
	mov	$22, r0	; check 21
	halt
1:
	mov	=1073762296, r2
	cbeq r9, r2, 1f
	mov	$23, r0	; check 22
	halt
1:
	mov	=1073762312, r2
	cbeq sp, r2, 1f
	mov	$24, r0	; check 23
	halt
1:
	lea	pgdata, r2
	mov	(r2), r13
	mov	4088(r2), r12
	mov	=1073762312, sp
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_e1, r4
ins_e1:
	pushx
res_e1:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$25, r0	; check 24
	halt
1:
	cbeq r8, $(VECTOR_SFAULT), 1f
	mov	$26, r0	; check 25
	halt
1:
	lea	ins_e1, r11
	cbeq r6, r11, 1f
	mov	$27, r0	; check 26
	halt
1:
	mov	=1073762296, r2
	cbeq r9, r2, 1f
	mov	$28, r0	; check 27
	halt
1:
	mov	=1073762312, r2
	cbeq sp, r2, 1f
	mov	$29, r0	; check 28
	halt
1:
	lea	pgdata, r2
	mov	(r2), r5
	cbeq r5, r13, 1f
	mov	$30, r0	; check 29
	halt
1:
	mov	=1073745928, sp
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_e2, r4
ins_e2:
	pushx
res_e2:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$31, r0	; check 30
	halt
1:
	cbeq r8, $(VECTOR_SFAULT), 1f
	mov	$32, r0	; check 31
	halt
1:
	lea	ins_e2, r11
	cbeq r6, r11, 1f
	mov	$33, r0	; check 32
	halt
1:
	mov	=1073745920, r2
	cbeq r9, r2, 1f
	mov	$34, r0	; check 33
	halt
1:
	mov	=1073745928, r2
	cbeq sp, r2, 1f
	mov	$35, r0	; check 34
	halt
1:
	lea	pgdata, r2
	mov	4088(r2), r5
	mov	4088(r2), r12
	cbeq r5, $(0), 1f
	mov	$36, r0	; check 35
	halt
1:
	mov	$0x1111, r1
	mtsr	epc, r1
	mov	$0x22, r1
	mtsr	epsw, r1
	mov	=1073745912, sp
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	res_f, r4
ins_f:
	popx
res_f:
	mov	r7, r1
	bic	$15, r7
	cbeq r10, $(1), 1f
	mov	$37, r0	; check 36
	halt
1:
	cbeq r8, $(VECTOR_LFAULT), 1f
	mov	$38, r0	; check 37
	halt
1:
	lea	ins_f, r11
	cbeq r6, r11, 1f
	mov	$39, r0	; check 38
	halt
1:
	mov	=1073745920, r2
	cbeq r9, r2, 1f
	mov	$40, r0	; check 39
	halt
1:
	mov	=1073745912, r2
	cbeq sp, r2, 1f
	mov	$41, r0	; check 40
	halt
1:
	mfsr	r5, epc
	mfsr	r13, epsw
	lea	stk_top, sp
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	=1073758206, r3
	lea	res_g, r4
ins_g:
	call	r3
res_g:
	add	$8, sp
	cbeq r10, $(1), 1f
	mov	$42, r0	; check 41
	halt
1:
	cbeq r8, $(VECTOR_IFAULT), 1f
	mov	$43, r0	; check 42
	halt
1:
	mov	=1073758206, r2
	cbeq r6, r2, 1f
	mov	$44, r0	; check 43
	halt
1:
	mov	=1073758208, r2
	cbeq r9, r2, 1f
	mov	$45, r0	; check 44
	halt
1:
	mov	r15, sp
	mov	$0, r0
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
h_ok:	mov	$0, r0
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
	add	$1000, r1	; four bytes: the first parcel ends the page, its second parcel is on the next page

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


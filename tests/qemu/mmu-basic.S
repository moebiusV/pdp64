; System v1 MMU: enable and disable, non-canonical addresses (vector 5), negative addresses, the physical vector table, tlbi/tlbia/tlbsync.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	lea	stk_top, sp
	mfsr	r5, mmuctl
	cmp	r5, #(0)
	beq	1f
	movq	#2, r0	; check 1
	halt
1:
	movq	=65536, r3
	movq	8(r3), r5
	movq	#1, r1
	mtsr	mmuctl, r1
	mfsr	r5, mmuctl
	cmp	r5, #(1)
	beq	1f
	movq	#3, r0	; check 2
	halt
1:
	movq	=65536, r3
	movq	8(r3), r5
	movq	#0x77, r5
	movq	r5, 8(r3)
	movq	8(r3), r6
	cmp	r6, #(119)
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc0load, r4
ins_nc0load:
	movq	=274877906944, r3
x_nc0load:
	movq	(r3), r5
res_nc0load:
	cmp	r10, #(1)
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#6, r0	; check 5
	halt
1:
	movq	=274877906944, r2
	cmp	r9, r2
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	lea	x_nc0load, r11
	cmp	r6, r11
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc0store, r4
ins_nc0store:
	movq	=274877906944, r3
x_nc0store:
	movq	r5, (r3)
res_nc0store:
	cmp	r10, #(1)
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	movq	=274877906944, r2
	cmp	r9, r2
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	lea	x_nc0store, r11
	cmp	r6, r11
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc0fetch, r4
ins_nc0fetch:
	movq	=274877906944, r3
x_nc0fetch:
	call	r3
res_nc0fetch:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	movq	=274877906944, r2
	cmp	r9, r2
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	cmp	r6, r2
	beq	1f
	movq	#16, r0	; check 15
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc1load, r4
ins_nc1load:
	movq	=72057594037927936, r3
x_nc1load:
	movq	(r3), r5
res_nc1load:
	cmp	r10, #(1)
	beq	1f
	movq	#17, r0	; check 16
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	movq	=72057594037927936, r2
	cmp	r9, r2
	beq	1f
	movq	#19, r0	; check 18
	halt
1:
	lea	x_nc1load, r11
	cmp	r6, r11
	beq	1f
	movq	#20, r0	; check 19
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc1store, r4
ins_nc1store:
	movq	=72057594037927936, r3
x_nc1store:
	movq	r5, (r3)
res_nc1store:
	cmp	r10, #(1)
	beq	1f
	movq	#21, r0	; check 20
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#22, r0	; check 21
	halt
1:
	movq	=72057594037927936, r2
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 22
	halt
1:
	lea	x_nc1store, r11
	cmp	r6, r11
	beq	1f
	movq	#24, r0	; check 23
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc1fetch, r4
ins_nc1fetch:
	movq	=72057594037927936, r3
x_nc1fetch:
	call	r3
res_nc1fetch:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#25, r0	; check 24
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#26, r0	; check 25
	halt
1:
	movq	=72057594037927936, r2
	cmp	r9, r2
	beq	1f
	movq	#27, r0	; check 26
	halt
1:
	cmp	r6, r2
	beq	1f
	movq	#28, r0	; check 27
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc2load, r4
ins_nc2load:
	movq	=18446743798831644664, r3
x_nc2load:
	movq	(r3), r5
res_nc2load:
	cmp	r10, #(1)
	beq	1f
	movq	#29, r0	; check 28
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#30, r0	; check 29
	halt
1:
	movq	=18446743798831644664, r2
	cmp	r9, r2
	beq	1f
	movq	#31, r0	; check 30
	halt
1:
	lea	x_nc2load, r11
	cmp	r6, r11
	beq	1f
	movq	#32, r0	; check 31
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc2store, r4
ins_nc2store:
	movq	=18446743798831644664, r3
x_nc2store:
	movq	r5, (r3)
res_nc2store:
	cmp	r10, #(1)
	beq	1f
	movq	#33, r0	; check 32
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#34, r0	; check 33
	halt
1:
	movq	=18446743798831644664, r2
	cmp	r9, r2
	beq	1f
	movq	#35, r0	; check 34
	halt
1:
	lea	x_nc2store, r11
	cmp	r6, r11
	beq	1f
	movq	#36, r0	; check 35
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc2fetch, r4
ins_nc2fetch:
	movq	=18446743798831644664, r3
x_nc2fetch:
	call	r3
res_nc2fetch:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#37, r0	; check 36
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#38, r0	; check 37
	halt
1:
	movq	=18446743798831644664, r2
	cmp	r9, r2
	beq	1f
	movq	#39, r0	; check 38
	halt
1:
	cmp	r6, r2
	beq	1f
	movq	#40, r0	; check 39
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc3load, r4
ins_nc3load:
	movq	=549755813888, r3
x_nc3load:
	movq	(r3), r5
res_nc3load:
	cmp	r10, #(1)
	beq	1f
	movq	#41, r0	; check 40
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#42, r0	; check 41
	halt
1:
	movq	=549755813888, r2
	cmp	r9, r2
	beq	1f
	movq	#43, r0	; check 42
	halt
1:
	lea	x_nc3load, r11
	cmp	r6, r11
	beq	1f
	movq	#44, r0	; check 43
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc3store, r4
ins_nc3store:
	movq	=549755813888, r3
x_nc3store:
	movq	r5, (r3)
res_nc3store:
	cmp	r10, #(1)
	beq	1f
	movq	#45, r0	; check 44
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#46, r0	; check 45
	halt
1:
	movq	=549755813888, r2
	cmp	r9, r2
	beq	1f
	movq	#47, r0	; check 46
	halt
1:
	lea	x_nc3store, r11
	cmp	r6, r11
	beq	1f
	movq	#48, r0	; check 47
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc3fetch, r4
ins_nc3fetch:
	movq	=549755813888, r3
x_nc3fetch:
	call	r3
res_nc3fetch:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#49, r0	; check 48
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#50, r0	; check 49
	halt
1:
	movq	=549755813888, r2
	cmp	r9, r2
	beq	1f
	movq	#51, r0	; check 50
	halt
1:
	cmp	r6, r2
	beq	1f
	movq	#52, r0	; check 51
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc4load, r4
ins_nc4load:
	movq	=9223372036854775808, r3
x_nc4load:
	movq	(r3), r5
res_nc4load:
	cmp	r10, #(1)
	beq	1f
	movq	#53, r0	; check 52
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#54, r0	; check 53
	halt
1:
	movq	=9223372036854775808, r2
	cmp	r9, r2
	beq	1f
	movq	#55, r0	; check 54
	halt
1:
	lea	x_nc4load, r11
	cmp	r6, r11
	beq	1f
	movq	#56, r0	; check 55
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc4store, r4
ins_nc4store:
	movq	=9223372036854775808, r3
x_nc4store:
	movq	r5, (r3)
res_nc4store:
	cmp	r10, #(1)
	beq	1f
	movq	#57, r0	; check 56
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#58, r0	; check 57
	halt
1:
	movq	=9223372036854775808, r2
	cmp	r9, r2
	beq	1f
	movq	#59, r0	; check 58
	halt
1:
	lea	x_nc4store, r11
	cmp	r6, r11
	beq	1f
	movq	#60, r0	; check 59
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_nc4fetch, r4
ins_nc4fetch:
	movq	=9223372036854775808, r3
x_nc4fetch:
	call	r3
res_nc4fetch:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#61, r0	; check 60
	halt
1:
	cmp	r8, #(VECTOR_NONCANONICAL)
	beq	1f
	movq	#62, r0	; check 61
	halt
1:
	movq	=9223372036854775808, r2
	cmp	r9, r2
	beq	1f
	movq	#63, r0	; check 62
	halt
1:
	cmp	r6, r2
	beq	1f
	movq	#64, r0	; check 63
	halt
1:
	movq	=0xFFFFFFC000000000, r3
	lea	pgdata, r2
	add	r2, r3
	movq	8(r3), r5
	cmp	r5, #(4660)
	beq	1f
	movq	#65, r0	; check 64
	halt
1:
	movq	#0, r1
	mtsr	mmuctl, r1
	movq	=0x800000, r2
	lea	h_gen, r1
	movq	r1, 56(r2)
	movq	r1, 2072(r2)
	mtsr	vbr, r2
	movq	#1, r1
	mtsr	mmuctl, r1
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_v1, r4
	movq	=0x800000, r3
ins_v1:
	movq	(r3), r5
res_v1:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#66, r0	; check 65
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#67, r0	; check 66
	halt
1:
	lea	ins_v1, r11
	cmp	r6, r11
	beq	1f
	movq	#68, r0	; check 67
	halt
1:
	movq	=8388608, r2
	cmp	r9, r2
	beq	1f
	movq	#69, r0	; check 68
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#3
aft:
	cmp	r10, #(1)
	beq	1f
	movq	#70, r0	; check 69
	halt
1:
	cmp	r8, #(VECTOR_TRAP_BASE+3)
	beq	1f
	movq	#71, r0	; check 70
	halt
1:
	movq	=0x10000, r3
	tlbi	r3
	tlbia
	tlbsync
	movq	#0, r1
	mtsr	mmuctl, r1
	movq	=0x800000, r3
	movq	8(r3), r5
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
	.quad	l1a + (1<<PTE_V)
	.space	2040
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.space	2040

	.align	4096
l1a:
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.space	4088

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

	.align 8
	.space 512
stk_top:


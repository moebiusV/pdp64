; System v1 MMU: the same matrix accessed in USER mode (the program runs at the user alias of memory, a 1 GB U page at 0x80000000). Generated from a reference model of section 15 (the PTE rules) in the generator; a failed check n exits with n mod 255 + 1.
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
	lea	ustk_top, r1
	movq	=2147483648, r2
	add	r2, r1
	mtsr	usp, r1
	lea	user, r1
	add	r2, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti
user:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073741824, r3
	lea	res_m_0_load, r4
	movq	#0, r5
ins_m_0_load:
	movq	8(r3), r5
res_m_0_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#2, r0	; check 1
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#3, r0	; check 2
	trap	#1
1:
	lea	ins_m_0_load, r11
	cmp	r6, r11
	beq	1f
	movq	#4, r0	; check 3
	trap	#1
1:
	movq	=1073741832, r2
	cmp	r9, r2
	beq	1f
	movq	#5, r0	; check 4
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073741824, r3
	lea	res_m_0_store, r4
	movq	#0x1234, r5
ins_m_0_store:
	movq	r5, 8(r3)
res_m_0_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#6, r0	; check 5
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#7, r0	; check 6
	trap	#1
1:
	lea	ins_m_0_store, r11
	cmp	r6, r11
	beq	1f
	movq	#8, r0	; check 7
	trap	#1
1:
	movq	=1073741832, r2
	cmp	r9, r2
	beq	1f
	movq	#9, r0	; check 8
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073741824, r3
	lea	res_m_0_fetch, r4
ins_m_0_fetch:
	call	r3
res_m_0_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#10, r0	; check 9
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#11, r0	; check 10
	trap	#1
1:
	movq	=1073741824, r2
	cmp	r6, r2
	beq	1f
	movq	#12, r0	; check 11
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#13, r0	; check 12
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073745920, r3
	lea	res_m_1_load, r4
	movq	#0, r5
ins_m_1_load:
	movq	8(r3), r5
res_m_1_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#14, r0	; check 13
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#15, r0	; check 14
	trap	#1
1:
	lea	ins_m_1_load, r11
	cmp	r6, r11
	beq	1f
	movq	#16, r0	; check 15
	trap	#1
1:
	movq	=1073745928, r2
	cmp	r9, r2
	beq	1f
	movq	#17, r0	; check 16
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073745920, r3
	lea	res_m_1_store, r4
	movq	#0x1234, r5
ins_m_1_store:
	movq	r5, 8(r3)
res_m_1_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#18, r0	; check 17
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#19, r0	; check 18
	trap	#1
1:
	lea	ins_m_1_store, r11
	cmp	r6, r11
	beq	1f
	movq	#20, r0	; check 19
	trap	#1
1:
	movq	=1073745928, r2
	cmp	r9, r2
	beq	1f
	movq	#21, r0	; check 20
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073745920, r3
	lea	res_m_1_fetch, r4
ins_m_1_fetch:
	call	r3
res_m_1_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#22, r0	; check 21
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#23, r0	; check 22
	trap	#1
1:
	movq	=1073745920, r2
	cmp	r6, r2
	beq	1f
	movq	#24, r0	; check 23
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#25, r0	; check 24
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073750016, r3
	lea	res_m_2_load, r4
	movq	#0, r5
ins_m_2_load:
	movq	8(r3), r5
res_m_2_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#26, r0	; check 25
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#27, r0	; check 26
	trap	#1
1:
	lea	ins_m_2_load, r11
	cmp	r6, r11
	beq	1f
	movq	#28, r0	; check 27
	trap	#1
1:
	movq	=1073750024, r2
	cmp	r9, r2
	beq	1f
	movq	#29, r0	; check 28
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073750016, r3
	lea	res_m_2_store, r4
	movq	#0x1234, r5
ins_m_2_store:
	movq	r5, 8(r3)
res_m_2_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#30, r0	; check 29
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#31, r0	; check 30
	trap	#1
1:
	lea	ins_m_2_store, r11
	cmp	r6, r11
	beq	1f
	movq	#32, r0	; check 31
	trap	#1
1:
	movq	=1073750024, r2
	cmp	r9, r2
	beq	1f
	movq	#33, r0	; check 32
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073750016, r3
	lea	res_m_2_fetch, r4
ins_m_2_fetch:
	call	r3
res_m_2_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#34, r0	; check 33
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#35, r0	; check 34
	trap	#1
1:
	movq	=1073750016, r2
	cmp	r6, r2
	beq	1f
	movq	#36, r0	; check 35
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#37, r0	; check 36
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073754112, r3
	lea	res_m_3_load, r4
	movq	#0, r5
ins_m_3_load:
	movq	8(r3), r5
res_m_3_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#38, r0	; check 37
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#39, r0	; check 38
	trap	#1
1:
	lea	ins_m_3_load, r11
	cmp	r6, r11
	beq	1f
	movq	#40, r0	; check 39
	trap	#1
1:
	movq	=1073754120, r2
	cmp	r9, r2
	beq	1f
	movq	#41, r0	; check 40
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073754112, r3
	lea	res_m_3_store, r4
	movq	#0x1234, r5
ins_m_3_store:
	movq	r5, 8(r3)
res_m_3_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#42, r0	; check 41
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#43, r0	; check 42
	trap	#1
1:
	lea	ins_m_3_store, r11
	cmp	r6, r11
	beq	1f
	movq	#44, r0	; check 43
	trap	#1
1:
	movq	=1073754120, r2
	cmp	r9, r2
	beq	1f
	movq	#45, r0	; check 44
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073754112, r3
	lea	res_m_3_fetch, r4
ins_m_3_fetch:
	call	r3
res_m_3_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#46, r0	; check 45
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#47, r0	; check 46
	trap	#1
1:
	movq	=1073754112, r2
	cmp	r6, r2
	beq	1f
	movq	#48, r0	; check 47
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#49, r0	; check 48
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073758208, r3
	lea	res_m_4_load, r4
	movq	#0, r5
ins_m_4_load:
	movq	8(r3), r5
res_m_4_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#50, r0	; check 49
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#51, r0	; check 50
	trap	#1
1:
	lea	ins_m_4_load, r11
	cmp	r6, r11
	beq	1f
	movq	#52, r0	; check 51
	trap	#1
1:
	movq	=1073758216, r2
	cmp	r9, r2
	beq	1f
	movq	#53, r0	; check 52
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073758208, r3
	lea	res_m_4_store, r4
	movq	#0x1234, r5
ins_m_4_store:
	movq	r5, 8(r3)
res_m_4_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#54, r0	; check 53
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#55, r0	; check 54
	trap	#1
1:
	lea	ins_m_4_store, r11
	cmp	r6, r11
	beq	1f
	movq	#56, r0	; check 55
	trap	#1
1:
	movq	=1073758216, r2
	cmp	r9, r2
	beq	1f
	movq	#57, r0	; check 56
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073758208, r3
	lea	res_m_4_fetch, r4
ins_m_4_fetch:
	call	r3
res_m_4_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#58, r0	; check 57
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#59, r0	; check 58
	trap	#1
1:
	movq	=1073758208, r2
	cmp	r6, r2
	beq	1f
	movq	#60, r0	; check 59
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#61, r0	; check 60
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073762304, r3
	lea	res_m_5_load, r4
	movq	#0, r5
ins_m_5_load:
	movq	8(r3), r5
res_m_5_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#62, r0	; check 61
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#63, r0	; check 62
	trap	#1
1:
	lea	ins_m_5_load, r11
	cmp	r6, r11
	beq	1f
	movq	#64, r0	; check 63
	trap	#1
1:
	movq	=1073762312, r2
	cmp	r9, r2
	beq	1f
	movq	#65, r0	; check 64
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073762304, r3
	lea	res_m_5_store, r4
	movq	#0x1234, r5
ins_m_5_store:
	movq	r5, 8(r3)
res_m_5_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#66, r0	; check 65
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#67, r0	; check 66
	trap	#1
1:
	lea	ins_m_5_store, r11
	cmp	r6, r11
	beq	1f
	movq	#68, r0	; check 67
	trap	#1
1:
	movq	=1073762312, r2
	cmp	r9, r2
	beq	1f
	movq	#69, r0	; check 68
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073762304, r3
	lea	res_m_5_fetch, r4
ins_m_5_fetch:
	call	r3
res_m_5_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#70, r0	; check 69
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#71, r0	; check 70
	trap	#1
1:
	movq	=1073762304, r2
	cmp	r6, r2
	beq	1f
	movq	#72, r0	; check 71
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#73, r0	; check 72
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073766400, r3
	lea	res_m_6_load, r4
	movq	#0, r5
ins_m_6_load:
	movq	8(r3), r5
res_m_6_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#74, r0	; check 73
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#75, r0	; check 74
	trap	#1
1:
	lea	ins_m_6_load, r11
	cmp	r6, r11
	beq	1f
	movq	#76, r0	; check 75
	trap	#1
1:
	movq	=1073766408, r2
	cmp	r9, r2
	beq	1f
	movq	#77, r0	; check 76
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073766400, r3
	lea	res_m_6_store, r4
	movq	#0x1234, r5
ins_m_6_store:
	movq	r5, 8(r3)
res_m_6_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#78, r0	; check 77
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#79, r0	; check 78
	trap	#1
1:
	lea	ins_m_6_store, r11
	cmp	r6, r11
	beq	1f
	movq	#80, r0	; check 79
	trap	#1
1:
	movq	=1073766408, r2
	cmp	r9, r2
	beq	1f
	movq	#81, r0	; check 80
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073766400, r3
	lea	res_m_6_fetch, r4
ins_m_6_fetch:
	call	r3
res_m_6_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#82, r0	; check 81
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#83, r0	; check 82
	trap	#1
1:
	movq	=1073766400, r2
	cmp	r6, r2
	beq	1f
	movq	#84, r0	; check 83
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#85, r0	; check 84
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073770496, r3
	lea	res_m_7_load, r4
	movq	#0, r5
ins_m_7_load:
	movq	8(r3), r5
res_m_7_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#86, r0	; check 85
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#87, r0	; check 86
	trap	#1
1:
	lea	ins_m_7_load, r11
	cmp	r6, r11
	beq	1f
	movq	#88, r0	; check 87
	trap	#1
1:
	movq	=1073770504, r2
	cmp	r9, r2
	beq	1f
	movq	#89, r0	; check 88
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073770496, r3
	lea	res_m_7_store, r4
	movq	#0x1234, r5
ins_m_7_store:
	movq	r5, 8(r3)
res_m_7_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#90, r0	; check 89
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#91, r0	; check 90
	trap	#1
1:
	lea	ins_m_7_store, r11
	cmp	r6, r11
	beq	1f
	movq	#92, r0	; check 91
	trap	#1
1:
	movq	=1073770504, r2
	cmp	r9, r2
	beq	1f
	movq	#93, r0	; check 92
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073770496, r3
	lea	res_m_7_fetch, r4
ins_m_7_fetch:
	call	r3
res_m_7_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#94, r0	; check 93
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#95, r0	; check 94
	trap	#1
1:
	movq	=1073770496, r2
	cmp	r6, r2
	beq	1f
	movq	#96, r0	; check 95
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#97, r0	; check 96
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073774592, r3
	lea	res_m_8_load, r4
	movq	#0, r5
ins_m_8_load:
	movq	8(r3), r5
res_m_8_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#98, r0	; check 97
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#99, r0	; check 98
	trap	#1
1:
	lea	ins_m_8_load, r11
	cmp	r6, r11
	beq	1f
	movq	#100, r0	; check 99
	trap	#1
1:
	movq	=1073774600, r2
	cmp	r9, r2
	beq	1f
	movq	#101, r0	; check 100
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073774592, r3
	lea	res_m_8_store, r4
	movq	#0x1234, r5
ins_m_8_store:
	movq	r5, 8(r3)
res_m_8_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#102, r0	; check 101
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#103, r0	; check 102
	trap	#1
1:
	lea	ins_m_8_store, r11
	cmp	r6, r11
	beq	1f
	movq	#104, r0	; check 103
	trap	#1
1:
	movq	=1073774600, r2
	cmp	r9, r2
	beq	1f
	movq	#105, r0	; check 104
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073774592, r3
	lea	res_m_8_fetch, r4
ins_m_8_fetch:
	call	r3
res_m_8_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#106, r0	; check 105
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#107, r0	; check 106
	trap	#1
1:
	movq	=1073774592, r2
	cmp	r6, r2
	beq	1f
	movq	#108, r0	; check 107
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#109, r0	; check 108
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073778688, r3
	lea	res_m_9_load, r4
	movq	#0, r5
ins_m_9_load:
	movq	8(r3), r5
res_m_9_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#110, r0	; check 109
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#111, r0	; check 110
	trap	#1
1:
	lea	ins_m_9_load, r11
	cmp	r6, r11
	beq	1f
	movq	#112, r0	; check 111
	trap	#1
1:
	movq	=1073778696, r2
	cmp	r9, r2
	beq	1f
	movq	#113, r0	; check 112
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073778688, r3
	lea	res_m_9_store, r4
	movq	#0x1234, r5
ins_m_9_store:
	movq	r5, 8(r3)
res_m_9_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#114, r0	; check 113
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#115, r0	; check 114
	trap	#1
1:
	lea	ins_m_9_store, r11
	cmp	r6, r11
	beq	1f
	movq	#116, r0	; check 115
	trap	#1
1:
	movq	=1073778696, r2
	cmp	r9, r2
	beq	1f
	movq	#117, r0	; check 116
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073778688, r3
	lea	res_m_9_fetch, r4
ins_m_9_fetch:
	call	r3
res_m_9_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#118, r0	; check 117
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#119, r0	; check 118
	trap	#1
1:
	movq	=1073778688, r2
	cmp	r6, r2
	beq	1f
	movq	#120, r0	; check 119
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#121, r0	; check 120
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073782784, r3
	lea	res_m_10_load, r4
	movq	#0, r5
ins_m_10_load:
	movq	8(r3), r5
res_m_10_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#122, r0	; check 121
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#123, r0	; check 122
	trap	#1
1:
	lea	ins_m_10_load, r11
	cmp	r6, r11
	beq	1f
	movq	#124, r0	; check 123
	trap	#1
1:
	movq	=1073782792, r2
	cmp	r9, r2
	beq	1f
	movq	#125, r0	; check 124
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073782784, r3
	lea	res_m_10_store, r4
	movq	#0x1234, r5
ins_m_10_store:
	movq	r5, 8(r3)
res_m_10_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#126, r0	; check 125
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#127, r0	; check 126
	trap	#1
1:
	lea	ins_m_10_store, r11
	cmp	r6, r11
	beq	1f
	movq	#128, r0	; check 127
	trap	#1
1:
	movq	=1073782792, r2
	cmp	r9, r2
	beq	1f
	movq	#129, r0	; check 128
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073782784, r3
	lea	res_m_10_fetch, r4
ins_m_10_fetch:
	call	r3
res_m_10_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#130, r0	; check 129
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#131, r0	; check 130
	trap	#1
1:
	movq	=1073782784, r2
	cmp	r6, r2
	beq	1f
	movq	#132, r0	; check 131
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#133, r0	; check 132
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073786880, r3
	lea	res_m_11_load, r4
	movq	#0, r5
ins_m_11_load:
	movq	8(r3), r5
res_m_11_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#134, r0	; check 133
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#135, r0	; check 134
	trap	#1
1:
	lea	ins_m_11_load, r11
	cmp	r6, r11
	beq	1f
	movq	#136, r0	; check 135
	trap	#1
1:
	movq	=1073786888, r2
	cmp	r9, r2
	beq	1f
	movq	#137, r0	; check 136
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073786880, r3
	lea	res_m_11_store, r4
	movq	#0x1234, r5
ins_m_11_store:
	movq	r5, 8(r3)
res_m_11_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#138, r0	; check 137
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#139, r0	; check 138
	trap	#1
1:
	lea	ins_m_11_store, r11
	cmp	r6, r11
	beq	1f
	movq	#140, r0	; check 139
	trap	#1
1:
	movq	=1073786888, r2
	cmp	r9, r2
	beq	1f
	movq	#141, r0	; check 140
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073786880, r3
	lea	res_m_11_fetch, r4
ins_m_11_fetch:
	call	r3
res_m_11_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#142, r0	; check 141
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#143, r0	; check 142
	trap	#1
1:
	movq	=1073786880, r2
	cmp	r6, r2
	beq	1f
	movq	#144, r0	; check 143
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#145, r0	; check 144
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073790976, r3
	lea	res_m_12_load, r4
	movq	#0, r5
ins_m_12_load:
	movq	8(r3), r5
res_m_12_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#146, r0	; check 145
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#147, r0	; check 146
	trap	#1
1:
	lea	ins_m_12_load, r11
	cmp	r6, r11
	beq	1f
	movq	#148, r0	; check 147
	trap	#1
1:
	movq	=1073790984, r2
	cmp	r9, r2
	beq	1f
	movq	#149, r0	; check 148
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073790976, r3
	lea	res_m_12_store, r4
	movq	#0x1234, r5
ins_m_12_store:
	movq	r5, 8(r3)
res_m_12_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#150, r0	; check 149
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#151, r0	; check 150
	trap	#1
1:
	lea	ins_m_12_store, r11
	cmp	r6, r11
	beq	1f
	movq	#152, r0	; check 151
	trap	#1
1:
	movq	=1073790984, r2
	cmp	r9, r2
	beq	1f
	movq	#153, r0	; check 152
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073790976, r3
	lea	res_m_12_fetch, r4
ins_m_12_fetch:
	call	r3
res_m_12_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#154, r0	; check 153
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#155, r0	; check 154
	trap	#1
1:
	movq	=1073790976, r2
	cmp	r6, r2
	beq	1f
	movq	#156, r0	; check 155
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#157, r0	; check 156
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073795072, r3
	lea	res_m_13_load, r4
	movq	#0, r5
ins_m_13_load:
	movq	8(r3), r5
res_m_13_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#158, r0	; check 157
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#159, r0	; check 158
	trap	#1
1:
	lea	ins_m_13_load, r11
	cmp	r6, r11
	beq	1f
	movq	#160, r0	; check 159
	trap	#1
1:
	movq	=1073795080, r2
	cmp	r9, r2
	beq	1f
	movq	#161, r0	; check 160
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073795072, r3
	lea	res_m_13_store, r4
	movq	#0x1234, r5
ins_m_13_store:
	movq	r5, 8(r3)
res_m_13_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#162, r0	; check 161
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#163, r0	; check 162
	trap	#1
1:
	lea	ins_m_13_store, r11
	cmp	r6, r11
	beq	1f
	movq	#164, r0	; check 163
	trap	#1
1:
	movq	=1073795080, r2
	cmp	r9, r2
	beq	1f
	movq	#165, r0	; check 164
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073795072, r3
	lea	res_m_13_fetch, r4
ins_m_13_fetch:
	call	r3
res_m_13_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#166, r0	; check 165
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#167, r0	; check 166
	trap	#1
1:
	movq	=1073795072, r2
	cmp	r6, r2
	beq	1f
	movq	#168, r0	; check 167
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#169, r0	; check 168
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073799168, r3
	lea	res_m_14_load, r4
	movq	#0, r5
ins_m_14_load:
	movq	8(r3), r5
res_m_14_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#170, r0	; check 169
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#171, r0	; check 170
	trap	#1
1:
	lea	ins_m_14_load, r11
	cmp	r6, r11
	beq	1f
	movq	#172, r0	; check 171
	trap	#1
1:
	movq	=1073799176, r2
	cmp	r9, r2
	beq	1f
	movq	#173, r0	; check 172
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073799168, r3
	lea	res_m_14_store, r4
	movq	#0x1234, r5
ins_m_14_store:
	movq	r5, 8(r3)
res_m_14_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#174, r0	; check 173
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#175, r0	; check 174
	trap	#1
1:
	lea	ins_m_14_store, r11
	cmp	r6, r11
	beq	1f
	movq	#176, r0	; check 175
	trap	#1
1:
	movq	=1073799176, r2
	cmp	r9, r2
	beq	1f
	movq	#177, r0	; check 176
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073799168, r3
	lea	res_m_14_fetch, r4
ins_m_14_fetch:
	call	r3
res_m_14_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#178, r0	; check 177
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#179, r0	; check 178
	trap	#1
1:
	movq	=1073799168, r2
	cmp	r6, r2
	beq	1f
	movq	#180, r0	; check 179
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#181, r0	; check 180
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073803264, r3
	lea	res_m_15_load, r4
	movq	#0, r5
ins_m_15_load:
	movq	8(r3), r5
res_m_15_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#182, r0	; check 181
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#183, r0	; check 182
	trap	#1
1:
	lea	ins_m_15_load, r11
	cmp	r6, r11
	beq	1f
	movq	#184, r0	; check 183
	trap	#1
1:
	movq	=1073803272, r2
	cmp	r9, r2
	beq	1f
	movq	#185, r0	; check 184
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073803264, r3
	lea	res_m_15_store, r4
	movq	#0x1234, r5
ins_m_15_store:
	movq	r5, 8(r3)
res_m_15_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#186, r0	; check 185
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#187, r0	; check 186
	trap	#1
1:
	lea	ins_m_15_store, r11
	cmp	r6, r11
	beq	1f
	movq	#188, r0	; check 187
	trap	#1
1:
	movq	=1073803272, r2
	cmp	r9, r2
	beq	1f
	movq	#189, r0	; check 188
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073803264, r3
	lea	res_m_15_fetch, r4
ins_m_15_fetch:
	call	r3
res_m_15_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#190, r0	; check 189
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#191, r0	; check 190
	trap	#1
1:
	movq	=1073803264, r2
	cmp	r6, r2
	beq	1f
	movq	#192, r0	; check 191
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#193, r0	; check 192
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073807360, r3
	lea	res_m_16_load, r4
	movq	#0, r5
ins_m_16_load:
	movq	8(r3), r5
res_m_16_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#194, r0	; check 193
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#195, r0	; check 194
	trap	#1
1:
	lea	ins_m_16_load, r11
	cmp	r6, r11
	beq	1f
	movq	#196, r0	; check 195
	trap	#1
1:
	movq	=1073807368, r2
	cmp	r9, r2
	beq	1f
	movq	#197, r0	; check 196
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073807360, r3
	lea	res_m_16_store, r4
	movq	#0x1234, r5
ins_m_16_store:
	movq	r5, 8(r3)
res_m_16_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#198, r0	; check 197
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#199, r0	; check 198
	trap	#1
1:
	lea	ins_m_16_store, r11
	cmp	r6, r11
	beq	1f
	movq	#200, r0	; check 199
	trap	#1
1:
	movq	=1073807368, r2
	cmp	r9, r2
	beq	1f
	movq	#201, r0	; check 200
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073807360, r3
	lea	res_m_16_fetch, r4
ins_m_16_fetch:
	call	r3
res_m_16_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#202, r0	; check 201
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#203, r0	; check 202
	trap	#1
1:
	movq	=1073807360, r2
	cmp	r6, r2
	beq	1f
	movq	#204, r0	; check 203
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#205, r0	; check 204
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073811456, r3
	lea	res_m_17_load, r4
	movq	#0, r5
ins_m_17_load:
	movq	8(r3), r5
res_m_17_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#206, r0	; check 205
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#207, r0	; check 206
	trap	#1
1:
	lea	ins_m_17_load, r11
	cmp	r6, r11
	beq	1f
	movq	#208, r0	; check 207
	trap	#1
1:
	movq	=1073811464, r2
	cmp	r9, r2
	beq	1f
	movq	#209, r0	; check 208
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073811456, r3
	lea	res_m_17_store, r4
	movq	#0x1234, r5
ins_m_17_store:
	movq	r5, 8(r3)
res_m_17_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#210, r0	; check 209
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#211, r0	; check 210
	trap	#1
1:
	lea	ins_m_17_store, r11
	cmp	r6, r11
	beq	1f
	movq	#212, r0	; check 211
	trap	#1
1:
	movq	=1073811464, r2
	cmp	r9, r2
	beq	1f
	movq	#213, r0	; check 212
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073811456, r3
	lea	res_m_17_fetch, r4
ins_m_17_fetch:
	call	r3
res_m_17_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#214, r0	; check 213
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#215, r0	; check 214
	trap	#1
1:
	movq	=1073811456, r2
	cmp	r6, r2
	beq	1f
	movq	#216, r0	; check 215
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#217, r0	; check 216
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073815552, r3
	lea	res_m_18_load, r4
	movq	#0, r5
ins_m_18_load:
	movq	8(r3), r5
res_m_18_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#218, r0	; check 217
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#219, r0	; check 218
	trap	#1
1:
	lea	ins_m_18_load, r11
	cmp	r6, r11
	beq	1f
	movq	#220, r0	; check 219
	trap	#1
1:
	movq	=1073815560, r2
	cmp	r9, r2
	beq	1f
	movq	#221, r0	; check 220
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073815552, r3
	lea	res_m_18_store, r4
	movq	#0x1234, r5
ins_m_18_store:
	movq	r5, 8(r3)
res_m_18_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#222, r0	; check 221
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#223, r0	; check 222
	trap	#1
1:
	lea	ins_m_18_store, r11
	cmp	r6, r11
	beq	1f
	movq	#224, r0	; check 223
	trap	#1
1:
	movq	=1073815560, r2
	cmp	r9, r2
	beq	1f
	movq	#225, r0	; check 224
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073815552, r3
	lea	res_m_18_fetch, r4
ins_m_18_fetch:
	call	r3
res_m_18_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#226, r0	; check 225
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#227, r0	; check 226
	trap	#1
1:
	movq	=1073815552, r2
	cmp	r6, r2
	beq	1f
	movq	#228, r0	; check 227
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#229, r0	; check 228
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073819648, r3
	lea	res_m_19_load, r4
	movq	#0, r5
ins_m_19_load:
	movq	8(r3), r5
res_m_19_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#230, r0	; check 229
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#231, r0	; check 230
	trap	#1
1:
	lea	ins_m_19_load, r11
	cmp	r6, r11
	beq	1f
	movq	#232, r0	; check 231
	trap	#1
1:
	movq	=1073819656, r2
	cmp	r9, r2
	beq	1f
	movq	#233, r0	; check 232
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073819648, r3
	lea	res_m_19_store, r4
	movq	#0x1234, r5
ins_m_19_store:
	movq	r5, 8(r3)
res_m_19_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#234, r0	; check 233
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#235, r0	; check 234
	trap	#1
1:
	lea	ins_m_19_store, r11
	cmp	r6, r11
	beq	1f
	movq	#236, r0	; check 235
	trap	#1
1:
	movq	=1073819656, r2
	cmp	r9, r2
	beq	1f
	movq	#237, r0	; check 236
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073819648, r3
	lea	res_m_19_fetch, r4
ins_m_19_fetch:
	call	r3
res_m_19_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#238, r0	; check 237
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#239, r0	; check 238
	trap	#1
1:
	movq	=1073819648, r2
	cmp	r6, r2
	beq	1f
	movq	#240, r0	; check 239
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#241, r0	; check 240
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073823744, r3
	lea	res_m_20_load, r4
	movq	#0, r5
ins_m_20_load:
	movq	8(r3), r5
res_m_20_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#242, r0	; check 241
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#243, r0	; check 242
	trap	#1
1:
	lea	ins_m_20_load, r11
	cmp	r6, r11
	beq	1f
	movq	#244, r0	; check 243
	trap	#1
1:
	movq	=1073823752, r2
	cmp	r9, r2
	beq	1f
	movq	#245, r0	; check 244
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073823744, r3
	lea	res_m_20_store, r4
	movq	#0x1234, r5
ins_m_20_store:
	movq	r5, 8(r3)
res_m_20_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#246, r0	; check 245
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#247, r0	; check 246
	trap	#1
1:
	lea	ins_m_20_store, r11
	cmp	r6, r11
	beq	1f
	movq	#248, r0	; check 247
	trap	#1
1:
	movq	=1073823752, r2
	cmp	r9, r2
	beq	1f
	movq	#249, r0	; check 248
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073823744, r3
	lea	res_m_20_fetch, r4
ins_m_20_fetch:
	call	r3
res_m_20_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#250, r0	; check 249
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#251, r0	; check 250
	trap	#1
1:
	movq	=1073823744, r2
	cmp	r6, r2
	beq	1f
	movq	#252, r0	; check 251
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#253, r0	; check 252
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073827840, r3
	lea	res_m_21_load, r4
	movq	#0, r5
ins_m_21_load:
	movq	8(r3), r5
res_m_21_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#254, r0	; check 253
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#255, r0	; check 254
	trap	#1
1:
	lea	ins_m_21_load, r11
	cmp	r6, r11
	beq	1f
	movq	#1, r0	; check 255
	trap	#1
1:
	movq	=1073827848, r2
	cmp	r9, r2
	beq	1f
	movq	#2, r0	; check 256
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073827840, r3
	lea	res_m_21_store, r4
	movq	#0x1234, r5
ins_m_21_store:
	movq	r5, 8(r3)
res_m_21_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#3, r0	; check 257
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#4, r0	; check 258
	trap	#1
1:
	lea	ins_m_21_store, r11
	cmp	r6, r11
	beq	1f
	movq	#5, r0	; check 259
	trap	#1
1:
	movq	=1073827848, r2
	cmp	r9, r2
	beq	1f
	movq	#6, r0	; check 260
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073827840, r3
	lea	res_m_21_fetch, r4
ins_m_21_fetch:
	call	r3
res_m_21_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#7, r0	; check 261
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#8, r0	; check 262
	trap	#1
1:
	movq	=1073827840, r2
	cmp	r6, r2
	beq	1f
	movq	#9, r0	; check 263
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#10, r0	; check 264
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073831936, r3
	lea	res_m_22_load, r4
	movq	#0, r5
ins_m_22_load:
	movq	8(r3), r5
res_m_22_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#11, r0	; check 265
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#12, r0	; check 266
	trap	#1
1:
	lea	ins_m_22_load, r11
	cmp	r6, r11
	beq	1f
	movq	#13, r0	; check 267
	trap	#1
1:
	movq	=1073831944, r2
	cmp	r9, r2
	beq	1f
	movq	#14, r0	; check 268
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073831936, r3
	lea	res_m_22_store, r4
	movq	#0x1234, r5
ins_m_22_store:
	movq	r5, 8(r3)
res_m_22_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#15, r0	; check 269
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#16, r0	; check 270
	trap	#1
1:
	lea	ins_m_22_store, r11
	cmp	r6, r11
	beq	1f
	movq	#17, r0	; check 271
	trap	#1
1:
	movq	=1073831944, r2
	cmp	r9, r2
	beq	1f
	movq	#18, r0	; check 272
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073831936, r3
	lea	res_m_22_fetch, r4
ins_m_22_fetch:
	call	r3
res_m_22_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#19, r0	; check 273
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#20, r0	; check 274
	trap	#1
1:
	movq	=1073831936, r2
	cmp	r6, r2
	beq	1f
	movq	#21, r0	; check 275
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#22, r0	; check 276
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073836032, r3
	lea	res_m_23_load, r4
	movq	#0, r5
ins_m_23_load:
	movq	8(r3), r5
res_m_23_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#23, r0	; check 277
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#24, r0	; check 278
	trap	#1
1:
	lea	ins_m_23_load, r11
	cmp	r6, r11
	beq	1f
	movq	#25, r0	; check 279
	trap	#1
1:
	movq	=1073836040, r2
	cmp	r9, r2
	beq	1f
	movq	#26, r0	; check 280
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073836032, r3
	lea	res_m_23_store, r4
	movq	#0x1234, r5
ins_m_23_store:
	movq	r5, 8(r3)
res_m_23_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#27, r0	; check 281
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#28, r0	; check 282
	trap	#1
1:
	lea	ins_m_23_store, r11
	cmp	r6, r11
	beq	1f
	movq	#29, r0	; check 283
	trap	#1
1:
	movq	=1073836040, r2
	cmp	r9, r2
	beq	1f
	movq	#30, r0	; check 284
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073836032, r3
	lea	res_m_23_fetch, r4
ins_m_23_fetch:
	call	r3
res_m_23_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#31, r0	; check 285
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#32, r0	; check 286
	trap	#1
1:
	movq	=1073836032, r2
	cmp	r6, r2
	beq	1f
	movq	#33, r0	; check 287
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#34, r0	; check 288
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073840128, r3
	lea	res_m_24_load, r4
	movq	#0, r5
ins_m_24_load:
	movq	8(r3), r5
res_m_24_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#35, r0	; check 289
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#36, r0	; check 290
	trap	#1
1:
	lea	ins_m_24_load, r11
	cmp	r6, r11
	beq	1f
	movq	#37, r0	; check 291
	trap	#1
1:
	movq	=1073840136, r2
	cmp	r9, r2
	beq	1f
	movq	#38, r0	; check 292
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073840128, r3
	lea	res_m_24_store, r4
	movq	#0x1234, r5
ins_m_24_store:
	movq	r5, 8(r3)
res_m_24_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#39, r0	; check 293
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#40, r0	; check 294
	trap	#1
1:
	lea	ins_m_24_store, r11
	cmp	r6, r11
	beq	1f
	movq	#41, r0	; check 295
	trap	#1
1:
	movq	=1073840136, r2
	cmp	r9, r2
	beq	1f
	movq	#42, r0	; check 296
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073840128, r3
	lea	res_m_24_fetch, r4
ins_m_24_fetch:
	call	r3
res_m_24_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#43, r0	; check 297
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#44, r0	; check 298
	trap	#1
1:
	movq	=1073840128, r2
	cmp	r6, r2
	beq	1f
	movq	#45, r0	; check 299
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#46, r0	; check 300
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073844224, r3
	lea	res_m_25_load, r4
	movq	#0, r5
ins_m_25_load:
	movq	8(r3), r5
res_m_25_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#47, r0	; check 301
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#48, r0	; check 302
	trap	#1
1:
	lea	ins_m_25_load, r11
	cmp	r6, r11
	beq	1f
	movq	#49, r0	; check 303
	trap	#1
1:
	movq	=1073844232, r2
	cmp	r9, r2
	beq	1f
	movq	#50, r0	; check 304
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073844224, r3
	lea	res_m_25_store, r4
	movq	#0x1234, r5
ins_m_25_store:
	movq	r5, 8(r3)
res_m_25_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#51, r0	; check 305
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#52, r0	; check 306
	trap	#1
1:
	lea	ins_m_25_store, r11
	cmp	r6, r11
	beq	1f
	movq	#53, r0	; check 307
	trap	#1
1:
	movq	=1073844232, r2
	cmp	r9, r2
	beq	1f
	movq	#54, r0	; check 308
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073844224, r3
	lea	res_m_25_fetch, r4
ins_m_25_fetch:
	call	r3
res_m_25_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#55, r0	; check 309
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#56, r0	; check 310
	trap	#1
1:
	movq	=1073844224, r2
	cmp	r6, r2
	beq	1f
	movq	#57, r0	; check 311
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#58, r0	; check 312
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073848320, r3
	lea	res_m_26_load, r4
	movq	#0, r5
ins_m_26_load:
	movq	8(r3), r5
res_m_26_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#59, r0	; check 313
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#60, r0	; check 314
	trap	#1
1:
	lea	ins_m_26_load, r11
	cmp	r6, r11
	beq	1f
	movq	#61, r0	; check 315
	trap	#1
1:
	movq	=1073848328, r2
	cmp	r9, r2
	beq	1f
	movq	#62, r0	; check 316
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073848320, r3
	lea	res_m_26_store, r4
	movq	#0x1234, r5
ins_m_26_store:
	movq	r5, 8(r3)
res_m_26_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#63, r0	; check 317
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#64, r0	; check 318
	trap	#1
1:
	lea	ins_m_26_store, r11
	cmp	r6, r11
	beq	1f
	movq	#65, r0	; check 319
	trap	#1
1:
	movq	=1073848328, r2
	cmp	r9, r2
	beq	1f
	movq	#66, r0	; check 320
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073848320, r3
	lea	res_m_26_fetch, r4
ins_m_26_fetch:
	call	r3
res_m_26_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#67, r0	; check 321
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#68, r0	; check 322
	trap	#1
1:
	movq	=1073848320, r2
	cmp	r6, r2
	beq	1f
	movq	#69, r0	; check 323
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#70, r0	; check 324
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073852416, r3
	lea	res_m_27_load, r4
	movq	#0, r5
ins_m_27_load:
	movq	8(r3), r5
res_m_27_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#71, r0	; check 325
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#72, r0	; check 326
	trap	#1
1:
	lea	ins_m_27_load, r11
	cmp	r6, r11
	beq	1f
	movq	#73, r0	; check 327
	trap	#1
1:
	movq	=1073852424, r2
	cmp	r9, r2
	beq	1f
	movq	#74, r0	; check 328
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073852416, r3
	lea	res_m_27_store, r4
	movq	#0x1234, r5
ins_m_27_store:
	movq	r5, 8(r3)
res_m_27_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#75, r0	; check 329
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#76, r0	; check 330
	trap	#1
1:
	lea	ins_m_27_store, r11
	cmp	r6, r11
	beq	1f
	movq	#77, r0	; check 331
	trap	#1
1:
	movq	=1073852424, r2
	cmp	r9, r2
	beq	1f
	movq	#78, r0	; check 332
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073852416, r3
	lea	res_m_27_fetch, r4
ins_m_27_fetch:
	call	r3
res_m_27_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#79, r0	; check 333
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#80, r0	; check 334
	trap	#1
1:
	movq	=1073852416, r2
	cmp	r6, r2
	beq	1f
	movq	#81, r0	; check 335
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#82, r0	; check 336
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073856512, r3
	lea	res_m_28_load, r4
	movq	#0, r5
ins_m_28_load:
	movq	8(r3), r5
res_m_28_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#83, r0	; check 337
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#84, r0	; check 338
	trap	#1
1:
	lea	ins_m_28_load, r11
	cmp	r6, r11
	beq	1f
	movq	#85, r0	; check 339
	trap	#1
1:
	movq	=1073856520, r2
	cmp	r9, r2
	beq	1f
	movq	#86, r0	; check 340
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073856512, r3
	lea	res_m_28_store, r4
	movq	#0x1234, r5
ins_m_28_store:
	movq	r5, 8(r3)
res_m_28_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#87, r0	; check 341
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#88, r0	; check 342
	trap	#1
1:
	lea	ins_m_28_store, r11
	cmp	r6, r11
	beq	1f
	movq	#89, r0	; check 343
	trap	#1
1:
	movq	=1073856520, r2
	cmp	r9, r2
	beq	1f
	movq	#90, r0	; check 344
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073856512, r3
	lea	res_m_28_fetch, r4
ins_m_28_fetch:
	call	r3
res_m_28_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#91, r0	; check 345
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#92, r0	; check 346
	trap	#1
1:
	movq	=1073856512, r2
	cmp	r6, r2
	beq	1f
	movq	#93, r0	; check 347
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#94, r0	; check 348
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073860608, r3
	lea	res_m_29_load, r4
	movq	#0, r5
ins_m_29_load:
	movq	8(r3), r5
res_m_29_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#95, r0	; check 349
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#96, r0	; check 350
	trap	#1
1:
	lea	ins_m_29_load, r11
	cmp	r6, r11
	beq	1f
	movq	#97, r0	; check 351
	trap	#1
1:
	movq	=1073860616, r2
	cmp	r9, r2
	beq	1f
	movq	#98, r0	; check 352
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073860608, r3
	lea	res_m_29_store, r4
	movq	#0x1234, r5
ins_m_29_store:
	movq	r5, 8(r3)
res_m_29_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#99, r0	; check 353
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#100, r0	; check 354
	trap	#1
1:
	lea	ins_m_29_store, r11
	cmp	r6, r11
	beq	1f
	movq	#101, r0	; check 355
	trap	#1
1:
	movq	=1073860616, r2
	cmp	r9, r2
	beq	1f
	movq	#102, r0	; check 356
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073860608, r3
	lea	res_m_29_fetch, r4
ins_m_29_fetch:
	call	r3
res_m_29_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#103, r0	; check 357
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#104, r0	; check 358
	trap	#1
1:
	movq	=1073860608, r2
	cmp	r6, r2
	beq	1f
	movq	#105, r0	; check 359
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#106, r0	; check 360
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073864704, r3
	lea	res_m_30_load, r4
	movq	#0, r5
ins_m_30_load:
	movq	8(r3), r5
res_m_30_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#107, r0	; check 361
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#108, r0	; check 362
	trap	#1
1:
	lea	ins_m_30_load, r11
	cmp	r6, r11
	beq	1f
	movq	#109, r0	; check 363
	trap	#1
1:
	movq	=1073864712, r2
	cmp	r9, r2
	beq	1f
	movq	#110, r0	; check 364
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073864704, r3
	lea	res_m_30_store, r4
	movq	#0x1234, r5
ins_m_30_store:
	movq	r5, 8(r3)
res_m_30_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#111, r0	; check 365
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#112, r0	; check 366
	trap	#1
1:
	lea	ins_m_30_store, r11
	cmp	r6, r11
	beq	1f
	movq	#113, r0	; check 367
	trap	#1
1:
	movq	=1073864712, r2
	cmp	r9, r2
	beq	1f
	movq	#114, r0	; check 368
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073864704, r3
	lea	res_m_30_fetch, r4
ins_m_30_fetch:
	call	r3
res_m_30_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#115, r0	; check 369
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#116, r0	; check 370
	trap	#1
1:
	movq	=1073864704, r2
	cmp	r6, r2
	beq	1f
	movq	#117, r0	; check 371
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#118, r0	; check 372
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073868800, r3
	lea	res_m_31_load, r4
	movq	#0, r5
ins_m_31_load:
	movq	8(r3), r5
res_m_31_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#119, r0	; check 373
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#120, r0	; check 374
	trap	#1
1:
	lea	ins_m_31_load, r11
	cmp	r6, r11
	beq	1f
	movq	#121, r0	; check 375
	trap	#1
1:
	movq	=1073868808, r2
	cmp	r9, r2
	beq	1f
	movq	#122, r0	; check 376
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073868800, r3
	lea	res_m_31_store, r4
	movq	#0x1234, r5
ins_m_31_store:
	movq	r5, 8(r3)
res_m_31_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#123, r0	; check 377
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#124, r0	; check 378
	trap	#1
1:
	lea	ins_m_31_store, r11
	cmp	r6, r11
	beq	1f
	movq	#125, r0	; check 379
	trap	#1
1:
	movq	=1073868808, r2
	cmp	r9, r2
	beq	1f
	movq	#126, r0	; check 380
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073868800, r3
	lea	res_m_31_fetch, r4
ins_m_31_fetch:
	call	r3
res_m_31_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#127, r0	; check 381
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#128, r0	; check 382
	trap	#1
1:
	movq	=1073868800, r2
	cmp	r6, r2
	beq	1f
	movq	#129, r0	; check 383
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#130, r0	; check 384
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073872896, r3
	lea	res_m_32_load, r4
	movq	#0, r5
ins_m_32_load:
	movq	8(r3), r5
res_m_32_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#131, r0	; check 385
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#132, r0	; check 386
	trap	#1
1:
	lea	ins_m_32_load, r11
	cmp	r6, r11
	beq	1f
	movq	#133, r0	; check 387
	trap	#1
1:
	movq	=1073872904, r2
	cmp	r9, r2
	beq	1f
	movq	#134, r0	; check 388
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073872896, r3
	lea	res_m_32_store, r4
	movq	#0x1234, r5
ins_m_32_store:
	movq	r5, 8(r3)
res_m_32_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#135, r0	; check 389
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#136, r0	; check 390
	trap	#1
1:
	lea	ins_m_32_store, r11
	cmp	r6, r11
	beq	1f
	movq	#137, r0	; check 391
	trap	#1
1:
	movq	=1073872904, r2
	cmp	r9, r2
	beq	1f
	movq	#138, r0	; check 392
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073872896, r3
	lea	res_m_32_fetch, r4
ins_m_32_fetch:
	call	r3
res_m_32_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#139, r0	; check 393
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#140, r0	; check 394
	trap	#1
1:
	movq	=1073872896, r2
	cmp	r6, r2
	beq	1f
	movq	#141, r0	; check 395
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#142, r0	; check 396
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073876992, r3
	lea	res_m_33_load, r4
	movq	#0, r5
ins_m_33_load:
	movq	8(r3), r5
res_m_33_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#143, r0	; check 397
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#144, r0	; check 398
	trap	#1
1:
	lea	ins_m_33_load, r11
	cmp	r6, r11
	beq	1f
	movq	#145, r0	; check 399
	trap	#1
1:
	movq	=1073877000, r2
	cmp	r9, r2
	beq	1f
	movq	#146, r0	; check 400
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073876992, r3
	lea	res_m_33_store, r4
	movq	#0x1234, r5
ins_m_33_store:
	movq	r5, 8(r3)
res_m_33_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#147, r0	; check 401
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#148, r0	; check 402
	trap	#1
1:
	lea	ins_m_33_store, r11
	cmp	r6, r11
	beq	1f
	movq	#149, r0	; check 403
	trap	#1
1:
	movq	=1073877000, r2
	cmp	r9, r2
	beq	1f
	movq	#150, r0	; check 404
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073876992, r3
	lea	res_m_33_fetch, r4
ins_m_33_fetch:
	call	r3
res_m_33_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#151, r0	; check 405
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#152, r0	; check 406
	trap	#1
1:
	movq	=1073876992, r2
	cmp	r6, r2
	beq	1f
	movq	#153, r0	; check 407
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#154, r0	; check 408
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073881088, r3
	lea	res_m_34_load, r4
	movq	#0, r5
ins_m_34_load:
	movq	8(r3), r5
res_m_34_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#155, r0	; check 409
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#156, r0	; check 410
	trap	#1
1:
	lea	ins_m_34_load, r11
	cmp	r6, r11
	beq	1f
	movq	#157, r0	; check 411
	trap	#1
1:
	movq	=1073881096, r2
	cmp	r9, r2
	beq	1f
	movq	#158, r0	; check 412
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073881088, r3
	lea	res_m_34_store, r4
	movq	#0x1234, r5
ins_m_34_store:
	movq	r5, 8(r3)
res_m_34_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#159, r0	; check 413
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#160, r0	; check 414
	trap	#1
1:
	lea	ins_m_34_store, r11
	cmp	r6, r11
	beq	1f
	movq	#161, r0	; check 415
	trap	#1
1:
	movq	=1073881096, r2
	cmp	r9, r2
	beq	1f
	movq	#162, r0	; check 416
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073881088, r3
	lea	res_m_34_fetch, r4
ins_m_34_fetch:
	call	r3
res_m_34_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#163, r0	; check 417
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#164, r0	; check 418
	trap	#1
1:
	movq	=1073881088, r2
	cmp	r6, r2
	beq	1f
	movq	#165, r0	; check 419
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#166, r0	; check 420
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073885184, r3
	lea	res_m_35_load, r4
	movq	#0, r5
ins_m_35_load:
	movq	8(r3), r5
res_m_35_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#167, r0	; check 421
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#168, r0	; check 422
	trap	#1
1:
	lea	ins_m_35_load, r11
	cmp	r6, r11
	beq	1f
	movq	#169, r0	; check 423
	trap	#1
1:
	movq	=1073885192, r2
	cmp	r9, r2
	beq	1f
	movq	#170, r0	; check 424
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073885184, r3
	lea	res_m_35_store, r4
	movq	#0x1234, r5
ins_m_35_store:
	movq	r5, 8(r3)
res_m_35_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#171, r0	; check 425
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#172, r0	; check 426
	trap	#1
1:
	lea	ins_m_35_store, r11
	cmp	r6, r11
	beq	1f
	movq	#173, r0	; check 427
	trap	#1
1:
	movq	=1073885192, r2
	cmp	r9, r2
	beq	1f
	movq	#174, r0	; check 428
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073885184, r3
	lea	res_m_35_fetch, r4
ins_m_35_fetch:
	call	r3
res_m_35_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#175, r0	; check 429
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#176, r0	; check 430
	trap	#1
1:
	movq	=1073885184, r2
	cmp	r6, r2
	beq	1f
	movq	#177, r0	; check 431
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#178, r0	; check 432
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073889280, r3
	lea	res_m_36_load, r4
	movq	#0, r5
ins_m_36_load:
	movq	8(r3), r5
res_m_36_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#179, r0	; check 433
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#180, r0	; check 434
	trap	#1
1:
	lea	ins_m_36_load, r11
	cmp	r6, r11
	beq	1f
	movq	#181, r0	; check 435
	trap	#1
1:
	movq	=1073889288, r2
	cmp	r9, r2
	beq	1f
	movq	#182, r0	; check 436
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073889280, r3
	lea	res_m_36_store, r4
	movq	#0x1234, r5
ins_m_36_store:
	movq	r5, 8(r3)
res_m_36_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#183, r0	; check 437
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#184, r0	; check 438
	trap	#1
1:
	lea	ins_m_36_store, r11
	cmp	r6, r11
	beq	1f
	movq	#185, r0	; check 439
	trap	#1
1:
	movq	=1073889288, r2
	cmp	r9, r2
	beq	1f
	movq	#186, r0	; check 440
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073889280, r3
	lea	res_m_36_fetch, r4
ins_m_36_fetch:
	call	r3
res_m_36_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#187, r0	; check 441
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#188, r0	; check 442
	trap	#1
1:
	movq	=1073889280, r2
	cmp	r6, r2
	beq	1f
	movq	#189, r0	; check 443
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#190, r0	; check 444
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073893376, r3
	lea	res_m_37_load, r4
	movq	#0, r5
ins_m_37_load:
	movq	8(r3), r5
res_m_37_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#191, r0	; check 445
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#192, r0	; check 446
	trap	#1
1:
	lea	ins_m_37_load, r11
	cmp	r6, r11
	beq	1f
	movq	#193, r0	; check 447
	trap	#1
1:
	movq	=1073893384, r2
	cmp	r9, r2
	beq	1f
	movq	#194, r0	; check 448
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073893376, r3
	lea	res_m_37_store, r4
	movq	#0x1234, r5
ins_m_37_store:
	movq	r5, 8(r3)
res_m_37_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#195, r0	; check 449
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#196, r0	; check 450
	trap	#1
1:
	lea	ins_m_37_store, r11
	cmp	r6, r11
	beq	1f
	movq	#197, r0	; check 451
	trap	#1
1:
	movq	=1073893384, r2
	cmp	r9, r2
	beq	1f
	movq	#198, r0	; check 452
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073893376, r3
	lea	res_m_37_fetch, r4
ins_m_37_fetch:
	call	r3
res_m_37_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#199, r0	; check 453
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#200, r0	; check 454
	trap	#1
1:
	movq	=1073893376, r2
	cmp	r6, r2
	beq	1f
	movq	#201, r0	; check 455
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#202, r0	; check 456
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073897472, r3
	lea	res_m_38_load, r4
	movq	#0, r5
ins_m_38_load:
	movq	8(r3), r5
res_m_38_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#203, r0	; check 457
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#204, r0	; check 458
	trap	#1
1:
	lea	ins_m_38_load, r11
	cmp	r6, r11
	beq	1f
	movq	#205, r0	; check 459
	trap	#1
1:
	movq	=1073897480, r2
	cmp	r9, r2
	beq	1f
	movq	#206, r0	; check 460
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073897472, r3
	lea	res_m_38_store, r4
	movq	#0x1234, r5
ins_m_38_store:
	movq	r5, 8(r3)
res_m_38_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#207, r0	; check 461
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#208, r0	; check 462
	trap	#1
1:
	lea	ins_m_38_store, r11
	cmp	r6, r11
	beq	1f
	movq	#209, r0	; check 463
	trap	#1
1:
	movq	=1073897480, r2
	cmp	r9, r2
	beq	1f
	movq	#210, r0	; check 464
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073897472, r3
	lea	res_m_38_fetch, r4
ins_m_38_fetch:
	call	r3
res_m_38_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#211, r0	; check 465
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#212, r0	; check 466
	trap	#1
1:
	movq	=1073897472, r2
	cmp	r6, r2
	beq	1f
	movq	#213, r0	; check 467
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#214, r0	; check 468
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073901568, r3
	lea	res_m_39_load, r4
	movq	#0, r5
ins_m_39_load:
	movq	8(r3), r5
res_m_39_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#215, r0	; check 469
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#216, r0	; check 470
	trap	#1
1:
	lea	ins_m_39_load, r11
	cmp	r6, r11
	beq	1f
	movq	#217, r0	; check 471
	trap	#1
1:
	movq	=1073901576, r2
	cmp	r9, r2
	beq	1f
	movq	#218, r0	; check 472
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073901568, r3
	lea	res_m_39_store, r4
	movq	#0x1234, r5
ins_m_39_store:
	movq	r5, 8(r3)
res_m_39_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#219, r0	; check 473
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#220, r0	; check 474
	trap	#1
1:
	lea	ins_m_39_store, r11
	cmp	r6, r11
	beq	1f
	movq	#221, r0	; check 475
	trap	#1
1:
	movq	=1073901576, r2
	cmp	r9, r2
	beq	1f
	movq	#222, r0	; check 476
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073901568, r3
	lea	res_m_39_fetch, r4
ins_m_39_fetch:
	call	r3
res_m_39_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#223, r0	; check 477
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#224, r0	; check 478
	trap	#1
1:
	movq	=1073901568, r2
	cmp	r6, r2
	beq	1f
	movq	#225, r0	; check 479
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#226, r0	; check 480
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073905664, r3
	lea	res_m_40_load, r4
	movq	#0, r5
ins_m_40_load:
	movq	8(r3), r5
res_m_40_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#227, r0	; check 481
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#228, r0	; check 482
	trap	#1
1:
	lea	ins_m_40_load, r11
	cmp	r6, r11
	beq	1f
	movq	#229, r0	; check 483
	trap	#1
1:
	movq	=1073905672, r2
	cmp	r9, r2
	beq	1f
	movq	#230, r0	; check 484
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073905664, r3
	lea	res_m_40_store, r4
	movq	#0x1234, r5
ins_m_40_store:
	movq	r5, 8(r3)
res_m_40_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#231, r0	; check 485
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#232, r0	; check 486
	trap	#1
1:
	lea	ins_m_40_store, r11
	cmp	r6, r11
	beq	1f
	movq	#233, r0	; check 487
	trap	#1
1:
	movq	=1073905672, r2
	cmp	r9, r2
	beq	1f
	movq	#234, r0	; check 488
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073905664, r3
	lea	res_m_40_fetch, r4
ins_m_40_fetch:
	call	r3
res_m_40_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#235, r0	; check 489
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#236, r0	; check 490
	trap	#1
1:
	movq	=1073905664, r2
	cmp	r6, r2
	beq	1f
	movq	#237, r0	; check 491
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#238, r0	; check 492
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073909760, r3
	lea	res_m_41_load, r4
	movq	#0, r5
ins_m_41_load:
	movq	8(r3), r5
res_m_41_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#239, r0	; check 493
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#240, r0	; check 494
	trap	#1
1:
	lea	ins_m_41_load, r11
	cmp	r6, r11
	beq	1f
	movq	#241, r0	; check 495
	trap	#1
1:
	movq	=1073909768, r2
	cmp	r9, r2
	beq	1f
	movq	#242, r0	; check 496
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073909760, r3
	lea	res_m_41_store, r4
	movq	#0x1234, r5
ins_m_41_store:
	movq	r5, 8(r3)
res_m_41_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#243, r0	; check 497
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#244, r0	; check 498
	trap	#1
1:
	lea	ins_m_41_store, r11
	cmp	r6, r11
	beq	1f
	movq	#245, r0	; check 499
	trap	#1
1:
	movq	=1073909768, r2
	cmp	r9, r2
	beq	1f
	movq	#246, r0	; check 500
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073909760, r3
	lea	res_m_41_fetch, r4
ins_m_41_fetch:
	call	r3
res_m_41_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#247, r0	; check 501
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#248, r0	; check 502
	trap	#1
1:
	movq	=1073909760, r2
	cmp	r6, r2
	beq	1f
	movq	#249, r0	; check 503
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#250, r0	; check 504
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073913856, r3
	lea	res_m_42_load, r4
	movq	#0, r5
ins_m_42_load:
	movq	8(r3), r5
res_m_42_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#251, r0	; check 505
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#252, r0	; check 506
	trap	#1
1:
	lea	ins_m_42_load, r11
	cmp	r6, r11
	beq	1f
	movq	#253, r0	; check 507
	trap	#1
1:
	movq	=1073913864, r2
	cmp	r9, r2
	beq	1f
	movq	#254, r0	; check 508
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073913856, r3
	lea	res_m_42_store, r4
	movq	#0x1234, r5
ins_m_42_store:
	movq	r5, 8(r3)
res_m_42_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#255, r0	; check 509
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#1, r0	; check 510
	trap	#1
1:
	lea	ins_m_42_store, r11
	cmp	r6, r11
	beq	1f
	movq	#2, r0	; check 511
	trap	#1
1:
	movq	=1073913864, r2
	cmp	r9, r2
	beq	1f
	movq	#3, r0	; check 512
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073913856, r3
	lea	res_m_42_fetch, r4
ins_m_42_fetch:
	call	r3
res_m_42_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#4, r0	; check 513
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#5, r0	; check 514
	trap	#1
1:
	movq	=1073913856, r2
	cmp	r6, r2
	beq	1f
	movq	#6, r0	; check 515
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#7, r0	; check 516
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073917952, r3
	lea	res_m_43_load, r4
	movq	#0, r5
ins_m_43_load:
	movq	8(r3), r5
res_m_43_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#8, r0	; check 517
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#9, r0	; check 518
	trap	#1
1:
	lea	ins_m_43_load, r11
	cmp	r6, r11
	beq	1f
	movq	#10, r0	; check 519
	trap	#1
1:
	movq	=1073917960, r2
	cmp	r9, r2
	beq	1f
	movq	#11, r0	; check 520
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073917952, r3
	lea	res_m_43_store, r4
	movq	#0x1234, r5
ins_m_43_store:
	movq	r5, 8(r3)
res_m_43_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#12, r0	; check 521
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#13, r0	; check 522
	trap	#1
1:
	lea	ins_m_43_store, r11
	cmp	r6, r11
	beq	1f
	movq	#14, r0	; check 523
	trap	#1
1:
	movq	=1073917960, r2
	cmp	r9, r2
	beq	1f
	movq	#15, r0	; check 524
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073917952, r3
	lea	res_m_43_fetch, r4
ins_m_43_fetch:
	call	r3
res_m_43_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#16, r0	; check 525
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#17, r0	; check 526
	trap	#1
1:
	movq	=1073917952, r2
	cmp	r6, r2
	beq	1f
	movq	#18, r0	; check 527
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#19, r0	; check 528
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073922048, r3
	lea	res_m_44_load, r4
	movq	#0, r5
ins_m_44_load:
	movq	8(r3), r5
res_m_44_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#20, r0	; check 529
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#21, r0	; check 530
	trap	#1
1:
	lea	ins_m_44_load, r11
	cmp	r6, r11
	beq	1f
	movq	#22, r0	; check 531
	trap	#1
1:
	movq	=1073922056, r2
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 532
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073922048, r3
	lea	res_m_44_store, r4
	movq	#0x1234, r5
ins_m_44_store:
	movq	r5, 8(r3)
res_m_44_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#24, r0	; check 533
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#25, r0	; check 534
	trap	#1
1:
	lea	ins_m_44_store, r11
	cmp	r6, r11
	beq	1f
	movq	#26, r0	; check 535
	trap	#1
1:
	movq	=1073922056, r2
	cmp	r9, r2
	beq	1f
	movq	#27, r0	; check 536
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073922048, r3
	lea	res_m_44_fetch, r4
ins_m_44_fetch:
	call	r3
res_m_44_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#28, r0	; check 537
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#29, r0	; check 538
	trap	#1
1:
	movq	=1073922048, r2
	cmp	r6, r2
	beq	1f
	movq	#30, r0	; check 539
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#31, r0	; check 540
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073926144, r3
	lea	res_m_45_load, r4
	movq	#0, r5
ins_m_45_load:
	movq	8(r3), r5
res_m_45_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#32, r0	; check 541
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#33, r0	; check 542
	trap	#1
1:
	lea	ins_m_45_load, r11
	cmp	r6, r11
	beq	1f
	movq	#34, r0	; check 543
	trap	#1
1:
	movq	=1073926152, r2
	cmp	r9, r2
	beq	1f
	movq	#35, r0	; check 544
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073926144, r3
	lea	res_m_45_store, r4
	movq	#0x1234, r5
ins_m_45_store:
	movq	r5, 8(r3)
res_m_45_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#36, r0	; check 545
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#37, r0	; check 546
	trap	#1
1:
	lea	ins_m_45_store, r11
	cmp	r6, r11
	beq	1f
	movq	#38, r0	; check 547
	trap	#1
1:
	movq	=1073926152, r2
	cmp	r9, r2
	beq	1f
	movq	#39, r0	; check 548
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073926144, r3
	lea	res_m_45_fetch, r4
ins_m_45_fetch:
	call	r3
res_m_45_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#40, r0	; check 549
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#41, r0	; check 550
	trap	#1
1:
	movq	=1073926144, r2
	cmp	r6, r2
	beq	1f
	movq	#42, r0	; check 551
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#43, r0	; check 552
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073930240, r3
	lea	res_m_46_load, r4
	movq	#0, r5
ins_m_46_load:
	movq	8(r3), r5
res_m_46_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#44, r0	; check 553
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#45, r0	; check 554
	trap	#1
1:
	lea	ins_m_46_load, r11
	cmp	r6, r11
	beq	1f
	movq	#46, r0	; check 555
	trap	#1
1:
	movq	=1073930248, r2
	cmp	r9, r2
	beq	1f
	movq	#47, r0	; check 556
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073930240, r3
	lea	res_m_46_store, r4
	movq	#0x1234, r5
ins_m_46_store:
	movq	r5, 8(r3)
res_m_46_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#48, r0	; check 557
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#49, r0	; check 558
	trap	#1
1:
	lea	ins_m_46_store, r11
	cmp	r6, r11
	beq	1f
	movq	#50, r0	; check 559
	trap	#1
1:
	movq	=1073930248, r2
	cmp	r9, r2
	beq	1f
	movq	#51, r0	; check 560
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073930240, r3
	lea	res_m_46_fetch, r4
ins_m_46_fetch:
	call	r3
res_m_46_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#52, r0	; check 561
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#53, r0	; check 562
	trap	#1
1:
	movq	=1073930240, r2
	cmp	r6, r2
	beq	1f
	movq	#54, r0	; check 563
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#55, r0	; check 564
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073934336, r3
	lea	res_m_47_load, r4
	movq	#0, r5
ins_m_47_load:
	movq	8(r3), r5
res_m_47_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#56, r0	; check 565
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#57, r0	; check 566
	trap	#1
1:
	lea	ins_m_47_load, r11
	cmp	r6, r11
	beq	1f
	movq	#58, r0	; check 567
	trap	#1
1:
	movq	=1073934344, r2
	cmp	r9, r2
	beq	1f
	movq	#59, r0	; check 568
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073934336, r3
	lea	res_m_47_store, r4
	movq	#0x1234, r5
ins_m_47_store:
	movq	r5, 8(r3)
res_m_47_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#60, r0	; check 569
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#61, r0	; check 570
	trap	#1
1:
	lea	ins_m_47_store, r11
	cmp	r6, r11
	beq	1f
	movq	#62, r0	; check 571
	trap	#1
1:
	movq	=1073934344, r2
	cmp	r9, r2
	beq	1f
	movq	#63, r0	; check 572
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073934336, r3
	lea	res_m_47_fetch, r4
ins_m_47_fetch:
	call	r3
res_m_47_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#64, r0	; check 573
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#65, r0	; check 574
	trap	#1
1:
	movq	=1073934336, r2
	cmp	r6, r2
	beq	1f
	movq	#66, r0	; check 575
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#67, r0	; check 576
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073938432, r3
	lea	res_m_48_load, r4
	movq	#0, r5
ins_m_48_load:
	movq	8(r3), r5
res_m_48_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#68, r0	; check 577
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#69, r0	; check 578
	trap	#1
1:
	lea	ins_m_48_load, r11
	cmp	r6, r11
	beq	1f
	movq	#70, r0	; check 579
	trap	#1
1:
	movq	=1073938440, r2
	cmp	r9, r2
	beq	1f
	movq	#71, r0	; check 580
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073938432, r3
	lea	res_m_48_store, r4
	movq	#0x1234, r5
ins_m_48_store:
	movq	r5, 8(r3)
res_m_48_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#72, r0	; check 581
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#73, r0	; check 582
	trap	#1
1:
	lea	ins_m_48_store, r11
	cmp	r6, r11
	beq	1f
	movq	#74, r0	; check 583
	trap	#1
1:
	movq	=1073938440, r2
	cmp	r9, r2
	beq	1f
	movq	#75, r0	; check 584
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073938432, r3
	lea	res_m_48_fetch, r4
ins_m_48_fetch:
	call	r3
res_m_48_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#76, r0	; check 585
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#77, r0	; check 586
	trap	#1
1:
	movq	=1073938432, r2
	cmp	r6, r2
	beq	1f
	movq	#78, r0	; check 587
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#79, r0	; check 588
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073942528, r3
	lea	res_m_49_load, r4
	movq	#0, r5
ins_m_49_load:
	movq	8(r3), r5
res_m_49_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#80, r0	; check 589
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#81, r0	; check 590
	trap	#1
1:
	lea	ins_m_49_load, r11
	cmp	r6, r11
	beq	1f
	movq	#82, r0	; check 591
	trap	#1
1:
	movq	=1073942536, r2
	cmp	r9, r2
	beq	1f
	movq	#83, r0	; check 592
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073942528, r3
	lea	res_m_49_store, r4
	movq	#0x1234, r5
ins_m_49_store:
	movq	r5, 8(r3)
res_m_49_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#84, r0	; check 593
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#85, r0	; check 594
	trap	#1
1:
	lea	ins_m_49_store, r11
	cmp	r6, r11
	beq	1f
	movq	#86, r0	; check 595
	trap	#1
1:
	movq	=1073942536, r2
	cmp	r9, r2
	beq	1f
	movq	#87, r0	; check 596
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073942528, r3
	lea	res_m_49_fetch, r4
ins_m_49_fetch:
	call	r3
res_m_49_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#88, r0	; check 597
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#89, r0	; check 598
	trap	#1
1:
	movq	=1073942528, r2
	cmp	r6, r2
	beq	1f
	movq	#90, r0	; check 599
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#91, r0	; check 600
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073946624, r3
	lea	res_m_50_load, r4
	movq	#0, r5
ins_m_50_load:
	movq	8(r3), r5
res_m_50_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#92, r0	; check 601
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#93, r0	; check 602
	trap	#1
1:
	lea	ins_m_50_load, r11
	cmp	r6, r11
	beq	1f
	movq	#94, r0	; check 603
	trap	#1
1:
	movq	=1073946632, r2
	cmp	r9, r2
	beq	1f
	movq	#95, r0	; check 604
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073946624, r3
	lea	res_m_50_store, r4
	movq	#0x1234, r5
ins_m_50_store:
	movq	r5, 8(r3)
res_m_50_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#96, r0	; check 605
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#97, r0	; check 606
	trap	#1
1:
	lea	ins_m_50_store, r11
	cmp	r6, r11
	beq	1f
	movq	#98, r0	; check 607
	trap	#1
1:
	movq	=1073946632, r2
	cmp	r9, r2
	beq	1f
	movq	#99, r0	; check 608
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073946624, r3
	lea	res_m_50_fetch, r4
ins_m_50_fetch:
	call	r3
res_m_50_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#100, r0	; check 609
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#101, r0	; check 610
	trap	#1
1:
	movq	=1073946624, r2
	cmp	r6, r2
	beq	1f
	movq	#102, r0	; check 611
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#103, r0	; check 612
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073950720, r3
	lea	res_m_51_load, r4
	movq	#0, r5
ins_m_51_load:
	movq	8(r3), r5
res_m_51_load:
	cmp	r10, #(0)
	beq	1f
	movq	#104, r0	; check 613
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#105, r0	; check 614
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073950720, r3
	lea	res_m_51_store, r4
	movq	#0x1234, r5
ins_m_51_store:
	movq	r5, 8(r3)
res_m_51_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#106, r0	; check 615
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#107, r0	; check 616
	trap	#1
1:
	lea	ins_m_51_store, r11
	cmp	r6, r11
	beq	1f
	movq	#108, r0	; check 617
	trap	#1
1:
	movq	=1073950728, r2
	cmp	r9, r2
	beq	1f
	movq	#109, r0	; check 618
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073950720, r3
	lea	res_m_51_fetch, r4
ins_m_51_fetch:
	call	r3
res_m_51_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#110, r0	; check 619
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#111, r0	; check 620
	trap	#1
1:
	movq	=1073950720, r2
	cmp	r6, r2
	beq	1f
	movq	#112, r0	; check 621
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#113, r0	; check 622
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073954816, r3
	lea	res_m_52_load, r4
	movq	#0, r5
ins_m_52_load:
	movq	8(r3), r5
res_m_52_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#114, r0	; check 623
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#115, r0	; check 624
	trap	#1
1:
	lea	ins_m_52_load, r11
	cmp	r6, r11
	beq	1f
	movq	#116, r0	; check 625
	trap	#1
1:
	movq	=1073954824, r2
	cmp	r9, r2
	beq	1f
	movq	#117, r0	; check 626
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073954816, r3
	lea	res_m_52_store, r4
	movq	#0x1234, r5
ins_m_52_store:
	movq	r5, 8(r3)
res_m_52_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#118, r0	; check 627
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#119, r0	; check 628
	trap	#1
1:
	lea	ins_m_52_store, r11
	cmp	r6, r11
	beq	1f
	movq	#120, r0	; check 629
	trap	#1
1:
	movq	=1073954824, r2
	cmp	r9, r2
	beq	1f
	movq	#121, r0	; check 630
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073954816, r3
	lea	res_m_52_fetch, r4
ins_m_52_fetch:
	call	r3
res_m_52_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#122, r0	; check 631
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#123, r0	; check 632
	trap	#1
1:
	movq	=1073954816, r2
	cmp	r6, r2
	beq	1f
	movq	#124, r0	; check 633
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#125, r0	; check 634
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073958912, r3
	lea	res_m_53_load, r4
	movq	#0, r5
ins_m_53_load:
	movq	8(r3), r5
res_m_53_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#126, r0	; check 635
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#127, r0	; check 636
	trap	#1
1:
	lea	ins_m_53_load, r11
	cmp	r6, r11
	beq	1f
	movq	#128, r0	; check 637
	trap	#1
1:
	movq	=1073958920, r2
	cmp	r9, r2
	beq	1f
	movq	#129, r0	; check 638
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073958912, r3
	lea	res_m_53_store, r4
	movq	#0x1234, r5
ins_m_53_store:
	movq	r5, 8(r3)
res_m_53_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#130, r0	; check 639
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#131, r0	; check 640
	trap	#1
1:
	lea	ins_m_53_store, r11
	cmp	r6, r11
	beq	1f
	movq	#132, r0	; check 641
	trap	#1
1:
	movq	=1073958920, r2
	cmp	r9, r2
	beq	1f
	movq	#133, r0	; check 642
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073958912, r3
	lea	res_m_53_fetch, r4
ins_m_53_fetch:
	call	r3
res_m_53_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#134, r0	; check 643
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#135, r0	; check 644
	trap	#1
1:
	movq	=1073958912, r2
	cmp	r6, r2
	beq	1f
	movq	#136, r0	; check 645
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#137, r0	; check 646
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073963008, r3
	lea	res_m_54_load, r4
	movq	#0, r5
ins_m_54_load:
	movq	8(r3), r5
res_m_54_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#138, r0	; check 647
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#139, r0	; check 648
	trap	#1
1:
	lea	ins_m_54_load, r11
	cmp	r6, r11
	beq	1f
	movq	#140, r0	; check 649
	trap	#1
1:
	movq	=1073963016, r2
	cmp	r9, r2
	beq	1f
	movq	#141, r0	; check 650
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073963008, r3
	lea	res_m_54_store, r4
	movq	#0x1234, r5
ins_m_54_store:
	movq	r5, 8(r3)
res_m_54_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#142, r0	; check 651
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#143, r0	; check 652
	trap	#1
1:
	lea	ins_m_54_store, r11
	cmp	r6, r11
	beq	1f
	movq	#144, r0	; check 653
	trap	#1
1:
	movq	=1073963016, r2
	cmp	r9, r2
	beq	1f
	movq	#145, r0	; check 654
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073963008, r3
	lea	res_m_54_fetch, r4
ins_m_54_fetch:
	call	r3
res_m_54_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#146, r0	; check 655
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#147, r0	; check 656
	trap	#1
1:
	movq	=1073963008, r2
	cmp	r6, r2
	beq	1f
	movq	#148, r0	; check 657
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#149, r0	; check 658
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073967104, r3
	lea	res_m_55_load, r4
	movq	#0, r5
ins_m_55_load:
	movq	8(r3), r5
res_m_55_load:
	cmp	r10, #(0)
	beq	1f
	movq	#150, r0	; check 659
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#151, r0	; check 660
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073967104, r3
	lea	res_m_55_store, r4
	movq	#0x1234, r5
ins_m_55_store:
	movq	r5, 8(r3)
res_m_55_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#152, r0	; check 661
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#153, r0	; check 662
	trap	#1
1:
	lea	ins_m_55_store, r11
	cmp	r6, r11
	beq	1f
	movq	#154, r0	; check 663
	trap	#1
1:
	movq	=1073967112, r2
	cmp	r9, r2
	beq	1f
	movq	#155, r0	; check 664
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073967104, r3
	lea	res_m_55_fetch, r4
ins_m_55_fetch:
	call	r3
res_m_55_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#156, r0	; check 665
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#157, r0	; check 666
	trap	#1
1:
	movq	=1073967104, r2
	cmp	r6, r2
	beq	1f
	movq	#158, r0	; check 667
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#159, r0	; check 668
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073971200, r3
	lea	res_m_56_load, r4
	movq	#0, r5
ins_m_56_load:
	movq	8(r3), r5
res_m_56_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#160, r0	; check 669
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#161, r0	; check 670
	trap	#1
1:
	lea	ins_m_56_load, r11
	cmp	r6, r11
	beq	1f
	movq	#162, r0	; check 671
	trap	#1
1:
	movq	=1073971208, r2
	cmp	r9, r2
	beq	1f
	movq	#163, r0	; check 672
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073971200, r3
	lea	res_m_56_store, r4
	movq	#0x1234, r5
ins_m_56_store:
	movq	r5, 8(r3)
res_m_56_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#164, r0	; check 673
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#165, r0	; check 674
	trap	#1
1:
	lea	ins_m_56_store, r11
	cmp	r6, r11
	beq	1f
	movq	#166, r0	; check 675
	trap	#1
1:
	movq	=1073971208, r2
	cmp	r9, r2
	beq	1f
	movq	#167, r0	; check 676
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073971200, r3
	lea	res_m_56_fetch, r4
ins_m_56_fetch:
	call	r3
res_m_56_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#168, r0	; check 677
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#169, r0	; check 678
	trap	#1
1:
	movq	=1073971200, r2
	cmp	r6, r2
	beq	1f
	movq	#170, r0	; check 679
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#171, r0	; check 680
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073975296, r3
	lea	res_m_57_load, r4
	movq	#0, r5
ins_m_57_load:
	movq	8(r3), r5
res_m_57_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#172, r0	; check 681
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#173, r0	; check 682
	trap	#1
1:
	lea	ins_m_57_load, r11
	cmp	r6, r11
	beq	1f
	movq	#174, r0	; check 683
	trap	#1
1:
	movq	=1073975304, r2
	cmp	r9, r2
	beq	1f
	movq	#175, r0	; check 684
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073975296, r3
	lea	res_m_57_store, r4
	movq	#0x1234, r5
ins_m_57_store:
	movq	r5, 8(r3)
res_m_57_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#176, r0	; check 685
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#177, r0	; check 686
	trap	#1
1:
	lea	ins_m_57_store, r11
	cmp	r6, r11
	beq	1f
	movq	#178, r0	; check 687
	trap	#1
1:
	movq	=1073975304, r2
	cmp	r9, r2
	beq	1f
	movq	#179, r0	; check 688
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073975296, r3
	lea	res_m_57_fetch, r4
ins_m_57_fetch:
	call	r3
res_m_57_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#180, r0	; check 689
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073979392, r3
	lea	res_m_58_load, r4
	movq	#0, r5
ins_m_58_load:
	movq	8(r3), r5
res_m_58_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#181, r0	; check 690
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#182, r0	; check 691
	trap	#1
1:
	lea	ins_m_58_load, r11
	cmp	r6, r11
	beq	1f
	movq	#183, r0	; check 692
	trap	#1
1:
	movq	=1073979400, r2
	cmp	r9, r2
	beq	1f
	movq	#184, r0	; check 693
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073979392, r3
	lea	res_m_58_store, r4
	movq	#0x1234, r5
ins_m_58_store:
	movq	r5, 8(r3)
res_m_58_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#185, r0	; check 694
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#186, r0	; check 695
	trap	#1
1:
	lea	ins_m_58_store, r11
	cmp	r6, r11
	beq	1f
	movq	#187, r0	; check 696
	trap	#1
1:
	movq	=1073979400, r2
	cmp	r9, r2
	beq	1f
	movq	#188, r0	; check 697
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073979392, r3
	lea	res_m_58_fetch, r4
ins_m_58_fetch:
	call	r3
res_m_58_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#189, r0	; check 698
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#190, r0	; check 699
	trap	#1
1:
	movq	=1073979392, r2
	cmp	r6, r2
	beq	1f
	movq	#191, r0	; check 700
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#192, r0	; check 701
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073983488, r3
	lea	res_m_59_load, r4
	movq	#0, r5
ins_m_59_load:
	movq	8(r3), r5
res_m_59_load:
	cmp	r10, #(0)
	beq	1f
	movq	#193, r0	; check 702
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#194, r0	; check 703
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073983488, r3
	lea	res_m_59_store, r4
	movq	#0x1234, r5
ins_m_59_store:
	movq	r5, 8(r3)
res_m_59_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#195, r0	; check 704
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#196, r0	; check 705
	trap	#1
1:
	lea	ins_m_59_store, r11
	cmp	r6, r11
	beq	1f
	movq	#197, r0	; check 706
	trap	#1
1:
	movq	=1073983496, r2
	cmp	r9, r2
	beq	1f
	movq	#198, r0	; check 707
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073983488, r3
	lea	res_m_59_fetch, r4
ins_m_59_fetch:
	call	r3
res_m_59_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#199, r0	; check 708
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073987584, r3
	lea	res_m_60_load, r4
	movq	#0, r5
ins_m_60_load:
	movq	8(r3), r5
res_m_60_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#200, r0	; check 709
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#201, r0	; check 710
	trap	#1
1:
	lea	ins_m_60_load, r11
	cmp	r6, r11
	beq	1f
	movq	#202, r0	; check 711
	trap	#1
1:
	movq	=1073987592, r2
	cmp	r9, r2
	beq	1f
	movq	#203, r0	; check 712
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073987584, r3
	lea	res_m_60_store, r4
	movq	#0x1234, r5
ins_m_60_store:
	movq	r5, 8(r3)
res_m_60_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#204, r0	; check 713
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#205, r0	; check 714
	trap	#1
1:
	lea	ins_m_60_store, r11
	cmp	r6, r11
	beq	1f
	movq	#206, r0	; check 715
	trap	#1
1:
	movq	=1073987592, r2
	cmp	r9, r2
	beq	1f
	movq	#207, r0	; check 716
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073987584, r3
	lea	res_m_60_fetch, r4
ins_m_60_fetch:
	call	r3
res_m_60_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#208, r0	; check 717
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#209, r0	; check 718
	trap	#1
1:
	movq	=1073987584, r2
	cmp	r6, r2
	beq	1f
	movq	#210, r0	; check 719
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#211, r0	; check 720
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073991680, r3
	lea	res_m_61_load, r4
	movq	#0, r5
ins_m_61_load:
	movq	8(r3), r5
res_m_61_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#212, r0	; check 721
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#213, r0	; check 722
	trap	#1
1:
	lea	ins_m_61_load, r11
	cmp	r6, r11
	beq	1f
	movq	#214, r0	; check 723
	trap	#1
1:
	movq	=1073991688, r2
	cmp	r9, r2
	beq	1f
	movq	#215, r0	; check 724
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073991680, r3
	lea	res_m_61_store, r4
	movq	#0x1234, r5
ins_m_61_store:
	movq	r5, 8(r3)
res_m_61_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#216, r0	; check 725
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#217, r0	; check 726
	trap	#1
1:
	lea	ins_m_61_store, r11
	cmp	r6, r11
	beq	1f
	movq	#218, r0	; check 727
	trap	#1
1:
	movq	=1073991688, r2
	cmp	r9, r2
	beq	1f
	movq	#219, r0	; check 728
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073991680, r3
	lea	res_m_61_fetch, r4
ins_m_61_fetch:
	call	r3
res_m_61_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#220, r0	; check 729
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#221, r0	; check 730
	trap	#1
1:
	movq	=1073991680, r2
	cmp	r6, r2
	beq	1f
	movq	#222, r0	; check 731
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#223, r0	; check 732
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073995776, r3
	lea	res_m_62_load, r4
	movq	#0, r5
ins_m_62_load:
	movq	8(r3), r5
res_m_62_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#224, r0	; check 733
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#225, r0	; check 734
	trap	#1
1:
	lea	ins_m_62_load, r11
	cmp	r6, r11
	beq	1f
	movq	#226, r0	; check 735
	trap	#1
1:
	movq	=1073995784, r2
	cmp	r9, r2
	beq	1f
	movq	#227, r0	; check 736
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073995776, r3
	lea	res_m_62_store, r4
	movq	#0x1234, r5
ins_m_62_store:
	movq	r5, 8(r3)
res_m_62_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#228, r0	; check 737
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#229, r0	; check 738
	trap	#1
1:
	lea	ins_m_62_store, r11
	cmp	r6, r11
	beq	1f
	movq	#230, r0	; check 739
	trap	#1
1:
	movq	=1073995784, r2
	cmp	r9, r2
	beq	1f
	movq	#231, r0	; check 740
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073995776, r3
	lea	res_m_62_fetch, r4
ins_m_62_fetch:
	call	r3
res_m_62_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#232, r0	; check 741
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#233, r0	; check 742
	trap	#1
1:
	movq	=1073995776, r2
	cmp	r6, r2
	beq	1f
	movq	#234, r0	; check 743
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#235, r0	; check 744
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073999872, r3
	lea	res_m_63_load, r4
	movq	#0, r5
ins_m_63_load:
	movq	8(r3), r5
res_m_63_load:
	cmp	r10, #(0)
	beq	1f
	movq	#236, r0	; check 745
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#237, r0	; check 746
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073999872, r3
	lea	res_m_63_store, r4
	movq	#0x1234, r5
ins_m_63_store:
	movq	r5, 8(r3)
res_m_63_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#238, r0	; check 747
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#239, r0	; check 748
	trap	#1
1:
	lea	ins_m_63_store, r11
	cmp	r6, r11
	beq	1f
	movq	#240, r0	; check 749
	trap	#1
1:
	movq	=1073999880, r2
	cmp	r9, r2
	beq	1f
	movq	#241, r0	; check 750
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073999872, r3
	lea	res_m_63_fetch, r4
ins_m_63_fetch:
	call	r3
res_m_63_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#242, r0	; check 751
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074003968, r3
	lea	res_m_64_load, r4
	movq	#0, r5
ins_m_64_load:
	movq	8(r3), r5
res_m_64_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#243, r0	; check 752
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#244, r0	; check 753
	trap	#1
1:
	lea	ins_m_64_load, r11
	cmp	r6, r11
	beq	1f
	movq	#245, r0	; check 754
	trap	#1
1:
	movq	=1074003976, r2
	cmp	r9, r2
	beq	1f
	movq	#246, r0	; check 755
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074003968, r3
	lea	res_m_64_store, r4
	movq	#0x1234, r5
ins_m_64_store:
	movq	r5, 8(r3)
res_m_64_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#247, r0	; check 756
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#248, r0	; check 757
	trap	#1
1:
	lea	ins_m_64_store, r11
	cmp	r6, r11
	beq	1f
	movq	#249, r0	; check 758
	trap	#1
1:
	movq	=1074003976, r2
	cmp	r9, r2
	beq	1f
	movq	#250, r0	; check 759
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074003968, r3
	lea	res_m_64_fetch, r4
ins_m_64_fetch:
	call	r3
res_m_64_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#251, r0	; check 760
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#252, r0	; check 761
	trap	#1
1:
	movq	=1074003968, r2
	cmp	r6, r2
	beq	1f
	movq	#253, r0	; check 762
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#254, r0	; check 763
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074008064, r3
	lea	res_m_65_load, r4
	movq	#0, r5
ins_m_65_load:
	movq	8(r3), r5
res_m_65_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#255, r0	; check 764
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#1, r0	; check 765
	trap	#1
1:
	lea	ins_m_65_load, r11
	cmp	r6, r11
	beq	1f
	movq	#2, r0	; check 766
	trap	#1
1:
	movq	=1074008072, r2
	cmp	r9, r2
	beq	1f
	movq	#3, r0	; check 767
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074008064, r3
	lea	res_m_65_store, r4
	movq	#0x1234, r5
ins_m_65_store:
	movq	r5, 8(r3)
res_m_65_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#4, r0	; check 768
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#5, r0	; check 769
	trap	#1
1:
	lea	ins_m_65_store, r11
	cmp	r6, r11
	beq	1f
	movq	#6, r0	; check 770
	trap	#1
1:
	movq	=1074008072, r2
	cmp	r9, r2
	beq	1f
	movq	#7, r0	; check 771
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074008064, r3
	lea	res_m_65_fetch, r4
ins_m_65_fetch:
	call	r3
res_m_65_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#8, r0	; check 772
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#9, r0	; check 773
	trap	#1
1:
	movq	=1074008064, r2
	cmp	r6, r2
	beq	1f
	movq	#10, r0	; check 774
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#11, r0	; check 775
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074012160, r3
	lea	res_m_66_load, r4
	movq	#0, r5
ins_m_66_load:
	movq	8(r3), r5
res_m_66_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#12, r0	; check 776
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#13, r0	; check 777
	trap	#1
1:
	lea	ins_m_66_load, r11
	cmp	r6, r11
	beq	1f
	movq	#14, r0	; check 778
	trap	#1
1:
	movq	=1074012168, r2
	cmp	r9, r2
	beq	1f
	movq	#15, r0	; check 779
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074012160, r3
	lea	res_m_66_store, r4
	movq	#0x1234, r5
ins_m_66_store:
	movq	r5, 8(r3)
res_m_66_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#16, r0	; check 780
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#17, r0	; check 781
	trap	#1
1:
	lea	ins_m_66_store, r11
	cmp	r6, r11
	beq	1f
	movq	#18, r0	; check 782
	trap	#1
1:
	movq	=1074012168, r2
	cmp	r9, r2
	beq	1f
	movq	#19, r0	; check 783
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074012160, r3
	lea	res_m_66_fetch, r4
ins_m_66_fetch:
	call	r3
res_m_66_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#20, r0	; check 784
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#21, r0	; check 785
	trap	#1
1:
	movq	=1074012160, r2
	cmp	r6, r2
	beq	1f
	movq	#22, r0	; check 786
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 787
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074016256, r3
	lea	res_m_67_load, r4
	movq	#0, r5
ins_m_67_load:
	movq	8(r3), r5
res_m_67_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#24, r0	; check 788
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#25, r0	; check 789
	trap	#1
1:
	lea	ins_m_67_load, r11
	cmp	r6, r11
	beq	1f
	movq	#26, r0	; check 790
	trap	#1
1:
	movq	=1074016264, r2
	cmp	r9, r2
	beq	1f
	movq	#27, r0	; check 791
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074016256, r3
	lea	res_m_67_store, r4
	movq	#0x1234, r5
ins_m_67_store:
	movq	r5, 8(r3)
res_m_67_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#28, r0	; check 792
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#29, r0	; check 793
	trap	#1
1:
	lea	ins_m_67_store, r11
	cmp	r6, r11
	beq	1f
	movq	#30, r0	; check 794
	trap	#1
1:
	movq	=1074016264, r2
	cmp	r9, r2
	beq	1f
	movq	#31, r0	; check 795
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074016256, r3
	lea	res_m_67_fetch, r4
ins_m_67_fetch:
	call	r3
res_m_67_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#32, r0	; check 796
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#33, r0	; check 797
	trap	#1
1:
	movq	=1074016256, r2
	cmp	r6, r2
	beq	1f
	movq	#34, r0	; check 798
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#35, r0	; check 799
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074020352, r3
	lea	res_m_68_load, r4
	movq	#0, r5
ins_m_68_load:
	movq	8(r3), r5
res_m_68_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#36, r0	; check 800
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#37, r0	; check 801
	trap	#1
1:
	lea	ins_m_68_load, r11
	cmp	r6, r11
	beq	1f
	movq	#38, r0	; check 802
	trap	#1
1:
	movq	=1074020360, r2
	cmp	r9, r2
	beq	1f
	movq	#39, r0	; check 803
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074020352, r3
	lea	res_m_68_store, r4
	movq	#0x1234, r5
ins_m_68_store:
	movq	r5, 8(r3)
res_m_68_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#40, r0	; check 804
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#41, r0	; check 805
	trap	#1
1:
	lea	ins_m_68_store, r11
	cmp	r6, r11
	beq	1f
	movq	#42, r0	; check 806
	trap	#1
1:
	movq	=1074020360, r2
	cmp	r9, r2
	beq	1f
	movq	#43, r0	; check 807
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074020352, r3
	lea	res_m_68_fetch, r4
ins_m_68_fetch:
	call	r3
res_m_68_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#44, r0	; check 808
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#45, r0	; check 809
	trap	#1
1:
	movq	=1074020352, r2
	cmp	r6, r2
	beq	1f
	movq	#46, r0	; check 810
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#47, r0	; check 811
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074024448, r3
	lea	res_m_69_load, r4
	movq	#0, r5
ins_m_69_load:
	movq	8(r3), r5
res_m_69_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#48, r0	; check 812
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#49, r0	; check 813
	trap	#1
1:
	lea	ins_m_69_load, r11
	cmp	r6, r11
	beq	1f
	movq	#50, r0	; check 814
	trap	#1
1:
	movq	=1074024456, r2
	cmp	r9, r2
	beq	1f
	movq	#51, r0	; check 815
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074024448, r3
	lea	res_m_69_store, r4
	movq	#0x1234, r5
ins_m_69_store:
	movq	r5, 8(r3)
res_m_69_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#52, r0	; check 816
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#53, r0	; check 817
	trap	#1
1:
	lea	ins_m_69_store, r11
	cmp	r6, r11
	beq	1f
	movq	#54, r0	; check 818
	trap	#1
1:
	movq	=1074024456, r2
	cmp	r9, r2
	beq	1f
	movq	#55, r0	; check 819
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074024448, r3
	lea	res_m_69_fetch, r4
ins_m_69_fetch:
	call	r3
res_m_69_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#56, r0	; check 820
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#57, r0	; check 821
	trap	#1
1:
	movq	=1074024448, r2
	cmp	r6, r2
	beq	1f
	movq	#58, r0	; check 822
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#59, r0	; check 823
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074028544, r3
	lea	res_m_70_load, r4
	movq	#0, r5
ins_m_70_load:
	movq	8(r3), r5
res_m_70_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#60, r0	; check 824
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#61, r0	; check 825
	trap	#1
1:
	lea	ins_m_70_load, r11
	cmp	r6, r11
	beq	1f
	movq	#62, r0	; check 826
	trap	#1
1:
	movq	=1074028552, r2
	cmp	r9, r2
	beq	1f
	movq	#63, r0	; check 827
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074028544, r3
	lea	res_m_70_store, r4
	movq	#0x1234, r5
ins_m_70_store:
	movq	r5, 8(r3)
res_m_70_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#64, r0	; check 828
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#65, r0	; check 829
	trap	#1
1:
	lea	ins_m_70_store, r11
	cmp	r6, r11
	beq	1f
	movq	#66, r0	; check 830
	trap	#1
1:
	movq	=1074028552, r2
	cmp	r9, r2
	beq	1f
	movq	#67, r0	; check 831
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074028544, r3
	lea	res_m_70_fetch, r4
ins_m_70_fetch:
	call	r3
res_m_70_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#68, r0	; check 832
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#69, r0	; check 833
	trap	#1
1:
	movq	=1074028544, r2
	cmp	r6, r2
	beq	1f
	movq	#70, r0	; check 834
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#71, r0	; check 835
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074032640, r3
	lea	res_m_71_load, r4
	movq	#0, r5
ins_m_71_load:
	movq	8(r3), r5
res_m_71_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#72, r0	; check 836
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#73, r0	; check 837
	trap	#1
1:
	lea	ins_m_71_load, r11
	cmp	r6, r11
	beq	1f
	movq	#74, r0	; check 838
	trap	#1
1:
	movq	=1074032648, r2
	cmp	r9, r2
	beq	1f
	movq	#75, r0	; check 839
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074032640, r3
	lea	res_m_71_store, r4
	movq	#0x1234, r5
ins_m_71_store:
	movq	r5, 8(r3)
res_m_71_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#76, r0	; check 840
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#77, r0	; check 841
	trap	#1
1:
	lea	ins_m_71_store, r11
	cmp	r6, r11
	beq	1f
	movq	#78, r0	; check 842
	trap	#1
1:
	movq	=1074032648, r2
	cmp	r9, r2
	beq	1f
	movq	#79, r0	; check 843
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074032640, r3
	lea	res_m_71_fetch, r4
ins_m_71_fetch:
	call	r3
res_m_71_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#80, r0	; check 844
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#81, r0	; check 845
	trap	#1
1:
	movq	=1074032640, r2
	cmp	r6, r2
	beq	1f
	movq	#82, r0	; check 846
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#83, r0	; check 847
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074036736, r3
	lea	res_m_72_load, r4
	movq	#0, r5
ins_m_72_load:
	movq	8(r3), r5
res_m_72_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#84, r0	; check 848
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#85, r0	; check 849
	trap	#1
1:
	lea	ins_m_72_load, r11
	cmp	r6, r11
	beq	1f
	movq	#86, r0	; check 850
	trap	#1
1:
	movq	=1074036744, r2
	cmp	r9, r2
	beq	1f
	movq	#87, r0	; check 851
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074036736, r3
	lea	res_m_72_store, r4
	movq	#0x1234, r5
ins_m_72_store:
	movq	r5, 8(r3)
res_m_72_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#88, r0	; check 852
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#89, r0	; check 853
	trap	#1
1:
	lea	ins_m_72_store, r11
	cmp	r6, r11
	beq	1f
	movq	#90, r0	; check 854
	trap	#1
1:
	movq	=1074036744, r2
	cmp	r9, r2
	beq	1f
	movq	#91, r0	; check 855
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074036736, r3
	lea	res_m_72_fetch, r4
ins_m_72_fetch:
	call	r3
res_m_72_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#92, r0	; check 856
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#93, r0	; check 857
	trap	#1
1:
	movq	=1074036736, r2
	cmp	r6, r2
	beq	1f
	movq	#94, r0	; check 858
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#95, r0	; check 859
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074040832, r3
	lea	res_m_73_load, r4
	movq	#0, r5
ins_m_73_load:
	movq	8(r3), r5
res_m_73_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#96, r0	; check 860
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#97, r0	; check 861
	trap	#1
1:
	lea	ins_m_73_load, r11
	cmp	r6, r11
	beq	1f
	movq	#98, r0	; check 862
	trap	#1
1:
	movq	=1074040840, r2
	cmp	r9, r2
	beq	1f
	movq	#99, r0	; check 863
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074040832, r3
	lea	res_m_73_store, r4
	movq	#0x1234, r5
ins_m_73_store:
	movq	r5, 8(r3)
res_m_73_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#100, r0	; check 864
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#101, r0	; check 865
	trap	#1
1:
	lea	ins_m_73_store, r11
	cmp	r6, r11
	beq	1f
	movq	#102, r0	; check 866
	trap	#1
1:
	movq	=1074040840, r2
	cmp	r9, r2
	beq	1f
	movq	#103, r0	; check 867
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074040832, r3
	lea	res_m_73_fetch, r4
ins_m_73_fetch:
	call	r3
res_m_73_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#104, r0	; check 868
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#105, r0	; check 869
	trap	#1
1:
	movq	=1074040832, r2
	cmp	r6, r2
	beq	1f
	movq	#106, r0	; check 870
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#107, r0	; check 871
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074044928, r3
	lea	res_m_74_load, r4
	movq	#0, r5
ins_m_74_load:
	movq	8(r3), r5
res_m_74_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#108, r0	; check 872
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#109, r0	; check 873
	trap	#1
1:
	lea	ins_m_74_load, r11
	cmp	r6, r11
	beq	1f
	movq	#110, r0	; check 874
	trap	#1
1:
	movq	=1074044936, r2
	cmp	r9, r2
	beq	1f
	movq	#111, r0	; check 875
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074044928, r3
	lea	res_m_74_store, r4
	movq	#0x1234, r5
ins_m_74_store:
	movq	r5, 8(r3)
res_m_74_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#112, r0	; check 876
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#113, r0	; check 877
	trap	#1
1:
	lea	ins_m_74_store, r11
	cmp	r6, r11
	beq	1f
	movq	#114, r0	; check 878
	trap	#1
1:
	movq	=1074044936, r2
	cmp	r9, r2
	beq	1f
	movq	#115, r0	; check 879
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074044928, r3
	lea	res_m_74_fetch, r4
ins_m_74_fetch:
	call	r3
res_m_74_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#116, r0	; check 880
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#117, r0	; check 881
	trap	#1
1:
	movq	=1074044928, r2
	cmp	r6, r2
	beq	1f
	movq	#118, r0	; check 882
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#119, r0	; check 883
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074049024, r3
	lea	res_m_75_load, r4
	movq	#0, r5
ins_m_75_load:
	movq	8(r3), r5
res_m_75_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#120, r0	; check 884
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#121, r0	; check 885
	trap	#1
1:
	lea	ins_m_75_load, r11
	cmp	r6, r11
	beq	1f
	movq	#122, r0	; check 886
	trap	#1
1:
	movq	=1074049032, r2
	cmp	r9, r2
	beq	1f
	movq	#123, r0	; check 887
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074049024, r3
	lea	res_m_75_store, r4
	movq	#0x1234, r5
ins_m_75_store:
	movq	r5, 8(r3)
res_m_75_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#124, r0	; check 888
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#125, r0	; check 889
	trap	#1
1:
	lea	ins_m_75_store, r11
	cmp	r6, r11
	beq	1f
	movq	#126, r0	; check 890
	trap	#1
1:
	movq	=1074049032, r2
	cmp	r9, r2
	beq	1f
	movq	#127, r0	; check 891
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074049024, r3
	lea	res_m_75_fetch, r4
ins_m_75_fetch:
	call	r3
res_m_75_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#128, r0	; check 892
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#129, r0	; check 893
	trap	#1
1:
	movq	=1074049024, r2
	cmp	r6, r2
	beq	1f
	movq	#130, r0	; check 894
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#131, r0	; check 895
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074053120, r3
	lea	res_m_76_load, r4
	movq	#0, r5
ins_m_76_load:
	movq	8(r3), r5
res_m_76_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#132, r0	; check 896
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#133, r0	; check 897
	trap	#1
1:
	lea	ins_m_76_load, r11
	cmp	r6, r11
	beq	1f
	movq	#134, r0	; check 898
	trap	#1
1:
	movq	=1074053128, r2
	cmp	r9, r2
	beq	1f
	movq	#135, r0	; check 899
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074053120, r3
	lea	res_m_76_store, r4
	movq	#0x1234, r5
ins_m_76_store:
	movq	r5, 8(r3)
res_m_76_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#136, r0	; check 900
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#137, r0	; check 901
	trap	#1
1:
	lea	ins_m_76_store, r11
	cmp	r6, r11
	beq	1f
	movq	#138, r0	; check 902
	trap	#1
1:
	movq	=1074053128, r2
	cmp	r9, r2
	beq	1f
	movq	#139, r0	; check 903
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074053120, r3
	lea	res_m_76_fetch, r4
ins_m_76_fetch:
	call	r3
res_m_76_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#140, r0	; check 904
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#141, r0	; check 905
	trap	#1
1:
	movq	=1074053120, r2
	cmp	r6, r2
	beq	1f
	movq	#142, r0	; check 906
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#143, r0	; check 907
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074057216, r3
	lea	res_m_77_load, r4
	movq	#0, r5
ins_m_77_load:
	movq	8(r3), r5
res_m_77_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#144, r0	; check 908
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#145, r0	; check 909
	trap	#1
1:
	lea	ins_m_77_load, r11
	cmp	r6, r11
	beq	1f
	movq	#146, r0	; check 910
	trap	#1
1:
	movq	=1074057224, r2
	cmp	r9, r2
	beq	1f
	movq	#147, r0	; check 911
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074057216, r3
	lea	res_m_77_store, r4
	movq	#0x1234, r5
ins_m_77_store:
	movq	r5, 8(r3)
res_m_77_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#148, r0	; check 912
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#149, r0	; check 913
	trap	#1
1:
	lea	ins_m_77_store, r11
	cmp	r6, r11
	beq	1f
	movq	#150, r0	; check 914
	trap	#1
1:
	movq	=1074057224, r2
	cmp	r9, r2
	beq	1f
	movq	#151, r0	; check 915
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074057216, r3
	lea	res_m_77_fetch, r4
ins_m_77_fetch:
	call	r3
res_m_77_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#152, r0	; check 916
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#153, r0	; check 917
	trap	#1
1:
	movq	=1074057216, r2
	cmp	r6, r2
	beq	1f
	movq	#154, r0	; check 918
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#155, r0	; check 919
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074061312, r3
	lea	res_m_78_load, r4
	movq	#0, r5
ins_m_78_load:
	movq	8(r3), r5
res_m_78_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#156, r0	; check 920
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#157, r0	; check 921
	trap	#1
1:
	lea	ins_m_78_load, r11
	cmp	r6, r11
	beq	1f
	movq	#158, r0	; check 922
	trap	#1
1:
	movq	=1074061320, r2
	cmp	r9, r2
	beq	1f
	movq	#159, r0	; check 923
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074061312, r3
	lea	res_m_78_store, r4
	movq	#0x1234, r5
ins_m_78_store:
	movq	r5, 8(r3)
res_m_78_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#160, r0	; check 924
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#161, r0	; check 925
	trap	#1
1:
	lea	ins_m_78_store, r11
	cmp	r6, r11
	beq	1f
	movq	#162, r0	; check 926
	trap	#1
1:
	movq	=1074061320, r2
	cmp	r9, r2
	beq	1f
	movq	#163, r0	; check 927
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074061312, r3
	lea	res_m_78_fetch, r4
ins_m_78_fetch:
	call	r3
res_m_78_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#164, r0	; check 928
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#165, r0	; check 929
	trap	#1
1:
	movq	=1074061312, r2
	cmp	r6, r2
	beq	1f
	movq	#166, r0	; check 930
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#167, r0	; check 931
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074065408, r3
	lea	res_m_79_load, r4
	movq	#0, r5
ins_m_79_load:
	movq	8(r3), r5
res_m_79_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#168, r0	; check 932
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#169, r0	; check 933
	trap	#1
1:
	lea	ins_m_79_load, r11
	cmp	r6, r11
	beq	1f
	movq	#170, r0	; check 934
	trap	#1
1:
	movq	=1074065416, r2
	cmp	r9, r2
	beq	1f
	movq	#171, r0	; check 935
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074065408, r3
	lea	res_m_79_store, r4
	movq	#0x1234, r5
ins_m_79_store:
	movq	r5, 8(r3)
res_m_79_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#172, r0	; check 936
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#173, r0	; check 937
	trap	#1
1:
	lea	ins_m_79_store, r11
	cmp	r6, r11
	beq	1f
	movq	#174, r0	; check 938
	trap	#1
1:
	movq	=1074065416, r2
	cmp	r9, r2
	beq	1f
	movq	#175, r0	; check 939
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074065408, r3
	lea	res_m_79_fetch, r4
ins_m_79_fetch:
	call	r3
res_m_79_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#176, r0	; check 940
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#177, r0	; check 941
	trap	#1
1:
	movq	=1074065408, r2
	cmp	r6, r2
	beq	1f
	movq	#178, r0	; check 942
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#179, r0	; check 943
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074069504, r3
	lea	res_m_80_load, r4
	movq	#0, r5
ins_m_80_load:
	movq	8(r3), r5
res_m_80_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#180, r0	; check 944
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#181, r0	; check 945
	trap	#1
1:
	lea	ins_m_80_load, r11
	cmp	r6, r11
	beq	1f
	movq	#182, r0	; check 946
	trap	#1
1:
	movq	=1074069512, r2
	cmp	r9, r2
	beq	1f
	movq	#183, r0	; check 947
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074069504, r3
	lea	res_m_80_store, r4
	movq	#0x1234, r5
ins_m_80_store:
	movq	r5, 8(r3)
res_m_80_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#184, r0	; check 948
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#185, r0	; check 949
	trap	#1
1:
	lea	ins_m_80_store, r11
	cmp	r6, r11
	beq	1f
	movq	#186, r0	; check 950
	trap	#1
1:
	movq	=1074069512, r2
	cmp	r9, r2
	beq	1f
	movq	#187, r0	; check 951
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074069504, r3
	lea	res_m_80_fetch, r4
ins_m_80_fetch:
	call	r3
res_m_80_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#188, r0	; check 952
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#189, r0	; check 953
	trap	#1
1:
	movq	=1074069504, r2
	cmp	r6, r2
	beq	1f
	movq	#190, r0	; check 954
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#191, r0	; check 955
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074073600, r3
	lea	res_m_81_load, r4
	movq	#0, r5
ins_m_81_load:
	movq	8(r3), r5
res_m_81_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#192, r0	; check 956
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#193, r0	; check 957
	trap	#1
1:
	lea	ins_m_81_load, r11
	cmp	r6, r11
	beq	1f
	movq	#194, r0	; check 958
	trap	#1
1:
	movq	=1074073608, r2
	cmp	r9, r2
	beq	1f
	movq	#195, r0	; check 959
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074073600, r3
	lea	res_m_81_store, r4
	movq	#0x1234, r5
ins_m_81_store:
	movq	r5, 8(r3)
res_m_81_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#196, r0	; check 960
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#197, r0	; check 961
	trap	#1
1:
	lea	ins_m_81_store, r11
	cmp	r6, r11
	beq	1f
	movq	#198, r0	; check 962
	trap	#1
1:
	movq	=1074073608, r2
	cmp	r9, r2
	beq	1f
	movq	#199, r0	; check 963
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074073600, r3
	lea	res_m_81_fetch, r4
ins_m_81_fetch:
	call	r3
res_m_81_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#200, r0	; check 964
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#201, r0	; check 965
	trap	#1
1:
	movq	=1074073600, r2
	cmp	r6, r2
	beq	1f
	movq	#202, r0	; check 966
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#203, r0	; check 967
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074077696, r3
	lea	res_m_82_load, r4
	movq	#0, r5
ins_m_82_load:
	movq	8(r3), r5
res_m_82_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#204, r0	; check 968
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#205, r0	; check 969
	trap	#1
1:
	lea	ins_m_82_load, r11
	cmp	r6, r11
	beq	1f
	movq	#206, r0	; check 970
	trap	#1
1:
	movq	=1074077704, r2
	cmp	r9, r2
	beq	1f
	movq	#207, r0	; check 971
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074077696, r3
	lea	res_m_82_store, r4
	movq	#0x1234, r5
ins_m_82_store:
	movq	r5, 8(r3)
res_m_82_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#208, r0	; check 972
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#209, r0	; check 973
	trap	#1
1:
	lea	ins_m_82_store, r11
	cmp	r6, r11
	beq	1f
	movq	#210, r0	; check 974
	trap	#1
1:
	movq	=1074077704, r2
	cmp	r9, r2
	beq	1f
	movq	#211, r0	; check 975
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074077696, r3
	lea	res_m_82_fetch, r4
ins_m_82_fetch:
	call	r3
res_m_82_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#212, r0	; check 976
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#213, r0	; check 977
	trap	#1
1:
	movq	=1074077696, r2
	cmp	r6, r2
	beq	1f
	movq	#214, r0	; check 978
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#215, r0	; check 979
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074081792, r3
	lea	res_m_83_load, r4
	movq	#0, r5
ins_m_83_load:
	movq	8(r3), r5
res_m_83_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#216, r0	; check 980
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#217, r0	; check 981
	trap	#1
1:
	lea	ins_m_83_load, r11
	cmp	r6, r11
	beq	1f
	movq	#218, r0	; check 982
	trap	#1
1:
	movq	=1074081800, r2
	cmp	r9, r2
	beq	1f
	movq	#219, r0	; check 983
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074081792, r3
	lea	res_m_83_store, r4
	movq	#0x1234, r5
ins_m_83_store:
	movq	r5, 8(r3)
res_m_83_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#220, r0	; check 984
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#221, r0	; check 985
	trap	#1
1:
	lea	ins_m_83_store, r11
	cmp	r6, r11
	beq	1f
	movq	#222, r0	; check 986
	trap	#1
1:
	movq	=1074081800, r2
	cmp	r9, r2
	beq	1f
	movq	#223, r0	; check 987
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074081792, r3
	lea	res_m_83_fetch, r4
ins_m_83_fetch:
	call	r3
res_m_83_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#224, r0	; check 988
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#225, r0	; check 989
	trap	#1
1:
	movq	=1074081792, r2
	cmp	r6, r2
	beq	1f
	movq	#226, r0	; check 990
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#227, r0	; check 991
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074085888, r3
	lea	res_m_84_load, r4
	movq	#0, r5
ins_m_84_load:
	movq	8(r3), r5
res_m_84_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#228, r0	; check 992
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#229, r0	; check 993
	trap	#1
1:
	lea	ins_m_84_load, r11
	cmp	r6, r11
	beq	1f
	movq	#230, r0	; check 994
	trap	#1
1:
	movq	=1074085896, r2
	cmp	r9, r2
	beq	1f
	movq	#231, r0	; check 995
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074085888, r3
	lea	res_m_84_store, r4
	movq	#0x1234, r5
ins_m_84_store:
	movq	r5, 8(r3)
res_m_84_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#232, r0	; check 996
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#233, r0	; check 997
	trap	#1
1:
	lea	ins_m_84_store, r11
	cmp	r6, r11
	beq	1f
	movq	#234, r0	; check 998
	trap	#1
1:
	movq	=1074085896, r2
	cmp	r9, r2
	beq	1f
	movq	#235, r0	; check 999
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074085888, r3
	lea	res_m_84_fetch, r4
ins_m_84_fetch:
	call	r3
res_m_84_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#236, r0	; check 1000
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#237, r0	; check 1001
	trap	#1
1:
	movq	=1074085888, r2
	cmp	r6, r2
	beq	1f
	movq	#238, r0	; check 1002
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#239, r0	; check 1003
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074089984, r3
	lea	res_m_85_load, r4
	movq	#0, r5
ins_m_85_load:
	movq	8(r3), r5
res_m_85_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#240, r0	; check 1004
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#241, r0	; check 1005
	trap	#1
1:
	lea	ins_m_85_load, r11
	cmp	r6, r11
	beq	1f
	movq	#242, r0	; check 1006
	trap	#1
1:
	movq	=1074089992, r2
	cmp	r9, r2
	beq	1f
	movq	#243, r0	; check 1007
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074089984, r3
	lea	res_m_85_store, r4
	movq	#0x1234, r5
ins_m_85_store:
	movq	r5, 8(r3)
res_m_85_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#244, r0	; check 1008
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#245, r0	; check 1009
	trap	#1
1:
	lea	ins_m_85_store, r11
	cmp	r6, r11
	beq	1f
	movq	#246, r0	; check 1010
	trap	#1
1:
	movq	=1074089992, r2
	cmp	r9, r2
	beq	1f
	movq	#247, r0	; check 1011
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074089984, r3
	lea	res_m_85_fetch, r4
ins_m_85_fetch:
	call	r3
res_m_85_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#248, r0	; check 1012
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#249, r0	; check 1013
	trap	#1
1:
	movq	=1074089984, r2
	cmp	r6, r2
	beq	1f
	movq	#250, r0	; check 1014
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#251, r0	; check 1015
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074094080, r3
	lea	res_m_86_load, r4
	movq	#0, r5
ins_m_86_load:
	movq	8(r3), r5
res_m_86_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#252, r0	; check 1016
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#253, r0	; check 1017
	trap	#1
1:
	lea	ins_m_86_load, r11
	cmp	r6, r11
	beq	1f
	movq	#254, r0	; check 1018
	trap	#1
1:
	movq	=1074094088, r2
	cmp	r9, r2
	beq	1f
	movq	#255, r0	; check 1019
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074094080, r3
	lea	res_m_86_store, r4
	movq	#0x1234, r5
ins_m_86_store:
	movq	r5, 8(r3)
res_m_86_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#1, r0	; check 1020
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#2, r0	; check 1021
	trap	#1
1:
	lea	ins_m_86_store, r11
	cmp	r6, r11
	beq	1f
	movq	#3, r0	; check 1022
	trap	#1
1:
	movq	=1074094088, r2
	cmp	r9, r2
	beq	1f
	movq	#4, r0	; check 1023
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074094080, r3
	lea	res_m_86_fetch, r4
ins_m_86_fetch:
	call	r3
res_m_86_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#5, r0	; check 1024
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#6, r0	; check 1025
	trap	#1
1:
	movq	=1074094080, r2
	cmp	r6, r2
	beq	1f
	movq	#7, r0	; check 1026
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#8, r0	; check 1027
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074098176, r3
	lea	res_m_87_load, r4
	movq	#0, r5
ins_m_87_load:
	movq	8(r3), r5
res_m_87_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#9, r0	; check 1028
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#10, r0	; check 1029
	trap	#1
1:
	lea	ins_m_87_load, r11
	cmp	r6, r11
	beq	1f
	movq	#11, r0	; check 1030
	trap	#1
1:
	movq	=1074098184, r2
	cmp	r9, r2
	beq	1f
	movq	#12, r0	; check 1031
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074098176, r3
	lea	res_m_87_store, r4
	movq	#0x1234, r5
ins_m_87_store:
	movq	r5, 8(r3)
res_m_87_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#13, r0	; check 1032
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#14, r0	; check 1033
	trap	#1
1:
	lea	ins_m_87_store, r11
	cmp	r6, r11
	beq	1f
	movq	#15, r0	; check 1034
	trap	#1
1:
	movq	=1074098184, r2
	cmp	r9, r2
	beq	1f
	movq	#16, r0	; check 1035
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074098176, r3
	lea	res_m_87_fetch, r4
ins_m_87_fetch:
	call	r3
res_m_87_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#17, r0	; check 1036
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#18, r0	; check 1037
	trap	#1
1:
	movq	=1074098176, r2
	cmp	r6, r2
	beq	1f
	movq	#19, r0	; check 1038
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#20, r0	; check 1039
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074102272, r3
	lea	res_m_88_load, r4
	movq	#0, r5
ins_m_88_load:
	movq	8(r3), r5
res_m_88_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#21, r0	; check 1040
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#22, r0	; check 1041
	trap	#1
1:
	lea	ins_m_88_load, r11
	cmp	r6, r11
	beq	1f
	movq	#23, r0	; check 1042
	trap	#1
1:
	movq	=1074102280, r2
	cmp	r9, r2
	beq	1f
	movq	#24, r0	; check 1043
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074102272, r3
	lea	res_m_88_store, r4
	movq	#0x1234, r5
ins_m_88_store:
	movq	r5, 8(r3)
res_m_88_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#25, r0	; check 1044
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#26, r0	; check 1045
	trap	#1
1:
	lea	ins_m_88_store, r11
	cmp	r6, r11
	beq	1f
	movq	#27, r0	; check 1046
	trap	#1
1:
	movq	=1074102280, r2
	cmp	r9, r2
	beq	1f
	movq	#28, r0	; check 1047
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074102272, r3
	lea	res_m_88_fetch, r4
ins_m_88_fetch:
	call	r3
res_m_88_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#29, r0	; check 1048
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#30, r0	; check 1049
	trap	#1
1:
	movq	=1074102272, r2
	cmp	r6, r2
	beq	1f
	movq	#31, r0	; check 1050
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#32, r0	; check 1051
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074106368, r3
	lea	res_m_89_load, r4
	movq	#0, r5
ins_m_89_load:
	movq	8(r3), r5
res_m_89_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#33, r0	; check 1052
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#34, r0	; check 1053
	trap	#1
1:
	lea	ins_m_89_load, r11
	cmp	r6, r11
	beq	1f
	movq	#35, r0	; check 1054
	trap	#1
1:
	movq	=1074106376, r2
	cmp	r9, r2
	beq	1f
	movq	#36, r0	; check 1055
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074106368, r3
	lea	res_m_89_store, r4
	movq	#0x1234, r5
ins_m_89_store:
	movq	r5, 8(r3)
res_m_89_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#37, r0	; check 1056
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#38, r0	; check 1057
	trap	#1
1:
	lea	ins_m_89_store, r11
	cmp	r6, r11
	beq	1f
	movq	#39, r0	; check 1058
	trap	#1
1:
	movq	=1074106376, r2
	cmp	r9, r2
	beq	1f
	movq	#40, r0	; check 1059
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074106368, r3
	lea	res_m_89_fetch, r4
ins_m_89_fetch:
	call	r3
res_m_89_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#41, r0	; check 1060
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#42, r0	; check 1061
	trap	#1
1:
	movq	=1074106368, r2
	cmp	r6, r2
	beq	1f
	movq	#43, r0	; check 1062
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#44, r0	; check 1063
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074110464, r3
	lea	res_m_90_load, r4
	movq	#0, r5
ins_m_90_load:
	movq	8(r3), r5
res_m_90_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#45, r0	; check 1064
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#46, r0	; check 1065
	trap	#1
1:
	lea	ins_m_90_load, r11
	cmp	r6, r11
	beq	1f
	movq	#47, r0	; check 1066
	trap	#1
1:
	movq	=1074110472, r2
	cmp	r9, r2
	beq	1f
	movq	#48, r0	; check 1067
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074110464, r3
	lea	res_m_90_store, r4
	movq	#0x1234, r5
ins_m_90_store:
	movq	r5, 8(r3)
res_m_90_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#49, r0	; check 1068
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#50, r0	; check 1069
	trap	#1
1:
	lea	ins_m_90_store, r11
	cmp	r6, r11
	beq	1f
	movq	#51, r0	; check 1070
	trap	#1
1:
	movq	=1074110472, r2
	cmp	r9, r2
	beq	1f
	movq	#52, r0	; check 1071
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074110464, r3
	lea	res_m_90_fetch, r4
ins_m_90_fetch:
	call	r3
res_m_90_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#53, r0	; check 1072
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#54, r0	; check 1073
	trap	#1
1:
	movq	=1074110464, r2
	cmp	r6, r2
	beq	1f
	movq	#55, r0	; check 1074
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#56, r0	; check 1075
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074114560, r3
	lea	res_m_91_load, r4
	movq	#0, r5
ins_m_91_load:
	movq	8(r3), r5
res_m_91_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#57, r0	; check 1076
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#58, r0	; check 1077
	trap	#1
1:
	lea	ins_m_91_load, r11
	cmp	r6, r11
	beq	1f
	movq	#59, r0	; check 1078
	trap	#1
1:
	movq	=1074114568, r2
	cmp	r9, r2
	beq	1f
	movq	#60, r0	; check 1079
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074114560, r3
	lea	res_m_91_store, r4
	movq	#0x1234, r5
ins_m_91_store:
	movq	r5, 8(r3)
res_m_91_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#61, r0	; check 1080
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#62, r0	; check 1081
	trap	#1
1:
	lea	ins_m_91_store, r11
	cmp	r6, r11
	beq	1f
	movq	#63, r0	; check 1082
	trap	#1
1:
	movq	=1074114568, r2
	cmp	r9, r2
	beq	1f
	movq	#64, r0	; check 1083
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074114560, r3
	lea	res_m_91_fetch, r4
ins_m_91_fetch:
	call	r3
res_m_91_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#65, r0	; check 1084
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#66, r0	; check 1085
	trap	#1
1:
	movq	=1074114560, r2
	cmp	r6, r2
	beq	1f
	movq	#67, r0	; check 1086
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#68, r0	; check 1087
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074118656, r3
	lea	res_m_92_load, r4
	movq	#0, r5
ins_m_92_load:
	movq	8(r3), r5
res_m_92_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#69, r0	; check 1088
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#70, r0	; check 1089
	trap	#1
1:
	lea	ins_m_92_load, r11
	cmp	r6, r11
	beq	1f
	movq	#71, r0	; check 1090
	trap	#1
1:
	movq	=1074118664, r2
	cmp	r9, r2
	beq	1f
	movq	#72, r0	; check 1091
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074118656, r3
	lea	res_m_92_store, r4
	movq	#0x1234, r5
ins_m_92_store:
	movq	r5, 8(r3)
res_m_92_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#73, r0	; check 1092
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#74, r0	; check 1093
	trap	#1
1:
	lea	ins_m_92_store, r11
	cmp	r6, r11
	beq	1f
	movq	#75, r0	; check 1094
	trap	#1
1:
	movq	=1074118664, r2
	cmp	r9, r2
	beq	1f
	movq	#76, r0	; check 1095
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074118656, r3
	lea	res_m_92_fetch, r4
ins_m_92_fetch:
	call	r3
res_m_92_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#77, r0	; check 1096
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#78, r0	; check 1097
	trap	#1
1:
	movq	=1074118656, r2
	cmp	r6, r2
	beq	1f
	movq	#79, r0	; check 1098
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#80, r0	; check 1099
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074122752, r3
	lea	res_m_93_load, r4
	movq	#0, r5
ins_m_93_load:
	movq	8(r3), r5
res_m_93_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#81, r0	; check 1100
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#82, r0	; check 1101
	trap	#1
1:
	lea	ins_m_93_load, r11
	cmp	r6, r11
	beq	1f
	movq	#83, r0	; check 1102
	trap	#1
1:
	movq	=1074122760, r2
	cmp	r9, r2
	beq	1f
	movq	#84, r0	; check 1103
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074122752, r3
	lea	res_m_93_store, r4
	movq	#0x1234, r5
ins_m_93_store:
	movq	r5, 8(r3)
res_m_93_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#85, r0	; check 1104
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#86, r0	; check 1105
	trap	#1
1:
	lea	ins_m_93_store, r11
	cmp	r6, r11
	beq	1f
	movq	#87, r0	; check 1106
	trap	#1
1:
	movq	=1074122760, r2
	cmp	r9, r2
	beq	1f
	movq	#88, r0	; check 1107
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074122752, r3
	lea	res_m_93_fetch, r4
ins_m_93_fetch:
	call	r3
res_m_93_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#89, r0	; check 1108
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#90, r0	; check 1109
	trap	#1
1:
	movq	=1074122752, r2
	cmp	r6, r2
	beq	1f
	movq	#91, r0	; check 1110
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#92, r0	; check 1111
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074126848, r3
	lea	res_m_94_load, r4
	movq	#0, r5
ins_m_94_load:
	movq	8(r3), r5
res_m_94_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#93, r0	; check 1112
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#94, r0	; check 1113
	trap	#1
1:
	lea	ins_m_94_load, r11
	cmp	r6, r11
	beq	1f
	movq	#95, r0	; check 1114
	trap	#1
1:
	movq	=1074126856, r2
	cmp	r9, r2
	beq	1f
	movq	#96, r0	; check 1115
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074126848, r3
	lea	res_m_94_store, r4
	movq	#0x1234, r5
ins_m_94_store:
	movq	r5, 8(r3)
res_m_94_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#97, r0	; check 1116
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#98, r0	; check 1117
	trap	#1
1:
	lea	ins_m_94_store, r11
	cmp	r6, r11
	beq	1f
	movq	#99, r0	; check 1118
	trap	#1
1:
	movq	=1074126856, r2
	cmp	r9, r2
	beq	1f
	movq	#100, r0	; check 1119
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074126848, r3
	lea	res_m_94_fetch, r4
ins_m_94_fetch:
	call	r3
res_m_94_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#101, r0	; check 1120
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#102, r0	; check 1121
	trap	#1
1:
	movq	=1074126848, r2
	cmp	r6, r2
	beq	1f
	movq	#103, r0	; check 1122
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#104, r0	; check 1123
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074130944, r3
	lea	res_m_95_load, r4
	movq	#0, r5
ins_m_95_load:
	movq	8(r3), r5
res_m_95_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#105, r0	; check 1124
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#106, r0	; check 1125
	trap	#1
1:
	lea	ins_m_95_load, r11
	cmp	r6, r11
	beq	1f
	movq	#107, r0	; check 1126
	trap	#1
1:
	movq	=1074130952, r2
	cmp	r9, r2
	beq	1f
	movq	#108, r0	; check 1127
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074130944, r3
	lea	res_m_95_store, r4
	movq	#0x1234, r5
ins_m_95_store:
	movq	r5, 8(r3)
res_m_95_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#109, r0	; check 1128
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#110, r0	; check 1129
	trap	#1
1:
	lea	ins_m_95_store, r11
	cmp	r6, r11
	beq	1f
	movq	#111, r0	; check 1130
	trap	#1
1:
	movq	=1074130952, r2
	cmp	r9, r2
	beq	1f
	movq	#112, r0	; check 1131
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074130944, r3
	lea	res_m_95_fetch, r4
ins_m_95_fetch:
	call	r3
res_m_95_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#113, r0	; check 1132
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#114, r0	; check 1133
	trap	#1
1:
	movq	=1074130944, r2
	cmp	r6, r2
	beq	1f
	movq	#115, r0	; check 1134
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#116, r0	; check 1135
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074135040, r3
	lea	res_m_96_load, r4
	movq	#0, r5
ins_m_96_load:
	movq	8(r3), r5
res_m_96_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#117, r0	; check 1136
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#118, r0	; check 1137
	trap	#1
1:
	lea	ins_m_96_load, r11
	cmp	r6, r11
	beq	1f
	movq	#119, r0	; check 1138
	trap	#1
1:
	movq	=1074135048, r2
	cmp	r9, r2
	beq	1f
	movq	#120, r0	; check 1139
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074135040, r3
	lea	res_m_96_store, r4
	movq	#0x1234, r5
ins_m_96_store:
	movq	r5, 8(r3)
res_m_96_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#121, r0	; check 1140
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#122, r0	; check 1141
	trap	#1
1:
	lea	ins_m_96_store, r11
	cmp	r6, r11
	beq	1f
	movq	#123, r0	; check 1142
	trap	#1
1:
	movq	=1074135048, r2
	cmp	r9, r2
	beq	1f
	movq	#124, r0	; check 1143
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074135040, r3
	lea	res_m_96_fetch, r4
ins_m_96_fetch:
	call	r3
res_m_96_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#125, r0	; check 1144
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#126, r0	; check 1145
	trap	#1
1:
	movq	=1074135040, r2
	cmp	r6, r2
	beq	1f
	movq	#127, r0	; check 1146
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#128, r0	; check 1147
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074139136, r3
	lea	res_m_97_load, r4
	movq	#0, r5
ins_m_97_load:
	movq	8(r3), r5
res_m_97_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#129, r0	; check 1148
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#130, r0	; check 1149
	trap	#1
1:
	lea	ins_m_97_load, r11
	cmp	r6, r11
	beq	1f
	movq	#131, r0	; check 1150
	trap	#1
1:
	movq	=1074139144, r2
	cmp	r9, r2
	beq	1f
	movq	#132, r0	; check 1151
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074139136, r3
	lea	res_m_97_store, r4
	movq	#0x1234, r5
ins_m_97_store:
	movq	r5, 8(r3)
res_m_97_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#133, r0	; check 1152
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#134, r0	; check 1153
	trap	#1
1:
	lea	ins_m_97_store, r11
	cmp	r6, r11
	beq	1f
	movq	#135, r0	; check 1154
	trap	#1
1:
	movq	=1074139144, r2
	cmp	r9, r2
	beq	1f
	movq	#136, r0	; check 1155
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074139136, r3
	lea	res_m_97_fetch, r4
ins_m_97_fetch:
	call	r3
res_m_97_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#137, r0	; check 1156
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#138, r0	; check 1157
	trap	#1
1:
	movq	=1074139136, r2
	cmp	r6, r2
	beq	1f
	movq	#139, r0	; check 1158
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#140, r0	; check 1159
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074143232, r3
	lea	res_m_98_load, r4
	movq	#0, r5
ins_m_98_load:
	movq	8(r3), r5
res_m_98_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#141, r0	; check 1160
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#142, r0	; check 1161
	trap	#1
1:
	lea	ins_m_98_load, r11
	cmp	r6, r11
	beq	1f
	movq	#143, r0	; check 1162
	trap	#1
1:
	movq	=1074143240, r2
	cmp	r9, r2
	beq	1f
	movq	#144, r0	; check 1163
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074143232, r3
	lea	res_m_98_store, r4
	movq	#0x1234, r5
ins_m_98_store:
	movq	r5, 8(r3)
res_m_98_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#145, r0	; check 1164
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#146, r0	; check 1165
	trap	#1
1:
	lea	ins_m_98_store, r11
	cmp	r6, r11
	beq	1f
	movq	#147, r0	; check 1166
	trap	#1
1:
	movq	=1074143240, r2
	cmp	r9, r2
	beq	1f
	movq	#148, r0	; check 1167
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074143232, r3
	lea	res_m_98_fetch, r4
ins_m_98_fetch:
	call	r3
res_m_98_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#149, r0	; check 1168
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#150, r0	; check 1169
	trap	#1
1:
	movq	=1074143232, r2
	cmp	r6, r2
	beq	1f
	movq	#151, r0	; check 1170
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#152, r0	; check 1171
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074147328, r3
	lea	res_m_99_load, r4
	movq	#0, r5
ins_m_99_load:
	movq	8(r3), r5
res_m_99_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#153, r0	; check 1172
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#154, r0	; check 1173
	trap	#1
1:
	lea	ins_m_99_load, r11
	cmp	r6, r11
	beq	1f
	movq	#155, r0	; check 1174
	trap	#1
1:
	movq	=1074147336, r2
	cmp	r9, r2
	beq	1f
	movq	#156, r0	; check 1175
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074147328, r3
	lea	res_m_99_store, r4
	movq	#0x1234, r5
ins_m_99_store:
	movq	r5, 8(r3)
res_m_99_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#157, r0	; check 1176
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#158, r0	; check 1177
	trap	#1
1:
	lea	ins_m_99_store, r11
	cmp	r6, r11
	beq	1f
	movq	#159, r0	; check 1178
	trap	#1
1:
	movq	=1074147336, r2
	cmp	r9, r2
	beq	1f
	movq	#160, r0	; check 1179
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074147328, r3
	lea	res_m_99_fetch, r4
ins_m_99_fetch:
	call	r3
res_m_99_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#161, r0	; check 1180
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#162, r0	; check 1181
	trap	#1
1:
	movq	=1074147328, r2
	cmp	r6, r2
	beq	1f
	movq	#163, r0	; check 1182
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#164, r0	; check 1183
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074151424, r3
	lea	res_m_100_load, r4
	movq	#0, r5
ins_m_100_load:
	movq	8(r3), r5
res_m_100_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#165, r0	; check 1184
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#166, r0	; check 1185
	trap	#1
1:
	lea	ins_m_100_load, r11
	cmp	r6, r11
	beq	1f
	movq	#167, r0	; check 1186
	trap	#1
1:
	movq	=1074151432, r2
	cmp	r9, r2
	beq	1f
	movq	#168, r0	; check 1187
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074151424, r3
	lea	res_m_100_store, r4
	movq	#0x1234, r5
ins_m_100_store:
	movq	r5, 8(r3)
res_m_100_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#169, r0	; check 1188
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#170, r0	; check 1189
	trap	#1
1:
	lea	ins_m_100_store, r11
	cmp	r6, r11
	beq	1f
	movq	#171, r0	; check 1190
	trap	#1
1:
	movq	=1074151432, r2
	cmp	r9, r2
	beq	1f
	movq	#172, r0	; check 1191
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074151424, r3
	lea	res_m_100_fetch, r4
ins_m_100_fetch:
	call	r3
res_m_100_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#173, r0	; check 1192
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#174, r0	; check 1193
	trap	#1
1:
	movq	=1074151424, r2
	cmp	r6, r2
	beq	1f
	movq	#175, r0	; check 1194
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#176, r0	; check 1195
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074155520, r3
	lea	res_m_101_load, r4
	movq	#0, r5
ins_m_101_load:
	movq	8(r3), r5
res_m_101_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#177, r0	; check 1196
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#178, r0	; check 1197
	trap	#1
1:
	lea	ins_m_101_load, r11
	cmp	r6, r11
	beq	1f
	movq	#179, r0	; check 1198
	trap	#1
1:
	movq	=1074155528, r2
	cmp	r9, r2
	beq	1f
	movq	#180, r0	; check 1199
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074155520, r3
	lea	res_m_101_store, r4
	movq	#0x1234, r5
ins_m_101_store:
	movq	r5, 8(r3)
res_m_101_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#181, r0	; check 1200
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#182, r0	; check 1201
	trap	#1
1:
	lea	ins_m_101_store, r11
	cmp	r6, r11
	beq	1f
	movq	#183, r0	; check 1202
	trap	#1
1:
	movq	=1074155528, r2
	cmp	r9, r2
	beq	1f
	movq	#184, r0	; check 1203
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074155520, r3
	lea	res_m_101_fetch, r4
ins_m_101_fetch:
	call	r3
res_m_101_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#185, r0	; check 1204
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#186, r0	; check 1205
	trap	#1
1:
	movq	=1074155520, r2
	cmp	r6, r2
	beq	1f
	movq	#187, r0	; check 1206
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#188, r0	; check 1207
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074159616, r3
	lea	res_m_102_load, r4
	movq	#0, r5
ins_m_102_load:
	movq	8(r3), r5
res_m_102_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#189, r0	; check 1208
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#190, r0	; check 1209
	trap	#1
1:
	lea	ins_m_102_load, r11
	cmp	r6, r11
	beq	1f
	movq	#191, r0	; check 1210
	trap	#1
1:
	movq	=1074159624, r2
	cmp	r9, r2
	beq	1f
	movq	#192, r0	; check 1211
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074159616, r3
	lea	res_m_102_store, r4
	movq	#0x1234, r5
ins_m_102_store:
	movq	r5, 8(r3)
res_m_102_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#193, r0	; check 1212
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#194, r0	; check 1213
	trap	#1
1:
	lea	ins_m_102_store, r11
	cmp	r6, r11
	beq	1f
	movq	#195, r0	; check 1214
	trap	#1
1:
	movq	=1074159624, r2
	cmp	r9, r2
	beq	1f
	movq	#196, r0	; check 1215
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074159616, r3
	lea	res_m_102_fetch, r4
ins_m_102_fetch:
	call	r3
res_m_102_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#197, r0	; check 1216
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#198, r0	; check 1217
	trap	#1
1:
	movq	=1074159616, r2
	cmp	r6, r2
	beq	1f
	movq	#199, r0	; check 1218
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#200, r0	; check 1219
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074163712, r3
	lea	res_m_103_load, r4
	movq	#0, r5
ins_m_103_load:
	movq	8(r3), r5
res_m_103_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#201, r0	; check 1220
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#202, r0	; check 1221
	trap	#1
1:
	lea	ins_m_103_load, r11
	cmp	r6, r11
	beq	1f
	movq	#203, r0	; check 1222
	trap	#1
1:
	movq	=1074163720, r2
	cmp	r9, r2
	beq	1f
	movq	#204, r0	; check 1223
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074163712, r3
	lea	res_m_103_store, r4
	movq	#0x1234, r5
ins_m_103_store:
	movq	r5, 8(r3)
res_m_103_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#205, r0	; check 1224
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#206, r0	; check 1225
	trap	#1
1:
	lea	ins_m_103_store, r11
	cmp	r6, r11
	beq	1f
	movq	#207, r0	; check 1226
	trap	#1
1:
	movq	=1074163720, r2
	cmp	r9, r2
	beq	1f
	movq	#208, r0	; check 1227
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074163712, r3
	lea	res_m_103_fetch, r4
ins_m_103_fetch:
	call	r3
res_m_103_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#209, r0	; check 1228
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#210, r0	; check 1229
	trap	#1
1:
	movq	=1074163712, r2
	cmp	r6, r2
	beq	1f
	movq	#211, r0	; check 1230
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#212, r0	; check 1231
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074167808, r3
	lea	res_m_104_load, r4
	movq	#0, r5
ins_m_104_load:
	movq	8(r3), r5
res_m_104_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#213, r0	; check 1232
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#214, r0	; check 1233
	trap	#1
1:
	lea	ins_m_104_load, r11
	cmp	r6, r11
	beq	1f
	movq	#215, r0	; check 1234
	trap	#1
1:
	movq	=1074167816, r2
	cmp	r9, r2
	beq	1f
	movq	#216, r0	; check 1235
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074167808, r3
	lea	res_m_104_store, r4
	movq	#0x1234, r5
ins_m_104_store:
	movq	r5, 8(r3)
res_m_104_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#217, r0	; check 1236
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#218, r0	; check 1237
	trap	#1
1:
	lea	ins_m_104_store, r11
	cmp	r6, r11
	beq	1f
	movq	#219, r0	; check 1238
	trap	#1
1:
	movq	=1074167816, r2
	cmp	r9, r2
	beq	1f
	movq	#220, r0	; check 1239
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074167808, r3
	lea	res_m_104_fetch, r4
ins_m_104_fetch:
	call	r3
res_m_104_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#221, r0	; check 1240
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#222, r0	; check 1241
	trap	#1
1:
	movq	=1074167808, r2
	cmp	r6, r2
	beq	1f
	movq	#223, r0	; check 1242
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#224, r0	; check 1243
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074171904, r3
	lea	res_m_105_load, r4
	movq	#0, r5
ins_m_105_load:
	movq	8(r3), r5
res_m_105_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#225, r0	; check 1244
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#226, r0	; check 1245
	trap	#1
1:
	lea	ins_m_105_load, r11
	cmp	r6, r11
	beq	1f
	movq	#227, r0	; check 1246
	trap	#1
1:
	movq	=1074171912, r2
	cmp	r9, r2
	beq	1f
	movq	#228, r0	; check 1247
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074171904, r3
	lea	res_m_105_store, r4
	movq	#0x1234, r5
ins_m_105_store:
	movq	r5, 8(r3)
res_m_105_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#229, r0	; check 1248
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#230, r0	; check 1249
	trap	#1
1:
	lea	ins_m_105_store, r11
	cmp	r6, r11
	beq	1f
	movq	#231, r0	; check 1250
	trap	#1
1:
	movq	=1074171912, r2
	cmp	r9, r2
	beq	1f
	movq	#232, r0	; check 1251
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074171904, r3
	lea	res_m_105_fetch, r4
ins_m_105_fetch:
	call	r3
res_m_105_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#233, r0	; check 1252
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#234, r0	; check 1253
	trap	#1
1:
	movq	=1074171904, r2
	cmp	r6, r2
	beq	1f
	movq	#235, r0	; check 1254
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#236, r0	; check 1255
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074176000, r3
	lea	res_m_106_load, r4
	movq	#0, r5
ins_m_106_load:
	movq	8(r3), r5
res_m_106_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#237, r0	; check 1256
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#238, r0	; check 1257
	trap	#1
1:
	lea	ins_m_106_load, r11
	cmp	r6, r11
	beq	1f
	movq	#239, r0	; check 1258
	trap	#1
1:
	movq	=1074176008, r2
	cmp	r9, r2
	beq	1f
	movq	#240, r0	; check 1259
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074176000, r3
	lea	res_m_106_store, r4
	movq	#0x1234, r5
ins_m_106_store:
	movq	r5, 8(r3)
res_m_106_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#241, r0	; check 1260
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#242, r0	; check 1261
	trap	#1
1:
	lea	ins_m_106_store, r11
	cmp	r6, r11
	beq	1f
	movq	#243, r0	; check 1262
	trap	#1
1:
	movq	=1074176008, r2
	cmp	r9, r2
	beq	1f
	movq	#244, r0	; check 1263
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074176000, r3
	lea	res_m_106_fetch, r4
ins_m_106_fetch:
	call	r3
res_m_106_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#245, r0	; check 1264
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#246, r0	; check 1265
	trap	#1
1:
	movq	=1074176000, r2
	cmp	r6, r2
	beq	1f
	movq	#247, r0	; check 1266
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#248, r0	; check 1267
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074180096, r3
	lea	res_m_107_load, r4
	movq	#0, r5
ins_m_107_load:
	movq	8(r3), r5
res_m_107_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#249, r0	; check 1268
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#250, r0	; check 1269
	trap	#1
1:
	lea	ins_m_107_load, r11
	cmp	r6, r11
	beq	1f
	movq	#251, r0	; check 1270
	trap	#1
1:
	movq	=1074180104, r2
	cmp	r9, r2
	beq	1f
	movq	#252, r0	; check 1271
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074180096, r3
	lea	res_m_107_store, r4
	movq	#0x1234, r5
ins_m_107_store:
	movq	r5, 8(r3)
res_m_107_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#253, r0	; check 1272
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#254, r0	; check 1273
	trap	#1
1:
	lea	ins_m_107_store, r11
	cmp	r6, r11
	beq	1f
	movq	#255, r0	; check 1274
	trap	#1
1:
	movq	=1074180104, r2
	cmp	r9, r2
	beq	1f
	movq	#1, r0	; check 1275
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074180096, r3
	lea	res_m_107_fetch, r4
ins_m_107_fetch:
	call	r3
res_m_107_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#2, r0	; check 1276
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#3, r0	; check 1277
	trap	#1
1:
	movq	=1074180096, r2
	cmp	r6, r2
	beq	1f
	movq	#4, r0	; check 1278
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#5, r0	; check 1279
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074184192, r3
	lea	res_m_108_load, r4
	movq	#0, r5
ins_m_108_load:
	movq	8(r3), r5
res_m_108_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#6, r0	; check 1280
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#7, r0	; check 1281
	trap	#1
1:
	lea	ins_m_108_load, r11
	cmp	r6, r11
	beq	1f
	movq	#8, r0	; check 1282
	trap	#1
1:
	movq	=1074184200, r2
	cmp	r9, r2
	beq	1f
	movq	#9, r0	; check 1283
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074184192, r3
	lea	res_m_108_store, r4
	movq	#0x1234, r5
ins_m_108_store:
	movq	r5, 8(r3)
res_m_108_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#10, r0	; check 1284
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#11, r0	; check 1285
	trap	#1
1:
	lea	ins_m_108_store, r11
	cmp	r6, r11
	beq	1f
	movq	#12, r0	; check 1286
	trap	#1
1:
	movq	=1074184200, r2
	cmp	r9, r2
	beq	1f
	movq	#13, r0	; check 1287
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074184192, r3
	lea	res_m_108_fetch, r4
ins_m_108_fetch:
	call	r3
res_m_108_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#14, r0	; check 1288
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#15, r0	; check 1289
	trap	#1
1:
	movq	=1074184192, r2
	cmp	r6, r2
	beq	1f
	movq	#16, r0	; check 1290
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#17, r0	; check 1291
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074188288, r3
	lea	res_m_109_load, r4
	movq	#0, r5
ins_m_109_load:
	movq	8(r3), r5
res_m_109_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#18, r0	; check 1292
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#19, r0	; check 1293
	trap	#1
1:
	lea	ins_m_109_load, r11
	cmp	r6, r11
	beq	1f
	movq	#20, r0	; check 1294
	trap	#1
1:
	movq	=1074188296, r2
	cmp	r9, r2
	beq	1f
	movq	#21, r0	; check 1295
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074188288, r3
	lea	res_m_109_store, r4
	movq	#0x1234, r5
ins_m_109_store:
	movq	r5, 8(r3)
res_m_109_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#22, r0	; check 1296
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#23, r0	; check 1297
	trap	#1
1:
	lea	ins_m_109_store, r11
	cmp	r6, r11
	beq	1f
	movq	#24, r0	; check 1298
	trap	#1
1:
	movq	=1074188296, r2
	cmp	r9, r2
	beq	1f
	movq	#25, r0	; check 1299
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074188288, r3
	lea	res_m_109_fetch, r4
ins_m_109_fetch:
	call	r3
res_m_109_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#26, r0	; check 1300
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#27, r0	; check 1301
	trap	#1
1:
	movq	=1074188288, r2
	cmp	r6, r2
	beq	1f
	movq	#28, r0	; check 1302
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#29, r0	; check 1303
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074192384, r3
	lea	res_m_110_load, r4
	movq	#0, r5
ins_m_110_load:
	movq	8(r3), r5
res_m_110_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#30, r0	; check 1304
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#31, r0	; check 1305
	trap	#1
1:
	lea	ins_m_110_load, r11
	cmp	r6, r11
	beq	1f
	movq	#32, r0	; check 1306
	trap	#1
1:
	movq	=1074192392, r2
	cmp	r9, r2
	beq	1f
	movq	#33, r0	; check 1307
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074192384, r3
	lea	res_m_110_store, r4
	movq	#0x1234, r5
ins_m_110_store:
	movq	r5, 8(r3)
res_m_110_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#34, r0	; check 1308
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#35, r0	; check 1309
	trap	#1
1:
	lea	ins_m_110_store, r11
	cmp	r6, r11
	beq	1f
	movq	#36, r0	; check 1310
	trap	#1
1:
	movq	=1074192392, r2
	cmp	r9, r2
	beq	1f
	movq	#37, r0	; check 1311
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074192384, r3
	lea	res_m_110_fetch, r4
ins_m_110_fetch:
	call	r3
res_m_110_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#38, r0	; check 1312
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#39, r0	; check 1313
	trap	#1
1:
	movq	=1074192384, r2
	cmp	r6, r2
	beq	1f
	movq	#40, r0	; check 1314
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#41, r0	; check 1315
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074196480, r3
	lea	res_m_111_load, r4
	movq	#0, r5
ins_m_111_load:
	movq	8(r3), r5
res_m_111_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#42, r0	; check 1316
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#43, r0	; check 1317
	trap	#1
1:
	lea	ins_m_111_load, r11
	cmp	r6, r11
	beq	1f
	movq	#44, r0	; check 1318
	trap	#1
1:
	movq	=1074196488, r2
	cmp	r9, r2
	beq	1f
	movq	#45, r0	; check 1319
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074196480, r3
	lea	res_m_111_store, r4
	movq	#0x1234, r5
ins_m_111_store:
	movq	r5, 8(r3)
res_m_111_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#46, r0	; check 1320
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#47, r0	; check 1321
	trap	#1
1:
	lea	ins_m_111_store, r11
	cmp	r6, r11
	beq	1f
	movq	#48, r0	; check 1322
	trap	#1
1:
	movq	=1074196488, r2
	cmp	r9, r2
	beq	1f
	movq	#49, r0	; check 1323
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074196480, r3
	lea	res_m_111_fetch, r4
ins_m_111_fetch:
	call	r3
res_m_111_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#50, r0	; check 1324
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#51, r0	; check 1325
	trap	#1
1:
	movq	=1074196480, r2
	cmp	r6, r2
	beq	1f
	movq	#52, r0	; check 1326
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#53, r0	; check 1327
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074200576, r3
	lea	res_m_112_load, r4
	movq	#0, r5
ins_m_112_load:
	movq	8(r3), r5
res_m_112_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#54, r0	; check 1328
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#55, r0	; check 1329
	trap	#1
1:
	lea	ins_m_112_load, r11
	cmp	r6, r11
	beq	1f
	movq	#56, r0	; check 1330
	trap	#1
1:
	movq	=1074200584, r2
	cmp	r9, r2
	beq	1f
	movq	#57, r0	; check 1331
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074200576, r3
	lea	res_m_112_store, r4
	movq	#0x1234, r5
ins_m_112_store:
	movq	r5, 8(r3)
res_m_112_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#58, r0	; check 1332
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#59, r0	; check 1333
	trap	#1
1:
	lea	ins_m_112_store, r11
	cmp	r6, r11
	beq	1f
	movq	#60, r0	; check 1334
	trap	#1
1:
	movq	=1074200584, r2
	cmp	r9, r2
	beq	1f
	movq	#61, r0	; check 1335
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074200576, r3
	lea	res_m_112_fetch, r4
ins_m_112_fetch:
	call	r3
res_m_112_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#62, r0	; check 1336
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#63, r0	; check 1337
	trap	#1
1:
	movq	=1074200576, r2
	cmp	r6, r2
	beq	1f
	movq	#64, r0	; check 1338
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#65, r0	; check 1339
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074204672, r3
	lea	res_m_113_load, r4
	movq	#0, r5
ins_m_113_load:
	movq	8(r3), r5
res_m_113_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#66, r0	; check 1340
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#67, r0	; check 1341
	trap	#1
1:
	lea	ins_m_113_load, r11
	cmp	r6, r11
	beq	1f
	movq	#68, r0	; check 1342
	trap	#1
1:
	movq	=1074204680, r2
	cmp	r9, r2
	beq	1f
	movq	#69, r0	; check 1343
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074204672, r3
	lea	res_m_113_store, r4
	movq	#0x1234, r5
ins_m_113_store:
	movq	r5, 8(r3)
res_m_113_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#70, r0	; check 1344
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#71, r0	; check 1345
	trap	#1
1:
	lea	ins_m_113_store, r11
	cmp	r6, r11
	beq	1f
	movq	#72, r0	; check 1346
	trap	#1
1:
	movq	=1074204680, r2
	cmp	r9, r2
	beq	1f
	movq	#73, r0	; check 1347
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074204672, r3
	lea	res_m_113_fetch, r4
ins_m_113_fetch:
	call	r3
res_m_113_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#74, r0	; check 1348
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#75, r0	; check 1349
	trap	#1
1:
	movq	=1074204672, r2
	cmp	r6, r2
	beq	1f
	movq	#76, r0	; check 1350
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#77, r0	; check 1351
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074208768, r3
	lea	res_m_114_load, r4
	movq	#0, r5
ins_m_114_load:
	movq	8(r3), r5
res_m_114_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#78, r0	; check 1352
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#79, r0	; check 1353
	trap	#1
1:
	lea	ins_m_114_load, r11
	cmp	r6, r11
	beq	1f
	movq	#80, r0	; check 1354
	trap	#1
1:
	movq	=1074208776, r2
	cmp	r9, r2
	beq	1f
	movq	#81, r0	; check 1355
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074208768, r3
	lea	res_m_114_store, r4
	movq	#0x1234, r5
ins_m_114_store:
	movq	r5, 8(r3)
res_m_114_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#82, r0	; check 1356
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#83, r0	; check 1357
	trap	#1
1:
	lea	ins_m_114_store, r11
	cmp	r6, r11
	beq	1f
	movq	#84, r0	; check 1358
	trap	#1
1:
	movq	=1074208776, r2
	cmp	r9, r2
	beq	1f
	movq	#85, r0	; check 1359
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074208768, r3
	lea	res_m_114_fetch, r4
ins_m_114_fetch:
	call	r3
res_m_114_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#86, r0	; check 1360
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#87, r0	; check 1361
	trap	#1
1:
	movq	=1074208768, r2
	cmp	r6, r2
	beq	1f
	movq	#88, r0	; check 1362
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#89, r0	; check 1363
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074212864, r3
	lea	res_m_115_load, r4
	movq	#0, r5
ins_m_115_load:
	movq	8(r3), r5
res_m_115_load:
	cmp	r10, #(0)
	beq	1f
	movq	#90, r0	; check 1364
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#91, r0	; check 1365
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074212864, r3
	lea	res_m_115_store, r4
	movq	#0x1234, r5
ins_m_115_store:
	movq	r5, 8(r3)
res_m_115_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#92, r0	; check 1366
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#93, r0	; check 1367
	trap	#1
1:
	lea	ins_m_115_store, r11
	cmp	r6, r11
	beq	1f
	movq	#94, r0	; check 1368
	trap	#1
1:
	movq	=1074212872, r2
	cmp	r9, r2
	beq	1f
	movq	#95, r0	; check 1369
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074212864, r3
	lea	res_m_115_fetch, r4
ins_m_115_fetch:
	call	r3
res_m_115_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#96, r0	; check 1370
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#97, r0	; check 1371
	trap	#1
1:
	movq	=1074212864, r2
	cmp	r6, r2
	beq	1f
	movq	#98, r0	; check 1372
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#99, r0	; check 1373
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074216960, r3
	lea	res_m_116_load, r4
	movq	#0, r5
ins_m_116_load:
	movq	8(r3), r5
res_m_116_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#100, r0	; check 1374
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#101, r0	; check 1375
	trap	#1
1:
	lea	ins_m_116_load, r11
	cmp	r6, r11
	beq	1f
	movq	#102, r0	; check 1376
	trap	#1
1:
	movq	=1074216968, r2
	cmp	r9, r2
	beq	1f
	movq	#103, r0	; check 1377
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074216960, r3
	lea	res_m_116_store, r4
	movq	#0x1234, r5
ins_m_116_store:
	movq	r5, 8(r3)
res_m_116_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#104, r0	; check 1378
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#105, r0	; check 1379
	trap	#1
1:
	lea	ins_m_116_store, r11
	cmp	r6, r11
	beq	1f
	movq	#106, r0	; check 1380
	trap	#1
1:
	movq	=1074216968, r2
	cmp	r9, r2
	beq	1f
	movq	#107, r0	; check 1381
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074216960, r3
	lea	res_m_116_fetch, r4
ins_m_116_fetch:
	call	r3
res_m_116_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#108, r0	; check 1382
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#109, r0	; check 1383
	trap	#1
1:
	movq	=1074216960, r2
	cmp	r6, r2
	beq	1f
	movq	#110, r0	; check 1384
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#111, r0	; check 1385
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074221056, r3
	lea	res_m_117_load, r4
	movq	#0, r5
ins_m_117_load:
	movq	8(r3), r5
res_m_117_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#112, r0	; check 1386
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#113, r0	; check 1387
	trap	#1
1:
	lea	ins_m_117_load, r11
	cmp	r6, r11
	beq	1f
	movq	#114, r0	; check 1388
	trap	#1
1:
	movq	=1074221064, r2
	cmp	r9, r2
	beq	1f
	movq	#115, r0	; check 1389
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074221056, r3
	lea	res_m_117_store, r4
	movq	#0x1234, r5
ins_m_117_store:
	movq	r5, 8(r3)
res_m_117_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#116, r0	; check 1390
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#117, r0	; check 1391
	trap	#1
1:
	lea	ins_m_117_store, r11
	cmp	r6, r11
	beq	1f
	movq	#118, r0	; check 1392
	trap	#1
1:
	movq	=1074221064, r2
	cmp	r9, r2
	beq	1f
	movq	#119, r0	; check 1393
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074221056, r3
	lea	res_m_117_fetch, r4
ins_m_117_fetch:
	call	r3
res_m_117_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#120, r0	; check 1394
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#121, r0	; check 1395
	trap	#1
1:
	movq	=1074221056, r2
	cmp	r6, r2
	beq	1f
	movq	#122, r0	; check 1396
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#123, r0	; check 1397
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074225152, r3
	lea	res_m_118_load, r4
	movq	#0, r5
ins_m_118_load:
	movq	8(r3), r5
res_m_118_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#124, r0	; check 1398
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#125, r0	; check 1399
	trap	#1
1:
	lea	ins_m_118_load, r11
	cmp	r6, r11
	beq	1f
	movq	#126, r0	; check 1400
	trap	#1
1:
	movq	=1074225160, r2
	cmp	r9, r2
	beq	1f
	movq	#127, r0	; check 1401
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074225152, r3
	lea	res_m_118_store, r4
	movq	#0x1234, r5
ins_m_118_store:
	movq	r5, 8(r3)
res_m_118_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#128, r0	; check 1402
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#129, r0	; check 1403
	trap	#1
1:
	lea	ins_m_118_store, r11
	cmp	r6, r11
	beq	1f
	movq	#130, r0	; check 1404
	trap	#1
1:
	movq	=1074225160, r2
	cmp	r9, r2
	beq	1f
	movq	#131, r0	; check 1405
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074225152, r3
	lea	res_m_118_fetch, r4
ins_m_118_fetch:
	call	r3
res_m_118_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#132, r0	; check 1406
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#133, r0	; check 1407
	trap	#1
1:
	movq	=1074225152, r2
	cmp	r6, r2
	beq	1f
	movq	#134, r0	; check 1408
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#135, r0	; check 1409
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074229248, r3
	lea	res_m_119_load, r4
	movq	#0, r5
ins_m_119_load:
	movq	8(r3), r5
res_m_119_load:
	cmp	r10, #(0)
	beq	1f
	movq	#136, r0	; check 1410
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#137, r0	; check 1411
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074229248, r3
	lea	res_m_119_store, r4
	movq	#0x1234, r5
ins_m_119_store:
	movq	r5, 8(r3)
res_m_119_store:
	cmp	r10, #(0)
	beq	1f
	movq	#138, r0	; check 1412
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074229248, r3
	lea	res_m_119_fetch, r4
ins_m_119_fetch:
	call	r3
res_m_119_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#139, r0	; check 1413
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#140, r0	; check 1414
	trap	#1
1:
	movq	=1074229248, r2
	cmp	r6, r2
	beq	1f
	movq	#141, r0	; check 1415
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#142, r0	; check 1416
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074233344, r3
	lea	res_m_120_load, r4
	movq	#0, r5
ins_m_120_load:
	movq	8(r3), r5
res_m_120_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#143, r0	; check 1417
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#144, r0	; check 1418
	trap	#1
1:
	lea	ins_m_120_load, r11
	cmp	r6, r11
	beq	1f
	movq	#145, r0	; check 1419
	trap	#1
1:
	movq	=1074233352, r2
	cmp	r9, r2
	beq	1f
	movq	#146, r0	; check 1420
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074233344, r3
	lea	res_m_120_store, r4
	movq	#0x1234, r5
ins_m_120_store:
	movq	r5, 8(r3)
res_m_120_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#147, r0	; check 1421
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#148, r0	; check 1422
	trap	#1
1:
	lea	ins_m_120_store, r11
	cmp	r6, r11
	beq	1f
	movq	#149, r0	; check 1423
	trap	#1
1:
	movq	=1074233352, r2
	cmp	r9, r2
	beq	1f
	movq	#150, r0	; check 1424
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074233344, r3
	lea	res_m_120_fetch, r4
ins_m_120_fetch:
	call	r3
res_m_120_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#151, r0	; check 1425
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#152, r0	; check 1426
	trap	#1
1:
	movq	=1074233344, r2
	cmp	r6, r2
	beq	1f
	movq	#153, r0	; check 1427
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#154, r0	; check 1428
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074237440, r3
	lea	res_m_121_load, r4
	movq	#0, r5
ins_m_121_load:
	movq	8(r3), r5
res_m_121_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#155, r0	; check 1429
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#156, r0	; check 1430
	trap	#1
1:
	lea	ins_m_121_load, r11
	cmp	r6, r11
	beq	1f
	movq	#157, r0	; check 1431
	trap	#1
1:
	movq	=1074237448, r2
	cmp	r9, r2
	beq	1f
	movq	#158, r0	; check 1432
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074237440, r3
	lea	res_m_121_store, r4
	movq	#0x1234, r5
ins_m_121_store:
	movq	r5, 8(r3)
res_m_121_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#159, r0	; check 1433
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#160, r0	; check 1434
	trap	#1
1:
	lea	ins_m_121_store, r11
	cmp	r6, r11
	beq	1f
	movq	#161, r0	; check 1435
	trap	#1
1:
	movq	=1074237448, r2
	cmp	r9, r2
	beq	1f
	movq	#162, r0	; check 1436
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074237440, r3
	lea	res_m_121_fetch, r4
ins_m_121_fetch:
	call	r3
res_m_121_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#163, r0	; check 1437
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074241536, r3
	lea	res_m_122_load, r4
	movq	#0, r5
ins_m_122_load:
	movq	8(r3), r5
res_m_122_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#164, r0	; check 1438
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#165, r0	; check 1439
	trap	#1
1:
	lea	ins_m_122_load, r11
	cmp	r6, r11
	beq	1f
	movq	#166, r0	; check 1440
	trap	#1
1:
	movq	=1074241544, r2
	cmp	r9, r2
	beq	1f
	movq	#167, r0	; check 1441
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074241536, r3
	lea	res_m_122_store, r4
	movq	#0x1234, r5
ins_m_122_store:
	movq	r5, 8(r3)
res_m_122_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#168, r0	; check 1442
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#169, r0	; check 1443
	trap	#1
1:
	lea	ins_m_122_store, r11
	cmp	r6, r11
	beq	1f
	movq	#170, r0	; check 1444
	trap	#1
1:
	movq	=1074241544, r2
	cmp	r9, r2
	beq	1f
	movq	#171, r0	; check 1445
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074241536, r3
	lea	res_m_122_fetch, r4
ins_m_122_fetch:
	call	r3
res_m_122_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#172, r0	; check 1446
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#173, r0	; check 1447
	trap	#1
1:
	movq	=1074241536, r2
	cmp	r6, r2
	beq	1f
	movq	#174, r0	; check 1448
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#175, r0	; check 1449
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074245632, r3
	lea	res_m_123_load, r4
	movq	#0, r5
ins_m_123_load:
	movq	8(r3), r5
res_m_123_load:
	cmp	r10, #(0)
	beq	1f
	movq	#176, r0	; check 1450
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#177, r0	; check 1451
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074245632, r3
	lea	res_m_123_store, r4
	movq	#0x1234, r5
ins_m_123_store:
	movq	r5, 8(r3)
res_m_123_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#178, r0	; check 1452
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#179, r0	; check 1453
	trap	#1
1:
	lea	ins_m_123_store, r11
	cmp	r6, r11
	beq	1f
	movq	#180, r0	; check 1454
	trap	#1
1:
	movq	=1074245640, r2
	cmp	r9, r2
	beq	1f
	movq	#181, r0	; check 1455
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074245632, r3
	lea	res_m_123_fetch, r4
ins_m_123_fetch:
	call	r3
res_m_123_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#182, r0	; check 1456
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074249728, r3
	lea	res_m_124_load, r4
	movq	#0, r5
ins_m_124_load:
	movq	8(r3), r5
res_m_124_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#183, r0	; check 1457
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#184, r0	; check 1458
	trap	#1
1:
	lea	ins_m_124_load, r11
	cmp	r6, r11
	beq	1f
	movq	#185, r0	; check 1459
	trap	#1
1:
	movq	=1074249736, r2
	cmp	r9, r2
	beq	1f
	movq	#186, r0	; check 1460
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074249728, r3
	lea	res_m_124_store, r4
	movq	#0x1234, r5
ins_m_124_store:
	movq	r5, 8(r3)
res_m_124_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#187, r0	; check 1461
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#188, r0	; check 1462
	trap	#1
1:
	lea	ins_m_124_store, r11
	cmp	r6, r11
	beq	1f
	movq	#189, r0	; check 1463
	trap	#1
1:
	movq	=1074249736, r2
	cmp	r9, r2
	beq	1f
	movq	#190, r0	; check 1464
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074249728, r3
	lea	res_m_124_fetch, r4
ins_m_124_fetch:
	call	r3
res_m_124_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#191, r0	; check 1465
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#192, r0	; check 1466
	trap	#1
1:
	movq	=1074249728, r2
	cmp	r6, r2
	beq	1f
	movq	#193, r0	; check 1467
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#194, r0	; check 1468
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074253824, r3
	lea	res_m_125_load, r4
	movq	#0, r5
ins_m_125_load:
	movq	8(r3), r5
res_m_125_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#195, r0	; check 1469
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#196, r0	; check 1470
	trap	#1
1:
	lea	ins_m_125_load, r11
	cmp	r6, r11
	beq	1f
	movq	#197, r0	; check 1471
	trap	#1
1:
	movq	=1074253832, r2
	cmp	r9, r2
	beq	1f
	movq	#198, r0	; check 1472
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074253824, r3
	lea	res_m_125_store, r4
	movq	#0x1234, r5
ins_m_125_store:
	movq	r5, 8(r3)
res_m_125_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#199, r0	; check 1473
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#200, r0	; check 1474
	trap	#1
1:
	lea	ins_m_125_store, r11
	cmp	r6, r11
	beq	1f
	movq	#201, r0	; check 1475
	trap	#1
1:
	movq	=1074253832, r2
	cmp	r9, r2
	beq	1f
	movq	#202, r0	; check 1476
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074253824, r3
	lea	res_m_125_fetch, r4
ins_m_125_fetch:
	call	r3
res_m_125_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#203, r0	; check 1477
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#204, r0	; check 1478
	trap	#1
1:
	movq	=1074253824, r2
	cmp	r6, r2
	beq	1f
	movq	#205, r0	; check 1479
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#206, r0	; check 1480
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074257920, r3
	lea	res_m_126_load, r4
	movq	#0, r5
ins_m_126_load:
	movq	8(r3), r5
res_m_126_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#207, r0	; check 1481
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#208, r0	; check 1482
	trap	#1
1:
	lea	ins_m_126_load, r11
	cmp	r6, r11
	beq	1f
	movq	#209, r0	; check 1483
	trap	#1
1:
	movq	=1074257928, r2
	cmp	r9, r2
	beq	1f
	movq	#210, r0	; check 1484
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074257920, r3
	lea	res_m_126_store, r4
	movq	#0x1234, r5
ins_m_126_store:
	movq	r5, 8(r3)
res_m_126_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#211, r0	; check 1485
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#212, r0	; check 1486
	trap	#1
1:
	lea	ins_m_126_store, r11
	cmp	r6, r11
	beq	1f
	movq	#213, r0	; check 1487
	trap	#1
1:
	movq	=1074257928, r2
	cmp	r9, r2
	beq	1f
	movq	#214, r0	; check 1488
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074257920, r3
	lea	res_m_126_fetch, r4
ins_m_126_fetch:
	call	r3
res_m_126_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#215, r0	; check 1489
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#216, r0	; check 1490
	trap	#1
1:
	movq	=1074257920, r2
	cmp	r6, r2
	beq	1f
	movq	#217, r0	; check 1491
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#218, r0	; check 1492
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074262016, r3
	lea	res_m_127_load, r4
	movq	#0, r5
ins_m_127_load:
	movq	8(r3), r5
res_m_127_load:
	cmp	r10, #(0)
	beq	1f
	movq	#219, r0	; check 1493
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#220, r0	; check 1494
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074262016, r3
	lea	res_m_127_store, r4
	movq	#0x1234, r5
ins_m_127_store:
	movq	r5, 8(r3)
res_m_127_store:
	cmp	r10, #(0)
	beq	1f
	movq	#221, r0	; check 1495
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074262016, r3
	lea	res_m_127_fetch, r4
ins_m_127_fetch:
	call	r3
res_m_127_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#222, r0	; check 1496
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074266112, r3
	lea	res_m_128_load, r4
	movq	#0, r5
ins_m_128_load:
	movq	8(r3), r5
res_m_128_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#223, r0	; check 1497
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#224, r0	; check 1498
	trap	#1
1:
	lea	ins_m_128_load, r11
	cmp	r6, r11
	beq	1f
	movq	#225, r0	; check 1499
	trap	#1
1:
	movq	=1074266120, r2
	cmp	r9, r2
	beq	1f
	movq	#226, r0	; check 1500
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074266112, r3
	lea	res_m_128_store, r4
	movq	#0x1234, r5
ins_m_128_store:
	movq	r5, 8(r3)
res_m_128_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#227, r0	; check 1501
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#228, r0	; check 1502
	trap	#1
1:
	lea	ins_m_128_store, r11
	cmp	r6, r11
	beq	1f
	movq	#229, r0	; check 1503
	trap	#1
1:
	movq	=1074266120, r2
	cmp	r9, r2
	beq	1f
	movq	#230, r0	; check 1504
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074266112, r3
	lea	res_m_128_fetch, r4
ins_m_128_fetch:
	call	r3
res_m_128_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#231, r0	; check 1505
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#232, r0	; check 1506
	trap	#1
1:
	movq	=1074266112, r2
	cmp	r6, r2
	beq	1f
	movq	#233, r0	; check 1507
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#234, r0	; check 1508
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074270208, r3
	lea	res_m_129_load, r4
	movq	#0, r5
ins_m_129_load:
	movq	8(r3), r5
res_m_129_load:
	cmp	r10, #(0)
	beq	1f
	movq	#235, r0	; check 1509
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#236, r0	; check 1510
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074270208, r3
	lea	res_m_129_store, r4
	movq	#0x1234, r5
ins_m_129_store:
	movq	r5, 8(r3)
res_m_129_store:
	cmp	r10, #(0)
	beq	1f
	movq	#237, r0	; check 1511
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074270208, r3
	lea	res_m_129_fetch, r4
ins_m_129_fetch:
	call	r3
res_m_129_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#238, r0	; check 1512
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074274304, r3
	lea	res_m_130_load, r4
	movq	#0, r5
ins_m_130_load:
	movq	8(r3), r5
res_m_130_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#239, r0	; check 1513
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#240, r0	; check 1514
	trap	#1
1:
	lea	ins_m_130_load, r11
	cmp	r6, r11
	beq	1f
	movq	#241, r0	; check 1515
	trap	#1
1:
	movq	=1074274312, r2
	cmp	r9, r2
	beq	1f
	movq	#242, r0	; check 1516
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074274304, r3
	lea	res_m_130_store, r4
	movq	#0x1234, r5
ins_m_130_store:
	movq	r5, 8(r3)
res_m_130_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#243, r0	; check 1517
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#244, r0	; check 1518
	trap	#1
1:
	lea	ins_m_130_store, r11
	cmp	r6, r11
	beq	1f
	movq	#245, r0	; check 1519
	trap	#1
1:
	movq	=1074274312, r2
	cmp	r9, r2
	beq	1f
	movq	#246, r0	; check 1520
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074274304, r3
	lea	res_m_130_fetch, r4
ins_m_130_fetch:
	call	r3
res_m_130_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#247, r0	; check 1521
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#248, r0	; check 1522
	trap	#1
1:
	movq	=1074274304, r2
	cmp	r6, r2
	beq	1f
	movq	#249, r0	; check 1523
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#250, r0	; check 1524
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074278400, r3
	lea	res_m_131_load, r4
	movq	#0, r5
ins_m_131_load:
	movq	8(r3), r5
res_m_131_load:
	cmp	r10, #(0)
	beq	1f
	movq	#251, r0	; check 1525
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#252, r0	; check 1526
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074278400, r3
	lea	res_m_131_store, r4
	movq	#0x1234, r5
ins_m_131_store:
	movq	r5, 8(r3)
res_m_131_store:
	cmp	r10, #(0)
	beq	1f
	movq	#253, r0	; check 1527
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074278400, r3
	lea	res_m_131_fetch, r4
ins_m_131_fetch:
	call	r3
res_m_131_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#254, r0	; check 1528
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074282496, r3
	lea	res_m_132_load, r4
	movq	#0, r5
ins_m_132_load:
	movq	8(r3), r5
res_m_132_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#255, r0	; check 1529
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#1, r0	; check 1530
	trap	#1
1:
	lea	ins_m_132_load, r11
	cmp	r6, r11
	beq	1f
	movq	#2, r0	; check 1531
	trap	#1
1:
	movq	=1074282504, r2
	cmp	r9, r2
	beq	1f
	movq	#3, r0	; check 1532
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074282496, r3
	lea	res_m_132_store, r4
	movq	#0x1234, r5
ins_m_132_store:
	movq	r5, 8(r3)
res_m_132_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#4, r0	; check 1533
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#5, r0	; check 1534
	trap	#1
1:
	lea	ins_m_132_store, r11
	cmp	r6, r11
	beq	1f
	movq	#6, r0	; check 1535
	trap	#1
1:
	movq	=1074282504, r2
	cmp	r9, r2
	beq	1f
	movq	#7, r0	; check 1536
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074282496, r3
	lea	res_m_132_fetch, r4
ins_m_132_fetch:
	call	r3
res_m_132_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#8, r0	; check 1537
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#9, r0	; check 1538
	trap	#1
1:
	movq	=1074282496, r2
	cmp	r6, r2
	beq	1f
	movq	#10, r0	; check 1539
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#11, r0	; check 1540
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074286592, r3
	lea	res_m_133_load, r4
	movq	#0, r5
ins_m_133_load:
	movq	8(r3), r5
res_m_133_load:
	cmp	r10, #(0)
	beq	1f
	movq	#12, r0	; check 1541
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#13, r0	; check 1542
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074286592, r3
	lea	res_m_133_store, r4
	movq	#0x1234, r5
ins_m_133_store:
	movq	r5, 8(r3)
res_m_133_store:
	cmp	r10, #(0)
	beq	1f
	movq	#14, r0	; check 1543
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074286592, r3
	lea	res_m_133_fetch, r4
ins_m_133_fetch:
	call	r3
res_m_133_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#15, r0	; check 1544
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074290688, r3
	lea	res_m_134_load, r4
	movq	#0, r5
ins_m_134_load:
	movq	8(r3), r5
res_m_134_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#16, r0	; check 1545
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#17, r0	; check 1546
	trap	#1
1:
	lea	ins_m_134_load, r11
	cmp	r6, r11
	beq	1f
	movq	#18, r0	; check 1547
	trap	#1
1:
	movq	=1074290696, r2
	cmp	r9, r2
	beq	1f
	movq	#19, r0	; check 1548
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074290688, r3
	lea	res_m_134_store, r4
	movq	#0x1234, r5
ins_m_134_store:
	movq	r5, 8(r3)
res_m_134_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#20, r0	; check 1549
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#21, r0	; check 1550
	trap	#1
1:
	lea	ins_m_134_store, r11
	cmp	r6, r11
	beq	1f
	movq	#22, r0	; check 1551
	trap	#1
1:
	movq	=1074290696, r2
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 1552
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074290688, r3
	lea	res_m_134_fetch, r4
ins_m_134_fetch:
	call	r3
res_m_134_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#24, r0	; check 1553
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#25, r0	; check 1554
	trap	#1
1:
	movq	=1074290688, r2
	cmp	r6, r2
	beq	1f
	movq	#26, r0	; check 1555
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#27, r0	; check 1556
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074294784, r3
	lea	res_m_135_load, r4
	movq	#0, r5
ins_m_135_load:
	movq	8(r3), r5
res_m_135_load:
	cmp	r10, #(0)
	beq	1f
	movq	#28, r0	; check 1557
	trap	#1
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#29, r0	; check 1558
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074294784, r3
	lea	res_m_135_store, r4
	movq	#0x1234, r5
ins_m_135_store:
	movq	r5, 8(r3)
res_m_135_store:
	cmp	r10, #(0)
	beq	1f
	movq	#30, r0	; check 1559
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074294784, r3
	lea	res_m_135_fetch, r4
ins_m_135_fetch:
	call	r3
res_m_135_fetch:
	cmp	r10, #(0)
	beq	1f
	movq	#31, r0	; check 1560
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074298880, r3
	lea	res_m_136_load, r4
	movq	#0, r5
ins_m_136_load:
	movq	8(r3), r5
res_m_136_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#32, r0	; check 1561
	trap	#1
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#33, r0	; check 1562
	trap	#1
1:
	lea	ins_m_136_load, r11
	cmp	r6, r11
	beq	1f
	movq	#34, r0	; check 1563
	trap	#1
1:
	movq	=1074298888, r2
	cmp	r9, r2
	beq	1f
	movq	#35, r0	; check 1564
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074298880, r3
	lea	res_m_136_store, r4
	movq	#0x1234, r5
ins_m_136_store:
	movq	r5, 8(r3)
res_m_136_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#36, r0	; check 1565
	trap	#1
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#37, r0	; check 1566
	trap	#1
1:
	lea	ins_m_136_store, r11
	cmp	r6, r11
	beq	1f
	movq	#38, r0	; check 1567
	trap	#1
1:
	movq	=1074298888, r2
	cmp	r9, r2
	beq	1f
	movq	#39, r0	; check 1568
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074298880, r3
	lea	res_m_136_fetch, r4
ins_m_136_fetch:
	call	r3
res_m_136_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#40, r0	; check 1569
	trap	#1
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#41, r0	; check 1570
	trap	#1
1:
	movq	=1074298880, r2
	cmp	r6, r2
	beq	1f
	movq	#42, r0	; check 1571
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#43, r0	; check 1572
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074302976, r3
	lea	res_m_137_load, r4
	movq	#0, r5
ins_m_137_load:
	movq	8(r3), r5
res_m_137_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#44, r0	; check 1573
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#45, r0	; check 1574
	trap	#1
1:
	lea	ins_m_137_load, r11
	cmp	r6, r11
	beq	1f
	movq	#46, r0	; check 1575
	trap	#1
1:
	movq	=1074302984, r2
	cmp	r9, r2
	beq	1f
	movq	#47, r0	; check 1576
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074302976, r3
	lea	res_m_137_store, r4
	movq	#0x1234, r5
ins_m_137_store:
	movq	r5, 8(r3)
res_m_137_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#48, r0	; check 1577
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#49, r0	; check 1578
	trap	#1
1:
	lea	ins_m_137_store, r11
	cmp	r6, r11
	beq	1f
	movq	#50, r0	; check 1579
	trap	#1
1:
	movq	=1074302984, r2
	cmp	r9, r2
	beq	1f
	movq	#51, r0	; check 1580
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074302976, r3
	lea	res_m_137_fetch, r4
ins_m_137_fetch:
	call	r3
res_m_137_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#52, r0	; check 1581
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#53, r0	; check 1582
	trap	#1
1:
	movq	=1074302976, r2
	cmp	r6, r2
	beq	1f
	movq	#54, r0	; check 1583
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#55, r0	; check 1584
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074307072, r3
	lea	res_m_138_load, r4
	movq	#0, r5
ins_m_138_load:
	movq	8(r3), r5
res_m_138_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#56, r0	; check 1585
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#57, r0	; check 1586
	trap	#1
1:
	lea	ins_m_138_load, r11
	cmp	r6, r11
	beq	1f
	movq	#58, r0	; check 1587
	trap	#1
1:
	movq	=1074307080, r2
	cmp	r9, r2
	beq	1f
	movq	#59, r0	; check 1588
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074307072, r3
	lea	res_m_138_store, r4
	movq	#0x1234, r5
ins_m_138_store:
	movq	r5, 8(r3)
res_m_138_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#60, r0	; check 1589
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#61, r0	; check 1590
	trap	#1
1:
	lea	ins_m_138_store, r11
	cmp	r6, r11
	beq	1f
	movq	#62, r0	; check 1591
	trap	#1
1:
	movq	=1074307080, r2
	cmp	r9, r2
	beq	1f
	movq	#63, r0	; check 1592
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074307072, r3
	lea	res_m_138_fetch, r4
ins_m_138_fetch:
	call	r3
res_m_138_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#64, r0	; check 1593
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#65, r0	; check 1594
	trap	#1
1:
	movq	=1074307072, r2
	cmp	r6, r2
	beq	1f
	movq	#66, r0	; check 1595
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#67, r0	; check 1596
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074311168, r3
	lea	res_m_139_load, r4
	movq	#0, r5
ins_m_139_load:
	movq	8(r3), r5
res_m_139_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#68, r0	; check 1597
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#69, r0	; check 1598
	trap	#1
1:
	lea	ins_m_139_load, r11
	cmp	r6, r11
	beq	1f
	movq	#70, r0	; check 1599
	trap	#1
1:
	movq	=1074311176, r2
	cmp	r9, r2
	beq	1f
	movq	#71, r0	; check 1600
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074311168, r3
	lea	res_m_139_store, r4
	movq	#0x1234, r5
ins_m_139_store:
	movq	r5, 8(r3)
res_m_139_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#72, r0	; check 1601
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#73, r0	; check 1602
	trap	#1
1:
	lea	ins_m_139_store, r11
	cmp	r6, r11
	beq	1f
	movq	#74, r0	; check 1603
	trap	#1
1:
	movq	=1074311176, r2
	cmp	r9, r2
	beq	1f
	movq	#75, r0	; check 1604
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074311168, r3
	lea	res_m_139_fetch, r4
ins_m_139_fetch:
	call	r3
res_m_139_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#76, r0	; check 1605
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#77, r0	; check 1606
	trap	#1
1:
	movq	=1074311168, r2
	cmp	r6, r2
	beq	1f
	movq	#78, r0	; check 1607
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#79, r0	; check 1608
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074315264, r3
	lea	res_m_140_load, r4
	movq	#0, r5
ins_m_140_load:
	movq	8(r3), r5
res_m_140_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#80, r0	; check 1609
	trap	#1
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#81, r0	; check 1610
	trap	#1
1:
	lea	ins_m_140_load, r11
	cmp	r6, r11
	beq	1f
	movq	#82, r0	; check 1611
	trap	#1
1:
	movq	=1074315272, r2
	cmp	r9, r2
	beq	1f
	movq	#83, r0	; check 1612
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074315264, r3
	lea	res_m_140_store, r4
	movq	#0x1234, r5
ins_m_140_store:
	movq	r5, 8(r3)
res_m_140_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#84, r0	; check 1613
	trap	#1
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#85, r0	; check 1614
	trap	#1
1:
	lea	ins_m_140_store, r11
	cmp	r6, r11
	beq	1f
	movq	#86, r0	; check 1615
	trap	#1
1:
	movq	=1074315272, r2
	cmp	r9, r2
	beq	1f
	movq	#87, r0	; check 1616
	trap	#1
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1074315264, r3
	lea	res_m_140_fetch, r4
ins_m_140_fetch:
	call	r3
res_m_140_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#88, r0	; check 1617
	trap	#1
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#89, r0	; check 1618
	trap	#1
1:
	movq	=1074315264, r2
	cmp	r6, r2
	beq	1f
	movq	#90, r0	; check 1619
	trap	#1
1:
	cmp	r9, r2
	beq	1f
	movq	#91, r0	; check 1620
	trap	#1
1:
	movq	#0, r0
	trap	#0
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
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.space	4072

	.align	4096
l1a:
	.quad	l0a + (1<<PTE_V)
	.space	4088

	.align	4096
l0a:
	.quad	pgdata + (0)
	.quad	pgdata + (1<<PTE_V)
	.quad	pgdata + (1<<PTE_R)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R)
	.quad	pgdata + (1<<PTE_W)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W)
	.quad	pgdata + (1<<PTE_X)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X)
	.quad	pgdata + (1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_U)
	.quad	pgdata + (1<<PTE_R|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_U)
	.quad	pgdata + (1<<PTE_W|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_U)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_U)
	.quad	pgdata + (1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U)
	.quad	pgdata + (1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_A)
	.quad	pgdata + (1<<PTE_W|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A)
	.quad	pgdata + (1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A)
	.quad	pgdata + (1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_W|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A)
	.quad	pgdata + (1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_D)
	.quad	pgdata + (1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_D)
	.quad	pgdata + (1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_D)
	.quad	pgdata + (1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_G|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_G|1<<PTE_A|1<<PTE_D)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|1<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D|1<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|2<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D|2<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|3<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D|3<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|0x400)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|0x800)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|0x10000000000)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_U|1<<PTE_A|1<<PTE_D|0x8000000000000000)
	.space	2968

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
	.space	2032

	.align 8
ustk:	.space 512
ustk_top:


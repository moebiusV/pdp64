; System v1 MMU: every combination of V R W X U A D (and G, MT, reserved bits) on a 4 KB page, accessed in KERNEL mode by a load, a store and an instruction fetch; the vector,
; EPC and EVA of each fault. Generated from a reference model of section 15 (the PTE rules) in the generator; a failed check n exits with n mod 255 + 1.
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
	lea	res_m_0_load, r4
	movq	#0, r5
ins_m_0_load:
	movq	8(r3), r5
res_m_0_load:
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
	lea	ins_m_0_load, r11
	cmp	r6, r11
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	=1073741832, r2
	cmp	r9, r2
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	lea	ins_m_0_store, r11
	cmp	r6, r11
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	movq	=1073741832, r2
	cmp	r9, r2
	beq	1f
	movq	#9, r0	; check 8
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
	lea	res_m_0_fetch, r4
ins_m_0_fetch:
	call	r3
res_m_0_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	movq	=1073741824, r2
	cmp	r6, r2
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#13, r0	; check 12
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
	lea	res_m_1_load, r4
	movq	#0, r5
ins_m_1_load:
	movq	8(r3), r5
res_m_1_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	lea	ins_m_1_load, r11
	cmp	r6, r11
	beq	1f
	movq	#16, r0	; check 15
	halt
1:
	movq	=1073745928, r2
	cmp	r9, r2
	beq	1f
	movq	#17, r0	; check 16
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
	lea	res_m_1_store, r4
	movq	#0x1234, r5
ins_m_1_store:
	movq	r5, 8(r3)
res_m_1_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#19, r0	; check 18
	halt
1:
	lea	ins_m_1_store, r11
	cmp	r6, r11
	beq	1f
	movq	#20, r0	; check 19
	halt
1:
	movq	=1073745928, r2
	cmp	r9, r2
	beq	1f
	movq	#21, r0	; check 20
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
	lea	res_m_1_fetch, r4
ins_m_1_fetch:
	call	r3
res_m_1_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#22, r0	; check 21
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#23, r0	; check 22
	halt
1:
	movq	=1073745920, r2
	cmp	r6, r2
	beq	1f
	movq	#24, r0	; check 23
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#25, r0	; check 24
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
	lea	res_m_2_load, r4
	movq	#0, r5
ins_m_2_load:
	movq	8(r3), r5
res_m_2_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#26, r0	; check 25
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#27, r0	; check 26
	halt
1:
	lea	ins_m_2_load, r11
	cmp	r6, r11
	beq	1f
	movq	#28, r0	; check 27
	halt
1:
	movq	=1073750024, r2
	cmp	r9, r2
	beq	1f
	movq	#29, r0	; check 28
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
	lea	res_m_2_store, r4
	movq	#0x1234, r5
ins_m_2_store:
	movq	r5, 8(r3)
res_m_2_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#30, r0	; check 29
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#31, r0	; check 30
	halt
1:
	lea	ins_m_2_store, r11
	cmp	r6, r11
	beq	1f
	movq	#32, r0	; check 31
	halt
1:
	movq	=1073750024, r2
	cmp	r9, r2
	beq	1f
	movq	#33, r0	; check 32
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
	lea	res_m_2_fetch, r4
ins_m_2_fetch:
	call	r3
res_m_2_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#34, r0	; check 33
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#35, r0	; check 34
	halt
1:
	movq	=1073750016, r2
	cmp	r6, r2
	beq	1f
	movq	#36, r0	; check 35
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#37, r0	; check 36
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
	lea	res_m_3_load, r4
	movq	#0, r5
ins_m_3_load:
	movq	8(r3), r5
res_m_3_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#38, r0	; check 37
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#39, r0	; check 38
	halt
1:
	lea	ins_m_3_load, r11
	cmp	r6, r11
	beq	1f
	movq	#40, r0	; check 39
	halt
1:
	movq	=1073754120, r2
	cmp	r9, r2
	beq	1f
	movq	#41, r0	; check 40
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
	lea	res_m_3_store, r4
	movq	#0x1234, r5
ins_m_3_store:
	movq	r5, 8(r3)
res_m_3_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#42, r0	; check 41
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#43, r0	; check 42
	halt
1:
	lea	ins_m_3_store, r11
	cmp	r6, r11
	beq	1f
	movq	#44, r0	; check 43
	halt
1:
	movq	=1073754120, r2
	cmp	r9, r2
	beq	1f
	movq	#45, r0	; check 44
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
	lea	res_m_3_fetch, r4
ins_m_3_fetch:
	call	r3
res_m_3_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#46, r0	; check 45
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#47, r0	; check 46
	halt
1:
	movq	=1073754112, r2
	cmp	r6, r2
	beq	1f
	movq	#48, r0	; check 47
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#49, r0	; check 48
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
	lea	res_m_4_load, r4
	movq	#0, r5
ins_m_4_load:
	movq	8(r3), r5
res_m_4_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#50, r0	; check 49
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#51, r0	; check 50
	halt
1:
	lea	ins_m_4_load, r11
	cmp	r6, r11
	beq	1f
	movq	#52, r0	; check 51
	halt
1:
	movq	=1073758216, r2
	cmp	r9, r2
	beq	1f
	movq	#53, r0	; check 52
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
	lea	res_m_4_store, r4
	movq	#0x1234, r5
ins_m_4_store:
	movq	r5, 8(r3)
res_m_4_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#54, r0	; check 53
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#55, r0	; check 54
	halt
1:
	lea	ins_m_4_store, r11
	cmp	r6, r11
	beq	1f
	movq	#56, r0	; check 55
	halt
1:
	movq	=1073758216, r2
	cmp	r9, r2
	beq	1f
	movq	#57, r0	; check 56
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
	lea	res_m_4_fetch, r4
ins_m_4_fetch:
	call	r3
res_m_4_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#58, r0	; check 57
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#59, r0	; check 58
	halt
1:
	movq	=1073758208, r2
	cmp	r6, r2
	beq	1f
	movq	#60, r0	; check 59
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#61, r0	; check 60
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
	lea	res_m_5_load, r4
	movq	#0, r5
ins_m_5_load:
	movq	8(r3), r5
res_m_5_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#62, r0	; check 61
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#63, r0	; check 62
	halt
1:
	lea	ins_m_5_load, r11
	cmp	r6, r11
	beq	1f
	movq	#64, r0	; check 63
	halt
1:
	movq	=1073762312, r2
	cmp	r9, r2
	beq	1f
	movq	#65, r0	; check 64
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
	lea	res_m_5_store, r4
	movq	#0x1234, r5
ins_m_5_store:
	movq	r5, 8(r3)
res_m_5_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#66, r0	; check 65
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#67, r0	; check 66
	halt
1:
	lea	ins_m_5_store, r11
	cmp	r6, r11
	beq	1f
	movq	#68, r0	; check 67
	halt
1:
	movq	=1073762312, r2
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#71, r0	; check 70
	halt
1:
	movq	=1073762304, r2
	cmp	r6, r2
	beq	1f
	movq	#72, r0	; check 71
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#73, r0	; check 72
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#75, r0	; check 74
	halt
1:
	lea	ins_m_6_load, r11
	cmp	r6, r11
	beq	1f
	movq	#76, r0	; check 75
	halt
1:
	movq	=1073766408, r2
	cmp	r9, r2
	beq	1f
	movq	#77, r0	; check 76
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#79, r0	; check 78
	halt
1:
	lea	ins_m_6_store, r11
	cmp	r6, r11
	beq	1f
	movq	#80, r0	; check 79
	halt
1:
	movq	=1073766408, r2
	cmp	r9, r2
	beq	1f
	movq	#81, r0	; check 80
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#83, r0	; check 82
	halt
1:
	movq	=1073766400, r2
	cmp	r6, r2
	beq	1f
	movq	#84, r0	; check 83
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#85, r0	; check 84
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#87, r0	; check 86
	halt
1:
	lea	ins_m_7_load, r11
	cmp	r6, r11
	beq	1f
	movq	#88, r0	; check 87
	halt
1:
	movq	=1073770504, r2
	cmp	r9, r2
	beq	1f
	movq	#89, r0	; check 88
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#91, r0	; check 90
	halt
1:
	lea	ins_m_7_store, r11
	cmp	r6, r11
	beq	1f
	movq	#92, r0	; check 91
	halt
1:
	movq	=1073770504, r2
	cmp	r9, r2
	beq	1f
	movq	#93, r0	; check 92
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#95, r0	; check 94
	halt
1:
	movq	=1073770496, r2
	cmp	r6, r2
	beq	1f
	movq	#96, r0	; check 95
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#97, r0	; check 96
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#99, r0	; check 98
	halt
1:
	lea	ins_m_8_load, r11
	cmp	r6, r11
	beq	1f
	movq	#100, r0	; check 99
	halt
1:
	movq	=1073774600, r2
	cmp	r9, r2
	beq	1f
	movq	#101, r0	; check 100
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#103, r0	; check 102
	halt
1:
	lea	ins_m_8_store, r11
	cmp	r6, r11
	beq	1f
	movq	#104, r0	; check 103
	halt
1:
	movq	=1073774600, r2
	cmp	r9, r2
	beq	1f
	movq	#105, r0	; check 104
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#107, r0	; check 106
	halt
1:
	movq	=1073774592, r2
	cmp	r6, r2
	beq	1f
	movq	#108, r0	; check 107
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#109, r0	; check 108
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#111, r0	; check 110
	halt
1:
	lea	ins_m_9_load, r11
	cmp	r6, r11
	beq	1f
	movq	#112, r0	; check 111
	halt
1:
	movq	=1073778696, r2
	cmp	r9, r2
	beq	1f
	movq	#113, r0	; check 112
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#115, r0	; check 114
	halt
1:
	lea	ins_m_9_store, r11
	cmp	r6, r11
	beq	1f
	movq	#116, r0	; check 115
	halt
1:
	movq	=1073778696, r2
	cmp	r9, r2
	beq	1f
	movq	#117, r0	; check 116
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#119, r0	; check 118
	halt
1:
	movq	=1073778688, r2
	cmp	r6, r2
	beq	1f
	movq	#120, r0	; check 119
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#121, r0	; check 120
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#123, r0	; check 122
	halt
1:
	lea	ins_m_10_load, r11
	cmp	r6, r11
	beq	1f
	movq	#124, r0	; check 123
	halt
1:
	movq	=1073782792, r2
	cmp	r9, r2
	beq	1f
	movq	#125, r0	; check 124
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#127, r0	; check 126
	halt
1:
	lea	ins_m_10_store, r11
	cmp	r6, r11
	beq	1f
	movq	#128, r0	; check 127
	halt
1:
	movq	=1073782792, r2
	cmp	r9, r2
	beq	1f
	movq	#129, r0	; check 128
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#131, r0	; check 130
	halt
1:
	movq	=1073782784, r2
	cmp	r6, r2
	beq	1f
	movq	#132, r0	; check 131
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#133, r0	; check 132
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#135, r0	; check 134
	halt
1:
	lea	ins_m_11_load, r11
	cmp	r6, r11
	beq	1f
	movq	#136, r0	; check 135
	halt
1:
	movq	=1073786888, r2
	cmp	r9, r2
	beq	1f
	movq	#137, r0	; check 136
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#139, r0	; check 138
	halt
1:
	lea	ins_m_11_store, r11
	cmp	r6, r11
	beq	1f
	movq	#140, r0	; check 139
	halt
1:
	movq	=1073786888, r2
	cmp	r9, r2
	beq	1f
	movq	#141, r0	; check 140
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#143, r0	; check 142
	halt
1:
	movq	=1073786880, r2
	cmp	r6, r2
	beq	1f
	movq	#144, r0	; check 143
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#145, r0	; check 144
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#147, r0	; check 146
	halt
1:
	lea	ins_m_12_load, r11
	cmp	r6, r11
	beq	1f
	movq	#148, r0	; check 147
	halt
1:
	movq	=1073790984, r2
	cmp	r9, r2
	beq	1f
	movq	#149, r0	; check 148
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#151, r0	; check 150
	halt
1:
	lea	ins_m_12_store, r11
	cmp	r6, r11
	beq	1f
	movq	#152, r0	; check 151
	halt
1:
	movq	=1073790984, r2
	cmp	r9, r2
	beq	1f
	movq	#153, r0	; check 152
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#155, r0	; check 154
	halt
1:
	movq	=1073790976, r2
	cmp	r6, r2
	beq	1f
	movq	#156, r0	; check 155
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#157, r0	; check 156
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#159, r0	; check 158
	halt
1:
	lea	ins_m_13_load, r11
	cmp	r6, r11
	beq	1f
	movq	#160, r0	; check 159
	halt
1:
	movq	=1073795080, r2
	cmp	r9, r2
	beq	1f
	movq	#161, r0	; check 160
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#163, r0	; check 162
	halt
1:
	lea	ins_m_13_store, r11
	cmp	r6, r11
	beq	1f
	movq	#164, r0	; check 163
	halt
1:
	movq	=1073795080, r2
	cmp	r9, r2
	beq	1f
	movq	#165, r0	; check 164
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#167, r0	; check 166
	halt
1:
	movq	=1073795072, r2
	cmp	r6, r2
	beq	1f
	movq	#168, r0	; check 167
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#169, r0	; check 168
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#171, r0	; check 170
	halt
1:
	lea	ins_m_14_load, r11
	cmp	r6, r11
	beq	1f
	movq	#172, r0	; check 171
	halt
1:
	movq	=1073799176, r2
	cmp	r9, r2
	beq	1f
	movq	#173, r0	; check 172
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#175, r0	; check 174
	halt
1:
	lea	ins_m_14_store, r11
	cmp	r6, r11
	beq	1f
	movq	#176, r0	; check 175
	halt
1:
	movq	=1073799176, r2
	cmp	r9, r2
	beq	1f
	movq	#177, r0	; check 176
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#179, r0	; check 178
	halt
1:
	movq	=1073799168, r2
	cmp	r6, r2
	beq	1f
	movq	#180, r0	; check 179
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#181, r0	; check 180
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#183, r0	; check 182
	halt
1:
	lea	ins_m_15_load, r11
	cmp	r6, r11
	beq	1f
	movq	#184, r0	; check 183
	halt
1:
	movq	=1073803272, r2
	cmp	r9, r2
	beq	1f
	movq	#185, r0	; check 184
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#187, r0	; check 186
	halt
1:
	lea	ins_m_15_store, r11
	cmp	r6, r11
	beq	1f
	movq	#188, r0	; check 187
	halt
1:
	movq	=1073803272, r2
	cmp	r9, r2
	beq	1f
	movq	#189, r0	; check 188
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#191, r0	; check 190
	halt
1:
	movq	=1073803264, r2
	cmp	r6, r2
	beq	1f
	movq	#192, r0	; check 191
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#193, r0	; check 192
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#195, r0	; check 194
	halt
1:
	lea	ins_m_16_load, r11
	cmp	r6, r11
	beq	1f
	movq	#196, r0	; check 195
	halt
1:
	movq	=1073807368, r2
	cmp	r9, r2
	beq	1f
	movq	#197, r0	; check 196
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#199, r0	; check 198
	halt
1:
	lea	ins_m_16_store, r11
	cmp	r6, r11
	beq	1f
	movq	#200, r0	; check 199
	halt
1:
	movq	=1073807368, r2
	cmp	r9, r2
	beq	1f
	movq	#201, r0	; check 200
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#203, r0	; check 202
	halt
1:
	movq	=1073807360, r2
	cmp	r6, r2
	beq	1f
	movq	#204, r0	; check 203
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#205, r0	; check 204
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#207, r0	; check 206
	halt
1:
	lea	ins_m_17_load, r11
	cmp	r6, r11
	beq	1f
	movq	#208, r0	; check 207
	halt
1:
	movq	=1073811464, r2
	cmp	r9, r2
	beq	1f
	movq	#209, r0	; check 208
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#211, r0	; check 210
	halt
1:
	lea	ins_m_17_store, r11
	cmp	r6, r11
	beq	1f
	movq	#212, r0	; check 211
	halt
1:
	movq	=1073811464, r2
	cmp	r9, r2
	beq	1f
	movq	#213, r0	; check 212
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#215, r0	; check 214
	halt
1:
	movq	=1073811456, r2
	cmp	r6, r2
	beq	1f
	movq	#216, r0	; check 215
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#217, r0	; check 216
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#219, r0	; check 218
	halt
1:
	lea	ins_m_18_load, r11
	cmp	r6, r11
	beq	1f
	movq	#220, r0	; check 219
	halt
1:
	movq	=1073815560, r2
	cmp	r9, r2
	beq	1f
	movq	#221, r0	; check 220
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#223, r0	; check 222
	halt
1:
	lea	ins_m_18_store, r11
	cmp	r6, r11
	beq	1f
	movq	#224, r0	; check 223
	halt
1:
	movq	=1073815560, r2
	cmp	r9, r2
	beq	1f
	movq	#225, r0	; check 224
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#227, r0	; check 226
	halt
1:
	movq	=1073815552, r2
	cmp	r6, r2
	beq	1f
	movq	#228, r0	; check 227
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#229, r0	; check 228
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#231, r0	; check 230
	halt
1:
	lea	ins_m_19_load, r11
	cmp	r6, r11
	beq	1f
	movq	#232, r0	; check 231
	halt
1:
	movq	=1073819656, r2
	cmp	r9, r2
	beq	1f
	movq	#233, r0	; check 232
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#235, r0	; check 234
	halt
1:
	lea	ins_m_19_store, r11
	cmp	r6, r11
	beq	1f
	movq	#236, r0	; check 235
	halt
1:
	movq	=1073819656, r2
	cmp	r9, r2
	beq	1f
	movq	#237, r0	; check 236
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#239, r0	; check 238
	halt
1:
	movq	=1073819648, r2
	cmp	r6, r2
	beq	1f
	movq	#240, r0	; check 239
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#241, r0	; check 240
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#243, r0	; check 242
	halt
1:
	lea	ins_m_20_load, r11
	cmp	r6, r11
	beq	1f
	movq	#244, r0	; check 243
	halt
1:
	movq	=1073823752, r2
	cmp	r9, r2
	beq	1f
	movq	#245, r0	; check 244
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#247, r0	; check 246
	halt
1:
	lea	ins_m_20_store, r11
	cmp	r6, r11
	beq	1f
	movq	#248, r0	; check 247
	halt
1:
	movq	=1073823752, r2
	cmp	r9, r2
	beq	1f
	movq	#249, r0	; check 248
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#251, r0	; check 250
	halt
1:
	movq	=1073823744, r2
	cmp	r6, r2
	beq	1f
	movq	#252, r0	; check 251
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#253, r0	; check 252
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#255, r0	; check 254
	halt
1:
	lea	ins_m_21_load, r11
	cmp	r6, r11
	beq	1f
	movq	#1, r0	; check 255
	halt
1:
	movq	=1073827848, r2
	cmp	r9, r2
	beq	1f
	movq	#2, r0	; check 256
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#4, r0	; check 258
	halt
1:
	lea	ins_m_21_store, r11
	cmp	r6, r11
	beq	1f
	movq	#5, r0	; check 259
	halt
1:
	movq	=1073827848, r2
	cmp	r9, r2
	beq	1f
	movq	#6, r0	; check 260
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#8, r0	; check 262
	halt
1:
	movq	=1073827840, r2
	cmp	r6, r2
	beq	1f
	movq	#9, r0	; check 263
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#10, r0	; check 264
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#12, r0	; check 266
	halt
1:
	lea	ins_m_22_load, r11
	cmp	r6, r11
	beq	1f
	movq	#13, r0	; check 267
	halt
1:
	movq	=1073831944, r2
	cmp	r9, r2
	beq	1f
	movq	#14, r0	; check 268
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#16, r0	; check 270
	halt
1:
	lea	ins_m_22_store, r11
	cmp	r6, r11
	beq	1f
	movq	#17, r0	; check 271
	halt
1:
	movq	=1073831944, r2
	cmp	r9, r2
	beq	1f
	movq	#18, r0	; check 272
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#20, r0	; check 274
	halt
1:
	movq	=1073831936, r2
	cmp	r6, r2
	beq	1f
	movq	#21, r0	; check 275
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#22, r0	; check 276
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#24, r0	; check 278
	halt
1:
	lea	ins_m_23_load, r11
	cmp	r6, r11
	beq	1f
	movq	#25, r0	; check 279
	halt
1:
	movq	=1073836040, r2
	cmp	r9, r2
	beq	1f
	movq	#26, r0	; check 280
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#28, r0	; check 282
	halt
1:
	lea	ins_m_23_store, r11
	cmp	r6, r11
	beq	1f
	movq	#29, r0	; check 283
	halt
1:
	movq	=1073836040, r2
	cmp	r9, r2
	beq	1f
	movq	#30, r0	; check 284
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#32, r0	; check 286
	halt
1:
	movq	=1073836032, r2
	cmp	r6, r2
	beq	1f
	movq	#33, r0	; check 287
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#34, r0	; check 288
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#36, r0	; check 290
	halt
1:
	lea	ins_m_24_load, r11
	cmp	r6, r11
	beq	1f
	movq	#37, r0	; check 291
	halt
1:
	movq	=1073840136, r2
	cmp	r9, r2
	beq	1f
	movq	#38, r0	; check 292
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#40, r0	; check 294
	halt
1:
	lea	ins_m_24_store, r11
	cmp	r6, r11
	beq	1f
	movq	#41, r0	; check 295
	halt
1:
	movq	=1073840136, r2
	cmp	r9, r2
	beq	1f
	movq	#42, r0	; check 296
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#44, r0	; check 298
	halt
1:
	movq	=1073840128, r2
	cmp	r6, r2
	beq	1f
	movq	#45, r0	; check 299
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#46, r0	; check 300
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#48, r0	; check 302
	halt
1:
	lea	ins_m_25_load, r11
	cmp	r6, r11
	beq	1f
	movq	#49, r0	; check 303
	halt
1:
	movq	=1073844232, r2
	cmp	r9, r2
	beq	1f
	movq	#50, r0	; check 304
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#52, r0	; check 306
	halt
1:
	lea	ins_m_25_store, r11
	cmp	r6, r11
	beq	1f
	movq	#53, r0	; check 307
	halt
1:
	movq	=1073844232, r2
	cmp	r9, r2
	beq	1f
	movq	#54, r0	; check 308
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#56, r0	; check 310
	halt
1:
	movq	=1073844224, r2
	cmp	r6, r2
	beq	1f
	movq	#57, r0	; check 311
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#58, r0	; check 312
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#60, r0	; check 314
	halt
1:
	lea	ins_m_26_load, r11
	cmp	r6, r11
	beq	1f
	movq	#61, r0	; check 315
	halt
1:
	movq	=1073848328, r2
	cmp	r9, r2
	beq	1f
	movq	#62, r0	; check 316
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#64, r0	; check 318
	halt
1:
	lea	ins_m_26_store, r11
	cmp	r6, r11
	beq	1f
	movq	#65, r0	; check 319
	halt
1:
	movq	=1073848328, r2
	cmp	r9, r2
	beq	1f
	movq	#66, r0	; check 320
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#68, r0	; check 322
	halt
1:
	movq	=1073848320, r2
	cmp	r6, r2
	beq	1f
	movq	#69, r0	; check 323
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#70, r0	; check 324
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#72, r0	; check 326
	halt
1:
	lea	ins_m_27_load, r11
	cmp	r6, r11
	beq	1f
	movq	#73, r0	; check 327
	halt
1:
	movq	=1073852424, r2
	cmp	r9, r2
	beq	1f
	movq	#74, r0	; check 328
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#76, r0	; check 330
	halt
1:
	lea	ins_m_27_store, r11
	cmp	r6, r11
	beq	1f
	movq	#77, r0	; check 331
	halt
1:
	movq	=1073852424, r2
	cmp	r9, r2
	beq	1f
	movq	#78, r0	; check 332
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#80, r0	; check 334
	halt
1:
	movq	=1073852416, r2
	cmp	r6, r2
	beq	1f
	movq	#81, r0	; check 335
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#82, r0	; check 336
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#84, r0	; check 338
	halt
1:
	lea	ins_m_28_load, r11
	cmp	r6, r11
	beq	1f
	movq	#85, r0	; check 339
	halt
1:
	movq	=1073856520, r2
	cmp	r9, r2
	beq	1f
	movq	#86, r0	; check 340
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#88, r0	; check 342
	halt
1:
	lea	ins_m_28_store, r11
	cmp	r6, r11
	beq	1f
	movq	#89, r0	; check 343
	halt
1:
	movq	=1073856520, r2
	cmp	r9, r2
	beq	1f
	movq	#90, r0	; check 344
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#92, r0	; check 346
	halt
1:
	movq	=1073856512, r2
	cmp	r6, r2
	beq	1f
	movq	#93, r0	; check 347
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#94, r0	; check 348
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#96, r0	; check 350
	halt
1:
	lea	ins_m_29_load, r11
	cmp	r6, r11
	beq	1f
	movq	#97, r0	; check 351
	halt
1:
	movq	=1073860616, r2
	cmp	r9, r2
	beq	1f
	movq	#98, r0	; check 352
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#100, r0	; check 354
	halt
1:
	lea	ins_m_29_store, r11
	cmp	r6, r11
	beq	1f
	movq	#101, r0	; check 355
	halt
1:
	movq	=1073860616, r2
	cmp	r9, r2
	beq	1f
	movq	#102, r0	; check 356
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#104, r0	; check 358
	halt
1:
	movq	=1073860608, r2
	cmp	r6, r2
	beq	1f
	movq	#105, r0	; check 359
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#106, r0	; check 360
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#108, r0	; check 362
	halt
1:
	lea	ins_m_30_load, r11
	cmp	r6, r11
	beq	1f
	movq	#109, r0	; check 363
	halt
1:
	movq	=1073864712, r2
	cmp	r9, r2
	beq	1f
	movq	#110, r0	; check 364
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#112, r0	; check 366
	halt
1:
	lea	ins_m_30_store, r11
	cmp	r6, r11
	beq	1f
	movq	#113, r0	; check 367
	halt
1:
	movq	=1073864712, r2
	cmp	r9, r2
	beq	1f
	movq	#114, r0	; check 368
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#116, r0	; check 370
	halt
1:
	movq	=1073864704, r2
	cmp	r6, r2
	beq	1f
	movq	#117, r0	; check 371
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#118, r0	; check 372
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#120, r0	; check 374
	halt
1:
	lea	ins_m_31_load, r11
	cmp	r6, r11
	beq	1f
	movq	#121, r0	; check 375
	halt
1:
	movq	=1073868808, r2
	cmp	r9, r2
	beq	1f
	movq	#122, r0	; check 376
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#124, r0	; check 378
	halt
1:
	lea	ins_m_31_store, r11
	cmp	r6, r11
	beq	1f
	movq	#125, r0	; check 379
	halt
1:
	movq	=1073868808, r2
	cmp	r9, r2
	beq	1f
	movq	#126, r0	; check 380
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#128, r0	; check 382
	halt
1:
	movq	=1073868800, r2
	cmp	r6, r2
	beq	1f
	movq	#129, r0	; check 383
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#130, r0	; check 384
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#132, r0	; check 386
	halt
1:
	lea	ins_m_32_load, r11
	cmp	r6, r11
	beq	1f
	movq	#133, r0	; check 387
	halt
1:
	movq	=1073872904, r2
	cmp	r9, r2
	beq	1f
	movq	#134, r0	; check 388
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#136, r0	; check 390
	halt
1:
	lea	ins_m_32_store, r11
	cmp	r6, r11
	beq	1f
	movq	#137, r0	; check 391
	halt
1:
	movq	=1073872904, r2
	cmp	r9, r2
	beq	1f
	movq	#138, r0	; check 392
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#140, r0	; check 394
	halt
1:
	movq	=1073872896, r2
	cmp	r6, r2
	beq	1f
	movq	#141, r0	; check 395
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#142, r0	; check 396
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#144, r0	; check 398
	halt
1:
	lea	ins_m_33_load, r11
	cmp	r6, r11
	beq	1f
	movq	#145, r0	; check 399
	halt
1:
	movq	=1073877000, r2
	cmp	r9, r2
	beq	1f
	movq	#146, r0	; check 400
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#148, r0	; check 402
	halt
1:
	lea	ins_m_33_store, r11
	cmp	r6, r11
	beq	1f
	movq	#149, r0	; check 403
	halt
1:
	movq	=1073877000, r2
	cmp	r9, r2
	beq	1f
	movq	#150, r0	; check 404
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#152, r0	; check 406
	halt
1:
	movq	=1073876992, r2
	cmp	r6, r2
	beq	1f
	movq	#153, r0	; check 407
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#154, r0	; check 408
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#156, r0	; check 410
	halt
1:
	lea	ins_m_34_load, r11
	cmp	r6, r11
	beq	1f
	movq	#157, r0	; check 411
	halt
1:
	movq	=1073881096, r2
	cmp	r9, r2
	beq	1f
	movq	#158, r0	; check 412
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#160, r0	; check 414
	halt
1:
	lea	ins_m_34_store, r11
	cmp	r6, r11
	beq	1f
	movq	#161, r0	; check 415
	halt
1:
	movq	=1073881096, r2
	cmp	r9, r2
	beq	1f
	movq	#162, r0	; check 416
	halt
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
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#164, r0	; check 418
	halt
1:
	movq	=1073881088, r2
	cmp	r6, r2
	beq	1f
	movq	#165, r0	; check 419
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#166, r0	; check 420
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#167, r0	; check 421
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#168, r0	; check 422
	halt
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
	movq	#169, r0	; check 423
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#170, r0	; check 424
	halt
1:
	lea	ins_m_35_store, r11
	cmp	r6, r11
	beq	1f
	movq	#171, r0	; check 425
	halt
1:
	movq	=1073885192, r2
	cmp	r9, r2
	beq	1f
	movq	#172, r0	; check 426
	halt
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
	movq	#173, r0	; check 427
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#174, r0	; check 428
	halt
1:
	movq	=1073885184, r2
	cmp	r6, r2
	beq	1f
	movq	#175, r0	; check 429
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#176, r0	; check 430
	halt
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
	movq	#177, r0	; check 431
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#178, r0	; check 432
	halt
1:
	lea	ins_m_36_load, r11
	cmp	r6, r11
	beq	1f
	movq	#179, r0	; check 433
	halt
1:
	movq	=1073889288, r2
	cmp	r9, r2
	beq	1f
	movq	#180, r0	; check 434
	halt
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
	movq	#181, r0	; check 435
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#182, r0	; check 436
	halt
1:
	lea	ins_m_36_store, r11
	cmp	r6, r11
	beq	1f
	movq	#183, r0	; check 437
	halt
1:
	movq	=1073889288, r2
	cmp	r9, r2
	beq	1f
	movq	#184, r0	; check 438
	halt
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
	movq	#185, r0	; check 439
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#186, r0	; check 440
	halt
1:
	movq	=1073889280, r2
	cmp	r6, r2
	beq	1f
	movq	#187, r0	; check 441
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#188, r0	; check 442
	halt
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
	movq	#189, r0	; check 443
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#190, r0	; check 444
	halt
1:
	lea	ins_m_37_load, r11
	cmp	r6, r11
	beq	1f
	movq	#191, r0	; check 445
	halt
1:
	movq	=1073893384, r2
	cmp	r9, r2
	beq	1f
	movq	#192, r0	; check 446
	halt
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
	movq	#193, r0	; check 447
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#194, r0	; check 448
	halt
1:
	lea	ins_m_37_store, r11
	cmp	r6, r11
	beq	1f
	movq	#195, r0	; check 449
	halt
1:
	movq	=1073893384, r2
	cmp	r9, r2
	beq	1f
	movq	#196, r0	; check 450
	halt
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
	movq	#197, r0	; check 451
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#198, r0	; check 452
	halt
1:
	movq	=1073893376, r2
	cmp	r6, r2
	beq	1f
	movq	#199, r0	; check 453
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#200, r0	; check 454
	halt
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
	movq	#201, r0	; check 455
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#202, r0	; check 456
	halt
1:
	lea	ins_m_38_load, r11
	cmp	r6, r11
	beq	1f
	movq	#203, r0	; check 457
	halt
1:
	movq	=1073897480, r2
	cmp	r9, r2
	beq	1f
	movq	#204, r0	; check 458
	halt
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
	movq	#205, r0	; check 459
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#206, r0	; check 460
	halt
1:
	lea	ins_m_38_store, r11
	cmp	r6, r11
	beq	1f
	movq	#207, r0	; check 461
	halt
1:
	movq	=1073897480, r2
	cmp	r9, r2
	beq	1f
	movq	#208, r0	; check 462
	halt
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
	movq	#209, r0	; check 463
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#210, r0	; check 464
	halt
1:
	movq	=1073897472, r2
	cmp	r6, r2
	beq	1f
	movq	#211, r0	; check 465
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#212, r0	; check 466
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#213, r0	; check 467
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#214, r0	; check 468
	halt
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
	movq	#215, r0	; check 469
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#216, r0	; check 470
	halt
1:
	lea	ins_m_39_store, r11
	cmp	r6, r11
	beq	1f
	movq	#217, r0	; check 471
	halt
1:
	movq	=1073901576, r2
	cmp	r9, r2
	beq	1f
	movq	#218, r0	; check 472
	halt
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
	movq	#219, r0	; check 473
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#220, r0	; check 474
	halt
1:
	movq	=1073901568, r2
	cmp	r6, r2
	beq	1f
	movq	#221, r0	; check 475
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#222, r0	; check 476
	halt
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
	movq	#223, r0	; check 477
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#224, r0	; check 478
	halt
1:
	lea	ins_m_40_load, r11
	cmp	r6, r11
	beq	1f
	movq	#225, r0	; check 479
	halt
1:
	movq	=1073905672, r2
	cmp	r9, r2
	beq	1f
	movq	#226, r0	; check 480
	halt
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
	movq	#227, r0	; check 481
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#228, r0	; check 482
	halt
1:
	lea	ins_m_40_store, r11
	cmp	r6, r11
	beq	1f
	movq	#229, r0	; check 483
	halt
1:
	movq	=1073905672, r2
	cmp	r9, r2
	beq	1f
	movq	#230, r0	; check 484
	halt
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
	movq	#231, r0	; check 485
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#232, r0	; check 486
	halt
1:
	movq	=1073905664, r2
	cmp	r6, r2
	beq	1f
	movq	#233, r0	; check 487
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#234, r0	; check 488
	halt
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
	movq	#235, r0	; check 489
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#236, r0	; check 490
	halt
1:
	lea	ins_m_41_load, r11
	cmp	r6, r11
	beq	1f
	movq	#237, r0	; check 491
	halt
1:
	movq	=1073909768, r2
	cmp	r9, r2
	beq	1f
	movq	#238, r0	; check 492
	halt
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
	movq	#239, r0	; check 493
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#240, r0	; check 494
	halt
1:
	lea	ins_m_41_store, r11
	cmp	r6, r11
	beq	1f
	movq	#241, r0	; check 495
	halt
1:
	movq	=1073909768, r2
	cmp	r9, r2
	beq	1f
	movq	#242, r0	; check 496
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#243, r0	; check 497
	halt
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
	movq	#244, r0	; check 498
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#245, r0	; check 499
	halt
1:
	lea	ins_m_42_load, r11
	cmp	r6, r11
	beq	1f
	movq	#246, r0	; check 500
	halt
1:
	movq	=1073913864, r2
	cmp	r9, r2
	beq	1f
	movq	#247, r0	; check 501
	halt
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
	movq	#248, r0	; check 502
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#249, r0	; check 503
	halt
1:
	lea	ins_m_42_store, r11
	cmp	r6, r11
	beq	1f
	movq	#250, r0	; check 504
	halt
1:
	movq	=1073913864, r2
	cmp	r9, r2
	beq	1f
	movq	#251, r0	; check 505
	halt
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
	movq	#252, r0	; check 506
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#253, r0	; check 507
	halt
1:
	movq	=1073913856, r2
	cmp	r6, r2
	beq	1f
	movq	#254, r0	; check 508
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#255, r0	; check 509
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#1, r0	; check 510
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#2, r0	; check 511
	halt
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
	movq	#3, r0	; check 512
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#4, r0	; check 513
	halt
1:
	lea	ins_m_43_store, r11
	cmp	r6, r11
	beq	1f
	movq	#5, r0	; check 514
	halt
1:
	movq	=1073917960, r2
	cmp	r9, r2
	beq	1f
	movq	#6, r0	; check 515
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#7, r0	; check 516
	halt
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
	movq	#8, r0	; check 517
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#9, r0	; check 518
	halt
1:
	lea	ins_m_44_load, r11
	cmp	r6, r11
	beq	1f
	movq	#10, r0	; check 519
	halt
1:
	movq	=1073922056, r2
	cmp	r9, r2
	beq	1f
	movq	#11, r0	; check 520
	halt
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
	movq	#12, r0	; check 521
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#13, r0	; check 522
	halt
1:
	lea	ins_m_44_store, r11
	cmp	r6, r11
	beq	1f
	movq	#14, r0	; check 523
	halt
1:
	movq	=1073922056, r2
	cmp	r9, r2
	beq	1f
	movq	#15, r0	; check 524
	halt
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
	movq	#16, r0	; check 525
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#17, r0	; check 526
	halt
1:
	movq	=1073922048, r2
	cmp	r6, r2
	beq	1f
	movq	#18, r0	; check 527
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#19, r0	; check 528
	halt
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
	movq	#20, r0	; check 529
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#21, r0	; check 530
	halt
1:
	lea	ins_m_45_load, r11
	cmp	r6, r11
	beq	1f
	movq	#22, r0	; check 531
	halt
1:
	movq	=1073926152, r2
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 532
	halt
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
	movq	#24, r0	; check 533
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#25, r0	; check 534
	halt
1:
	lea	ins_m_45_store, r11
	cmp	r6, r11
	beq	1f
	movq	#26, r0	; check 535
	halt
1:
	movq	=1073926152, r2
	cmp	r9, r2
	beq	1f
	movq	#27, r0	; check 536
	halt
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
	movq	#28, r0	; check 537
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#29, r0	; check 538
	halt
1:
	movq	=1073926144, r2
	cmp	r6, r2
	beq	1f
	movq	#30, r0	; check 539
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#31, r0	; check 540
	halt
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
	movq	#32, r0	; check 541
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#33, r0	; check 542
	halt
1:
	lea	ins_m_46_load, r11
	cmp	r6, r11
	beq	1f
	movq	#34, r0	; check 543
	halt
1:
	movq	=1073930248, r2
	cmp	r9, r2
	beq	1f
	movq	#35, r0	; check 544
	halt
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
	movq	#36, r0	; check 545
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#37, r0	; check 546
	halt
1:
	lea	ins_m_46_store, r11
	cmp	r6, r11
	beq	1f
	movq	#38, r0	; check 547
	halt
1:
	movq	=1073930248, r2
	cmp	r9, r2
	beq	1f
	movq	#39, r0	; check 548
	halt
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
	movq	#40, r0	; check 549
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#41, r0	; check 550
	halt
1:
	movq	=1073930240, r2
	cmp	r6, r2
	beq	1f
	movq	#42, r0	; check 551
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#43, r0	; check 552
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#44, r0	; check 553
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#45, r0	; check 554
	halt
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
	movq	#46, r0	; check 555
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#47, r0	; check 556
	halt
1:
	lea	ins_m_47_store, r11
	cmp	r6, r11
	beq	1f
	movq	#48, r0	; check 557
	halt
1:
	movq	=1073934344, r2
	cmp	r9, r2
	beq	1f
	movq	#49, r0	; check 558
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#50, r0	; check 559
	halt
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
	movq	#51, r0	; check 560
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#52, r0	; check 561
	halt
1:
	lea	ins_m_48_load, r11
	cmp	r6, r11
	beq	1f
	movq	#53, r0	; check 562
	halt
1:
	movq	=1073938440, r2
	cmp	r9, r2
	beq	1f
	movq	#54, r0	; check 563
	halt
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
	movq	#55, r0	; check 564
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#56, r0	; check 565
	halt
1:
	lea	ins_m_48_store, r11
	cmp	r6, r11
	beq	1f
	movq	#57, r0	; check 566
	halt
1:
	movq	=1073938440, r2
	cmp	r9, r2
	beq	1f
	movq	#58, r0	; check 567
	halt
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
	movq	#59, r0	; check 568
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#60, r0	; check 569
	halt
1:
	movq	=1073938432, r2
	cmp	r6, r2
	beq	1f
	movq	#61, r0	; check 570
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#62, r0	; check 571
	halt
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
	movq	#63, r0	; check 572
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#64, r0	; check 573
	halt
1:
	lea	ins_m_49_load, r11
	cmp	r6, r11
	beq	1f
	movq	#65, r0	; check 574
	halt
1:
	movq	=1073942536, r2
	cmp	r9, r2
	beq	1f
	movq	#66, r0	; check 575
	halt
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
	movq	#67, r0	; check 576
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#68, r0	; check 577
	halt
1:
	lea	ins_m_49_store, r11
	cmp	r6, r11
	beq	1f
	movq	#69, r0	; check 578
	halt
1:
	movq	=1073942536, r2
	cmp	r9, r2
	beq	1f
	movq	#70, r0	; check 579
	halt
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
	movq	#71, r0	; check 580
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#72, r0	; check 581
	halt
1:
	movq	=1073942528, r2
	cmp	r6, r2
	beq	1f
	movq	#73, r0	; check 582
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#74, r0	; check 583
	halt
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
	movq	#75, r0	; check 584
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#76, r0	; check 585
	halt
1:
	lea	ins_m_50_load, r11
	cmp	r6, r11
	beq	1f
	movq	#77, r0	; check 586
	halt
1:
	movq	=1073946632, r2
	cmp	r9, r2
	beq	1f
	movq	#78, r0	; check 587
	halt
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
	movq	#79, r0	; check 588
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#80, r0	; check 589
	halt
1:
	lea	ins_m_50_store, r11
	cmp	r6, r11
	beq	1f
	movq	#81, r0	; check 590
	halt
1:
	movq	=1073946632, r2
	cmp	r9, r2
	beq	1f
	movq	#82, r0	; check 591
	halt
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
	movq	#83, r0	; check 592
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#84, r0	; check 593
	halt
1:
	movq	=1073946624, r2
	cmp	r6, r2
	beq	1f
	movq	#85, r0	; check 594
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#86, r0	; check 595
	halt
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
	movq	#87, r0	; check 596
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#88, r0	; check 597
	halt
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
	movq	#89, r0	; check 598
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#90, r0	; check 599
	halt
1:
	lea	ins_m_51_store, r11
	cmp	r6, r11
	beq	1f
	movq	#91, r0	; check 600
	halt
1:
	movq	=1073950728, r2
	cmp	r9, r2
	beq	1f
	movq	#92, r0	; check 601
	halt
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
	movq	#93, r0	; check 602
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#94, r0	; check 603
	halt
1:
	movq	=1073950720, r2
	cmp	r6, r2
	beq	1f
	movq	#95, r0	; check 604
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#96, r0	; check 605
	halt
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
	movq	#97, r0	; check 606
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#98, r0	; check 607
	halt
1:
	lea	ins_m_52_load, r11
	cmp	r6, r11
	beq	1f
	movq	#99, r0	; check 608
	halt
1:
	movq	=1073954824, r2
	cmp	r9, r2
	beq	1f
	movq	#100, r0	; check 609
	halt
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
	movq	#101, r0	; check 610
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#102, r0	; check 611
	halt
1:
	lea	ins_m_52_store, r11
	cmp	r6, r11
	beq	1f
	movq	#103, r0	; check 612
	halt
1:
	movq	=1073954824, r2
	cmp	r9, r2
	beq	1f
	movq	#104, r0	; check 613
	halt
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
	movq	#105, r0	; check 614
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#106, r0	; check 615
	halt
1:
	movq	=1073954816, r2
	cmp	r6, r2
	beq	1f
	movq	#107, r0	; check 616
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#108, r0	; check 617
	halt
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
	movq	#109, r0	; check 618
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#110, r0	; check 619
	halt
1:
	lea	ins_m_53_load, r11
	cmp	r6, r11
	beq	1f
	movq	#111, r0	; check 620
	halt
1:
	movq	=1073958920, r2
	cmp	r9, r2
	beq	1f
	movq	#112, r0	; check 621
	halt
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
	movq	#113, r0	; check 622
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#114, r0	; check 623
	halt
1:
	lea	ins_m_53_store, r11
	cmp	r6, r11
	beq	1f
	movq	#115, r0	; check 624
	halt
1:
	movq	=1073958920, r2
	cmp	r9, r2
	beq	1f
	movq	#116, r0	; check 625
	halt
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
	movq	#117, r0	; check 626
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#118, r0	; check 627
	halt
1:
	movq	=1073958912, r2
	cmp	r6, r2
	beq	1f
	movq	#119, r0	; check 628
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#120, r0	; check 629
	halt
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
	movq	#121, r0	; check 630
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#122, r0	; check 631
	halt
1:
	lea	ins_m_54_load, r11
	cmp	r6, r11
	beq	1f
	movq	#123, r0	; check 632
	halt
1:
	movq	=1073963016, r2
	cmp	r9, r2
	beq	1f
	movq	#124, r0	; check 633
	halt
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
	movq	#125, r0	; check 634
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#126, r0	; check 635
	halt
1:
	lea	ins_m_54_store, r11
	cmp	r6, r11
	beq	1f
	movq	#127, r0	; check 636
	halt
1:
	movq	=1073963016, r2
	cmp	r9, r2
	beq	1f
	movq	#128, r0	; check 637
	halt
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
	movq	#129, r0	; check 638
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#130, r0	; check 639
	halt
1:
	movq	=1073963008, r2
	cmp	r6, r2
	beq	1f
	movq	#131, r0	; check 640
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#132, r0	; check 641
	halt
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
	movq	#133, r0	; check 642
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#134, r0	; check 643
	halt
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
	movq	#135, r0	; check 644
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#136, r0	; check 645
	halt
1:
	lea	ins_m_55_store, r11
	cmp	r6, r11
	beq	1f
	movq	#137, r0	; check 646
	halt
1:
	movq	=1073967112, r2
	cmp	r9, r2
	beq	1f
	movq	#138, r0	; check 647
	halt
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
	movq	#139, r0	; check 648
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#140, r0	; check 649
	halt
1:
	movq	=1073967104, r2
	cmp	r6, r2
	beq	1f
	movq	#141, r0	; check 650
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#142, r0	; check 651
	halt
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
	movq	#143, r0	; check 652
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#144, r0	; check 653
	halt
1:
	lea	ins_m_56_load, r11
	cmp	r6, r11
	beq	1f
	movq	#145, r0	; check 654
	halt
1:
	movq	=1073971208, r2
	cmp	r9, r2
	beq	1f
	movq	#146, r0	; check 655
	halt
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
	movq	#147, r0	; check 656
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#148, r0	; check 657
	halt
1:
	lea	ins_m_56_store, r11
	cmp	r6, r11
	beq	1f
	movq	#149, r0	; check 658
	halt
1:
	movq	=1073971208, r2
	cmp	r9, r2
	beq	1f
	movq	#150, r0	; check 659
	halt
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
	movq	#151, r0	; check 660
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#152, r0	; check 661
	halt
1:
	movq	=1073971200, r2
	cmp	r6, r2
	beq	1f
	movq	#153, r0	; check 662
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#154, r0	; check 663
	halt
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
	movq	#155, r0	; check 664
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#156, r0	; check 665
	halt
1:
	lea	ins_m_57_load, r11
	cmp	r6, r11
	beq	1f
	movq	#157, r0	; check 666
	halt
1:
	movq	=1073975304, r2
	cmp	r9, r2
	beq	1f
	movq	#158, r0	; check 667
	halt
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
	movq	#159, r0	; check 668
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#160, r0	; check 669
	halt
1:
	lea	ins_m_57_store, r11
	cmp	r6, r11
	beq	1f
	movq	#161, r0	; check 670
	halt
1:
	movq	=1073975304, r2
	cmp	r9, r2
	beq	1f
	movq	#162, r0	; check 671
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#163, r0	; check 672
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#164, r0	; check 673
	halt
1:
	movq	=1073975296, r2
	cmp	r6, r2
	beq	1f
	movq	#165, r0	; check 674
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#166, r0	; check 675
	halt
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
	movq	#167, r0	; check 676
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#168, r0	; check 677
	halt
1:
	lea	ins_m_58_load, r11
	cmp	r6, r11
	beq	1f
	movq	#169, r0	; check 678
	halt
1:
	movq	=1073979400, r2
	cmp	r9, r2
	beq	1f
	movq	#170, r0	; check 679
	halt
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
	movq	#171, r0	; check 680
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#172, r0	; check 681
	halt
1:
	lea	ins_m_58_store, r11
	cmp	r6, r11
	beq	1f
	movq	#173, r0	; check 682
	halt
1:
	movq	=1073979400, r2
	cmp	r9, r2
	beq	1f
	movq	#174, r0	; check 683
	halt
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
	movq	#175, r0	; check 684
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#176, r0	; check 685
	halt
1:
	movq	=1073979392, r2
	cmp	r6, r2
	beq	1f
	movq	#177, r0	; check 686
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#178, r0	; check 687
	halt
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
	movq	#179, r0	; check 688
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#180, r0	; check 689
	halt
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
	movq	#181, r0	; check 690
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#182, r0	; check 691
	halt
1:
	lea	ins_m_59_store, r11
	cmp	r6, r11
	beq	1f
	movq	#183, r0	; check 692
	halt
1:
	movq	=1073983496, r2
	cmp	r9, r2
	beq	1f
	movq	#184, r0	; check 693
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#185, r0	; check 694
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#186, r0	; check 695
	halt
1:
	movq	=1073983488, r2
	cmp	r6, r2
	beq	1f
	movq	#187, r0	; check 696
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#188, r0	; check 697
	halt
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
	movq	#189, r0	; check 698
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#190, r0	; check 699
	halt
1:
	lea	ins_m_60_load, r11
	cmp	r6, r11
	beq	1f
	movq	#191, r0	; check 700
	halt
1:
	movq	=1073987592, r2
	cmp	r9, r2
	beq	1f
	movq	#192, r0	; check 701
	halt
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
	movq	#193, r0	; check 702
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#194, r0	; check 703
	halt
1:
	lea	ins_m_60_store, r11
	cmp	r6, r11
	beq	1f
	movq	#195, r0	; check 704
	halt
1:
	movq	=1073987592, r2
	cmp	r9, r2
	beq	1f
	movq	#196, r0	; check 705
	halt
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
	movq	#197, r0	; check 706
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#198, r0	; check 707
	halt
1:
	movq	=1073987584, r2
	cmp	r6, r2
	beq	1f
	movq	#199, r0	; check 708
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#200, r0	; check 709
	halt
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
	movq	#201, r0	; check 710
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#202, r0	; check 711
	halt
1:
	lea	ins_m_61_load, r11
	cmp	r6, r11
	beq	1f
	movq	#203, r0	; check 712
	halt
1:
	movq	=1073991688, r2
	cmp	r9, r2
	beq	1f
	movq	#204, r0	; check 713
	halt
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
	movq	#205, r0	; check 714
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#206, r0	; check 715
	halt
1:
	lea	ins_m_61_store, r11
	cmp	r6, r11
	beq	1f
	movq	#207, r0	; check 716
	halt
1:
	movq	=1073991688, r2
	cmp	r9, r2
	beq	1f
	movq	#208, r0	; check 717
	halt
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
	movq	#209, r0	; check 718
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#210, r0	; check 719
	halt
1:
	movq	=1073991680, r2
	cmp	r6, r2
	beq	1f
	movq	#211, r0	; check 720
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#212, r0	; check 721
	halt
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
	movq	#213, r0	; check 722
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#214, r0	; check 723
	halt
1:
	lea	ins_m_62_load, r11
	cmp	r6, r11
	beq	1f
	movq	#215, r0	; check 724
	halt
1:
	movq	=1073995784, r2
	cmp	r9, r2
	beq	1f
	movq	#216, r0	; check 725
	halt
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
	movq	#217, r0	; check 726
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#218, r0	; check 727
	halt
1:
	lea	ins_m_62_store, r11
	cmp	r6, r11
	beq	1f
	movq	#219, r0	; check 728
	halt
1:
	movq	=1073995784, r2
	cmp	r9, r2
	beq	1f
	movq	#220, r0	; check 729
	halt
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
	movq	#221, r0	; check 730
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#222, r0	; check 731
	halt
1:
	movq	=1073995776, r2
	cmp	r6, r2
	beq	1f
	movq	#223, r0	; check 732
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#224, r0	; check 733
	halt
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
	movq	#225, r0	; check 734
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#226, r0	; check 735
	halt
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
	movq	#227, r0	; check 736
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#228, r0	; check 737
	halt
1:
	lea	ins_m_63_store, r11
	cmp	r6, r11
	beq	1f
	movq	#229, r0	; check 738
	halt
1:
	movq	=1073999880, r2
	cmp	r9, r2
	beq	1f
	movq	#230, r0	; check 739
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#231, r0	; check 740
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#232, r0	; check 741
	halt
1:
	movq	=1073999872, r2
	cmp	r6, r2
	beq	1f
	movq	#233, r0	; check 742
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#234, r0	; check 743
	halt
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
	movq	#235, r0	; check 744
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#236, r0	; check 745
	halt
1:
	lea	ins_m_64_load, r11
	cmp	r6, r11
	beq	1f
	movq	#237, r0	; check 746
	halt
1:
	movq	=1074003976, r2
	cmp	r9, r2
	beq	1f
	movq	#238, r0	; check 747
	halt
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
	movq	#239, r0	; check 748
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#240, r0	; check 749
	halt
1:
	lea	ins_m_64_store, r11
	cmp	r6, r11
	beq	1f
	movq	#241, r0	; check 750
	halt
1:
	movq	=1074003976, r2
	cmp	r9, r2
	beq	1f
	movq	#242, r0	; check 751
	halt
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
	movq	#243, r0	; check 752
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#244, r0	; check 753
	halt
1:
	movq	=1074003968, r2
	cmp	r6, r2
	beq	1f
	movq	#245, r0	; check 754
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#246, r0	; check 755
	halt
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
	movq	#247, r0	; check 756
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#248, r0	; check 757
	halt
1:
	lea	ins_m_65_load, r11
	cmp	r6, r11
	beq	1f
	movq	#249, r0	; check 758
	halt
1:
	movq	=1074008072, r2
	cmp	r9, r2
	beq	1f
	movq	#250, r0	; check 759
	halt
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
	movq	#251, r0	; check 760
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#252, r0	; check 761
	halt
1:
	lea	ins_m_65_store, r11
	cmp	r6, r11
	beq	1f
	movq	#253, r0	; check 762
	halt
1:
	movq	=1074008072, r2
	cmp	r9, r2
	beq	1f
	movq	#254, r0	; check 763
	halt
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
	movq	#255, r0	; check 764
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#1, r0	; check 765
	halt
1:
	movq	=1074008064, r2
	cmp	r6, r2
	beq	1f
	movq	#2, r0	; check 766
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#3, r0	; check 767
	halt
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
	movq	#4, r0	; check 768
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#5, r0	; check 769
	halt
1:
	lea	ins_m_66_load, r11
	cmp	r6, r11
	beq	1f
	movq	#6, r0	; check 770
	halt
1:
	movq	=1074012168, r2
	cmp	r9, r2
	beq	1f
	movq	#7, r0	; check 771
	halt
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
	movq	#8, r0	; check 772
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#9, r0	; check 773
	halt
1:
	lea	ins_m_66_store, r11
	cmp	r6, r11
	beq	1f
	movq	#10, r0	; check 774
	halt
1:
	movq	=1074012168, r2
	cmp	r9, r2
	beq	1f
	movq	#11, r0	; check 775
	halt
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
	movq	#12, r0	; check 776
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#13, r0	; check 777
	halt
1:
	movq	=1074012160, r2
	cmp	r6, r2
	beq	1f
	movq	#14, r0	; check 778
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#15, r0	; check 779
	halt
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
	movq	#16, r0	; check 780
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#17, r0	; check 781
	halt
1:
	lea	ins_m_67_load, r11
	cmp	r6, r11
	beq	1f
	movq	#18, r0	; check 782
	halt
1:
	movq	=1074016264, r2
	cmp	r9, r2
	beq	1f
	movq	#19, r0	; check 783
	halt
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
	movq	#20, r0	; check 784
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#21, r0	; check 785
	halt
1:
	lea	ins_m_67_store, r11
	cmp	r6, r11
	beq	1f
	movq	#22, r0	; check 786
	halt
1:
	movq	=1074016264, r2
	cmp	r9, r2
	beq	1f
	movq	#23, r0	; check 787
	halt
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
	movq	#24, r0	; check 788
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#25, r0	; check 789
	halt
1:
	movq	=1074016256, r2
	cmp	r6, r2
	beq	1f
	movq	#26, r0	; check 790
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#27, r0	; check 791
	halt
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
	movq	#28, r0	; check 792
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#29, r0	; check 793
	halt
1:
	lea	ins_m_68_load, r11
	cmp	r6, r11
	beq	1f
	movq	#30, r0	; check 794
	halt
1:
	movq	=1074020360, r2
	cmp	r9, r2
	beq	1f
	movq	#31, r0	; check 795
	halt
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
	movq	#32, r0	; check 796
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#33, r0	; check 797
	halt
1:
	lea	ins_m_68_store, r11
	cmp	r6, r11
	beq	1f
	movq	#34, r0	; check 798
	halt
1:
	movq	=1074020360, r2
	cmp	r9, r2
	beq	1f
	movq	#35, r0	; check 799
	halt
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
	movq	#36, r0	; check 800
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#37, r0	; check 801
	halt
1:
	movq	=1074020352, r2
	cmp	r6, r2
	beq	1f
	movq	#38, r0	; check 802
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#39, r0	; check 803
	halt
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
	movq	#40, r0	; check 804
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#41, r0	; check 805
	halt
1:
	lea	ins_m_69_load, r11
	cmp	r6, r11
	beq	1f
	movq	#42, r0	; check 806
	halt
1:
	movq	=1074024456, r2
	cmp	r9, r2
	beq	1f
	movq	#43, r0	; check 807
	halt
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
	movq	#44, r0	; check 808
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#45, r0	; check 809
	halt
1:
	lea	ins_m_69_store, r11
	cmp	r6, r11
	beq	1f
	movq	#46, r0	; check 810
	halt
1:
	movq	=1074024456, r2
	cmp	r9, r2
	beq	1f
	movq	#47, r0	; check 811
	halt
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
	movq	#48, r0	; check 812
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#49, r0	; check 813
	halt
1:
	movq	=1074024448, r2
	cmp	r6, r2
	beq	1f
	movq	#50, r0	; check 814
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#51, r0	; check 815
	halt
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
	movq	#52, r0	; check 816
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#53, r0	; check 817
	halt
1:
	lea	ins_m_70_load, r11
	cmp	r6, r11
	beq	1f
	movq	#54, r0	; check 818
	halt
1:
	movq	=1074028552, r2
	cmp	r9, r2
	beq	1f
	movq	#55, r0	; check 819
	halt
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
	movq	#56, r0	; check 820
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#57, r0	; check 821
	halt
1:
	lea	ins_m_70_store, r11
	cmp	r6, r11
	beq	1f
	movq	#58, r0	; check 822
	halt
1:
	movq	=1074028552, r2
	cmp	r9, r2
	beq	1f
	movq	#59, r0	; check 823
	halt
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
	movq	#60, r0	; check 824
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#61, r0	; check 825
	halt
1:
	movq	=1074028544, r2
	cmp	r6, r2
	beq	1f
	movq	#62, r0	; check 826
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#63, r0	; check 827
	halt
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
	movq	#64, r0	; check 828
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#65, r0	; check 829
	halt
1:
	lea	ins_m_71_load, r11
	cmp	r6, r11
	beq	1f
	movq	#66, r0	; check 830
	halt
1:
	movq	=1074032648, r2
	cmp	r9, r2
	beq	1f
	movq	#67, r0	; check 831
	halt
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
	movq	#68, r0	; check 832
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#69, r0	; check 833
	halt
1:
	lea	ins_m_71_store, r11
	cmp	r6, r11
	beq	1f
	movq	#70, r0	; check 834
	halt
1:
	movq	=1074032648, r2
	cmp	r9, r2
	beq	1f
	movq	#71, r0	; check 835
	halt
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
	movq	#72, r0	; check 836
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#73, r0	; check 837
	halt
1:
	movq	=1074032640, r2
	cmp	r6, r2
	beq	1f
	movq	#74, r0	; check 838
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#75, r0	; check 839
	halt
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
	movq	#76, r0	; check 840
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#77, r0	; check 841
	halt
1:
	lea	ins_m_72_load, r11
	cmp	r6, r11
	beq	1f
	movq	#78, r0	; check 842
	halt
1:
	movq	=1074036744, r2
	cmp	r9, r2
	beq	1f
	movq	#79, r0	; check 843
	halt
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
	movq	#80, r0	; check 844
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#81, r0	; check 845
	halt
1:
	lea	ins_m_72_store, r11
	cmp	r6, r11
	beq	1f
	movq	#82, r0	; check 846
	halt
1:
	movq	=1074036744, r2
	cmp	r9, r2
	beq	1f
	movq	#83, r0	; check 847
	halt
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
	movq	#84, r0	; check 848
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#85, r0	; check 849
	halt
1:
	movq	=1074036736, r2
	cmp	r6, r2
	beq	1f
	movq	#86, r0	; check 850
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#87, r0	; check 851
	halt
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
	movq	#88, r0	; check 852
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#89, r0	; check 853
	halt
1:
	lea	ins_m_73_load, r11
	cmp	r6, r11
	beq	1f
	movq	#90, r0	; check 854
	halt
1:
	movq	=1074040840, r2
	cmp	r9, r2
	beq	1f
	movq	#91, r0	; check 855
	halt
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
	movq	#92, r0	; check 856
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#93, r0	; check 857
	halt
1:
	lea	ins_m_73_store, r11
	cmp	r6, r11
	beq	1f
	movq	#94, r0	; check 858
	halt
1:
	movq	=1074040840, r2
	cmp	r9, r2
	beq	1f
	movq	#95, r0	; check 859
	halt
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
	movq	#96, r0	; check 860
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#97, r0	; check 861
	halt
1:
	movq	=1074040832, r2
	cmp	r6, r2
	beq	1f
	movq	#98, r0	; check 862
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#99, r0	; check 863
	halt
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
	movq	#100, r0	; check 864
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#101, r0	; check 865
	halt
1:
	lea	ins_m_74_load, r11
	cmp	r6, r11
	beq	1f
	movq	#102, r0	; check 866
	halt
1:
	movq	=1074044936, r2
	cmp	r9, r2
	beq	1f
	movq	#103, r0	; check 867
	halt
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
	movq	#104, r0	; check 868
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#105, r0	; check 869
	halt
1:
	lea	ins_m_74_store, r11
	cmp	r6, r11
	beq	1f
	movq	#106, r0	; check 870
	halt
1:
	movq	=1074044936, r2
	cmp	r9, r2
	beq	1f
	movq	#107, r0	; check 871
	halt
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
	movq	#108, r0	; check 872
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#109, r0	; check 873
	halt
1:
	movq	=1074044928, r2
	cmp	r6, r2
	beq	1f
	movq	#110, r0	; check 874
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#111, r0	; check 875
	halt
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
	movq	#112, r0	; check 876
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#113, r0	; check 877
	halt
1:
	lea	ins_m_75_load, r11
	cmp	r6, r11
	beq	1f
	movq	#114, r0	; check 878
	halt
1:
	movq	=1074049032, r2
	cmp	r9, r2
	beq	1f
	movq	#115, r0	; check 879
	halt
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
	movq	#116, r0	; check 880
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#117, r0	; check 881
	halt
1:
	lea	ins_m_75_store, r11
	cmp	r6, r11
	beq	1f
	movq	#118, r0	; check 882
	halt
1:
	movq	=1074049032, r2
	cmp	r9, r2
	beq	1f
	movq	#119, r0	; check 883
	halt
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
	movq	#120, r0	; check 884
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#121, r0	; check 885
	halt
1:
	movq	=1074049024, r2
	cmp	r6, r2
	beq	1f
	movq	#122, r0	; check 886
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#123, r0	; check 887
	halt
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
	movq	#124, r0	; check 888
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#125, r0	; check 889
	halt
1:
	lea	ins_m_76_load, r11
	cmp	r6, r11
	beq	1f
	movq	#126, r0	; check 890
	halt
1:
	movq	=1074053128, r2
	cmp	r9, r2
	beq	1f
	movq	#127, r0	; check 891
	halt
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
	movq	#128, r0	; check 892
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#129, r0	; check 893
	halt
1:
	lea	ins_m_76_store, r11
	cmp	r6, r11
	beq	1f
	movq	#130, r0	; check 894
	halt
1:
	movq	=1074053128, r2
	cmp	r9, r2
	beq	1f
	movq	#131, r0	; check 895
	halt
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
	movq	#132, r0	; check 896
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#133, r0	; check 897
	halt
1:
	movq	=1074053120, r2
	cmp	r6, r2
	beq	1f
	movq	#134, r0	; check 898
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#135, r0	; check 899
	halt
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
	movq	#136, r0	; check 900
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#137, r0	; check 901
	halt
1:
	lea	ins_m_77_load, r11
	cmp	r6, r11
	beq	1f
	movq	#138, r0	; check 902
	halt
1:
	movq	=1074057224, r2
	cmp	r9, r2
	beq	1f
	movq	#139, r0	; check 903
	halt
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
	movq	#140, r0	; check 904
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#141, r0	; check 905
	halt
1:
	lea	ins_m_77_store, r11
	cmp	r6, r11
	beq	1f
	movq	#142, r0	; check 906
	halt
1:
	movq	=1074057224, r2
	cmp	r9, r2
	beq	1f
	movq	#143, r0	; check 907
	halt
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
	movq	#144, r0	; check 908
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#145, r0	; check 909
	halt
1:
	movq	=1074057216, r2
	cmp	r6, r2
	beq	1f
	movq	#146, r0	; check 910
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#147, r0	; check 911
	halt
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
	movq	#148, r0	; check 912
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#149, r0	; check 913
	halt
1:
	lea	ins_m_78_load, r11
	cmp	r6, r11
	beq	1f
	movq	#150, r0	; check 914
	halt
1:
	movq	=1074061320, r2
	cmp	r9, r2
	beq	1f
	movq	#151, r0	; check 915
	halt
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
	movq	#152, r0	; check 916
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#153, r0	; check 917
	halt
1:
	lea	ins_m_78_store, r11
	cmp	r6, r11
	beq	1f
	movq	#154, r0	; check 918
	halt
1:
	movq	=1074061320, r2
	cmp	r9, r2
	beq	1f
	movq	#155, r0	; check 919
	halt
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
	movq	#156, r0	; check 920
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#157, r0	; check 921
	halt
1:
	movq	=1074061312, r2
	cmp	r6, r2
	beq	1f
	movq	#158, r0	; check 922
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#159, r0	; check 923
	halt
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
	movq	#160, r0	; check 924
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#161, r0	; check 925
	halt
1:
	lea	ins_m_79_load, r11
	cmp	r6, r11
	beq	1f
	movq	#162, r0	; check 926
	halt
1:
	movq	=1074065416, r2
	cmp	r9, r2
	beq	1f
	movq	#163, r0	; check 927
	halt
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
	movq	#164, r0	; check 928
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#165, r0	; check 929
	halt
1:
	lea	ins_m_79_store, r11
	cmp	r6, r11
	beq	1f
	movq	#166, r0	; check 930
	halt
1:
	movq	=1074065416, r2
	cmp	r9, r2
	beq	1f
	movq	#167, r0	; check 931
	halt
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
	movq	#168, r0	; check 932
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#169, r0	; check 933
	halt
1:
	movq	=1074065408, r2
	cmp	r6, r2
	beq	1f
	movq	#170, r0	; check 934
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#171, r0	; check 935
	halt
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
	movq	#172, r0	; check 936
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#173, r0	; check 937
	halt
1:
	lea	ins_m_80_load, r11
	cmp	r6, r11
	beq	1f
	movq	#174, r0	; check 938
	halt
1:
	movq	=1074069512, r2
	cmp	r9, r2
	beq	1f
	movq	#175, r0	; check 939
	halt
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
	movq	#176, r0	; check 940
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#177, r0	; check 941
	halt
1:
	lea	ins_m_80_store, r11
	cmp	r6, r11
	beq	1f
	movq	#178, r0	; check 942
	halt
1:
	movq	=1074069512, r2
	cmp	r9, r2
	beq	1f
	movq	#179, r0	; check 943
	halt
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
	movq	#180, r0	; check 944
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#181, r0	; check 945
	halt
1:
	movq	=1074069504, r2
	cmp	r6, r2
	beq	1f
	movq	#182, r0	; check 946
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#183, r0	; check 947
	halt
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
	movq	#184, r0	; check 948
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#185, r0	; check 949
	halt
1:
	lea	ins_m_81_load, r11
	cmp	r6, r11
	beq	1f
	movq	#186, r0	; check 950
	halt
1:
	movq	=1074073608, r2
	cmp	r9, r2
	beq	1f
	movq	#187, r0	; check 951
	halt
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
	movq	#188, r0	; check 952
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#189, r0	; check 953
	halt
1:
	lea	ins_m_81_store, r11
	cmp	r6, r11
	beq	1f
	movq	#190, r0	; check 954
	halt
1:
	movq	=1074073608, r2
	cmp	r9, r2
	beq	1f
	movq	#191, r0	; check 955
	halt
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
	movq	#192, r0	; check 956
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#193, r0	; check 957
	halt
1:
	movq	=1074073600, r2
	cmp	r6, r2
	beq	1f
	movq	#194, r0	; check 958
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#195, r0	; check 959
	halt
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
	movq	#196, r0	; check 960
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#197, r0	; check 961
	halt
1:
	lea	ins_m_82_load, r11
	cmp	r6, r11
	beq	1f
	movq	#198, r0	; check 962
	halt
1:
	movq	=1074077704, r2
	cmp	r9, r2
	beq	1f
	movq	#199, r0	; check 963
	halt
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
	movq	#200, r0	; check 964
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#201, r0	; check 965
	halt
1:
	lea	ins_m_82_store, r11
	cmp	r6, r11
	beq	1f
	movq	#202, r0	; check 966
	halt
1:
	movq	=1074077704, r2
	cmp	r9, r2
	beq	1f
	movq	#203, r0	; check 967
	halt
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
	movq	#204, r0	; check 968
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#205, r0	; check 969
	halt
1:
	movq	=1074077696, r2
	cmp	r6, r2
	beq	1f
	movq	#206, r0	; check 970
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#207, r0	; check 971
	halt
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
	movq	#208, r0	; check 972
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#209, r0	; check 973
	halt
1:
	lea	ins_m_83_load, r11
	cmp	r6, r11
	beq	1f
	movq	#210, r0	; check 974
	halt
1:
	movq	=1074081800, r2
	cmp	r9, r2
	beq	1f
	movq	#211, r0	; check 975
	halt
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
	movq	#212, r0	; check 976
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#213, r0	; check 977
	halt
1:
	lea	ins_m_83_store, r11
	cmp	r6, r11
	beq	1f
	movq	#214, r0	; check 978
	halt
1:
	movq	=1074081800, r2
	cmp	r9, r2
	beq	1f
	movq	#215, r0	; check 979
	halt
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
	movq	#216, r0	; check 980
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#217, r0	; check 981
	halt
1:
	movq	=1074081792, r2
	cmp	r6, r2
	beq	1f
	movq	#218, r0	; check 982
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#219, r0	; check 983
	halt
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
	movq	#220, r0	; check 984
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#221, r0	; check 985
	halt
1:
	lea	ins_m_84_load, r11
	cmp	r6, r11
	beq	1f
	movq	#222, r0	; check 986
	halt
1:
	movq	=1074085896, r2
	cmp	r9, r2
	beq	1f
	movq	#223, r0	; check 987
	halt
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
	movq	#224, r0	; check 988
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#225, r0	; check 989
	halt
1:
	lea	ins_m_84_store, r11
	cmp	r6, r11
	beq	1f
	movq	#226, r0	; check 990
	halt
1:
	movq	=1074085896, r2
	cmp	r9, r2
	beq	1f
	movq	#227, r0	; check 991
	halt
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
	movq	#228, r0	; check 992
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#229, r0	; check 993
	halt
1:
	movq	=1074085888, r2
	cmp	r6, r2
	beq	1f
	movq	#230, r0	; check 994
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#231, r0	; check 995
	halt
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
	movq	#232, r0	; check 996
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#233, r0	; check 997
	halt
1:
	lea	ins_m_85_load, r11
	cmp	r6, r11
	beq	1f
	movq	#234, r0	; check 998
	halt
1:
	movq	=1074089992, r2
	cmp	r9, r2
	beq	1f
	movq	#235, r0	; check 999
	halt
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
	movq	#236, r0	; check 1000
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#237, r0	; check 1001
	halt
1:
	lea	ins_m_85_store, r11
	cmp	r6, r11
	beq	1f
	movq	#238, r0	; check 1002
	halt
1:
	movq	=1074089992, r2
	cmp	r9, r2
	beq	1f
	movq	#239, r0	; check 1003
	halt
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
	movq	#240, r0	; check 1004
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#241, r0	; check 1005
	halt
1:
	movq	=1074089984, r2
	cmp	r6, r2
	beq	1f
	movq	#242, r0	; check 1006
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#243, r0	; check 1007
	halt
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
	movq	#244, r0	; check 1008
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#245, r0	; check 1009
	halt
1:
	lea	ins_m_86_load, r11
	cmp	r6, r11
	beq	1f
	movq	#246, r0	; check 1010
	halt
1:
	movq	=1074094088, r2
	cmp	r9, r2
	beq	1f
	movq	#247, r0	; check 1011
	halt
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
	movq	#248, r0	; check 1012
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#249, r0	; check 1013
	halt
1:
	lea	ins_m_86_store, r11
	cmp	r6, r11
	beq	1f
	movq	#250, r0	; check 1014
	halt
1:
	movq	=1074094088, r2
	cmp	r9, r2
	beq	1f
	movq	#251, r0	; check 1015
	halt
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
	movq	#252, r0	; check 1016
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#253, r0	; check 1017
	halt
1:
	movq	=1074094080, r2
	cmp	r6, r2
	beq	1f
	movq	#254, r0	; check 1018
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#255, r0	; check 1019
	halt
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
	movq	#1, r0	; check 1020
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#2, r0	; check 1021
	halt
1:
	lea	ins_m_87_load, r11
	cmp	r6, r11
	beq	1f
	movq	#3, r0	; check 1022
	halt
1:
	movq	=1074098184, r2
	cmp	r9, r2
	beq	1f
	movq	#4, r0	; check 1023
	halt
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
	movq	#5, r0	; check 1024
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#6, r0	; check 1025
	halt
1:
	lea	ins_m_87_store, r11
	cmp	r6, r11
	beq	1f
	movq	#7, r0	; check 1026
	halt
1:
	movq	=1074098184, r2
	cmp	r9, r2
	beq	1f
	movq	#8, r0	; check 1027
	halt
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
	movq	#9, r0	; check 1028
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#10, r0	; check 1029
	halt
1:
	movq	=1074098176, r2
	cmp	r6, r2
	beq	1f
	movq	#11, r0	; check 1030
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#12, r0	; check 1031
	halt
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
	movq	#13, r0	; check 1032
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#14, r0	; check 1033
	halt
1:
	lea	ins_m_88_load, r11
	cmp	r6, r11
	beq	1f
	movq	#15, r0	; check 1034
	halt
1:
	movq	=1074102280, r2
	cmp	r9, r2
	beq	1f
	movq	#16, r0	; check 1035
	halt
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
	movq	#17, r0	; check 1036
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#18, r0	; check 1037
	halt
1:
	lea	ins_m_88_store, r11
	cmp	r6, r11
	beq	1f
	movq	#19, r0	; check 1038
	halt
1:
	movq	=1074102280, r2
	cmp	r9, r2
	beq	1f
	movq	#20, r0	; check 1039
	halt
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
	movq	#21, r0	; check 1040
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#22, r0	; check 1041
	halt
1:
	movq	=1074102272, r2
	cmp	r6, r2
	beq	1f
	movq	#23, r0	; check 1042
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#24, r0	; check 1043
	halt
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
	movq	#25, r0	; check 1044
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#26, r0	; check 1045
	halt
1:
	lea	ins_m_89_load, r11
	cmp	r6, r11
	beq	1f
	movq	#27, r0	; check 1046
	halt
1:
	movq	=1074106376, r2
	cmp	r9, r2
	beq	1f
	movq	#28, r0	; check 1047
	halt
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
	movq	#29, r0	; check 1048
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#30, r0	; check 1049
	halt
1:
	lea	ins_m_89_store, r11
	cmp	r6, r11
	beq	1f
	movq	#31, r0	; check 1050
	halt
1:
	movq	=1074106376, r2
	cmp	r9, r2
	beq	1f
	movq	#32, r0	; check 1051
	halt
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
	movq	#33, r0	; check 1052
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#34, r0	; check 1053
	halt
1:
	movq	=1074106368, r2
	cmp	r6, r2
	beq	1f
	movq	#35, r0	; check 1054
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#36, r0	; check 1055
	halt
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
	movq	#37, r0	; check 1056
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#38, r0	; check 1057
	halt
1:
	lea	ins_m_90_load, r11
	cmp	r6, r11
	beq	1f
	movq	#39, r0	; check 1058
	halt
1:
	movq	=1074110472, r2
	cmp	r9, r2
	beq	1f
	movq	#40, r0	; check 1059
	halt
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
	movq	#41, r0	; check 1060
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#42, r0	; check 1061
	halt
1:
	lea	ins_m_90_store, r11
	cmp	r6, r11
	beq	1f
	movq	#43, r0	; check 1062
	halt
1:
	movq	=1074110472, r2
	cmp	r9, r2
	beq	1f
	movq	#44, r0	; check 1063
	halt
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
	movq	#45, r0	; check 1064
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#46, r0	; check 1065
	halt
1:
	movq	=1074110464, r2
	cmp	r6, r2
	beq	1f
	movq	#47, r0	; check 1066
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#48, r0	; check 1067
	halt
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
	movq	#49, r0	; check 1068
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#50, r0	; check 1069
	halt
1:
	lea	ins_m_91_load, r11
	cmp	r6, r11
	beq	1f
	movq	#51, r0	; check 1070
	halt
1:
	movq	=1074114568, r2
	cmp	r9, r2
	beq	1f
	movq	#52, r0	; check 1071
	halt
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
	movq	#53, r0	; check 1072
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#54, r0	; check 1073
	halt
1:
	lea	ins_m_91_store, r11
	cmp	r6, r11
	beq	1f
	movq	#55, r0	; check 1074
	halt
1:
	movq	=1074114568, r2
	cmp	r9, r2
	beq	1f
	movq	#56, r0	; check 1075
	halt
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
	movq	#57, r0	; check 1076
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#58, r0	; check 1077
	halt
1:
	movq	=1074114560, r2
	cmp	r6, r2
	beq	1f
	movq	#59, r0	; check 1078
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#60, r0	; check 1079
	halt
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
	movq	#61, r0	; check 1080
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#62, r0	; check 1081
	halt
1:
	lea	ins_m_92_load, r11
	cmp	r6, r11
	beq	1f
	movq	#63, r0	; check 1082
	halt
1:
	movq	=1074118664, r2
	cmp	r9, r2
	beq	1f
	movq	#64, r0	; check 1083
	halt
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
	movq	#65, r0	; check 1084
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#66, r0	; check 1085
	halt
1:
	lea	ins_m_92_store, r11
	cmp	r6, r11
	beq	1f
	movq	#67, r0	; check 1086
	halt
1:
	movq	=1074118664, r2
	cmp	r9, r2
	beq	1f
	movq	#68, r0	; check 1087
	halt
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
	movq	#69, r0	; check 1088
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#70, r0	; check 1089
	halt
1:
	movq	=1074118656, r2
	cmp	r6, r2
	beq	1f
	movq	#71, r0	; check 1090
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#72, r0	; check 1091
	halt
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
	movq	#73, r0	; check 1092
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#74, r0	; check 1093
	halt
1:
	lea	ins_m_93_load, r11
	cmp	r6, r11
	beq	1f
	movq	#75, r0	; check 1094
	halt
1:
	movq	=1074122760, r2
	cmp	r9, r2
	beq	1f
	movq	#76, r0	; check 1095
	halt
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
	movq	#77, r0	; check 1096
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#78, r0	; check 1097
	halt
1:
	lea	ins_m_93_store, r11
	cmp	r6, r11
	beq	1f
	movq	#79, r0	; check 1098
	halt
1:
	movq	=1074122760, r2
	cmp	r9, r2
	beq	1f
	movq	#80, r0	; check 1099
	halt
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
	movq	#81, r0	; check 1100
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#82, r0	; check 1101
	halt
1:
	movq	=1074122752, r2
	cmp	r6, r2
	beq	1f
	movq	#83, r0	; check 1102
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#84, r0	; check 1103
	halt
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
	movq	#85, r0	; check 1104
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#86, r0	; check 1105
	halt
1:
	lea	ins_m_94_load, r11
	cmp	r6, r11
	beq	1f
	movq	#87, r0	; check 1106
	halt
1:
	movq	=1074126856, r2
	cmp	r9, r2
	beq	1f
	movq	#88, r0	; check 1107
	halt
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
	movq	#89, r0	; check 1108
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#90, r0	; check 1109
	halt
1:
	lea	ins_m_94_store, r11
	cmp	r6, r11
	beq	1f
	movq	#91, r0	; check 1110
	halt
1:
	movq	=1074126856, r2
	cmp	r9, r2
	beq	1f
	movq	#92, r0	; check 1111
	halt
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
	movq	#93, r0	; check 1112
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#94, r0	; check 1113
	halt
1:
	movq	=1074126848, r2
	cmp	r6, r2
	beq	1f
	movq	#95, r0	; check 1114
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#96, r0	; check 1115
	halt
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
	movq	#97, r0	; check 1116
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#98, r0	; check 1117
	halt
1:
	lea	ins_m_95_load, r11
	cmp	r6, r11
	beq	1f
	movq	#99, r0	; check 1118
	halt
1:
	movq	=1074130952, r2
	cmp	r9, r2
	beq	1f
	movq	#100, r0	; check 1119
	halt
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
	movq	#101, r0	; check 1120
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#102, r0	; check 1121
	halt
1:
	lea	ins_m_95_store, r11
	cmp	r6, r11
	beq	1f
	movq	#103, r0	; check 1122
	halt
1:
	movq	=1074130952, r2
	cmp	r9, r2
	beq	1f
	movq	#104, r0	; check 1123
	halt
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
	movq	#105, r0	; check 1124
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#106, r0	; check 1125
	halt
1:
	movq	=1074130944, r2
	cmp	r6, r2
	beq	1f
	movq	#107, r0	; check 1126
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#108, r0	; check 1127
	halt
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
	movq	#109, r0	; check 1128
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#110, r0	; check 1129
	halt
1:
	lea	ins_m_96_load, r11
	cmp	r6, r11
	beq	1f
	movq	#111, r0	; check 1130
	halt
1:
	movq	=1074135048, r2
	cmp	r9, r2
	beq	1f
	movq	#112, r0	; check 1131
	halt
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
	movq	#113, r0	; check 1132
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#114, r0	; check 1133
	halt
1:
	lea	ins_m_96_store, r11
	cmp	r6, r11
	beq	1f
	movq	#115, r0	; check 1134
	halt
1:
	movq	=1074135048, r2
	cmp	r9, r2
	beq	1f
	movq	#116, r0	; check 1135
	halt
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
	movq	#117, r0	; check 1136
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#118, r0	; check 1137
	halt
1:
	movq	=1074135040, r2
	cmp	r6, r2
	beq	1f
	movq	#119, r0	; check 1138
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#120, r0	; check 1139
	halt
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
	movq	#121, r0	; check 1140
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#122, r0	; check 1141
	halt
1:
	lea	ins_m_97_load, r11
	cmp	r6, r11
	beq	1f
	movq	#123, r0	; check 1142
	halt
1:
	movq	=1074139144, r2
	cmp	r9, r2
	beq	1f
	movq	#124, r0	; check 1143
	halt
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
	movq	#125, r0	; check 1144
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#126, r0	; check 1145
	halt
1:
	lea	ins_m_97_store, r11
	cmp	r6, r11
	beq	1f
	movq	#127, r0	; check 1146
	halt
1:
	movq	=1074139144, r2
	cmp	r9, r2
	beq	1f
	movq	#128, r0	; check 1147
	halt
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
	movq	#129, r0	; check 1148
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#130, r0	; check 1149
	halt
1:
	movq	=1074139136, r2
	cmp	r6, r2
	beq	1f
	movq	#131, r0	; check 1150
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#132, r0	; check 1151
	halt
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
	movq	#133, r0	; check 1152
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#134, r0	; check 1153
	halt
1:
	lea	ins_m_98_load, r11
	cmp	r6, r11
	beq	1f
	movq	#135, r0	; check 1154
	halt
1:
	movq	=1074143240, r2
	cmp	r9, r2
	beq	1f
	movq	#136, r0	; check 1155
	halt
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
	movq	#137, r0	; check 1156
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#138, r0	; check 1157
	halt
1:
	lea	ins_m_98_store, r11
	cmp	r6, r11
	beq	1f
	movq	#139, r0	; check 1158
	halt
1:
	movq	=1074143240, r2
	cmp	r9, r2
	beq	1f
	movq	#140, r0	; check 1159
	halt
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
	movq	#141, r0	; check 1160
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#142, r0	; check 1161
	halt
1:
	movq	=1074143232, r2
	cmp	r6, r2
	beq	1f
	movq	#143, r0	; check 1162
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#144, r0	; check 1163
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#145, r0	; check 1164
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#146, r0	; check 1165
	halt
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
	movq	#147, r0	; check 1166
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#148, r0	; check 1167
	halt
1:
	lea	ins_m_99_store, r11
	cmp	r6, r11
	beq	1f
	movq	#149, r0	; check 1168
	halt
1:
	movq	=1074147336, r2
	cmp	r9, r2
	beq	1f
	movq	#150, r0	; check 1169
	halt
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
	movq	#151, r0	; check 1170
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#152, r0	; check 1171
	halt
1:
	movq	=1074147328, r2
	cmp	r6, r2
	beq	1f
	movq	#153, r0	; check 1172
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#154, r0	; check 1173
	halt
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
	movq	#155, r0	; check 1174
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#156, r0	; check 1175
	halt
1:
	lea	ins_m_100_load, r11
	cmp	r6, r11
	beq	1f
	movq	#157, r0	; check 1176
	halt
1:
	movq	=1074151432, r2
	cmp	r9, r2
	beq	1f
	movq	#158, r0	; check 1177
	halt
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
	movq	#159, r0	; check 1178
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#160, r0	; check 1179
	halt
1:
	lea	ins_m_100_store, r11
	cmp	r6, r11
	beq	1f
	movq	#161, r0	; check 1180
	halt
1:
	movq	=1074151432, r2
	cmp	r9, r2
	beq	1f
	movq	#162, r0	; check 1181
	halt
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
	movq	#163, r0	; check 1182
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#164, r0	; check 1183
	halt
1:
	movq	=1074151424, r2
	cmp	r6, r2
	beq	1f
	movq	#165, r0	; check 1184
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#166, r0	; check 1185
	halt
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
	movq	#167, r0	; check 1186
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#168, r0	; check 1187
	halt
1:
	lea	ins_m_101_load, r11
	cmp	r6, r11
	beq	1f
	movq	#169, r0	; check 1188
	halt
1:
	movq	=1074155528, r2
	cmp	r9, r2
	beq	1f
	movq	#170, r0	; check 1189
	halt
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
	movq	#171, r0	; check 1190
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#172, r0	; check 1191
	halt
1:
	lea	ins_m_101_store, r11
	cmp	r6, r11
	beq	1f
	movq	#173, r0	; check 1192
	halt
1:
	movq	=1074155528, r2
	cmp	r9, r2
	beq	1f
	movq	#174, r0	; check 1193
	halt
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
	movq	#175, r0	; check 1194
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#176, r0	; check 1195
	halt
1:
	movq	=1074155520, r2
	cmp	r6, r2
	beq	1f
	movq	#177, r0	; check 1196
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#178, r0	; check 1197
	halt
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
	movq	#179, r0	; check 1198
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#180, r0	; check 1199
	halt
1:
	lea	ins_m_102_load, r11
	cmp	r6, r11
	beq	1f
	movq	#181, r0	; check 1200
	halt
1:
	movq	=1074159624, r2
	cmp	r9, r2
	beq	1f
	movq	#182, r0	; check 1201
	halt
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
	movq	#183, r0	; check 1202
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#184, r0	; check 1203
	halt
1:
	lea	ins_m_102_store, r11
	cmp	r6, r11
	beq	1f
	movq	#185, r0	; check 1204
	halt
1:
	movq	=1074159624, r2
	cmp	r9, r2
	beq	1f
	movq	#186, r0	; check 1205
	halt
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
	movq	#187, r0	; check 1206
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#188, r0	; check 1207
	halt
1:
	movq	=1074159616, r2
	cmp	r6, r2
	beq	1f
	movq	#189, r0	; check 1208
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#190, r0	; check 1209
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#191, r0	; check 1210
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#192, r0	; check 1211
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#193, r0	; check 1212
	halt
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
	movq	#194, r0	; check 1213
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#195, r0	; check 1214
	halt
1:
	movq	=1074163712, r2
	cmp	r6, r2
	beq	1f
	movq	#196, r0	; check 1215
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#197, r0	; check 1216
	halt
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
	movq	#198, r0	; check 1217
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#199, r0	; check 1218
	halt
1:
	lea	ins_m_104_load, r11
	cmp	r6, r11
	beq	1f
	movq	#200, r0	; check 1219
	halt
1:
	movq	=1074167816, r2
	cmp	r9, r2
	beq	1f
	movq	#201, r0	; check 1220
	halt
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
	movq	#202, r0	; check 1221
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#203, r0	; check 1222
	halt
1:
	lea	ins_m_104_store, r11
	cmp	r6, r11
	beq	1f
	movq	#204, r0	; check 1223
	halt
1:
	movq	=1074167816, r2
	cmp	r9, r2
	beq	1f
	movq	#205, r0	; check 1224
	halt
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
	movq	#206, r0	; check 1225
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#207, r0	; check 1226
	halt
1:
	movq	=1074167808, r2
	cmp	r6, r2
	beq	1f
	movq	#208, r0	; check 1227
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#209, r0	; check 1228
	halt
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
	movq	#210, r0	; check 1229
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#211, r0	; check 1230
	halt
1:
	lea	ins_m_105_load, r11
	cmp	r6, r11
	beq	1f
	movq	#212, r0	; check 1231
	halt
1:
	movq	=1074171912, r2
	cmp	r9, r2
	beq	1f
	movq	#213, r0	; check 1232
	halt
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
	movq	#214, r0	; check 1233
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#215, r0	; check 1234
	halt
1:
	lea	ins_m_105_store, r11
	cmp	r6, r11
	beq	1f
	movq	#216, r0	; check 1235
	halt
1:
	movq	=1074171912, r2
	cmp	r9, r2
	beq	1f
	movq	#217, r0	; check 1236
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#218, r0	; check 1237
	halt
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
	movq	#219, r0	; check 1238
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#220, r0	; check 1239
	halt
1:
	lea	ins_m_106_load, r11
	cmp	r6, r11
	beq	1f
	movq	#221, r0	; check 1240
	halt
1:
	movq	=1074176008, r2
	cmp	r9, r2
	beq	1f
	movq	#222, r0	; check 1241
	halt
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
	movq	#223, r0	; check 1242
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#224, r0	; check 1243
	halt
1:
	lea	ins_m_106_store, r11
	cmp	r6, r11
	beq	1f
	movq	#225, r0	; check 1244
	halt
1:
	movq	=1074176008, r2
	cmp	r9, r2
	beq	1f
	movq	#226, r0	; check 1245
	halt
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
	movq	#227, r0	; check 1246
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#228, r0	; check 1247
	halt
1:
	movq	=1074176000, r2
	cmp	r6, r2
	beq	1f
	movq	#229, r0	; check 1248
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#230, r0	; check 1249
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#231, r0	; check 1250
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#232, r0	; check 1251
	halt
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
	movq	#233, r0	; check 1252
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#234, r0	; check 1253
	halt
1:
	lea	ins_m_107_store, r11
	cmp	r6, r11
	beq	1f
	movq	#235, r0	; check 1254
	halt
1:
	movq	=1074180104, r2
	cmp	r9, r2
	beq	1f
	movq	#236, r0	; check 1255
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#237, r0	; check 1256
	halt
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
	movq	#238, r0	; check 1257
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#239, r0	; check 1258
	halt
1:
	lea	ins_m_108_load, r11
	cmp	r6, r11
	beq	1f
	movq	#240, r0	; check 1259
	halt
1:
	movq	=1074184200, r2
	cmp	r9, r2
	beq	1f
	movq	#241, r0	; check 1260
	halt
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
	movq	#242, r0	; check 1261
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#243, r0	; check 1262
	halt
1:
	lea	ins_m_108_store, r11
	cmp	r6, r11
	beq	1f
	movq	#244, r0	; check 1263
	halt
1:
	movq	=1074184200, r2
	cmp	r9, r2
	beq	1f
	movq	#245, r0	; check 1264
	halt
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
	movq	#246, r0	; check 1265
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#247, r0	; check 1266
	halt
1:
	movq	=1074184192, r2
	cmp	r6, r2
	beq	1f
	movq	#248, r0	; check 1267
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#249, r0	; check 1268
	halt
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
	movq	#250, r0	; check 1269
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#251, r0	; check 1270
	halt
1:
	lea	ins_m_109_load, r11
	cmp	r6, r11
	beq	1f
	movq	#252, r0	; check 1271
	halt
1:
	movq	=1074188296, r2
	cmp	r9, r2
	beq	1f
	movq	#253, r0	; check 1272
	halt
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
	movq	#254, r0	; check 1273
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#255, r0	; check 1274
	halt
1:
	lea	ins_m_109_store, r11
	cmp	r6, r11
	beq	1f
	movq	#1, r0	; check 1275
	halt
1:
	movq	=1074188296, r2
	cmp	r9, r2
	beq	1f
	movq	#2, r0	; check 1276
	halt
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
	movq	#3, r0	; check 1277
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#4, r0	; check 1278
	halt
1:
	movq	=1074188288, r2
	cmp	r6, r2
	beq	1f
	movq	#5, r0	; check 1279
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#6, r0	; check 1280
	halt
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
	movq	#7, r0	; check 1281
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#8, r0	; check 1282
	halt
1:
	lea	ins_m_110_load, r11
	cmp	r6, r11
	beq	1f
	movq	#9, r0	; check 1283
	halt
1:
	movq	=1074192392, r2
	cmp	r9, r2
	beq	1f
	movq	#10, r0	; check 1284
	halt
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
	movq	#11, r0	; check 1285
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#12, r0	; check 1286
	halt
1:
	lea	ins_m_110_store, r11
	cmp	r6, r11
	beq	1f
	movq	#13, r0	; check 1287
	halt
1:
	movq	=1074192392, r2
	cmp	r9, r2
	beq	1f
	movq	#14, r0	; check 1288
	halt
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
	movq	#15, r0	; check 1289
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#16, r0	; check 1290
	halt
1:
	movq	=1074192384, r2
	cmp	r6, r2
	beq	1f
	movq	#17, r0	; check 1291
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#18, r0	; check 1292
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#19, r0	; check 1293
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#20, r0	; check 1294
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#21, r0	; check 1295
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#22, r0	; check 1296
	halt
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
	movq	#23, r0	; check 1297
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#24, r0	; check 1298
	halt
1:
	lea	ins_m_112_load, r11
	cmp	r6, r11
	beq	1f
	movq	#25, r0	; check 1299
	halt
1:
	movq	=1074200584, r2
	cmp	r9, r2
	beq	1f
	movq	#26, r0	; check 1300
	halt
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
	movq	#27, r0	; check 1301
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#28, r0	; check 1302
	halt
1:
	lea	ins_m_112_store, r11
	cmp	r6, r11
	beq	1f
	movq	#29, r0	; check 1303
	halt
1:
	movq	=1074200584, r2
	cmp	r9, r2
	beq	1f
	movq	#30, r0	; check 1304
	halt
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
	movq	#31, r0	; check 1305
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#32, r0	; check 1306
	halt
1:
	movq	=1074200576, r2
	cmp	r6, r2
	beq	1f
	movq	#33, r0	; check 1307
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#34, r0	; check 1308
	halt
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
	movq	#35, r0	; check 1309
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#36, r0	; check 1310
	halt
1:
	lea	ins_m_113_load, r11
	cmp	r6, r11
	beq	1f
	movq	#37, r0	; check 1311
	halt
1:
	movq	=1074204680, r2
	cmp	r9, r2
	beq	1f
	movq	#38, r0	; check 1312
	halt
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
	movq	#39, r0	; check 1313
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#40, r0	; check 1314
	halt
1:
	lea	ins_m_113_store, r11
	cmp	r6, r11
	beq	1f
	movq	#41, r0	; check 1315
	halt
1:
	movq	=1074204680, r2
	cmp	r9, r2
	beq	1f
	movq	#42, r0	; check 1316
	halt
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
	movq	#43, r0	; check 1317
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#44, r0	; check 1318
	halt
1:
	movq	=1074204672, r2
	cmp	r6, r2
	beq	1f
	movq	#45, r0	; check 1319
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#46, r0	; check 1320
	halt
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
	movq	#47, r0	; check 1321
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#48, r0	; check 1322
	halt
1:
	lea	ins_m_114_load, r11
	cmp	r6, r11
	beq	1f
	movq	#49, r0	; check 1323
	halt
1:
	movq	=1074208776, r2
	cmp	r9, r2
	beq	1f
	movq	#50, r0	; check 1324
	halt
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
	movq	#51, r0	; check 1325
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#52, r0	; check 1326
	halt
1:
	lea	ins_m_114_store, r11
	cmp	r6, r11
	beq	1f
	movq	#53, r0	; check 1327
	halt
1:
	movq	=1074208776, r2
	cmp	r9, r2
	beq	1f
	movq	#54, r0	; check 1328
	halt
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
	movq	#55, r0	; check 1329
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#56, r0	; check 1330
	halt
1:
	movq	=1074208768, r2
	cmp	r6, r2
	beq	1f
	movq	#57, r0	; check 1331
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#58, r0	; check 1332
	halt
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
	movq	#59, r0	; check 1333
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#60, r0	; check 1334
	halt
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
	movq	#61, r0	; check 1335
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#62, r0	; check 1336
	halt
1:
	lea	ins_m_115_store, r11
	cmp	r6, r11
	beq	1f
	movq	#63, r0	; check 1337
	halt
1:
	movq	=1074212872, r2
	cmp	r9, r2
	beq	1f
	movq	#64, r0	; check 1338
	halt
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
	movq	#65, r0	; check 1339
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#66, r0	; check 1340
	halt
1:
	movq	=1074212864, r2
	cmp	r6, r2
	beq	1f
	movq	#67, r0	; check 1341
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#68, r0	; check 1342
	halt
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
	movq	#69, r0	; check 1343
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#70, r0	; check 1344
	halt
1:
	lea	ins_m_116_load, r11
	cmp	r6, r11
	beq	1f
	movq	#71, r0	; check 1345
	halt
1:
	movq	=1074216968, r2
	cmp	r9, r2
	beq	1f
	movq	#72, r0	; check 1346
	halt
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
	movq	#73, r0	; check 1347
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#74, r0	; check 1348
	halt
1:
	lea	ins_m_116_store, r11
	cmp	r6, r11
	beq	1f
	movq	#75, r0	; check 1349
	halt
1:
	movq	=1074216968, r2
	cmp	r9, r2
	beq	1f
	movq	#76, r0	; check 1350
	halt
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
	movq	#77, r0	; check 1351
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#78, r0	; check 1352
	halt
1:
	movq	=1074216960, r2
	cmp	r6, r2
	beq	1f
	movq	#79, r0	; check 1353
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#80, r0	; check 1354
	halt
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
	movq	#81, r0	; check 1355
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#82, r0	; check 1356
	halt
1:
	lea	ins_m_117_load, r11
	cmp	r6, r11
	beq	1f
	movq	#83, r0	; check 1357
	halt
1:
	movq	=1074221064, r2
	cmp	r9, r2
	beq	1f
	movq	#84, r0	; check 1358
	halt
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
	movq	#85, r0	; check 1359
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#86, r0	; check 1360
	halt
1:
	lea	ins_m_117_store, r11
	cmp	r6, r11
	beq	1f
	movq	#87, r0	; check 1361
	halt
1:
	movq	=1074221064, r2
	cmp	r9, r2
	beq	1f
	movq	#88, r0	; check 1362
	halt
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
	movq	#89, r0	; check 1363
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#90, r0	; check 1364
	halt
1:
	movq	=1074221056, r2
	cmp	r6, r2
	beq	1f
	movq	#91, r0	; check 1365
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#92, r0	; check 1366
	halt
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
	movq	#93, r0	; check 1367
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#94, r0	; check 1368
	halt
1:
	lea	ins_m_118_load, r11
	cmp	r6, r11
	beq	1f
	movq	#95, r0	; check 1369
	halt
1:
	movq	=1074225160, r2
	cmp	r9, r2
	beq	1f
	movq	#96, r0	; check 1370
	halt
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
	movq	#97, r0	; check 1371
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#98, r0	; check 1372
	halt
1:
	lea	ins_m_118_store, r11
	cmp	r6, r11
	beq	1f
	movq	#99, r0	; check 1373
	halt
1:
	movq	=1074225160, r2
	cmp	r9, r2
	beq	1f
	movq	#100, r0	; check 1374
	halt
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
	movq	#101, r0	; check 1375
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#102, r0	; check 1376
	halt
1:
	movq	=1074225152, r2
	cmp	r6, r2
	beq	1f
	movq	#103, r0	; check 1377
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#104, r0	; check 1378
	halt
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
	movq	#105, r0	; check 1379
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#106, r0	; check 1380
	halt
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
	movq	#107, r0	; check 1381
	halt
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
	movq	#108, r0	; check 1382
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#109, r0	; check 1383
	halt
1:
	movq	=1074229248, r2
	cmp	r6, r2
	beq	1f
	movq	#110, r0	; check 1384
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#111, r0	; check 1385
	halt
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
	movq	#112, r0	; check 1386
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#113, r0	; check 1387
	halt
1:
	lea	ins_m_120_load, r11
	cmp	r6, r11
	beq	1f
	movq	#114, r0	; check 1388
	halt
1:
	movq	=1074233352, r2
	cmp	r9, r2
	beq	1f
	movq	#115, r0	; check 1389
	halt
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
	movq	#116, r0	; check 1390
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#117, r0	; check 1391
	halt
1:
	lea	ins_m_120_store, r11
	cmp	r6, r11
	beq	1f
	movq	#118, r0	; check 1392
	halt
1:
	movq	=1074233352, r2
	cmp	r9, r2
	beq	1f
	movq	#119, r0	; check 1393
	halt
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
	movq	#120, r0	; check 1394
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#121, r0	; check 1395
	halt
1:
	movq	=1074233344, r2
	cmp	r6, r2
	beq	1f
	movq	#122, r0	; check 1396
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#123, r0	; check 1397
	halt
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
	movq	#124, r0	; check 1398
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#125, r0	; check 1399
	halt
1:
	lea	ins_m_121_load, r11
	cmp	r6, r11
	beq	1f
	movq	#126, r0	; check 1400
	halt
1:
	movq	=1074237448, r2
	cmp	r9, r2
	beq	1f
	movq	#127, r0	; check 1401
	halt
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
	movq	#128, r0	; check 1402
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#129, r0	; check 1403
	halt
1:
	lea	ins_m_121_store, r11
	cmp	r6, r11
	beq	1f
	movq	#130, r0	; check 1404
	halt
1:
	movq	=1074237448, r2
	cmp	r9, r2
	beq	1f
	movq	#131, r0	; check 1405
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#132, r0	; check 1406
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#133, r0	; check 1407
	halt
1:
	movq	=1074237440, r2
	cmp	r6, r2
	beq	1f
	movq	#134, r0	; check 1408
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#135, r0	; check 1409
	halt
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
	movq	#136, r0	; check 1410
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#137, r0	; check 1411
	halt
1:
	lea	ins_m_122_load, r11
	cmp	r6, r11
	beq	1f
	movq	#138, r0	; check 1412
	halt
1:
	movq	=1074241544, r2
	cmp	r9, r2
	beq	1f
	movq	#139, r0	; check 1413
	halt
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
	movq	#140, r0	; check 1414
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#141, r0	; check 1415
	halt
1:
	lea	ins_m_122_store, r11
	cmp	r6, r11
	beq	1f
	movq	#142, r0	; check 1416
	halt
1:
	movq	=1074241544, r2
	cmp	r9, r2
	beq	1f
	movq	#143, r0	; check 1417
	halt
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
	movq	#144, r0	; check 1418
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#145, r0	; check 1419
	halt
1:
	movq	=1074241536, r2
	cmp	r6, r2
	beq	1f
	movq	#146, r0	; check 1420
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#147, r0	; check 1421
	halt
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
	movq	#148, r0	; check 1422
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#149, r0	; check 1423
	halt
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
	movq	#150, r0	; check 1424
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#151, r0	; check 1425
	halt
1:
	lea	ins_m_123_store, r11
	cmp	r6, r11
	beq	1f
	movq	#152, r0	; check 1426
	halt
1:
	movq	=1074245640, r2
	cmp	r9, r2
	beq	1f
	movq	#153, r0	; check 1427
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#154, r0	; check 1428
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#155, r0	; check 1429
	halt
1:
	movq	=1074245632, r2
	cmp	r6, r2
	beq	1f
	movq	#156, r0	; check 1430
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#157, r0	; check 1431
	halt
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
	movq	#158, r0	; check 1432
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#159, r0	; check 1433
	halt
1:
	lea	ins_m_124_load, r11
	cmp	r6, r11
	beq	1f
	movq	#160, r0	; check 1434
	halt
1:
	movq	=1074249736, r2
	cmp	r9, r2
	beq	1f
	movq	#161, r0	; check 1435
	halt
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
	movq	#162, r0	; check 1436
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#163, r0	; check 1437
	halt
1:
	lea	ins_m_124_store, r11
	cmp	r6, r11
	beq	1f
	movq	#164, r0	; check 1438
	halt
1:
	movq	=1074249736, r2
	cmp	r9, r2
	beq	1f
	movq	#165, r0	; check 1439
	halt
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
	movq	#166, r0	; check 1440
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#167, r0	; check 1441
	halt
1:
	movq	=1074249728, r2
	cmp	r6, r2
	beq	1f
	movq	#168, r0	; check 1442
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#169, r0	; check 1443
	halt
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
	movq	#170, r0	; check 1444
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#171, r0	; check 1445
	halt
1:
	lea	ins_m_125_load, r11
	cmp	r6, r11
	beq	1f
	movq	#172, r0	; check 1446
	halt
1:
	movq	=1074253832, r2
	cmp	r9, r2
	beq	1f
	movq	#173, r0	; check 1447
	halt
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
	movq	#174, r0	; check 1448
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#175, r0	; check 1449
	halt
1:
	lea	ins_m_125_store, r11
	cmp	r6, r11
	beq	1f
	movq	#176, r0	; check 1450
	halt
1:
	movq	=1074253832, r2
	cmp	r9, r2
	beq	1f
	movq	#177, r0	; check 1451
	halt
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
	movq	#178, r0	; check 1452
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#179, r0	; check 1453
	halt
1:
	movq	=1074253824, r2
	cmp	r6, r2
	beq	1f
	movq	#180, r0	; check 1454
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#181, r0	; check 1455
	halt
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
	movq	#182, r0	; check 1456
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#183, r0	; check 1457
	halt
1:
	lea	ins_m_126_load, r11
	cmp	r6, r11
	beq	1f
	movq	#184, r0	; check 1458
	halt
1:
	movq	=1074257928, r2
	cmp	r9, r2
	beq	1f
	movq	#185, r0	; check 1459
	halt
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
	movq	#186, r0	; check 1460
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#187, r0	; check 1461
	halt
1:
	lea	ins_m_126_store, r11
	cmp	r6, r11
	beq	1f
	movq	#188, r0	; check 1462
	halt
1:
	movq	=1074257928, r2
	cmp	r9, r2
	beq	1f
	movq	#189, r0	; check 1463
	halt
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
	movq	#190, r0	; check 1464
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#191, r0	; check 1465
	halt
1:
	movq	=1074257920, r2
	cmp	r6, r2
	beq	1f
	movq	#192, r0	; check 1466
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#193, r0	; check 1467
	halt
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
	movq	#194, r0	; check 1468
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#195, r0	; check 1469
	halt
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
	movq	#196, r0	; check 1470
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#197, r0	; check 1471
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#198, r0	; check 1472
	halt
1:
	movq	=1074262016, r2
	cmp	r6, r2
	beq	1f
	movq	#199, r0	; check 1473
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#200, r0	; check 1474
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#201, r0	; check 1475
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#202, r0	; check 1476
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#203, r0	; check 1477
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#204, r0	; check 1478
	halt
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
	movq	#205, r0	; check 1479
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#206, r0	; check 1480
	halt
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
	movq	#207, r0	; check 1481
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#208, r0	; check 1482
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#209, r0	; check 1483
	halt
1:
	movq	=1074270208, r2
	cmp	r6, r2
	beq	1f
	movq	#210, r0	; check 1484
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#211, r0	; check 1485
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#212, r0	; check 1486
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#213, r0	; check 1487
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#214, r0	; check 1488
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#215, r0	; check 1489
	halt
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
	movq	#216, r0	; check 1490
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#217, r0	; check 1491
	halt
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
	movq	#218, r0	; check 1492
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#219, r0	; check 1493
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#220, r0	; check 1494
	halt
1:
	movq	=1074278400, r2
	cmp	r6, r2
	beq	1f
	movq	#221, r0	; check 1495
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#222, r0	; check 1496
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#223, r0	; check 1497
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#224, r0	; check 1498
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#225, r0	; check 1499
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#226, r0	; check 1500
	halt
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
	movq	#227, r0	; check 1501
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#228, r0	; check 1502
	halt
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
	movq	#229, r0	; check 1503
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#230, r0	; check 1504
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#231, r0	; check 1505
	halt
1:
	movq	=1074286592, r2
	cmp	r6, r2
	beq	1f
	movq	#232, r0	; check 1506
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#233, r0	; check 1507
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#234, r0	; check 1508
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#235, r0	; check 1509
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#236, r0	; check 1510
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#237, r0	; check 1511
	halt
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
	movq	#238, r0	; check 1512
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#239, r0	; check 1513
	halt
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
	movq	#240, r0	; check 1514
	halt
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
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#241, r0	; check 1515
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#242, r0	; check 1516
	halt
1:
	movq	=1074294784, r2
	cmp	r6, r2
	beq	1f
	movq	#243, r0	; check 1517
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#244, r0	; check 1518
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#245, r0	; check 1519
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#246, r0	; check 1520
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#247, r0	; check 1521
	halt
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
	cmp	r10, #(0)
	beq	1f
	movq	#248, r0	; check 1522
	halt
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
	movq	#249, r0	; check 1523
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#250, r0	; check 1524
	halt
1:
	lea	ins_m_137_load, r11
	cmp	r6, r11
	beq	1f
	movq	#251, r0	; check 1525
	halt
1:
	movq	=1074302984, r2
	cmp	r9, r2
	beq	1f
	movq	#252, r0	; check 1526
	halt
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
	movq	#253, r0	; check 1527
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#254, r0	; check 1528
	halt
1:
	lea	ins_m_137_store, r11
	cmp	r6, r11
	beq	1f
	movq	#255, r0	; check 1529
	halt
1:
	movq	=1074302984, r2
	cmp	r9, r2
	beq	1f
	movq	#1, r0	; check 1530
	halt
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
	movq	#2, r0	; check 1531
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#3, r0	; check 1532
	halt
1:
	movq	=1074302976, r2
	cmp	r6, r2
	beq	1f
	movq	#4, r0	; check 1533
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#5, r0	; check 1534
	halt
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
	movq	#6, r0	; check 1535
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#7, r0	; check 1536
	halt
1:
	lea	ins_m_138_load, r11
	cmp	r6, r11
	beq	1f
	movq	#8, r0	; check 1537
	halt
1:
	movq	=1074307080, r2
	cmp	r9, r2
	beq	1f
	movq	#9, r0	; check 1538
	halt
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
	movq	#10, r0	; check 1539
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#11, r0	; check 1540
	halt
1:
	lea	ins_m_138_store, r11
	cmp	r6, r11
	beq	1f
	movq	#12, r0	; check 1541
	halt
1:
	movq	=1074307080, r2
	cmp	r9, r2
	beq	1f
	movq	#13, r0	; check 1542
	halt
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
	movq	#14, r0	; check 1543
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#15, r0	; check 1544
	halt
1:
	movq	=1074307072, r2
	cmp	r6, r2
	beq	1f
	movq	#16, r0	; check 1545
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#17, r0	; check 1546
	halt
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
	movq	#18, r0	; check 1547
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#19, r0	; check 1548
	halt
1:
	lea	ins_m_139_load, r11
	cmp	r6, r11
	beq	1f
	movq	#20, r0	; check 1549
	halt
1:
	movq	=1074311176, r2
	cmp	r9, r2
	beq	1f
	movq	#21, r0	; check 1550
	halt
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
	movq	#22, r0	; check 1551
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#23, r0	; check 1552
	halt
1:
	lea	ins_m_139_store, r11
	cmp	r6, r11
	beq	1f
	movq	#24, r0	; check 1553
	halt
1:
	movq	=1074311176, r2
	cmp	r9, r2
	beq	1f
	movq	#25, r0	; check 1554
	halt
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
	movq	#26, r0	; check 1555
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#27, r0	; check 1556
	halt
1:
	movq	=1074311168, r2
	cmp	r6, r2
	beq	1f
	movq	#28, r0	; check 1557
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#29, r0	; check 1558
	halt
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
	movq	#30, r0	; check 1559
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#31, r0	; check 1560
	halt
1:
	lea	ins_m_140_load, r11
	cmp	r6, r11
	beq	1f
	movq	#32, r0	; check 1561
	halt
1:
	movq	=1074315272, r2
	cmp	r9, r2
	beq	1f
	movq	#33, r0	; check 1562
	halt
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
	movq	#34, r0	; check 1563
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#35, r0	; check 1564
	halt
1:
	lea	ins_m_140_store, r11
	cmp	r6, r11
	beq	1f
	movq	#36, r0	; check 1565
	halt
1:
	movq	=1074315272, r2
	cmp	r9, r2
	beq	1f
	movq	#37, r0	; check 1566
	halt
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
	movq	#38, r0	; check 1567
	halt
1:
	cmp	r8, #(VECTOR_IFAULT)
	beq	1f
	movq	#39, r0	; check 1568
	halt
1:
	movq	=1074315264, r2
	cmp	r6, r2
	beq	1f
	movq	#40, r0	; check 1569
	halt
1:
	cmp	r9, r2
	beq	1f
	movq	#41, r0	; check 1570
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


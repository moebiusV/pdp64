; System v1 MMU, errata 65 (PROPOSED): the memory type of a leaf must agree with bit 39 of its physical page (device space: device or device-weak; memory: cached or uncached), else a protection fault; translation off reaches the devices.
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
	cmp	r5, #(-1)
	beq	1f
	movq	#2, r0	; check 1
	halt
1:
	movq	=1073745920, r3
	movq	8(r3), r5
	cmp	r5, #(-1)
	beq	1f
	movq	#3, r0	; check 2
	halt
1:
	movq	#5, r5
	movq	=1073741824, r3
	movq	r5, 8(r3)
	movq	8(r3), r6
	cmp	r6, #(5)
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	#-1, r5
	movq	r5, 8(r3)
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=1073750016, r3
	lea	res_sp_2_load, r4
	movq	#0, r5
ins_sp_2_load:
	movq	8(r3), r5
res_sp_2_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#6, r0	; check 5
	halt
1:
	lea	ins_sp_2_load, r11
	cmp	r6, r11
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	movq	=1073750024, r2
	cmp	r9, r2
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
	movq	=1073750016, r3
	lea	res_sp_2_store, r4
	movq	#0x1234, r5
ins_sp_2_store:
	movq	r5, 8(r3)
res_sp_2_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	lea	ins_sp_2_store, r11
	cmp	r6, r11
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	movq	=1073750024, r2
	cmp	r9, r2
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
	movq	=1073754112, r3
	lea	res_sp_3_load, r4
	movq	#0, r5
ins_sp_3_load:
	movq	8(r3), r5
res_sp_3_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	lea	ins_sp_3_load, r11
	cmp	r6, r11
	beq	1f
	movq	#15, r0	; check 14
	halt
1:
	movq	=1073754120, r2
	cmp	r9, r2
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
	movq	=1073754112, r3
	lea	res_sp_3_store, r4
	movq	#0x1234, r5
ins_sp_3_store:
	movq	r5, 8(r3)
res_sp_3_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#17, r0	; check 16
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	lea	ins_sp_3_store, r11
	cmp	r6, r11
	beq	1f
	movq	#19, r0	; check 18
	halt
1:
	movq	=1073754120, r2
	cmp	r9, r2
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
	movq	=1073758208, r3
	lea	res_sp_4_load, r4
	movq	#0, r5
ins_sp_4_load:
	movq	8(r3), r5
res_sp_4_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#21, r0	; check 20
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#22, r0	; check 21
	halt
1:
	lea	ins_sp_4_load, r11
	cmp	r6, r11
	beq	1f
	movq	#23, r0	; check 22
	halt
1:
	movq	=1073758216, r2
	cmp	r9, r2
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
	movq	=1073758208, r3
	lea	res_sp_4_store, r4
	movq	#0x1234, r5
ins_sp_4_store:
	movq	r5, 8(r3)
res_sp_4_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#25, r0	; check 24
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#26, r0	; check 25
	halt
1:
	lea	ins_sp_4_store, r11
	cmp	r6, r11
	beq	1f
	movq	#27, r0	; check 26
	halt
1:
	movq	=1073758216, r2
	cmp	r9, r2
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
	movq	=1073758208, r3
	lea	res_sp_4_fetch, r4
ins_sp_4_fetch:
	call	r3
res_sp_4_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#29, r0	; check 28
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#30, r0	; check 29
	halt
1:
	movq	=1073758208, r2
	cmp	r6, r2
	beq	1f
	movq	#31, r0	; check 30
	halt
1:
	cmp	r9, r2
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
	movq	=1073762304, r3
	lea	res_sp_5_load, r4
	movq	#0, r5
ins_sp_5_load:
	movq	8(r3), r5
res_sp_5_load:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#33, r0	; check 32
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#34, r0	; check 33
	halt
1:
	lea	ins_sp_5_load, r11
	cmp	r6, r11
	beq	1f
	movq	#35, r0	; check 34
	halt
1:
	movq	=1073762312, r2
	cmp	r9, r2
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
	movq	=1073762304, r3
	lea	res_sp_5_store, r4
	movq	#0x1234, r5
ins_sp_5_store:
	movq	r5, 8(r3)
res_sp_5_store:
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#37, r0	; check 36
	halt
1:
	cmp	r8, #(VECTOR_SPROT)
	beq	1f
	movq	#38, r0	; check 37
	halt
1:
	lea	ins_sp_5_store, r11
	cmp	r6, r11
	beq	1f
	movq	#39, r0	; check 38
	halt
1:
	movq	=1073762312, r2
	cmp	r9, r2
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
	movq	=1073762304, r3
	lea	res_sp_5_fetch, r4
ins_sp_5_fetch:
	call	r3
res_sp_5_fetch:
	bic	#15, r7
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#41, r0	; check 40
	halt
1:
	cmp	r8, #(VECTOR_IPROT)
	beq	1f
	movq	#42, r0	; check 41
	halt
1:
	movq	=1073762304, r2
	cmp	r6, r2
	beq	1f
	movq	#43, r0	; check 42
	halt
1:
	cmp	r9, r2
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
	movq	=1073766400, r3
	lea	res_sp_6_load, r4
	movq	#0, r5
ins_sp_6_load:
	movq	8(r3), r5
res_sp_6_load:
	cmp	r10, #(0)
	beq	1f
	movq	#45, r0	; check 44
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#46, r0	; check 45
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
	lea	res_sp_6_store, r4
	movq	#0x1234, r5
ins_sp_6_store:
	movq	r5, 8(r3)
res_sp_6_store:
	cmp	r10, #(0)
	beq	1f
	movq	#47, r0	; check 46
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	res_big, r4
	movq	=0x100000000, r3
ins_big:
	movq	(r3), r5
res_big:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#48, r0	; check 47
	halt
1:
	cmp	r8, #(VECTOR_LPROT)
	beq	1f
	movq	#49, r0	; check 48
	halt
1:
	lea	ins_big, r11
	cmp	r6, r11
	beq	1f
	movq	#50, r0	; check 49
	halt
1:
	movq	=4294967296, r2
	cmp	r9, r2
	beq	1f
	movq	#51, r0	; check 50
	halt
1:
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	=0x140000000, r3
	movq	8(r3), r5
	cmp	r10, #(0)
	beq	1f
	movq	#52, r0	; check 51
	halt
1:
	cmp	r5, #(-1)
	beq	1f
	movq	#53, r0	; check 52
	halt
1:
	movq	#0, r1
	mtsr	mmuctl, r1
	movq	=MAP_TIMER, r3
	movq	8(r3), r5
	cmp	r5, #(-1)
	beq	1f
	movq	#54, r0	; check 53
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
	.space	16
	.quad	0x8000000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	0x8000000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D|2<<PTE_MT)
	.space	4048

	.align	4096
l1a:
	.quad	l0a + (1<<PTE_V)
	.space	4088

	.align	4096
l0a:
	.quad	0x8000000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D|2<<PTE_MT)
	.quad	0x8000000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D|3<<PTE_MT)
	.quad	0x8000000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	0x8000000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D|1<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D|2<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D|3<<PTE_MT)
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D|1<<PTE_MT)
	.space	4040

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


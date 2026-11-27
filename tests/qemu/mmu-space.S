; System v1 MMU, errata 65 (PROPOSED): the memory type of a leaf must agree with bit 39 of its physical page (device space: device or device-weak; memory: cached or uncached), else a protection fault; translation off reaches the devices.
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
	cbeq r5, #(-1), 1f
	mov	#2, r0	; check 1
	halt
1:
	mov	=1073745920, r3
	mov	8(r3), r5
	cbeq r5, #(-1), 1f
	mov	#3, r0	; check 2
	halt
1:
	mov	#5, r5
	mov	=1073741824, r3
	mov	r5, 8(r3)
	mov	8(r3), r6
	cbeq r6, #(5), 1f
	mov	#4, r0	; check 3
	halt
1:
	mov	#-1, r5
	mov	r5, 8(r3)
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073750016, r3
	lea	res_sp_2_load, r4
	mov	#0, r5
ins_sp_2_load:
	mov	8(r3), r5
res_sp_2_load:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#5, r0	; check 4
	halt
1:
	cbeq r8, #(VECTOR_LPROT), 1f
	mov	#6, r0	; check 5
	halt
1:
	lea	ins_sp_2_load, r11
	cbeq r6, r11, 1f
	mov	#7, r0	; check 6
	halt
1:
	mov	=1073750024, r2
	cbeq r9, r2, 1f
	mov	#8, r0	; check 7
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
	lea	res_sp_2_store, r4
	mov	#0x1234, r5
ins_sp_2_store:
	mov	r5, 8(r3)
res_sp_2_store:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#9, r0	; check 8
	halt
1:
	cbeq r8, #(VECTOR_SPROT), 1f
	mov	#10, r0	; check 9
	halt
1:
	lea	ins_sp_2_store, r11
	cbeq r6, r11, 1f
	mov	#11, r0	; check 10
	halt
1:
	mov	=1073750024, r2
	cbeq r9, r2, 1f
	mov	#12, r0	; check 11
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
	lea	res_sp_3_load, r4
	mov	#0, r5
ins_sp_3_load:
	mov	8(r3), r5
res_sp_3_load:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#13, r0	; check 12
	halt
1:
	cbeq r8, #(VECTOR_LPROT), 1f
	mov	#14, r0	; check 13
	halt
1:
	lea	ins_sp_3_load, r11
	cbeq r6, r11, 1f
	mov	#15, r0	; check 14
	halt
1:
	mov	=1073754120, r2
	cbeq r9, r2, 1f
	mov	#16, r0	; check 15
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
	lea	res_sp_3_store, r4
	mov	#0x1234, r5
ins_sp_3_store:
	mov	r5, 8(r3)
res_sp_3_store:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#17, r0	; check 16
	halt
1:
	cbeq r8, #(VECTOR_SPROT), 1f
	mov	#18, r0	; check 17
	halt
1:
	lea	ins_sp_3_store, r11
	cbeq r6, r11, 1f
	mov	#19, r0	; check 18
	halt
1:
	mov	=1073754120, r2
	cbeq r9, r2, 1f
	mov	#20, r0	; check 19
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
	lea	res_sp_4_load, r4
	mov	#0, r5
ins_sp_4_load:
	mov	8(r3), r5
res_sp_4_load:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#21, r0	; check 20
	halt
1:
	cbeq r8, #(VECTOR_LPROT), 1f
	mov	#22, r0	; check 21
	halt
1:
	lea	ins_sp_4_load, r11
	cbeq r6, r11, 1f
	mov	#23, r0	; check 22
	halt
1:
	mov	=1073758216, r2
	cbeq r9, r2, 1f
	mov	#24, r0	; check 23
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
	lea	res_sp_4_store, r4
	mov	#0x1234, r5
ins_sp_4_store:
	mov	r5, 8(r3)
res_sp_4_store:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#25, r0	; check 24
	halt
1:
	cbeq r8, #(VECTOR_SPROT), 1f
	mov	#26, r0	; check 25
	halt
1:
	lea	ins_sp_4_store, r11
	cbeq r6, r11, 1f
	mov	#27, r0	; check 26
	halt
1:
	mov	=1073758216, r2
	cbeq r9, r2, 1f
	mov	#28, r0	; check 27
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
	lea	res_sp_4_fetch, r4
ins_sp_4_fetch:
	call	r3
res_sp_4_fetch:
	bic	#15, r7
	add	#8, sp
	cbeq r10, #(1), 1f
	mov	#29, r0	; check 28
	halt
1:
	cbeq r8, #(VECTOR_IPROT), 1f
	mov	#30, r0	; check 29
	halt
1:
	mov	=1073758208, r2
	cbeq r6, r2, 1f
	mov	#31, r0	; check 30
	halt
1:
	cbeq r9, r2, 1f
	mov	#32, r0	; check 31
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
	lea	res_sp_5_load, r4
	mov	#0, r5
ins_sp_5_load:
	mov	8(r3), r5
res_sp_5_load:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#33, r0	; check 32
	halt
1:
	cbeq r8, #(VECTOR_LPROT), 1f
	mov	#34, r0	; check 33
	halt
1:
	lea	ins_sp_5_load, r11
	cbeq r6, r11, 1f
	mov	#35, r0	; check 34
	halt
1:
	mov	=1073762312, r2
	cbeq r9, r2, 1f
	mov	#36, r0	; check 35
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
	lea	res_sp_5_store, r4
	mov	#0x1234, r5
ins_sp_5_store:
	mov	r5, 8(r3)
res_sp_5_store:
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#37, r0	; check 36
	halt
1:
	cbeq r8, #(VECTOR_SPROT), 1f
	mov	#38, r0	; check 37
	halt
1:
	lea	ins_sp_5_store, r11
	cbeq r6, r11, 1f
	mov	#39, r0	; check 38
	halt
1:
	mov	=1073762312, r2
	cbeq r9, r2, 1f
	mov	#40, r0	; check 39
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
	lea	res_sp_5_fetch, r4
ins_sp_5_fetch:
	call	r3
res_sp_5_fetch:
	bic	#15, r7
	add	#8, sp
	cbeq r10, #(1), 1f
	mov	#41, r0	; check 40
	halt
1:
	cbeq r8, #(VECTOR_IPROT), 1f
	mov	#42, r0	; check 41
	halt
1:
	mov	=1073762304, r2
	cbeq r6, r2, 1f
	mov	#43, r0	; check 42
	halt
1:
	cbeq r9, r2, 1f
	mov	#44, r0	; check 43
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073766400, r3
	lea	res_sp_6_load, r4
	mov	#0, r5
ins_sp_6_load:
	mov	8(r3), r5
res_sp_6_load:
	cbeq r10, #(0), 1f
	mov	#45, r0	; check 44
	halt
1:
	cbeq r5, #(4660), 1f
	mov	#46, r0	; check 45
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=1073766400, r3
	lea	res_sp_6_store, r4
	mov	#0x1234, r5
ins_sp_6_store:
	mov	r5, 8(r3)
res_sp_6_store:
	cbeq r10, #(0), 1f
	mov	#47, r0	; check 46
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	lea	res_big, r4
	mov	=0x100000000, r3
ins_big:
	mov	(r3), r5
res_big:
	mov	r7, r1
	bic	#15, r7
	cbeq r10, #(1), 1f
	mov	#48, r0	; check 47
	halt
1:
	cbeq r8, #(VECTOR_LPROT), 1f
	mov	#49, r0	; check 48
	halt
1:
	lea	ins_big, r11
	cbeq r6, r11, 1f
	mov	#50, r0	; check 49
	halt
1:
	mov	=4294967296, r2
	cbeq r9, r2, 1f
	mov	#51, r0	; check 50
	halt
1:
	mov	#0, r4
	mov	#0, r10
	mov	#0, r6
	mov	#0, r7
	mov	#0, r8
	mov	#0, r9
	mov	#0, r12
	mov	=0x140000000, r3
	mov	8(r3), r5
	cbeq r10, #(0), 1f
	mov	#52, r0	; check 51
	halt
1:
	cbeq r5, #(-1), 1f
	mov	#53, r0	; check 52
	halt
1:
	mov	#0, r1
	mtsr	mmuctl, r1
	mov	=MAP_TIMER, r3
	mov	8(r3), r5
	cbeq r5, #(-1), 1f
	mov	#54, r0	; check 53
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


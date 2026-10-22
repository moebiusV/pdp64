; System v1 MMU: invalid and malformed entries at each level, reserved bits, a misaligned superpage, a table or a page outside physical memory (bus fault).
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
	lea	res_l2inv, r4
	movq	=0xC0000000, r3
ins_l2inv:
	movq	(r3), r5
res_l2inv:
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
	lea	ins_l2inv, r11
	cmp	r6, r11
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	movq	=3221225472, r2
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
	lea	res_l1inv, r4
	movq	=1075838976, r3
ins_l1inv:
	movq	(r3), r5
res_l1inv:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#6, r0	; check 5
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	lea	ins_l1inv, r11
	cmp	r6, r11
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	movq	=1075838976, r2
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
	lea	res_l1inv_s, r4
	movq	=1075838976, r3
ins_l1inv_s:
	movq	r5, (r3)
res_l1inv_s:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	cmp	r8, #(VECTOR_SFAULT)
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	lea	ins_l1inv_s, r11
	cmp	r6, r11
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	movq	=1075838976, r2
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
	lea	res_l1mis, r4
	movq	=1077936128, r3
ins_l1mis:
	movq	(r3), r5
res_l1mis:
	movq	r7, r1
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
	lea	ins_l1mis, r11
	cmp	r6, r11
	beq	1f
	movq	#16, r0	; check 15
	halt
1:
	movq	=1077936128, r2
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
	lea	res_l2mis, r4
	movq	=0x100000000, r3
ins_l2mis:
	movq	(r3), r5
res_l2mis:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#18, r0	; check 17
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#19, r0	; check 18
	halt
1:
	lea	ins_l2mis, r11
	cmp	r6, r11
	beq	1f
	movq	#20, r0	; check 19
	halt
1:
	movq	=4294967296, r2
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
	lea	res_l2res, r4
	movq	=0x140000000, r3
ins_l2res:
	movq	(r3), r5
res_l2res:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#22, r0	; check 21
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#23, r0	; check 22
	halt
1:
	lea	ins_l2res, r11
	cmp	r6, r11
	beq	1f
	movq	#24, r0	; check 23
	halt
1:
	movq	=5368709120, r2
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
	lea	res_l1res, r4
	movq	=1080033280, r3
ins_l1res:
	movq	(r3), r5
res_l1res:
	movq	r7, r1
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
	lea	ins_l1res, r11
	cmp	r6, r11
	beq	1f
	movq	#28, r0	; check 27
	halt
1:
	movq	=1080033280, r2
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
	lea	res_l0ptr, r4
	movq	=1082130432, r3
ins_l0ptr:
	movq	(r3), r5
res_l0ptr:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#30, r0	; check 29
	halt
1:
	cmp	r8, #(VECTOR_LFAULT)
	beq	1f
	movq	#31, r0	; check 30
	halt
1:
	lea	ins_l0ptr, r11
	cmp	r6, r11
	beq	1f
	movq	#32, r0	; check 31
	halt
1:
	movq	=1082130432, r2
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
	lea	res_tbus, r4
	movq	=0x180000000, r3
ins_tbus:
	movq	(r3), r5
res_tbus:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#34, r0	; check 33
	halt
1:
	cmp	r8, #(VECTOR_BUSFAULT)
	beq	1f
	movq	#35, r0	; check 34
	halt
1:
	lea	ins_tbus, r11
	cmp	r6, r11
	beq	1f
	movq	#36, r0	; check 35
	halt
1:
	movq	=6442450944, r2
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
	lea	res_dbus, r4
	movq	=1084227584, r3
ins_dbus:
	movq	8(r3), r5
res_dbus:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#38, r0	; check 37
	halt
1:
	cmp	r8, #(VECTOR_BUSFAULT)
	beq	1f
	movq	#39, r0	; check 38
	halt
1:
	lea	ins_dbus, r11
	cmp	r6, r11
	beq	1f
	movq	#40, r0	; check 39
	halt
1:
	movq	=1084227592, r2
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
	lea	res_sbus, r4
	movq	=1084227584, r3
ins_sbus:
	movq	r5, 8(r3)
res_sbus:
	movq	r7, r1
	bic	#15, r7
	cmp	r10, #(1)
	beq	1f
	movq	#42, r0	; check 41
	halt
1:
	cmp	r8, #(VECTOR_BUSFAULT)
	beq	1f
	movq	#43, r0	; check 42
	halt
1:
	lea	ins_sbus, r11
	cmp	r6, r11
	beq	1f
	movq	#44, r0	; check 43
	halt
1:
	movq	=1084227592, r2
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
	movq	=1084227584, r3
	lea	res_fbus, r4
ins_fbus:
	call	r3
res_fbus:
	add	#8, sp
	cmp	r10, #(1)
	beq	1f
	movq	#46, r0	; check 45
	halt
1:
	cmp	r8, #(VECTOR_BUSFAULT)
	beq	1f
	movq	#47, r0	; check 46
	halt
1:
	movq	=1084227584, r2
	cmp	r9, r2
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
	movq	=1086324736, r3
	movq	8(r3), r5
	cmp	r10, #(0)
	beq	1f
	movq	#49, r0	; check 48
	halt
1:
	cmp	r5, #(4660)
	beq	1f
	movq	#50, r0	; check 49
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
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	l1a + (1<<PTE_V|0x800)
	.quad	0x30000000 + (1<<PTE_V)
	.space	4040

	.align	4096
l1a:
	.quad	l0a + (1<<PTE_V)
	.space	8
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.quad	l0a + (1<<PTE_V|0x800)
	.quad	l0b + (1<<PTE_V)
	.quad	l0c + (1<<PTE_V)
	.quad	l0a + (1<<PTE_V)
	.space	4040

	.align	4096
l0a:
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.space	4088

	.align	4096
l0b:
	.quad	0 + (1<<PTE_V)
	.space	4088

	.align	4096
l0c:
	.quad	0x30000000 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
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


; SEC-B12 (the split load): a load that starts in a page it may read and ends in a page it may not must leak nothing of the part that fits: the destination register is as it was (no half of
; the value), the fault is precise on the second page (the load protection fault, EVA the first byte of that page, EPC the instruction), and when the first page is the one that refuses, EVA
; is the address of the load.  Kernel mode with translation on; the code and the tables are in the first 1 GiB, an identity superpage with no U bit.  The pages of virtual 1 << 30 are, in
; order: P0 read and write, P1 execute only (a kernel load of it is a protection fault), P2 and P3 read and write, P4 execute only, P5 read and write.  Failed check n: exit n.
#include "pdp64-consts.h"
#define RW (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
#define XO (1<<PTE_V|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	movq	#1, r1
	mtsr	mmuctl, r1
	isync
	movq	=1073741824, r3		; P0
	movq	=1073745920, r11	; P1
	movq	=1073758208, r12	; P4
	movq	=0xa5a5a5a5a5a5a5a5, r4
	lea	pg0, r7			; a secret in the last eight bytes of P0 and the first of P1 (through the physical alias)
	movq	=0x5ec4e75ec4e75ec4, r5
	movq	r5, 4088(r7)
	lea	pg1, r7
	movq	r5, (r7)
; ---- 1: the load from P0 into P1, which refuses
	movq	=0x7777777777777777, r6
	movq	#0, r10
	lea	res1, r13
at1:	movq	4092(r3), r6
res1:	cmp	r10, #1
	bne	F1	; check 1: exactly one fault
	cmp	r8, #(VECTOR_LPROT)
	bne	F2	; check 2: the load protection fault
	cmp	r9, r11
	bne	F3	; check 3: EVA is the first byte of the second page
	lea	at1, r2
	cmp	r15, r2
	bne	F4	; check 4: EPC is the instruction
	movq	=0x7777777777777777, r2
	cmp	r6, r2
	bne	F5	; check 5: the destination is as it was: no bytes of the readable page reached it
; ---- 2: the load from P4, which refuses, into P5
	movq	#0, r10
	lea	res2, r13
at2:	movq	4092(r12), r6
res2:	cmp	r10, #1
	bne	F6	; check 6: exactly one fault
	cmp	r8, #(VECTOR_LPROT)
	bne	F7	; check 7: the load protection fault
	lea	4092(r12), r2
	cmp	r9, r2
	bne	F8	; check 8: EVA is the address of the load: the first page refused
	movq	=0x7777777777777777, r2
	cmp	r6, r2
	bne	F9	; check 9: the destination is as it was
	movq	#0, r0
	halt
h_gen:	add	#1, r10
	mfsr	r8, ecause
	mfsr	r9, eva
	mfsr	r15, epc
	mtsr	epc, r13
	rti	#RTIMASK_ALL
h_fail:	movq	#99, r0
	halt
F1:	movq	#1, r0
	halt
F2:	movq	#2, r0
	halt
F3:	movq	#3, r0
	halt
F4:	movq	#4, r0
	halt
F5:	movq	#5, r0
	halt
F6:	movq	#6, r0
	halt
F7:	movq	#7, r0
	halt
F8:	movq	#8, r0
	halt
F9:	movq	#9, r0
	halt
	.data
	.align	8
vtab:
	.quad	h_fail, h_fail, h_fail, h_fail, h_fail, h_fail, h_fail, h_gen
	.quad	h_gen, h_gen, h_gen, h_gen, h_fail, h_fail, h_fail, h_fail
	.quad	h_fail, h_fail

	.align	4096
l2:
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	l1 + (1<<PTE_V)
	.space	4080

	.align	4096
l1:
	.quad	l0 + (1<<PTE_V)
	.space	4088

	.align	4096
l0:
	.quad	pg0 + RW
	.quad	pg1 + XO
	.quad	pg2 + RW
	.quad	pg3 + RW
	.quad	pg4 + XO
	.quad	pg5 + RW
	.space	4048

	.align	4096
pg0:	.space	4096
	.align	4096
pg1:	.space	4096
	.align	4096
pg2:	.space	4096
	.align	4096
pg3:	.space	4096
	.align	4096
pg4:	.space	4096
	.align	4096
pg5:	.space	4096

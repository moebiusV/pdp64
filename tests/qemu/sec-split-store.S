; SEC-M09 (the split store): a store that crosses from a page it may write into a page it may not must not write the part that fits.  The fault is precise on the second page (the store
; protection fault, EVA the first byte of that page, EPC the instruction) and nothing of the store is in memory; when the first page is the one that refuses, EVA is the address of the
; store and the second page is untouched.  Kernel mode with translation on; the code and the tables are in the first 1 GiB, an identity superpage with no U bit (the pages are also reached
; through it, at their physical addresses, to fill and to read them).  The pages of virtual 1 << 30 are, in order: P0 read and write, P1 read only, P2 and P3 not used, P4 read only, P5 read
; and write.  Failed check n: exit n.
#include "pdp64-consts.h"
#define RW (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
#define RO (1<<PTE_V|1<<PTE_R|1<<PTE_A|1<<PTE_D)
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	mov	$1, r1
	mtsr	mmuctl, r1
	isync
	mov	=1073741824, r3		; P0
	mov	=1073745920, r11	; P1
	mov	=1073758208, r12	; P4
	mov	=1073762304, r14	; P5 (r14 is not used as a stack pointer in this probe)
	mov	=0x1111111111111111, r5
	lea	pg0, r7			; the physical alias of the pages: fill the last eight bytes of P0 and the first eight of P1 with ones
	mov	r5, 4088(r7)
	lea	pg1, r7
	mov	r5, (r7)
	mov	=0x2222222222222222, r1
; ---- 1: the store from P0 into P1, which refuses
	mov	$0, r10
	lea	res1, r13
at1:	mov	r1, 4092(r3)
res1:	cbne r10, $1, F1 ; check 1: exactly one fault
	cbne r8, $(VECTOR_SPROT), F2 ; check 2: the store protection fault
	cbne r9, r11, F3 ; check 3: EVA is the first byte of the second page
	lea	at1, r2
	cbne r6, r2, F4 ; check 4: EPC is the instruction
	lea	pg0, r7
	mov	4088(r7), r2
	mov	=0x1111111111111111, r4
	cbne r2, r4, F5 ; check 5: the last eight bytes of P0 are as they were: the four bytes that fit were not written
	lea	pg1, r7
	mov	(r7), r2
	cbne r2, r4, F6 ; check 6: and P1 is as it was
; ---- 2: the store from P4, which refuses, into P5
	mov	=0x1111111111111111, r5
	lea	pg5, r7
	mov	r5, (r7)
	mov	$0, r10
	lea	res2, r13
at2:	mov	r1, 4092(r12)
res2:	cbne r10, $1, F7 ; check 7: exactly one fault
	cbne r8, $(VECTOR_SPROT), F8 ; check 8: the store protection fault
	lea	4092(r12), r2
	cbne r9, r2, F9 ; check 9: EVA is the address of the store: the first page refused
	lea	at2, r2
	cbne r6, r2, F10 ; check 10: EPC is the instruction
	lea	pg5, r7
	mov	(r7), r2
	mov	=0x1111111111111111, r4
	cbne r2, r4, F11 ; check 11: P5 is as it was
	mov	$0, r0
	halt
h_gen:	add	$1, r10
	mfsr	r8, ecause
	mfsr	r9, eva
	mfsr	r6, epc
	mtsr	epc, r13
	rti	$RTIMASK_ALL
h_fail:	mov	$99, r0
	halt
F1:	mov	$1, r0
	halt
F2:	mov	$2, r0
	halt
F3:	mov	$3, r0
	halt
F4:	mov	$4, r0
	halt
F5:	mov	$5, r0
	halt
F6:	mov	$6, r0
	halt
F7:	mov	$7, r0
	halt
F8:	mov	$8, r0
	halt
F9:	mov	$9, r0
	halt
F10:	mov	$10, r0
	halt
F11:	mov	$11, r0
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
	.quad	pg1 + RO
	.quad	pg2 + RW
	.quad	pg3 + RW
	.quad	pg4 + RO
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

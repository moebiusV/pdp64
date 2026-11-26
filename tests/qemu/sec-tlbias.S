; Written by hand for the security corpus (docs/security-corpus.md, SEC-B25).  TLBIAS rN invalidates the translations of the address-space number in rN (its low 16 bits):
; a page-table entry changed behind a cached translation is not seen (the control: the buffer holds it), and is seen after TLBIAS of the number it was cached under.  Failed check n: exit n.
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
	movq	#5, r1
	mtsr	asid, r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cbeq r5, #(4660), 1f
	movq	#1, r0	; check 1 the page is mapped to the first data page, read under address-space number 5
	halt
1:
	lea	pgdata2, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cbeq r5, #(4660), 1f
	movq	#2, r0	; check 2 control: the changed entry is not seen, the buffer holds the old translation
	halt
1:
	movq	#5, r1
	tlbias	r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cbeq r5, #(22136), 1f
	movq	#3, r0	; check 3 after TLBIAS of number 5 the changed entry is seen
	halt
1:
	lea	pgdata, r2
	movq	=((1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	=1073741824, r3
	movq	8(r3), r5
	cbeq r5, #(22136), 1f
	movq	#4, r0	; check 4 control: the entry changed back is not seen yet
	halt
1:
	movq	=0x70005, r1
	tlbias	r1
	movq	=1073741824, r3
	movq	8(r3), r5
	cbeq r5, #(4660), 1f
	movq	#5, r0	; check 5 TLBIAS uses the low 16 bits of the register: 0x70005 is number 5
	halt
1:
	movq	#0, r0
	halt
h_gen:	mfsr	r6, epc
	mfsr	r8, ecause
	add	#1, r10
	movq	#99, r0
	halt
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
	.quad	pgdata + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.space	4080

	.align	4096
l2b:
	.quad	0 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.quad	l1b + (1<<PTE_V)
	.space	4080

	.align	4096
l1b:
	.quad	l0b + (1<<PTE_V)
	.space	4088

	.align	4096
l0b:
	.quad	pgdata2 + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.space	4088

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
	add	#1000, r1	; four bytes: the first parcel ends the page, its second parcel is on the next page

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


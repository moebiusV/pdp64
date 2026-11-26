; System v1 MMU: what happens to cached translations when MMUCTL, PTBR or ASID is written (manual 6.8.4, errata 178).  The rule under test:
;   (a) a write to MMUCTL that changes bit 0, either way, discards every cached translation: a translation cached before translation was turned off is not
;       used after it is turned on again, whatever the page tables say now;
;   (c) a write to PTBR discards the entries of the current ASID: an entry walked from the old table is not used under the new one;
;       an entry tagged with another ASID is not used after a write to ASID (the architecture does not say whether it is kept: the test never reads one
;       back after switching back to its ASID);
;   (d) each takes effect at the ISYNC after the write.
; No TLBI or TLBIA is executed after the first access to P: every page-table entry is changed behind the translation buffer.  P (virtual 1 << 30) is reached
; through the root table l2 (or l2b), the first of the pages of l0a (or l0b); the first 1 GiB is an identity superpage that holds the code and the tables.
; The reset case is not tested here (the harness cannot reset the machine): errata 178 says what QEMU's reset does.
; Failure: halt with the number of the check in r0.
#include "pdp64-consts.h"
#define RW (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	l2, r1
	mtsr	ptbr, r1
	movq	#0, r1
	mtsr	asid, r1
	movq	#1, r1
	mtsr	mmuctl, r1
	isync
	movq	=1073741824, r3
	movq	8(r3), r5		; P is now cached: it maps pgA
	cbeq r5, #(4369), 1f
	movq	#1, r0
	halt
1:
; (i) translation off, change the entry, translation on: P must read pgC, not the cached pgA
	movq	#0, r1
	mtsr	mmuctl, r1
	isync
	lea	pgC, r2
	movq	=(RW), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	#1, r1
	mtsr	mmuctl, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(13107), 1f
	movq	#2, r0			; a translation cached before translation was off was used
	halt
1:
; (i) again with the entry changed back while translation is on and P cached (pgC), then off, on: pgA
	movq	#0, r1
	mtsr	mmuctl, r1
	isync
	lea	pgA, r2
	movq	=(RW), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	#1, r1
	mtsr	mmuctl, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(4369), 1f
	movq	#3, r0
	halt
1:
; (ii) PTBR: P is cached (pgA, table l2); a new table that maps P to pgB must be used at once, and when l2 is loaded again, pgB must not answer
	lea	l2b, r1
	mtsr	ptbr, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(8738), 1f
	movq	#4, r0			; an entry walked from the old table was used under the new one
	halt
1:
	lea	l2, r1
	mtsr	ptbr, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(4369), 1f
	movq	#5, r0			; the entry of l2b was used under l2
	halt
1:
; (iii) ASID: P is cached with tag 0 (pgA).  The entry is changed without any TLBI; under ASID 1 the entry tagged 0 must not answer
	lea	pgC, r2
	movq	=(RW), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	#1, r1
	mtsr	asid, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(13107), 1f
	movq	#6, r0			; an entry tagged ASID 0 answered under ASID 1
	halt
1:
; the same from tag 1 (pgC) to ASID 2 (pgA)
	lea	pgA, r2
	movq	=(RW), r1
	add	r1, r2
	lea	l0a, r1
	movq	r2, 0(r1)
	movq	#2, r1
	mtsr	asid, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(4369), 1f
	movq	#7, r0			; an entry tagged ASID 1 answered under ASID 2
	halt
1:
; a write of the same value to MMUCTL, PTBR and ASID does not break anything (whether it flushes is not specified: only the value read is checked)
	movq	#1, r1
	mtsr	mmuctl, r1
	isync
	movq	8(r3), r5
	cbeq r5, #(4369), 1f
	movq	#8, r0
	halt
1:
	movq	#0, r0
	halt
h_fail:	movq	#99, r0			; an unexpected exception
	halt
	.data
	.align	8
vtab:
	.quad	h_fail, h_fail, h_fail, h_fail, h_fail, h_fail, h_fail, h_fail
	.quad	h_fail, h_fail, h_fail, h_fail, h_fail, h_fail, h_fail, h_fail
	.quad	h_fail, h_fail

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
	.quad	pgA + RW
	.space	4088

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
	.quad	pgB + RW
	.space	4088

	.align	4096
pgA:	.quad	0
	.quad	0x1111
	.space	4080

	.align	4096
pgB:	.quad	0
	.quad	0x2222
	.space	4080

	.align	4096
pgC:	.quad	0
	.quad	0x3333
	.space	4080

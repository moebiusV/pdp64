; System v1 MMU: the user-access guard UA (status word bit 12), STUA and CLUA, and the user-qualified moves (errata 43, 190; manual 6.10.1, 6.10.3, 6.10.4, 6.13.7).
; Kernel mode with translation on.  P_U, P_K, P_R and P_X are pages of virtual 1 << 30: P_U a user page (U, R, W), P_K a kernel page (R, W), P_R a user page that is only
; readable, P_X a user page that is executable; P_N is not present.  The code and the tables are in the first 1 GiB, an identity superpage with no U bit.
;   1  UA is clear at reset; a load from, and a store to, P_U take the load and the store protection fault (vectors LPROT, SPROT, EVA the address, EPC the instruction); the handler
;      sees UA clear in the status word, and EPSW keeps the old value (clear)
;   2  a kernel page is reached with UA clear
;   3  STUA: the same accesses to P_U work (and the page cached under UA set is not used after CLUA: no flush is needed)
;   4  CLUA: they fault again
;   5  exception entry with UA set: the handler sees UA clear, EPSW holds it set, RTI brings it back
;   6  an instruction fetch from a user page is a fetch protection fault with UA set or clear (UA does not change it)
;   7  PROBER and PROBEW are not affected by UA
;   8  a `.U` move accesses its operand with user privilege: with UA clear it reaches P_U, it cannot reach P_K, and it cannot write P_R; its fault has bit 15 of ECAUSE set, a
;      plain move's fault has not (also when it follows a `.U` fault)
; Failure: halt with 4 * (the number of the check) + (0 no fault or too many, 1 ECAUSE, 2 EVA, 3 EPC), or 249 to 255 for the status word checks, 100 and up for a wrong value read.
#include "pdp64-consts.h"
#define RW (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
#define RWU (RW|1<<PTE_U)
#define RU (1<<PTE_V|1<<PTE_R|1<<PTE_A|1<<PTE_D|1<<PTE_U)
#define RXU (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_A|1<<PTE_D|1<<PTE_U)
#define UA (1<<PSW_UA)
#define USRBIT 0x8000
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
	movq	=1073741824, r3		; P_U
	movq	=1073745920, r11	; P_K
	movq	=1073750016, r14	; P_R (r14 is the stack pointer: nothing is pushed here)
	mfps	r1
	and	#(UA), r1
	cbeq	r1, #0, 1f
	movq	#250, r0		; UA was set at reset
	halt
1:
; ---- 1: UA clear
	movq	#0, r10
	lea	res1, r13
at1:	movq	8(r3), r5
res1:	lea	at1, r1
	movq	#(VECTOR_LPROT), r2
	movq	r3, r4
	add	#8, r4
	movq	#1, r0
	call	expect_fault
	and	#(UA), r12		; the handler saw UA clear, and so did EPSW
	cbeq	r12, #0, 1f
	movq	#251, r0
	halt
1:	and	#(UA), r7
	cbeq	r7, #0, 1f
	movq	#252, r0
	halt
1:	movq	#0, r10
	lea	res1s, r13
at1s:	movq	r5, 16(r3)
res1s:	lea	at1s, r1
	movq	#(VECTOR_SPROT), r2
	movq	r3, r4
	add	#16, r4
	movq	#2, r0
	call	expect_fault
; ---- 2: a kernel page
	movq	#0, r10
	movq	#0x7777, r5
	movq	r5, 16(r11)
	movq	16(r11), r2
	cmp	r2, r5
	beq	1f
	movq	#100, r0
	halt
1:	movq	#3, r0
	call	expect_none
; ---- 3: STUA
	stua
	mfps	r1
	and	#(UA), r1
	cbne	r1, #0, 1f
	movq	#253, r0
	halt
1:	movq	#0, r10
	movq	8(r3), r5
	cmp	r5, #0x1234
	beq	1f
	movq	#101, r0
	halt
1:	movq	#0x5555, r5
	movq	r5, 16(r3)
	movq	16(r3), r2
	cmp	r2, r5
	beq	1f
	movq	#102, r0
	halt
1:	movq	#4, r0
	call	expect_none
; ---- 4: CLUA
	clua
	mfps	r1
	and	#(UA), r1
	cbeq	r1, #0, 1f
	movq	#254, r0
	halt
1:	movq	#0, r10
	lea	res4, r13
at4:	movq	8(r3), r5
res4:	lea	at4, r1
	movq	#(VECTOR_LPROT), r2
	movq	r3, r4
	add	#8, r4
	movq	#5, r0
	call	expect_fault
; ---- 5: exception entry with UA set
	stua
	movq	#0, r10
	movq	=1073758208, r4		; P_N: not present
	lea	res5, r13
at5:	movq	(r4), r5
res5:	mfps	r15
	and	#(UA), r15		; RTI restored it
	cbne	r15, #0, 1f
	movq	#255, r0
	halt
1:	lea	at5, r1
	movq	#(VECTOR_LFAULT), r2
	movq	#6, r0
	call	expect_fault
	and	#(UA), r12		; in the handler: clear
	cbeq	r12, #0, 1f
	movq	#251, r0
	halt
1:	and	#(UA), r7		; EPSW: the old value, set
	cbne	r7, #0, 1f
	movq	#252, r0
	halt
1:
; ---- 6: an instruction fetch from a user page, with UA set and clear
	movq	=1073754112, r4		; P_X
	movq	#0, r10
	lea	res6, r13
	jmp	r4
res6:	movq	r4, r1
	movq	#(VECTOR_IPROT), r2
	movq	r4, r4
	movq	#7, r0
	call	expect_fault
	clua
	movq	#0, r10
	lea	res6b, r13
	jmp	r4
res6b:	movq	r4, r1
	movq	#(VECTOR_IPROT), r2
	movq	#8, r0
	call	expect_fault
; ---- 7: PROBER and PROBEW with UA clear
	prober	r2, r3
	cmp	r2, #1
	beq	1f
	movq	#103, r0
	halt
1:	probew	r2, r3
	cmp	r2, #1
	beq	1f
	movq	#104, r0
	halt
1:	probew	r2, r14
	cmp	r2, #0
	beq	1f
	movq	#105, r0
	halt
1:	prober	r2, r14
	cmp	r2, #1
	beq	1f
	movq	#106, r0
	halt
1:
; ---- 8: the `.U` moves, UA clear
	movq	#0, r10
	movq.u	8(r3), r5
	cmp	r5, #0x1234
	beq	1f
	movq	#107, r0
	halt
1:	movq	#0x6666, r5
	movq.u	r5, 24(r3)
	movq.u	24(r3), r2
	cmp	r2, r5
	beq	1f
	movq	#101, r0
	halt
1:	movq	#9, r0
	call	expect_none
	movq	#0, r10
	lea	res8a, r13
at8a:	movq.u	8(r11), r5
res8a:	lea	at8a, r1
	movq	#(VECTOR_LPROT|USRBIT), r2
	movq	r11, r4
	add	#8, r4
	movq	#10, r0
	call	expect_fault
	movq	#0, r10
	lea	res8b, r13
at8b:	movq.u	r5, 8(r11)
res8b:	lea	at8b, r1
	movq	#(VECTOR_SPROT|USRBIT), r2
	movq	r11, r4
	add	#8, r4
	movq	#11, r0
	call	expect_fault
	movq	#0, r10
	lea	res8c, r13
at8c:	movq.u	r5, 8(r14)
res8c:	lea	at8c, r1
	movq	#(VECTOR_SPROT|USRBIT), r2
	movq	r14, r4
	add	#8, r4
	movq	#12, r0
	call	expect_fault
	movq	#0, r10			; a plain move's fault after a .U fault has no bit 15
	lea	res8d, r13
at8d:	movq	8(r3), r5
res8d:	lea	at8d, r1
	movq	#(VECTOR_LPROT), r2
	movq	r3, r4
	add	#8, r4
	movq	#13, r0
	call	expect_fault
	stua				; with UA set a .U move still cannot reach a kernel page
	movq	#0, r10
	lea	res8e, r13
at8e:	movq.u	8(r11), r5
res8e:	lea	at8e, r1
	movq	#(VECTOR_LPROT|USRBIT), r2
	movq	r11, r4
	add	#8, r4
	movq	#14, r0
	call	expect_fault
	movq	#0, r0
	halt

; r10 == 0
expect_none:
	cbeq	r10, #0, 1f
	asl	r0
	asl	r0
	halt
1:	ret
; r0 = the number n of the check, r1 = the EPC, r2 = the ECAUSE, r4 = the EVA that the handler must have seen, exactly once
expect_fault:
	movq	r0, r5
	asl	r5
	asl	r5
	cmp	r10, #1
	beq	1f
	movq	r5, r0
	halt
1:	cmp	r8, r2
	beq	1f
	add	#1, r5
	movq	r5, r0
	halt
1:	cmp	r9, r4
	beq	1f
	add	#2, r5
	movq	r5, r0
	halt
1:	cmp	r6, r1
	beq	1f
	add	#3, r5
	movq	r5, r0
	halt
1:	ret
h_gen:	mfps	r12
	mfsr	r7, epsw
	mfsr	r6, epc
	mfsr	r8, ecause
	mfsr	r9, eva
	add	#1, r10
	mtsr	epc, r13
	rti
h_fail:	movq	#249, r0		; an unexpected exception
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
	.quad	pgU + RWU
	.quad	pgK + RW
	.quad	pgR + RU
	.quad	pgX + RXU
	.space	4064

	.align	4096
pgU:	.quad	0
	.quad	0x1234
	.space	4080

	.align	4096
pgK:	.quad	0
	.quad	0x2345
	.space	4080

	.align	4096
pgR:	.quad	0
	.quad	0x3456
	.space	4080

	.align	4096
pgX:	.quad	0
	.space	4088

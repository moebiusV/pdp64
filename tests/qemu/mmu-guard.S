; System v1 MMU: the user-memory guard and the user-qualified accesses (errata 43, 190; manual 6.10.1, 6.10.4, 6.13.7).  The guard has no switch: in kernel mode a data access to a user page
; is always a protection fault, and the only way to reach one is a `.U` access: a move qualified `.U`, or the block copy `MCPY.UR` (the bytes it reads are user memory) and `MCPY.UW` (the
; bytes it writes are).  Kernel mode with translation on.  P_U, P_K, P_R and P_X are pages of virtual 1 << 30: P_U a user page (U, R, W), P_K a kernel page (R, W), P_R a user page that is
; only readable, P_X a user page that is executable; P_N is not present.  The code and the tables are in the first 1 GiB, an identity superpage with no U bit.
;   1  a load from, and a store to, P_U take the load and the store protection fault (vectors LPROT, SPROT, EVA the address, EPC the instruction); bit 12 of the status word is not a bit
;   2  a kernel page is reached
;   3  an exception entry changes no guard: the handler's status word and EPSW have no bit 12, and a write of it by MTPS is dropped
;   4  an instruction fetch from a user page is a fetch protection fault
;   5  PROBER and PROBEW are not affected by the guard
;   6  a `.U` move accesses its operand with user privilege: it reaches P_U, it cannot reach P_K, and it cannot write P_R; its fault has bit 15 of ECAUSE set, a plain move's fault has not
;      (also when it follows a `.U` fault)
;   7  `MCPY.UR` copies from a user page into a kernel page and `MCPY.UW` from a kernel page into a user page; the plain `MCPY` does neither; a user side that is not user memory is a
;      protection fault with bit 15 of ECAUSE set; a copy that meets a fault in its middle has moved the bytes before it and left its registers at the byte
; Failure: halt with 4 * (the number of the check) + (0 no fault or too many, 1 ECAUSE, 2 EVA, 3 EPC), or 249 to 255 for the status word checks, 100 and up for a wrong value read.
#include "pdp64-consts.h"
#define RW (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D)
#define RWU (RW|1<<PTE_U)
#define RU (1<<PTE_V|1<<PTE_R|1<<PTE_A|1<<PTE_D|1<<PTE_U)
#define RXU (1<<PTE_V|1<<PTE_R|1<<PTE_X|1<<PTE_A|1<<PTE_D|1<<PTE_U)
#define UA 0x1000
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
	movq	#250, r0		; bit 12 of the status word is set
	halt
1:
; ---- 1: a user page
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
	cbeq r2, r5, 1f
	movq	#100, r0
	halt
1:	movq	#3, r0
	call	expect_none
; ---- 3: no guard in the status word
	mfps	r1
	and	#(UA), r1
	cbeq	r1, #0, 1f
	movq	#253, r0
	halt
1:	mfps	r1
	bis	#(UA), r1
	mtps	r1			; a write of bit 12 is dropped
	mfps	r1
	and	#(UA), r1
	cbeq	r1, #0, 1f
	movq	#254, r0
	halt
1:	movq	#0, r10
	movq	=1073758208, r4		; P_N: not present
	lea	res3, r13
at3:	movq	(r4), r5
res3:	and	#(UA), r12		; in the handler
	cbeq	r12, #0, 1f
	movq	#251, r0
	halt
1:	and	#(UA), r7		; EPSW
	cbeq	r7, #0, 1f
	movq	#252, r0
	halt
1:
; ---- 4: an instruction fetch from a user page
	movq	=1073754112, r4		; P_X
	movq	#0, r10
	lea	res4, r13
	jmp	r4
res4:	movq	r4, r1
	movq	#(VECTOR_IPROT), r2
	movq	r4, r4
	movq	#4, r0
	call	expect_fault
; ---- 5: PROBER and PROBEW
	prober	r2, r3
	cbeq r2, #1, 1f
	movq	#103, r0
	halt
1:	probew	r2, r3
	cbeq r2, #1, 1f
	movq	#104, r0
	halt
1:	probew	r2, r14
	cbeq r2, #0, 1f
	movq	#105, r0
	halt
1:	prober	r2, r14
	cbeq r2, #1, 1f
	movq	#106, r0
	halt
1:
; ---- 6: the `.U` moves
	movq	#0, r10
	movq.u	8(r3), r5
	cbeq r5, #0x1234, 1f
	movq	#107, r0
	halt
1:	movq	#0x6666, r5
	movq.u	r5, 24(r3)
	movq.u	24(r3), r2
	cbeq r2, r5, 1f
	movq	#101, r0
	halt
1:	movq	#5, r0
	call	expect_none
	movq	#0, r10
	lea	res8a, r13
at8a:	movq.u	8(r11), r5
res8a:	lea	at8a, r1
	movq	#(VECTOR_LPROT|USRBIT), r2
	movq	r11, r4
	add	#8, r4
	movq	#6, r0
	call	expect_fault
	movq	#0, r10
	lea	res8b, r13
at8b:	movq.u	r5, 8(r11)
res8b:	lea	at8b, r1
	movq	#(VECTOR_SPROT|USRBIT), r2
	movq	r11, r4
	add	#8, r4
	movq	#7, r0
	call	expect_fault
	movq	#0, r10
	lea	res8c, r13
at8c:	movq.u	r5, 8(r14)
res8c:	lea	at8c, r1
	movq	#(VECTOR_SPROT|USRBIT), r2
	movq	r14, r4
	add	#8, r4
	movq	#8, r0
	call	expect_fault
	movq	#0, r10			; a plain move's fault after a .U fault has no bit 15
	lea	res8d, r13
at8d:	movq	8(r3), r5
res8d:	lea	at8d, r1
	movq	#(VECTOR_LPROT), r2
	movq	r3, r4
	add	#8, r4
	movq	#9, r0
	call	expect_fault
; ---- 7: MCPY.UR and MCPY.UW
	movq	#0, r10
	movq	r11, r20		; to P_K + 32
	add	#32, r20
	movq	r3, r21			; from P_U + 8
	add	#8, r21
	movq	#8, r22
	mcpy.ur	r20, r21, r22
	movq	32(r11), r2
	cbeq r2, #0x1234, 1f
	movq	#108, r0
	halt
1:	cbeq r22, #0, 1f
	movq	#109, r0
	halt
1:	movq	#11, r0
	call	expect_none
	movq	r3, r20			; to P_U + 40
	add	#40, r20
	movq	r11, r21		; from P_K + 8
	add	#8, r21
	movq	#8, r22
	mcpy.uw	r20, r21, r22
	movq.u	40(r3), r2
	cbeq r2, #0x2345, 1f
	movq	#110, r0
	halt
1:	movq	#12, r0
	call	expect_none
	movq	#0, r10			; the plain copy reads no user page ...
	lea	res7a, r13
	movq	r11, r20
	add	#32, r20
	movq	r3, r21
	add	#8, r21
	movq	#8, r22
at7a:	mcpy	r20, r21, r22
res7a:	lea	at7a, r1
	movq	#(VECTOR_LPROT), r2
	movq	r3, r4
	add	#8, r4
	movq	#13, r0
	call	expect_fault
	movq	#0, r10			; ... and writes none
	lea	res7b, r13
	movq	r3, r20
	add	#40, r20
	movq	r11, r21
	add	#8, r21
	movq	#8, r22
at7b:	mcpy	r20, r21, r22
res7b:	lea	at7b, r1
	movq	#(VECTOR_SPROT), r2
	movq	r3, r4
	add	#40, r4
	movq	#14, r0
	call	expect_fault
	movq	#0, r10			; MCPY.UR of a kernel page: the read is a user access, and fails
	lea	res7c, r13
	movq	r3, r20
	add	#40, r20
	movq	r11, r21
	add	#8, r21
	movq	#8, r22
at7c:	mcpy.ur	r20, r21, r22
res7c:	lea	at7c, r1
	movq	#(VECTOR_LPROT|USRBIT), r2
	movq	r11, r4
	add	#8, r4
	movq	#15, r0
	call	expect_fault
	movq	#0, r10			; MCPY.UW to a kernel page
	lea	res7d, r13
	movq	r11, r20
	add	#40, r20
	movq	r11, r21
	add	#8, r21
	movq	#8, r22
at7d:	mcpy.uw	r20, r21, r22
res7d:	lea	at7d, r1
	movq	#(VECTOR_SPROT|USRBIT), r2
	movq	r11, r4
	add	#40, r4
	movq	#16, r0
	call	expect_fault
	movq	#0, r10			; MCPY.UW to a user page that cannot be written
	lea	res7e, r13
	movq	r14, r20
	add	#8, r20
	movq	r11, r21
	add	#8, r21
	movq	#8, r22
at7e:	mcpy.uw	r20, r21, r22
res7e:	lea	at7e, r1
	movq	#(VECTOR_SPROT|USRBIT), r2
	movq	r14, r4
	add	#8, r4
	movq	#17, r0
	call	expect_fault
	movq	#0, r10			; a copy that meets a fault in the middle: the bytes before it are moved, the registers stand at the byte
	lea	res7f, r13
	movq	r11, r20
	add	#64, r20
	movq	r3, r21
	add	#4088, r21		; the last 8 bytes of P_U, then P_K
	movq	#16, r22
at7f:	mcpy.ur	r20, r21, r22
res7f:	lea	at7f, r1
	movq	#(VECTOR_LPROT|USRBIT), r2
	movq	r3, r4
	add	#4096, r4
	movq	#18, r0
	call	expect_fault
	cbeq r22, #8, 1f
	movq	#111, r0
	halt
1:	movq	r3, r2
	add	#4096, r2
	cbeq r21, r2, 1f
	movq	#112, r0
	halt
1:	movq	r11, r2
	add	#72, r2
	cbeq r20, r2, 1f
	movq	#113, r0
	halt
1:	movq	#0, r0
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
	cbeq r10, #1, 1f
	movq	r5, r0
	halt
1:	cbeq r8, r2, 1f
	add	#1, r5
	movq	r5, r0
	halt
1:	cbeq r9, r4, 1f
	add	#2, r5
	movq	r5, r0
	halt
1:	cbeq r6, r1, 1f
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
	rti	#RTIMASK_ALL
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

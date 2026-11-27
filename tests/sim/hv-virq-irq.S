; A physical interrupt and a virtual line at the same boundary (errata 195, 196; design 1.8 "interplay"): the physical interrupt exits first, the virtual line stays pending (VIRQ unchanged, the guest's
; EPC untouched); when the hypervisor enters the guest again the virtual line is delivered.  The request is injected by -i at instruction 100 (level 1: the hypervisor at priority 7 does not take it).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	xh, r2
	mov	#512, r3
fill1:	mov	r2, (r1)+
	sob	r3, fill1
	lea	gvtab, r1
	mtsr	vbr, r1
	lea	gh, r2
	mov	#512, r3
fill2:	mov	r2, (r1)+
	sob	r3, fill2
	lea	gstk_top, r2
	mtsr	gksp, r2
	mov	#0, r1
	mtsr	htrap, r1
	mtsr	epc, r1
	mov	=(200<<32), r1		; line 5 -> vector 200
	mtsr	vivec, r1
	mov	#(1<<5), r1
	mtsr	virq, r1
	lea	guest, r1
	mtsr	hepc, r1
	mov	#0, r1
	mtsr	hepsw, r1
	mov	#0, r10
	mov	#0, r11
	mov	#99, r0
	genter	#RTIMASK_ALL
guest:	nop
	nop
	halt
xh:	mfsr	r20, hexitr
	cbne	r20, #XCODE_IRQ, 1f
	; the exit for the physical request: the vector, HEPC the first guest instruction, VIRQ unchanged, EPC untouched
	add	#1, r10
	mfsr	r21, hcause
	cbeq	r21, #43, 2f
	mov	#1, r0
	halt
2:	mfsr	r21, hepc
	lea	guest, r22
	cbeq	r21, r22, 2f
	mov	#2, r0
	halt
2:	mfsr	r21, virq
	cbeq	r21, #(1<<5), 2f
	mov	#3, r0
	halt
2:	mfsr	r21, epc
	cbeq	r21, #0, 2f
	mov	#4, r0
	halt
2:	genter	#RTIMASK_ALL	; HEPC and HEPSW are as the exit left them
1:	cbeq	r20, #XCODE_HALT, 1f
	mov	#5, r0
	halt
1:	cbeq	r10, #1, 1f		; exactly one exit for the physical request
	mov	#6, r0
	halt
1:	cbeq	r11, #1, 1f		; and then exactly one virtual interrupt, vector 200
	mov	#7, r0
	halt
1:	cbeq	r12, #200, 1f
	mov	#8, r0
	halt
1:	mfsr	r21, virq
	cbeq	r21, #0, 1f
	mov	#9, r0
	halt
1:	mov	#0, r0
	halt
gh:	add	#1, r11
	mfsr	r12, ecause
	rti	#RTIMASK_ALL
	.data
	.align	8
htab:	.space	4096
gvtab:	.space	4096
	.space	512
gstk_top:

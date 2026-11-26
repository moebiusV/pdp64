; the explicit tag check of a runtime with 3-bit low tags: cons = 1, fixnum = 0, nil = 2.
; A plain access works at any address, so a mis-tagged pointer is caught by BNTAG, not by a fault; the walk of a list uses BTAG as its loop test.
	.text
	.globl	_start
_start:
	lea	cells+1, r1		; a tagged cons: car at -1, cdr at 7
	bntag	r1, #1, f1		; the right tag: not taken
	movq	-1(r1), r2
	cbne r2, #40, f2
	movq	7(r1), r3		; cdr: the next cell, tagged
	btag	r3, #1, ok3
	br	f3
ok3:	movq	-1(r3), r2
	cbne r2, #56, f4
	; a mis-tagged pointer: the check takes the slow path
	lea	cells+2, r4
	bntag	r4, #1, slow
	br	f5
slow:	bis	#1, r4			; the slow path repairs the tag
	bic	#6, r4
	movq	-1(r4), r2
	cbne r2, #40, f6
	; the same mis-tagged pointer used without a check: no fault, a misaligned load that returns the bytes at that address
	lea	cells+2, r4
	mov	-1(r4).8, r2 ; byte at cells+1: the second byte of the car
	mov	0(r4).8, r5 ; byte at cells+2: the third byte
	movq	-1(r4), r3		; the quad at cells+1: a misaligned access, no fault
	shl	#8, r3			; drop the top byte (the cdr's low byte); bytes 1..7 of the car are zero
	cbne r3, #0, f7
	; an unaligned store to the same address changes exactly the bytes it covers
	movq	#0x1122334455667788, r5
	movq	r5, -1(r4)
	movq	cells, r2		; the low byte of the car (40 = 0x28) is untouched, bytes 1..7 are the new value's low seven bytes
	movq	#0x2233445566778828, r6
	cbne r2, r6, f8
	; the walk: three cells, the loop test is BTAG (cons: go on), the fall-through tests nil
	lea	walk+1, r1
	movq	#0, r2
	bntag	r1, #1, f9
top:	movq	-1(r1), r3
	add	r3, r2
	movq	7(r1), r1
	btag	r1, #1, top
	cbne	r1, #2, f10		; the end of the list is nil
	cbne r2, #24, f11
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
f3:	movq	#3, r0
	trap	#0
f4:	movq	#4, r0
	trap	#0
f5:	movq	#5, r0
	trap	#0
f6:	movq	#6, r0
	trap	#0
f7:	movq	#7, r0
	trap	#0
f8:	movq	#8, r0
	trap	#0
f9:	movq	#9, r0
	trap	#0
f10:	movq	#10, r0
	trap	#0
f11:	movq	#11, r0
	trap	#0
	.data
	.align	8
cells:	.quad	40
	.quad	cells+17		; cdr: the next cell, tag 1
	.quad	56
	.quad	2
walk:	.quad	8
	.quad	walk+17
	.quad	8
	.quad	walk+33
	.quad	8
	.quad	2

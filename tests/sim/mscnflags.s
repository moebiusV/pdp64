; mscn and mscnn write all four flags (errata 39): Z is set when the byte was found (mscnn: when a different byte was found) and N, V and C are cleared;
; Z is clear and N, V, C cleared when it was not found, or the count was zero.  The flags are all set before.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	lea	buf, r5
	movq	#0x33, r2		; the byte to find
	movq	#8, r3			; the count
	movq	#15, r6
	mtps	r6			; N Z V C all set
	movq	r5, r1
	mscn	r1, r2, r3		; found at buf+3
	mfps	r7
	and	#15, r7
	cmp	r7, #4			; Z only
	bne	f1
	movq	#15, r6
	mtps	r6
	movq	r5, r1
	movq	#8, r3
	movq	#0x77, r2		; not in the buffer
	mscn	r1, r2, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0			; none (N, V, C were set: they are cleared)
	bne	f2
	movq	#15, r6
	mtps	r6
	movq	r5, r1
	movq	#8, r3
	movq	#0x11, r2		; the first byte is 0x11: mscnn skips it and finds the second
	mscnn	r1, r2, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f3
	movq	#15, r6
	mtps	r6
	movq	r5, r1
	movq	#0, r3			; a count of zero scans nothing: not found
	movq	#0x11, r2
	mscn	r1, r2, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f4
	movq	#0, r6
	mtps	r6			; all clear before: a hit sets Z only, a miss writes nothing visible
	movq	r5, r1
	movq	#8, r3
	movq	#0x11, r2
	mscn	r1, r2, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f5
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
	.data
buf:	.byte	0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 - 1, 0x88

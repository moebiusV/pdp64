; k_sad (FFmpeg pixel_sad_c): the sum of absolute differences of two w x h blocks of bytes.  r0 = a, r1 = a stride, r2 = b, r3 = b stride, r4 = w, r5 = h.
; The row is a region with a reduction into r6; the rows stay a scalar loop.
k_sad:
	clr	r6
	movq	r1,r10
	sub	r4,r10			; a stride - w
	movq	r3,r11
	sub	r4,r11			; b stride - w
.row:	lea	(r0)(r4),r7
	vec	r0,r7
	vld.bu	v0,(r0)+		; byte lanes: a strip of 32 bytes (errata 168: the reduction widens, the load need not)
	vld.bu	v1,(r2)+
	vabdu.b	v0,v0,v1		; absolute difference of unsigned bytes
	vacc.bu.l r6,v0			; r6 += the sum of the byte lanes of the strip as unsigned, in 32 bits; kept in r6 after each strip, so a fault restarts cleanly
	vend
	add	r10,r0
	add	r11,r2
	dec	r5
	cbgt	r5,#0,.row
	movq	r6,r0
	ret

; k_dctop_fill (dav1d splat_dc, 8 bits): every pixel of a width x height block is the byte dc.  r0 = dst, r1 = stride, r2 = width, r3 = height, r4 = dc.
; A fill: the single-instruction prefix is enough (a store of a register to a region).  The row loop stays scalar.
k_dctop_fill:
	movq	r1,r6
	sub	r2,r6			; stride - width: what is left to add after a row moved r0 by width
.row:	lea	(r0)(r2),r5
	vec	r0,r5
	movb	r4,(r0)+		; store the byte; r0 moves by one element at a time (or by a strip, at the implementation's choice)
	add	r6,r0
	dec	r3
	cbgt	r3,#0,.row
	ret

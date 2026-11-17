; k_prep8 (dav1d prep_c, 8 bits, one row): tmp[x] = src[x] << 4.   r0 = tmp (int16), r1 = src (bytes), r2 = w
; Two memory streams and a widening: the single-instruction prefix cannot say it, the block form can.
k_prep8:
	lea	(r1)(r2),r3		; end of the source region
	vec	r1,r3			; the block to vend runs once for each strip of [r1, r3)
	vld.bu.h v0,(r1)+		; load a strip of bytes, zero-extended to 16-bit lanes; r1 moves past the strip
	vshl.h	v0,#4
	vst.h	v0,(r0)+		; store the strip; r0 moves past it
	vend
	ret

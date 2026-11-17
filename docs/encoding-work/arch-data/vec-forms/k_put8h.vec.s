; k_put8h (dav1d put_8tap_c, horizontal only, 8 bits, one row): dst[x] = clip8((sum of F[k]*src[x-3+k] + 32) >> 6).
; r0 = dst, r1 = src, r2 = w, r3 = F (eight signed bytes).  Form A: taps by eight displaced loads, no operation beyond the decided prefix idea.
k_put8h:
	movsb	0(r3),r10		; the eight taps (hoisted out of a loop over rows in real use)
	movsb	1(r3),r11
	movsb	2(r3),r12
	movsb	3(r3),r13
	movsb	4(r3),r14
	movsb	5(r3),r15
	movsb	6(r3),r16
	movsb	7(r3),r17
	lea	(r1)(r2),r9
	vec	r1,r9
	vld.bu.l v0,-3(r1)		; 32-bit lanes: the sum of eight products of bytes needs more than 16 bits
	vmul.l	v1,v0,r10		; v1 = v0 * r10 (a scalar register is the multiplier)
	vld.bu.l v0,-2(r1)
	vmla.l	v1,v0,r11		; v1 += v0 * r11
	vld.bu.l v0,-1(r1)
	vmla.l	v1,v0,r12
	vld.bu.l v0,0(r1)
	vmla.l	v1,v0,r13
	vld.bu.l v0,1(r1)
	vmla.l	v1,v0,r14
	vld.bu.l v0,2(r1)
	vmla.l	v1,v0,r15
	vld.bu.l v0,3(r1)
	vmla.l	v1,v0,r16
	vld.bu.l v0,4(r1)+		; the last load moves r1 past the strip
	vmla.l	v1,v0,r17
	vadd.l	v1,#32
	vsar.l	v1,#6
	vsts.l.bu v1,(r0)+		; saturating narrow: clamp to 0..255 and store bytes
	vend
	ret

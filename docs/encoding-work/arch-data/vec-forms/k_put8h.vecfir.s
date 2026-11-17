; k_put8h, form B: the same with a sliding-window multiply-accumulate (a FIR filter over a strip, eight taps held in r10..r17; the hardware keeps the
; seven elements of the previous strip that the window needs, so the region is read once).
k_put8h:
	movsb	0(r3),r10
	movsb	1(r3),r11
	movsb	2(r3),r12
	movsb	3(r3),r13
	movsb	4(r3),r14
	movsb	5(r3),r15
	movsb	6(r3),r16
	movsb	7(r3),r17
	lea	(r1)(r2),r9
	vec	r1,r9
	vld.bu.l v0,(r1)+
	vfir.l	v1,v0,r10		; v1[i] = sum over k = 0..7 of r(10+k) * v0[i+k-3]; reads 3 before and 4 after the region as the scalar code does
	vadd.l	v1,#32
	vsar.l	v1,#6
	vsts.l.bu v1,(r0)+
	vend
	ret

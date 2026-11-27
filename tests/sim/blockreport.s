; the register report of mcmp, mscn and mscnn (they write no flag).
; mcmp Rd, Rs, Rn: Rn is 0 when the blocks were equal; at a difference Rn is not 0 and Rd and Rs point at the first differing bytes.
; mscn / mscnn Rd, Rv, Rn: Rn is 0 when no byte was found; otherwise Rn is not 0 and Rd points at the byte found.
; A failed check n exits with n.
	.text
	.globl	_start
_start:
	lea	a, r1
	lea	b, r2
	mov	#8, r3
	mcmp	r1, r2, r3
	cbne	r3, #0, f1		; equal: Rn is 0
	lea	a, r4
	lea	b, r5
	lea	a, r1
	lea	c, r2
	mov	#8, r3
	mcmp	r1, r2, r3
	cbeq	r3, #0, f3		; a difference: Rn is not 0
	lea	a+0, r4
	cbne	r1, r4, f4		; Rd at the differing byte
	lea	c+0, r4
	cbne	r2, r4, f5		; Rs at the differing byte
	lea	a, r1
	lea	d, r2
	mov	#8, r3
	mcmp	r1, r2, r3
	cbeq	r3, #0, f6		; a difference: Rn is not 0
	lea	a+4, r4
	cbne	r1, r4, f7		; Rd at the differing byte
	lea	d+4, r4
	cbne	r2, r4, f8		; Rs at the differing byte
	lea	a, r1
	lea	e, r2
	mov	#8, r3
	mcmp	r1, r2, r3
	cbeq	r3, #0, f9		; a difference: Rn is not 0
	lea	a+7, r4
	cbne	r1, r4, f10		; Rd at the differing byte
	lea	e+7, r4
	cbne	r2, r4, f11		; Rs at the differing byte
	lea	a, r1
	lea	e, r2
	mov	#7, r3
	mcmp	r1, r2, r3
	cbne	r3, #0, f12		; equal: Rn is 0
	lea	a, r4
	lea	e, r5
	lea	a, r1
	lea	c, r2
	mov	#0, r3
	mcmp	r1, r2, r3
	cbne	r3, #0, f14		; equal: Rn is 0
	lea	a, r4
	lea	c, r5
	lea	s, r1
	mov	#51, r2
	mov	#8, r3
	mscn	r1, r2, r3
	cbeq	r3, #0, f16		; found: Rn is not 0
	lea	s+2, r4
	cbne	r1, r4, f17		; Rd at the byte found
	lea	s, r1
	mov	#17, r2
	mov	#8, r3
	mscn	r1, r2, r3
	cbeq	r3, #0, f18		; found: Rn is not 0
	lea	s+0, r4
	cbne	r1, r4, f19		; Rd at the byte found
	lea	s, r1
	mov	#136, r2
	mov	#8, r3
	mscn	r1, r2, r3
	cbeq	r3, #0, f20		; found: Rn is not 0
	lea	s+7, r4
	cbne	r1, r4, f21		; Rd at the byte found
	lea	s, r1
	mov	#119, r2
	mov	#8, r3
	mscn	r1, r2, r3
	cbne	r3, #0, f22		; not found: Rn is 0
	lea	s, r1
	mov	#136, r2
	mov	#7, r3
	mscn	r1, r2, r3
	cbne	r3, #0, f23		; not found: Rn is 0
	lea	s, r1
	mov	#17, r2
	mov	#0, r3
	mscn	r1, r2, r3
	cbne	r3, #0, f24		; not found: Rn is 0
	lea	s, r1
	mov	#17, r2
	mov	#8, r3
	mscnn	r1, r2, r3
	cbeq	r3, #0, f25		; found: Rn is not 0
	lea	s+1, r4
	cbne	r1, r4, f26		; Rd at the byte found
	lea	t, r1
	mov	#85, r2
	mov	#8, r3
	mscnn	r1, r2, r3
	cbne	r3, #0, f27		; not found: Rn is 0
	lea	t, r1
	mov	#85, r2
	mov	#0, r3
	mscnn	r1, r2, r3
	cbne	r3, #0, f28		; not found: Rn is 0
	lea	u, r1
	mov	#85, r2
	mov	#8, r3
	mscnn	r1, r2, r3
	cbeq	r3, #0, f29		; found: Rn is not 0
	lea	u+7, r4
	cbne	r1, r4, f30		; Rd at the byte found
	mov	#0, r0
	trap	#0
f1:	mov	#1, r0
	trap	#0
f2:	mov	#2, r0
	trap	#0
f3:	mov	#3, r0
	trap	#0
f4:	mov	#4, r0
	trap	#0
f5:	mov	#5, r0
	trap	#0
f6:	mov	#6, r0
	trap	#0
f7:	mov	#7, r0
	trap	#0
f8:	mov	#8, r0
	trap	#0
f9:	mov	#9, r0
	trap	#0
f10:	mov	#10, r0
	trap	#0
f11:	mov	#11, r0
	trap	#0
f12:	mov	#12, r0
	trap	#0
f13:	mov	#13, r0
	trap	#0
f14:	mov	#14, r0
	trap	#0
f15:	mov	#15, r0
	trap	#0
f16:	mov	#16, r0
	trap	#0
f17:	mov	#17, r0
	trap	#0
f18:	mov	#18, r0
	trap	#0
f19:	mov	#19, r0
	trap	#0
f20:	mov	#20, r0
	trap	#0
f21:	mov	#21, r0
	trap	#0
f22:	mov	#22, r0
	trap	#0
f23:	mov	#23, r0
	trap	#0
f24:	mov	#24, r0
	trap	#0
f25:	mov	#25, r0
	trap	#0
f26:	mov	#26, r0
	trap	#0
f27:	mov	#27, r0
	trap	#0
f28:	mov	#28, r0
	trap	#0
f29:	mov	#29, r0
	trap	#0
f30:	mov	#30, r0
	trap	#0
	.data
a:	.byte	1, 2, 3, 4, 5, 6, 7, 8
b:	.byte	1, 2, 3, 4, 5, 6, 7, 8
c:	.byte	9, 2, 3, 4, 5, 6, 7, 8
d:	.byte	1, 2, 3, 4, 9, 6, 7, 8
e:	.byte	1, 2, 3, 4, 5, 6, 7, 9
s:	.byte	0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 - 1, 0x88
t:	.byte	0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
u:	.byte	0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56

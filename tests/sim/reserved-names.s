; every word the assembler reads as a word (the NASM data and section words, the vector and tile registers) is an ordinary symbol where a symbol is expected:
; a C global may be called dd, v0 or t7 (errata 169).  Only the vector instructions name v0..v15 and t0..t7.
	.text
	.globl	_start
_start:
	mov	#1, r9
	lea	dd, r1			; dd, dq, db, dw after an instruction word are the symbols, not a datum
	mov	(r1), r2
	mov	#11, r3
	cbne	r2, r3, fail
	mov	#2, r9
	lea	v0, r1
	mov	(r1), r2
	mov	#22, r3
	cbne	r2, r3, fail
	mov	#3, r9
	lea	t7, r1
	mov	(r1), r2
	mov	#33, r3
	cbne	r2, r3, fail
	mov	#4, r9
	lea	resb, r1
	mov	(r1), r2
	mov	#44, r3
	cbne	r2, r3, fail
	mov	#5, r9
	lea	section, r1
	mov	(r1), r2
	mov	#55, r3
	cbne	r2, r3, fail
	mov	#6, r9
	lea	ptrs, r1			; .quad takes the symbols too
	mov	8(r1), r1
	mov	(r1), r2
	cbne	r2, r3, fail
	mov	#7, r9
	; a vector block still takes v0 as a vector register
	lea	vsrc, r1
	lea	vdst, r0
	lea	8(r1), r4
	vec	r1, r4
	vld.b	v0, (r1)+
	vst.b	v0, (r0)+
	vend
	lea	vdst, r0
	mov.s8	(r0), r2
	mov	#9, r3
	cbne	r2, r3, fail
	mov	#0, r0
	trap	#0
fail:	mov	r9, r0
	trap	#0
	.data
	.align	8
dd:	.quad	11
v0:	.quad	22
t7:	.quad	33
resb:	.quad	44
section: .quad	55
ptrs:	.quad	dd, section
vsrc:	.byte	9, 8, 7, 6, 5, 4, 3, 2
vdst:	.space	8

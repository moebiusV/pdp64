; literal-pool loads (=K): a 64-bit constant in the pool, used as a quad memory source; the result is that of the same operation with an immediate.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	mov	=0x123456789ABC, r1
	mov	r1, r2
	shr	$32, r2
	cbne r2, $0x1234, f1
	mov	=0x123456789ABC, r3
	cbne r1, r3, f2
	mov	=0x123456789ABC, r13	; equal: Z set
	cbne	r1, r13, f3
	add	=0x100000000, r1
	shr	$32, r1
	cbne r1, $0x1235, f4
	mov	$-1, r4
	and	=0xFFFFFFFF00, r4
	shr	$8, r4
	mov	=0xFFFFFFFF, r13
	cbne	r4, r13, f5
	push	=0x7000000000
	pop	r5
	shr	$32, r5
	cbne r5, $0x70, f6
	mov	=-0x8000000001, r6	; below -2^31
	add	$1, r6
	mov	=-0x8000000000, r7
	cbne r6, r7, f7
	mov	=K, r8			; a constant defined by an assignment
	shr	$40, r8
	cbne r8, $0x7f, f8
	mov	=0x3FF0000000000000, r9	; 1.0 as a bit pattern: fadd =1.0, r9 gives 2.0
	fadd	=0x3FF0000000000000, r9
	mov	=0x4000000000000000, r10
	cbne r9, r10, f9
	br	1f			; a pool in the middle of the code: jumped over, the code after it goes on
	.pool
1:
	mov	=5, r11
	cbne r11, $5, f10
	mov	$0, r0
	trap	$0
f1:	mov	$1, r0
	trap	$0
f2:	mov	$2, r0
	trap	$0
f3:	mov	$3, r0
	trap	$0
f4:	mov	$4, r0
	trap	$0
f5:	mov	$5, r0
	trap	$0
f6:	mov	$6, r0
	trap	$0
f7:	mov	$7, r0
	trap	$0
f8:	mov	$8, r0
	trap	$0
f9:	mov	$9, r0
	trap	$0
f10:	mov	$10, r0
	trap	$0
K = 0x7fffffffffff

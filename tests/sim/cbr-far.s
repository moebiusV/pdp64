; the register-register cbCC in its six-byte form (a displacement of more than 2047 parcels), forward and back, taken and not taken.  Exit 1 on failure.
	.text
	.globl	_start
_start:
	movq	#4, r1
	movq	#9, r2
	cblt	r1, r2, 3f		; taken, forward 2500 parcels
	br	fail
	.space	5000
3:	cbgt	r1, r2, fail		; not taken
	br	4f
5:	cbeq	r2, r2, 6f		; taken, backward from the far end
	br	fail
	.space	5000
4:	cbne	r1, r1, fail		; not taken, six bytes
	cbeq	r1, r1, 5b		; taken, backward 2500 parcels
	br	fail
6:	movq	#0, r0
	trap	#0
fail:	movq	#1, r0
	trap	#0

; the wide-immediate cbCC over about 30000 parcels, forward and back (the displacement is 16 bits).  Exit 1 on failure.
	.text
	.globl	_start
_start:
	movq	#255, r1
	cbeq	r1, #255, 3f
	br	fail
	.space	60000
3:	br	4f
5:	br	6f
	.space	60000
4:	cbeq	r1, #255, 5b
	br	fail
6:
	movq	#0, r0
	trap	#0
fail:	movq	#1, r0
	trap	#0

; sum 1..10 in a loop; exit status 55
	.text
	.globl	_start
_start:	movq	#0, r0
	movq	#10, r1
1:	add	r1, r0
	sob	r1, 1b
	trap	#0

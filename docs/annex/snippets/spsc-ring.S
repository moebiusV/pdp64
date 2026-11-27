; A one-producer, one-consumer ring of 8 words, with no fence and no lock.  Run alone on one core it pushes 3 words and pops them.
	.text
	.globl	_start
_start:
	; ---- producer: data first, then the new tail
	lea	ring, r1
	lea	tail, r2
	mov	(r2), r3			; tail (only the producer writes it)
	mov	#11, r4
	mov	r4, (r1)(r3*8)			; 1. store the data
	add	#1, r3
	and	#7, r3
	mov	r3, (r2)			; 2. publish: store the new tail
	; ---- consumer: tail first, then the data
	lea	head, r5
	mov	(r5), r6			; head (only the consumer writes it)
	mov	(r2), r7			; 1. load the tail
	cbeq	r6, r7, empty			; head == tail: nothing there
	mov	(r1)(r6*8), r8			; 2. load the data: it cannot be the old word
	add	#1, r6
	and	#7, r6
	mov	r6, (r5)			; free the slot
	cbeq	r8, #11, ok
empty:	mov	#1, r0
	halt
ok:	mov	#0, r0
	halt
	.data
	.align	8
ring:	.space	64
head:	.quad	0
tail:	.quad	0

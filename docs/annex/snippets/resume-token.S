; A handler that wants a vector block to START AGAIN rather than resume clears the token (the upper half of the saved status word).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	mfsr	r1, epsw
	shl	#32, r1
	shr	#32, r1				; the token is gone: the block restarts from its first strip
	mtsr	epsw, r1
	rti	#RTIMASK_ALL

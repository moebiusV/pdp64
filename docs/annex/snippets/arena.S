; The hypervisor tells the hardware where its stage-2 tables live (the arena), and where the epoch word is.  After this a plain store into
; the arena is all it does to change a guest's mapping: the hardware throws the guest's cached translations away at the next GENTER.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	arena, r1
	shr	$12, r1				; the number of the first page of the arena ...
	shl	$28, r1				; ... in bits 55 to 28 of HARENA ...
	bis	$16, r1				; ... and the number of pages (16) in bits 27 to 0
	mtsr	harena, r1
	lea	epoch_word, r1			; the word the other cores read at their guest entry
	mtsr	hepoch, r1
	lea	s2leaf, r2			; change one stage-2 entry of a guest: an ordinary store ...
	mov	=0x8f7013, r3
	mov	r3, (r2)			; ... into the arena; nothing else is asked of the hypervisor
	genter	$0				; the entry throws away the guest's translations if the flag was set
	.data
epoch_word:	.quad	0
	.align	4096
arena:
s2leaf:	.space	65536

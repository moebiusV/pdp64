; Starting a new guest: ask the hardware for a tag, and read back the one it gave.
#include "pdp64-consts.h"
#define GTBR_NEW 1
	.text
	.globl	_start
_start:
	lea	hroot, r1			; the stage-2 root (one page)
	movq	=(1<<GTBR_S2EN | 1<<GTBR_NEW), r2
	bis	r2, r1
	mtsr	gtbr, r1			; every entry under the next number is thrown away, then the number is handed out
	mfsr	r3, gtbr
	shr	#48, r3				; r3 is the guest's tag; the hypervisor never chose it
	halt
	.data
	.align	4096
hroot:	.space	4096

; At the hypervisor level the ordinary names are the hypervisor's own: a kernel's page-table code runs unchanged.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	hproot, r1
	mtsr	ptbr, r1			; the hypervisor's own table root
	mov	#1, r2
	mtsr	mmuctl, r2			; its own translation on (one stage, tag 0)
	isync
	halt
	.data
	.align	4096
hproot:	.space	4096

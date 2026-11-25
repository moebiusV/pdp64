; 6.15 example 2: the trap bits that keep one guest from timing its neighbours are set after reset; a hypervisor that gives a guest a core of its own clears them.
; Assembled only (the reset value of HTRAP is a rule of the new text; the first form of the implementation resets it to WFE and SEV only).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	mfsr	r1, htrap
	movq	=((1<<HTRAP_ICINV)|(1<<HTRAP_TLBIA)|(1<<HTRAP_TLBSYNC)), r2
	bic	r2, r1				; this guest owns its core: its invalidates are its own
	mtsr	htrap, r1

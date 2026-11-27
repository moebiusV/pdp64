; 6.15 example 5: the timer registers.  Assembled only: TIME and TIMECMP are new.
	.text
	.globl	_start
_start:
	mfsr	r1, time			; the guest's time: the real counter minus VTOFF
	add	$3000, r1
	mtsr	timecmp, r1			; the guest's own deadline; no exit
	mov	$0, r1
	mtsr	timecmp, r1			; zero means never

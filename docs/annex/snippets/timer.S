; The timer: arm, tick, disarm.
	.text
	.globl	_start
_start:
	mfsr	r1, time			; arm from now: read, add, write
	add	#100000, r1			; 100000 ticks of 100 ns: 10 ms
	mtsr	timecmp, r1
tick:	mfsr	r1, timecmp			; the handler of a periodic tick: the old deadline plus the period
	add	#100000, r1			; (never "now plus the period": that drifts)
	mtsr	timecmp, r1
	movq	#0, r1				; nothing to wait for (idle): zero means never
	mtsr	timecmp, r1

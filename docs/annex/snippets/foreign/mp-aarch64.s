// message passing on Arm: the barriers are those of OpenBSD's membar_producer() and membar_consumer() (sys/arch/arm64/include/atomic.h)
	str	x1, [x2]		// writer: the data
	dmb	st			// membar_producer()
	str	x3, [x4]		// writer: the flag
	ldr	x5, [x4]		// reader: the flag
	dmb	ld			// membar_consumer()
	ldr	x6, [x2]		// reader: the data

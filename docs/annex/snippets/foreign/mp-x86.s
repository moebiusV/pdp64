# the same on x86-64: membar_producer() and membar_consumer() are empty there (sys/arch/amd64/include/atomic.h)
	movq	%rsi, (%rdx)
	movq	%rcx, (%r8)
	movq	(%r8), %r9
	movq	(%rdx), %r10

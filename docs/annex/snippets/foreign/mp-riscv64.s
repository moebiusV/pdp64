# the same on RISC-V: OpenBSD's membar_producer() and membar_consumer() (sys/arch/riscv64/include/atomic.h)
	sd	a1, 0(a2)
	fence	w,w
	sd	a3, 0(a4)
	ld	a5, 0(a4)
	fence	r,r
	ld	a6, 0(a2)

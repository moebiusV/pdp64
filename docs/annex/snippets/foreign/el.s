	msr	ttbr0_el1, x0		// what an operating system's code writes
	msr	ttbr0_el2, x0		// what the same code writes when it runs at the hypervisor level
	msr	ttbr0_el12, x0		// what a host kernel's hypervisor half writes to reach the guest's

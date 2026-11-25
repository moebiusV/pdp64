	.text
	rti #0
	rti #0xffffffff
	rti #0x12345678
	rtt #0
	rtt #0xffffffff
	genter #0
	genter #0x12345678
	tlbias r0
	tlbias r31
	tlbigp r0
	tlbigp r5
	tlbi r5
	syspg0
	syspg1
	syspg2

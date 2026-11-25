; 6.15 example 7: at the hypervisor level the plain names are the hypervisor's own; the guest's registers have a G in front.  DP is reached by MFDP and MTDP.
; Assembled only: the G names are new.
	.text
	.globl	_start
_start:
	mfdp	r20				; the hypervisor's own per-core structure
	mfsr	r1, gptbr			; the guest's PTBR
	movq	r1, (r20)
	mfsr	r1, gvbr
	movq	r1, 8(r20)
	mfsr	r1, gkdp			; the guest's kernel-mode DP
	movq	r1, 16(r20)
	mtsr	ptbr, r2			; the hypervisor's own table base

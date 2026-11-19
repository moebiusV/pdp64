; The first software of the hypervisor mode (manual 6.14.10; errata 195, 196): a small hypervisor of our own and ONE guest kernel, on pdp64-virt,kernel-mode=on,hypervisor=on.
; Both are in this file.  The hypervisor boots at H = 1 (untranslated), builds its vector table and stage 2, sets the trap control (WFE, SEV and writes of PTBR are exits, the hypercall mask routes
; TRAP #224 to #255), the virtual core number, a virtual timer offset and the vector of virtual line 6, and enters the guest with GENTER.  The guest kernel (kernel mode, its own priority and vector
; table) builds its own page tables (stage 1) and turns translation on, reads its virtual core number, touches a page that stage 2 does not map yet (an exit: the hypervisor maps it and the store is
; retried), takes a virtual timer interrupt (the core's timer page is mapped into its stage 2), runs a user program that makes a system call (which must not exit) and prints through a
; hypercall (TRAP #224: a routed TRAP), and stops with HALT (an exit).  The hypervisor handles every exit and ends the machine.  Stage 2 puts guest-physical 2 to 4 MiB and the demand region at
; guest-physical + 32 MiB; the first 2 MiB (the image) are identity-mapped.  Output: the guest's text, then the hypervisor's line.
#include "pdp64-consts.h"
#define LEAF (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
#define VTIMER_VA (0xC0000000 + MAP_VTIMER - MAP_DEV)
	.text
	.globl	_start
_start:
	; ---- the hypervisor: vector table (an unexpected exit ends with 98), then the entries it handles
	lea	htab, r1
	mtsr	hvbr, r1
	lea	hbad, r2
	movq	#512, r3
fillh:	movq	r2, (r1)+
	sob	r3, fillh
	lea	hx, r2
	lea	htab+8*VECTOR_HEXIT, r1
	movq	r2, (r1)
	lea	hs, r2
	lea	htab+8*VECTOR_GIFAULT, r1
	movq	r2, (r1)
	movq	r2, 8(r1)
	movq	r2, 16(r1)
	lea	hx, r2
	lea	htab+8*(VECTOR_TRAP_BASE+224), r1
	movq	#32, r3
fillc:	movq	r2, (r1)+
	sob	r3, fillc
	; ---- stage 2: root (two pages) -> l1 -> 2 MiB leaves and the demand region; the device page of the virtual timer
	lea	hl1, r1
	bis	#(1<<PTE_V), r1
	movq	r1, hroot
	lea	hvl1, r1
	bis	#(1<<PTE_V), r1
	movq	r1, hroot+8*512		; guest-physical bit 39 (device space): root index 512
	movq	=(LEAF), r1
	movq	r1, hl1			; guest-physical 0 .. 2 MiB: the image, identity
	movq	=(0x2200000|LEAF), r1
	movq	r1, hl1+8		; 2 .. 4 MiB at + 32 MiB
	lea	hdl0, r1
	bis	#(1<<PTE_V), r1
	movq	r1, hl1+24		; 6 .. 8 MiB: the demand region, mapped by the hypervisor when the guest touches it
	lea	hvl0, r1
	bis	#(1<<PTE_V), r1
	movq	r1, hvl1
	movq	=(MAP_VTIMER|1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D|MT_DEVICE<<PTE_MT), r1
	movq	r1, hvl0+8*3		; the core's virtual timer page, at the same guest-physical address as the physical one
	lea	hroot, r1
	movq	=(1<<GTBR_S2EN|1<<GTBR_TAG), r2
	bis	r2, r1
	mtsr	gtbr, r1
	; ---- the trap control, the virtual core number, the virtual timer offset and the line of the timer
	movq	=((1<<HTRAP_WFE)|(1<<HTRAP_SEV)|(1<<HTRAP_PTBR)|(0x80<<HTRAP_MASK)), r1
	mtsr	htrap, r1
	movq	#7, r1
	mtsr	vcpuid, r1
	movq	=MAP_TIMER, r1
	movq	(r1), r2
	mtsr	vtoff, r2		; the guest's timer counts from about 0
	movq	=(0x60<<40), r1		; virtual line 6 -> vector 0x60
	mtsr	vivec, r1
	lea	gstk_top, r1
	mtsr	gksp, r1
	movq	#0, r10
	movq	#0, r11
	movq	#0, r12
	lea	gk, r1
	mtsr	hepc, r1
	movq	#0, r1
	mtsr	hepsw, r1
	movq	#99, r0			; a HALT of the guest that stops the machine with this status would be a bug
	genter
	; ---- the exits.  r10: hypercalls, r11: writes of PTBR, r12: stage-2 faults
hx:	mfsr	r20, hexitr
	cbeq	r20, #XCODE_HYPERCALL, hc
	cbeq	r20, #XCODE_PTBR, hp
	cbeq	r20, #XCODE_HALT, hh
	br	hbad
hc:	mfsr	r21, hcause		; TRAP #224: put the character in r0 on the console
	cbne	r21, #(VECTOR_TRAP_BASE+224), hbad
	movq	=MAP_CONSOLE, r22
	movq	r0, CONSOLE_REG_TXDB(r22)
	add	#1, r10
	genter
hp:	mtsr	ptbr, r1		; the guest's MTSR PTBR, r1: emulated (at H = 1 PTBR is the guest's register)
	tlbia
	add	#1, r11
	genter
hs:	mfsr	r20, hexitr		; a stage-2 fault: map the page of the demand region (physical = guest-physical + 32 MiB) and enter again
	cbne	r20, #XCODE_S2_INVALID, hbad
	mfsr	r21, hgpa
	movq	=0x600000, r22
	cbcs	r21, r22, hbad		; below the demand region
	movq	=0x800000, r22
	cbcc	r21, r22, hbad		; above it
	movq	=0xfffffffff000, r22
	and	r21, r22		; the page
	movq	r22, r23
	sub	#0x600000, r23
	shr	#12, r23
	shl	#3, r23
	lea	hdl0, r24
	add	r24, r23		; the entry
	movq	=0x2000000, r24
	add	r24, r22
	bis	#LEAF, r22
	movq	r22, (r23)
	tlbia
	add	#1, r12
	genter
hh:	cbeq	r10, #0, hbad		; the guest halted: it printed, wrote PTBR once, faulted once, took its tick and made the system calls
	cbeq	r11, #1, 1f
	movq	#2, r0
	halt
1:	cbeq	r12, #1, 1f
	movq	#3, r0
	halt
1:	movq	ticks, r1
	cbeq	r1, #1, 1f
	movq	#4, r0
	halt
1:	cbeq	r0, #0, 1f		; the guest's r0 is its status
	halt
1:	lea	hvmsg, r1
	movq	=MAP_CONSOLE, r22
2:	movzb	(r1)+, r0
	cbeq	r0, #0, 3f
	movq	r0, CONSOLE_REG_TXDB(r22)
	br	2b
3:	movq	#0, r0
	halt
hbad:	movq	#98, r0
	halt

	; ---------------------------------------------------------------------------------------------------------------- the guest kernel
gk:	lea	gvtab, r1
	mtsr	vbr, r1
	lea	g_bad, r2
	movq	#512, r3
fillg:	movq	r2, (r1)+
	sob	r3, fillg
	lea	g_sys, r2
	lea	gvtab+8*(VECTOR_TRAP_BASE+1), r1
	movq	r2, (r1)
	lea	g_exit, r2
	lea	gvtab+8*(VECTOR_TRAP_BASE+0), r1
	movq	r2, (r1)
	lea	g_tick, r2
	lea	gvtab+8*0x60, r1
	movq	r2, (r1)
	lea	msg1, r1
	call	puts
	mfcpuid	r1			; the virtual core number: the hardware gives it, no exit
	cbeq	r1, #7, 1f
	movq	#10, r0
	halt
1:	; the guest's own page tables (guest-physical = the image): 1 GiB identity for the kernel, a user alias of it, device space for the timer page
	movq	=(LEAF), r1
	movq	r1, gpt_root
	movq	=(LEAF|1<<PTE_U), r1
	movq	r1, gpt_root+16
	movq	=(MAP_DEV|1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D|MT_DEVICE<<PTE_MT), r1
	movq	r1, gpt_root+24
	lea	gpt_root, r1
	mtsr	ptbr, r1		; trapped by the hypervisor (HTRAP bit PTBR): emulated, the write is made at H = 1
	movq	#1, r1
	mtsr	mmuctl, r1		; not trapped
	isync
	; a page that stage 2 does not map: the store exits, the hypervisor maps it, the store is retried
	movq	=0x600008, r13
	movq	=0x1234, r1
	movq	r1, (r13)
	movq	(r13), r2
	cbeq	r2, r1, 1f
	movq	#11, r0
	halt
1:	lea	msg2, r1
	call	puts
	; the virtual timer: its page is in the guest's stage 2; priority 0, so line 6 is taken
	movq	=VTIMER_VA, r13
	movq	(r13), r1		; the counter, about 0
	add	#3000, r1
	movq	r1, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	spl	#0
2:	movq	ticks, r3
	cbeq	r3, #0, 2b
	lea	msg3, r1
	call	puts
	; to user mode: the user alias of the image, a user stack, priority 0
	lea	user, r1
	movq	=0x80000000, r2
	add	r2, r1
	mtsr	epc, r1
	lea	ustk_top, r1
	add	r2, r1
	mtsr	usp, r1
	movq	#(MODE_USER<<PSW_MODE|MODE_USER<<PSW_PREV), r1
	mtsr	epsw, r1
	rti
puts:	movzb	(r1)+, r0		; r1: the string, to the console by hypercall (a routed TRAP: no vector of the guest is taken)
	cbeq	r0, #0, 3f
	trap	#224
	br	puts
3:	ret
g_sys:	stua				; system call 1: write(r1 = user buffer, r2 = length); the user's page is read with UA set; no exit happens here
1:	movzb	(r1)+, r0
	trap	#224
	sob	r2, 1b
	clua
	rti
g_exit:	lea	msg5, r1
	call	puts
	movq	#0, r0
	halt				; the guest stops: an exit with code HALT
g_tick:	movq	=VTIMER_VA, r20		; the virtual timer's interrupt (vector 0x60): stop the timer, count
	movq	#0, r21
	movq	r21, TIMER_REG_CONTROL(r20)
	movq	ticks, r21
	add	#1, r21
	movq	r21, ticks
	rti
g_bad:	movq	#77, r0
	halt
user:	lea	msg4, r1		; the user program, at the alias address (lea is relative to the PC, so this is the alias address of the text): it writes a line and exits
	movq	#(msg4_end - msg4), r2
	trap	#1
	trap	#0
msg1:	.ascii	"guest kernel up\n"
	.byte	0
msg2:	.ascii	"demand page ok\n"
	.byte	0
msg3:	.ascii	"virtual timer ok\n"
	.byte	0
msg4:	.ascii	"hello from user\n"
msg4_end:
msg5:	.ascii	"guest stops\n"
	.byte	0
hvmsg:	.ascii	"hypervisor: guest halted\n"
	.byte	0
	.data
	.align	8
ticks:	.quad	0
	.align	4096
htab:	.space	4096
gvtab:	.space	4096
gpt_root:	.space	4096
	.align	8192
hroot:	.space	8192
hl1:	.space	4096
hdl0:	.space	4096
hvl1:	.space	4096
hvl0:	.space	4096
	.space	512
ustk_top:
	.space	1024
gstk_top:

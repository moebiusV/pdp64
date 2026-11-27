; PCI Express host bridge of the kernel-mode machine (errata 194): a kernel-mode program reads the configuration space through the ECAM window (the address is MAP_PCIE_ECAM + (bus << 20 | device << 15 | function << 12 | register)).
; Bus 0, device 0 is the host bridge itself (vendor 0x1b36, device 0x0008, class host bridge 0x0600); an empty position reads all ones (manual 2.4.7); a position beyond the ECAM window is a bus fault
; (not tested here).  The configuration window takes 32-bit accesses.  Failure: halt with the number of the check in r0.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	mov	=MAP_PCIE_ECAM, r13
	mov	=0xffffffff, r12
	mov.u32	(r13), r1 ; bus 0, device 0, function 0: vendor and device
	mov	=0x00081b36, r2
	cbeq r1, r2, 1f
	mov	$1, r0
	halt
1:
	mov.u32	8(r13), r1 ; revision and class code: the class (bits 31 to 16) is 0x0600, a host bridge
	shr	$16, r1
	cbeq r1, $0x0600, 1f
	mov	$2, r0
	halt
1:
	mov.u32	12(r13), r1 ; header type (bits 23 to 16): 0, a normal function
	shr	$16, r1
	and	$0x7f, r1
	cbeq	r1, $0, 1f
	mov	$3, r0
	halt
1:
	; an empty position reads all ones: devices 1 to 31 of bus 0 (there is no function in this test: the machine has none unless the command line adds it)
	mov	$1, r5
2:	mov	r5, r6
	shl	$15, r6
	add	r13, r6
	mov.u32	(r6), r1
	cbeq r1, r12, 1f
	mov	$4, r0
	halt
1:	add	$1, r5
	cblo r5, $32, 2b
	; the root bus has no devices on bus 1: all ones too
	mov	=0x100000, r6
	add	r13, r6
	mov.u32	(r6), r1
	cbeq r1, r12, 1f
	mov	$5, r0
	halt
1:
	mov	$0, r0
	halt

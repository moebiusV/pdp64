; The DMA test function (qemu/hw-pdp64/dmatest.c, -device pdp64-dmatest,addr=2) and enumeration (errata 194).  A kernel-mode program with translation off:
;   (1) finds the function by reading the vendor and device identifiers of every position of bus 0 through the ECAM window;
;   (2) sizes its base address register (a 64-bit memory register of 8 KiB), assigns it an address in the PCI Express memory window, enables memory space and bus mastering;
;   (3) reads its ID register, writes and reads back its own buffer through the window;
;   (4) runs a DMA write (buffer to RAM) and a DMA read (RAM to buffer) and sees the data;
;   (5) takes the function's interrupt: pin A of device 2 is routed to pin C (the swizzle, (pin + device) mod 4), vector VECTOR_PCIE_INTC, level IRQ_LEVEL_PCIE.
; The IOMMU of the root complex is blocked at reset (2.11.1): before the DMA the program gives the function an identity mapping of the first gigabyte, one level-A table
; of three levels with a single 1 GB leaf (the tests iommu-*.S test the unit itself).
; Failure: halt with the number of the check in r0.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	=MAP_PCIE_ECAM, r13
	movq	=0xffffffff, r12
	; (1) find the function: the first position of bus 0 whose identifier register is device << 16 | vendor
	movq	#1, r5
	movq	=((DMATEST_ID_DEVICE<<16)|DMATEST_ID_VENDOR), r4
2:	movq	r5, r6
	shl	#15, r6
	add	r13, r6
	mov	(r6).u32, r1
	cbeq r1, r4, 1f
	add	#1, r5
	cblo r5, #32, 2b
	movq	#1, r0			; not found
	halt
1:	cbeq r5, #2, 1f
	movq	#2, r0
	halt
1:	movq	r6, r13			; r13: the function's configuration space
	; (2) the base address register: the low dword reads back the size mask and the type bits (64-bit memory), the high dword all ones
	movq	#-1, r1
	mov	r1, 16(r13).32
	mov	16(r13).u32, r1
	movq	=0xffffe004, r2
	cbeq r1, r2, 1f
	movq	#3, r0
	halt
1:	mov	r12, 20(r13).32
	mov	20(r13).u32, r1
	cbeq r1, r12, 1f
	movq	#4, r0
	halt
1:	movq	=MAP_PCIE_MMIO, r1	; the address: the low dword (the type bits stay), then the high dword
	mov	r1, 16(r13).32
	shr	#32, r1
	mov	r1, 20(r13).32
	movq	#6, r1			; memory space and bus master
	mov	r1, 4(r13).16
	mov	16(r13).u32, r1
	cbeq r1, #4, 1f
	movq	#5, r0
	halt
1:	mov	20(r13).u32, r1
	cbeq r1, #(MAP_PCIE_MMIO>>32), 1f
	movq	#6, r0
	halt
1:
	; (3) the registers
	movq	=MAP_PCIE_MMIO, r12
	movq	DMATEST_REG_ID(r12), r1
	movq	=DMATEST_ID_MAGIC, r2
	cbeq r1, r2, 1f
	movq	#7, r0
	halt
1:	movq	=0x0123456789abcdef, r2
	movq	=DMATEST_MAP_BUFFER, r3
	add	r12, r3			; r3: the function's buffer
	movq	r2, (r3)
	movq	r2, 56(r3)
	movq	(r3), r1
	cbeq r1, r2, 1f
	movq	#8, r0
	halt
1:	movq	56(r3), r1
	cbeq r1, r2, 1f
	movq	#9, r0
	halt
1:	movq	#77, r1
	movq	r1, DMATEST_REG_LEN(r12)
	movq	DMATEST_REG_LEN(r12), r1
	cbeq r1, #77, 1f
	movq	#10, r0
	halt
1:
	; the IOMMU: the device entry of requester identity 0x10 (bus 0, device 2): V, stage A, three levels, root idp; the directory entry points to the leaf page; two-level mode
	movq	=MAP_IOMMU, r11
	movq	#(1<<PTE_V|1<<PTE_R|1<<PTE_W), r1
	lea	idp, r2
	movq	r1, (r2)
	movq	=((1<<IOMMU_DTE_V)|(IOMMU_STAGES_A<<IOMMU_DTE_STAGES)|(3<<IOMMU_DTE_LEVELS_A)), r1
	lea	leafp, r2
	movq	r1, 512(r2)		; the entry of index 0x10, 32 bytes each
	lea	idp, r1
	movq	r1, 520(r2)
	lea	leafp, r1
	bis	#(1<<IOMMU_DIR_V), r1
	lea	dirp, r2
	movq	r1, (r2)
	lea	dirp, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	movq	r1, IOMMU_REG_DEVICE(r11)
	; (4) a DMA write: eight quadwords of the buffer to RAM at `dest`; then a DMA read of `src` into the buffer
	movq	=0x0101010101010101, r11
	movq	#0, r10			; the interrupt count
	movq	#0, r9
	lea	dest, r1
	movq	r1, DMATEST_REG_DST(r12)
	movq	#64, r1
	movq	r1, DMATEST_REG_LEN(r12)
	movq	#8, r6
	movq	r3, r7
	movq	=0x1111111111111111, r2
3:	movq	r2, (r7)+
	add	r11, r2				; 8 different quadwords
	sub	#1, r6
	cbne	r6, #0, 3b
	movq	#((1<<DMATEST_CTL_START)|(1<<DMATEST_CTL_WRITE)), r1
	movq	r1, DMATEST_REG_CONTROL(r12)
	movq	DMATEST_REG_STATUS(r12), r1
	cbeq r1, #(1<<DMATEST_STATUS_DONE), 1f
	movq	#11, r0
	halt
1:	lea	dest, r8
	movq	=0x1111111111111111, r2
	movq	#8, r6
3:	movq	(r8)+, r1
	cbeq r1, r2, 1f
	movq	#12, r0			; the data did not arrive
	halt
1:	add	r11, r2
	sub	#1, r6
	cbne	r6, #0, 3b
	movq	#(1<<DMATEST_STATUS_DONE), r1
	movq	r1, DMATEST_REG_STATUS(r12)	; write one to clear
	movq	DMATEST_REG_STATUS(r12), r1
	cbeq r1, #0, 1f
	movq	#13, r0
	halt
1:	; a DMA read: clear the buffer, read 32 bytes from `src` (four quadwords of a pattern)
	movq	#8, r6
	movq	r3, r7
3:	movq	#0, r1
	movq	r1, (r7)+
	sub	#1, r6
	cbne	r6, #0, 3b
	lea	src, r1
	movq	r1, DMATEST_REG_SRC(r12)
	movq	#32, r1
	movq	r1, DMATEST_REG_LEN(r12)
	movq	#(1<<DMATEST_CTL_START), r1
	movq	r1, DMATEST_REG_CONTROL(r12)
	movq	DMATEST_REG_STATUS(r12), r1
	cbeq r1, #(1<<DMATEST_STATUS_DONE), 1f
	movq	#14, r0
	halt
1:	movq	DMATEST_REG_RESULT(r12), r1
	cbeq r1, #0, 1f
	movq	#15, r0
	halt
1:	movq	(r3), r1
	movq	=0xa0a1a2a3a4a5a6a7, r2
	cbeq r1, r2, 1f
	movq	#16, r0
	halt
1:	movq	24(r3), r1
	movq	=0xb8b9babbbcbdbebf, r2
	cbeq r1, r2, 1f
	movq	#17, r0
	halt
1:	movq	32(r3), r1		; beyond the length: unchanged
	cbeq r1, #0, 1f
	movq	#18, r0
	halt
1:	movq	#(1<<DMATEST_STATUS_DONE), r1
	movq	r1, DMATEST_REG_STATUS(r12)
	; (5) the interrupt: enable it and run a transfer
	movq	#(1<<DMATEST_IRQ_ENABLE), r1
	movq	r1, DMATEST_REG_IRQ(r12)
	spl	#IRQ_LEVEL_PCIE
	movq	#(1<<DMATEST_CTL_START), r1
	movq	r1, DMATEST_REG_CONTROL(r12)
	nop
	nop
	cbeq r10, #0, 1f
	movq	#19, r0			; taken at the level of the line: it must be masked
	halt
1:	spl	#0
	nop
	nop
	cbeq r10, #1, 1f
	movq	#20, r0
	halt
1:	cbeq r8, #VECTOR_PCIE_INTC, 1f
	movq	#21, r0
	halt
1:	movq	#0, r0
	halt
h_intc:	movq	#VECTOR_PCIE_INTC, r8
	add	#1, r10
	movq	#0, r9
	movq	r9, DMATEST_REG_IRQ(r12)	; the handler turns the interrupt off (the line stays up while done is set and enable is set)
	movq	#(1<<DMATEST_STATUS_DONE), r9
	movq	r9, DMATEST_REG_STATUS(r12)
	rti	#RTIMASK_ALL
	.data
	.align	8
vtab:
	.space	256
	.quad	0			; 32: timer
	.quad	0			; 33: console in
	.quad	0			; 34: console out
	.quad	0			; 35: pin A
	.quad	0			; 36: pin B
	.quad	h_intc			; 37: pin C
	.space	3792
	.align	4096
dirp:	.space	4096
leafp:	.space	4096
idp:	.space	4096
dest:	.space	64
src:	.quad	0xa0a1a2a3a4a5a6a7, 0xa8a9aaabacadaeaf, 0xb0b1b2b3b4b5b6b7, 0xb8b9babbbcbdbebf

; (a) A kernel-mode program enumerates the host bridge and finds the DMA test function (pcie-enum and pcie-dmatest do it step by step) and the IOMMU's register block
; (errata 194; manual 2.11.10): the identification, the capabilities, the reset values of every register ("blocked at reset": the device-table mode is zero, the control
; register is zero, nothing is cached), the read-only registers that a write does not change, and the registers that hold what is written.  Failure: halt with the check number.
#include "iommu-lib.h"
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	; the identification: the version in bits 16 to 31, the unit type in bits 0 to 15
	movq	IOMMU_REG_ID(r11), r1
	movq	=((IOMMU_ID_VERSION<<IOMMU_ID_FIELD_VERSION)|(IOMMU_ID_TYPE<<IOMMU_ID_FIELD_TYPE)), r2
	cmp	r1, r2
	beq	1f
	movq	#1, r0
	halt
1:	movq	IOMMU_REG_CAPS(r11), r1
	movq	=((IOMMU_CAPS_VALUE_MAX_LEVELS<<IOMMU_CAPS_MAX_LEVELS)|(IOMMU_CAPS_VALUE_PA_BITS<<IOMMU_CAPS_PA_BITS)|(IOMMU_CAPS_VALUE_TAG_BITS<<IOMMU_CAPS_TAG_BITS)|(1<<IOMMU_CAPS_STAGE_B)|(1<<IOMMU_CAPS_NESTED)), r2
	cmp	r1, r2
	beq	1f
	movq	#2, r0
	halt
1:	movq	IOMMU_REG_IRQ(r11), r1		; the interrupt: a wired line, its vector
	cmp	r1, #VECTOR_IOMMU
	beq	1f
	movq	#3, r0
	halt
1:
	; the reset values: every register is zero (the device-table mode is blocked) but the ID, the IRQ and the CAPS
	movq	#IOMMU_REG_CONTROL, r5
2:	cmp	r5, #IOMMU_REG_IRQ
	beq	3f
	cmp	r5, #IOMMU_REG_CAPS
	beq	3f
	cmp	r5, #IOMMU_REG_INV1
	beq	3f			; INV1 is write only: it reads zero too, but it is not a state
	add	r11, r5
	movq	(r5), r1
	sub	r11, r5
	cmp	r1, #0
	beq	3f
	movq	#4, r0			; a register does not read zero after reset
	halt
3:	add	#8, r5
	cmp	r5, #(IOMMU_REG_DROPPED_WRITES+8)
	blo	2b
	; the read-only registers ignore a write: ID, IRQ, CAPS, CMD_HEAD, FAULT_TAIL and the two counts
	movq	#-1, r1
	movq	r1, IOMMU_REG_ID(r11)
	movq	r1, IOMMU_REG_IRQ(r11)
	movq	r1, IOMMU_REG_CAPS(r11)
	movq	r1, IOMMU_REG_CMD_HEAD(r11)
	movq	r1, IOMMU_REG_FAULT_TAIL(r11)
	movq	r1, IOMMU_REG_REFUSED_READS(r11)
	movq	r1, IOMMU_REG_DROPPED_WRITES(r11)
	movq	IOMMU_REG_ID(r11), r1
	movq	=((IOMMU_ID_VERSION<<IOMMU_ID_FIELD_VERSION)|(IOMMU_ID_TYPE<<IOMMU_ID_FIELD_TYPE)), r2
	cmp	r1, r2
	beq	1f
	movq	#5, r0
	halt
1:	movq	IOMMU_REG_IRQ(r11), r1
	cmp	r1, #VECTOR_IOMMU
	beq	1f
	movq	#6, r0
	halt
1:	movq	IOMMU_REG_CMD_HEAD(r11), r1
	movq	IOMMU_REG_FAULT_TAIL(r11), r2
	bis	r2, r1
	movq	IOMMU_REG_REFUSED_READS(r11), r2
	bis	r2, r1
	movq	IOMMU_REG_DROPPED_WRITES(r11), r2
	bis	r2, r1
	cmp	r1, #0
	beq	1f
	movq	#7, r0
	halt
1:	; registers that hold what is written: page-aligned bases lose the low bits; CONTROL keeps its three bits and the reset bit reads zero
	movq	=0x123456789, r1
	movq	r1, IOMMU_REG_RING_BASE(r11)
	movq	r1, IOMMU_REG_FAULT_BASE(r11)
	movq	IOMMU_REG_RING_BASE(r11), r2
	movq	=0x123456000, r3
	cmp	r2, r3
	beq	1f
	movq	#8, r0
	halt
1:	movq	IOMMU_REG_FAULT_BASE(r11), r2
	cmp	r2, r3
	beq	1f
	movq	#9, r0
	halt
1:	movq	#16, r1
	movq	r1, IOMMU_REG_RING_SIZE(r11)
	movq	r1, IOMMU_REG_FAULT_SIZE(r11)
	movq	IOMMU_REG_RING_SIZE(r11), r2
	cmp	r2, #16
	beq	1f
	movq	#10, r0
	halt
1:	movq	#(1<<IOMMU_CONTROL_RESET|1<<IOMMU_CONTROL_FAULT_ENABLE|1<<IOMMU_CONTROL_CMD_ENABLE), r1
	movq	r1, IOMMU_REG_CONTROL(r11)
	movq	IOMMU_REG_CONTROL(r11), r2
	cmp	r2, #(1<<IOMMU_CONTROL_FAULT_ENABLE|1<<IOMMU_CONTROL_CMD_ENABLE)
	beq	1f
	movq	#11, r0
	halt
1:	; the device-table pointer holds the mode and the page number only
	movq	=0xffffffffffffffff, r1
	movq	r1, IOMMU_REG_DEVICE(r11)
	movq	IOMMU_REG_DEVICE(r11), r2
	movq	r2, r3
	and	#((1<<IOMMU_DEVICE_WIDTH_MODE)-1), r3	; mode 3 does not exist: blocked, with the table-error bit set
	beq	1f
	movq	#12, r0
	halt
1:	movq	=((1<<PTE_WIDTH_PPN)-1), r4			; the page number: every bit of it is kept, and nothing else (bits 2 to 11 and 40 to 63 are zero)
	shl	#PTE_PPN, r4
	cmp	r2, r4
	beq	1f
	movq	#15, r0
	halt
1:	movq	IOMMU_REG_STATUS(r11), r2
	and	#(1<<IOMMU_STATUS_TABLE_ERROR), r2
	bne	1f
	movq	#13, r0
	halt
1:	movq	#(1<<IOMMU_STATUS_TABLE_ERROR), r1	; write one to clear
	movq	r1, IOMMU_REG_STATUS(r11)
	movq	IOMMU_REG_STATUS(r11), r2
	cmp	r2, #0
	beq	1f
	movq	#14, r0
	halt
1:	movq	#0, r0
	halt
#include "iommu-lib.inc"

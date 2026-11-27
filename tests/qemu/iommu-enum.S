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
	mov	IOMMU_REG_ID(r11), r1
	mov	=((IOMMU_ID_VERSION<<IOMMU_ID_FIELD_VERSION)|(IOMMU_ID_TYPE<<IOMMU_ID_FIELD_TYPE)), r2
	cbeq r1, r2, 1f
	mov	$1, r0
	halt
1:	mov	IOMMU_REG_CAPS(r11), r1
	mov	=((IOMMU_CAPS_VALUE_MAX_LEVELS<<IOMMU_CAPS_MAX_LEVELS)|(IOMMU_CAPS_VALUE_PA_BITS<<IOMMU_CAPS_PA_BITS)|(IOMMU_CAPS_VALUE_TAG_BITS<<IOMMU_CAPS_TAG_BITS)|(1<<IOMMU_CAPS_STAGE_B)|(1<<IOMMU_CAPS_NESTED)), r2
	cbeq r1, r2, 1f
	mov	$2, r0
	halt
1:	mov	IOMMU_REG_IRQ(r11), r1		; the interrupt: a wired line, its vector
	cbeq r1, $VECTOR_IOMMU, 1f
	mov	$3, r0
	halt
1:
	; the reset values: every register is zero (the device-table mode is blocked) but the ID, the IRQ and the CAPS
	mov	$IOMMU_REG_CONTROL, r5
2:	cbeq r5, $IOMMU_REG_IRQ, 3f
	cbeq r5, $IOMMU_REG_CAPS, 3f
	cbeq r5, $IOMMU_REG_INV1, 3f ; INV1 is write only: it reads zero too, but it is not a state
	add	r11, r5
	mov	(r5), r1
	sub	r11, r5
	cbeq r1, $0, 3f
	mov	$4, r0			; a register does not read zero after reset
	halt
3:	add	$8, r5
	cblo r5, $(IOMMU_REG_DROPPED_WRITES+8), 2b
	; the read-only registers ignore a write: ID, IRQ, CAPS, CMD_HEAD, FAULT_TAIL and the two counts
	mov	$-1, r1
	mov	r1, IOMMU_REG_ID(r11)
	mov	r1, IOMMU_REG_IRQ(r11)
	mov	r1, IOMMU_REG_CAPS(r11)
	mov	r1, IOMMU_REG_CMD_HEAD(r11)
	mov	r1, IOMMU_REG_FAULT_TAIL(r11)
	mov	r1, IOMMU_REG_REFUSED_READS(r11)
	mov	r1, IOMMU_REG_DROPPED_WRITES(r11)
	mov	IOMMU_REG_ID(r11), r1
	mov	=((IOMMU_ID_VERSION<<IOMMU_ID_FIELD_VERSION)|(IOMMU_ID_TYPE<<IOMMU_ID_FIELD_TYPE)), r2
	cbeq r1, r2, 1f
	mov	$5, r0
	halt
1:	mov	IOMMU_REG_IRQ(r11), r1
	cbeq r1, $VECTOR_IOMMU, 1f
	mov	$6, r0
	halt
1:	mov	IOMMU_REG_CMD_HEAD(r11), r1
	mov	IOMMU_REG_FAULT_TAIL(r11), r2
	bis	r2, r1
	mov	IOMMU_REG_REFUSED_READS(r11), r2
	bis	r2, r1
	mov	IOMMU_REG_DROPPED_WRITES(r11), r2
	bis	r2, r1
	cbeq r1, $0, 1f
	mov	$7, r0
	halt
1:	; registers that hold what is written: page-aligned bases lose the low bits; CONTROL keeps its three bits and the reset bit reads zero
	mov	=0x123456789, r1
	mov	r1, IOMMU_REG_RING_BASE(r11)
	mov	r1, IOMMU_REG_FAULT_BASE(r11)
	mov	IOMMU_REG_RING_BASE(r11), r2
	mov	=0x123456000, r3
	cbeq r2, r3, 1f
	mov	$8, r0
	halt
1:	mov	IOMMU_REG_FAULT_BASE(r11), r2
	cbeq r2, r3, 1f
	mov	$9, r0
	halt
1:	mov	$16, r1
	mov	r1, IOMMU_REG_RING_SIZE(r11)
	mov	r1, IOMMU_REG_FAULT_SIZE(r11)
	mov	IOMMU_REG_RING_SIZE(r11), r2
	cbeq r2, $16, 1f
	mov	$10, r0
	halt
1:	mov	$(1<<IOMMU_CONTROL_RESET|1<<IOMMU_CONTROL_FAULT_ENABLE|1<<IOMMU_CONTROL_CMD_ENABLE), r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	mov	IOMMU_REG_CONTROL(r11), r2
	cbeq r2, $(1<<IOMMU_CONTROL_FAULT_ENABLE|1<<IOMMU_CONTROL_CMD_ENABLE), 1f
	mov	$11, r0
	halt
1:	; the device-table pointer holds the mode and the page number only
	mov	=0xffffffffffffffff, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	IOMMU_REG_DEVICE(r11), r2
	mov	r2, r3
	and	$((1<<IOMMU_DEVICE_WIDTH_MODE)-1), r3	; mode 3 does not exist: blocked, with the table-error bit set
	cbeq	r3, $0, 1f
	mov	$12, r0
	halt
1:	mov	=((1<<PTE_WIDTH_PPN)-1), r4			; the page number: every bit of it is kept, and nothing else (bits 2 to 11 and 40 to 63 are zero)
	shl	$PTE_PPN, r4
	cbeq r2, r4, 1f
	mov	$15, r0
	halt
1:	mov	IOMMU_REG_STATUS(r11), r2
	and	$(1<<IOMMU_STATUS_TABLE_ERROR), r2
	cbne	r2, $0, 1f
	mov	$13, r0
	halt
1:	mov	$(1<<IOMMU_STATUS_TABLE_ERROR), r1	; write one to clear
	mov	r1, IOMMU_REG_STATUS(r11)
	mov	IOMMU_REG_STATUS(r11), r2
	cbeq r2, $0, 1f
	mov	$14, r0
	halt
1:	mov	$0, r0
	halt
#include "iommu-lib.inc"

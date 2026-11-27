; (b) Refusals (errata 194; manual 2.11.6, 2.11.3, 2.11.4).  With no mapping a DMA from the test function is refused: a read gets an error completion (the function reports
; error and a nonzero result and its buffer is left alone, never all ones), a posted write is dropped and counted (the function sees none of it); every refusal is logged in
; the fault ring with the right cause, stage, kind and device address, and the unit's interrupt is raised.  The cases: no device entry; an entry whose page is not mapped; a
; read-only mapping (a write is refused, a read goes through); a device address in another function's window (not mapped); the interrupt (taken only when the priority allows);
; a full fault ring (the records beyond it are lost, counted, the sticky overflow bit is set, nothing hangs; the next record carries the overflow bit); a muted device (counted,
; not logged); logging switched off (counted, not logged).  A machine check or a bus fault would halt the test (50, 51).  Failure: halt with the check number.
#include "iommu-lib.h"
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	call	lib_unit_up
	mov	#0, r30
	; the target pages hold a sentinel that a refused write must not change
	mov	=0x5a5a5a5a5a5a5a5a, r1
	lea	pg1, r2
	mov	r1, (r2)
	; ---- no device entry (V = 0): a write and a read are refused with the cause "no entry", stage "device table" ----
	mov	#0x1000, r1
	mov	#IOMMU_CAUSE_NO_ENTRY, r2
	mov	#11, r3
	mov	#IOMMU_STAGE_TABLE, r4
	mov	#1, r5
	call	lib_chk_ref
	mov	#0x1000, r1
	mov	#IOMMU_CAUSE_NO_ENTRY, r2
	mov	#12, r3
	mov	#IOMMU_STAGE_TABLE, r4
	mov	#0, r5
	call	lib_chk_ref
	; ---- the interrupt: a refused write with the priority at 7: the line is up (the status says the ring is not empty) but the interrupt is not taken; at priority 0 it is taken once ----
	mov	#0x1000, r1
	mov	#8, r2
	call	lib_dma_w
	cbeq r30, #0, 1f
	mov	#13, r0
	halt
1:	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_FAULT_PENDING), r1
	cbne	r1, #0, 1f
	mov	#14, r0
	halt
1:	spl	#0
	nop
	nop
	spl	#7
	cbeq r30, #1, 1f
	mov	#15, r0
	halt
1:	call	lib_drain
	mov	#CTL_ON, r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	mov	IOMMU_REG_STATUS(r11), r1
	cbeq r1, #0, 1f
	mov	#16, r0
	halt
1:	; ---- an entry for level A only (3 levels, root ts_a) with nothing mapped: "no mapping" at stage A ----
	lea	ts_a, r1
	call	lib_tbl_clear
	lea	ts_a, r1
	lea	ts_a, r5
	call	lib_tbl_init
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	#0x2000, r1
	mov	#IOMMU_CAUSE_NO_MAPPING, r2
	mov	#21, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#1, r5
	call	lib_chk_ref
	mov	#0x2000, r1
	mov	#IOMMU_CAUSE_NO_MAPPING, r2
	mov	#22, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#0, r5
	call	lib_chk_ref
	; ---- a read-only mapping of 0x1000 to pg1: a write is refused ("no write"), a read goes through ----
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg1, r3
	bis	#RL, r3
	call	lib_map
	mov	#0x1000, r1
	mov	#IOMMU_CAUSE_NO_WRITE, r2
	mov	#31, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#1, r5
	call	lib_chk_ref
	mov	#0x1000, r1
	lea	pg1, r2
	mov	#32, r3
	call	lib_chk_ok_r
	lea	pg1, r2
	mov	(r2), r1
	mov	=0x7172737475767778, r2		; the target of the refused write was not touched (the read check wrote this value there itself)
	cbeq r1, r2, 1f
	mov	#33, r0
	halt
1:	; ---- another function's window is an ordinary address: not mapped, so refused (2.3.5).  A four-level entry covers 48 bits; its root has no entry for this address ----
	lea	r4page, r1
	lea	ts_a, r2
	bis	#PTRL, r2
	mov	r2, (r1)
	mov	=DTE0(IOMMU_STAGES_A, 4, 0, 0, 0), r1
	lea	r4page, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	=(MAP_PCIE_MMIO+0x10000), r1
	mov	#IOMMU_CAUSE_NO_MAPPING, r2
	mov	#41, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#1, r5
	call	lib_chk_ref
	mov	=(MAP_PCIE_MMIO+0x10000), r1
	mov	#IOMMU_CAUSE_NO_MAPPING, r2
	mov	#42, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#0, r5
	call	lib_chk_ref
	; (the same address with the three-level entry is outside the 39 bits it covers: the cause is "range")
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	=(MAP_PCIE_MMIO+0x10000), r1
	mov	#IOMMU_CAUSE_RANGE, r2
	mov	#43, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#1, r5
	call	lib_chk_ref
	; ---- a full fault ring: the ring of four records holds three; five refusals: tail 3, two lost, the sticky bit, the count, no hang ----
	mov	#4, r1
	mov	r1, IOMMU_REG_FAULT_SIZE(r11)
	mov	#5, r6
	mov	#0x2000, r1
1:	mov	#8, r2
	call	lib_dma_w
	mov	#0x2000, r1
	sub	#1, r6
	cbne	r6, #0, 1b
	mov	IOMMU_REG_FAULT_TAIL(r11), r1
	cbeq r1, #3, 1f
	mov	#91, r0
	halt
1:	mov	IOMMU_REG_FAULT_DROPPED(r11), r1
	cbeq r1, #2, 1f
	mov	#92, r0
	halt
1:	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_OVERFLOW), r1
	cbne	r1, #0, 1f
	mov	#93, r0
	halt
1:	call	lib_drain
	mov	#0x2000, r1					; a record after the loss carries the overflow bit
	mov	#8, r2
	call	lib_dma_w
	call	lib_lastrec
	shr	#63, r1
	cbeq r1, #1, 1f
	mov	#94, r0
	halt
1:	mov	#0, r1						; the kernel clears the count and the sticky bit
	mov	r1, IOMMU_REG_FAULT_DROPPED(r11)
	mov	#(1<<IOMMU_STATUS_OVERFLOW), r1
	mov	r1, IOMMU_REG_STATUS(r11)
	call	lib_drain
	mov	IOMMU_REG_FAULT_DROPPED(r11), r1
	cbeq r1, #0, 1f
	mov	#95, r0
	halt
1:	mov	IOMMU_REG_STATUS(r11), r1
	cbeq r1, #0, 1f
	mov	#96, r0
	halt
1:	mov	#0x2000, r1
	mov	#8, r2
	call	lib_dma_w
	call	lib_lastrec
	shr	#63, r1
	cbeq r1, #0, 1f
	mov	#97, r0
	halt
1:	call	lib_drain
	mov	#16, r1
	mov	r1, IOMMU_REG_FAULT_SIZE(r11)
	; ---- a muted device: the refusal is counted, not logged ----
	mov	=(DTE0(IOMMU_STAGES_A, 3, 0, 0, 0)|(1<<IOMMU_DTE_MUTE)), r1
	lea	ts_a, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	IOMMU_REG_DROPPED_WRITES(r11), r20
	mov	IOMMU_REG_FAULT_TAIL(r11), r21
	mov	#0x2000, r1
	mov	#8, r2
	call	lib_dma_w
	cbeq r1, #ST_DONE, 1f
	mov	#61, r0
	halt
1:	mov	IOMMU_REG_DROPPED_WRITES(r11), r1
	sub	r20, r1
	cbeq r1, #1, 1f
	mov	#62, r0
	halt
1:	mov	IOMMU_REG_FAULT_TAIL(r11), r1
	cbeq r1, r21, 1f
	mov	#63, r0
	halt
1:	; ---- logging switched off: the same ----
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#(1<<IOMMU_CONTROL_CMD_ENABLE), r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	mov	IOMMU_REG_REFUSED_READS(r11), r20
	mov	IOMMU_REG_FAULT_TAIL(r11), r21
	mov	#0x2000, r1
	mov	#8, r2
	call	lib_dma_r
	cbeq r1, #ST_ERR, 1f
	mov	#71, r0
	halt
1:	mov	IOMMU_REG_REFUSED_READS(r11), r1
	sub	r20, r1
	cbeq r1, #1, 1f
	mov	#72, r0
	halt
1:	mov	IOMMU_REG_FAULT_TAIL(r11), r1
	cbeq r1, r21, 1f
	mov	#73, r0
	halt
1:	mov	#CTL_ON, r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	; the entry logged again after the switch: one more record
	mov	#0x2000, r1
	mov	#IOMMU_CAUSE_NO_MAPPING, r2
	mov	#74, r3
	mov	#IOMMU_STAGE_A, r4
	mov	#1, r5
	call	lib_chk_ref
	mov	#0, r0
	halt
#include "iommu-lib.inc"

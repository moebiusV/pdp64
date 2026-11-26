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
	movq	#0, r30
	; the target pages hold a sentinel that a refused write must not change
	movq	=0x5a5a5a5a5a5a5a5a, r1
	lea	pg1, r2
	movq	r1, (r2)
	; ---- no device entry (V = 0): a write and a read are refused with the cause "no entry", stage "device table" ----
	movq	#0x1000, r1
	movq	#IOMMU_CAUSE_NO_ENTRY, r2
	movq	#11, r3
	movq	#IOMMU_STAGE_TABLE, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	#0x1000, r1
	movq	#IOMMU_CAUSE_NO_ENTRY, r2
	movq	#12, r3
	movq	#IOMMU_STAGE_TABLE, r4
	movq	#0, r5
	call	lib_chk_ref
	; ---- the interrupt: a refused write with the priority at 7: the line is up (the status says the ring is not empty) but the interrupt is not taken; at priority 0 it is taken once ----
	movq	#0x1000, r1
	movq	#8, r2
	call	lib_dma_w
	cbeq r30, #0, 1f
	movq	#13, r0
	halt
1:	movq	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_FAULT_PENDING), r1
	cbne	r1, #0, 1f
	movq	#14, r0
	halt
1:	spl	#0
	nop
	nop
	spl	#7
	cbeq r30, #1, 1f
	movq	#15, r0
	halt
1:	call	lib_drain
	movq	#CTL_ON, r1
	movq	r1, IOMMU_REG_CONTROL(r11)
	movq	IOMMU_REG_STATUS(r11), r1
	cbeq r1, #0, 1f
	movq	#16, r0
	halt
1:	; ---- an entry for level A only (3 levels, root ts_a) with nothing mapped: "no mapping" at stage A ----
	lea	ts_a, r1
	call	lib_tbl_clear
	lea	ts_a, r1
	lea	ts_a, r5
	call	lib_tbl_init
	movq	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	#0x2000, r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#21, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	#0x2000, r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#22, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#0, r5
	call	lib_chk_ref
	; ---- a read-only mapping of 0x1000 to pg1: a write is refused ("no write"), a read goes through ----
	lea	ts_a, r1
	movq	#0x1000, r2
	lea	pg1, r3
	bis	#RL, r3
	call	lib_map
	movq	#0x1000, r1
	movq	#IOMMU_CAUSE_NO_WRITE, r2
	movq	#31, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	#0x1000, r1
	lea	pg1, r2
	movq	#32, r3
	call	lib_chk_ok_r
	lea	pg1, r2
	movq	(r2), r1
	movq	=0x7172737475767778, r2		; the target of the refused write was not touched (the read check wrote this value there itself)
	cbeq r1, r2, 1f
	movq	#33, r0
	halt
1:	; ---- another function's window is an ordinary address: not mapped, so refused (2.3.5).  A four-level entry covers 48 bits; its root has no entry for this address ----
	lea	r4page, r1
	lea	ts_a, r2
	bis	#PTRL, r2
	movq	r2, (r1)
	movq	=DTE0(IOMMU_STAGES_A, 4, 0, 0, 0), r1
	lea	r4page, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	=(MAP_PCIE_MMIO+0x10000), r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#41, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	=(MAP_PCIE_MMIO+0x10000), r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#42, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#0, r5
	call	lib_chk_ref
	; (the same address with the three-level entry is outside the 39 bits it covers: the cause is "range")
	movq	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	=(MAP_PCIE_MMIO+0x10000), r1
	movq	#IOMMU_CAUSE_RANGE, r2
	movq	#43, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	; ---- a full fault ring: the ring of four records holds three; five refusals: tail 3, two lost, the sticky bit, the count, no hang ----
	movq	#4, r1
	movq	r1, IOMMU_REG_FAULT_SIZE(r11)
	movq	#5, r6
	movq	#0x2000, r1
1:	movq	#8, r2
	call	lib_dma_w
	movq	#0x2000, r1
	sub	#1, r6
	cbne	r6, #0, 1b
	movq	IOMMU_REG_FAULT_TAIL(r11), r1
	cbeq r1, #3, 1f
	movq	#91, r0
	halt
1:	movq	IOMMU_REG_FAULT_DROPPED(r11), r1
	cbeq r1, #2, 1f
	movq	#92, r0
	halt
1:	movq	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_OVERFLOW), r1
	cbne	r1, #0, 1f
	movq	#93, r0
	halt
1:	call	lib_drain
	movq	#0x2000, r1					; a record after the loss carries the overflow bit
	movq	#8, r2
	call	lib_dma_w
	call	lib_lastrec
	shr	#63, r1
	cbeq r1, #1, 1f
	movq	#94, r0
	halt
1:	movq	#0, r1						; the kernel clears the count and the sticky bit
	movq	r1, IOMMU_REG_FAULT_DROPPED(r11)
	movq	#(1<<IOMMU_STATUS_OVERFLOW), r1
	movq	r1, IOMMU_REG_STATUS(r11)
	call	lib_drain
	movq	IOMMU_REG_FAULT_DROPPED(r11), r1
	cbeq r1, #0, 1f
	movq	#95, r0
	halt
1:	movq	IOMMU_REG_STATUS(r11), r1
	cbeq r1, #0, 1f
	movq	#96, r0
	halt
1:	movq	#0x2000, r1
	movq	#8, r2
	call	lib_dma_w
	call	lib_lastrec
	shr	#63, r1
	cbeq r1, #0, 1f
	movq	#97, r0
	halt
1:	call	lib_drain
	movq	#16, r1
	movq	r1, IOMMU_REG_FAULT_SIZE(r11)
	; ---- a muted device: the refusal is counted, not logged ----
	movq	=(DTE0(IOMMU_STAGES_A, 3, 0, 0, 0)|(1<<IOMMU_DTE_MUTE)), r1
	lea	ts_a, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	IOMMU_REG_DROPPED_WRITES(r11), r20
	movq	IOMMU_REG_FAULT_TAIL(r11), r21
	movq	#0x2000, r1
	movq	#8, r2
	call	lib_dma_w
	cbeq r1, #ST_DONE, 1f
	movq	#61, r0
	halt
1:	movq	IOMMU_REG_DROPPED_WRITES(r11), r1
	sub	r20, r1
	cbeq r1, #1, 1f
	movq	#62, r0
	halt
1:	movq	IOMMU_REG_FAULT_TAIL(r11), r1
	cbeq r1, r21, 1f
	movq	#63, r0
	halt
1:	; ---- logging switched off: the same ----
	movq	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	#(1<<IOMMU_CONTROL_CMD_ENABLE), r1
	movq	r1, IOMMU_REG_CONTROL(r11)
	movq	IOMMU_REG_REFUSED_READS(r11), r20
	movq	IOMMU_REG_FAULT_TAIL(r11), r21
	movq	#0x2000, r1
	movq	#8, r2
	call	lib_dma_r
	cbeq r1, #ST_ERR, 1f
	movq	#71, r0
	halt
1:	movq	IOMMU_REG_REFUSED_READS(r11), r1
	sub	r20, r1
	cbeq r1, #1, 1f
	movq	#72, r0
	halt
1:	movq	IOMMU_REG_FAULT_TAIL(r11), r1
	cbeq r1, r21, 1f
	movq	#73, r0
	halt
1:	movq	#CTL_ON, r1
	movq	r1, IOMMU_REG_CONTROL(r11)
	; the entry logged again after the switch: one more record
	movq	#0x2000, r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#74, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	#0, r0
	halt
#include "iommu-lib.inc"

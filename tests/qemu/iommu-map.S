; (c) With a mapping the DMA works and the data arrives (errata 194; manual 2.11.3, 2.11.4).  A device entry for level A only: a 4 KB page (a write and a read, at an offset in the
; page); a 2 MB page at level 1; the number of levels (3, 4 and 5); A and D ignored (the entries here have both clear); and the leaf rules, each refused with the cause "bad entry
; in the page table" and nothing delivered: X, U, G, a memory type, bit 10, a bit of 40 to 63, W without R, a 2 MB page that is not aligned; a pointer where nothing is left to
; point to and an entry with V clear are "no mapping"; an address beyond what the levels cover is "range".  Failure: halt with the check number.
#include "iommu-lib.h"
#define BIG 0x800000			/* a 2 MB aligned region of RAM, far from the program */
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	call	lib_unit_up
	movq	#0, r30
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
	; ---- a 4 KB page: 0x1000 -> pg1, with the offset 0x10 and 0x18; A and D are clear ----
	lea	ts_a, r1
	movq	#0x1000, r2
	lea	pg1, r3
	bis	#RWL, r3
	call	lib_map
	movq	#0x1010, r1
	lea	pg1, r2
	add	#0x10, r2
	movq	#11, r3
	call	lib_chk_ok_w
	movq	#0x1018, r1
	lea	pg1, r2
	add	#0x18, r2
	movq	#12, r3
	call	lib_chk_ok_r
	; ---- a 2 MB page at level 1: 0x200000 -> BIG; an offset of 0x1234 ----
	lea	ts_a, r1
	movq	=0x200000, r2
	movq	=(BIG|RWL), r3
	call	lib_map_l1
	movq	=0x201238, r1
	movq	=(BIG+0x1238), r2
	movq	#21, r3
	call	lib_chk_ok_w
	movq	=0x3ff000, r1			; the last page of the large page
	movq	=(BIG+0x1ff000), r2
	movq	#22, r3
	call	lib_chk_ok_r
	; ---- four levels and five: the roots r4page, r5page point to the three-level block; the same address works ----
	lea	r4page, r1
	lea	ts_a, r2
	bis	#PTRL, r2
	movq	r2, (r1)
	lea	r5page, r1
	lea	r4page, r2
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
	movq	#0x1020, r1
	lea	pg1, r2
	add	#0x20, r2
	movq	#31, r3
	call	lib_chk_ok_w
	movq	=0x8000000000, r1		; bit 39: the second entry of the four-level root, not there: no mapping
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#32, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	=DTE0(IOMMU_STAGES_A, 5, 0, 0, 0), r1
	lea	r5page, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	#0x1028, r1
	lea	pg1, r2
	add	#0x28, r2
	movq	#33, r3
	call	lib_chk_ok_r
	movq	=0x8000000000, r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#34, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#0, r5
	call	lib_chk_ref
	movq	=0x1000000000000, r1		; bit 48: the second entry of the five-level root's next table (r4page), not there: no mapping
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#35, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	=0x200000000000000, r1		; bit 57: beyond the 57 bits of the five-level table: range
	movq	#IOMMU_CAUSE_RANGE, r2
	movq	#36, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	; back to three levels: an address of bit 39 is outside the 39 bits: range
	movq	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	ts_a, r2
	movq	#0, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	=0x8000000000, r1
	movq	#IOMMU_CAUSE_RANGE, r2
	movq	#37, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	; ---- the leaf rules.  Each bad leaf is made at 0x5000 (index 5 of the level-0 table) with the entry cleared again after; no invalidate is needed: a refused translation is not cached ----
	movq	#0, r28				; the case number
	lea	badleaf, r29
2:	movq	(r29), r3			; the flags of the case; 0 is the end
	cbeq r3, #0, 3f
	add	#8, r29
	add	#1, r28
	lea	pg1, r4
	bis	r4, r3				; the entry: the page of pg1 and the flags
	lea	ts_a, r1
	movq	#0x5000, r2
	call	lib_map
	movq	#0x5000, r1
	movq	#IOMMU_CAUSE_BAD_PTE, r2
	movq	r28, r3
	add	#130, r3				; the checks 131 to 140: a write, ...
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	#0x5000, r1
	movq	#IOMMU_CAUSE_BAD_PTE, r2
	movq	r28, r3
	add	#150, r3				; 151 to 160: and a read
	movq	#IOMMU_STAGE_A, r4
	movq	#0, r5
	call	lib_chk_ref
	br	2b
3:	; a pointer at level 0 and an entry with V clear are "no mapping"
	lea	ts_a, r1
	movq	#0x5000, r2
	lea	pg1, r3
	bis	#PTRL, r3
	call	lib_map
	movq	#0x5000, r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#81, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	lea	ts_a, r1
	movq	#0x5000, r2
	lea	pg1, r3
	bis	#(1<<PTE_R|1<<PTE_W), r3		; V clear
	call	lib_map
	movq	#0x5000, r1
	movq	#IOMMU_CAUSE_NO_MAPPING, r2
	movq	#82, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#0, r5
	call	lib_chk_ref
	; a 2 MB page that is not aligned (its page number has a bit below bit 21): bad entry
	lea	ts_a, r1
	movq	=0x400000, r2
	movq	=((BIG+0x1000)|RWL), r3
	call	lib_map_l1
	movq	=0x400000, r1
	movq	#IOMMU_CAUSE_BAD_PTE, r2
	movq	#83, r3
	movq	#IOMMU_STAGE_A, r4
	movq	#1, r5
	call	lib_chk_ref
	movq	#0, r0
	halt
	.data
	.align	8
; the flags of the bad leaves: X, U, G, memory type 1, bit 10, bit 45 (free in the processor's entry, unallocated here), W without R, X alone with R, V with the dirty bit and a reserved bit 11
badleaf:
	.quad	(RWL|(1<<PTE_X))
	.quad	(RWL|(1<<PTE_U))
	.quad	(RWL|(1<<PTE_G))
	.quad	(RWL|(1<<PTE_MT))
	.quad	(RWL|(1<<10))
	.quad	(RWL|(1<<11))
	.quad	(RWL|(1<<45))
	.quad	(RWL|(1<<63))
	.quad	((1<<PTE_V)|(1<<PTE_W))
	.quad	(RL|(1<<PTE_X))
	.quad	0
	.text
#include "iommu-lib.inc"

; (e) The guest-visible second level: a device assigned to a guest is translated in two levels, A (written by the guest: a device address to a guest-physical address) and then
; B (written by the hypervisor: guest-physical to physical) (errata 190; manual 2.11.2, 2.11.3).  The model has no hypervisor mode, so this program plays both roles: it writes
; the guest's level A and the hypervisor's level B.  The unit's nesting is what is tested, not the entry and exit of a guest nor the virtual unit.  Checks:
;   the composed translation (a write and a read reach the page that B gives to the guest-physical page that A gives);
;   the tables of level A sit at guest-physical addresses (0x100000 and up) whose host pages are NOT the identity: the walk succeeds only if every table pointer went through B;
;   a hole in A is reported as a level-A fault (stage A, the device address, the guest tag in the record), a hole in B as a level-B fault (stage B, the guest-physical address),
;   a read-only page in B refuses a write ("no write", stage B, the guest-physical address) and gives a read, a table of A that B does not map is a level-B fault on the address of
;   that table word;
;   level B only (stages = 2): the device address is a guest-physical address;
;   the guest reset sequence (the entry rewritten with V clear): the nested translation is stale until invalidate guest, and after it and sync nothing of the nested state is used;
;   two guests with the same level A (the same guest-physical addresses) and different level B reach different pages.
; Failure: halt with the check number.
#include "iommu-lib.h"
#define GA 0x100000			/* the guest-physical address of the guest's level-A tables (three pages) */
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	call	lib_pci_up2
	call	lib_unit_up
	movq	#0, r30
	lea	ts_a, r1			; the host address of the guest's tables is not the identity (else the test could not tell)
	movq	#GA, r2
	cbne r1, r2, 1f
	movq	#10, r0
	halt
1:	; level A: the guest's tables, at host ts_a, with pointers that hold guest-physical addresses (base GA)
	lea	ts_a, r1
	call	lib_tbl_clear
	lea	ts_a, r1
	movq	#GA, r5
	call	lib_tbl_init
	lea	ts_a, r1
	movq	#0x4000, r2
	movq	=(0x150000|RWL), r3
	call	lib_map				; 0x4000 -> guest-physical 0x150000
	lea	ts_a, r1
	movq	#0x6000, r2
	movq	=(0x160000|RWL), r3
	call	lib_map				; 0x6000 -> 0x160000 (not in B)
	lea	ts_a, r1
	movq	#0x7000, r2
	movq	=(0x170000|RWL), r3
	call	lib_map				; 0x7000 -> 0x170000 (read only in B)
	; level B: the hypervisor's table ts_b: the guest's table pages and the data pages
	lea	ts_b, r1
	call	lib_tbl_clear
	lea	ts_b, r1
	lea	ts_b, r5
	call	lib_tbl_init
	lea	ts_b, r1
	movq	=GA, r2
	lea	ts_a, r3
	call	lib_mappage
	lea	ts_b, r1
	movq	=(GA+0x1000), r2
	lea	ts_a, r3
	add	#4096, r3
	call	lib_mappage
	lea	ts_b, r1
	movq	=(GA+0x2000), r2
	lea	ts_a, r3
	add	#8192, r3
	call	lib_mappage
	lea	ts_b, r1
	movq	=0x150000, r2
	lea	pg2, r3
	call	lib_mappage
	lea	ts_b, r1
	movq	=0x170000, r2
	lea	pg3, r3
	bis	#RL, r3
	call	lib_map
	; the device entry: A then B, 3 levels each, domain 7, guest 1
	movq	=DTE0(IOMMU_STAGES_A_THEN_B, 3, 3, 7, 1), r1
	movq	=GA, r2
	lea	ts_b, r3
	movq	#RID1, r4
	call	lib_dte
	; ---- the composed translation ----
	movq	#0x4000, r1
	movq	#2, r2
	movq	#11, r3
	call	lib_expect			; pg2
	movq	#0x4008, r1
	lea	pg2, r2
	add	#8, r2
	movq	#12, r3
	call	lib_chk_ok_r
	; ---- a hole in A: stage A, the device address, the guest tag in the record ----
	movq	#0x5000, r1
	movq	#8, r2
	call	lib_dma_w
	movq	#IOMMU_CAUSE_NO_MAPPING, r1
	movq	#IOMMU_STAGE_A, r2
	movq	=(RID1|(1<<IOMMU_FAULT_WHO_GUEST)), r3
	movq	#0x5000, r4
	movq	#0, r5
	movq	#21, r6
	call	lib_chk_rec
	; ---- a hole in B: stage B, the guest-physical address ----
	movq	#0x6008, r1
	movq	#8, r2
	call	lib_dma_w
	movq	#IOMMU_CAUSE_NO_MAPPING, r1
	movq	#IOMMU_STAGE_B, r2
	movq	=(RID1|(1<<IOMMU_FAULT_WHO_GUEST)), r3
	movq	#0x6008, r4
	movq	=0x160008, r5
	movq	#31, r6
	call	lib_chk_rec
	; ---- a read-only page in B: a write is refused (stage B, "no write"), a read goes through ----
	movq	#0x7010, r1
	movq	#8, r2
	call	lib_dma_w
	movq	#IOMMU_CAUSE_NO_WRITE, r1
	movq	#IOMMU_STAGE_B, r2
	movq	=(RID1|(1<<IOMMU_FAULT_WHO_GUEST)), r3
	movq	#0x7010, r4
	movq	=0x170010, r5
	movq	#41, r6
	call	lib_chk_rec
	movq	#0x7018, r1
	lea	pg3, r2
	add	#0x18, r2
	movq	#42, r3
	call	lib_chk_ok_r
	; ---- a table of A that B does not map: the level-A walk reads l1[0] at guest-physical GA + 0x1000: B has no entry for it ----
	lea	ts_b, r1
	movq	=(GA+0x1000), r2
	movq	#0, r3
	call	lib_map
	movq	=0x8000, r1			; not cached
	movq	#8, r2
	call	lib_dma_w
	movq	#IOMMU_CAUSE_NO_MAPPING, r1
	movq	#IOMMU_STAGE_B, r2
	movq	=(RID1|(1<<IOMMU_FAULT_WHO_GUEST)), r3
	movq	=0x8000, r4
	movq	=(GA+0x1000), r5		; the guest-physical address of the table word (index 0 of the level-1 table)
	movq	#51, r6
	call	lib_chk_rec
	lea	ts_b, r1			; put it back
	movq	=(GA+0x1000), r2
	lea	ts_a, r3
	add	#4096, r3
	call	lib_mappage
	; ---- level B only: the device address is a guest-physical address ----
	movq	=DTE0(IOMMU_STAGES_B, 0, 3, 7, 1), r1
	movq	#0, r2
	lea	ts_b, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	=0x150000, r1
	movq	#2, r2
	movq	#61, r3
	call	lib_expect
	movq	=0x160010, r1
	movq	#8, r2
	call	lib_dma_w
	movq	#IOMMU_CAUSE_NO_MAPPING, r1
	movq	#IOMMU_STAGE_B, r2
	movq	=(RID1|(1<<IOMMU_FAULT_WHO_GUEST)), r3
	movq	=0x160010, r4
	movq	=0x160010, r5
	movq	#62, r6
	call	lib_chk_rec
	; ---- the guest reset sequence: nested again, cached; the entry is rewritten with V clear: stale until invalidate guest and sync ----
	movq	=DTE0(IOMMU_STAGES_A_THEN_B, 3, 3, 7, 1), r1
	movq	=GA, r2
	lea	ts_b, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	#0x4000, r1
	movq	#2, r2
	movq	#71, r3
	call	lib_expect			; cached, nested
	movq	#0, r1				; V clear
	movq	=GA, r2
	lea	ts_b, r3
	movq	#RID1, r4
	call	lib_dte
	movq	#0x4000, r1
	movq	#2, r2
	movq	#72, r3
	call	lib_expect			; stale: the nested translation is still used (a property of the model)
	movq	=CMD(IOMMU_OP_INV_GUEST, 0, 0, 1), r1
	movq	#0, r2
	call	lib_cmd
	movq	#0, r1
	movq	#73, r3
	call	lib_sync
	movq	#0x4000, r1
	movq	#0, r2
	movq	#74, r3
	call	lib_expect			; nothing of the nested state is used: refused
	movq	#0x4000, r1
	movq	#8, r2
	call	lib_dma_w
	movq	#IOMMU_CAUSE_NO_ENTRY, r1
	movq	#IOMMU_STAGE_TABLE, r2
	movq	=(RID1|(0<<IOMMU_FAULT_WHO_GUEST)), r3
	movq	#0x4000, r4
	movq	#0, r5
	movq	#75, r6
	call	lib_chk_rec
	; ---- two guests, the same level A (the same guest-physical addresses), different level B: function 1 uses ts_b (gpa 0x150000 -> pg2), function 2 uses ts_c (gpa 0x150000 -> pg3) ----
	lea	ts_c, r1
	call	lib_tbl_clear
	lea	ts_c, r1
	lea	ts_c, r5
	call	lib_tbl_init
	lea	ts_c, r1
	movq	=GA, r2
	lea	ts_a, r3
	call	lib_mappage
	lea	ts_c, r1
	movq	=(GA+0x1000), r2
	lea	ts_a, r3
	add	#4096, r3
	call	lib_mappage
	lea	ts_c, r1
	movq	=(GA+0x2000), r2
	lea	ts_a, r3
	add	#8192, r3
	call	lib_mappage
	lea	ts_c, r1
	movq	=0x150000, r2
	lea	pg3, r3
	call	lib_mappage
	movq	=DTE0(IOMMU_STAGES_A_THEN_B, 3, 3, 7, 1), r1
	movq	=GA, r2
	lea	ts_b, r3
	movq	#RID1, r4
	call	lib_dte
	movq	=DTE0(IOMMU_STAGES_A_THEN_B, 3, 3, 7, 2), r1
	movq	=GA, r2
	lea	ts_c, r3
	movq	#RID2, r4
	call	lib_dte
	movq	=CMD(IOMMU_OP_INV_ALL, 0, 0, 0), r1
	movq	#0, r2
	call	lib_cmd
	movq	#0x4000, r1
	movq	#2, r2
	movq	#81, r3
	call	lib_expect
	call	lib_swap12
	movq	#0x4000, r1
	movq	#4, r2
	movq	#82, r3
	call	lib_expect
	call	lib_swap12
	movq	#0, r0
	halt
#include "iommu-lib.inc"

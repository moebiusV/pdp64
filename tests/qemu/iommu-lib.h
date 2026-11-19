/* The macros of the IOMMU tests (errata 194): included at the top of a test; the routines and data are in iommu-lib.inc, included at the bottom.
   The numbers are the generated constants of pdp64-consts.h (spec/grammars.d/51-iommu-v1.hbnf). */
#include "pdp64-consts.h"

/* word 0 of a device entry: V, the stages, the levels of each stage, the domain tag and the guest tag */
#define DTE0(st, la, lb, dom, gst) ((1<<IOMMU_DTE_V)|((st)<<IOMMU_DTE_STAGES)|((la)<<IOMMU_DTE_LEVELS_A)|((lb)<<IOMMU_DTE_LEVELS_B)|((dom)<<IOMMU_DTE_DOMAIN)|((gst)<<IOMMU_DTE_GUEST))
/* a command: the operation, the requester identity, the domain tag and the guest tag */
#define CMD(op, rid, dom, gst) ((op)|((rid)<<IOMMU_CMD_RID)|((dom)<<IOMMU_CMD_DOMAIN)|((gst)<<IOMMU_CMD_GUEST))
/* the requester identities of the two test functions (bus 0, devices 2 and 3, function 0) */
#define RID1 0x10
#define RID2 0x18
/* page-table entries: V R W (A and D are ignored by the unit and left clear unless a test sets them); a pointer is V alone */
#define RWL (1<<PTE_V|1<<PTE_R|1<<PTE_W)
#define RL (1<<PTE_V|1<<PTE_R)
#define PTRL (1<<PTE_V)
/* the control word with everything on, and with the interrupt off (what the interrupt routine writes) */
#define CTL_ON ((1<<IOMMU_CONTROL_CMD_ENABLE)|(1<<IOMMU_CONTROL_FAULT_ENABLE)|(1<<IOMMU_CONTROL_FAULT_IRQ))
#define CTL_QUIET ((1<<IOMMU_CONTROL_CMD_ENABLE)|(1<<IOMMU_CONTROL_FAULT_ENABLE))
/* the status of a finished transfer, and of a finished transfer that failed */
#define ST_DONE (1<<DMATEST_STATUS_DONE)
#define ST_ERR ((1<<DMATEST_STATUS_DONE)|(1<<DMATEST_STATUS_ERROR))

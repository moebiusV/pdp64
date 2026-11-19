/* The meaning of the pdp64 instructions, shared by every executor (see pdp64exec.c). */
#ifndef PDP64EXEC_H
#define PDP64EXEC_H
#include <stdint.h>
#include "pdp64-consts.h"

/* The valid bits of the PSW (System v1: docs/pdp64-system-architecture.md section 15): the flags, T, the priority, the two modes and the user-access guard UA (bit 12); the rest is reserved, zero. */
#define PSW_FLAGS	((1u << PSW_C) | (1u << PSW_V) | (1u << PSW_Z) | (1u << PSW_N))
#define PSW_FIELD(name, v)	(((unsigned)(v) & ((1u << PSW_WIDTH_##name) - 1)) << PSW_##name)
#define PSW_VALID	(PSW_FLAGS | (1u << PSW_T) | PSW_FIELD(PRI, ~0u) | PSW_FIELD(MODE, ~0u) | PSW_FIELD(PREV, ~0u) | (1u << PSW_UA))

/* the instruction classes of the second cycle model of the vec blocks: each has a latency and an interval (cycles) that the host sets (sim64 --latency) */
enum { VC_ALU, VC_CMP, VC_BSL, VC_SHIFT, VC_NARROW, VC_MUL8, VC_MUL16, VC_MULH16, VC_MUL32, VC_MUL64, VC_DOT, VC_DACC, VC_SAD, VC_ACC, VC_MMACC, VC_FIR, VC_TBL, VC_LSEG, VC_SSEG, VC_CVT,
       VC_FMA, VC_FMA64, VC_LD, VC_ST, VC_MISC, VC_N };
const char *pdp64_vclass_name(int c);		/* "alu", "cmp", ... (docs/encoding-work/vec-latency.md) */

struct pdp64_cpu {
	uint64_t r[32], pc, dp, fpsr;
	int fN, fZ, fV, fC;				/* the flag bits of the PSW; the other bits are in `psw` */
	uint64_t cur_pc;			/* the instruction being executed (set by pdp64_step) */
	unsigned psw;				/* the PSW without the flags (bits 0 to 3 are always zero here): T, priority, current and previous mode.  Read and write it through pdp64_psw / pdp64_set_psw. */
	/* r[14] and dp are the current bank's copies; the other banks' are here, by bank index (kernel 0, supervisor 1, user 2, the hypervisor 3: errata 195, 196).  The current bank's slot is stale.
	   While H = 1 the current bank is 3 whatever the mode field of the status word says; the guest's three banks are then all in their slots. */
	uint64_t spbank[4], dpbank[4];
	/* the hypervisor mode (errata 195, 196; docs/encoding-work/hypervisor-design.md).  hve: the machine strap, set by the host (pdp64_set_hve); with it clear the machine is the machine without a hypervisor
	   and none of the rest exists.  h: the internal state bit H, 1 while the hypervisor runs (reset value with hve set), 0 for a guest.  Not in the status word.  The registers are the system registers 128 to 147. */
	int hve, h;
	uint64_t htrap, hexitr, hepc, hepsw, heva, hcause, hgpa, hinsn, hvbr, gtbr, virq, vivec, vtoff, vcpuid;
	/* a stage-2 fault (set by the host before it raises the abort, or when its vecread returns 2; design 1.6, 2.5): the exit code (XCODE_S2_INVALID or XCODE_S2_REFUSED; 0: no stage-2 fault), the flag bits of HEXITR (XFLAG_WALK, XFLAG_VEC) shifted in place, and the guest-physical address that failed */
	int vec_phys;				/* set while the executor reads the hypervisor's vector word (HVBR + 8 * HCAUSE): a physical address, not a guest-physical one */
	int s2_code;
	unsigned s2_flags;
	uint64_t s2_gpa;
	uint32_t cur_insn;			/* the first two parcels of the instruction being executed (parcel 0 in the high half; zero if it has one parcel): HINSN of an exit that it causes */
	/* the system registers that mfsr and mtsr reach (privileged: kernel mode).  eva, ecause and cpuid are read only for software; the exception entry writes eva and ecause. */
	uint64_t ptbr, epc, eva, ecause, dmw[2], epsw, vbr, mmuctl, asid, cpuid;
	/* what the host chooses */
	int deliver;				/* 1: faults, traps and interrupts are exceptions delivered through the vector table (the host unwinds with raise and calls pdp64_exception); 0: they end the program (fault) */
	int standin;				/* 1: trap #n is the host's system-call stand-in (env->trap) and halt is allowed in every mode, bpt is a fault */
	/* what the core reports */
	int wait;				/* wfe executed: the host stops running instructions until an interrupt is taken */
	int entered;				/* an exception was entered by this instruction */
	int progress;				/* the instruction in progress is a block operation: an abort keeps its register progress */
	int snap_valid;				/* an instruction is in progress (snap is its starting state); 0 for a fault before any instruction ran, e.g. in the translation of the fetch: EPC is then pc */
	/* the vec block (pdp64exec_vec.inc): hidden registers (not saved at a context switch), and the statistics the benchmarks read */
	uint8_t vr[16][64];			/* the vector registers v0..v15: storage for a strip of up to 64 bytes (the strip in use is vstrip, default 32) */
	uint16_t vacc;				/* the vector registers that vclr named accumulators: they keep their values from strip to strip */
	int uacc;				/* the memory operand of the move being run is accessed with user privilege (a .u move, 6.10.4): the host's memory functions read it; an exception entry sets bit 15 of ECAUSE and clears it */
	int vhidden;				/* the running block holds hidden accumulation: an abort discards it and restarts the block from its entry */
	uint64_t vblocks, vstrips, vops, velems;	/* blocks run, strips run, vector instructions executed (one for each strip), elements they worked on */
	int vstrip, vport, vcommit, vcommit_set;	/* set by the host (sim64 -S, -C): the strip in bytes (0: 32), the model's memory port in bytes a cycle (0: 16), the commit cost of a strip (used if vcommit_set; default 1) */
	uint64_t vcycles, vcyc_comp, vcyc_mem, vmemstrips;	/* the cycle model of the vec blocks (docs/sim64.md): cycles of the blocks (strips and vends), the strips' compute and memory-port cycles summed, strips bound by memory */
	/* the second cycle model (latencies from logic depth, docs/sim64.md and docs/encoding-work/vec-latency.md); off (vm2 = 0) unless the host sets it, then a counter only */
	int vm2, vpipe, vmemlat;			/* vm2: the model is on; strips in flight (1 to 16); the load-to-use latency of the memory system, cycles */
	int vlat[VC_N], vint[VC_N];			/* latency and initiation interval, cycles, of each instruction class (enum VC_*): set by the host */
	uint64_t v2cycles, v2hidden, v2sdep;		/* the model's cycles of the blocks (the vends included), blocks with a hidden accumulator, blocks whose strips depend through a scalar register */
	uint64_t v2n[VC_N];				/* the vector instructions run, by class */
	int vrow, vrow_set;				/* the 2D block (vec2, errata 176): the model's cost of the row advance, cycles a row (used if vrow_set; default 1: an ASSUMPTION, vec-2d.md) */
	uint64_t vrows, vskips, v2blocks;		/* rows run, vskip words decoded, vec2 blocks run */
	struct { uint64_t r[32], pc, dp, fpsr; int fN, fZ, fV, fC; } snap;	/* the state at the start of the instruction, for precise aborts (kept only when deliver is on) */
};

/* The host's side.  ld and st move 1, 2, 4 or 8 bytes, little-endian, and check alignment and mapping themselves; fault never returns. */
struct pdp64_env {
	uint64_t (*ld)(void *u, uint64_t addr, int size);
	void (*st)(void *u, uint64_t addr, int size, uint64_t value);
	void (*fault)(void *u, const char *what, uint64_t addr) __attribute__((noreturn));
	void (*trap)(void *u, int n);		/* trap #n (the stand-in) */
	void (*halt)(void *u);			/* halt */
	int (*probe)(void *u, uint64_t addr, int write, int mode);	/* prober, probew: may the code running in this mode (a MODE_ number) read (write) this address? 1 or 0, no fault */
	uint64_t (*fetch)(void *u, uint64_t addr);	/* one two-byte parcel of an instruction (an instruction fetch is not a data load for the page faults) */
	int (*vecread)(void *u, uint64_t paddr, uint64_t *value);	/* the 64-bit word at a physical address (of a guest: a guest-physical address, through stage 2), for the vector table; 1 if the bus refuses (a machine check), 2 if stage 2 refuses a guest (the host has set s2_code, s2_flags, s2_gpa) */
	void (*check)(void *u, uint64_t addr, int size, int write);	/* the checks of an access (alignment, mapping, permission) without the transfer: the same abort, or nothing; pushx and popx use it so that an abort has no effect */
	void (*tlb)(void *u, int op, uint64_t addr);	/* PDP64_TLB_*: tlbi (one page), tlbia, or a write to ptbr / asid / mmuctl */
	void (*raise)(void *u, int vector, uint64_t eva) __attribute__((noreturn));	/* deliver mode: the core has an abort; unwind to the main loop, which calls pdp64_exception(vector, eva) */
	void *u;
	void (*profile)(void *u, uint64_t pc, int nparcels, int cat);	/* optional (NULL: none): called for every instruction at decode, before it runs; cat is a PDP64_CAT_ number.  A block instruction is one. */
	void (*hv_event)(void *u, int what);	/* optional (NULL: none): the hypervisor wrote a register that a device of the host depends on (PDP64_HV_*) */
};
#define PDP64_HV_VTOFF 0	/* a write to VTOFF: the virtual timer's deadline moves (design 1.9) */
/* the categories of the profile (the same for all encodings): what an instruction is, by its operation and operand */
enum { PDP64_CAT_OTHER, PDP64_CAT_FRAME_LD, PDP64_CAT_FRAME_ST, PDP64_CAT_REGMOVE, PDP64_CAT_PUSHPOP, PDP64_CAT_MEMREF, PDP64_CAT_BRANCH, PDP64_CAT_CALL,
       PDP64_CAT_BLOCK, PDP64_CAT_FUSED, PDP64_CAT_LEA, PDP64_NCAT };
#define PDP64_CAT_NAMES { "other", "frame_load", "frame_store", "regmove", "pushpop", "memref", "branch", "call_ret_jmp", "block", "fused", "lea" }
#define PDP64_TLB_PAGE 0	/* tlbi: the page that contains addr, for the current ASID and the global entries */
#define PDP64_TLB_ALL 1		/* tlbia, or a write to ptbr, asid or mmuctl: discards the translations of the tag in GTBR (the guest's own at H = 0), design rules G-a, G-b, G-d */
#define PDP64_TLB_SYNC 2	/* isync and genter: the effect of the earlier writes is published; no cached translation of any tag is discarded (a host that keeps no cache of its own may flush) */
#define PDP64_TLB_GTBR 3	/* a write to GTBR that changes the root or the enable bit (rule G-c): discard every translation of the tag in the new value, passed as addr */

/* The space bit (errata 60): bit 39 of a 40-bit physical address is set for device space, clear for memory.  PROPOSED (errata 65): a leaf page-table entry must agree with
   it: a page in device space has memory type device or device-weak, a page of memory has cached or uncached; the walker makes any other combination a protection fault. */
static inline int pdp64_pte_space_ok(uint64_t pte)
{
	int device_page = (int)(((pte >> PTE_PPN) << 12) >> MAP_SPACE_BIT) & 1;
	unsigned mt = (unsigned)(pte >> PTE_MT) & ((1u << PTE_WIDTH_MT) - 1);
	return device_page == (mt == MT_DEVICE || mt == MT_DEVICE_WEAK);
}

static inline unsigned pdp64_mode(const struct pdp64_cpu *c) { return (c->psw >> PSW_MODE) & ((1u << PSW_WIDTH_MODE) - 1); }
static inline unsigned pdp64_priority(const struct pdp64_cpu *c) { return (c->psw >> PSW_PRI) & ((1u << PSW_WIDTH_PRI) - 1); }

int pdp64_insn_parcels(uint16_t parcel0);	/* the length in parcels of the instruction whose first parcel this is (0: an illegal pattern) */
void pdp64_init(void);				/* once, before the first step */
void pdp64_step(struct pdp64_cpu *c, const struct pdp64_env *e);

unsigned pdp64_psw(const struct pdp64_cpu *c);	/* the whole PSW: flags and the rest */
void pdp64_set_hve(struct pdp64_cpu *c, int hve);	/* the strap: with hve set the core starts at H = 1 with HTRAP at its reset value; call after the status word and before r[14] and dp are set */
void pdp64_set_h(struct pdp64_cpu *c, int h);	/* change H, switching the r14 and DP banks (the hypervisor's bank is 3) */
#define HTRAP_VALID	((((unsigned)1 << (HTRAP_STEP + 1)) - 1) | ((((unsigned)1 << HTRAP_WIDTH_MASK) - 1) << HTRAP_MASK))	/* the defined bits of HTRAP; the others read as zero and a write of a one is an illegal instruction */
#define GTBR_VALID	(((uint64_t)1 << GTBR_S2EN) | ((((uint64_t)1 << GTBR_WIDTH_ROOT) - 1) << GTBR_ROOT) | ((((uint64_t)1 << GTBR_WIDTH_TAG) - 1) << GTBR_TAG))
void pdp64_set_psw(struct pdp64_cpu *c, unsigned psw);	/* load a PSW (valid bits only), switching the r14 and DP banks if the mode changes; the mode must not be the reserved 2 */
/* an abort (the host unwound with raise, or a fault in a hook): undo the partial effects of the instruction in progress (if any) and enter the exception.  eva: the faulting address */
void pdp64_exception(struct pdp64_cpu *c, const struct pdp64_env *e, int vector, uint64_t eva);
/* an interrupt request of this level and vector, between two instructions: taken (1) if the level is above the priority, else not (0) */
int pdp64_interrupt(struct pdp64_cpu *c, const struct pdp64_env *e, int level, int vector);
/* the virtual interrupt lines (design 1.8).  A guest (hve set, H clear) takes the highest pending line above its priority between two instructions: the guest's own exception entry with the vector of the line,
   and the hardware clears the line.  A physical interrupt is looked at first (the host calls pdp64_interrupt before these).  A line whose vector field is below 32 is not deliverable (the model's rule). */
int pdp64_virq_pending(const struct pdp64_cpu *c);		/* 1: a guest is running and a line with a deliverable vector is pending, whatever the priority: what ends a WFE */
int pdp64_virq_deliverable(const struct pdp64_cpu *c);		/* 1: ... and its level is above the guest's priority */
int pdp64_virtual_interrupt(struct pdp64_cpu *c, const struct pdp64_env *e);	/* take it if deliverable (1) */
#endif

/* The meaning of the pdp64 instructions, shared by every executor (see pdp64exec.c). */
#ifndef PDP64EXEC_H
#define PDP64EXEC_H
#include <stdint.h>
#include "pdp64-consts.h"

/* The valid bits of the PSW (System v1: docs/pdp64-system-architecture.md section 15): the flags, T, the priority and the two modes; the rest is reserved, zero. */
#define PSW_FLAGS	((1u << PSW_C) | (1u << PSW_V) | (1u << PSW_Z) | (1u << PSW_N))
#define PSW_FIELD(name, v)	(((unsigned)(v) & ((1u << PSW_WIDTH_##name) - 1)) << PSW_##name)
#define PSW_VALID	(PSW_FLAGS | (1u << PSW_T) | PSW_FIELD(PRI, ~0u) | PSW_FIELD(MODE, ~0u) | PSW_FIELD(PREV, ~0u))

struct pdp64_cpu {
	uint64_t r[16], pc, dp, fpsr;
	int fN, fZ, fV, fC;				/* the flag bits of the PSW; the other bits are in `psw` */
	uint64_t cur_pc;			/* the instruction being executed (set by pdp64_step) */
	unsigned psw;				/* the PSW without the flags (bits 0 to 3 are always zero here): T, priority, current and previous mode.  Read and write it through pdp64_psw / pdp64_set_psw. */
	/* r[14] and dp are the current mode's copies; the other modes' are here, by mode index (kernel 0, supervisor 1, user 2).  The current mode's slot is stale. */
	uint64_t spbank[3], dpbank[3];
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
	struct { uint64_t r[16], pc, dp, fpsr; int fN, fZ, fV, fC; } snap;	/* the state at the start of the instruction, for precise aborts (kept only when deliver is on) */
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
	int (*vecread)(void *u, uint64_t paddr, uint64_t *value);	/* the 64-bit word at a physical address, for the vector table; nonzero if the bus refuses (a machine check) */
	void (*tlb)(void *u, int op, uint64_t addr);	/* PDP64_TLB_*: tlbi (one page), tlbia, or a write to ptbr / asid / mmuctl */
	void (*raise)(void *u, int vector, uint64_t eva) __attribute__((noreturn));	/* deliver mode: the core has an abort; unwind to the main loop, which calls pdp64_exception(vector, eva) */
	void *u;
};
#define PDP64_TLB_PAGE 0	/* tlbi: the page that contains addr, for the current ASID and the global entries */
#define PDP64_TLB_ALL 1		/* tlbia, or a write to ptbr, asid or mmuctl */

static inline unsigned pdp64_mode(const struct pdp64_cpu *c) { return (c->psw >> PSW_MODE) & ((1u << PSW_WIDTH_MODE) - 1); }
static inline unsigned pdp64_priority(const struct pdp64_cpu *c) { return (c->psw >> PSW_PRI) & ((1u << PSW_WIDTH_PRI) - 1); }

int pdp64_insn_parcels(uint16_t parcel0);	/* the length in parcels of the instruction whose first parcel this is (a page-2 instruction is one) */
void pdp64_init(void);				/* once, before the first step */
void pdp64_step(struct pdp64_cpu *c, const struct pdp64_env *e);

unsigned pdp64_psw(const struct pdp64_cpu *c);	/* the whole PSW: flags and the rest */
void pdp64_set_psw(struct pdp64_cpu *c, unsigned psw);	/* load a PSW (valid bits only), switching the r14 and DP banks if the mode changes; the mode must not be the reserved 2 */
/* an abort (the host unwound with raise, or a fault in a hook): undo the partial effects of the instruction in progress (if any) and enter the exception.  eva: the faulting address */
void pdp64_exception(struct pdp64_cpu *c, const struct pdp64_env *e, int vector, uint64_t eva);
/* an interrupt request of this level and vector, between two instructions: taken (1) if the level is above the priority, else not (0) */
int pdp64_interrupt(struct pdp64_cpu *c, const struct pdp64_env *e, int level, int vector);
#endif

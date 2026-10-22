/* The meaning of the pdp64 instructions, shared by every executor (see pdp64exec.c). */
#ifndef PDP64EXEC_H
#define PDP64EXEC_H
#include <stdint.h>

struct pdp64_cpu {
	uint64_t r[16], pc, dp, fpsr;
	int fN, fZ, fV, fC;
	uint64_t cur_pc;			/* the instruction being executed (set by pdp64_step) */
};

/* The host's side.  ld and st move 1, 2, 4 or 8 bytes, little-endian, and check alignment and mapping themselves; fault never returns. */
struct pdp64_env {
	uint64_t (*ld)(void *u, uint64_t addr, int size);
	void (*st)(void *u, uint64_t addr, int size, uint64_t value);
	void (*fault)(void *u, const char *what, uint64_t addr) __attribute__((noreturn));
	void (*trap)(void *u, int n);		/* trap #n */
	void (*halt)(void *u);			/* halt */
	int (*mapped)(void *u, uint64_t addr);	/* prober, probew: may this address be accessed? */
	void *u;
};

int pdp64_insn_parcels(uint16_t parcel0);	/* the length in parcels of the instruction whose first parcel this is (a page-2 instruction is one) */
void pdp64_init(void);				/* once, before the first step */
void pdp64_step(struct pdp64_cpu *c, const struct pdp64_env *e);
#endif

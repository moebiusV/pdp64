/*
 * pdp64 CPU state.  The register file and flags are struct pdp64_cpu of the
 * shared execution core (gen/pdp64exec.h), embedded as is: the core operates
 * on it directly.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#ifndef PDP64_CPU_H
#define PDP64_CPU_H

#include "cpu-qom.h"
#include "exec/cpu-common.h"
#include "exec/cpu-interrupt.h"
#include "gen/pdp64exec.h"

#ifdef CONFIG_USER_ONLY
#error "pdp64 does not support user mode emulation"
#endif

#define EXCP_PDP64_FAULT 0x100

typedef struct CPUArchState {
    struct pdp64_cpu c;         /* r0..r15, pc, dp, fpsr, N Z V C */

    /* Fields up to this point are cleared by a CPU reset */
    struct {} end_reset_fields;

    uint64_t entry;             /* initial pc and sp, set by the board */
    uint64_t initial_sp;
    uint64_t ram_size;          /* physical RAM is [0, ram_size) */
    const char *fault_what;     /* the fault being reported */
    uint64_t fault_addr;
} CPUPDP64State;

struct ArchCPU {
    CPUState parent_obj;

    CPUPDP64State env;
};

struct PDP64CPUClass {
    CPUClass parent_class;

    DeviceRealize parent_realize;
    ResettablePhases parent_phases;
};

#define CPU_RESOLVING_TYPE TYPE_PDP64_CPU

static inline bool pdp64_mapped(const CPUPDP64State *env, uint64_t a, int size)
{
    return a < env->ram_size && size <= env->ram_size - a;
}

void pdp64_translate_init(void);
void pdp64_translate_code(CPUState *cs, TranslationBlock *tb,
                          int *max_insns, vaddr pc, void *host_pc);
void pdp64_cpu_do_interrupt(CPUState *cs);
void pdp64_cpu_dump_state(CPUState *cs, FILE *f, int flags);
void pdp64_report_fault(CPUPDP64State *env, const char *what, uint64_t addr);
void pdp64_stop(CPUPDP64State *env, int code);

#endif

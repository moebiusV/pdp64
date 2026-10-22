/*
 * pdp64 CPU state.  The register file, flags, PSW and system registers are
 * struct pdp64_cpu of the shared execution core (gen/pdp64exec.h), embedded
 * as is: the core operates on it directly.
 * SPDX-License-Identifier: BSD-2-Clause
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

#define EXCP_PDP64_FAULT 0x100  /* legacy machine: report and exit with 139 */
#define EXCP_PDP64_ABORT 0x101  /* kernel mode: an abort, vector ex_vector */

typedef struct CPUArchState {
    struct pdp64_cpu c;         /* r0..r15, pc, PSW, system registers */

    /* Fields up to this point are cleared by a CPU reset */
    struct {} end_reset_fields;

    uint64_t entry;             /* initial pc and sp, set by the board */
    uint64_t initial_sp;
    uint64_t ram_size;          /* physical RAM is [0, ram_size) */
    bool kernel_mode;           /* machine option kernel-mode: System v1 */
    const char *fault_what;     /* the fault being reported (legacy machine) */
    uint64_t fault_addr;
    int ex_vector;              /* the abort being delivered */
    uint64_t ex_eva;
    uint32_t irq_lines;         /* bit n: the device line of vector 32 + n is asserted */
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

/* the legacy machine's idea of a mapped address: RAM */
static inline bool pdp64_mapped(const CPUPDP64State *env, uint64_t a, int size)
{
    return a < env->ram_size && size <= env->ram_size - a;
}

/*
 * The QEMU MMU indexes: 0 physical (translation off), 1 kernel, 2 the other
 * modes (user, and supervisor, which is treated as user).
 */
enum { PDP64_MMU_PHYS = 0, PDP64_MMU_KERNEL = 1, PDP64_MMU_USER = 2 };

static inline int pdp64_mmu_idx_mode(const CPUPDP64State *env, unsigned mode)
{
    if (!env->c.deliver || !(env->c.mmuctl & (1u << MMUCTL_ENABLE))) {
        return PDP64_MMU_PHYS;
    }
    return mode == MODE_KERNEL ? PDP64_MMU_KERNEL : PDP64_MMU_USER;
}

void pdp64_translate_init(void);
void pdp64_translate_code(CPUState *cs, TranslationBlock *tb,
                          int *max_insns, vaddr pc, void *host_pc);
void pdp64_cpu_do_interrupt(CPUState *cs);
void pdp64_cpu_dump_state(CPUState *cs, FILE *f, int flags);
void pdp64_report_fault(CPUPDP64State *env, const char *what, uint64_t addr);
void pdp64_stop(CPUPDP64State *env, int code);

/* an abort: with exceptions delivered, vector and EVA; otherwise the report */
G_NORETURN void pdp64_raise(CPUPDP64State *env, int vector, uint64_t eva,
                            const char *what, uintptr_t ra);
/* op_helper.c: the core's entry points with the host's hooks */
void pdp64_enter_abort(CPUPDP64State *env);
bool pdp64_take_interrupt(CPUPDP64State *env, int level, int vector);
/* interrupt lines: the best asserted line, by level then lowest vector */
bool pdp64_irq_best(const CPUPDP64State *env, int *level, int *vector);
int pdp64_irq_level(int vector);
/* mmu.c: the page-table walk (kernel mode machine, translation on) */
bool pdp64_mmu_translate(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                         int mmu_idx, hwaddr *pa, int *prot, vaddr *size,
                         int *fault_vector);

#endif

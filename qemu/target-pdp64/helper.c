/*
 * pdp64 exceptions and state dump.  The only exception there is: a fault,
 * which ends the machine (exit status 139) as it does in sim64.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "qemu/osdep.h"
#include "qemu/qemu-print.h"
#include "qemu/main-loop.h"
#include "system/runstate.h"
#include "cpu.h"

void pdp64_cpu_dump_state(CPUState *cs, FILE *f, int flags)
{
    CPUPDP64State *env = cpu_env(cs);
    int i;

    for (i = 0; i < 16; i++) {
        qemu_fprintf(f, "r%-2d %016" PRIx64 "%s", i, env->c.r[i],
                     i % 4 == 3 ? "\n" : "  ");
    }
    qemu_fprintf(f, "pc  %016" PRIx64 "  N%d Z%d V%d C%d  fpsr %02" PRIx64 "\n",
                 env->c.pc, env->c.fN, env->c.fZ, env->c.fV, env->c.fC,
                 env->c.fpsr);
}

/* Stop the machine; the qemu process exits with status code. */
void pdp64_stop(CPUPDP64State *env, int code)
{
    CPUState *cs = env_cpu(env);
    bool locked = bql_locked();

    if (!locked) {
        bql_lock();
    }
    qemu_system_shutdown_request_with_code(SHUTDOWN_CAUSE_GUEST_SHUTDOWN, code);
    cpu_interrupt(cs, CPU_INTERRUPT_HALT);
    if (!locked) {
        bql_unlock();
    }
}

void pdp64_report_fault(CPUPDP64State *env, const char *what, uint64_t addr)
{
    fflush(stdout);
    fprintf(stderr, "qemu-system-pdp64: %s at pc=%#" PRIx64 " addr=%#" PRIx64
            "\n", what, env->c.cur_pc, addr);
    pdp64_cpu_dump_state(env_cpu(env), stderr, 0);
    pdp64_stop(env, 139);
}

void pdp64_cpu_do_interrupt(CPUState *cs)
{
    CPUPDP64State *env = cpu_env(cs);

    if (cs->exception_index == EXCP_PDP64_FAULT) {
        env->c.cur_pc = env->c.pc;
        pdp64_report_fault(env, env->fault_what, env->fault_addr);
    }
    cs->exception_index = -1;
}

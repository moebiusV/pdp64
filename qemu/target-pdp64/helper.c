/*
 * pdp64 exceptions, interrupt lines and state dump.
 * SPDX-License-Identifier: BSD-2-Clause
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
    qemu_fprintf(f, "pc  %016" PRIx64 "  N%d Z%d V%d C%d  fpsr %02" PRIx64
                 "  psw %04x\n",
                 env->c.pc, env->c.fN, env->c.fZ, env->c.fV, env->c.fC,
                 env->c.fpsr, pdp64_psw(&env->c));
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
    } else if (cs->exception_index == EXCP_PDP64_ABORT) {
        cs->exception_index = -1;
        pdp64_enter_abort(env);
    }
    cs->exception_index = -1;
}

/* The priority level of the device line of a vector. */
int pdp64_irq_level(int vector)
{
    switch (vector) {
    case VECTOR_TIMER:
        return IRQ_LEVEL_TIMER;
    case VECTOR_CONSOLE_IN:
    case VECTOR_CONSOLE_OUT:
        return IRQ_LEVEL_CONSOLE;
    default:
        return 1;
    }
}

/* The asserted line with the highest level; at equal levels the lowest vector. */
bool pdp64_irq_best(const CPUPDP64State *env, int *level, int *vector)
{
    bool found = false;
    int n;

    for (n = 0; n < 32; n++) {
        if (env->irq_lines >> n & 1) {
            int l = pdp64_irq_level(VECTOR_IRQ_BASE + n);
            if (!found || l > *level) {
                *level = l;
                *vector = VECTOR_IRQ_BASE + n;
                found = true;
            }
        }
    }
    return found;
}

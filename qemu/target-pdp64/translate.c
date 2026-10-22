/*
 * pdp64 translator: one instruction per translation block.  The block only
 * calls helper_exec, which decodes and executes the instruction in memory
 * with the shared core; the translator reads the first parcel to know how
 * long the instruction is, so that the block covers the right bytes.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "qemu/osdep.h"
#include "cpu.h"
#include "tcg/tcg-op.h"
#include "exec/helper-proto.h"
#include "exec/helper-gen.h"
#include "exec/translator.h"
#include "exec/translation-block.h"
#include "exec/log.h"
#define HELPER_H "helper.h"
#include "exec/helper-info.c.inc"
#undef  HELPER_H

typedef struct DisasContext {
    DisasContextBase base;
} DisasContext;

static void pdp64_tr_init_disas_context(DisasContextBase *dcbase, CPUState *cs)
{
}

static void pdp64_tr_tb_start(DisasContextBase *dcbase, CPUState *cs)
{
}

static void pdp64_tr_insn_start(DisasContextBase *dcbase, CPUState *cs)
{
    tcg_gen_insn_start(dcbase->pc_next, 0, 0);
}

static void pdp64_tr_translate_insn(DisasContextBase *dcbase, CPUState *cs)
{
    CPUPDP64State *env = cpu_env(cs);
    vaddr pc = dcbase->pc_next;
    uint16_t parcel0 = translator_lduw_end(env, dcbase, pc, MO_LE);
    int len = parcel0 >> 14;                /* the instruction has len+1 parcels */
    TCGv_i64 tpc = tcg_constant_i64(pc);

    dcbase->pc_next = pc + 2 * (len + 1);
    tcg_gen_st_i64(tpc, tcg_env, offsetof(CPUPDP64State, c.pc));
    gen_helper_exec(tcg_env);
    /* the helper has set pc */
    tcg_gen_lookup_and_goto_ptr();
    dcbase->is_jmp = DISAS_NORETURN;
}

static void pdp64_tr_tb_stop(DisasContextBase *dcbase, CPUState *cs)
{
}

static const TranslatorOps pdp64_tr_ops = {
    .init_disas_context = pdp64_tr_init_disas_context,
    .tb_start           = pdp64_tr_tb_start,
    .insn_start         = pdp64_tr_insn_start,
    .translate_insn     = pdp64_tr_translate_insn,
    .tb_stop            = pdp64_tr_tb_stop,
};

void pdp64_translate_code(CPUState *cs, TranslationBlock *tb,
                          int *max_insns, vaddr pc, void *host_pc)
{
    DisasContext dc;

    translator_loop(cs, tb, max_insns, pc, host_pc, &pdp64_tr_ops, &dc.base,
                    TCG_TYPE_VA);
}

void pdp64_translate_init(void)
{
}

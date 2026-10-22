/* p2: the table of page 2.  Every entry says which page-1 instruction a page-2 opcode abbreviates:  the top-level opcode, the register
 * that goes in its reg field, the addressing mode and base register of its memory operand (or its immediate), and where the displacement or
 * immediate comes from (the low nibble, the low nibble and the low bit of the opcode, a signed low nibble, a step of the opcode, or the byte
 * reg:low).  The numbers are those of spec/pdp64-mnemonics.hbnf, by name. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "fmt.h"
#include "calib.h"
#include "pdp64-consts.h"
#include "p2.h"

enum { D_ZERO, D_LOW, D_LOWHI, D_SLOW, D_STEP, D_BYTE };
#define FIELD (-1)		/* taken from the page-2 instruction: for reg, its reg nibble; for rm, its low nibble */
#define NONE (-2)

struct p2def {
	int valid, opc, reg, mode, rm, dsrc, scale, idx;
	int sysx;			/* 1 + the SYSX sub-opcode: the entry abbreviates a SYSX word; reg and low must be zero, or (sysxn) are the pad byte n = reg:low */
	int sysxn;
	/* opc: the page-1 opcode.  reg: the reg field of that instruction, or FIELD.  mode: AMODE_BASE or AMODE_IMM.  rm: base register or FIELD or NONE.
	   The displacement or immediate is, by dsrc:  D_ZERO 0;  D_LOW scale*low;  D_LOWHI scale*(16*idx + low);  D_SLOW low as 4-bit signed;
	   D_STEP scale*(1+idx);  D_BYTE scale*(reg:low as an 8-bit number). */
};

#define E(op, ...) [P2OP_##op] = { 1, __VA_ARGS__ }
#define X(op, sub) [P2OP_##op] = { 1, OPGROUP_SYS, 0, 0, 0, D_ZERO, 0, 0, 1 + (sub), 0 }
#define XN(op, sub) [P2OP_##op] = { 1, OPGROUP_SYS, 0, 0, 0, D_ZERO, 0, 0, 1 + (sub), 1 }
static const struct p2def T[64] = {
	E(LD_Q,  MN_MOV_MOVQ,      FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(ST_Q,  MOVSTORE_MOVQ,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LD_L,  MN_MOV_MOVL,      FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(ST_L,  MOVSTORE_MOVL,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LD_W,  MN_MOV_MOVW,      FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(ST_W,  MOVSTORE_MOVW,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LD_B,  MN_MOV_MOVB,      FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(ST_B,  MOVSTORE_MOVB,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LDZ_L, MN_MOVZ_MOVZL,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LDZ_W, MN_MOVZ_MOVZW,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LDZ_B, MN_MOVZ_MOVZB,    FIELD, AMODE_BASE, FIELD, D_ZERO, 0, 0),
	E(LEA_SP,  OPGROUP_LEA,    FIELD, AMODE_BASE, RALIAS_SP, D_LOW, 8, 0),
	E(LDQ_SP0, MN_MOV_MOVQ,    FIELD, AMODE_BASE, RALIAS_SP, D_LOWHI, 8, 0),
	E(LDQ_SP1, MN_MOV_MOVQ,    FIELD, AMODE_BASE, RALIAS_SP, D_LOWHI, 8, 1),
	E(STQ_SP,  MOVSTORE_MOVQ,  FIELD, AMODE_BASE, RALIAS_SP, D_LOW, 8, 0),
	E(LDL_SP0, MN_MOV_MOVL,    FIELD, AMODE_BASE, RALIAS_SP, D_LOWHI, 4, 0),
	E(LDL_SP1, MN_MOV_MOVL,    FIELD, AMODE_BASE, RALIAS_SP, D_LOWHI, 4, 1),
	E(STL_SP0, MOVSTORE_MOVL,  FIELD, AMODE_BASE, RALIAS_SP, D_LOWHI, 4, 0),
	E(STL_SP1, MOVSTORE_MOVL,  FIELD, AMODE_BASE, RALIAS_SP, D_LOWHI, 4, 1),
	E(LDQ_D1,  MN_MOV_MOVQ,    FIELD, AMODE_BASE, FIELD, D_STEP, 8, 0),
	E(LDQ_D2,  MN_MOV_MOVQ,    FIELD, AMODE_BASE, FIELD, D_STEP, 8, 1),
	E(LDQ_D3,  MN_MOV_MOVQ,    FIELD, AMODE_BASE, FIELD, D_STEP, 8, 2),
	E(LDQ_D4,  MN_MOV_MOVQ,    FIELD, AMODE_BASE, FIELD, D_STEP, 8, 3),
	E(STQ_D1,  MOVSTORE_MOVQ,  FIELD, AMODE_BASE, FIELD, D_STEP, 8, 0),
	E(STQ_D2,  MOVSTORE_MOVQ,  FIELD, AMODE_BASE, FIELD, D_STEP, 8, 1),
	E(LDL_D1,  MN_MOV_MOVL,    FIELD, AMODE_BASE, FIELD, D_STEP, 4, 0),
	E(LDL_D2,  MN_MOV_MOVL,    FIELD, AMODE_BASE, FIELD, D_STEP, 4, 1),
	E(LDL_D3,  MN_MOV_MOVL,    FIELD, AMODE_BASE, FIELD, D_STEP, 4, 2),
	E(LDL_D4,  MN_MOV_MOVL,    FIELD, AMODE_BASE, FIELD, D_STEP, 4, 3),
	E(PUSHM8,  OPGROUP_SOP,    MN_SOP_PUSHM, AMODE_IMM, NONE, D_BYTE, 256, 0),
	E(POPM8,   OPGROUP_SOP,    MN_SOP_POPM,  AMODE_IMM, NONE, D_BYTE, 256, 0),
	E(SUB_SP,  MN_ALU_SUB,     RALIAS_SP, AMODE_IMM, NONE, D_BYTE, 8, 0),
	E(ADD_SP,  MN_ALU_ADD,     RALIAS_SP, AMODE_IMM, NONE, D_BYTE, 8, 0),
	E(MOVQ_I,  MN_MOV_MOVQ,    FIELD, AMODE_IMM, NONE, D_SLOW, 0, 0),
	E(SHL_I,   MN_ALU_SHL,     FIELD, AMODE_IMM, NONE, D_LOW, 1, 0),
	E(SHR_I,   MN_ALU_SHR,     FIELD, AMODE_IMM, NONE, D_LOW, 1, 0),
	E(SAR_I,   MN_ALU_SAR,     FIELD, AMODE_IMM, NONE, D_LOW, 1, 0),
	E(AND_I,   MN_ALU_AND,     FIELD, AMODE_IMM, NONE, D_SLOW, 0, 0),
	E(BIS_I,   MN_ALU_BIS,     FIELD, AMODE_IMM, NONE, D_SLOW, 0, 0),
	E(XOR_I,   MN_ALU_XOR,     FIELD, AMODE_IMM, NONE, D_SLOW, 0, 0),
	E(ADD_I,   MN_ALU_ADD,     FIELD, AMODE_IMM, NONE, D_SLOW, 0, 0),
	X(PUSHX,   MN_SYSX_PUSHX),
	X(POPX,    MN_SYSX_POPX),
	X(ISYNC,   MN_SYSX_ISYNC),
	XN(HINT,   MN_SYSX_HINT),
};

/* the opcode of a page-2 instruction is the index in T; the displacement it carries */
static int64_t disp_of(const struct p2def *e, int reg, int low)
{
	switch (e->dsrc) {
	case D_LOW: return (int64_t)e->scale * low;
	case D_LOWHI: return (int64_t)e->scale * (16 * e->idx + low);
	case D_SLOW: return low >= 8 ? low - 16 : low;
	case D_STEP: return (int64_t)e->scale * (1 + e->idx);
	case D_BYTE: return (int64_t)e->scale * (reg * 16 + low);
	}
	return 0;
}

int p2_expand(const struct fmt *p, struct fmt *lf)
{
	if (p->opc < 0 || p->opc >= 64 || !T[p->opc].valid) return -1;
	const struct p2def *e = &T[p->opc];
	int64_t d = disp_of(e, p->reg, p->low);
	memset(lf, 0, sizeof *lf);
	if (e->sysx) {									/* pushx, popx: the SYSX of the long form */
		if (!e->sysxn && (p->reg || p->low)) return -1;
		lf->len = 1; lf->opc = OPGROUP_SYS; lf->reg = 0; lf->low = SYS_MINOR_SYSX;
		lf->shape = FS_SYSX; lf->sub = e->sysx - 1; lf->n = e->sysxn ? (unsigned)(p->reg * 16 + p->low) : 0;
		return 0;
	}
	lf->len = 1;
	lf->opc = e->opc;
	lf->reg = e->reg == FIELD ? p->reg : e->reg;
	lf->low = e->mode;
	lf->shape = e->mode == AMODE_BASE ? FS_BASE : FS_WIDE;
	lf->rm = e->rm == FIELD ? (unsigned)p->low : e->rm == NONE ? 0 : (unsigned)e->rm;
	int bits = dispbits(e->mode, 1);
	lf->d = (uint64_t)d & (bits >= 64 ? ~(uint64_t)0 : (((uint64_t)1 << bits) - 1));
	return 0;
}

/* ---- the other direction: every (reg, low) of every page-2 opcode is expanded once, into a hash table keyed by the page-1 instruction ---- */

struct slot { uint64_t key; int used; uint8_t opc, reg, low; };
#define NSLOT 32768
static struct slot *slots;

static uint64_t key_of(int opc, int reg, int mode, int rm, int64_t d)
{
	return (uint64_t)opc | (uint64_t)reg << 8 | (uint64_t)mode << 12 | (uint64_t)rm << 16 | ((uint64_t)d & 0xFFFFFFFFu) << 24;
}
static struct slot *probe(uint64_t key)
{
	unsigned h = (unsigned)((key * 0x9E3779B97F4A7C15ULL) >> 49) & (NSLOT - 1);
	while (slots[h].used && slots[h].key != key) h = (h + 1) & (NSLOT - 1);
	return &slots[h];
}
static void build_table(void)
{
	slots = calloc(NSLOT, sizeof *slots);
	for (int opc = 0; opc < 64; opc++) {
		if (!T[opc].valid) continue;
		const struct p2def *e = &T[opc];
		for (int reg = 0; reg < 16; reg++)
			for (int low = 0; low < 16; low++) {
				struct fmt p = { 0 }, lf;
				p.len = LENCODE_PAGE2; p.opc = opc; p.reg = reg; p.low = low;
				if (p2_expand(&p, &lf)) continue;
				int64_t d = disp_of(e, reg, low);
				if (e->sysx) { lf.rm = lf.sub; d = lf.n; }	/* the sub-opcode is the key's rm, the pad byte its displacement */
				struct slot *s = probe(key_of(lf.opc, lf.reg, lf.low, lf.rm, d));
				if (s->used) continue;			/* the lowest page-2 opcode wins */
				s->used = 1; s->key = key_of(lf.opc, lf.reg, lf.low, lf.rm, d);
				s->opc = opc; s->reg = reg; s->low = low;
			}
	}
}

int p2_find(int opc, int reg, int mode, int rm, int64_t d, struct fmt *p)
{
	if (d < INT32_MIN || d > INT32_MAX) return 0;
	if (!slots) build_table();
	struct slot *s = probe(key_of(opc, reg, mode, (mode == AMODE_BASE || opc == OPGROUP_SYS) ? rm : 0, d));
	if (!s->used) return 0;
	memset(p, 0, sizeof *p);
	p->len = LENCODE_PAGE2; p->shape = FS_P2; p->opc = s->opc; p->reg = s->reg; p->low = s->low;
	return 1;
}

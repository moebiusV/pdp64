/* The instruction decoder of the shared executor.  Included by pdp64exec.c (it shares that file's statics); the codec is common/pdp64enc.c with the
 * generated tables.
 *
 * An instruction is decoded by the table codec into an einsn (a mnemonic and operands as the assembly language writes them: sources first, destination
 * last, `cmp` register first).  An instruction of the groups of the mnemonic numbering (spec/grammars.d) is turned into the struct fmt (opcode
 * group, sub-opcode, register fields) and run by exec_fmt, with its memory-side operand built by eoperand from the einsn, so that the semantics are one
 * piece of code.  What only the grammar of the encoding has (the fused instructions, the selects, the overflow-checked arithmetic, the checked trap, movql,
 * MESC) is written here.
 *
 * What is not implemented traps as an illegal instruction with a message that names the mnemonic (list: H_UNIMPL below): the atomic group (the operand
 * placement and the size encoding are not fixed by the ISA text), the AES and SHA instructions, UTF8DEC, UTF8ENC, MVAL, the deferred loads (.d, .ud),
 * the placeholders syspg3 to syspg5.
 */
/* the register file is r in pdp64exec.c, a macro that would also take the field `r` of an eop: use RG here */
#undef r
#define RG (C->r)
enum {
	H_UNIMPL = 0,
	H_MOV, H_MOVZ, H_LEA, H_ALU, H_SOP, H_XFER, H_JTAG,
	H_BR, H_CB, H_SOB, H_TAG,
	H_SYS0, H_SYSX, H_SYSM, H_TLBX, H_SYSR, H_SPL, H_TRAP, H_PROBE, H_MFSR, H_MTSR,
	H_BESC, H_AESC, H_MBLK, H_FESC, H_SET,
	H_MOVU, H_RMW,
	H_MASK, H_BSEL, H_OVF, H_TRAPCC, H_MOVQL, H_UTF8LEN, H_CT, H_CHK2,
	H_MOVCALL, H_POPMRET, H_POPRET, H_MOV2,
	H_VEC
};
struct hdef { const char *name; int kind, a; };
#define H_USER 0x4000				/* or-ed into the argument of the user-qualified moves (movq.u ...): the memory operand is accessed with the privilege of user mode (6.10.4) */
#define VECTOR_CHECK 16				/* the overflow / bounds check trap (docs/study-proposals.md item 9) */
#include "pdp64exec_corehdefs.inc"	/* hdefs[]: word -> handler kind and argument, generated from spec/facts/core.toml (tools/gen-core-names.py) */
/* every other mnemonic of the tables is H_UNIMPL: ATOM (cas casdb swap swapdb xadd xadddb xand xanddb xor_ xor_db xxor xxordb xmax xmaxdb xmin xmindb xmaxu xmaxudb
   xminu xminudb ll sc), aeses aesesm aesds aesdsm aesks1 aesks2 aesim, sha256sig0/1 sha256sum0/1 sha512sig0/1 sha512sum0/1, msha256 msha512 maesctr, utf8dec utf8enc
   mval, the deferred loads movX.d movX.ud, syspg3 to syspg5 */

static struct hinfo { uint8_t kind; uint8_t user; int a; } *HT;
static void vec_init(void);

static void enc_exec_init(void)
{
	const struct etab *t = &enc_tab;
	enc_init(t);
	HT = calloc(t->nmn, sizeof *HT);
	for (size_t i = 0; i < sizeof hdefs / sizeof *hdefs; i++) {
		int m = enc_mn_find(t, hdefs[i].name);
		if (m >= 0) { HT[m].kind = hdefs[i].kind; HT[m].user = (hdefs[i].a & H_USER) != 0; HT[m].a = hdefs[i].a & ~H_USER; }
	}
	vec_init();
}

/* ---- the memory-side operand of the instruction being run ------------------------------------------------------------ */
static const struct eop *EO;			/* the operand eoperand builds */
static int EO_size;				/* the access size: the stride of (rn)+ and -(rn) when none is written (8 outside the moves) */

static void eoperand(uint64_t start, struct opnd *o)
{
	const struct eop *e = EO;
	int64_t stride = e->v ? e->v : EO_size;
	o->adjust_reg = -1;
	switch (e->k) {
	case EK_R: o->kind = O_REG; o->reg = e->r; return;
	case EK_I: o->kind = O_IMM; o->imm = e->v; return;
	case EK_B: o->kind = O_MEM; o->addr = (e->r == EBASE_DP ? dp : RG[e->r]) + e->v; return;
	case EK_X: o->kind = O_MEM; o->addr = RG[e->r] + RG[e->x] * e->s + e->v; return;
	case EK_PI: o->kind = O_MEM; o->addr = RG[e->r]; o->adjust_reg = e->r; o->adjust = stride; return;
	case EK_PD: o->kind = O_MEM; o->addr = RG[e->r] - stride; RG[e->r] = o->addr; return;	/* pre-decrement happens before the access */
	case EK_PC: o->kind = O_MEM; o->addr = start + e->v; return;
	case EK_A: o->kind = O_MEM; o->addr = e->v; return;
	}
	die("unimplemented operand form", 0);
}

static int is_mem(const struct eop *e) { return e->k != EK_R && e->k != EK_I; }

#include "pdp64exec_vec.inc"

/* ---- one instruction ------------------------------------------------------------------------------------------------ */
static void check_both(uint64_t a, int size, int write)
{
	E->check(E->u, a, 1, write);
	E->check(E->u, a + size - 1, 1, write);
}

/* the category of a decoded instruction, for the profile  */
static int is_frame(const struct eop *e) { return e->k == EK_B && (e->r == 13 || e->r == 14); }
static int classify_enc(const struct hinfo *h, const struct einsn *in)
{
	const struct eop *op = in->op;
	switch (h->kind) {
	case H_MOV: case H_MOVZ:
		if (in->nops == 2 && is_mem(&op[1])) return is_frame(&op[1]) ? PDP64_CAT_FRAME_ST : PDP64_CAT_MEMREF;
		if (is_mem(&op[0])) return is_frame(&op[0]) ? PDP64_CAT_FRAME_LD : PDP64_CAT_MEMREF;
		return op[0].k == EK_R && h->a == MN_MOV_MOVQ && h->kind == H_MOV ? PDP64_CAT_REGMOVE : PDP64_CAT_OTHER;
	case H_LEA: return PDP64_CAT_LEA;
	case H_ALU: return is_mem(h->a == MN_ALU_CMP || h->a == MN_ALU_FCMP ? &op[1] : &op[0]) ? PDP64_CAT_MEMREF : PDP64_CAT_OTHER;
	case H_SOP:
		if (h->a == MN_SOP_PUSHM || h->a == MN_SOP_POPM || h->a == MN_SOP_PUSH || h->a == MN_SOP_POP) return PDP64_CAT_PUSHPOP;
		if (h->a == MN_SOP_JMP || h->a == MN_SOP_CALL) return PDP64_CAT_CALL;
		return is_mem(&op[0]) ? PDP64_CAT_MEMREF : PDP64_CAT_OTHER;
	case H_XFER: case H_JTAG: return PDP64_CAT_CALL;
	case H_BR: case H_CB: case H_SOB: case H_TAG: return PDP64_CAT_BRANCH;
	case H_SYS0: return h->a == MN_SYS_NONE_RET ? PDP64_CAT_CALL : PDP64_CAT_OTHER;
	case H_MBLK: return PDP64_CAT_BLOCK;
	case H_MOVCALL: case H_POPMRET: case H_POPRET: case H_MOV2: return PDP64_CAT_FUSED;
	case H_VEC: return PDP64_CAT_BLOCK;
	case H_MOVU: case H_RMW: return PDP64_CAT_MEMREF;
	}
	return PDP64_CAT_OTHER;
}

static void step_enc(void)
{
	const struct etab *t = &enc_tab;
	uint64_t start = pc;
	uint16_t par[5];
	struct einsn in;
	par[0] = (uint16_t)E->fetch(E->u, pc);
	int n = enc_len_p0(t, par[0]);
	if (!n) die("illegal instruction", 0);
	for (int i = 1; i < n; i++) par[i] = (uint16_t)E->fetch(E->u, pc + 2 * i);
	if (enc_decode(t, par, n, &in, NULL) != n) die("illegal instruction", 0);
	pc += 2 * n;
	C->cur_insn = (uint32_t)par[0] << 16 | (n > 1 ? par[1] : 0);			/* HINSN of an exit that this instruction causes */

	const struct hinfo *h = &HT[in.mn];
	const struct eop *op = in.op;
	if (E->profile) E->profile(E->u, start, n, classify_enc(h, &in));
	struct fmt f;
	memset(&f, 0, sizeof f); EO = NULL; EO_size = 8;
	switch (h->kind) {
	case H_UNIMPL: {
		static char msg[96];
		snprintf(msg, sizeof msg, "unimplemented instruction %s (not in the reference executor)", t->mn[in.mn].name);
		die(msg, 0);
	}
	case H_MOV: case H_MOVZ: {
		int opc = h->a, size = moves_size(opc);
		EO_size = size;
		if (in.nops == 2 && is_mem(&op[1])) {					/* the store: rs, memory */
			f.opc = opc == MN_MOV_MOVQ ? MOVSTORE_MOVQ : opc == MN_MOV_MOVL ? MOVSTORE_MOVL : opc == MN_MOV_MOVW ? MOVSTORE_MOVW : MOVSTORE_MOVB;
			f.reg = op[0].r; EO = &op[1];
		} else { f.opc = opc; f.reg = op[1].r; EO = &op[0]; }
		C->uacc = h->user;								/* a .u move: its memory operand is accessed with user privilege (the host looks at uacc); an exception marks ECAUSE (enter) */
		exec_fmt(f, start, 0);
		C->uacc = 0;
		return;
	}
	case H_LEA: f.opc = OPGROUP_LEA; f.reg = op[1].r; EO = &op[0]; exec_fmt(f, start, 0); return;
	case H_ALU:
		f.opc = h->a;
		if (h->a == MN_ALU_CMP || h->a == MN_ALU_FCMP) { f.reg = op[0].r; EO = &op[1]; }
		else { f.reg = op[1].r; EO = &op[0]; }
		exec_fmt(f, start, 0); return;
	case H_SOP:
		f.opc = OPGROUP_SOP; f.reg = h->a; EO = &op[0]; exec_fmt(f, start, 0); return;
	case H_XFER:
		f.opc = OPGROUP_XFER; f.reg = h->a; EO = &op[0]; exec_fmt(f, start, 0); return;
	case H_JTAG: {									/* jtag d(rbase)(rtagged): jump to the table entry that the tag selects */
		uint64_t a = RG[op[0].r] + op[0].v + 8 * (RG[op[0].x] & 7);
		pc = ld(a, 8);
		return;
	}
	case H_BR: if (cond(h->a)) pc = start + op[0].v; return;
	case H_CB: {									/* cbCC ra, #imm|rb, target: the comparison leaves the flags as they were */
		uint64_t b = op[1].k == EK_R ? RG[op[1].r] : (uint64_t)op[1].v;
		if (cmp_taken(RG[op[0].r], b, h->a)) pc = start + op[2].v;
		return;
	}
	case H_SOB: if (--RG[op[0].r] != 0) pc = start + op[1].v; return;
	case H_TAG: if (((RG[op[0].r] & 7) == (uint64_t)op[1].v) == !h->a) pc = start + op[2].v; return;
	case H_SYS0: f.opc = OPGROUP_SYS; f.reg = 0; f.low = h->a; exec_fmt(f, start, 0); return;
	case H_SYSX:
		f.opc = OPGROUP_SYS; f.reg = 0; f.low = SYS_MINOR_SYSX; f.shape = FS_SYSX; f.sub = h->a;
		if (h->a == MN_SYSX_HINT) f.n = (unsigned)op[0].v;
		exec_fmt(f, start, 0); return;
	case H_SYSM:									/* rti #mask, rtt #mask, genter #mask: the mask is the operand (f.n) */
		f.opc = OPGROUP_SYS; f.reg = 0; f.n = (unsigned)op[0].v;
		if (h->a == MN_SYSX_GENTER && h->kind == H_SYSM) { f.low = SYS_MINOR_SYSX; f.shape = FS_SYSX; f.sub = MN_SYSX_GENTER; }
		else f.low = h->a;
		exec_fmt(f, start, 0); return;
	case H_TLBX: tlbx(h->a, RG[op[0].r]); return;						/* tlbias rN, tlbigp rN */
	case H_SYSR: f.opc = OPGROUP_SYS; f.reg = h->a; f.low = op[0].r; exec_fmt(f, start, 0); return;
	case H_SPL: f.opc = OPGROUP_SYS; f.reg = MN_SYS_SPL; f.low = (int)op[0].v; exec_fmt(f, start, 0); return;
	case H_TRAP: f.opc = OPGROUP_SYS; f.reg = MN_SYS_TRAPL; f.n = (unsigned)op[0].v; exec_fmt(f, start, 0); return;
	case H_PROBE: f.opc = OPGROUP_SYS; f.reg = h->a; f.rd = op[0].r; f.low = op[1].r; exec_fmt(f, start, 0); return;
	case H_MFSR: f.opc = OPGROUP_SYS; f.reg = 0; f.low = MN_SYSREG_MFSR; f.sub = (unsigned)op[1].v; f.rd = op[0].r; exec_fmt(f, start, 0); return;
	case H_MTSR: f.opc = OPGROUP_SYS; f.reg = 0; f.low = MN_SYSREG_MTSR; f.sub = (unsigned)op[0].v; f.rd = op[1].r; exec_fmt(f, start, 0); return;
	case H_SET: f.opc = OPGROUP_AESC; f.sub = SUBOP_SET; f.x = (unsigned)op[0].v; f.reg = op[1].r; exec_fmt(f, start, 0); return;
	case H_BESC: case H_AESC: case H_MBLK: case H_FESC: {
		int sub = h->a;
		f.opc = h->kind == H_BESC ? OPGROUP_BESC : h->kind == H_AESC ? OPGROUP_AESC : h->kind == H_MBLK ? OPGROUP_MBLK : OPGROUP_FESC;
		f.sub = sub;
		if (h->kind == H_MBLK) { f.reg = op[0].r; f.low = in.nops == 3 ? op[1].r : 0; f.t = op[in.nops - 1].r; }	/* mcpy rd, rs, rn: the destination pointer first */
		else if (sub == MN_FESC_FCMP32 && h->kind == H_FESC) { f.reg = op[0].r; f.low = op[1].r; }
		else if (sub == MN_FESC_FCMP16 && h->kind == H_FESC) { f.reg = op[0].r; f.low = op[1].r; }
		else if (h->kind == H_BESC && (sub == MN_BESC_RORI || sub == MN_BESC_RORI32 || sub == MN_BESC_ROL)) {	/* rori rs, #n, rd */
			f.low = op[0].r; f.reg = op[2].r; f.count = (unsigned)op[1].v;
			if (sub == MN_BESC_ROL) { f.sub = MN_BESC_RORI; f.count = (unsigned)((64 - op[1].v) & 63); }
		}
		else if (h->kind == H_BESC && sub == MN_BESC_DSHR) { f.low = op[0].r; f.t = op[1].r; f.pos = (unsigned)op[2].v; f.reg = op[3].r; }	/* dshr ra, rb, #n, rd */
		else if (h->kind == H_BESC && (sub == MN_BESC_EXTB || sub == MN_BESC_EXTZB || sub == MN_BESC_INSB)) {	/* extb rs, #pos, #width, rd */
			f.low = op[0].r; f.pos = (unsigned)op[1].v; f.width = (unsigned)(op[2].v & 255); f.reg = op[3].r;
		} else {									/* sources first, the destination last */
			f.reg = op[in.nops - 1].r; f.low = op[0].r;
			if (in.nops >= 3) f.t = op[1].r;
			if (in.nops >= 4) f.x = op[2].r;
		}
		exec_fmt(f, start, 0); return;
	}
	case H_UTF8LEN: {								/* the length of a sequence from its leading byte: 0 for a byte that cannot begin one */
		unsigned b = (unsigned)(RG[op[0].r] & 255);
		RG[op[1].r] = b < 0x80 ? 1 : b < 0xC2 ? 0 : b < 0xE0 ? 2 : b < 0xF0 ? 3 : b < 0xF5 ? 4 : 0;
		return;
	}
	case H_MOVU: {									/* explicit unaligned access (MESC): little-endian bytes, no alignment fault */
		int size = h->a;
		struct opnd o;
		EO_size = size;
		if (is_mem(&op[1])) {
			EO = &op[1]; operand(&f, start, &o);
			check_both(o.addr, size, 1);
			uint64_t v = RG[op[0].r];
			for (int i = 0; i < size; i++) st(o.addr + i, 1, v >> (8 * i));
			after(&o);
		} else {
			EO = &op[0]; operand(&f, start, &o);
			check_both(o.addr, size, 0);
			uint64_t v = 0;
			for (int i = 0; i < size; i++) v |= ld(o.addr + i, 1) << (8 * i);
			after(&o);
			RG[op[1].r] = (uint64_t)sext(v, size * 8);
		} return;
	}
	case H_RMW: {									/* addm rs, mem: M[EA] <- M[EA] op rs, the flags of the ALU operation */
		struct opnd o;
		uint64_t a, b = RG[op[0].r], res;
		EO_size = 8; EO = &op[1];
		operand(&f, start, &o);
		E->check(E->u, o.addr, 8, 1);						/* write permission is checked with the read */
		a = ld(o.addr, 8);
		switch (h->a) {
		case MN_ALU_ADD: res = add_f(a, b, 0); break;
		case MN_ALU_SUB: res = sub_f(a, b, 0); break;
		case MN_ALU_BIC: res = a & ~b; nz(res); fV = 0; break;
		default: res = a | b; nz(res); fV = 0; break;
		}
		st(o.addr, 8, res); after(&o);
		return;
	}
	case H_MASK: RG[op[2].r] = (RG[op[1].r] == 0) == (h->a == 0) ? 0 : RG[op[0].r]; return;	/* maskeqz ra, rc, rd: rd <- rc == 0 ? 0 : ra */
	case H_BSEL: { uint64_t m = RG[op[0].r]; RG[op[3].r] = (m & RG[op[1].r]) | (~m & RG[op[2].r]); return; }	/* bsel rm, ra, rb, rd */
	case H_OVF: {									/* addv/subv/mulv rs, rd (the tables have the two-register form: rd <- rd op rs, as add/sub/mul): signed overflow is an abort
										   at this instruction, rd unwritten, no flags.  (docs/study-proposals.md item 9 writes it with three registers: ra op rb -> rd; the three-register
										   form is accepted here too, although no table has it.) */
		int three = in.nops == 3;
		int64_t a = (int64_t)RG[three ? op[0].r : op[1].r], b = (int64_t)RG[three ? op[1].r : op[0].r], res;
		int ovf = h->a == 0 ? __builtin_add_overflow(a, b, &res) : h->a == 1 ? __builtin_sub_overflow(a, b, &res) : __builtin_mul_overflow(a, b, &res);
		if (ovf) fault_v(VECTOR_CHECK, "arithmetic overflow (addv/subv/mulv)", 0);
		RG[op[in.nops - 1].r] = (uint64_t)res;
		return;
	}
	case H_CT: case H_CHK2: {							/* the check instructions (errata 152): a fault on vector 16, EPC and EVA the address of this instruction, no flag read or written */
		int trap;
		if (h->kind == H_CT) {							/* ctCC rs, rb | #imm | (nothing: rs against zero) */
			uint64_t b = in.nops < 2 ? 0 : op[1].k == EK_R ? RG[op[1].r] : (uint64_t)op[1].v;
			trap = cmp_taken(RG[op[0].r], b, h->a);
		} else									/* chk2 rs, rlo, rhi: trap unless rlo <= rs < rhi, signed */
			trap = !((int64_t)RG[op[0].r] >= (int64_t)RG[op[1].r] && (int64_t)RG[op[0].r] < (int64_t)RG[op[2].r]);
		if (trap) {
			if (C->deliver && !C->standin) enter(VECTOR_CHECK, start, start);
			else E->fault(E->u, "check failed (ct, chk2)", start);
		}
		return;
	}
	case H_TRAPCC:									/* a trap, not an abort: EPC is the next instruction, EVA the address of this one */
		if (cond(h->a)) {
			if (C->deliver && !C->standin) enter(VECTOR_CHECK, pc, start);
			else E->fault(E->u, "check trap (trapcc)", start);
		}
		return;
	case H_VEC: vec_step(&in, start, n); return;
	case H_MOVQL: RG[op[1].r] = (uint64_t)op[0].v; return;
	/* the fused instructions: the first half reads registers the second does not change, so a fault in the second half restarts the whole instruction
	   (the state at its start is restored, errata 87) */
	case H_MOVCALL: {								/* movcall rs, rd, target: movq rs,rd ; call target */
		RG[op[1].r] = RG[op[0].r];
		uint64_t tgt = op[2].k == EK_PC ? start + op[2].v : (uint64_t)op[2].v;
		push(pc); pc = tgt;
		return;
	}
	case H_POPMRET: {								/* popmret #mask: popm #mask ; ret */
		uint32_t mask = (uint32_t)op[0].v;
		for (int k = 31; k >= 0; k--) if (mask >> k & 1) RG[k] = pop();
		pc = pop();
		return;
	}
	case H_POPRET: RG[op[0].r] = pop(); pc = pop(); return;				/* popret rd: pop rd ; ret */
	case H_MOV2: RG[op[1].r] = RG[op[0].r]; RG[op[3].r] = RG[op[2].r]; return;		/* mov2 ra, rb, rc, rd: movq ra,rb ; movq rc,rd, in that order */
	}
	die("unimplemented instruction", h->kind);
}

#undef RG
#define r (C->r)

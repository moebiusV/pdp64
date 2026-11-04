/* The prefix-coded encodings pdp64/16 and pdp64/32 in the shared executor.  Included by pdp64exec.c (it shares that file's statics) when PDP64_ENC is
 * defined; the codec is common/pdp64enc.c with the generated tables.
 *
 * An instruction is decoded by the table codec into an einsn (a mnemonic and operands as the assembly language writes them: sources first, destination
 * last, `cmp` register first).  The meaning is the one of exec_fmt: an instruction of the groups the original encoding has is turned into the struct fmt
 * the old decoder would have produced (opcode group, sub-opcode, register fields) and run by exec_fmt, with its memory-side operand built by eoperand from
 * the einsn; so the semantics of those instructions are one piece of code for the three encodings.  What only the new encodings have (the fused
 * instructions, the selects, the overflow-checked arithmetic, the checked trap, movql, MESC) is written here.
 *
 * What is not implemented traps as an illegal instruction with a message that names the mnemonic (list: H_UNIMPL below): the atomic group (the operand
 * placement and the size encoding are not fixed by the ISA text), the AES and SHA instructions, UTF8DEC, UTF8ENC, MVAL, the deferred loads (.d, .ud),
 * the placeholders syspg0 to syspg5.
 */
/* the register file is r in pdp64exec.c, a macro that would also take the field `r` of an eop: use RG here */
#undef r
#define RG (C->r)
enum {
	H_UNIMPL = 0,
	H_MOV, H_MOVZ, H_LEA, H_ALU, H_SOP, H_XFER, H_JTAG,
	H_BR, H_CB, H_SOB, H_TAG,
	H_SYS0, H_SYSX, H_SYSR, H_SPL, H_TRAP, H_PROBE, H_MFSR, H_MTSR,
	H_BESC, H_AESC, H_MBLK, H_FESC, H_SET,
	H_MOVU, H_RMW,
	H_MASK, H_BSEL, H_OVF, H_TRAPCC, H_MOVQL, H_UTF8LEN,
	H_MOVCALL, H_POPMRET, H_POPRET, H_MOV2
};
struct hdef { const char *name; int kind, a; };
#define VECTOR_CHECK 16				/* the overflow / bounds check trap (docs/study-proposals.md item 9) */
static const struct hdef hdefs[] = {
	{ "movq", H_MOV, MN_MOV_MOVQ }, { "movl", H_MOV, MN_MOV_MOVL }, { "movw", H_MOV, MN_MOV_MOVW }, { "movb", H_MOV, MN_MOV_MOVB },
	{ "movq.u", H_MOV, MN_MOV_MOVQ }, { "movl.u", H_MOV, MN_MOV_MOVL }, { "movw.u", H_MOV, MN_MOV_MOVW }, { "movb.u", H_MOV, MN_MOV_MOVB },
	{ "movzl", H_MOVZ, MN_MOVZ_MOVZL }, { "movzw", H_MOVZ, MN_MOVZ_MOVZW }, { "movzb", H_MOVZ, MN_MOVZ_MOVZB },
	{ "movzl.u", H_MOVZ, MN_MOVZ_MOVZL }, { "movzw.u", H_MOVZ, MN_MOVZ_MOVZW }, { "movzb.u", H_MOVZ, MN_MOVZ_MOVZB },
	{ "lea", H_LEA, 0 },
	{ "add", H_ALU, MN_ALU_ADD }, { "sub", H_ALU, MN_ALU_SUB }, { "bic", H_ALU, MN_ALU_BIC }, { "bis", H_ALU, MN_ALU_BIS }, { "cmp", H_ALU, MN_ALU_CMP },
	{ "bit", H_ALU, MN_ALU_BIT }, { "xor", H_ALU, MN_ALU_XOR }, { "and", H_ALU, MN_ALU_AND }, { "mul", H_ALU, MN_ALU_MUL }, { "mulh", H_ALU, MN_ALU_MULH },
	{ "shl", H_ALU, MN_ALU_SHL }, { "shr", H_ALU, MN_ALU_SHR }, { "sar", H_ALU, MN_ALU_SAR }, { "fadd", H_ALU, MN_ALU_FADD }, { "fsub", H_ALU, MN_ALU_FSUB },
	{ "fmul", H_ALU, MN_ALU_FMUL }, { "fcmp", H_ALU, MN_ALU_FCMP },
	{ "clr", H_SOP, MN_SOP_CLR }, { "com", H_SOP, MN_SOP_COM }, { "inc", H_SOP, MN_SOP_INC }, { "dec", H_SOP, MN_SOP_DEC }, { "neg", H_SOP, MN_SOP_NEG },
	{ "tst", H_SOP, MN_SOP_TST }, { "adc", H_SOP, MN_SOP_ADC }, { "sbc", H_SOP, MN_SOP_SBC }, { "asl", H_SOP, MN_SOP_ASL }, { "asr", H_SOP, MN_SOP_ASR },
	{ "pushm", H_SOP, MN_SOP_PUSHM }, { "popm", H_SOP, MN_SOP_POPM }, { "jmp", H_SOP, MN_SOP_JMP }, { "call", H_SOP, MN_SOP_CALL },
	{ "push", H_SOP, MN_SOP_PUSH }, { "pop", H_SOP, MN_SOP_POP },
	{ "jmpi", H_XFER, MN_XFER_JMPI }, { "calli", H_XFER, MN_XFER_CALLI }, { "jtag", H_JTAG, 0 },
	{ "br", H_BR, 0 }, { "bne", H_BR, 1 }, { "beq", H_BR, 2 }, { "bpl", H_BR, 3 }, { "bmi", H_BR, 4 }, { "bvc", H_BR, 5 }, { "bvs", H_BR, 6 },
	{ "bcc", H_BR, 7 }, { "bcs", H_BR, 8 }, { "bge", H_BR, 9 }, { "blt", H_BR, 10 }, { "bgt", H_BR, 11 }, { "ble", H_BR, 12 }, { "bhi", H_BR, 13 }, { "blos", H_BR, 14 },
	{ "cbne", H_CB, 1 }, { "cbeq", H_CB, 2 }, { "cbpl", H_CB, 3 }, { "cbmi", H_CB, 4 }, { "cbvc", H_CB, 5 }, { "cbvs", H_CB, 6 }, { "cbcc", H_CB, 7 },
	{ "cbcs", H_CB, 8 }, { "cbge", H_CB, 9 }, { "cblt", H_CB, 10 }, { "cbgt", H_CB, 11 }, { "cble", H_CB, 12 }, { "cbhi", H_CB, 13 }, { "cblos", H_CB, 14 },
	{ "sob", H_SOB, 0 }, { "btag", H_TAG, 0 }, { "bntag", H_TAG, 1 },
	{ "nop", H_SYS0, MN_SYS_NONE_NOP }, { "rti", H_SYS0, MN_SYS_NONE_RTI }, { "rtt", H_SYS0, MN_SYS_NONE_RTT }, { "ret", H_SYS0, MN_SYS_NONE_RET },
	{ "halt", H_SYS0, MN_SYS_NONE_HALT }, { "bpt", H_SYS0, MN_SYS_NONE_BPT }, { "fence", H_SYS0, MN_SYS_NONE_FENCE }, { "wfe", H_SYS0, MN_SYS_NONE_WFE },
	{ "sev", H_SYS0, MN_SYS_NONE_SEV }, { "lpad", H_SYS0, MN_SYS_NONE_LPAD }, { "tlbia", H_SYS0, MN_SYS_NONE_TLBIA }, { "tlbsync", H_SYS0, MN_SYS_NONE_TLBSYNC },
	{ "icinva", H_SYS0, MN_SYS_NONE_ICINVA },
	{ "pushx", H_SYSX, MN_SYSX_PUSHX }, { "popx", H_SYSX, MN_SYSX_POPX }, { "isync", H_SYSX, MN_SYSX_ISYNC }, { "hint", H_SYSX, MN_SYSX_HINT },
	{ "mtps", H_SYSR, MN_SYS_MTPS }, { "mfps", H_SYSR, MN_SYS_MFPS }, { "tlbi", H_SYSR, MN_SYS_TLBI }, { "mtasid", H_SYSR, MN_SYS_MTASID },
	{ "mfasid", H_SYSR, MN_SYS_MFASID }, { "mtdp", H_SYSR, MN_SYS_MTDP }, { "mfdp", H_SYSR, MN_SYS_MFDP }, { "mtdmw", H_SYSR, MN_SYS_MTDMW },
	{ "mfcpuid", H_SYSR, MN_SYS_MFCPUID }, { "icinv", H_SYSR, MN_SYS_ICINV },
	{ "spl", H_SPL, 0 }, { "trap", H_TRAP, 0 }, { "trapl", H_TRAP, 0 },
	{ "prober", H_PROBE, MN_SYS_PROBER }, { "probew", H_PROBE, MN_SYS_PROBEW }, { "mfsr", H_MFSR, 0 }, { "mtsr", H_MTSR, 0 },
	{ "clz", H_BESC, MN_BESC_CLZ }, { "ctz", H_BESC, MN_BESC_CTZ }, { "clo", H_BESC, MN_BESC_CLO }, { "cto", H_BESC, MN_BESC_CTO },
	{ "popcnt", H_BESC, MN_BESC_POPCNT }, { "bswap", H_BESC, MN_BESC_BSWAP }, { "bswapw", H_BESC, MN_BESC_BSWAPW }, { "bswapl", H_BESC, MN_BESC_BSWAPL },
	{ "bitrev", H_BESC, MN_BESC_BITREV }, { "ror", H_BESC, MN_BESC_ROR }, { "rori", H_BESC, MN_BESC_RORI }, { "rori32", H_BESC, MN_BESC_RORI32 },
	{ "rol", H_BESC, MN_BESC_ROL }, { "dshr", H_BESC, MN_BESC_DSHR }, { "extb", H_BESC, MN_BESC_EXTB }, { "extzb", H_BESC, MN_BESC_EXTZB },
	{ "insb", H_BESC, MN_BESC_INSB }, { "xnorpop", H_BESC, MN_BESC_XNORPOP }, { "clmull", H_BESC, MN_BESC_CLMULL }, { "clmulh", H_BESC, MN_BESC_CLMULH },
	{ "utf8len", H_UTF8LEN, 0 },
	{ "div", H_AESC, MN_AESC_DIV }, { "divu", H_AESC, MN_AESC_DIVU }, { "mod", H_AESC, MN_AESC_MOD }, { "modu", H_AESC, MN_AESC_MODU },
	{ "mulhu", H_AESC, MN_AESC_MULHU }, { "abs", H_AESC, MN_AESC_ABS }, { "min", H_AESC, MN_AESC_MIN }, { "minu", H_AESC, MN_AESC_MINU },
	{ "max", H_AESC, MN_AESC_MAX }, { "maxu", H_AESC, MN_AESC_MAXU }, { "set", H_SET, 0 },
	{ "mcpy", H_MBLK, MN_MBLK_MCPY }, { "mmov", H_MBLK, MN_MBLK_MMOV }, { "mset", H_MBLK, MN_MBLK_MSET }, { "mcmp", H_MBLK, MN_MBLK_MCMP },
	{ "mscn", H_MBLK, MN_MBLK_MSCN }, { "mscnn", H_MBLK, MN_MBLK_MSCNN },
	{ "fdiv", H_FESC, MN_FESC_FDIV }, { "fsqrt", H_FESC, MN_FESC_FSQRT }, { "fadd32", H_FESC, MN_FESC_FADD32 }, { "fsub32", H_FESC, MN_FESC_FSUB32 },
	{ "fmul32", H_FESC, MN_FESC_FMUL32 }, { "fdiv32", H_FESC, MN_FESC_FDIV32 }, { "fsqrt32", H_FESC, MN_FESC_FSQRT32 }, { "fcmp32", H_FESC, MN_FESC_FCMP32 },
	{ "fmadd", H_FESC, MN_FESC_FMADD }, { "fmsub", H_FESC, MN_FESC_FMSUB }, { "fnmadd", H_FESC, MN_FESC_FNMADD }, { "fnmsub", H_FESC, MN_FESC_FNMSUB },
	{ "fmadd32", H_FESC, MN_FESC_FMADD32 }, { "fmsub32", H_FESC, MN_FESC_FMSUB32 }, { "fnmadd32", H_FESC, MN_FESC_FNMADD32 }, { "fnmsub32", H_FESC, MN_FESC_FNMSUB32 },
	{ "fneg", H_FESC, MN_FESC_FNEG }, { "fabs", H_FESC, MN_FESC_FABS }, { "fcopysign", H_FESC, MN_FESC_FCOPYSIGN }, { "fmin", H_FESC, MN_FESC_FMIN },
	{ "fmax", H_FESC, MN_FESC_FMAX }, { "fclass", H_FESC, MN_FESC_FCLASS }, { "fclass32", H_FESC, MN_FESC_FCLASS32 },
	{ "frint", H_FESC, MN_FESC_FRINT }, { "frintz", H_FESC, MN_FESC_FRINTZ }, { "frintm", H_FESC, MN_FESC_FRINTM }, { "frintp", H_FESC, MN_FESC_FRINTP },
	{ "frinta", H_FESC, MN_FESC_FRINTA }, { "fcvtdq", H_FESC, MN_FESC_FCVTDQ }, { "fcvtqd", H_FESC, MN_FESC_FCVTQD }, { "fcvtds", H_FESC, MN_FESC_FCVTDS },
	{ "fcvtsd", H_FESC, MN_FESC_FCVTSD }, { "fcvtsl", H_FESC, MN_FESC_FCVTSL }, { "fcvtls", H_FESC, MN_FESC_FCVTLS }, { "fcvtdqu", H_FESC, MN_FESC_FCVTDQU },
	{ "fcvtqud", H_FESC, MN_FESC_FCVTQUD }, { "fsflags", H_FESC, MN_FESC_FSFLAGS },
	{ "fadd16", H_FESC, MN_FESC_FADD16 }, { "fsub16", H_FESC, MN_FESC_FSUB16 }, { "fmul16", H_FESC, MN_FESC_FMUL16 }, { "fdiv16", H_FESC, MN_FESC_FDIV16 },
	{ "fsqrt16", H_FESC, MN_FESC_FSQRT16 }, { "fcmp16", H_FESC, MN_FESC_FCMP16 }, { "fmadd16", H_FESC, MN_FESC_FMADD16 }, { "fmsub16", H_FESC, MN_FESC_FMSUB16 },
	{ "fnmadd16", H_FESC, MN_FESC_FNMADD16 }, { "fnmsub16", H_FESC, MN_FESC_FNMSUB16 }, { "fclass16", H_FESC, MN_FESC_FCLASS16 }, { "fcvtsh", H_FESC, MN_FESC_FCVTSH },
	{ "fcvths", H_FESC, MN_FESC_FCVTHS }, { "fcvtdh", H_FESC, MN_FESC_FCVTDH }, { "fcvthd", H_FESC, MN_FESC_FCVTHD }, { "fcvthl", H_FESC, MN_FESC_FCVTHL },
	{ "fcvtlh", H_FESC, MN_FESC_FCVTLH },
	{ "movub", H_MOVU, 1 }, { "movuw", H_MOVU, 2 }, { "movul", H_MOVU, 4 }, { "movuq", H_MOVU, 8 },
	{ "addm", H_RMW, MN_ALU_ADD }, { "subm", H_RMW, MN_ALU_SUB }, { "bicm", H_RMW, MN_ALU_BIC }, { "bism", H_RMW, MN_ALU_BIS },
	{ "maskeqz", H_MASK, 0 }, { "masknez", H_MASK, 1 }, { "bsel", H_BSEL, 0 },
	{ "addv", H_OVF, 0 }, { "subv", H_OVF, 1 }, { "mulv", H_OVF, 2 },
	{ "trapcc.ne", H_TRAPCC, 1 }, { "trapcc.eq", H_TRAPCC, 2 }, { "trapcc.pl", H_TRAPCC, 3 }, { "trapcc.mi", H_TRAPCC, 4 }, { "trapcc.vc", H_TRAPCC, 5 },
	{ "trapcc.vs", H_TRAPCC, 6 }, { "trapcc.cc", H_TRAPCC, 7 }, { "trapcc.cs", H_TRAPCC, 8 }, { "trapcc.ge", H_TRAPCC, 9 }, { "trapcc.lt", H_TRAPCC, 10 },
	{ "trapcc.gt", H_TRAPCC, 11 }, { "trapcc.le", H_TRAPCC, 12 }, { "trapcc.hi", H_TRAPCC, 13 }, { "trapcc.los", H_TRAPCC, 14 },
	{ "movql", H_MOVQL, 0 },
	{ "movcall", H_MOVCALL, 0 }, { "popmret", H_POPMRET, 0 }, { "popret", H_POPRET, 0 }, { "mov2", H_MOV2, 0 },
};
/* every other mnemonic of the tables is H_UNIMPL: ATOM (cas casdb swap swapdb xadd xadddb xand xanddb xor_ xor_db xxor xxordb xmax xmaxdb xmin xmindb xmaxu xmaxudb
   xminu xminudb ll sc), aeses aesesm aesds aesdsm aesks1 aesks2 aesim, sha256sig0/1 sha256sum0/1 sha512sig0/1 sha512sum0/1, msha256 msha512 maesctr, utf8dec utf8enc
   mval, the deferred loads movX.d movX.ud, syspg0 to syspg5 */

static struct hinfo { uint8_t kind; int a; } *HT[3];
static const struct etab *ETAB[3];

static void enc_exec_init(void)
{
	const struct etab *tabs[3] = { NULL, &enc_tab_16, &enc_tab_32 };
	for (int e = 1; e <= 2; e++) {
		const struct etab *t = tabs[e];
		ETAB[e] = t;
		enc_init(t);
		HT[e] = calloc(t->nmn, sizeof **HT);
		for (size_t i = 0; i < sizeof hdefs / sizeof *hdefs; i++) {
			int m = enc_mn_find(t, hdefs[i].name);
			if (m >= 0) { HT[e][m].kind = hdefs[i].kind; HT[e][m].a = hdefs[i].a; }
		}
	}
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

/* ---- one instruction ------------------------------------------------------------------------------------------------ */
static void check_both(uint64_t a, int size, int write)
{
	E->check(E->u, a, 1, write);
	E->check(E->u, a + size - 1, 1, write);
}

/* the category of a decoded instruction, for the profile (the same classes as classify_fmt) */
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
	case H_MOVU: case H_RMW: return PDP64_CAT_MEMREF;
	}
	return PDP64_CAT_OTHER;
}

static void step_enc(void)
{
	const struct etab *t = ETAB[C->enc];
	uint64_t start = pc;
	uint16_t par[5];
	struct einsn in;
	par[0] = (uint16_t)E->fetch(E->u, pc);
	int n = enc_len_p0(t, par[0]);
	if (!n) die("illegal instruction", 0);
	for (int i = 1; i < n; i++) par[i] = (uint16_t)E->fetch(E->u, pc + 2 * i);
	if (enc_decode(t, par, n, &in, NULL) != n) die("illegal instruction", 0);
	pc += 2 * n;

	const struct hinfo *h = &HT[C->enc][in.mn];
	const struct eop *op = in.op;
	if (E->profile) E->profile(E->u, start, n, classify_enc(h, &in));
	struct fmt f;
	memset(&f, 0, sizeof f);
	enc_active = 0; EO = NULL; EO_size = 8;
	switch (h->kind) {
	case H_UNIMPL: {
		static char msg[96];
		snprintf(msg, sizeof msg, "unimplemented instruction %s (not in the reference executor)", t->mn[in.mn].name);
		die(msg, 0);
	}
	case H_MOV: case H_MOVZ: {
		int opc = h->a, size = moves_size(opc);
		EO_size = size; enc_active = 1;
		if (in.nops == 2 && is_mem(&op[1])) {					/* the store: rs, memory */
			f.opc = opc == MN_MOV_MOVQ ? MOVSTORE_MOVQ : opc == MN_MOV_MOVL ? MOVSTORE_MOVL : opc == MN_MOV_MOVW ? MOVSTORE_MOVW : MOVSTORE_MOVB;
			f.reg = op[0].r; EO = &op[1];
		} else { f.opc = opc; f.reg = op[1].r; EO = &op[0]; }
		exec_fmt(f, start, 0); enc_active = 0; return;
	}
	case H_LEA: f.opc = OPGROUP_LEA; f.reg = op[1].r; EO = &op[0]; enc_active = 1; exec_fmt(f, start, 0); enc_active = 0; return;
	case H_ALU:
		f.opc = h->a; enc_active = 1;
		if (h->a == MN_ALU_CMP || h->a == MN_ALU_FCMP) { f.reg = op[0].r; EO = &op[1]; }
		else { f.reg = op[1].r; EO = &op[0]; }
		exec_fmt(f, start, 0); enc_active = 0; return;
	case H_SOP:
		f.opc = OPGROUP_SOP; f.reg = h->a; EO = &op[0]; enc_active = 1; exec_fmt(f, start, 0); enc_active = 0; return;
	case H_XFER:
		f.opc = OPGROUP_XFER; f.reg = h->a; EO = &op[0]; enc_active = 1; exec_fmt(f, start, 0); enc_active = 0; return;
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
		EO_size = size; enc_active = 1;
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
		}
		enc_active = 0; return;
	}
	case H_RMW: {									/* addm rs, mem: M[EA] <- M[EA] op rs, the flags of the ALU operation */
		struct opnd o;
		uint64_t a, b = RG[op[0].r], res;
		EO_size = 8; EO = &op[1]; enc_active = 1;
		operand(&f, start, &o);
		enc_active = 0;
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
	case H_OVF: {									/* addv/subv/mulv ra, rb, rd: signed overflow is an abort at this instruction, rd unwritten, no flags */
		int64_t a = (int64_t)RG[op[0].r], b = (int64_t)RG[op[1].r], res;
		int ovf = h->a == 0 ? __builtin_add_overflow(a, b, &res) : h->a == 1 ? __builtin_sub_overflow(a, b, &res) : __builtin_mul_overflow(a, b, &res);
		if (ovf) fault_v(VECTOR_CHECK, "arithmetic overflow (addv/subv/mulv)", 0);
		RG[op[2].r] = (uint64_t)res;
		return;
	}
	case H_TRAPCC:									/* a trap, not an abort: EPC is the next instruction, EVA the address of this one */
		if (cond(h->a)) {
			if (C->deliver && !C->standin) enter(VECTOR_CHECK, pc, start);
			else E->fault(E->u, "check trap (trapcc)", start);
		}
		return;
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

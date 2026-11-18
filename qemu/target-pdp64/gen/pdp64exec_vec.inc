/* The vec block, the tile and the GEMM unit (docs/encoding-work/vec-isa.md, gemm-forms.md), for the shared executor.  Included by pdp64exec_enc.inc, which
 * shares its statics (C, E, RG, ld, st, die, step).  The family was added to be benchmarked and pruned (errata 161); the semantics here are vec-isa.md's:
 *
 *   - A block is `vec Rs, Re`, instructions, `vend`.  It is run whole by the `vec` instruction (an interrupt waits for the end of the block in this executor).  The
 *     instructions up to `vend` are decoded once; with no `vend` before something that is not a vector instruction, the block is the one instruction after `vec`.
 *   - A strip is VL elements.  This implementation's strip is VBYTES bytes, so VL is VBYTES over the widest lane type that the block uses; the last strip is
 *     shorter.  The elements of the stream are those of the first instruction whose memory operand is (Rs)+, in its access size, and `Re` is the end.
 *   - The hidden registers v0..v15, t0..t7 are in struct pdp64_cpu.  The registers that are not accumulators (vclr) are zero at the start of each strip.
 *   - The integer registers a strip changes (the (Ra)+ pointers, the reduction targets) are changed in a copy and committed when the strip ends; the stores of a strip
 *     are held and made when it ends, after their addresses have been checked: a fault in a strip leaves the registers as they were at its start, and a block
 *     without accumulators restarts where it stopped (an abort keeps the progress); a block with accumulators restarts from its entry.
 *   - Statistics (struct pdp64_cpu: vblocks, vstrips, vops, velems) count what the benchmarks need.
 *
 * Choices the documents leave open: the sliding window's centre is (taps-1)/2 (the hand-written kernel reads 3 before and 4 after for 8 taps); the elements of a
 * floating-point register in an integer register are binary32 in the low 32 bits (f) or binary64 (d); the gather index lanes are signed byte offsets in lanes of
 * the destination's width; the descriptor of gemm.f is described at vec_gemm.
 */
#define VBYTES 32
#define VMAXBODY 64
#define VSQMAX 1024

enum {
	VO_NONE = 0, VO_VEC, VO_VEND, VO_VLEN,
	VO_ADD, VO_SUB, VO_SUBR, VO_MUL, VO_MIN, VO_MAX, VO_MINU, VO_MAXU, VO_ABD, VO_ABDU, VO_AND, VO_OR, VO_XOR, VO_SHL, VO_SHR, VO_SAR,
	VO_ADDS, VO_SUBS, VO_ADDSU, VO_SUBSU, VO_MOV, VO_NEG, VO_MLA, VO_FMA, VO_FNMA, VO_FMAB, VO_DOT, VO_DOTU, VO_DOTSU,
	VO_ACC, VO_MAXACC, VO_MINACC, VO_FIR, VO_CLR,
	VO_LD, VO_ST, VO_STS, VO_LDT, VO_STT, VO_LDX, VO_LSEG, VO_SSEG,
	VO_TCLR, VO_TMOPA, VO_TLD, VO_TST, VO_TADD, VO_GEMM
};

struct vinfo {
	uint8_t op, nseg;
	uint8_t lsz, lfl;		/* the lane type: bytes, floating point */
	uint8_t msz, msign, mfl;	/* the memory type: bytes, sign-extending, floating point */
};
static struct vinfo *VI;

static const struct { const char *base; int op; } vbases[] = {
	{ "vec", VO_VEC }, { "vend", VO_VEND }, { "vlen", VO_VLEN },
	{ "vadd", VO_ADD }, { "vsub", VO_SUB }, { "vsubr", VO_SUBR }, { "vmul", VO_MUL }, { "vmin", VO_MIN }, { "vmax", VO_MAX }, { "vminu", VO_MINU },
	{ "vmaxu", VO_MAXU }, { "vabd", VO_ABD }, { "vabdu", VO_ABDU }, { "vand", VO_AND }, { "vor", VO_OR }, { "vxor", VO_XOR }, { "vshl", VO_SHL },
	{ "vshr", VO_SHR }, { "vsar", VO_SAR }, { "vadds", VO_ADDS }, { "vsubs", VO_SUBS }, { "vaddsu", VO_ADDSU }, { "vsubsu", VO_SUBSU },
	{ "vmov", VO_MOV }, { "vneg", VO_NEG }, { "vmla", VO_MLA }, { "vfma", VO_FMA }, { "vfnma", VO_FNMA }, { "vfmab", VO_FMAB },
	{ "vdot", VO_DOT }, { "vdotu", VO_DOTU }, { "vdotsu", VO_DOTSU }, { "vacc", VO_ACC }, { "vmaxacc", VO_MAXACC }, { "vminacc", VO_MINACC },
	{ "vfir", VO_FIR }, { "vclr", VO_CLR },
	{ "vld", VO_LD }, { "vst", VO_ST }, { "vsts", VO_STS }, { "vldt", VO_LDT }, { "vstt", VO_STT }, { "vldx", VO_LDX },
	{ "vlseg2", VO_LSEG }, { "vlseg3", VO_LSEG }, { "vlseg4", VO_LSEG }, { "vsseg2", VO_SSEG }, { "vsseg3", VO_SSEG }, { "vsseg4", VO_SSEG },
	{ "vtclr", VO_TCLR }, { "vtfmopa", VO_TMOPA }, { "vtld", VO_TLD }, { "vtst", VO_TST }, { "vtadd", VO_TADD }, { "gemm", VO_GEMM },
};

static int v_lane(const char *s, uint8_t *sz, uint8_t *fl)
{
	if (!s || !s[0] || s[1]) return 0;
	*fl = 0;
	switch (s[0]) {
	case 'b': *sz = 1; return 1;
	case 'w': *sz = 2; return 1;
	case 'l': *sz = 4; return 1;
	case 'q': *sz = 8; return 1;
	case 'f': *sz = 4; *fl = 1; return 1;
	case 'd': *sz = 8; *fl = 1; return 1;
	}
	return 0;
}
static int v_mem(const char *s, uint8_t *sz, uint8_t *sign, uint8_t *fl)
{
	char t[3]; size_t n = s ? strlen(s) : 0;
	if (n < 1 || n > 2) return 0;
	memcpy(t, s, n + 1);
	*sign = 1;
	if (n == 2) { if (t[1] != 'u' || t[0] == 'q' || t[0] == 'f' || t[0] == 'd') return 0; *sign = 0; t[1] = 0; }
	return v_lane(t, sz, fl) ? (*fl ? (*sign = 0, 1) : 1) : 0;
}

/* classify a mnemonic: the base operation and its suffixes; 0 if it is not a vector word */
static int vec_classify(const char *name, struct vinfo *vi)
{
	char buf[32], *tok[3] = { 0, 0, 0 };
	int nt = 0, op = 0;
	size_t n = strlen(name);
	if (n >= sizeof buf) return 0;
	memcpy(buf, name, n + 1);
	char *dot = strchr(buf, '.');
	if (dot) {
		*dot++ = 0;
		for (char *p = dot; p && nt < 3; ) { tok[nt++] = p; p = strchr(p, '.'); if (p) *p++ = 0; }
	}
	for (size_t i = 0; i < sizeof vbases / sizeof *vbases; i++)
		if (!strcmp(vbases[i].base, buf)) { op = vbases[i].op; break; }
	if (!op) return 0;
	memset(vi, 0, sizeof *vi);
	vi->op = (uint8_t)op;
	if (op == VO_LSEG || op == VO_SSEG) vi->nseg = (uint8_t)(buf[5] - '0');
	switch (op) {
	case VO_VEC: case VO_VEND: case VO_TCLR: return nt == 0;
	case VO_LD: case VO_LDT: case VO_LDX: case VO_LSEG:			/* .m[.lane] */
		if (nt < 1 || nt > 2 || !v_mem(tok[0], &vi->msz, &vi->msign, &vi->mfl)) return 0;
		if (nt == 2) return v_lane(tok[1], &vi->lsz, &vi->lfl);
		vi->lsz = vi->msz; vi->lfl = vi->mfl;
		return 1;
	case VO_ST: case VO_STT: case VO_SSEG:					/* .lane[.m] */
		if (nt < 1 || nt > 2 || !v_lane(tok[0], &vi->lsz, &vi->lfl)) return 0;
		if (nt == 2) return v_mem(tok[1], &vi->msz, &vi->msign, &vi->mfl);
		vi->msz = vi->lsz; vi->mfl = vi->lfl; vi->msign = 1;
		return 1;
	case VO_ACC: case VO_MAXACC: case VO_MINACC: {			/* vacc.<src>.<acc>, vmaxacc.<src>: the source lane type, with its signedness; the accumulate width in msz, mfl (the memory fields are not used) */
		uint8_t ssz, ssg, sfl;
		if (nt < 1 || nt > 2 || !v_mem(tok[0], &ssz, &ssg, &sfl)) return 0;
		vi->lsz = ssz; vi->lfl = sfl; vi->msign = ssg;
		if (nt == 2) return op == VO_ACC && v_lane(tok[1], &vi->msz, &vi->mfl);
		vi->msz = sfl ? ssz : 8; vi->mfl = sfl;
		return 1;
	}
	case VO_STS:								/* .lane.m */
		return nt == 2 && v_lane(tok[0], &vi->lsz, &vi->lfl) && v_mem(tok[1], &vi->msz, &vi->msign, &vi->mfl);
	default:								/* .lane */
		return nt == 1 && v_lane(tok[0], &vi->lsz, &vi->lfl);
	}
}

static void vec_init(void)
{
	const struct etab *t = &enc_tab;
	VI = calloc(t->nmn, sizeof *VI);
	for (int m = 0; m < t->nmn; m++) {
		struct vinfo vi;
		if (HT[m].kind == H_UNIMPL && t->mn[m].name[0] != 0 && vec_classify(t->mn[m].name, &vi)) { HT[m].kind = H_VEC; VI[m] = vi; }
	}
}

/* ---- the lanes ----------------------------------------------------------------------------------------------------- */
static int64_t lget_s(const uint8_t *p, int sz) { int64_t v = 0; memcpy(&v, p, sz); return sext((uint64_t)v, sz * 8); }
static uint64_t lget_u(const uint8_t *p, int sz) { uint64_t v = 0; memcpy(&v, p, sz); return v; }
static void lput(uint8_t *p, int sz, uint64_t v) { memcpy(p, &v, sz); }
static double lget_f(const uint8_t *p, int sz) { if (sz == 4) { float f; memcpy(&f, p, 4); return f; } double d; memcpy(&d, p, 8); return d; }
static void lput_f(uint8_t *p, int sz, double v) { if (sz == 4) { float f = (float)v; memcpy(p, &f, 4); } else memcpy(p, &v, 8); }
/* a floating-point value in an integer register: binary32 in the low 32 bits (f), binary64 (d) */
static double rget_f(uint64_t x, int sz) { if (sz == 4) { uint32_t b = (uint32_t)x; float f; memcpy(&f, &b, 4); return f; } double d; memcpy(&d, &x, 8); return d; }
static uint64_t rput_f(double v, int sz) { if (sz == 4) { float f = (float)v; uint32_t b; memcpy(&b, &f, 4); return b; } uint64_t x; memcpy(&x, &v, 8); return x; }

/* ---- a strip ------------------------------------------------------------------------------------------------------- */
struct vsrc { int valid; uint64_t addr; int64_t stride; int msz, msign, mfl, lsz, lfl; };	/* where a register's lanes were loaded from: the sliding window reads its neighbours there */
struct vctx {
	uint64_t lr[32];		/* the integer registers as the strip sees them */
	int nact, vl, first, inblock;
	int nsq;
	struct { uint64_t a; uint64_t v; uint8_t sz; } sq[VSQMAX];
	struct vsrc src[16];
};
static struct vctx *VX;

static uint8_t *VR(int v) { return C->vr[v & 15]; }

static void vput_store(struct vctx *x, uint64_t a, int sz, uint64_t v)
{
	if (x->nsq >= VSQMAX) die("vector strip stores too much", 0);
	x->sq[x->nsq].a = a; x->sq[x->nsq].sz = (uint8_t)sz; x->sq[x->nsq].v = v; x->nsq++;
}
/* the stores of a strip, after their addresses have been checked */
static void vflush(struct vctx *x)
{
	for (int i = 0; i < x->nsq; i++) E->check(E->u, x->sq[i].a, x->sq[i].sz, 1);
	for (int i = 0; i < x->nsq; i++) st(x->sq[i].a, x->sq[i].sz, x->sq[i].v);
	x->nsq = 0;
}

/* the memory operand of a strip instruction: the address of the first element, and the (Ra)+ move */
struct vmem { uint64_t addr; int adj_reg; };
static void vmem_of(struct vctx *x, const struct eop *e, struct vmem *m)
{
	m->adj_reg = -1;
	switch (e->k) {
	case EK_B: m->addr = (e->r == EBASE_DP ? dp : x->lr[e->r]) + e->v; return;
	case EK_PI: m->addr = x->lr[e->r]; m->adj_reg = e->r; return;
	}
	die("vector memory operand form", 0);
}

/* the value of an element loaded from memory: sign or zero extended to 64 bits, floats converted to the lane's type */
static void vload_elem(uint8_t *dst, uint64_t a, const struct vinfo *vi)
{
	uint64_t raw = ld(a, vi->msz);
	if (vi->mfl) {
		double d = rget_f(raw, vi->msz);
		if (vi->lfl) lput_f(dst, vi->lsz, d); else lput(dst, vi->lsz, (uint64_t)(int64_t)d);
		return;
	}
	uint64_t v = vi->msign ? (uint64_t)sext(raw, vi->msz * 8) : raw;
	if (vi->lfl) lput_f(dst, vi->lsz, vi->msign ? (double)(int64_t)v : (double)v); else lput(dst, vi->lsz, v);
}
/* the value of a lane as memory holds it: narrowed (truncated), or saturated to the memory type */
static uint64_t vstore_elem(const uint8_t *src, const struct vinfo *vi, int sat)
{
	if (vi->lfl) {
		double d = lget_f(src, vi->lsz);
		if (vi->mfl) { double q = d; uint64_t x = rput_f(q, vi->msz); return x; }
		return (uint64_t)(int64_t)d;
	}
	if (vi->mfl) return rput_f((double)lget_s(src, vi->lsz), vi->msz);
	if (!sat) return lget_u(src, vi->lsz);
	int64_t x = lget_s(src, vi->lsz), lo, hi;
	int bits = vi->msz * 8;
	if (vi->msign) { lo = -((int64_t)1 << (bits - 1)); hi = ((int64_t)1 << (bits - 1)) - 1; } else { lo = 0; hi = bits >= 64 ? INT64_MAX : ((int64_t)1 << bits) - 1; }
	return (uint64_t)(x < lo ? lo : x > hi ? hi : x);
}

static uint64_t vreg_scalar_lane(const struct vctx *x, const struct eop *e, int lsz, int lfl, double *fv)
{
	uint64_t raw = e->k == EK_R ? x->lr[e->r] : (uint64_t)e->v;
	if (lfl) *fv = e->k == EK_R ? rget_f(raw, lsz) : (double)(int64_t)raw;
	return raw;
}

/* the second source of a lane operation: a vector (its lanes) or a scalar or an immediate (the same value in every lane) */
static void vsrc_b(const struct vctx *x, const struct eop *e, const struct vinfo *vi, uint8_t *tmp, const uint8_t **B)
{
	if (e->k == EK_V) { *B = VR(e->r); return; }
	double fv = 0;
	uint64_t raw = vreg_scalar_lane(x, e, vi->lsz, vi->lfl, &fv);
	for (int i = 0; i < VBYTES / vi->lsz; i++) { if (vi->lfl) lput_f(tmp + i * vi->lsz, vi->lsz, fv); else lput(tmp + i * vi->lsz, vi->lsz, raw); }
	*B = tmp;
}

static void vop_lane(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	int sz = vi->lsz, bits = sz * 8, n = x->nact;
	uint8_t tmp[VBYTES], *D = VR(op[0].r);
	const uint8_t *A = in->nops == 2 ? NULL : VR(op[1].r), *B = NULL;
	uint8_t out[VBYTES];
	memcpy(out, D, VBYTES);									/* the lanes beyond the strip keep what they hold (an accumulator's) */
	if (vi->op == VO_MOV || vi->op == VO_NEG) {						/* vD, vA | rS | #imm */
		if (op[1].k == EK_V) A = VR(op[1].r); else vsrc_b(x, &op[1], vi, tmp, &A);
		for (int i = 0; i < n; i++) {
			if (vi->lfl) lput_f(out + i * sz, sz, vi->op == VO_NEG ? -lget_f(A + i * sz, sz) : lget_f(A + i * sz, sz));
			else lput(out + i * sz, sz, vi->op == VO_NEG ? (uint64_t)(-lget_s(A + i * sz, sz)) : lget_u(A + i * sz, sz));
		}
		memcpy(D, out, VBYTES); return;
	}
	vsrc_b(x, &op[2], vi, tmp, &B);
	for (int i = 0; i < n; i++) {
		const uint8_t *a = A + i * sz, *b = B + i * sz;
		if (vi->lfl) {
			double p = lget_f(a, sz), q = lget_f(b, sz), z;
			switch (vi->op) {
			case VO_ADD: z = p + q; break;
			case VO_SUB: z = p - q; break;
			case VO_SUBR: z = q - p; break;
			case VO_MUL: z = p * q; break;
			case VO_MIN: z = p < q ? p : q; break;
			case VO_MAX: z = p > q ? p : q; break;
			case VO_ABD: z = fabs(p - q); break;
			case VO_FMA: z = sz == 4 ? (double)fmaf((float)p, (float)q, (float)lget_f(D + i * sz, sz)) : fma(p, q, lget_f(D + i * sz, sz)); break;
			case VO_FNMA: z = sz == 4 ? (double)fmaf(-(float)p, (float)q, (float)lget_f(D + i * sz, sz)) : fma(-p, q, lget_f(D + i * sz, sz)); break;
			default: die("vector floating-point lane operation not defined", vi->op);
			}
			lput_f(out + i * sz, sz, z);
		} else {
			int64_t p = lget_s(a, sz), q = lget_s(b, sz), z = 0;
			uint64_t up = lget_u(a, sz), uq = lget_u(b, sz), uz = 0;
			switch (vi->op) {
			case VO_ADD: uz = up + uq; break;
			case VO_SUB: uz = up - uq; break;
			case VO_SUBR: uz = uq - up; break;
			case VO_MUL: uz = up * uq; break;
			case VO_MIN: z = p < q ? p : q; uz = (uint64_t)z; break;
			case VO_MAX: z = p > q ? p : q; uz = (uint64_t)z; break;
			case VO_MINU: uz = up < uq ? up : uq; break;
			case VO_MAXU: uz = up > uq ? up : uq; break;
			case VO_ABD: uz = (uint64_t)(p > q ? p - q : q - p); break;
			case VO_ABDU: uz = up > uq ? up - uq : uq - up; break;
			case VO_AND: uz = up & uq; break;
			case VO_OR: uz = up | uq; break;
			case VO_XOR: uz = up ^ uq; break;
			case VO_SHL: uz = uq >= (uint64_t)bits ? 0 : up << uq; break;
			case VO_SHR: uz = uq >= (uint64_t)bits ? 0 : up >> uq; break;
			case VO_SAR: uz = (uint64_t)(uq >= (uint64_t)bits ? (p < 0 ? -1 : 0) : p >> uq); break;
			case VO_ADDS: case VO_SUBS: {
				int64_t lo = bits >= 64 ? INT64_MIN : -((int64_t)1 << (bits - 1)), hi = bits >= 64 ? INT64_MAX : ((int64_t)1 << (bits - 1)) - 1, w;
				int ovf = vi->op == VO_ADDS ? __builtin_add_overflow(p, q, &w) : __builtin_sub_overflow(p, q, &w);
				if (ovf) w = (vi->op == VO_ADDS ? q : -q) < 0 ? lo : hi;
				uz = (uint64_t)(w < lo ? lo : w > hi ? hi : w); break;
			}
			case VO_ADDSU: { uint64_t m = bits >= 64 ? ~(uint64_t)0 : ((uint64_t)1 << bits) - 1, w; uz = __builtin_add_overflow(up, uq, &w) || w > m ? m : w; break; }
			case VO_SUBSU: uz = up < uq ? 0 : up - uq; break;
			case VO_MLA: uz = (uint64_t)lget_s(D + i * sz, sz) + up * uq; break;
			default: die("vector integer lane operation not defined", vi->op);
			}
			lput(out + i * sz, sz, uz);
		}
	}
	memcpy(D, out, VBYTES);
}

static void vop_fmab(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	int sz = vi->lsz;
	uint8_t one[8];
	lput(one, sz, ld(x->lr[op[2].r], sz));
	double s = lget_f(one, sz);
	x->lr[op[2].r] += sz;							/* (Ra)+ moves by one element here, not by the strip */
	uint8_t *D = VR(op[0].r); const uint8_t *A = VR(op[1].r);
	for (int i = 0; i < x->nact; i++) {
		double z = sz == 4 ? (double)fmaf((float)lget_f(A + i * sz, sz), (float)s, (float)lget_f(D + i * sz, sz)) : fma(lget_f(A + i * sz, sz), s, lget_f(D + i * sz, sz));
		lput_f(D + i * sz, sz, z);
	}
}

static void vop_dot(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	uint8_t *D = VR(op[0].r); const uint8_t *A = VR(op[1].r), *B = VR(op[2].r);
	int nl = (x->nact + 3) / 4;
	for (int i = 0; i < nl; i++) {
		int64_t s = lget_s(D + 4 * i, 4);
		for (int k = 0; k < 4; k++) {
			int j = 4 * i + k;
			if (j >= x->nact) break;
			int64_t p = vi->op == VO_DOTU ? (int64_t)A[j] : (int64_t)(int8_t)A[j], q = vi->op == VO_DOT ? (int64_t)(int8_t)B[j] : (int64_t)B[j];
			s += p * q;
		}
		lput(D + 4 * i, 4, (uint64_t)s);
	}
}

static void vop_reduce(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	const uint8_t *S = VR(op[1].r);
	int sz = vi->lsz, asz = vi->op == VO_ACC ? vi->msz : sz;		/* the lanes' size; the accumulate width of vacc (the strip's VL does not count it) */
	uint64_t *Rd = &x->lr[op[0].r];
	if (vi->lfl) {
		double acc = rget_f(*Rd, asz);
		for (int i = 0; i < x->nact; i++) {
			double v = lget_f(S + i * sz, sz);
			if (vi->op == VO_ACC) acc += v; else if (vi->op == VO_MAXACC) { if (v > acc) acc = v; } else if (v < acc) acc = v;
		}
		*Rd = rput_f(acc, asz);
	} else if (vi->op == VO_ACC) {						/* the sum of the lanes, signed or unsigned as the source type says, wrapped to the accumulate width, added to the register */
		int64_t part = 0;
		for (int i = 0; i < x->nact; i++) part += vi->msign ? lget_s(S + i * sz, sz) : (int64_t)lget_u(S + i * sz, sz);
		if (asz < 8) part = (int64_t)sext((uint64_t)part, asz * 8);
		*Rd = (uint64_t)((int64_t)*Rd + part);
	} else {
		int64_t acc = (int64_t)*Rd;
		for (int i = 0; i < x->nact; i++) {
			int64_t v = vi->msign ? lget_s(S + i * sz, sz) : (int64_t)lget_u(S + i * sz, sz);
			if (vi->op == VO_MAXACC) { if (v > acc) acc = v; } else if (v < acc) acc = v;
		}
		*Rd = (uint64_t)acc;
	}
}

/* the sliding window: lane i of vD is the sum over k of R(t+k) times lane i+k-c of vS.  The lanes outside the strip are read from where vS's lanes were loaded
   from, if vS is the result of a load (the neighbours across the strip's edge, and outside the region, as the scalar code reads them), else they are zero. */
static void vop_fir(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	int sz = vi->lsz, taps = (int)op[3].v, c = (taps - 1) / 2, vs = op[1].r & 15, t = op[2].r;
	uint8_t out[VBYTES];
	const struct vsrc *s = &x->src[vs];
	memset(out, 0, sizeof out);
	for (int i = 0; i < x->nact; i++) {
		double fs = 0; int64_t is = 0;
		for (int k = 0; k < taps; k++) {
			int j = i + k - c;
			uint8_t lane[8];
			if (j >= 0 && j < x->nact) memcpy(lane, VR(vs) + j * sz, sz);
			else if (s->valid) { struct vinfo li = { 0, 0, (uint8_t)s->lsz, (uint8_t)s->lfl, (uint8_t)s->msz, (uint8_t)s->msign, (uint8_t)s->mfl }; vload_elem(lane, s->addr + (uint64_t)((int64_t)j * s->stride), &li); }
			else memset(lane, 0, sizeof lane);
			uint64_t coef = x->lr[(t + k) & 31];
			if (vi->lfl) fs = fma(lget_f(lane, sz), rget_f(coef, sz), fs);
			else is += lget_s(lane, sz) * (int64_t)sext(coef, sz * 8);
		}
		if (vi->lfl) lput_f(out + i * sz, sz, fs); else lput(out + i * sz, sz, (uint64_t)is);
	}
	memcpy(VR(op[0].r), out, VBYTES);
}

static void vop_mem(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	int v = op[0].r & 15, n = x->nact, op_ = vi->op, nf = vi->nseg ? vi->nseg : 1;
	struct vmem m;
	vmem_of(x, &op[1], &m);
	int esz = vi->msz;
	switch (op_) {
	case VO_LD: case VO_LSEG:
		for (int f = 0; f < nf; f++) {
			uint8_t *D = VR(v + f);
			memset(D, 0, VBYTES);
			for (int i = 0; i < n; i++) vload_elem(D + i * vi->lsz, m.addr + ((uint64_t)i * nf + f) * esz, vi);
			x->src[(v + f) & 15] = (struct vsrc){ 1, m.addr + (uint64_t)f * esz, (int64_t)esz * nf, esz, vi->msign, vi->mfl, vi->lsz, vi->lfl };
		}
		if (m.adj_reg >= 0) x->lr[m.adj_reg] += (uint64_t)n * nf * esz;
		return;
	case VO_ST: case VO_STS: case VO_SSEG:
		for (int f = 0; f < nf; f++) {
			const uint8_t *S = VR(v + f);
			for (int i = 0; i < n; i++) vput_store(x, m.addr + ((uint64_t)i * nf + f) * esz, esz, vstore_elem(S + i * vi->lsz, vi, op_ == VO_STS));
		}
		if (m.adj_reg >= 0) x->lr[m.adj_reg] += (uint64_t)n * nf * esz;
		return;
	case VO_LDT: case VO_STT: {
		int64_t stride = op[2].v;
		for (int i = 0; i < n; i++) {
			uint64_t a = m.addr + (uint64_t)((int64_t)i * stride);
			if (op_ == VO_LDT) { if (!i) memset(VR(v), 0, VBYTES); vload_elem(VR(v) + i * vi->lsz, a, vi); }
			else vput_store(x, a, esz, vstore_elem(VR(v) + i * vi->lsz, vi, 0));
		}
		if (op_ == VO_LDT) x->src[v].valid = 0;
		if (m.adj_reg >= 0) x->lr[m.adj_reg] += (uint64_t)((int64_t)n * stride);
		return;
	}
	}
}

static void vop_gather(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;			/* vldx vD, (Rb), vI: the codec has the base and the index vector as two operands */
	uint8_t *D = VR(op[0].r);
	const uint8_t *I = VR(op[2].r);
	uint64_t base = x->lr[op[1].r];
	uint8_t out[VBYTES];
	memset(out, 0, sizeof out);
	for (int i = 0; i < x->nact; i++) vload_elem(out + i * vi->lsz, base + (uint64_t)lget_s(I + i * vi->lsz, vi->lsz), vi);
	memcpy(D, out, VBYTES);
	x->src[op[0].r & 15].valid = 0;
}

/* ---- the tile ------------------------------------------------------------------------------------------------------ */
static int vtile_n(const struct vinfo *vi) { return vi->lsz ? VBYTES / vi->lsz : VBYTES / 4; }		/* VLt: the tile is VLt x VLt elements */

static void vop_tile(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	int sz = vi->lsz, n = vtile_n(vi);
	uint8_t *T = C->tr[op[0].r & 7];
	switch (vi->op) {
	case VO_TCLR: memset(T, 0, 256); return;
	case VO_TMOPA: {								/* tD[i][j] += vA[i] * vB[j] */
		const uint8_t *A = VR(op[1].r), *B = VR(op[2].r);
		for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) {
			uint8_t *e = T + (i * n + j) * sz;
			double z = sz == 4 ? (double)fmaf((float)lget_f(A + i * sz, sz), (float)lget_f(B + j * sz, sz), (float)lget_f(e, sz)) : fma(lget_f(A + i * sz, sz), lget_f(B + j * sz, sz), lget_f(e, sz));
			lput_f(e, sz, z);
		}
		return;
	}
	case VO_TADD: {
		const uint8_t *A = C->tr[op[1].r & 7], *B = C->tr[op[2].r & 7];
		uint8_t out[256];
		for (int i = 0; i < n * n; i++) lput_f(out + i * sz, sz, lget_f(A + i * sz, sz) + lget_f(B + i * sz, sz));
		memcpy(T, out, 256);
		return;
	}
	case VO_TLD: case VO_TST: {							/* vtld tN, (Ra), Rs: row i at Ra + i * Rs */
		uint64_t base = x->lr[op[1].r], rowb = x->lr[op[2].r];
		for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) {
			uint64_t a = base + (uint64_t)i * rowb + (uint64_t)j * sz;
			if (vi->op == VO_TLD) lput(T + (i * n + j) * sz, sz, ld(a, sz));
			else vput_store(x, a, sz, lget_u(T + (i * n + j) * sz, sz));
		}
		return;
	}
	}
}

/* gemm.f Rd, Rr, Rc: C[M,N] = alpha * A[M,K] . B[N,K]^T + beta * C[M,N] (the NT product of cngpt's linear layer), in binary32, for the tiles from (Rr, Rc) on.  Rd is the
   address of a descriptor of twelve 64-bit words:  0 A  1 B  2 C (addresses)  3 M  4 N  5 K (elements)  6 lda  7 ldb  8 ldc (bytes between rows)  9 alpha  10 beta
   (binary32 in the low 32 bits)  11 flags (bit 0: B is [K,N] (not transposed)).  Rr and Rc are the row and column of the next output tile (element numbers, multiples of
   the tile size VLt = VBYTES/4): the instruction does the tiles in the order rows first, then columns, each tile over all of K, and stops when Rc reaches N: a
   restart from the registers goes on with the next tile.  (An interrupt waits for it in this executor.) */
static void vop_gemm(struct vctx *x, const struct einsn *in)
{
	const struct eop *op = in->op;
	uint64_t d = x->lr[op[0].r];
	uint64_t A = ld(d, 8), B = ld(d + 8, 8), Cm = ld(d + 16, 8), M = ld(d + 24, 8), N = ld(d + 32, 8), K = ld(d + 40, 8);
	uint64_t lda = ld(d + 48, 8), ldb = ld(d + 56, 8), ldc = ld(d + 64, 8), fl = ld(d + 88, 8);
	float alpha = (float)rget_f(ld(d + 72, 8), 4), beta = (float)rget_f(ld(d + 80, 8), 4);
	const int T = VBYTES / 4;
	uint64_t *rr = &x->lr[op[1].r], *rc = &x->lr[op[2].r];
	C->vops++;
	C->progress = 1;								/* the registers are the progress: an abort keeps the tiles done */
	while (*rc < N) {
		uint64_t r0 = *rr, c0 = *rc;
		if (r0 >= M) { *rr = 0; *rc += T; continue; }
		uint64_t nr = M - r0 < (uint64_t)T ? M - r0 : T, nc = N - c0 < (uint64_t)T ? N - c0 : T;
		float acc[8][8];
		memset(acc, 0, sizeof acc);
		for (uint64_t k = 0; k < K; k++)
			for (uint64_t i = 0; i < nr; i++) {
				uint32_t ab = (uint32_t)ld(A + (r0 + i) * lda + k * 4, 4); float a; memcpy(&a, &ab, 4);
				for (uint64_t j = 0; j < nc; j++) {
					uint64_t ba = (fl & 1) ? B + k * ldb + (c0 + j) * 4 : B + (c0 + j) * ldb + k * 4;
					uint32_t bb = (uint32_t)ld(ba, 4); float b; memcpy(&b, &bb, 4);
					acc[i][j] = fmaf(a, b, acc[i][j]);
				}
			}
		for (uint64_t i = 0; i < nr; i++) for (uint64_t j = 0; j < nc; j++) E->check(E->u, Cm + (r0 + i) * ldc + (c0 + j) * 4, 4, 1);
		for (uint64_t i = 0; i < nr; i++) for (uint64_t j = 0; j < nc; j++) {
			uint64_t ca = Cm + (r0 + i) * ldc + (c0 + j) * 4;
			float cv = 0; if (beta != 0) { uint32_t cb = (uint32_t)ld(ca, 4); memcpy(&cv, &cb, 4); }
			float res = fmaf(alpha, acc[i][j], beta != 0 ? beta * cv : 0.0f);
			uint32_t rb; memcpy(&rb, &res, 4);
			st(ca, 4, rb);
		}
		C->velems += nr * nc * K;
		*rr += T;
		if (*rr >= M) { *rr = 0; *rc += T; }
		/* the registers are the progress: committed after each tile */
		RG[op[1].r] = *rr; RG[op[2].r] = *rc;
	}
}

/* ---- one instruction of a strip ----------------------------------------------------------------------------------- */
static void vop(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	C->vops++;
	switch (vi->op) {
	case VO_VLEN: x->lr[op[0].r] = (uint64_t)(x->inblock ? x->vl : VBYTES / vi->lsz); return;
	case VO_ADD: case VO_SUB: case VO_SUBR: case VO_MUL: case VO_MIN: case VO_MAX: case VO_MINU: case VO_MAXU: case VO_ABD: case VO_ABDU:
	case VO_AND: case VO_OR: case VO_XOR: case VO_SHL: case VO_SHR: case VO_SAR: case VO_ADDS: case VO_SUBS: case VO_ADDSU: case VO_SUBSU:
	case VO_MOV: case VO_NEG: case VO_MLA: case VO_FMA: case VO_FNMA:
		vop_lane(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_FMAB: vop_fmab(x, vi, in); C->velems += x->nact; return;
	case VO_DOT: case VO_DOTU: case VO_DOTSU: vop_dot(x, vi, in); C->velems += x->nact; return;
	case VO_ACC: case VO_MAXACC: case VO_MINACC: vop_reduce(x, vi, in); C->velems += x->nact; return;
	case VO_FIR: vop_fir(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_CLR: {
		if (x->inblock && !x->first) return;				/* a vclr inside a block is the block's preamble: the first strip only */
		for (int i = 0; i < (int)op[1].v && ((op[0].r + i) & 15) == op[0].r + i; i++) { memset(VR(op[0].r + i), 0, VBYTES); C->vacc |= (uint16_t)1 << (op[0].r + i); }
		return;
	}
	case VO_LD: case VO_ST: case VO_STS: case VO_LDT: case VO_STT: case VO_LSEG: case VO_SSEG: vop_mem(x, vi, in); C->velems += x->nact; return;
	case VO_LDX: vop_gather(x, vi, in); C->velems += x->nact; return;
	case VO_TCLR: case VO_TMOPA: case VO_TADD: case VO_TLD: case VO_TST: vop_tile(x, vi, in); C->velems += (uint64_t)vtile_n(vi) * vtile_n(vi); return;
	case VO_GEMM: C->vops--; vop_gemm(x, in); return;
	}
	die("vector instruction not defined", vi->op);
}

static int vec_is_standalone(int op) { return op == VO_VLEN || op == VO_CLR || op == VO_TCLR || op == VO_TADD || op == VO_TLD || op == VO_TST || op == VO_GEMM; }

static void vec_commit(struct vctx *x)
{
	vflush(x);
	for (int i = 0; i < 32; i++) RG[i] = x->lr[i];
}

/* ---- the block ----------------------------------------------------------------------------------------------------- */
struct vdec { struct einsn in; const struct vinfo *vi; };
static struct vctx VXS;

static void vec_run(const struct einsn *vin, uint64_t start, int nvec)
{
	struct vdec body[VMAXBODY];
	int nb = 0, found_end = 0, firstlen = 0;
	uint64_t addr = start + 2 * (uint64_t)nvec, endpc;
	struct vctx *x = &VXS;
	/* the body: vector instructions up to vend; with no vend before something else, the one instruction after vec */
	for (;;) {
		uint16_t par[5];
		par[0] = (uint16_t)E->fetch(E->u, addr);
		int n = enc_len_p0(&enc_tab, par[0]);
		if (!n) die("vec: illegal instruction in the block", 0);
		for (int i = 1; i < n; i++) par[i] = (uint16_t)E->fetch(E->u, addr + 2 * i);
		struct einsn in;
		if (enc_decode(&enc_tab, par, n, &in, NULL) != n) die("vec: illegal instruction in the block", 0);
		const struct vinfo *vi = &VI[in.mn];
		if (HT[in.mn].kind != H_VEC || vi->op == VO_VEC) {
			if (nb == 0) die("vec: a vector instruction must follow", 0);
			break;
		}
		addr += 2 * (uint64_t)n;
		if (vi->op == VO_VEND) { found_end = 1; break; }
		if (nb == VMAXBODY) die("vec: block too long", 0);
		if (nb == 0) firstlen = n;
		body[nb].in = in; body[nb].vi = vi; nb++;
	}
	if (found_end) endpc = addr;
	else { nb = 1; endpc = start + 2 * (uint64_t)nvec + 2 * (uint64_t)firstlen; }	/* the one-instruction prefix */
	if (nb == 0) { pc = endpc; return; }
	/* the strip: the widest lane of the block, and the element size and the pointer of the first stream */
	int lanemax = 1, esz = 0, nfst = 1;
	int rs = vin->op[0].r, re = vin->op[1].r;
	for (int i = 0; i < nb; i++) {
		const struct vinfo *vi = body[i].vi;
		if (vi->lsz > lanemax && vi->op != VO_TCLR) lanemax = vi->lsz;
	}
	for (int i = 0; i < nb && !esz; i++) {
		const struct vinfo *vi = body[i].vi;
		const struct eop *m = &body[i].in.op[1];
		if (vi->op >= VO_LD && vi->op <= VO_SSEG && vi->op != VO_LDX && m->k == EK_PI && m->r == rs) {
			esz = (vi->op == VO_LDT || vi->op == VO_STT) ? (int)body[i].in.op[2].v : vi->msz;	/* a strided stream moves by its stride */
			nfst = vi->nseg ? vi->nseg : 1;
		}
	}
	if (!esz) die("vec: no instruction of the block moves the pointer register by (Rs)+", 0);
	int vl = VBYTES / lanemax;
	C->vblocks++;
	/* hidden accumulation (a vclr in the block, an accumulator named before it, a tile written): hidden state is not saved at a context switch (R435), so an abort
	   restarts the block from its entry and discards the accumulators (vec-isa.md 4.1, the second option).  Otherwise the pointers are the progress and the block
	   goes on from the strip it stopped at. */
	int hidden = C->vacc != 0, touch = 0;
	for (int i = 0; i < nb; i++) {
		int o = body[i].vi->op;
		if (o == VO_CLR) hidden = 1;
		if (o == VO_TMOPA || o == VO_TADD || o == VO_TLD) { hidden = 1; touch |= 1 << (body[i].in.op[0].r & 7); }
	}
	C->progress = !hidden; C->vhidden = hidden; C->vtouch = (uint8_t)touch;
	x->vl = vl; x->inblock = 1; x->nsq = 0;
	for (long strip = 0; ; strip++) {
		uint64_t cur = RG[rs], end = RG[re];
		if (end <= cur) break;
		uint64_t rem = (end - cur) / ((uint64_t)esz * nfst);
		if (rem == 0) break;
		x->nact = rem < (uint64_t)vl ? (int)rem : vl;
		x->first = strip == 0;
		x->nsq = 0;
		for (int i = 0; i < 32; i++) x->lr[i] = RG[i];
		for (int v = 0; v < 16; v++) if (!(C->vacc >> v & 1)) memset(VR(v), 0, VBYTES);
		for (int i = 0; i < 16; i++) x->src[i].valid = 0;
		for (int i = 0; i < nb; i++) vop(x, body[i].vi, &body[i].in);
		C->vstrips++;
		vec_commit(x);
		if (RG[rs] == cur) die("vec: the pointer register does not move", 0);
		if (strip > (1L << 26)) die("vec: runaway block", 0);
	}
	C->vhidden = 0;
	pc = endpc;
}

static void vec_step(const struct einsn *in, uint64_t start, int n)
{
	const struct vinfo *vi = &VI[in->mn];
	if (vi->op == VO_VEND) return;							/* a stray vend does nothing */
	if (vi->op == VO_VEC) { vec_run(in, start, n); return; }
	if (!vec_is_standalone(vi->op)) die("vector instruction outside a vec block", 0);
	struct vctx *x = &VXS;
	for (int i = 0; i < 32; i++) x->lr[i] = RG[i];
	x->inblock = 0; x->first = 1; x->nsq = 0; x->nact = VBYTES;
	for (int i = 0; i < 16; i++) x->src[i].valid = 0;
	C->progress = vi->op == VO_GEMM;
	vop(x, vi, in);
	vec_commit(x);
}

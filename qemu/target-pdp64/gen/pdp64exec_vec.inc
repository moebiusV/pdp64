/* The vec block (docs/encoding-work/vec-isa.md; wave 1: errata 170, wave 2: errata 171; the tile, the GEMM unit and the gather were removed there), for the shared executor.  Included by pdp64exec_enc.inc, which
 * shares its statics (C, E, RG, ld, st, die, step).  The family was added to be benchmarked and pruned (errata 161); the semantics here are vec-isa.md's (section "wave 1" for the words of errata 170):
 *
 *   - A block is `vec Rs, Re`, instructions, `vend`.  It is run whole by the `vec` instruction (an interrupt waits for the end of the block in this executor).  The
 *     instructions up to `vend` are decoded once; with no `vend` before something that is not a vector instruction, the block is the one instruction after `vec`.
 *   - A strip is VL elements.  This implementation's strip is VSTRIP bytes (32 unless the host sets cpu->vstrip: 8, 16, 32 or 64; sim64 -S), so VL is VSTRIP over the widest
 *     lane type that the block uses; the last strip is shorter.  The strip is the implementation's choice, not the program's: a program must not depend on it (docs/encoding-work/vec-strip.md).  The elements of the stream are those of the first instruction whose memory operand is (Rs)+, in its access size, and `Re` is the end.
 *   - The hidden registers v0..v15 are in struct pdp64_cpu.  The registers that are not accumulators (vclr) are zero at the start of each strip.
 *   - The integer registers a strip changes (the (Ra)+ pointers, the reduction targets) are changed in a copy and committed when the strip ends; the stores of a strip
 *     are held and made when it ends, after their addresses have been checked: a fault in a strip leaves the registers as they were at its start, and a block
 *     without accumulators restarts where it stopped (an abort keeps the progress); a block with accumulators restarts from its entry.
 *   - Statistics (struct pdp64_cpu: vblocks, vstrips, vops, velems) count what the benchmarks need, and vcycles, vcyc_comp, vcyc_mem, vmemstrips the cycle MODEL of docs/sim64.md
 *     (one cycle for each vector instruction in a strip, a commit cost for each strip, the memory port; a model with stated parameters, not a measurement of hardware).
 *
 * Choices the documents leave open: the sliding window's centre is (taps-1)/2 (the hand-written kernel reads 3 before and 4 after for 8 taps); the elements of a
 * floating-point register in an integer register are binary32 in the low 32 bits (f) or binary64 (d).
 * Nothing of wave 1 keeps state from one strip to the next: vdacc and vsad add to a register that is committed at the end of the strip like vacc; vtbl reads its table
 * (exactly 16 bytes of memory at (Ra): the register form was removed, errata 173) and its index within the strip; the rounding of vavg, vmulhr, vsarr, vshrr and vsts is arithmetic of the lane.
 */
#define VBYTES 64			/* the storage of a vector register: the largest strip; the strip in use is VSTRIP */
#define VSTRIP (C->vstrip ? C->vstrip : 32)	/* the strip in bytes (the host sets cpu->vstrip; 0 is the default, 32) */
#define VPORT (C->vport ? C->vport : 16)		/* the model's memory port, bytes a cycle */
#define VCOMMIT (C->vcommit_set ? C->vcommit : 1)	/* the model's cost of committing a strip, cycles */
#define VMAXBODY 64
#define VROW (C->vrow_set ? C->vrow : 1)		/* the model's cost of the row advance of a vec2 block, cycles a row */
#define VMAXSKIP 4		/* the streams a vec2 block can advance by a pitch (vskip): four adders */
#define VSQMAX 1024

enum {
	VO_NONE = 0, VO_VEC, VO_VEND, VO_FIN, VO_VEC2, VO_SKIP,
	VO_ADD, VO_SUB, VO_SUBR, VO_MUL, VO_MIN, VO_MAX, VO_MINU, VO_MAXU, VO_ABD, VO_ABDU, VO_AND, VO_OR, VO_XOR, VO_SHL, VO_SHR, VO_SAR,
	VO_ADDS, VO_SUBS, VO_ADDSU, VO_SUBSU, VO_MOV, VO_NEG, VO_MLA, VO_FMA, VO_FNMA, VO_FMAB, VO_DOT, VO_DOTU, VO_DOTSU,
	VO_AVG, VO_AVGU, VO_MULH, VO_MULHU, VO_MULHR, VO_SARR, VO_SHRR, VO_TBL, VO_DACC, VO_SAD,
	VO_CEQ, VO_CGT, VO_CGTU, VO_BSL, VO_CVT,
	VO_ACC, VO_MAXACC, VO_MINACC, VO_FIR, VO_CLR,
	VO_LD, VO_ST, VO_STS, VO_LDT, VO_STT, VO_LSEG, VO_SSEG
};

struct vinfo {
	uint8_t op, nseg;
	uint8_t lsz, lfl;		/* the lane type: bytes, floating point */
	uint8_t msz, msign, mfl;	/* the memory type: bytes, sign-extending, floating point */
};
static struct vinfo *VI;

#include "pdp64exec_vecbases.inc"	/* vbases[]: base mnemonic -> VO_ operation, generated from spec/facts/vec.toml (tools/gen-vec-names.py) */

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
	case VO_VEC: case VO_VEC2: case VO_SKIP: case VO_VEND: case VO_FIN: case VO_BSL: return nt == 0;			/* vbsl has no lane suffix: it selects bits */
	case VO_CVT: {							/* vcvt.<from>.<to>: l, lu <-> f (32-bit lanes); lsz 4, lfl: the source is float, msign: the integer side is signed, mfl: the result is float */
		if (nt != 2) return 0;
		int fr_f = !strcmp(tok[0], "f"), to_f = !strcmp(tok[1], "f");
		const char *in = fr_f ? tok[1] : tok[0];
		if (fr_f == to_f || (strcmp(in, "l") && strcmp(in, "lu"))) return 0;
		vi->lsz = 4; vi->lfl = (uint8_t)fr_f; vi->mfl = (uint8_t)to_f; vi->msign = !strcmp(in, "l");
		return 1;
	}
	case VO_LD: case VO_LDT: case VO_LSEG:			/* .m[.lane] */
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
	case VO_DACC: case VO_SAD: {						/* vdacc.b .bu .bsu .w, vsad.bu: the source lane in lsz; the mode (0 signed x signed, 1 unsigned x unsigned, 2 signed x unsigned) in msz */
		if (nt != 1) return 0;
		if (op == VO_SAD) { if (strcmp(tok[0], "bu")) return 0; vi->lsz = 1; vi->msz = 1; return 1; }
		if (!strcmp(tok[0], "b")) { vi->lsz = 1; vi->msz = 0; return 1; }
		if (!strcmp(tok[0], "bu")) { vi->lsz = 1; vi->msz = 1; return 1; }
		if (!strcmp(tok[0], "bsu")) { vi->lsz = 1; vi->msz = 2; return 1; }
		if (!strcmp(tok[0], "w")) { vi->lsz = 2; vi->msz = 0; return 1; }
		return 0;
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
	uint64_t cyc_c, cyc_m;		/* the model: this strip's compute cycles and memory-port cycles */
	uint64_t mb;			/* the second model: the bytes the instruction just run moved over the memory port */
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
/* the stores of a strip (their addresses were checked, in the order of the elements, by vprecheck before the strip began) */
static void vflush(struct vctx *x)
{
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

/* the cycle model: a memory instruction of a strip occupies the port for bytes / VPORT cycles (rounded up) */
static void vmodel_mem(struct vctx *x, uint64_t bytes) { if (x->inblock) { x->cyc_m += (bytes + (uint64_t)VPORT - 1) / (uint64_t)VPORT; x->mb += bytes; } }

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
static uint64_t vstore_elem(const uint8_t *src, const struct vinfo *vi, int sat, int sh)
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
	if (sh > 0) { __int128 y = ((__int128)x + ((__int128)1 << (sh - 1))) >> sh; x = y > INT64_MAX ? INT64_MAX : y < INT64_MIN ? INT64_MIN : (int64_t)y; }	/* the rounding shift of the narrowing store: round half up, exact */
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
	if (vi->op == VO_CEQ || vi->op == VO_CGT || vi->op == VO_CGTU) {			/* the lane mask: all ones or zero, an integer lane of the size compared; a NaN compares false, -0.0 equals +0.0 */
		for (int i = 0; i < n; i++) {
			const uint8_t *a = A + i * sz, *b = B + i * sz;
			int t;
			if (vi->lfl) { double p = lget_f(a, sz), q = lget_f(b, sz); t = vi->op == VO_CEQ ? p == q : p > q; }
			else if (vi->op == VO_CGTU) t = lget_u(a, sz) > lget_u(b, sz);
			else t = vi->op == VO_CEQ ? lget_u(a, sz) == lget_u(b, sz) : lget_s(a, sz) > lget_s(b, sz);
			lput(out + i * sz, sz, t ? ~(uint64_t)0 : 0);
		}
		memcpy(D, out, VBYTES); return;
	}
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
			case VO_AVG: uz = (uint64_t)((p + q + 1) >> 1); break;				/* the sum in a wider type, rounded up: (a + b + 1) >> 1 */
			case VO_AVGU: uz = (up + uq + 1) >> 1; break;
			case VO_MULH: uz = (uint64_t)((p * q) >> 16); break;				/* .w: the high 16 bits of the 32-bit product */
			case VO_MULHU: uz = (up * uq) >> 16; break;
			case VO_MULHR: { int64_t r = (p * q + 0x4000) >> 15; uz = (uint64_t)(r > 32767 ? 32767 : r); break; }	/* Q15, round half up, saturating (only -32768 x -32768 saturates) */
			case VO_SARR: uz = (uint64_t)(uq == 0 ? p : uq > (uint64_t)bits ? 0 : (p + ((int64_t)1 << (uq - 1))) >> uq); break;	/* exact: (x + 2^(s-1)) >> s, the sum not wrapped */
			case VO_SHRR: uz = uq == 0 ? up : uq > (uint64_t)bits ? 0 : (up + ((uint64_t)1 << (uq - 1))) >> uq; break;
			default: die("vector integer lane operation not defined", vi->op);
			}
			lput(out + i * sz, sz, uz);
		}
	}
	memcpy(D, out, VBYTES);
}

/* vcvt.<from>.<to>: the 32-bit lanes of the strip, int32 (signed l, unsigned lu) to binary32 (round to nearest even, as FCVTLS) and binary32 to int32 as the scalar FCVTSL
   does it: truncate toward zero, then saturate; a NaN gives the largest value.  The unsigned form: a negative value or -0 gives 0, a NaN or a value of 2^32 or more gives
   0xffffffff (as FCVTDQU does for 64 bits).  No flag is set (the lane operations never touch FPSR). */
static void vop_cvt(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	uint8_t out[VBYTES];
	const uint8_t *A = VR(op[1].r);
	memcpy(out, VR(op[0].r), VBYTES);
	for (int i = 0; i < x->nact; i++) {
		uint32_t r;
		if (vi->mfl) {							/* integer to float */
			float f = vi->msign ? (float)(int32_t)lget_u(A + 4 * i, 4) : (float)(uint32_t)lget_u(A + 4 * i, 4);
			memcpy(&r, &f, 4);
		} else {
			float f; uint32_t b = (uint32_t)lget_u(A + 4 * i, 4);
			memcpy(&f, &b, 4);
			if (vi->msign) r = (uint32_t)(isnan(f) ? INT32_MAX : f >= 2147483648.0f ? INT32_MAX : f < -2147483648.0f ? INT32_MIN : (int32_t)f);
			else r = isnan(f) ? 0xffffffffu : f >= 4294967296.0f ? 0xffffffffu : f <= -1.0f ? 0 : (uint32_t)f;
		}
		lput(out + 4 * i, 4, r);
	}
	memcpy(VR(op[0].r), out, VBYTES);
}

/* vbsl vD, vM, vA, vB: vD = (vM & vA) | (~vM & vB), bitwise over the whole register; vD may be any of the sources (all are read before vD is written) */
static void vop_bsl(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	(void)x; (void)vi;
	const struct eop *op = in->op;
	uint8_t out[VBYTES];
	const uint8_t *M = VR(op[1].r), *A = VR(op[2].r), *B = VR(op[3].r);
	for (int i = 0; i < VBYTES; i++) out[i] = (uint8_t)((M[i] & A[i]) | (~M[i] & B[i]));
	memcpy(VR(op[0].r), out, VBYTES);
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
	int k = vi->lsz == 2 ? 2 : 4;							/* vdot.w: two 16-bit products a 32-bit lane; vdot.b: four byte products */
	int nl = (x->nact + k - 1) / k;
	for (int i = 0; i < nl; i++) {
		int64_t s = lget_s(D + 4 * i, 4);
		for (int m = 0; m < k; m++) {
			int j = k * i + m;
			if (j >= x->nact) break;
			if (k == 2) s += lget_s(A + 2 * j, 2) * lget_s(B + 2 * j, 2);
			else {
				int64_t p = vi->op == VO_DOTU ? (int64_t)A[j] : (int64_t)(int8_t)A[j], q = vi->op == VO_DOT ? (int64_t)(int8_t)B[j] : (int64_t)B[j];
				s += p * q;
			}
		}
		lput(D + 4 * i, 4, (uint64_t)s);
	}
}

/* vdacc.<b|bu|bsu|w> Rd, vA, vB: Rd += the exact sum of all the products of the strip (not wrapped to 32 bits: a vdot.w lane of two products can reach 2^31).
   vsad.bu Rd, vA, vB: Rd += the sum of |a - b| over the byte lanes, unsigned.  The register is committed with the strip, as vacc. */
static void vop_dacc(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	const uint8_t *A = VR(op[1].r), *B = VR(op[2].r);
	int64_t sum = 0;
	for (int i = 0; i < x->nact; i++) {
		if (vi->op == VO_SAD) { int a = A[i], b = B[i]; sum += a > b ? a - b : b - a; continue; }
		int64_t p, q;
		if (vi->lsz == 2) { p = lget_s(A + 2 * i, 2); q = lget_s(B + 2 * i, 2); }
		else { p = vi->msz == 1 ? (int64_t)A[i] : (int64_t)(int8_t)A[i]; q = vi->msz == 0 ? (int64_t)(int8_t)B[i] : (int64_t)B[i]; }
		sum += p * q;
	}
	x->lr[op[0].r] += (uint64_t)sum;
}

/* vtbl.b vD, (Ra), vI: lane i of vD is the byte of the table that the index lane i names, and 0 if the index is 16 or more (unsigned).  The table is exactly 16 bytes at (Ra), read
   once for each strip, the same for every lane whatever the strip's length (errata 173: there is no register form, whose table was the lanes of a register and so the strip). */
static void vop_tbl(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	(void)vi;
	const struct eop *op = in->op;
	uint8_t tab[16], out[VBYTES];
	const uint8_t *I = VR(op[2].r);
	struct vmem m; vmem_of(x, &op[1], &m);
	for (int i = 0; i < 16; i++) tab[i] = (uint8_t)ld(m.addr + (uint64_t)i, 1);
	vmodel_mem(x, 16);
	memset(out, 0, sizeof out);
	for (int i = 0; i < x->nact; i++) {
		unsigned ix = I[i];
		if (ix < 16) out[i] = tab[ix];
	}
	memcpy(VR(op[0].r), out, VBYTES);
}

static void vop_reduce(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	const uint8_t *S = VR(op[1].r);
	int sz = vi->lsz, asz = vi->op == VO_ACC ? vi->msz : sz;		/* the lanes' size; the accumulate width of vacc (the strip's VL does not count it) */
	uint64_t *Rd = &x->lr[op[0].r];
	if (vi->lfl && vi->op == VO_ACC) {					/* the canonical order of a floating-point sum (errata 173, vec-isa.md section 8): the lanes of the stream are taken in chunks of 16 bytes
									   of the source type (4 binary32, 2 binary64: the least strip); each chunk is summed by the fixed tree ((l0 + l1) + (l2 + l3)) and added to the register in the accumulate
									   precision, the chunks one after the other in element order; a chunk the end of the region cuts short has the lanes it has.  A strip is a whole number of
									   chunks (the assembler sees to it), so the strip does not change the order. */
		int ch = 16 / sz, n = x->nact;
		if (asz == 4) {
			float acc = (float)rget_f(*Rd, 4);
			for (int c0 = 0; c0 < n; c0 += ch) {
				int m = n - c0 < ch ? n - c0 : ch;
				float l[4], t;
				for (int k = 0; k < m; k++) l[k] = (float)lget_f(S + (c0 + k) * sz, sz);
				t = m == 1 ? l[0] : m == 2 ? l[0] + l[1] : m == 3 ? (l[0] + l[1]) + l[2] : (l[0] + l[1]) + (l[2] + l[3]);
				acc = acc + t;
			}
			*Rd = rput_f((double)acc, 4);
		} else {
			double acc = rget_f(*Rd, 8);
			for (int c0 = 0; c0 < n; c0 += ch) {
				int m = n - c0 < ch ? n - c0 : ch;
				double l[4], t;
				for (int k = 0; k < m; k++) l[k] = lget_f(S + (c0 + k) * sz, sz);
				t = m == 1 ? l[0] : m == 2 ? l[0] + l[1] : m == 3 ? (l[0] + l[1]) + l[2] : (l[0] + l[1]) + (l[2] + l[3]);
				acc = acc + t;
			}
			*Rd = rput_f(acc, 8);
		}
	} else if (vi->lfl) {							/* vmaxacc.f / vminacc.f: in element order (a comparison is exact, so the order is only visible in the sign of a zero and a NaN, and it is the stream's) */
		double acc = rget_f(*Rd, asz);
		for (int i = 0; i < x->nact; i++) {
			double v = lget_f(S + i * sz, sz);
			if (vi->op == VO_MAXACC) { if (v > acc) acc = v; } else if (v < acc) acc = v;
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
	vmodel_mem(x, (op_ == VO_LDT || op_ == VO_STT) ? (uint64_t)n * (uint64_t)esz : (uint64_t)n * (uint64_t)nf * (uint64_t)esz);
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
			for (int i = 0; i < n; i++) vput_store(x, m.addr + ((uint64_t)i * nf + f) * esz, esz, vstore_elem(S + i * vi->lsz, vi, op_ == VO_STS, op_ == VO_STS && in->nops == 3 ? (int)op[2].v : 0));
		}
		if (m.adj_reg >= 0) x->lr[m.adj_reg] += (uint64_t)n * nf * esz;
		return;
	case VO_LDT: case VO_STT: {
		int64_t stride = op[2].v;
		for (int i = 0; i < n; i++) {
			uint64_t a = m.addr + (uint64_t)((int64_t)i * stride);
			if (op_ == VO_LDT) { if (!i) memset(VR(v), 0, VBYTES); vload_elem(VR(v) + i * vi->lsz, a, vi); }
			else vput_store(x, a, esz, vstore_elem(VR(v) + i * vi->lsz, vi, 0, 0));
		}
		if (op_ == VO_LDT) x->src[v].valid = 0;
		if (m.adj_reg >= 0) x->lr[m.adj_reg] += (uint64_t)((int64_t)n * stride);
		return;
	}
	}
}

/* ---- one instruction of a strip ----------------------------------------------------------------------------------- */
static void vop(struct vctx *x, const struct vinfo *vi, const struct einsn *in)
{
	const struct eop *op = in->op;
	C->vops++;
	if (x->inblock) x->cyc_c += vi->op == VO_FIR ? (uint64_t)op[3].v : vi->op == VO_CLR && !x->first ? 0 : vi->op == VO_ACC && vi->lfl ? (uint64_t)((x->nact * vi->lsz + 15) / 16) : 1;	/* the model: one cycle an instruction in a strip, a vfir one a tap, a floating-point sum one for each 16-byte chunk (the chunks are added to the register one after the other: errata 173); a vclr only in the first strip */
	switch (vi->op) {
	case VO_ADD: case VO_SUB: case VO_SUBR: case VO_MUL: case VO_MIN: case VO_MAX: case VO_MINU: case VO_MAXU: case VO_ABD: case VO_ABDU:
	case VO_AND: case VO_OR: case VO_XOR: case VO_SHL: case VO_SHR: case VO_SAR: case VO_ADDS: case VO_SUBS: case VO_ADDSU: case VO_SUBSU:
	case VO_MOV: case VO_NEG: case VO_MLA: case VO_FMA: case VO_FNMA: case VO_AVG: case VO_AVGU: case VO_MULH: case VO_MULHU: case VO_MULHR: case VO_SARR: case VO_SHRR:
		vop_lane(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_CEQ: case VO_CGT: case VO_CGTU: vop_lane(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_CVT: vop_cvt(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_BSL: vop_bsl(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_FMAB: vop_fmab(x, vi, in); C->velems += x->nact; return;
	case VO_DOT: case VO_DOTU: case VO_DOTSU: vop_dot(x, vi, in); C->velems += x->nact; return;
	case VO_ACC: case VO_MAXACC: case VO_MINACC: vop_reduce(x, vi, in); C->velems += x->nact; return;
	case VO_DACC: case VO_SAD: vop_dacc(x, vi, in); C->velems += x->nact; return;
	case VO_TBL: vop_tbl(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_FIR: vop_fir(x, vi, in); x->src[op[0].r & 15].valid = 0; C->velems += x->nact; return;
	case VO_CLR: {
		if (x->inblock && !x->first) return;				/* a vclr inside a block is the block's preamble: the first strip only */
		for (int i = 0; i < (int)op[1].v && ((op[0].r + i) & 15) == op[0].r + i; i++) { memset(VR(op[0].r + i), 0, VBYTES); C->vacc |= (uint16_t)1 << (op[0].r + i); }
		return;
	}
	case VO_LD: case VO_ST: case VO_STS: case VO_LDT: case VO_STT: case VO_LSEG: case VO_SSEG: vop_mem(x, vi, in); C->velems += x->nact; return;
	}
	die("vector instruction not defined", vi->op);
}

static int vec_is_standalone(int op) { return op == VO_CLR; }

static void vec_commit(struct vctx *x)
{
	vflush(x);
	for (int i = 0; i < 32; i++) RG[i] = x->lr[i];
}

/* ---- the second cycle model (docs/sim64.md, docs/encoding-work/vec-latency.md) ----------------------------------------------------------------
 * A latency model: the host sets, for each instruction class (enum VC_*), a latency and an interval in cycles (from logic depth: a table that is an ASSUMPTION), the memory's load-to-use latency
 * (vmemlat) and the strips in flight (vpipe).  Per block, from the cycle 0 of the block: vector instructions issue in order, one a cycle (a vfir one for each tap); an instruction issues when its
 * source registers are ready (a scoreboard on v0..v15: a result is ready `latency` cycles after issue, no forwarding between stages beyond that), the unit of its class has accepted the last
 * instruction of the class `interval` cycles ago, the destination has no older pending write (a younger write completes later), and, for a memory instruction, the one memory port is free (it holds
 * the port bytes / port cycles, rounded up, as the first model).  A load's data is ready vmemlat + the class latency of the alignment after the last beat; a store reads its register at issue and
 * is done after the merge.  A reduction (vacc vdacc vsad vmaxacc vminacc) adds into its scalar register once its tree is done, the next strip's add one cycle after.  A strip ends when its last
 * result and store are done, plus the commit cost.  Strip k + vpipe may start issuing only when strip k has ended (vpipe 1: strips do not overlap); a block that reads a scalar register that one
 * of its reductions writes, waits for the previous strip to end whatever vpipe says; the registers that vclr named accumulators keep their ready times from strip to strip (a loop-carried
 * dependency through them), the others are taken as renamed for each strip (for vpipe > 1 that is a register file for each strip in flight, which the area figures do not contain).
 * A counter only: nothing here changes what the program computes. */
static const char *const vclass_names[VC_N] = { "alu", "cmp", "bsl", "shift", "narrow", "mul8", "mul16", "mulh16", "mul32", "mul64", "dot", "dacc", "sad", "acc", "mmacc", "fir", "tbl", "lseg", "sseg", "cvt",
	"fma", "fma64", "ld", "st", "misc" };
const char *pdp64_vclass_name(int c) { return c >= 0 && c < VC_N ? vclass_names[c] : NULL; }

struct vm2d {
	uint8_t cls, taps, isld, isst;		/* the class; a vfir's taps; a load; a store */
	uint8_t nar, seg;			/* vsts narrows (adds the narrowing class); a segment load or store (adds that class to the load or store) */
	uint8_t mtab;			/* vtbl with its table in memory */
	int8_t red;			/* the integer register that a reduction adds into, else -1 */
	uint8_t fpacc, chunks;		/* a floating-point sum (vacc.f, .f.d, .d): the 16-byte chunks of a strip, added to the register one after the other (errata 173) */
	uint16_t src, dst;		/* the v registers read, written */
	uint32_t sread;			/* the integer registers read (not counting a reduction's own accumulation) */
};
struct vm2 {
	uint64_t slot, port, end, ready[16], sready[32], unit[VC_N], comp[16];	/* the next issue cycle; the cycle the port is free; the end of the last strip; ready times; strip ends in a ring */
	int sdep;
};
static struct vm2 VM2;

static void vm2_decode(const struct vinfo *vi, const struct einsn *in, struct vm2d *d)
{
	const struct eop *op = in->op;
	memset(d, 0, sizeof *d); d->red = -1;
	int lsz = vi->lsz, o = vi->op, nf = vi->nseg ? vi->nseg : 1;
	int fp = vi->lfl;
#define VSRC(i) do { if ((i) < in->nops && op[i].k == EK_V) d->src |= (uint16_t)(1u << (op[i].r & 15)); } while (0)
#define VDST(i) do { d->dst |= (uint16_t)(1u << (op[i].r & 15)); } while (0)
	switch (o) {
	case VO_ADD: case VO_SUB: case VO_SUBR: case VO_MIN: case VO_MAX: case VO_MINU: case VO_MAXU: case VO_ABD: case VO_ABDU: case VO_AND: case VO_OR: case VO_XOR: case VO_MOV: case VO_NEG:
	case VO_ADDS: case VO_SUBS: case VO_ADDSU: case VO_SUBSU: case VO_AVG: case VO_AVGU:
		d->cls = fp && o != VO_MIN && o != VO_MAX && o != VO_MOV && o != VO_NEG ? (lsz == 8 ? VC_FMA64 : VC_FMA) : VC_ALU; break;
	case VO_SHL: case VO_SHR: case VO_SAR: case VO_SARR: case VO_SHRR: d->cls = VC_SHIFT; break;
	case VO_MUL: case VO_MULH: case VO_MULHU: case VO_MULHR: case VO_MLA:
		if (fp) d->cls = lsz == 8 ? VC_FMA64 : VC_FMA;
		else d->cls = lsz == 1 ? VC_MUL8 : lsz == 2 ? (o == VO_MUL ? VC_MUL16 : VC_MULH16) : lsz == 4 ? VC_MUL32 : VC_MUL64;
		break;
	case VO_FMA: case VO_FNMA: case VO_FMAB: d->cls = lsz == 8 ? VC_FMA64 : VC_FMA; break;
	case VO_DOT: case VO_DOTU: case VO_DOTSU: d->cls = VC_DOT; break;
	case VO_CEQ: case VO_CGT: case VO_CGTU: d->cls = VC_CMP; break;
	case VO_BSL: d->cls = VC_BSL; break;
	case VO_CVT: d->cls = VC_CVT; break;
	case VO_TBL: d->cls = VC_TBL; break;
	case VO_DACC: d->cls = VC_DACC; break;
	case VO_SAD: d->cls = VC_SAD; break;
	case VO_ACC: d->cls = VC_ACC; d->fpacc = (uint8_t)fp; break;
	case VO_MAXACC: case VO_MINACC: d->cls = VC_MMACC; break;
	case VO_FIR: d->cls = VC_FIR; d->taps = (uint8_t)op[3].v; break;
	case VO_LD: case VO_LDT: d->cls = VC_LD; d->isld = 1; break;
	case VO_LSEG: d->cls = VC_LD; d->isld = 1; d->seg = VC_LSEG; break;
	case VO_ST: case VO_STT: d->cls = VC_ST; d->isst = 1; break;
	case VO_STS: d->cls = VC_ST; d->isst = 1; d->nar = 1; break;
	case VO_SSEG: d->cls = VC_ST; d->isst = 1; d->seg = VC_SSEG; break;
	default: d->cls = VC_MISC; break;
	}
	switch (o) {
	case VO_ST: case VO_STS: case VO_STT: d->src |= (uint16_t)(1u << (op[0].r & 15)); break;
	case VO_SSEG: for (int f = 0; f < nf; f++) d->src |= (uint16_t)(1u << ((op[0].r + f) & 15)); break;
	case VO_LD: case VO_LDT: VDST(0); break;
	case VO_LSEG: for (int f = 0; f < nf; f++) d->dst |= (uint16_t)(1u << ((op[0].r + f) & 15)); break;
	case VO_DACC: case VO_SAD: VSRC(1); VSRC(2); d->red = (int8_t)op[0].r; break;
	case VO_ACC: case VO_MAXACC: case VO_MINACC: VSRC(1); d->red = (int8_t)op[0].r; break;
	case VO_FIR: VDST(0); VSRC(1); break;
	case VO_CLR: for (int i = 0; i < (int)op[1].v && ((op[0].r + i) & 15) == op[0].r + i; i++) d->dst |= (uint16_t)(1u << (op[0].r + i)); break;
	default:
		VDST(0); VSRC(1); VSRC(2); VSRC(3);
		if (o == VO_MLA || o == VO_FMA || o == VO_FNMA || o == VO_FMAB || o == VO_DOT || o == VO_DOTU || o == VO_DOTSU) d->src |= d->dst;	/* the destination is also an accumulator input */
		if (o == VO_TBL && op[1].k != EK_V) d->mtab = 1;
		break;
	}
	/* the integer registers the instruction reads */
	for (int i = 0; i < in->nops; i++) {
		if (d->red >= 0 && i == 0) continue;
		if (op[i].k == EK_R) d->sread |= 1u << (op[i].r & 31);
		else if ((op[i].k == EK_B || op[i].k == EK_PI || op[i].k == EK_PD || op[i].k == EK_X) && op[i].r != EBASE_DP) d->sread |= 1u << (op[i].r & 31);
		if (op[i].k == EK_X) d->sread |= 1u << (op[i].x & 31);
	}
	if (o == VO_FIR && op[2].k == EK_R) for (int k = 0; k < d->taps; k++) d->sread |= 1u << ((op[2].r + k) & 31);
}

/* a new block: no strips yet, the ready times zero; does a reduction's register get read by the block (a dependency from strip to strip through the scalar register)? */
static void vm2_begin(const struct vm2d *d, int nb)
{
	struct vm2 *m = &VM2;
	memset(m, 0, sizeof *m);
	uint32_t rd = 0, rr = 0;
	for (int i = 0; i < nb; i++) { rd |= d[i].sread; if (d[i].red >= 0) rr |= 1u << (d[i].red & 31); }
	m->sdep = (rd & rr) != 0;
	C->v2sdep += m->sdep;
}

/* one strip: schedule its instructions (d[0..nb-1]), the bytes each moved over the port in mbytes[]; returns the cycles this strip added to the block's timeline */
static uint64_t vm2_strip(const struct vm2d *d, const uint64_t *mbytes, int nb, long strip, int first)
{
	struct vm2 *m = &VM2;
	int N = C->vpipe < 1 ? 1 : C->vpipe > 16 ? 16 : C->vpipe;
	uint64_t t0 = m->slot, done = 0;
	if (strip >= N && m->comp[(strip - N) & 15] > t0) t0 = m->comp[(strip - N) & 15];
	if (strip >= 1 && m->sdep && m->comp[(strip - 1) & 15] > t0) t0 = m->comp[(strip - 1) & 15];
	m->slot = t0;
	for (int v = 0; v < 16; v++) if (!(C->vacc >> v & 1)) m->ready[v] = 0;		/* not an accumulator: zero at the start of the strip, renamed */
	for (int i = 0; i < nb; i++) {
		const struct vm2d *e = &d[i];
		if (e->cls == VC_MISC && e->dst && !first) continue;						/* a vclr inside a block runs in the first strip only */
		uint64_t occ = mbytes[i] ? (mbytes[i] + (uint64_t)VPORT - 1) / (uint64_t)VPORT : 0;
		uint64_t lat = (uint64_t)C->vlat[e->cls], t = m->slot;
		if (e->isld) lat = (occ ? occ - 1 : 0) + (uint64_t)C->vmemlat + (uint64_t)C->vlat[VC_LD] + (e->seg ? (uint64_t)C->vlat[e->seg] : 0);
		else if (e->mtab) lat += (occ ? occ - 1 : 0) + (uint64_t)C->vmemlat;
		else if (e->isst) lat = (occ ? occ - 1 : 0) + (uint64_t)C->vlat[VC_ST] + (e->nar ? (uint64_t)C->vlat[VC_NARROW] : 0) + (e->seg ? (uint64_t)C->vlat[e->seg] : 0);
		else if (e->cls == VC_FIR) lat += (uint64_t)(e->taps ? e->taps - 1 : 0);
		else if (e->fpacc && e->chunks > 1) lat += (uint64_t)(e->chunks - 1) * (uint64_t)C->vlat[VC_FMA];	/* the chain of chunk adds through the register: each a floating-point add */
		for (int v = 0; v < 16; v++) if (e->src >> v & 1 && m->ready[v] > t) t = m->ready[v];
		if (occ && m->port > t) t = m->port;
		if (m->unit[e->cls] > t) t = m->unit[e->cls];
		if (!e->isst) for (int v = 0; v < 16; v++) if (e->dst >> v & 1 && m->ready[v] > t + lat) t = m->ready[v] - lat;	/* a write completes after the older pending one */
		uint64_t res = t + lat;
		C->v2n[(e->isld || e->isst) && e->seg ? e->seg : e->cls]++;
		if (e->red >= 0) { uint64_t step = e->fpacc ? (uint64_t)(e->chunks ? e->chunks : 1) * (uint64_t)C->vlat[VC_FMA] : 1; if (m->sready[e->red & 31] + step > res) res = m->sready[e->red & 31] + step; m->sready[e->red & 31] = res; }	/* a floating-point sum: the register's recurrence is the chain of its chunks */
		if (!e->isst) for (int v = 0; v < 16; v++) if (e->dst >> v & 1) m->ready[v] = res;
		m->slot = t + (e->cls == VC_FIR && e->taps ? e->taps : 1);
		if (occ) m->port = t + occ;
		m->unit[e->cls] = t + (uint64_t)(C->vint[e->cls] < 1 ? 1 : C->vint[e->cls]);
		if (res > done) done = res;
	}
	uint64_t end = (done > m->slot ? done : m->slot) + (uint64_t)VCOMMIT;
	if (end < m->end) end = m->end;
	m->comp[strip & 15] = end;
	uint64_t add = end - m->end;
	m->end = end;
	return add;
}

/* ---- the first fault of a strip (errata 173, vec-isa.md section 8): EVA is strip independent ----------------------------------------------------------------
 * Before a strip runs, every memory access it will make is listed with the element of the stream it belongs to (the elements of the strip are e0 + lane; the table of vtbl, the scalar of vfmab and
 * an epilogue are the strip's first element, e0) and the instruction, and the checks (alignment, mapping, permission: E->check, which raises the abort) are made in the order (element, instruction,
 * field), not in the order of the strip.  The abort is therefore that of the access with the least element, the first instruction among equals, whatever the strip: EVA and the cause are the same at
 * every strip width.  Nothing has been done when it is raised (no register changed, no store made, no load), so the strip is annulled whole.  The accesses the strip then makes cannot fault. */
struct vacs { int64_t e; int ord; uint64_t a; int sz; int wr; };
static int vacs_cmp(const void *p, const void *q)
{
	const struct vacs *a = p, *b = q;
	if (a->e != b->e) return a->e < b->e ? -1 : 1;
	return a->ord - b->ord;
}
struct vdec { struct einsn in; const struct vinfo *vi; };
static struct vacs VACS[VSQMAX * 4];
static void vprecheck(struct vctx *x, const struct vdec *body, int nb, int64_t e0)
{
	uint64_t lr[32];
	struct vsrc src[16];
	int na = 0, n = x->nact;
	memcpy(lr, x->lr, sizeof lr);
	memcpy(src, x->src, sizeof src);
#define VADD(E_, ORD, A, SZ, WR) do { if (na < (int)(sizeof VACS / sizeof *VACS)) { VACS[na].e = (E_); VACS[na].ord = (ORD); VACS[na].a = (A); VACS[na].sz = (SZ); VACS[na].wr = (WR); na++; } } while (0)
	for (int ii = 0; ii < nb; ii++) {
		const struct vinfo *vi = body[ii].vi;
		const struct eop *op = body[ii].in.op;
		int o = vi->op, nf = vi->nseg ? vi->nseg : 1, esz = vi->msz;
		uint64_t base = 0; int adj = -1;
		if (o == VO_LD || o == VO_ST || o == VO_STS || o == VO_LDT || o == VO_STT || o == VO_LSEG || o == VO_SSEG || (o == VO_TBL)) {
			const struct eop *e = o == VO_TBL ? &op[1] : &op[1];
			if (e->k == EK_B) base = (e->r == EBASE_DP ? dp : lr[e->r]) + e->v;
			else if (e->k == EK_PI) { base = lr[e->r]; adj = e->r; }
			else continue;
		}
		switch (o) {
		case VO_LD: case VO_LSEG: case VO_ST: case VO_STS: case VO_SSEG: {
			int wr = o == VO_ST || o == VO_STS || o == VO_SSEG;
			for (int i = 0; i < n; i++) for (int f = 0; f < nf; f++) VADD(e0 + i, ii * 16 + f, base + ((uint64_t)i * nf + f) * esz, esz, wr);
			if (!wr) for (int f = 0; f < nf; f++) src[(op[0].r + f) & 15] = (struct vsrc){ 1, base + (uint64_t)f * esz, (int64_t)esz * nf, esz, vi->msign, vi->mfl, vi->lsz, vi->lfl };
			if (adj >= 0) lr[adj] += (uint64_t)n * nf * esz;
			break;
		}
		case VO_LDT: case VO_STT: {
			int64_t stride = op[2].v;
			for (int i = 0; i < n; i++) VADD(e0 + i, ii * 16, base + (uint64_t)((int64_t)i * stride), esz, o == VO_STT);
			if (o == VO_LDT) src[op[0].r & 15].valid = 0;
			if (adj >= 0) lr[adj] += (uint64_t)((int64_t)n * stride);
			break;
		}
		case VO_TBL:
			for (int i = 0; i < 16; i++) VADD(e0, ii * 16 + i, base + (uint64_t)i, 1, 0);
			src[op[0].r & 15].valid = 0;
			break;
		case VO_FMAB:
			VADD(e0, ii * 16, lr[op[2].r], vi->lsz, 0);
			lr[op[2].r] += vi->lsz;
			break;
		case VO_FIR: {
			int taps = (int)op[3].v, c = (taps - 1) / 2;
			const struct vsrc *sv = &src[op[1].r & 15];
			if (sv->valid) for (int j = -c; j < n + taps - 1 - c; j++) if (j < 0 || j >= n) VADD(e0 + j, ii * 16, sv->addr + (uint64_t)((int64_t)j * sv->stride), sv->msz, 0);
			src[op[0].r & 15].valid = 0;
			break;
		}
		case VO_ADD: case VO_SUB: case VO_SUBR: case VO_MUL: case VO_MIN: case VO_MAX: case VO_MINU: case VO_MAXU: case VO_ABD: case VO_ABDU:
		case VO_AND: case VO_OR: case VO_XOR: case VO_SHL: case VO_SHR: case VO_SAR: case VO_ADDS: case VO_SUBS: case VO_ADDSU: case VO_SUBSU:
		case VO_MOV: case VO_NEG: case VO_MLA: case VO_FMA: case VO_FNMA: case VO_AVG: case VO_AVGU: case VO_MULH: case VO_MULHU: case VO_MULHR: case VO_SARR: case VO_SHRR:
		case VO_CEQ: case VO_CGT: case VO_CGTU: case VO_CVT: case VO_BSL:
			src[op[0].r & 15].valid = 0;
			break;
		}
	}
#undef VADD
	if (na > 1) qsort(VACS, (size_t)na, sizeof *VACS, vacs_cmp);
	for (int i = 0; i < na; i++) E->check(E->u, VACS[i].a, VACS[i].sz, VACS[i].wr);
}

/* ---- the block ----------------------------------------------------------------------------------------------------- */
static struct vctx VXS;
/* the hardware's hidden copy made at a vec that has hidden accumulation (the address of the vec, the accumulators it names): vrun is the block running, valid from its entry until it
   ends; one that is still valid at the next vec was aborted, and becomes vrst, the copy a restart at the same address uses (a handler's own blocks do not touch it) */
static uint64_t vrun_pc, vrst_pc;
static uint16_t vrun_acc, vrst_acc;
static int vrun_valid, vrst_valid;

/* one strip of the instructions body[0..nb): its registers as the strip sees them, the checks of its accesses, the instructions, the model; the commit is the caller's */
static void vstrip_run(struct vctx *x, const struct vdec *body, int nb, int64_t e0)
{
	for (int i = 0; i < 32; i++) x->lr[i] = RG[i];
	for (int v = 0; v < 16; v++) if (!(C->vacc >> v & 1)) memset(VR(v), 0, VBYTES);
	for (int i = 0; i < 16; i++) x->src[i].valid = 0;
	x->nsq = 0;
	vprecheck(x, body, nb, e0);
}

/* the row advance of a 2D block (errata 176), on the registers L (the strip's copy, committed with the strip that ends the row, or the registers themselves for an empty row): every vskip pointer moves by its
   gap register, Re moves by the row width and the gap of the first stream's pointer, the row count falls by one.  Gap and width registers are read only in the block, so the order does not matter */
static void vrow_advance(uint64_t *L, int rs, int re, int rn, int rw, int nskip, const int *sp, const int *sg)
{
	uint64_t g1 = 0;
	for (int k = 0; k < nskip; k++) if (sp[k] == rs) g1 = L[sg[k]];
	for (int k = 0; k < nskip; k++) L[sp[k]] += L[sg[k]];
	L[re] += L[rw] + g1;
	L[rn] -= 1;
	C->vrows++;
}

static void vec_run(const struct einsn *vin, uint64_t start, int nvec)
{
	struct vdec body[VMAXBODY];
	int nb = 0, found_end = 0, firstlen = 0, fin = -1;
	int two = VI[vin->mn].op == VO_VEC2, nskip = 0, sp[VMAXSKIP], sg[VMAXSKIP];			/* the 2D block (errata 176): vec2 Rs, Re, Rn, Rw and the vskip declarations that follow it */
	uint64_t addr = start + 2 * (uint64_t)nvec, endpc;
	struct vctx *x = &VXS;
	/* the body: vector instructions up to vend (a vfin splits it into the instructions of every strip and the epilogue); with no vend before something else, the one instruction after vec */
	for (;;) {
		uint16_t par[5];
		par[0] = (uint16_t)E->fetch(E->u, addr);
		int n = enc_len_p0(&enc_tab, par[0]);
		if (!n) die("vec: illegal instruction in the block", 0);
		for (int i = 1; i < n; i++) par[i] = (uint16_t)E->fetch(E->u, addr + 2 * i);
		struct einsn in;
		if (enc_decode(&enc_tab, par, n, &in, NULL) != n) die("vec: illegal instruction in the block", 0);
		const struct vinfo *vi = &VI[in.mn];
		if (HT[in.mn].kind != H_VEC || vi->op == VO_VEC || vi->op == VO_VEC2) {
			if (nb == 0) die("vec: a vector instruction must follow", 0);
			break;
		}
		addr += 2 * (uint64_t)n;
		if (vi->op == VO_SKIP) {						/* vskip Ra, Rg: only between vec2 and the body, at most VMAXSKIP of them, each pointer once */
			if (!two || nb || fin >= 0 || nskip == VMAXSKIP) die("vskip: only after vec2, before the body, at most four", 0);
			for (int k = 0; k < nskip; k++) if (sp[k] == in.op[0].r) die("vskip: the register is declared twice", 0);
			sp[nskip] = in.op[0].r; sg[nskip] = in.op[1].r; nskip++;
			continue;
		}
		if (vi->op == VO_VEND) { found_end = 1; break; }
		if (vi->op == VO_FIN) { if (fin >= 0) die("vec: two vfin in a block", 0); fin = nb; continue; }
		if (nb == VMAXBODY) die("vec: block too long", 0);
		if (nb == 0) firstlen = n;
		body[nb].in = in; body[nb].vi = vi; nb++;
	}
	if (two && !found_end) die("vec2: a 2D block ends with vend", 0);
	if (found_end) endpc = addr;
	else { nb = 1; fin = -1; endpc = start + 2 * (uint64_t)nvec + 2 * (uint64_t)firstlen; }	/* the one-instruction prefix */
	if (nb == 0) { pc = endpc; return; }
	int nmain = fin >= 0 ? fin : nb;
	/* the strip: the widest lane of the block, and the element size and the pointer of the first stream */
	int lanemax = 1, esz = 0, nfst = 1, hasfmab = 0;
	int rs = vin->op[0].r, re = vin->op[1].r;
	for (int i = 0; i < nb; i++) {
		const struct vinfo *vi = body[i].vi;
		if (vi->lsz > lanemax) lanemax = vi->lsz;
		if (vi->op == VO_FMAB) hasfmab = 1;
	}
	for (int i = 0; i < nmain && !esz; i++) {
		const struct vinfo *vi = body[i].vi;
		const struct eop *m = &body[i].in.op[1];
		if (vi->op >= VO_LD && vi->op <= VO_SSEG && m->k == EK_PI && m->r == rs) {
			esz = (vi->op == VO_LDT || vi->op == VO_STT) ? (int)body[i].in.op[2].v : vi->msz;	/* a strided stream moves by its stride */
			nfst = vi->nseg ? vi->nseg : 1;
		}
	}
	if (!esz) die("vec: no instruction of the block moves the pointer register by (Rs)+", 0);
	int rn = vin->op[2].r, rw = vin->op[3].r;
	uint64_t unit = (uint64_t)esz * nfst;
	if (two) {
		/* the registers the block writes (the (Ra)+ pointers, the skipped pointers, Re, Rn, the targets of reductions) are not the registers it only reads (Rw, the skips), and Rs, Re, Rn, Rw are four different registers:
		   what a block computes must not depend on the order in which the hardware updates them (vec-2d.md) */
		uint32_t wr = 1u << (re & 31) | 1u << (rn & 31), rd = 1u << (rw & 31);
		if (rs == re || rs == rn || rs == rw || re == rn || re == rw || rn == rw) die("vec2: Rs, Re, Rn and Rw must be four different registers", 0);
		for (int i = 0; i < nb; i++) {
			const struct vinfo *vi = body[i].vi;
			for (int k = 0; k < 4; k++) if (body[i].in.op[k].k == EK_PI) wr |= 1u << (body[i].in.op[k].r & 31);
			if (vi->op == VO_ACC || vi->op == VO_MAXACC || vi->op == VO_MINACC || vi->op == VO_DACC || vi->op == VO_SAD) wr |= 1u << (body[i].in.op[0].r & 31);
			if (vi->op == VO_CLR || vi->op == VO_FMAB) die("vec2: a block with accumulators (vclr, vfmab) is not a 2D block", 0);
		}
		if (fin >= 0) die("vec2: a block with an epilogue (vfin) is not a 2D block", 0);
		for (int k = 0; k < nskip; k++) {
			if (sp[k] == re || sp[k] == rn || sp[k] == rw) die("vec2: a vskip names Re, Rn or Rw", 0);
			wr |= 1u << (sp[k] & 31); rd |= 1u << (sg[k] & 31);
		}
		if (wr & rd) die("vec2: Rw and the registers of the vskip declarations are read only: the block writes one of them", 0);
		if (C->vacc) die("vec2: accumulators are named before the block", 0);
	}
	C->vblocks++;
	if (found_end) C->vcycles++;						/* the model: the vend (the vec is one of the scalar instructions) */
	if (two) { C->v2blocks++; C->vskips += (uint64_t)nskip; C->vcycles += (uint64_t)nskip; }	/* and each vskip, a decode slot like the vend (an assumption: vec-2d.md) */
	/* hidden accumulation (a vclr in the block, an accumulator named before it, a vfin): hidden state is not saved at a context switch (R435), so an abort
	   restarts the block from its entry and discards the accumulators (vec-isa.md 4.1, the second option).  Otherwise the pointers are the progress and the block
	   goes on from the strip it stopped at. */
	if (vrun_valid) { vrst_pc = vrun_pc; vrst_acc = vrun_acc; vrst_valid = 1; }	/* a hidden block that did not end was aborted by a fault: its hidden copy is kept for the restart */
	vrun_valid = 0;
	if (vrst_valid && vrst_pc == start) {			/* the restart of an aborted hidden block: the naming of its accumulators is part of the hardware's copy made at the vec, so a handler that ran vector code of its own
								   (which names and clears accumulators too) does not change it; the accumulators themselves are discarded (zero) */
		C->vacc = vrst_acc;
		for (int v = 0; v < 16; v++) if (C->vacc >> v & 1) memset(VR(v), 0, VBYTES);
		vrst_valid = 0;
	}
	int hidden = C->vacc != 0 || fin >= 0;
	for (int i = 0; i < nb; i++) if (body[i].vi->op == VO_CLR) hidden = 1;
	/* the strip of a block with accumulators or a vfmab is 16 bytes on every implementation (errata 173, vec-isa.md section 8): an accumulator's lanes, and the number of strips a (Ra)+ of vfmab moves
	   its pointer for, are then the program's, not the hardware's; the other blocks take the implementation's strip */
	int vl = (hidden || hasfmab ? 16 : VSTRIP) / lanemax;
	if (vl < 1) vl = 1;
	struct vm2d m2d[VMAXBODY]; uint64_t m2mb[VMAXBODY];
	if (C->vm2) {									/* the second model: classify the block once */
		for (int i = 0; i < nb; i++) { vm2_decode(body[i].vi, &body[i].in, &m2d[i]); if (m2d[i].fpacc) m2d[i].chunks = (uint8_t)((vl * body[i].vi->lsz + 15) / 16); }
		vm2_begin(m2d, nmain);
		C->v2hidden += hidden;
		C->v2cycles += found_end + (two ? (uint64_t)nskip : 0);			/* the vend, the vskips */
	}
	if (hidden) { vrun_valid = 1; vrun_pc = start; vrun_acc = C->vacc; }		/* stays valid if a fault leaves this function; a block that ends clears it */
	C->progress = !hidden; C->vhidden = hidden;
	x->vl = vl; x->inblock = 1; x->nsq = 0;
	int64_t e0 = 0; long strip;
	if (two && RG[rw] == 0) { C->vhidden = 0; pc = endpc; return; }			/* a row of no width: nothing to do, nothing changes */
	if (two && RG[rw] % unit) die("vec2: the row width is not a whole number of elements of the first stream", 0);
	for (strip = 0; ; strip++) {
		uint64_t cur = RG[rs], end = RG[re];
		if (two) {
			if (RG[rn] == 0) break;
			if (end <= cur) {							/* an empty row (the end is not above the pointer): the advance only */
				vrow_advance(RG, rs, re, rn, rw, nskip, sp, sg);
				C->vcycles += (uint64_t)VROW;
				if (C->vm2) { VM2.slot += (uint64_t)VROW; VM2.end += (uint64_t)VROW; VM2.comp[(strip - 1) & 15] += (uint64_t)VROW; C->v2cycles += (uint64_t)VROW; }
				if (strip > (1L << 26)) die("vec2: runaway block", 0);
				continue;
			}
			if ((end - cur) % unit) die("vec2: Re - Rs is not a whole number of elements of the first stream", 0);
		} else if (end <= cur) break;
		uint64_t rem = (end - cur) / unit;
		if (rem == 0) break;
		x->nact = rem < (uint64_t)vl ? (int)rem : vl;
		x->first = strip == 0;
		vstrip_run(x, body, nmain, e0);
		x->cyc_c = x->cyc_m = 0;
		for (int i = 0; i < nmain; i++) { x->mb = 0; vop(x, body[i].vi, &body[i].in); m2mb[i] = x->mb; }
		if (C->vm2) C->v2cycles += vm2_strip(m2d, m2mb, nmain, strip, x->first);
		C->vstrips++;
		C->vcyc_comp += x->cyc_c; C->vcyc_mem += x->cyc_m;			/* the model: a strip takes the greater of the instructions it issues and the time its memory instructions hold the port, and a commit */
		C->vcycles += (x->cyc_c > x->cyc_m ? x->cyc_c : x->cyc_m) + (uint64_t)VCOMMIT;
		if (x->cyc_m > x->cyc_c) C->vmemstrips++;
		e0 += x->nact;
		if (two && x->lr[re] <= x->lr[rs]) {					/* the strip ended its row: the row advance is committed with it, so that a fault in the next row finds a consistent state */
			vrow_advance(x->lr, rs, re, rn, rw, nskip, sp, sg);
			C->vcycles += (uint64_t)VROW;
			if (C->vm2) { VM2.slot += (uint64_t)VROW; VM2.end += (uint64_t)VROW; VM2.comp[strip & 15] += (uint64_t)VROW; C->v2cycles += (uint64_t)VROW; }
		}
		vec_commit(x);
		if (!two && RG[rs] == cur) die("vec: the pointer register does not move", 0);
		if (strip > (1L << 26)) die("vec: runaway block", 0);
	}
	if (fin >= 0) {									/* the epilogue: one more strip of the block's lanes, after the last, that the accumulators' final values are read in (vec-isa.md section 8) */
		x->nact = vl; x->first = 0;
		vstrip_run(x, body + fin, nb - fin, e0);
		x->cyc_c = x->cyc_m = 0;
		for (int i = fin; i < nb; i++) { x->mb = 0; vop(x, body[i].vi, &body[i].in); m2mb[i] = x->mb; }
		if (C->vm2) C->v2cycles += vm2_strip(m2d + fin, m2mb + fin, nb - fin, strip, 0);
		C->vstrips++;
		C->vcyc_comp += x->cyc_c; C->vcyc_mem += x->cyc_m;
		C->vcycles += (x->cyc_c > x->cyc_m ? x->cyc_c : x->cyc_m) + (uint64_t)VCOMMIT;
		if (x->cyc_m > x->cyc_c) C->vmemstrips++;
		vec_commit(x);
	}
	C->vhidden = 0;
	vrun_valid = 0;
	C->vacc = 0;			/* the accumulators are named for this block only: the registers keep their values (a vclr before the block, then the results read after vend), but the next block starts with no
				   accumulators (without this every block after a vclr was "hidden" for good, restarted from its entry and kept the registers across strips: tests/sim/vec-restart.S) */
	pc = endpc;
}

static void vec_step(const struct einsn *in, uint64_t start, int n)
{
	const struct vinfo *vi = &VI[in->mn];
	if (vi->op == VO_VEND) return;							/* a stray vend does nothing */
	if (vi->op == VO_VEC || vi->op == VO_VEC2) { vec_run(in, start, n); return; }
	if (!vec_is_standalone(vi->op)) die("vector instruction outside a vec block", 0);
	struct vctx *x = &VXS;
	for (int i = 0; i < 32; i++) x->lr[i] = RG[i];
	x->inblock = 0; x->first = 1; x->nsq = 0; x->nact = VSTRIP;
	for (int i = 0; i < 16; i++) x->src[i].valid = 0;
	C->progress = 0;
	vop(x, vi, in);
	vec_commit(x);
}

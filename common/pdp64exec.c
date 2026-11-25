/* pdp64exec: what each pdp64 instruction does.  One source for every executor: sim64 uses it, and so does the QEMU target.
 *
 * The decoder is the table codec (pdp64enc.c, with the tables generated from spec/pdp64/pdp64.hbnf); the numbers of the instructions are the names of pdp64-consts.h.  This file holds the meaning only.  Everything that touches the
 * host (memory, faults, `trap`, `halt`) goes through the hooks of struct pdp64_env, so that an executor can map memory its own way.
 */
#include <fenv.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "fmt.h"
#include "pdp64-consts.h"
#include "pdp64exec.h"
#include "pdp64enc.h"

static struct pdp64_cpu *C;
static const struct pdp64_env *E;
#define r (C->r)
#define pc (C->pc)
#define dp (C->dp)
#define fpsr (C->fpsr)
#define fN (C->fN)
#define fZ (C->fZ)
#define fV (C->fV)
#define fC (C->fC)
#define cur_pc (C->cur_pc)
#define ld(a, n) E->ld(E->u, (a), (n))
#define st(a, n, v) E->st(E->u, (a), (n), (v))
/* a fault of the instruction itself.  With exceptions delivered it is an abort with this vector; otherwise it ends the program. */
static void fault_v(int vector, const char *what, uint64_t addr) __attribute__((noreturn));
static void fault_v(int vector, const char *what, uint64_t addr)
{
	if (C->deliver) E->raise(E->u, vector, addr);
	E->fault(E->u, what, addr);
}
#define die(what, addr) fault_v(VECTOR_ILLEGAL, (what), (addr))
#define MODE ((int)pdp64_mode(C))

static int64_t sext(uint64_t v, int bits) { return bits >= 64 ? (int64_t)v : (int64_t)(v << (64 - bits)) >> (64 - bits); }
static uint64_t zext(uint64_t v, int bits) { return bits >= 64 ? v : v & (((uint64_t)1 << bits) - 1); }
static int64_t ldx(uint64_t a, int size) { return sext(ld(a, size), size * 8); }

/* the atomic words: what each does to the word (errata 211; pdp64exec.h, struct pdp64_env atomic).  The signed forms compare the values as `size` bytes of a signed number. */
int pdp64_amo_result(int op, int size, uint64_t old, uint64_t a, uint64_t b, uint64_t *nv)
{
	uint64_t m = size >= 8 ? ~(uint64_t)0 : ((uint64_t)1 << (size * 8)) - 1;
	int64_t so = sext(old, size * 8), sa = sext(a, size * 8);
	switch (op) {
	case PDP64_AMO_SWAP: *nv = a & m; return 1;
	case PDP64_AMO_ADD: *nv = (old + a) & m; return 1;
	case PDP64_AMO_AND: *nv = old & a & m; return 1;
	case PDP64_AMO_OR: *nv = (old | a) & m; return 1;
	case PDP64_AMO_XOR: *nv = (old ^ a) & m; return 1;
	case PDP64_AMO_SMAX: *nv = (so > sa ? old : a) & m; return 1;
	case PDP64_AMO_SMIN: *nv = (so < sa ? old : a) & m; return 1;
	case PDP64_AMO_UMAX: *nv = (old > (a & m) ? old : a) & m; return 1;
	case PDP64_AMO_UMIN: *nv = (old < (a & m) ? old : a) & m; return 1;
	case PDP64_AMO_CAS: if (old != (a & m)) return 0; *nv = b & m; return 1;
	case PDP64_AMO_SC: if (old != (b & m)) return 0; *nv = a & m; return 1;
	}
	return 0;
}

enum { O_REG, O_MEM, O_IMM };
struct opnd { int kind, reg; uint64_t addr; int64_t imm; int adjust_reg; int64_t adjust; };

/* the memory-side operand of a decoded instruction.  The effect of (Rn)+ / -(Rn) on Rn is applied here; the stride is in the instruction. */
static void eoperand(uint64_t start, struct opnd *o);
/* the memory-side operand of the instruction being run: built by eoperand from the operand of the codec's instruction */
static void operand(const struct fmt *f, uint64_t start, struct opnd *o)
{
	(void)f;
	memset(o, 0, sizeof *o);
	o->adjust_reg = -1;
	eoperand(start, o);
}
static void after(const struct opnd *o) { if (o->adjust_reg >= 0) r[o->adjust_reg] += o->adjust; }
static uint64_t opval(struct opnd *o, int size, int sign)
{
	uint64_t v;
	if (o->kind == O_REG) v = r[o->reg];
	else if (o->kind == O_IMM) v = (uint64_t)o->imm;
	else { v = ld(o->addr, size); after(o); return sign ? (uint64_t)sext(v, size * 8) : v; }
	return sign ? (uint64_t)sext(v, size * 8) : zext(v, size * 8);
}
static void opset(struct opnd *o, int size, uint64_t v)
{
	if (o->kind == O_REG) r[o->reg] = (uint64_t)sext(v, size * 8);
	else if (o->kind == O_MEM) { st(o->addr, size, v); after(o); }
	else die("store to an immediate", 0);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* flags                                                                                                               */

static void nz(uint64_t v) { fN = v >> 63; fZ = v == 0; }
static uint64_t add_f(uint64_t a, uint64_t b, uint64_t cin)
{
	unsigned __int128 w = (unsigned __int128)a + b + cin;
	uint64_t res = (uint64_t)w;
	fC = (int)(w >> 64); fV = (int)(((a ^ res) & (b ^ res)) >> 63); nz(res);
	return res;
}
static uint64_t sub_f(uint64_t a, uint64_t b, uint64_t bin)
{
	uint64_t res = a - b - bin;
	fC = (a < b) || (a == b && bin); fV = (int)(((a ^ b) & (a ^ res)) >> 63); nz(res);
	return res;
}
static int cond(int c)
{
	switch (c) {
	case 0: return 1;
	case 1: return !fZ;
	case 2: return fZ;
	case 3: return !fN;
	case 4: return fN;
	case 5: return !fV;
	case 6: return fV;
	case 7: return !fC;
	case 8: return fC;
	case 9: return fN == fV;
	case 10: return fN != fV;
	case 11: return !fZ && fN == fV;
	case 12: return fZ || fN != fV;
	case 13: return !fC && !fZ;
	case 14: return fC || fZ;
	}
	return 0;
}
/* the condition c of the comparison a - b, for a decision, with no flag written: cbCC leaves N Z V C as they were (errata 39) */
static int cmp_taken(uint64_t a, uint64_t b, int c)
{
	int n = fN, z = fZ, v = fV, cy = fC, t;
	sub_f(a, b, 0);
	t = cond(c);
	fN = n; fZ = z; fV = v; fC = cy;
	return t;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* floating point: values are bits in general registers; the flags are recorded in fpsr and never trap                */

static int is_snan(uint64_t v) { return (v >> 52 & 0x7ff) == 0x7ff && (v & 0xfffffffffffffULL) && !(v >> 51 & 1); }
static double asd(uint64_t v) { double d; memcpy(&d, &v, 8); return d; }
/* a NaN result is always the canonical quiet NaN, whatever the host produced and whatever the operands carried (errata 26) */
static uint64_t fromd(double d) { uint64_t v; if (isnan(d)) return 0x7ff8000000000000ULL; memcpy(&v, &d, 8); return v; }
static float ass(uint64_t v) { uint32_t w = (uint32_t)v; float x; memcpy(&x, &w, 4); return x; }
static uint64_t froms(float x) { uint32_t w; if (isnan(x)) return 0x7fc00000; memcpy(&w, &x, 4); return (uint64_t)sext(w, 32); }
static void fp_begin(void) { feclearexcept(FE_ALL_EXCEPT); }
static void fp_end(void)
{
	int e = fetestexcept(FE_ALL_EXCEPT);
	if (e & FE_INEXACT) fpsr |= 1;
	if (e & FE_UNDERFLOW) fpsr |= 2;
	if (e & FE_OVERFLOW) fpsr |= 4;
	if (e & FE_DIVBYZERO) fpsr |= 8;
	if (e & FE_INVALID) fpsr |= 16;
}
static void fcmp_flags(double a, double b)
{
	fN = fZ = fV = fC = 0;
	if (isnan(a) || isnan(b)) { fV = 1; return; }
	fN = a < b; fZ = a == b;
}
static uint64_t cvt_to_q(double d, int uns)
{
	if (isnan(d)) { fpsr |= 16; return uns ? ~(uint64_t)0 : 0x7fffffffffffffffULL; }
	d = trunc(d);
	if (uns) {
		if (d < 0) { fpsr |= 16; return 0; }
		if (d >= 18446744073709551616.0) { fpsr |= 16; return ~(uint64_t)0; }
		return (uint64_t)d;
	}
	if (d >= 9223372036854775808.0) { fpsr |= 16; return 0x7fffffffffffffffULL; }
	if (d < -9223372036854775808.0) { fpsr |= 16; return 0x8000000000000000ULL; }
	return (uint64_t)(int64_t)d;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* helpers                                                                                                             */

static void push(uint64_t v) { r[14] -= 8; st(r[14], 8, v); }
static uint64_t pop(void) { uint64_t v = ld(r[14], 8); r[14] += 8; return v; }
static int clz64(uint64_t v) { return v ? __builtin_clzll(v) : 64; }
static int ctz64(uint64_t v) { return v ? __builtin_ctzll(v) : 64; }
static uint64_t ror64(uint64_t v, unsigned n) { n &= 63; return n ? (v >> n) | (v << (64 - n)) : v; }
static uint64_t bitrev64(uint64_t v) { uint64_t o = 0; for (int i = 0; i < 64; i++) o |= ((v >> i) & 1) << (63 - i); return o; }
static void clmul(uint64_t a, uint64_t b, uint64_t *lo, uint64_t *hi)
{
	uint64_t l = 0, h = 0;
	for (int i = 0; i < 64; i++) if ((b >> i) & 1) { l ^= a << i; if (i) h ^= a >> (64 - i); }
	*lo = l; *hi = h;
}


/* ------------------------------------------------------------------------------------------------------------------ */
/* binary16 (errata 27).  A half is the low 16 bits of a register, sign-extended like a binary32.  Every result is correctly rounded to
 * nearest even; the exception flags come from the rounding here, never from the host.  add, subtract, multiply are exact in a double,
 * divide and square root are correctly rounded in a double (53 bits is more than 2 * 11 + 2), so one more rounding gives the right
 * half; the fused multiply-adds are summed exactly in 128 bits.                                                                     */

typedef unsigned __int128 u128;
static int h_isnan(uint16_t h) { return (h & 0x7c00) == 0x7c00 && (h & 0x3ff); }
static int h_issnan(uint16_t h) { return h_isnan(h) && !(h & 0x200); }
static double h2d(uint16_t h)
{
	int e = (h >> 10) & 31, m = h & 1023;
	double v = e == 0 ? ldexp(m, -24) : e == 31 ? (m ? NAN : INFINITY) : ldexp(1024 + m, e - 25);
	return h >> 15 ? -v : v;
}
static int bitlen128(u128 v) { int n = 0; while (v) { n++; v >>= 1; } return n; }
/* mag >> sh rounded to nearest even; *inexact says whether anything was lost */
static u128 round_shift(u128 mag, int sh, int *inexact)
{
	u128 m, rem, half;
	if (sh <= 0) { *inexact = 0; return mag << -sh; }
	if (sh >= 127) { *inexact = 1; return 0; }
	m = mag >> sh; rem = mag & (((u128)1 << sh) - 1); half = (u128)1 << (sh - 1);
	*inexact = rem != 0;
	if (rem > half || (rem == half && (m & 1))) m++;
	return m;
}
/* the half nearest to sign * mag * 2^exp (mag > 0) */
static uint16_t roundhalf(uint16_t sign, u128 mag, int exp)
{
	int L = bitlen128(mag), E = exp + L - 1, inexact, tiny = 0;
	int q = E < -14 ? -24 : E - 10;
	u128 M = round_shift(mag, q - exp, &inexact);
	uint16_t bits;
	if (E < -14) {
		if (inexact) {					/* tininess is judged after rounding with an unbounded exponent */
			int ix2; u128 M11 = round_shift(mag, -25 - exp, &ix2);
			tiny = !(E == -15 && M11 == 2048);
		}
		bits = (uint16_t)M;				/* M = 1024 is the smallest normal number: exponent field 1, fraction 0 */
	} else {
		if (M == 2048) { M = 1024; E++; }
		if (E + 15 >= 31) { fpsr |= 4 | 1; return sign | 0x7c00; }
		bits = (uint16_t)(((E + 15) << 10) | (M - 1024));
	}
	if (inexact) fpsr |= 1;
	if (tiny) fpsr |= 2;
	return sign | bits;
}
static uint16_t d2h(double x)
{
	int e; double m; uint16_t sign = signbit(x) ? 0x8000 : 0;
	if (isnan(x)) return 0x7e00;
	if (isinf(x)) return sign | 0x7c00;
	if (x == 0) return sign;
	m = frexp(fabs(x), &e);				/* separate statements: the order of evaluation of arguments is not defined */
	return roundhalf(sign, (u128)(uint64_t)ldexp(m, 53), e - 53);
}
static uint64_t fromh(uint16_t h) { return (uint64_t)(int64_t)(int16_t)h; }
/* a finite half as integer * 2^exp */
static void h_parts(uint16_t h, int *neg, int64_t *m, int *exp)
{
	int e = (h >> 10) & 31;
	*neg = h >> 15;
	*m = e == 0 ? (h & 1023) : 1024 + (h & 1023);
	*exp = e == 0 ? -24 : e - 25;
}
static uint16_t fma16(uint16_t a, uint16_t b, uint16_t c, int negprod, int negc)
{
	int fin = ((a >> 10) & 31) != 31 && ((b >> 10) & 31) != 31 && ((c >> 10) & 31) != 31;
	if (h_issnan(a) || h_issnan(b) || h_issnan(c)) fpsr |= 16;
	if (fin) {
		int na, nb, nc, ea, eb, ec;
		int64_t ma, mb, mc;
		h_parts(a, &na, &ma, &ea); h_parts(b, &nb, &mb, &eb); h_parts(c, &nc, &mc, &ec);
		int pe = ea + eb, emin = pe < ec ? pe : ec;
		__int128 P = (__int128)(ma * mb) << (pe - emin), Cc = (__int128)mc << (ec - emin), S;
		if (na ^ nb ^ negprod) P = -P;
		if (nc ^ negc) Cc = -Cc;
		S = P + Cc;
		if (S != 0) return roundhalf(S < 0 ? 0x8000 : 0, (u128)(S < 0 ? -S : S), emin);
	}
	/* infinities, NaNs and an exact zero sum: the host's fused multiply-add has the right rules, and rounding a double result to a half
	   cannot differ from the exact one when the result is a special value or zero */
	{
		double v; feclearexcept(FE_ALL_EXCEPT);
		v = fma(negprod ? -h2d(a) : h2d(a), h2d(b), negc ? -h2d(c) : h2d(c));
		if (fetestexcept(FE_INVALID)) fpsr |= 16;
		return d2h(v);
	}
}
/* returns 1 if the instruction was a binary16 one */
static int half_op(int sub, const struct fmt *f, uint64_t *rd)
{
	uint16_t a = (uint16_t)r[f->low], b = (uint16_t)r[f->t], c = (uint16_t)r[f->x], d = (uint16_t)*rd, res;
	double x, y;
	int e;
	switch (sub) {
	case MN_FESC_FADD16: case MN_FESC_FSUB16: case MN_FESC_FMUL16: case MN_FESC_FDIV16:		/* rd <- rd op rs */
		if (h_issnan(a) || h_issnan(d)) fpsr |= 16;
		feclearexcept(FE_ALL_EXCEPT);
		x = h2d(d); y = h2d(a);
		res = d2h(sub == MN_FESC_FADD16 ? x + y : sub == MN_FESC_FSUB16 ? x - y : sub == MN_FESC_FMUL16 ? x * y : x / y);
		e = fetestexcept(FE_ALL_EXCEPT);
		if (e & FE_INVALID) fpsr |= 16;
		if (e & FE_DIVBYZERO) fpsr |= 8;
		*rd = fromh(res); return 1;
	case MN_FESC_FSQRT16:
		if (h_issnan(a)) fpsr |= 16;
		feclearexcept(FE_ALL_EXCEPT);
		res = d2h(sqrt(h2d(a)));
		if (fetestexcept(FE_INVALID)) fpsr |= 16;
		*rd = fromh(res); return 1;
	case MN_FESC_FCMP16:
		if (h_issnan(a) || h_issnan(d)) fpsr |= 16;
		fcmp_flags(h2d(d), h2d(a)); return 1;
	case MN_FESC_FMADD16: *rd = fromh(fma16(a, b, c, 0, 0)); return 1;
	case MN_FESC_FMSUB16: *rd = fromh(fma16(a, b, c, 0, 1)); return 1;
	case MN_FESC_FNMADD16: *rd = fromh(fma16(a, b, c, 1, 1)); return 1;
	case MN_FESC_FNMSUB16: *rd = fromh(fma16(a, b, c, 1, 0)); return 1;
	case MN_FESC_FCLASS16: {
		int sgn = a >> 15, ex = (a >> 10) & 31, m = a & 1023;
		unsigned k = ex == 31 ? (m ? ((a & 0x200) ? 1u << 9 : 1u << 8) : (sgn ? 1u << 0 : 1u << 7))
		    : ex == 0 ? (m ? (sgn ? 1u << 2 : 1u << 5) : (sgn ? 1u << 3 : 1u << 4)) : (sgn ? 1u << 1 : 1u << 6);
		*rd = k; return 1;
	}
	case MN_FESC_FCVTSH: {		/* binary32 to binary16 */
		uint32_t w = (uint32_t)r[f->low];
		if ((w & 0x7f800000) == 0x7f800000 && (w & 0x7fffff) && !(w & 0x400000)) fpsr |= 16;
		*rd = fromh(d2h((double)ass(r[f->low]))); return 1;
	}
	case MN_FESC_FCVTHS:
		if (h_issnan(a)) fpsr |= 16;
		*rd = froms((float)h2d(a)); return 1;
	case MN_FESC_FCVTDH: {		/* binary64 to binary16 */
		uint64_t v = r[f->low];
		if (is_snan(v)) fpsr |= 16;
		*rd = fromh(d2h(asd(v))); return 1;
	}
	case MN_FESC_FCVTHD:
		if (h_issnan(a)) fpsr |= 16;
		*rd = fromd(h2d(a)); return 1;
	case MN_FESC_FCVTHL:		/* binary16 to int32, toward zero; a NaN or an infinity is invalid and saturates */
		if (h_isnan(a) || (a & 0x7fff) == 0x7c00) { fpsr |= 16; *rd = (uint64_t)(int64_t)(h_isnan(a) || !(a >> 15) ? INT32_MAX : INT32_MIN); return 1; }
		x = h2d(a);
		if (trunc(x) != x) fpsr |= 1;
		*rd = (uint64_t)(int64_t)(int32_t)trunc(x); return 1;
	case MN_FESC_FCVTLH:
		*rd = fromh(d2h((double)(int32_t)r[f->low])); return 1;
	}
	return 0;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the processor status word, the banked registers, exception entry                                                    */

static int bank(int mode) { return mode == MODE_USER ? 2 : mode; }
#define HYP_BANK 3
#define GUEST() (C->hve && !C->h)							/* a guest is running (the hypervisor mode exists and H is clear) */
unsigned pdp64_psw(const struct pdp64_cpu *c);
static int psw_bad(uint64_t v)								/* a PSW with the reserved mode 2 in either mode field */
{
	return (v >> PSW_MODE & 3) == 2 || (v >> PSW_PREV & 3) == 2;
}
static void priv(void)
{
	if (C->h) return;								/* the hypervisor is privileged whatever the mode field says */
	if (MODE != MODE_KERNEL) fault_v(VECTOR_PRIVILEGED, "privileged instruction in user mode", 0);
}

/* Exception entry (docs/pdp64-system-architecture.md section 15): registers only, then the new PC from the table at the physical address vbr + 8 * vector.
   The new priority is the highest (7) for every exception and interrupt (errata 40), so nothing nests until the handler lowers it; the old one is in EPSW. */
/* An exit (errata 195, 196; design 2.1): a guest event goes to the hypervisor.  The vector word at HVBR + 8 * vector is read first (a failed read changes nothing and is a machine check of the hypervisor); then
   the exit registers are written, H is set (the banks switch), the status word is kernel mode with the guest's mode as the previous mode, priority 7, flags, trace and UA clear, and the PC is the word read.
   The guest's EPC, EPSW, EVA, ECAUSE, its system registers and its general registers are not touched. */
static void hexit(unsigned code, unsigned flags, int vector, uint64_t epc, uint64_t eva, uint64_t gpa, uint64_t insn)
{
	uint64_t target, at = C->hvbr + 8 * (uint64_t)vector;
	unsigned old;
	C->vec_phys = 1;
	if (E->vecread(E->u, at, &target)) E->fault(E->u, "machine check: the vector fetch of an exit failed", at);
	C->vec_phys = 0;
	old = pdp64_psw(C);
	C->hepc = epc; C->hepsw = old; C->heva = eva; C->hgpa = gpa; C->hinsn = insn; C->hexitr = code | flags; C->hcause = (uint64_t)vector;
	C->uacc = 0;
	C->resv_on = 0;									/* an exit clears any LL reservation: no mark of one level is found by another (errata 211) */
	pdp64_set_h(C, 1);
	pdp64_set_psw(C, MODE_KERNEL << PSW_MODE | (old >> PSW_MODE & 3) << PSW_PREV | PSW_FIELD(PRI, ~0u));
	C->vacc = 0;									/* the world switch clears the naming of the vector accumulators (errata 186 decision 13)*/
	C->wait = 0;
	pc = target;
	C->entered = 1;
}
/* the exit of an instruction: a trap (EPC is the next instruction; the instruction is not run, the hypervisor emulates it) if the bit of HTRAP is set.  1 if it exited.  Only a guest. */
static int gtrap(int bit, unsigned code)
{
	if (!GUEST() || !(C->htrap >> bit & 1)) return 0;
	hexit(code, 0, VECTOR_HEXIT, pc, 0, 0, C->cur_insn);
	return 1;
}
/* an event that always exits (no bit of HTRAP): 1 if it exited */
static int gexit(unsigned code)
{
	if (!GUEST()) return 0;
	hexit(code, 0, VECTOR_HEXIT, pc, 0, 0, C->cur_insn);
	return 1;
}
/* An exception or interrupt taken while H = 1 (the hypervisor's own: design 1.2 rule 2): the hypervisor's registers and vector base, exit code 0.  The guest's registers are not touched. */
static void enter_h(int vector, uint64_t epc, uint64_t eva)
{
	uint64_t target, at = C->hvbr + 8 * (uint64_t)vector;
	unsigned old;
	if (E->vecread(E->u, at, &target)) E->fault(E->u, "machine check: the vector fetch failed", at);
	old = pdp64_psw(C);
	C->hepc = epc; C->hepsw = old; C->heva = eva; C->hgpa = 0; C->hinsn = 0; C->hexitr = XCODE_TAKEN_AT_H; C->hcause = (uint64_t)vector;
	C->uacc = 0; C->resv_on = 0;
	pdp64_set_psw(C, MODE_KERNEL << PSW_MODE | (old >> PSW_MODE & 3) << PSW_PREV | PSW_FIELD(PRI, ~0u));
	C->vacc = 0;
	pc = target;
	C->entered = 1;
}
static void enter(int vector, uint64_t epc, uint64_t eva)
{
	uint64_t target, at = C->vbr + 8 * (uint64_t)vector;
	unsigned old;
	if (C->h) { enter_h(vector, epc, eva); return; }
	int rc = E->vecread(E->u, at, &target);
	if (rc) {
		/* an exit does not run the instruction again: the exit's EPC is the instruction itself if this entry is made by an instruction (a TRAP, BPT or check trap: nothing of it has an effect), the next instruction for an interrupt */
		uint64_t xpc = C->snap_valid ? cur_pc : epc;
		if (rc == 2 && GUEST()) {					/* stage 2 refused the vector fetch: an exit with nothing changed, VEC set (design 2.4, 2.5); the hypervisor fills stage 2 and the guest retries */
			int code = C->s2_code; C->s2_code = 0;
			hexit(code, C->s2_flags, VECTOR_GLFAULT, xpc, eva, C->s2_gpa, C->snap_valid ? C->cur_insn : 0);
			return;
		}
		if (GUEST()) { hexit(XCODE_MACHINE_CHECK, 0, VECTOR_MACHINE_CHECK, xpc, eva, at, 0); return; }	/* a machine check in a guest always exits (design 1.6 code 21) */
		E->fault(E->u, "machine check: the vector fetch failed", at);
	}
	old = pdp64_psw(C);
	C->epc = epc; C->epsw = old; C->eva = eva; C->ecause = (uint64_t)vector | (C->uacc ? 1u << 15 : 0);	/* bit 15: the fault was on the operand of a .u move (6.10.4) */
	C->uacc = 0; C->resv_on = 0;							/* every exception entry clears any LL reservation (errata 211) */
	pdp64_set_psw(C, MODE_KERNEL << PSW_MODE | (old >> PSW_MODE & 3) << PSW_PREV | PSW_FIELD(PRI, ~0u));	/* UA is clear in the new status word; EPSW keeps the old value (6.10.1) */
	C->vacc = 0;									/* every exception entry clears the naming of the vector accumulators (errata 186 decision 13, 6.14.9); the hardware's copy of a hidden block, vrun_* and vrst_*, is not touched. */
	pc = target;
	C->entered = 1;
}
/* The mask of a return to a lesser mode and of GENTER (manual 6.3.5, 6.14.9; docs/encoding-work/rejudge-holes-rti-resume-hv.md A8, A12): bit n of the mask keeps Rn, n = 0 to 31 except 14; every register
   whose bit is zero is cleared in the same step as the return.  R14 is the stack pointer of the mode returned to and is never cleared, so bit 14 names the vector registers and the floating-point flags
   instead: zero clears the sixteen vector registers, the naming of the accumulators and the flags in FPSR.  The caller has made every check that could refuse the instruction: nothing is cleared by an
   instruction that does not return. */
static void clear_unkept(uint32_t keep)
{
	for (int n = 0; n < 32; n++) if (n != 14 && !(keep >> n & 1)) r[n] = 0;
	if (!(keep >> RTIMASK_VECTOR & 1)) { memset(C->vr, 0, sizeof C->vr); C->vacc = 0; fpsr = 0; }
}
/* the rank of a mode for "a lesser mode": kernel above supervisor above user (the field values are 0, 1 and 3) */
static int mode_rank(int mode) { return mode == MODE_KERNEL ? 2 : mode == MODE_SUPERVISOR ? 1 : 0; }

/* The entry into a guest: GENTER #mask (design 2.2).  Legal at H = 1 only; at H = 0 (a guest used it) an exit, code 18; with no hypervisor an illegal instruction.  A reserved mode in HEPSW is an illegal
   instruction and nothing changes.  It includes an ISYNC (the earlier writes to PTBR, MMUCTL, ASID, VBR, GTBR and HTRAP take effect for what follows); then PSW := HEPSW, the hypervisor's bank is put away and
   the guest's loaded, PC := HEPC, H := 0, the naming of the vector accumulators is cleared (the world switch, errata 186 decision 13), and the registers the mask does not keep are cleared: a guest is always
   a lesser mode than the hypervisor. */
static void genter(uint32_t keep)
{
	if (!C->hve) die("illegal instruction", 0);
	priv();
	if (!C->h) { hexit(XCODE_HVREG, 0, VECTOR_HEXIT, pc, 0, 0, C->cur_insn); return; }
	if (psw_bad(C->hepsw)) die("genter: reserved mode in hepsw", 0);
	E->tlb(E->u, PDP64_TLB_SYNC, 0);
	C->resv_on = 0;									/* GENTER clears any LL reservation (errata 211) */
	pdp64_set_h(C, 0);
	pdp64_set_psw(C, (unsigned)C->hepsw);
	pc = C->hepc;
	C->vacc = 0;
	clear_unkept(keep);
	C->wait = 0;
	C->entered = 1;									/* the trace trap of the hypervisor's own T is not taken after it */
}

/* TLBIAS rN and TLBIGP rN (manual 6.8.3, 6.16.22).  TLBIAS is privileged and exits to the hypervisor under the same bit of HTRAP as TLBI; TLBIGP is the hypervisor's: an exit (code 18) at H = 0, illegal with no hypervisor. */
static void tlbx(int which, uint64_t v)
{
	if (which == MN_TLBX_TLBIGP) {
		if (!C->hve) die("illegal instruction", 0);
		priv();
		if (!C->h) { hexit(XCODE_HVREG, 0, VECTOR_HEXIT, pc, 0, 0, C->cur_insn); return; }
		E->tlb(E->u, PDP64_TLB_GPA, v);
		return;
	}
	priv();
	if (gtrap(HTRAP_TLBI, XCODE_TLB)) return;
	E->tlb(E->u, PDP64_TLB_ASID, v & 0xffff);
}

/* MFSR and MTSR of a hypervisor register (numbers 128 to 147) at H = 1.  HTRAP takes only its defined bits (a one in a reserved bit is an illegal instruction); the read-only registers refuse a write; GEVA and
   GECAUSE are the write aliases of the guest's EVA and ECAUSE, GKSP/GKDP/GSDP/GUDP the guest's banked R14 and DP (all three of the guest's banks are in their slots while H = 1). */
static void hv_sysreg(int write, unsigned num, int rd)
{
	uint64_t *sr, mask = ~(uint64_t)0, v;
	switch (num) {
	case SYSREG_HTRAP: sr = &C->htrap; mask = HTRAP_VALID; break;
	case SYSREG_HEXITR: sr = &C->hexitr; break;
	case SYSREG_HEPC: sr = &C->hepc; break;
	case SYSREG_HEPSW: sr = &C->hepsw; mask = PSW_VALID; break;
	case SYSREG_HEVA: sr = &C->heva; break;
	case SYSREG_HCAUSE: sr = &C->hcause; break;
	case SYSREG_HGPA: sr = &C->hgpa; break;
	case SYSREG_HINSN: sr = &C->hinsn; break;
	case SYSREG_HVBR: sr = &C->hvbr; break;
	case SYSREG_GTBR: sr = &C->gtbr; mask = GTBR_VALID; break;
	case SYSREG_VIRQ: sr = &C->virq; mask = (((uint64_t)1 << (VIRQ_LINES + 1)) - 1) & ~(uint64_t)1; break;	/* bit L is line L, 1 to 7; bit 0 reads as zero */
	case SYSREG_VIVEC: sr = &C->vivec; mask = ((uint64_t)1 << (VIRQ_LINES * VIRQ_VEC_WIDTH)) - 1; break;
	case SYSREG_VTOFF: sr = &C->vtoff; break;
	case SYSREG_VCPUID: sr = &C->vcpuid; mask = 0xffff; break;
	case SYSREG_GEVA: sr = &C->eva; break;
	case SYSREG_GECAUSE: sr = &C->ecause; break;
	case SYSREG_GKSP: sr = &C->spbank[bank(MODE_KERNEL)]; break;
	case SYSREG_GKDP: sr = &C->dpbank[bank(MODE_KERNEL)]; break;
	case SYSREG_GSDP: sr = &C->dpbank[bank(MODE_SUPERVISOR)]; break;
	case SYSREG_GUDP: sr = &C->dpbank[bank(MODE_USER)]; break;
	default: die("illegal instruction", 0);
	}
	if (!write) { r[rd] = *sr; return; }
	if (SYSREG_READONLY(num) && num != SYSREG_CPUID) die("illegal instruction", 0);
	v = r[rd];
	if (v & ~mask) die("illegal instruction", 0);					/* a one in an unused bit is refused where it is made (the software probes; an old version never ignores a request to trap); such a bit reads zero */
	if (num == SYSREG_VIVEC) for (int l = 0; l < VIRQ_LINES; l++) {			/* a vector below 32 is no interrupt vector (6.3.6): refused at once, not found when the line is raised; zero is "no vector" */
		unsigned vec = (unsigned)(v >> (VIRQ_VEC_WIDTH * l) & ((1u << VIRQ_VEC_WIDTH) - 1));
		if (vec != 0 && vec < 32) die("illegal instruction", 0);
	}
	if (num == SYSREG_GTBR) {
		uint64_t old = C->gtbr;
		*sr = v;
		fpsr = 0;									/* the floating-point flags belong to the process: a write of the guest tag or root clears them (the kernel restores the incoming one's) */
		if ((v ^ old) & (GTBR_VALID & ~((((uint64_t)1 << GTBR_WIDTH_TAG) - 1) << GTBR_TAG))) E->tlb(E->u, PDP64_TLB_GTBR, v);	/* a new root or enable discards every translation of the tag written (rule G-c) */
		else if (v != old) E->tlb(E->u, PDP64_TLB_SYNC, 0);									/* only the tag changed: nothing is discarded, the host's own buffer must not serve the old tag */
		return;
	}
	*sr = v;
	if (num == SYSREG_VTOFF && E->hv_event) E->hv_event(E->u, PDP64_HV_VTOFF);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* one instruction                                                                                                     */

static int moves_size(int opc)
{
	switch (opc) { case MN_MOV_MOVQ: case MOVSTORE_MOVQ: return 8; case MN_MOV_MOVL: case MOVSTORE_MOVL: case MN_MOVZ_MOVZL: return 4;
	case MN_MOV_MOVW: case MOVSTORE_MOVW: case MN_MOVZ_MOVZW: return 2; default: return 1; }
}

static void exec_fmt(struct fmt f, uint64_t start, int len);
static void step_enc(void);
static void step(void)
{
	cur_pc = pc;
	step_enc();
}

/* what an instruction of a group of the mnemonic numbering does (a struct fmt built from the codec's instruction by step_enc) */
static void exec_fmt(struct fmt f, uint64_t start, int len)
{
	int opc = f.opc;
	struct opnd o;

	if (opc <= OPGROUP_LEA) {							/* moves and LEA */
		if (opc == OPGROUP_LEA) {
			operand(&f, start, &o);
			if (o.kind != O_MEM) die("lea of a register or immediate", 0);
			r[f.reg] = o.addr; after(&o);
			return;
		}
		int size = moves_size(opc);
		int store = (opc == MOVSTORE_MOVQ || opc == MOVSTORE_MOVL || opc == MOVSTORE_MOVW || opc == MOVSTORE_MOVB);
		int zero = (opc >= MN_MOVZ_MOVZL && opc <= MN_MOVZ_MOVZB);
		operand(&f, start, &o);
		if (store) {
			uint64_t v = r[f.reg];
			opset(&o, size, v);							/* moves, loads and stores write no flags (errata 39) */
		} else {
			uint64_t v = opval(&o, size, !zero);
			r[f.reg] = v;
		}
		return;
	}
	if (opc >= MN_ALU_ADD && opc <= MN_ALU_FCMP) {					/* ALU, register destination */
		operand(&f, start, &o);
		uint64_t a = r[f.reg], b = opval(&o, 8, 0), res;
		switch (opc) {
		case MN_ALU_ADD: r[f.reg] = add_f(a, b, 0); break;
		case MN_ALU_SUB: r[f.reg] = sub_f(a, b, 0); break;
		case MN_ALU_CMP: sub_f(a, b, 0); break;
		case MN_ALU_BIC: res = a & ~b; nz(res); fV = 0; r[f.reg] = res; break;
		case MN_ALU_BIS: res = a | b; nz(res); fV = 0; r[f.reg] = res; break;
		case MN_ALU_BIT: res = a & b; nz(res); fV = 0; break;
		case MN_ALU_XOR: res = a ^ b; nz(res); fV = 0; r[f.reg] = res; break;
		case MN_ALU_AND: res = a & b; nz(res); fV = 0; r[f.reg] = res; break;
		case MN_ALU_MUL: {
			__int128 w = (__int128)(int64_t)a * (int64_t)b;
			res = (uint64_t)w; nz(res); fV = w != (__int128)(int64_t)res; r[f.reg] = res;
			break;
		}
		case MN_ALU_MULH: { __int128 w = (__int128)(int64_t)a * (int64_t)b; res = (uint64_t)(w >> 64); nz(res); fV = 0; r[f.reg] = res; break; }
		case MN_ALU_SHL: case MN_ALU_SHR: case MN_ALU_SAR: {
			/* the same flags for every count (errata 39): N and Z from the result (a count of 0 leaves the operand), V = 0, C = the last bit shifted out, 0 for a count of 0 */
			if (b == 0) { res = a; fC = 0; }
			else if (opc == MN_ALU_SHL) { res = b >= 64 ? 0 : a << b; fC = b <= 64 ? (int)((a >> (64 - b)) & 1) : 0; }
			else if (opc == MN_ALU_SHR) { res = b >= 64 ? 0 : a >> b; fC = b <= 64 ? (int)((a >> (b - 1)) & 1) : 0; }
			else { res = b >= 64 ? ((int64_t)a < 0 ? ~(uint64_t)0 : 0) : (uint64_t)((int64_t)a >> b); fC = b <= 64 ? (int)((a >> (b - 1)) & 1) : (int)(a >> 63); }
			nz(res); fV = 0; r[f.reg] = res;
			break;
		}
		case MN_ALU_FADD: fp_begin(); r[f.reg] = fromd(asd(a) + asd(b)); fp_end(); break;
		case MN_ALU_FSUB: fp_begin(); r[f.reg] = fromd(asd(a) - asd(b)); fp_end(); break;
		case MN_ALU_FMUL: fp_begin(); r[f.reg] = fromd(asd(a) * asd(b)); fp_end(); break;
		case MN_ALU_FCMP: fp_begin(); fcmp_flags(asd(a), asd(b)); if (is_snan(a) || is_snan(b)) fpsr |= 16; fp_end(); break;
		default: die("reserved ALU opcode", opc);
		}
		return;
	}
	if (opc == OPGROUP_SOP) {
		int sub = f.reg;
		operand(&f, start, &o);
		uint64_t v, res;
		switch (sub) {
		case MN_SOP_CLR: opset(&o, 8, 0); fN = 0; fZ = 1; fV = 0; fC = 0; return;
		case MN_SOP_COM: v = opval(&o, 8, 0); res = ~v; nz(res); fV = 0; fC = 1; break;
		case MN_SOP_INC: { int c = fC; v = opval(&o, 8, 0); res = add_f(v, 1, 0); fC = c; break; }
		case MN_SOP_DEC: { int c = fC; v = opval(&o, 8, 0); res = sub_f(v, 1, 0); fC = c; break; }
		case MN_SOP_NEG: v = opval(&o, 8, 0); res = sub_f(0, v, 0); break;
		case MN_SOP_TST: v = opval(&o, 8, 0); nz(v); fV = 0; fC = 0; return;
		case MN_SOP_ADC: v = opval(&o, 8, 0); res = add_f(v, 0, (uint64_t)fC); break;
		case MN_SOP_SBC: v = opval(&o, 8, 0); res = sub_f(v, 0, (uint64_t)fC); break;
		case MN_SOP_ASL: v = opval(&o, 8, 0); res = v << 1; fC = (int)(v >> 63); nz(res); fV = fN != fC; break;
		case MN_SOP_ASR: v = opval(&o, 8, 0); res = (uint64_t)((int64_t)v >> 1); fC = (int)(v & 1); nz(res); fV = 0; break;
		case MN_SOP_PUSHM: case MN_SOP_POPM: {
			uint32_t mask = (uint32_t)(o.imm & 0xFFFFFFFFu);
			if (sub == MN_SOP_PUSHM) { for (int n = 0; n < 32; n++) if (mask >> n & 1) push(r[n]); }
			else { for (int n = 31; n >= 0; n--) if (mask >> n & 1) r[n] = pop(); }
			return;
		}
		case MN_SOP_JMP: pc = o.kind == O_REG ? r[o.reg] : o.addr; after(&o); return;
		case MN_SOP_CALL: { uint64_t t = o.kind == O_REG ? r[o.reg] : o.addr; after(&o); push(pc); pc = t; return; }
		case MN_SOP_PUSH: v = opval(&o, 8, 0); push(v); return;
		case MN_SOP_POP: v = pop(); opset(&o, 8, v); return;
		default: die("reserved single-operand opcode", sub);
		}
		opset(&o, 8, res);
		return;
	}
	if (opc == OPGROUP_XFER) {
		int sub = f.reg;
		operand(&f, start, &o);
		if (sub == MN_XFER_JTAG) { pc = ld(o.addr + 8 * (r[f.rx] & 7) - (r[f.rx] << f.s), 8); return; }	/* the index was applied with its scale: take it back out */
		if (o.kind != O_MEM) die("jmpi/calli through a register", 0);
		uint64_t t = ld(o.addr, 8); after(&o);
		if (sub == MN_XFER_CALLI) push(pc);
		pc = t;
		return;
	}
	if (opc == OPGROUP_SYS) {
		int cls = f.reg;
		if (cls == 0) {
			switch (f.low) {
			case MN_SYS_NONE_RET: pc = pop(); return;
			case MN_SYS_NONE_HALT: if (!C->standin) priv(); if (gexit(XCODE_HALT)) return; E->halt(E->u); return;	/* HALT in a guest always exits (errata 186 decision 4) */
			case MN_SYS_NONE_BPT:
				if (C->deliver && !C->standin) { if (gtrap(HTRAP_BPT, XCODE_BPT)) return; enter(VECTOR_BPT, pc, 0); return; }
				die("breakpoint", 0);
			case MN_SYS_NONE_RTI: case MN_SYS_NONE_RTT: {					/* RTI #mask, RTT #mask: PC from EPC, PSW from EPSW (rtt: and T set after the return); at H = 1 from HEPC and HEPSW (design 1.2 rule 3).
											   The mask names the registers that keep their values when the return is to a lesser mode (clear_unkept); to the same mode it is ignored; there is no form without it */
				uint64_t xpc = C->h ? C->hepc : C->epc, xpsw = C->h ? C->hepsw : C->epsw;
				int lesser;
				priv();
				if (psw_bad(xpsw)) die("rti: reserved mode in epsw", 0);
				lesser = mode_rank((int)(xpsw >> PSW_MODE & 3)) < mode_rank(MODE);
				pc = xpc; pdp64_set_psw(C, (unsigned)xpsw);
				C->resv_on = 0;								/* every return clears any LL reservation (errata 211) */
				C->vacc = 0;								/* the return clears the naming too: what a handler named with a vclr outside a block is not left for the interrupted program (errata 172) */
				if (lesser) clear_unkept(f.n);
				if (f.low == MN_SYS_NONE_RTT) C->psw |= 1u << PSW_T;
				return;
			}
			case SYS_MINOR_SYSX: {								/* the SYSX escape: pushx, popx, isync, hint */
				uint64_t a;
				if (f.shape != FS_SYSX) die("illegal instruction", 0);
				if (f.sub == MN_SYSX_GENTER) { genter(f.n); return; }				/* the entry into a guest (errata 195, 196; design 2.2), with its mask (f.n) */
				if (f.sub == MN_SYSX_HINT) { if (f.n == 1 && gtrap(HTRAP_PAUSE, XCODE_PAUSE)) return; return; }	/* hint #n: not privileged, no flags, no effect, whatever n is (0 nop, 1 pause, 2 speculation barrier, the rest reserved) */
				if (f.sub == MN_SYSX_ISYNC) {							/* isync: earlier writes to PTBR, ASID, MMUCTL, VBR and earlier ICINVs take effect for what follows.  Not privileged
											   (errata 190): those writes are privileged themselves, so it gives a program no power.  The architecture promises
											   the effect only after the next ISYNC; this emulator applies them at once and keeps the translation state
											   coherent here, so only a kernel-mode ISYNC discards the translation buffer (a user-mode one has nothing to publish) */
					if (f.n != 0) die("illegal instruction", 0);
					if (MODE == MODE_KERNEL) E->tlb(E->u, PDP64_TLB_SYNC, 0);
					return;
				}
				priv();
				if (f.sub == MN_SYSX_STUA || f.sub == MN_SYSX_CLUA) {				/* stua, clua: set and clear UA, the user-access guard (errata 43, 190; 6.10.1): no flags, pad zero */
					if (f.n != 0) die("illegal instruction", 0);
					if (f.sub == MN_SYSX_STUA) C->psw |= 1u << PSW_UA; else C->psw &= ~(1u << PSW_UA);
					return;
				}
				if (f.n != 0 || (f.sub != MN_SYSX_PUSHX && f.sub != MN_SYSX_POPX)) die("illegal instruction", 0);
				a = f.sub == MN_SYSX_PUSHX ? r[14] - 16 : r[14];
				if (a & 7) fault_v(VECTOR_MISALIGNED, "misaligned data access", a);
				E->check(E->u, a, 8, f.sub == MN_SYSX_PUSHX); E->check(E->u, a + 8, 8, f.sub == MN_SYSX_PUSHX);	/* both words, before either is touched */
				{								/* at H = 1 these are HEPC and HEPSW (design 1.2 rule 3) */
					uint64_t *xpc = C->h ? &C->hepc : &C->epc, *xpsw = C->h ? &C->hepsw : &C->epsw;
					if (f.sub == MN_SYSX_PUSHX) { st(a, 8, *xpsw); st(a + 8, 8, *xpc); r[14] = a; }
					else { uint64_t w0 = ld(a, 8), w1 = ld(a + 8, 8); *xpsw = w0 & PSW_VALID; *xpc = w1; r[14] = a + 16; }
				}
				return;
			}
			case MN_SYS_NONE_WFE: priv(); if (gtrap(HTRAP_WFE, XCODE_WFE)) return; C->wait = 1; return;	/* the privilege check first, then the trap-control bit (design decision 10) */
			case MN_SYS_NONE_SEV: if (gtrap(HTRAP_SEV, XCODE_SEV)) return; return;
			case MN_SYS_NONE_ICINVA: if (gtrap(HTRAP_ICINV, XCODE_ICINV)) return; return;
			case MN_SYS_NONE_TLBIA: priv(); if (gtrap(HTRAP_TLBIA, XCODE_TLB)) return; E->tlb(E->u, PDP64_TLB_ALL, 0); return;
			case MN_SYS_NONE_TLBSYNC: priv(); if (gtrap(HTRAP_TLBSYNC, XCODE_TLB)) return; return;	/* one core: nothing to wait for */
			case MN_SYSREG_MFSR: case MN_SYSREG_MTSR: {					/* mfsr rd,name / mtsr name,rs: privileged */
				uint64_t *sr, mask = ~(uint64_t)0, tmp;
				int write = f.low == MN_SYSREG_MTSR;
				priv();
				if (f.sub >= SYSREG_HTRAP && f.sub <= SYSREG_GUDP) {			/* the hypervisor block: illegal with no hypervisor, an exit from a guest (6.14.7), the register at H = 1 */
					if (!C->hve) die("illegal instruction", 0);
					if (!C->h) { hexit(XCODE_HVREG, 0, VECTOR_HEXIT, pc, 0, 0, C->cur_insn); return; }
					hv_sysreg(write, f.sub, f.rd);
					return;
				}
				if (GUEST()) switch (f.sub) {						/* the trapped moves of a guest (design 1.5, 1.6); an unassigned number is not caught here: it is illegal below, in the guest */
				case SYSREG_DMW0: case SYSREG_DMW1: if (gexit(XCODE_DMW)) return; break;
				case SYSREG_PTBR: if (write && gtrap(HTRAP_PTBR, XCODE_PTBR)) return; break;
				case SYSREG_MMUCTL: if (write && gtrap(HTRAP_MMUCTL, XCODE_MMUCTL)) return; break;
				case SYSREG_VBR: if (write && gtrap(HTRAP_VBR, XCODE_VBR)) return; break;
				case SYSREG_ASID: if (gtrap(HTRAP_ASID, XCODE_ASID)) return; break;
				case SYSREG_CPUID: if (!write) { if (gtrap(HTRAP_CPUID, XCODE_CPUID)) return; r[f.rd] = C->vcpuid; return; } break;	/* the guest reads the virtual core number */
				}
				switch (f.sub) {
				case SYSREG_PTBR: sr = &C->ptbr; break;
				case SYSREG_EPC: sr = &C->epc; break;
				case SYSREG_EVA: sr = &C->eva; break;
				case SYSREG_ECAUSE: sr = &C->ecause; break;
				case SYSREG_DMW0: sr = &C->dmw[0]; break;
				case SYSREG_DMW1: sr = &C->dmw[1]; break;
				case SYSREG_USP: sr = &C->spbank[bank(MODE_USER)]; break;
				case SYSREG_SSP: sr = &C->spbank[bank(MODE_SUPERVISOR)]; break;
				case SYSREG_EPSW: sr = &C->epsw; mask = PSW_VALID; break;
				case SYSREG_VBR: sr = &C->vbr; break;
				case SYSREG_MMUCTL: sr = &C->mmuctl; mask = 1u << MMUCTL_ENABLE; break;
				case SYSREG_ASID: sr = &C->asid; mask = 0xffff; break;
				case SYSREG_CPUID: sr = &C->cpuid; break;
				default: die("illegal instruction", 0);					/* an unassigned system register */
				}
				if (!write) r[f.rd] = *sr;
				else if (SYSREG_READONLY(f.sub)) die("illegal instruction", 0);	/* read only */
				else {
					tmp = r[f.rd] & mask;
					if (f.sub == SYSREG_ASID || f.sub == SYSREG_MMUCTL || f.sub == SYSREG_PTBR) {
						*sr = tmp; E->tlb(E->u, PDP64_TLB_ALL, 0);
						if (f.sub != SYSREG_MMUCTL) fpsr = 0;			/* the floating-point flags belong to the process: a write of the address-space number or the table base clears them (6.8.4) */
					}
					else *sr = tmp;
				}
				return;
			}
			default: return;							/* nop, fence, sev, lpad, icinva */
			}
		}
		switch (cls) {
		case MN_SYS_MTPS: {
			unsigned v = (unsigned)r[f.low];
			if (MODE != MODE_KERNEL) { v = (v & PSW_FLAGS) | (pdp64_psw(C) & ~PSW_FLAGS); }	/* user mode writes only the flags */
			else if (psw_bad(v)) die("mtps: reserved mode", 0);
			else if (GUEST() && (v >> PSW_PRI & 7) != pdp64_priority(C) && gtrap(HTRAP_PRIO, XCODE_PRIO)) return;	/* a change of priority exits only if the hypervisor asks (design 1.5; the guest's priority masks virtual interrupts only) */
			pdp64_set_psw(C, v);
			return;
		}
		case MN_SYS_MFPS: r[f.low] = pdp64_psw(C); return;
		case MN_SYS_SPL: priv(); if (f.low > 7) die("spl: the priority is 0 to 7", 0); if (gtrap(HTRAP_PRIO, XCODE_PRIO)) return; C->psw = (C->psw & ~PSW_FIELD(PRI, ~0u)) | PSW_FIELD(PRI, f.low); return;
		case MN_SYS_TRAP: case MN_SYS_TRAPL: {
			int n = cls == MN_SYS_TRAP ? f.low : (int)f.n;			/* trapl: the vector number is in parcel 1 */
			if (C->deliver && !C->standin) {
				if (GUEST() && n < 256 && (C->htrap >> (HTRAP_MASK + (n >> HCALL_BLOCK_SHIFT)) & 1)) {	/* a routed TRAP #n is the hypercall: a trap exit, the vector 256 + n, at any guest mode (design 1.5) */
					hexit(XCODE_HYPERCALL, 0, VECTOR_TRAP_BASE + n, pc, 0, 0, C->cur_insn);
					return;
				}
				enter(VECTOR_TRAP_BASE + n, pc, 0);
			}
			else E->trap(E->u, n);
			return;
		}
		case MN_SYS_MTDP: dp = r[f.low]; return;
		case MN_SYS_MFDP: r[f.low] = dp; return;
		case MN_SYS_MFCPUID: priv(); if (gtrap(HTRAP_CPUID, XCODE_CPUID)) return; r[f.low] = GUEST() ? C->vcpuid : C->cpuid; return;			/* privileged (errata 186 decision 2; 6.2.5, 6.14.11): MFSR CPUID already is */
		case MN_SYS_PROBER: case MN_SYS_PROBEW:
			priv();
			r[f.rd] = E->probe(E->u, r[f.low], cls == MN_SYS_PROBEW, (int)(C->psw >> PSW_PREV & 3));
			return;
		case MN_SYS_TLBI: priv(); if (gtrap(HTRAP_TLBI, XCODE_TLB)) return; E->tlb(E->u, PDP64_TLB_PAGE, r[f.low]); return;
		case MN_SYS_MTASID: priv(); if (gtrap(HTRAP_ASID, XCODE_ASID)) return; C->asid = r[f.low] & 0xffff; E->tlb(E->u, PDP64_TLB_ALL, 0); fpsr = 0; return;
		case MN_SYS_MFASID: priv(); if (gtrap(HTRAP_ASID, XCODE_ASID)) return; r[f.low] = C->asid; return;
		case MN_SYS_MTDMW: priv(); if (gexit(XCODE_DMW)) return; C->dmw[0] = r[f.low]; return;			/* v1: storage only; the operand names no window, so it is DMW0 */
		case MN_SYS_ICINV: if (gtrap(HTRAP_ICINV, XCODE_ICINV)) return; return;
		}
		die("unimplemented system instruction", cls);
	}
	if (opc == OPGROUP_BESC || opc == OPGROUP_AESC) {				/* register-to-register escapes */
		int sub = f.sub, rd = f.reg, rs = f.low, rt = f.t;
		uint64_t a = r[rs], b = r[rt], res;
		if (opc == OPGROUP_AESC) {
			switch (sub) {
			case MN_AESC_DIV: case MN_AESC_DIVU: case MN_AESC_MOD: case MN_AESC_MODU:
				if (b == 0) fault_v(VECTOR_DIVZERO, "division by zero", 0);
				if (sub == MN_AESC_DIV) res = (int64_t)a == INT64_MIN && (int64_t)b == -1 ? a : (uint64_t)((int64_t)a / (int64_t)b);
				else if (sub == MN_AESC_DIVU) res = a / b;
				else if (sub == MN_AESC_MOD) res = (int64_t)b == -1 ? 0 : (uint64_t)((int64_t)a % (int64_t)b);
				else res = a % b;
				r[rd] = res; return;
			case MN_AESC_MULHU: r[rd] = (uint64_t)(((unsigned __int128)a * b) >> 64); return;
			case MN_AESC_ABS: res = (int64_t)a < 0 ? 0 - a : a; r[rd] = res; nz(res); fV = a == 0x8000000000000000ULL; return;
			case MN_AESC_MIN: res = (int64_t)a < (int64_t)b ? a : b; r[rd] = res; nz(res); fV = 0; return;
			case MN_AESC_MINU: res = a < b ? a : b; r[rd] = res; nz(res); fV = 0; return;
			case MN_AESC_MAX: res = (int64_t)a > (int64_t)b ? a : b; r[rd] = res; nz(res); fV = 0; return;
			case MN_AESC_MAXU: res = a > b ? a : b; r[rd] = res; nz(res); fV = 0; return;
			case SUBOP_SET: r[rd] = cond(f.x); return;
			}
			die("unimplemented arithmetic instruction", sub);
		}
		switch (sub) {
		case MN_BESC_CLZ: r[rd] = clz64(a); return;
		case MN_BESC_CTZ: r[rd] = ctz64(a); return;
		case MN_BESC_CLO: r[rd] = clz64(~a); return;
		case MN_BESC_CTO: r[rd] = ctz64(~a); return;
		case MN_BESC_POPCNT: r[rd] = __builtin_popcountll(a); return;
		case MN_BESC_BSWAP: r[rd] = __builtin_bswap64(a); return;
		case MN_BESC_BSWAPW: r[rd] = ((a & 0x00FF00FF00FF00FFULL) << 8) | ((a >> 8) & 0x00FF00FF00FF00FFULL); return;
		case MN_BESC_BSWAPL: r[rd] = ((uint64_t)__builtin_bswap32((uint32_t)(a >> 32)) << 32) | __builtin_bswap32((uint32_t)a); return;
		case MN_BESC_BITREV: r[rd] = bitrev64(a); return;
		case MN_BESC_ROR: r[rd] = ror64(a, (unsigned)b); return;
		case MN_BESC_RORI: r[rd] = ror64(a, f.count); return;
		case MN_BESC_RORI32: { uint32_t w = (uint32_t)a; unsigned n = f.count & 31; r[rd] = (uint64_t)(int64_t)(int32_t)(n ? (w >> n) | (w << (32 - n)) : w); return; }
		case MN_BESC_DSHR: { unsigned n = f.pos & 63; r[rd] = n ? (b >> n) | (a << (64 - n)) : b; return; }
		case MN_BESC_EXTB: case MN_BESC_EXTZB: {
			unsigned pos = f.pos & 63, w = f.width & 255;
			uint64_t v = a >> pos;
			if (w == 0 || w > 64) w = 64;
			r[rd] = sub == MN_BESC_EXTB ? (uint64_t)sext(v, w) : zext(v, w);
			return;
		}
		case MN_BESC_INSB: {
			unsigned pos = f.pos & 63, w = f.width & 255;
			if (w == 0 || w > 64) w = 64;
			uint64_t m = (w == 64 ? ~(uint64_t)0 : (((uint64_t)1 << w) - 1)) << pos;
			r[rd] = (r[rd] & ~m) | ((a << pos) & m);
			return;
		}
		case MN_BESC_XNORPOP: r[rd] = __builtin_popcountll(~(a ^ b)); return;
		case MN_BESC_CLMULL: { uint64_t lo, hi; clmul(a, b, &lo, &hi); r[rd] = lo; return; }
		case MN_BESC_CLMULH: { uint64_t lo, hi; clmul(a, b, &lo, &hi); r[rd] = hi; return; }
		}
		die("unimplemented bit instruction", sub);
	}
	if (opc == OPGROUP_MBLK) {
		C->progress = 1;
		int sub = f.sub, rd = f.reg, rs = f.low, rn = f.t;
		switch (sub) {
		case MN_MBLK_MCPY: while (r[rn]) { st(r[rd], 1, ld(r[rs], 1)); r[rd]++; r[rs]++; r[rn]--; } return;
		case MN_MBLK_MMOV:
			if (r[rd] <= r[rs] || r[rd] >= r[rs] + r[rn]) { while (r[rn]) { st(r[rd], 1, ld(r[rs], 1)); r[rd]++; r[rs]++; r[rn]--; } }
			else { while (r[rn]) { r[rn]--; st(r[rd] + r[rn], 1, ld(r[rs] + r[rn], 1)); } r[rd] += 0; }
			return;
		case MN_MBLK_MSET: while (r[rn]) { st(r[rd], 1, (uint8_t)r[rs]); r[rd]++; r[rn]--; } return;
		case MN_MBLK_MCMP:
			while (r[rn]) {
				uint8_t x = (uint8_t)ld(r[rd], 1), y = (uint8_t)ld(r[rs], 1);
				if (x != y) { sub_f(x, y, 0); return; }
				r[rd]++; r[rs]++; r[rn]--;
			}
			fN = 0; fZ = 1; fV = 0; fC = 0;
			return;
		case MN_MBLK_MSCN: case MN_MBLK_MSCNN:
			while (r[rn]) {
				int hit = (uint8_t)ld(r[rd], 1) == (uint8_t)r[rs];
				if (sub == MN_MBLK_MSCNN) hit = !hit;
				if (hit) { fN = fV = fC = 0; fZ = 1; return; }		/* mscn writes all four flags (errata 39) */
				r[rd]++; r[rn]--;
			}
			fN = fV = fC = 0; fZ = 0;
			return;
		}
		die("unimplemented block instruction", sub);
	}
	if (opc == OPGROUP_FESC) {
		int sub = f.sub, rd = f.reg;
		double a = asd(r[f.low]), b = asd(r[f.t]), c = asd(r[f.x]);
		float sa = ass(r[f.low]), sb = ass(r[f.t]), sc = ass(r[f.x]);
		if (half_op(sub, &f, &r[rd])) return;					/* binary16: its own rounding and flags */
		if (sub == MN_FESC_FSFLAGS) { uint64_t old = fpsr; fpsr = r[f.low] & 31; r[rd] = old; return; }	/* swap, not an arithmetic operation */
		fp_begin();
		switch (sub) {
		case MN_FESC_FDIV: r[rd] = fromd(asd(r[rd]) / a); break;
		case MN_FESC_FSQRT: r[rd] = fromd(sqrt(a)); break;
		case MN_FESC_FADD32: r[rd] = froms(ass(r[rd]) + sa); break;
		case MN_FESC_FSUB32: r[rd] = froms(ass(r[rd]) - sa); break;
		case MN_FESC_FMUL32: r[rd] = froms(ass(r[rd]) * sa); break;
		case MN_FESC_FDIV32: r[rd] = froms(ass(r[rd]) / sa); break;
		case MN_FESC_FSQRT32: r[rd] = froms(sqrtf(sa)); break;
		case MN_FESC_FCMP32: fcmp_flags(ass(r[rd]), sa); break;
		case MN_FESC_FMADD: r[rd] = fromd(fma(a, b, c)); break;
		case MN_FESC_FMSUB: r[rd] = fromd(fma(a, b, -c)); break;
		case MN_FESC_FNMADD: r[rd] = fromd(fma(-a, b, -c)); break;
		case MN_FESC_FNMSUB: r[rd] = fromd(fma(-a, b, c)); break;
		case MN_FESC_FMADD32: r[rd] = froms(fmaf(sa, sb, sc)); break;
		case MN_FESC_FMSUB32: r[rd] = froms(fmaf(sa, sb, -sc)); break;
		case MN_FESC_FNMADD32: r[rd] = froms(fmaf(-sa, sb, -sc)); break;
		case MN_FESC_FNMSUB32: r[rd] = froms(fmaf(-sa, sb, sc)); break;
		case MN_FESC_FNEG: r[rd] = r[f.low] ^ 0x8000000000000000ULL; break;
		case MN_FESC_FABS: r[rd] = r[f.low] & 0x7fffffffffffffffULL; break;
		case MN_FESC_FCOPYSIGN: r[rd] = (r[f.low] & 0x7fffffffffffffffULL) | (r[f.t] & 0x8000000000000000ULL); break;
		case MN_FESC_FMIN: r[rd] = fromd(isnan(a) ? b : isnan(b) ? a : fmin(a, b)); break;
		case MN_FESC_FMAX: r[rd] = fromd(isnan(a) ? b : isnan(b) ? a : fmax(a, b)); break;
		case MN_FESC_FCLASS: {
			uint64_t v = r[f.low]; int sgn = v >> 63; double x = asd(v); unsigned m;
			if (isnan(x)) m = (v >> 51 & 1) ? 1u << 9 : 1u << 8;
			else if (isinf(x)) m = sgn ? 1u << 0 : 1u << 7;
			else if (x == 0) m = sgn ? 1u << 3 : 1u << 4;
			else if (fpclassify(x) == FP_SUBNORMAL) m = sgn ? 1u << 2 : 1u << 5;
			else m = sgn ? 1u << 1 : 1u << 6;
			r[rd] = m; break;
		}
		case MN_FESC_FCLASS32: {		/* as FCLASS16, for a binary32 in the low 32 bits */
			uint32_t w = (uint32_t)r[f.low]; unsigned sgn = w >> 31, ex = (w >> 23) & 255, m = w & 0x7fffff, k;
			k = ex == 255 ? (m ? ((w & 0x400000) ? 1u << 9 : 1u << 8) : (sgn ? 1u << 0 : 1u << 7))
			    : ex == 0 ? (m ? (sgn ? 1u << 2 : 1u << 5) : (sgn ? 1u << 3 : 1u << 4)) : (sgn ? 1u << 1 : 1u << 6);
			r[rd] = k; break;
		}
		case MN_FESC_FRINT: r[rd] = fromd(nearbyint(a)); break;
		case MN_FESC_FRINTZ: r[rd] = fromd(trunc(a)); break;
		case MN_FESC_FRINTM: r[rd] = fromd(floor(a)); break;
		case MN_FESC_FRINTP: r[rd] = fromd(ceil(a)); break;
		case MN_FESC_FRINTA: r[rd] = fromd(round(a)); break;
		case MN_FESC_FCVTDQ: r[rd] = cvt_to_q(a, 0); break;
		case MN_FESC_FCVTDQU: r[rd] = cvt_to_q(a, 1); break;
		case MN_FESC_FCVTQD: r[rd] = fromd((double)(int64_t)r[f.low]); break;
		case MN_FESC_FCVTQUD: r[rd] = fromd((double)r[f.low]); break;
		case MN_FESC_FCVTDS: r[rd] = froms((float)a); break;
		case MN_FESC_FCVTSD: r[rd] = fromd((double)sa); break;
		case MN_FESC_FCVTSL: r[rd] = (uint64_t)(int64_t)(int32_t)(isnan(sa) ? INT32_MAX : sa >= 2147483648.0f ? INT32_MAX : sa < -2147483648.0f ? INT32_MIN : (int32_t)sa); break;
		case MN_FESC_FCVTLS: r[rd] = froms((float)(int32_t)r[f.low]); break;
		default: fp_end(); die("unimplemented floating-point instruction", sub);
		}
		fp_end();
		return;
	}
	die("unimplemented instruction", opc);
}
#include "pdp64exec_enc.inc"
void pdp64_init(void)
{
	enc_exec_init();
}

int pdp64_insn_parcels(uint16_t parcel0)
{
	return enc_len_p0(&enc_tab, parcel0);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the interface to the hosts (the short names above are macros on C, so they are undone here)                         */
#undef r
#undef pc
#undef dp
#undef fpsr
#undef fN
#undef fZ
#undef fV
#undef fC
#undef cur_pc

unsigned pdp64_psw(const struct pdp64_cpu *c)
{
	return (c->psw & ~PSW_FLAGS) | (unsigned)c->fC << PSW_C | (unsigned)c->fV << PSW_V | (unsigned)c->fZ << PSW_Z | (unsigned)c->fN << PSW_N;
}
void pdp64_set_h(struct pdp64_cpu *c, int h)
{
	int mode = pdp64_mode(c), ob = c->h ? HYP_BANK : bank(mode), nb = h ? HYP_BANK : bank(mode);
	c->h = h != 0;
	if (ob != nb) {									/* r14 and DP name the new bank's copies */
		c->spbank[ob] = c->r[14]; c->dpbank[ob] = c->dp;
		c->r[14] = c->spbank[nb]; c->dp = c->dpbank[nb];
	}
}
void pdp64_set_hve(struct pdp64_cpu *c, int hve)
{
	c->hve = hve != 0;
	if (hve) { c->htrap = HTRAP_RESET_VALUE; pdp64_set_h(c, 1); }			/* the core starts as the hypervisor, with WFE and SEV trapped */
}
void pdp64_set_psw(struct pdp64_cpu *c, unsigned v)
{
	int old = pdp64_mode(c), nw;
	v &= PSW_VALID;
	nw = v >> PSW_MODE & ((1u << PSW_WIDTH_MODE) - 1);
	c->fC = v >> PSW_C & 1; c->fV = v >> PSW_V & 1; c->fZ = v >> PSW_Z & 1; c->fN = v >> PSW_N & 1;
	if (nw != old && !c->h) {							/* r14 and DP name the new mode's copies (at H = 1 the bank is the hypervisor's whatever the mode) */
		c->spbank[bank(old)] = c->r[14]; c->dpbank[bank(old)] = c->dp;
		c->r[14] = c->spbank[bank(nw)]; c->dp = c->dpbank[bank(nw)];
	}
	c->psw = v & ~PSW_FLAGS;
}

void pdp64_exception(struct pdp64_cpu *c, const struct pdp64_env *e, int vector, uint64_t eva)
{
	uint64_t epc = c->pc;
	uint32_t insn = c->snap_valid ? c->cur_insn : 0;				/* a fault in the translation of the fetch (before the instruction began) has no instruction to show */
	C = c; E = e;
	if (c->vhidden) {									/* a block with hidden accumulation: it restarts from its entry, the accumulators discarded (hidden state is not saved: R435) */
		for (int v = 0; v < 16; v++) if (c->vacc >> v & 1) memset(c->vr[v], 0, sizeof c->vr[v]);
		c->vhidden = 0;
	}
	if (c->snap_valid) {
		if (!c->progress) {							/* an abort leaves no trace: the registers (the (rN)+ and -(rN) updates among them) are as before */
			memcpy(c->r, c->snap.r, sizeof c->r); c->dp = c->snap.dp; c->fpsr = c->snap.fpsr;
			c->fN = c->snap.fN; c->fZ = c->snap.fZ; c->fV = c->snap.fV; c->fC = c->snap.fC;
		}
		epc = c->cur_pc;
		c->snap_valid = 0;
	}
	if (c->s2_code && c->hve && !c->h) {						/* a stage-2 fault: the abort is an exit (design 2.5): HEPC the instruction, HEVA the guest-virtual address, HGPA the guest-physical address, HINSN the instruction */
		int code = c->s2_code;
		c->s2_code = 0;
		hexit(code, c->s2_flags, vector, epc, eva, c->s2_gpa, insn);
		return;
	}
	c->s2_code = 0;
	enter(vector, epc, eva);
}
/* the highest pending virtual line that has a deliverable vector (VIVEC field of 8 bits, 32 to 255); 0 if none */
static int virq_best(const struct pdp64_cpu *c, int *vector)
{
	for (int l = VIRQ_LINES; l >= 1; l--) {
		int v = (int)(c->vivec >> (VIRQ_VEC_WIDTH * (l - 1)) & ((1u << VIRQ_VEC_WIDTH) - 1));
		if ((c->virq >> l & 1) && v >= 32) { if (vector) *vector = v; return l; }
	}
	return 0;
}
int pdp64_virq_pending(const struct pdp64_cpu *c) { return c->hve && !c->h && virq_best(c, NULL) != 0; }
int pdp64_virq_deliverable(const struct pdp64_cpu *c) { return c->hve && !c->h && virq_best(c, NULL) > (int)pdp64_priority(c); }
int pdp64_virtual_interrupt(struct pdp64_cpu *c, const struct pdp64_env *e)
{
	int v, l;
	if (!c->hve || c->h) return 0;
	l = virq_best(c, &v);
	if (l <= (int)pdp64_priority(c)) return 0;
	C = c; E = e;
	enter(v, c->pc, 0);								/* the guest's exception entry: EPC the next instruction, EVA 0, ECAUSE the vector, kernel mode at priority 7 */
	if (!c->h) c->virq &= ~((uint64_t)1 << l);					/* delivered: the hardware clears the line (an entry that exited, a failed vector fetch, changed nothing and leaves it pending) */
	c->wait = 0;
	return 1;
}
int pdp64_interrupt(struct pdp64_cpu *c, const struct pdp64_env *e, int level, int vector)
{
	C = c; E = e;
	if (GUEST()) { hexit(XCODE_IRQ, 0, vector, c->pc, 0, 0, 0); return 1; }	/* a physical interrupt always exits, whatever the guest's priority (errata 186 decision 1) */
	if (level <= (int)pdp64_priority(c)) return 0;
	enter(vector, c->pc, 0);
	c->wait = 0;
	return 1;
}

void pdp64_step(struct pdp64_cpu *c, const struct pdp64_env *e)
{
	int traced = c->psw >> PSW_T & 1, guest = c->hve && !c->h;
	C = c; E = e;
	c->entered = 0; c->progress = 0; c->wait = 0; c->vhidden = 0; c->uacc = 0; c->snap_valid = c->deliver;
	c->cur_insn = 0;									/* an exit during the fetch has no instruction to show */
	c->s2_code = 0;
	if (c->deliver) {									/* keep what an abort has to undo */
		memcpy(c->snap.r, c->r, sizeof c->r); c->snap.pc = c->pc; c->snap.dp = c->dp; c->snap.fpsr = c->fpsr;
		c->snap.fN = c->fN; c->snap.fZ = c->fZ; c->snap.fV = c->fV; c->snap.fC = c->fC;
	}
	{
		int watch = c->resv_on; uint64_t pc0 = c->pc;
		step();
		/* the constrained loop of LL and SC (manual 7.4): a taken branch that does not go forward breaks it: the reservation is lost and the SC will fail */
		if (watch && c->resv_on && !c->entered && c->pc <= pc0) c->resv_on = 0;
	}
	c->snap_valid = 0;
	if (traced && c->deliver && !c->entered) enter(VECTOR_BPT, c->pc, 0);		/* T was set when the instruction began: the trace trap (vector 15, as bpt) */
	if (guest && !c->h && (c->htrap >> HTRAP_STEP & 1) && !c->entered) hexit(XCODE_STEP, 0, VECTOR_HEXIT, c->pc, 0, 0, c->cur_insn);	/* single step: an exit after each guest instruction (design 1.5 bit STEP) */
}

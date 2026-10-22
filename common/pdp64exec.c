/* pdp64exec: what each pdp64 instruction does.  One source for every executor: sim64 uses it, and so does the QEMU target.
 *
 * The decoder is the one generated from the grammar (fmtp.c); the widths of the displacement fields come from common/calib.c; the
 * numbers of the instructions are the names of pdp64-consts.h.  This file holds the meaning only.  Everything that touches the
 * host (memory, faults, `trap`, `halt`) goes through the hooks of struct pdp64_env, so that an executor can map memory its own way.
 */
#include <fenv.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include "fmt.h"
#include "calib.h"
#include "pdp64-consts.h"
#include "pdp64exec.h"

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
#define die(what, addr) E->fault(E->u, (what), (addr))

static int64_t sext(uint64_t v, int bits) { return bits >= 64 ? (int64_t)v : (int64_t)(v << (64 - bits)) >> (64 - bits); }
static uint64_t zext(uint64_t v, int bits) { return bits >= 64 ? v : v & (((uint64_t)1 << bits) - 1); }
static int64_t ldx(uint64_t a, int size) { return sext(ld(a, size), size * 8); }

enum { O_REG, O_MEM, O_IMM };
struct opnd { int kind, reg; uint64_t addr; int64_t imm; int adjust_reg; int64_t adjust; };

/* the memory-side operand of a decoded instruction.  The effect of (Rn)+ / -(Rn) on Rn is applied here; the stride is in the instruction. */
static void operand(const struct fmt *f, uint64_t start, struct opnd *o)
{
	int len = f->len, mode = f->low;
	memset(o, 0, sizeof *o);
	o->adjust_reg = -1;
	if (f->shape == FS_MEM0) { o->kind = O_REG; o->reg = f->low; return; }
	o->kind = O_MEM;
	switch (f->shape) {
	case FS_BASE: {
		int64_t d = sext(f->d, dispbits(mode, len));
		if (mode == AMODE_BASE) o->addr = r[f->rm] + d;
		else if (mode == AMODE_POSTINC) { o->addr = r[f->rm]; o->adjust_reg = f->rm; o->adjust = d; }
		else { o->addr = r[f->rm] - d; r[f->rm] = o->addr; }				/* pre-decrement happens before the access */
		break;
	}
	case FS_INDEX: o->addr = r[f->rm] + (r[f->rx] << f->s) + sext(f->d, dispbits(AMODE_INDEX, len)); break;
	case FS_DP: o->addr = dp + sext(f->d, dispbits(AMODE_DP, len)); break;
	case FS_WIDE:
		if (mode == AMODE_PCREL) o->addr = start + sext(f->d, dispbits(mode, len));
		else if (mode == AMODE_ABS) o->addr = sext(f->d, dispbits(mode, len));
		else { o->kind = O_IMM; o->imm = sext(f->d, dispbits(mode, len)); }
		break;
	default: die("unimplemented operand form", 0);
	}
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
/* one instruction                                                                                                     */

static int moves_size(int opc)
{
	switch (opc) { case MN_MOV_MOVQ: case MOVSTORE_MOVQ: return 8; case MN_MOV_MOVL: case MOVSTORE_MOVL: case MN_MOVZ_MOVZL: return 4;
	case MN_MOV_MOVW: case MOVSTORE_MOVW: case MN_MOVZ_MOVZW: return 2; default: return 1; }
}

static void step(void)
{
	uint8_t buf[8];
	struct fmt f;
	uint64_t start = pc;
	cur_pc = pc;
	uint16_t p0 = (uint16_t)ld(pc, 2);
	int len = p0 >> 14;
	for (int i = 0; i <= len; i++) { uint16_t p = (uint16_t)ld(pc + 2 * i, 2); buf[2 * i] = p >> 8; buf[2 * i + 1] = p & 255; }
	if (fmt_decode(buf, 2 * (len + 1), &f)) die("illegal instruction", 0);
	pc += 2 * (len + 1);

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
			opset(&o, size, v);
			nz((uint64_t)sext(v, size * 8)); fV = 0;
		} else {
			uint64_t v = opval(&o, size, !zero);
			r[f.reg] = v; nz(v); fV = 0;
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
			if (b == 0) break;							/* a zero count changes nothing, not even C */
			if (opc == MN_ALU_SHL) { res = b >= 64 ? 0 : a << b; fC = b <= 64 ? (int)((a >> (64 - b)) & 1) : 0; if (b == 64) fC = a & 1; }
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
	if (opc >= MN_BRANCH_BR && opc <= MN_BRANCH_BLOS) {				/* conditional branches */
		int64_t d = f.shape == FS_BR0 ? (int8_t)((f.reg << lowbits) | f.low) : sext(f.d, branchbits(len));
		if (cond(opc - MN_BRANCH_BR)) pc = start + 2 * d;
		return;
	}
	if (opc == OPGROUP_SOB) {
		int64_t d = sext(f.d, branchbits(len));
		if (--r[f.reg] != 0) pc = start + 2 * d;
		return;
	}
	if (opc == OPGROUP_TAG) {
		int sense = f.low >> 3, tag = f.low & 7;
		int64_t d = sext(f.d, branchbits(len));
		if (((r[f.reg] & 7) == (unsigned)tag) == !sense) pc = start + 2 * d;
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
			unsigned mask = (unsigned)(o.imm & 0xFFFF);
			if (sub == MN_SOP_PUSHM) { for (int n = 0; n < 16; n++) if (mask >> n & 1) push(r[n]); }
			else { for (int n = 15; n >= 0; n--) if (mask >> n & 1) r[n] = pop(); }
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
			case MN_SYS_NONE_HALT: E->halt(E->u); return;
			case MN_SYS_NONE_BPT: die("breakpoint", 0);
			case MN_SYS_NONE_RTI: case MN_SYS_NONE_RTT: die("privileged instruction", f.low);
			default: return;							/* nop, fence, wfe, sev, lpad, tlb and cache operations */
			}
		}
		switch (cls) {
		case MN_SYS_MTPS: { uint64_t v = r[f.low]; fC = v & 1; fV = v >> 1 & 1; fZ = v >> 2 & 1; fN = v >> 3 & 1; return; }
		case MN_SYS_MFPS: r[f.low] = (uint64_t)(fC | fV << 1 | fZ << 2 | fN << 3); return;
		case MN_SYS_TRAP: E->trap(E->u, f.low); return;
		case MN_SYS_TRAPL: E->trap(E->u, (int)(f.d >> 8)); return;
		case MN_SYS_MTDP: dp = r[f.low]; return;
		case MN_SYS_MFDP: r[f.low] = dp; return;
		case MN_SYS_MFCPUID: r[f.low] = 0; return;
		case MN_SYS_PROBER: case MN_SYS_PROBEW: r[(f.d >> 12) & 15] = E->mapped(E->u, r[f.low]); return;
		case MN_SYS_SPL: case MN_SYS_TLBI: case MN_SYS_MTASID: case MN_SYS_MFASID: case MN_SYS_MTDMW: case MN_SYS_ICINV: return;
		}
		die("unimplemented system instruction", cls);
	}
	if (opc == OPGROUP_BESC || opc == OPGROUP_AESC) {				/* register-to-register escapes */
		int sub = f.sub, rd = f.reg, rs = f.low, rt = f.t;
		uint64_t a = r[rs], b = r[rt], res;
		if (opc == OPGROUP_AESC) {
			switch (sub) {
			case MN_AESC_DIV: case MN_AESC_DIVU: case MN_AESC_MOD: case MN_AESC_MODU:
				if (b == 0) die("division by zero", 0);
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
		case MN_BESC_DSHR: { unsigned n = (f.d >> 8) & 63; r[rd] = n ? (b >> n) | (a << (64 - n)) : b; return; }
		case MN_BESC_EXTB: case MN_BESC_EXTZB: {
			unsigned pos = (f.d >> 8) & 63, w = f.d & 255;
			uint64_t v = a >> pos;
			if (w == 0 || w > 64) w = 64;
			r[rd] = sub == MN_BESC_EXTB ? (uint64_t)sext(v, w) : zext(v, w);
			return;
		}
		case MN_BESC_INSB: {
			unsigned pos = (f.d >> 8) & 63, w = f.d & 255;
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
				if (hit) { fZ = 1; return; }
				r[rd]++; r[rn]--;
			}
			fZ = 0;
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
void pdp64_init(void) { calibrate(); }

void pdp64_step(struct pdp64_cpu *c, const struct pdp64_env *e)
{
	C = c; E = e;
	step();
}

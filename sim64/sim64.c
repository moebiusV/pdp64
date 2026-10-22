/* sim64: a reference emulator for pdp64 (user mode).
 *
 * It loads an ELF executable written by ld64, decodes each instruction with the generated decoder (spec/pdp64.hbnf, through fmtp.c) and
 * executes it.  The widths of the displacement fields come from the same calibration as the assembler's (common/calib.c); the numbers of
 * the instructions are the names of pdp64-consts.h.  What each instruction does is written here.
 *
 *   sim64 [-t] [-r] [-n steps] program
 *
 *   -t  trace: one line per instruction, to standard error     -r  print the registers and flags when the program stops
 *   -n  stop after that many instructions (default 200 million)
 *
 * The system call interface is a stand-in until there is an operating system (docs/sim64.md): `trap #n` with n = 0 exit(r0), 1 write(r0
 * fd, r1 buffer, r2 length) returning the count in r0, 2 read(...).  `halt` stops with the status in r0.  The program's exit status is the
 * emulator's.  A fault (misaligned data, an unmapped address, an unimplemented instruction, a divide by zero) prints a message and exits 139.
 */
#include <errno.h>
#include <fenv.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "fmt.h"
#include "calib.h"
#include "pdp64-consts.h"
#include "relocs.h"
#include "elf-parser.c"

/* ------------------------------------------------------------------------------------------------------------------ */
/* state                                                                                                               */

static uint64_t r[16], pc, dp, fpsr;
static int fN, fZ, fV, fC;
static int trace, maxsteps = 200000000;
static uint64_t cur_pc;			/* the instruction being executed */

static void regdump(FILE *o)
{
	for (int i = 0; i < 16; i++) fprintf(o, "r%-2d %016llx%s", i, (unsigned long long)r[i], i % 4 == 3 ? "\n" : "  ");
	fprintf(o, "pc  %016llx  N%d Z%d V%d C%d  fpsr %02llx\n", (unsigned long long)pc, fN, fZ, fV, fC, (unsigned long long)fpsr);
}
static void die(const char *what, uint64_t addr)
{
	fprintf(stderr, "sim64: %s at pc=%#llx addr=%#llx\n", what, (unsigned long long)cur_pc, (unsigned long long)addr);
	regdump(stderr);
	exit(139);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* memory: pages made on demand inside the mapped regions                                                              */

#define PG 4096
struct page { uint64_t base; uint8_t *d; struct page *next; };
static struct page *ptab[1 << 12];
struct region { uint64_t lo, hi; };
static struct region regions[16];
static int nregions;

static int mapped(uint64_t a)
{
	for (int i = 0; i < nregions; i++) if (a >= regions[i].lo && a < regions[i].hi) return 1;
	return 0;
}
static uint8_t *pgget(uint64_t a)
{
	uint64_t base = a & ~(uint64_t)(PG - 1);
	struct page **h = &ptab[(base / PG) & ((1 << 12) - 1)], *p;
	for (p = *h; p; p = p->next) if (p->base == base) return p->d;
	if (!mapped(a)) return NULL;
	p = malloc(sizeof *p);
	p->base = base; p->d = calloc(PG, 1); p->next = *h; *h = p;
	return p->d;
}
static void addregion(uint64_t lo, uint64_t hi)
{
	regions[nregions].lo = lo & ~(uint64_t)(PG - 1);
	regions[nregions].hi = (hi + PG - 1) & ~(uint64_t)(PG - 1);
	nregions++;
}
static uint8_t *bp(uint64_t a, int write)
{
	uint8_t *p = pgget(a);
	(void)write;
	if (!p) die("access to unmapped memory", a);
	return p + (a & (PG - 1));
}
static uint64_t ld(uint64_t a, int size)
{
	uint64_t v = 0;
	if (size > 1 && (a & (size - 1))) die("misaligned data access", a);
	for (int i = 0; i < size; i++) v |= (uint64_t)*bp(a + i, 0) << (8 * i);
	return v;
}
static void st(uint64_t a, int size, uint64_t v)
{
	if (size > 1 && (a & (size - 1))) die("misaligned data access", a);
	for (int i = 0; i < size; i++) *bp(a + i, 1) = v >> (8 * i);
}
static int64_t sext(uint64_t v, int bits) { return bits >= 64 ? (int64_t)v : (int64_t)(v << (64 - bits)) >> (64 - bits); }
static uint64_t zext(uint64_t v, int bits) { return bits >= 64 ? v : v & (((uint64_t)1 << bits) - 1); }
static int64_t ldx(uint64_t a, int size) { return sext(ld(a, size), size * 8); }

/* ------------------------------------------------------------------------------------------------------------------ */
/* loading                                                                                                             */

static uint64_t load_elf(const char *path)
{
	FILE *f = fopen(path, "rb");
	if (!f) { perror(path); exit(1); }
	fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
	uint8_t *b = malloc(n + 1);
	if (fread(b, 1, n, f) != (size_t)n) { fprintf(stderr, "sim64: read error\n"); exit(1); }
	fclose(f);
	elfrec_t rec; uint8_t tmp[80]; char e[160]; size_t at;
	tmp[0] = 1; memcpy(tmp + 1, b, 64);
	if (n < 64 || !parse_bytes(tmp, 65, &rec, e, sizeof e, &at) || memcmp(b, "\177ELF\2\1\1", 7) || rec.body.u.a1.e.machine != EM_PDP64 || rec.body.u.a1.e.type != 2) {
		fprintf(stderr, "sim64: %s is not a pdp64 executable\n", path); exit(1);
	}
	ehdr_t eh = rec.body.u.a1.e;
	for (int i = 0; i < eh.phnum; i++) {
		tmp[0] = 5; memcpy(tmp + 1, b + eh.phoff + (size_t)i * 56, 56);
		if (!parse_bytes(tmp, 57, &rec, e, sizeof e, &at)) { fprintf(stderr, "sim64: bad program header\n"); exit(1); }
		phdr_t p = rec.body.u.a5.p;
		if (p.type != 1) continue;
		addregion(p.vaddr, p.vaddr + p.memsz);
		for (uint64_t k = 0; k < p.filesz; k++) *bp(p.vaddr + k, 1) = b[p.offset + k];
	}
	return eh.entry;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* operands                                                                                                            */

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
static uint64_t fromd(double d) { uint64_t v; memcpy(&v, &d, 8); return v; }
static float ass(uint64_t v) { uint32_t w = (uint32_t)v; float x; memcpy(&x, &w, 4); return x; }
static uint64_t froms(float x) { uint32_t w; memcpy(&w, &x, 4); return (uint64_t)sext(w, 32); }
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
static void syscall_n(int n)
{
	switch (n) {
	case 0: fflush(stdout); exit((int)(r[0] & 255));
	case 1: {
		uint64_t a = r[1], len = r[2];
		for (uint64_t i = 0; i < len; i++) { uint8_t c = *bp(a + i, 0); if (write((int)r[0], &c, 1) != 1) break; }
		r[0] = len;
		break;
	}
	case 2: {
		uint64_t a = r[1], len = r[2];
		uint8_t *tmp = malloc(len + 1);
		ssize_t got = read((int)r[0], tmp, len);
		for (ssize_t i = 0; i < got; i++) *bp(a + i, 1) = tmp[i];
		free(tmp);
		r[0] = (uint64_t)got;
		break;
	}
	default: die("unknown system call", n);
	}
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
	if (trace) fprintf(stderr, "%08llx:", (unsigned long long)start), ({ for (int i = 0; i <= len; i++) fprintf(stderr, " %04x", (unsigned)ld(start + 2 * i, 2)); }), fprintf(stderr, "\n");

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
			case MN_SYS_NONE_HALT: if (trace) regdump(stderr); fflush(stdout); exit((int)(r[0] & 255));
			case MN_SYS_NONE_BPT: die("breakpoint", 0);
			case MN_SYS_NONE_RTI: case MN_SYS_NONE_RTT: die("privileged instruction", f.low);
			default: return;							/* nop, fence, wfe, sev, lpad, tlb and cache operations */
			}
		}
		switch (cls) {
		case MN_SYS_MTPS: { uint64_t v = r[f.low]; fC = v & 1; fV = v >> 1 & 1; fZ = v >> 2 & 1; fN = v >> 3 & 1; return; }
		case MN_SYS_MFPS: r[f.low] = (uint64_t)(fC | fV << 1 | fZ << 2 | fN << 3); return;
		case MN_SYS_TRAP: syscall_n(f.low); return;
		case MN_SYS_TRAPL: syscall_n((int)(f.d >> 8)); return;
		case MN_SYS_MTDP: dp = r[f.low]; return;
		case MN_SYS_MFDP: r[f.low] = dp; return;
		case MN_SYS_MFCPUID: r[f.low] = 0; return;
		case MN_SYS_PROBER: case MN_SYS_PROBEW: r[(f.d >> 12) & 15] = mapped(r[f.low]); return;
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
		case MN_MBLK_MCPY: while (r[rn]) { *bp(r[rd], 1) = *bp(r[rs], 0); r[rd]++; r[rs]++; r[rn]--; } return;
		case MN_MBLK_MMOV:
			if (r[rd] <= r[rs] || r[rd] >= r[rs] + r[rn]) { while (r[rn]) { *bp(r[rd], 1) = *bp(r[rs], 0); r[rd]++; r[rs]++; r[rn]--; } }
			else { while (r[rn]) { r[rn]--; *bp(r[rd] + r[rn], 1) = *bp(r[rs] + r[rn], 0); } r[rd] += 0; }
			return;
		case MN_MBLK_MSET: while (r[rn]) { *bp(r[rd], 1) = (uint8_t)r[rs]; r[rd]++; r[rn]--; } return;
		case MN_MBLK_MCMP:
			while (r[rn]) {
				uint8_t x = *bp(r[rd], 0), y = *bp(r[rs], 0);
				if (x != y) { sub_f(x, y, 0); return; }
				r[rd]++; r[rs]++; r[rn]--;
			}
			fN = 0; fZ = 1; fV = 0; fC = 0;
			return;
		case MN_MBLK_MSCN: case MN_MBLK_MSCNN:
			while (r[rn]) {
				int hit = *bp(r[rd], 0) == (uint8_t)r[rs];
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

int main(int argc, char **argv)
{
	int regs = 0;
	const char *prog = NULL;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-t")) trace = 1;
		else if (!strcmp(argv[i], "-r")) regs = 1;
		else if (!strcmp(argv[i], "-n") && i + 1 < argc) maxsteps = atoi(argv[++i]);
		else if (argv[i][0] == '-') { fprintf(stderr, "usage: sim64 [-t] [-r] [-n steps] program\n"); return 2; }
		else prog = argv[i];
	}
	if (!prog) { fprintf(stderr, "usage: sim64 [-t] [-r] [-n steps] program\n"); return 2; }
	calibrate();
	pc = load_elf(prog);
	addregion(0x7fff000000ULL, 0x7fffffffffULL & ~(uint64_t)(PG - 1));
	r[14] = 0x7ffffff000ULL;
	for (long n = 0; n < maxsteps; n++) step();
	if (regs) regdump(stderr);
	fprintf(stderr, "sim64: step limit reached\n");
	return 124;
}

/* The executor against the tables of pdp64/16 and pdp64/32, exhaustively over the first parcel:
 *   - a first parcel is illegal (enc_len_p0 == 0, 5.0% of them) iff the executor faults with `illegal instruction`; every first parcel the tables give a
 *     length to is run, with the following parcels random, at least 3 times,
 *   - an instruction the tables decode never runs as `illegal instruction` (the sub-opcode beyond the leaf's mnemonics is the one other illegal pattern: the
 *     decoder rejects it, and so does the executor),
 *   - an instruction is `unimplemented` only if it is one of the known words (atomics, AES, SHA, UTF8DEC/ENC, MVAL, deferred loads, syspg),
 *   - the registers of a decoded instruction are below the number of registers of the encoding (r16 to r31 do not exist in pdp64/16),
 *   - no other message names an internal inconsistency ("unimplemented operand form").
 * usage: exectest-enc */
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "fmt.h"
#include "pdp64exec.h"
#include "pdp64enc.h"
#define DBASE 0x100000ULL
#define DSIZE 0x4000
#define CBASE 0x200000ULL
struct machine { struct pdp64_cpu c; uint8_t mem[DSIZE]; uint8_t code[16]; jmp_buf jb; char fault[96]; };
static struct machine *M;
static uint8_t *at(uint64_t a, int n)
{
	if (a >= DBASE && a - DBASE <= DSIZE - n) return M->mem + (a - DBASE);
	if (a >= CBASE && a - CBASE <= sizeof M->code - n) return M->code + (a - CBASE);
	return NULL;
}
static void flt(const char *what) { snprintf(M->fault, sizeof M->fault, "%s", what); longjmp(M->jb, 1); }
static uint64_t h_ld(void *u, uint64_t a, int n)
{
	uint64_t v = 0;
	if (n > 1 && (a & (n - 1))) flt("misaligned");
	uint8_t *p = at(a, n);
	if (!p) flt("unmapped");
	for (int i = 0; i < n; i++) v |= (uint64_t)p[i] << (8 * i);
	return v;
}
static void h_st(void *u, uint64_t a, int n, uint64_t v)
{
	if (n > 1 && (a & (n - 1))) flt("misaligned");
	uint8_t *p = at(a, n);
	if (!p) flt("unmapped");
	for (int i = 0; i < n; i++) p[i] = v >> (8 * i);
}
static void h_fault(void *u, const char *what, uint64_t a) { flt(what); __builtin_unreachable(); }
static void h_trap(void *u, int n) { flt("trap"); }
static void h_halt(void *u) { flt("halt"); }
static int h_probe(void *u, uint64_t a, int w, int m) { return at(a, 1) != NULL; }
static uint64_t h_fetch(void *u, uint64_t a) { return h_ld(u, a, 2); }
static int h_vecread(void *u, uint64_t a, uint64_t *v) { return 1; }
static void h_check(void *u, uint64_t a, int n, int w) { if (n > 1 && (a & (n - 1))) flt("misaligned"); if (!at(a, n)) flt("unmapped"); }
static void h_tlb(void *u, int op, uint64_t a) { }
static void h_raise(void *u, int vector, uint64_t eva) { flt("exception"); __builtin_unreachable(); }
static const struct pdp64_env env = { h_ld, h_st, h_fault, h_trap, h_halt, h_probe, h_fetch, h_vecread, h_check, h_tlb, h_raise, NULL, NULL };
static uint64_t seed = 99;
static uint64_t rnd(void) { seed = seed * 6364136223846793005ULL + 1442695040888963407ULL; return seed >> 11 ^ seed << 20; }
static const char *const known[] = { "cas", "swap", "xadd", "xand", "xor_", "xxor", "xmax", "xmin", "ll", "sc", "aes", "sha", "msha", "maesctr", "utf8dec", "utf8enc", "mval", ".d", ".ud", "syspg" };
static int is_known(const char *msg)
{
	const char *p = strstr(msg, "unimplemented instruction ");
	if (!p) return 0;
	p += 26;
	for (size_t i = 0; i < sizeof known / sizeof *known; i++) if (strstr(p, known[i])) return 1;
	return 0;
}
static int regs_ok(const struct einsn *in, int nregs)
{
	for (int i = 0; i < in->nops; i++) {
		const struct eop *o = &in->op[i];
		switch (o->k) {
		case EK_R: if (o->r >= nregs) return 0; break;
		case EK_B: case EK_PI: case EK_PD: if (o->r >= nregs && o->r != EBASE_DP) return 0; break;
		case EK_X: if (o->r >= nregs || o->x >= nregs) return 0; break;
		}
	}
	return 1;
}
int main(void)
{
	int bad = 0;
	M = malloc(sizeof *M);
	pdp64_init();
	for (int enc = 1; enc <= 2; enc++) {
		const struct etab *t = enc == 1 ? &enc_tab_16 : &enc_tab_32;
		long illegal = 0, ran = 0, unimpl = 0, decode_illegal = 0;
		for (int p0 = 0; p0 < 65536; p0++) {
			int n = enc_len_p0(t, (uint16_t)p0);
			if (!n) illegal++;
			for (int rep = 0; rep < (n ? 3 : 1); rep++) {
				memset(M, 0, sizeof *M);
				M->c.enc = enc; M->c.standin = 1;
				pdp64_set_psw(&M->c, MODE_USER << PSW_MODE | MODE_USER << PSW_PREV);
				for (int i = 0; i < DSIZE; i++) M->mem[i] = (uint8_t)rnd();
				for (int i = 0; i < 32; i++) M->c.r[i] = DBASE + 8 * (rnd() % 1024);
				M->c.r[14] = DBASE + 4096 + 8 * (rnd() % 256);
				for (int i = 0; i < 5; i++) { uint16_t q = i ? (uint16_t)rnd() : (uint16_t)p0; M->code[2 * i] = q; M->code[2 * i + 1] = q >> 8; }
				M->c.pc = CBASE;
				struct einsn in; uint16_t par[5];
				for (int i = 0; i < 5; i++) par[i] = M->code[2 * i] | M->code[2 * i + 1] << 8;
				int dec = n ? enc_decode(t, par, 5, &in, NULL) : 0;
				if (n && dec == 0) decode_illegal++;
				if (dec && !regs_ok(&in, t->regs)) { printf("FAIL %s: parcel %04x names a register beyond r%d\n", t->name, p0, t->regs - 1); bad++; }
				M->fault[0] = 0;
				if (!setjmp(M->jb)) pdp64_step(&M->c, &env);
				ran++;
				int isill = !strcmp(M->fault, "illegal instruction");
				if (isill != (dec == 0)) { printf("FAIL %s: parcel %04x decodes %s but the executor says '%s'\n", t->name, p0, dec ? "to an instruction" : "as illegal", M->fault); bad++; }
				if (strstr(M->fault, "unimplemented")) {
					unimpl++;
					if (!is_known(M->fault)) { printf("FAIL %s: parcel %04x: %s\n", t->name, p0, M->fault); bad++; }
				}
			}
		}
		printf("%s: %ld of 65536 first parcels illegal (%.2f%%), %ld runs, %ld illegal after decoding (sub-opcode beyond the leaf), %ld runs of a word the executor does not implement\n",
		    t->name, illegal, illegal / 655.36, ran, decode_illegal, unimpl);
		if (illegal != 3277) { printf("FAIL %s: expected 3277 illegal first parcels\n", t->name); bad++; }
	}
	printf(bad ? "exectest-enc: %d FAILED\n" : "exectest-enc: ok (%d)\n", bad);
	return bad != 0;
}

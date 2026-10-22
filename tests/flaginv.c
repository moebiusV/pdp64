/* The flag invariant (errata 39): the flags are two groups, C and {N, Z, V}; an instruction writes neither, or one group completely, never part of {N, Z, V}
 * and never conditionally.  Every instruction form of tests/flaginv.py (one line each: the parcels, then a `#` and the source text) runs on random registers and
 * memory in user and in kernel mode, each time twice, once with the four flags clear and once with them set.  A flag is WRITTEN by a run if it does not come
 * out as it went in on both runs (the final value differs from the initial one for one of them).  A run that faults says nothing.  A form is reported when
 *   - a run wrote part of {N, Z, V} (some but not all of the three), or
 *   - the set of flags it wrote is not the same on every run (a conditional write).
 * Forms listed in KNOWN are the author's pending decisions or the known exceptions and are printed as such; any other is a failure.
 * usage: flaginv forms.txt */
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "fmt.h"
#include "pdp64exec.h"
#define DBASE 0x100000ULL
#define DSIZE 0x4000
#define CBASE 0x200000ULL

struct machine { struct pdp64_cpu c; uint8_t mem[DSIZE]; uint8_t code[16]; jmp_buf jb; char fault[64]; };
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

static const struct pdp64_env env = { h_ld, h_st, h_fault, h_trap, h_halt, h_probe, h_fetch, h_vecread, h_check, h_tlb, h_raise, NULL };

static uint64_t seed = 12345;
static uint64_t rnd(void) { seed = seed * 6364136223846793005ULL + 1442695040888963407ULL; return seed >> 11 ^ seed << 20; }

static void initial(struct machine *m, int variant, int fl)
{
	memset(m, 0, sizeof *m);
	if (variant & 1) pdp64_set_psw(&m->c, MODE_KERNEL << PSW_MODE | MODE_KERNEL << PSW_PREV);
	else pdp64_set_psw(&m->c, MODE_USER << PSW_MODE | MODE_USER << PSW_PREV);
	m->c.standin = 1;
	for (int i = 0; i < DSIZE; i++) m->mem[i] = (uint8_t)rnd();
	for (int i = 0; i < 16; i++) {
		uint64_t k = rnd();
		switch ((k >> 60) & 7) {
		case 0: case 1: case 2: m->c.r[i] = DBASE + 8 * (rnd() % 1024); break;
		case 3: m->c.r[i] = DBASE + (rnd() % 8192); break;
		case 4: m->c.r[i] = (uint64_t)(int64_t)(int)(rnd() % 40) - 12; break;
		case 5: m->c.r[i] = 0x8000000000000000ULL | rnd() % 64; break;
		case 6: m->c.r[i] = rnd() % 70; break;							/* shift counts around 64, small block counts */
		default: m->c.r[i] = rnd(); break;
		}
	}
	m->c.r[14] = DBASE + 4096 + 8 * (rnd() % 256);
	if (variant & 2) { m->c.r[6] = rnd() % 9; m->c.r[3] = DBASE + 8 * (rnd() % 64); m->c.r[4] = rnd() % 3; }	/* shift counts 0, 1, 2 */	/* small counts for the block instructions */
	m->c.fN = m->c.fZ = m->c.fV = m->c.fC = fl;
	m->c.dp = DBASE;
}

static int run(struct machine *m, const uint16_t *parcels, int n)
{
	M = m;
	for (int i = 0; i < n; i++) { m->code[2 * i] = parcels[i] & 255; m->code[2 * i + 1] = parcels[i] >> 8; }
	m->c.pc = CBASE;
	m->fault[0] = 0;
	if (setjmp(m->jb) == 0) pdp64_step(&m->c, &env);
	return m->fault[0] != 0;
}

/* the forms whose flag behaviour is not the invariant, and why (reported, not failed) */
static const char *known(const char *src)
{
	static const char *rot[] = { "ror ", "rori ", "rori32 ", "dshr ", "rol ", "asl", NULL };
	static const char *rdc[] = { "adc", "sbc", NULL };
	for (int i = 0; rdc[i]; i++) if (!strncmp(src, rdc[i], 3)) return "reads C: the two probe runs differ in the carry in, so the result and Z/N/V differ; it writes N Z V C (by hand)";
	for (int i = 0; rot[i]; i++) if (!strncmp(src, rot[i], strlen(rot[i]))) return "rotate/ASL flags: the author's pending decision (errata 39)";
	return NULL;
}

int main(int argc, char **argv)
{
	FILE *f = fopen(argv[1], "r");
	char line[512];
	long norun = 0, forms = 0, runs = 0, faults = 0, bad = 0, unknown_bad = 0;
	pdp64_init();
	struct machine *a = malloc(sizeof *a), *b = malloc(sizeof *b);
	if (!f) { perror(argv[1]); return 2; }
	while (fgets(line, sizeof line, f)) {
		char *hash = strchr(line, '#');
		if (!hash) continue;
		unsigned p[4]; int n = sscanf(line, "%x %x %x %x", &p[0], &p[1], &p[2], &p[3]);
		uint16_t w[4];
		for (int i = 0; i < n; i++) w[i] = (uint16_t)p[i];
		char *src = hash + 1; while (*src == ' ') src++;
		src[strcspn(src, "\n")] = 0;
		forms++;
		unsigned seen = 0;		/* bit k set: some run wrote exactly the flag set k (bits: C=1, V=2, Z=4, N=8) */
		int partial = 0, ran = 0;
		for (int v = 0; v < 4; v++)
			for (int s = 0; s < 24; s++) {
				seed = (uint64_t)forms * 100003 + v * 1009 + s;
				initial(a, v, 0); memcpy(b, a, sizeof *a);
				b->c.fN = b->c.fZ = b->c.fV = b->c.fC = 1;
				int f0 = run(a, w, n), f1 = run(b, w, n);
				runs++;
				if (f0 || f1) { faults++; continue; }
				ran++;
				unsigned W = 0;
				if (a->c.fC != 0 || b->c.fC != 1) W |= 1;
				if (a->c.fV != 0 || b->c.fV != 1) W |= 2;
				if (a->c.fZ != 0 || b->c.fZ != 1) W |= 4;
				if (a->c.fN != 0 || b->c.fN != 1) W |= 8;
				seen |= 1u << W;
				if ((W & 14) != 0 && (W & 14) != 14) partial = 1;
			}
		int cond = __builtin_popcount(seen) > 1;
		if (partial || cond) {
			const char *why = known(src);
			bad++; if (!why) unknown_bad++;
			printf("%s %-34s %s%s; written-flag sets seen:", why ? "KNOWN" : "FAIL ", src, partial ? "PARTIAL " : "", cond ? "CONDITIONAL " : "");
			for (int k = 0; k < 16; k++) if (seen >> k & 1) printf(" {%s%s%s%s}", k & 8 ? "N" : "", k & 4 ? "Z" : "", k & 2 ? "V" : "", k & 1 ? "C" : "");
			if (why) printf("  [%s]", why);
			printf("\n");
		}
		if (!ran) norun++;
	}
	printf("flaginv: %ld instruction forms (%ld always fault: trap, bpt, halt, not implemented), %ld runs (%ld faulted), %ld outside the invariant, %ld not explained\n", forms, norun, runs, faults, bad, unknown_bad);
	return unknown_bad != 0 || forms == 0;
}

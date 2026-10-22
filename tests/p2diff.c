/* Differential test of page 2: every page-2 word runs on the shared core and so does the page-1 instruction it abbreviates, on the same initial
 * registers and memory, and everything must come out the same: registers, flags, memory, whether and how it faulted, and the pc (advanced by the
 * length of each).  The pairs come from tools/check-p2.sh (tests/p2diff.py): the page-2 word is built from the specification's table, the page-1
 * instruction is what as64 assembles (--no-p2) from the abbreviated instruction's text, so the table in common/p2.c is checked against two
 * independent sources.  Input, one pair per line: the page-2 word in hex, then the parcels of the page-1 instruction in hex.
 * usage: p2diff pairs.txt [mutate]   (with a second argument it flips the result of one case, to show that a mismatch is caught) */
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

static void initial(struct machine *m, int variant)
{
	memset(m, 0, sizeof *m);
	if (variant & 4) pdp64_set_psw(&m->c, MODE_KERNEL << PSW_MODE | MODE_KERNEL << PSW_PREV);	/* half of the states in kernel mode (isync, pushx, popx run), half in user mode */
	else pdp64_set_psw(&m->c, MODE_USER << PSW_MODE | MODE_USER << PSW_PREV);	/* user mode and the stand-in, as sim64 without options */
	m->c.standin = 1;
	for (int i = 0; i < DSIZE; i++) m->mem[i] = (uint8_t)rnd();
	for (int i = 0; i < 16; i++) {
		uint64_t k = rnd();
		switch ((k >> 60) & 7) {
		case 0: case 1: case 2: m->c.r[i] = DBASE + 8 * (rnd() % 1024); break;			/* an aligned pointer into the data */
		case 3: m->c.r[i] = DBASE + (rnd() % 8192); break;				/* any pointer */
		case 4: m->c.r[i] = (uint64_t)(int64_t)(int)(rnd() % 40) - 12; break;		/* a small number, negative too */
		case 5: m->c.r[i] = 0x8000000000000000ULL | rnd() % 64; break;
		default: m->c.r[i] = rnd(); break;
		}
		if (variant & 1 && i == 14) m->c.r[i] = DBASE + 4096 + 8 * (rnd() % 256);		/* sp: room below and above */
	}
	if (variant & 2) m->c.r[14] = DBASE + 4096 + 8 * (rnd() % 256);
	m->c.fN = rnd() & 1; m->c.fZ = rnd() & 1; m->c.fV = rnd() & 1; m->c.fC = rnd() & 1;
	m->c.dp = DBASE; m->c.fpsr = 0;
}

static int run(struct machine *m, const uint16_t *parcels, int n, int *faulted)
{
	M = m;
	for (int i = 0; i < n; i++) { m->code[2 * i] = parcels[i] & 255; m->code[2 * i + 1] = parcels[i] >> 8; }
	m->c.pc = CBASE;
	m->fault[0] = 0;
	if (setjmp(m->jb) == 0) pdp64_step(&m->c, &env);
	*faulted = m->fault[0] != 0;
	return 0;
}

int main(int argc, char **argv)
{
	FILE *f = fopen(argv[1], "r");
	char line[256];
	long cases = 0, runs = 0, faults = 0, bad = 0;
	pdp64_init();
	struct machine *a = malloc(sizeof *a), *b = malloc(sizeof *b);
	if (!f) { perror(argv[1]); return 2; }
	while (fgets(line, sizeof line, f)) {
		unsigned p[4]; int n = sscanf(line, "%x %x %x %x", &p[0], &p[1], &p[2], &p[3]);
		if (n < 2) continue;
		uint16_t two[1] = { (uint16_t)p[0] }, lng[3];
		for (int i = 1; i < n; i++) lng[i - 1] = (uint16_t)p[i];
		cases++;
		for (int v = 0; v < 8; v++) {
			seed = (uint64_t)cases * 7919 + v;
			initial(a, v); memcpy(b, a, sizeof *a);
			int fa, fb;
			run(a, two, 1, &fa); run(b, lng, n - 1, &fb);
			int same = fa == fb && !strcmp(a->fault, b->fault);
			if (argc > 2 && cases == 100 && v == 3) same = 0;		/* the deliberate mismatch */
			if (same && !fa) {
				same = memcmp(a->c.r, b->c.r, sizeof a->c.r) == 0 && a->c.fN == b->c.fN && a->c.fZ == b->c.fZ && a->c.fV == b->c.fV && a->c.fC == b->c.fC &&
				    a->c.dp == b->c.dp && a->c.fpsr == b->c.fpsr && memcmp(a->mem, b->mem, DSIZE) == 0 &&
				    a->c.pc == CBASE + 2 && b->c.pc == CBASE + 2 * (n - 1);
			}
			runs++; faults += fa;
			if (!same) { bad++; if (bad < 10) printf("MISMATCH %s  (variant %d, faults %d/%d %s/%s)\n", line, v, fa, fb, a->fault, b->fault); }
		}
	}
	printf("p2diff: %ld instructions x 8 states = %ld runs (%ld faulted alike), %ld mismatches\n", cases, runs, faults, bad);
	return bad != 0 || cases == 0;
}

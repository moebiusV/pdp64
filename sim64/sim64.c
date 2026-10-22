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
#include "pdp64exec.h"
#include "pdp64-consts.h"
#include "relocs.h"
#include "elf-parser.c"

/* ------------------------------------------------------------------------------------------------------------------ */
/* state                                                                                                               */

static struct pdp64_cpu cpu;
static int trace, maxsteps = 200000000;

static void regdump(FILE *o)
{
	for (int i = 0; i < 16; i++) fprintf(o, "r%-2d %016llx%s", i, (unsigned long long)cpu.r[i], i % 4 == 3 ? "\n" : "  ");
	fprintf(o, "pc  %016llx  N%d Z%d V%d C%d  fpsr %02llx\n", (unsigned long long)cpu.pc, cpu.fN, cpu.fZ, cpu.fV, cpu.fC, (unsigned long long)cpu.fpsr);
}
static void die(const char *what, uint64_t addr)
{
	fprintf(stderr, "sim64: %s at pc=%#llx addr=%#llx\n", what, (unsigned long long)cpu.cur_pc, (unsigned long long)addr);
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

static void syscall_n(int n)
{
	switch (n) {
	case 0: fflush(stdout); exit((int)(cpu.r[0] & 255));
	case 1: {
		uint64_t a = cpu.r[1], len = cpu.r[2];
		for (uint64_t i = 0; i < len; i++) { uint8_t c = *bp(a + i, 0); if (write((int)cpu.r[0], &c, 1) != 1) break; }
		cpu.r[0] = len;
		break;
	}
	case 2: {
		uint64_t a = cpu.r[1], len = cpu.r[2];
		uint8_t *tmp = malloc(len + 1);
		ssize_t got = read((int)cpu.r[0], tmp, len);
		for (ssize_t i = 0; i < got; i++) *bp(a + i, 1) = tmp[i];
		free(tmp);
		cpu.r[0] = (uint64_t)got;
		break;
	}
	default: die("unknown system call", n);
	}
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the host's side of the shared instruction core (common/pdp64exec.c)                                                 */

static uint64_t h_ld(void *u, uint64_t a, int size) { (void)u; return ld(a, size); }
static void h_st(void *u, uint64_t a, int size, uint64_t v) { (void)u; st(a, size, v); }
static void h_fault(void *u, const char *what, uint64_t addr) { (void)u; die(what, addr); }
static void h_trap(void *u, int n) { (void)u; syscall_n(n); }
static void h_halt(void *u) { (void)u; if (trace) regdump(stderr); fflush(stdout); exit((int)(cpu.r[0] & 255)); }
static int h_mapped(void *u, uint64_t a) { (void)u; return mapped(a); }
static const struct pdp64_env env = { h_ld, h_st, h_fault, h_trap, h_halt, h_mapped, NULL };

static void step(void)
{
	if (trace) {
		int len = pdp64_insn_parcels((uint16_t)ld(cpu.pc, 2)) - 1;
		fprintf(stderr, "%08llx:", (unsigned long long)cpu.pc);
		for (int i = 0; i <= len; i++) fprintf(stderr, " %04x", (unsigned)ld(cpu.pc + 2 * i, 2));
		fprintf(stderr, "\n");
	}
	pdp64_step(&cpu, &env);
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
	pdp64_init();
	cpu.pc = load_elf(prog);
	addregion(0x7fff000000ULL, 0x7fffffffffULL & ~(uint64_t)(PG - 1));
	cpu.r[14] = 0x7ffffff000ULL;
	for (long n = 0; n < maxsteps; n++) step();
	if (regs) regdump(stderr);
	fprintf(stderr, "sim64: step limit reached\n");
	return 124;
}
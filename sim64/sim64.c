/* sim64: a reference emulator for pdp64 (user mode).
 *
 * It loads an ELF executable written by ld64, decodes each instruction with the generated decoder (spec/pdp64.hbnf, through fmtp.c) and
 * executes it.  The widths of the displacement fields come from the same calibration as the assembler's (common/calib.c); the numbers of
 * the instructions are the names of pdp64-consts.h.  What each instruction does is written here.
 *
 *   sim64 [-t] [-r] [-k | -K] [-i N:LEVEL:VECTOR] [-n steps] program
 *
 *   -t  trace: one line per instruction, to standard error     -r  print the registers and flags when the program stops
 *   -n  stop after that many instructions (default 200 million)
 *   -k  start in kernel mode (privileged instructions allowed); the system-call stand-in stays
 *   -K  System v1 kernel mode: start in kernel mode at priority 7, flat physical memory, no MMU; faults, traps and interrupts are exceptions
 *       delivered through the vector table at the physical address in VBR (the stand-in is off: trap #n is vector 256 + n, halt exits with r0)
 *   -i N:LEVEL:VECTOR  (with -K, repeatable) an interrupt request of that level and vector, raised once N instructions have been started; it stays pending
 *       until it is taken.  wfe jumps to the next pending request (and stops with status 125 if none can be taken).
 *
 * The system call interface is a stand-in until there is an operating system (docs/sim64.md): `trap #n` with n = 0 exit(r0), 1 write(r0
 * fd, r1 buffer, r2 length) returning the count in r0, 2 read(...).  `halt` stops with the status in r0.  The program's exit status is the
 * emulator's.  A fault (misaligned data, an unmapped address, an unimplemented instruction, a divide by zero) prints a message and exits 139.
 */
#include <errno.h>
#include <setjmp.h>
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
static jmp_buf jb;				/* -K: an abort unwinds to the main loop */
static int jvec;
static uint64_t jeva;
struct irq { long count; int level, vector, done; } irqs[64];
static int nirqs;
static long steps;

static void regdump(FILE *o)
{
	for (int i = 0; i < 16; i++) fprintf(o, "r%-2d %016llx%s", i, (unsigned long long)cpu.r[i], i % 4 == 3 ? "\n" : "  ");
	fprintf(o, "pc  %016llx  N%d Z%d V%d C%d  fpsr %02llx  psw %04x\n", (unsigned long long)cpu.pc, cpu.fN, cpu.fZ, cpu.fV, cpu.fC, (unsigned long long)cpu.fpsr, pdp64_psw(&cpu));
}
static void die(const char *what, uint64_t addr)
{
	fprintf(stderr, "sim64: %s at pc=%#llx addr=%#llx\n", what, (unsigned long long)cpu.cur_pc, (unsigned long long)addr);
	regdump(stderr);
	exit(139);
}

/* a fault of the access: an abort with this vector when exceptions are delivered, otherwise the end of the program */
static void memfault(int vector, const char *what, uint64_t addr)
{
	if (cpu.deliver) { jvec = vector; jeva = addr; longjmp(jb, 1); }
	die(what, addr);
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
	if (!p) memfault(VECTOR_BUSFAULT, "access to unmapped memory", a);
	return p + (a & (PG - 1));
}
static uint64_t ld(uint64_t a, int size)
{
	uint64_t v = 0;
	if (size > 1 && (a & (size - 1))) memfault(VECTOR_MISALIGNED, "misaligned data access", a);
	for (int i = 0; i < size; i++) v |= (uint64_t)*bp(a + i, 0) << (8 * i);
	return v;
}
static void st(uint64_t a, int size, uint64_t v)
{
	if (size > 1 && (a & (size - 1))) memfault(VECTOR_MISALIGNED, "misaligned data access", a);
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
static int h_probe(void *u, uint64_t a, int write, int mode) { (void)u; (void)write; (void)mode; return mapped(a); }
static uint64_t h_fetch(void *u, uint64_t a) { (void)u; return ld(a, 2); }
static int h_vecread(void *u, uint64_t pa, uint64_t *v)
{
	(void)u;
	if (!mapped(pa) || !mapped(pa + 7)) return 1;
	*v = 0;
	for (int i = 0; i < 8; i++) *v |= (uint64_t)*bp(pa + i, 0) << (8 * i);
	return 0;
}
static void h_check(void *u, uint64_t a, int size, int write) { (void)u; (void)write; if (a & (size - 1)) memfault(VECTOR_MISALIGNED, "misaligned data access", a); bp(a, 0); bp(a + size - 1, 0); }
static void h_tlb(void *u, int op, uint64_t a) { (void)u; (void)op; (void)a; }
static void h_raise(void *u, int vector, uint64_t eva) { (void)u; jvec = vector; jeva = eva; longjmp(jb, 1); }
static const struct pdp64_env env = { h_ld, h_st, h_fault, h_trap, h_halt, h_probe, h_fetch, h_vecread, h_check, h_tlb, h_raise, NULL };

/* -K: the pending interrupt requests; the highest level above the priority is taken */
static int take_interrupt(void)
{
	int best = -1;
	for (int i = 0; i < nirqs; i++)
		if (!irqs[i].done && irqs[i].count <= steps && (best < 0 || irqs[i].level > irqs[best].level)) best = i;
	if (best >= 0 && pdp64_interrupt(&cpu, &env, irqs[best].level, irqs[best].vector)) { irqs[best].done = 1; return 1; }
	return 0;
}

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

static void step_k(void)
{
	if (setjmp(jb)) { pdp64_exception(&cpu, &env, jvec, jeva); return; }
	take_interrupt();
	while (cpu.wait) {								/* wfe: nothing runs until a request arrives */
		long next = -1;
		for (int i = 0; i < nirqs; i++) if (!irqs[i].done && (next < 0 || irqs[i].count < next)) next = irqs[i].count;
		if (next < 0 || (steps < next && (steps = next, 0)) || !take_interrupt()) {
			fprintf(stderr, "sim64: wfe at pc=%#llx with no interrupt that can be taken\n", (unsigned long long)cpu.pc);
			exit(125);
		}
	}
	step();
}

int main(int argc, char **argv)
{
	int regs = 0, mode = MODE_USER, sys = 0;
	const char *prog = NULL;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-t")) trace = 1;
		else if (!strcmp(argv[i], "-r")) regs = 1;
		else if (!strcmp(argv[i], "-k")) mode = MODE_KERNEL;
		else if (!strcmp(argv[i], "-K")) mode = MODE_KERNEL, sys = 1;
		else if (!strcmp(argv[i], "-i") && i + 1 < argc && nirqs < 64) {
			struct irq *q = &irqs[nirqs++];
			if (sscanf(argv[++i], "%ld:%d:%d", &q->count, &q->level, &q->vector) != 3 || q->level < 1 || q->level > 7 || q->vector < 0 || q->vector >= VECTOR_COUNT) { fprintf(stderr, "sim64: -i N:LEVEL:VECTOR\n"); return 2; }
		}
		else if (!strcmp(argv[i], "-n") && i + 1 < argc) maxsteps = atoi(argv[++i]);
		else if (argv[i][0] == '-') { fprintf(stderr, "usage: sim64 [-t] [-r] [-k | -K] [-i N:LEVEL:VECTOR] [-n steps] program\n"); return 2; }
		else prog = argv[i];
	}
	if (!prog) { fprintf(stderr, "usage: sim64 [-t] [-r] [-k | -K] [-i N:LEVEL:VECTOR] [-n steps] program\n"); return 2; }
	pdp64_init();
	pdp64_set_psw(&cpu, mode << PSW_MODE | mode << PSW_PREV | (sys ? 7 << PSW_PRI : 0));
	cpu.deliver = sys; cpu.standin = !sys;
	cpu.pc = load_elf(prog);
	addregion(0x7fff000000ULL, 0x7fffffffffULL & ~(uint64_t)(PG - 1));
	cpu.r[14] = 0x7ffffff000ULL;
	for (steps = 0; steps < maxsteps; steps++) { if (sys) step_k(); else step(); }
	if (regs) regdump(stderr);
	fprintf(stderr, "sim64: step limit reached\n");
	return 124;
}

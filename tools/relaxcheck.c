/* relaxcheck: the self-consistency check of a linked (relaxed) executable of pdp64/16 or pdp64/32 (docs/relaxation.md).
 *   relaxcheck program.x starts.txt [-datasyms] [-slack bytes]
 * starts.txt: the address (hex) of every instruction of the executable segment, ascending, from the assembler's own list (tools/check-relax.py joins as64
 * --dump-lens with ld64 --dump-map).  Each is decoded with the C decoder and:
 *   - its length is the decoder's and does not run into the next instruction; what lies between two instructions is padding or data;
 *   - every global symbol of the text segment is an instruction start (-datasyms: or lies in the data between instructions, never inside an instruction: for
 *     programs that keep tables in .text);
 *   - a branch, call or jmp lands on an instruction start (no other address in the text segment);
 *   - another pc-relative operand lands inside the segments of the program (and, in the text segment, never in the middle of an instruction, and
 *     on a multiple of the access size when it is in data between instructions: a literal pool);
 * -slack: bytes beyond the end of the data segment that an address may name (stub objects that are smaller than the objects they stand for).
 * Prints a summary and exits 1 if anything is wrong. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pdp64enc.h"

static int is_ctl(const char *mn)
{
	if (!strcmp(mn, "call") || !strcmp(mn, "jmp") || !strcmp(mn, "movcall") || !strcmp(mn, "sob") || !strcmp(mn, "br")) return 1;
	if (!strncmp(mn, "cb", 2)) return 1;
	if (mn[0] == 'b' && strlen(mn) <= 4) {
		static const char *const no[] = { "bic", "bis", "bit", "bsf", "bsr", "bicm", "bism", "bext", "bset", "bclr", 0 };
		for (int i = 0; no[i]; i++) if (!strcmp(mn, no[i])) return 0;
		return 1;
	}
	return 0;
}

static uint64_t *starts;
static long nstarts;
static long find(uint64_t a) { long lo = 0, hi = nstarts - 1; while (lo <= hi) { long m = (lo + hi) / 2; if (starts[m] == a) return m; if (starts[m] < a) lo = m + 1; else hi = m - 1; } return -(lo + 1) - 1; }

int main(int argc, char **argv)
{
	uint64_t slack = 0;
	int datasyms = 0;
	for (int i = 3; i < argc; i++) {
		if (!strcmp(argv[i], "-datasyms")) datasyms = 1;
		else if (!strcmp(argv[i], "-slack") && i + 1 < argc) slack = strtoull(argv[++i], 0, 0);
		else argc = 0;
	}
	if (argc < 3) { fprintf(stderr, "usage: relaxcheck program.x starts.txt [-datasyms] [-slack bytes]\n"); return 2; }	/* bytes beyond the data segment that an address may name (stubs that are smaller than the objects they stand for) */
	FILE *f = fopen(argv[1], "rb");
	if (!f) { perror(argv[1]); return 2; }
	fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
	uint8_t *b = malloc(n);
	if (fread(b, 1, n, f) != (size_t)n) return 2;
	uint32_t flags = b[0x30] | b[0x31] << 8 | b[0x32] << 16 | (uint32_t)b[0x33] << 24;
	struct etab *t = (flags & 15) == 1 ? &enc_tab_16 : (flags & 15) == 2 ? &enc_tab_32 : NULL;
	if (!t) { fprintf(stderr, "relaxcheck: not a pdp64/16 or pdp64/32 executable\n"); return 2; }
	uint64_t phoff = *(uint64_t *)(b + 0x20), shoff = *(uint64_t *)(b + 0x28); int phnum = b[0x38] | b[0x39] << 8, shnum = b[0x3c] | b[0x3d] << 8;
	uint64_t tva = 0, tsz = 0, toff = 0, dlo = ~0ull, dhi = 0;
	for (int i = 0; i < phnum; i++) {
		uint8_t *p = b + phoff + 56 * i;
		uint32_t pf = *(uint32_t *)(p + 4);
		uint64_t off = *(uint64_t *)(p + 8), va = *(uint64_t *)(p + 16), fsz = *(uint64_t *)(p + 32), msz = *(uint64_t *)(p + 40);
		if (pf & 1) { tva = va; tsz = fsz; toff = off; } else { if (va < dlo) dlo = va; if (va + msz > dhi) dhi = va + msz; }
	}
	FILE *g = fopen(argv[2], "r");
	if (!g) { perror(argv[2]); return 2; }
	unsigned long long a;
	long cap = 0;
	while (fscanf(g, "%llx", &a) == 1) { if (nstarts == cap) { cap = cap ? cap * 2 : 4096; starts = realloc(starts, cap * sizeof *starts); } starts[nstarts++] = a; }
	long bad = 0, ninsn = 0, ngap = 0, nctl = 0, ncall = 0, ndata = 0, npool = 0, nsym = 0, ndsym = 0;
	uint64_t gapbytes = 0;
#define BAD(...) do { if (bad++ < 30) { fprintf(stderr, "relaxcheck: %llx: ", (unsigned long long)starts[i]); fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } } while (0)
	for (long i = 0; i < nstarts; i++) {
		uint64_t pc = starts[i];
		uint16_t par[5];
		struct einsn in;
		int np = 0;
		if (pc < tva || pc >= tva + tsz || (pc & 1)) { BAD("outside the text segment, or odd"); continue; }
		for (int k = 0; k < 5 && pc + 2 * k < tva + tsz; k++) { par[k] = b[toff + pc - tva + 2 * k] | b[toff + pc - tva + 2 * k + 1] << 8; np++; }
		int len = enc_decode(t, par, np, &in, NULL);
		if (len <= 0) { BAD("does not decode (%04x)", par[0]); continue; }
		ninsn++;
		uint64_t next = i + 1 < nstarts ? starts[i + 1] : tva + tsz;
		if (pc + 2 * len > next) { BAD("%s of %d bytes runs into the next instruction at %llx", enc_mn_name(t, in.mn), 2 * len, (unsigned long long)next); continue; }
		if (pc + 2 * len < next) { ngap++; gapbytes += next - (pc + 2 * len); }
		const char *mn = enc_mn_name(t, in.mn);
		for (int k = 0; k < in.nops; k++) {
			if (in.op[k].k != EK_PC) continue;
			uint64_t T = pc + in.op[k].v;
			long j = find(T);
			if (is_ctl(mn)) {
				nctl++;
				if (!strcmp(mn, "call") || !strcmp(mn, "movcall")) ncall++;
				if (j < 0) BAD("%s to %llx, which is not the start of an instruction", mn, (unsigned long long)T);
			} else if (T >= tva && T < tva + tsz) {
				if (j >= 0) { ndata++; continue; }			/* the address of code (lea f) or data read from code */
				long q = -j - 3;					/* the instruction before T */
				if (q >= 0) {
					uint8_t *pp = b + toff + starts[q] - tva;
					uint16_t pr[5]; int m = 0, ql;
					struct einsn qi;
					for (int z = 0; z < 5; z++) { pr[z] = pp[2 * z] | pp[2 * z + 1] << 8; m++; }
					ql = enc_decode(t, pr, m, &qi, NULL);
					if (ql > 0 && T < starts[q] + 2 * ql) { BAD("%s reads %llx, the middle of the instruction at %llx", mn, (unsigned long long)T, (unsigned long long)starts[q]); continue; }
				}
				npool++;
				if (t->mn[in.mn].msz > 1 && T % t->mn[in.mn].msz) BAD("%s reads %llx, which is not a multiple of %d", mn, (unsigned long long)T, t->mn[in.mn].msz);
			} else if (T >= dlo && T <= dhi + slack) ndata++;			/* one past the end of the last object is a legitimate pointer */
			else BAD("%s refers to %llx, outside the program", mn, (unsigned long long)T);
		}
	}
	/* symbols */
	for (int s = 0; s < shnum; s++) {
		uint8_t *h = b + shoff + 64 * s;
		if (*(uint32_t *)(h + 4) != 2) continue;
		uint64_t off = *(uint64_t *)(h + 24), size = *(uint64_t *)(h + 32);
		for (uint64_t k = 24; k < size; k += 24) {
			uint8_t *y = b + off + k;
			uint64_t v = *(uint64_t *)(y + 8);
			if ((y[4] >> 4) == 1 || y[4] == 0x10) {
				if (v >= tva && v < tva + tsz) {
					nsym++;
					long i = find(v);
					if (i < 0 && !datasyms) { fprintf(stderr, "relaxcheck: symbol at %llx is not the start of an instruction\n", (unsigned long long)v); bad++; }
					else if (i < 0) {					/* data in .text (a table, a string): it must not be inside an instruction */
						long q = -i - 3;
						if (q >= 0) {
							uint8_t *pp = b + toff + starts[q] - tva;
							uint16_t pr[5]; struct einsn qi;
							for (int z = 0; z < 5; z++) pr[z] = pp[2 * z] | pp[2 * z + 1] << 8;
							int ql = enc_decode(t, pr, 5, &qi, NULL);
							if (ql > 0 && v < starts[q] + 2 * ql) { fprintf(stderr, "relaxcheck: symbol at %llx is in the middle of the instruction at %llx\n", (unsigned long long)v, (unsigned long long)starts[q]); bad++; continue; }
						}
						ndsym++;
					}
				}
			}
		}
	}
	printf("relaxcheck: %ld instructions decoded, %ld gaps (%llu bytes of padding and data), %ld branches/calls (%ld calls) on instruction starts, %ld pc-relative data operands (%ld in text), %ld text symbols (%ld of them data in .text, none inside an instruction), %ld errors\n",
	    ninsn, ngap, (unsigned long long)gapbytes, nctl, ncall, ndata + npool, npool, nsym, ndsym, bad);
	return bad ? 1 : 0;
}

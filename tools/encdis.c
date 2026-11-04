/* encdis: disassemble the executable segment of a pdp64/16 or pdp64/32 executable with the codec (a debugging aid and the oracle of tools/check-sim64-enc).
 *   encdis program.x [start [end]]       one line per instruction: address, parcels, mnemonic and operands in assembly order
 * The encoding is taken from the e_flags of the file.  Not a round-trip assembler: addresses of pc-relative operands are shown as the target. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pdp64enc.h"
static void put(const struct eop *o, uint64_t pc)
{
	static const char *rn[] = { "r0","r1","r2","r3","r4","r5","r6","r7","r8","r9","r10","r11","r12","fp","sp","r15","r16","r17","r18","r19","r20","r21","r22","r23","r24","r25","r26","r27","r28","r29","r30","r31" };
	switch (o->k) {
	case EK_R: printf("%s", rn[o->r]); break;
	case EK_I: printf("#%lld", (long long)o->v); break;
	case EK_B: printf("%lld(%s)", (long long)o->v, o->r == EBASE_DP ? "dp" : rn[o->r]); break;
	case EK_X: printf("%lld(%s)(%s*%d)", (long long)o->v, rn[o->r], rn[o->x], o->s); break;
	case EK_PI: printf("(%s)+%lld", rn[o->r], (long long)o->v); break;
	case EK_PD: printf("(%s)-%lld", rn[o->r], (long long)o->v); break;
	case EK_PC: printf("%llx", (unsigned long long)(pc + o->v)); break;
	case EK_A: printf("@%llx", (unsigned long long)o->v); break;
	}
}
int main(int argc, char **argv)
{
	if (argc < 2) { fprintf(stderr, "usage: encdis program.x [start [end]]\n"); return 2; }
	FILE *f = fopen(argv[1], "rb");
	if (!f) { perror(argv[1]); return 1; }
	fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
	uint8_t *b = malloc(n);
	if (fread(b, 1, n, f) != (size_t)n) return 1;
	uint32_t flags = b[0x30] | b[0x31] << 8 | b[0x32] << 16 | (uint32_t)b[0x33] << 24;
	struct etab *t = (flags & 15) == 1 ? &enc_tab_16 : (flags & 15) == 2 ? &enc_tab_32 : NULL;
	if (!t) { fprintf(stderr, "encdis: %s is not a pdp64/16 or pdp64/32 executable\n", argv[1]); return 1; }
	uint64_t phoff = *(uint64_t *)(b + 0x20); int phnum = b[0x38] | b[0x39] << 8;
	for (int i = 0; i < phnum; i++) {
		uint8_t *p = b + phoff + 56 * i;
		uint32_t type = *(uint32_t *)p, pf = *(uint32_t *)(p + 4);
		uint64_t off = *(uint64_t *)(p + 8), va = *(uint64_t *)(p + 16), fsz = *(uint64_t *)(p + 32);
		if (type != 1 || !(pf & 1)) continue;
		uint64_t lo = argc > 2 ? strtoull(argv[2], 0, 16) : va, hi = argc > 3 ? strtoull(argv[3], 0, 16) : va + fsz;
		for (uint64_t a = lo < va ? va : lo; a < hi && a < va + fsz;) {
			uint16_t par[5]; struct einsn in; int np = 0;
			for (int k = 0; k < 5 && a + 2 * k < va + fsz; k++) { par[k] = b[off + a - va + 2 * k] | b[off + a - va + 2 * k + 1] << 8; np++; }
			int len = enc_decode(t, par, np, &in, NULL);
			printf("%08llx:", (unsigned long long)a);
			if (len <= 0) { printf(" %04x\t.illegal\n", par[0]); a += 2; continue; }
			for (int k = 0; k < len; k++) printf(" %04x", par[k]);
			for (int k = len; k < 5; k++) printf("     ");
			printf("\t%s", enc_mn_name(t, in.mn));
			for (int k = 0; k < in.nops; k++) { printf(k ? ", " : " "); put(&in.op[k], a); }
			printf("\n");
			a += 2 * len;
		}
	}
	return 0;
}

/* encdrv: a text driver for the codec (common/pdp64enc.c), for tools/check-enc.py.  One instruction per line on stdin:
       MNEMONIC OP OP ...      OP: R:r  I:v  B:d:r  X:d:r:x:s  PI:r:d  PD:r:d  PC:v  A:v     (PC, A, I may end in :E, an external reference)
   prints, per line, either `NOENC` or `n p0 p1 ... | MNEMONIC OP ...` (the parcels in hex, then the instruction decoded back from them).
   With -d the lines are parcels in hex and the output is the decoded instruction (or ILLEGAL). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pdp64enc.h"
static struct etab *T;
static void put_op(char *o, const struct eop *p)
{
	switch (p->k) {
	case EK_R: sprintf(o, "R:%d", p->r); break;
	case EK_I: sprintf(o, "I:%lld%s", (long long)p->v, p->ext ? ":E" : ""); break;
	case EK_B: sprintf(o, "B:%lld:%d", (long long)p->v, p->r); break;
	case EK_X: sprintf(o, "X:%lld:%d:%d:%d", (long long)p->v, p->r, p->x, p->s); break;
	case EK_PI: sprintf(o, "PI:%d:%lld", p->r, (long long)p->v); break;
	case EK_PD: sprintf(o, "PD:%d:%lld", p->r, (long long)p->v); break;
	case EK_PC: sprintf(o, "PC:%lld%s", (long long)p->v, p->ext ? ":E" : ""); break;
	case EK_A: sprintf(o, "A:%lld%s", (long long)p->v, p->ext ? ":E" : ""); break;
	}
}
static void put_insn(char *line, const struct einsn *in)
{
	char o[96];
	strcpy(line, enc_mn_name(T, in->mn));
	for (int i = 0; i < in->nops; i++) { put_op(o, &in->op[i]); strcat(line, " "); strcat(line, o); }
}
static int get_op(char *t, struct eop *p)
{
	char *f[6]; int n = 0;
	memset(p, 0, sizeof *p);
	for (char *s = strtok(t, ":"); s && n < 6; s = strtok(NULL, ":")) f[n++] = s;
	if (!n) return -1;
	if (!strcmp(f[0], "R")) { p->k = EK_R; p->r = atoi(f[1]); }
	else if (!strcmp(f[0], "I")) { p->k = EK_I; p->v = strtoll(f[1], 0, 10); p->ext = n > 2; }
	else if (!strcmp(f[0], "B")) { p->k = EK_B; p->v = strtoll(f[1], 0, 10); p->r = atoi(f[2]); }
	else if (!strcmp(f[0], "X")) { p->k = EK_X; p->v = strtoll(f[1], 0, 10); p->r = atoi(f[2]); p->x = atoi(f[3]); p->s = atoi(f[4]); }
	else if (!strcmp(f[0], "PI") || !strcmp(f[0], "PD")) { p->k = f[0][1] == 'I' ? EK_PI : EK_PD; p->r = atoi(f[1]); p->v = strtoll(f[2], 0, 10); }
	else if (!strcmp(f[0], "PC")) { p->k = EK_PC; p->v = strtoll(f[1], 0, 10); p->ext = n > 2; }
	else if (!strcmp(f[0], "A")) { p->k = EK_A; p->v = strtoll(f[1], 0, 10); p->ext = n > 2; }
	else return -1;
	return 0;
}
int main(int argc, char **argv)
{
	char line[1024];
	int dec = argc > 1 && !strcmp(argv[1], "-d");
	T = &enc_tab;
	while (fgets(line, sizeof line, stdin)) {
		line[strcspn(line, "\n")] = 0;
		if (dec) {
			uint16_t p[5] = { 0 }; int np = 0, need = 0;
			char *s = strtok(line, " ");
			while (s && np < 5) { p[np++] = (uint16_t)strtoul(s, 0, 16); s = strtok(NULL, " "); }
			struct einsn in; char out[400];
			int n = enc_decode(T, p, np, &in, &need);
			if (n < 0) printf("SHORT %d\n", need);
			else if (!n) printf("ILLEGAL\n");
			else { put_insn(out, &in); printf("%d %s\n", n, out); }
			continue;
		}
		struct einsn in; char *sv, *tok = strtok_r(line, " ", &sv);
		memset(&in, 0, sizeof in);
		if (!tok) continue;
		in.mn = enc_mn_find(T, tok);
		if (in.mn < 0) { printf("NOMN\n"); continue; }
		while ((tok = strtok_r(NULL, " ", &sv)) && in.nops < 4) get_op(tok, &in.op[in.nops++]);
		uint16_t p[5]; char out[400], buf[40];
		int n = enc_encode(T, &in, p, NULL, NULL);
		if (!n) { printf("NOENC\n"); continue; }
		struct einsn d; int need;
		int m = enc_decode(T, p, n, &d, &need);
		out[0] = 0;
		for (int i = 0; i < n; i++) { sprintf(buf, "%04x ", p[i]); strcat(out, buf); }
		if (m != n) strcat(out, "| DECODE-FAILED"); else { strcat(out, "| "); put_insn(out + strlen(out), &d); }
		printf("%d %s\n", n, out);
	}
	return 0;
}

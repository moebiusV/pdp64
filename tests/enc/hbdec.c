/* hbdec: the decoder hbnf generates from the grammar of an encoding (parse_bits of spec/pdp64-NN/pdp64-NN.hbnf) against the codec of common/pdp64enc.c with the tables
 * tools/mkenc.py generates from the same grammar.  For every first parcel (65,536) and several tails: both say legal or illegal, the same length, the same leaf, and the
 * same raw value in every field (the sub-opcode, the pieces of every operand).  The two readings of the grammar are made by different programs (hbnf, and mkenc through
 * tools/encgram.py), so a disagreement is a bug in one of them.
 *
 *   cc -DT16 (or -DT32) -I build -I common tests/enc/hbdec.c common/pdp64enc.c build/pdp64-NN-tab.c   with HBDEC and HBFIELDS the generated parser and the accessor
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include "pdp64enc.h"
#include HBDEC
#include HBFIELDS
#ifdef T16
#define TAB (&enc_tab_16)
#else
#define TAB (&enc_tab_32)
#endif

static int codec_fields(const struct etab *t, int li, const uint16_t *p, int *key, uint64_t *val)
{
	const struct eleaf *lf = &t->leaves[li];
	int n = 0;
	for (int i = 0; i < lf->npl; i++) {
		const struct eplace *pl = &t->place[lf->pl0 + i];
		uint64_t v = 0;
		for (int r = 0; r < pl->nruns; r++) {
			const struct erun *ru = &t->runs[pl->run0 + r];
			v = (v << ru->len) | ((p[ru->parcel] >> (ru->hi - ru->len + 1)) & ((1u << ru->len) - 1));
		}
		key[n] = pl->oi * 16 + pl->pi;
		if (pl->oi == ESUB)
			key[n] = 0xFE0;
		val[n++] = v;
	}
	return n;
}

static void sort(int *key, uint64_t *val, int n)
{
	for (int i = 1; i < n; i++)
		for (int j = i; j > 0 && key[j - 1] > key[j]; j--) {
			int k = key[j]; key[j] = key[j - 1]; key[j - 1] = k;
			uint64_t v = val[j]; val[j] = val[j - 1]; val[j - 1] = v;
		}
}

int main(void)
{
	const struct etab *t = TAB;
	enc_init(t);
	uint32_t rng = 12345;
	long legal = 0, bad = 0, total = 0;
	int shown = 0;
	for (int p0 = 0; p0 < 65536; p0++) {
		for (int variant = 0; variant < 4; variant++) {
			uint16_t p[5];
			p[0] = p0;
			for (int i = 1; i < 5; i++) {
				rng = rng * 1664525u + 1013904223u;
				p[i] = variant == 0 ? 0 : variant == 1 ? 0xFFFF : (uint16_t)(rng >> 8);
			}
			total++;
			struct einsn in;
			int need = 0;
			int cn = enc_decode(t, p, 5, &in, &need);
			int li = t->lut[p0] - 1;
			int hn = 0, alt = 0;
			insn_t out;
			uint8_t buf[10];
			int hkey[64], ckey[64];
			uint64_t hval[64], cval[64];
			int nh = 0;
			for (int np = 1; np <= 5; np++) {
				for (int i = 0; i < np; i++) { buf[2 * i] = p[i] >> 8; buf[2 * i + 1] = p[i] & 255; }
				char err[256]; size_t at;
				memset(&out, 0, sizeof out);
				if (parse_bits(buf, 16 * np, &out, err, sizeof err, &at)) {
					if (hn) { hn = -1; break; }
					hn = np; alt = out.leaf.kind;
					nh = hb_fields(&out, hkey, hval);
				}
				free_arena();
			}
			int ok = 1;
			if (hn == -1) ok = 0;			/* two lengths both parse */
			else if ((cn > 0) != (hn > 0)) ok = 0;
			else if (cn > 0) {
				int nc = codec_fields(t, li, p, ckey, cval);
				if (cn != hn || alt != li + 1 || nc != nh) ok = 0;
				else {
					sort(hkey, hval, nh); sort(ckey, cval, nc);
					for (int i = 0; i < nc; i++)
						if (hkey[i] != ckey[i] || hval[i] != cval[i]) ok = 0;
				}
				legal++;
			}
			if (!ok) {
				bad++;
				if (shown++ < 5)
					fprintf(stderr, "hbdec: p0=%04x variant %d: codec n=%d leaf=%d, hbnf n=%d alt=%d\n", p0, variant, cn, li, hn, alt - 1);
			}
		}
	}
	printf("hbdec %s: %ld parcel sequences, %ld legal, %ld disagreements between hbnf's decoder and the codec\n", t->name, total, legal, bad);
	return bad != 0;
}

/* calib.c: what the grammar says about the instruction formats, learned by asking its generated writer (shared by as64 and sim64). */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "fmt.h"
#include "pdp64-consts.h"
#include "calib.h"

static uint64_t mask(int bits) { return bits >= 64 ? ~(uint64_t)0 : (((uint64_t)1 << bits) - 1); }

/* ---- what the grammar says about the formats, learned by asking its generated writer ------------------------------------
 * The widths of the displacement fields, which addressing mode uses which shape, and the size of the reg and low nibbles are
 * written once, in spec/pdp64.hbnf.in.  Nothing here repeats them: the writer refuses a value that does not fit, so the
 * widths are found by encoding all-ones values until it refuses, once at startup. */
int fieldbits[32][4];		/* [shape][len]: bits of the displacement field, 0 if the shape does not exist at that len */
int mode_shape[16];		/* addressing mode -> shape, 0 if no shape takes it */
int maxlen = 3;
int regbits, lowbits;
int cbimmbits;		/* bits of the immediate of cbCC */
int cbwimmbits;		/* bits of the immediate of the wide cbCC */

static int try_enc(const struct fmt *f) { uint8_t b[8]; size_t n; return fmt_encode(f, b, &n) == 0; }
/* the fields of the wide cbCC are 16 bits wide, as wide as their C types, so a value too wide is cut before the writer sees it: see whether it came back */
static int try_rt(const struct fmt *f)
{
	uint8_t b[8]; size_t n; struct fmt g;
	if (fmt_encode(f, b, &n) || fmt_decode(b, n, &g)) return 0;
	return g.imm == f->imm && g.d == f->d;
}

void calibrate(void)
{
	static const int shapes[] = { FS_BASE, FS_INDEX, FS_DP, FS_WIDE, FS_D, FS_CB, FS_CBW };
	struct fmt f;

	for (maxlen = 0; maxlen < 8; maxlen++) {
		memset(&f, 0, sizeof f); f.shape = FS_D; f.opc = MN_BRANCH_BR; f.len = maxlen + 1;
		if (!try_enc(&f)) break;
	}
	for (regbits = 0; regbits < 16; regbits++) {
		memset(&f, 0, sizeof f); f.shape = FS_MEM0; f.opc = MN_MOV_MOVQ; f.reg = (int)mask(regbits + 1);
		if (!try_enc(&f)) break;
	}
	for (lowbits = 0; lowbits < 16; lowbits++) {
		memset(&f, 0, sizeof f); f.shape = FS_MEM0; f.opc = MN_MOV_MOVQ; f.low = (int)mask(lowbits + 1);
		if (!try_enc(&f)) break;
	}
	for (cbimmbits = 0; cbimmbits < 32; cbimmbits++) {
		memset(&f, 0, sizeof f); f.shape = FS_CB; f.opc = OPGROUP_CBR; f.len = 1; f.imm = (unsigned)mask(cbimmbits + 1);
		if (!try_enc(&f)) break;
	}
	for (cbwimmbits = 0; cbwimmbits < 32; cbwimmbits++) {
		memset(&f, 0, sizeof f); f.shape = FS_CBW; f.opc = OPGROUP_CBW; f.len = 2; f.imm = (unsigned)mask(cbwimmbits + 1);
		if (!try_rt(&f)) break;
	}
	for (int m = 0; m < (1 << lowbits); m++)
		for (unsigned k = 0; k < sizeof shapes / sizeof *shapes; k++) {
			memset(&f, 0, sizeof f); f.len = 1; f.opc = MN_MOV_MOVQ; f.low = m; f.shape = shapes[k];
			if (shapes[k] == FS_D || shapes[k] == FS_CB || shapes[k] == FS_CBW) continue;
			if (try_enc(&f)) { mode_shape[m] = shapes[k]; break; }
		}
	for (unsigned k = 0; k < sizeof shapes / sizeof *shapes; k++)
		for (int len = 1; len <= maxlen; len++) {
			int mode = -1;
			memset(&f, 0, sizeof f); f.len = len; f.shape = shapes[k];
			if (shapes[k] == FS_D) f.opc = MN_BRANCH_BR;
			else if (shapes[k] == FS_CB) f.opc = OPGROUP_CBR;
			else if (shapes[k] == FS_CBW) f.opc = OPGROUP_CBW;
			else {
				f.opc = MN_MOV_MOVQ;
				for (int m = 0; m < (1 << lowbits); m++) if (mode_shape[m] == shapes[k]) { mode = m; break; }
				if (mode < 0) continue;
				f.low = mode;
			}
			int w = 0;
			while (w < 64) {
				f.d = mask(w + 1);
				if (!(shapes[k] == FS_CBW ? try_rt(&f) : try_enc(&f))) break;
				w++;
			}
			fieldbits[shapes[k]][len] = w;
		}
}

/* the limits a compiler needs, as a header, measured from the generated encoder (as64 --limits) */
static void print_limits(void);

int dispbits(int mode, int len) { return fieldbits[mode_shape[mode]][len]; }
int branchbits(int len) { return fieldbits[FS_D][len]; }
int cbbits(int len) { return fieldbits[FS_CB][len]; }
int cbwbits(int len) { return fieldbits[FS_CBW][len]; }


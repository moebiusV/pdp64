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
int fieldbits[16][4];		/* [shape][len]: bits of the displacement field, 0 if the shape does not exist at that len */
int mode_shape[16];		/* addressing mode -> shape, 0 if no shape takes it */
int maxlen = 3;
int regbits, lowbits;

static int try_enc(const struct fmt *f) { uint8_t b[8]; size_t n; return fmt_encode(f, b, &n) == 0; }

void calibrate(void)
{
	static const int shapes[] = { FS_BASE, FS_INDEX, FS_DP, FS_WIDE, FS_D };
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
	for (int m = 0; m < (1 << lowbits); m++)
		for (unsigned k = 0; k < sizeof shapes / sizeof *shapes; k++) {
			memset(&f, 0, sizeof f); f.len = 1; f.opc = MN_MOV_MOVQ; f.low = m; f.shape = shapes[k];
			if (shapes[k] == FS_D) continue;
			if (try_enc(&f)) { mode_shape[m] = shapes[k]; break; }
		}
	for (unsigned k = 0; k < sizeof shapes / sizeof *shapes; k++)
		for (int len = 1; len <= maxlen; len++) {
			int mode = -1;
			memset(&f, 0, sizeof f); f.len = len; f.shape = shapes[k];
			if (shapes[k] == FS_D) f.opc = MN_BRANCH_BR;
			else {
				f.opc = MN_MOV_MOVQ;
				for (int m = 0; m < (1 << lowbits); m++) if (mode_shape[m] == shapes[k]) { mode = m; break; }
				if (mode < 0) continue;
				f.low = mode;
			}
			int w = 0;
			while (w < 64) {
				f.d = mask(w + 1);
				if (!try_enc(&f)) break;
				w++;
			}
			fieldbits[shapes[k]][len] = w;
		}
}

/* the limits a compiler needs, as a header, measured from the generated encoder (as64 --limits) */
static void print_limits(void);

int dispbits(int mode, int len) { return fieldbits[mode_shape[mode]][len]; }
int branchbits(int len) { return fieldbits[FS_D][len]; }


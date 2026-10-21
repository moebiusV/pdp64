/* One decoded or to-be-encoded instruction: the fields of spec/pdp64.hbnf as plain C.  `shape` is the alternative of the
   `body` of the grammar; it says which of the remaining fields mean anything. */
#ifndef FMT_H
#define FMT_H
#include <stddef.h>
#include <stdint.h>

enum fmt_shape {
	FS_MEM0 = 1,	/* len 0, memory class: low is a register */
	FS_BASE,	/* rm d: base register modes (0, 6, 7) */
	FS_INDEX,	/* rm rx s d */
	FS_DP,		/* d (pad is zero) */
	FS_WIDE,	/* d: pc-relative, immediate, absolute */
	FS_REGESC,	/* sub t x more */
	FS_MEMESC,	/* sub rm d */
	FS_BR0,		/* len 0 branch: reg:low is the displacement */
	FS_D,		/* d: branch, SOB, TAGOP */
	FS_SYS0,	/* len 0 SYS */
	FS_SYSP		/* p: SYS payload */
};

struct fmt {
	int len, opc, reg, low;
	int shape;
	unsigned rm, rx, s, sub, t, x;
	uint64_t d;	/* displacement, immediate, address; `more` of FS_REGESC; `p` of FS_SYSP */
};

/* parcels are written big-endian in both directions; the caller swaps them to little-endian for memory */
int fmt_encode(const struct fmt *f, uint8_t *out, size_t *n);
int fmt_decode(const uint8_t *buf, size_t n, struct fmt *f);
#endif

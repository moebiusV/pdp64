/* fmtp.c: the generated instruction-format parser and writer (spec/pdp64.hbnf) behind a plain interface. */
#include <string.h>
#include "pdp64-parser.c"
#include "fmt.h"

int fmt_encode(const struct fmt *f, uint8_t *out, size_t *n)
{
	insn_t i;
	char err[160];

	memset(&i, 0, sizeof i);
	i.len = f->len; i.opc = f->opc; i.reg = f->reg; i.low = f->low;
	i.body.kind = f->shape;
	switch (f->shape) {
	case FS_BASE:   i.body.u.a2.rm = f->rm; i.body.u.a2.d = f->d; break;
	case FS_INDEX:  i.body.u.a3.rm = f->rm; i.body.u.a3.rx = f->rx; i.body.u.a3.s = f->s; i.body.u.a3.d = f->d; break;
	case FS_DP:     i.body.u.a4.d = f->d; break;
	case FS_WIDE:   i.body.u.a5.d = f->d; break;
	case FS_REGESC: i.body.u.a6.sub = f->sub; i.body.u.a6.t = f->t; i.body.u.a6.x = f->x; i.body.u.a6.more = f->d; break;
	case FS_MEMESC: i.body.u.a7.sub = f->sub; i.body.u.a7.rm = f->rm; i.body.u.a7.d = f->d; break;
	case FS_D:      i.body.u.a9.d = f->d; break;
	case FS_SYSP:   i.body.u.a11.p = f->d; break;
	}
	return emit_bytes(&i, out, 8, n, err, sizeof err) ? 0 : -1;
}

int fmt_decode(const uint8_t *buf, size_t n, struct fmt *f)
{
	insn_t i;
	char err[160];
	size_t at;

	memset(f, 0, sizeof *f);
	if (!parse_bytes(buf, n, &i, err, sizeof err, &at))
		return -1;
	f->len = i.len; f->opc = i.opc; f->reg = i.reg; f->low = i.low;
	f->shape = i.body.kind;
	switch (f->shape) {
	case FS_BASE:   f->rm = i.body.u.a2.rm; f->d = i.body.u.a2.d; break;
	case FS_INDEX:  f->rm = i.body.u.a3.rm; f->rx = i.body.u.a3.rx; f->s = i.body.u.a3.s; f->d = i.body.u.a3.d; break;
	case FS_DP:     f->d = i.body.u.a4.d; break;
	case FS_WIDE:   f->d = i.body.u.a5.d; break;
	case FS_REGESC: f->sub = i.body.u.a6.sub; f->t = i.body.u.a6.t; f->x = i.body.u.a6.x; f->d = i.body.u.a6.more; break;
	case FS_MEMESC: f->sub = i.body.u.a7.sub; f->rm = i.body.u.a7.rm; f->d = i.body.u.a7.d; break;
	case FS_D:      f->d = i.body.u.a9.d; break;
	case FS_SYSP:   f->d = i.body.u.a11.p; break;
	}
	return 0;
}

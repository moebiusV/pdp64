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
	case FS_COUNT:  i.body.u.a6.sub = f->sub; i.body.u.a6.count = f->count; i.body.u.a6.more = f->d; break;
	case FS_FIELD:  i.body.u.a7.sub = f->sub; i.body.u.a7.t = f->t; i.body.u.a7.x = f->x; i.body.u.a7.pos = f->pos; i.body.u.a7.width = f->width; i.body.u.a7.more = f->d; break;
	case FS_REGESC: i.body.u.a8.sub = f->sub; i.body.u.a8.t = f->t; i.body.u.a8.x = f->x; i.body.u.a8.more = f->d; break;
	case FS_MEMESC: i.body.u.a9.sub = f->sub; i.body.u.a9.rm = f->rm; i.body.u.a9.d = f->d; break;
	case FS_D:      i.body.u.a11.d = f->d; break;
	case FS_SYSRD:  i.body.u.a13.rd = f->rd; break;
	case FS_SYSN:   i.body.u.a14.n = f->n; break;
	case FS_SYSP:   i.body.u.a15.p = f->d; break;
	case FS_CB:     i.body.u.a16.imm = f->imm; i.body.u.a16.d = f->d; break;
	case FS_CBW:    i.body.u.a19.imm = f->imm; i.body.u.a19.d = f->d; break;
	case FS_CBR:    i.body.u.a20.cond = f->x; i.body.u.a20.d = f->d; break;
	case FS_SYSX:   i.body.u.a21.sub = f->sub; i.body.u.a21.pad = f->n; break;
	case FS_SYSREG: i.body.u.a17.sr = f->sub; i.body.u.a17.r = f->rd; i.body.u.a17.pad = f->n; break;
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
	case FS_COUNT:  f->sub = i.body.u.a6.sub; f->count = i.body.u.a6.count; f->d = i.body.u.a6.more; break;
	case FS_FIELD:  f->sub = i.body.u.a7.sub; f->t = i.body.u.a7.t; f->x = i.body.u.a7.x; f->pos = i.body.u.a7.pos; f->width = i.body.u.a7.width; f->d = i.body.u.a7.more; break;
	case FS_REGESC: f->sub = i.body.u.a8.sub; f->t = i.body.u.a8.t; f->x = i.body.u.a8.x; f->d = i.body.u.a8.more; break;
	case FS_MEMESC: f->sub = i.body.u.a9.sub; f->rm = i.body.u.a9.rm; f->d = i.body.u.a9.d; break;
	case FS_D:      f->d = i.body.u.a11.d; break;
	case FS_SYSRD:  f->rd = i.body.u.a13.rd; break;
	case FS_SYSN:   f->n = i.body.u.a14.n; break;
	case FS_SYSP:   f->d = i.body.u.a15.p; break;
	case FS_CB:     f->imm = i.body.u.a16.imm; f->d = i.body.u.a16.d; break;
	case FS_CBW:    f->imm = i.body.u.a19.imm; f->d = i.body.u.a19.d; break;
	case FS_CBR:    f->x = i.body.u.a20.cond; f->d = i.body.u.a20.d; break;
	case FS_SYSX:   f->sub = i.body.u.a21.sub; f->n = i.body.u.a21.pad; break;
	case FS_SYSREG: f->sub = i.body.u.a17.sr; f->rd = i.body.u.a17.r; f->n = i.body.u.a17.pad; break;
	}
	return 0;
}

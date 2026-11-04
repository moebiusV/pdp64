/* relax.c: linker relaxation (docs/relaxation.md).  Included by ld64.c, after the layout and the relocation values.
 *
 * Input: objects made with `as64 --relax` (EF_PDP64_RELAX).  Every instruction of their .text that holds the address of a symbol has a relocation
 * (R_PDP64_INSN_PC, _BR or _ABS), local symbols too, and every padding that .even, .align or .pool put there has an R_PDP64_ALIGN.  Those are the
 * sites.  Everything else in the section is a stretch of bytes that is copied as it is, and whose position is that of the stretch before plus the
 * change in length of the sites before it.
 *
 * The lengths.  An instruction site starts with the shortest form of its instruction (the codec's: the same mnemonic and operands, the address
 * operand of value 0).  Each round lays the sections out (a padding is as long as its alignment needs at its new place), measures every site's
 * address operand on that layout and lets the instruction grow to the shortest form of at least its present length that takes the value.  Lengths
 * only grow, and are bounded by the longest form, so the rounds end; at the end no site grew, so the last layout is the one every value was measured
 * on: every operand fits its form.  A padding is not monotone (removing two bytes before it can make it six longer) but it is a function of the
 * layout, never a state, so it does not take part in the argument.  The result is the least fixed point of a monotone system when no padding
 * lies between a site and its target, and always a correct one.  (docs/relaxation.md has the argument.)
 */

static struct { long nsites, ninsn, nalign, rounds, grown, shrunk, bytes0, bytes1; int stats; const char *dump; } rx;
struct rxcat { const char *name; long n, b0, b1; };
enum { RC_CALL_EXT, RC_CALL_SAME, RC_JMP_EXT, RC_JMP_SAME, RC_LEA_DATA, RC_LEA_CODE, RC_BRANCH, RC_DATA_REF, RC_ABS, RC_OTHER, NRC };
static struct rxcat rxc[NRC] = {
	{ "call, target in another section" }, { "call, target in the same section" }, { "jmp, target in another section" }, { "jmp, target in the same section" },
	{ "lea of a data or bss symbol" }, { "lea of a code symbol" }, { "conditional branch and sob" }, { "pc-relative operand of another instruction (data, pool)" },
	{ "absolute address or immediate" }, { "other" },
};

static int site_cmp(const void *a, const void *b)
{
	const struct site *x = a, *y = b;
	return x->off < y->off ? -1 : x->off > y->off;
}

/* The sites of the relaxable sections of an object.  Returns -1 after a message. */
static int build_sites(struct obj *o)
{
	for (int i = 0; i < o->nsec; i++) {
		if (o->cls[i] != C_TEXT) continue;
		struct isec *s = &o->is[i];
		int n = 0, cap = 0;
		struct site *v = NULL;
		for (int k = 0; k < o->nrl; k++) {
			struct rel *r = &o->rl[k];
			if (r->target != i) continue;
			if (r->type != R_PDP64_ALIGN && r->type != R_PDP64_INSN_PC && r->type != R_PDP64_INSN_BR && r->type != R_PDP64_INSN_ABS) continue;
			if (n == cap) { cap = cap ? cap * 2 : 64; v = realloc(v, cap * sizeof *v); }
			struct site *t = &v[n];
			memset(t, 0, sizeof *t);
			t->off = r->off; t->rl = k;
			if (r->type == R_PDP64_ALIGN) {
				uint64_t pad = (uint64_t)r->addend >> 32, al = (uint64_t)r->addend & 0xFFFFFFFFu;
				if (!al || (al & (al - 1)) || al > s->align || r->off + pad > s->size) { fail("%s: bad alignment record at offset %#llx", o->name, (unsigned long long)r->off); return -1; }
				t->kind = SK_ALIGN; t->len0 = t->cur = (uint32_t)pad; t->align = (uint32_t)al;
				rx.nalign++;
			} else {
				uint16_t p[5];
				size_t avail = r->off < s->size ? (s->size - r->off) / 2 : 0;
				int np = avail > 5 ? 5 : (int)avail, need = 0, len;
				struct efield f;
				t->kind = SK_INSN;
				t->want = r->type == R_PDP64_INSN_ABS ? ES_A : ES_PC;
				for (int q = 0; q < np; q++) p[q] = get16(s->data + r->off + 2 * q);
				if (np < 1 || (len = enc_decode(link_tab, p, np, &t->in, &need)) <= 0 || enc_reloc_field(link_tab, p, np, t->want, &f)) {
					fail("%s: relocation at offset %#llx: not an instruction with a %s operand", o->name, (unsigned long long)r->off, t->want == ES_PC ? "pc-relative" : "immediate or absolute");
					return -1;
				}
				if (t->want == ES_PC && (r->type == R_PDP64_INSN_BR) != (f.unit == 2)) { fail("%s: relocation at offset %#llx: the type does not match the field of the instruction", o->name, (unsigned long long)r->off); return -1; }
				t->oi = f.oi;
				t->len0 = t->cur = 2 * len;
				struct einsn z = t->in;
				z.op[t->oi].v = 0; z.op[t->oi].ext = 0;
				int m = enc_len(link_tab, &z);
				if (m > 0 && 2 * m < (int)t->len0) t->cur = 2 * m;
				rx.ninsn++;
			}
			n++;
		}
		if (!n) continue;
		qsort(v, n, sizeof *v, site_cmp);
		for (int k = 0; k < n; k++) {
			if (k && v[k].off < v[k - 1].off + v[k - 1].len0) { fail("%s: two relocations on the same instruction or padding, at offset %#llx", o->name, (unsigned long long)v[k].off); return -1; }
			if (v[k].off + v[k].len0 > s->size) { fail("%s: relocation at offset %#llx is outside the section", o->name, (unsigned long long)v[k].off); return -1; }
			o->rl[v[k].rl].site = k;
		}
		s->sites = v; s->nsites = n; s->cum = calloc(n + 1, sizeof *s->cum);
		rx.nsites += n;
	}
	return 0;
}

/* the value to put in the operand of an instruction site on the present layout */
static int site_operand(struct obj *o, int isec, const struct site *t, struct einsn *in, int quiet)
{
	int64_t V;
	if (rel_value(o, &o->rl[t->rl], &V, quiet)) return -1;
	*in = t->in;
	in->op[t->oi].ext = 0;
	in->op[t->oi].v = t->want == ES_PC ? V - (int64_t)isec_addr(o, isec, (int64_t)t->off) : V;
	return 0;
}

/* one round: let the instructions grow to what the present layout asks.  Returns how many did. */
static long relax_round(void)
{
	long grown = 0;
	for (int oi = 0; oi < nobjs; oi++) {
		struct obj *o = &objs[oi];
		for (int i = 0; i < o->nsec; i++) {
			struct isec *s = &o->is[i];
			for (int k = 0; k < s->nsites; k++) {
				struct site *t = &s->sites[k];
				struct einsn in;
				uint16_t par[5];
				if (t->kind != SK_INSN || site_operand(o, i, t, &in, 1)) continue;
				int n = enc_encode_n(link_tab, &in, par, NULL, NULL, (int)t->cur / 2);
				if (n && (uint32_t)(2 * n) > t->cur) { t->cur = 2 * n; grown++; }
			}
		}
	}
	return grown;
}

static int relax_all(void)
{
	for (rx.rounds = 1; rx.rounds < 10000; rx.rounds++) {
		layout();
		if (!relax_round()) return 0;
	}
	fail("relaxation does not converge");
	return -1;
}

static int rx_category(struct obj *o, int isec, const struct site *t)
{
	const char *mn = enc_mn_name(link_tab, t->in.mn);
	int64_t V = 0;
	int same = 0, data = 0;
	if (t->want == ES_PC && !rel_value(o, &o->rl[t->rl], &V, 1)) {
		uint64_t a = (uint64_t)V;
		data = !(a >= cbase[C_TEXT] && a < cbase[C_TEXT] + csize[C_TEXT]);
		const struct rel *r = &o->rl[t->rl];
		sym_t *y = &o->syms[r->symidx];
		int g = o->gsym[r->symidx], ts = (y->info & 15) == 3 || g < 0 ? (int)y->shndx : (gs[g].defined > 0 && !gs[g].abs && !gs[g].common && gs[g].obj == (int)(o - objs) ? gs[g].sec : -1);
		same = ts == isec;
	}
	if (t->want == ES_A) return RC_ABS;
	if (!strcmp(mn, "call") || !strcmp(mn, "movcall")) return same ? RC_CALL_SAME : RC_CALL_EXT;
	if (!strcmp(mn, "jmp")) return same ? RC_JMP_SAME : RC_JMP_EXT;
	if (!strcmp(mn, "lea")) return data ? RC_LEA_DATA : RC_LEA_CODE;
	if ((mn[0] == 'b' && strlen(mn) <= 4 && strcmp(mn, "bic") && strcmp(mn, "bis") && strcmp(mn, "bit") && strcmp(mn, "bsf") && strcmp(mn, "bsr") && strncmp(mn, "bext", 4) && strncmp(mn, "bset", 4) && strncmp(mn, "bclr", 4)) || !strncmp(mn, "cb", 2) || !strcmp(mn, "sob")) return RC_BRANCH;
	if (!strncmp(mn, "mov", 3) || !strcmp(mn, "add") || !strcmp(mn, "sub") || !strcmp(mn, "cmp") || !strcmp(mn, "push") || data) return RC_DATA_REF;
	return RC_OTHER;
}

/* the section's bytes, after relaxation: the stretches between the sites, the sites encoded for the final layout, the paddings made */
static void emit_isec(struct obj *o, int isec, uint8_t *dst)
{
	struct isec *s = &o->is[isec];
	uint64_t old = 0;
	uint8_t *d = dst;
	for (int k = 0; k < s->nsites; k++) {
		struct site *t = &s->sites[k];
		memcpy(d, s->data + old, t->off - old);
		d += t->off - old;
		if (t->kind == SK_ALIGN) fill_pad(d, (uint64_t)(d - dst), t->cur);
		else {
			struct einsn in;
			uint16_t par[5];
			char nb[300];
			const struct rel *r = &o->rl[t->rl];
			if (site_operand(o, isec, t, &in, 0)) goto skip;
			int n = enc_encode_n(link_tab, &in, par, NULL, NULL, (int)t->cur / 2);
			if (!n || 2 * n != (int)t->cur) {
				fail("%s: relocation to %s out of range (%s %lld does not fit any form of %s)", o->name, relname(o, r->symidx, r->addend, nb, sizeof nb),
				    t->want == ES_PC ? "displacement" : "value", (long long)in.op[t->oi].v, enc_mn_name(link_tab, t->in.mn));
				goto skip;
			}
			{	/* the new instruction is the old one with another value in the same operand */
				struct einsn back;
				int bn = enc_decode(link_tab, par, n, &back, NULL);
				if (bn != n || back.mn != t->in.mn || back.nops != t->in.nops) goto internal;
				for (int q = 0; q < back.nops; q++) {
					const struct eop *x = &back.op[q], *y = &t->in.op[q];
					if (x->k != y->k || x->r != y->r || x->x != y->x || x->s != y->s || (q != t->oi && x->v != y->v)) goto internal;
				}
			}
			for (int q = 0; q < n; q++) put16(d + 2 * q, par[q]);
			goto done;
internal:
			fail("%s: internal error: the relaxed %s at offset %#llx is not the instruction the assembler wrote", o->name, enc_mn_name(link_tab, t->in.mn), (unsigned long long)t->off);
skip:
			memset(d, 0, t->cur);
		}
done:
		d += t->cur;
		old = t->off + t->len0;
	}
	memcpy(d, s->data + old, s->size - old);
}

static void relax_stats(void)
{
	long b0 = 0, b1 = 0;
	for (int c = 0; c < NRC; c++) rxc[c].n = rxc[c].b0 = rxc[c].b1 = 0;
	for (int oi = 0; oi < nobjs; oi++) {
		struct obj *o = &objs[oi];
		for (int i = 0; i < o->nsec; i++)
			for (int k = 0; k < o->is[i].nsites; k++) {
				struct site *t = &o->is[i].sites[k];
				if (t->kind != SK_INSN) { b0 += t->len0; b1 += t->cur; continue; }
				int c = rx_category(o, i, t);
				rxc[c].n++; rxc[c].b0 += t->len0; rxc[c].b1 += t->cur;
				b0 += t->len0; b1 += t->cur;
			}
	}
	fprintf(stderr, "ld64: relaxation: %ld instruction sites, %ld paddings, %ld rounds; text %llu bytes\n", rx.ninsn, rx.nalign, rx.rounds, (unsigned long long)csize[C_TEXT]);
	for (int c = 0; c < NRC; c++)
		if (rxc[c].n) fprintf(stderr, "ld64:   %-56s %7ld sites %9ld -> %9ld bytes (%+ld)\n", rxc[c].name, rxc[c].n, rxc[c].b0, rxc[c].b1, rxc[c].b1 - rxc[c].b0);
	fprintf(stderr, "ld64:   all sites and paddings: %ld -> %ld bytes (%+ld)\n", b0, b1, b1 - b0);
}

/* --dump-map FILE: where every input .text section went and what happened to its sites (tools/check-relax.py joins it with as64 --dump-lens):
     S object-name section-index address size-in-object size-now
     T offset-in-object length-in-object length-now kind          (kind: i instruction, a padding)  */
static void relax_dump(const char *path)
{
	FILE *f = fopen(path, "w");
	if (!f) { fprintf(stderr, "%s: %s: %s\n", progname, path, strerror(errno)); errors++; return; }
	for (int oi = 0; oi < nobjs; oi++)
		for (int i = 0; i < objs[oi].nsec; i++) {
			struct isec *s = &objs[oi].is[i];
			if (objs[oi].cls[i] != C_TEXT) continue;
			fprintf(f, "S %s %d %#llx %llu %llu\n", objs[oi].name, i, (unsigned long long)(cbase[C_TEXT] + s->outoff), (unsigned long long)s->size, (unsigned long long)s->cursize);
			for (int k = 0; k < s->nsites; k++) fprintf(f, "T %llu %u %u %c\n", (unsigned long long)s->sites[k].off, s->sites[k].len0, s->sites[k].cur, s->sites[k].kind == SK_INSN ? 'i' : 'a');
		}
	fclose(f);
}

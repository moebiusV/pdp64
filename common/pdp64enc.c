/* pdp64enc.c: the codec of the encoding.  Table driven: every bit position comes from the generated tables
   (tools/mkenc.py, from the grammar spec/pdp64/pdp64.hbnf); nothing here knows where a field is.  The semantics of the operand
   specs are those of docs/codegen-data/encoding/enc.py (the model that produced the tables), which this file is checked against. */
#include <stdlib.h>
#include <string.h>
#include "pdp64enc.h"

static int sgn_fits(int64_t q, int w) { return w >= 64 || (q >= -((int64_t)1 << (w - 1)) && q < ((int64_t)1 << (w - 1))); }
static uint64_t wmask(int w) { return w >= 64 ? ~(uint64_t)0 : (((uint64_t)1 << w) - 1); }
static int64_t sext(uint64_t x, int w) { return w >= 64 ? (int64_t)x : (int64_t)(x << (64 - w)) >> (64 - w); }

void enc_init(const struct etab *tc)
{
	struct etab *t = (struct etab *)tc;
	if (t->lut) return;
	t->lut = calloc(65536, sizeof *t->lut);
	for (int i = 0; i < t->nleaves; i++) {
		const struct eleaf *lf = &t->leaves[i];
		uint32_t lo = (uint32_t)lf->prefix << (16 - lf->L), n = 1u << (16 - lf->L);
		for (uint32_t p = lo; p < lo + n; p++) t->lut[p] = (uint16_t)(i + 1);
	}
}

int enc_mn_find(const struct etab *t, const char *name)
{
	int lo = 0, hi = t->nmn - 1;
	while (lo <= hi) {
		int mid = (lo + hi) / 2, c = strcmp(name, t->mn[mid].name);
		if (!c) return mid;
		if (c < 0) hi = mid - 1; else lo = mid + 1;
	}
	return -1;
}
const char *enc_mn_name(const struct etab *t, int mn) { return t->mn[mn].name; }

/* ---- fitting an operand to a spec ---------------------------------------------------------------------------------- */

static int fit_reg(const struct etab *t, const struct espec *s, int reg, uint64_t *pv, int *np)
{
	if (s->kind == ES_K) return s->kop == EK_R && s->kval == reg;
	if (s->ntab) {
		for (int i = 0; i < s->ntab; i++) if (t->hot[s->tab + i] == reg) { pv[(*np)++] = i; return 1; }
		return 0;
	}
	if (reg < 0 || (s->w < 16 && reg >= (1 << s->w)) || reg >= 256) return 0;
	pv[(*np)++] = (uint64_t)reg;
	return 1;
}

static int fit_spec(const struct etab *t, int si, const struct eop *o, int msz, uint64_t *pv, int *np)
{
	const struct espec *s = &t->specs[si];
	switch (s->kind) {
	case ES_R:
		return o->k == EK_R && fit_reg(t, s, o->r, pv, np);
	case ES_K:
		if (s->kop == EK_R) return o->k == EK_R && s->kval == o->r;
		return o->k == EK_I && !o->ext && o->v == s->kval;
	case ES_I: {
		int64_t q;
		if (o->k != EK_I) return 0;
		if (o->ext) {					/* a value the linker supplies: a field of 32 bits or more, unscaled, signed */
			if (s->w < 32 || s->scale != 1 || !s->sgn) return 0;
			pv[(*np)++] = 0;
			return 1;
		}
		if (o->v % s->scale) return 0;
		q = o->v / s->scale;
		if (s->sgn) { if (!sgn_fits(q, s->w)) return 0; pv[(*np)++] = (uint64_t)q & wmask(s->w); }
		else { if (q < 0 || (s->w < 63 && q >= ((int64_t)1 << s->w))) return 0; pv[(*np)++] = (uint64_t)q; }
		return 1;
	}
	case ES_B: {
		int64_t d = o->v, q;
		int sc = s->scale ? s->scale : msz;
		if (o->k != EK_B) return 0;
		if (!fit_reg(t, &t->specs[s->rn], o->r, pv, np)) return 0;
		if (!s->w) return d == 0;
		if (d % sc) return 0;
		q = d / sc;
		if (s->sgn) { if (!sgn_fits(q, s->w)) return 0; q &= (int64_t)wmask(s->w); }
		else if (q < 0 || q >= ((int64_t)1 << s->w)) return 0;
		pv[(*np)++] = (uint64_t)q;
		return 1;
	}
	case ES_X: {
		int64_t d = o->v;
		if (o->k != EK_X) return 0;
		if (!fit_reg(t, &t->specs[s->rn], o->r, pv, np)) return 0;
		if (!fit_reg(t, &t->specs[s->rx], o->x, pv, np)) return 0;
		switch (o->s) { case 1: pv[(*np)++] = 0; break; case 2: pv[(*np)++] = 1; break; case 4: pv[(*np)++] = 2; break; case 8: pv[(*np)++] = 3; break; default: return 0; }
		if (!s->w) return d == 0;
		if (s->sgn) { if (!sgn_fits(d, s->w)) return 0; d &= (int64_t)wmask(s->w); }
		else if (d < 0 || d >= ((int64_t)1 << s->w)) return 0;
		pv[(*np)++] = (uint64_t)d;
		return 1;
	}
	case ES_PI: case ES_PD:
		if (o->k != (s->kind == ES_PI ? EK_PI : EK_PD)) return 0;
		if (!fit_reg(t, &t->specs[s->rn], o->r, pv, np)) return 0;
		if (o->v < 0 || o->v >= ((int64_t)1 << s->w)) return 0;
		pv[(*np)++] = (uint64_t)o->v;
		return 1;
	case ES_PC: {
		int64_t v = o->v, q;
		if (o->k != EK_PC) return 0;
		if (o->ext) { int lg = s->scale == 2 ? 1 : s->scale == 4 ? 2 : s->scale == 8 ? 3 : 0; if (s->w + lg < 32) return 0; v = 0; }
		if (v % s->scale) return 0;
		q = v / s->scale;
		if (!sgn_fits(q, s->w)) return 0;
		pv[(*np)++] = (uint64_t)q & wmask(s->w);
		return 1;
	}
	case ES_A:
		if (o->k != EK_A) return 0;
		if (o->ext) { if (s->w < 32) return 0; pv[(*np)++] = 0; return 1; }
		if (!sgn_fits(o->v, s->w)) return 0;
		pv[(*np)++] = (uint64_t)o->v & wmask(s->w);
		return 1;
	}
	return 0;
}

/* ---- bits ---------------------------------------------------------------------------------------------------------- */

static void put_bits(const struct etab *t, const struct eplace *pl, uint16_t *par, uint64_t v)
{
	int left = pl->w;
	for (int r = 0; r < pl->nruns; r++) {
		const struct erun *ru = &t->runs[pl->run0 + r];
		left -= ru->len;
		uint16_t m = (uint16_t)(((1u << ru->len) - 1) << (ru->hi + 1 - ru->len));
		uint16_t x = (uint16_t)((((v >> left) & ((1u << ru->len) - 1))) << (ru->hi + 1 - ru->len));
		par[ru->parcel] = (uint16_t)((par[ru->parcel] & ~m) | x);
	}
}
static uint64_t get_bits(const struct etab *t, const struct eplace *pl, const uint16_t *par)
{
	uint64_t v = 0;
	for (int r = 0; r < pl->nruns; r++) {
		const struct erun *ru = &t->runs[pl->run0 + r];
		v = (v << ru->len) | ((par[ru->parcel] >> (ru->hi + 1 - ru->len)) & ((1u << ru->len) - 1));
	}
	return v;
}

/* the number of parts of an operand spec, in the order the generator numbered them: registers of the base (and index), the scale, the displacement */
static int part_regs(const struct etab *t, int si) { return t->specs[si].kind == ES_R ? 1 : 0; }

static const struct eplace *find_place(const struct etab *t, const struct eleaf *lf, int oi, int pi)
{
	for (int i = 0; i < lf->npl; i++) {
		const struct eplace *pl = &t->place[lf->pl0 + i];
		if (pl->oi == oi && pl->pi == pi) return pl;
	}
	return NULL;
}

/* ---- encode -------------------------------------------------------------------------------------------------------- */

static const struct ecand *pick(const struct etab *t, const struct einsn *in, uint64_t pv[4][8], int npv[4], int minn)
{
	const struct emn *m = &t->mn[in->mn];
	for (int c = 0; c < m->ncand; c++) {
		const struct ecand *cd = &t->cands[m->cand0 + c];
		const struct eform *f = &t->forms[cd->form];
		int ok = f->nspecs == in->nops && f->n >= minn;
		for (int i = 0; ok && i < f->nspecs; i++) {
			npv[i] = 0;
			ok = fit_spec(t, t->formspec[f->spec0 + i], &in->op[i], m->msz, pv[i], &npv[i]);
		}
		if (ok) return cd;
	}
	return NULL;
}

int enc_len(const struct etab *t, const struct einsn *in)
{
	uint64_t pv[4][8]; int npv[4];
	const struct ecand *cd = pick(t, in, pv, npv, 0);
	return cd ? t->forms[cd->form].n : 0;
}

int enc_encode_n(const struct etab *t, const struct einsn *in, uint16_t *par, int *form, int *leaf, int minn)
{
	uint64_t pv[4][8]; int npv[4];
	const struct ecand *cd = pick(t, in, pv, npv, minn);
	if (!cd) return 0;
	const struct eform *f = &t->forms[cd->form];
	const struct eleaf *lf = &t->leaves[cd->leaf];
	memset(par, 0, 5 * sizeof *par);
	par[0] = (uint16_t)(lf->prefix << (16 - lf->L));
	for (int i = 0; i < lf->npl; i++) {
		const struct eplace *pl = &t->place[lf->pl0 + i];
		if (pl->oi == ESUB) put_bits(t, pl, par, cd->k);
		else put_bits(t, pl, par, pv[pl->oi][pl->pi]);
	}
	if (form) *form = cd->form;
	if (leaf) *leaf = cd->leaf;
	return f->n;
}

int enc_encode(const struct etab *t, const struct einsn *in, uint16_t *par, int *form, int *leaf) { return enc_encode_n(t, in, par, form, leaf, 0); }

/* ---- decode -------------------------------------------------------------------------------------------------------- */

int enc_len_p0(const struct etab *t, uint16_t p0)
{
	enc_init(t);
	int l = t->lut[p0];
	return l ? t->forms[t->leaves[l - 1].form].n : 0;
}

static int make_reg(const struct etab *t, int si, const uint64_t *pv, int *used, int *reg)
{
	const struct espec *s = &t->specs[si];
	if (s->kind == ES_K) { *reg = s->kval; return 1; }
	uint64_t x = pv[(*used)++];
	if (s->ntab) { if (x >= s->ntab) return 0; *reg = t->hot[s->tab + x]; return 1; }
	*reg = (int)x;
	return 1;
}

static int make_op(const struct etab *t, int si, const uint64_t *pv, int msz, struct eop *o)
{
	const struct espec *s = &t->specs[si];
	int u = 0, r, x;
	memset(o, 0, sizeof *o);
	switch (s->kind) {
	case ES_R: if (!make_reg(t, si, pv, &u, &r)) return 0; o->k = EK_R; o->r = r; return 1;
	case ES_K: if (s->kop == EK_R) { o->k = EK_R; o->r = s->kval; } else { o->k = EK_I; o->v = s->kval; } return 1;
	case ES_I: {
		int64_t q;
		if (s->sgn) q = sext(pv[0], s->w); else q = (int64_t)pv[0];
		o->k = EK_I; o->v = q * s->scale;
		return 1;
	}
	case ES_B:
		if (!make_reg(t, s->rn, pv, &u, &r)) return 0;
		o->k = EK_B; o->r = r;
		if (s->w) { int64_t q = s->sgn ? sext(pv[u], s->w) : (int64_t)pv[u]; o->v = q * (s->scale ? s->scale : msz); }
		return 1;
	case ES_X:
		if (!make_reg(t, s->rn, pv, &u, &r) || !make_reg(t, s->rx, pv, &u, &x)) return 0;
		o->k = EK_X; o->r = r; o->x = x; o->s = (uint8_t)(1 << pv[u++]);
		if (s->w) o->v = s->sgn ? sext(pv[u], s->w) : (int64_t)pv[u];
		return 1;
	case ES_PI: case ES_PD:
		if (!make_reg(t, s->rn, pv, &u, &r)) return 0;
		o->k = s->kind == ES_PI ? EK_PI : EK_PD; o->r = r; o->v = (int64_t)pv[u];
		return 1;
	case ES_PC: o->k = EK_PC; o->v = sext(pv[0], s->w) * s->scale; return 1;
	case ES_A: o->k = EK_A; o->v = sext(pv[0], s->w); return 1;
	}
	return 0;
}

int enc_decode(const struct etab *t, const uint16_t *p, int np, struct einsn *out, int *need)
{
	enc_init(t);
	int l = t->lut[p[0]];
	if (!l) return 0;
	const struct eleaf *lf = &t->leaves[l - 1];
	const struct eform *f = &t->forms[lf->form];
	if (need) *need = f->n;
	if (np < f->n) return -1;
	uint64_t pv[4][8];
	unsigned k = 0;
	memset(pv, 0, sizeof pv);
	for (int i = 0; i < lf->npl; i++) {
		const struct eplace *pl = &t->place[lf->pl0 + i];
		uint64_t v = get_bits(t, pl, p);
		if (pl->oi == ESUB) k = (unsigned)v; else pv[pl->oi][pl->pi] = v;
	}
	if (k >= lf->nmn) return 0;
	int mn = t->formmn[f->mn0 + lf->off + k];
	memset(out, 0, sizeof *out);
	out->mn = mn; out->nops = f->nspecs;
	for (int i = 0; i < f->nspecs; i++)
		if (!make_op(t, t->formspec[f->spec0 + i], pv[i], t->mn[mn].msz, &out->op[i])) return 0;
	return f->n;
}

/* ---- relocation fields --------------------------------------------------------------------------------------------- */

int enc_reloc_field(const struct etab *t, const uint16_t *p, int np, int want, struct efield *f)
{
	enc_init(t);
	int l = t->lut[p[0]];
	if (!l) return -1;
	const struct eleaf *lf = &t->leaves[l - 1];
	const struct eform *fm = &t->forms[lf->form];
	if (np < fm->n) return -1;
	for (int i = 0; i < fm->nspecs; i++) {
		const struct espec *s = &t->specs[t->formspec[fm->spec0 + i]];
		int ok = want == ES_PC ? s->kind == ES_PC : (s->kind == ES_A || (s->kind == ES_I && s->w >= 32 && s->scale == 1));
		if (!ok) continue;
		const struct eplace *pl = find_place(t, lf, i, 0);
		if (!pl) return -1;
		memset(f, 0, sizeof *f);
		f->kind = s->kind; f->w = pl->w; f->unit = s->kind == ES_PC ? s->scale : 1; f->sgn = s->kind != ES_I || s->sgn;
		f->nparcels = fm->n; f->oi = i; f->nruns = pl->nruns;
		for (int r = 0; r < pl->nruns; r++) f->run[r] = t->runs[pl->run0 + r];
		return 0;
	}
	(void)part_regs;
	return -1;
}

void enc_field_put(const struct efield *f, uint16_t *p, uint64_t q)
{
	int left = f->w;
	for (int r = 0; r < f->nruns; r++) {
		const struct erun *ru = &f->run[r];
		left -= ru->len;
		uint16_t m = (uint16_t)(((1u << ru->len) - 1) << (ru->hi + 1 - ru->len));
		uint16_t x = (uint16_t)((((q >> left) & ((1u << ru->len) - 1))) << (ru->hi + 1 - ru->len));
		p[ru->parcel] = (uint16_t)((p[ru->parcel] & ~m) | x);
	}
}
int64_t enc_field_get(const struct efield *f, const uint16_t *p)
{
	uint64_t v = 0;
	for (int r = 0; r < f->nruns; r++) {
		const struct erun *ru = &f->run[r];
		v = (v << ru->len) | ((p[ru->parcel] >> (ru->hi + 1 - ru->len)) & ((1u << ru->len) - 1));
	}
	return f->sgn ? sext(v, f->w) : (int64_t)v;
}

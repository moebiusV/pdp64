/* encopt.c -- the model, the greedy baseline, the exact solver and the prefix assignment.  C99, libc only. */
#define _POSIX_C_SOURCE 200809L
#include "encopt.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <ctype.h>

#define BYTES(m, k) (2 * (m)->form[(m)->cand[k]].parcels)

static void *xmalloc(size_t n) { void *p = malloc(n ? n : 1); if (!p) { fputs("encopt: out of memory\n", stderr); exit(2); } return p; }
static void *xcalloc(size_t n, size_t s) { void *p = calloc(n ? n : 1, s ? s : 1); if (!p) { fputs("encopt: out of memory\n", stderr); exit(2); } return p; }
static void *xrealloc(void *q, size_t n) { void *p = realloc(q, n ? n : 1); if (!p) { fputs("encopt: out of memory\n", stderr); exit(2); } return p; }
static char *xstrdup(const char *s) { char *p = xmalloc(strlen(s) + 1); strcpy(p, s); return p; }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }

/* ------------------------------------------------------------------------------------------------ reading */
void eo_free(eo_model *m) {
	int i;
	for (i = 0; i < m->nform; i++) { int j; free(m->form[i].name); for (j = 0; j < m->form[i].nmn; j++) free(m->form[i].mn[j]); free(m->form[i].mn); }
	free(m->form); free(m->cand);
	for (i = 0; i < m->ndem; i++) free(m->dem[i].at);
	free(m->dem);
	for (i = 0; i < m->ncommitted; i++) free(m->committed[i]);
	free(m->committed);
	for (i = 0; i < m->nrequire; i++) free(m->require[i]);
	for (i = 0; i < m->nforbid; i++) free(m->forbid[i]);
	free(m->require); free(m->forbid);
	memset(m, 0, sizeof *m);
}

int eo_cand_by_name(const eo_model *m, const char *name) {
	int k;
	for (k = 0; k < m->ncand; k++) if (!strcmp(m->form[m->cand[k]].name, name)) return k;
	return -1;
}

eo_i64 eo_forced_patterns(const eo_model *m) {
	eo_i64 s = 0; int i;
	for (i = 0; i < m->nform; i++) if (m->form[i].forced) s += m->form[i].pat;
	return s;
}

#define FAIL(...) do { snprintf(err, errlen, __VA_ARGS__); return -1; } while (0)

int eo_read(FILE *f, const char *fname, eo_model *m, char *err, size_t errlen) {
	char *line = NULL; size_t cap = 0; ssize_t len; int ln = 0, seen = 0, capf = 0, capd = 0;
	memset(m, 0, sizeof *m);
	m->total = 65536;
	while ((len = getline(&line, &cap, f)) >= 0) {
		char *save, *t; char *tok[1]; (void)tok;
		ln++;
		{ char *h = strchr(line, '#'); if (h) *h = 0; }
		t = strtok_r(line, " \t\r\n", &save);
		if (!t) continue;
		if (!seen) {
			if (strcmp(t, "encopt-input")) { free(line); FAIL("%s:%d: not an encopt input file (first line must be `encopt-input 1`)", fname, ln); }
			t = strtok_r(NULL, " \t\r\n", &save);
			if (!t || strcmp(t, "1")) { free(line); FAIL("%s:%d: unknown format version", fname, ln); }
			seen = 1; continue;
		}
		if (!strcmp(t, "budget")) {
			char *a = strtok_r(NULL, " \t\r\n", &save), *b = strtok_r(NULL, " \t\r\n", &save);
			if (!a) { free(line); FAIL("%s:%d: budget needs a number", fname, ln); }
			m->budget = atoll(a); if (b) m->total = atoll(b);
		} else if (!strcmp(t, "lam")) {
			char *a = strtok_r(NULL, " \t\r\n", &save); if (a) m->lam = atof(a);
		} else if (!strcmp(t, "form")) {
			char *nm = strtok_r(NULL, " \t\r\n", &save), *role = strtok_r(NULL, " \t\r\n", &save), *p = strtok_r(NULL, " \t\r\n", &save), *L = strtok_r(NULL, " \t\r\n", &save), *x = strtok_r(NULL, " \t\r\n", &save);
			eo_form *fm; int nm_cap = 0;
			if (!x) { free(line); FAIL("%s:%d: form NAME ROLE PARCELS L XBITS MNEMONIC...", fname, ln); }
			if (m->nform == capf) { capf = capf ? 2 * capf : 256; m->form = xrealloc(m->form, capf * sizeof *m->form); }
			fm = &m->form[m->nform++]; memset(fm, 0, sizeof *fm);
			fm->name = xstrdup(nm);
			if (!strcmp(role, "forced")) fm->forced = 1; else if (strcmp(role, "cand")) { free(line); FAIL("%s:%d: role must be forced or cand", fname, ln); }
			fm->parcels = atoi(p); fm->L = atoi(L); fm->xbits = atoi(x);
			if (fm->parcels < 1 || fm->parcels > 5 || fm->L < 1 || fm->L > 16) { free(line); FAIL("%s:%d: form %s: parcels or prefix length out of range", fname, ln, nm); }
			while ((t = strtok_r(NULL, " \t\r\n", &save))) {
				if (fm->nmn == nm_cap) { nm_cap = nm_cap ? 2 * nm_cap : 8; fm->mn = xrealloc(fm->mn, nm_cap * sizeof *fm->mn); }
				fm->mn[fm->nmn++] = xstrdup(t);
			}
			if (!fm->nmn) { free(line); FAIL("%s:%d: form %s has no mnemonic", fname, ln, nm); }
			fm->pat = fm->xbits ? ((eo_i64)1 << (16 - fm->L)) : fm->nmn * ((eo_i64)1 << (16 - fm->L));
			if (!fm->forced) { m->cand = xrealloc(m->cand, (m->ncand + 1) * sizeof *m->cand); m->cand[m->ncand++] = m->nform - 1; } else m->nforced++;
		} else if (!strcmp(t, "demand")) {
			char *w = strtok_r(NULL, " \t\r\n", &save), *b = strtok_r(NULL, " \t\r\n", &save), *k = strtok_r(NULL, " \t\r\n", &save);
			eo_demand *d; int i;
			if (!k) { free(line); FAIL("%s:%d: demand WEIGHT BASE K ATOM...", fname, ln); }
			if (m->ndem == capd) { capd = capd ? 2 * capd : 256; m->dem = xrealloc(m->dem, capd * sizeof *m->dem); }
			d = &m->dem[m->ndem++]; d->w = atoll(w); d->base = atoi(b); d->nat = atoi(k); d->at = xmalloc(d->nat * sizeof(int));
			for (i = 0; i < d->nat; i++) {
				t = strtok_r(NULL, " \t\r\n", &save);
				if (!t) { free(line); FAIL("%s:%d: demand lists fewer atoms than it says", fname, ln); }
				d->at[i] = atoi(t);
			}
		} else if (!strcmp(t, "committed")) {
			t = strtok_r(NULL, " \t\r\n", &save);
			if (t) { m->committed = xrealloc(m->committed, (m->ncommitted + 1) * sizeof *m->committed); m->committed[m->ncommitted++] = xstrdup(t); }
		} else if (!strcmp(t, "require") || !strcmp(t, "forbid")) {
			char *nm = strtok_r(NULL, " \t\r\n", &save);
			if (nm && t[0] == 'r') { m->require = xrealloc(m->require, (m->nrequire + 1) * sizeof *m->require); m->require[m->nrequire++] = xstrdup(nm); }
			else if (nm) { m->forbid = xrealloc(m->forbid, (m->nforbid + 1) * sizeof *m->forbid); m->forbid[m->nforbid++] = xstrdup(nm); }
		} else { char c[64]; snprintf(c, sizeof c, "%s", t); free(line); FAIL("%s:%d: unknown line `%s`", fname, ln, c); }
	}
	free(line);
	if (!seen) FAIL("%s: empty file", fname);
	{
		int i, j;
		for (i = 0; i < m->ndem; i++) for (j = 0; j < m->dem[i].nat; j++)
			if (m->dem[i].at[j] < 0 || m->dem[i].at[j] >= m->ncand) FAIL("%s: a demand names candidate %d of %d", fname, m->dem[i].at[j], m->ncand);
	}
	return 0;
}

/* ------------------------------------------------------------------------------------------------ objective */
eo_i64 eo_cost(const eo_model *m, const char *sel) {
	eo_i64 s = 0; int k;
	for (k = 0; k < m->ncand; k++) if (sel[k]) s += m->form[m->cand[k]].pat;
	return s;
}

eo_i64 eo_value(const eo_model *m, const char *sel, eo_i64 *unenc, eo_i64 *excl) {
	eo_i64 tot = 0, un = 0, ex = 0; int i, j;
	for (i = 0; i < m->ndem; i++) {
		const eo_demand *d = &m->dem[i]; int b = d->base;
		for (j = 0; j < d->nat; j++) { int k = d->at[j]; if (sel[k] && BYTES(m, k) < b) b = BYTES(m, k); }
		tot += d->w * b;
		if (b >= 99) un += d->w; else ex += d->w * b;
	}
	if (unenc) *unenc = un;
	if (excl) *excl = ex;
	return tot;
}

/* ------------------------------------------------------------------------------------------------ the study's greedy */
typedef struct { int nd; int *dl; int *ds; } hitlist;   /* per candidate: demands it covers */

static void build_hits(const eo_model *m, int **astart, int **adem) {
	int *cnt = xcalloc(m->ncand + 1, sizeof(int)), i, j, k, *pos;
	for (i = 0; i < m->ndem; i++) for (j = 0; j < m->dem[i].nat; j++) cnt[m->dem[i].at[j] + 1]++;
	for (k = 0; k < m->ncand; k++) cnt[k + 1] += cnt[k];
	*astart = cnt; *adem = xmalloc((cnt[m->ncand] + 1) * sizeof(int)); pos = xmalloc((m->ncand + 1) * sizeof(int)); memcpy(pos, cnt, (m->ncand + 1) * sizeof(int));
	for (i = 0; i < m->ndem; i++) for (j = 0; j < m->dem[i].nat; j++) (*adem)[pos[m->dem[i].at[j]]++] = i;
	free(pos);
}

static int is_forbidden(const eo_model *m, int k) { int i; for (i = 0; i < m->nforbid; i++) if (!strcmp(m->form[m->cand[k]].name, m->forbid[i])) return 1; return 0; }

/* greedy completion of sel (a set of candidate numbers, already counted in the cost); skip: candidates that may not be chosen */
static void fill(const eo_model *m, const int *as, const int *ad, char *sel, double alpha, const char *skip, eo_i64 *used_io) {
	int k, i, *best = xmalloc(m->ndem * sizeof(int)); char *dead = xcalloc(m->ncand, 1);
	eo_i64 used = *used_io;
	for (i = 0; i < m->ndem; i++) {
		int j, b = m->dem[i].base;
		for (j = 0; j < m->dem[i].nat; j++) { int c = m->dem[i].at[j]; if (sel[c] && BYTES(m, c) < b) b = BYTES(m, c); }
		best[i] = b;
	}
	for (k = 0; k < m->ncand; k++) if (sel[k] || (skip && skip[k]) || is_forbidden(m, k)) dead[k] = 1;
	for (;;) {
		int pick = -1; double pr = 0;
		for (k = 0; k < m->ncand; k++) {
			eo_i64 g = 0; int by = BYTES(m, k), j;
			if (dead[k]) continue;
			if (used + m->form[m->cand[k]].pat > m->budget) { dead[k] = 1; continue; }
			for (j = as[k]; j < as[k + 1]; j++) { int d = ad[j]; if (best[d] > by) g += m->dem[d].w * (best[d] - by); }
			if (g <= 0) continue;
			{ double r = (double)g / pow((double)m->form[m->cand[k]].pat, alpha); if (pick < 0 || r > pr * (1 + 1e-12)) { pick = k; pr = r; } }
		}
		if (pick < 0) break;
		sel[pick] = 1; dead[pick] = 1; used += m->form[m->cand[pick]].pat;
		{ int j, by = BYTES(m, pick); for (j = as[pick]; j < as[pick + 1]; j++) if (best[ad[j]] > by) best[ad[j]] = by; }
	}
	*used_io = used; free(best); free(dead);
}

static eo_i64 forced_used(const eo_model *m) { return eo_forced_patterns(m); }

eo_i64 eo_greedy(const eo_model *m, char *sel, double *alpha_used) {
	static const double alphas[5] = { 0.8, 0.9, 1.0, 1.1, 1.25 };
	int *as, *ad, a, k; eo_i64 bestv = -1; char *tmp = xmalloc(m->ncand);
	build_hits(m, &as, &ad);
	for (a = 0; a < 5; a++) {
		eo_i64 used = forced_used(m), un, ex;
		memset(tmp, 0, m->ncand);
		for (k = 0; k < m->nrequire; k++) { int c = eo_cand_by_name(m, m->require[k]); if (c >= 0 && !tmp[c]) { tmp[c] = 1; used += m->form[m->cand[c]].pat; } }
		fill(m, as, ad, tmp, alphas[a], NULL, &used);
		eo_value(m, tmp, &un, &ex);
		if (bestv < 0 || ex < bestv) { bestv = ex; memcpy(sel, tmp, m->ncand); if (alpha_used) *alpha_used = alphas[a]; }
	}
	free(tmp); free(as); free(ad);
	return bestv;
}

eo_i64 eo_greedy_refine(const eo_model *m, char *sel, int rounds) {
	int *as, *ad, it, k, i; double alpha = 1.0; eo_i64 cur, un, ex;
	char *tmp = xmalloc(m->ncand), *skip = xcalloc(m->ncand, 1);
	eo_greedy(m, sel, &alpha);
	build_hits(m, &as, &ad);
	cur = eo_value(m, sel, &un, &ex);
	for (it = 0; it < rounds; it++) {
		int n = 0, *order = xmalloc(m->ncand * sizeof(int)); double *loss = xmalloc(m->ncand * sizeof(double)); int improved = 0;
		for (k = 0; k < m->ncand; k++) if (sel[k]) {
			/* the loss of removing k: value without k minus value with k (the other candidates stay) */
			eo_i64 v1; char sv = sel[k]; sel[k] = 0; v1 = eo_value(m, sel, &un, &ex); sel[k] = sv;
			loss[k] = (double)(v1 - cur) / (double)m->form[m->cand[k]].pat; order[n++] = k;
		}
		/* the 12 chosen candidates whose loss per pattern is smallest */
		for (i = 0; i < n; i++) { int j, b = i; for (j = i + 1; j < n; j++) if (loss[order[j]] < loss[order[b]]) b = j; { int t = order[i]; order[i] = order[b]; order[b] = t; } if (i >= 11) break; }
		for (i = 0; i < n && i < 12; i++) {
			int c = order[i]; eo_i64 used = forced_used(m), v;
			memcpy(tmp, sel, m->ncand); tmp[c] = 0; memset(skip, 0, m->ncand); skip[c] = 1;
			used += eo_cost(m, tmp);
			fill(m, as, ad, tmp, alpha, skip, &used);
			v = eo_value(m, tmp, &un, &ex);
			if (v < cur) { cur = v; memcpy(sel, tmp, m->ncand); improved = 1; break; }
		}
		free(order); free(loss);
		if (!improved) break;
	}
	free(tmp); free(skip); free(as); free(ad); (void)ex;
	return cur;
}

/* ------------------------------------------------------------------------------------------------ the reduced problem */
typedef struct {
	int m;                 /* atoms (candidates that survive the reductions) */
	int *cid; eo_i64 *cost; int *by;
	int nd; eo_i64 *w; int *base; int *dstart, *dat;      /* demands with at least one useful atom; atoms of a demand (CSR) */
	int *astart, *ad;                                     /* demands of an atom (CSR) */
	int ncomp; int *cstart_a, *ca; int *cstart_d, *cd;    /* components: atoms, demands */
	int *comp_of_atom;
	eo_i64 constv;         /* weight * base of demands no atom shortens */
	eo_i64 avail;          /* patterns left for candidates */
	int nreq; int *req;    /* required atoms (reduced ids) */
	eo_i64 reqcost;
	int infeasible;
} problem;

static void problem_free(problem *p) {
	free(p->cid); free(p->cost); free(p->by); free(p->w); free(p->base); free(p->dstart); free(p->dat); free(p->astart); free(p->ad);
	free(p->cstart_a); free(p->ca); free(p->cstart_d); free(p->cd); free(p->comp_of_atom); free(p->req);
}

static int find(int *par, int x) { while (par[x] != x) { par[x] = par[par[x]]; x = par[x]; } return x; }

static void reduce(const eo_model *m, problem *p) {
	int k, i, j, nW, *newid = xmalloc(m->ncand * sizeof(int));
	int *as, *ad;
	eo_i64 forced = eo_forced_patterns(m);
	char *isreq = xcalloc(m->ncand, 1), *isforb = xcalloc(m->ncand, 1), *keep = xcalloc(m->ncand, 1);
	memset(p, 0, sizeof *p);
	p->avail = m->budget - forced;
	for (i = 0; i < m->nrequire; i++) { int c = eo_cand_by_name(m, m->require[i]); if (c >= 0) isreq[c] = 1; }
	for (i = 0; i < m->nforbid; i++) { int c = eo_cand_by_name(m, m->forbid[i]); if (c >= 0) isforb[c] = 1; }
	for (k = 0; k < m->ncand; k++) if (isreq[k]) { isreq[k] = 1; p->reqcost += m->form[m->cand[k]].pat; }
	if (p->avail < p->reqcost) { p->infeasible = 1; p->avail -= p->reqcost; }
	else p->avail -= p->reqcost;
	/* useful hits: a demand is useful for a candidate that is shorter than its base */
	build_hits(m, &as, &ad);
	{
		/* candidates that can be chosen at all: cost <= available (required ones are taken out: their cost is paid) */
		for (k = 0; k < m->ncand; k++) {
			int any = 0, by = BYTES(m, k);
			if (isforb[k]) continue;
			if (!isreq[k] && m->form[m->cand[k]].pat > p->avail) continue;
			for (j = as[k]; j < as[k + 1]; j++) if (by < m->dem[ad[j]].base) { any = 1; break; }
			if (any) keep[k] = 1;
		}
	}
	/* dominance: a candidate is dropped if another one covers a superset of its useful demands, is not longer and not dearer (ties: the lower number stays) */
	nW = (m->ndem + 63) / 64;
	{
		unsigned long long *bits = xcalloc((size_t)m->ncand * nW, sizeof(unsigned long long));
		for (k = 0; k < m->ncand; k++) if (keep[k]) for (j = as[k]; j < as[k + 1]; j++) if (BYTES(m, k) < m->dem[ad[j]].base) bits[(size_t)k * nW + ad[j] / 64] |= 1ULL << (ad[j] % 64);
		for (k = 0; k < m->ncand; k++) {
			if (!keep[k] || isreq[k]) continue;
			for (i = 0; i < m->ncand; i++) {
				int w, sub = 1;
				if (i == k || !keep[i]) continue;
				if (BYTES(m, i) > BYTES(m, k) || m->form[m->cand[i]].pat > m->form[m->cand[k]].pat) continue;
				for (w = 0; w < nW; w++) if (bits[(size_t)k * nW + w] & ~bits[(size_t)i * nW + w]) { sub = 0; break; }
				if (!sub) continue;
				if (BYTES(m, i) == BYTES(m, k) && m->form[m->cand[i]].pat == m->form[m->cand[k]].pat && i > k) {
					/* identical: the one with the lower number stays; but only if equal coverage (else i strictly dominates anyway) */
					int eq = 1; for (w = 0; w < nW; w++) if (bits[(size_t)k * nW + w] != bits[(size_t)i * nW + w]) { eq = 0; break; }
					if (eq) continue;
				}
				keep[k] = 0; break;
			}
		}
		free(bits);
	}
	/* number the survivors, required ones are not part of the free problem but shorten the demands: they enter through the base */
	p->m = 0;
	for (k = 0; k < m->ncand; k++) if (keep[k] && !isreq[k]) newid[k] = p->m++; else newid[k] = -1;
	p->cid = xmalloc(p->m * sizeof(int)); p->cost = xmalloc(p->m * sizeof(eo_i64)); p->by = xmalloc(p->m * sizeof(int));
	for (k = 0; k < m->ncand; k++) if (newid[k] >= 0) { p->cid[newid[k]] = k; p->cost[newid[k]] = m->form[m->cand[k]].pat; p->by[newid[k]] = BYTES(m, k); }
	/* demands: base lowered by required candidates; keep those that some free atom shortens */
	{
		int *eb = xmalloc(m->ndem * sizeof(int)), *cnt = xcalloc(m->ndem + 1, sizeof(int)), nd = 0, *dmap = xmalloc(m->ndem * sizeof(int)), tot = 0;
		for (i = 0; i < m->ndem; i++) {
			eb[i] = m->dem[i].base;
			for (j = 0; j < m->dem[i].nat; j++) { int c = m->dem[i].at[j]; if (isreq[c] && BYTES(m, c) < eb[i]) eb[i] = BYTES(m, c); }
		}
		for (i = 0; i < m->ndem; i++) {
			int u = 0;
			for (j = 0; j < m->dem[i].nat; j++) { int c = m->dem[i].at[j]; if (newid[c] >= 0 && BYTES(m, c) < eb[i]) u++; }
			if (u) { dmap[i] = nd++; tot += u; cnt[dmap[i]] = u; } else { dmap[i] = -1; p->constv += m->dem[i].w * eb[i]; }
		}
		p->nd = nd; p->w = xmalloc(nd * sizeof(eo_i64)); p->base = xmalloc(nd * sizeof(int)); p->dstart = xmalloc((nd + 1) * sizeof(int)); p->dat = xmalloc((tot + 1) * sizeof(int));
		p->dstart[0] = 0; tot = 0;
		for (i = 0; i < m->ndem; i++) if (dmap[i] >= 0) {
			int d = dmap[i];
			p->w[d] = m->dem[i].w; p->base[d] = eb[i];
			for (j = 0; j < m->dem[i].nat; j++) { int c = m->dem[i].at[j]; if (newid[c] >= 0 && BYTES(m, c) < eb[i]) p->dat[tot++] = newid[c]; }
			p->dstart[d + 1] = tot;
		}
		free(eb); free(cnt); free(dmap);
	}
	/* atom -> demands */
	{
		int *c2 = xcalloc(p->m + 1, sizeof(int)), *pos;
		for (i = 0; i < p->dstart[p->nd]; i++) c2[p->dat[i] + 1]++;
		for (i = 0; i < p->m; i++) c2[i + 1] += c2[i];
		p->astart = c2; p->ad = xmalloc((c2[p->m] + 1) * sizeof(int)); pos = xmalloc((p->m + 1) * sizeof(int)); memcpy(pos, c2, (p->m + 1) * sizeof(int));
		for (i = 0; i < p->nd; i++) for (j = p->dstart[i]; j < p->dstart[i + 1]; j++) p->ad[pos[p->dat[j]]++] = i;
		free(pos);
	}
	/* components */
	{
		int *par = xmalloc((p->m + 1) * sizeof(int)), *cn = xcalloc(p->m + 1, sizeof(int)), nc = 0, *rid = xmalloc((p->m + 1) * sizeof(int)), q;
		for (i = 0; i < p->m; i++) par[i] = i;
		for (i = 0; i < p->nd; i++) for (j = p->dstart[i] + 1; j < p->dstart[i + 1]; j++) { int a = find(par, p->dat[p->dstart[i]]), b = find(par, p->dat[j]); if (a != b) par[b] = a; }
		for (i = 0; i < p->m; i++) rid[i] = -1;
		p->comp_of_atom = xmalloc((p->m + 1) * sizeof(int));
		for (i = 0; i < p->m; i++) { int r = find(par, i); if (rid[r] < 0) rid[r] = nc++; p->comp_of_atom[i] = rid[r]; cn[rid[r]]++; }
		p->ncomp = nc; p->cstart_a = xcalloc(nc + 1, sizeof(int)); p->cstart_d = xcalloc(nc + 1, sizeof(int));
		for (i = 0; i < nc; i++) p->cstart_a[i + 1] = p->cstart_a[i] + cn[i];
		p->ca = xmalloc((p->m + 1) * sizeof(int)); memset(cn, 0, (p->m + 1) * sizeof(int));
		for (i = 0; i < p->m; i++) { int c = p->comp_of_atom[i]; p->ca[p->cstart_a[c] + cn[c]++] = i; }
		{
			int *dc = xmalloc((p->nd + 1) * sizeof(int)), *dcnt = xcalloc(nc + 1, sizeof(int));
			for (i = 0; i < p->nd; i++) { dc[i] = p->comp_of_atom[p->dat[p->dstart[i]]]; dcnt[dc[i]]++; }
			for (i = 0; i < nc; i++) p->cstart_d[i + 1] = p->cstart_d[i] + dcnt[i];
			p->cd = xmalloc((p->nd + 1) * sizeof(int)); memset(dcnt, 0, (nc + 1) * sizeof(int));
			for (i = 0; i < p->nd; i++) p->cd[p->cstart_d[dc[i]] + dcnt[dc[i]]++] = i;
			free(dc); free(dcnt);
		}
		(void)q; free(par); free(cn); free(rid);
	}
	p->nreq = 0; p->req = xmalloc((m->ncand + 1) * sizeof(int));
	for (k = 0; k < m->ncand; k++) if (isreq[k]) p->req[p->nreq++] = k;
	free(keep); free(newid); free(as); free(ad); free(isreq); free(isforb);
}

/* ------------------------------------------------------------------------------------------------ the search */
typedef struct {
	const problem *p; const eo_opts *o;
	char *st;              /* 0 free, 1 in, 2 out */
	int *eff;              /* current base of each demand (lowered by chosen atoms) */
	eo_i64 R;              /* patterns left */
	eo_i64 ub;             /* incumbent value (of the reduced problem, without constv) */
	char *bestsel;         /* incumbent: reduced atoms */
	eo_i64 nodes; double t0; int stopped;
	double *vs, *slack;    /* scratch */
	int *trail; int ntrail; int *etrail_d, *etrail_v; int netrail;
	double lam;
	eo_i64 root_lb; int have_root;
	eo_i64 known_lb;       /* a proved lower bound on the value: the search ends when the incumbent reaches it */
	int solved; int root_set;
} search;

static void improved(search *s) { if (s->ub <= s->known_lb) s->solved = 1; }

/* dual ascent bound of one component for the multiplier lam: a valid lower bound on  min over S of  value(S) + lam * cost(S)  (S among the free atoms of the component) */
static double da_comp(search *s, int c, double lam, double *free_out) {
	const problem *p = s->p; int a, jj, d, q; double total = 0;
	for (jj = p->cstart_a[c]; jj < p->cstart_a[c + 1]; jj++) { a = p->ca[jj]; s->slack[a] = s->st[a] == 0 ? lam * (double)p->cost[a] : 0; }
	/* round robin to the next breakpoint (Erlenkotter's ascent) */
	{
		int nd = p->cstart_d[c + 1] - p->cstart_d[c], *act = (int *)s->trail + 0; (void)act; (void)nd;
	}
	/* initial v: the cheapest useful free atom of each demand; customers without one are constants */
	for (jj = p->cstart_d[c]; jj < p->cstart_d[c + 1]; jj++) {
		d = p->cd[jj]; int mn = s->eff[d], any = 0, e = s->eff[d];
		for (q = p->dstart[d]; q < p->dstart[d + 1]; q++) { a = p->dat[q]; if (s->st[a] == 0 && p->by[a] < e) { any = 1; if (p->by[a] < mn) mn = p->by[a]; } }
		if (!any) { s->vs[d] = -1; total += (double)p->w[d] * e; } else s->vs[d] = (double)p->w[d] * mn;
	}
	for (;;) {
		int changed = 0;
		for (jj = p->cstart_d[c]; jj < p->cstart_d[c + 1]; jj++) {
			d = p->cd[jj];
			if (s->vs[d] < 0) continue;
			{
				double w = (double)p->w[d], v = s->vs[d], cap = w * s->eff[d], nxt = cap, t;
				int e = s->eff[d];
				for (q = p->dstart[d]; q < p->dstart[d + 1]; q++) {
					a = p->dat[q]; if (s->st[a] != 0 || p->by[a] >= e) continue;
					{ double ca = w * p->by[a]; if (ca > v + 1e-9 && ca < nxt) nxt = ca; }
				}
				t = nxt;
				for (q = p->dstart[d]; q < p->dstart[d + 1]; q++) {
					a = p->dat[q]; if (s->st[a] != 0 || p->by[a] >= e) continue;
					{ double ca = w * p->by[a], lo = ca > v ? ca : v, lim = lo + s->slack[a]; if (lim < t) t = lim; }
				}
				if (t > v + 1e-9) {
					for (q = p->dstart[d]; q < p->dstart[d + 1]; q++) {
						a = p->dat[q]; if (s->st[a] != 0 || p->by[a] >= e) continue;
						{ double ca = w * p->by[a], lo = ca > v ? ca : v; if (t > lo) s->slack[a] -= t - lo; }
					}
					s->vs[d] = t; changed = 1;
				}
			}
		}
		if (!changed) break;
	}
	for (jj = p->cstart_d[c]; jj < p->cstart_d[c + 1]; jj++) { d = p->cd[jj]; if (s->vs[d] >= 0) total += s->vs[d]; }
	(void)free_out;
	return total;
}

static double lb_at(search *s, double lam, double *comp_lb) {
	const problem *p = s->p; double tot = -lam * (double)s->R; int c;
	for (c = 0; c < p->ncomp; c++) { double x = da_comp(s, c, lam, NULL); if (comp_lb) comp_lb[c] = x; tot += x; }
	return tot;
}

static eo_i64 state_value(search *s) {
	const problem *p = s->p; eo_i64 tot = 0; int d;
	for (d = 0; d < p->nd; d++) tot += p->w[d] * s->eff[d];
	return tot;
}

static void set_in(search *s, int a) {
	const problem *p = s->p; int j;
	s->st[a] = 1; s->R -= p->cost[a]; s->trail[s->ntrail++] = a;
	for (j = p->astart[a]; j < p->astart[a + 1]; j++) {
		int d = p->ad[j];
		if (p->by[a] < s->eff[d]) { s->etrail_d[s->netrail] = d; s->etrail_v[s->netrail++] = s->eff[d]; s->eff[d] = p->by[a]; }
	}
}
static void set_out(search *s, int a) { s->st[a] = 2; s->trail[s->ntrail++] = a; }
/* undo to a mark: marks are (ntrail, netrail) pairs */
static void undo(search *s, int nt, int ne) {
	const problem *p = s->p;
	while (s->netrail > ne) { s->netrail--; s->eff[s->etrail_d[s->netrail]] = s->etrail_v[s->netrail]; }
	while (s->ntrail > nt) { int a = s->trail[--s->ntrail]; if (s->st[a] == 1) s->R += p->cost[a]; s->st[a] = 0; }
}

/* greedy completion from the state; records the incumbent if better */
static void primal(search *s, double alpha) {
	const problem *p = s->p; int nt = s->ntrail, ne = s->netrail, k;
	for (;;) {
		int pick = -1; double pr = 0;
		for (k = 0; k < p->m; k++) {
			eo_i64 g = 0; int j;
			if (s->st[k] != 0) continue;
			if (p->cost[k] > s->R) continue;
			for (j = p->astart[k]; j < p->astart[k + 1]; j++) { int d = p->ad[j]; if (s->eff[d] > p->by[k]) g += p->w[d] * (s->eff[d] - p->by[k]); }
			if (g <= 0) continue;
			{ double r = (double)g / pow((double)p->cost[k], alpha); if (pick < 0 || r > pr * (1 + 1e-12)) { pick = k; pr = r; } }
		}
		if (pick < 0) break;
		set_in(s, pick);
	}
	{
		eo_i64 v = state_value(s);
		if (v < s->ub) { int i; s->ub = v; for (i = 0; i < p->m; i++) s->bestsel[i] = s->st[i] == 1; improved(s); }
	}
	undo(s, nt, ne);
}

static int out_of_time(search *s) {
	if (s->stopped || s->solved) return 1;
	if (s->o->node_limit && s->nodes >= s->o->node_limit) s->stopped = 1;
	else if (s->o->time_limit > 0 && (s->nodes & 15) == 0 && now() - s->t0 > s->o->time_limit) s->stopped = 1;
	return s->stopped;
}

static void bb(search *s, int depth) {
	const problem *p = s->p; int nt = s->ntrail, ne = s->netrail, k;
	double lam, best, *clb;
	if (out_of_time(s)) return;
	s->nodes++;
	/* atoms that no longer fit are out */
	for (k = 0; k < p->m; k++) if (s->st[k] == 0) {
		int j, use = 0;
		if (p->cost[k] > s->R) { set_out(s, k); continue; }
		for (j = p->astart[k]; j < p->astart[k + 1]; j++) if (p->by[k] < s->eff[p->ad[j]]) { use = 1; break; }
		if (!use) set_out(s, k);       /* shortens nothing now: redundant with what is chosen, it can only cost */
	}
	/* everything free fits: exact */
	{
		eo_i64 tc = 0; for (k = 0; k < p->m; k++) if (s->st[k] == 0) tc += p->cost[k];
		if (tc <= s->R) {
			int j; for (k = 0; k < p->m; k++) if (s->st[k] == 0) { /* choose all useful ones */ int use = 0; for (j = p->astart[k]; j < p->astart[k + 1]; j++) if (p->by[k] < s->eff[p->ad[j]]) { use = 1; break; } if (use) set_in(s, k); }
			{ eo_i64 v = state_value(s); if (v < s->ub) { int i; s->ub = v; for (i = 0; i < p->m; i++) s->bestsel[i] = s->st[i] == 1; improved(s); } }
			undo(s, nt, ne); return;
		}
	}
	/* the bound: the best multiplier near the parent's, a coarse search when there is none */
	clb = xmalloc(p->ncomp * sizeof(double));
	{
		double thr = (double)s->ub - 1 + 1e-6, x, v, step = 0.3; int it;
		if (!s->have_root) {
			double bl = -1e300, bx = 1; int i;
			for (i = 0; i <= 24; i++) { double xx = 1e-4 * pow(1e8, i / 24.0), vv = lb_at(s, xx, NULL); if (vv > bl) { bl = vv; bx = xx; } }
			s->lam = bx; s->have_root = 1;
		}
		x = s->lam; v = lb_at(s, x, NULL);
		for (it = 0; it < 14 && v <= thr; it++) {
			double up = lb_at(s, x * (1 + step), NULL), dn = lb_at(s, x / (1 + step), NULL);
			if (up > v && up >= dn) { x *= 1 + step; v = up; } else if (dn > v) { x /= 1 + step; v = dn; } else { step /= 2; if (step < 0.01) break; }
		}
		s->lam = x; best = v;
		if (!s->root_set) s->root_lb = (eo_i64)ceil(v - 1e-6);
	}
	s->root_set = 1;
	lam = s->lam;
	if (best > (double)s->ub - 1 + 1e-6) { free(clb); undo(s, nt, ne); return; }
	if (depth == 0 || (s->nodes & 7) == 0) primal(s, 1.0);
	/* branching: the free atom the bound opens (slack 0) with the largest cost, otherwise the one with the largest gain */
	lb_at(s, lam, clb);
	{
		int pick = -1; double pw = -1;
		for (k = 0; k < p->m; k++) if (s->st[k] == 0) {
			double w = 0; int j;
			if (s->slack[k] > 1e-7 * (1 + lam * (double)p->cost[k])) continue;    /* slack left by the last component evaluated: only valid for tight ones */
			for (j = p->astart[k]; j < p->astart[k + 1]; j++) if (s->eff[p->ad[j]] > p->by[k]) w += (double)p->w[p->ad[j]] * (s->eff[p->ad[j]] - p->by[k]);
			if (w <= 0) continue;
			w *= (double)p->cost[k];
			if (w > pw) { pw = w; pick = k; }
		}
		if (pick < 0) for (k = 0; k < p->m; k++) if (s->st[k] == 0) {
			double w = 0; int j;
			for (j = p->astart[k]; j < p->astart[k + 1]; j++) if (s->eff[p->ad[j]] > p->by[k]) w += (double)p->w[p->ad[j]] * (s->eff[p->ad[j]] - p->by[k]);
			if (w > pw) { pw = w; pick = k; }
		}
		free(clb);
		if (pick < 0) { undo(s, nt, ne); return; }
		{
			int nt2 = s->ntrail, ne2 = s->netrail;
			set_in(s, pick); bb(s, depth + 1); undo(s, nt2, ne2);
			if (!s->stopped) { set_out(s, pick); bb(s, depth + 1); undo(s, nt2, ne2); }
		}
	}
	undo(s, nt, ne);
}

/* ------------------------------------------------------------------------------------------------ one component, one budget */
/* the sub-problem of component c of p: atoms and demands renumbered; constv is the value of the demands (so values are comparable) */
static void extract(const problem *p, int c, problem *q) {
	int i, j, na = p->cstart_a[c + 1] - p->cstart_a[c], nd = p->cstart_d[c + 1] - p->cstart_d[c], *amap = xmalloc((p->m + 1) * sizeof(int)), tot = 0, t2 = 0;
	memset(q, 0, sizeof *q);
	for (i = 0; i < p->m; i++) amap[i] = -1;
	q->m = na; q->cid = xmalloc((na + 1) * sizeof(int)); q->cost = xmalloc((na + 1) * sizeof(eo_i64)); q->by = xmalloc((na + 1) * sizeof(int));
	for (i = 0; i < na; i++) { int a = p->ca[p->cstart_a[c] + i]; amap[a] = i; q->cid[i] = a; q->cost[i] = p->cost[a]; q->by[i] = p->by[a]; }
	q->nd = nd; q->w = xmalloc((nd + 1) * sizeof(eo_i64)); q->base = xmalloc((nd + 1) * sizeof(int)); q->dstart = xmalloc((nd + 2) * sizeof(int));
	for (i = 0; i < nd; i++) tot += p->dstart[p->cd[p->cstart_d[c] + i] + 1] - p->dstart[p->cd[p->cstart_d[c] + i]];
	q->dat = xmalloc((tot + 1) * sizeof(int)); q->dstart[0] = 0;
	for (i = 0; i < nd; i++) {
		int d = p->cd[p->cstart_d[c] + i]; q->w[i] = p->w[d]; q->base[i] = p->base[d];
		for (j = p->dstart[d]; j < p->dstart[d + 1]; j++) q->dat[t2++] = amap[p->dat[j]];
		q->dstart[i + 1] = t2;
	}
	{
		int *c2 = xcalloc(na + 2, sizeof(int)), *pos;
		for (i = 0; i < t2; i++) c2[q->dat[i] + 1]++;
		for (i = 0; i < na; i++) c2[i + 1] += c2[i];
		q->astart = c2; q->ad = xmalloc((t2 + 1) * sizeof(int)); pos = xmalloc((na + 2) * sizeof(int)); memcpy(pos, c2, (na + 1) * sizeof(int));
		for (i = 0; i < nd; i++) for (j = q->dstart[i]; j < q->dstart[i + 1]; j++) q->ad[pos[q->dat[j]]++] = i;
		free(pos);
	}
	q->ncomp = 1; q->cstart_a = xmalloc(2 * sizeof(int)); q->cstart_d = xmalloc(2 * sizeof(int)); q->cstart_a[0] = q->cstart_d[0] = 0; q->cstart_a[1] = na; q->cstart_d[1] = nd;
	q->ca = xmalloc((na + 1) * sizeof(int)); for (i = 0; i < na; i++) q->ca[i] = i;
	q->cd = xmalloc((nd + 1) * sizeof(int)); for (i = 0; i < nd; i++) q->cd[i] = i;
	q->comp_of_atom = xcalloc(na + 1, sizeof(int));
	q->req = xmalloc(sizeof(int));
	free(amap);
}

typedef struct { eo_i64 cost, value; char *sel; } fpoint;

/* min over S, cost(S) <= budget, of the demand values of q (no constant); proved = 0 if a limit stopped the search; *lb is a lower bound */
static eo_i64 solve_budget(const problem *q, eo_i64 budget, eo_i64 known_lb, double *lam_io, const eo_opts *o, double t0, eo_i64 *nodes, char *sel, int *proved, eo_i64 *lb) {
	search s; int i; eo_i64 v;
	memset(&s, 0, sizeof s);
	s.p = q; s.o = o; s.st = xcalloc(q->m + 1, 1); s.eff = xmalloc((q->nd + 1) * sizeof(int)); s.bestsel = xcalloc(q->m + 1, 1);
	s.vs = xmalloc((q->nd + 1) * sizeof(double)); s.slack = xmalloc((q->m + 1) * sizeof(double)); s.trail = xmalloc((q->m + 1) * sizeof(int));
	{ int sz = q->dstart[q->nd] + q->m + 1; s.etrail_d = xmalloc(sz * sizeof(int)); s.etrail_v = xmalloc(sz * sizeof(int)); }
	for (i = 0; i < q->nd; i++) s.eff[i] = q->base[i];
	s.R = budget; s.t0 = t0; s.ub = 1LL << 60; s.known_lb = known_lb; if (lam_io && *lam_io > 0) { s.lam = *lam_io; s.have_root = 1; }
	primal(&s, 1.0); primal(&s, 0.9); primal(&s, 1.1); primal(&s, 0.8); primal(&s, 1.25);
	{ eo_i64 e = 0; for (i = 0; i < q->nd; i++) e += q->w[i] * q->base[i]; if (e < s.ub) { s.ub = e; memset(s.bestsel, 0, q->m); } }
	improved(&s);
	if (!s.solved) bb(&s, 0);
	*nodes += s.nodes; *proved = !s.stopped; v = s.ub; if (lam_io && s.have_root) *lam_io = s.lam;
	*lb = s.stopped ? (s.have_root ? s.root_lb : 0) : v;
	memcpy(sel, s.bestsel, q->m);
	free(s.st); free(s.eff); free(s.bestsel); free(s.vs); free(s.slack); free(s.trail); free(s.etrail_d); free(s.etrail_v);
	return v;
}

static eo_i64 sel_value(const problem *q, const char *sel, eo_i64 *cost) {
	eo_i64 tot = 0, c = 0; int d, j, a;
	for (a = 0; a < q->m; a++) if (sel[a]) c += q->cost[a];
	for (d = 0; d < q->nd; d++) { int b = q->base[d]; for (j = q->dstart[d]; j < q->dstart[d + 1]; j++) if (sel[q->dat[j]] && q->by[q->dat[j]] < b) b = q->by[q->dat[j]]; tot += q->w[d] * b; }
	*cost = c; return tot;
}

/* remove the chosen atoms whose removal does not raise the value (largest cost first) */
static void make_irredundant(const problem *q, char *sel) {
	int a, done = 0; eo_i64 c, v, c2, v2;
	v = sel_value(q, sel, &c);
	while (!done) {
		int best = -1; done = 1;
		for (a = 0; a < q->m; a++) if (sel[a]) { sel[a] = 0; v2 = sel_value(q, sel, &c2); sel[a] = 1; if (v2 == v && (best < 0 || q->cost[a] > q->cost[best])) best = a; }
		if (best >= 0) { sel[best] = 0; done = 0; }
	}
	(void)c;
}

/* a search state over q with nothing decided: for the bounds */
static void search_init(search *s, const problem *q, const eo_opts *o) {
	int i;
	memset(s, 0, sizeof *s);
	s->p = q; s->o = o; s->st = xcalloc(q->m + 1, 1); s->eff = xmalloc((q->nd + 1) * sizeof(int)); s->bestsel = xcalloc(q->m + 1, 1);
	s->vs = xmalloc((q->nd + 1) * sizeof(double)); s->slack = xmalloc((q->m + 1) * sizeof(double)); s->trail = xmalloc((q->m + 1) * sizeof(int));
	{ int sz = q->dstart[q->nd] + q->m + 1; s->etrail_d = xmalloc(sz * sizeof(int)); s->etrail_v = xmalloc(sz * sizeof(int)); }
	for (i = 0; i < q->nd; i++) s->eff[i] = q->base[i];
}
static void search_done(search *s) { free(s->st); free(s->eff); free(s->bestsel); free(s->vs); free(s->slack); free(s->trail); free(s->etrail_d); free(s->etrail_v); }

#define NLAM 160
typedef struct { problem q; fpoint *pts; int n, cap; double L[NLAM]; eo_i64 tot; } compinfo;

static void add_point(compinfo *ci, eo_i64 cost, eo_i64 value, const char *sel) {
	if (ci->n == ci->cap) { ci->cap = ci->cap ? 2 * ci->cap : 16; ci->pts = xrealloc(ci->pts, ci->cap * sizeof *ci->pts); }
	ci->pts[ci->n].cost = cost; ci->pts[ci->n].value = value; ci->pts[ci->n].sel = xmalloc(ci->q.m + 1); memcpy(ci->pts[ci->n].sel, sel, ci->q.m); ci->n++;
}
static int cmp_pt(const void *a, const void *b) { const fpoint *x = a, *y = b; if (x->cost != y->cost) return x->cost < y->cost ? -1 : 1; return x->value < y->value ? -1 : x->value > y->value; }
/* keep the efficient points (increasing cost, strictly decreasing value) */
static void pareto(compinfo *ci) {
	int j, w = 0; fpoint *out = xmalloc((ci->n + 1) * sizeof *out);
	qsort(ci->pts, ci->n, sizeof *ci->pts, cmp_pt);
	for (j = 0; j < ci->n; j++) if (w == 0 || ci->pts[j].value < out[w - 1].value) out[w++] = ci->pts[j]; else free(ci->pts[j].sel);
	free(ci->pts); ci->pts = out; ci->n = w; ci->cap = w + 1; ci->pts = xrealloc(ci->pts, ci->cap * sizeof *ci->pts);
}

/* the multiple-choice knapsack over the frontiers; returns the least value (<0: infeasible) and the point chosen per component */
static eo_i64 knapsack(compinfo *ci, int nc, eo_i64 avail, int *pick) {
	eo_i64 *dp = xmalloc((avail + 1) * sizeof(eo_i64)), *nd2 = xmalloc((avail + 1) * sizeof(eo_i64)); short **choice = xcalloc(nc + 1, sizeof *choice); int c, j; long b;
	for (b = 0; b <= avail; b++) dp[b] = 0;
	for (c = 0; c < nc; c++) {
		choice[c] = xmalloc((avail + 1) * sizeof(short));
		for (b = 0; b <= avail; b++) {
			eo_i64 bestv = -1; int bj = -1;
			for (j = 0; j < ci[c].n; j++) if (ci[c].pts[j].cost <= b && dp[b - ci[c].pts[j].cost] >= 0) { eo_i64 v = dp[b - ci[c].pts[j].cost] + ci[c].pts[j].value; if (bestv < 0 || v < bestv) { bestv = v; bj = j; } }
			nd2[b] = bestv; choice[c][b] = (short)bj;
		}
		memcpy(dp, nd2, (avail + 1) * sizeof(eo_i64));
	}
	{
		eo_i64 val = dp[avail];
		if (val >= 0) { b = avail; for (c = nc - 1; c >= 0; c--) { j = choice[c][b]; pick[c] = j; b -= ci[c].pts[j].cost; } }
		for (c = 0; c < nc; c++) free(choice[c]);
		free(choice); free(dp); free(nd2);
		return val;
	}
}

int eo_solve(const eo_model *m, const eo_opts *o, eo_result *r) {
	problem p; int k, c, i, j, nc; double t0 = now(); eo_i64 nodes = 0, avail, ub_red, lbsum_const;
	int proved_all = 1; compinfo *ci; int *pick; eo_i64 *Lall; double lams[NLAM];
	memset(r, 0, sizeof *r); r->sel = xcalloc(m->ncand + 1, 1);
	reduce(m, &p);
	if (p.infeasible) { problem_free(&p); r->proved = 1; r->value = -1; return -1; }
	avail = p.avail; nc = p.ncomp; (void)Lall; (void)lbsum_const;
	if (o->verbose) fprintf(stderr, "encopt: %d candidates -> %d after reduction, %d demand classes, %d components, %lld patterns available\n", m->ncand, p.m, p.nd, nc, (long long)avail);
	ci = xcalloc(nc + 1, sizeof *ci); pick = xmalloc((nc + 1) * sizeof(int));
	for (c = 0; c < nc; c++) { extract(&p, c, &ci[c].q); for (i = 0; i < ci[c].q.m; i++) ci[c].tot += ci[c].q.cost[i]; }
	/* the dual-ascent bounds of every component at NLAM multipliers (log scale): valid lower bounds on min value + lam * cost */
	for (k = 0; k < NLAM; k++) lams[k] = 1e-3 * pow(1e7, k / (NLAM - 1.0));
	for (c = 0; c < nc; c++) { search s; search_init(&s, &ci[c].q, o); for (k = 0; k < NLAM; k++) ci[c].L[k] = da_comp(&s, 0, lams[k], NULL); search_done(&s); }
	/* pass 1: a coarse frontier from budgets on a geometric grid (heuristic: node limit), solved by the dynamic programme: an upper bound and a selection */
	{
		eo_opts o1 = *o; o1.node_limit = 300; o1.time_limit = 0;
		for (c = 0; c < nc; c++) {
			char *sel = xmalloc(ci[c].q.m + 1); double B = (double)(ci[c].tot < avail ? ci[c].tot : avail), lamc = 0; int proved; eo_i64 lb, cst, v;
			for (;;) {
				v = solve_budget(&ci[c].q, (eo_i64)B, 0, &lamc, &o1, t0, &nodes, sel, &proved, &lb);
				make_irredundant(&ci[c].q, sel); v = sel_value(&ci[c].q, sel, &cst); add_point(&ci[c], cst, v, sel);
				if (B < 1) break;
				B = B * 0.8; if (B < 1) B = 0;
			}
			{ eo_i64 e = 0; memset(sel, 0, ci[c].q.m + 1); v = sel_value(&ci[c].q, sel, &cst); e = v; add_point(&ci[c], 0, e, sel); }
			free(sel); pareto(&ci[c]);
		}
		ub_red = knapsack(ci, nc, avail, pick);
		if (ub_red < 0) { proved_all = 0; ub_red = 1LL << 60; }
		else for (c = 0; c < nc; c++) { int a; for (a = 0; a < ci[c].q.m; a++) if (ci[c].pts[pick[c]].sel[a]) r->sel[p.cid[ci[c].q.cid[a]]] = 1; }
		if (ub_red < (1LL << 60)) {
			/* coordinate descent: re-solve one component at a time for the budget the others leave it */
			eo_opts o2 = *o; int round, improved = 1; o2.node_limit = 3000; o2.time_limit = 0;
			char **cs = xmalloc(nc * sizeof(char *)); eo_i64 *cc = xmalloc(nc * sizeof(eo_i64)), *cv = xmalloc(nc * sizeof(eo_i64)), tc = 0;
			for (c = 0; c < nc; c++) { cs[c] = xmalloc(ci[c].q.m + 1); memcpy(cs[c], ci[c].pts[pick[c]].sel, ci[c].q.m); cc[c] = ci[c].pts[pick[c]].cost; cv[c] = ci[c].pts[pick[c]].value; tc += cc[c]; }
			for (round = 0; round < 6 && improved; round++) {
				improved = 0;
				for (c = 0; c < nc; c++) {
					char *sel = xmalloc(ci[c].q.m + 1); double lamc = 0; int proved; eo_i64 lb, v, cst;
					eo_i64 R = avail - (tc - cc[c]);
					solve_budget(&ci[c].q, R < ci[c].tot ? R : ci[c].tot, 0, &lamc, &o2, t0, &nodes, sel, &proved, &lb);
					make_irredundant(&ci[c].q, sel); v = sel_value(&ci[c].q, sel, &cst);
					if (v < cv[c] || (v == cv[c] && cst < cc[c])) { if (v < cv[c]) improved = 1; tc += cst - cc[c]; cc[c] = cst; cv[c] = v; memcpy(cs[c], sel, ci[c].q.m); }
					free(sel);
				}
			}
			{ eo_i64 t = 0; memset(r->sel, 0, m->ncand + 1); for (c = 0; c < nc; c++) { int a; t += cv[c]; for (a = 0; a < ci[c].q.m; a++) if (cs[c][a]) r->sel[p.cid[ci[c].q.cid[a]]] = 1; } if (t < ub_red) ub_red = t; }
			for (c = 0; c < nc; c++) free(cs[c]);
			free(cs); free(cc); free(cv);
		}
		if (o->verbose) fprintf(stderr, "encopt: heuristic passes: value %lld (%.2fs)\n", (long long)(ub_red + p.constv), now() - t0);
	}
	/* pass 2: exact.  Only budgets that can belong to a solution of value <= thr matter: for the budget B of component c the bound  g_c(B) + H(avail - B)  (hulls of
	   the dual-ascent bounds, a different multiplier for each part) must stay <= thr.  thr starts just above the root bound and doubles its distance to it until the
	   dynamic programme over the windowed frontiers finds a solution (then that solution is optimal: every solution of value <= thr lies in the windows), or until
	   thr reaches the incumbent (then the incumbent is optimal). */
	{
		double S[NLAM], lb0 = -1e300, gap = 16; eo_i64 *Blo = xmalloc(nc * sizeof(eo_i64)), *Bhi = xmalloc(nc * sizeof(eo_i64)); int done = 0;
		for (k = 0; k < NLAM; k++) { double t = 0, v; for (c = 0; c < nc; c++) t += ci[c].L[k]; S[k] = t; v = t - lams[k] * (double)avail; if (v > lb0) lb0 = v; }
		{ double g0 = 0.4 * ((double)ub_red - lb0); if (g0 > gap) gap = g0; }
		if (o->verbose) fprintf(stderr, "encopt: root bound %lld, incumbent %lld\n", (long long)ceil(lb0 - 1e-6) + (long long)p.constv, (long long)(ub_red + p.constv));
		while (!done && !(proved_all == 0 && 0)) {
			double thr = lb0 + gap; int any_better = 1;
			if (thr >= (double)ub_red - 1 + 1e-6) { thr = (double)ub_red - 1 + 1e-6; done = 1; }
			for (c = 0; c < nc; c++) {
				long b; Blo[c] = -1; Bhi[c] = -1;
				for (b = 0; b <= avail; b++) {
					double g = -1e300, h = -1e300;
					for (k = 0; k < NLAM; k++) {
						double x = ci[c].L[k] - lams[k] * (double)b, y = S[k] - ci[c].L[k] - lams[k] * (double)(avail - b);
						if (x > g) g = x;
						if (y > h) h = y;
					}
					if (g + h <= thr) { if (Blo[c] < 0) Blo[c] = b; Bhi[c] = b; }
				}
				if (Blo[c] < 0) any_better = 0;
			}
			if (o->verbose) { eo_i64 w = 0; for (c = 0; c < nc; c++) if (Blo[c] >= 0) w += Bhi[c] - Blo[c] + 1; fprintf(stderr, "encopt: threshold %lld: windows of %lld budget values over %d components (of %lld) (%.2fs)\n", (long long)ceil(thr) + (long long)p.constv, (long long)w, nc, (long long)(avail + 1) * nc, now() - t0); }
			if (!any_better) { gap *= 1.5; if (done) break; continue; }
			for (c = 0; c < nc; c++) {
				compinfo *x = &ci[c]; char *sel = xmalloc(x->q.m + 1); eo_i64 B, prevv = 0; double lamc = 0; int d, jj;
				for (i = 0; i < x->n; i++) free(x->pts[i].sel);
				x->n = 0;
				for (d = 0; d < x->q.nd; d++) { int b = x->q.base[d]; for (jj = x->q.dstart[d]; jj < x->q.dstart[d + 1]; jj++) if (x->q.by[x->q.dat[jj]] < b) b = x->q.by[x->q.dat[jj]]; prevv += x->q.w[d] * b; }
				B = Bhi[c] < avail ? Bhi[c] : avail; if (B > x->tot) B = x->tot;
				for (;;) {
					int proved; eo_i64 lb, v, cst;
					solve_budget(&x->q, B, prevv, &lamc, o, t0, &nodes, sel, &proved, &lb);
					if (!proved) proved_all = 0;
					make_irredundant(&x->q, sel); v = sel_value(&x->q, sel, &cst); prevv = v;
					if (cst < Blo[c]) break;
					add_point(x, cst, v, sel);
					if (cst == 0 || (o->time_limit > 0 && now() - t0 > o->time_limit)) break;
					B = cst - 1;
				}
				free(sel); pareto(x);
				if (o->verbose > 1) fprintf(stderr, "encopt: component %d: %d atoms, window [%lld,%lld], %d frontier points, %lld nodes, %.2fs\n", c, x->q.m, (long long)Blo[c], (long long)Bhi[c], x->n, (long long)nodes, now() - t0);
			}
			{
				eo_i64 v = knapsack(ci, nc, avail, pick);
				if (v >= 0 && v < ub_red) {
					ub_red = v; memset(r->sel, 0, m->ncand + 1);
					for (c = 0; c < nc; c++) { int a; for (a = 0; a < ci[c].q.m; a++) if (ci[c].pts[pick[c]].sel[a]) r->sel[p.cid[ci[c].q.cid[a]]] = 1; }
					if ((double)v <= thr + 1e-9) done = 1;     /* every solution of value <= thr lies in the windows: this one is optimal */
				}
			}
			if (o->time_limit > 0 && now() - t0 > o->time_limit) { proved_all = 0; break; }
			gap *= 1.5;
		}
		free(Blo); free(Bhi);
	}
	for (k = 0; k < p.nreq; k++) r->sel[p.req[k]] = 1;
	for (c = 0; c < nc; c++) { for (i = 0; i < ci[c].n; i++) free(ci[c].pts[i].sel); free(ci[c].pts); problem_free(&ci[c].q); }
	free(ci); free(pick); (void)j;
	r->value = ub_red + p.constv;
	r->nodes = nodes; r->secs = now() - t0; r->proved = proved_all;
	r->lower = proved_all ? r->value : 0;
	r->cost = eo_cost(m, r->sel);
	problem_free(&p);
	return 0;
}

/* ------------------------------------------------------------------------------------------------ brute force (tests) */
eo_i64 eo_brute(const eo_model *m, char *sel) {
	eo_i64 best = -1; unsigned long long mask, lim; int k;
	if (m->ncand > 26) return -1;
	lim = 1ULL << m->ncand;
	for (mask = 0; mask < lim; mask++) {
		char *t = sel ? NULL : NULL; (void)t;
		eo_i64 cost = 0, v; char buf[32];
		memset(buf, 0, sizeof buf);
		for (k = 0; k < m->ncand; k++) if (mask >> k & 1) { buf[k] = 1; cost += m->form[m->cand[k]].pat; }
		if (cost + eo_forced_patterns(m) > m->budget) continue;
		{ int ok = 1, q; for (q = 0; q < m->nrequire; q++) { int c = eo_cand_by_name(m, m->require[q]); if (c >= 0 && !buf[c]) ok = 0; } for (q = 0; q < m->nforbid; q++) { int c = eo_cand_by_name(m, m->forbid[q]); if (c >= 0 && buf[c]) ok = 0; } if (!ok) continue; }
		v = eo_value(m, buf, NULL, NULL);
		if (best < 0 || v < best) { best = v; if (sel) memcpy(sel, buf, m->ncand); }
	}
	return best;
}

/* ------------------------------------------------------------------------------------------------ the prefix assignment */
int eo_assign(const eo_model *m, const int *forms, int nf, eo_leaf **out, eo_i64 *used_out, char *err, size_t errlen) {
	int f, n = 0, cap = 0, i; eo_leaf *lv = NULL; eo_i64 pos = 0;
	int *ord;
	for (f = 0; f < nf; f++) {
		const eo_form *fm = &m->form[forms[f]];
		if (fm->xbits) {
			if (n == cap) { cap = cap ? 2 * cap : 64; lv = xrealloc(lv, cap * sizeof *lv); }
			lv[n].form = forms[f]; lv[n].k = 0; lv[n].off = 0; lv[n].j = 0; lv[n].L = fm->L; lv[n].nm = fm->nmn; n++;
		} else {
			int off = 0, b, k = 0;
			for (b = 20; b >= 0; b--) if (fm->nmn >> b & 1) {
				if (n == cap) { cap = cap ? 2 * cap : 64; lv = xrealloc(lv, cap * sizeof *lv); }
				lv[n].form = forms[f]; lv[n].k = ++k; lv[n].off = off; lv[n].j = b; lv[n].L = fm->L - b; lv[n].nm = 1 << b; off += 1 << b; n++;
			}
		}
	}
	for (i = 0; i < n; i++) if (lv[i].L < 1 || lv[i].L > 16) { snprintf(err, errlen, "prefix length %d out of range for form %s", lv[i].L, m->form[lv[i].form].name); free(lv); return -1; }
	ord = xmalloc(n * sizeof(int)); for (i = 0; i < n; i++) ord[i] = i;
	/* stable insertion sort by prefix length: the study's canonical assignment (shorter prefixes first, ties in the order of the leaves) */
	for (i = 1; i < n; i++) { int x = ord[i], j = i - 1; while (j >= 0 && lv[ord[j]].L > lv[x].L) { ord[j + 1] = ord[j]; j--; } ord[j + 1] = x; }
	for (i = 0; i < n; i++) {
		eo_leaf *l = &lv[ord[i]]; eo_i64 size = (eo_i64)1 << (16 - l->L);
		if (pos % size) pos += size - pos % size;
		l->lo = pos; l->prefix = (unsigned)(pos >> (16 - l->L)); pos += size;
	}
	free(ord);
	if (pos > 65536) { snprintf(err, errlen, "Kraft's sum exceeds 1 (%lld of 65536 patterns)", (long long)pos); free(lv); return -1; }
	*out = lv; if (used_out) *used_out = pos;
	return n;
}

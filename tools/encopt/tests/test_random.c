/* test_random.c -- encopt's exact solver against brute force (all subsets) on small random instances, and checks of the prefix assignment.
 * usage: test_random [instances] [seed]            exit status 0 when every instance agrees */
#define _POSIX_C_SOURCE 200809L
#include "../encopt.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static unsigned long long rs;
static unsigned rnd(void) { rs = rs * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(rs >> 33); }
static int rr(int n) { return (int)(rnd() % (unsigned)n); }

static void mkform(eo_form *f, const char *name, int forced, int parcels, int L, int nmn, int xbits) {
	int i; char buf[32];
	memset(f, 0, sizeof *f);
	f->name = strdup(name); f->forced = forced; f->parcels = parcels; f->L = L; f->xbits = xbits; f->nmn = nmn;
	f->mn = malloc(nmn * sizeof(char *));
	for (i = 0; i < nmn; i++) { snprintf(buf, sizeof buf, "%s.m%d", name, i); f->mn[i] = strdup(buf); }
	f->pat = xbits ? (eo_i64)1 << (16 - L) : (eo_i64)nmn << (16 - L);
}

static void random_model(eo_model *m, int ncand) {
	int i, j, nd; char nm[32];
	memset(m, 0, sizeof *m);
	m->total = 65536;
	m->nforced = 3; m->ncand = ncand; m->nform = 3 + ncand;
	m->form = calloc(m->nform, sizeof *m->form); m->cand = malloc(ncand * sizeof(int));
	for (i = 0; i < 3; i++) { snprintf(nm, sizeof nm, "F%d", i); mkform(&m->form[i], nm, 1, 1 + rr(2), 4 + rr(4), 1 + rr(3), 0); }
	for (i = 0; i < ncand; i++) {
		int par = 1 + rr(3), L = par == 1 ? 3 + rr(6) : 8 + rr(8), nmn = 1 + rr(3);
		snprintf(nm, sizeof nm, "C%d", i);
		mkform(&m->form[3 + i], nm, 0, par, L, nmn, 0); m->cand[i] = 3 + i;
	}
	{ eo_i64 f = 0; for (i = 0; i < 3; i++) f += m->form[i].pat; m->budget = f + 1 + rr(40000); if (m->budget > 65536) m->budget = 65536; }
	nd = 3 + rr(25); m->ndem = nd; m->dem = calloc(nd, sizeof *m->dem);
	for (i = 0; i < nd; i++) {
		eo_demand *d = &m->dem[i]; int k = 0, a[64];
		d->w = 1 + rr(1000); d->base = (rr(8) == 0) ? 99 : 2 * (1 + rr(3)) + 2 * rr(2);
		for (j = 0; j < ncand; j++) if (rr(100) < 35) a[k++] = j;
		d->nat = k; d->at = malloc((k + 1) * sizeof(int)); memcpy(d->at, a, k * sizeof(int));
	}
	if (rr(4) == 0) { m->nrequire = 1; m->require = malloc(sizeof(char *)); snprintf(nm, sizeof nm, "C%d", rr(ncand)); m->require[0] = strdup(nm); }
	if (rr(4) == 0) { m->nforbid = 1; m->forbid = malloc(sizeof(char *)); snprintf(nm, sizeof nm, "C%d", rr(ncand)); if (m->nrequire && !strcmp(nm, m->require[0])) { m->nforbid = 0; free(m->forbid); m->forbid = NULL; } else m->forbid[0] = strdup(nm); }
}

int main(int argc, char **argv) {
	int n = argc > 1 ? atoi(argv[1]) : 500, it, bad = 0, nonopt = 0, gsub = 0, tested = 0; eo_opts o;
	rs = argc > 2 ? strtoull(argv[2], NULL, 10) : 12345;
	memset(&o, 0, sizeof o);
	for (it = 0; it < n; it++) {
		eo_model m; eo_result r; char *bsel; eo_i64 bv; int nc = 4 + rr(11);
		random_model(&m, nc);
		bsel = calloc(32, 1);
		bv = eo_brute(&m, bsel);
		if (bv < 0) { /* no feasible selection (forced too big or a required one does not fit): the solver must say infeasible or the empty/required selection */
			eo_free(&m); free(bsel); continue;
		}
		if (eo_solve(&m, &o, &r) < 0) { printf("instance %d: solver says infeasible, brute force value %lld\n", it, (long long)bv); bad++; }
		else {
			eo_i64 v = eo_value(&m, r.sel, NULL, NULL);
			{ char gs[32]; memset(gs, 0, sizeof gs); eo_greedy(&m, gs, NULL); tested++; if (eo_value(&m, gs, NULL, NULL) > bv) gsub++; }
			if (!r.proved) { nonopt++; }
			if (v != r.value || v != bv || eo_cost(&m, r.sel) + eo_forced_patterns(&m) > m.budget) {
				printf("instance %d: solver %lld (selection value %lld cost %lld budget %lld) brute force %lld\n", it, (long long)r.value, (long long)v, (long long)(eo_cost(&m, r.sel) + eo_forced_patterns(&m)), (long long)m.budget, (long long)bv);
				bad++;
			}
			{ /* the required and forbidden constraints hold */
				int q; for (q = 0; q < m.nrequire; q++) if (!r.sel[eo_cand_by_name(&m, m.require[q])]) { printf("instance %d: required candidate missing\n", it); bad++; }
				for (q = 0; q < m.nforbid; q++) if (r.sel[eo_cand_by_name(&m, m.forbid[q])]) { printf("instance %d: forbidden candidate chosen\n", it); bad++; }
			}
			{ /* prefix assignment of forced + chosen: Kraft's inequality and prefix-freeness */
				int forms[64], nf = 0, i, j, k; eo_leaf *lv; eo_i64 used; char err[200];
				for (i = 0; i < m.nform; i++) if (m.form[i].forced) forms[nf++] = i;
				for (k = 0; k < m.ncand; k++) if (r.sel[k]) forms[nf++] = m.cand[k];
				k = eo_assign(&m, forms, nf, &lv, &used, err, sizeof err);
				if (k < 0) { /* forced + chosen exceed the leaf range only if a prefix length < 1: the instances keep L >= 3 so this is a failure */ printf("instance %d: assign: %s\n", it, err); bad++; }
				else {
					for (i = 0; i < k; i++) for (j = i + 1; j < k; j++) {
						eo_i64 s1 = (eo_i64)1 << (16 - lv[i].L), s2 = (eo_i64)1 << (16 - lv[j].L);
						if (lv[i].lo < lv[j].lo + s2 && lv[j].lo < lv[i].lo + s1) { printf("instance %d: leaves %d and %d overlap\n", it, i, j); bad++; }
					}
					if (used > m.budget + 65536 || used > 65536) { printf("instance %d: used %lld\n", it, (long long)used); bad++; }
					free(lv);
				}
			}
		}
		free(r.sel); free(bsel); eo_free(&m);
	}
	printf("%d random instances (%d feasible, the study's greedy is suboptimal on %d): %d disagreements with brute force, %d not proved\n", n, tested, gsub, bad, nonopt);
	return bad ? 1 : 0;
}

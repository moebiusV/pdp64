/* main.c -- the command line of encopt (encopt(1)). */
#define _POSIX_C_SOURCE 200809L
#include "encopt.h"
#include <stdlib.h>
#include <string.h>

#ifndef ENCOPT_VERSION
#define ENCOPT_VERSION "1.1"
#endif

static void usage(FILE *f) {
	fputs("usage: encopt [-O OBJECTIVE] [-k BYTES] [-o OUTPUT] [-t SECONDS] [-n NODES] [-r NAME] [-x NAME] [-C] [-q] INPUT\n"
	      "       encopt --version | --help\n"
	      "  -O OBJ      the objective (also --objective OBJ): static (bytes of the corpus; the default), fetch (bytes fetched when the programs run) or\n"
	      "              exec (operations executed, bytes fetched breaking ties)\n"
	      "  -k BYTES    exec: the bytes one executed operation counts for (also --opcost; default 4096)\n"
	      "  -o FILE     write the result to FILE (default: standard output)\n"
	      "  -t SECONDS  time limit of the exact search (default 600; 0 = none)\n"
	      "  -n NODES    node limit of the exact search (default none)\n"
	      "  -r NAME     the candidate NAME must be chosen (a constraint; repeatable)\n"
	      "  -x NAME     the candidate NAME may not be chosen (a constraint; repeatable)\n"
	      "  -C          evaluate only the committed selection of the input (lines `committed`) and write its prefix assignment\n"
	      "  -q          no progress on standard error\n", f);
}

static void add(char ***v, int *n, const char *s) { *v = realloc(*v, (*n + 1) * sizeof **v); (*v)[(*n)++] = strdup(s); }

static void line_cmp(FILE *f, const eo_model *m, const char *name, const char *sel, eo_i64 base) {
	eo_i64 un, ex, v = eo_value(m, sel, &un, &ex);
	fprintf(f, "compare %s credit %lld bytes %lld unencodable %lld patterns %lld", name, (long long)v, (long long)ex, (long long)un, (long long)(eo_forced_patterns(m) + eo_cost(m, sel)));
	if (base > 0) fprintf(f, " vs-committed %+lld", (long long)(ex - base));
	fputc('\n', f);
}

static void line_metrics(FILE *f, const eo_model *m, const char *name, const char *sel) {
	eo_metrics x; eo_measure(m, sel, &x);
	fprintf(f, "metrics %s static-bytes %lld fetch-bytes %lld operations %lld unencodable-static %lld unencodable-dynamic %lld\n", name, (long long)x.static_bytes, (long long)x.fetch_bytes, (long long)x.ops,
	    (long long)x.unenc_static, (long long)x.unenc_dynamic);
}

static void write_leaves(FILE *f, const eo_model *m, const char *sel, const char *const *order, int norder) {
	int *forms = malloc((m->nform + 1) * sizeof(int)), nf = 0, i, k; eo_leaf *lv; eo_i64 used; char err[200]; int n;
	for (i = 0; i < m->nform; i++) if (m->form[i].forced) forms[nf++] = i;
	if (order) { for (k = 0; k < norder; k++) { int c = eo_cand_by_name(m, order[k]); if (c >= 0) forms[nf++] = m->cand[c]; } }
	else for (k = 0; k < m->ncand; k++) if (sel[k]) forms[nf++] = m->cand[k];
	n = eo_assign(m, forms, nf, &lv, &used, err, sizeof err);
	if (n < 0) { fprintf(f, "error %s\n", err); free(forms); return; }
	fprintf(f, "kraft %lld 65536\n", (long long)used);
	for (i = 0; i < n; i++) {
		const eo_form *fm = &m->form[lv[i].form]; int b;
		fprintf(f, "leaf %s %d %d ", fm->name, lv[i].k, lv[i].L);
		for (b = lv[i].L - 1; b >= 0; b--) fputc('0' + (int)(lv[i].prefix >> b & 1), f);
		fprintf(f, " %d", lv[i].nm);
		for (b = 0; b < lv[i].nm; b++) fprintf(f, " %s", fm->mn[lv[i].off + b]);
		fputc('\n', f);
	}
	free(lv); free(forms);
}

int main(int argc, char **argv) {
	eo_model m; eo_opts o; eo_result r; char err[400], *outname = NULL, *in = NULL; FILE *fi, *fo = stdout; int i, quiet = 0, conly = 0, vflag = 0, obj = EO_STATIC, opcost = EO_OPCOST_DEFAULT;
	char **req = NULL, **forb = NULL; int nreq = 0, nforb = 0;
	memset(&o, 0, sizeof o); o.time_limit = 600;
	for (i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--help") || !strcmp(argv[i], "-h")) { usage(stdout); return 0; }
		else if (!strcmp(argv[i], "--version")) { puts("encopt " ENCOPT_VERSION); return 0; }
		else if ((!strcmp(argv[i], "-O") || !strcmp(argv[i], "--objective")) && i + 1 < argc) {
			const char *v = argv[++i];
			if (!strcmp(v, "static")) obj = EO_STATIC; else if (!strcmp(v, "fetch")) obj = EO_FETCH; else if (!strcmp(v, "exec")) obj = EO_EXEC;
			else { fprintf(stderr, "encopt: unknown objective %s (static, fetch or exec)\n", v); return 2; }
		}
		else if ((!strcmp(argv[i], "-k") || !strcmp(argv[i], "--opcost")) && i + 1 < argc) opcost = atoi(argv[++i]);
		else if (!strcmp(argv[i], "-o") && i + 1 < argc) outname = argv[++i];
		else if (!strcmp(argv[i], "-t") && i + 1 < argc) o.time_limit = atof(argv[++i]);
		else if (!strcmp(argv[i], "-n") && i + 1 < argc) o.node_limit = atoll(argv[++i]);
		else if (!strcmp(argv[i], "-r") && i + 1 < argc) add(&req, &nreq, argv[++i]);
		else if (!strcmp(argv[i], "-x") && i + 1 < argc) add(&forb, &nforb, argv[++i]);
		else if (!strcmp(argv[i], "-C")) conly = 1;
		else if (!strcmp(argv[i], "-q")) quiet = 1;
		else if (!strcmp(argv[i], "-v")) vflag++;
		else if (argv[i][0] == '-' && argv[i][1]) { usage(stderr); return 2; }
		else in = argv[i];
	}
	if (!in) { usage(stderr); return 2; }
	fi = strcmp(in, "-") ? fopen(in, "r") : stdin;
	if (!fi) { perror(in); return 2; }
	if (eo_read(fi, in, &m, err, sizeof err) < 0) { fprintf(stderr, "encopt: %s\n", err); return 2; }
	if (fi != stdin) fclose(fi);
	if (eo_set_objective(&m, obj, opcost) < 0) { fprintf(stderr, "encopt: the operation cost must be between 16 and 1000000\n"); return 2; }
	if (obj != EO_STATIC) {
		eo_i64 dyn = 0; for (i = 0; i < m.ndem; i++) dyn += m.dem[i].wd;
		if (!dyn) { fprintf(stderr, "encopt: the objective %s needs the dynamic counts of a profile, and the input has none (export.py --weights)\n", obj == EO_FETCH ? "fetch" : "exec"); return 2; }
	}
	for (i = 0; i < nreq; i++) { m.require = realloc(m.require, (m.nrequire + 1) * sizeof *m.require); m.require[m.nrequire++] = req[i]; }
	for (i = 0; i < nforb; i++) { m.forbid = realloc(m.forbid, (m.nforbid + 1) * sizeof *m.forbid); m.forbid[m.nforbid++] = forb[i]; }
	for (i = 0; i < m.nrequire; i++) if (eo_cand_by_name(&m, m.require[i]) < 0) { fprintf(stderr, "encopt: no candidate named %s\n", m.require[i]); return 2; }
	for (i = 0; i < m.nforbid; i++) if (eo_cand_by_name(&m, m.forbid[i]) < 0) { fprintf(stderr, "encopt: no candidate named %s\n", m.forbid[i]); return 2; }
	o.verbose = quiet ? 0 : 1 + vflag;
	if (outname) { fo = fopen(outname, "w"); if (!fo) { perror(outname); return 2; } }
	if (eo_forced_patterns(&m) > m.budget) { fprintf(stderr, "encopt: the forced forms take %lld patterns, more than the budget of %lld\n", (long long)eo_forced_patterns(&m), (long long)m.budget); return 1; }
	{
		char *csel = calloc(m.ncand + 1, 1); eo_i64 cbytes = 0, un;
		int have_c = 0;
		for (i = 0; i < m.ncommitted; i++) { int c = eo_cand_by_name(&m, m.committed[i]); if (c >= 0) { csel[c] = 1; have_c = 1; } }
		if (have_c) eo_value(&m, csel, &un, &cbytes);
		fprintf(fo, "encopt-output 2\n");
		fprintf(fo, "objective %s\n", obj == EO_STATIC ? "static" : obj == EO_FETCH ? "fetch" : "exec");
		if (obj == EO_EXEC) fprintf(fo, "operation-cost %d\n", opcost);
		if (conly) {
			fprintf(fo, "status committed-selection\n");
			line_cmp(fo, &m, "committed", csel, 0);
			line_metrics(fo, &m, "committed", csel);
			for (i = 0; i < m.ncommitted; i++) if (eo_cand_by_name(&m, m.committed[i]) >= 0) fprintf(fo, "chosen %s\n", m.committed[i]);
			write_leaves(fo, &m, csel, (const char *const *)m.committed, m.ncommitted);
			return 0;
		}
		{
			char *g = calloc(m.ncand + 1, 1), *g2 = calloc(m.ncand + 1, 1); double alpha = 0;
			char *msel;
			eo_greedy(&m, g, &alpha);
			eo_greedy_refine(&m, g2, 20);
			if (eo_solve(&m, &o, &r) < 0) { fprintf(fo, "status infeasible\n"); return 1; }
			msel = r.sel;
			fprintf(fo, "status %s\n", r.proved ? ((m.nrequire || m.nforbid) ? "optimal-within-constraint-set" : "optimal") : "best-found");
			fprintf(fo, "objective-credit %lld\nlower-bound-credit %lld\ngap-credit %lld\n", (long long)r.value, (long long)r.lower, (long long)(r.value - r.lower));
			{ eo_i64 un2, ex2; eo_value(&m, msel, &un2, &ex2); fprintf(fo, "objective-bytes %lld\nunencodable-weight %lld\n", (long long)ex2, (long long)un2); }
			fprintf(fo, "patterns %lld %lld\n", (long long)(eo_forced_patterns(&m) + r.cost), (long long)m.budget);
			if (have_c) line_cmp(fo, &m, "committed", csel, cbytes);
			line_cmp(fo, &m, "greedy", g, have_c ? cbytes : 0);
			line_cmp(fo, &m, "greedy-refined", g2, have_c ? cbytes : 0);
			line_cmp(fo, &m, "encopt", msel, have_c ? cbytes : 0);
			if (have_c) line_metrics(fo, &m, "committed", csel);
			line_metrics(fo, &m, "greedy", g); line_metrics(fo, &m, "greedy-refined", g2); line_metrics(fo, &m, "encopt", msel);
			for (i = 0; i < m.ncand; i++) if (msel[i]) fprintf(fo, "chosen %s\n", m.form[m.cand[i]].name);
			write_leaves(fo, &m, msel, NULL, 0);
			if (!quiet) fprintf(stderr, "encopt: %s, credit objective %lld, %lld search nodes, %.2fs\n", r.proved ? "optimal" : "best found", (long long)r.value, (long long)r.nodes, r.secs);
			free(g); free(g2); eo_free(&m);
		}
		free(csel);
	}
	if (fo != stdout) fclose(fo);
	return 0;
}

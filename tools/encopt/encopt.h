/* encopt.h -- the model and the exact solvers of encopt (see encopt(1), encopt(5), README).
 *
 * The problem: a prefix code over the first parcel (16 bits) assigns every form a share of the 65,536 first-parcel patterns (a leaf of prefix length L takes 2^(16-L)
 * of them; Kraft's inequality, sum 2^-L <= 1, is the exact condition for a prefix-free assignment to exist).  The forms the instruction set cannot do without are
 * "forced"; the "candidate" forms each shorten some instructions of the corpus and each costs code space.  Choose the candidates that minimise the bytes of the
 * corpus within the code space that is left: a budgeted facility-location problem, solved here exactly (branch and bound with a Lagrangian dual-ascent bound).
 */
#ifndef ENCOPT_H
#define ENCOPT_H
#include <stdio.h>

typedef long long eo_i64;

typedef struct {
	char *name;
	int forced;          /* 1: forced form, 0: candidate */
	int parcels;         /* length of the instruction in 16-bit parcels */
	int L;               /* leaf prefix length of one mnemonic of the form (no sub-opcode bits): 16*parcels - operand bits - extended sub-opcode bits */
	int xbits;           /* bits of an extended sub-opcode: the whole mnemonic list is one leaf of prefix length L */
	int nmn;
	char **mn;
	eo_i64 pat;          /* first-parcel patterns taken: 2^(16-L) times the number of mnemonics (once if xbits) */
} eo_form;

typedef struct {
	eo_i64 w;            /* weight: executions or static count of the instruction class */
	int base;            /* bytes the forced forms give it (99: no form at all, the credit of the byte model) */
	int nat;
	int *at;             /* candidate numbers (0-based, order of the cand forms of the file) that could shorten it */
} eo_demand;

typedef struct {
	eo_i64 budget, total;        /* patterns usable (of total = 65536) */
	double lam;
	int nform, nforced, ncand;
	eo_form *form;               /* all forms, file order */
	int *cand;                   /* cand[k] = index into form of the k-th candidate */
	int ndem;
	eo_demand *dem;
	int ncommitted;
	char **committed;            /* names, catalogue order */
	int ncfix;                   /* constraints: forced-in / forbidden candidates (by name) */
	char **require, **forbid;
	int nrequire, nforbid;
} eo_model;

typedef struct {
	int proved;                  /* 1: the search finished: the selection is optimal for the model (and the constraints) */
	eo_i64 value;                /* objective with the credit of unencodable classes (what is minimised) */
	eo_i64 lower;                /* proved lower bound on the value (== value when proved) */
	eo_i64 cost;                 /* patterns used by the chosen candidates */
	char *sel;                   /* sel[k] = 1: candidate k chosen */
	eo_i64 nodes;
	double secs;
} eo_result;

typedef struct {
	double time_limit;           /* seconds, 0: none */
	eo_i64 node_limit;           /* 0: none */
	int verbose;
	int no_bound_cache;
} eo_opts;

int  eo_read(FILE *f, const char *fname, eo_model *m, char *err, size_t errlen);
void eo_free(eo_model *m);
int  eo_cand_by_name(const eo_model *m, const char *name);
eo_i64 eo_forced_patterns(const eo_model *m);
/* the objective of a selection: sum of weight * min(base, bytes of the chosen candidates that cover the demand) */
eo_i64 eo_value(const eo_model *m, const char *sel, eo_i64 *unenc_weight, eo_i64 *bytes_excl);
eo_i64 eo_cost(const eo_model *m, const char *sel);
/* the study's greedy (bytes saved per pattern^alpha over whole candidate leaves, alpha in {0.8,0.9,1,1.1,1.25}, the best) and its local search; sel gets the result */
eo_i64 eo_greedy(const eo_model *m, char *sel, double *alpha_used);
eo_i64 eo_greedy_refine(const eo_model *m, char *sel, int rounds);
/* the exact solver */
int  eo_solve(const eo_model *m, const eo_opts *o, eo_result *r);
/* brute force over all subsets of the useful candidates (only for tests: ncand <= 24) */
eo_i64 eo_brute(const eo_model *m, char *sel);

/* the prefix assignment */
typedef struct { int form; int k; int off; int j; int L; int nm; eo_i64 lo; unsigned prefix; } eo_leaf;
/* forms in the order given (indices into m->form); returns the number of leaves, or -1 (err) when Kraft's sum exceeds 1 or a prefix length is out of range */
int  eo_assign(const eo_model *m, const int *forms, int nf, eo_leaf **leaves, eo_i64 *used, char *err, size_t errlen);
#endif

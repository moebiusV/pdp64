/* ptrgrow.c: the cache-footprint cost of a pointer that is 16 bytes instead of 8, measured on the host (AMD Ryzen 5 7600, Linux, LP64).
   Only the SIZE is emulated: each pointer field is a 16-byte aligned slot whose low 8 bytes hold the address (so a loaded pointer is still one 8-byte load,
   and the capability's bounds/permission check, which would be free in the access on the real machine, is not modelled).  This isolates the effect the
   cost model attributes to memory growth.  Workloads: random lookups in a binary search tree, a shuffled linked list walk, chained hash lookups, and an
   array-of-indices control (no pointers: must not change).  Build: cc -O2 -DP=8 / -DP=16.  Output: ns per operation. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#if P == 16
#define PTR(T, n) struct { T *p; long pad; } __attribute__((aligned(16))) n
#define GET(x) ((x).p)
#else
#define PTR(T, n) struct { T *p; } n
#define GET(x) ((x).p)
#endif
struct tn { PTR(struct tn, l); PTR(struct tn, r); long key; long val; };
struct hn { PTR(struct hn, next); long key; long val; };
static uint64_t rs = 88172645463325252ULL; static inline uint64_t rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return rs; }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
static struct tn *build(long n, struct tn **pool) {
    struct tn *a = aligned_alloc(64, n * sizeof *a); long *keys = malloc(n * sizeof *keys);
    for (long i = 0; i < n; i++) keys[i] = i;
    for (long i = n - 1; i > 0; i--) { long j = rnd() % (i + 1), t = keys[i]; keys[i] = keys[j]; keys[j] = t; }
    struct tn *root = 0;
    for (long i = 0; i < n; i++) {       /* insert in random key order: a balanced-ish tree, nodes allocated in insertion order */
        struct tn *x = &a[i]; GET(x->l) = GET(x->r) = 0; x->key = keys[i]; x->val = i;
        struct tn **pp = &root; while (*pp) pp = keys[i] < (*pp)->key ? &GET((*pp)->l) : &GET((*pp)->r);
        *pp = x;
    }
    free(keys); *pool = a; return root;
}
int main(int argc, char **argv) {
    for (int lg = 10; lg <= 23; lg += 1) {
        long n = 1L << lg; long ops = 4000000; volatile long sink = 0; double t0, t1;
        struct tn *pool, *root = build(n, &pool);
        t0 = now(); long s = 0;
        for (long i = 0; i < ops; i++) { long k = rnd() % n; struct tn *x = root; while (x && x->key != k) x = k < x->key ? GET(x->l) : GET(x->r); s += x ? x->val : 0; }
        t1 = now(); sink = s; double tree = (t1 - t0) / ops * 1e9; free(pool);
        /* shuffled list */
        struct hn *h = aligned_alloc(64, n * sizeof *h); long *perm = malloc(n * sizeof *perm);
        for (long i = 0; i < n; i++) perm[i] = i;
        for (long i = n - 1; i > 0; i--) { long j = rnd() % (i + 1), t = perm[i]; perm[i] = perm[j]; perm[j] = t; }
        for (long i = 0; i < n; i++) { GET(h[perm[i]].next) = &h[perm[(i + 1) % n]]; h[perm[i]].key = i; h[perm[i]].val = i; }
        struct hn *p = &h[perm[0]]; t0 = now(); s = 0;
        for (long i = 0; i < ops; i++) { s += p->val; p = GET(p->next); }
        t1 = now(); sink = s + (long)p; double list = (t1 - t0) / ops * 1e9;
        /* chained hash table: n buckets (array of pointers), n nodes */
        typedef PTR(struct hn, bslot); bslot *b = aligned_alloc(64, n * sizeof(bslot)); void *bk = b; for (long i = 0; i < n; i++) GET(b[i]) = 0;
        for (long i = 0; i < n; i++) { long hh = (h[i].key * 0x9E3779B97F4A7C15ULL >> 20) % n; GET(h[i].next) = GET(b[hh]); GET(b[hh]) = &h[i]; }
        t0 = now(); s = 0;
        for (long i = 0; i < ops; i++) { long k = rnd() % n; long hh = (k * 0x9E3779B97F4A7C15ULL >> 20) % n; struct hn *q = GET(b[hh]); while (q && q->key != k) q = GET(q->next); s += q ? q->val : 0; }
        t1 = now(); sink = s; double hash = (t1 - t0) / ops * 1e9;
        /* control: array of 32-bit indices walked at random (no pointers) */
        int *ix = malloc(n * sizeof *ix); for (long i = 0; i < n; i++) ix[i] = (int)perm[i]; 
        long c = 0; t0 = now(); for (long i = 0; i < ops; i++) { c = ix[c]; } t1 = now(); sink = c; double ctl = (t1 - t0) / ops * 1e9;
        printf("P=%d n=2^%d node_bytes=%zu,%zu tree_ns=%.2f list_ns=%.2f hash_ns=%.2f control_ns=%.2f\n", P, lg, sizeof(struct tn), sizeof(struct hn), tree, list, hash, ctl);
        free(h); free(perm); free(bk); free(ix);
    }
    return 0;
}

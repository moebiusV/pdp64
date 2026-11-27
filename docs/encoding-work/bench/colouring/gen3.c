/* gen3.c TRACE [W]: how long a stale pointer stays caught with 3 colour bits against 4, in the slab MODEL of OpenBSD's malloc (the same model as slab.py: host glibc malloc traces of
 ../sizeclass/mtrace.c, x86-64: NOT an OpenBSD or pdp64 run; chunks of a multiple of 16 bytes up to 2048 in a 4096-byte page per bucket, the slot chosen at random among the free ones
 of the first page with room, a drained page is dropped; large requests are whole pages and take no colour; W = FIFO delay of W frees before a slot is free, default 0).  C instead of
 Python only for speed (xorshift random numbers: the slot choices differ from slab.py's, the distributions do not).
 Policies (colour ids; 0 = uncoloured and the freed colour are reserved apart):
   A6  parity x 6 generations (the 4-bit design of errata 240: 12 live colours used; generation = reuse count mod 6)
   A3  parity x 3 generations (the 3-bit design: 6 live colours)
   F14 free choice among 14 live colours (4 bits): not equal to either live neighbour slot, then the colour this slot used least recently
   F6  the same among 6 live colours (3 bits)
   E3  3-bit, generation rotated per slab PAGE: parity x (page epoch mod 3); a slot reused twice in one epoch bumps the epoch   (the 'middle option')
   E6  the same with 6 generations (4 bits)
 For every freed small chunk m it records the later occupants of its slot (up to D = 16 back) that get the colour m had: a stale pointer to m passes the check at that reuse.
 Output (one line per policy): frees, frees whose slot colour recurs within 16 reuses, histogram of the first-recurrence distance 1..16, neighbour violations, and the expected pass
 probability if the stale pointer is used after j reuses of its slot with j geometric of mean 0.5, 1, 2, 4 (assumed), plus chain counts: allocs with >=k earlier occupants.   */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#define D 16
#define NPOL 8
#define PG 4096
#define MAXC 2048
#define CAP 2500000L
static const char *pn[NPOL] = {"A6", "A3", "F14", "F6", "E3", "E6", "F14b", "F6b"};
static const int ncol[NPOL] = {12, 6, 14, 6, 6, 12, 14, 6};
static const int fpol[4] = {2, 3, 6, 7}, fbnd[4] = {0, 0, 1, 1};   /* F policies; the b ones keep the first slot of a page to the lower half of the colours and the last slot to the upper half, so that slab pages next to each other need no cross-page look */
static uint64_t rs = 88172645463325252ULL;
static uint64_t rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return rs; }
typedef struct { uint8_t hcol[NPOL][D]; uint16_t hfl[NPOL]; int32_t last[4][15]; } Extra;
typedef struct {
    int b, total, nfree, live; uint32_t epoch[2];
    uint8_t *freeb; uint32_t *used; uint8_t (*cur)[NPOL]; uint32_t (*lastep)[2]; Extra **ex;
} Page;
typedef struct { Page **pg; int np, cap; int *part[129]; int npart[129], cappart[129]; long *delay; long dh, dt, dcap; } Heap;
typedef struct { uint32_t pid; uint64_t ptr; uint32_t oid; } Ent;
typedef struct { uint8_t kind; int pg; int slot; } Obj;
static Ent *ht; static long HS = 1L << 22;
static Obj *objs; static long nobj = 0;
static Heap *heaps[1 << 16];
static long fs, chain_ge[17]; static long coll[NPOL], dist[NPOL][D + 1], viol[NPOL]; static double wsum[NPOL][4]; static const double QS[4] = {1.0/3, 0.5, 2.0/3, 0.8};
static long small_allocs, reuses, allocs, frees_all;
static long hfind(uint32_t pid, uint64_t ptr) { uint64_t h = (ptr * 0x9E3779B97F4A7C15ULL ^ pid * 0xC2B2AE3D27D4EB4FULL) >> 20; long i = h & (HS - 1);
    while (ht[i].oid) { if (ht[i].ptr == ptr && ht[i].pid == pid && ht[i].oid != 0xFFFFFFFFu) return i; i = (i + 1) & (HS - 1); } return -1; }
static void hput(uint32_t pid, uint64_t ptr, uint32_t oid) { uint64_t h = (ptr * 0x9E3779B97F4A7C15ULL ^ pid * 0xC2B2AE3D27D4EB4FULL) >> 20; long i = h & (HS - 1);
    while (ht[i].oid && ht[i].oid != 0xFFFFFFFFu) i = (i + 1) & (HS - 1); ht[i].pid = pid; ht[i].ptr = ptr; ht[i].oid = oid; }
static Heap *heap(uint32_t pid) { if (!heaps[pid & 0xFFFF]) heaps[pid & 0xFFFF] = calloc(1, sizeof(Heap)); return heaps[pid & 0xFFFF]; }
static void part_remove(Heap *h, int b, int pg) { for (int i = 0; i < h->npart[b]; i++) if (h->part[b][i] == pg) { memmove(&h->part[b][i], &h->part[b][i + 1], (h->npart[b] - i - 1) * sizeof(int)); h->npart[b]--; return; } }
static void part_push(Heap *h, int b, int pg) { if (h->npart[b] == h->cappart[b]) { h->cappart[b] = h->cappart[b] ? 2 * h->cappart[b] : 8; h->part[b] = realloc(h->part[b], h->cappart[b] * sizeof(int)); } h->part[b][h->npart[b]++] = pg; }
static void page_free(Page *p) { for (int s = 0; s < p->total; s++) free(p->ex[s]); free(p->ex); free(p->freeb); free(p->used); free(p->cur); free(p->lastep); free(p); }
static void release(Heap *h, long o) {
    Obj *ob = &objs[o]; if (ob->kind == 0) return;      /* large: nothing */
    Page *p = h->pg[ob->pg]; fs++; p->live--; p->freeb[ob->slot] = 1; p->nfree++;
    if (p->nfree == p->total) { part_remove(h, p->b, ob->pg); page_free(p); h->pg[ob->pg] = NULL; }
    else if (p->nfree == 1) part_push(h, p->b, ob->pg);
}
static int nb(Page *p, int s, int d, int pol) { int t = s + d; if (t < 0 || t >= p->total || p->freeb[t]) return 0; return p->cur[t][pol]; }
static void alloc_slot(Page *p, int s) {
    uint32_t u = p->used[s]; Extra *e = p->ex[s];
    if (u >= 1) {
        if (!e) { e = p->ex[s] = calloc(1, sizeof(Extra)); for (int f = 0; f < 4; f++) e->last[f][p->cur[s][fpol[f]]] = 1; }   /* the first occupant's colour, used at occupant 0 */
        for (int k = 1; k <= 16; k++) if (u >= (uint32_t)k) chain_ge[k]++;
    }
    int nc[NPOL];
    nc[0] = 1 + (s & 1) + 2 * (u % 6); nc[1] = 1 + (s & 1) + 2 * (u % 3);
    for (int f = 0; f < 4; f++) {                          /* free choice, F14 (pol 2), F6 (3), and the boundary-restricted F14b (6), F6b (7) */
        int pol = fpol[f], L = ncol[pol]; int a = nb(p, s, -1, pol), c = nb(p, s, +1, pol), best = 0; long bl = 1L << 40; int lo = 1, hi = L;
        if (fbnd[f] && s == 0) hi = L / 2; else if (fbnd[f] && s == p->total - 1) lo = L / 2 + 1;
        for (int col = lo; col <= hi; col++) { if (col == a || col == c) continue; long l = e ? e->last[f][col] : 0; if (l < bl) { bl = l; best = col; } }
        nc[pol] = best;
    }
    for (int g = 0; g < 2; g++) {                           /* epoch, E3 (pol 4) and E6 (pol 5) */
        int G = g ? 6 : 3; if (u && p->lastep[s][g] == p->epoch[g]) p->epoch[g]++;
        p->lastep[s][g] = p->epoch[g]; nc[4 + g] = 1 + (s & 1) + 2 * (p->epoch[g] % G);
    }
    for (int pol = 0; pol < NPOL; pol++) {
        if (nb(p, s, -1, pol) == nc[pol] || nb(p, s, +1, pol) == nc[pol]) viol[pol]++;
        if (u >= 1) {
            e->hcol[pol][(u - 1) % D] = p->cur[s][pol]; e->hfl[pol] &= ~(1u << ((u - 1) % D));       /* the previous occupant joins the history */
            for (int j = 1; j <= D && (uint32_t)j <= u; j++) {
                int m = u - j;
                if (e->hcol[pol][m % D] == nc[pol]) {
                    double q;
                    for (int k = 0; k < 4; k++) { q = QS[k]; double w = (1 - q); for (int i = 0; i < j; i++) w *= q; wsum[pol][k] += w; }
                    if (!(e->hfl[pol] & (1u << (m % D)))) { e->hfl[pol] |= 1u << (m % D); coll[pol]++; dist[pol][j]++; }
                }
            }
        }
        p->cur[s][pol] = nc[pol];
        for (int f = 0; f < 4; f++) if (fpol[f] == pol && e) e->last[f][nc[pol]] = u + 1;

    }
    if (u >= 1) reuses++;
    p->used[s]++;
}
int main(int argc, char **argv) {
    long W = argc > 2 ? atol(argv[2]) : 0;
    FILE *f = fopen(argv[1], "rb"); if (!f) return 1;
    ht = calloc(HS, sizeof(Ent)); objs = malloc(CAP * sizeof(Obj) + 1024); long cnt = 0; nobj = 0;
    struct { uint32_t op, pid; uint64_t size, ptr; } r;
    while (cnt < CAP && fread(&r, 24, 1, f) == 1) {
        cnt++; Heap *h = heap(r.pid);
        if (r.op == 1) {
            long i = hfind(r.pid, r.ptr); if (i >= 0) { release(h, ht[i].oid); ht[i].oid = 0xFFFFFFFFu; }
            allocs++; uint64_t sz = r.size ? r.size : 1; long need = sz; Obj *ob = &objs[++nobj];
            if (need <= MAXC) {
                int b = (need + 15) / 16, nslots = PG / (b * 16); small_allocs++;
                if (!h->npart[b]) {
                    if (h->np == h->cap) { h->cap = h->cap ? 2 * h->cap : 64; h->pg = realloc(h->pg, h->cap * sizeof(Page *)); }
                    Page *p = calloc(1, sizeof(Page)); p->b = b; p->total = p->nfree = nslots; p->freeb = malloc(nslots); memset(p->freeb, 1, nslots);
                    p->used = calloc(nslots, 4); p->cur = calloc(nslots, NPOL); p->lastep = calloc(nslots, 8); p->ex = calloc(nslots, sizeof(Extra *));
                    h->pg[h->np] = p; part_push(h, b, h->np); h->np++;
                }
                int pgi = h->part[b][0]; Page *p = h->pg[pgi]; int k = (int)(rnd() % p->nfree), slot = -1;
                for (int s = 0; s < p->total; s++) if (p->freeb[s] && k-- == 0) { slot = s; break; }
                p->freeb[slot] = 0; p->nfree--; p->live++; if (p->nfree == 0) part_remove(h, b, pgi);
                alloc_slot(p, slot); ob->kind = 1; ob->pg = pgi; ob->slot = slot;
            } else ob->kind = 0;
            hput(r.pid, r.ptr, (uint32_t)nobj);
        } else if (r.op == 2) {
            long i = hfind(r.pid, r.ptr); if (i < 0) continue; long o = ht[i].oid; ht[i].oid = 0xFFFFFFFFu; frees_all++;
            if (W == 0) release(h, o);
            else {
                if (!h->delay) { h->dcap = W + 2; h->delay = malloc(h->dcap * sizeof(long)); }
                h->delay[h->dt++ % h->dcap] = o;
                if (h->dt - h->dh > W) release(h, h->delay[h->dh++ % h->dcap]);
            }
        }
    }
    printf("allocs %ld small %ld reuses %ld small-frees %ld W=%ld\n", allocs, small_allocs, reuses, fs, W);
    printf("chain_ge");  for (int k = 1; k <= 8; k++) printf(" %d:%ld", k, chain_ge[k]); printf("\n");
    for (int pol = 0; pol < NPOL; pol++) {
        printf("pol %s frees %ld recur %ld viol %ld first-recurrence-distance", pn[pol], fs, coll[pol], viol[pol]); for (int j = 1; j <= D; j++) printf(" %ld", dist[pol][j]); printf(" w");
        for (int k = 0; k < 4; k++) printf(" %.6f", wsum[pol][k]); printf("\n");
    }
    return 0;
}

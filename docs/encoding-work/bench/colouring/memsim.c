/* memsim.c: a MODEL of colour-tag traffic, fed by the memory accesses of a program compiled with clang -fsanitize=thread -c (so that every load and store of a
 * variable that is not in a register calls __tsan_readN / __tsan_writeN), linked with this file instead of the tsan runtime.  It also interposes malloc/free.
 * It is NOT a pdp64 run: host x86-64 LP64, glibc malloc, the program's own accesses only (libc's internal accesses are not seen).  Output on stderr at exit.
 * Model (all assumed, labelled in the note): data cache = one unified LLC of MS_LLC_KB (default 256 and 1024: two models at once), 8-way, 64-byte lines, LRU, write-back;
 * the 4-bit colours ride in the data cache lines (16 bits per 64-byte line), the TAG CACHE backs them: 32-byte lines, each covering 1 KB of data, 4-way LRU, sizes 4..64 KB;
 * a tag-cache read happens when a coloured line is FILLED into the data cache; a colour write (the allocator, at malloc and at free) is a write to the tag cache (dirty, written
 * back on eviction), and does not fetch data.  Also the pessimistic reading: the tag cache consulted on EVERY coloured access.
 * Coloured = heap (pages that malloc ever handed out) in the HEAP model; heap + stack + globals (everything) in the ALL model.
 * build: clang -O2 -fsanitize=thread -c prog.c ; cc -O2 -shared -fPIC -o libmemsim.so memsim.c -ldl ; clang prog.o -L. -lmemsim -Wl,-rpath,. -o prog */
#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
extern void *__libc_malloc(size_t), *__libc_calloc(size_t, size_t), *__libc_realloc(void *, size_t), *__libc_memalign(size_t, size_t);
extern void __libc_free(void *);
typedef uint64_t u64;
typedef struct { int sets, ways; u64 *tag; unsigned char *dirty, *valid; u64 *lru; u64 clk; u64 acc, miss, wb; int lbits; } cache_t;
static void cinit(cache_t *c, long bytes, int ways, int lbits) {
  c->lbits = lbits; c->ways = ways; c->sets = bytes / ((1 << lbits) * ways); if (c->sets < 1) c->sets = 1;
  long n = (long)c->sets * ways; c->tag = __libc_calloc(n, 8); c->dirty = __libc_calloc(n, 1); c->valid = __libc_calloc(n, 1); c->lru = __libc_calloc(n, 8); c->clk = 1;
}
/* returns 1 on hit; on a miss fills; *evict_dirty set if a dirty line was evicted */
static int cacc(cache_t *c, u64 addr, int wr, int *evd) {
  u64 line = addr >> c->lbits; int set = line % c->sets; long b = (long)set * c->ways; int i, v = 0; u64 old = ~0ull;
  c->acc++; c->clk++; if (evd) *evd = 0;
  for (i = 0; i < c->ways; i++) if (c->valid[b + i] && c->tag[b + i] == line) { c->lru[b + i] = c->clk; if (wr) c->dirty[b + i] = 1; return 1; }
  c->miss++;
  for (i = 0; i < c->ways; i++) { if (!c->valid[b + i]) { v = i; old = 0; break; } if (c->lru[b + i] < c->lru[b + v]) v = i; }
  if (old == ~0ull || c->valid[b + v]) { if (c->valid[b + v] && c->dirty[b + v]) { c->wb++; if (evd) *evd = 1; } }
  c->valid[b + v] = 1; c->tag[b + v] = line; c->dirty[b + v] = wr; c->lru[b + v] = c->clk; return 0;
}
#define NLLC 2
#define NTC 5
static const int llc_kb[NLLC] = {256, 1024}, tc_kb[NTC] = {4, 8, 16, 32, 64};
typedef struct { cache_t llc; cache_t tc[NTC]; u64 tc_fill_reads[NTC]; u64 data_dram; } model_t;
static model_t M[2][NLLC];           /* [0]=HEAP coloured, [1]=ALL coloured */
static cache_t PER[2][NTC];          /* tag cache consulted on every coloured access */
static u64 nacc, nheap, nstack, nother, nwr, ncolw_gran, ncolw_lines, ncolw_ops, nmalloc, nfree, nfunc, ncallstk, ncallany;
static u64 coloured_bytes_live, coloured_bytes_peak;
static int inited, stack_flag_depth;
static unsigned char *l1[1 << 18];  /* heap-page bitmap, 2 levels: addr>>30 -> 2^18 bits */
static u64 stack_lo, stack_hi;
static unsigned char sflag[1 << 20]; static int sdepth;
static void init(void) {
  int k, j; inited = 1;
  for (k = 0; k < 2; k++) for (j = 0; j < NLLC; j++) { cinit(&M[k][j].llc, llc_kb[j] * 1024L, 8, 6); for (int t = 0; t < NTC; t++) cinit(&M[k][j].tc[t], tc_kb[t] * 1024L, 4, 5); }
  for (k = 0; k < 2; k++) for (int t = 0; t < NTC; t++) cinit(&PER[k][t], tc_kb[t] * 1024L, 4, 5);
  extern void __memsim_atexit(void); atexit(__memsim_atexit);
}
static void markheap(u64 a, u64 n) {
  for (u64 p = a >> 12; p <= (a + n - 1) >> 12; p++) { u64 hi = p >> 18, lo = p & ((1 << 18) - 1); if (hi >= (1 << 18)) return;
    if (!l1[hi]) l1[hi] = __libc_calloc(1 << 15, 1); l1[hi][lo >> 3] |= 1 << (lo & 7); }
}
static int isheap(u64 a) { u64 p = a >> 12, hi = p >> 18, lo = p & ((1 << 18) - 1); return hi < (1 << 18) && l1[hi] && (l1[hi][lo >> 3] >> (lo & 7) & 1); }
static void tagacc_line(model_t *m, u64 dataaddr, int wr_tag, int model) {
  for (int t = 0; t < NTC; t++) { int e; if (!cacc(&m->tc[t], dataaddr >> 10 << 5, wr_tag, &e)) m->tc_fill_reads[t]++; }
}
static void memacc(u64 a, int sz, int wr) {
  if (!inited) init();
  nacc++; nwr += wr;
  int heap = isheap(a), stk = 0;
  if (!heap) { int x; u64 sp = (u64)&x; if (a >= sp - 128 && a < sp + (1ull << 24)) stk = 1; }
  if (heap) nheap++; else if (stk) nstack++; else nother++;
  if (stk && sdepth > 0) sflag[sdepth - 1] = 1;
  for (u64 l = a >> 6; l <= (a + sz - 1) >> 6; l++) {
    u64 la = l << 6;
    for (int k = 0; k < 2; k++) {
      int col = k == 0 ? heap : 1;
      if (col) for (int t = 0; t < NTC; t++) cacc(&PER[k][t], la >> 10 << 5, 0, 0);
      for (int j = 0; j < NLLC; j++) {
        model_t *m = &M[k][j]; int e;
        if (!cacc(&m->llc, la, wr, &e)) { m->data_dram++; if (col) tagacc_line(m, la, 0, k); }
        if (e) m->data_dram++;
      }
    }
  }
}
static void colour_write(u64 a, u64 n) {          /* the allocator sets the colours of [a, a+n): one write to the tag cache per 1 KB chunk */
  if (!inited) init();
  ncolw_ops++; ncolw_gran += (n + 15) / 16; ncolw_lines += ((a + n - 1) >> 6) - (a >> 6) + 1;
  for (u64 c = a >> 10; c <= (a + (n ? n : 1) - 1) >> 10; c++) for (int k = 0; k < 2; k++) for (int j = 0; j < NLLC; j++) {
    model_t *m = &M[k][j]; for (int t = 0; t < NTC; t++) { int e; if (!cacc(&m->tc[t], c << 5, 1, &e)) m->tc_fill_reads[t]++; } }
}
void __tsan_init(void) {}
void __tsan_func_entry(void *pc) { nfunc++; if (sdepth < (1 << 20)) sflag[sdepth] = 0; sdepth++; }
void __tsan_func_exit(void) { if (sdepth > 0) { sdepth--; if (sdepth < (1 << 20) && sflag[sdepth]) ncallstk++; } }
#define RW(n) void __tsan_read##n(void *a) { memacc((u64)a, n, 0); } void __tsan_write##n(void *a) { memacc((u64)a, n, 1); } \
  void __tsan_unaligned_read##n(void *a) { memacc((u64)a, n, 0); } void __tsan_unaligned_write##n(void *a) { memacc((u64)a, n, 1); }
RW(1) RW(2) RW(4) RW(8) RW(16)
void __tsan_read_range(void *a, unsigned long n) { for (u64 p = (u64)a; p < (u64)a + n; p += 16) memacc(p, 16, 0); }
void __tsan_write_range(void *a, unsigned long n) { for (u64 p = (u64)a; p < (u64)a + n; p += 16) memacc(p, 16, 1); }
void *__tsan_memcpy(void *d, const void *s, size_t n) { __tsan_read_range((void *)s, n); __tsan_write_range(d, n); return memcpy(d, s, n); }
void *__tsan_memmove(void *d, const void *s, size_t n) { __tsan_read_range((void *)s, n); __tsan_write_range(d, n); return memmove(d, s, n); }
void *__tsan_memset(void *d, int c, size_t n) { __tsan_write_range(d, n); return memset(d, c, n); }
void __tsan_vptr_update(void **a, void *b) {} void __tsan_vptr_read(void **a) {}
void __tsan_atomic_signal_fence(int o) {} void __tsan_atomic_thread_fence(int o) {}
static void got(void *p, size_t n) { if (!p) return; nmalloc++; markheap((u64)p, n ? n : 1); colour_write((u64)p, n ? n : 1); coloured_bytes_live += n; if (coloured_bytes_live > coloured_bytes_peak) coloured_bytes_peak = coloured_bytes_live; }
static size_t usz[1]; 
#include <malloc.h>
static void gave(void *p) { if (!p) return; nfree++; size_t n = malloc_usable_size(p); colour_write((u64)p, n); if (coloured_bytes_live >= n) coloured_bytes_live -= n; }
void *malloc(size_t n) { void *p = __libc_malloc(n); got(p, malloc_usable_size(p) ? n : n); return p; }
void *calloc(size_t a, size_t b) { void *p = __libc_calloc(a, b); got(p, a * b); if (p) __tsan_write_range(p, a * b); return p; }
void free(void *p) { if (p) gave(p); __libc_free(p); }
void *realloc(void *o, size_t n) { if (o) gave(o); void *p = __libc_realloc(o, n); got(p, n); return p; }
void *memalign(size_t al, size_t n) { void *p = __libc_memalign(al, n); got(p, n); return p; }
int posix_memalign(void **r, size_t al, size_t n) { void *p = __libc_memalign(al, n); if (!p) return 12; *r = p; got(p, n); return 0; }
void __memsim_atexit(void) {
  FILE *f = stderr; const char *nm[2] = {"HEAP", "ALL"};
  fprintf(f, "MEMSIM accesses %llu (writes %llu): heap %llu stack %llu other %llu; calls %llu, calls touching a stack-resident object %llu (%.1f%%)\n", (unsigned long long)nacc, (unsigned long long)nwr,
          (unsigned long long)nheap, (unsigned long long)nstack, (unsigned long long)nother, (unsigned long long)nfunc, (unsigned long long)ncallstk, nfunc ? 100.0 * ncallstk / nfunc : 0.0);
  fprintf(f, "MEMSIM allocator: malloc-class calls %llu, frees %llu; colour writes: %llu granules (16 B), %llu 64-byte lines, %llu block operations; peak live requested bytes %llu\n",
          (unsigned long long)nmalloc, (unsigned long long)nfree, (unsigned long long)ncolw_gran, (unsigned long long)ncolw_lines, (unsigned long long)ncolw_ops, (unsigned long long)coloured_bytes_peak);
  for (int k = 0; k < 2; k++) {
    for (int t = 0; t < NTC; t++) fprintf(f, "MEMSIM %s per-access tag cache %d KB: lookups %llu hit rate %.4f\n", nm[k], tc_kb[t], (unsigned long long)PER[k][t].acc, 1.0 - (double)PER[k][t].miss / (PER[k][t].acc ? PER[k][t].acc : 1));
    for (int j = 0; j < NLLC; j++) { model_t *m = &M[k][j];
      fprintf(f, "MEMSIM %s LLC %d KB: accesses %llu misses %llu (%.4f) dram data lines %llu (%.1f KB)\n", nm[k], llc_kb[j], (unsigned long long)m->llc.acc, (unsigned long long)m->llc.miss, (double)m->llc.miss / (m->llc.acc ? m->llc.acc : 1), (unsigned long long)m->data_dram, m->data_dram * 64 / 1024.0);
      for (int t = 0; t < NTC; t++) { double tb = (m->tc_fill_reads[t] + m->tc[t].wb) * 32.0, db = m->data_dram * 64.0;
        fprintf(f, "MEMSIM %s LLC %d KB tagcache %d KB: tag reads %llu tag writebacks %llu extra tag bytes %.0f over data bytes %.0f = %.4f\n", nm[k], llc_kb[j], tc_kb[t], (unsigned long long)m->tc_fill_reads[t], (unsigned long long)m->tc[t].wb, tb, db, db ? tb / db : 0.0); } }
  }
}

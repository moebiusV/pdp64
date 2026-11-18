/* expect: 2874  vec: 3  lv: 3  flags: -ffast-math -ffp-contract=fast */
/* what LoopVectorize's run-time overlap test must send to the scalar loop, and what it must not: arrays that overlap by one element in either direction (a forward and a backward dependence
   through memory: the strip semantics would read stale or new data), exactly adjacent arrays (no overlap), the same array (in place), a loop-carried dependence that LoopVectorize itself refuses
   (a[i+1] = a[i] + 1), and a dependence at distance 4 (safe for a vector of 4, not for a strip of 8). */
int a[400], b[400];
short h[400];
__attribute__((noinline)) void k_add(int *d, const int *s, int n) { for (int i = 0; i < n; i++) d[i] = s[i] + 3; }
__attribute__((noinline)) void k_scale(int *d, const int *s, int n) { for (int i = 0; i < n; i++) d[i] = s[i] * 2 - d[i]; }
__attribute__((noinline)) void k_carry(int *a, int n) { for (int i = 0; i < n; i++) a[i + 1] = a[i] + 1; }
__attribute__((noinline)) void k_dist4(int *a, int n) { for (int i = 0; i < n; i++) a[i + 4] = a[i] + 5; }
__attribute__((noinline)) void k_ahead(short *a, int n) { for (int i = 0; i < n; i++) a[i] = a[i + 1] + 1; }
int test(void)
{
    static const int ns[] = { 0, 1, 5, 8, 9, 31, 64, 100 };
    long sum = 0;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 400; i++) { a[i] = i * 3 - 100; b[i] = 1000 - i * 7; h[i] = (short)(i * 5); }
        k_add(a + 1, a, n);                 /* d = s + 1: backward-dependent (each element reads what the last iteration wrote) */
        for (int i = 0; i < 400; i++) sum += a[i] * (i % 5 + 1);
        for (int i = 0; i < 400; i++) a[i] = i * 3 - 100;
        k_add(a, a + 1, n);                 /* d = s - 1: forward */
        for (int i = 0; i < 400; i++) sum += a[i] * (i % 7 + 1);
        for (int i = 0; i < 400; i++) a[i] = i * 3 - 100;
        k_add(b, a + 100, n);               /* disjoint */
        k_add(b + 200, b + 200 - n, n);     /* adjacent, no overlap */
        for (int i = 0; i < 400; i++) sum += b[i] * (i % 3 + 1);
        k_scale(a, a, n);                   /* in place */
        for (int i = 0; i < 400; i++) sum += a[i] * (i % 9 + 1);
        for (int i = 0; i < 400; i++) a[i] = i * 3 - 100;
        k_carry(a, n);
        for (int i = 0; i < 400; i++) sum += a[i] * (i % 11 + 1);
        for (int i = 0; i < 400; i++) a[i] = i * 3 - 100;
        k_dist4(a, n);
        for (int i = 0; i < 400; i++) sum += a[i] * (i % 13 + 1);
        k_ahead(h, n);
        for (int i = 0; i < 400; i++) sum += h[i] * (i % 17 + 1);
    }
    return (int)(sum % 100003);
}

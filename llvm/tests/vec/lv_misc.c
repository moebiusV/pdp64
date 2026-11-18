/* expect: 42221  vec: 7  lv: 6  flags: -ffast-math -ffp-contract=fast */
/* LoopVectorize's output for: a rotate by a constant (fshl: vshl, vshr, vor), a float widened to a double and a double narrowed to a float (vld.f.d, vst.d.f), a read ahead in the same
   array (a[i] = a[i + 1] + 1: a write-after-read dependence that the strip order keeps), a loop that must NOT be a block (a prefix sum: LoopVectorize refuses it), and a fill of a 2-D array
   (a block for each row).  Trip counts 0, 1 and not multiples of the strip. */
unsigned r32[300];
float fs[300];
double dd[300];
short sa[300];
int ia[300];
unsigned char grid[40][40];
__attribute__((noinline)) void k_rotl(unsigned *c, const unsigned *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] << 7) | (a[i] >> 25); }
__attribute__((noinline)) void k_rotr(unsigned *c, const unsigned *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] >> 11) | (a[i] << 21); }
__attribute__((noinline)) void k_widen(double *d, const float *f, int n) { for (int i = 0; i < n; i++) d[i] = (double)f[i] * 2.0; }
__attribute__((noinline)) void k_narrow(float *f, const double *d, int n) { for (int i = 0; i < n; i++) f[i] = (float)(d[i] + 0.5); }
__attribute__((noinline)) void k_ahead(short *a, int n) { for (int i = 0; i < n; i++) a[i] = a[i + 1] + 1; }
__attribute__((noinline)) void k_prefix(int *a, int n) { for (int i = 1; i < n; i++) a[i] += a[i - 1]; }
__attribute__((noinline)) void k_grid(unsigned char (*g)[40], int rows, int cols, int v) { for (int y = 0; y < rows; y++) for (int x = 0; x < cols; x++) g[y][x] = (unsigned char)(v + y); }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 5, 8, 9, 31, 32, 33, 100 };
    long sum = 0;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { r32[i] = (unsigned)i * 2654435761u + 12345u; fs[i] = (float)(i % 37) * 0.25f - 3.0f; dd[i] = (double)(i % 41) * 0.125 - 2.0; sa[i] = (short)(i * 7 - 300); ia[i] = i % 13 - 6; }
        k_rotl(r32 + 1, r32, n);  for (int i = 0; i < 300; i++) sum += (r32[i] >> 3) % 1009 + (i % 5);
        k_rotr(r32, r32 + 100, n); for (int i = 0; i < 300; i++) sum += (r32[i] >> 5) % 997;
        k_widen(dd + 1, fs, n);   for (int i = 0; i < 300; i++) sum += (long)(dd[i] * 8.0) * (i % 3 + 1);
        k_narrow(fs + 1, dd, n);  for (int i = 0; i < 300; i++) sum += (long)(fs[i] * 8.0f) * (i % 5 + 1);
        k_ahead(sa, n);           for (int i = 0; i < 300; i++) sum += sa[i] * (i % 7 + 1);
        k_prefix(ia, n);          for (int i = 0; i < 300; i++) sum += ia[i] * (i % 9 + 1);
        for (int y = 0; y < 40; y++) for (int x = 0; x < 40; x++) grid[y][x] = 3;
        k_grid(grid, n > 40 ? 40 : n, n > 40 ? 40 : n, 17 + k);
        for (int y = 0; y < 40; y++) for (int x = 0; x < 40; x++) sum += grid[y][x] * (x + y % 4 + 1);
    }
    return (int)(sum % 100003);
}

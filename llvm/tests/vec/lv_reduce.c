/* expect: 30096  vec: 7  lv: 7  flags: -ffast-math -ffp-contract=fast */
/* reductions that LoopVectorize makes and PDP64VecLoop turns into vacc / vmaxacc / vminacc: an unsigned byte sum (vacc.bu.l from byte lanes), a halfword sum into 32 bits, a signed
   maximum, an unsigned minimum of bytes (vminacc.bu), a float maximum (vmaxacc.f: fmax with nnan) with a start value, a float sum and an i16 x i16 dot product.  Trip counts 0, 1, not
   multiples of any strip (8, 16 and 32 lanes), and a start offset of 1 so the data is not aligned to the strip. */
unsigned char ub[300];
short sh[300], sh2[300];
int iv[300];
float fv[300];
__attribute__((noinline)) unsigned k_usum(const unsigned char *a, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }
__attribute__((noinline)) int k_ssum(const short *a, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }
__attribute__((noinline)) int k_imax(const int *a, int n, int m) { for (int i = 0; i < n; i++) m = a[i] > m ? a[i] : m; return m; }
__attribute__((noinline)) unsigned char k_umin(const unsigned char *a, int n) { unsigned char m = 255; for (int i = 0; i < n; i++) m = a[i] < m ? a[i] : m; return m; }
__attribute__((noinline)) float k_fsum(const float *a, int n) { float s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }
__attribute__((noinline)) float k_fmax(const float *a, int n, float m) { for (int i = 0; i < n; i++) m = __builtin_fmaxf(m, a[i]); return m; }
__attribute__((noinline)) int k_dot16(const short *a, const short *b, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 100, 257 };
    long sum = 0;
    for (int i = 0; i < 300; i++) {
        ub[i] = (unsigned char)(i * 37 + 11); sh[i] = (short)(i * 131 - 20000); sh2[i] = (short)(9000 - i * 71);
        iv[i] = (i * 7919) % 1009 - 400; fv[i] = (float)((i * 29) % 211 - 100) * 0.5f;
    }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        sum += k_usum(ub + 1, n) + k_ssum(sh + 1, n) + k_imax(iv + 1, n, -1000) + k_umin(ub + 1, n);
        sum += (long)k_fsum(fv + 1, n) + (long)k_fmax(fv + 1, n, -50.0f) + k_dot16(sh + 1, sh2, n);
        sum += k_imax(iv, n, 100000);   /* the start value is the maximum: nothing replaces it */
    }
    return (int)(sum % 100003);
}

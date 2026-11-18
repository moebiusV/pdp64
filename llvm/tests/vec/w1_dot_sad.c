/* expect: 31167  vec: 9  lv: 9  words: vdacc.b vdacc.bu vdacc.bsu vdacc.w vsad.bu  flags: */
/* Wave 1 reductions straight into a scalar register: the dot products of bytes (vdacc.b signed by signed, .bu unsigned by unsigned, .bsu signed by unsigned) and of halfwords
   (vdacc.w), and the sum of absolute differences of bytes (vsad.bu).  The sums are exact in 64 bits and cut to the accumulator: the 32-bit sums wrap as the C sums do (unsigned
   accumulators, so that the wrap is defined).  A 64-bit accumulator over halfwords too.  Trip counts 0, 1 and not multiples of the strip (32 bytes, 16 halfwords). */
unsigned char ua[600], ub[600];
signed char sa8[600], sb8[600];
short sa[600], sb[600];
__attribute__((noinline)) unsigned k_dot8(const signed char *a, const signed char *b, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
__attribute__((noinline)) unsigned k_dot8u(const unsigned char *a, const unsigned char *b, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
__attribute__((noinline)) unsigned k_dot8su(const signed char *a, const unsigned char *b, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
__attribute__((noinline)) unsigned k_dot16(const short *a, const short *b, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
__attribute__((noinline)) long k_dot16l(const short *a, const short *b, int n) { long s = 0; for (int i = 0; i < n; i++) s += (long)a[i] * b[i]; return s; }
__attribute__((noinline)) int k_dot8i(const signed char *a, const signed char *b, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
__attribute__((noinline)) unsigned k_sad(const unsigned char *a, const unsigned char *b, int n) { unsigned s = 0; for (int i = 0; i < n; i++) { int d = a[i] - b[i]; s += d < 0 ? -d : d; } return s; }
__attribute__((noinline)) unsigned k_sad2(const unsigned char *a, const unsigned char *b, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += __builtin_abs(a[i] - b[i]); return s; }
static unsigned lcg = 99u;
static unsigned rnd(void) { lcg = lcg * 1103515245u + 12345u; return lcg >> 8; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 100, 255, 500 };
    unsigned long sum = 0;
    for (int i = 0; i < 600; i++) {
        unsigned r = rnd();
        ua[i] = (i % 5 == 0) ? 255 : (i % 7 == 0) ? 0 : (unsigned char)r;
        ub[i] = (i % 3 == 0) ? 255 : (i % 11 == 0) ? 0 : (unsigned char)(r >> 7);
        sa8[i] = (i % 5 == 0) ? -128 : (i % 7 == 0) ? 127 : (signed char)r;
        sb8[i] = (i % 3 == 0) ? -128 : (i % 11 == 0) ? 127 : (signed char)(r >> 7);
        sa[i] = (i % 5 == 0) ? -32768 : (i % 7 == 0) ? 32767 : (short)r;
        sb[i] = (i % 3 == 0) ? -32768 : (i % 11 == 0) ? 32767 : (short)(r >> 3);
    }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        sum = sum * 3 + k_dot8(sa8 + 1, sb8 + 2, n);
        sum = sum * 3 + k_dot8u(ua + 1, ub + 2, n);
        sum = sum * 3 + k_dot8su(sa8 + 1, ub + 2, n);
        sum = sum * 3 + k_dot16(sa + 1, sb + 2, n);
        sum = sum * 3 + (unsigned long)k_dot16l(sa + 1, sb + 2, n);
        sum = sum * 3 + (unsigned)k_dot8i(sa8, sb8, n);
        sum = sum * 3 + k_sad(ua + 1, ub + 2, n);
        sum = sum * 3 + k_sad2(ub, ua + 3, n);
    }
    /* -128 x -128, -32768 x -32768 repeated: the largest sums */
    for (int i = 0; i < 600; i++) { sa8[i] = -128; sb8[i] = -128; sa[i] = -32768; sb[i] = -32768; ua[i] = 255; ub[i] = 0; }
    sum = sum * 3 + k_dot8(sa8, sb8, 600) + k_dot16(sa, sb, 600) + (unsigned long)k_dot16l(sa, sb, 600) + k_sad(ua, ub, 600);
    return (int)(sum % 100003);
}

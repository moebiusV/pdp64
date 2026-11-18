/* expect: 90929  vec: 37  lv: 37  words: vcgt.l vcgtu.l vceq.l vcgt.b vcgtu.b vcgt.w vcgtu.w vceq.b vbsl  lvwords:  flags: */
/* Wave 2, integer: x ? a : b from a compare (vceq / vcgt / vcgtu make a mask of integer lanes, vbsl takes the bits of the first arm where the mask is 1).  All the signed and
   unsigned predicates on 8, 16 and 32-bit lanes with a scalar, a constant and a vector as the other operand (the predicates the word lacks are the negation of one it has: the
   arms are swapped, or the operands), a compare used as a value (a 0/1 byte, a sum of the mask), a masked sum, an immediate that is not the lane's sign extension (vcgtu.b #254).
   Trip counts 0, 1 and not multiples of the strip. */
int ia[300], ib[300], ic[300], ox[300], oy[300];
unsigned ua[300], ub[300], uc[300];
short sa[300], sb[300], so[300];
unsigned short ha[300], hb[300], ho[300];
signed char ca[300], cb[300], co[300];
unsigned char ba[300], bb[300], bo[300];
#define N __attribute__((noinline))
N void s_gt(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 100 : 7; }
N void s_ge(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] >= t ? 100 : 7; }
N void s_lt(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < t ? 100 : 7; }
N void s_le(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] <= t ? 100 : 7; }
N void s_eq(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] == t ? 100 : 7; }
N void s_ne(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] != t ? 100 : 7; }
N void s_gtk(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > 5 ? -1 : 1000; }
N void s_ltk(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < -3 ? 31 : 32; }
N void s_vec(int *c, const int *a, const int *b, const int *x, const int *y, int n) { for (int i = 0; i < n; i++) { int xv = x[i], yv = y[i]; c[i] = a[i] > b[i] ? xv + 1 : yv * 3; } }
N void s_vlt(int *c, const int *a, const int *b, const int *x, const int *y, int n) { for (int i = 0; i < n; i++) { int xv = x[i], yv = y[i]; c[i] = a[i] < b[i] ? xv + 1 : yv * 3; } }
N void s_vle(int *c, const int *a, const int *b, const int *x, const int *y, int n) { for (int i = 0; i < n; i++) { int xv = x[i], yv = y[i]; c[i] = a[i] <= b[i] ? xv + 1 : yv * 3; } }
N void s_vne(int *c, const int *a, const int *b, const int *x, const int *y, int n) { for (int i = 0; i < n; i++) { int xv = x[i], yv = y[i]; c[i] = a[i] != b[i] ? xv + 1 : yv * 3; } }
N void u_gt(unsigned *c, const unsigned *a, unsigned t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 100u : 7u; }
N void u_ge(unsigned *c, const unsigned *a, unsigned t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] >= t ? 100u : 7u; }
N void u_lt(unsigned *c, const unsigned *a, unsigned t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < t ? 100u : 7u; }
N void u_le(unsigned *c, const unsigned *a, unsigned t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] <= t ? 100u : 7u; }
N void u_vec(unsigned *c, const unsigned *a, const unsigned *b, const unsigned *x, const unsigned *y, int n) { for (int i = 0; i < n; i++) { unsigned xv = x[i], yv = y[i]; c[i] = a[i] > b[i] ? xv + 1 : yv * 3; } }
N void u_vlt(unsigned *c, const unsigned *a, const unsigned *b, const unsigned *x, const unsigned *y, int n) { for (int i = 0; i < n; i++) { unsigned xv = x[i], yv = y[i]; c[i] = a[i] < b[i] ? xv + 1 : yv * 3; } }
N void h_gt(short *c, const short *a, short t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 1000 : -7; }
N void h_lt(short *c, const short *a, short t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < t ? 1000 : -7; }
N void h_vec(short *c, const short *a, const short *b, const short *x, const short *y, int n) { for (int i = 0; i < n; i++) { int xv = x[i], yv = y[i]; c[i] = a[i] > b[i] ? xv + 1 : yv * 3; } }
N void hu_gt(unsigned short *c, const unsigned short *a, unsigned short t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 1000 : 7; }
N void hu_ule(unsigned short *c, const unsigned short *a, const unsigned short *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] <= b[i] ? 1000 : 7; }
N void b_gt(signed char *c, const signed char *a, signed char t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 100 : -7; }
N void b_eq(signed char *c, const signed char *a, const signed char *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] == b[i] ? 100 : -7; }
N void bu_gt(unsigned char *c, const unsigned char *a, unsigned char t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 200 : 7; }
N void bu_254(unsigned char *c, const unsigned char *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > 254 ? 1 : 2; }
N void bu_lt(unsigned char *c, const unsigned char *a, const unsigned char *b, const unsigned char *x, const unsigned char *y, int n) { for (int i = 0; i < n; i++) { int xv = x[i], yv = y[i]; c[i] = a[i] < b[i] ? xv + 1 : yv * 3; } }
N void h_sel(short *c, const short *x, const short *a, const short *b, int t, int n) { for (int i = 0; i < n; i++) { short va = a[i], vb = b[i]; c[i] = x[i] > t ? va : vb; } }
N void b_sel(unsigned char *c, const unsigned char *x, const unsigned char *a, const unsigned char *b, int t, int n) { for (int i = 0; i < n; i++) { unsigned char va = a[i], vb = b[i]; c[i] = x[i] > t ? va : vb; } }
N void v_cmp8(unsigned char *c, const int *a, const int *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < b[i]; }
N int v_count(const int *a, int t, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] > t; return s; }
N int v_masked(const int *a, int t, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] > t ? a[i] : 0; return s; }
N void v_and(int *c, const int *a, const int *b, int t, int n) { for (int i = 0; i < n; i++) c[i] = ((a[i] > t) & (b[i] < t)) ? 1 : 0; }
N void v_or(int *c, const int *a, const int *b, int t, int n) { for (int i = 0; i < n; i++) c[i] = ((a[i] > t) | (b[i] < -t)) ? 11 : 22; }
N void v_clamp(int *c, const int *a, int lo, int hi, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < lo ? lo : a[i] > hi ? hi : a[i]; }
static unsigned lcg = 5u;
static unsigned rnd(void) { lcg = lcg * 1103515245u + 12345u; return lcg >> 8; }
static unsigned long cs(const void *p, int bytes) { const unsigned char *q = p; unsigned long h = 7; for (int i = 0; i < bytes; i++) h = h * 31 + q[i]; return h; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 65, 100, 290 };
    static const int e32[] = { 0, 1, -1, 5, 6, 4, -3, -4, -2, 2147483647, -2147483647 - 1, 1000, -1000 };
    unsigned long sum = 0;
    for (int i = 0; i < 300; i++) {
        unsigned r = rnd();
        ia[i] = (i % 2) ? e32[r % 13] : (int)(r % 21) - 10;
        ib[i] = (i % 3 == 0) ? ia[i] : (i % 2) ? e32[(r >> 5) % 13] : (int)((r >> 5) % 21) - 10;
        ic[i] = (int)(r >> 9) % 5000;
        ua[i] = (unsigned)ia[i]; ub[i] = (unsigned)ib[i];
        sa[i] = (short)((i % 2) ? ia[i] * 7 : (int)(r % 41) - 20); sb[i] = (i % 3 == 0) ? sa[i] : (short)((r >> 5) % 41 - 20);
        if (i % 7 == 0) { sa[i] = 32767; sb[i] = -32768; }
        ha[i] = (unsigned short)sa[i]; hb[i] = (unsigned short)sb[i];
        ca[i] = (signed char)((i % 2) ? ia[i] * 31 : (int)(r % 17) - 8); cb[i] = (i % 3 == 0) ? ca[i] : (signed char)((r >> 5) % 17 - 8);
        if (i % 5 == 0) { ca[i] = 127; cb[i] = -128; }
        ba[i] = (unsigned char)((i % 4 == 0) ? 255 : (i % 4 == 1) ? 254 : (i % 4 == 2) ? 128 : r); bb[i] = (i % 3 == 0) ? ba[i] : (unsigned char)(r >> 5);
    }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        #define R(f) for (int i = 0; i < 300; i++) { ox[i] = 31337; oy[i] = 4242; uc[i] = 999; so[i] = 4141; ho[i] = 5151; co[i] = 61; bo[i] = 71; }
        R(0)
        s_gt(ox + 1, ia + 2, 5, n);  sum = sum * 3 + cs(ox, sizeof ox);
        s_ge(ox + 1, ia + 2, 5, n);  sum = sum * 3 + cs(ox, sizeof ox);
        s_lt(ox + 1, ia + 2, 5, n);  sum = sum * 3 + cs(ox, sizeof ox);
        s_le(ox + 1, ia + 2, -3, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_eq(ox + 1, ia + 2, -1, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_ne(ox + 1, ia + 2, -1, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_gt(ox + 1, ia + 2, 2147483647, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_lt(ox + 1, ia + 2, -2147483647 - 1, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_gtk(ox + 1, ia + 2, n);    sum = sum * 3 + cs(ox, sizeof ox);
        s_ltk(ox + 1, ia + 2, n);    sum = sum * 3 + cs(ox, sizeof ox);
        s_vec(ox + 1, ia + 2, ib + 3, ic + 1, ic + 5, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_vlt(ox + 1, ia + 2, ib + 3, ic + 1, ic + 5, n); sum = sum * 3 + cs(ox, sizeof ox);
        s_vle(oy + 1, ia + 2, ib + 3, ic + 1, ic + 5, n); sum = sum * 3 + cs(oy, sizeof oy);
        s_vne(oy + 1, ia + 2, ib + 3, ic + 1, ic + 5, n); sum = sum * 3 + cs(oy, sizeof oy);
        u_gt(uc + 1, ua + 2, 5u, n);  sum = sum * 3 + cs(uc, sizeof uc);
        u_gt(uc + 1, ua + 2, 0x80000000u, n);  sum = sum * 3 + cs(uc, sizeof uc);
        u_ge(uc + 1, ua + 2, 0x80000000u, n);  sum = sum * 3 + cs(uc, sizeof uc);
        u_lt(uc + 1, ua + 2, 5u, n);  sum = sum * 3 + cs(uc, sizeof uc);
        u_le(uc + 1, ua + 2, 0xffffffffu, n);  sum = sum * 3 + cs(uc, sizeof uc);
        u_vec(uc + 1, ua + 2, ub + 3, ua + 1, ub + 5, n); sum = sum * 3 + cs(uc, sizeof uc);
        u_vlt(uc + 1, ua + 2, ub + 3, ua + 1, ub + 5, n); sum = sum * 3 + cs(uc, sizeof uc);
        h_gt(so + 1, sa + 2, 3, n);  sum = sum * 3 + cs(so, sizeof so);
        h_gt(so + 1, sa + 2, -32768, n);  sum = sum * 3 + cs(so, sizeof so);
        h_lt(so + 1, sa + 2, 3, n);  sum = sum * 3 + cs(so, sizeof so);
        h_vec(so + 1, sa + 2, sb + 3, sa + 1, sb + 5, n); sum = sum * 3 + cs(so, sizeof so);
        hu_gt(ho + 1, ha + 2, 3, n);  sum = sum * 3 + cs(ho, sizeof ho);
        hu_gt(ho + 1, ha + 2, 40000, n);  sum = sum * 3 + cs(ho, sizeof ho);
        hu_ule(ho + 1, ha + 2, hb + 3, n);  sum = sum * 3 + cs(ho, sizeof ho);
        b_gt(co + 1, ca + 2, 3, n);  sum = sum * 3 + cs(co, sizeof co);
        b_gt(co + 1, ca + 2, -128, n);  sum = sum * 3 + cs(co, sizeof co);
        b_eq(co + 1, ca + 2, cb + 3, n);  sum = sum * 3 + cs(co, sizeof co);
        bu_gt(bo + 1, ba + 2, 3, n);  sum = sum * 3 + cs(bo, sizeof bo);
        bu_gt(bo + 1, ba + 2, 253, n);  sum = sum * 3 + cs(bo, sizeof bo);
        bu_254(bo + 1, ba + 2, n);  sum = sum * 3 + cs(bo, sizeof bo);
        bu_lt(bo + 1, ba + 2, bb + 3, ba + 1, bb + 5, n);  sum = sum * 3 + cs(bo, sizeof bo);
        h_sel(so + 1, sa + 2, sb + 1, sa + 5, 3, n);       sum = sum * 3 + cs(so, sizeof so);
        h_sel(so + 1, sa + 2, sb + 1, sa + 5, 40000, n);   sum = sum * 3 + cs(so, sizeof so);
        h_sel(so + 1, sa + 2, sb + 1, sa + 5, -40000, n);  sum = sum * 3 + cs(so, sizeof so);
        h_sel(so + 1, sa + 2, sb + 1, sa + 5, -32768, n);  sum = sum * 3 + cs(so, sizeof so);
        b_sel(bo + 1, ba + 2, bb + 1, ba + 5, 200, n);     sum = sum * 3 + cs(bo, sizeof bo);
        b_sel(bo + 1, ba + 2, bb + 1, ba + 5, -1, n);      sum = sum * 3 + cs(bo, sizeof bo);
        b_sel(bo + 1, ba + 2, bb + 1, ba + 5, 255, n);     sum = sum * 3 + cs(bo, sizeof bo);
        v_cmp8(bo + 1, ia + 2, ib + 3, n); sum = sum * 3 + cs(bo, sizeof bo);
        sum = sum * 3 + (unsigned)v_count(ia + 1, 2, n);
        sum = sum * 3 + (unsigned)v_masked(ic + 1, 1000, n);
        v_and(ox + 1, ia + 2, ib + 3, 1, n); sum = sum * 3 + cs(ox, sizeof ox);
        v_or(ox + 1, ia + 2, ib + 3, 4, n);  sum = sum * 3 + cs(ox, sizeof ox);
        v_clamp(oy + 1, ia + 2, -3, 6, n);   sum = sum * 3 + cs(oy, sizeof oy);
        v_clamp(oy + 1, ic + 2, 100, 3000, n);   sum = sum * 3 + cs(oy, sizeof oy);
    }
    return (int)(sum % 100003);
}

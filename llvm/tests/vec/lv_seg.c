/* expect: 52250  vec: 6  lv: 6  flags: -ffast-math -ffp-contract=fast */
/* interleaved access groups of LoopVectorize: vlseg2 / vsseg2 (a stereo split and merge, a complex multiply), vsseg3 (three byte planes into rgb, the stores narrowed from byte lanes),
   vlseg4 and vsseg4 (a 3x3 transform of xyzw floats that passes w through).  The trip counts include 0, 1 and what is not a multiple of the strip; the arrays are at an offset of one element. */
short L[300], R[300], S[600];
unsigned char pr[300], pg[300], pb[300], rgb[900];
float ca[600], cb[600], cc[600], vin[1200], vout[1200];
__attribute__((noinline)) void k_split(short *l, short *r, const short *s, int n) { for (int i = 0; i < n; i++) { l[i] = s[2 * i]; r[i] = s[2 * i + 1]; } }
__attribute__((noinline)) void k_merge(short *s, const short *l, const short *r, int n) { for (int i = 0; i < n; i++) { s[2 * i] = l[i]; s[2 * i + 1] = r[i]; } }
__attribute__((noinline)) void k_cmul(float *c, const float *a, const float *b, int n)
{ for (int i = 0; i < n; i++) { float ar = a[2*i], ai = a[2*i+1], br = b[2*i], bi = b[2*i+1]; c[2*i] = ar*br - ai*bi; c[2*i+1] = ar*bi + ai*br; } }
__attribute__((noinline)) void k_rgb(unsigned char *o, const unsigned char *r, const unsigned char *g, const unsigned char *b, int n)
{ for (int i = 0; i < n; i++) { o[3*i] = r[i]; o[3*i+1] = g[i]; o[3*i+2] = b[i]; } }
__attribute__((noinline)) void k_xform(float *o, const float *v, const float *m, int n)
{
    for (int i = 0; i < n; i++) {
        float x = v[4*i], y = v[4*i+1], z = v[4*i+2];
        o[4*i] = m[0]*x + m[1]*y + m[2]*z; o[4*i+1] = m[3]*x + m[4]*y + m[5]*z; o[4*i+2] = m[6]*x + m[7]*y + m[8]*z; o[4*i+3] = v[4*i+3];
    }
}
__attribute__((noinline)) void k_swap(short *s, int n) { for (int i = 0; i < n; i++) { short a = s[2*i], b = s[2*i+1]; s[2*i] = b; s[2*i+1] = a; } }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 3, 7, 8, 9, 15, 16, 17, 31, 33, 100 };
    static const float m[9] = { 1.5f, -0.5f, 2.0f, 0.25f, 1.0f, -1.0f, 3.0f, 0.5f, -2.0f };
    long sum = 0;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 600; i++) { S[i] = (short)(i * 211 - 9000); ca[i] = (float)(i % 17) - 8.0f; cb[i] = (float)(i % 13) * 0.5f - 3.0f; cc[i] = 0; }
        for (int i = 0; i < 300; i++) { L[i] = 7; R[i] = 9; pr[i] = (unsigned char)(i * 3); pg[i] = (unsigned char)(i * 5 + 1); pb[i] = (unsigned char)(i * 11 + 2); }
        for (int i = 0; i < 900; i++) rgb[i] = 200;
        for (int i = 0; i < 1200; i++) { vin[i] = (float)((i * 7) % 23) - 11.0f; vout[i] = -1.0f; }
        k_split(L + 1, R + 1, S + 2, n);
        for (int i = 0; i < 300; i++) sum += (L[i] * 3 + R[i]) * (i % 5 + 1);
        k_merge(S + 2, L + 1, R + 2, n);
        for (int i = 0; i < 600; i++) sum += S[i] * (i % 7 + 1);
        k_cmul(cc + 2, ca + 2, cb, n);
        for (int i = 0; i < 600; i++) sum += (long)(cc[i] * 4.0f) * (i % 3 + 1);
        k_rgb(rgb + 3, pr + 1, pg, pb + 2, n);
        for (int i = 0; i < 900; i++) sum += rgb[i] * (i % 11 + 1);
        k_xform(vout + 4, vin, m, n);
        for (int i = 0; i < 1200; i++) sum += (long)(vout[i] * 8.0f) * (i % 9 + 1);
        k_swap(S + 2, n);
        for (int i = 0; i < 600; i++) sum += S[i] * (i % 13 + 1);
    }
    return (int)(sum % 100003);
}

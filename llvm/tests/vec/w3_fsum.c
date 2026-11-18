/* expect: 7861 vec: 1  lv: 1  flags: -ffast-math */
/* errata 173: the order of a floating-point sum is fixed by chunks of 16 bytes of its source lanes (vec-isa.md section 8), so a block may hold a float sum only if no lane of the block is wider than a float.
   k_sum is one block (vacc.f).  k_wide sums floats and 64-bit integers in one loop: the block would have 8-byte lanes beside a float sum, which as64 refuses, so the pass makes no block for it (the scalar
   loop runs; the first line counts the blocks of k_sum only).  The values are small integers, so every order gives the same sum and the test does not look at the order. */
float f[100];
long long q[100];
__attribute__((noinline)) float k_sum(const float *a, int n)
{
    float s = 0;
    for (int i = 0; i < n; i++) s += a[i];
    return s;
}
__attribute__((noinline)) float k_wide(const float *a, const long long *b, int n, long long *out)
{
    float s = 0;
    long long t = 0;
    for (int i = 0; i < n; i++) { s += a[i]; t += b[i]; }
    *out = t;
    return s;
}
int test(void)
{
    long long t = 0, r = 0;
    for (int i = 0; i < 100; i++) { f[i] = (float)(i % 7); q[i] = i * 3; }
    for (int n = 0; n < 100; n += 7) { r += (long long)k_sum(f, n); r += (long long)k_wide(f, q, n, &t) + t; }
    return (int)(r % 10007);
}

/* The simple loops of the comparison (llvm/bench/bench.py): saxpy, a float and an integer dot product, a sum, a byte map, a copy */
#include <stdint.h>
void k_saxpy(float *y, const float *x, float a, int n) { for (int i = 0; i < n; i++) y[i] += a * x[i]; }
float k_sdot(const float *x, const float *y, int n) { float s = 0; for (int i = 0; i < n; i++) s += x[i] * y[i]; return s; }
int k_isum(const int *x, int n) { int s = 0; for (int i = 0; i < n; i++) s += x[i]; return s; }
void k_bytemap(uint8_t *d, const uint8_t *s, int n) { for (int i = 0; i < n; i++) d[i] = (uint8_t)(255 - s[i]); }
void k_copy16(int16_t *d, const int16_t *s, int n) { for (int i = 0; i < n; i++) d[i] = s[i]; }

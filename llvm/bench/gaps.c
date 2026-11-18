/* gaps.c -- one small loop for each thing LoopVectorize may refuse, to see why (llvm/bench/gaps.py, llvm/vectorizer-gaps.md).  Each g_* function is ONE innermost loop; the
   expectation in the comment is what the machine's ISA would need.  Compiled by clang -O2 (no LLVM pass) and run through opt -O2 -mtriple=pdp64 with the loop vectoriser's remarks. */
#include <stdint.h>
#include <stddef.h>
#define N __attribute__((noinline))
float sqrtf(float); float expf(float); float fabsf(float); float fmaxf(float, float);
/* ---- works (the control group) */
N void g_axpy(float *y, const float *x, float a, int n) { for (int i = 0; i < n; i++) y[i] += a * x[i]; }
N int g_sum32(const int *a, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }
N void g_max2(int *c, const int *a, const int *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > b[i] ? a[i] : b[i]; }
N void g_neg(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = -a[i]; }
N void g_widen_mul(int *c, const int8_t *a, const int8_t *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] * b[i]; }
N void g_shiftv(uint32_t *c, const uint32_t *a, const uint32_t *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] << (b[i] & 31); }
N void g_clamp_u8(uint8_t *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < 0 ? 0 : a[i] > 255 ? 255 : a[i]; }
/* ---- conditional code */
N void g_select_const(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 100 : 7; }              /* a compare that makes a mask, a select */
N void g_cond_store(int *c, const int *a, int t, int n) { for (int i = 0; i < n; i++) if (a[i] > t) c[i] = a[i]; }                /* a masked store */
N int g_count(const int *a, int t, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] > t; return s; }                     /* compare, then a sum of the mask */
N void g_cmp_val(uint8_t *c, const int *a, const int *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < b[i]; }              /* a compare used as a 0/1 value */
N int g_argmax(const int *a, int n) { int m = a[0], k = 0; for (int i = 1; i < n; i++) if (a[i] > m) { m = a[i]; k = i; } return k; }   /* index of a maximum */
N int g_find(const int *a, int key, int n) { for (int i = 0; i < n; i++) if (a[i] == key) return i; return -1; }                   /* early exit */
N void g_if_else(float *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) { if (a[i] > 0.0f) c[i] = a[i] * b[i]; else c[i] = b[i]; } }
N float g_fmax_nan(const float *a, int n) { float m = a[0]; for (int i = 1; i < n; i++) m = fmaxf(m, a[i]); return m; }              /* NaN-aware maximum */
/* ---- arithmetic the ISA lacks */
N void g_idiv(int *c, const int *a, const int *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] / b[i]; }                       /* integer division */
N void g_idiv_const(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] / 7; }                                  /* division by a constant: a high multiply */
N void g_irem(uint32_t *c, const uint32_t *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] % 10; }
N void g_fdiv(float *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] / b[i]; }
N void g_fdiv_inv(float *c, const float *a, float d, int n) { for (int i = 0; i < n; i++) c[i] = a[i] / d; }                        /* division by an invariant */
N void g_sqrt(float *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = sqrtf(a[i]); }
N void g_exp(float *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = expf(a[i]); }                                    /* a library call */
N void g_fabs(float *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = fabsf(a[i]); }
N void g_popcnt(uint32_t *c, const uint32_t *a, int n) { for (int i = 0; i < n; i++) c[i] = __builtin_popcount(a[i]); }
N void g_clz(uint32_t *c, const uint32_t *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] ? __builtin_clz(a[i]) : 32; }
N void g_bswap(uint32_t *c, const uint32_t *a, int n) { for (int i = 0; i < n; i++) c[i] = __builtin_bswap32(a[i]); }
N void g_mulh(uint32_t *c, const uint32_t *a, const uint32_t *b, int n) { for (int i = 0; i < n; i++) c[i] = (uint32_t)(((uint64_t)a[i] * b[i]) >> 32); }
N void g_rotl(uint32_t *c, const uint32_t *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] << 7) | (a[i] >> 25); }
/* ---- conversions between lane types of registers */
N void g_i2f(float *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i]; }
N void g_f2i(int *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (int)a[i]; }
N void g_f2d(double *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (double)a[i]; }                                /* works: vld.f.d */
N void g_u8_to_f(float *c, const uint8_t *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] * (1.0f / 255.0f); }               /* byte to float */
N void g_q4(uint8_t *c, const uint8_t *a, int n) { for (int i = 0; i < n; i++) c[i] = (uint8_t)((a[i] & 15) + (a[i] >> 4)); }     /* a computed byte value widened */
N int g_q4dot(const uint8_t *w, const int8_t *x, int n) { int s = 0; for (int i = 0; i < n; i++) s += ((w[i] & 15) - 8) * x[i]; return s; }
/* ---- memory access patterns */
N void g_gather(int *c, const int *a, const int *idx, int n) { for (int i = 0; i < n; i++) c[i] = a[idx[i]]; }                      /* gather: vldx exists */
N void g_scatter(int *a, const int *c, const int *idx, int n) { for (int i = 0; i < n; i++) a[idx[i]] = c[i]; }                    /* scatter: nothing */
N void g_hist(int *h, const uint8_t *a, int n) { for (int i = 0; i < n; i++) h[a[i]]++; }                                          /* scatter-add */
N void g_stride2(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = a[2 * i]; }                                     /* one field of two: a gap */
N void g_stride3(uint8_t *c, const uint8_t *a, int n) { for (int i = 0; i < n; i++) c[i] = a[3 * i] + a[3 * i + 1] + a[3 * i + 2]; } /* a full 3-field group */
N void g_stride4_gap(uint8_t *c, const uint8_t *a, int n) { for (int i = 0; i < n; i++) c[i] = (uint8_t)((77 * a[4*i] + 150 * a[4*i+1] + 29 * a[4*i+2]) >> 8); }   /* 3 of 4 fields */
N void g_reverse(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = a[n - 1 - i]; }                                 /* a reversed access */
N void g_ahead(int *a, int n) { for (int i = 0; i < n; i++) a[i] = a[i + 1] + 1; }                                                 /* read ahead in the same array */
N void g_prefix(int *a, const int *b, int n) { for (int i = 1; i < n; i++) a[i] = a[i - 1] + b[i]; }                               /* a true dependence */
N void g_window8(uint8_t *d, const uint8_t *s, const int8_t *f, int n) { for (int i = 0; i < n; i++) { int t = 0; for (int k = 0; k < 8; k++) t += f[k] * s[i + k]; d[i] = (uint8_t)(t >> 6); } }
N void g_matvec_row(float *y, const float *m, const float *x, int rows, int cols) { for (int r = 0; r < rows; r++) { float s = 0; for (int c = 0; c < cols; c++) s += m[r * cols + c] * x[c]; y[r] = s; } }
/* ---- reductions that are not a sum, a maximum or a minimum */
N int g_prod(const int *a, int n) { int p = 1; for (int i = 0; i < n; i++) p *= a[i]; return p; }
N uint32_t g_or(const uint32_t *a, int n) { uint32_t s = 0; for (int i = 0; i < n; i++) s |= a[i]; return s; }
N uint32_t g_xor(const uint32_t *a, int n) { uint32_t s = 0; for (int i = 0; i < n; i++) s ^= a[i]; return s; }
N uint32_t g_and(const uint32_t *a, int n) { uint32_t s = ~0u; for (int i = 0; i < n; i++) s &= a[i]; return s; }
N int64_t g_sum64_of32(const int *a, int n) { int64_t s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }                    /* a widening sum: works */
N float g_fsum(const float *a, int n) { float s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }                            /* strict: an ordered sum */
N int g_sad8(const uint8_t *a, const uint8_t *b, int n) { int s = 0; for (int i = 0; i < n; i++) { int d = a[i] - b[i]; s += d < 0 ? -d : d; } return s; }
/* ---- loop structure */
N int g_strlen(const char *p) { int n = 0; while (p[n]) n++; return n; }                                                           /* trip count unknown to the loop */
struct node { struct node *next; int v; };
N int g_list(const struct node *p) { int s = 0; for (; p; p = p->next) s += p->v; return s; }
N void g_call(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = (int)__builtin_ctz((unsigned)a[i] | 256); }
N void g_inner3(float *c, const float *a, int n) { for (int i = 0; i < n; i++) { float s = 0; for (int k = 0; k < 3; k++) s += a[3 * i + k]; c[i] = s; } }
/* ---- the words of waves 1 and 2 (errata 170, 171): the idioms that select them, and the forms that still do not */
N void g_avg_u8(uint8_t *c, const uint8_t *a, const uint8_t *b, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + b[i] + 1) >> 1; }                      /* vavgu.b */
N void g_mulh16(int16_t *c, const int16_t *a, const int16_t *b, int n) { for (int i = 0; i < n; i++) c[i] = (int16_t)((a[i] * b[i]) >> 16); }          /* vmulh.w */
N void g_q15(int16_t *c, const int16_t *a, const int16_t *b, int n) { for (int i = 0; i < n; i++) { int t = (a[i] * b[i] + 16384) >> 15; c[i] = t > 32767 ? 32767 : t; } }   /* vmulhr.w */
N int g_dot8(const int8_t *a, const int8_t *b, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }                              /* vdacc.b */
N int64_t g_dot16(const int16_t *a, const int16_t *b, int n) { int64_t s = 0; for (int i = 0; i < n; i++) s += (int64_t)a[i] * b[i]; return s; }       /* vdacc.w */
N void g_rsh16(int16_t *c, const int16_t *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + 8) >> 4; }                                              /* vsarr.w */
N void g_rsh32_u(uint32_t *c, const uint32_t *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + 128u) >> 8; }                                       /* no nuw: the sum wraps in C, vshrr.l would not */
N void g_qround(int8_t *c, const int *a, int n) { for (int i = 0; i < n; i++) { int t = (a[i] + 128) >> 8; c[i] = t < -128 ? -128 : t > 127 ? 127 : t; } }   /* vsts.l.b #8 */
N void g_mla(int *c, const int *a, const int *b, const int *d, int n) { for (int i = 0; i < n; i++) c[i] = a[i] * b[i] + d[i]; }                          /* vmla.l */
N void g_thresh_arms(int16_t *c, const int16_t *x, const int16_t *a, const int16_t *b, int t, int n) { for (int i = 0; i < n; i++) { int16_t va = a[i], vb = b[i]; c[i] = x[i] > t ? va : vb; } }   /* int threshold: compare in 32-bit lanes, arms widened */
N void g_thresh_cond(int16_t *c, const int16_t *x, const int16_t *a, const int16_t *b, int t, int n) { for (int i = 0; i < n; i++) c[i] = x[i] > t ? a[i] : b[i]; }   /* conditional loads: masked loads */
N void g_lut16(uint8_t *c, const uint8_t *a, const uint8_t *tbl, int n) { for (int i = 0; i < n; i++) c[i] = tbl[a[i] & 15]; }                          /* a 16-byte table: vtbl.b, but this is a gather */
N void g_fmaxnan(float *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > b[i] ? a[i] : b[i]; }                      /* fcmp + select, NaN exact */
N void g_f2u(unsigned *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (unsigned)a[i]; }                                                    /* vcvt.f.lu */
N void g_u2f(float *c, const unsigned *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i]; }                                                       /* vcvt.lu.f */
N void g_f2i64(int64_t *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (int64_t)a[i]; }                                                    /* 64-bit lanes: no vcvt */
N void g_d2i(int *c, const double *a, int n) { for (int i = 0; i < n; i++) c[i] = (int)a[i]; }                                                             /* double: no vcvt.d */
N void g_cmp64(int *c, const int64_t *a, int64_t t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? 1 : 0; }                                       /* 64-bit lanes: no vcgt.q */
N void g_cmp_wide_arms(int *c, const uint8_t *x, const int *a, const int *b, int t, int n) { for (int i = 0; i < n; i++) c[i] = x[i] > t ? a[i] : b[i]; }   /* mask narrower than the arms, and conditional loads */
N void g_cmp_wide_arms2(int *c, const uint8_t *x, int t, int n) { for (int i = 0; i < n; i++) c[i] = x[i] > t ? 1000 : 7; }                               /* a byte compared with an int, int arms: the mask is in bytes only if t fits */

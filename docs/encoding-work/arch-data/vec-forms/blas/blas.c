/* The BLAS calls of cugpt (double: dgemv, dger, ddot, daxpy, dscal) and of cngpt (float: sgemm NT, the linear layer), as plain loops. */
#include <stdint.h>
#include <stddef.h>
double k_ddot(const double *x, const double *y, int n)
{
    double s = 0;
    for (int i = 0; i < n; i++) s += x[i] * y[i];
    return s;
}
void k_daxpy(double *y, const double *x, double a, int n)
{
    for (int i = 0; i < n; i++) y[i] += a * x[i];
}
void k_dscal(double *x, double a, int n)
{
    for (int i = 0; i < n; i++) x[i] *= a;
}
/* cblas_dgemv NoTrans, row major: y = W x, W is nout x nin */
void k_dgemv_n(const double *W, const double *x, double *y, int nout, int nin)
{
    for (int i = 0; i < nout; i++) {
        double s = 0;
        for (int j = 0; j < nin; j++) s += W[i * nin + j] * x[j];
        y[i] = s;
    }
}
/* cblas_dgemv Trans, row major: gx = W^T gy */
void k_dgemv_t(const double *W, const double *gy, double *gx, int nout, int nin)
{
    for (int j = 0; j < nin; j++) gx[j] = 0;
    for (int i = 0; i < nout; i++)
        for (int j = 0; j < nin; j++) gx[j] += W[i * nin + j] * gy[i];
}
/* cblas_dger, row major: gW += gy x^T */
void k_dger(double *gW, const double *gy, const double *x, int nout, int nin)
{
    for (int i = 0; i < nout; i++)
        for (int j = 0; j < nin; j++) gW[i * nin + j] += gy[i] * x[j];
}
/* cngpt linear_fwd: Y[M,N] = X[M,K] . W[N,K]^T (cblas_sgemm NoTrans, Trans), the reference triple loop */
void k_sgemm_nt(const float *X, const float *W, float *Y, int M, int K, int N)
{
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            float s = 0;
            for (int k = 0; k < K; k++) s += X[i * K + k] * W[j * K + k];
            Y[i * N + j] = s;
        }
}

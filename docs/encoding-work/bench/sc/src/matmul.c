/* 48x48 matrix multiply of 64-bit integers (18 KB per matrix), ijk order */
#define M 48
static long A[M][M], B[M][M], C[M][M];
int test(void)
{
	long i, j, k, s = 0, t;
	for (i = 0; i < M; i++) for (j = 0; j < M; j++) { A[i][j] = i + j; B[i][j] = i - j; }
	for (i = 0; i < M; i++)
		for (j = 0; j < M; j++) {
			t = 0;
			for (k = 0; k < M; k++) t += A[i][k] * B[k][j];
			C[i][j] = t;
		}
	for (i = 0; i < M; i++) s += C[i][i];
	return (int)(s & 0x7fffffff);
}

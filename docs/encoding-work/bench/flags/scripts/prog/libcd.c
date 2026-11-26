typedef unsigned long size_t;
void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
int heapsort(void *, size_t, size_t, int (*)(const void *, const void *));
void *bsearch(const void *, const void *, size_t, size_t, int (*)(const void *, const void *));
long strtol(const char *, char **, int);
size_t strlcpy(char *, const char *, size_t);
size_t strlcat(char *, const char *, size_t);
size_t strlen(const char *);
int strcmp(const char *, const char *);
char *strstr(const char *, const char *);
int strncmp(const char *, const char *, size_t);
char *strpbrk(const char *, const char *);
size_t strspn(const char *, const char *);
static char words[2000][12];
static char *ptr[2000], *ptr2[2000];
static unsigned long seed = 7;
static unsigned rnd(void) { seed = seed * 6364136223846793005UL + 1442695040888963407UL; return seed >> 40; }
static int cmps(const void *a, const void *b) { return strcmp(*(char **)a, *(char **)b); }
static int cmpl(const void *a, const void *b) { long x = *(const long *)a, y = *(const long *)b; return x < y ? -1 : x > y; }
static long nums[3000];
int test(void)
{
	int i, j, n = 2000, ok = 0;
	long s = 0;
	char big[600], tmp[64];
	for (i = 0; i < n; i++) { int l = 3 + rnd() % 8; for (j = 0; j < l; j++) words[i][j] = 'a' + rnd() % 26; words[i][l] = 0; ptr[i] = ptr2[i] = words[i]; }
	qsort(ptr, n, sizeof ptr[0], cmps);
	heapsort(ptr2, n, sizeof ptr2[0], cmps);
	for (i = 0; i < n; i++) if (ptr[i] == ptr2[i]) ok++;
	for (i = 1; i < n; i++) if (strcmp(ptr[i - 1], ptr[i]) > 0) return -1;
	for (i = 0; i < 500; i++) { char **r = bsearch(&ptr[(i * 37) % n], ptr, n, sizeof ptr[0], cmps); if (r) s += r - ptr; }
	for (i = 0; i < 3000; i++) { nums[i] = (long)rnd() - 8000000; }
	qsort(nums, 3000, sizeof nums[0], cmpl);
	for (i = 1; i < 3000; i++) if (nums[i - 1] > nums[i]) return -2;
	big[0] = 0;
	for (i = 0; i < 40; i++) strlcat(big, ptr[i * 30], sizeof big);
	for (i = 0; i < 300; i++) { char *p = strstr(big, ptr[(i * 61) % n]); if (p) s += p - big; }
	for (i = 0; i < 1500; i++) { char nb[24]; long v = nums[i]; int k = 0; unsigned long u = v < 0 ? -v : v; char r[24]; int m = 0; do { r[m++] = '0' + u % 10; u /= 10; } while (u); if (v < 0) nb[k++] = '-'; while (m) nb[k++] = r[--m]; nb[k] = 0; s += strtol(nb, 0, 10) == v; s += strspn(nb, "0123456789-"); }
	return (int)((s + ok + strlen(big)) & 0x7fffffff);
}

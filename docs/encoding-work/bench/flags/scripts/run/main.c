int test(void);
long write(int, char *, long);
int main(void)
{
	char b[24];
	char *p = b + 24;
	long v = test();
	int neg = v < 0;
	unsigned long u = neg ? -(unsigned long)v : (unsigned long)v;
	*--p = '\n';
	do { *--p = '0' + (int)(u % 10); u /= 10; } while (u);
	if (neg) *--p = '-';
	write(1, p, b + 24 - p);
	return 0;
}

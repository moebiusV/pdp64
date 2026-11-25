#include <x86intrin.h>
/* the timing step of a Flush+Reload probe: flush a line, let the victim run, time a reload */
unsigned long reload_time(const char *p) {
	unsigned int aux;
	unsigned long t0, t1;
	_mm_clflush(p);
	t0 = __rdtscp(&aux);
	(void)*(volatile const char *)p;
	t1 = __rdtscp(&aux);
	return t1 - t0;
}

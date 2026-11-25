/* a linked list of 12000 nodes allocated in shuffled order (192 KB), built, traversed and summed twice, then reversed in place */
struct node { struct node *next; long v; };
#define N 12000
static struct node pool[N];
static unsigned short order[N];
int test(void)
{
	long i, r, s = 0, j;
	struct node *p, *q, *n, *head = 0;
	unsigned long seed = 5;
	for (i = 0; i < N; i++) order[i] = (unsigned short)i;
	for (i = N - 1; i > 0; i--) { seed = seed * 6364136223846793005UL + 1; j = (seed >> 33) % (i + 1); r = order[i]; order[i] = order[j]; order[j] = (unsigned short)r; }
	for (i = 0; i < N; i++) { p = &pool[order[i]]; p->v = i; p->next = head; head = p; }
	for (r = 0; r < 2; r++) for (p = head; p; p = p->next) s += p->v;
	q = 0;
	for (p = head; p; p = n) { n = p->next; p->next = q; q = p; }
	for (p = q; p; p = p->next) s += p->v;
	return (int)(s & 0x7fffffff);
}

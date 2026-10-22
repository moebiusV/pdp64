/* ld64: the pdp64 linker.
 *
 * Reads the ELF64 relocatable objects as64 writes, resolves symbols, lays the sections out, applies the five relocation
 * types (as64/relocs.h) and writes an ELF64 executable.  The ELF records come from the generated grammar (spec/elf.hbnf),
 * as in as64; the layout of the file, offsets and sizes, is done here.
 *
 *   ld64 [-o out] [-e entry] [-Ttext addr] [-M] file.o ...
 *
 * Layout: the executable code of every object in one segment at -Ttext (default 0x10000), then, on the next page, the
 * data and the zero-filled data (.bss and common symbols) in a second.  Pages are 4096 bytes (ISA 8.2).
 *
 * An instruction relocation patches the last 16*len bits of the instruction whose first parcel is at r_offset; `len` is in
 * bits 15..14 of that parcel (docs/CHANGES-SINCE-R20.md 7).  The field holds its parcels most significant first, each
 * parcel little-endian in memory.
 */
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "elf-parser.c"
#include "relocs.h"

static const char *progname = "ld64";
static int errors;
static void fail(const char *fmt, ...)
{
	va_list ap;
	fprintf(stderr, "%s: ", progname);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
	errors++;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* records (the generated grammar)                                                                                     */

enum { REC_EHDR = 1, REC_SHDR, REC_SYM, REC_RELA, REC_PHDR };
#define RECSIZE(k) ((k) == REC_EHDR ? 64 : (k) == REC_SHDR ? 64 : (k) == REC_SYM ? 24 : (k) == REC_RELA ? 24 : 56)

static int rec_get(int kind, const uint8_t *p, size_t avail, elfrec_t *r)
{
	uint8_t tmp[80]; char e[160]; size_t at;
	if (avail < (size_t)RECSIZE(kind)) return -1;
	tmp[0] = (uint8_t)kind;
	memcpy(tmp + 1, p, RECSIZE(kind));
	return parse_bytes(tmp, 1 + RECSIZE(kind), r, e, sizeof e, &at) ? 0 : -1;
}
struct buf { uint8_t *p; size_t n, cap; };
static void bput(struct buf *b, const void *d, size_t n)
{
	if (b->n + n > b->cap) { b->cap = (b->n + n) * 2 + 256; b->p = realloc(b->p, b->cap); }
	memcpy(b->p + b->n, d, n);
	b->n += n;
}
static void balign(struct buf *b, size_t a) { static const uint8_t z[1]; while (b->n % a) bput(b, z, 1); }
static void rec_put(elfrec_t *r, struct buf *out)
{
	uint8_t tmp[128]; size_t n; char e[160];
	if (!emit_bytes(r, tmp, sizeof tmp, &n, e, sizeof e)) { fprintf(stderr, "%s: internal error writing a record: %s\n", progname, e); exit(2); }
	bput(out, tmp + 1, n - 1);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* objects and symbols                                                                                                 */

enum { C_TEXT, C_DATA, C_BSS, NCLASS };		/* output classes */

struct isec {		/* an input section that is loaded */
	int cls;
	const uint8_t *data;	/* NULL for NOBITS */
	uint64_t size, align, outoff;	/* offset within its class once placed */
	int shndx;
};
struct obj {
	const char *name;
	uint8_t *file;
	size_t flen;
	int nsec;
	shdr_t *sh;
	struct isec *is;		/* indexed by section number; cls < 0 for sections that are not loaded */
	int *cls;
	sym_t *syms;
	char **symname;
	int nsyms;
	int *gsym;		/* object symbol -> global symbol index, or -1 */
};
static struct obj *objs;
static int nobjs;

struct gsym {
	char *name;
	int defined;
	int obj;		/* defining object, -1 for absolute / common */
	int sec;		/* section number in that object */
	uint64_t value;		/* offset in the section, or the absolute value */
	int abs, common;
	uint64_t csize, calign;
	uint64_t addr;		/* final address */
};
static struct gsym *gs;
static int ngs, capgs;

static int gfind(const char *name)
{
	for (int i = 0; i < ngs; i++) if (!strcmp(gs[i].name, name)) return i;
	if (ngs == capgs) { capgs = capgs ? capgs * 2 : 256; gs = realloc(gs, capgs * sizeof *gs); }
	memset(&gs[ngs], 0, sizeof gs[ngs]);
	gs[ngs].name = strdup(name);
	gs[ngs].obj = -1;
	return ngs++;
}

static const char *cstr(const uint8_t *tab, size_t n, uint32_t off) { return off < n ? (const char *)tab + off : ""; }

static int load_object(const char *path)
{
	FILE *f = fopen(path, "rb");
	struct obj o;
	elfrec_t r;
	if (!f) { fail("%s: %s", path, strerror(errno)); return -1; }
	memset(&o, 0, sizeof o);
	o.name = path;
	fseek(f, 0, SEEK_END); o.flen = ftell(f); fseek(f, 0, SEEK_SET);
	o.file = malloc(o.flen + 1);
	if (fread(o.file, 1, o.flen, f) != o.flen) { fail("%s: read error", path); return -1; }
	fclose(f);
	if (rec_get(REC_EHDR, o.file, o.flen, &r) || memcmp(o.file, "\177ELF\2\1\1", 7) || r.body.u.a1.e.machine != EM_PDP64 || r.body.u.a1.e.type != 1) {
		fail("%s: not a pdp64 ELF relocatable object", path); return -1;
	}
	ehdr_t eh = r.body.u.a1.e;
	o.nsec = eh.shnum;
	o.sh = calloc(o.nsec, sizeof *o.sh);
	o.is = calloc(o.nsec, sizeof *o.is);
	o.cls = malloc(o.nsec * sizeof *o.cls);
	for (int i = 0; i < o.nsec; i++) {
		if (rec_get(REC_SHDR, o.file + eh.shoff + (size_t)i * 64, o.flen - eh.shoff, &r)) { fail("%s: bad section header", path); return -1; }
		o.sh[i] = r.body.u.a2.s;
		o.cls[i] = -1;
		if ((o.sh[i].type == 1 || o.sh[i].type == 8) && (o.sh[i].flags & 2)) {	/* PROGBITS or NOBITS, SHF_ALLOC */
			o.cls[i] = o.sh[i].type == 8 ? C_BSS : (o.sh[i].flags & 4) ? C_TEXT : C_DATA;
			o.is[i].cls = o.cls[i];
			o.is[i].data = o.sh[i].type == 8 ? NULL : o.file + o.sh[i].offset;
			o.is[i].size = o.sh[i].size;
			o.is[i].align = o.sh[i].addralign ? o.sh[i].addralign : 1;
			o.is[i].shndx = i;
		}
	}
	/* symbols */
	for (int i = 0; i < o.nsec; i++) {
		if (o.sh[i].type != 2) continue;
		const uint8_t *strtab = o.file + o.sh[o.sh[i].link].offset;
		size_t strn = o.sh[o.sh[i].link].size;
		o.nsyms = (int)(o.sh[i].size / 24);
		o.syms = calloc(o.nsyms, sizeof *o.syms);
		o.symname = calloc(o.nsyms, sizeof *o.symname);
		o.gsym = malloc(o.nsyms * sizeof *o.gsym);
		for (int k = 0; k < o.nsyms; k++) {
			if (rec_get(REC_SYM, o.file + o.sh[i].offset + (size_t)k * 24, o.flen, &r)) { fail("%s: bad symbol", path); return -1; }
			o.syms[k] = r.body.u.a3.y;
			o.symname[k] = (char *)cstr(strtab, strn, o.syms[k].name);
			o.gsym[k] = -1;
		}
	}
	objs = realloc(objs, (nobjs + 1) * sizeof *objs);
	objs[nobjs] = o;
	return nobjs++;
}

static void collect_globals(void)
{
	for (int oi = 0; oi < nobjs; oi++) {
		struct obj *o = &objs[oi];
		for (int k = 1; k < o->nsyms; k++) {
			sym_t *y = &o->syms[k];
			int bind = y->info >> 4, type = y->info & 15;
			if (type == 3 || bind == 0) continue;			/* section and local symbols are not global names */
			int g = gfind(o->symname[k]);
			o->gsym[k] = g;
			if (y->shndx == 0) continue;				/* a reference */
			if (y->shndx == SHN_COMMON) {
				struct gsym *s = &gs[g];
				if (s->defined && !s->common) continue;
				s->common = 1; s->defined = 1;
				if (y->size > s->csize) s->csize = y->size;
				if (y->value > s->calign) s->calign = y->value;
				continue;
			}
			if (gs[g].defined && !gs[g].common) { fail("%s defined twice (in %s and %s)", gs[g].name, gs[g].obj >= 0 ? objs[gs[g].obj].name : "?", o->name); continue; }
			gs[g].defined = 1; gs[g].common = 0;
			if (y->shndx == SHN_ABS) { gs[g].abs = 1; gs[g].value = y->value; }
			else { gs[g].obj = oi; gs[g].sec = y->shndx; gs[g].value = y->value; }
		}
	}
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* layout                                                                                                              */

static uint64_t csize[NCLASS], cbase[NCLASS];
static uint64_t text_base = 0x10000;
#define PAGE 4096
static uint64_t alignup(uint64_t v, uint64_t a) { return a > 1 ? (v + a - 1) / a * a : v; }

static void layout(void)
{
	for (int oi = 0; oi < nobjs; oi++) {
		struct obj *o = &objs[oi];
		for (int i = 0; i < o->nsec; i++) {
			if (o->cls[i] < 0) continue;
			int c = o->cls[i];
			csize[c] = alignup(csize[c], o->is[i].align);
			o->is[i].outoff = csize[c];
			csize[c] += o->is[i].size;
		}
	}
	/* common symbols go to the end of .bss */
	for (int g = 0; g < ngs; g++)
		if (gs[g].common) {
			csize[C_BSS] = alignup(csize[C_BSS], gs[g].calign ? gs[g].calign : 8);
			gs[g].value = csize[C_BSS];
			csize[C_BSS] += gs[g].csize;
		}
	cbase[C_TEXT] = text_base;
	cbase[C_DATA] = alignup(cbase[C_TEXT] + csize[C_TEXT], PAGE);
	cbase[C_BSS] = alignup(cbase[C_DATA] + csize[C_DATA], 8);
	for (int g = 0; g < ngs; g++) {
		struct gsym *s = &gs[g];
		if (!s->defined) continue;
		if (s->abs) s->addr = s->value;
		else if (s->common) s->addr = cbase[C_BSS] + s->value;
		else {
			struct obj *o = &objs[s->obj];
			s->addr = cbase[o->cls[s->sec]] + o->is[s->sec].outoff + s->value;
		}
	}
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* relocation                                                                                                          */

static int fits_signed(int64_t v, int bits) { return bits >= 64 || (v >= -((int64_t)1 << (bits - 1)) && v < ((int64_t)1 << (bits - 1))); }

static uint16_t get16(const uint8_t *p) { return (uint16_t)(p[0] | p[1] << 8); }
static void put16(uint8_t *p, uint16_t v) { p[0] = v & 255; p[1] = v >> 8; }

/* The value of a symbol as a relocation sees it: S. */
static int sym_addr(struct obj *o, int k, uint64_t *out, const char *what)
{
	sym_t *y = &o->syms[k];
	int type = y->info & 15;
	if (type == 3) { *out = cbase[o->cls[y->shndx]] + o->is[y->shndx].outoff; return 0; }		/* section symbol */
	if (o->gsym[k] >= 0 && gs[o->gsym[k]].defined) { *out = gs[o->gsym[k]].addr; return 0; }
	if (o->gsym[k] >= 0) return -1;									/* undefined global: reported once, elsewhere */
	if (y->shndx == SHN_ABS) { *out = y->value; return 0; }
	if (y->shndx > 0 && y->shndx < o->nsec && o->cls[y->shndx] >= 0) {				/* a local symbol */
		*out = cbase[o->cls[y->shndx]] + o->is[y->shndx].outoff + y->value;
		return 0;
	}
	fail("%s: relocation against %s: unusable symbol (%s)", o->name, o->symname[k], what);
	return -1;
}

/* The name to report for a relocation's symbol.  The assembler refers to a local symbol through its section's symbol, with the offset as the
   addend: then name the nearest named symbol at or below that offset in the section ("target", or "target+0x8"), as the programmer wrote it. */
static const char *relname(struct obj *o, int k, int64_t addend, char *buf, size_t n)
{
	sym_t *y = &o->syms[k];
	if ((y->info & 15) != 3) return o->symname[k];
	int best = -1;
	for (int j = 1; j < o->nsyms; j++) {
		sym_t *z = &o->syms[j];
		if ((z->info & 15) == 3 || z->shndx != y->shndx || !o->symname[j][0] || (int64_t)z->value > addend) continue;
		if (best < 0 || z->value > o->syms[best].value) best = j;
	}
	if (best < 0) snprintf(buf, n, "section %u+%#llx", (unsigned)y->shndx, (unsigned long long)addend);
	else if ((int64_t)o->syms[best].value == addend) snprintf(buf, n, "%s", o->symname[best]);
	else snprintf(buf, n, "%s+%#llx", o->symname[best], (unsigned long long)(addend - (int64_t)o->syms[best].value));
	return buf;
}

static void relocate(uint8_t *image[NCLASS])
{
	for (int oi = 0; oi < nobjs; oi++) {
		struct obj *o = &objs[oi];
		for (int i = 0; i < o->nsec; i++) {
			if (o->sh[i].type != 4) continue;
			int target = (int)o->sh[i].info;
			if (target <= 0 || target >= o->nsec || o->cls[target] < 0 || o->cls[target] == C_BSS) continue;
			int c = o->cls[target];
			uint64_t secaddr = cbase[c] + o->is[target].outoff;
			size_t n = o->sh[i].size / 24;
			for (size_t k = 0; k < n; k++) {
				elfrec_t r;
				if (rec_get(REC_RELA, o->file + o->sh[i].offset + k * 24, o->flen, &r)) { fail("%s: bad relocation", o->name); continue; }
				rela_t rl = r.body.u.a4.r;
				uint64_t S;
				if (rl.symidx >= (uint32_t)o->nsyms) { fail("%s: relocation names symbol %u", o->name, rl.symidx); continue; }
				if (sym_addr(o, rl.symidx, &S, "relocation")) continue;
				uint64_t P = secaddr + rl.offset;
				uint8_t *where = image[c] + o->is[target].outoff + rl.offset;
				int64_t V = (int64_t)S + rl.addend;
				char nb[300];
				const char *sname = relname(o, rl.symidx, rl.addend, nb, sizeof nb);
				switch (rl.type) {
				case R_PDP64_D64:
					for (int b = 0; b < 8; b++) where[b] = (uint64_t)V >> (8 * b);
					break;
				case R_PDP64_D32:
					if (!fits_signed(V, 32) && (uint64_t)V > 0xFFFFFFFFu) { fail("%s: %s: value %#llx does not fit 32 bits", o->name, sname, (unsigned long long)V); break; }
					for (int b = 0; b < 4; b++) where[b] = (uint64_t)V >> (8 * b);
					break;
				case R_PDP64_INSN_ABS: case R_PDP64_INSN_PC: case R_PDP64_INSN_BR: {
					int len = get16(where) >> 14;			/* 1 or 2: a page-2 instruction (len 3) has no field to patch */
					int bits = 16 * len;
					if (len == 3) { fail("%s: relocation to %s on a one-parcel (page 2) instruction", o->name, sname); break; }
					int64_t val = V;
					if (rl.type == R_PDP64_INSN_PC) val = V - (int64_t)P;
					if (rl.type == R_PDP64_INSN_BR) {
						val = V - (int64_t)P;
						if (val & 1) { fail("%s: branch to %s is to an odd address", o->name, sname); break; }
						val /= 2;
					}
					if (len == 0 || !fits_signed(val, bits)) {
						fail("%s: relocation to %s out of range (%s %lld does not fit the %d-bit field of the instruction; an immediate or absolute address is a sign-extended 32-bit value)", o->name, sname,
						    rl.type == R_PDP64_INSN_ABS ? "value" : "displacement", (long long)val, bits);
						break;
					}
					for (int pc = 1; pc <= len; pc++) {			/* parcel 1 is the most significant */
						int shift = 16 * (len - pc);
						put16(where + 2 * pc, (uint16_t)((uint64_t)val >> shift));
					}
					break;
				}
				default:
					fail("%s: unknown relocation type %u", o->name, rl.type);
				}
			}
		}
	}
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the executable                                                                                                      */

static int write_exec(const char *path, uint64_t entry, uint8_t *image[NCLASS])
{
	struct buf f = { 0 }, symtab = { 0 }, strtab = { 0 }, shstr = { 0 };
	elfrec_t r;
	uint8_t zero[64] = { 0 };
	bput(&strtab, "", 1);
	bput(&shstr, "", 1);
	/* file: ehdr, phdrs, (pad to a page), text, (pad to a page), data, then the tables and section headers */
	bput(&f, zero, 64 + 2 * 56);
	while (f.n < PAGE) bput(&f, zero, 1);
	size_t off_text = f.n;
	bput(&f, image[C_TEXT], csize[C_TEXT]);
	while (f.n % PAGE) bput(&f, zero, 1);
	size_t off_data = f.n;
	bput(&f, image[C_DATA], csize[C_DATA]);
	balign(&f, 8);
	/* symbols: every defined global, for readelf and for the emulator's traces */
	memset(&r, 0, sizeof r); r.kind = REC_SYM; r.body.kind = REC_SYM;
	rec_put(&r, &symtab);
	int nsym = 1;
	for (int g = 0; g < ngs; g++) {
		if (!gs[g].defined) continue;
		memset(&r, 0, sizeof r); r.kind = REC_SYM; r.body.kind = REC_SYM;
		sym_t *y = &r.body.u.a3.y;
		y->name = (uint32_t)strtab.n; bput(&strtab, gs[g].name, strlen(gs[g].name) + 1);
		y->info = 0x10;
		y->shndx = gs[g].abs ? SHN_ABS : gs[g].addr >= cbase[C_BSS] ? 3 : gs[g].addr >= cbase[C_DATA] ? 2 : 1;
		y->value = gs[g].addr;
		rec_put(&r, &symtab);
		nsym++;
	}
	size_t off_sym = f.n; bput(&f, symtab.p, symtab.n);
	size_t off_str = f.n; bput(&f, strtab.p, strtab.n);
	size_t nm_text = shstr.n; bput(&shstr, ".text", 6);
	size_t nm_data = shstr.n; bput(&shstr, ".data", 6);
	size_t nm_bss = shstr.n; bput(&shstr, ".bss", 5);
	size_t nm_sym = shstr.n; bput(&shstr, ".symtab", 8);
	size_t nm_str = shstr.n; bput(&shstr, ".strtab", 8);
	size_t nm_shs = shstr.n; bput(&shstr, ".shstrtab", 10);
	size_t off_shs = f.n; bput(&f, shstr.p, shstr.n);
	balign(&f, 8);
	size_t off_sh = f.n;
	struct { uint32_t name, type; uint64_t flags, addr, off, size; uint32_t link, info; uint64_t align, entsize; } sh[7] = {
		{ 0 },
		{ (uint32_t)nm_text, 1, 6, cbase[C_TEXT], off_text, csize[C_TEXT], 0, 0, 2, 0 },
		{ (uint32_t)nm_data, 1, 3, cbase[C_DATA], off_data, csize[C_DATA], 0, 0, 8, 0 },
		{ (uint32_t)nm_bss, 8, 3, cbase[C_BSS], off_data + csize[C_DATA], csize[C_BSS], 0, 0, 8, 0 },
		{ (uint32_t)nm_sym, 2, 0, 0, off_sym, symtab.n, 5, (uint32_t)nsym, 8, 24 },
		{ (uint32_t)nm_str, 3, 0, 0, off_str, strtab.n, 0, 0, 1, 0 },
		{ (uint32_t)nm_shs, 3, 0, 0, off_shs, shstr.n, 0, 0, 1, 0 },
	};
	for (int i = 0; i < 7; i++) {
		memset(&r, 0, sizeof r); r.kind = REC_SHDR; r.body.kind = REC_SHDR;
		shdr_t *h = &r.body.u.a2.s;
		h->name = sh[i].name; h->type = sh[i].type; h->flags = sh[i].flags; h->addr = sh[i].addr; h->offset = sh[i].off; h->size = sh[i].size;
		h->link = sh[i].link; h->info = sh[i].info; h->addralign = sh[i].align; h->entsize = sh[i].entsize;
		rec_put(&r, &f);
	}
	/* program headers and the file header, now that the offsets are known */
	{
		struct buf head = { 0 };
		static const uint8_t ident[16] = { 0x7f, 'E', 'L', 'F', 2, 1, 1, 0 };
		memset(&r, 0, sizeof r); r.kind = REC_EHDR; r.body.kind = REC_EHDR;
		ehdr_t *e = &r.body.u.a1.e;
		e->ident.ptr = ident; e->ident.len = 16;
		e->type = 2; e->machine = EM_PDP64; e->version = 1; e->entry = entry; e->phoff = 64; e->shoff = off_sh;
		e->ehsize = 64; e->phentsize = 56; e->phnum = 2; e->shentsize = 64; e->shnum = 7; e->shstrndx = 6;
		rec_put(&r, &head);
		memset(&r, 0, sizeof r); r.kind = REC_PHDR; r.body.kind = REC_PHDR;
		phdr_t *p = &r.body.u.a5.p;
		p->type = 1; p->flags = 5; p->offset = off_text; p->vaddr = p->paddr = cbase[C_TEXT]; p->filesz = p->memsz = csize[C_TEXT]; p->align = PAGE;
		rec_put(&r, &head);
		memset(&r, 0, sizeof r); r.kind = REC_PHDR; r.body.kind = REC_PHDR;
		p = &r.body.u.a5.p;
		p->type = 1; p->flags = 6; p->offset = off_data; p->vaddr = p->paddr = cbase[C_DATA]; p->filesz = csize[C_DATA];
		p->memsz = cbase[C_BSS] + csize[C_BSS] - cbase[C_DATA]; p->align = PAGE;
		rec_put(&r, &head);
		memcpy(f.p, head.p, head.n);
	}
	FILE *fp = fopen(path, "wb");
	if (!fp || fwrite(f.p, 1, f.n, fp) != f.n || fclose(fp)) { fprintf(stderr, "%s: cannot write %s: %s\n", progname, path, strerror(errno)); return -1; }
	return 0;
}

int main(int argc, char **argv)
{
	const char *out = "a.out", *entry = "_start";
	int map = 0;
	char **files = malloc(argc * sizeof *files);
	int nfiles = 0;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-o") && i + 1 < argc) out = argv[++i];
		else if (!strcmp(argv[i], "-e") && i + 1 < argc) entry = argv[++i];
		else if (!strcmp(argv[i], "-Ttext") && i + 1 < argc) text_base = strtoull(argv[++i], NULL, 0);
		else if (!strcmp(argv[i], "-M")) map = 1;
		else if (argv[i][0] == '-' && argv[i][1]) { fprintf(stderr, "usage: %s [-o out] [-e entry] [-Ttext addr] [-M] file.o ...\n", progname); return 2; }
		else files[nfiles++] = argv[i];
	}
	if (!nfiles) { fprintf(stderr, "usage: %s [-o out] [-e entry] [-Ttext addr] [-M] file.o ...\n", progname); return 2; }
	if (text_base % PAGE) { fprintf(stderr, "%s: -Ttext must be a multiple of %d\n", progname, PAGE); return 2; }
	for (int i = 0; i < nfiles; i++) load_object(files[i]);
	if (errors) return 1;
	collect_globals();
	/* undefined symbols: one report each */
	for (int oi = 0; oi < nobjs; oi++)
		for (int k = 1; k < objs[oi].nsyms; k++) {
			int g = objs[oi].gsym[k];
			if (g >= 0 && !gs[g].defined && objs[oi].syms[k].shndx == 0) { fail("undefined symbol %s (referenced from %s)", gs[g].name, objs[oi].name); gs[g].defined = -1; }
		}
	if (errors) return 1;
	layout();
	uint8_t *image[NCLASS];
	for (int c = 0; c < NCLASS; c++) image[c] = calloc(csize[c] + 1, 1);
	for (int oi = 0; oi < nobjs; oi++)
		for (int i = 0; i < objs[oi].nsec; i++)
			if (objs[oi].cls[i] >= 0 && objs[oi].cls[i] != C_BSS)
				memcpy(image[objs[oi].cls[i]] + objs[oi].is[i].outoff, objs[oi].is[i].data, objs[oi].is[i].size);
	relocate(image);
	int eg = -1;
	for (int g = 0; g < ngs; g++) if (!strcmp(gs[g].name, entry) && gs[g].defined > 0) eg = g;
	if (eg < 0) fail("entry symbol %s is not defined", entry);
	if (errors) return 1;
	if (map) {
		printf("text %#llx +%#llx\ndata %#llx +%#llx\nbss  %#llx +%#llx\n", (unsigned long long)cbase[C_TEXT], (unsigned long long)csize[C_TEXT],
		    (unsigned long long)cbase[C_DATA], (unsigned long long)csize[C_DATA], (unsigned long long)cbase[C_BSS], (unsigned long long)csize[C_BSS]);
		for (int g = 0; g < ngs; g++) if (gs[g].defined > 0) printf("%#018llx %s\n", (unsigned long long)gs[g].addr, gs[g].name);
	}
	return write_exec(out, gs[eg].addr, image) ? 1 : 0;
}

/* pdp64enc.h: the shared codec of the prefix-coded encodings pdp64/16 and pdp64/32 (docs/encoding-proposal.md, spec/README.md).
 *
 * The bit positions are not in the C: they are in the generated tables (tools/mkenc.py reads spec/pdp64-NN/forms.json and writes build/pdp64-NN-tab.c).
 * One codec, any table.  as64 uses encode, ld64 the field extract/insert for relocations, sim64 and the disassembler the decoder.
 *
 * An instruction is a mnemonic and up to four operands of the kinds below; the same shapes as the assembly language (docs/asm-syntax.md).
 * Parcels are 16 bits, little-endian in memory.  The length of an instruction (1, 2, 3 or 5 parcels) is a function of parcel 0 alone.
 */
#ifndef PDP64ENC_H
#define PDP64ENC_H
#include <stddef.h>
#include <stdint.h>

enum ek { EK_NONE = 0, EK_R, EK_I, EK_B, EK_X, EK_PI, EK_PD, EK_PC, EK_A };

#define EBASE_DP 255			/* the base register of d(DP), as `r` of an EK_B operand */

struct eop {
	uint8_t k;			/* enum ek */
	uint8_t ext;			/* EK_PC, EK_A, EK_I: the value is not known (a relocation will supply it): only a field of 32 bits or more takes it */
	uint8_t s;			/* EK_X: the scale, 1 2 4 or 8 */
	uint16_t r, x;			/* EK_R: r.  EK_B, EK_PI, EK_PD: r is the base.  EK_X: r base, x index */
	int64_t v;			/* EK_I: the immediate.  EK_B, EK_X: displacement in bytes.  EK_PI, EK_PD: the stride.
					   EK_PC: bytes from the first parcel of the instruction to the target.  EK_A: the address */
};

struct einsn {
	int mn;				/* the index in the table's mnemonic list (enc_mn_find) */
	int nops;
	struct eop op[4];
};

/* ---- the generated tables: plain data, defined in build/pdp64-NN-tab.c ---------------------------------------------- */
enum { ES_R = 1, ES_K, ES_I, ES_B, ES_X, ES_PI, ES_PD, ES_PC, ES_A };

struct espec {
	uint8_t kind;			/* ES_* */
	uint8_t w;			/* ES_R, ES_I, ES_PC, ES_A: the width; ES_B, ES_X, ES_PI, ES_PD: the width of the displacement (0: none) */
	uint8_t sgn;			/* ES_I, ES_B, ES_X: signed */
	uint8_t ntab;			/* ES_R: the length of the hot-register table at tab (0: the register number itself) */
	uint8_t kop;			/* ES_K: EK_R or EK_I */
	int32_t scale;			/* ES_I: the scale; ES_B: the scale (0: the size of the mnemonic's access); ES_PC: the unit in bytes */
	int32_t kval;			/* ES_K: the value (register EBASE_DP for d(DP)) */
	uint16_t tab;			/* ES_R: offset into the hot-register pool */
	int16_t rn, rx;			/* ES_B, ES_X, ES_PI, ES_PD: the register specs (indexes into the spec pool) */
};

struct erun { uint8_t parcel, hi, len; };	/* bits hi..hi-len+1 of one parcel */
struct eplace {
	uint8_t oi;			/* operand index; ESUB for the sub-opcode field */
	uint8_t pi;			/* part of that operand (register, displacement, scale...) */
	uint8_t w;			/* total width */
	uint8_t nruns;
	uint16_t run0;			/* first run, msb first */
};
#define ESUB 0xFE

struct eform {
	uint8_t n;			/* parcels */
	uint8_t nspecs;
	uint16_t spec0;			/* first entry in the form-spec pool: indexes into the spec pool, one per operand */
	uint16_t nmn, mn0;		/* the mnemonics of the form, in order: ids in the form-mnemonic pool */
	const char *name;
};

struct eleaf {
	uint16_t form;
	uint16_t off, nmn;		/* the mnemonics form.mn[off .. off+nmn-1] are the leaf's; the sub-opcode field selects one */
	uint16_t prefix;
	uint8_t L;			/* the prefix is the top L bits of parcel 0 */
	uint16_t pl0, npl;		/* the placement of the fields in the eplace pool */
};

struct ecand { uint16_t form, leaf, k; };	/* a way to encode a mnemonic: the form, the leaf in it, the sub-opcode value */

struct emn { const char *name; uint8_t msz; uint16_t cand0, ncand; };

struct etab {
	const char *name;		/* "pdp64/16" */
	int regs;			/* 16 or 32 */
	int nmn, nforms, nleaves, nspecs;
	const struct emn *mn;		/* sorted by name */
	const struct eform *forms;
	const struct espec *specs;
	const uint16_t *formspec;
	const uint16_t *formmn;
	const uint8_t *hot;
	const struct eleaf *leaves;
	const struct eplace *place;
	const struct erun *runs;
	const struct ecand *cands;
	uint16_t *lut;			/* parcel 0 -> leaf index + 1, 0 for an illegal pattern (built by enc_init) */
};
extern struct etab enc_tab_16, enc_tab_32;

/* ---- the codec ------------------------------------------------------------------------------------------------------ */
void enc_init(const struct etab *t);			/* builds the length/leaf table; the other calls do it on first use */
int enc_mn_find(const struct etab *t, const char *name);	/* -1 if the table has no such mnemonic */
const char *enc_mn_name(const struct etab *t, int mn);

/* Encode: the first form, in order of length then of the table, in which every operand fits.  Returns the number of parcels (1, 2, 3, 5), 0 if no form
   takes the instruction.  The parcels are written as 16-bit values (not yet byte-swapped).  *form and *leaf (if not NULL) name the choice. */
int enc_encode(const struct etab *t, const struct einsn *in, uint16_t *par, int *form, int *leaf);
/* The length in parcels of the shortest form (0: none): the same search without producing bits */
int enc_len(const struct etab *t, const struct einsn *in);

/* Decode one instruction from parcels p[0..np-1].  Returns the number of parcels, 0 for an illegal pattern, -1 if np is too small (*need set to the
   parcels required, known from p[0]). */
int enc_decode(const struct etab *t, const uint16_t *p, int np, struct einsn *out, int *need);
/* The length in parcels from parcel 0 alone; 0: an illegal pattern */
int enc_len_p0(const struct etab *t, uint16_t p0);

/* ---- relocation fields (ld64, as64) ------------------------------------------------------------------------------- */
struct efield {
	int kind;			/* ES_PC, ES_A or ES_I */
	int w;				/* width in bits */
	int unit;			/* ES_PC: bytes per unit of the field (1 or 2); 1 for the others */
	int sgn;
	int nparcels;			/* the instruction's length */
	int nruns;
	struct erun run[8];		/* msb first */
};
/* Find the operand of the instruction at p (parcels, already native values) that a relocation of this kind patches: the first ES_PC operand
   (want = ES_PC) or the first ES_A or ES_I operand of 32 bits or more (want = ES_A).  Returns 0 and fills *f, or -1 (illegal, or no such operand). */
int enc_reloc_field(const struct etab *t, const uint16_t *p, int np, int want, struct efield *f);
/* Insert the low f->w bits of q into the parcels; extract (sign-extended if f->sgn). */
void enc_field_put(const struct efield *f, uint16_t *p, uint64_t q);
int64_t enc_field_get(const struct efield *f, const uint16_t *p);

/* little-endian bytes <-> parcels */
static inline uint16_t enc_ld16(const uint8_t *b) { return (uint16_t)(b[0] | (b[1] << 8)); }
static inline void enc_st16(uint8_t *b, uint16_t v) { b[0] = v & 0xFF; b[1] = v >> 8; }
#endif

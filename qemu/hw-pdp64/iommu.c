/*
 * pdp64-iommu: the IOMMU of the pdp64 in the QEMU model (manual 2.11.1 to 2.11.11; docs/encoding-work/iommu-proposals.md; errata 187, 190, 194).
 *
 * One unit at the root complex (a sysbus device: its register block is in the root complex's own block, not a PCI Express function), attached to the
 * host bridge with pci_setup_iommu(): QEMU asks for an address space for each function and the unit gives it an IOMMU memory region whose translate
 * method is the unit.  All the numbers (the registers, bits, entry fields, commands and causes) are the generated constants of pdp64-consts.h
 * (spec/grammars.d/51-iommu-v1.hbnf).
 *
 *   - The device table: a mode (blocked at reset, one level or two levels), a directory of 512 entries of 8 bytes and leaf pages of 128 device entries of
 *     32 bytes.  The device entry has V, MUTE, the stages (A, B, A then B), the levels of each, the domain and guest tags, two roots and a reserved word.
 *   - The leaf entry is the processor's page-table entry: V, R, W and the page number are used; W requires R; X, U, G and the memory type must be zero;
 *     A and D are ignored; leaves of level 1 and 2 are 2 MB and 1 GB pages; 3, 4 or 5 levels.  The unit never writes a table.
 *   - A refused read is answered with an error (the access fails with a decode error, which the device model sees as an error completion); a refused
 *     posted write is dropped and counted.  Every refusal is logged in the fault ring (unless the device is muted or logging is off), with the interrupt,
 *     the sticky overflow bit and count.  A table that cannot be read fails closed: the access is refused, the sticky table-error bit is set.
 *   - The unit's own cache of device entries and translations, keyed by (requester identity, guest tag, domain tag, page, level), is filled on every
 *     translation and emptied only by the commands (invalidate device, domain, guest, all), by a change of the device-table pointer, by the reset bit and
 *     by reset: so an entry that was changed in memory and not invalidated is still used, and a MISSING invalidate is observable.  (The architecture
 *     allows the unit to discard more at any time; the model discards exactly what it is told to, and everything when the cache holds too much.)
 *   - Commands come through the command ring (DOORBELL) and through the invalidate register (INV0, INV1) to one executor.  The executor is synchronous:
 *     the device models of QEMU do their DMA synchronously, so no request of a device is ever in flight while a command runs; "invalidate device does not
 *     complete before the device's requests in flight are finished or refused" holds trivially and cannot be tested here.  The guard that blocks a device
 *     whose guest is being invalidated is a flag held for the duration of the invalidation, which a synchronous executor never lets a device see.
 *   - The interrupt is a wired line to the processor (VECTOR_IOMMU), asserted while logging interrupts are enabled and the fault ring is not empty or
 *     overflow or table-error is set.
 * The model has no hypervisor mode: a test plays both the guest's and the hypervisor's roles (the unit's two levels are tested as such).
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/units.h"
#include "qapi/error.h"
#include "hw/core/irq.h"
#include "hw/core/sysbus.h"
#include "hw/core/qdev-properties.h"
#include "hw/pci/pci.h"
#include "hw/pci/pci_bus.h"
#include "system/memory.h"
#include "system/address-spaces.h"
#include "system/dma.h"
#include "migration/vmstate.h"
#include "target/pdp64/gen/pdp64-consts.h"

#define TYPE_PDP64_IOMMU "pdp64-iommu"
OBJECT_DECLARE_SIMPLE_TYPE(PDP64IOMMUState, PDP64_IOMMU)
#define TYPE_PDP64_IOMMU_MR "pdp64-iommu-memory-region"

#define PTE_BIT(n)      (1ULL << PTE_##n)
#define PTE_MASK(n)     (((1ULL << PTE_WIDTH_##n) - 1) << PTE_##n)
#define PA_LIMIT        (1ULL << MMU_PA_BITS)
#define PAGE            (1ULL << IOMMU_TABLE_PAGE_BITS)

typedef struct PDP64IOMMUSpace PDP64IOMMUSpace;

/* a device entry, decoded (only a good one is cached) */
typedef struct Dte {
    bool mute;
    unsigned stages, levels_a, levels_b;
    uint16_t domain, guest;
    uint64_t root_a, root_b;
} Dte;

/* the key of a cached translation: no padding, so the whole key is compared and hashed */
typedef struct IotKey {
    uint64_t page;              /* the device address >> (12 + 9 * level) */
    uint32_t rid;
    uint32_t tags;              /* guest << 16 | domain */
    uint32_t level;
    uint32_t zero;
} IotKey;

typedef struct IotVal {
    uint64_t pa;                /* the physical address of the page */
    uint64_t gpa;               /* the guest-physical address of the page (for a level-B refusal's record) */
    int perm_a, perm_b;         /* the rights of each stage, IOMMU_RO | IOMMU_WO; a stage that is not used allows all */
} IotVal;

/* a refusal */
typedef struct Fault {
    unsigned cause, stage;
    uint64_t gpa;
} Fault;

struct PDP64IOMMUSpace {
    IOMMUMemoryRegion mr;
    AddressSpace as;
    PDP64IOMMUState *s;
    PCIBus *bus;
    int devfn;
    QLIST_ENTRY(PDP64IOMMUSpace) next;
};

struct PDP64IOMMUState {
    SysBusDevice parent_obj;

    MemoryRegion iomem;
    qemu_irq irq;
    PCIBus *bus;                /* the root bus (a link property) */
    MemoryRegion abort_mr;      /* where a refused access goes: it answers every access with an error (below) */
    AddressSpace abort_as;

    uint64_t control, status, ring_base, ring_size, tail, device, cmd_head;
    uint64_t fault_base, fault_size, fault_head, fault_tail, fault_dropped;
    uint64_t inv0, refused_reads, dropped_writes;

    GHashTable *entries;        /* requester identity -> Dte */
    GHashTable *iotlb;          /* IotKey -> IotVal */
    bool guard;                 /* an invalidate guest is executing ... */
    uint16_t guard_guest;       /* ... for this guest tag */

    QLIST_HEAD(, PDP64IOMMUSpace) spaces;
};

static inline uint64_t fld(uint64_t v, unsigned pos, unsigned width)
{
    return (v >> pos) & ((1ULL << width) - 1);
}

static inline bool is_pow2(uint64_t v)
{
    return v && !(v & (v - 1));
}

/* ---- memory the unit reads and writes: it must be RAM (a table that points at a device window fails closed) ---- */

static bool ram_ok(hwaddr addr, bool write)
{
    MemoryRegion *mr;
    hwaddr xlat, l = 8;

    if (addr & 7) {
        return false;
    }
    RCU_READ_LOCK_GUARD();
    mr = address_space_translate(&address_space_memory, addr, &xlat, &l, write, MEMTXATTRS_UNSPECIFIED);
    return memory_region_is_ram(mr) && l >= 8;
}

static bool read_u64(hwaddr addr, uint64_t *v)
{
    MemTxResult r;

    if (!ram_ok(addr, false)) {
        return false;
    }
    *v = address_space_ldq_le(&address_space_memory, addr, MEMTXATTRS_UNSPECIFIED, &r);
    return r == MEMTX_OK;
}

static bool write_u64(hwaddr addr, uint64_t v)
{
    MemTxResult r;

    if (!ram_ok(addr, true)) {
        return false;
    }
    address_space_stq_le(&address_space_memory, addr, v, MEMTXATTRS_UNSPECIFIED, &r);
    return r == MEMTX_OK;
}

/* ---- the interrupt line ---- */

static bool ring_pending(PDP64IOMMUState *s)
{
    return s->fault_tail != s->fault_head;
}

static void update_irq(PDP64IOMMUState *s)
{
    bool on = (s->control & BIT(IOMMU_CONTROL_FAULT_IRQ))
              && (ring_pending(s) || (s->status & (BIT(IOMMU_STATUS_OVERFLOW) | BIT(IOMMU_STATUS_TABLE_ERROR))));

    qemu_set_irq(s->irq, on);
}

/* ---- the cache ---- */

static guint iot_hash(gconstpointer p)
{
    const IotKey *k = p;

    return (guint)(k->page * 0x9e3779b97f4a7c15ULL >> 32) ^ k->rid * 2654435761u ^ k->tags ^ k->level;
}

static gboolean iot_equal(gconstpointer a, gconstpointer b)
{
    return memcmp(a, b, sizeof(IotKey)) == 0;
}

static unsigned level_shift(unsigned level)
{
    return IOMMU_TABLE_PAGE_BITS + MMU_LEVEL_BITS * level;
}

/* tell QEMU's own users of the translation (notifiers) that it is gone */
static void notify_unmap(PDP64IOMMUState *s, const IotKey *k)
{
    PDP64IOMMUSpace *sp;
    IOMMUTLBEvent ev;

    QLIST_FOREACH(sp, &s->spaces, next) {
        if (((pci_bus_num(sp->bus) << 8) | sp->devfn) == k->rid) {
            ev.type = IOMMU_NOTIFIER_UNMAP;
            ev.entry.target_as = &address_space_memory;
            ev.entry.iova = k->page << level_shift(k->level);
            ev.entry.translated_addr = 0;
            ev.entry.addr_mask = (1ULL << level_shift(k->level)) - 1;
            ev.entry.perm = IOMMU_NONE;
            memory_region_notify_iommu(&sp->mr, 0, ev);
        }
    }
}

typedef struct Drop {
    PDP64IOMMUState *s;
    unsigned op;
    uint32_t rid;
    uint16_t domain, guest;
} Drop;

static bool drop_iot(Drop *d, const IotKey *k)
{
    switch (d->op) {
    case IOMMU_OP_INV_DEVICE: return k->rid == d->rid;
    case IOMMU_OP_INV_DOMAIN: return (k->tags & 0xffff) == d->domain;
    case IOMMU_OP_INV_GUEST:  return (k->tags >> 16) == d->guest;
    default:                  return true;              /* inv-all, reset, a change of the device-table pointer */
    }
}

static gboolean drop_iot_cb(gpointer key, gpointer val, gpointer user)
{
    Drop *d = user;

    if (drop_iot(d, key)) {
        notify_unmap(d->s, key);
        return TRUE;
    }
    return FALSE;
}

static gboolean drop_dte_cb(gpointer key, gpointer val, gpointer user)
{
    Drop *d = user;
    const Dte *e = val;

    switch (d->op) {
    case IOMMU_OP_INV_DEVICE: return GPOINTER_TO_UINT(key) == d->rid;
    case IOMMU_OP_INV_DOMAIN: return e->domain == d->domain;
    case IOMMU_OP_INV_GUEST:  return e->guest == d->guest;
    default:                  return TRUE;
    }
}

static void cache_drop(PDP64IOMMUState *s, unsigned op, uint32_t rid, uint16_t domain, uint16_t guest)
{
    Drop d = { s, op, rid, domain, guest };

    g_hash_table_foreach_remove(s->iotlb, drop_iot_cb, &d);
    g_hash_table_foreach_remove(s->entries, drop_dte_cb, &d);
}

static void cache_drop_all(PDP64IOMMUState *s)
{
    cache_drop(s, IOMMU_OP_INV_ALL, 0, 0, 0);
}

/* ---- the fault ring ---- */

static void log_fault(PDP64IOMMUState *s, uint32_t rid, const Dte *e, uint64_t iova, bool write, const Fault *f)
{
    uint64_t next, base, w0;

    if (write) {
        s->dropped_writes++;
    } else {
        s->refused_reads++;
    }
    if ((e && e->mute) || !(s->control & BIT(IOMMU_CONTROL_FAULT_ENABLE))) {
        return;                                         /* refused, counted, not logged */
    }
    if (!is_pow2(s->fault_size)) {
        return;                                         /* no ring */
    }
    next = (s->fault_tail + 1) & (s->fault_size - 1);
    if (next == s->fault_head) {                        /* full: nothing is written, the loss is remembered */
        s->status |= BIT(IOMMU_STATUS_OVERFLOW);
        s->fault_dropped++;
        update_irq(s);
        return;
    }
    base = s->fault_base + s->fault_tail * IOMMU_FAULT_BYTES_SIZE;
    w0 = (uint64_t)f->cause << IOMMU_FAULT_CAUSE | (uint64_t)f->stage << IOMMU_FAULT_STAGE
         | (uint64_t)write << IOMMU_FAULT_WRITE | BIT(IOMMU_FAULT_VALID)
         | (s->fault_dropped ? BIT(IOMMU_FAULT_OVERFLOW) : 0);
    if (!write_u64(base + IOMMU_FAULT_WORD_INFO, w0)
        || !write_u64(base + IOMMU_FAULT_WORD_WHO, (uint64_t)rid << IOMMU_FAULT_WHO_RID | (uint64_t)(e ? e->guest : 0) << IOMMU_FAULT_WHO_GUEST)
        || !write_u64(base + IOMMU_FAULT_WORD_IOVA, iova)
        || !write_u64(base + IOMMU_FAULT_WORD_GPA, f->stage == IOMMU_STAGE_B ? f->gpa : 0)) {
        s->status |= BIT(IOMMU_STATUS_TABLE_ERROR);     /* the ring itself cannot be written */
        update_irq(s);
        return;
    }
    s->fault_tail = next;                               /* the record first, then the tail, then the interrupt (5.10.3) */
    update_irq(s);
}

/* ---- the walks ---- */

/* the result of walking a stage: the physical (or guest-physical) address of the page, its size as a level, the rights */
typedef struct Leaf {
    uint64_t pa;
    unsigned level;
    int perm;
} Leaf;

static void set_fault(Fault *f, unsigned cause, unsigned stage, uint64_t gpa)
{
    f->cause = cause;
    f->stage = stage;
    f->gpa = gpa;
}

/* walk one stage: root is a physical address (the top table), addr the address to translate.  With `through_b` (stage A of A then B) every table pointer is a
   guest-physical address and goes through the level-B walk before it is read. */
static bool walk(PDP64IOMMUState *s, const Dte *e, unsigned stage, uint64_t root, unsigned levels, uint64_t addr,
                 bool through_b, Leaf *out, Fault *f);

static bool walk_b_read(PDP64IOMMUState *s, const Dte *e, uint64_t gpa, uint64_t *v, Fault *f)
{
    Leaf lb;

    if (!walk(s, e, IOMMU_STAGE_B, e->root_b, e->levels_b, gpa, false, &lb, f)) {
        return false;
    }
    if (!(lb.perm & IOMMU_RO)) {
        set_fault(f, IOMMU_CAUSE_NO_READ, IOMMU_STAGE_B, gpa);
        return false;
    }
    if (!read_u64(lb.pa | (gpa & ((1ULL << level_shift(lb.level)) - 1)), v)) {
        set_fault(f, IOMMU_CAUSE_TABLE_READ, IOMMU_STAGE_B, gpa);
        s->status |= BIT(IOMMU_STATUS_TABLE_ERROR);
        return false;
    }
    return true;
}

static bool walk(PDP64IOMMUState *s, const Dte *e, unsigned stage, uint64_t root, unsigned levels, uint64_t addr,
                 bool through_b, Leaf *out, Fault *f)
{
    uint64_t table = root;
    int level;

    if (addr >> (IOMMU_TABLE_PAGE_BITS + MMU_LEVEL_BITS * levels)) {
        set_fault(f, IOMMU_CAUSE_RANGE, stage, stage == IOMMU_STAGE_B ? addr : 0);
        return false;
    }
    for (level = levels - 1; level >= 0; level--) {
        uint64_t idx = (addr >> level_shift(level)) & ((1u << MMU_LEVEL_BITS) - 1);
        uint64_t pte, ppn_addr;
        bool ok;

        if (through_b) {
            ok = walk_b_read(s, e, table + idx * 8, &pte, f);
        } else {
            ok = read_u64(table + idx * 8, &pte);
            if (!ok) {
                set_fault(f, IOMMU_CAUSE_TABLE_READ, stage, stage == IOMMU_STAGE_B ? addr : 0);
                s->status |= BIT(IOMMU_STATUS_TABLE_ERROR);
            }
        }
        if (!ok) {
            return false;
        }
        if (!(pte & PTE_BIT(V))) {
            set_fault(f, IOMMU_CAUSE_NO_MAPPING, stage, stage == IOMMU_STAGE_B ? addr : 0);
            return false;
        }
        /* X, U, G, the memory type, bits 10 and 11 and bits 40 to 63 must be zero; A and D are ignored */
        if (pte & ~(PTE_BIT(V) | PTE_BIT(R) | PTE_BIT(W) | PTE_BIT(A) | PTE_BIT(D) | PTE_MASK(PPN))) {
            set_fault(f, IOMMU_CAUSE_BAD_PTE, stage, stage == IOMMU_STAGE_B ? addr : 0);
            return false;
        }
        ppn_addr = ((pte & PTE_MASK(PPN)) >> PTE_PPN) << IOMMU_TABLE_PAGE_BITS;
        if (pte & (PTE_BIT(R) | PTE_BIT(W))) {          /* a leaf */
            if ((pte & PTE_BIT(W)) && !(pte & PTE_BIT(R))) {
                set_fault(f, IOMMU_CAUSE_BAD_PTE, stage, stage == IOMMU_STAGE_B ? addr : 0);
                return false;
            }
            if (level > 2 || (ppn_addr & ((1ULL << level_shift(level)) - 1))) {    /* a leaf is a 4 KB, 2 MB or 1 GB page, aligned to its size */
                set_fault(f, IOMMU_CAUSE_BAD_PTE, stage, stage == IOMMU_STAGE_B ? addr : 0);
                return false;
            }
            out->pa = ppn_addr;
            out->level = level;
            out->perm = ((pte & PTE_BIT(R)) ? IOMMU_RO : 0) | ((pte & PTE_BIT(W)) ? IOMMU_WO : 0);
            return true;
        }
        if (level == 0) {                               /* a pointer where nothing is left to point to */
            set_fault(f, IOMMU_CAUSE_NO_MAPPING, stage, stage == IOMMU_STAGE_B ? addr : 0);
            return false;
        }
        table = ppn_addr;
    }
    return false;
}

/* ---- the device table ---- */

static bool dte_decode(const uint64_t w[4], Dte *e)
{
    uint64_t w0 = w[0];
    uint64_t known = BIT(IOMMU_DTE_V) | BIT(IOMMU_DTE_MUTE)
        | (((1ULL << IOMMU_DTE_WIDTH_STAGES) - 1) << IOMMU_DTE_STAGES)
        | (((1ULL << IOMMU_DTE_WIDTH_LEVELS_A) - 1) << IOMMU_DTE_LEVELS_A)
        | (((1ULL << IOMMU_DTE_WIDTH_LEVELS_B) - 1) << IOMMU_DTE_LEVELS_B)
        | (((1ULL << IOMMU_DTE_WIDTH_DOMAIN) - 1) << IOMMU_DTE_DOMAIN)
        | (((1ULL << IOMMU_DTE_WIDTH_GUEST) - 1) << IOMMU_DTE_GUEST);

    if (w0 & ~known || w[3]) {
        return false;                                   /* a reserved bit is set */
    }
    e->mute = w0 >> IOMMU_DTE_MUTE & 1;
    e->stages = fld(w0, IOMMU_DTE_STAGES, IOMMU_DTE_WIDTH_STAGES);
    e->levels_a = fld(w0, IOMMU_DTE_LEVELS_A, IOMMU_DTE_WIDTH_LEVELS_A);
    e->levels_b = fld(w0, IOMMU_DTE_LEVELS_B, IOMMU_DTE_WIDTH_LEVELS_B);
    e->domain = fld(w0, IOMMU_DTE_DOMAIN, IOMMU_DTE_WIDTH_DOMAIN);
    e->guest = fld(w0, IOMMU_DTE_GUEST, IOMMU_DTE_WIDTH_GUEST);
    e->root_a = w[1];
    e->root_b = w[2];
    if (e->stages != IOMMU_STAGES_A && e->stages != IOMMU_STAGES_B && e->stages != IOMMU_STAGES_A_THEN_B) {
        return false;
    }
    if (e->stages & IOMMU_STAGES_A) {                   /* the bit of stage A is bit 0 of the stages value, the bit of stage B bit 1 */
        if (e->levels_a < IOMMU_TABLE_MIN_LEVELS || e->levels_a > IOMMU_TABLE_MAX_LEVELS
            || (e->root_a & (PAGE - 1)) || e->root_a >= PA_LIMIT) {
            return false;
        }
    }
    if (e->stages & IOMMU_STAGES_B) {
        if (e->levels_b < IOMMU_TABLE_MIN_LEVELS || e->levels_b > IOMMU_TABLE_MAX_LEVELS
            || (e->root_b & (PAGE - 1)) || e->root_b >= PA_LIMIT) {
            return false;
        }
    }
    return true;
}

/* find the device entry of a requester identity: the cache, else the table.  On a refusal fills f; `*e` is the entry (cached) */
static const Dte *dte_find(PDP64IOMMUState *s, uint32_t rid, Fault *f)
{
    unsigned mode = fld(s->device, IOMMU_DEVICE_MODE, IOMMU_DEVICE_WIDTH_MODE);
    uint64_t leaf_page, w[4], dir;
    Dte *e = g_hash_table_lookup(s->entries, GUINT_TO_POINTER(rid));
    int i;

    if (e) {
        return e;
    }
    if (mode == IOMMU_MODE_TWO_LEVEL) {
        uint64_t da = (((s->device >> IOMMU_DEVICE_PPN) & ((1ULL << PTE_WIDTH_PPN) - 1)) << IOMMU_TABLE_PAGE_BITS)
                      + (uint64_t)(rid >> IOMMU_TABLE_LEAF_BITS) * IOMMU_TABLE_DIR_ENTRY_BYTES;

        if (!read_u64(da, &dir)) {
            set_fault(f, IOMMU_CAUSE_TABLE_READ, IOMMU_STAGE_TABLE, 0);
            s->status |= BIT(IOMMU_STATUS_TABLE_ERROR);
            return NULL;
        }
        if (!(dir & BIT(IOMMU_DIR_V))) {
            set_fault(f, IOMMU_CAUSE_NO_ENTRY, IOMMU_STAGE_TABLE, 0);
            return NULL;
        }
        if (dir & ~(BIT(IOMMU_DIR_V) | PTE_MASK(PPN))) {
            set_fault(f, IOMMU_CAUSE_BAD_ENTRY, IOMMU_STAGE_TABLE, 0);
            return NULL;
        }
        leaf_page = ((dir & PTE_MASK(PPN)) >> PTE_PPN) << IOMMU_TABLE_PAGE_BITS;
    } else if (mode == IOMMU_MODE_ONE_LEVEL) {
        if (rid >> IOMMU_TABLE_LEAF_BITS) {             /* one level covers 7 bits of identity */
            set_fault(f, IOMMU_CAUSE_NO_ENTRY, IOMMU_STAGE_TABLE, 0);
            return NULL;
        }
        leaf_page = ((s->device >> IOMMU_DEVICE_PPN) & ((1ULL << PTE_WIDTH_PPN) - 1)) << IOMMU_TABLE_PAGE_BITS;
    } else {
        set_fault(f, IOMMU_CAUSE_BLOCKED, IOMMU_STAGE_TABLE, 0);
        return NULL;
    }
    for (i = 0; i < 4; i++) {
        if (!read_u64(leaf_page + (uint64_t)(rid & (IOMMU_TABLE_LEAF_ENTRIES - 1)) * IOMMU_TABLE_LEAF_ENTRY_BYTES + i * 8, &w[i])) {
            set_fault(f, IOMMU_CAUSE_TABLE_READ, IOMMU_STAGE_TABLE, 0);
            s->status |= BIT(IOMMU_STATUS_TABLE_ERROR);
            return NULL;
        }
    }
    if (!(w[0] & BIT(IOMMU_DTE_V))) {
        set_fault(f, IOMMU_CAUSE_NO_ENTRY, IOMMU_STAGE_TABLE, 0);
        return NULL;
    }
    e = g_new0(Dte, 1);
    if (!dte_decode(w, e)) {
        /* a bad entry is refused, and the guest tag and the mute bit, if they can be read, still count: the entry is not cached */
        g_free(e);
        set_fault(f, IOMMU_CAUSE_BAD_ENTRY, IOMMU_STAGE_TABLE, 0);
        return NULL;
    }
    g_hash_table_insert(s->entries, GUINT_TO_POINTER(rid), e);
    return e;
}

/* ---- one translation ---- */

typedef struct Xlat {
    uint64_t pa;                /* the physical address of the page */
    uint64_t gpa;               /* the guest-physical address of the page */
    unsigned level;
    int perm_a, perm_b;
} Xlat;

static bool translate_walk(PDP64IOMMUState *s, const Dte *e, uint64_t iova, Xlat *x, Fault *f)
{
    Leaf la, lb;
    uint64_t gpa, mask;
    unsigned lvl;

    if (e->stages == IOMMU_STAGES_A) {
        if (!walk(s, e, IOMMU_STAGE_A, e->root_a, e->levels_a, iova, false, &la, f)) {
            return false;
        }
        x->pa = la.pa;
        x->gpa = 0;
        x->level = la.level;
        x->perm_a = la.perm;
        x->perm_b = IOMMU_RW;
        return true;
    }
    if (e->stages == IOMMU_STAGES_B) {                  /* the device address is a guest-physical address */
        if (!walk(s, e, IOMMU_STAGE_B, e->root_b, e->levels_b, iova, false, &lb, f)) {
            return false;
        }
        x->pa = lb.pa;
        x->gpa = iova & ~((1ULL << level_shift(lb.level)) - 1);
        x->level = lb.level;
        x->perm_a = IOMMU_RW;
        x->perm_b = lb.perm;
        return true;
    }
    /* A then B: level A (its table pointers are guest-physical: each goes through level B), then level B for the final guest-physical address */
    if (!walk(s, e, IOMMU_STAGE_A, e->root_a, e->levels_a, iova, true, &la, f)) {
        return false;
    }
    gpa = la.pa | (iova & ((1ULL << level_shift(la.level)) - 1));
    if (!walk(s, e, IOMMU_STAGE_B, e->root_b, e->levels_b, gpa, false, &lb, f)) {
        return false;
    }
    lvl = la.level < lb.level ? la.level : lb.level;    /* the page of the cached translation is the smaller of the two */
    mask = (1ULL << level_shift(lvl)) - 1;
    x->pa = (lb.pa | (gpa & ((1ULL << level_shift(lb.level)) - 1))) & ~mask;
    x->gpa = gpa & ~mask;
    x->level = lvl;
    x->perm_a = la.perm;
    x->perm_b = lb.perm;
    return true;
}

/* translate for a function; returns the page (physical address, level, rights), or false with a logged refusal */
static bool unit_translate(PDP64IOMMUState *s, uint32_t rid, uint64_t iova, IOMMUAccessFlags flag, int idx, Xlat *x)
{
    bool write = flag & IOMMU_WO;
    bool probe = (flag & (IOMMU_RO | IOMMU_WO)) == IOMMU_NONE;      /* not an access: nothing to refuse, nothing to log */
    const Dte *e = NULL;
    Fault f = { 0 };
    int level;
    IotKey k;
    IotVal *v;

    if (idx != 0) {                                     /* a translated request: no translation requests in version 1 (2.11.9) */
        set_fault(&f, IOMMU_CAUSE_ATS, IOMMU_STAGE_TABLE, 0);
        goto refuse;
    }
    e = dte_find(s, rid, &f);
    if (!e) {
        goto refuse;
    }
    if (s->guard && e->guest == s->guard_guest) {
        set_fault(&f, IOMMU_CAUSE_GUARD, IOMMU_STAGE_TABLE, 0);
        goto refuse;
    }
    memset(&k, 0, sizeof(k));
    k.rid = rid;
    k.tags = (uint32_t)e->guest << 16 | e->domain;
    for (level = 0; level < 3; level++) {                /* a leaf is a page of 4 KB, 2 MB or 1 GB */
        k.level = level;
        k.page = iova >> level_shift(level);
        v = g_hash_table_lookup(s->iotlb, &k);
        if (v) {
            x->pa = v->pa;
            x->gpa = v->gpa;
            x->level = level;
            x->perm_a = v->perm_a;
            x->perm_b = v->perm_b;
            goto have;
        }
    }
    if (!translate_walk(s, e, iova, x, &f)) {
        goto refuse;
    }
    if (g_hash_table_size(s->iotlb) >= 4096) {          /* too much: the unit may discard at any time */
        g_hash_table_remove_all(s->iotlb);
    }
    memset(&k, 0, sizeof(k));
    k.rid = rid;
    k.tags = (uint32_t)e->guest << 16 | e->domain;
    k.level = x->level;
    k.page = iova >> level_shift(x->level);
    v = g_new0(IotVal, 1);
    v->pa = x->pa;
    v->gpa = x->gpa;
    v->perm_a = x->perm_a;
    v->perm_b = x->perm_b;
    g_hash_table_insert(s->iotlb, g_memdup2(&k, sizeof(k)), v);
have:
    if (!probe) {
        int need = write ? IOMMU_WO : IOMMU_RO;

        if (!(x->perm_a & need)) {
            set_fault(&f, write ? IOMMU_CAUSE_NO_WRITE : IOMMU_CAUSE_NO_READ, e->stages == IOMMU_STAGES_B ? IOMMU_STAGE_B : IOMMU_STAGE_A, 0);
            goto refuse;
        }
        if (!(x->perm_b & need)) {
            set_fault(&f, write ? IOMMU_CAUSE_NO_WRITE : IOMMU_CAUSE_NO_READ, IOMMU_STAGE_B, x->gpa | (iova & ((1ULL << level_shift(x->level)) - 1)));
            goto refuse;
        }
    }
    return true;

refuse:
    if (!probe) {
        log_fault(s, rid, e, iova, write, &f);
        update_irq(s);
    }
    return false;
}

/* A refused access is not left to QEMU's "unassigned" region: that one takes accesses of at most four bytes, so one refused transfer of eight bytes would be
   translated, refused and logged twice.  The refusal is logged once, when the unit refuses (unit_translate); the access then goes on to this region, which answers it
   with an error (a read gets the error completion, no data; the device model sees MEMTX_ERROR) and drops the write: a transaction is refused once. */
static MemTxResult abort_read(void *opaque, hwaddr addr, uint64_t *data, unsigned size, MemTxAttrs attrs)
{
    *data = 0;
    return MEMTX_ERROR;
}

static MemTxResult abort_write(void *opaque, hwaddr addr, uint64_t data, unsigned size, MemTxAttrs attrs)
{
    return MEMTX_ERROR;
}

static const MemoryRegionOps abort_ops = {
    .read_with_attrs = abort_read,
    .write_with_attrs = abort_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = { .min_access_size = 1, .max_access_size = 8 },
};

static IOMMUTLBEntry space_translate(IOMMUMemoryRegion *mr, hwaddr addr, IOMMUAccessFlags flag, int iommu_idx)
{
    PDP64IOMMUSpace *sp = container_of(mr, PDP64IOMMUSpace, mr);
    uint32_t rid = (pci_bus_num(sp->bus) << 8) | sp->devfn;
    IOMMUTLBEntry ent = { .target_as = &address_space_memory, .iova = addr & ~(PAGE - 1), .translated_addr = 0,
                          .addr_mask = PAGE - 1, .perm = IOMMU_NONE };
    Xlat x;

    if (unit_translate(sp->s, rid, addr, flag, iommu_idx, &x)) {
        uint64_t mask = (1ULL << level_shift(x.level)) - 1;

        ent.iova = addr & ~mask;
        ent.translated_addr = x.pa;
        ent.addr_mask = mask;
        ent.perm = x.perm_a & x.perm_b;
    } else if (flag & IOMMU_RW) {                       /* refused (and logged): on to the region that answers with an error */
        ent.target_as = &sp->s->abort_as;
        ent.perm = IOMMU_RW;
    }
    return ent;
}

static int space_attrs_to_index(IOMMUMemoryRegion *mr, MemTxAttrs attrs)
{
    return attrs.address_type ? 1 : 0;                  /* index 1: a request that says it is already translated */
}

static int space_num_indexes(IOMMUMemoryRegion *mr)
{
    return 2;
}

static void space_class_init(ObjectClass *klass, const void *data)
{
    IOMMUMemoryRegionClass *imrc = IOMMU_MEMORY_REGION_CLASS(klass);

    imrc->translate = space_translate;
    imrc->attrs_to_index = space_attrs_to_index;
    imrc->num_indexes = space_num_indexes;
}

static const TypeInfo space_info = {
    .name = TYPE_PDP64_IOMMU_MR,
    .parent = TYPE_IOMMU_MEMORY_REGION,
    .class_init = space_class_init,
};

static AddressSpace *iommu_get_address_space(PCIBus *bus, void *opaque, int devfn)
{
    PDP64IOMMUState *s = opaque;
    PDP64IOMMUSpace *sp;

    QLIST_FOREACH(sp, &s->spaces, next) {
        if (sp->bus == bus && sp->devfn == devfn) {
            return &sp->as;
        }
    }
    sp = g_new0(PDP64IOMMUSpace, 1);
    sp->s = s;
    sp->bus = bus;
    sp->devfn = devfn;
    memory_region_init_iommu(&sp->mr, sizeof(sp->mr), TYPE_PDP64_IOMMU_MR, OBJECT(s), "pdp64-iommu", UINT64_MAX);
    address_space_init(&sp->as, MEMORY_REGION(&sp->mr), "pdp64-iommu-as");
    QLIST_INSERT_HEAD(&s->spaces, sp, next);
    return &sp->as;
}

static const PCIIOMMUOps iommu_ops = {
    .get_address_space = iommu_get_address_space,
};

/* ---- the commands ---- */

static bool command_exec(PDP64IOMMUState *s, uint64_t w0, uint64_t w1)
{
    unsigned op = fld(w0, IOMMU_CMD_OP, IOMMU_CMD_WIDTH_OP);
    uint32_t rid = fld(w0, IOMMU_CMD_RID, IOMMU_CMD_WIDTH_RID);
    uint16_t domain = fld(w0, IOMMU_CMD_DOMAIN, IOMMU_CMD_WIDTH_DOMAIN);
    uint16_t guest = fld(w0, IOMMU_CMD_GUEST, IOMMU_CMD_WIDTH_GUEST);

    switch (op) {
    case IOMMU_OP_NOP:
        return true;
    case IOMMU_OP_INV_DEVICE:
    case IOMMU_OP_INV_DOMAIN:
    case IOMMU_OP_INV_ALL:
        cache_drop(s, op, rid, domain, guest);
        return true;
    case IOMMU_OP_INV_GUEST:
        s->guard = true;                                /* the devices of the guest are blocked until the invalidation is complete */
        s->guard_guest = guest;
        cache_drop(s, op, rid, domain, guest);
        s->guard = false;
        return true;
    case IOMMU_OP_SYNC:                                 /* every earlier command has taken effect (the executor is synchronous): say so in memory */
        return write_u64(w1, IOMMU_CMD_BYTES_SYNC_VALUE);
    default:
        return false;
    }
}

static void command_run(PDP64IOMMUState *s, uint64_t w0, uint64_t w1)
{
    if (!command_exec(s, w0, w1)) {
        s->status |= BIT(IOMMU_STATUS_CMD_ERROR);
    }
}

static void ring_run(PDP64IOMMUState *s)
{
    if (!(s->control & BIT(IOMMU_CONTROL_CMD_ENABLE)) || !is_pow2(s->ring_size)) {
        return;
    }
    while (s->cmd_head != s->tail) {
        uint64_t a = s->ring_base + s->cmd_head * IOMMU_CMD_BYTES_SIZE, w0, w1;

        if (!read_u64(a, &w0) || !read_u64(a + 8, &w1)) {
            s->status |= BIT(IOMMU_STATUS_CMD_ERROR);
            return;
        }
        command_run(s, w0, w1);
        s->cmd_head = (s->cmd_head + 1) & (s->ring_size - 1);
    }
}

/* ---- the registers ---- */

static uint64_t caps_value(void)
{
    return (uint64_t)IOMMU_CAPS_VALUE_MAX_LEVELS << IOMMU_CAPS_MAX_LEVELS
           | (uint64_t)IOMMU_CAPS_VALUE_PA_BITS << IOMMU_CAPS_PA_BITS
           | (uint64_t)IOMMU_CAPS_VALUE_TAG_BITS << IOMMU_CAPS_TAG_BITS
           | BIT(IOMMU_CAPS_STAGE_B) | BIT(IOMMU_CAPS_NESTED);
}

static uint64_t iommu_read(void *opaque, hwaddr addr, unsigned size)
{
    PDP64IOMMUState *s = opaque;

    switch (addr) {
    case IOMMU_REG_ID:
        return (uint64_t)IOMMU_ID_VERSION << IOMMU_ID_FIELD_VERSION | (uint64_t)IOMMU_ID_TYPE << IOMMU_ID_FIELD_TYPE;
    case IOMMU_REG_CONTROL:     return s->control;
    case IOMMU_REG_STATUS:
        return (s->status & (BIT(IOMMU_STATUS_CMD_ERROR) | BIT(IOMMU_STATUS_OVERFLOW) | BIT(IOMMU_STATUS_TABLE_ERROR)))
               | (ring_pending(s) ? BIT(IOMMU_STATUS_FAULT_PENDING) : 0);
    case IOMMU_REG_RING_BASE:   return s->ring_base;
    case IOMMU_REG_RING_SIZE:   return s->ring_size;
    case IOMMU_REG_DOORBELL:    return s->tail;
    case IOMMU_REG_IRQ:         return VECTOR_IOMMU;
    case IOMMU_REG_DEVICE:      return s->device;
    case IOMMU_REG_CAPS:        return caps_value();
    case IOMMU_REG_CMD_HEAD:    return s->cmd_head;
    case IOMMU_REG_FAULT_BASE:  return s->fault_base;
    case IOMMU_REG_FAULT_SIZE:  return s->fault_size;
    case IOMMU_REG_FAULT_HEAD:  return s->fault_head;
    case IOMMU_REG_FAULT_TAIL:  return s->fault_tail;
    case IOMMU_REG_FAULT_DROPPED: return s->fault_dropped;
    case IOMMU_REG_INV0:        return s->inv0;
    case IOMMU_REG_REFUSED_READS: return s->refused_reads;
    case IOMMU_REG_DROPPED_WRITES: return s->dropped_writes;
    default:                    return 0;
    }
}

static void unit_reset_bit(PDP64IOMMUState *s)
{
    cache_drop_all(s);
    s->device &= ~(((1ULL << IOMMU_DEVICE_WIDTH_MODE) - 1) << IOMMU_DEVICE_MODE);     /* blocked */
    s->guard = false;
}

static void iommu_write(void *opaque, hwaddr addr, uint64_t val, unsigned size)
{
    PDP64IOMMUState *s = opaque;
    uint64_t sticky = BIT(IOMMU_STATUS_CMD_ERROR) | BIT(IOMMU_STATUS_OVERFLOW) | BIT(IOMMU_STATUS_TABLE_ERROR);

    switch (addr) {
    case IOMMU_REG_CONTROL:
        s->control = val & (BIT(IOMMU_CONTROL_CMD_ENABLE) | BIT(IOMMU_CONTROL_FAULT_ENABLE) | BIT(IOMMU_CONTROL_FAULT_IRQ));
        if (val & BIT(IOMMU_CONTROL_RESET)) {
            unit_reset_bit(s);
        }
        ring_run(s);
        break;
    case IOMMU_REG_STATUS:                              /* write one to clear the sticky bits */
        s->status &= ~(val & sticky);
        break;
    case IOMMU_REG_RING_BASE:
        s->ring_base = val & ~(PAGE - 1) & (PA_LIMIT - 1);
        break;
    case IOMMU_REG_RING_SIZE:                           /* a new size starts the ring over */
        s->ring_size = val;
        s->cmd_head = s->tail = 0;
        break;
    case IOMMU_REG_DOORBELL:
        s->tail = is_pow2(s->ring_size) ? val & (s->ring_size - 1) : 0;
        ring_run(s);
        break;
    case IOMMU_REG_DEVICE: {
        uint64_t nv = val & (((1ULL << IOMMU_DEVICE_WIDTH_MODE) - 1) << IOMMU_DEVICE_MODE | PTE_MASK(PPN));

        if (fld(nv, IOMMU_DEVICE_MODE, IOMMU_DEVICE_WIDTH_MODE) > IOMMU_MODE_TWO_LEVEL) {
            nv &= ~(((1ULL << IOMMU_DEVICE_WIDTH_MODE) - 1) << IOMMU_DEVICE_MODE);   /* a mode that does not exist: blocked */
            s->status |= BIT(IOMMU_STATUS_TABLE_ERROR);
        }
        if (nv != s->device) {
            s->device = nv;
            cache_drop_all(s);                          /* the hardware discards every cached translation on a change of the pointer (2.11.7) */
        }
        break;
    }
    case IOMMU_REG_FAULT_BASE:
        s->fault_base = val & ~(PAGE - 1) & (PA_LIMIT - 1);
        s->fault_head = s->fault_tail = 0;
        break;
    case IOMMU_REG_FAULT_SIZE:
        s->fault_size = val;
        s->fault_head = s->fault_tail = 0;
        break;
    case IOMMU_REG_FAULT_HEAD:
        s->fault_head = is_pow2(s->fault_size) ? val & (s->fault_size - 1) : 0;
        break;
    case IOMMU_REG_FAULT_DROPPED:
        s->fault_dropped = 0;
        break;
    case IOMMU_REG_INV0:
        s->inv0 = val;
        break;
    case IOMMU_REG_INV1:                                /* the write starts the command */
        command_run(s, s->inv0, val);
        break;
    default:                                            /* ID, IRQ, CAPS, CMD_HEAD, FAULT_TAIL and the counts are read only */
        break;
    }
    update_irq(s);
}

static const MemoryRegionOps iommu_ops_mmio = {
    .read = iommu_read,
    .write = iommu_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = { .min_access_size = 1, .max_access_size = 8 },
    .impl = { .min_access_size = 8, .max_access_size = 8 },
};

static void iommu_reset(DeviceState *dev)
{
    PDP64IOMMUState *s = PDP64_IOMMU(dev);

    s->control = s->status = s->ring_base = s->ring_size = s->tail = s->device = s->cmd_head = 0;
    s->fault_base = s->fault_size = s->fault_head = s->fault_tail = s->fault_dropped = 0;
    s->inv0 = s->refused_reads = s->dropped_writes = 0;
    s->guard = false;
    if (s->iotlb) {
        cache_drop_all(s);
    }
    update_irq(s);
}

static void iommu_realize(DeviceState *dev, Error **errp)
{
    PDP64IOMMUState *s = PDP64_IOMMU(dev);
    SysBusDevice *sbd = SYS_BUS_DEVICE(dev);

    if (!s->bus) {
        error_setg(errp, "pdp64-iommu: the property pci-bus is not set");
        return;
    }
    s->entries = g_hash_table_new_full(g_direct_hash, g_direct_equal, NULL, g_free);
    s->iotlb = g_hash_table_new_full(iot_hash, iot_equal, g_free, g_free);
    memory_region_init_io(&s->abort_mr, OBJECT(s), &abort_ops, s, "pdp64.iommu.abort", PAGE);
    address_space_init(&s->abort_as, &s->abort_mr, "pdp64-iommu-abort");
    memory_region_init_io(&s->iomem, OBJECT(s), &iommu_ops_mmio, s, "pdp64.iommu", 0x1000);
    sysbus_init_mmio(sbd, &s->iomem);
    sysbus_init_irq(sbd, &s->irq);
    pci_setup_iommu(s->bus, &iommu_ops, s);
}

static void iommu_init(Object *obj)
{
    PDP64IOMMUState *s = PDP64_IOMMU(obj);

    object_property_add_link(obj, "pci-bus", TYPE_PCI_BUS, (Object **)&s->bus, qdev_prop_allow_set_link_before_realize, 0);
}

static void iommu_class_init(ObjectClass *klass, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);

    dc->realize = iommu_realize;
    device_class_set_legacy_reset(dc, iommu_reset);
}

static const TypeInfo iommu_info = {
    .name = TYPE_PDP64_IOMMU,
    .parent = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(PDP64IOMMUState),
    .instance_init = iommu_init,
    .class_init = iommu_class_init,
};

static void iommu_register_types(void)
{
    type_register_static(&space_info);
    type_register_static(&iommu_info);
}

type_init(iommu_register_types)

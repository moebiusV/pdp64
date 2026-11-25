# Sources for the verification of table coherence and hypervisor cycle figures

*Saved because the owner asked (2026-11-25) that all evidence be kept. Each file below is a note on one source: the full citation, the address(es), the date read (all 2026-11-25), the exact quoted sentences (each under 25 words, with its section or page), and a short note on what the source says. No page or paper is copied whole. The document that uses them is `docs/encoding-work/table-coherence-verified.md`.*

| file | source | used for |
|---|---|---|
| `intel-sdm-tlb.md` | Intel 64 and IA-32 SDM, combined volumes, order 325462-093US (September 2026), vol. 3A section 5.10 and vol. 3C section 31.4 | x86: TLB and walk caches, INVLPG, INVPCID, CR3, speculative fills, EPT, VPID, INVEPT |
| `amd-apm-svm-tlb.md` | AMD64 APM vol. 2, rev. 3.46 (October 2026), sections 5.5 and 15.16 | x86 (AMD): no snooping, TLB_CONTROL, INVLPGA, INVLPGB |
| `intel-80386-prm-tlb.md` | Intel 80386 Programmer's Reference Manual, section 5.2.5 | x86, old |
| `arm-arm-bbm.md` | Arm ARM DDI 0487 issues G.b (2021) and C.a (2017): TLB maintenance, break-before-make, FEAT_BBM, stage 2 | Arm |
| `linux-arm64-kvm-tlb.md` | Linux source: `cachetlb.rst`, `kvm/hyp/nvhe/tlb.c`, `kvm/hyp/pgtable.c`, `kvm/vmid.c` | Arm in practice |
| `ibm-poo-ipte.md` | IBM z/Architecture Principles of Operation SA22-7832-11 (September 2017): TLB, IPTE, IDTE, CSP | IBM z |
| `ibm-sie-guest-tlb.md` | IBM 370-XA Interpretive Execution SA22-7095-1 (1985): guest TLB entries | IBM z, guests |
| `power-isa-tlbie.md` | Power ISA 3.1C, Book III 6.10 | IBM POWER |
| `hatric-isca2017.md` | Yan, Veselý, Cox, Bhattacharjee, "Hardware Translation Coherence for Virtualized Systems", ISCA 2017 (arXiv v2 read whole) | HATRIC |
| `riscv-priv-sfence.md` | RISC-V privileged ISA sources: SFENCE.VMA, HFENCE.GVMA, Svinval, Svadu | RISC-V |
| `itanium-sparc-mips-alpha.md` | Itanium SDM vol. 2 rev. 2.1; SPARC V9 appendix F; MIPS32 PRA 6.02; Alpha ARM 4th ed. | other architectures |
| `vm-exit-cycles.md` | Agesen 2012, Ben-Yehuda 2010, Dall 2016, Lim 2017, Yan 2017, Chen 2022, Misono 2024, and two blogs | guest exit and entry cycle figures |

Conventions. A quotation is copied from the text of the PDF or page as extracted; where a sentence is longer than 25 words only part is quoted and the omission is marked "...". For the 1985 IBM scan the extracted text had character-recognition errors and is quoted with them corrected. Figures read from a chart (not from running text) are marked as such. What was searched for and not found is listed at the end of each note.

## What was not obtained (details in each note)

* Arm DDI 0487, current issue (only G.b and C.a were read); Arm "Learn the architecture" guides.
* A current IBM text on guest TLB handling; the Power ISA `tlbie` instruction page.
* SPARC implementation manuals (Oracle refused an automated fetch with 403; not retried).
* AMD `INVLPGB` instruction text; Intel RAR text.
* The published ISCA version of the HATRIC paper.
* Any Intel or AMD figure for VM exit latency (neither manual has one); RISC-V silicon measurements.
* kernel.org's git viewer (bot challenge; the Linux files were read from a GitHub mirror).

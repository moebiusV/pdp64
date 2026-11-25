# Snippets of docs/encoding-work/hypervisor-text-v3.md

Every snippet of assembler in the text comes from a file here (the text shows the lines that matter and marks the rest with `...`).
Run everything from the top of the repository with `docs/encoding-work/hypervisor-text-v3-snippets/run.sh`; it needs `build/as64`, `build/ld64` and `build/sim64`.

The command line of each, by hand (NAME.S is preprocessed so that it can use the names of `build/pdp64-consts.h`):

    gcc -E -P -x assembler-with-cpp -Ibuild -Itests/qemu NAME.S -o /tmp/NAME.s
    build/as64 -o /tmp/NAME.o /tmp/NAME.s
    build/ld64 -o /tmp/NAME.x /tmp/NAME.o
    build/sim64 FLAGS /tmp/NAME.x ; echo $?        (0 is success; a failed check exits with its number)

## Run on sim64 (all passed, 2026-11-25)

| file | text | flags | result | what it shows |
|---|---|---|---|---|
| `story-spl-caught.S` | 6.14 story | `-H` | exit 0 | a guest's `SPL #7` exits (code 6); the handler puts the priority in the saved status word; the guest's `MFPS` sees 7; the handler counts the exit, and the check fails if the `SPL` never exited |
| `ex01-02-guest.S` | 6.15 examples 1, 2 | `-H` | exit 0 | `GENTER #0` starts the guest; its `WFE` exits (code 3) with `HEPC` after the instruction; the hypervisor's counter is in memory because `GENTER #0` clears the registers; the guest's `HALT` exits |
| `ex03-hypercall.S` | 6.15 example 3 | `-H` | exit 0 | `TRAPL #40` with bit 1 of the hypercall mask: exit code 17, vector 256 + 40, argument in `R0`; `GENTER #1` keeps `R0` |
| `ex05-virtual-line.S` | 6.15 example 5 | `-H` | exit 0 | line 6 pending at priority 7 is held off; `SPL #0` takes the guest's own exception entry; the handler ran once |
| `ex08-return-mask.S` | 6.15 example 8 | `-K` | exit 0 | `RTI #(1<<8)` to user mode clears the kernel's `R5` and keeps `R8` |
| `ex08-vector-sum.S` | 6.15 example 8 | none; `-S 32`; `-S 64` | exit 0 each | a `VEC` block with a `VCLR` accumulator and a `VFIN` epilogue gives the scalar sum with strips of 16, 32 and 64 bytes |

| `ex10-spinlock.S` | 6.15 example 10 | none | exit 0 | `CASDB` takes a free lock word (0 to 1, the old value 0 comes back in `Rd`), the release is an ordinary store, and the lock can be taken again |
| `ex10-counter.S` | 6.15 example 10 | none | exit 0 | `XADD` hands out 0 then 1 and leaves the counter at 2 |
| `ex10-llsc.S` | 6.15 example 10 | none | exit 0 | the `LL`/`SC` counter loop (a constrained loop of five instructions) counts from 98 to its limit 100 and stops |
| `ex11-message-passing.S` | 6.15 example 11 | `-H` | exit 0 | G writes data then flag and makes a hypercall; the hypervisor reads the flag then the data and checks them; sim64 has one core, so the reader runs after the writer has stopped (an illustration of the order and the shared words, not a test of two cores) |

The three atomic snippets are written in the final spelling (three registers, `(Ra)` with no offset, the 8-byte word with the bare name, the 4-byte word with the suffix `l` before `db`: `xaddl`, `casldb`, `lll`, `scl`); the lines marked `(check, not in the text)` are the only additions to the lines the text shows. The faults of an atomic (misaligned, a page that is not present, uncached memory, a device) are run by `tests/sim/atom-fault-align.S`, `atom-fault-page.S` and `tests/qemu/sec-atomic-memtype.S`.

Each check was shown to be able to fail: in `ex10-spinlock.S` the expected word 1 changed to 2 exits 1, in `ex10-counter.S` the expected counter 2 changed to 3 exits 3; the `RTI` mask changed to also keep `R5` exits 1; the `VADD` line removed exits 1; the `SPL #0` of the virtual-line test replaced by `NOP` exits 2; in `ex11-message-passing.S` the data changed to 41 exits 1, the flag store removed exits 98, the expected value changed to 43 exits 1; the `PRIO` bit of the `SPL` test replaced by another bit exits 2.

## Assembled, not run

| file | text | note |
|---|---|---|
| `ex02-timing-bits.S` | example 2 | clears the trap bits for `ICINV`, `TLBIA`, `TLBSYNC`; the reset value that sets them is a rule of the new text, so there is nothing to run against |
| `ex04-stage2-entry.S` | examples 4 and 6 | the hypervisor's demand fill of a stage-2 entry; it needs the page tables of a whole guest (the same steps run in `tests/qemu/hv-first.S`, on QEMU) |

## Snippets not yet assemblable (new spellings; the line that fails, with as64's message)

The spellings are those of the text and the decisions; the files `ex01-start-new.S`, `ex05-timer.S` and `ex07-guest-names.S` assemble except for these lines.

| file | line | message |
|---|---|---|
| `ex01-start-new.S` | `mtsr harena, r1` | expected a system register name: `HARENA` (number 142) is new |
| `ex01-start-new.S` | `mtsr hepoch, r1` | the same: `HEPOCH` (143) is new |
| `ex01-start-new.S` | `1<<GTBR_NEW` | assembles only because the file defines `GTBR_NEW` as 1 itself; the constant (bit 1 of `GTBR`, the request for a hardware-allocated tag) is not in `build/pdp64-consts.h` |
| `ex05-timer.S` | `mfsr r1, time`; `mtsr timecmp, r1` (twice) | `TIME` (16) and `TIMECMP` (17) are new; `GTIMECMP` (148) is the same |
| `ex07-guest-names.S` | `mfsr r1, gptbr`; `mfsr r1, gvbr` | `GPTBR` and `GVBR` are new (the `G` names 149 to 164 other than `GKSP`, `GKDP`, `GSDP`, `GUDP`, which exist as aliases today); `GKDP` assembles |
| not in any file | `mfsr r1, features`; `mfsr r1, gtoken`; `tlbigpa r1` | `FEATURES` (32), `GTOKEN` (144) and the mnemonic `TLBIGPA` are new; `TLBIAS`, `RTI #mask`, `GENTER #mask`, `MFDP`, `TRAPL` assemble today |

The running snippets were written for the implementation as it is: they set the hypervisor's vector table with `HVBR`, which the text no longer has (at `H` = 1 the ordinary `VBR` is the hypervisor's), and they use the old reset value of `HTRAP`. The text shows none of the `HVBR` lines.

PDP-11 snippets (the `SPL 7` of the story) are PDP-11 assembler and were not assembled: there is no PDP-11 assembler in this repository. The fragments in the text that are marked `...` are cut from the files above and were not assembled separately.

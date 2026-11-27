# Part 9. Memory safety

## {{#annex-granule-colours}} Colours on memory and on pointers: an overflow, a stale pointer and a double free each fault where they happen

**The decision.** I give every 16-byte piece of coloured memory a 4-bit colour and every pointer the same 4 bits in its top bits, and a load or store whose pointer colour differs from the colour of the memory it touches faults before it changes anything.

**The problem.** On the PDP-11 a pointer was a number and memory did not care whose number it was. Two mistakes in that world cost programmers years, and they are still the commonest ones. In the first, a program writes past the end of a block it was given (a string copied into a buffer that is too short) and the bytes land in the next block, which belongs to someone else; the program goes on, and some distance later the other block's owner finds its data changed. In the second, a program keeps a pointer to a block after it has given the block back (`free`); the allocator hands the same bytes to a new owner, and now two parts of the program write to one place, each believing it is the only one. A third mistake, giving the same block back twice, corrupts the allocator's own lists.

Colouring marks the memory and the pointer with the same small number, and the hardware compares them at every access. Neighbouring blocks get different colours, so a write that runs off the end of one meets another colour and stops. A block that is given back gets colour 15, which no pointer the allocator hands out carries, so any use of an old pointer stops. A block that is reused gets a new colour, so an old pointer to it stops too. The fault is precise: the program halts at the store that did it, with the address, the pointer's colour and the memory's colour in `ECAUSE` and `EVA`.

### Before and after

**Before** (the slab chunk of OpenBSD's allocator, adapted from `lib/libc/stdlib/malloc.c`, `$OpenBSD: malloc.c,v 1.303 2026/11/13 07:13:50 otto Exp $`, the functions `malloc_bytes`, `free_bytes` and `find_chunknum`; shortened, rewritten in pdp64 assembler by me, with the random choice of a chunk, the canaries and the statistics left out). A page holds equal chunks; a bitmap says which are free; the only defence against a double free is that the bitmap bit is already set (`find_chunknum` calls `wrterror(d, "double free %p", ptr)`):

```
slab_alloc:   mov 32(r1), r2          ; the bitmap
              cbeq r2, $0, full
              ctz r2, r3              ; the first free chunk
              ...                     ; clear its bit, count it, address = page + number * size
slab_free:    ...                     ; number = (chunk - page) / size
              and r4, r6              ; is its bit set already?
              cbne r6, $0, double_free
```

*(`snippets/colour-slab-before.S`: 15 instructions on the path of an allocation, 16 on a free, 90 bytes for the two routines and the double-free stop; assembled with `build/as64`, not run.)* This catches the second `free` only while the chunk stays free; once it is reused, the bit says "taken" and a stale pointer is believed. It catches nothing about an overflow.

**After** (`snippets/colour-slab-after.S`):

```
slab_alloc:   ...
              mov r5, r6
              colset $15, r6          ; a pointer to a free chunk: colour 15
              mov (r6), r7            ; the last occupant's generation, kept in its first word
              add $1, r7              ; 1 to 6
              ...                     ; the colour is (generation << 1) | (chunk number & 1)
              mcol r5, r7, r8         ; the whole chunk takes it
              colset r7, r0           ; so does the pointer returned
slab_free:    ldcol r0, r2            ; the chunk's colour now
              mov r0, r3
              shr $60, r3             ; the pointer's colour
              cbne r2, r3, double_free
              ...                     ; mcol with 15; the generation goes in the first word
```

*(27 instructions on the path of an allocation, 26 on a free, 184 bytes in all, counted from the assembled object; assembled, not run.)* The double-free test is now exact for as long as the chunk is free, and for six reuses afterwards, because a new occupant has a new colour.

A client that follows it (`snippets/colour-slab-use.S`) takes chunk 0 (colour 2) and chunk 1 (colour 3) of 32 bytes each. A store at 32 bytes from the first pointer lands in chunk 1: colour 3 against 2, a fault. After `slab_free` the first chunk is colour 15 and a load through the old pointer faults; a second `slab_free` stops at its `ldcol` test.

### What it enables

* **Allocator policies chosen by the allocator.** The hardware compares; the allocator decides the colours. In a slab, the parity of the chunk number keeps neighbours different by construction. An allocator without slots looks at the colours on both sides (`ldcol`) and takes one that is neither, nor the old colour (`snippets/colour-neighbours.S`: at most three of fourteen are excluded, so the loop ends in four tries). Objects over 2,048 bytes need no colours: they are whole pages with a guard page after them, unmapped when freed. The strict policy, every live block colour 1 and every free block colour 15, is the special case that closes use after free while the block is free, and it runs on the same machine.
* **Cheap bulk work.** One `mcol` colours a whole block as `mset` fills one, with its progress in its registers.
* **Stack objects**, by a compiler option that is off unless asked for: the same colours on the frame's arrays.

### What it saves us from

OpenBSD's allocator already spends effort on these bugs, and the cost shows in its source: freed chunks are held back in a table of delayed slots (`MALLOC_DELAYED_CHUNK_MASK`, 16 slots), freed memory is filled with junk and checked for it again, a canary after the requested bytes catches a short overflow, and the chunk to give out is chosen at random. Each is a defence in software, paid in time and memory on every call, and each is a chance rather than a certainty. Colour makes the neighbour case and the freed-block case certain, in hardware. I read `malloc.c` here for this; I did not read any other machine's tagging documents for this entry, so I make no claim about them.

### What it costs

Four bits for every 16 bytes: one thirty-second of memory, which is arithmetic, not a measurement. I quote no run-time figure, because none has been measured on the machine. The routines above are 12 and 10 instructions longer than the plain ones, counted from the assembled code.

### What it puts off limits

What colouring does not catch: an overflow inside the last 16-byte piece of a block, a read that stays inside a piece, a pointer forged with the right colour by luck, a stale pointer more than six reuses old (one chance in twelve), and a device write that the IOMMU allows. Code that masks pointers, assumes bits 63 to 60 are zero, or hides data in them now sees the colour; remove it with `colstrip` (and put it back with `colset`). The kernel strips at the system calls that take an address. A `longjmp` over coloured frames must clear their colours with one `mcol`.

### Where the manual states it

{{r:memory-has-a-colour}}, {{r:colour-0-and-15}}, {{r:page-is-coloured}}, {{r:translation-ignores-the-colour}}, {{r:ldcol-and-mcol}}, {{r:colour-fault-is-precise}}, {{r:devices-carry-no-colour}} and {{r:moving-a-page-moves-colours}}.

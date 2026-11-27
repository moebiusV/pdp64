## {{#annex-level-from-vector}} The interrupt level follows from the vector number

**The decision.** An interrupt's priority level is the vector number divided by 32, so there are eight levels of 32 vectors each, and no table or register says which vector has which level.

**The problem.** On the PDP-11 an interrupt has two numbers. The **priority** says how urgent it is: the processor takes an interrupt only when its priority is higher than the one in the status word, so `spl` (set priority level) in a critical section keeps out everything at or below that level. The **vector** says where its handler is: a pair of words in low memory holding the handler's address and the status word to load. The two are set in different places. The vector comes from switches on the device card; the priority from which of the four bus request lines (BR4 to BR7) the card is wired to. And the kernel states both again in its own table. 2.11BSD's `pdp/scb.s` has `DEVTRAP(220, rkintr, br5)` for the RK11 disk: vector 0220, priority 5, written by hand. V7's `l.s` has the same shape, a pair of words for each vector:

```
        klin;  br4              / 060  console keyboard
        klou;  br4              / 064  console printer
        . = ZERO+100
        kwlp;  br6              / 100  line clock
```

Nothing makes the priority in that second word agree with the priority the device asserts, or with what the `spl` calls in the driver think it is. A vector and its level that disagree give a kernel that is sometimes interrupted inside a critical section, once in a while, depending on what else is happening. I did not find a record in the repository's sources of a specific bug of this kind, so I do not claim one; I say that the structure permits it, and that the pdp64 does not.

### Before and after

**Before** (PDP-11; quoted from V7 `l.s` and 2.11BSD `pdp/scb.s`, in the manual's chapter on the kernel):

```
        kwlp;  br6              / 100  line clock: address of handler, then the priority
        DEVTRAP(220, rkintr, br5)   /* the RK11: vector 0220, level 5 */
```

*(Each interrupt is two numbers written in one place and expected to agree with a third elsewhere; the table is 2 words a vector.)*

**After** (pdp64, `snippets/level.S`, assembled):

```
        lea     disk_handler, r2
        mov    r2, 8*100(r1)           ; vector 100: its level is fixed by the number
        spl     #3                      ; keep out vector 100 and everything at or below its level
```

*(One store per vector, and nothing else to keep in step: 100 divided by 32 is 3.)*

### What it enables

* **A priority that cannot disagree with its vector.** `spl #3` in a driver means exactly the vectors from 96 to 127 and below; the programmer can read it off the numbers.
* **A smaller interrupt controller.** Choosing the highest eligible pending vector is a comparison of numbers. I measured the selection circuit at 1,007 gates when the level is derived from the vector and 11,741 when every vector carries a stored level of its own, and the stored form also needs 672 bits of state (about 4,000 gates): a saving of at least 4,000 and probably 14,800 gates, five to seven percent of a core.
* **Drivers that name a level by choosing a vector.** A card with one queue for each core gets one vector for each core, in the level its work deserves.

### What it saves us from

* **Disagreement between a table and the wiring**, the structure of the PDP-11 pair above.
* **A table that costs gates and state.** Other designs derive priority from the number: x86's interrupt controller does, and so does RISC-V's AIA ("Within a single interrupt file, interrupt priorities are determined directly from interrupt identity numbers", section 3.3 of the specification as the repository's reading records it).
* **The small vector space.** x86's problem that "the vector space is notoriously low" is a reminder that 32 vectors a level a core is a limit; a card with a queue for each core needs few vectors for each core, so it holds.

### What it costs

Vectors are not freely assignable: a device gets a vector in the level it wants. The 32 vectors of a level are a limit, which the interrupt-per-queue cards stay within.

### What it puts off limits

A kernel cannot give vector 100 a level other than 3. To make a device less urgent it moves it to another vector.

### Where the manual states it

{{r:vector-table-has-512-entries}} and {{r:there-are-eight-interrupt-priority}}.

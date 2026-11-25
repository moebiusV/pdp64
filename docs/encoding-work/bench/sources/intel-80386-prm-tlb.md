# Intel 80386 Programmer's Reference Manual: the page-translation cache (old x86)

**Citation.** Intel, 80386 Programmer's Reference Manual (1986), section 5.2.5 "Page Translation Cache".
**URL.** https://pdos.csail.mit.edu/6.828/2005/readings/i386/s05_02.htm (an HTML copy of the manual kept by a university course).
**Date read.** 2026-11-25.

## What it says (short note)

The first x86 with paging already had the arrangement the current manuals still have: a small on-chip cache of translations that the processor does not keep in step with the tables; the operating system must empty it after changing the tables, by reloading CR3 or by a task switch that loads a different CR3. (That INVLPG came later, with the 486, is from memory and was not verified here; the year 1986 in the citation is also from memory, the page does not print it.)

## Quotation

> "operating-system programmers must flush the cache whenever the page tables are changed."

(the sentence begins "The existence of the page-translation cache is invisible to applications programmers but not to systems programmers;".)

The two flush methods given are "By reloading CR3 with a MOV instruction" and "By performing a task switch to a TSS that has a different CR3 image than the current TSS".

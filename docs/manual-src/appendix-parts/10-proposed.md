**10.1.2** (moved from chapter 10) The first board is the Terasic DE10-Nano (Cyclone V SE: about 110,000 logic elements, dual Cortex-A9, 1 GB of memory on the hard processor, HDMI, and the MiSTer ecosystem); the Digilent Zybo Z7-20 or the AMD Kria KV260 are the move when timing becomes the limit; the open-toolchain ULX3S is kept in view but loses the hard-core harness. The device chat staged devices first on a Zynq UltraScale+ (`decisions-pending.md` E6). *(P)*

**10.1.8** (moved from chapter 10) On the paper estimates of the SMP decisions, four cores with the floating-point unit fit only a board of the Kria KV260 class, and sixteen cores fit none of the boards of the plan; no core has been synthesised. *(E)*


**10.3.4** (moved from chapter 10) Sequential consistency is nearly free on a small in-order core and is the most expensive memory model for a large speculative one; if a large core is built it may be necessary to move to total store order, which is the least painful retreat. *(P)*

**10.1.1** (moved from chapter 10) The first implementation is a soft core on a system-on-chip FPGA whose hard ARM cores serve as the bring-up harness: they load programs, run the tests and provide the console while the pdp64 core is still being debugged, and run an instruction-set simulator beside the core to compare the architectural state after every instruction (`pdp64-fpga-plan.md`, section 6). The text of the chapter tagged this *(D)*; no decision of the author was found for the harness (the register's R24, "since the soc will have hdmi", assumes a system-on-chip and nothing more), so it is proposed. *(P)*

**10.1.4** (moved from chapter 10) The estimated clock a simple single-issue core reaches is 50 to 80 MHz on the Cyclone V, 90 to 130 MHz on a Zynq 7020 and 180 to 250 MHz on an UltraScale+; every one of those estimates is below the 200 to 300 MHz target except the upper part of the UltraScale+ range, and reaching the target means pipeline stages in the datapath. A correct machine at a lower clock comes before a fast broken one. *(E)*

**10.1.5** (moved from chapter 10) The work is staged in phases, each ending in a demonstration and a regression suite: specification and tools; an integer core; exceptions; the memory-management unit; the memory system; floating point; a booting kernel; peripherals; and, last, the other cores. The text of the chapter tagged this *(D)*; the phase plan is the assistant's (`pdp64-fpga-plan.md`, section 5) and the author has not spoken to it (`decisions-pending.md`, E6: "No erratum backs either"), so it is proposed. The decided part, the number of cores, stays in the chapter (10.1.3). *(P)*

**10.1.6** (moved from chapter 10) The second phase, the fault model, is not optional and does not move; the block operations are built with it, because their whole specification is about what state is visible when an exception arrives. *(P)*

**10.1.7** (moved from chapter 10, from 10.1.3) On the first board the block RAM is about 5.5 megabits, and the caches, the translation buffer, the framebuffer and the blitter's scratch memory compete for it. *(E)*

**10.1.9** (moved from the commentary of 10.1) A single engineer working part-time can reach a booting system with floating point in roughly 10 to 19 months, by the plan's wide-error-bar estimate (phase by phase: 5 to 9 weeks for specification and tools, 9 to 14 for the integer core, 6 to 11 for exceptions, 7 to 11 for the memory-management unit, 4 to 8 for the memory system, 4 to 7 for floating point, 8 to 16 for the kernel), with phases 2 and 3 the ones that historically double. *(E)*

**10.1.10** (moved from the commentary of 10.1) The register-transfer description is kept vendor-neutral, with every vendor primitive in one thin directory that holds the register file, block RAM and DSP wrappers and should stay under 500 lines, so that moving between boards costs that directory and nothing else; the datapath is written in SystemVerilog and the floating-point unit is bought, not written (Berkeley HardFloat). *(P)*

**10.1.11** (moved from the commentary of 10.1) A multiplier built from two to four multiplier blocks over four to eight cycles closes timing where a full combinational one will not. *(E)*

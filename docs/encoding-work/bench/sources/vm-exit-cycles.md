# Measured cost of a guest exit and re-entry (a "null hypercall" round trip)

What is measured differs from paper to paper, so each row says exactly what. "Hardware alone" means the processor's own work to leave the guest and come back with the hypervisor doing nothing; "null hypercall" means the guest calls the hypervisor, which returns at once, so it includes the hypervisor's own entry and exit code (saving and restoring the guest's registers). All read on 2026-11-25. Quotations are under 25 words; the figures read from a chart are marked.

## Summary table

| Hardware, year | What exactly | Cycles | Source |
|---|---|---:|---|
| Intel Prescott (2005) to Sandy Bridge (2011) | "Hardware round-trip latency" of a VM exit and re-entry | 3,963 (Prescott), 1,579 (Merom), 1,266 (Penryn), 1,009 (Nehalem), 761 (Westmere), 784 (Sandy Bridge) | Agesen et al., USENIX ATC 2012, Table 1 |
| Intel Xeon 2.9 GHz (2010) | a `cpuid` in a guest (exit, KVM emulates, return): total; of which "CPU mode switching" | about 2,600; about 1,000 | Ben-Yehuda et al., "The Turtles Project", OSDI 2010, section 4.1 |
| Dell r320, Intel Xeon E5-2450 2.1 GHz (2015 paper) | null hypercall, KVM x86; Xen x86 | 1,300; 1,228 | Dall et al., ISCA 2016, Table II |
| APM X-Gene (Atlas) ARMv8-A 2.4 GHz, HP Moonshot m400 (2015 paper) | null hypercall, KVM ARM; Xen ARM (hypervisor in EL2, a thin type-1 hypervisor) | 6,500; 376 | Dall et al., ISCA 2016, Table II |
| the same X-Gene (2017 paper) | null hypercall of a non-nested VM under KVM ARM | 2,729 | Lim et al., "NEVE", SOSP 2017, Table 1 |
| Intel Haswell (about 2015) | "a VM exit", average | 1,300 | Yan et al., HATRIC, ISCA 2017, section 3.3 |
| RISC-V Rocket core with hypervisor extension, FPGA, 3.2 GHz modelled by FireSim (paper of 2022) | null hypercall, KVM; DuVisor (a user-level hypervisor) | 739; 546 (read from Fig. 6a) | Chen et al., "DuVisor", arXiv 2201.09652, section 8.2 |
| AMD EPYC 9654P and Intel Xeon Platinum 8570, Linux 6.8, QEMU 8.2 (paper of 2024) | null hypercall of a normal VM (KVM returns at once): time, not cycles | 1,132 ns (AMD); 1,781 ns (Intel) (read from Fig. 5) | Misono et al., Proc. ACM Meas. Anal. Comput. Syst. 8(3), art. 36, December 2024 |
| Intel i7-3960X (blog, 2014, secondary) | a guest VMCALL that KVM returns from early | 1,600 to 1,700 ("~95%") | https://yshalabi.github.io/VMExits |

For the clock rates: Sandy Bridge's 784 is the hardware alone. The two 2024 figures are in nanoseconds because that paper gives no clock rate; at an assumed 2 to 4 GHz they would be about 2,300 to 4,500 cycles (AMD) and 3,600 to 7,100 cycles (Intel): an **estimate**, not in the paper.

## Source details

### Agesen, Mattson, Rugina, Sheldon (VMware), "Software Techniques for Avoiding Hardware Virtualization Exits", USENIX Annual Technical Conference 2012
URL: https://usenix.org/system/files/conference/atc12/atc12-final158.pdf

> "hardware advances and microcode improvements have reduced exit latencies by about 80%"

(section 1, from Prescott to Sandy Bridge; Table 1 "Hardware round-trip latency" has the figures above, with launch dates 3Q2005 to 1Q2011.)

> "As the hardware round-trip latency bottoms out, efforts to improve virtualization performance must shift to techniques for avoiding virtualization exits."

(section 11, "Future Work and Conclusions".) In nested use "the virtual hardware round-trip latency for a virtualization exit is 9794 cycles" on Sandy Bridge, "over 10 times worse than the underlying physical hardware".

### Ben-Yehuda et al., "The Turtles Project: Design and Implementation of Nested Virtualization", OSDI 2010
URL: https://www.usenix.org/legacy/event/osdi10/tech/full_papers/Ben-Yehuda.pdf

> "On bare metal cpuid takes about 100 cycles, while in a virtual machine it takes about 2,600 cycles"

> "about 1,000 of which is due to the CPU mode switching."

(section 4.1; "a single Intel Xeon 2.9GHz core" is the test machine's description in section 4; nested: "about 58,000 cycles".)

### Dall, Li, Lim, Nieh, Koloventzos, "ARM Virtualization: Performance and Architectural Implications", ISCA 2016
URL: https://www.cs.columbia.edu/~cdall/pubs/isca2016-dall.pdf

> "Transition from VM to hypervisor and return to VM without doing any work in the hypervisor."

(Table I, the Hypercall microbenchmark. Table II: KVM ARM 6,500; Xen ARM 376; KVM x86 1,300; Xen x86 1,228 cycles.)

> "which takes less than a third of the cycles that Xen or KVM on x86 take."

(section 4, about Xen ARM.) The cost of KVM ARM is spent on register state, Table III (cycles, KVM ARM): general-purpose registers save 152, restore 184; floating point 282 and 310; EL1 system registers 230 and 511; the interrupt-controller registers 3,250 and 181; timer 104 and 106; EL2 configuration 92 and 107; EL2 virtual memory 92 and 107.

> "Unlike Xen ARM which only incurs the relatively small cost of saving and restoring the general-purpose (GP) registers"

(section 4.) So, as the paper shows it, an Arm exit and return with only the 31 general registers saved and restored costs 376 cycles in total, of which saving and restoring the general registers (152 + 184 = 336, measured in KVM's code on the same machine) is by far the larger part. That the hardware trap and return alone is about 40 cycles (376 - 336) is my subtraction (an **estimate**; the paper does not say it).

### Lim, Dall, Li, Nieh, Zyngier, "NEVE: Nested Virtualization Extensions for ARM", SOSP 2017
URL: https://www.cs.columbia.edu/~nieh/pubs/sosp2017_neve.pdf
Table 1 and Table 6 ("Microbenchmark Cycle Counts"): non-nested VM, KVM ARM: Hypercall 2,729; Device I/O 3,534; Virtual IPI 8,364; Virtual EOI 71. Nested VM on Armv8.3: Hypercall 422,720 (non-VHE guest hypervisor) and 307,363 (VHE); with NEVE 92,385 and 100,895.

> "from a nested VM on ARMv8.3, it requires 126 and 82 traps to the host hypervisor"

> "x86 incurs a 31 times slowdown running in a nested vs. non-nested VM."

(section 7.1; x86 machine Cisco UCS with Intel E5-2630 v3 2.4 GHz, the ARM machine the 2.4 GHz X-Gene.) The nested figures show how much a hypervisor that runs in a guest costs; they are not an input to the pdp64's study unless nested virtualization is used.

### Yan et al., HATRIC (see hatric-isca2017.md)

> "the average of 1300 cycles required for a VM exit."

### Chen, Li, Mi, Liu, Zang, Guan, Chen (Shanghai Jiao Tong University), "DuVisor: a User-level Hypervisor Through Delegated Virtualization", arXiv 2201.09652 (January 2022)
URL: https://arxiv.org/pdf/2201.09652

> "The number of cycles between the start of the hypercall and its return position is counted."

> "DuVisor improves performance by approximately 26.12% compared with KVM."

(section 8.2; the figure 6(a) bars read 739 (KVM) and 546 (DuVisor) cycles, and 546 against 739 is 26.1% less.) Hardware: "board has eight RISC-V cores (3.2GHz, rv64imafdc)" (section 8.1), "Rocket CPU using FPGAs", with the "H" extension implemented in the core. For a stage-2 page fault: "accounts for 2,939 cycles (57.32%) of the S2PF handling procedure in KVM", about 5,100 cycles in all (Fig. 6c, read from the chart) against about 1,500 for DuVisor. Remember that the machine is an FPGA model, whose memory latency to the processor is that of the model, not of a silicon part.

### Misono, Stavrakakis, Santos, Bhatotia, "Confidential VMs Explained: An Empirical Analysis of AMD SEV-SNP and Intel TDX", Proc. ACM on Measurement and Analysis of Computing Systems 8(3), article 36, December 2024
URL: https://dse.in.tum.de/wp-content/uploads/2024/11/sigmetrics25summer-CVM-Explained.pdf

> "hypercall (KVM_HC_MMU_OP (deprecated), the KVM returns immediately)"

(section 4.2: "We invoke instructions a hundred thousand times and calculate the average latency".) Figure 5 (read from the chart labels, "vm" bars: ordinary virtual machine): on the 4th-generation AMD EPYC 9654P, CPUID 1,106 ns, MSR read 1,167 ns, hypercall 1,132 ns, port read 1,479 ns; on the 5th-generation Intel Xeon Platinum 8570, CPUID 1,779 ns, MSR read 1,826 ns, hypercall 1,781 ns, port read 4,251 ns. Host and guest Linux 6.8, QEMU 8.2.

### QEMU blog, "Micro-Optimizing KVM VM-Exits" (2019)
URL: https://www.qemu.org/2019/11/15/micro-optimizing-kvm-vmexits/
Describes a CPUID-in-a-loop benchmark on both Intel VMX and AMD SVM; it gives gains in percent, no cycle counts and no processor model, so no figure is taken from it.

### The blog "The Cost of Virtualization Exits" (December 2014)
URL: https://yshalabi.github.io/VMExits . Read only through the fetch tool's summary, not the page text, and the chart was not readable: so the 1,600 to 1,700 cycle figure (pinned processors, Intel i7-3960X, a KVM changed to return early from a fake VMCALL) is **secondary and not used in the conclusions**.

## What was searched for and not found

* Intel's or AMD's own figure for the latency of VM entry or exit: none in the Intel SDM (searched "latency" and "cycles" near "VM entry" and "VM exit") or in AMD's Volume 2 (same search). Neither vendor documents it.
* A published null-hypercall figure for RISC-V on silicon with the H extension: none found. The one RISC-V figure is an FPGA model with the H extension (above). A search for the gem5 H-extension paper and a Rocket-core evaluation of the extension (arXiv 2103.14951, "A First Look at RISC-V Virtualization from an Embedded Systems Perspective") gave interrupt and context-switch discussion but no cycle figure for a hypercall round trip in the text I searched.
* Zen 2, Zen 3, Ice Lake or Sapphire Rapids VM-exit cycle counts in a primary measurement paper: none found (the 2024 paper above gives nanoseconds, for a 4th-generation EPYC and a 5th-generation Xeon).

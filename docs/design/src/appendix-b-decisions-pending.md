# Decisions pending

[← manual index](../manual/00-index.md)

**This appendix is a list of pointers.** Each decision listed here was a question with one proposed answer: the question and its answer, with the precedent, the trade-offs and the benefits, are in [appendix H](proposed.md) under "Appendix B" (the identifiers P, R, S, N and B are those of the working document [`decisions-pending.md`](../decisions-pending.md), and the boot choices are worked through in [`boot.md`](../boot.md)). A question that the architecture must answer, with each option weighed, is an open item in [appendix J](open-items.md). What has been decided is in the chapters, and what has been put off in [appendix I](deferred.md). Questions of this list that I answered are no longer listed: the wake rule of `WFE` (7.10.2), priority 7 on interrupt entry as well as exception entry (6.3.2), constant-time execution by the secure core and the `DIT` bit (7.11.3, 9.3.7; what stays open is [J.9.2](open-items.md#j92)), and, in the entries that remain, the parts I decided (the random-number source, the device route for vector work, enumeration, the all-ones read of an absent function and the block-0 boot) are stated as decided. Each question was judged by the three principles in order: code size, easy recoverability (less recovery code), and speed and efficiency through fewer gates and tighter hot loops.

**B.1 The instruction set and the system**

* [B.1.2 An unprivileged time counter (P3)](proposed.md#b12-an-unprivileged-time-counter-p3)
* [B.1.3 Feature and identification registers (P4)](proposed.md#b13-feature-and-identification-registers-p4)
* [B.1.4 TLB invalidation by address-space tag (P5)](proposed.md#b14-tlb-invalidation-by-address-space-tag-p5)
* [B.1.5 What a multi-register instruction leaves behind when it faults (P12)](proposed.md#b15-what-a-multi-register-instruction-leaves-behind-when-it-faults-p12)
* [B.1.7 A prefetch instruction (P15)](proposed.md#b17-a-prefetch-instruction-p15)
* [B.1.8 Performance counters (P16)](proposed.md#b18-performance-counters-p16)
* [B.1.10 The literal pool and execute-only code (P18)](proposed.md#b110-the-literal-pool-and-execute-only-code-p18)
* [B.1.11 Vector and SIMD math (S1 to S6)](proposed.md#b111-vector-and-simd-math-s1-to-s6)

**B.2 The bus, boot and devices**

* [B.2.1 Data-cache maintenance by address (P6)](proposed.md#b21-data-cache-maintenance-by-address-p6)
* [B.2.2 Firmware calls (P7)](proposed.md#b22-firmware-calls-p7)
* [B.2.3 Double-width compare-and-swap and a random-number instruction (P8, P9)](proposed.md#b23-double-width-compare-and-swap-and-a-random-number-instruction-p8-p9)
* [B.2.4 The interrupt controller and routing to cores (R1)](proposed.md#b24-the-interrupt-controller-and-routing-to-cores-r1)
* [B.2.5 Inter-processor interrupts and starting other cores (R2, B2)](proposed.md#b25-inter-processor-interrupts-and-starting-other-cores-r2-b2)
* [B.2.6 How coherence scales (R3)](proposed.md#b26-how-coherence-scales-r3) See also the open entry [J.9.8](open-items.md#j98).
* [B.2.8 The device layout and the descriptor (R5)](proposed.md#b28-the-device-layout-and-the-descriptor-r5)
* [B.2.10 Errors raised by devices and the bus (R7)](proposed.md#b210-errors-raised-by-devices-and-the-bus-r7)
* [B.2.11 Virtualisation (R8)](proposed.md#b211-virtualisation-r8)
* [B.2.12 Enumeration and hot-plug (N1 to N3)](proposed.md#b212-enumeration-and-hot-plug-n1-to-n3)
* [B.2.13 The boot decisions (B1, B3, B4, B5, B8)](proposed.md#b213-the-boot-decisions-b1-b3-b4-b5-b8) The UEFI decision is in chapter 4.
* [B.2.14 How USB attaches, and virtio first](proposed.md#b214-how-usb-attaches-and-virtio-first)

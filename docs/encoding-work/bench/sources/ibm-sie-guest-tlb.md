# IBM interpretive execution (SIE): translation buffer entries of a guest

**Citation.** IBM, System/370 Extended Architecture: Interpretive Execution, publication SA22-7095-1, Second Edition, September 1985 (a scanned copy; the text below is from the scan's character recognition, so spacing and some letters (for example "TlB") were wrong in the extraction and are written here correctly).
**URL.** https://mirrorservice.org/sites/www.bitsavers.org/pdf/ibm/370/MVS_XA/SA22-7095-1_System_370-XA_Interpretive_Execution_2nd_ed_198509.pdf (a mirror of the Bitsavers archive).
**Date read.** 2026-11-25.
**Why this is old.** It is the only IBM text found that describes how the translation buffer is handled for a guest. The current z/Architecture book points to this publication for the subject (see ibm-poo-ipte.md). Later IBM documents for the modern machines (for example the z/VM and LPAR books) were not found, so what is below is the 1985 definition; whether current machines keep it is **could not verify**.

## What the document says (short note)

When a hypervisor starts a guest (the instruction is START INTERPRETIVE EXECUTION, "SIE", the equivalent of our GENTER), the hardware may keep translation entries made for the guest ("guest-type TLB entries"). The entries remember which guest they belong to: the address of the guest's state description (its control block), the address of its system-control area, the guest's translation parameters and tables, and the host's own. They may be kept or thrown away when the guest exits. A field of the state description, the "last-host-CPU address", is compared on every entry with the number of the processor that is entering: if the guest last ran on another processor, its entries are cleared. The host can force a clear on the next entry by writing a special value into that field. And when a guest executes IPTE, other processors that run the same guest are signalled through the system-control area to clear their entries for it, with an interlock bit in that area.

So IBM's answer for the guest case is a mix of tags (the entries name the guest) and a hypervisor-writable "flush at next entry" field, which the hardware also sets by itself when the guest moves processors. Nothing watches the hypervisor's own table stores.

## Quotations (character-recognition errors corrected)

### Instruction description, programming note

> "guest-type translation-lookaside buffer (TLB) entries may be formed and used during execution."

### State description, LAST-HOST-CPU ADDRESS

> "If the field does not match the address, then existing guest-type TLB entries for this guest are cleared."

> "The host program may store the hex value FFFF in this field to force all guest-type TLB entries for this guest to be cleared"

(the sentence goes on "on the CPU on entry to the interpretive-execution mode".)

### State description, guest environmental information

> "The relevant environmental information includes guest translation parameters and translation tables, host translation parameters and translation tables"

(the list continues with the host real addresses of the state description and of the system-control area, and the guest's storage and architecture modes; entries formed under one set of these are not used under another.)

> "These entries may or may not be retained when the CPU exits from the interpretive-execution mode."

### System-control area (SCA)

> "then all CPUs in the configuration are signaled to clear those guest-type TLB entries formed under a matching SCA-origin value"

(the sentence begins "If the SCA origin has a nonzero value," and is about a guest's own INVALIDATE PAGE TABLE ENTRY; with SCA origin zero the guest's IPTE is executed "without signaling other CPUs".) Bit 0 of the SCA is the IPTE-interlock-control bit, set by a guest IPTE.

# The bit layout of every instruction word (pdp64/32)

[← dictionary index](index.md)

One chart for each way a word is encoded: the bits that the word fixes (its opcode or prefix, its sub-opcode, the fields it holds constant) are shaded and carry their value; the operand fields are named. A word that has several forms (a length, an addressing form, a load and a store) has one chart for each, one under the other. The charts are generated from the grammar by `tools/mkmanual.py`, as those of [the bit layouts of every opcode](by-encoding.md), which show a layout once for all the words that share it.

<a id="w-abs"></a>
### ABS

![Layouts of ABS](../figures/w/abs.svg)

Entry: [ABS](../09-isa.md#abs-absolute-value). 1 form.

<a id="w-adc"></a>
### ADC

![Layouts of ADC](../figures/w/adc.svg)

Entry: [ADC](../09-isa.md#adc-add-carry). 7 forms.

<a id="w-add"></a>
### ADD

![Layouts of ADD](../figures/w/add.svg)

Entry: [ADD](../09-isa.md#add-add). 24 forms.

<a id="w-addm"></a>
### ADDM

![Layouts of ADDM](../figures/w/addm.svg)

Entry: [ADDM](../09-isa.md#addm-alu-operation-with-a-memory-destination). 6 forms.

<a id="w-addv"></a>
### ADDV

![Layouts of ADDV](../figures/w/addv.svg)

Entry: [OVF](../09-isa.md#ovf-add-subtract-and-multiply-trapping-on-signed-overflow). 1 form.

<a id="w-aesds"></a>
### AESDS

![Layouts of AESDS](../figures/w/aesds.svg)

Entry: [AESR](../09-isa.md#aesr-aes-round-on-a-128-bit-block-in-two-registers). 1 form.

<a id="w-aesdsm"></a>
### AESDSM

![Layouts of AESDSM](../figures/w/aesdsm.svg)

Entry: [AESR](../09-isa.md#aesr-aes-round-on-a-128-bit-block-in-two-registers). 1 form.

<a id="w-aeses"></a>
### AESES

![Layouts of AESES](../figures/w/aeses.svg)

Entry: [AESR](../09-isa.md#aesr-aes-round-on-a-128-bit-block-in-two-registers). 1 form.

<a id="w-aesesm"></a>
### AESESM

![Layouts of AESESM](../figures/w/aesesm.svg)

Entry: [AESR](../09-isa.md#aesr-aes-round-on-a-128-bit-block-in-two-registers). 1 form.

<a id="w-aesim"></a>
### AESIM

![Layouts of AESIM](../figures/w/aesim.svg)

Entry: [AESK](../09-isa.md#aesk-aes-key-schedule-steps). 1 form.

<a id="w-aesks1"></a>
### AESKS1

![Layouts of AESKS1](../figures/w/aesks1.svg)

Entry: [AESK](../09-isa.md#aesk-aes-key-schedule-steps). 1 form.

<a id="w-aesks2"></a>
### AESKS2

![Layouts of AESKS2](../figures/w/aesks2.svg)

Entry: [AESK](../09-isa.md#aesk-aes-key-schedule-steps). 1 form.

<a id="w-and"></a>
### AND

![Layouts of AND](../figures/w/and.svg)

Entry: [AND](../09-isa.md#and-and). 22 forms.

<a id="w-asl"></a>
### ASL

![Layouts of ASL](../figures/w/asl.svg)

Entry: [ASL](../09-isa.md#asl-arithmetic-shift-left-by-one). 7 forms.

<a id="w-asr"></a>
### ASR

![Layouts of ASR](../figures/w/asr.svg)

Entry: [ASR](../09-isa.md#asr-arithmetic-shift-right-by-one). 7 forms.

<a id="w-bcc"></a>
### BCC

![Layouts of BCC](../figures/w/bcc.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bcs"></a>
### BCS

![Layouts of BCS](../figures/w/bcs.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-beq"></a>
### BEQ

![Layouts of BEQ](../figures/w/beq.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 3 forms.

<a id="w-bge"></a>
### BGE

![Layouts of BGE](../figures/w/bge.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bgt"></a>
### BGT

![Layouts of BGT](../figures/w/bgt.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bhi"></a>
### BHI

![Layouts of BHI](../figures/w/bhi.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bic"></a>
### BIC

![Layouts of BIC](../figures/w/bic.svg)

Entry: [BIC](../09-isa.md#bic-bit-clear). 13 forms.

<a id="w-bicm"></a>
### BICM

![Layouts of BICM](../figures/w/bicm.svg)

Entry: [ADDM](../09-isa.md#addm-alu-operation-with-a-memory-destination). 6 forms.

<a id="w-bis"></a>
### BIS

![Layouts of BIS](../figures/w/bis.svg)

Entry: [BIS](../09-isa.md#bis-bit-set-inclusive-or). 18 forms.

<a id="w-bism"></a>
### BISM

![Layouts of BISM](../figures/w/bism.svg)

Entry: [ADDM](../09-isa.md#addm-alu-operation-with-a-memory-destination). 6 forms.

<a id="w-bit"></a>
### BIT

![Layouts of BIT](../figures/w/bit.svg)

Entry: [BIT](../09-isa.md#bit-bit-test). 12 forms.

<a id="w-bitrev"></a>
### BITREV

![Layouts of BITREV](../figures/w/bitrev.svg)

Entry: [BITREV](../09-isa.md#bitrev-reverse-the-bits). 1 form.

<a id="w-ble"></a>
### BLE

![Layouts of BLE](../figures/w/ble.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-blos"></a>
### BLOS

![Layouts of BLOS](../figures/w/blos.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-blt"></a>
### BLT

![Layouts of BLT](../figures/w/blt.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bmi"></a>
### BMI

![Layouts of BMI](../figures/w/bmi.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bne"></a>
### BNE

![Layouts of BNE](../figures/w/bne.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 3 forms.

<a id="w-bntag"></a>
### BNTAG

![Layouts of BNTAG](../figures/w/bntag.svg)

Entry: [BTAG](../09-isa.md#btag-branch-on-pointer-tag). 1 form.

<a id="w-bpl"></a>
### BPL

![Layouts of BPL](../figures/w/bpl.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bpt"></a>
### BPT

![Layouts of BPT](../figures/w/bpt.svg)

Entry: [BPT](../09-isa.md#bpt-breakpoint). 1 form.

<a id="w-br"></a>
### BR

![Layouts of BR](../figures/w/br.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 6 forms.

<a id="w-bsel"></a>
### BSEL

![Layouts of BSEL](../figures/w/bsel.svg)

Entry: [BSEL](../09-isa.md#bsel-bitwise-select). 1 form.

<a id="w-bswap"></a>
### BSWAP

![Layouts of BSWAP](../figures/w/bswap.svg)

Entry: [BSWAP](../09-isa.md#bswap-byte-swap). 1 form.

<a id="w-bswapl"></a>
### BSWAPL

![Layouts of BSWAPL](../figures/w/bswapl.svg)

Entry: [BSWAP](../09-isa.md#bswap-byte-swap). 1 form.

<a id="w-bswapw"></a>
### BSWAPW

![Layouts of BSWAPW](../figures/w/bswapw.svg)

Entry: [BSWAP](../09-isa.md#bswap-byte-swap). 1 form.

<a id="w-btag"></a>
### BTAG

![Layouts of BTAG](../figures/w/btag.svg)

Entry: [BTAG](../09-isa.md#btag-branch-on-pointer-tag). 1 form.

<a id="w-bvc"></a>
### BVC

![Layouts of BVC](../figures/w/bvc.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-bvs"></a>
### BVS

![Layouts of BVS](../figures/w/bvs.svg)

Entry: [BCC](../09-isa.md#bcc-branch-on-condition). 2 forms.

<a id="w-call"></a>
### CALL

![Layouts of CALL](../figures/w/call.svg)

Entry: [CALL](../09-isa.md#call-call). 13 forms.

<a id="w-calli"></a>
### CALLI

![Layouts of CALLI](../figures/w/calli.svg)

Entry: [JMPI](../09-isa.md#jmpi-jump-and-call-through-memory). 9 forms.

<a id="w-cas"></a>
### CAS

![Layouts of CAS](../figures/w/cas.svg)

Entry: [CAS](../09-isa.md#cas-compare-and-swap). 1 form.

<a id="w-casdb"></a>
### CASDB

![Layouts of CASDB](../figures/w/casdb.svg)

Entry: [CAS](../09-isa.md#cas-compare-and-swap). 1 form.

<a id="w-cbcc"></a>
### CBCC

![Layouts of CBCC](../figures/w/cbcc.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 11 forms.

<a id="w-cbcs"></a>
### CBCS

![Layouts of CBCS](../figures/w/cbcs.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 11 forms.

<a id="w-cbeq"></a>
### CBEQ

![Layouts of CBEQ](../figures/w/cbeq.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 21 forms.

<a id="w-cbge"></a>
### CBGE

![Layouts of CBGE](../figures/w/cbge.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 10 forms.

<a id="w-cbgt"></a>
### CBGT

![Layouts of CBGT](../figures/w/cbgt.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 10 forms.

<a id="w-cbhi"></a>
### CBHI

![Layouts of CBHI](../figures/w/cbhi.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 11 forms.

<a id="w-cble"></a>
### CBLE

![Layouts of CBLE](../figures/w/cble.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 10 forms.

<a id="w-cblos"></a>
### CBLOS

![Layouts of CBLOS](../figures/w/cblos.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 11 forms.

<a id="w-cblt"></a>
### CBLT

![Layouts of CBLT](../figures/w/cblt.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 10 forms.

<a id="w-cbmi"></a>
### CBMI

![Layouts of CBMI](../figures/w/cbmi.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 2 forms.

<a id="w-cbne"></a>
### CBNE

![Layouts of CBNE](../figures/w/cbne.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 21 forms.

<a id="w-cbpl"></a>
### CBPL

![Layouts of CBPL](../figures/w/cbpl.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 2 forms.

<a id="w-cbvc"></a>
### CBVC

![Layouts of CBVC](../figures/w/cbvc.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 2 forms.

<a id="w-cbvs"></a>
### CBVS

![Layouts of CBVS](../figures/w/cbvs.svg)

Entry: [CBCC](../09-isa.md#cbcc-compare-and-branch-on-condition). 2 forms.

<a id="w-clmulh"></a>
### CLMULH

![Layouts of CLMULH](../figures/w/clmulh.svg)

Entry: [CLMUL](../09-isa.md#clmul-carry-less-multiply). 1 form.

<a id="w-clmull"></a>
### CLMULL

![Layouts of CLMULL](../figures/w/clmull.svg)

Entry: [CLMUL](../09-isa.md#clmul-carry-less-multiply). 1 form.

<a id="w-clo"></a>
### CLO

![Layouts of CLO](../figures/w/clo.svg)

Entry: [COUNT](../09-isa.md#count-count-leading-and-trailing-zeros-and-ones). 1 form.

<a id="w-clr"></a>
### CLR

![Layouts of CLR](../figures/w/clr.svg)

Entry: [CLR](../09-isa.md#clr-clear). 10 forms.

<a id="w-clz"></a>
### CLZ

![Layouts of CLZ](../figures/w/clz.svg)

Entry: [COUNT](../09-isa.md#count-count-leading-and-trailing-zeros-and-ones). 1 form.

<a id="w-cmp"></a>
### CMP

![Layouts of CMP](../figures/w/cmp.svg)

Entry: [CMP](../09-isa.md#cmp-compare). 19 forms.

<a id="w-com"></a>
### COM

![Layouts of COM](../figures/w/com.svg)

Entry: [COM](../09-isa.md#com-complement). 7 forms.

<a id="w-cto"></a>
### CTO

![Layouts of CTO](../figures/w/cto.svg)

Entry: [COUNT](../09-isa.md#count-count-leading-and-trailing-zeros-and-ones). 1 form.

<a id="w-ctz"></a>
### CTZ

![Layouts of CTZ](../figures/w/ctz.svg)

Entry: [COUNT](../09-isa.md#count-count-leading-and-trailing-zeros-and-ones). 1 form.

<a id="w-dec"></a>
### DEC

![Layouts of DEC](../figures/w/dec.svg)

Entry: [DEC](../09-isa.md#dec-decrement). 10 forms.

<a id="w-div"></a>
### DIV

![Layouts of DIV](../figures/w/div.svg)

Entry: [DIV](../09-isa.md#div-divide-and-remainder-signed-and-unsigned). 1 form.

<a id="w-divu"></a>
### DIVU

![Layouts of DIVU](../figures/w/divu.svg)

Entry: [DIV](../09-isa.md#div-divide-and-remainder-signed-and-unsigned). 1 form.

<a id="w-dshr"></a>
### DSHR

![Layouts of DSHR](../figures/w/dshr.svg)

Entry: [DSHR](../09-isa.md#dshr-double-width-funnel-shift-right). 1 form.

<a id="w-extb"></a>
### EXTB

![Layouts of EXTB](../figures/w/extb.svg)

Entry: [EXTB](../09-isa.md#extb-extract-a-bit-field). 1 form.

<a id="w-extzb"></a>
### EXTZB

![Layouts of EXTZB](../figures/w/extzb.svg)

Entry: [EXTB](../09-isa.md#extb-extract-a-bit-field). 1 form.

<a id="w-fabs"></a>
### FABS

![Layouts of FABS](../figures/w/fabs.svg)

Entry: [FSIGN](../09-isa.md#fsign-sign-operations-on-the-bits). 1 form.

<a id="w-fadd"></a>
### FADD

![Layouts of FADD](../figures/w/fadd.svg)

Entry: [FADD](../09-isa.md#fadd-floating-add-subtract-and-multiply-binary64). 11 forms.

<a id="w-fadd16"></a>
### FADD16

![Layouts of FADD16](../figures/w/fadd16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fadd32"></a>
### FADD32

![Layouts of FADD32](../figures/w/fadd32.svg)

Entry: [FSINGLE](../09-isa.md#fsingle-floating-arithmetic-binary32). 1 form.

<a id="w-fclass"></a>
### FCLASS

![Layouts of FCLASS](../figures/w/fclass.svg)

Entry: [FCLASS](../09-isa.md#fclass-classify-a-floating-point-value). 1 form.

<a id="w-fclass16"></a>
### FCLASS16

![Layouts of FCLASS16](../figures/w/fclass16.svg)

Entry: [FCLASS](../09-isa.md#fclass-classify-a-floating-point-value). 1 form.

<a id="w-fclass32"></a>
### FCLASS32

![Layouts of FCLASS32](../figures/w/fclass32.svg)

Entry: [FCLASS](../09-isa.md#fclass-classify-a-floating-point-value). 1 form.

<a id="w-fcmp"></a>
### FCMP

![Layouts of FCMP](../figures/w/fcmp.svg)

Entry: [FCMP](../09-isa.md#fcmp-floating-compare-binary64). 9 forms.

<a id="w-fcmp16"></a>
### FCMP16

![Layouts of FCMP16](../figures/w/fcmp16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fcmp32"></a>
### FCMP32

![Layouts of FCMP32](../figures/w/fcmp32.svg)

Entry: [FSINGLE](../09-isa.md#fsingle-floating-arithmetic-binary32). 1 form.

<a id="w-fcopysign"></a>
### FCOPYSIGN

![Layouts of FCOPYSIGN](../figures/w/fcopysign.svg)

Entry: [FSIGN](../09-isa.md#fsign-sign-operations-on-the-bits). 1 form.

<a id="w-fcvtdh"></a>
### FCVTDH

![Layouts of FCVTDH](../figures/w/fcvtdh.svg)

Entry: [FCVTH](../09-isa.md#fcvth-conversions-to-and-from-binary16). 1 form.

<a id="w-fcvtdq"></a>
### FCVTDQ

![Layouts of FCVTDQ](../figures/w/fcvtdq.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvtdqu"></a>
### FCVTDQU

![Layouts of FCVTDQU](../figures/w/fcvtdqu.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvtds"></a>
### FCVTDS

![Layouts of FCVTDS](../figures/w/fcvtds.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvthd"></a>
### FCVTHD

![Layouts of FCVTHD](../figures/w/fcvthd.svg)

Entry: [FCVTH](../09-isa.md#fcvth-conversions-to-and-from-binary16). 1 form.

<a id="w-fcvthl"></a>
### FCVTHL

![Layouts of FCVTHL](../figures/w/fcvthl.svg)

Entry: [FCVTH](../09-isa.md#fcvth-conversions-to-and-from-binary16). 1 form.

<a id="w-fcvths"></a>
### FCVTHS

![Layouts of FCVTHS](../figures/w/fcvths.svg)

Entry: [FCVTH](../09-isa.md#fcvth-conversions-to-and-from-binary16). 1 form.

<a id="w-fcvtlh"></a>
### FCVTLH

![Layouts of FCVTLH](../figures/w/fcvtlh.svg)

Entry: [FCVTH](../09-isa.md#fcvth-conversions-to-and-from-binary16). 1 form.

<a id="w-fcvtls"></a>
### FCVTLS

![Layouts of FCVTLS](../figures/w/fcvtls.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvtqd"></a>
### FCVTQD

![Layouts of FCVTQD](../figures/w/fcvtqd.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvtqud"></a>
### FCVTQUD

![Layouts of FCVTQUD](../figures/w/fcvtqud.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvtsd"></a>
### FCVTSD

![Layouts of FCVTSD](../figures/w/fcvtsd.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fcvtsh"></a>
### FCVTSH

![Layouts of FCVTSH](../figures/w/fcvtsh.svg)

Entry: [FCVTH](../09-isa.md#fcvth-conversions-to-and-from-binary16). 1 form.

<a id="w-fcvtsl"></a>
### FCVTSL

![Layouts of FCVTSL](../figures/w/fcvtsl.svg)

Entry: [FCVT](../09-isa.md#fcvt-floating-conversions). 1 form.

<a id="w-fdiv"></a>
### FDIV

![Layouts of FDIV](../figures/w/fdiv.svg)

Entry: [FDIV](../09-isa.md#fdiv-floating-divide-and-square-root-binary64). 1 form.

<a id="w-fdiv16"></a>
### FDIV16

![Layouts of FDIV16](../figures/w/fdiv16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fdiv32"></a>
### FDIV32

![Layouts of FDIV32](../figures/w/fdiv32.svg)

Entry: [FSINGLE](../09-isa.md#fsingle-floating-arithmetic-binary32). 1 form.

<a id="w-fence"></a>
### FENCE

![Layouts of FENCE](../figures/w/fence.svg)

Entry: [FENCE](../09-isa.md#fence-memory-fence). 1 form.

<a id="w-fmadd"></a>
### FMADD

![Layouts of FMADD](../figures/w/fmadd.svg)

Entry: [FMADD](../09-isa.md#fmadd-fused-multiply-add-binary64). 1 form.

<a id="w-fmadd16"></a>
### FMADD16

![Layouts of FMADD16](../figures/w/fmadd16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fmadd32"></a>
### FMADD32

![Layouts of FMADD32](../figures/w/fmadd32.svg)

Entry: [FMADD32](../09-isa.md#fmadd32-fused-multiply-add-binary32). 1 form.

<a id="w-fmax"></a>
### FMAX

![Layouts of FMAX](../figures/w/fmax.svg)

Entry: [FMIN](../09-isa.md#fmin-floating-minimum-and-maximum-binary64). 1 form.

<a id="w-fmin"></a>
### FMIN

![Layouts of FMIN](../figures/w/fmin.svg)

Entry: [FMIN](../09-isa.md#fmin-floating-minimum-and-maximum-binary64). 1 form.

<a id="w-fmsub"></a>
### FMSUB

![Layouts of FMSUB](../figures/w/fmsub.svg)

Entry: [FMADD](../09-isa.md#fmadd-fused-multiply-add-binary64). 1 form.

<a id="w-fmsub16"></a>
### FMSUB16

![Layouts of FMSUB16](../figures/w/fmsub16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fmsub32"></a>
### FMSUB32

![Layouts of FMSUB32](../figures/w/fmsub32.svg)

Entry: [FMADD32](../09-isa.md#fmadd32-fused-multiply-add-binary32). 1 form.

<a id="w-fmul"></a>
### FMUL

![Layouts of FMUL](../figures/w/fmul.svg)

Entry: [FADD](../09-isa.md#fadd-floating-add-subtract-and-multiply-binary64). 11 forms.

<a id="w-fmul16"></a>
### FMUL16

![Layouts of FMUL16](../figures/w/fmul16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fmul32"></a>
### FMUL32

![Layouts of FMUL32](../figures/w/fmul32.svg)

Entry: [FSINGLE](../09-isa.md#fsingle-floating-arithmetic-binary32). 1 form.

<a id="w-fneg"></a>
### FNEG

![Layouts of FNEG](../figures/w/fneg.svg)

Entry: [FSIGN](../09-isa.md#fsign-sign-operations-on-the-bits). 1 form.

<a id="w-fnmadd"></a>
### FNMADD

![Layouts of FNMADD](../figures/w/fnmadd.svg)

Entry: [FMADD](../09-isa.md#fmadd-fused-multiply-add-binary64). 1 form.

<a id="w-fnmadd16"></a>
### FNMADD16

![Layouts of FNMADD16](../figures/w/fnmadd16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fnmadd32"></a>
### FNMADD32

![Layouts of FNMADD32](../figures/w/fnmadd32.svg)

Entry: [FMADD32](../09-isa.md#fmadd32-fused-multiply-add-binary32). 1 form.

<a id="w-fnmsub"></a>
### FNMSUB

![Layouts of FNMSUB](../figures/w/fnmsub.svg)

Entry: [FMADD](../09-isa.md#fmadd-fused-multiply-add-binary64). 1 form.

<a id="w-fnmsub16"></a>
### FNMSUB16

![Layouts of FNMSUB16](../figures/w/fnmsub16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fnmsub32"></a>
### FNMSUB32

![Layouts of FNMSUB32](../figures/w/fnmsub32.svg)

Entry: [FMADD32](../09-isa.md#fmadd32-fused-multiply-add-binary32). 1 form.

<a id="w-frint"></a>
### FRINT

![Layouts of FRINT](../figures/w/frint.svg)

Entry: [FRINT](../09-isa.md#frint-round-to-an-integral-value-binary64). 1 form.

<a id="w-frinta"></a>
### FRINTA

![Layouts of FRINTA](../figures/w/frinta.svg)

Entry: [FRINT](../09-isa.md#frint-round-to-an-integral-value-binary64). 1 form.

<a id="w-frintm"></a>
### FRINTM

![Layouts of FRINTM](../figures/w/frintm.svg)

Entry: [FRINT](../09-isa.md#frint-round-to-an-integral-value-binary64). 1 form.

<a id="w-frintp"></a>
### FRINTP

![Layouts of FRINTP](../figures/w/frintp.svg)

Entry: [FRINT](../09-isa.md#frint-round-to-an-integral-value-binary64). 1 form.

<a id="w-frintz"></a>
### FRINTZ

![Layouts of FRINTZ](../figures/w/frintz.svg)

Entry: [FRINT](../09-isa.md#frint-round-to-an-integral-value-binary64). 1 form.

<a id="w-fsflags"></a>
### FSFLAGS

![Layouts of FSFLAGS](../figures/w/fsflags.svg)

Entry: [FSFLAGS](../09-isa.md#fsflags-swap-the-floating-point-exception-flags). 1 form.

<a id="w-fsqrt"></a>
### FSQRT

![Layouts of FSQRT](../figures/w/fsqrt.svg)

Entry: [FDIV](../09-isa.md#fdiv-floating-divide-and-square-root-binary64). 1 form.

<a id="w-fsqrt16"></a>
### FSQRT16

![Layouts of FSQRT16](../figures/w/fsqrt16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fsqrt32"></a>
### FSQRT32

![Layouts of FSQRT32](../figures/w/fsqrt32.svg)

Entry: [FSINGLE](../09-isa.md#fsingle-floating-arithmetic-binary32). 1 form.

<a id="w-fsub"></a>
### FSUB

![Layouts of FSUB](../figures/w/fsub.svg)

Entry: [FADD](../09-isa.md#fadd-floating-add-subtract-and-multiply-binary64). 11 forms.

<a id="w-fsub16"></a>
### FSUB16

![Layouts of FSUB16](../figures/w/fsub16.svg)

Entry: [FHALF](../09-isa.md#fhalf-floating-arithmetic-binary16). 1 form.

<a id="w-fsub32"></a>
### FSUB32

![Layouts of FSUB32](../figures/w/fsub32.svg)

Entry: [FSINGLE](../09-isa.md#fsingle-floating-arithmetic-binary32). 1 form.

<a id="w-halt"></a>
### HALT

![Layouts of HALT](../figures/w/halt.svg)

Entry: [HALT](../09-isa.md#halt-halt-the-processor). 1 form.

<a id="w-hint"></a>
### HINT

![Layouts of HINT](../figures/w/hint.svg)

Entry: [HINT](../09-isa.md#hint-hint). 1 form.

<a id="w-icinv"></a>
### ICINV

![Layouts of ICINV](../figures/w/icinv.svg)

Entry: [ICINV](../09-isa.md#icinv-invalidate-the-instruction-cache-for-an-address). 1 form.

<a id="w-icinva"></a>
### ICINVA

![Layouts of ICINVA](../figures/w/icinva.svg)

Entry: [TLBA](../09-isa.md#tlba-invalidate-all-translations-wait-for-translation-invalidations-invalidate-the-whole-instruction-cache). 1 form.

<a id="w-inc"></a>
### INC

![Layouts of INC](../figures/w/inc.svg)

Entry: [INC](../09-isa.md#inc-increment). 10 forms.

<a id="w-insb"></a>
### INSB

![Layouts of INSB](../figures/w/insb.svg)

Entry: [INSB](../09-isa.md#insb-insert-a-bit-field). 1 form.

<a id="w-isync"></a>
### ISYNC

![Layouts of ISYNC](../figures/w/isync.svg)

Entry: [ISYNC](../09-isa.md#isync-instruction-synchronisation). 1 form.

<a id="w-jmp"></a>
### JMP

![Layouts of JMP](../figures/w/jmp.svg)

Entry: [JMP](../09-isa.md#jmp-jump). 12 forms.

<a id="w-jmpi"></a>
### JMPI

![Layouts of JMPI](../figures/w/jmpi.svg)

Entry: [JMPI](../09-isa.md#jmpi-jump-and-call-through-memory). 9 forms.

<a id="w-jtag"></a>
### JTAG

![Layouts of JTAG](../figures/w/jtag.svg)

Entry: [JTAG](../09-isa.md#jtag-jump-through-a-tag-table). 2 forms.

<a id="w-lea"></a>
### LEA

![Layouts of LEA](../figures/w/lea.svg)

Entry: [LEA](../09-isa.md#lea-load-effective-address). 26 forms.

<a id="w-ll"></a>
### LL

![Layouts of LL](../figures/w/ll.svg)

Entry: [LLSC](../09-isa.md#llsc-load-linked-and-store-conditional). 1 form.

<a id="w-lpad"></a>
### LPAD

![Layouts of LPAD](../figures/w/lpad.svg)

Entry: [NOP](../09-isa.md#nop-no-operation-and-landing-pad). 1 form.

<a id="w-maesctr"></a>
### MAESCTR

![Layouts of MAESCTR](../figures/w/maesctr.svg)

Entry: [MAESCTR](../09-isa.md#maesctr-aes-in-counter-mode-over-a-buffer). 1 form.

<a id="w-maskeqz"></a>
### MASKEQZ

![Layouts of MASKEQZ](../figures/w/maskeqz.svg)

Entry: [MASK](../09-isa.md#mask-mask-by-a-condition-register). 1 form.

<a id="w-masknez"></a>
### MASKNEZ

![Layouts of MASKNEZ](../figures/w/masknez.svg)

Entry: [MASK](../09-isa.md#mask-mask-by-a-condition-register). 1 form.

<a id="w-max"></a>
### MAX

![Layouts of MAX](../figures/w/max.svg)

Entry: [MINMAX](../09-isa.md#minmax-minimum-and-maximum-signed-and-unsigned). 1 form.

<a id="w-maxu"></a>
### MAXU

![Layouts of MAXU](../figures/w/maxu.svg)

Entry: [MINMAX](../09-isa.md#minmax-minimum-and-maximum-signed-and-unsigned). 1 form.

<a id="w-mcmp"></a>
### MCMP

![Layouts of MCMP](../figures/w/mcmp.svg)

Entry: [MCMP](../09-isa.md#mcmp-compare-two-blocks-of-bytes). 1 form.

<a id="w-mcpy"></a>
### MCPY

![Layouts of MCPY](../figures/w/mcpy.svg)

Entry: [MCPY](../09-isa.md#mcpy-copy-a-block-of-bytes). 1 form.

<a id="w-mfasid"></a>
### MFASID

![Layouts of MFASID](../figures/w/mfasid.svg)

Entry: [MTASID](../09-isa.md#mtasid-move-to-and-from-the-address-space-identifier). 1 form.

<a id="w-mfcpuid"></a>
### MFCPUID

![Layouts of MFCPUID](../figures/w/mfcpuid.svg)

Entry: [MFCPUID](../09-isa.md#mfcpuid-read-the-processor-identifier). 1 form.

<a id="w-mfdp"></a>
### MFDP

![Layouts of MFDP](../figures/w/mfdp.svg)

Entry: [MTDP](../09-isa.md#mtdp-move-to-and-from-the-direct-pointer). 1 form.

<a id="w-mfps"></a>
### MFPS

![Layouts of MFPS](../figures/w/mfps.svg)

Entry: [MTPS](../09-isa.md#mtps-move-to-and-from-the-processor-status-word). 1 form.

<a id="w-mfsr"></a>
### MFSR

![Layouts of MFSR](../figures/w/mfsr.svg)

Entry: [MFSR](../09-isa.md#mfsr-move-from-and-to-a-system-register). 1 form.

<a id="w-min"></a>
### MIN

![Layouts of MIN](../figures/w/min.svg)

Entry: [MINMAX](../09-isa.md#minmax-minimum-and-maximum-signed-and-unsigned). 1 form.

<a id="w-minu"></a>
### MINU

![Layouts of MINU](../figures/w/minu.svg)

Entry: [MINMAX](../09-isa.md#minmax-minimum-and-maximum-signed-and-unsigned). 1 form.

<a id="w-mmov"></a>
### MMOV

![Layouts of MMOV](../figures/w/mmov.svg)

Entry: [MCPY](../09-isa.md#mcpy-copy-a-block-of-bytes). 1 form.

<a id="w-mod"></a>
### MOD

![Layouts of MOD](../figures/w/mod.svg)

Entry: [DIV](../09-isa.md#div-divide-and-remainder-signed-and-unsigned). 1 form.

<a id="w-modu"></a>
### MODU

![Layouts of MODU](../figures/w/modu.svg)

Entry: [DIV](../09-isa.md#div-divide-and-remainder-signed-and-unsigned). 1 form.

<a id="w-mov2"></a>
### MOV2

![Layouts of MOV2](../figures/w/mov2.svg)

Entry: [MOV2](../09-isa.md#mov2-two-register-moves). 1 form.

<a id="w-movb"></a>
### MOVB

![Layouts of MOVB](../figures/w/movb.svg)

Entry: [MOV](../09-isa.md#mov-move-load-and-store-64-32-16-and-8-bits). 33 forms.

<a id="w-movb-d"></a>
### MOVB.D

![Layouts of MOVB.D](../figures/w/movb-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movb-u"></a>
### MOVB.U

![Layouts of MOVB.U](../figures/w/movb-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 6 forms.

<a id="w-movb-ud"></a>
### MOVB.UD

![Layouts of MOVB.UD](../figures/w/movb-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-movcall"></a>
### MOVCALL

![Layouts of MOVCALL](../figures/w/movcall.svg)

Entry: [MOVCALL](../09-isa.md#movcall-move-a-register-and-call). 2 forms.

<a id="w-movl"></a>
### MOVL

![Layouts of MOVL](../figures/w/movl.svg)

Entry: [MOV](../09-isa.md#mov-move-load-and-store-64-32-16-and-8-bits). 42 forms.

<a id="w-movl-d"></a>
### MOVL.D

![Layouts of MOVL.D](../figures/w/movl-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movl-u"></a>
### MOVL.U

![Layouts of MOVL.U](../figures/w/movl-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 6 forms.

<a id="w-movl-ud"></a>
### MOVL.UD

![Layouts of MOVL.UD](../figures/w/movl-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-movq"></a>
### MOVQ

![Layouts of MOVQ](../figures/w/movq.svg)

Entry: [MOV](../09-isa.md#mov-move-load-and-store-64-32-16-and-8-bits). 48 forms.

<a id="w-movq-d"></a>
### MOVQ.D

![Layouts of MOVQ.D](../figures/w/movq-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movq-u"></a>
### MOVQ.U

![Layouts of MOVQ.U](../figures/w/movq-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 6 forms.

<a id="w-movq-ud"></a>
### MOVQ.UD

![Layouts of MOVQ.UD](../figures/w/movq-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-movql"></a>
### MOVQL

![Layouts of MOVQL](../figures/w/movql.svg)

Entry: [MOVQL](../09-isa.md#movql-move-a-64-bit-literal). 1 form.

<a id="w-movub"></a>
### MOVUB

![Layouts of MOVUB](../figures/w/movub.svg)

Entry: [MOVU](../09-isa.md#movu-unaligned-load-and-store). 13 forms.

<a id="w-movul"></a>
### MOVUL

![Layouts of MOVUL](../figures/w/movul.svg)

Entry: [MOVU](../09-isa.md#movu-unaligned-load-and-store). 13 forms.

<a id="w-movuq"></a>
### MOVUQ

![Layouts of MOVUQ](../figures/w/movuq.svg)

Entry: [MOVU](../09-isa.md#movu-unaligned-load-and-store). 13 forms.

<a id="w-movuw"></a>
### MOVUW

![Layouts of MOVUW](../figures/w/movuw.svg)

Entry: [MOVU](../09-isa.md#movu-unaligned-load-and-store). 13 forms.

<a id="w-movw"></a>
### MOVW

![Layouts of MOVW](../figures/w/movw.svg)

Entry: [MOV](../09-isa.md#mov-move-load-and-store-64-32-16-and-8-bits). 32 forms.

<a id="w-movw-d"></a>
### MOVW.D

![Layouts of MOVW.D](../figures/w/movw-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movw-u"></a>
### MOVW.U

![Layouts of MOVW.U](../figures/w/movw-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 6 forms.

<a id="w-movw-ud"></a>
### MOVW.UD

![Layouts of MOVW.UD](../figures/w/movw-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-movzb"></a>
### MOVZB

![Layouts of MOVZB](../figures/w/movzb.svg)

Entry: [MOVZ](../09-isa.md#movz-move-zero-extended-32-16-and-8-bits). 25 forms.

<a id="w-movzb-d"></a>
### MOVZB.D

![Layouts of MOVZB.D](../figures/w/movzb-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movzb-u"></a>
### MOVZB.U

![Layouts of MOVZB.U](../figures/w/movzb-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 3 forms.

<a id="w-movzb-ud"></a>
### MOVZB.UD

![Layouts of MOVZB.UD](../figures/w/movzb-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-movzl"></a>
### MOVZL

![Layouts of MOVZL](../figures/w/movzl.svg)

Entry: [MOVZ](../09-isa.md#movz-move-zero-extended-32-16-and-8-bits). 17 forms.

<a id="w-movzl-d"></a>
### MOVZL.D

![Layouts of MOVZL.D](../figures/w/movzl-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movzl-u"></a>
### MOVZL.U

![Layouts of MOVZL.U](../figures/w/movzl-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 3 forms.

<a id="w-movzl-ud"></a>
### MOVZL.UD

![Layouts of MOVZL.UD](../figures/w/movzl-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-movzw"></a>
### MOVZW

![Layouts of MOVZW](../figures/w/movzw.svg)

Entry: [MOVZ](../09-isa.md#movz-move-zero-extended-32-16-and-8-bits). 17 forms.

<a id="w-movzw-d"></a>
### MOVZW.D

![Layouts of MOVZW.D](../figures/w/movzw-d.svg)

Entry: [MOVD](../09-isa.md#movd-deferred-fault-load). 3 forms.

<a id="w-movzw-u"></a>
### MOVZW.U

![Layouts of MOVZW.U](../figures/w/movzw-u.svg)

Entry: [MOVUSER](../09-isa.md#movuser-user-qualified-load-and-store). 3 forms.

<a id="w-movzw-ud"></a>
### MOVZW.UD

![Layouts of MOVZW.UD](../figures/w/movzw-ud.svg)

Entry: [MOVUSERD](../09-isa.md#movuserd-user-qualified-deferred-fault-load). 3 forms.

<a id="w-mscn"></a>
### MSCN

![Layouts of MSCN](../figures/w/mscn.svg)

Entry: [MSCN](../09-isa.md#mscn-scan-a-block-for-a-byte-or-for-a-byte-not-equal-to-it). 1 form.

<a id="w-mscnn"></a>
### MSCNN

![Layouts of MSCNN](../figures/w/mscnn.svg)

Entry: [MSCN](../09-isa.md#mscn-scan-a-block-for-a-byte-or-for-a-byte-not-equal-to-it). 1 form.

<a id="w-mset"></a>
### MSET

![Layouts of MSET](../figures/w/mset.svg)

Entry: [MSET](../09-isa.md#mset-fill-a-block-of-bytes). 1 form.

<a id="w-msha256"></a>
### MSHA256

![Layouts of MSHA256](../figures/w/msha256.svg)

Entry: [MSHA](../09-isa.md#msha-hash-whole-blocks-of-memory). 1 form.

<a id="w-msha512"></a>
### MSHA512

![Layouts of MSHA512](../figures/w/msha512.svg)

Entry: [MSHA](../09-isa.md#msha-hash-whole-blocks-of-memory). 1 form.

<a id="w-mtasid"></a>
### MTASID

![Layouts of MTASID](../figures/w/mtasid.svg)

Entry: [MTASID](../09-isa.md#mtasid-move-to-and-from-the-address-space-identifier). 1 form.

<a id="w-mtdmw"></a>
### MTDMW

![Layouts of MTDMW](../figures/w/mtdmw.svg)

Entry: [MTDMW](../09-isa.md#mtdmw-move-to-a-direct-mapping-window). 1 form.

<a id="w-mtdp"></a>
### MTDP

![Layouts of MTDP](../figures/w/mtdp.svg)

Entry: [MTDP](../09-isa.md#mtdp-move-to-and-from-the-direct-pointer). 1 form.

<a id="w-mtps"></a>
### MTPS

![Layouts of MTPS](../figures/w/mtps.svg)

Entry: [MTPS](../09-isa.md#mtps-move-to-and-from-the-processor-status-word). 1 form.

<a id="w-mtsr"></a>
### MTSR

![Layouts of MTSR](../figures/w/mtsr.svg)

Entry: [MFSR](../09-isa.md#mfsr-move-from-and-to-a-system-register). 1 form.

<a id="w-mul"></a>
### MUL

![Layouts of MUL](../figures/w/mul.svg)

Entry: [MUL](../09-isa.md#mul-multiply-low-64-bits). 13 forms.

<a id="w-mulh"></a>
### MULH

![Layouts of MULH](../figures/w/mulh.svg)

Entry: [MULH](../09-isa.md#mulh-multiply-high-64-bits-signed). 11 forms.

<a id="w-mulhu"></a>
### MULHU

![Layouts of MULHU](../figures/w/mulhu.svg)

Entry: [MULHU](../09-isa.md#mulhu-multiply-high-64-bits-unsigned). 1 form.

<a id="w-mulv"></a>
### MULV

![Layouts of MULV](../figures/w/mulv.svg)

Entry: [OVF](../09-isa.md#ovf-add-subtract-and-multiply-trapping-on-signed-overflow). 1 form.

<a id="w-mval"></a>
### MVAL

![Layouts of MVAL](../figures/w/mval.svg)

Entry: [MVAL](../09-isa.md#mval-validate-a-block-as-utf-8). 1 form.

<a id="w-neg"></a>
### NEG

![Layouts of NEG](../figures/w/neg.svg)

Entry: [NEG](../09-isa.md#neg-negate). 7 forms.

<a id="w-nop"></a>
### NOP

![Layouts of NOP](../figures/w/nop.svg)

Entry: [NOP](../09-isa.md#nop-no-operation-and-landing-pad). 1 form.

<a id="w-pop"></a>
### POP

![Layouts of POP](../figures/w/pop.svg)

Entry: [POP](../09-isa.md#pop-pop). 10 forms.

<a id="w-popcnt"></a>
### POPCNT

![Layouts of POPCNT](../figures/w/popcnt.svg)

Entry: [POPCNT](../09-isa.md#popcnt-population-count). 1 form.

<a id="w-popm"></a>
### POPM

![Layouts of POPM](../figures/w/popm.svg)

Entry: [POPM](../09-isa.md#popm-pop-registers-by-mask). 4 forms.

<a id="w-popmret"></a>
### POPMRET

![Layouts of POPMRET](../figures/w/popmret.svg)

Entry: [POPMRET](../09-isa.md#popmret-pop-several-registers-and-return). 1 form.

<a id="w-popret"></a>
### POPRET

![Layouts of POPRET](../figures/w/popret.svg)

Entry: [POPRET](../09-isa.md#popret-pop-a-register-and-return). 1 form.

<a id="w-popx"></a>
### POPX

![Layouts of POPX](../figures/w/popx.svg)

Entry: [PUSHX](../09-isa.md#pushx-push-and-pop-the-exception-state). 1 form.

<a id="w-prober"></a>
### PROBER

![Layouts of PROBER](../figures/w/prober.svg)

Entry: [PROBE](../09-isa.md#probe-probe-an-address-for-read-or-write-access). 1 form.

<a id="w-probew"></a>
### PROBEW

![Layouts of PROBEW](../figures/w/probew.svg)

Entry: [PROBE](../09-isa.md#probe-probe-an-address-for-read-or-write-access). 1 form.

<a id="w-push"></a>
### PUSH

![Layouts of PUSH](../figures/w/push.svg)

Entry: [PUSH](../09-isa.md#push-push). 12 forms.

<a id="w-pushm"></a>
### PUSHM

![Layouts of PUSHM](../figures/w/pushm.svg)

Entry: [PUSHM](../09-isa.md#pushm-push-registers-by-mask). 4 forms.

<a id="w-pushx"></a>
### PUSHX

![Layouts of PUSHX](../figures/w/pushx.svg)

Entry: [PUSHX](../09-isa.md#pushx-push-and-pop-the-exception-state). 1 form.

<a id="w-ret"></a>
### RET

![Layouts of RET](../figures/w/ret.svg)

Entry: [RET](../09-isa.md#ret-return-from-subroutine). 1 form.

<a id="w-ror"></a>
### ROR

![Layouts of ROR](../figures/w/ror.svg)

Entry: [ROR](../09-isa.md#ror-rotate-right-by-a-register-count). 1 form.

<a id="w-rori"></a>
### RORI

![Layouts of RORI](../figures/w/rori.svg)

Entry: [RORI](../09-isa.md#rori-rotate-right-by-an-immediate). 1 form.

<a id="w-rori32"></a>
### RORI32

![Layouts of RORI32](../figures/w/rori32.svg)

Entry: [RORI32](../09-isa.md#rori32-rotate-right-by-an-immediate-32-bits). 1 form.

<a id="w-rti"></a>
### RTI

![Layouts of RTI](../figures/w/rti.svg)

Entry: [RTI](../09-isa.md#rti-return-from-interrupt-or-exception). 1 form.

<a id="w-rtt"></a>
### RTT

![Layouts of RTT](../figures/w/rtt.svg)

Entry: [RTI](../09-isa.md#rti-return-from-interrupt-or-exception). 1 form.

<a id="w-sar"></a>
### SAR

![Layouts of SAR](../figures/w/sar.svg)

Entry: [SHIFT](../09-isa.md#shift-shift-left-shift-right-logical-shift-right-arithmetic). 14 forms.

<a id="w-sbc"></a>
### SBC

![Layouts of SBC](../figures/w/sbc.svg)

Entry: [SBC](../09-isa.md#sbc-subtract-carry). 7 forms.

<a id="w-sc"></a>
### SC

![Layouts of SC](../figures/w/sc.svg)

Entry: [LLSC](../09-isa.md#llsc-load-linked-and-store-conditional). 1 form.

<a id="w-set"></a>
### SET

![Layouts of SET](../figures/w/set.svg)

Entry: [SET](../09-isa.md#set-set-a-register-from-a-condition). 1 form.

<a id="w-sev"></a>
### SEV

![Layouts of SEV](../figures/w/sev.svg)

Entry: [SEV](../09-isa.md#sev-send-an-event). 1 form.

<a id="w-sha256sig0"></a>
### SHA256SIG0

![Layouts of SHA256SIG0](../figures/w/sha256sig0.svg)

Entry: [SHA256](../09-isa.md#sha256-the-sha-256-functions). 1 form.

<a id="w-sha256sig1"></a>
### SHA256SIG1

![Layouts of SHA256SIG1](../figures/w/sha256sig1.svg)

Entry: [SHA256](../09-isa.md#sha256-the-sha-256-functions). 1 form.

<a id="w-sha256sum0"></a>
### SHA256SUM0

![Layouts of SHA256SUM0](../figures/w/sha256sum0.svg)

Entry: [SHA256](../09-isa.md#sha256-the-sha-256-functions). 1 form.

<a id="w-sha256sum1"></a>
### SHA256SUM1

![Layouts of SHA256SUM1](../figures/w/sha256sum1.svg)

Entry: [SHA256](../09-isa.md#sha256-the-sha-256-functions). 1 form.

<a id="w-sha512sig0"></a>
### SHA512SIG0

![Layouts of SHA512SIG0](../figures/w/sha512sig0.svg)

Entry: [SHA512](../09-isa.md#sha512-the-sha-512-functions). 1 form.

<a id="w-sha512sig1"></a>
### SHA512SIG1

![Layouts of SHA512SIG1](../figures/w/sha512sig1.svg)

Entry: [SHA512](../09-isa.md#sha512-the-sha-512-functions). 1 form.

<a id="w-sha512sum0"></a>
### SHA512SUM0

![Layouts of SHA512SUM0](../figures/w/sha512sum0.svg)

Entry: [SHA512](../09-isa.md#sha512-the-sha-512-functions). 1 form.

<a id="w-sha512sum1"></a>
### SHA512SUM1

![Layouts of SHA512SUM1](../figures/w/sha512sum1.svg)

Entry: [SHA512](../09-isa.md#sha512-the-sha-512-functions). 1 form.

<a id="w-shl"></a>
### SHL

![Layouts of SHL](../figures/w/shl.svg)

Entry: [SHIFT](../09-isa.md#shift-shift-left-shift-right-logical-shift-right-arithmetic). 15 forms.

<a id="w-shr"></a>
### SHR

![Layouts of SHR](../figures/w/shr.svg)

Entry: [SHIFT](../09-isa.md#shift-shift-left-shift-right-logical-shift-right-arithmetic). 14 forms.

<a id="w-sob"></a>
### SOB

![Layouts of SOB](../figures/w/sob.svg)

Entry: [SOB](../09-isa.md#sob-subtract-one-and-branch). 1 form.

<a id="w-spl"></a>
### SPL

![Layouts of SPL](../figures/w/spl.svg)

Entry: [SPL](../09-isa.md#spl-set-the-interrupt-priority-level). 1 form.

<a id="w-sub"></a>
### SUB

![Layouts of SUB](../figures/w/sub.svg)

Entry: [SUB](../09-isa.md#sub-subtract). 24 forms.

<a id="w-subm"></a>
### SUBM

![Layouts of SUBM](../figures/w/subm.svg)

Entry: [ADDM](../09-isa.md#addm-alu-operation-with-a-memory-destination). 6 forms.

<a id="w-subv"></a>
### SUBV

![Layouts of SUBV](../figures/w/subv.svg)

Entry: [OVF](../09-isa.md#ovf-add-subtract-and-multiply-trapping-on-signed-overflow). 1 form.

<a id="w-swap"></a>
### SWAP

![Layouts of SWAP](../figures/w/swap.svg)

Entry: [SWAP](../09-isa.md#swap-atomic-exchange). 1 form.

<a id="w-swapdb"></a>
### SWAPDB

![Layouts of SWAPDB](../figures/w/swapdb.svg)

Entry: [SWAP](../09-isa.md#swap-atomic-exchange). 1 form.

<a id="w-syspg0"></a>
### SYSPG0

![Layouts of SYSPG0](../figures/w/syspg0.svg)

Entry: [SYSPG](../09-isa.md#syspg-reserved-system-words). 1 form.

<a id="w-syspg1"></a>
### SYSPG1

![Layouts of SYSPG1](../figures/w/syspg1.svg)

Entry: [SYSPG](../09-isa.md#syspg-reserved-system-words). 1 form.

<a id="w-syspg2"></a>
### SYSPG2

![Layouts of SYSPG2](../figures/w/syspg2.svg)

Entry: [SYSPG](../09-isa.md#syspg-reserved-system-words). 1 form.

<a id="w-syspg3"></a>
### SYSPG3

![Layouts of SYSPG3](../figures/w/syspg3.svg)

Entry: [SYSPG](../09-isa.md#syspg-reserved-system-words). 1 form.

<a id="w-syspg4"></a>
### SYSPG4

![Layouts of SYSPG4](../figures/w/syspg4.svg)

Entry: [SYSPG](../09-isa.md#syspg-reserved-system-words). 1 form.

<a id="w-syspg5"></a>
### SYSPG5

![Layouts of SYSPG5](../figures/w/syspg5.svg)

Entry: [SYSPG](../09-isa.md#syspg-reserved-system-words). 1 form.

<a id="w-tlbi"></a>
### TLBI

![Layouts of TLBI](../figures/w/tlbi.svg)

Entry: [TLBI](../09-isa.md#tlbi-invalidate-a-translation). 1 form.

<a id="w-tlbia"></a>
### TLBIA

![Layouts of TLBIA](../figures/w/tlbia.svg)

Entry: [TLBA](../09-isa.md#tlba-invalidate-all-translations-wait-for-translation-invalidations-invalidate-the-whole-instruction-cache). 1 form.

<a id="w-tlbsync"></a>
### TLBSYNC

![Layouts of TLBSYNC](../figures/w/tlbsync.svg)

Entry: [TLBA](../09-isa.md#tlba-invalidate-all-translations-wait-for-translation-invalidations-invalidate-the-whole-instruction-cache). 1 form.

<a id="w-trap"></a>
### TRAP

![Layouts of TRAP](../figures/w/trap.svg)

Entry: [TRAP](../09-isa.md#trap-system-call-and-trap). 1 form.

<a id="w-trapcc-cc"></a>
### TRAPCC.CC

![Layouts of TRAPCC.CC](../figures/w/trapcc-cc.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-cs"></a>
### TRAPCC.CS

![Layouts of TRAPCC.CS](../figures/w/trapcc-cs.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-eq"></a>
### TRAPCC.EQ

![Layouts of TRAPCC.EQ](../figures/w/trapcc-eq.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-ge"></a>
### TRAPCC.GE

![Layouts of TRAPCC.GE](../figures/w/trapcc-ge.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-gt"></a>
### TRAPCC.GT

![Layouts of TRAPCC.GT](../figures/w/trapcc-gt.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-hi"></a>
### TRAPCC.HI

![Layouts of TRAPCC.HI](../figures/w/trapcc-hi.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-le"></a>
### TRAPCC.LE

![Layouts of TRAPCC.LE](../figures/w/trapcc-le.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-los"></a>
### TRAPCC.LOS

![Layouts of TRAPCC.LOS](../figures/w/trapcc-los.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-lt"></a>
### TRAPCC.LT

![Layouts of TRAPCC.LT](../figures/w/trapcc-lt.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-mi"></a>
### TRAPCC.MI

![Layouts of TRAPCC.MI](../figures/w/trapcc-mi.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-ne"></a>
### TRAPCC.NE

![Layouts of TRAPCC.NE](../figures/w/trapcc-ne.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-pl"></a>
### TRAPCC.PL

![Layouts of TRAPCC.PL](../figures/w/trapcc-pl.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-vc"></a>
### TRAPCC.VC

![Layouts of TRAPCC.VC](../figures/w/trapcc-vc.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapcc-vs"></a>
### TRAPCC.VS

![Layouts of TRAPCC.VS](../figures/w/trapcc-vs.svg)

Entry: [TRAPCC](../09-isa.md#trapcc-trap-on-condition). 1 form.

<a id="w-trapl"></a>
### TRAPL

![Layouts of TRAPL](../figures/w/trapl.svg)

Entry: [TRAP](../09-isa.md#trap-system-call-and-trap). 1 form.

<a id="w-tst"></a>
### TST

![Layouts of TST](../figures/w/tst.svg)

Entry: [TST](../09-isa.md#tst-test). 10 forms.

<a id="w-utf8dec"></a>
### UTF8DEC

![Layouts of UTF8DEC](../figures/w/utf8dec.svg)

Entry: [UTF8DEC](../09-isa.md#utf8dec-decode-a-utf-8-sequence). 1 form.

<a id="w-utf8enc"></a>
### UTF8ENC

![Layouts of UTF8ENC](../figures/w/utf8enc.svg)

Entry: [UTF8ENC](../09-isa.md#utf8enc-encode-a-unicode-scalar-value). 1 form.

<a id="w-utf8len"></a>
### UTF8LEN

![Layouts of UTF8LEN](../figures/w/utf8len.svg)

Entry: [UTF8LEN](../09-isa.md#utf8len-length-of-a-utf-8-sequence-from-its-leading-byte). 1 form.

<a id="w-wfe"></a>
### WFE

![Layouts of WFE](../figures/w/wfe.svg)

Entry: [WFE](../09-isa.md#wfe-wait-for-an-event). 1 form.

<a id="w-xadd"></a>
### XADD

![Layouts of XADD](../figures/w/xadd.svg)

Entry: [XADD](../09-isa.md#xadd-atomic-fetch-and-add). 1 form.

<a id="w-xadddb"></a>
### XADDDB

![Layouts of XADDDB](../figures/w/xadddb.svg)

Entry: [XADD](../09-isa.md#xadd-atomic-fetch-and-add). 1 form.

<a id="w-xand"></a>
### XAND

![Layouts of XAND](../figures/w/xand.svg)

Entry: [XAND](../09-isa.md#xand-atomic-fetch-and-and-or-xor). 1 form.

<a id="w-xanddb"></a>
### XANDDB

![Layouts of XANDDB](../figures/w/xanddb.svg)

Entry: [XAND](../09-isa.md#xand-atomic-fetch-and-and-or-xor). 1 form.

<a id="w-xmax"></a>
### XMAX

![Layouts of XMAX](../figures/w/xmax.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xmaxdb"></a>
### XMAXDB

![Layouts of XMAXDB](../figures/w/xmaxdb.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xmaxu"></a>
### XMAXU

![Layouts of XMAXU](../figures/w/xmaxu.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xmaxudb"></a>
### XMAXUDB

![Layouts of XMAXUDB](../figures/w/xmaxudb.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xmin"></a>
### XMIN

![Layouts of XMIN](../figures/w/xmin.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xmindb"></a>
### XMINDB

![Layouts of XMINDB](../figures/w/xmindb.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xminu"></a>
### XMINU

![Layouts of XMINU](../figures/w/xminu.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xminudb"></a>
### XMINUDB

![Layouts of XMINUDB](../figures/w/xminudb.svg)

Entry: [XMAX](../09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum). 1 form.

<a id="w-xnorpop"></a>
### XNORPOP

![Layouts of XNORPOP](../figures/w/xnorpop.svg)

Entry: [XNORPOP](../09-isa.md#xnorpop-population-count-of-the-equality-of-two-words). 1 form.

<a id="w-xor"></a>
### XOR

![Layouts of XOR](../figures/w/xor.svg)

Entry: [XOR](../09-isa.md#xor-exclusive-or). 18 forms.

<a id="w-xor-"></a>
### XOR_

![Layouts of XOR_](../figures/w/xor-.svg)

Entry: [XAND](../09-isa.md#xand-atomic-fetch-and-and-or-xor). 1 form.

<a id="w-xor-db"></a>
### XOR_DB

![Layouts of XOR_DB](../figures/w/xor-db.svg)

Entry: [XAND](../09-isa.md#xand-atomic-fetch-and-and-or-xor). 1 form.

<a id="w-xxor"></a>
### XXOR

![Layouts of XXOR](../figures/w/xxor.svg)

Entry: [XAND](../09-isa.md#xand-atomic-fetch-and-and-or-xor). 1 form.

<a id="w-xxordb"></a>
### XXORDB

![Layouts of XXORDB](../figures/w/xxordb.svg)

Entry: [XAND](../09-isa.md#xand-atomic-fetch-and-and-or-xor). 1 form.

*Generated by `tools/mkmanual.py`; do not edit.*

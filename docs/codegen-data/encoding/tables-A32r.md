# A32r (r32 + 5-bit one-parcel RR for 8 mnemonics)

Leaves (prefix-coded groups of mnemonics). prefix = top L bits of parcel 0. `subop` selects the mnemonic inside the group (binary-aligned).

| parcels | form | L | prefix (P0 top bits) | mnemonics | fields (bit positions) |
|---|---|---|---|---|---|
| 1 | RR5 | 3 | 000 | movq movl add sub xor and bis shl | op1.r=p0[9:5] op2.r=p0[4:0] |
| 1 | RRF | 4 | 0010 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | RRF | 5 | 01000 | shr sar fadd fsub fmul bit cmp fcmp | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | IMMh47/a | 5 | 01001 | movq | op1.i=p0[10:4] op2.r=p0[3:0] |
| 1 | SYSI | 6 | 010100 | spl trap trapl hint | op1.i=p0[7:0] |
| 1 | LDSPh4/a | 6 | 011100 | movq movl movzb lea | op1.d=p0[7:4] op2.r=p0[3:0] |
| 1 | CBZ1_4/a | 6 | 011101 | cbeq cbne | op3.p=p0[8:5] op1.r=p0[4:0] |
| 1 | LDHHH2/a | 6 | 011111 | movq movl movzb lea | op1.d=p0[7:6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | SHIh44/a | 6 | 100000 | shl shr sar rol | op1.i=p0[7:4] op2.r=p0[3:0] |
| 1 | LD0h4/a | 6 | 100001 | movq movl movzb lea | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | LDHHH1/a | 7 | 1010010 | movq movl movzb lea | op1.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | PUSHM8/a | 7 | 1010100 | pushm popm | op1.i=p0[7:0] |
| 1 | SHIh43/a | 7 | 1010101 | shl shr sar rol | op1.i=p0[6:4] op2.r=p0[3:0] |
| 1 | IMMh45/a | 7 | 1010110 | movq | op1.i=p0[8:4] op2.r=p0[3:0] |
| 1 | STSPh4/a | 7 | 1010111 | movq movl | op2.d=p0[7:4] op1.r=p0[3:0] |
| 1 | BR1_9/a | 7 | 1011001 | br | op1.p=p0[8:0] |
| 1 | STHHH2/a | 7 | 1011011 | movq movl | op2.d=p0[7:6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | LDHHH1/b | 7 | 1011100 | movw movb movzl movzw | op1.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | BR1_6/c | 7 | 1011101 | bpl bmi bvc bvs bcc bcs bge blt | op1.p=p0[5:0] |
| 1 | SYSR | 8 | 10111100 | mtps mfps tlbi mtasid mfasid mtdp mfdp mtdmw | op1.r=p0[4:0] |
| 1 | SOPR | 8 | 11001100 | clr com inc dec neg tst adc sbc | op1.r=p0[4:0] |
| 1 | STHHH1/a | 8 | 11001110 | movq movl | op2.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | LEASPh4/a | 8 | 11001111 | lea | op1.d=p0[7:4] op2.r=p0[3:0] |
| 1 | BR1_8/a | 8 | 11010001 | br | op1.p=p0[7:0] |
| 1 | STHHH1/b | 8 | 11010010 | movw movb | op2.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | IMMh43/b | 8 | 11010011 | add sub | op1.i=p0[6:4] op2.r=p0[3:0] |
| 1 | BR1_7/b | 8 | 11010100 | beq bne | op1.p=p0[6:0] |
| 1 | BR1_6/c | 8 | 11010111 | bgt ble bhi blos | op1.p=p0[5:0] |
| 1 | SOPR | 9 | 110111011 | asl asr push pop | op1.r=p0[4:0] |
| 1 | IMMh43/a | 9 | 110111110 | movq | op1.i=p0[6:4] op2.r=p0[3:0] |
| 1 | SPADJ6/a | 9 | 111000000 | add sub | op1.i=p0[5:0] |
| 1 | BR1_6/b | 9 | 111000001 | beq bne | op1.p=p0[5:0] |
| 1 | BR1_7/a | 9 | 111000010 | br | op1.p=p0[6:0] |
| 1 | IMMh43/b | 9 | 111000101 | and | op1.i=p0[6:4] op2.r=p0[3:0] |
| 1 | CMPIh43/a | 9 | 111001000 | cmp | op2.i=p0[6:4] op1.r=p0[3:0] |
| 1 | SYSR | 10 | 1110010010 | mfcpuid icinv | op1.r=p0[4:0] |
| 1 | SOPR | 10 | 1110100000 | jmp call | op1.r=p0[4:0] |
| 1 | BR1_6/a | 10 | 1110100011 | br | op1.p=p0[5:0] |
| 1 | SYS0 | 11 | 11101100110 | nop rti rtt ret halt bpt fence wfe sev lpad tlbia tlbsync icinva pushx popx isync trapcc.ne trapcc.eq trapcc.pl trapcc.mi trapcc.vc trapcc.vs trapcc.cc trapcc.cs trapcc.ge trapcc.lt trapcc.gt trapcc.le trapcc.hi trapcc.los syspg0 syspg1 |  |
| 1 | SYS0 | 14 | 11110010001110 | syspg2 syspg3 syspg4 syspg5 |  |
| 2 | LDU.X6 | 5 | 00110 | movq.u movl.u movw.u movb.u movzl.u movzw.u movzb.u movq.d movl.d movw.d movb.d movzl.d movzw.d movzb.d movq.ud movl.ud | op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[4:0] |
| 2 | LDU.B12 | 6 | 010110 | movq.u movl.u movw.u movb.u movzl.u movzw.u movzb.u movq.d movl.d movw.d movb.d movzl.d movzw.d movzb.d movq.ud movl.ud | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDF.PI12 | 6 | 011001 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDF.PD12 | 6 | 011010 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | CBI12_8H/c | 6 | 011110 | cbcs cbcc cbhi cblos | op2.i=p0[7:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | LDU.X6 | 7 | 1000101 | movw.ud movb.ud movzl.ud movzw.ud | op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[4:0] |
| 2 | STU.X6 | 7 | 1000110 | movq.u movl.u movw.u movb.u | op1.r=p0[6:5]+p1[15:13] op2.r=p1[12:8] op2.s=p1[7:6] op2.d=p1[5:0] op2.r=p0[4:0] |
| 2 | LDF.PI12 | 7 | 1001000 | shr sar fadd fsub fmul bit lea movub | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDF.PD12 | 7 | 1001001 | shr sar fadd fsub fmul bit lea movub | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | STF.PI12 | 7 | 1001111 | movq movl movw movb movub movuw movul movuq | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | STF.PD12 | 7 | 1010000 | movq movl movw movb movub movuw movul movuq | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | CBI8_12H/a | 7 | 1010001 | cbeq cbne | op2.i=p0[7:4]+p1[15:12] op3.p=p1[11:0] op1.r=p0[3:0] |
| 2 | CBI12_8H/a | 7 | 1010011 | cbeq cbne | op2.i=p0[7:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | PUSHM24/a | 7 | 1011000 | pushm popm | op1.i=p0[7:0]+p1[15:0] |
| 2 | CBI10_10H/a | 7 | 1011010 | cbeq cbne | op2.i=p0[7:4]+p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | R4 | 8 | 10111101 | fmadd fmsub fnmadd fnmsub fmadd32 fmsub32 fnmadd32 fnmsub32 fmadd16 fmsub16 fnmadd16 fnmsub16 bsel cas casdb maesctr | subop=p0[7:5]+p1[15] op1.r=p1[14:10] op2.r=p1[9:5] op3.r=p1[4:0] op4.r=p0[4:0] |
| 2 | LDU.B12 | 8 | 11000001 | movw.ud movb.ud movzl.ud movzw.ud | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | STU.B12 | 8 | 11000010 | movq.u movl.u movw.u movb.u | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | STF.PI12 | 8 | 11000111 | addm subm bicm bism | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | STF.PD12 | 8 | 11001000 | addm subm bicm bism | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | CBI10_8H/c | 8 | 11001101 | cbcs cbcc cbhi cblos | op2.i=p0[5:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI10_8H/b | 8 | 11010000 | cblt cbge cbgt cble | op2.i=p0[5:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI5_14H/a | 8 | 11010101 | cbeq cbne | op2.i=p0[6:4]+p1[15:14] op3.p=p1[13:0] op1.r=p0[3:0] |
| 2 | CBI8_10H/b | 8 | 11010110 | cblt cbge cbgt cble | op2.i=p0[5:4]+p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | LDU.X6 | 9 | 110110000 | movzb.ud | op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[4:0] |
| 2 | LDF.PI12 | 9 | 110110011 | movuw movul | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDF.PD12 | 9 | 110110100 | movuw movul | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | CMF.PI12 | 9 | 110111001 | cmp fcmp | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | CMF.PD12 | 9 | 110111010 | cmp fcmp | op1.r=p0[5]+p1[15:12] op2.d=p1[11:0] op2.r=p0[4:0] |
| 2 | CBI10_8H/a | 9 | 110111100 | cbeq cbne | op2.i=p0[5:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI8_10H/a | 9 | 110111101 | cbeq cbne | op2.i=p0[5:4]+p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | CBI6_12H/a | 9 | 110111111 | cbeq cbne | op2.i=p0[5:4]+p1[15:12] op3.p=p1[11:0] op1.r=p0[3:0] |
| 2 | CBR14H/a | 9 | 111000011 | cbeq cbne | op1.r=p0[5:4]+p1[15:14] op3.p=p1[13:0] op2.r=p0[3:0] |
| 2 | LDBs12H/a | 9 | 111000100 | movq movl movzb lea | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDI18H/b | 9 | 111000110 | add sub | op1.i=p0[5:4]+p1[15:0] op2.r=p0[3:0] |
| 2 | LDX6H/a | 9 | 111000111 | movq movl movzb lea | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[4:0] |
| 2 | R3 | 10 | 1110010011 | ror xnorpop clmull clmulh mcpy mmov mset mcmp mscn mscnn div divu mod modu mulhu min minu max maxu fcopysign fmin fmax maskeqz masknez aeses aesesm aesds aesdsm aesks2 mfsr_ xadd xadddb swap swapdb xand xanddb xor_ xor_db xxor xxordb xmax xmaxdb xmin xmindb xmaxu xmaxudb xminu xminudb ll sc msha256 msha512 | subop=p0[5]+p1[15:10] op1.r=p1[9:5] op2.r=p1[4:0] op3.r=p0[4:0] |
| 2 | LDU.B12 | 10 | 1110010101 | movzb.ud | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDF.PI12 | 10 | 1110010111 | movuq | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | LDF.PD12 | 10 | 1110011000 | movuq | op1.r=p0[5]+p1[15:12] op1.d=p1[11:0] op2.r=p0[4:0] |
| 2 | TAG | 10 | 1110100001 | btag bntag | op2.i=p1[15:13] op3.p=p1[12:0] op1.r=p0[4:0] |
| 2 | CBI8_8H/b | 10 | 1110100010 | cblt cbge cbgt cble | op2.i=p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI8_8H/c | 10 | 1110100100 | cbcs cbcc cbhi cblos | op2.i=p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | LDPC16H/a | 10 | 1110100101 | movq movl movzb lea | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | CBI3_14H/a | 10 | 1110100110 | cbeq cbne | op2.i=p0[4]+p1[15:14] op3.p=p1[13:0] op1.r=p0[3:0] |
| 2 | CBI8_8/a | 10 | 1110100111 | cbeq cbne | op2.i=p1[15:8] op3.p=p1[7:0] op1.r=p0[4:0] |
| 2 | CBR10/c | 10 | 1110101000 | cbcs cbcc cbhi cblos | op1.r=p0[3:0]+p1[15] op2.r=p1[14:10] op3.p=p1[9:0] |
| 2 | CBI6_10H/b | 10 | 1110101001 | cblt cbge cbgt cble | op2.i=p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | LDPC16H/c | 10 | 1110101010 | add sub and bis | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | LDI18H/b | 10 | 1110101011 | and | op1.i=p0[5:4]+p1[15:0] op2.r=p0[3:0] |
| 2 | CBI6_10H/c | 10 | 1110101100 | cbcs cbcc cbhi cblos | op2.i=p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | CMI18H/a | 10 | 1110101101 | cmp | op2.i=p0[5:4]+p1[15:0] op1.r=p0[3:0] |
| 2 | STX6H/a | 10 | 1110101110 | movq movl | op1.r=p0[4]+p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.d=p1[5:0] op2.r=p0[3:0] |
| 2 | CBR10/b | 10 | 1110101111 | cblt cbge cbgt cble | op1.r=p0[3:0]+p1[15] op2.r=p1[14:10] op3.p=p1[9:0] |
| 2 | CBR12H/c | 10 | 1110110000 | cbcs cbcc cbhi cblos | op1.r=p1[15:12] op3.p=p1[11:0] op2.r=p0[3:0] |
| 2 | LDI18H/a | 10 | 1110110001 | movq | op1.i=p0[5:4]+p1[15:0] op2.r=p0[3:0] |
| 2 | LDBs10/a | 10 | 1110110010 | movq movl movzb lea | op1.r=p0[3:0]+p1[15] op2.r=p1[14:10] op1.d=p1[9:0] |
| 2 | SOF.PI12 | 11 | 11101101011 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.r=p0[0]+p1[15:12] op1.d=p1[11:0] |
| 2 | SOF.PD12 | 11 | 11101101100 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.r=p0[0]+p1[15:12] op1.d=p1[11:0] |
| 2 | SOB | 11 | 11101101110 | sob | op2.p=p1[15:0] op1.r=p0[4:0] |
| 2 | CBI6_10H/a | 11 | 11101101111 | cbeq cbne | op2.i=p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | CBI5_10H/b | 11 | 11101110000 | cblt cbge cbgt cble | op1.r=p0[2:0]+p1[15] op2.i=p1[14:10] op3.p=p1[9:0] |
| 2 | LDBu10H/a | 11 | 11101110001 | movq movl movzb lea | op1.r=p0[2:0]+p1[15] op2.r=p1[14:10] op1.d=p1[9:0] |
| 2 | CBI5_10H/c | 11 | 11101110010 | cbcs cbcc cbhi cblos | op1.r=p0[2:0]+p1[15] op2.i=p1[14:10] op3.p=p1[9:0] |
| 2 | CBI6_8/b | 11 | 11101110011 | cblt cbge cbgt cble | op1.r=p0[2:0]+p1[15:14] op2.i=p1[13:8] op3.p=p1[7:0] |
| 2 | CBR12H/a | 11 | 11101110100 | cbeq cbne | op1.r=p1[15:12] op3.p=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI6_8/c | 11 | 11101110101 | cbcs cbcc cbhi cblos | op1.r=p0[2:0]+p1[15:14] op2.i=p1[13:8] op3.p=p1[7:0] |
| 2 | STBu12H/a | 11 | 11101110110 | movq movl | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | STBu12H/b | 11 | 11101110111 | movw movb | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDI16H/b | 11 | 11101111000 | add sub | op1.i=p1[15:0] op2.r=p0[3:0] |
| 2 | CBR10/a | 11 | 11101111001 | cbeq cbne | op1.r=p0[3:0]+p1[15] op2.r=p1[14:10] op3.p=p1[9:0] |
| 2 | CBZ2_14/b | 11 | 11101111010 | cblt cbge cbgt cble | op1.r=p0[2:0]+p1[15:14] op3.p=p1[13:0] |
| 2 | CBI5_10/a | 11 | 11101111011 | cbeq cbne | op1.r=p0[3:0]+p1[15] op2.i=p1[14:10] op3.p=p1[9:0] |
| 2 | LDBu10H/b | 11 | 11101111100 | movw movb movzl movzw | op1.r=p0[2:0]+p1[15] op2.r=p1[14:10] op1.d=p1[9:0] |
| 2 | LDBu10H/c | 11 | 11101111101 | add sub and bis | op1.r=p0[2:0]+p1[15] op2.r=p1[14:10] op1.d=p1[9:0] |
| 2 | R2 | 12 | 111011111100 | clz ctz clo cto popcnt bswap bswapw bswapl bitrev utf8len utf8dec utf8enc mval abs set prober probew fdiv fsqrt fadd32 fsub32 fmul32 fdiv32 fsqrt32 fcmp32 fneg fabs fclass fclass32 frint frintz frintm frintp frinta fcvtdq fcvtqd fcvtds fcvtsd fcvtsl fcvtls fcvtdqu fcvtqud fsflags fadd16 fsub16 fmul16 fdiv16 fsqrt16 fcmp16 fclass16 fcvtsh fcvths fcvtdh fcvthd fcvthl fcvtlh aesim sha256sig0 sha256sig1 sha256sum0 sha256sum1 sha512sig0 sha512sig1 sha512sum0 sha512sum1 addv subv mulv | op1.r=p0[3:0]+p1[15] op2.r=p1[14:10] subop=p1[9:0] |
| 2 | RRI | 12 | 111011111101 | rori rori32 rol aesks1 | op1.r=p1[15:11] op2.i=p1[10:5] op3.r=p1[4:0] subop=p0[3:0] |
| 2 | CBI6_8H/c | 12 | 111100000001 | cbcs cbcc cbhi cblos | op1.r=p0[1:0]+p1[15:14] op2.i=p1[13:8] op3.p=p1[7:0] |
| 2 | CBR8/c | 12 | 111100000010 | cbcs cbcc cbhi cblos | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op3.p=p1[7:0] |
| 2 | CBR10H/c | 12 | 111100000011 | cbcs cbcc cbhi cblos | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op3.p=p1[9:0] |
| 2 | LDPC14H/a | 12 | 111100000100 | movq movl movzb lea | op2.r=p0[1:0]+p1[15:14] op1.p=p1[13:0] |
| 2 | CBR8/b | 12 | 111100000101 | cblt cbge cbgt cble | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op3.p=p1[7:0] |
| 2 | CBI3_12H/a | 12 | 111100000110 | cbeq cbne | op1.r=p0[2:0]+p1[15] op2.i=p1[14:12] op3.p=p1[11:0] |
| 2 | LDI16H/a | 12 | 111100000111 | movq | op1.i=p1[15:0] op2.r=p0[3:0] |
| 2 | CBI5_8/c | 12 | 111100001000 | cbcs cbcc cbhi cblos | op1.r=p0[1:0]+p1[15:13] op2.i=p1[12:8] op3.p=p1[7:0] |
| 2 | CBR10H/b | 12 | 111100001001 | cblt cbge cbgt cble | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op3.p=p1[9:0] |
| 2 | CALL2_20/c | 12 | 111100001010 | call | op1.p=p0[3:0]+p1[15:0] |
| 2 | CBZ2_14H/b | 12 | 111100001011 | cblt cbge cbgt cble | op1.r=p0[1:0]+p1[15:14] op3.p=p1[13:0] |
| 2 | LDI16H/b | 12 | 111100001100 | and | op1.i=p1[15:0] op2.r=p0[3:0] |
| 2 | LDBu8/a | 12 | 111100001101 | movq movl movzb lea | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | LDPC16H/c | 12 | 111100001110 | xor | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | CMPC16H/a | 12 | 111100001111 | cmp | op2.p=p1[15:0] op1.r=p0[3:0] |
| 2 | LDBs8/a | 12 | 111100010000 | movq movl movzb lea | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | LDBu8/c | 12 | 111100010001 | add sub and bis | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | STX4H/b | 12 | 111100010010 | movw movb | op1.r=p0[2:0]+p1[15:14] op2.r=p1[13:10] op2.r=p1[9:6] op2.s=p1[5:4] op2.d=p1[3:0] |
| 2 | LDPC14H/b | 12 | 111100010011 | movw movb movzl movzw | op2.r=p0[1:0]+p1[15:14] op1.p=p1[13:0] |
| 2 | CMBu12H/a | 12 | 111100010100 | cmp | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI5_8H/b | 13 | 1111000101011 | cblt cbge cbgt cble | op1.r=p0[0]+p1[15:13] op2.i=p1[12:8] op3.p=p1[7:0] |
| 2 | CBI6_8H/a | 13 | 1111000101100 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op2.i=p1[13:8] op3.p=p1[7:0] |
| 2 | LDX0/a | 13 | 1111000101101 | movq movl movzb lea | op1.r=p0[0]+p1[15:12] op1.r=p1[11:7] op1.s=p1[6:5] op2.r=p1[4:0] |
| 2 | CBI4_10H/a | 13 | 1111000101110 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op2.i=p1[13:10] op3.p=p1[9:0] |
| 2 | LDBs8H/a | 13 | 1111000101111 | movq movl movzb lea | op1.r=p0[0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | CBR8/a | 13 | 1111000110000 | cbeq cbne | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op3.p=p1[7:0] |
| 2 | CBR10H/a | 13 | 1111000110001 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op3.p=p1[9:0] |
| 2 | CBZ2_14H/a | 13 | 1111000110010 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op3.p=p1[13:0] |
| 2 | LDBu8H/a | 13 | 1111000110011 | movq movl movzb lea | op1.r=p0[0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | BR2_16/c | 13 | 1111000110100 | bpl bmi bvc bvs bcc bcs bge blt | op1.p=p1[15:0] |
| 2 | CBI3_10H/c | 13 | 1111000110101 | cbcs cbcc cbhi cblos | op1.r=p0[0]+p1[15:13] op2.i=p1[12:10] op3.p=p1[9:0] |
| 2 | CBI3_10H/b | 13 | 1111000110110 | cblt cbge cbgt cble | op1.r=p0[0]+p1[15:13] op2.i=p1[12:10] op3.p=p1[9:0] |
| 2 | CBI3_10/a | 13 | 1111000110111 | cbeq cbne | op1.r=p0[1:0]+p1[15:13] op2.i=p1[12:10] op3.p=p1[9:0] |
| 2 | CBI4_8/b | 13 | 1111000111000 | cblt cbge cbgt cble | op1.r=p0[0]+p1[15:12] op2.i=p1[11:8] op3.p=p1[7:0] |
| 2 | LDX0/b | 13 | 1111000111001 | movw movb movzl movzw | op1.r=p0[0]+p1[15:12] op1.r=p1[11:7] op1.s=p1[6:5] op2.r=p1[4:0] |
| 2 | STBu10H/a | 13 | 1111000111010 | movq movl | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op2.d=p1[9:0] |
| 2 | LDI14H/b | 13 | 1111000111011 | add sub | op2.r=p0[1:0]+p1[15:14] op1.i=p1[13:0] |
| 2 | CBI5_8/a | 13 | 1111000111100 | cbeq cbne | op1.r=p0[1:0]+p1[15:13] op2.i=p1[12:8] op3.p=p1[7:0] |
| 2 | LDBu8H/c | 13 | 1111000111101 | add sub and bis | op1.r=p0[0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | LDI12/d | 13 | 1111000111110 | shl shr sar mul | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | STBu10H/b | 13 | 1111000111111 | movw movb | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op2.d=p1[9:0] |
| 2 | LDBu8H/b | 13 | 1111001000000 | movw movb movzl movzw | op1.r=p0[0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | LDX0/c | 13 | 1111001000001 | add sub and bis | op1.r=p0[0]+p1[15:12] op1.r=p1[11:7] op1.s=p1[6:5] op2.r=p1[4:0] |
| 2 | LDPC12/a | 13 | 1111001000010 | movq movl movzb lea | op2.r=p0[0]+p1[15:12] op1.p=p1[11:0] |
| 2 | SOBs12/a | 13 | 1111001000011 | clr inc dec tst | op1.r=p0[0]+p1[15:12] op1.d=p1[11:0] |
| 2 | SOBs12/x | 13 | 1111001000100 | jmp call jmpi calli | op1.r=p0[0]+p1[15:12] op1.d=p1[11:0] |
| 2 | LDPC12H/d | 13 | 1111001000101 | bic mul mulh shl shr sar fadd fsub | op2.r=p1[15:12] op1.p=p1[11:0] |
| 2 | LDBu10H/c | 13 | 1111001000110 | xor | op1.r=p0[2:0]+p1[15] op2.r=p1[14:10] op1.d=p1[9:0] |
| 2 | JTAG2 | 14 | 11110010010010 | jtag | op1.r=p0[1:0]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op1.d=p1[5:0] |
| 2 | CBR8H/c | 14 | 11110010010011 | cbcs cbcc cbhi cblos | op1.r=p1[15:12] op2.r=p1[11:8] op3.p=p1[7:0] |
| 2 | CBI5_8H/a | 14 | 11110010010100 | cbeq cbne | op1.r=p0[0]+p1[15:13] op2.i=p1[12:8] op3.p=p1[7:0] |
| 2 | LDBu6/a | 14 | 11110010010101 | movq movl movzb lea | op1.r=p1[15:11] op1.d=p1[10:5] op2.r=p1[4:0] |
| 2 | CBR8H/b | 14 | 11110010010110 | cblt cbge cbgt cble | op1.r=p1[15:12] op2.r=p1[11:8] op3.p=p1[7:0] |
| 2 | CBI4_8H/c | 14 | 11110010010111 | cbcs cbcc cbhi cblos | op1.r=p1[15:12] op2.i=p1[11:8] op3.p=p1[7:0] |
| 2 | CBZ2_12H/b | 14 | 11110010011000 | cblt cbge cbgt cble | op1.r=p1[15:12] op3.p=p1[11:0] |
| 2 | LDI12H/d | 14 | 11110010011001 | shl shr sar mul | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LDPC12H/a | 14 | 11110010011010 | movq movl movzb lea | op2.r=p1[15:12] op1.p=p1[11:0] |
| 2 | LDBu6/b | 14 | 11110010011011 | movw movb movzl movzw | op1.r=p1[15:11] op1.d=p1[10:5] op2.r=p1[4:0] |
| 2 | CALL2_18/c | 14 | 11110010011100 | call | op1.p=p0[1:0]+p1[15:0] |
| 2 | LDI14H/a | 14 | 11110010011101 | movq | op2.r=p0[1:0]+p1[15:14] op1.i=p1[13:0] |
| 2 | CBI3_8/b | 14 | 11110010011110 | cblt cbge cbgt cble | op1.r=p1[15:11] op2.i=p1[10:8] op3.p=p1[7:0] |
| 2 | SOBu12H/a | 14 | 11110010011111 | clr inc dec tst | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDBu6/c | 14 | 11110010100000 | add sub and bis | op1.r=p1[15:11] op1.d=p1[10:5] op2.r=p1[4:0] |
| 2 | CBZ2_12/a | 14 | 11110010100001 | cbeq cbne | op1.r=p0[0]+p1[15:12] op3.p=p1[11:0] |
| 2 | SOBu12H/x | 14 | 11110010100010 | jmp call jmpi calli | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | STX0/b | 14 | 11110010100011 | movw movb | op1.r=p0[0]+p1[15:12] op2.r=p1[11:7] op2.r=p1[6:2] op2.s=p1[1:0] |
| 2 | STX0/a | 14 | 11110010100100 | movq movl | op1.r=p0[0]+p1[15:12] op2.r=p1[11:7] op2.r=p1[6:2] op2.s=p1[1:0] |
| 2 | BR2_16/c | 14 | 11110010100101 | bgt ble bhi blos | op1.p=p1[15:0] |
| 2 | CBI4_8/a | 14 | 11110010100110 | cbeq cbne | op1.r=p0[0]+p1[15:12] op2.i=p1[11:8] op3.p=p1[7:0] |
| 2 | LDI12H/c | 14 | 11110010100111 | bis xor mul bic | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | CBI3_8/c | 14 | 11110010101000 | cbcs cbcc cbhi cblos | op1.r=p1[15:11] op2.i=p1[10:8] op3.p=p1[7:0] |
| 2 | LDI14H/b | 14 | 11110010101001 | and | op2.r=p0[1:0]+p1[15:14] op1.i=p1[13:0] |
| 2 | LDBs6/a | 14 | 11110010101010 | movq movl movzb lea | op1.r=p1[15:11] op1.d=p1[10:5] op2.r=p1[4:0] |
| 2 | LDI12/d | 14 | 11110010101011 | bic movb | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | CMBu10H/a | 14 | 11110010101100 | cmp | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op2.d=p1[9:0] |
| 2 | CMBu8/a | 14 | 11110010101101 | cmp | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op2.d=p1[7:0] |
| 2 | LDS12H/c | 14 | 11110010101110 | add sub and bis | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | CMI14H/a | 14 | 11110010101111 | cmp | op1.r=p0[1:0]+p1[15:14] op2.i=p1[13:0] |
| 2 | LDI12/b | 14 | 11110010110000 | add sub | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | STBx8H/b | 14 | 11110010110001 | movw movb | op1.r=p0[0]+p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | LDPC12H/b | 14 | 11110010110010 | movw movb movzl movzw | op2.r=p1[15:12] op1.p=p1[11:0] |
| 2 | SOX4/a | 14 | 11110010110011 | clr inc dec tst | op1.r=p1[15:11] op1.r=p1[10:6] op1.s=p1[5:4] op1.d=p1[3:0] |
| 2 | LDS12H/b | 14 | 11110010110100 | movw movb movzl movzw | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | SOBs12/a | 14 | 11110010110101 | push pop | op1.r=p0[0]+p1[15:12] op1.d=p1[11:0] |
| 2 | LDBu8/c | 14 | 11110010110110 | xor | op1.r=p0[1:0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | LDBs6/b | 14 | 11110010110111 | movw movb movzl movzw | op1.r=p1[15:11] op1.d=p1[10:5] op2.r=p1[4:0] |
| 2 | SOX4/x | 14 | 11110010111000 | jmp call jmpi calli | op1.r=p1[15:11] op1.r=p1[10:6] op1.s=p1[5:4] op1.d=p1[3:0] |
| 2 | MFSR | 15 | 111100101110010 | mfsr | op1.r=p0[0]+p1[15:12] op2.i=p1[11:0] |
| 2 | MTSR | 15 | 111100101110011 | mtsr | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | CBI4_8H/a | 15 | 111100101111001 | cbeq cbne | op1.r=p1[15:12] op2.i=p1[11:8] op3.p=p1[7:0] |
| 2 | CBR8H/a | 15 | 111100101111010 | cbeq cbne | op1.r=p1[15:12] op2.r=p1[11:8] op3.p=p1[7:0] |
| 2 | CBZ2_12H/a | 15 | 111100101111011 | cbeq cbne | op1.r=p1[15:12] op3.p=p1[11:0] |
| 2 | STBu6/a | 15 | 111100101111100 | movq movl | op1.r=p1[15:11] op2.r=p1[10:6] op2.d=p1[5:0] |
| 2 | CBI3_8/a | 15 | 111100101111101 | cbeq cbne | op1.r=p1[15:11] op2.i=p1[10:8] op3.p=p1[7:0] |
| 2 | LDI12H/b | 15 | 111100101111110 | add sub | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | PUSHM16b/a | 15 | 111100101111111 | pushm popm | op1.i=p1[15:0] |
| 2 | BR2_16/b | 15 | 111100110000000 | beq bne | op1.p=p1[15:0] |
| 2 | STBu8H/b | 15 | 111100110000001 | movw movb | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | LDI12H/d | 15 | 111100110000010 | bic movb | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | SOBu12H/a | 15 | 111100110000011 | push pop | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | STBs8H/a | 15 | 111100110000100 | movq movl | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | LDI12/a | 15 | 111100110000101 | movq | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | STBs6/b | 15 | 111100110000110 | movw movb | op1.r=p1[15:11] op2.r=p1[10:6] op2.d=p1[5:0] |
| 2 | LDBu8H/c | 15 | 111100110000111 | xor | op1.r=p0[0]+p1[15:13] op2.r=p1[12:8] op1.d=p1[7:0] |
| 2 | LDI12/d | 15 | 111100110001000 | bit | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | LDI12/b | 15 | 111100110001001 | and | op2.r=p0[0]+p1[15:12] op1.i=p1[11:0] |
| 2 | LDX0/c | 15 | 111100110001010 | xor | op1.r=p0[0]+p1[15:12] op1.r=p1[11:7] op1.s=p1[6:5] op2.r=p1[4:0] |
| 2 | STBs6/a | 15 | 111100110001011 | movq movl | op1.r=p1[15:11] op2.r=p1[10:6] op2.d=p1[5:0] |
| 2 | SOX4/a | 15 | 111100110001100 | push pop | op1.r=p1[15:11] op1.r=p1[10:6] op1.s=p1[5:4] op1.d=p1[3:0] |
| 2 | CMX0/a | 15 | 111100110001101 | cmp | op1.r=p0[0]+p1[15:12] op2.r=p1[11:7] op2.r=p1[6:2] op2.s=p1[1:0] |
| 2 | LDPC12H/d | 15 | 111100110001110 | fmul bit | op2.r=p1[15:12] op1.p=p1[11:0] |
| 2 | CMI12/a | 15 | 111100110001111 | cmp | op1.r=p0[0]+p1[15:12] op2.i=p1[11:0] |
| 2 | PUSHI2 | 16 | 1111001100100010 | push | op1.i=p1[15:0] |
| 2 | RRF5 | 16 | 1111001100100011 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl shr sar fadd fsub fmul bit cmp fcmp | subop=p1[15:10] op1.r=p1[9:5] op2.r=p1[4:0] |
| 2 | BR2_16/a | 16 | 1111001100100100 | br | op1.p=p1[15:0] |
| 2 | LDI12H/a | 16 | 1111001100100101 | movq | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | CALL2_16/c | 16 | 1111001100100110 | call | op1.p=p1[15:0] |
| 2 | LEASx12H/a | 16 | 1111001100100111 | lea | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDI12H/b | 16 | 1111001100101000 | and | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LDI12H/d | 16 | 1111001100101001 | bit | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | CMI12H/a | 16 | 1111001100101010 | cmp | op1.r=p1[15:12] op2.i=p1[11:0] |
| 2 | CMBu8H/a | 16 | 1111001100101011 | cmp | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | CALL2_16/j | 16 | 1111001100101100 | jmp | op1.p=p1[15:0] |
| 2 | LDBu6/c | 16 | 1111001100101101 | xor | op1.r=p1[15:11] op1.d=p1[10:5] op2.r=p1[4:0] |
| 2 | CMBu6/a | 16 | 1111001100101110 | cmp | op1.r=p1[15:11] op2.r=p1[10:6] op2.d=p1[5:0] |
| 2 | LEAS12H/a | 16 | 1111001100101111 | lea | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDS12H/c | 16 | 1111001100110000 | xor | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | CMS12H/a | 16 | 1111001100110001 | cmp | op1.r=p1[15:12] op2.d=p1[11:0] |
| 3 | LDF.X22 | 5 | 00111 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op2.r=p0[4:0] |
| 3 | LDU.B28 | 6 | 010101 | movq.u movl.u movw.u movb.u movzl.u movzw.u movzb.u movq.d movl.d movw.d movb.d movzl.d movzw.d movzb.d movq.ud movl.ud | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.B28 | 6 | 010111 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.X22 | 6 | 011000 | shr sar fadd fsub fmul bit lea movub | op1.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op2.r=p0[4:0] |
| 3 | STF.X22 | 6 | 011011 | movq movl movw movb movub movuw movul movuq | op2.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op2.r=p1[12:8] op2.s=p1[7:6] op2.r=p0[4:0] |
| 3 | BFx | 7 | 1000100 | dshr | subop=p1[3:0]+p2[15:0] op1.r=p0[8:5]+p1[15] op2.r=p1[14:10] op3.i=p1[9:4] op4.r=p0[4:0] |
| 3 | LDF.B28 | 7 | 1000111 | shr sar fadd fsub fmul bit lea movub | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.PC32 | 7 | 1001010 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.p=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | LDF.A32 | 7 | 1001011 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.a=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | LDFI.I32 | 7 | 1001100 | add sub bic bis xor and mul mulh shl shr sar fadd fsub fmul bit movq | op1.i=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | STF.B28 | 7 | 1001101 | movq movl movw movb movub movuw movul movuq | op2.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | STF.X22 | 7 | 1001110 | addm subm bicm bism | op2.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op2.r=p1[12:8] op2.s=p1[7:6] op2.r=p0[4:0] |
| 3 | BFy | 8 | 10111110 | extb extzb insb | subop=p1[1:0]+p2[15:0] op1.r=p0[7:5]+p1[15:14] op2.i=p1[13:8] op3.i=p1[7:2] op4.r=p0[4:0] |
| 3 | LDU.B28 | 8 | 10111111 | movw.ud movb.ud movzl.ud movzw.ud | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | STU.B28 | 8 | 11000000 | movq.u movl.u movw.u movb.u | op2.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.X22 | 8 | 11000011 | movuw movul | op1.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op2.r=p0[4:0] |
| 3 | LDF.PC32 | 8 | 11000100 | shr sar fadd fsub fmul bit lea movub | op1.p=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | LDF.A32 | 8 | 11000101 | shr sar fadd fsub fmul bit lea movub | op1.a=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | STF.B28 | 8 | 11000110 | addm subm bicm bism | op2.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | STF.PC32 | 8 | 11001001 | movq movl movw movb movub movuw movul movuq | op2.p=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | STF.A32 | 8 | 11001010 | movq movl movw movb movub movuw movul movuq | op2.a=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | CMF.X22 | 8 | 11001011 | cmp fcmp | op2.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op2.r=p1[12:8] op2.s=p1[7:6] op2.r=p0[4:0] |
| 3 | LDF.B28 | 9 | 110110001 | movuw movul | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.X22 | 9 | 110110010 | movuq | op1.d=p1[5:0]+p2[15:0] op1.r=p0[6:5]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] op2.r=p0[4:0] |
| 3 | LDFI.I32 | 9 | 110110101 | movl movw movb movzl | op1.i=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | STF.PC32 | 9 | 110110110 | addm subm bicm bism | op2.p=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | STF.A32 | 9 | 110110111 | addm subm bicm bism | op2.a=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | CMF.B28 | 9 | 110111000 | cmp fcmp | op2.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDU.B28 | 10 | 1110010100 | movzb.ud | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.B28 | 10 | 1110010110 | movuq | op1.d=p1[11:0]+p2[15:0] op1.r=p0[5]+p1[15:12] op2.r=p0[4:0] |
| 3 | LDF.PC32 | 10 | 1110011001 | movuw movul | op1.p=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | LDF.A32 | 10 | 1110011010 | movuw movul | op1.a=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | LDFI.I32 | 10 | 1110011011 | movzw movzb | op1.i=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | CMF.PC32 | 10 | 1110011100 | cmp fcmp | op2.p=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | CMF.A32 | 10 | 1110011101 | cmp fcmp | op2.a=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | CMF.I32 | 10 | 1110011110 | cmp fcmp | op2.i=p1[15:0]+p2[15:0] op1.r=p0[4:0] |
| 3 | SOF.X22 | 10 | 1110011111 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.d=p1[5:0]+p2[15:0] op1.r=p0[1:0]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] |
| 3 | LDF.PC32 | 11 | 11101101000 | movuq | op1.p=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | LDF.A32 | 11 | 11101101001 | movuq | op1.a=p1[15:0]+p2[15:0] op2.r=p0[4:0] |
| 3 | SOF.B28 | 11 | 11101101010 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.d=p1[11:0]+p2[15:0] op1.r=p0[0]+p1[15:12] |
| 3 | DPF.D28 | 11 | 11101101101 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.d=p1[11:0]+p2[15:0] op2.r=p0[0]+p1[15:12] |
| 3 | SOF.PC32 | 12 | 111011111110 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.p=p1[15:0]+p2[15:0] |
| 3 | SOF.A32 | 12 | 111011111111 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.a=p1[15:0]+p2[15:0] |
| 3 | DPF.D28 | 12 | 111100000000 | shr sar fadd fsub fmul bit lea movub | op1.d=p1[11:0]+p2[15:0] op2.r=p0[0]+p1[15:12] |
| 3 | BRF | 13 | 1111000101010 | br bne beq bpl bmi bvc bvs bcc | op1.p=p1[15:0]+p2[15:0] |
| 3 | DPF.D28 | 14 | 11110010001111 | movuw movul | op1.d=p1[11:0]+p2[15:0] op2.r=p0[0]+p1[15:12] |
| 3 | BRF | 14 | 11110010010000 | bcs bge blt bgt | op1.p=p1[15:0]+p2[15:0] |
| 3 | JTAG3 | 14 | 11110010010001 | jtag | op1.d=p1[5:0]+p2[15:0] op1.r=p0[1:0]+p1[15:13] op1.r=p1[12:8] op1.s=p1[7:6] |
| 3 | DPF.D28 | 15 | 111100101110100 | movuq | op1.d=p1[11:0]+p2[15:0] op2.r=p0[0]+p1[15:12] |
| 3 | BRF | 15 | 111100101110101 | ble bhi | op1.p=p1[15:0]+p2[15:0] |
| 3 | CALLF | 15 | 111100101110110 | call jmp | op1.p=p1[15:0]+p2[15:0] |
| 3 | PUSHMF | 15 | 111100101110111 | pushm popm | op1.i=p1[15:0]+p2[15:0] |
| 3 | SPADJF | 15 | 111100101111000 | add sub | op1.i=p1[15:0]+p2[15:0] |
| 3 | BRF | 16 | 1111001100100000 | blos | op1.p=p1[15:0]+p2[15:0] |
| 3 | PUSHI3 | 16 | 1111001100100001 | push | op1.i=p1[15:0]+p2[15:0] |
| 5 | MOVQL | 11 | 11101100111 | movql | op1.i=p1[15:0]+p2[15:0]+p3[15:0]+p4[15:0] op2.r=p0[4:0] |

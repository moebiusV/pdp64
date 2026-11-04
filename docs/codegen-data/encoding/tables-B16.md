# B16 (base16, mix=3.0, fuse=())

Leaves (prefix-coded groups of mnemonics). prefix = top L bits of parcel 0. `subop` selects the mnemonic inside the group (binary-aligned).

| parcels | form | L | prefix (P0 top bits) | mnemonics | fields (bit positions) |
|---|---|---|---|---|---|
| 1 | CBZ1_8/a | 3 | 000 | cbeq cbne | op3.p=p0[11:4] op1.r=p0[3:0] |
| 1 | RRF | 4 | 0010 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | LDHHR3/a | 4 | 0011 | movq movl movzb lea | op1.d=p0[9:7] op1.r=p0[6:4] op2.r=p0[3:0] |
| 1 | LDSP6/a | 4 | 0100 | movq movl movzb lea | op1.d=p0[9:4] op2.r=p0[3:0] |
| 1 | RRF | 5 | 01010 | shr sar fadd fsub fmul bit cmp fcmp | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | LDSP5/a | 5 | 01100 | movq movl movzb lea | op1.d=p0[8:4] op2.r=p0[3:0] |
| 1 | SHI5/a | 5 | 01101 | shl shr sar rol | op1.i=p0[8:4] op2.r=p0[3:0] |
| 1 | IMM7/a | 5 | 01110 | movq | op1.i=p0[10:4] op2.r=p0[3:0] |
| 1 | STSP6/a | 5 | 01111 | movq movl | op2.d=p0[9:4] op1.r=p0[3:0] |
| 1 | SYSI | 6 | 100000 | spl trap trapl hint | op1.i=p0[7:0] |
| 1 | STSP5/a | 6 | 100001 | movq movl | op2.d=p0[8:4] op1.r=p0[3:0] |
| 1 | LDHHH2/a | 6 | 100010 | movq movl movzb lea | op1.d=p0[7:6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | CBZ1_5/a | 6 | 100011 | cbeq cbne | op3.p=p0[8:4] op1.r=p0[3:0] |
| 1 | IMM6/a | 6 | 100100 | movq | op1.i=p0[9:4] op2.r=p0[3:0] |
| 1 | LD0/a | 6 | 100101 | movq movl movzb lea | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | LDHHH2/b | 6 | 100110 | movw movb movzl movzw | op1.d=p0[7:6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | STHHH3/a | 6 | 100111 | movq movl | op2.d=p0[8:6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | IMM5/b | 6 | 101010 | add sub | op1.i=p0[8:4] op2.r=p0[3:0] |
| 1 | LDHHH1/a | 7 | 1010110 | movq movl movzb lea | op1.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | SHI3/a | 7 | 1010111 | shl shr sar rol | op1.i=p0[6:4] op2.r=p0[3:0] |
| 1 | CBZ1_4/a | 7 | 1011000 | cbeq cbne | op3.p=p0[7:4] op1.r=p0[3:0] |
| 1 | PUSHM8/a | 7 | 1011001 | pushm popm | op1.i=p0[7:0] |
| 1 | IMM4/b | 7 | 1011010 | add sub | op1.i=p0[7:4] op2.r=p0[3:0] |
| 1 | ST0/a | 7 | 1011100 | movq movl | op1.r=p0[7:4] op2.r=p0[3:0] |
| 1 | STHHH2/b | 7 | 1011101 | movw movb | op2.d=p0[7:6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | BR1_9/a | 7 | 1011110 | br | op1.p=p0[8:0] |
| 1 | BR1_6/c | 7 | 1011111 | bpl bmi bvc bvs bcc bcs bge blt | op1.p=p0[5:0] |
| 1 | IMM5/b | 7 | 1100000 | and | op1.i=p0[8:4] op2.r=p0[3:0] |
| 1 | STHHH1/a | 8 | 11001111 | movq movl | op2.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | STHHH1/b | 8 | 11010000 | movw movb | op2.d=p0[6] op1.r=p0[5:3] op2.r=p0[2:0] |
| 1 | IMM4/b | 8 | 11010010 | and | op1.i=p0[7:4] op2.r=p0[3:0] |
| 1 | LEASP4/a | 8 | 11010100 | lea | op1.d=p0[7:4] op2.r=p0[3:0] |
| 1 | BR1_8/a | 8 | 11010101 | br | op1.p=p0[7:0] |
| 1 | BR1_7/b | 8 | 11010110 | beq bne | op1.p=p0[6:0] |
| 1 | BR1_6/c | 8 | 11011000 | bgt ble bhi blos | op1.p=p0[5:0] |
| 1 | SYSR | 9 | 110110100 | mtps mfps tlbi mtasid mfasid mtdp mfdp mtdmw | op1.r=p0[3:0] |
| 1 | SOPR | 9 | 111000001 | clr com inc dec neg tst adc sbc | op1.r=p0[3:0] |
| 1 | IMM3/a | 9 | 111000100 | movq | op1.i=p0[6:4] op2.r=p0[3:0] |
| 1 | SPADJ6/a | 9 | 111000110 | add sub | op1.i=p0[5:0] |
| 1 | BR1_6/b | 9 | 111000111 | beq bne | op1.p=p0[5:0] |
| 1 | BR1_7/a | 9 | 111001000 | br | op1.p=p0[6:0] |
| 1 | SOPR | 10 | 1110100101 | asl asr push pop | op1.r=p0[3:0] |
| 1 | BR1_6/a | 10 | 1110101000 | br | op1.p=p0[5:0] |
| 1 | SYS0 | 11 | 11101100110 | nop rti rtt ret halt bpt fence wfe sev lpad tlbia tlbsync icinva pushx popx isync trapcc.ne trapcc.eq trapcc.pl trapcc.mi trapcc.vc trapcc.vs trapcc.cc trapcc.cs trapcc.ge trapcc.lt trapcc.gt trapcc.le trapcc.hi trapcc.los syspg0 syspg1 |  |
| 1 | SYSR | 11 | 11101100111 | mfcpuid icinv | op1.r=p0[3:0] |
| 1 | SOPR | 11 | 11101110110 | jmp call | op1.r=p0[3:0] |
| 1 | SYS0 | 14 | 11110010100010 | syspg2 syspg3 syspg4 syspg5 |  |
| 2 | CBI8_14/a | 5 | 01011 | cbeq cbne | op2.i=p0[9:4]+p1[15:14] op3.p=p1[13:0] op1.r=p0[3:0] |
| 2 | CBI12_8/b | 6 | 101000 | cblt cbge cbgt cble | op2.i=p0[7:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI12_8/c | 6 | 101001 | cbcs cbcc cbhi cblos | op2.i=p0[7:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI12_8/a | 7 | 1011011 | cbeq cbne | op2.i=p0[7:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI10_10/a | 7 | 1100001 | cbeq cbne | op2.i=p0[7:4]+p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | LDU.B12 | 8 | 11000101 | movq.u movl.u movw.u movb.u movzl.u movzw.u movzb.u movq.d movl.d movw.d movb.d movzl.d movzw.d movzb.d movq.ud movl.ud | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDU.X6 | 8 | 11000110 | movq.u movl.u movw.u movb.u movzl.u movzw.u movzb.u movq.d movl.d movw.d movb.d movzl.d movzw.d movzb.d movq.ud movl.ud | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[3:0] |
| 2 | LDF.PI12 | 8 | 11001001 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDF.PD12 | 8 | 11001010 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI10_8/c | 8 | 11001110 | cbcs cbcc cbhi cblos | op2.i=p0[5:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBI8_10/b | 8 | 11010001 | cblt cbge cbgt cble | op2.i=p0[5:4]+p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | CBI10_8/b | 8 | 11010011 | cblt cbge cbgt cble | op2.i=p0[5:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | LDX8/a | 8 | 11010111 | movq movl movzb lea | op1.r=p0[5:4]+p1[15:14] op1.r=p1[13:10] op1.s=p1[9:8] op1.d=p1[7:0] op2.r=p0[3:0] |
| 2 | CMI20/a | 8 | 11011001 | cmp | op2.i=p0[7:4]+p1[15:0] op1.r=p0[3:0] |
| 2 | LDF.PI12 | 9 | 110110111 | shr sar fadd fsub fmul bit lea movub | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDF.PD12 | 9 | 110111000 | shr sar fadd fsub fmul bit lea movub | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | STF.PI12 | 9 | 110111101 | movq movl movw movb movub movuw movul movuq | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | STF.PD12 | 9 | 110111110 | movq movl movw movb movub movuw movul movuq | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI6_12/a | 9 | 111000010 | cbeq cbne | op2.i=p0[5:4]+p1[15:12] op3.p=p1[11:0] op1.r=p0[3:0] |
| 2 | CBI10_8/a | 9 | 111000011 | cbeq cbne | op2.i=p0[5:4]+p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBR14/a | 9 | 111000101 | cbeq cbne | op1.r=p0[5:4]+p1[15:14] op3.p=p1[13:0] op2.r=p0[3:0] |
| 2 | LDPC16/d | 9 | 111001001 | bic mul mulh shl shr sar fadd fsub | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | LDI18/b | 9 | 111001010 | add sub | op1.i=p0[5:4]+p1[15:0] op2.r=p0[3:0] |
| 2 | LDU.B12 | 10 | 1110011010 | movw.ud movb.ud movzl.ud movzw.ud | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | STU.B12 | 10 | 1110011011 | movq.u movl.u movw.u movb.u | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDU.X6 | 10 | 1110011100 | movw.ud movb.ud movzl.ud movzw.ud | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[3:0] |
| 2 | STU.X6 | 10 | 1110011101 | movq.u movl.u movw.u movb.u | op1.r=p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.d=p1[5:0] op2.r=p0[3:0] |
| 2 | STF.PI12 | 10 | 1110100001 | addm subm bicm bism | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | STF.PD12 | 10 | 1110100010 | addm subm bicm bism | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI8_8/b | 10 | 1110100110 | cblt cbge cbgt cble | op2.i=p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | CBR12/c | 10 | 1110100111 | cbcs cbcc cbhi cblos | op1.r=p1[15:12] op3.p=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI8_8/c | 10 | 1110101001 | cbcs cbcc cbhi cblos | op2.i=p1[15:8] op3.p=p1[7:0] op1.r=p0[3:0] |
| 2 | LDPC16/c | 10 | 1110101010 | add sub and bis | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | LDX6/a | 10 | 1110101011 | movq movl movzb lea | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[3:0] |
| 2 | LDPC16/a | 10 | 1110101100 | movq movl movzb lea | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | LDBs12/a | 10 | 1110101101 | movq movl movzb lea | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDI18/b | 10 | 1110101110 | and | op1.i=p0[5:4]+p1[15:0] op2.r=p0[3:0] |
| 2 | CMI18/a | 10 | 1110101111 | cmp | op2.i=p0[5:4]+p1[15:0] op1.r=p0[3:0] |
| 2 | LDBu12/b | 10 | 1110110000 | movw movb movzl movzw | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CBI6_10/c | 10 | 1110110001 | cbcs cbcc cbhi cblos | op2.i=p1[15:10] op3.p=p1[9:0] op1.r=p0[3:0] |
| 2 | CBR12/b | 10 | 1110110010 | cblt cbge cbgt cble | op1.r=p1[15:12] op3.p=p1[11:0] op2.r=p0[3:0] |
| 2 | LDF.PI12 | 11 | 11101101010 | movuw movul | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDF.PD12 | 11 | 11101101011 | movuw movul | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CMF.PI12 | 11 | 11101110001 | cmp fcmp | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | CMF.PD12 | 11 | 11101110010 | cmp fcmp | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | TAG | 11 | 11101110111 | btag bntag | op2.i=p1[15:13] op3.p=p1[12:0] op1.r=p0[3:0] |
| 2 | CBI5_10/b | 11 | 11101111000 | cblt cbge cbgt cble | op1.r=p0[2:0]+p1[15] op2.i=p1[14:10] op3.p=p1[9:0] |
| 2 | CBI5_10/c | 11 | 11101111001 | cbcs cbcc cbhi cblos | op1.r=p0[2:0]+p1[15] op2.i=p1[14:10] op3.p=p1[9:0] |
| 2 | STX6/a | 11 | 11101111010 | movq movl | op1.r=p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.d=p1[5:0] op2.r=p0[3:0] |
| 2 | STBu12/a | 11 | 11101111011 | movq movl | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDPC16/d | 11 | 11101111100 | fmul bit | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | STBu12/b | 11 | 11101111101 | movw movb | op1.r=p1[15:12] op2.d=p1[11:0] op2.r=p0[3:0] |
| 2 | STX6/b | 11 | 11101111110 | movw movb | op1.r=p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.d=p1[5:0] op2.r=p0[3:0] |
| 2 | R2 | 12 | 111011111110 | clz ctz clo cto popcnt bswap bswapw bswapl bitrev utf8len utf8dec utf8enc mval abs set prober probew fdiv fsqrt fadd32 fsub32 fmul32 fdiv32 fsqrt32 fcmp32 fneg fabs fclass fclass32 frint frintz frintm frintp frinta fcvtdq fcvtqd fcvtds fcvtsd fcvtsl fcvtls fcvtdqu fcvtqud fsflags fadd16 fsub16 fmul16 fdiv16 fsqrt16 fcmp16 fclass16 fcvtsh fcvths fcvtdh fcvthd fcvthl fcvtlh aesim sha256sig0 sha256sig1 sha256sum0 sha256sum1 sha512sig0 sha512sig1 sha512sum0 sha512sum1 addv subv mulv | op1.r=p1[15:12] subop=p1[11:0] op2.r=p0[3:0] |
| 2 | R3 | 12 | 111011111111 | ror xnorpop clmull clmulh mcpy mmov mset mcmp mscn mscnn div divu mod modu mulhu min minu max maxu fcopysign fmin fmax maskeqz masknez aeses aesesm aesds aesdsm aesks2 mfsr_ xadd xadddb swap swapdb xand xanddb xor_ xor_db xxor xxordb xmax xmaxdb xmin xmindb xmaxu xmaxudb xminu xminudb ll sc msha256 msha512 | op1.r=p1[15:12] op2.r=p1[11:8] subop=p1[7:0] op3.r=p0[3:0] |
| 2 | R4 | 12 | 111100000000 | fmadd fmsub fnmadd fnmsub fmadd32 fmsub32 fnmadd32 fnmsub32 fmadd16 fmsub16 fnmadd16 fnmsub16 bsel cas casdb maesctr | subop=p1[15:12] op1.r=p1[11:8] op2.r=p1[7:4] op3.r=p1[3:0] op4.r=p0[3:0] |
| 2 | RRI | 12 | 111100000001 | rori rori32 rol aesks1 | subop=p1[15:10] op1.r=p1[9:6] op2.i=p1[5:0] op3.r=p0[3:0] |
| 2 | LDU.B12 | 12 | 111100000100 | movzb.ud | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDU.X6 | 12 | 111100000101 | movzb.ud | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] op2.r=p0[3:0] |
| 2 | LDF.PI12 | 12 | 111100001000 | movuq | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | LDF.PD12 | 12 | 111100001001 | movuq | op1.r=p1[15:12] op1.d=p1[11:0] op2.r=p0[3:0] |
| 2 | SOF.PI12 | 12 | 111100001110 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | SOF.PD12 | 12 | 111100001111 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | SOB | 12 | 111100010011 | sob | op2.p=p1[15:0] op1.r=p0[3:0] |
| 2 | CBI5_10/a | 12 | 111100010100 | cbeq cbne | op1.r=p0[2:0]+p1[15] op2.i=p1[14:10] op3.p=p1[9:0] |
| 2 | CBR10/c | 12 | 111100010101 | cbcs cbcc cbhi cblos | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op3.p=p1[9:0] |
| 2 | CBI6_8/c | 12 | 111100010110 | cbcs cbcc cbhi cblos | op1.r=p0[1:0]+p1[15:14] op2.i=p1[13:8] op3.p=p1[7:0] |
| 2 | LDPC14/a | 12 | 111100010111 | movq movl movzb lea | op2.r=p0[1:0]+p1[15:14] op1.p=p1[13:0] |
| 2 | CBZ2_14/b | 12 | 111100011000 | cblt cbge cbgt cble | op1.r=p0[1:0]+p1[15:14] op3.p=p1[13:0] |
| 2 | LDI16/a | 12 | 111100011001 | movq | op1.i=p1[15:0] op2.r=p0[3:0] |
| 2 | LDBu10/a | 12 | 111100011010 | movq movl movzb lea | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op1.d=p1[9:0] |
| 2 | LDPC16/c | 12 | 111100011011 | xor | op1.p=p1[15:0] op2.r=p0[3:0] |
| 2 | CBR10/b | 12 | 111100011100 | cblt cbge cbgt cble | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op3.p=p1[9:0] |
| 2 | CALL2_20/c | 12 | 111100011101 | call | op1.p=p0[3:0]+p1[15:0] |
| 2 | LDX4/b | 12 | 111100011110 | movw movb movzl movzw | op1.r=p0[1:0]+p1[15:14] op1.r=p1[13:10] op1.s=p1[9:8] op1.d=p1[7:4] op2.r=p1[3:0] |
| 2 | LDBs10/c | 12 | 111100011111 | add sub and bis | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op1.d=p1[9:0] |
| 2 | CMPC16/a | 12 | 111100100000 | cmp | op2.p=p1[15:0] op1.r=p0[3:0] |
| 2 | SOX8/a | 12 | 111100100001 | clr inc dec tst | op1.r=p0[1:0]+p1[15:14] op1.r=p1[13:10] op1.s=p1[9:8] op1.d=p1[7:0] |
| 2 | CBI4_10/a | 13 | 1111001000110 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op2.i=p1[13:10] op3.p=p1[9:0] |
| 2 | CBI5_8/b | 13 | 1111001000111 | cblt cbge cbgt cble | op1.r=p0[0]+p1[15:13] op2.i=p1[12:8] op3.p=p1[7:0] |
| 2 | CBR10/a | 13 | 1111001001000 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op3.p=p1[9:0] |
| 2 | CBI5_8/c | 13 | 1111001001001 | cbcs cbcc cbhi cblos | op1.r=p0[0]+p1[15:13] op2.i=p1[12:8] op3.p=p1[7:0] |
| 2 | CBZ2_14/a | 13 | 1111001001010 | cbeq cbne | op1.r=p0[1:0]+p1[15:14] op3.p=p1[13:0] |
| 2 | CBI3_10/b | 13 | 1111001001011 | cblt cbge cbgt cble | op1.r=p0[0]+p1[15:13] op2.i=p1[12:10] op3.p=p1[9:0] |
| 2 | CBI3_10/c | 13 | 1111001001100 | cbcs cbcc cbhi cblos | op1.r=p0[0]+p1[15:13] op2.i=p1[12:10] op3.p=p1[9:0] |
| 2 | BR2_16/c | 13 | 1111001001101 | bpl bmi bvc bvs bcc bcs bge blt | op1.p=p1[15:0] |
| 2 | LDI14/b | 13 | 1111001001110 | add sub | op2.r=p0[1:0]+p1[15:14] op1.i=p1[13:0] |
| 2 | STBu10/a | 13 | 1111001001111 | movq movl | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op2.d=p1[9:0] |
| 2 | SOX8/a | 13 | 1111001010000 | push pop | op1.r=p0[1:0]+p1[15:14] op1.r=p1[13:10] op1.s=p1[9:8] op1.d=p1[7:0] |
| 2 | CBR8/c | 14 | 11110010100100 | cbcs cbcc cbhi cblos | op1.r=p1[15:12] op2.r=p1[11:8] op3.p=p1[7:0] |
| 2 | CBR8/b | 14 | 11110010100101 | cblt cbge cbgt cble | op1.r=p1[15:12] op2.r=p1[11:8] op3.p=p1[7:0] |
| 2 | LDBs8/a | 14 | 11110010100110 | movq movl movzb lea | op1.r=p1[15:12] op2.r=p1[11:8] op1.d=p1[7:0] |
| 2 | CBZ2_12/b | 14 | 11110010100111 | cblt cbge cbgt cble | op1.r=p1[15:12] op3.p=p1[11:0] |
| 2 | LDX2/a | 14 | 11110010101000 | movq movl movzb lea | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:4] op2.r=p1[3:0] |
| 2 | LDI12/d | 14 | 11110010101001 | shl shr sar mul | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LDX2/b | 14 | 11110010101010 | movw movb movzl movzw | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:4] op2.r=p1[3:0] |
| 2 | LDBu8/b | 14 | 11110010101011 | movw movb movzl movzw | op1.r=p1[15:12] op2.r=p1[11:8] op1.d=p1[7:0] |
| 2 | LDPC12/a | 14 | 11110010101100 | movq movl movzb lea | op2.r=p1[15:12] op1.p=p1[11:0] |
| 2 | LDBu8/c | 14 | 11110010101101 | add sub and bis | op1.r=p1[15:12] op2.r=p1[11:8] op1.d=p1[7:0] |
| 2 | CALL2_18/c | 14 | 11110010101110 | call | op1.p=p0[1:0]+p1[15:0] |
| 2 | BR2_16/c | 14 | 11110010101111 | bgt ble bhi blos | op1.p=p1[15:0] |
| 2 | LDBu8/a | 14 | 11110010110000 | movq movl movzb lea | op1.r=p1[15:12] op2.r=p1[11:8] op1.d=p1[7:0] |
| 2 | SOBu12/a | 14 | 11110010110001 | clr inc dec tst | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDI14/a | 14 | 11110010110010 | movq | op2.r=p0[1:0]+p1[15:14] op1.i=p1[13:0] |
| 2 | LDX2/c | 14 | 11110010110011 | add sub and bis | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:4] op2.r=p1[3:0] |
| 2 | SOBu12/x | 14 | 11110010110100 | jmp call jmpi calli | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDI12/c | 14 | 11110010110101 | bis xor mul bic | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LDI14/b | 14 | 11110010110110 | and | op2.r=p0[1:0]+p1[15:14] op1.i=p1[13:0] |
| 2 | CMBu10/a | 14 | 11110010110111 | cmp | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op2.d=p1[9:0] |
| 2 | LDS12/c | 14 | 11110010111000 | add sub and bis | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDBs10/c | 14 | 11110010111001 | xor | op1.r=p0[1:0]+p1[15:14] op2.r=p1[13:10] op1.d=p1[9:0] |
| 2 | SOX6/a | 14 | 11110010111010 | clr inc dec tst | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] |
| 2 | LDPC12/b | 14 | 11110010111011 | movw movb movzl movzw | op2.r=p1[15:12] op1.p=p1[11:0] |
| 2 | LDBs8/b | 14 | 11110010111100 | movw movb movzl movzw | op1.r=p1[15:12] op2.r=p1[11:8] op1.d=p1[7:0] |
| 2 | SOX6/x | 14 | 11110010111101 | jmp call jmpi calli | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] |
| 2 | CBI4_8/a | 15 | 111100110000001 | cbeq cbne | op1.r=p1[15:12] op2.i=p1[11:8] op3.p=p1[7:0] |
| 2 | CBR8/a | 15 | 111100110000010 | cbeq cbne | op1.r=p1[15:12] op2.r=p1[11:8] op3.p=p1[7:0] |
| 2 | STBs8/a | 15 | 111100110000011 | movq movl | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | LDI12/b | 15 | 111100110000100 | add sub | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LDI12/d | 15 | 111100110000101 | bic movb | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | STBu8/b | 15 | 111100110000110 | movw movb | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | PUSHM16a/a | 15 | 111100110000111 | pushm popm | op1.i=p1[15:0] |
| 2 | BR2_16/b | 15 | 111100110001000 | beq bne | op1.p=p1[15:0] |
| 2 | STX2/a | 15 | 111100110001001 | movq movl | op1.r=p1[15:12] op2.r=p1[11:8] op2.r=p1[7:4] op2.s=p1[3:2] op2.d=p1[1:0] |
| 2 | STX2/b | 15 | 111100110001010 | movw movb | op1.r=p1[15:12] op2.r=p1[11:8] op2.r=p1[7:4] op2.s=p1[3:2] op2.d=p1[1:0] |
| 2 | SOBu12/a | 15 | 111100110001011 | push pop | op1.r=p1[15:12] op1.d=p1[11:0] |
| 2 | STBs8/b | 15 | 111100110001100 | movw movb | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | SOX6/a | 15 | 111100110001101 | push pop | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] |
| 2 | MFSR | 16 | 1111001100011100 | mfsr | op1.r=p1[15:12] op2.i=p1[11:0] |
| 2 | MTSR | 16 | 1111001100011101 | mtsr | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | PUSHI2 | 16 | 1111001100100001 | push | op1.i=p1[15:0] |
| 2 | JTAG2 | 16 | 1111001100100011 | jtag | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:0] |
| 2 | BR2_16/a | 16 | 1111001100100100 | br | op1.p=p1[15:0] |
| 2 | LDI12/a | 16 | 1111001100100101 | movq | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | CALL2_16/c | 16 | 1111001100100110 | call | op1.p=p1[15:0] |
| 2 | LDI12/b | 16 | 1111001100100111 | and | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LDI12/d | 16 | 1111001100101000 | bit | op2.r=p1[15:12] op1.i=p1[11:0] |
| 2 | LEASx12/a | 16 | 1111001100101001 | lea | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | CMBu8/a | 16 | 1111001100101010 | cmp | op1.r=p1[15:12] op2.r=p1[11:8] op2.d=p1[7:0] |
| 2 | LDBu8/c | 16 | 1111001100101011 | xor | op1.r=p1[15:12] op2.r=p1[11:8] op1.d=p1[7:0] |
| 2 | CALL2_16/j | 16 | 1111001100101100 | jmp | op1.p=p1[15:0] |
| 2 | CMI12/a | 16 | 1111001100101101 | cmp | op1.r=p1[15:12] op2.i=p1[11:0] |
| 2 | LDX2/c | 16 | 1111001100101110 | xor | op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op1.d=p1[5:4] op2.r=p1[3:0] |
| 2 | LEAS12/a | 16 | 1111001100101111 | lea | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | LDS12/c | 16 | 1111001100110000 | xor | op2.r=p1[15:12] op1.d=p1[11:0] |
| 2 | CMS12/a | 16 | 1111001100110001 | cmp | op1.r=p1[15:12] op2.d=p1[11:0] |
| 2 | CMX2/a | 16 | 1111001100110010 | cmp | op1.r=p1[15:12] op2.r=p1[11:8] op2.r=p1[7:4] op2.s=p1[3:2] op2.d=p1[1:0] |
| 3 | LDU.B28 | 8 | 11000100 | movq.u movl.u movw.u movb.u movzl.u movzw.u movzb.u movq.d movl.d movw.d movb.d movzl.d movzw.d movzb.d movq.ud movl.ud | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDF.B28 | 8 | 11000111 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDF.X22 | 8 | 11001000 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op2.r=p0[3:0] |
| 3 | LDF.PC32 | 8 | 11001011 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.p=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDF.A32 | 8 | 11001100 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.a=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDFI.I32 | 8 | 11001101 | add sub bic bis xor and mul mulh shl shr sar fadd fsub fmul bit movq | op1.i=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDF.B28 | 9 | 110110101 | shr sar fadd fsub fmul bit lea movub | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDF.X22 | 9 | 110110110 | shr sar fadd fsub fmul bit lea movub | op1.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op2.r=p0[3:0] |
| 3 | LDF.PC32 | 9 | 110111001 | shr sar fadd fsub fmul bit lea movub | op1.p=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDF.A32 | 9 | 110111010 | shr sar fadd fsub fmul bit lea movub | op1.a=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | STF.B28 | 9 | 110111011 | movq movl movw movb movub movuw movul movuq | op2.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | STF.X22 | 9 | 110111100 | movq movl movw movb movub movuw movul movuq | op2.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.r=p0[3:0] |
| 3 | STF.PC32 | 9 | 110111111 | movq movl movw movb movub movuw movul movuq | op2.p=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | STF.A32 | 9 | 111000000 | movq movl movw movb movub movuw movul movuq | op2.a=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | BFx | 10 | 1110010110 | dshr | subop=p1[3:0]+p2[15:0] op1.r=p0[5:4]+p1[15:14] op2.r=p1[13:10] op3.i=p1[9:4] op4.r=p0[3:0] |
| 3 | BFy | 10 | 1110010111 | extb extzb insb | subop=p1[1:0]+p2[15:0] op1.r=p0[5:4]+p1[15:14] op2.i=p1[13:8] op3.i=p1[7:2] op4.r=p0[3:0] |
| 3 | LDU.B28 | 10 | 1110011000 | movw.ud movb.ud movzl.ud movzw.ud | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | STU.B28 | 10 | 1110011001 | movq.u movl.u movw.u movb.u | op2.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDFI.I32 | 10 | 1110011110 | movl movw movb movzl | op1.i=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | STF.B28 | 10 | 1110011111 | addm subm bicm bism | op2.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | STF.X22 | 10 | 1110100000 | addm subm bicm bism | op2.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.r=p0[3:0] |
| 3 | STF.PC32 | 10 | 1110100011 | addm subm bicm bism | op2.p=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | STF.A32 | 10 | 1110100100 | addm subm bicm bism | op2.a=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | LDF.B28 | 11 | 11101101000 | movuw movul | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDF.X22 | 11 | 11101101001 | movuw movul | op1.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op2.r=p0[3:0] |
| 3 | LDF.PC32 | 11 | 11101101100 | movuw movul | op1.p=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDF.A32 | 11 | 11101101101 | movuw movul | op1.a=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDFI.I32 | 11 | 11101101110 | movzw movzb | op1.i=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | CMF.B28 | 11 | 11101101111 | cmp fcmp | op2.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | CMF.X22 | 11 | 11101110000 | cmp fcmp | op2.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op2.r=p1[11:8] op2.s=p1[7:6] op2.r=p0[3:0] |
| 3 | CMF.PC32 | 11 | 11101110011 | cmp fcmp | op2.p=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | CMF.A32 | 11 | 11101110100 | cmp fcmp | op2.a=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | CMF.I32 | 11 | 11101110101 | cmp fcmp | op2.i=p1[15:0]+p2[15:0] op1.r=p0[3:0] |
| 3 | LDU.B28 | 12 | 111100000011 | movzb.ud | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDF.B28 | 12 | 111100000110 | movuq | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] op2.r=p0[3:0] |
| 3 | LDF.X22 | 12 | 111100000111 | movuq | op1.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] op2.r=p0[3:0] |
| 3 | LDF.PC32 | 12 | 111100001010 | movuq | op1.p=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | LDF.A32 | 12 | 111100001011 | movuq | op1.a=p1[15:0]+p2[15:0] op2.r=p0[3:0] |
| 3 | SOF.B28 | 12 | 111100001100 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.d=p1[11:0]+p2[15:0] op1.r=p1[15:12] |
| 3 | SOF.X22 | 12 | 111100001101 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] |
| 3 | SOF.PC32 | 12 | 111100010000 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.p=p1[15:0]+p2[15:0] |
| 3 | SOF.A32 | 12 | 111100010001 | clr com inc dec neg tst adc sbc asl asr push pop jmp call jmpi calli | op1.a=p1[15:0]+p2[15:0] |
| 3 | DPF.D28 | 12 | 111100010010 | movq movl movw movb movzl movzw movzb add sub bic bis xor and mul mulh shl | op1.d=p1[11:0]+p2[15:0] op2.r=p1[15:12] |
| 3 | DPF.D28 | 13 | 1111001000100 | shr sar fadd fsub fmul bit lea movub | op1.d=p1[11:0]+p2[15:0] op2.r=p1[15:12] |
| 3 | BRF | 13 | 1111001000101 | br bne beq bpl bmi bvc bvs bcc | op1.p=p1[15:0]+p2[15:0] |
| 3 | BRF | 14 | 11110010100011 | bcs bge blt bgt | op1.p=p1[15:0]+p2[15:0] |
| 3 | DPF.D28 | 15 | 111100101111100 | movuw movul | op1.d=p1[11:0]+p2[15:0] op2.r=p1[15:12] |
| 3 | BRF | 15 | 111100101111101 | ble bhi | op1.p=p1[15:0]+p2[15:0] |
| 3 | CALLF | 15 | 111100101111110 | call jmp | op1.p=p1[15:0]+p2[15:0] |
| 3 | PUSHMF | 15 | 111100101111111 | pushm popm | op1.i=p1[15:0]+p2[15:0] |
| 3 | SPADJF | 15 | 111100110000000 | add sub | op1.i=p1[15:0]+p2[15:0] |
| 3 | DPF.D28 | 16 | 1111001100011110 | movuq | op1.d=p1[11:0]+p2[15:0] op2.r=p1[15:12] |
| 3 | BRF | 16 | 1111001100011111 | blos | op1.p=p1[15:0]+p2[15:0] |
| 3 | PUSHI3 | 16 | 1111001100100000 | push | op1.i=p1[15:0]+p2[15:0] |
| 3 | JTAG3 | 16 | 1111001100100010 | jtag | op1.d=p1[5:0]+p2[15:0] op1.r=p1[15:12] op1.r=p1[11:8] op1.s=p1[7:6] |
| 5 | MOVQL | 12 | 111100000010 | movql | op1.i=p1[15:0]+p2[15:0]+p3[15:0]+p4[15:0] op2.r=p0[3:0] |

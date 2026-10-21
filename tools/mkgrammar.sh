#!/bin/sh
# Expand spec/pdp64.hbnf.in into spec/pdp64.hbnf.  hbnf expressions have no functions, so the two opcode classes that
# several alternatives share are written out here, once.
#   memory-operand opcodes: 0x00-0x0B moves and LEA, 0x12 XFER, 0x13 SOP, 0x16-0x22 ALU, 0x24-0x27 FP ALU
#   register-nibble escapes: 0x0C BESC, 0x0D MBLK, 0x0E AESC, 0x10 FESC, 0x11 ATOM
cd "$(dirname "$0")/../spec"
MEM='(opc <= 0x0B || opc == 0x12 || opc == 0x13 || (opc >= 0x16 \&\& opc <= 0x22) || (opc >= 0x24 \&\& opc <= 0x27))'
REGESC='(opc == 0x0C || opc == 0x0D || opc == 0x0E || opc == 0x10 || opc == 0x11)'
sed -e "s/@MEM@/$MEM/g" -e "s/@REGESC@/$REGESC/g" pdp64.hbnf.in > pdp64.hbnf

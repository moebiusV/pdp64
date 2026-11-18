#!/usr/bin/env python3
"""kmn.py FILE.s FUNC ... -- the distinct mnemonics (with counts) of each function of a compiler's assembly output"""
import re, sys, collections
txt = open(sys.argv[1]).read().split('\n')
funcs = {}
cur = None
for ln in txt:
    m = re.match(r'^([A-Za-z_]\w*):', ln)
    if m and not ln.startswith('.L'):
        cur = m.group(1); funcs[cur] = collections.Counter(); continue
    if cur is None: continue
    s = ln.strip()
    if not s or s[0] in '.#;@/' : continue
    s = re.sub(r'\s*(#|;|//).*$', '', s)
    w = s.split()[0] if s.split() else ''
    if re.match(r'^[A-Za-z]', w) and not w.endswith(':'):
        funcs[cur][w] += 1
skip = re.compile(r'^(mov|movl|movq|movzx|movsx|movslq|movsxd|add|addq|addl|sub|subl|subq|cmp|cmpl|cmpq|test|jmp|je|jne|jg|jge|jl|jle|ja|jae|jb|jbe|jns|js|ret|retq|lea|leaq|xor|xorl|and|andl|or|orl|shl|shr|sar|neg|negl|cdq|cltq|cdqe|imul|sete|setne|cmov\w+|b|b\.\w+|bl|ldr|str|ldrb|ldrh|ldrsb|ldrsh|ldrsw|strb|strh|ldp|stp|lsl|lsr|asr|orr|eor|neg|csel|cset|cbz|cbnz|tbnz|tbz|ret|nop|addi|addiw|slli|srli|srai|li|mv|bnez|beqz|bltz|bgez|blt|bge|bgeu|bltu|beq|bne|j|lw|ld|sw|sd|lb|lbu|lh|lhu|sb|sh|neg|negw|sext\.w|add\.w|subw|addw|andi|ori|xori|slliw|sraiw|srliw|mulw|mul|lui|auipc|jr|slti|sltiu|sltu|slt|seqz|snez|max|min|minu|maxu|clz|ctz|cpop|andn|orn|sext\.b|sext\.h|zext\.b|zext\.h|zext\.w|sh1add|sh2add|sh3add|add\.uw|sh1add\.uw|sh2add\.uw|sh3add\.uw|\.\w+|jirl|bne|bge|beq|blt|bltu|bgeu|bnez|beqz|move|ori|lu12i\.w|addi\.w|addi\.d|add\.w|add\.d|slli\.w|slli\.d|srli\.w|srai\.w|srli\.d|sub\.w|sub\.d|ld\.[bhwd]\w*|st\.[bhwd]\w*|bstrpick\.w|bstrpick\.d|ext\.w\.[bh]|slt|sltu|maskeqz|masknez|and|or|xor|nor|b|bl|ret|slti|sltui|mul\.w|mul\.d|jr|addi|li|lui|stw|stb|sth|lwz|lbz|lhz|lha|lwa|ld|std|addi|addis|add|subf|cmpw|cmpd|cmplw|cmpld|cmpwi|cmpdi|cmplwi|cmpldi|bne|beq|blt|bgt|ble|bge|bdnz|blr|b|mr|li|lis|ori|oris|extsw|extsh|extsb|clrldi|rldicl|rlwinm|slwi|srwi|srawi|neg|isel|nop|mtctr|mflr|mtlr|ld|lwz|stw|std|crxor|addic|addze|ble|bnelr|beqlr|bltlr|bgelr|sldi|srdi|rldic|rldimi|andi\.|ori|xori|cmpb|mulld|mullw|divw|addo|subfic|subfc|subfe|mulhw|mulhd|bgtlr|blelr|maskz|sllg|srlg|lgr|lgfr|lgh|lgb|llgc|llgh|llgf|ahi|aghi|ar|agr|sr|sgr|cr|cgr|clr|clgr|j|jh|jl|jle|jne|je|jnle|jnh|jnl|jhe|jnhe|jhe|jlh|jz|jnz|brctg|brcl|brc|br|lhi|lghi|llill|iihf|iilf|lr|ltr|ltgr|ar|nr|xr|or|ogr|ngr|xgr|sllk|srlk|srak|lcr|lpr|lndfr|mvhi|la|lay|laa|lgrl|bras|brasl|basr|jg|jm|jnm|jp|jnp|jo|jno|jc|jnc|lmg|stmg|\w+h?\.?\w*:)$')
for f in sys.argv[2:]:
    c = funcs.get(f)
    if c is None: print(f, 'missing'); continue
    print(f, ' '.join('%s:%d' % kv for kv in c.most_common() if not skip.match(kv[0])))

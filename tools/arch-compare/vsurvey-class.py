#!/usr/bin/env python3
"""vsurvey-class.py FREQ.TSV [--unk N] -- sort the tokens of vsurvey-freq.py into operation classes and print the shares.

The classes (the same for every ISA, so that the tables can be compared):
 ld   plain vector load/store            seg  interleaved/segment load/store     gath gather/scatter
 mv   move, broadcast, insert/extract, zero/set constant
 add  integer add/subtract (wrapping)    sat  saturating add/subtract            avg  averaging (rounding or not)
 abd  absolute value / absolute difference     sad  sum of abs differences, abs-diff-accumulate
 mm   min/max                            mul  integer multiply, low half
 mulh multiply high / rounding high / Q-format (pmulhrsw, sqrdmulh)   mulw widening multiply
 madd pairwise multiply-add (pmaddwd, pmaddubsw)  mac integer multiply-accumulate  macw widening multiply-accumulate
 dot  dot product (sdot, vpdpbusd)       fma  floating fused multiply-add         fp   other floating-point
 sh   shift                              shr  rounding shift                      shn  shift with narrowing (rshrn, vnclip)
 nar  narrowing (pack, xtn, sqxtn)       wid  widening (uxtl, pmovzx, punpck-with-zero)  wadd widening add
 logic and/or/xor/andn/not               sel  bit select / blend / merge          cmp  compare to mask
 mask mask/predicate registers           perm fixed shuffle/interleave/unpack/ext/slide   tbl variable table lookup/permute
 red  horizontal reduction, pairwise add bits popcount/clz/bit reverse/bswap/crypto cvt conversion
 cfg  vector-length configuration, prefetch   free no instruction (casts, get_low)   oth  other
Prints, for each ISA, the share of each class among the VECTOR instructions (scalar instructions of assembly are dropped)."""
import re, sys, collections

R = lambda *a: re.compile(*a)

# ----- x86: asm mnemonic or intrinsic 'W:op_type' -----
X86_VEC = R(r'^(v?p[a-z0-9]+|v[a-z0-9]+|mova\w*|movu\w*|movd|movq|movh\w*|movl\w*|movs[sd]|movdq\w*|movnt\w*|movmsk\w*|\w+(ps|pd|ss|sd)|shuf\w+|unpck\w+|cvt\w+|k(mov|xor|xnor|or|and|not|shift|add|test|unpck|ortest)\w*|palign\w+|lddqu|rcp\w+|rsqrt\w+|hadd\w+|hsub\w+|dpp\w+|round\w+|extractps|insertps|gf2p8\w+|aes\w+|pclmul\w+|blendp\w|blendv\w+)$')
X86_NOT = R(r'^(sub[bwlq]|add[bwlq]|cmp[bwlq]|xor[bwlq]|and[bwlq]|or[bwlq]|push|pop|popcnt|prefetch\w*|pause|pext|pdep|pushf|popf|jp|call|jmp|ja|jb|jc|jz|jnz|jne|je|jg|jl|jge|jle|jae|jbe|jnc|js|jns|add|sub|mul|div|and|or|xor|cmp|cmps|and|abs|kmov\w*_|v?pcmpistri)$')
X86_ASM = [
 ('mask', r'^k(mov|xor|xnor|or|and|not|shift|add|test|unpck|ortest)\w*|^v?p(movb2m|movw2m|movd2m|movq2m|movm2\w)|^v?ptestn?m\w|^vpcmpu?[bwdq]$|^vpblendm\w'),
 ('gath', r'^v?p?(gather|scatter)\w*'),
 ('mv',   r'^v?(mova\w*|movu\w*|movdq[au]|movd|movq|movh\w*|movl\w*|movs[sd]|movs[lh]dup|movddup|movlhps|movhlps|movntdqa?|movnt\w*|lddqu|vmovdqu\d*|vmovdqa\d*|vmovaps|vmovups|vmovd|vmovq|vmovntdq)$|^vzeroupper|^v?(broadcast\w*|pbroadcast\w*|pinsr\w|pextr\w|insert\w*|extract\w*|vinserti\w+|vextracti\w+|vinsertf\w+|vextractf\w+|vpbroadcast\w*|vbroadcast\w*|vperm2[if]128|vperm2i128)$|^v?(movmsk\w+|pmovmskb)$|^vpmov(b2m|w2m)$|^v?cvtsi2s[sd]$|^pxor_zero'),
 ('perm', r'^v?(pshuf[dlh]w?|pshufd|pshuflw|pshufhw|shufp[sd]|punpck\w+|unpck\w+|palignr|valign\w+|vpermq|vpermpd|vpermilp[sd]|vpermd|vpalignr|pblend[wd]|vpblendd|blendp[sd]|vshuf[if]\d+x\d+|vshufp[sd]|vpshufd|vpunpck\w+|pslldq|psrldq|vpslldq|vpsrldq|vpshuflw|vpshufhw|vperm[a-z]*i?)$'),
 ('tbl',  r'^v?(pshufb|vpshufb|vpermb|vpermw|vperm[it]2\w|vpermi2\w|vpermt2\w|vpermd|vpermps|vpermb)$'),
 ('sel',  r'^v?(pblendvb|blendv\w+|vpblendvb|vpternlog\w|vpblendm\w)$'),
 ('sad',  r'^v?psadbw|^v?mpsadbw'),
 ('madd', r'^v?pmadd(wd|ubsw)$|^vpmadd\w+|^v?pmacs\w+'),
 ('cfg',  r'^(vzeroupper|prefetch\w*|emms|sfence|lfence|mfence|pause)$'),
 ('dot',  r'^vpdp\w+|^vdpbf16ps|^v?dpp[sd]$'),
 ('mulh', r'^v?pmulh(rsw|w|uw|rw)$|^vpmulh\w+|^vpmulhrsw'),
 ('mulw', r'^v?pmul(udq|dq)$|^vpmuludq|^vpmuldq|^vpmultishiftqb'),
 ('mul',  r'^v?pmull(w|d|q)$|^vpmull\w+|^v?pmulld$'),
 ('fma',  r'^v?f(n)?m(add|sub|addsub|subadd)\w*|^fmadd\w*|^vfmadd\w*|^vfnmadd\w*|^vfmsub\w*'),
 ('avg',  r'^v?pavg[bw]$|^vpavg\w'),
 ('sat',  r'^v?p(adds|subs|addus|subus)[bw]$|^vp(adds|subs|addus|subus)\w'),
 ('abd',  r'^v?pabs[bwd]$|^vpabs\w|^v?psign[bwd]$'),
 ('mm',   r'^v?p(min|max)(s|u)[bwdq]$|^vp(min|max)\w+|^v?(min|max)(ps|pd|ss|sd)$|^v(min|max)\w+'),
 ('red',  r'^v?phadd\w*|^v?phsub\w*|^v?hadd\w+|^v?hsub\w+|^v?phminposuw'),
 ('nar',  r'^v?pack(ss|us)\w+|^vpack\w+|^vpmov(wb|dw|qd|db|qw|qb|uswb|usdw|usqd|sdb|swb|sdw)\w*|^vpmov(us|s)?\w+(?<!zx)(?<!sx)$'),
 ('wid',  r'^v?pmov[sz]x\w+|^vpmov[sz]x\w+'),
 ('shn',  r'^vpshr?\w*|^vpsh[ld]\w+'),
 ('sh',   r'^v?ps(ll|rl|ra)[wdq]$|^v?ps(ll|rl|ra)v\w+|^vps(ll|rl|ra)\w+|^vprol\w*|^vpror\w*'),
 ('logic',r'^v?(pand|por|pxor|pandn|andp[sd]|orp[sd]|xorp[sd]|andnp[sd])\w*$|^vpand\w*|^vpor\w*|^vpxor\w*|^vpandn\w*'),
 ('cmp',  r'^v?pcmp(eq|gt)[bwdq]$|^vpcmp\w+|^v?cmp(p[sd]|s[sd])$|^v?cmp\w+(ps|pd|ss|sd)$|^vcmp\w+'),
 ('cvt',  r'^v?cvt\w+|^vcvt\w+|^vpmov\w*2\w+'),
 ('bits', r'^v?(gf2p8\w+|aes\w+|pclmul\w+|vpopcnt\w+|vplzcnt\w+|vpshufbitqmb|vpconflict\w+)$'),
 ('fp',   r'^v?(add|sub|mul|div|sqrt|rcp|rsqrt|min|max|round|and|andn|or|xor|dp|hadd|hsub|addsub|unpck|shuf|mov|blend|cmp|comis|ucomis)\w*(ps|pd|ss|sd)$|^v?rcp\w+|^v?rsqrt\w+'),
 ('add',  r'^v?p(add|sub)[bwdq]$|^vp(add|sub)\w+'),
 ('mv',   r'^v?pinsr\w|^v?pextr\w'),
]
X86_ASM = [(c, R(p)) for c, p in X86_ASM]

# x86 intrinsics: 'W:op' with op like add_i16, maddubs_i16, mulhrs_i16 ...
X86_INT = [
 ('mask', r'^(kmov|kand|kor|kxor|cmp\w+_mask|test\w+_mask|movepi\d+_mask|mask_|maskz_)'),
 ('gath', r'(gather|scatter|i32gather|i64gather)'),
 ('free', r'^(cast\w+|undefined\w*|zextsi\d+_si\d+)'),
 ('mv',   r'^(load\w*|store\w*|loadu\w*|storeu\w*|lddqu\w*|stream\w*|set1\w*|set\w*|setzero\w*|broadcast\w*|insert\w*|extract\w*|cvtsi\d+_si\d+|movemask\w*|move\w*|unpack\w*_zero|mask_load\w*|maskz_load\w*|maskload\w*|maskstore\w*|permute2f128\w*|permute2x128\w*|get\w*)'),
 ('sad',  r'^sad_u8'),
 ('madd', r'^(madd_i16|maddubs_i16|madd52\w*)'),
 ('dot',  r'^(dpbusd\w*|dpwssd\w*|dpbusds\w*|dpwssds\w*|dpbf16\w*|dpbssd\w*|dpbuud\w*)'),
 ('mulh', r'^(mulhrs_i16|mulhi_i16|mulhi_u16)'),
 ('mulw', r'^(mul_i32|mul_u32|mul_epu32|mul_epi32)'),
 ('mul',  r'^(mullo_i\d+|mullo\w*)'),
 ('fma',  r'^(fmadd\w*|fnmadd\w*|fmsub\w*|fnmsub\w*|fmaddsub\w*)'),
 ('avg',  r'^avg_'),
 ('sat',  r'^(adds_|subs_)'),
 ('abd',  r'^(abs_|sign_)'),
 ('mm',   r'^(min_|max_|reduce_(max|min))'),
 ('red',  r'^(hadd_|hsub_|reduce_add|reduce_mul|reduce_)'),
 ('nar',  r'^(packs_|packus_|cvtepi\d+_epi\d+|cvtsepi|cvtusepi|cvtepi16_epi8|cvtepi32_epi16|cvtepi32_epi8)'),
 ('wid',  r'^(cvtepi8_|cvtepu8_|cvtepi16_|cvtepu16_|cvtepi32_epi64|cvtepu32_|cvtepu8_|unpack(lo|hi)_i\d+_zero)'),
 ('shn',  r'^(shrdi|shldi|shrdv|shldv)'),
 ('sh',   r'^(sll|srl|sra|slli|srli|srai|sllv|srlv|srav|slli_s|srli_s|bslli|bsrli|rol|ror|slli_)'),
 ('logic',r'^(and_|or_|xor_|andnot_|ternarylogic\w*|and_s|or_s|xor_s|andnot_s)'),
 ('cmp',  r'^(cmpeq_|cmpgt_|cmplt_|cmpge_|cmple_|cmp_|cmpneq_|cmpnle)'),
 ('sel',  r'^(blendv_|blend_|blendm_|mask_blend\w*|mask_mov|maskz_mov)'),
 ('perm', r'^(shuffle_i32|shuffle_i16|shufflelo|shufflehi|shuffle_f|shuffle_32x4|shuffle_i64x2|shuffle_f32x4|unpack\w+|alignr_\w+|permute_\w+|permute4x64_\w+|permutex_\w+|permutexvar_(f|i)32|permute32x\w+|permute2\w+|permutevar_\w+|blend_\w+|inserti\w+)'),
 ('tbl',  r'^(shuffle_i8|permutevar8x32\w*|permutexvar_i8|permutexvar_i16|permutexvar_i32|permutex2var\w+|permutexvar_\w+)'),
 ('cvt',  r'^(cvt\w+|cvtt\w+)'),
 ('bits', r'^(popcnt\w*|clmulepi64\w*|aesenc\w*|gf2p8\w*|lzcnt\w*|tzcnt\w*|crc32\w*|bswap\w*|sha\w+)'),
 ('fp',   r'^(add_f|sub_f|mul_f|div_f|sqrt_f|rcp_f|rsqrt_f|min_f|max_f|round_f|floor_f|ceil_f|abs_f|and_f|or_f|xor_f|hadd_f|dp_f|cmp\w+_f|blend_f|movehl|movelh|rcp14\w*|fmadd\w*|getexp|scalef|reduce\w*|castsi\w*|mulhi\w*)'),
 ('add',  r'^(add_i|sub_i|add_u|sub_u|add_epi|sub_epi|alignr_epi8)'),
]
X86_INT = [(c, R(p)) for c, p in X86_INT]

def cls_x86(tok, kind):
    if kind == 'intr' and ':' in tok:
        op = tok.split(':', 1)[1]
        for c, rx in X86_INT:
            if rx.search(op):
                return c
        return 'oth'
    if not X86_VEC.match(tok) or X86_NOT.match(tok):
        return None
    for c, rx in X86_ASM:
        if rx.search(tok):
            return c
    return 'oth'

# ----- ARM NEON (assembly names without v; intrinsic names with the leading v stripped) -----
NEON = [
 ('free', r'^(reinterpret\w*|combine|get_low|get_high|get_lane|set_lane|swp|create|set_lane_free|undef|dup_laneq_free)$'),
 ('seg',  r'^(ld[234]r?(_lane|_dup)?|st[234](_lane)?|ld1_x[234]|st1_x[234]|ld[234]q?)$'),
 ('ld',   r'^(ld1r?(_lane|_dup)?|st1(_lane)?|ldr|str|ldp|stp|ld1q?|ldur|stur|ldnp|stnp|ldrq|ld1[bhwd]|st1[bhwd]|ld1r[bhwd]|ld1rq\w*|ldff1\w*|ldnt1\w*|stnt1\w*|ld1s[bhw]|ld1u\w*|ld1rs\w*|ld1sb|ld1sh|ld1sw)$'),
 ('mask', r'^(whilelt|whilele|whilelo|whilels|ptrue|pfalse|cntp|ptest|pnext|pfirst|brk\w*|cnt[bhwd]|incp|decp|incb|inch|incw|incd|ptrues|pnext|rdffr|setffr|punpk\w+|zip1_p|zip2_p|uzp1_p|uzp2_p|trn1_p|rev_p|sel_p|and_p|eor_p|orr_p|bic_p|nand_p|lastb|lasta|clastb|clasta|splice|compact|index)$'),
 ('gath', r'^(ld1_gather\w*|st1_scatter\w*|gather\w*|scatter\w*|ldff1_gather\w*)$'),
 ('dot',  r'^(sdot|udot|usdot|sudot|dot|dot_lane|dot_laneq|usdot_lane|usdot_laneq|sudot_lane|sudot_laneq|smmla|ummla|usmmla|bfmmla|fmmla|bfdot|bfmlalb|bfmlalt|fdot|sdot_lane|udot_lane|cdot|sqdmlalbt)$'),
 ('fma',  r'^(fmla|fmls|fmadd|fmsub|fnmadd|fnmsub|fma|fms|fma_lane|fma_laneq|fma_n|fmls_lane|fmla_lane|fcmla|fmad|fmsb|fnmad|fnmla|fnmls|fnmsb|fcadd|fmlal\w*|fmlsl\w*|fmax_|fmmla|bfmla)$'),
 ('sad',  r'^(uabal2?|sabal2?|uaba|saba|uabal_high|sabal_high|abal|aba|abal_high|sabdlb|uabdlb|sabalb|uabalb|sabalt|uabalt|saba_s)$'),
 ('abd',  r'^(uabd|sabd|abd|abdl|abdl_high|uabdl2?|sabdl2?|abs|sqabs|fabs|fabd|neg|sqneg|fneg|abd_high|uabdlt|sabdlt|abs_s)$'),
 ('avg',  r'^(urhadd|srhadd|uhadd|shadd|rhadd|hadd|uhsub|shsub|hsub|urhadd_x|rhaddq)$'),
 ('mulh', r'^(sqrdmulh|sqdmulh|sqrdmulh_lane|sqdmulh_lane|qrdmulh|qdmulh|qrdmulh_n|qdmulh_n|qrdmulh_lane|qdmulh_lane|qrdmulhq_lane|mulh|smulh|umulh|sqrdmlah|sqrdmlsh|qrdmlah|qrdmlsh|pmulh|sqdmulh_n|sqrdmulh_n)$'),
 ('macw', r'^(smlal2?|umlal2?|smlsl2?|umlsl2?|mlal|mlal_high|mlsl|mlsl_high|mlal_n|mlal_lane|mlal_high_lane|mlal_high_n|mlsl_lane|mlal_laneq|mlal_high_laneq|smlalb|smlalt|umlalb|umlalt|smlslb|smlslt|umlslb|umlslt|sqdmlal2?|sqdmlsl2?|qdmlal|qdmlsl|qdmlal_lane|qdmlal_high|qdmlsl_lane|smlal_lane|sqdmlalb|sqdmlalt|sqdmlslb|sqdmlslt|mlal_laneq)$'),
 ('mulw', r'^(smull2?|umull2?|pmull2?|mull|mull_high|mull_n|mull_lane|mull_high_n|mull_high_lane|smullb|smullt|umullb|umullt|sqdmull2?|qdmull|qdmull_n|qdmull_high|qdmull_lane|qdmull_high_n|qdmull_high_lane|pmullb|pmullt|mull_laneq|qdmullb|qdmullt)$'),
 ('mac',  r'^(mla|mls|mla_n|mla_lane|mls_lane|mla_laneq|mls_n|mla_s|mla_q|mad|msb|mls_laneq)$'),
 ('mul',  r'^(mul|mul_n|mul_lane|mul_laneq|mul_s|mul_x|mulx|fmul|fmulx|mul_f|mul_m|mul_z|mul_lane_f|fmul_lane|fmul_n|fmul_laneq)$'),
 ('wadd', r'^(uaddl2?|saddl2?|uaddw2?|saddw2?|usubl2?|ssubl2?|usubw2?|ssubw2?|addl|addl_high|addw|addw_high|subl|subl_high|subw|subw_high|uaddlb|uaddlt|saddlb|saddlt|uaddwb|uaddwt|saddwb|saddwt|usublb|usublt|ssublb|ssublt|usubwb|usubwt|ssubwb|ssubwt|addhn2?|raddhn2?|subhn2?|rsubhn2?|addhn|raddhn|saddlbt|ssublbt)$'),
 ('red',  r'^(addv|uaddlv|saddlv|addp|uaddlp|saddlp|uadalp|sadalp|faddp|fmaxp|fminp|smaxp|sminp|umaxp|uminp|smaxv|sminv|umaxv|uminv|fmaxv|fminv|fmaxnmv|fminnmv|addv_|padd|paddl|padal|pmax|pmin|maxv|minv|addlv|addvq|paddlq|faddv|addv_x|saddv|uaddv|andv|orv|eorv|maxnmv|minnmv|fmaxnmp|fminnmp|padd_s|padd_u|paddlq_x|addhn_red|faddp_s|addp_s|pairwise|adalp|sadalp_s)$'),
 ('shn',  r'^(shrn2?|rshrn2?|sqshrn2?|sqrshrn2?|uqshrn2?|uqrshrn2?|sqshrun2?|sqrshrun2?|shrn_n|rshrn_n|qshrn_n|qrshrn_n|qshrun_n|qrshrun_n|shrn_high_n|rshrn_high_n|qshrn_high_n|qrshrn_high_n|qshrun_high_n|qrshrun_high_n|uqrshrn_sz|sqrshrn_sz|sqrshrun_sz|drshrn_h|sqshrnb|sqshrnt|sqrshrnb|sqrshrnt|uqshrnb|uqshrnt|uqrshrnb|uqrshrnt|sqshrunb|sqshrunt|sqrshrunb|sqrshrunt|shrnb|shrnt|rshrnb|rshrnt|sqrshrn_sz|shrn_sz)$'),
 ('nar',  r'^(xtn2?|sqxtn2?|uqxtn2?|sqxtun2?|movn|movn_high|qmovn|qmovn_high|qmovun|qmovun_high|sqxtnb|sqxtnt|uqxtnb|uqxtnt|sqxtunb|sqxtunt|movn_u|uzp\w*_narrow|fcvtn2?|fcvtxn2?|bfcvtn2?|cvt_bf16|fcvtn|qmovnb|qmovnt|sqxtn_s|sqxtun_s|qmovunb|qmovunt|qmovnb_s)$'),
 ('wid',  r'^(uxtl2?|sxtl2?|ushll2?|sshll2?|movl|movl_high|shll|shll_n|shll_high_n|ushllb|ushllt|sshllb|sshllt|uunpklo|uunpkhi|sunpklo|sunpkhi|unpklo|unpkhi|uxtb|uxth|uxtw|sxtb|sxth|sxtw|shll2|zext|sext|extend|sunpk|uunpk|bfcvtl|fcvtl2?|fcvtlt|fcvtl_high)$'),
 ('shr',  r'^(srshr|urshr|srshl|urshl|srsra|ursra|sqrshl|uqrshl|rshr_n|rshl|rshl_n|rsra_n|qrshl|rshr|rsra|srshr_s|urshr_s|srshl_s|rshr_x|rshl_x|srshr_m|urshr_m|rsra|sqrshlr|uqrshlr|srshlr|urshlr|rsubhn_free)$'),
 ('sh',   r'^(shl|sshl|ushl|sshr|ushr|ssra|usra|sli|sri|lsl|lsr|asr|shr_n|shl_n|sra_n|sli_n|sri_n|sqshl|uqshl|sqshlu|shr|sra|qshl|qshl_n|qshlu_n|ushr_x|lsl_x|lsr_x|asr_x|lsl_m|lsr_m|asr_m|asrd|lslr|lsrr|asrr|shl_s|ssra_s|usra_s|sshl_s|ushl_s|lsr_n|lsl_n|asr_n|sshr_s|ushr_s|shl_u|bsl_n_free)$'),
 ('sat',  r'^(sqadd|uqadd|sqsub|uqsub|usqadd|suqadd|qadd|qsub|sqadd_s|uqadd_s|sqsub_s|uqsub_s|qadd_x|qsub_x|sqaddf|sqsub_f|sqadd_n|sqsubr|uqsubr|sqadd_m|uqadd_m)$'),
 ('mm',   r'^(smin|smax|umin|umax|fmin|fmax|min|max|fminnm|fmaxnm|minnm|maxnm|smin_s|smax_s|umin_s|umax_s|min_x|max_x|min_m|max_m|fmin_m|fmax_m|clamp|sclamp|uclamp|fclamp|min_u|max_u)$'),
 ('logic',r'^(and|orr|eor|bic|orn|not|mvn|and_s|orr_s|eor_s|bic_s|orn_s|eon|and_x|orr_x|eor_x|not_x|cnot|eor3|bcax|xar|nand|nor|eorbt|eortb)$'),
 ('sel',  r'^(bsl|bit|bif|bsl_s|bit_s|bif_s|sel|bsl1n|bsl2n|nbsl|bsl_u|bsl_s8|bsl_f|sel_f|sel_x|bsl_x|bsl_p|bsl_n|bsl_q)$'),
 ('cmp',  r'^(cmeq|cmhs|cmhi|cmge|cmgt|cmle|cmlt|cmtst|fcmeq|fcmge|fcmgt|fcmle|fcmlt|fcmne|facge|facgt|ceq|cge|cgt|cle|clt|cltz|cgtz|ceqz|cmpeq|cmpne|cmpge|cmpgt|cmple|cmplt|cmphi|cmphs|cmplo|cmpls|tst_v|cmeq_s|cmtst_s|cmhs_s|cmhi_s|cmge_s|cmgt_s|fcmeq_s|cmp_x|cmpne_s|facge_s|ceqz_s|tst|cmhi_x|cmpeq_s)$'),
 ('tbl',  r'^(tbl|tbx|qtbl1|qtbl2|qtbl3|qtbl4|qtbx1|qtbx2|qtbx3|qtbx4|tbl1|tbl2|tbl3|tbl4|tbx1|tbx2|tbx3|tbx4|tbl2_s|tbl_s|tbx_s)$'),
 ('perm', r'^(zip1|zip2|trn_p|uzp1|uzp2|trn1|trn2|ext|rev16|rev32|rev64|rev|zip|uzp|trn|ext_s|revb|revh|revw|rbit_free|dupq|extq|zipq1|zipq2|uzpq1|uzpq2|tblq|tbxq|rev_s|ext_x|zip1q|zip2q|uzp1q|uzp2q|trn1q|trn2q|splice|insr|dup_lane_perm|rev64_s|rev16_s|rev32_s|revd|sel_perm|zip_s|uzp_s)$'),
 ('bits', r'^(cnt|clz|cls|rbit|clz_s|cls_s|pmull_bits|aese|aesd|aesmc|aesimc|sha256h|sha256h2|sha256su0|sha256su1|sha1\w+|cnt_s|cnt_x|cnt_m|cnt_z|rbit_x|bfi|bfxil|ubfx|sbfx|cnt_u|rev_x|crc32\w*|pmull_p|cntw|cnth|cntb|cntd|bdep|bext|bgrp|rax1|sm3\w+|sm4\w+|sha512\w+|pmullb_bits)$'),
 ('cvt',  r'^(scvtf|ucvtf|fcvtzs|fcvtzu|fcvtas|fcvtau|fcvtns|fcvtnu|fcvtps|fcvtpu|fcvtms|fcvtmu|fcvt|frintn|frintm|frintp|frintz|frinta|frinti|frintx|cvt|cvt_f32|cvt_s32|cvt_u32|cvt_n|cvtq|cvtn|cvta|cvtm|cvtp|rndn|rndm|rndp|rnd|rnda|rndi|rndx|cvt_s|cvt_u|cvt_f|cvt_x|scvtf_s|ucvtf_s|fcvtzs_s|fcvtzu_s|scvtf_x|ucvtf_x|fcvtzs_x|fcvtzu_x|scvtf_m|ucvtf_m|fcvtzs_m|fcvtzu_m|frinta_x|frintn_x|frintm_x|frintz_x|frintp_x|frinti_x)$'),
 ('fp',   r'^(fadd|fsub|fmul|fdiv|fsqrt|fabs|fneg|frecpe|frsqrte|frecps|frsqrts|fmov|fmaxnm|fminnm|fadd_s|fsub_s|add_f|sub_f|mul_f|div|sqrt|recpe|rsqrte|recps|rsqrts|rcp|abs_f|neg_f|fadda|faddv|fscale|fexpa|ftsmul|ftssel|ftmad|frecpx|fdivr|fsubr|fsub_x|fadd_x|fmul_x|fdiv_x|fsqrt_x|fneg_x|fabs_x|fsubr_x|fdivr_x|fadd_m|fsub_m|fmul_m|fdiv_m|fsqrt_m|fneg_m|fabs_m|recpe_x|rsqrte_x|recps_x|rsqrts_x|trn_f|fdup|fcpy|fexp|fmov_x|dup_f|fscale_x)$'),
 ('add',  r'^(add|sub|subs_v|add_s|sub_s|add_x|sub_x|add_m|sub_m|add_z|sub_z|subr|subr_x|subr_m|subr_z|adds_v|neg_s|add_u|sub_u|add_n|sub_n|add_vec|adc|sbc|adcl|adclb|adclt|sbclb|sbclt|add_f_free|cadd|sqcadd|addpl|addvl|sub_lane|addhn_free|bsl_free|add_lane)$'),
 ('mv',   r'^(mov|movi|mvni|dup|dup_n|mov_n|dup_lane|dup_laneq|ins|umov|smov|fmov_v|dupq_lane|mov_v|ins_lane|movi_n|mvni_n|mov_q|dup_s|dup_x|dup_m|dup_z|cpy|cpy_x|cpy_m|cpy_z|sel_mv|set_lane|get_lane|setq|create_mv|dup_n_s|mov_n_s|dup_n_u|mov_n_u|fdup|dupm|insr|index|adr|mov_p|mov_z|mov_m|movprfx|movprfx_x|mov_x|cpy_s|cpy_n|copy|mov_lane|sunpk_free|load_dup|dup_x_n|mov_u|mov_s|mov_f|dup_f|dup_u|dup_b|dup_h|dup_w|dup_d)$'),
 ('mma',  r'^(fmopa|fmops|smopa|smops|umopa|umops|bfmopa|usmopa|sumopa|mopa|mops|addha|addva|zero_za|ldr_za|str_za|ld1_hor|st1_hor|ld1_ver|st1_ver|mova_za|read_hor|read_ver|write_hor|write_ver)$'),
 ('cfg',  r'^(prfm|prfb|prfh|prfw|prfd|prefetch\w*|dmb|dsb|isb|setffr|rdffr|wrffr|getffr|rdvl|addvl|addpl|cntb)$'),
]
NEON = [(c, R(p)) for c, p in NEON]

def cls_neon(tok, kind):
    if kind == 'asm':
        if tok.startswith('s:'):
            return None
        t = tok[2:]
    else:
        t = tok[1:] if tok.startswith('v') and not tok.startswith(('vld', 'vst')) else tok
        t = t[1:] if tok.startswith('v') and tok[1:2] != 'l' and False else t
        if tok.startswith(('vld', 'vst')):
            t = tok[1:]
        t = re.sub(r'_(high|lane|laneq|n)$', '', t) if t not in ('dup_n',) else t
    # SVE/NEON intrinsics write 'sv...' for SVE; handled by cls_sve
    for c, rx in NEON:
        if rx.search(t):
            return c
    t2 = re.sub(r'_(high|lane|laneq|n|s|x|m|z)$', '', t)
    if t2 != t:
        for c, rx in NEON:
            if rx.search(t2):
                return c
    return 'oth'

# ----- RISC-V V -----
RVV = [
 ('cfg',  r'^(vsetvl\w*|vsetivli|vsetvlstatic\d+|csr\w+|vtype\w*|vlenb|vsetvli_|vsetvl_e\d+m\d+|vsetvlmax\w*|vsetvlmax_e\w+)$'),
 ('seg',  r'^(vlseg\d+e\d+(ff)?|vsseg\d+e\d+|vlsseg\d+e\d+|vssseg\d+e\d+|vluxseg\w+|vloxseg\w+|vsuxseg\w+|vsoxseg\w+|vlseg\d+e\d+ff)$|^vlseg|^vsseg|^vlsseg|^vssseg|^vluxseg|^vsuxseg'),
 ('gath', r'^(vluxei\d+|vloxei\d+|vsuxei\d+|vsoxei\d+)$'),
 ('ld',   r'^(vle\d+(ff)?|vse\d+|vlse\d+|vsse\d+|vl\d+re\d+|vs\d+r|vlm|vsm|vl\d*r\w*|vle\d+_|vle|vse|vlse|vsse|vl\d+re\w+)$'),
 ('dot',  r'^(vqdot\w*|vdot\w*|vwdot\w*|vfwdot\w*|vfdot\w*|vqmaccu?\w*|vqmaccsu|vqmaccus|vmmacc\w*)$'),
 ('macw', r'^(vwmacc\w*|vwmaccu\w*|vwmaccsu\w*|vwmaccus\w*|vfwmacc\w*|vfwnmacc\w*|vfwmsac\w*|vfwnmsac\w*|vwmacc)$'),
 ('mac',  r'^(vmacc|vmadd|vnmsac|vnmsub)$'),
 ('fma',  r'^(vfmacc|vfmadd|vfnmacc|vfnmadd|vfmsac|vfmsub|vfnmsac|vfnmsub)$'),
 ('mulw', r'^(vwmul|vwmulu|vwmulsu|vfwmul)$'),
 ('mulh', r'^(vmulh|vmulhu|vmulhsu|vsmul)$'),
 ('mul',  r'^(vmul)$'),
 ('wadd', r'^(vwadd|vwaddu|vwsub|vwsubu)$'),
 ('wid',  r'^(vzext|vsext|vwcvt|vwcvtu|vfwcvt|vwcvtu\.x|vzext\.vf\d|vsext\.vf\d)$'),
 ('avg',  r'^(vaadd|vaaddu|vasub|vasubu|vavg\w*)$'),
 ('sat',  r'^(vsadd|vsaddu|vssub|vssubu)$'),
 ('abd',  r'^(vabs|vabsdu|vabsd|vabsaddu|vneg|vfabs|vfneg|vfsgnj\w*|vrsub_abs|vabdu|vabd|vabsd)$'),
 ('mm',   r'^(vmin|vminu|vmax|vmaxu|vfmin|vfmax|vclip\w*)$'),
 ('red',  r'^(vredsum|vredmax\w*|vredmin\w*|vredand|vredor|vredxor|vwredsum\w*|vfredusum|vfredosum|vfredsum|vfredmax|vfredmin|vfwredusum|vfwredosum|vwredsumu|vwredsum)$'),
 ('shn',  r'^(vnsrl|vnsra|vnclip|vnclipu)$'),
 ('nar',  r'^(vncvt|vfncvt|vncvt\.x\.x\.w|vncvtu|vfncvt_rod)$'),
 ('shr',  r'^(vssra|vssrl)$'),
 ('sh',   r'^(vsll|vsrl|vsra|vslli|vsrli|vsrai|vror|vrol|vrev8|vbrev8|vbrev|vclz|vctz|vcpop)$'),
 ('logic',r'^(vand|vor|vxor|vnot|vandn|vmand|vmor|vmxor|vmnand|vmnor|vmandn|vmorn|vmxnor)$'),
 ('sel',  r'^(vmerge|vfmerge|vmv_merge)$'),
 ('cmp',  r'^(vmseq|vmsne|vmslt|vmsltu|vmsle|vmsleu|vmsgt|vmsgtu|vmsge|vmsgeu|vmfeq|vmfne|vmflt|vmfle|vmfgt|vmfge|vmadc|vmsbc|vmsbf|vmsif|vmsof|vmnot|vmclr|vmset|vmmv|vmand\w*|vmor\w*|vmxor\w*|vmnand|vmnor)$'),
 ('mask', r'^(vfirst|vcpop\.m|viota|vid|vmsbf|vmsif|vmsof|vfirst\.m|vpopc|vlm|vsm|viota\.m|vid\.v)$'),
 ('tbl',  r'^(vrgather|vrgatherei16|vcompress|vgather)$'),
 ('perm', r'^(vslideup|vslidedown|vslide1up|vslide1down|vfslide1up|vfslide1down|vslideup_tu|vmv2r|vmv4r|vmv8r|vmv1r|vzip|vunzip|vpaire|vpairo|vunzipe|vunzipo|vslide|vcreate|vget|vset|vlmul_ext|vlmul_trunc|vreinterpret)$'),
 ('cvt',  r'^(vfcvt|vfcvt\.\w+|vfwcvt|vfncvt\w*|vfrec7|vfrsqrt7|vfcvt_x_f|vfcvt_f_x|vfcvt_rtz_x_f|vfcvt_f_xu|vfcvt_xu_f)$'),
 ('fp',   r'^(vfadd|vfsub|vfmul|vfdiv|vfsqrt|vfrsub|vfrdiv|vfwadd|vfwsub|vfwmul|vfrec7|vfrsqrt7|vfclass|vfmv|vfmin|vfmax|vfsgnj|vfwadd_wv)$'),
 ('add',  r'^(vadd|vsub|vrsub|vadc|vsbc|vwadd_w|vwaddu_w|vwsub_w|vwsubu_w|vsubr)$'),
 ('mv',   r'^(vmv|vmv\.v\.v|vmv\.v\.x|vmv\.s\.x|vmv\.x\.s|vfmv|vmv_v|vmv_s|vmv_x|vmv_v_v|vmv_v_x|vfmv_v_f|vfmv_f_s|vfmv_s_f|vmv\w*|vundefined|vpair\w*|vmvr\w*)$'),
]
RVV = [(c, R(p)) for c, p in RVV]

def cls_rvv(tok, kind):
    t = tok.split('.')[0] if kind == 'intr' else tok
    t = t.split('.')[0]
    if kind == 'asm' and not t.startswith('v'):
        return None
    for c, rx in RVV:
        if rx.search(t):
            return c
    # intrinsics carry a type: vwmacc_vv -> t='vwmacc'
    return 'oth'

# ----- LoongArch LSX/LASX -----
LA = [
 ('seg',  r'^(vld\w*seg\w*)$'),
 ('ld',   r'^(vld|vldx|vst|vstx|vldrepl|vstelm|ld|vldrepl\w*|vld_|vst_|vld_x\w+|vst_x\w+|vldi_load|vld\w*|vst\w*)$'),
 ('mv',   r'^(vreplgr2vr|vreplve\w*|vreplvei|vinsgr2vr|vpickve2gr|vldi|vrepl\w*|vextrins|vinsert|vextract|vori_mv|vmov|vmskltz|vmsknz|vmskgez|vpickve\w*|vldi|vandi_mv|vreplve0|vrepl128vei|vseti\w*|xvreplve0|xvrepl128vei|xvreplgr2vr|xvinsgr2vr|xvpickve2gr|xvpickve|xmov|xvpermi_mv)$'),
 ('dot',  r'^(vdp2|vdp2add|vdp2sub|vdp4|xvdp2sub|vmsknz)$'),
 ('macw', r'^(vmaddwl|vmaddwh|vmaddwev|vmaddwod|vmaddwev_\w+|vmaddwod_\w+)$'),
 ('mac',  r'^(vmadd|vmsub|vmaddwev_free|vfmadd_int)$'),
 ('mulw', r'^(vmulwl|vmulwh|vmulwev|vmulwod|vmulwev_\w+|vmulwod_\w+)$'),
 ('mulh', r'^(vmuh|vmulh)$'),
 ('mul',  r'^(vmul)$'),
 ('fma',  r'^(vfmadd|vfmsub|vfnmadd|vfnmsub)$'),
 ('wadd', r'^(vaddwl|vaddwh|vaddw|vsaddw|vaddwev|vaddwod|vsubwev|vsubwod|vsllwil|vexth|vext2xv|vhaddw|vhsubw|vhaddw_\w+|vaddwev_\w+|vaddwod_\w+)$'),
 ('wid',  r'^(vsllwil|vexth|vext2xv|vsllwil_\w+|vexth_\w+|vext2xv_\w+)$'),
 ('avg',  r'^(vavg|vavgr)$'),
 ('abd',  r'^(vabsd|vadda|vneg|vsigncov|vabsd_\w+|vsigncov_\w+)$'),
 ('sat',  r'^(vsadd|vssub)$'),
 ('mm',   r'^(vmin|vmax|vmini|vmaxi|vclip|vclip255|vsat)$'),
 ('red',  r'^(vhaddw|vhsubw|vsadd_red)$'),
 ('shn',  r'^(vssrarni|vssrani|vssrlrni|vssrlni|vsrlni|vsrani|vsrarni|vsrlrni|vssran|vssrlrn|vssrarn|vssrln|vssrlrni|vsran|vsrlrn|vsrarn|vsrln|vssrlni|vssrlrnu|vssrarni_\w+|vssrani_\w+)$'),
 ('shr',  r'^(vsrari|vsrar|vsrlri|vsrlr)$'),
 ('sh',   r'^(vsll|vsrl|vsra|vslli|vsrli|vsrai|vrotr|vrotri|vbsll|vbsrl|vsllwil_sh)$'),
 ('logic',r'^(vand|vor|vxor|vnor|vandn|vorn|vandi|vori|vxori|vnori)$'),
 ('sel',  r'^(vbitsel|vbitseli|vbitclr|vbitset|vbitrev|vbitclri|vbitseti|vbitrevi)$'),
 ('cmp',  r'^(vcmplt|vcmpeq|vcmple|vseq|vsle|vslt|vseqi|vslei|vslti|vfcmp|vsetnez|vsetz|vsetanyeqz|vsetallnez|vseteqz|vsetnez\w*)$'),
 ('tbl',  r'^(vshuf|vshuf4i|vshuf_\w+|vpermi|vshuf4i_\w+)$'),
 ('perm', r'^(vperm|vinsve0|vsplati|vilvl|vilvh|vpackev|vpackod|vpickev|vpickod|vbsrl_perm|vpermi|vextrins_perm|vshuf4i_perm|vpermi_w|xvpermi|xvpermi_perm|vpermi_d|vpermi_q)$'),
 ('cvt',  r'^(vffint|vftint|vftintrz|vfcvt|vfcvth|vfcvtl|vffinth|vffintl|vfrint|vftintrne|vfrintrne|vftintrm|vftintrp)$'),
 ('bits', r'^(vpcnt|vclz|vclo|vrev|vbitrev_b|vr8|vbitrevi_b|vmskltz|vreplvei_bits)$'),
 ('fma',  r'^(vnmsub|vnmadd|vmadd[1-4]|vmsub[1-4])$'),
 ('fp',   r'^(vfadd|vfsub|vfmul|vfdiv|vfsqrt|vfrecip|vfrsqrt|vfmax|vfmin|vfmaxa|vfmina|vfclass|vflogb|vfscaleb)$'),
 ('add',  r'^(vadd|vsub|vaddi|vsubi|vneg_add|vaddi_\w+|vsubi_\w+)$'),
]
LA = [(c, R(p)) for c, p in LA]

def cls_la(tok, kind):
    t = tok
    if kind == 'intr':
        t = tok.split('_')[0]
        if t.startswith('xv'): t = t[1:]
    else:
        if t.startswith('xv'): t = t[1:]
        if not t.startswith('v'):
            return None
    for c, rx in LA:
        if rx.search(t):
            return c
    return 'oth'

# ----- MIPS MSA (intrinsic names, __msa_ cut) -----
MSA = [
 ('mv',   r'^(fill|splat|splati|insert|insve|copy_[su]|ldi|move_v|cast\w*|ctcmsa|cfcmsa)'),
 ('ld',   r'^(ld_|st_|ldr|str)'),
 ('dot',  r'^(dotp_|dpadd_|dpsub_)'),
 ('macw', r'^(dpadd_\w+|dpsub_\w+)'),
 ('mac',  r'^(maddv|msubv)'),
 ('mulh', r'^(mulr_q|madd_q|maddr_q|msub_q|msubr_q|mul_q)'),
 ('mul',  r'^(mulv|div_|mod_)'),
 ('wadd', r'^(hadd_|hsub_|addvi|subvi)'),
 ('avg',  r'^(aver_|ave_)'),
 ('abd',  r'^(asub_|add_a|adds_a|ave_|nloc|nlzc|abs)'),
 ('sat',  r'^(adds_|subs_|subsus|subsuu|sat_)'),
 ('mm',   r'^(max_|min_|maxi_|mini_|max_a|min_a|clip\w*)'),
 ('shr',  r'^(srar|srari|srlr|srlri)'),
 ('sh',   r'^(sll|slli|sra|srai|srl|srli|sldi|sld_)'),
 ('shn',  r'^(sat_|srari_narrow)'),
 ('logic',r'^(and_v|or_v|xor_v|nor_v|andi_b|ori_b|xori_b|nori_b)'),
 ('sel',  r'^(bmnz|bmz|bsel|bseli|bnz|bz|binsl|binsr|bclr|bset|bneg|bmnzi|bmzi)'),
 ('cmp',  r'^(ceq|clt|cle|ceqi|clti|clei|fceq|fclt|fcle|fcne|fcun|fcor|fsult|fsule)'),
 ('perm', r'^(ilvr|ilvl|ilvev|ilvod|pckev|pckod|shf_|sldi|sld_|splati|insve)'),
 ('tbl',  r'^(vshf_)'),
 ('cvt',  r'^(ffint|ftint|ffql|ffqr|ftq|fexdo|fexupl|fexupr|ftrunc|frint|fexp2|fsqrt|frcp|frsqrt|flog2)'),
 ('fp',   r'^(fadd|fsub|fmul|fdiv|fmax|fmin|fmadd|fmsub|fsqrt|fabs|fmax_a|fmin_a)'),
 ('bits', r'^(pcnt|nlzc|nloc)'),
 ('nar',  r'^(sat_|pckev)'),
 ('red',  r'^(hadd_|hsub_)'),
 ('add',  r'^(addv|subv|addvi|subvi|asub)'),
]
MSA = [(c, R(p)) for c, p in MSA]
def cls_msa(tok, kind):
    for c, rx in MSA:
        if rx.search(tok):
            return c
    return 'oth'

# ----- POWER / s390x vec_ names -----
PPC = [
 ('ld',   r'^(ld|st|xl|xst|xl_len|xst_len|lde|ste|ldl|stl|lvsl|lvsr|xld2|xst2|xl_be|xst_be|ld_|st_)$|^(xl|xst)\w*|^(load|store)\w*|^(xl_len\w*)'),
 ('mma',  r'^(xv\w*ger\w*|xxsetaccz|xxmfacc|xxmtacc|disassemble_acc|assemble_acc|mma\w*)$|_mma$'),
 ('mv',   r'^(splat\w*|splats|promote|extract|insert|mfvscr|mtvscr|zero|splat_s\d+|splat_u\d+|splats|gb|round|revb_mv|xxspltib|xxspltw|ctz_mv|insert_exact|extract_exp)$'),
 ('macw', r'^(msum|msums)$'),
 ('dot',  r'^(msum|msums|sum4s|sum2s|sums|gfmsum\w*|mulo_msum|msum_dot)$'),
 ('fma',  r'^(madd|nmsub|msub|nmadd|fma|fms|nmadd)$'),
 ('mac',  r'^(mladd|mradds|madds)$'),
 ('mulh', r'^(mradds|mulhi|mulhs)$'),
 ('mulw', r'^(mule|mulo|mul_even|mul_odd|mulh|mulhi)$'),
 ('mul',  r'^(mul|mullo|mulhw|mul_)$'),
 ('wadd', r'^(addc|adde|addec|subc|sube|subec|adde_i|unpackh_add)$'),
 ('wid',  r'^(unpackh|unpackl|unpack\w*|extend\w*|unpackh_|unpackl_|signed_ext)$'),
 ('avg',  r'^(avg|aver)$'),
 ('abd',  r'^(abs|abss|abd|absd|neg|nabs)$'),
 ('sat',  r'^(adds|subs|addsu|subsu)$'),
 ('mm',   r'^(min|max|clamp|vmin|vmax)$'),
 ('red',  r'^(sum4s|sum2s|sums|reduce\w*|addc_red|hadd|hsum)$'),
 ('nar',  r'^(packs|packsu|pack|packs_cc|packsu_cc|packpx|packs_|packsu_)$'),
 ('sh',   r'^(sl|sr|sra|rl|slo|sro|sll|srl|sld|sldw|srdb|sldb|slb|srb|srab|sral|slv|srv|rli|rl_)$'),
 ('logic',r'^(and|or|xor|nor|andc|orc|nand|eqv|not)$'),
 ('sel',  r'^(sel|blendv)$'),
 ('cmp',  r'^(cmpeq|cmpgt|cmplt|cmpge|cmple|cmpne|cmpeq_idx|cmpeq_or_idx|cmpnez|cmpgt_cc|all_eq|any_eq|all_ge|any_ge|all_gt|any_gt|all_le|any_le|all_lt|any_lt|all_ne|any_ne|all_nan|any_nan|find_any\w*|cmpne_idx|cmpb)$'),
 ('tbl',  r'^(perm|permi|perm_idx|permx|vperm|xxperm|bperm|genmask|gather_element|permi_)$'),
 ('perm', r'^(mergeh|mergel|merge\w*|sld|sldw|mergee|mergeo|reve|revb|rev|xxpermdi|xxsldwi|permi|mergeh_|mergel_|pack_perm|sldi|revb\w*)$'),
 ('cvt',  r'^(ctf|cts|ctu|ctd|cts_|ctf_|float|float2|floate|floato|double|doublee|doubleo|doubleh|doublel|signed|unsigned|signede|signedo|unsignede|unsignedo|cvf|cvfo|cvfe|cvt\w*|ceil|floor|trunc|roundc|rint|round|nearbyint|loge|expte|rsqrte|re|rsqrt|sqrt|rsqrtex)$'),
 ('bits', r'^(popcnt|cntlz|cnttz|cntlz_lsbb|cnttz_lsbb|gb|vpmsum|pmsum_be|gfmsum|clz|ctz|bperm|sbox|cipher\w*|ncipher\w*|sbox_be|shasigma|sha\w*)$'),
 ('fp',   r'^(add_f|sub_f|mul_f|div|sqrt|abs_f|neg_f|max_f|min_f|nabs|trunc_f|floor_f|ceil_f|cpsgn|copysign|re|rsqrte|expte|logb|scalef|test_data_class|ldexp|frexp|insert_exp|extract_exp)$'),
 ('add',  r'^(add|sub|addc|subc|neg|add_u|sub_u|adds_free|sub_s|sub_u|add_s)$'),
 ('free', r'^(cast|reinterpret|ptr|xl_free|splats_free|unpack_free|extract4b|insert4b|mergeqh|mergeql|promote_free|mfvsr)$'),
]
PPC = [(c, R(p)) for c, p in PPC]
def cls_ppc(tok, kind):
    for c, rx in PPC:
        if rx.search(tok):
            return c
    return 'oth'

# ----- SVE intrinsics (names svXXX, suffix cut) -----
def cls_sve(tok, kind):
    if kind == 'asm':
        return cls_neon(tok, kind)
    t = tok[2:] if tok.startswith('sv') else tok
    t = re.sub(r'_(n|lane)$', '', t)
    r = cls_neon('v:' + t, 'asm')
    return r

CLS = {'x86': cls_x86, 'neon': cls_neon, 'sve': cls_sve, 'rvv': cls_rvv, 'lsx': cls_la, 'lasx': cls_la,
       'msa': cls_msa, 'ppc': cls_ppc, 's390': cls_ppc}

def load(fn):
    rows = []
    for ln in open(fn):
        i, p, k, t, n, f = ln.rstrip('\n').split('\t')
        rows.append((i, p, k, t, int(n), int(f)))
    return rows

def classify(rows):
    out = []
    for i, p, k, t, n, f in rows:
        c = CLS[i](t, k)
        if c is None:
            c = 'scalar'
        out.append((i, p, k, t, n, f, c))
    return out

if __name__ == '__main__':
    rows = classify(load(sys.argv[1]))
    unk = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == '--unk' else 0
    agg = collections.defaultdict(collections.Counter)
    for i, p, k, t, n, f, c in rows:
        agg[(i, p, k)][c] += n
    for key in sorted(agg):
        cnt = agg[key]
        vec = sum(v for c, v in cnt.items() if c not in ('scalar', 'free'))
        print(key, 'vector', vec, 'scalar/other dropped', cnt.get('scalar', 0), 'oth', cnt.get('oth', 0), '%.1f%%' % (100.0 * cnt.get('oth', 0) / max(vec, 1)))
    if unk:
        u = collections.defaultdict(collections.Counter)
        for i, p, k, t, n, f, c in rows:
            if c == 'oth':
                u[i][t] += n
        for i in u:
            print('UNCLASSIFIED', i, ' '.join('%s:%d' % x for x in u[i].most_common(unk)))

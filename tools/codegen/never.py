import sys, json, csv, collections, re
sys.path.insert(0,'/home/david/claude/pdp64/tools'); sys.argv=['x']
import pdp64size as p
MN=json.load(open('/tmp/p64opt/analysis.json'))['pdp64_mn']
MN['rori']=MN.get('rori',0)+MN.get('rol',0)
allm=p.all_mnemonics()
group={}; rule=None
for line in open(p.MNEM):
    if line.startswith(';') or not line.strip(): continue
    m=re.match(r'^([a-z0-9-]+)\s*=',line)
    if m: rule=m.group(1)
    if rule and rule.startswith('mn-'):
        for n in re.findall(r'"([a-z0-9_]+)"\s*@',line): group[n]=rule[3:]
group['set']='cond'
R={}
def put(names, why):
    for n in names.split(): R[n]=why
put('clz ctz clo cto popcnt bitrev bswap bswapw bswapl','intrinsic: __builtin_clz, ctz, popcount, bswap; no C operator (an idiom pass could find bswap and popcount loops; gcc and clang do)')
put('ror','idiom or intrinsic: rotate by a register count; rotates by a constant are emitted (as rol, which assembles to rori) for 64-bit values only: a 32-bit rotate has no instruction and is shl/shr/bis')
put('dshr','intrinsic or idiom: funnel shift (128-bit shifts, bignum)')
put('extb extzb insb','idiom: bit-field extract and insert; pcc reads fields with shifts (the FIELDOPS path is not used)')
put('xnorpop clmull clmulh utf8len utf8dec utf8enc','intrinsic only (population-count dot products, carry-less multiply, UTF-8)')
put('mmov mset mcmp mscn mscnn mval','library: memmove, memset, memcmp, memchr, strchr live in libc; the compiler emits mcpy for small struct copies only')
put('cas casdb swap swapdb xadd xadddb xand xanddb xor_ xor_db xxor xxordb xmax xmaxdb xmin xmindb xmaxu xmaxudb xminu xminudb ll sc','intrinsic: __sync_* and __atomic_* builtins, not implemented in the back end; ATOM is not assembled yet')
put('mulhu mulh','idiom: divide by a constant (multiply by a reciprocal) and 128-bit arithmetic; pcc does not do the division strength reduction')
put('addm subm bicm bism','MESC (not assembled): x op= y on a 64-bit object in memory; pcc has the path (FINDMOPS), the table does not use it yet')
put('movub movuw movul movuq','intrinsic: explicit unaligned accesses; the compiler uses byte copies for packed structs')
put('btag bntag jtag','language: tagged pointers (a dynamic-language runtime, not C)')
put('jmpi','idiom: a switch as a jump table (JMPI table(pc)(r*8)); equal in bytes to a compare chain below ~8 cases because the table entries are 8 bytes')
put('abs min max minu maxu','idiom: x<0?-x:x and a<b?a:b; a shared pass-1 or middle-end change (not done)')
put('set','idiom: a comparison used as a value; pass 1 turns it into branches before pass 2 sees it (a shared change)')
put('sob','idiom: a counted loop (dec; bne); pcc does not choose it (same size, one instruction fewer)')
put('adc sbc','multi-word arithmetic: needs a long-long or bignum lowering; the machine has 64-bit registers so C code does not need it')
put('bic bit','idiom: x & ~y and a mask test; the compiler uses and with the complemented constant and and+tst')
put('asr asl','shifts by one are used: asl and asr appear')
put('bvc bvs','overflow tests: __builtin_*_overflow (not implemented)')
put('bmi bpl','used only after floating-point compares')
put('fabs fneg','fabs: libm builtin (fabs); fneg is used')
put('fmin fmax fcopysign fclass fclass32 fsqrt fsqrt32 frint frinta frintm frintp frintz frintz fmadd fmadd32 fmsub fmsub32 fnmadd fnmadd32 fnmsub fnmsub32 fsflags','libm builtins and fenv: sqrt, fma, rint, copysign, fmin/fmax and the exception flags are library calls or intrinsics; contraction a*b+c to fma is not done')
put('fadd16 fsub16 fmul16 fdiv16 fcmp16 fcvtsh fcvths fsqrt16 fmadd16','binary16: no C type for it (_Float16 is not accepted by this pcc)')
put('mtps mfps spl trap trapl rti rtt halt bpt wfe sev fence tlbi tlbia tlbsync icinv icinva mtasid mfasid mtdp mfdp mtdmw mfcpuid prober probew lpad','system code: privileged or system-level, from assembly or inline asm in an operating system, not from C')
put('wait','alias of wfe')
put('fclass16 fcvtdh fcvthd fcvthl fcvtlh fmsub16 fnmadd16 fnmsub16','binary16: no C type for it here')
put('fcvtdqu','double to unsigned 64-bit: the corpus converts to unsigned long once, through fcvtqud/fcvtdq; rare in C that is not numeric')
put('fdiv32 fsub32','float arithmetic is rare in the corpus (no instance of float division or subtraction); the instructions are used (fadd32, fmul32) where float code occurs')
put('nop','padding only: the assembler inserts it for .even; the compiler never asks')
out=[]
for n in allm:
    out.append([n,group.get(n,''),MN.get(n,0),R.get(n,'' if MN.get(n,0) else 'not classified')])
with open('/tmp/p64opt/analysis/instructions_used.csv','w',newline='') as f:
    c=csv.writer(f); c.writerow(['mnemonic','group','static count','if never emitted: why']); c.writerows(sorted(out,key=lambda r:-r[2]))
z=[r for r in out if r[2]==0]
print(len(allm),'mnemonics;',len(z),'never emitted;')
print([r[0] for r in z if not r[3] or r[3]=='not classified'])

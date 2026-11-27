#!/usr/bin/env python3
"""gen.py KIND [params] > prog.s : whole assembly programs for the REMOVED words (the tile, gemm.f, the gather vldx), run on the sim64 of the commit
before wave 1 (fe84570d~1; the build recipe is in ../README.md).  Data are written as .long/.byte lines; the program writes its output buffer to
standard output (trap #1), and expected values are computed here, so a run is checked.   usage: gen.py gemm_tile VL | gemm_unit | spmv NNZ_PER_ROW | lut256 | spmv_scalar NNZ"""
import sys, struct, random
def lcg(seed=12345):
    s = [seed]
    def r():
        s[0] = (s[0]*1103515245 + 12345) & 0xffffffff; return s[0] >> 8
    return r
def words(name, vals, fmt='.long'):
    out = ['\t.data', '\t.align 8', name + ':']
    for i in range(0, len(vals), 8): out.append('\t%s\t%s' % (fmt, ','.join(str(v) for v in vals[i:i+8])))
    return out
def f32(x): return struct.unpack('<I', struct.pack('<f', x))[0]
CRT = ['\t.text', '\t.globl\t_start', '_start:', '\tcall\tmain', '\ttrap\t#0']
def emit_write(buf, nbytes): return ['\tmovq\t#1,r0', '\tlea\t%s,r1' % buf, '\tmovq\t#%d,r2' % nbytes, '\ttrap\t#1']
M, N, K = 16, 16, 64
def gemm_data():
    r = lcg(); A = [[(r() % 17) - 8 for _ in range(K)] for _ in range(M)]; B = [[(r() % 13) - 6 for _ in range(K)] for _ in range(N)]
    C = [[sum(A[i][k]*B[j][k] for k in range(K)) for j in range(N)] for i in range(M)]
    return A, B, C
def gemm_tile(VL):
    A, B, C = gemm_data()
    pa = []; pb = []
    for p in range(M//VL):
        for k in range(K):
            for rr in range(VL): pa.append(f32(A[VL*p+rr][k]))
    for q in range(N//VL):
        for k in range(K):
            for c in range(VL): pb.append(f32(B[VL*q+c][k]))
    L = list(CRT) + ['\t.text', 'main:', '\tpush\tr8', '\tpush\tr9', '\tpush\tr10', '\tpush\tr11']
    L += ['\tclr\tr8']                      # p
    L += ['Lp:\tclr\tr9']                   # q
    L += ['Lq:\tmovq\t#%d,r0' % (VL*K*4), '\tmul\tr8,r0', '\tlea\tPA,r1', '\tadd\tr1,r0',          # r0 = PA + p*VL*K*4
          '\tmovq\t#%d,r1' % (VL*K*4), '\tmul\tr9,r1', '\tlea\tPB,r2', '\tadd\tr2,r1',           # r1 = PB + q*VL*K*4
          '\tmovq\t#%d,r2' % (VL*N*4), '\tmul\tr8,r2', '\tmovq\t#%d,r3' % (VL*4), '\tmul\tr9,r3', '\tadd\tr3,r2', '\tlea\tCC,r3', '\tadd\tr3,r2',   # r2 = C + (p*VL*N + q*VL)*4
          '\tmovq\t#%d,r3' % K, '\tmovq\t#%d,r4' % (N*4), '\tcall\tk_ukr',
          '\tinc\tr9', '\tcbne\tr9,#%d,Lq' % (N//VL), '\tinc\tr8', '\tcbne\tr8,#%d,Lp' % (M//VL)]
    L += emit_write('CC', M*N*4) + ['\tpop\tr11', '\tpop\tr10', '\tpop\tr9', '\tpop\tr8', '\tret']
    L += ['k_ukr:', '\tvlen.f\tr5', '\tmovq\tr3,r6', '\tmul\tr5,r6', '\tlea\t(r1)(r6*4),r6', '\tvtclr\tt0', '\tvec\tr1,r6', '\tvld.f\tv8,(r1)+', '\tvld.f\tv9,(r0)+',
          '\tvtfmopa.f t0,v9,v8', '\tvend', '\tvtld.f\tt1,(r2),r4', '\tvtadd.f\tt0,t0,t1', '\tvtst.f\tt0,(r2),r4', '\tret']
    L += words('PA', pa) + words('PB', pb) + words('CC', [0]*(M*N))
    exp = b''.join(struct.pack('<f', C[i][j]) for i in range(M) for j in range(N))
    return L, exp
def gemm_unit():
    A, B, C = gemm_data()
    pa = [f32(A[i][k]) for i in range(M) for k in range(K)]; pb = [f32(B[j][k]) for j in range(N) for k in range(K)]
    L = list(CRT) + ['\t.text', 'main:', '\tsub\t#96,sp', '\tlea\tPA,r0', '\tmovq\tr0,0(sp)', '\tlea\tPB,r0', '\tmovq\tr0,8(sp)', '\tlea\tCC,r0', '\tmovq\tr0,16(sp)']
    for off, v in ((24, M), (32, N), (40, K), (48, K*4), (56, K*4), (64, N*4), (72, 0x3f800000), (80, 0), (88, 0)):   # the twelve-word descriptor of the executor (vop_gemm): A B C M N K lda ldb ldc alpha beta flags
        L += ['\tmovq\t#%d,r0' % v, '\tmovq\tr0,%d(sp)' % off]
    L += ['\tmovq\tsp,r6', '\tclr\tr7', '\tclr\tr8', '\tgemm.f\tr6,r7,r8', '\tadd\t#96,sp']
    L += emit_write('CC', M*N*4) + ['\tret']
    L += words('PA', pa) + words('PB', pb) + words('CC', [0]*(M*N))
    return L, b''.join(struct.pack('<f', C[i][j]) for i in range(M) for j in range(N))
def spmv(nnz, NR=256, XN=1024):
    r = lcg(); x = [(r() % 9) - 4 for _ in range(XN)]
    val = []; col = []; y = []
    for _ in range(NR):
        s = 0
        for _ in range(nnz):
            c = r() % XN; v = (r() % 7) - 3; col.append(c); val.append(v); s += v * x[c]
        y.append(s)
    L = list(CRT) + ['\t.text', 'main:', '\tlea\tVAL,r0', '\tlea\tCOL,r1', '\tlea\tXV,r2', '\tlea\tYV,r3', '\tmovq\t#%d,r4' % NR, '\tmovq\t#%d,r5' % (nnz*4)]
    # row loop: region [VAL+row*nnz*4, +nnz*4); the block moves r0 (val) and r1 (col); x[col] is a gather
    L += ['Lrow:', '\tlea\t(r0)(r5),r6', '\tclr\tr7', '\tvec\tr0,r6',
          '\tvld.f\tv0,(r0)+', '\tvld.l\tv1,(r1)+', '\tvshl.l\tv1,v1,#2', '\tvldx.f\tv2,(r2)[v1]', '\tvmul.f\tv0,v0,v2', '\tvacc.f\tr7,v0', '\tvend',
          '\tmovl\tr7,(r3)+', '\tdec\tr4', '\tcbgt\tr4,#0,Lrow']
    L += emit_write('YV', NR*4) + ['\tret']
    L += words('VAL', [f32(v) for v in val]) + words('COL', col) + words('XV', [f32(v) for v in x]) + words('YV', [0]*NR)
    return L, b''.join(struct.pack('<f', v) for v in y)
def lut256(n=4096):
    r = lcg(); t = [(i*37 + 11) & 255 for i in range(256)]; src = [r() & 255 for _ in range(n)]
    L = list(CRT) + ['\t.text', 'main:', '\tlea\tIN,r0', '\tlea\tOUT,r2', '\tlea\tTAB,r3', '\tlea\tIN+%d,r4' % n,
          '\tvec\tr0,r4', '\tvld.bu.l\tv0,(r0)+', '\tvldx.bu.l\tv1,(r3)[v0]', '\tvst.l.b\tv1,(r2)+', '\tvend']
    L += emit_write('OUT', n) + ['\tret']
    L += words('IN', src, '.byte') + words('TAB', t, '.byte') + words('OUT', [0]*n, '.byte')
    return L, bytes(t[x] for x in src)
if __name__ == '__main__':
    k = sys.argv[1]
    if k == 'gemm_tile': L, e = gemm_tile(int(sys.argv[2]))
    elif k == 'gemm_unit': L, e = gemm_unit()
    elif k == 'spmv': L, e = spmv(int(sys.argv[2]))
    elif k == 'lut256': L, e = lut256()
    else: raise SystemExit('unknown ' + k)
    sys.stdout.write('\n'.join(L) + '\n')
    open('/dev/stderr', 'w').write('EXPECT %s\n' % e.hex())

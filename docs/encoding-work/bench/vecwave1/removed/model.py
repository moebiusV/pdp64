#!/usr/bin/env python3
"""model.py: model 1 of docs/sim64.md (scalar instruction = 1 cycle, a vend = 1, a strip = max(compute, memory) + commit; one vector instruction = 1 compute cycle; memory
= bytes / port rounded up per load or store) applied to the programs of the REMOVED words, whose old simulator has no cycle model.  The three assumptions that the old
words need are parameters (the study's sensitivity): 
  TILE_ROWS  cycles the tile unit needs for one outer product (vtfmopa):  1 = a VLxVL array of multiply-adders (the design of the survey: 665,000 gates at binary32),
             VL = one row of VL multiply-adders a cycle (a unit as wide as the vector unit).
  GATHER_LANES  lanes of a gather served in one cycle: 1 = a lane a cycle (the survey: 'vldx, a lane a cycle'), 4 = four address ports.
  GEMM_ARRAY  multiply-adds a cycle of the whole-GEMM unit; its memory time is the traffic through the same port (A and B read once for every tile that uses them).
The model is validated in check_model() against the current sim64's own model 1 on a kernel that exists in both (q8dot vdacc: 652 cycles at strip 32, port 16)."""
import math, sys
def ceil(a, b): return -(-a // b)
def strip_cycles(compute, mem_bytes_list, port=16, commit=1):
    mem = sum(ceil(b, port) for b in mem_bytes_list)
    return max(compute, mem) + commit
def check_model():
    # q8dot vdacc, 4096 bytes, strip 32: 128 strips of (vld 32B, vld 32B, vdacc): compute 3, memory 2+2
    assert 11 + 1 + 128 * strip_cycles(3, [32, 32]) == 652
check_model()
def tile_gemm(M=16, N=16, K=64, strip=32, TILE_ROWS='one', port=16, scalar_per_call=8 + 3 + 12):
    VL = strip // 4
    ntiles = (M // VL) * (N // VL)
    outer = 1 if TILE_ROWS == 'one' else VL
    per_k = strip_cycles(2 + outer, [strip, strip], port)           # vld B row, vld A column, vtfmopa
    epi = VL * ceil(VL * 4, port) * 2 + VL * ceil(VL * 4, port) + 3  # vtld (VL rows), vtst (VL rows), vtadd; one cycle each instruction, rows go through the port
    call = scalar_per_call + 1 + K * per_k + epi                   # + the vend
    return ntiles * call, ntiles
def gemm_unit(M=16, N=16, K=64, strip=32, array=None, port=16, setup=37):
    VL = strip // 4
    array = array or VL * VL
    fma = M * N * K
    compute = ceil(fma, array)
    tiles = (M // VL) * (N // VL)
    traffic = tiles * (2 * VL * K * 4) + M * N * 4                  # every tile reads its A rows and B rows; C written once
    compulsory = (M * K + N * K) * 4 + M * N * 4
    return setup + max(compute, ceil(traffic, port)), setup + max(compute, ceil(compulsory, port)), compute, ceil(traffic, port), ceil(compulsory, port)
def spmv_gather(nr=256, nnz=16, strip=32, lanes=1, port=16, row_scalar=6):
    VL = strip // 4
    nstr, tail = divmod(nnz, VL)
    def sc(vl):
        gather = ceil(vl, lanes)
        compute = 4 + gather + ceil(vl, 4)                          # vld.f vld.l vshl vmul + vldx + vacc.f (one cycle per 4-lane chunk)
        mem = ceil(vl * 4, port) * 2 + ceil(vl, lanes)               # two stream loads, the gathered lanes
        return strip_cycles(compute, [], port) if mem <= compute else mem + 1
    row = row_scalar + 1 + nstr * sc(VL) + (sc(tail) if tail else 0)
    return nr * row
def lut_gather(n=4096, strip=32, lanes=1, port=16):
    VL = strip // 4                                                  # vld.bu.l widens bytes to 32-bit lanes: VL elements a strip
    gather = ceil(VL, lanes)
    compute = 3 + gather                                             # vld, vldx, vst
    mem = ceil(VL, port) + ceil(VL, lanes) + ceil(VL, port)
    return 12 + 1 + ceil(n, VL) * (max(compute, mem) + 1)
if __name__ == '__main__':
    print('tile_gemm  16x16x64 strip 32 (4 tiles), one-cycle outer product:', tile_gemm(TILE_ROWS='one'))
    print('tile_gemm  16x16x64 strip 32, row-a-cycle outer product        :', tile_gemm(TILE_ROWS='rows'))
    for st in (16, 32, 64):
        print('tile_gemm strip', st, tile_gemm(strip=st)[0], tile_gemm(strip=st, TILE_ROWS='rows')[0])
    print('gemm_unit  (with tile reloads, compulsory only, compute, traffic, compulsory):', gemm_unit())
    for nnz in (4, 16, 64):
        print('spmv gather nnz/row', nnz, 'lane/cycle', spmv_gather(nnz=nnz, lanes=1), '4 lanes/cycle', spmv_gather(nnz=nnz, lanes=4))
    print('lut256 gather', lut_gather(lanes=1), lut_gather(lanes=4))

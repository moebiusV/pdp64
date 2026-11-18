#!/usr/bin/env python3
"""lat-depth.py FLOW TOP FILE.json [FILE.ltp] -- the logic depth of the module TOP of a yosys `write_json` netlist (docs/encoding-work/vec-latency.md).

The longest path from an input or a flip-flop output to an output or a flip-flop input, in LEVELS.  A level is the unit of the study's flow:
  nand   a 2-input gate ($_NAND_ or $_NOT_): 1 each                                   (what `ltp` counts too)
  ecp5   a LUT4 (and LUT4-equivalent CCU2C input pin) 1; PFUMX / L6MUX21 0.5; a carry hop CIN->COUT 0.1, CIN->sum 0.5   (ASSUMED weights)
  xc7    a LUT1..6 1; MUXF7/F8 0.5; a CARRY4 CI->CO 0.1, CI->sum 0.5, S/DI->out 0.3                                      (ASSUMED weights)
`ltp` itself counts every cell, a carry cell (2 bits of an adder) as much as a LUT: this script weights the carry hops down because the
carry chain is not a LUT level in time.  A multiplier primitive (MULT18X18D, DSP48E1, MULT9X9D) is not a level: it is counted on the path (field dsp) and the path is chosen
by levels + 4 x dsp (the assumed worst-path weight of a DSP stage; its real latency is a pipeline parameter of the design).
Prints one line: levels dsp cells   (levels with one decimal; cells = the number of cells on the chosen path, what `ltp` would count).
"""
import json, sys
flow, top, jf = sys.argv[1:4]
d = json.load(open(jf)); m = d['modules'][top]
DSPW = 4.0
DSP = {'MULT18X18D', 'DSP48E1', 'MULT9X9D', 'ALU54B', 'MULT18X18', 'DSP48E'}
FFPAT = ('$_DFF', '$_SDFF', '$_ADFF', '$_DLATCH', '$_DFFE', 'TRELLIS_FF', 'FD', 'LD', 'DP16KD', 'RAMB', 'FIFO', 'SRL', 'DPR16X4_WR')
def is_ff(t): return t.startswith(FFPAT) and not t.startswith('FDRE_') or t in ('DP16KD', 'TRELLIS_FF') or t.startswith('$_DFF') or t.startswith('RAMB')
def weight(t, i, o):
    """the delay in levels of the arc input port i -> output port o of a cell of type t; None = not an arc (a sink pin)"""
    if flow == 'nand': return 1.0
    if t in DSP: return 0.0
    if t.startswith('LUT') or t.startswith('$lut'): return 1.0
    if t in ('PFUMX', 'L6MUX21', 'MUXF7', 'MUXF8', 'MUXF9'): return 0.5
    if t == 'CCU2C':
        if i == 'CIN': return 0.1 if o == 'COUT' else 0.5
        return 1.0
    if t == 'CARRY4':
        if i == 'CI' or i == 'CYINIT': return 0.1 if o.startswith('CO') else 0.5
        return 0.3
    if t in ('IBUF', 'OBUF', 'BUFG', 'IBUFG', 'OBUFT', 'INV', 'GND', 'VCC'): return 0.0
    if t.startswith('TRELLIS_DPR16X4') : return 1.0 if i.startswith('RAD') else None
    if t.startswith('RAM') and t.endswith(('M', 'S', 'D')) and not t.startswith('RAMB'): return 1.0 if i.startswith(('ADDR', 'A', 'DPRA')) else None
    return 1.0
drv = {}	# bit -> (cell, port)
cells = m['cells']
for cn, c in cells.items():
    for p, dr in c['port_directions'].items():
        if dr in ('output', 'inout'):
            for b in c['connections'][p]:
                if isinstance(b, int): drv[b] = (cn, p)
ffq = {cn for cn, c in cells.items() if is_ff(c['type'])}
sinks = []
for pn, p in m['ports'].items():
    if p['direction'] in ('output', 'inout'): sinks += [b for b in p['bits'] if isinstance(b, int)]
for cn in ffq:
    c = cells[cn]
    for p, dr in c['port_directions'].items():
        if dr == 'input': sinks += [b for b in c['connections'][p] if isinstance(b, int)]
memo = {}	# bit -> (levels, dsp, cells) the arrival at that net
sys.setrecursionlimit(1000000)
def arrive(b0):
    st = [b0]
    while st:
        b = st[-1]
        if b in memo: st.pop(); continue
        if b not in drv: memo[b] = (0.0, 0, 0); st.pop(); continue
        cn, op = drv[b]; c = cells[cn]; t = c['type']
        if cn in ffq: memo[b] = (0.0, 0, 0); st.pop(); continue
        ins = [(p, x) for p, dr in c['port_directions'].items() if dr == 'input' for x in c['connections'][p] if isinstance(x, int)]
        pend = [x for p, x in ins if x not in memo]
        if pend: st += pend; continue
        best = (0.0, 0, 0)
        for p, x in ins:
            w = weight(t, p, op)
            if w is None: continue
            a = memo[x]
            cand = (a[0] + w, a[1] + (1 if t in DSP else 0), a[2] + 1)
            if cand[0] + DSPW * cand[1] > best[0] + DSPW * best[1]: best = cand
        memo[b] = best; st.pop()
best = (0.0, 0, 0)
for b in sinks:
    arrive(b); a = memo[b]
    if a[0] + DSPW * a[1] > best[0] + DSPW * best[1]: best = a
print('%.1f %d %d' % best)

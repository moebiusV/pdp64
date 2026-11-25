#!/usr/bin/env python3
"""Print the table of results/syscall-bench.json.  usage: syscall_table.py results/syscall-bench.json"""
import json, sys
rows = json.load(open(sys.argv[1]))
print('per system call: instructions executed (sim64 -K -t, whole loop: user code, TRAP, handler, RTI) and cycles of the same body run as a function under the timing model (no TRAP / RTI cost)')
print('%-5s %-12s %-22s | %8s %6s %6s %6s | %8s %6s %6s %6s' % ('comp', 'case', 'registers left', 'lazy', '+clear', '+frame', '+reg', 'lazy cyc', '+clear', '+frame', '+reg'))
for r in rows:
    print('%-5s %-12s %-22s | %8.1f %6.1f %6.1f %6.1f | %8.1f %6.1f %6.1f %6.1f' % (r['comp'], r['case'], 'r' + ',r'.join(map(str, [x for x in r['dirty']])) if r['dirty'] else '-',
        r['lazy'], r['clear'] - r['lazy'], r['frame'] - r['lazy'], r['mask-reg'] - r['lazy'], r['ucyc_lazy'], r['ucyc_clear'] - r['ucyc_lazy'], r['ucyc_frame'] - r['ucyc_lazy'], r['ucyc_mask-reg'] - r['ucyc_lazy']))

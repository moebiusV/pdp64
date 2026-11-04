from m2 import *
def p2ok(mn,ops,k):
    """one-parcel (page 2) form available in the current ISA?"""
    n=len(ops)
    if mn in('pushm','popm'):
        m=int(ops[0][1:],0); return (m & ~0xff00)==0
    if k==['imm','reg']:
        v=int(ops[0][1:],0)
        if mn=='movq': return sg(v,4)
        if mn in('and','bis','xor'): return sg(v,4)
        if mn=='add':
            if ops[1]=='sp' and v>=8 and v%8==0 and v//8<256: return True
            return sg(v,4)
        if mn=='sub': return ops[1]=='sp' and v%8==0 and 0<=v//8<256
        if mn in('shl','shr','sar'): return 0<=v<16
        return False
    if mn in MOVS+('lea',) and sorted(k)==['base','reg']:
        st=k[0]=='reg'; m=base_re.match(ops[1] if st else ops[0]); d=int(m.group(1) or 0); r=m.group(2)
        if mn=='lea': return (not st) and r=='sp' and d%8==0 and 0<=d<=120
        if st and mn.startswith('movz'): return False
        if d==0: return not(st and mn.startswith('movz'))
        if r=='sp':
            if mn=='movq': return d%8==0 and ((not st and 0<d<=248) or (st and 0<d<=120))
            if mn=='movl': return d%4==0 and 0<d<=124
        if mn=='movq' and not st and d in(8,16,24,32): return True
        if mn=='movq' and st and d in(8,16): return True
        if mn=='movl' and not st and d in(4,8,12,16): return True
    return False
def cur_len(r,dist):
    mn,ops,k=r['mn'],r['ops'],r['k']; n=len(ops)
    if isbr(mn) and n==1:
        if dist is None: return 6
        p=dist//2; return 2 if sg(p,8) else 4 if sg(p,16) else 6
    if mn in('sob','btag','bntag'): return 4
    if mn.startswith('cb') and n==3:
        if dist is None: return 6
        p=dist//2
        if ops[1].startswith('#'):
            v=int(ops[1][1:],0)
            if sg(v,5) and sg(p,11): return 4
            return 6
        return 4 if sg(p,12) else 6
    if all(x=='reg' for x in k):
        if mn in BF6: return 6
        return 4 if mn in ESC4 else 2
    if mn in('nop','ret') or n==0: return 2
    if p2ok(mn,ops,k): return 2
    for i,o in enumerate(ops):
        kk=k[i]
        if kk=='imm':
            v=int(o[1:],0)
            if mn in('trap','spl'): return 2
            return 4 if sg(v,16) else 6
        if kk=='abs': return 4
        if kk=='pcrel':
            if r['pool']: return 4
            return 6 if dist is None else (4 if sg(dist,16) else 6)
        if kk=='base':
            d=int(base_re.match(o).group(1) or 0); return 4 if sg(d,12) else 6
        if kk=='index':
            d=int(index_re.match(o).group(1) or 0); return 4 if sg(d,6) else 6
        if kk in('postinc','predec'): return 4
    return 2

from load import *
import re
REGN={'sp':14,'fp':13}
def regn(s): return REGN[s] if s in REGN else int(s[1:])
def op_norm(o,k,dist,off,pool):
    if k=='reg': return ('R',regn(o))
    if k=='imm': return ('I',int(o[1:],0))
    if k=='abs':
        t=o[1:]
        try: return ('A',int(t,0))
        except: return ('A',None)
    if k=='base':
        m=base_re.match(o); return ('B',int(m.group(1) or 0),regn(m.group(2)))
    if k=='index':
        m=index_re.match(o); return ('X',int(m.group(1) or 0),regn(m.group(2)),regn(m.group(3)),int(m.group(4) or 1))
    if k=='postinc':
        m=postinc.match(o); return ('PI',regn(m.group(1)),int(m.group(2)) if m.group(2) else 0)
    if k=='predec':
        m=predec.match(o)
        if m.group(1): return ('PD',regn(m.group(1)),0)
        return ('PD',regn(m.group(2)),int(m.group(3)))
    # pcrel
    if pool: return ('PC',32000 if dist is None else dist,'pool')
    return ('PC',dist,'sym')
def inst_of(r,dist):
    ops=[op_norm(o,k,dist,r['off'],r['pool']) for o,k in zip(r['ops'],r['k'])]
    if r['mn'] in('pushm','popm','fx_popmret','popmret'): ops=[('I',ops[0][1]&0xFFFFFFFF)]
    return r['mn'],tuple(ops)

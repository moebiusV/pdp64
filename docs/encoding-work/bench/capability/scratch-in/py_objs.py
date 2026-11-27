import time
class N:
    def __init__(s,a,b): s.a=a; s.b=b; s.c=None
l=[N(i,str(i)) for i in range(300000)]
d={i:[i,i+1,str(i)] for i in range(200000)}
t=[(i,(i,i)) for i in range(200000)]
time.sleep(60)

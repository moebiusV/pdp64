from enc import *
MOV7=['movq','movl','movw','movb','movzl','movzw','movzb']
ST4=['movq','movl','movw','movb']
ALUS=['add','sub','bic','bis','xor','and','mul','mulh','shl','shr','sar','fadd','fsub','fmul','bit']
CMPS=['cmp','fcmp']
UMOV=['movub','movuw','movul','movuq']
SOPS=['clr','com','inc','dec','neg','tst','adc','sbc','asl','asr','push','pop']
LDM=MOV7+ALUS+['lea']+UMOV
STM=ST4+UMOV+['addm','subm','bicm','bism']
SOPM=SOPS+['jmp','call','jmpi','calli']
CONDS=['ne','eq','pl','mi','vc','vs','cc','cs','ge','lt','gt','le','hi','los']
BRS=['br']+['b'+c for c in CONDS]
CBS=['cb'+c for c in CONDS]
IMMS=['movq','add','sub','and','bis','xor','mul','bic']
SHIFTS=['shl','shr','sar','rol']
BESC2=['clz','ctz','clo','cto','popcnt','bswap','bswapw','bswapl','bitrev','utf8len','utf8dec','utf8enc']
R2_RARE=BESC2+['mval','abs','set','prober','probew','fdiv','fsqrt','fadd32','fsub32','fmul32','fdiv32','fsqrt32','fcmp32','fneg','fabs','fclass','fclass32','frint','frintz','frintm','frintp','frinta','fcvtdq','fcvtqd','fcvtds','fcvtsd','fcvtsl','fcvtls','fcvtdqu','fcvtqud','fsflags','fadd16','fsub16','fmul16','fdiv16','fsqrt16','fcmp16','fclass16','fcvtsh','fcvths','fcvtdh','fcvthd','fcvthl','fcvtlh',
   'aesim','sha256sig0','sha256sig1','sha256sum0','sha256sum1','sha512sig0','sha512sig1','sha512sum0','sha512sum1','addv','subv','mulv']
R3_RARE=['ror','xnorpop','clmull','clmulh','mcpy','mmov','mset','mcmp','mscn','mscnn','div','divu','mod','modu','mulhu','min','minu','max','maxu','fcopysign','fmin','fmax',
   'maskeqz','masknez','aeses','aesesm','aesds','aesdsm','aesks2','mfsr_','xadd','xadddb','swap','swapdb','xand','xanddb','xor_','xor_db','xxor','xxordb','xmax','xmaxdb','xmin','xmindb','xmaxu','xmaxudb','xminu','xminudb','ll','sc','msha256','msha512']
R4_RARE=['fmadd','fmsub','fnmadd','fnmsub','fmadd32','fmsub32','fnmadd32','fnmsub32','fmadd16','fmsub16','fnmadd16','fnmsub16','bsel','cas','casdb','maesctr']
RRI_RARE=['rori','rori32','rol','aesks1']
BF=['dshr','extb','extzb','insb']
SYS0=['nop','rti','rtt','ret','halt','bpt','fence','wfe','sev','lpad','tlbia','tlbsync','icinva','pushx','popx','isync']+['trapcc.%s'%c for c in CONDS]+['syspg%d'%i for i in range(6)]
SYSR=['mtps','mfps','tlbi','mtasid','mfasid','mtdp','mfdp','mtdmw','mfcpuid','icinv']
SYSI=['spl','trap','trapl','hint']
def mk(R,H3,H4=None,hot16=False):
    """returns (forced, cands).  R full register spec; H3 3-bit hot map; H4 4-bit hot map (32-reg variant only)"""
    forced=[]; C=[]
    SPR=SK(("R",14))
    def F(lst,name,n,mns,specs,xbits=0): lst.append(Form(name,n,mns,specs,xbits=xbits))
    # ---------------- rare, generic (forced)
    F(forced,'SYS0',1,SYS0,[],xbits=0)
    F(forced,'SYSR',1,SYSR,[R]); 
    F(forced,'SYSI',1,SYSI,[SI(8,False)])      # trap #0-255 in one parcel (merges TRAP/TRAPL)
    F(forced,'MFSR',2,['mfsr'],[R,SI(12,False)])
    F(forced,'MTSR',2,['mtsr'],[SI(12,False),R])
    def rare(name,mns,specs):
        ob=sum(p[1] for sp in specs for p in sp.parts); need=math.ceil(math.log2(len(mns)))+1
        if len(mns)==16: need=4
        for n in (2,3):
            Lmax=16*n-ob-need
            if Lmax>=6:
                L=min(12,Lmax); break
        F(forced,name,n,mns,specs,xbits=16*n-ob-L)
    rare('R2',R2_RARE,[R,R]); rare('R3',R3_RARE,[R,R,R]); rare('R4',R4_RARE,[R,R,R,R]); rare('RRI',RRI_RARE,[R,SI(6,False),R])
    F(forced,'BFx',3,['dshr'],[R,R,SI(6,False),R],xbits=20)
    F(forced,'BFy',3,['extb','extzb','insb'],[R,SI(6,False),SI(6,False),R],xbits=18)
    F(forced,'MOVQL',5,['movql'],[SI(64,True),R])
    # user-qualified (.u) and deferred-load (.d, .ud) memory forms: base-register and index modes only (other modes: assembler uses a base register)
    ULD=[m+s for s in('.u','.d','.ud') for m in MOV7]; UST=[m+'.u' for m in ST4]
    forced.append(Form('LDU.B28',3,ULD,[SB(R,28,True,1),R])); forced.append(Form('STU.B28',3,UST,[R,SB(R,28,True,1)]))
    forced.append(Form('LDU.B12',2,ULD,[SB(R,12,True,1),R])); forced.append(Form('STU.B12',2,UST,[R,SB(R,12,True,1)]))
    forced.append(Form('LDU.X6',2,ULD,[SX(R,R,6),R])); forced.append(Form('STU.X6',2,UST,[R,SX(R,R,6)]))
    # ---------------- fallbacks
    mems_ld=lambda f,d3: None
    def memfam(lst,tag,mns,pat,n,dw):
        """pat 'ld': (M,R); 'st': (R,M); 'm': (M)  ; returns forms for modes B,X,PI,PD,PC,A,I"""
        pass
    def fam(lst,tag,mns,pat,modes,n,dwd):
        for mode in modes:
            dw=dwd[mode] if isinstance(dwd,dict) else dwd
            if mode=='B': M=SB(R,dw,True,1)
            elif mode=='X': M=SX(R,R,dw,True)
            elif mode=='PI': M=SP('PI',R,dw)
            elif mode=='PD': M=SP('PD',R,dw)
            elif mode=='PC': M=SPC(dw)
            elif mode=='A': M=SA(dw)
            elif mode=='I': M=SI(dw,True)
            elif mode=='D': M=SB(SK(('R',16)),dw,True,1)
            if pat=='ld': sp=[M,R]
            elif pat=='st': sp=[R,M]
            elif pat=='cm': sp=[R,M]
            else: sp=[M]
            lst.append(Form('%s.%s%d'%(tag,mode,dw),2 if mode in('PI','PD') and n==3 else n,mns,sp))
    DWF={'B':28,'X':22,'PI':12,'PD':12,'PC':32,'A':32,'I':32,'D':28}
    fam(forced,'LDF',LDM,'ld',['B','X','PI','PD','PC','A'],3,DWF)
    fam(forced,'LDFI',ALUS+MOV7,'ld',['I'],3,DWF)
    fam(forced,'STF',STM,'st',['B','X','PI','PD','PC','A'],3,DWF)
    fam(forced,'CMF',CMPS,'cm',['B','X','PI','PD','PC','A','I'],3,DWF)
    fam(forced,'SOF',SOPM,'m',['B','X','PI','PD','PC','A'],3,DWF)
    fam(forced,'DPF',LDM,'ld',['D'],3,DWF)
    forced.append(Form('BRF',3,BRS,[SPC(32,2)]))
    forced.append(Form('CALLF',3,['call','jmp'],[SPC(32,2)]))
    forced.append(Form('PUSHMF',3,['pushm','popm'],[SI(32,False)]))
    forced.append(Form('SOPR',1,SOPS+['jmp','call'],[R]))
    forced.append(Form('PUSHI3',3,['push'],[SI(32,True)])); forced.append(Form('PUSHI2',2,['push'],[SI(16,True)]))
    forced.append(Form('JTAG3',3,['jtag'],[SX(R,R,22)])); forced.append(Form('JTAG2',2,['jtag'],[SX(R,R,6)]))
    if H4 is not None:
        forced.append(Form('RRF',1,MOV7+ALUS+CMPS,[H4,H4]))
        forced.append(Form('RRF5',2,MOV7+ALUS+CMPS,[R,R],xbits=6))
    else: forced.append(Form('RRF',1,MOV7+ALUS+CMPS,[R,R]))
    forced.append(Form('SOB',2,['sob'],[R,SPC(16,2)],xbits=0))
    forced.append(Form('TAG',2,['btag','bntag'],[R,SI(3,False),SPC(13,2)]))
    forced.append(Form('SPADJF',3,['add','sub'],[SI(32,True),SK(('R',14))]))
    return forced,C


LD_A=['movq','movl','movzb','lea']; LD_B=['movw','movb','movzl','movzw']; LD_C=['add','sub','and','bis','xor']; LD_D=['bic','mul','mulh','shl','shr','sar','fadd','fsub','fmul','bit']
ST_A=['movq','movl']; ST_B=['movw','movb']
CM_A=['cmp']; CM_B=['fcmp']
SO_A=['clr','inc','dec','tst','push','pop']; SO_B=['com','neg','adc','sbc','asl','asr']; SO_X=['jmp','call','jmpi','calli']
CB_A=['cbeq','cbne']; CB_B=['cblt','cbge','cbgt','cble']; CB_C=['cbcs','cbcc','cbhi','cblos']; CB_D=['cbpl','cbmi','cbvc','cbvs']
BR_A=['br']; BR_B=['beq','bne']; BR_C=[m for m in BRS if m not in ('br','beq','bne')]
RRC=[('a',['movq','movl','movzl','movzb']),('b',['add','sub','cmp','and','bis','xor']),('c',['movw','movb','movzw','mul','mulh','shl','shr','sar','bic','bit','fadd','fsub','fmul','fcmp'])]
LDC=[('a',LD_A),('b',LD_B),('c',LD_C),('d',LD_D)]
STC=[('a',ST_A),('b',ST_B)]
CMC=[('a',CM_A),('b',CM_B)]
SOC=[('a',SO_A),('b',SO_B),('x',SO_X)]
CBC=[('a',CB_A),('b',CB_B),('c',CB_C),('d',CB_D)]
BRC=[('a',BR_A),('b',BR_B),('c',BR_C)]
IMC=[('a',['movq']),('b',['add','sub','and']),('c',['bis','xor','mul','bic'])]
def cands(R,H3,H4=None,opts=None):
    """optional (size-reducing) forms.  Each is a (form, mnemonic class); the solver picks whole classes by bytes saved per unit of code space"""
    o=dict(ldh=True,sp1=True,imm1=True,cbz=True,cbi=True,idx=True,pcrel=True,h4mem=True)
    if opts: o.update(opts)
    C=[]; SPR=SK(('R',14)); Z=SK(('I',0))
    W=o.get('W')
    Fw2=(lambda t:[x for x in t if x in o['W2']]) if o.get('W2') else (lambda t:t)
    Fw=(lambda t:[x for x in t if x in W]) if W else (lambda t:t)
    regv=[('',R,R)]
    if H4 is not None: regv+=[('h4',H4,H4),('m',H4,R),('n',R,H4)]
    def add(name,n,classes,specs):
        for tg,mns in classes:
            f=Form(name+'/'+tg,n,mns,specs)
            if 1<=f.Lleaf<=16: C.append(f)
    ALLC=[('all',None)]
    for tg,a,b in regv:
        add('RR'+tg,1,RRC,[a,b])
        add('SOP'+tg,1,[('a',SOPS)],[a])
        add('LD0'+tg,1,[('a',LD_A),('b',LD_B),('c',LD_C)],[SB(a,0),b])
        add('ST0'+tg,1,STC,[a,SB(b,0)])
    for w in (6,7,8,9):
        add('BR1_%d'%w,1,BRC,[SPC(w,2)])
    if o['ldh']:
        for dw in (1,2,3):
            for tg,a,b in (('RH',R,H3),('HR',H3,R),('HH',H3,H3)):
                add('LDH%s%d'%(tg,dw),1,LDC[:3],[SB(a,dw,False,'sz'),b])
                add('STH%s%d'%(tg,dw),1,STC,[a,SB(b,dw,False,'sz')])
    if o['sp1']:
        for dw in (4,5,6,7):
            for tg,r in (('',R),('h',H4)) if H4 is not None else (('',R),):
                add('LDSP%s%d'%(tg,dw),1,LDC[:3],[SB(SPR,dw,False,'sz'),r])
                add('STSP%s%d'%(tg,dw),1,STC,[r,SB(SPR,dw,False,'sz')])
                add('LEASP%s%d'%(tg,dw),1,[('a',['lea'])],[SB(SPR,dw,False,8),r])
    if o['imm1']:
        for w in (3,4,5,6,7,8):
            for tg,a,b in regv:
                add('IMM%s%d'%(tg,w),1,IMC,[SI(w,True),b])
                add('CMPI%s%d'%(tg,w),1,[('a',['cmp'])],[b,SI(w,True)])
                add('SHI%s%d'%(tg,w),1,[('a',SHIFTS)],[SI(w,False),b])
        for w in (6,8,10):
            add('SPADJ%d'%w,1,[('a',['add','sub'])],[SI(w,False,8),SPR])
        add('PUSHM8',1,[('a',['pushm','popm'])],[SI(8,False,256)])
        if H4 is not None:
            add('PUSHM8h',1,[('a',['pushm','popm'])],[SI(8,False,1<<24)])
            add('PUSHM16',2,[('a',['pushm','popm'])],[SI(16,False,1<<16)])
            add('PUSHM16b',2,[('a',['pushm','popm'])],[SI(16,False,1<<8)])
        add('PUSHM16a',2,[('a',['pushm','popm'])],[SI(16,False,1)])
        add('PUSHM24',2,[('a',['pushm','popm'])],[SI(24,False,1<<8)])
    if o['cbz']:
        for w in (4,5,6,7,8):
            add('CBZ1_%d'%w,1,CBC,[R,Z,SPC(w,2)])
    rvs=[('',R)]+([('H',H4)] if H4 is not None and o['h4mem'] else [])
    for tgv,Rv in rvs:
        def add2(name,n,classes,specs): add(name+tgv,n,classes,specs)
        for dw in Fw((4,6,8,10,12,14,16,18,20,22)):
            for sg_ in (True,False):
                t='s' if sg_ else 'u'
                add2('LDB%s%d'%(t,dw),2,LDC,[SB(Rv,dw,sg_,'sz'),R])
                add2('STB%s%d'%(t,dw),2,STC,[Rv,SB(Rv,dw,sg_,'sz')])
                add2('CMB%s%d'%(t,dw),2,CMC,[Rv,SB(Rv,dw,sg_,'sz')])
                add2('SOB%s%d'%(t,dw),2,SOC,[SB(Rv,dw,sg_,'sz')])
            add2('LDBx%d'%dw,2,LDC,[SB(Rv,dw,True,1),R])
            add2('STBx%d'%dw,2,STC,[R,SB(Rv,dw,True,1)])
        for dw in Fw((6,8,10,12,14,16,18,20,22,24)):
            add2('LDS%d'%dw,2,LDC,[SB(SPR,dw,False,'sz'),Rv])
            add2('STS%d'%dw,2,STC,[Rv,SB(SPR,dw,False,'sz')])
            add2('CMS%d'%dw,2,CMC,[Rv,SB(SPR,dw,False,'sz')])
            add2('LEAS%d'%dw,2,[('a',['lea'])],[SB(SPR,dw,False,8),Rv])
            add2('LEASx%d'%dw,2,[('a',['lea'])],[SB(SPR,dw,True,1),Rv])
            add2('SOS%d'%dw,2,SOC,[SB(SPR,dw,False,'sz')])
        if o['idx']:
            for dw in Fw((0,2,4,6,8,10,12,14,16)):
                add2('LDX%d'%dw,2,LDC,[SX(Rv,Rv,dw),R])
                add2('STX%d'%dw,2,STC,[R,SX(Rv,Rv,dw)])
                add2('CMX%d'%dw,2,CMC,[R,SX(Rv,Rv,dw)])
                add2('SOX%d'%dw,2,SOC,[SX(Rv,Rv,dw)])
        for dw in Fw((4,8,12)):
            add2('LDPI%d'%dw,2,LDC,[SP('PI',Rv,dw),R]); add2('LDPD%d'%dw,2,LDC,[SP('PD',Rv,dw),R])
            add2('STPI%d'%dw,2,STC,[R,SP('PI',Rv,dw)]); add2('STPD%d'%dw,2,STC,[R,SP('PD',Rv,dw)])
        if o['pcrel']:
            for dw in Fw((12,14,16,18,20,22,24,26,28)):
                add2('LDPC%d'%dw,2,LDC,[SPC(dw),Rv])
                add2('STPC%d'%dw,2,STC,[Rv,SPC(dw)])
                add2('CMPC%d'%dw,2,CMC,[Rv,SPC(dw)])
                add2('SOPC%d'%dw,2,SOC,[SPC(dw)])
                add2('LDA%d'%dw,2,LDC,[SA(dw),Rv])
                add2('STA%d'%dw,2,STC,[Rv,SA(dw)])
        for dw in Fw((6,8,10,12,14,16,18,20,22,24,26,28)):
            add2('LDI%d'%dw,2,IMC+[('d',['shl','shr','sar','mul','bic','movb','bit'])],[SI(dw,True),Rv])
            add2('CMI%d'%dw,2,CMC,[Rv,SI(dw,True)])
            add2('BR2_%d'%dw,2,BRC,[SPC(dw,2)])
            add2('CALL2_%d'%dw,2,[('c',['call']),('j',['jmp'])],[SPC(dw,2)])
            add2('SPADJ2_%d'%dw,2,[('a',['add','sub'])],[SI(dw,True),SPR])
        for dw in Fw((8,10,12,14,16,18,20,22,24)):
            add2('CBR%d'%dw,2,CBC,[Rv,Rv,SPC(dw,2)])
            if o['cbz']: add2('CBZ2_%d'%dw,2,CBC,[Rv,Z,SPC(dw,2)])
        if o['cbi']:
            for iw in Fw2((3,4,5,6,8,10,12,16)):
                for dw in Fw((8,10,12,14,16,18,20)):
                    add2('CBI%d_%d'%(iw,dw),2,CBC,[Rv,SI(iw,True),SPC(dw,2)])
    return C

def fused_forms(R,H3,which):
    out=[]
    if 'movcall' in which:
        out.append(Form('FX.MOVCALL3',3,['movcall'],[R,R,SPC(32,2)]))
        out.append(Form('FX.MOVCALL2',2,['movcall'],[R,R,SPC(16,2)]))
    if 'popmret' in which:
        out.append(Form('FX.POPMRET',1,['popmret'],[SI(8,False,256)]))
    if 'popret' in which:
        out.append(Form('FX.POPRET',1,['popret'],[R]))
    if 'mov2' in which:
        out.append(Form('FX.MOV2',1,['mov2'],[H3,H3,H3,H3]))
    return out

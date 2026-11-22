# Builds ../head.svg from the traced contours. Run from this folder: uv run --with numpy python build_head.py
import json,numpy as np,math
D=json.load(open('contours.json'));H=json.load(open('highlights.json'))
def seg(c,a,b,src=D):
    "points of contour c from index a to b (either direction, wraps when needed via '|w')"
    p=src[c][:-1] if src[c][0]==src[c][-1] else src[c]
    n=len(p)
    if a<=b: return [p[i%n] for i in range(a,b+1)]
    return [p[i%n] for i in range(a,b-1,-1)]
def wrap(c,a,b):
    p=D[c][:-1];n=len(p);return [p[i%n] for i in range(a,b+n+1)]
# ---- Schneider fit
def bez(c,t):
    t=np.asarray(t)[:,None];return (1-t)**3*c[0]+3*(1-t)**2*t*c[1]+3*(1-t)*t*t*c[2]+t**3*c[3]
def norm(v): l=np.hypot(*v);return v/l if l>1e-9 else v
def chord(p):
    d=np.r_[0,np.cumsum(np.hypot(*np.diff(p,axis=0).T))];return d/d[-1]
def gen(p,u,t1,t2):
    b0,b1,b2,b3=(1-u)**3,3*u*(1-u)**2,3*u*u*(1-u),u**3
    A1=t1*b1[:,None];A2=t2*b2[:,None]
    C=np.array([[np.sum(A1*A1),np.sum(A1*A2)],[np.sum(A1*A2),np.sum(A2*A2)]])
    r=p-(p[0]*(b0+b1)[:,None]+p[-1]*(b2+b3)[:,None])
    X=np.array([np.sum(A1*r),np.sum(A2*r)]);L=np.hypot(*(p[-1]-p[0]))
    d=np.linalg.det(C)
    a=np.linalg.solve(C,X) if abs(d)>1e-9 else np.array([L/3,L/3])
    if a[0]<L*1e-2 or a[1]<L*1e-2 or max(a)>3*L: a=np.array([L/3,L/3])
    return np.array([p[0],p[0]+t1*a[0],p[-1]+t2*a[1],p[-1]])
def rep(c,p,u):
    d1=3*(c[1:]-c[:-1]);d2=2*(d1[1:]-d1[:-1]);t=u[:,None]
    q=bez(c,u)-p;q1=(1-t)**2*d1[0]+2*(1-t)*t*d1[1]+t*t*d1[2];q2=(1-t)*d2[0]+t*d2[1]
    den=np.sum(q1*q1,1)+np.sum(q*q2,1);den[abs(den)<1e-9]=1
    return np.clip(u-np.sum(q*q1,1)/den,0,1)
def tan(p,k=4): k=min(k,len(p)-1);return norm(p[k]-p[0])
def fit(p,t1,t2,tol):
    if len(p)<=3: L=np.hypot(*(p[-1]-p[0]))/3;return [np.array([p[0],p[0]+t1*L,p[-1]+t2*L,p[-1]])]
    u=chord(p)
    for _ in range(12):
        c=gen(p,u,t1,t2);e=np.hypot(*(bez(c,u)-p).T);k=int(e.argmax())
        if e[k]<tol: return [c]
        u=rep(c,p,u)
    k=min(max(k,2),len(p)-3) if len(p)>5 else len(p)//2
    w=min(4,k,len(p)-1-k);tc=norm(p[k-w]-p[k+w])
    return fit(p[:k+1],t1,tc,tol)+fit(p[k:],-tc,t2,tol)
def corners(p,w=5,ang=52):
    n=len(p);a=np.zeros(n)
    for i in range(w,n-w):
        v1=p[i]-p[i-w];v2=p[i+w]-p[i];a[i]=abs(math.degrees(math.atan2(v1[0]*v2[1]-v1[1]*v2[0],v1@v2)))
    return [i for i in range(w,n-w) if a[i]>ang and a[i]==a[max(0,i-w):i+w+1].max()]
def curve(pts,tol=1.0,ang=52):
    p=[pts[0]]
    for q in pts[1:]:
        if math.dist(q,p[-1])>.05:p.append(q)
    p=np.array(p,float)
    if len(p)<=4: return [np.array([a,a+(b-a)/3,b-(b-a)/3,b]) for a,b in zip(p[:-1],p[1:])]
    if len(p)>14:
        s=p.copy()
        for _ in range(2): s[1:-1]=.25*s[:-2]+.5*s[1:-1]+.25*s[2:]
        p=s
    cs=[0]+[c for c in corners(p,ang=ang) if 4<c<len(p)-5]+[len(p)-1];out=[]
    for a,b in zip(cs[:-1],cs[1:]):
        q=p[a:b+1];out+=fit(q,tan(q),tan(q[::-1]),tol)
    return out
def closed_contour(pts,tol=1.0,ang=52):
    p=pts[:-1] if tuple(pts[0])==tuple(pts[-1]) else pts
    a=np.array(p);w=5;n=len(a)
    v1=a-np.roll(a,w,0);v2=np.roll(a,-w,0)-a
    t=abs(np.arctan2(v1[:,0]*v2[:,1]-v1[:,1]*v2[:,0],(v1*v2).sum(1)));k=int(t.argmax())
    if math.degrees(t[k])>ang:
        r=[p[(k+i)%n] for i in range(n+1)];return curve(r,tol,ang)
    k=int(a[:,0].argmin());r=np.array([p[(k+i)%n] for i in range(n+1)],float)
    tc=norm(r[4]-r[-5]);return fit(r,tc,-tc,tol)
def join(*parts,tol=1.0,ang=52):
    "parts: traced polylines (lists >4 pts) fitted; ('C',c1,c2,end) or ('L',end) hand joins"
    out=[];cur=None;first=None
    for q in parts:
        if isinstance(q[0],str):
            cur=np.array(cur,float)
            if q[0]=='L': e=np.array(q[1],float);out.append(np.array([cur,cur+(e-cur)/3,e-(e-cur)/3,e]))
            else: out.append(np.array([cur,q[1],q[2],q[3]],float))
            cur=out[-1][3]
        else:
            s=curve(q,tol,ang)
            if cur is not None and math.dist(cur,s[0][0])>.05: a=np.array(cur);b=s[0][0];out.append(np.array([a,a+(b-a)/3,b-(b-a)/3,b]))
            out+=s;cur=s[-1][3]
        if first is None: first=out[0][0]
    if math.dist(cur,first)>.05:
        a=np.array(cur);out.append(np.array([a,a+(first-a)/3,first-(first-a)/3,first]))
    return out
# smooth closed spline through hand points (Catmull-Rom)
def spline(pts,k=1/6,closed=True):
    P=np.array(pts,float);n=len(P);o=[]
    for i in range(n if closed else n-1):
        g=lambda j:P[j%n] if closed else P[min(max(j,0),n-1)]
        a,b,c,d=g(i-1),g(i),g(i+1),g(i+2);o.append(np.array([b,b+(c-a)*k,c-(d-b)*k,c]))
    return o
def streak(x0,y0,x1,y1,w):
    a=np.array([x0,y0]);b=np.array([x1,y1]);n=norm(np.array([-(b-a)[1],(b-a)[0]]))*w;m=a*.55+b*.45
    return [np.array([a,a*.8+b*.2+n*.9,m+n*.6,b]),np.array([b,m-n*.6,a*.8+b*.2-n*.9,a])]
G=lambda px,py:(290+(px-46.9)/2.34375,40+py/2.34375)
INK='#1f1f1f';HI='#3b3b3b';W='#ffffff'
parts=[]  # (group,name,[subpaths],style)
def add(g,n,subs,**st): parts.append((g,n,subs,st))
# hair_back: plain skull mass, inset from silhouette, behind everything
add('hair_back','skull',[spline([(385,250),(430,165),(530,135),(640,130),(740,180),(800,240),(815,340),(780,400),(600,440),(440,420),(380,350)])],fill=INK)
# nape flicks, behind face
add('nape_left','flick',[join(seg(0,3262,3362),('C',(500,560),(500,470),(452,470)))],fill=INK)
add('nape_right','flick',[join(seg(0,1153,1330),('C',(800,455),(740,455),(735,520)),('C',(738,548),(750,556),seg(0,1153,1154)[0]))],fill=INK)
# ears: outline + inner, extended under face
add('ear_left','outline',[join(seg(0,3110,3285),('C',(470,520),(475,420),(440,400)),('C',(415,390),(385,415),seg(0,3110,3111)[0]))],fill=INK)
add('ear_left','inner',[join(seg(13,0,180),('C',(425,405),(470,410),(470,470)),('C',(472,515),(465,523),seg(13,0,1)[0]))],fill=W)
add('ear_right','outline',[join(seg(0,1318,1460),('C',(838,375),(800,360),(765,372)),('C',(740,385),(742,500),seg(0,1318,1319)[0]))],fill=INK)
add('ear_right','inner',[join(seg(11,105,281),('C',(748,478),(745,380),seg(11,105,106)[0]))],fill=W)
# face skin, hidden edges run under hair / sideburns / beard
add('face','skin',[spline([(446,300),(470,220),(540,190),(640,195),(735,240),(762,300),(772,380),(772,470),(755,540),(715,600),(640,635),(570,625),(500,570),(455,500),(438,420)])],fill=W)
# beard incl sideburns
jawL=seg(0,3352,3448);jawM=seg(18,380,694);jawR=seg(0,1118,1152)
s13=seg(13,185,296);s11=seg(11,0,96)
add('beard','shape',[join(s13,('C',(458,545),(478,562),jawL[0]),jawL,('C',(514,616),(521,621),jawM[0]),jawM,('C',(743,586),(747,581),jawR[0]),jawR,('C',(780,545),(778,520),s11[0]),s11,('C',(778,368),(775,350),(764,345)),
   ('L',seg(7,1118,1119)[0]),seg(7,1118,1626),seg(7,0,470),('C',(433,398),(424,404),s13[0]),tol=.9)],fill=INK)
for i,s in enumerate([(500,1190,592,1325,13),(625,1285,668,1378,8),(698,1335,732,1405,8),(768,1355,812,1415,10),(925,1335,868,1402,11),(1035,1222,1000,1318,11),(1112,1155,1080,1245,10),(1150,1085,1138,1165,7)]):
    a=G(*s[:2]);b=G(*s[2:4]);add('beard',f'streak{i+1}',[streak(*a,*b,s[4]/2.34)],fill=HI)
add('chin_patch','shape',[closed_contour(D[17])],fill=INK)
# mouth: single stroked outline (centre line between traced outer and inner edges)
B=lambda *q:np.array(q,float)
add('mouth','line',[[B((556.5,525),(594,523.5),(644,516.5),(680,506.5)),B((680,506.5),(674,534),(644,552.8),(611,552.8)),B((611,552.8),(588,552.8),(568,543),(556.5,525))]],fill=W,stroke=INK,sw=8)
add('nose','left',[[np.array([(576.5,467.5),(580,472.5),(587,475),(594,479.5)],float)]],fill='none',stroke=INK,sw=6.4)
add('nose','right',[[np.array([(630,466.5),(624,466.5),(619.5,469.5),(618.5,474)],float)]],fill='none',stroke=INK,sw=6.4)
p14=D[14][:-1]
add('mustache','shape',[join(seg(14,0,424),('C',(611,478),(602,478),seg(14,577,578)[0]),seg(14,577,len(p14)-1),tol=.9)],fill=INK)
add('eye_left','pupil',[closed_contour(D[10])],fill=INK)
add('eye_right','pupil',[closed_contour(D[8])],fill=INK)
add('brow_left','shape',[closed_contour(D[5])],fill=INK)
add('brow_right','shape',[closed_contour(D[4])],fill=INK)
gt=seg(2,802,1186);gb=seg(7,496,1100)
add('glasses','frame',[join(gt,('C',(428,383),(424,388),(424,395)),('C',(426,402),(434,399),gb[0]),gb,('C',(757,351),(766,350),(772,347)),('C',(774,340),(768,335),gt[0])),closed_contour(D[9]),closed_contour(D[6])],fill=INK)
add('glasses','arm_left',[[B((434,391),(421,393),(409,395),(394,397))]],fill='none',stroke=INK,sw=17)
add('glasses','arm_right',[[B((764,342),(777,340),(788,338),(806,336))]],fill='none',stroke=INK,sw=13)
# hair front
h2=seg(2,24,799)
hf=join(seg(0,1452,3122),('C',(384,456),(388,454),seg(13,127,128)[0]),seg(13,127,176),('C',(428,432),(434,428),(437,418)),('C',(436,405),(434,395),(434,380)),('L',h2[0]),h2,('C',(757,340),(764,345),(768,352)),('C',(773,365),(777,372),seg(11,101,102)[0]),seg(11,101,150),('C',(824,393),(830,396),seg(0,1452,1453)[0]),tol=1.0)
add('hair_front','shape',[hf]+[closed_contour(D[i],.7) for i in (1,3,12)],fill=INK)
for i in (1,2,3,4,5,6,7,10,11): add('hair_front',f'highlight_{i}',[closed_contour(H[i],1.0)],fill=HI)
add('hair_front','highlight_12',[[B((788,319),(795,352),(822,372),(861,356)),B((861,356),(838,352),(806,346),(788,319))]],fill=HI)
add('hair_front','highlight_13',[[B((347,371),(346,390),(356,404),(367,408)),B((367,408),(364,390),(358,386),(347,371))]],fill=HI)
# ---- output
PIV=(628,640);A=math.radians(8.45);c,s=math.cos(A),math.sin(A)
R=lambda q:(PIV[0]+(q[0]-PIV[0])*c-(q[1]-PIV[1])*s,PIV[1]+(q[0]-PIV[0])*s+(q[1]-PIV[1])*c)
X=lambda a,b:a[0]*b[1]-a[1]*b[0]
def dstr(subs,rot,closed):
    o=''
    for sub in subs:
        f=lambda q:tuple(map(float,(R if rot else tuple)(q)))
        o+='M%.1f %.1f'%f(sub[0][0])
        for b in sub:
            if abs(X(b[3]-b[0],b[1]-b[0]))<.3 and abs(X(b[3]-b[0],b[2]-b[0]))<.3 : o+='L%.1f %.1f'%f(b[3])
            else:o+='C'+' '.join('%.1f %.1f'%f(q) for q in b[1:])
        if closed:o+='Z'
    return o
def svg(rot,vb,only=None):
    o=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"><g id="head">';g0=None
    for g,n,subs,st in parts:
        if only and g!=only: continue
        if g!=g0:
            if g0:o+='</g>'
            o+=f'\n<g id="{g}">';g0=g
        o+=f'\n<path id="{g}__{n}" fill="{st["fill"]}" fill-rule="evenodd"'
        if 'stroke' in st:o+=f' stroke="{st["stroke"]}" stroke-width="{st["sw"]}" stroke-linejoin="round" stroke-linecap="round"'
        o+=f' d="{dstr(subs,rot,st["fill"]!="none")}"/>'
    return o+'</g></g></svg>'
VB='270 20 700 680'
open('../head.svg','w').write(svg(1,VB))
groups=list(dict.fromkeys(p[0] for p in parts))
tot=0
for g in groups:
    k=sum(len(x) for p in parts if p[0]==g for x in p[2]);tot+=k;print(g,k,end='; ')
print('\nTOTAL curve segments',tot,'groups',len(groups))
for g,n,subs,st in parts:
    for sub in subs:
        for b in sub:
            if b.max()>900 or b.min()<0: print('WILD',g,n,b.round().tolist())

import math
def squircle(x0,y0,size,n=5.0,N=360):
    c=size/2; pts=[]
    for i in range(N):
        t=2*math.pi*i/N; ct,st=math.cos(t),math.sin(t)
        x=abs(ct)**(2/n)*(1 if ct>=0 else -1); y=abs(st)**(2/n)*(1 if st>=0 else -1)
        pts.append((x0+c+c*x,y0+c+c*y))
    return 'M'+' L'.join(f'{a:.2f} {b:.2f}' for a,b in pts)+' Z'
T=squircle(100,100,824)
HEAD='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>'
COMMON=f'''<filter id="ts" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#000" flood-opacity=".30"/></filter>
<filter id="sh" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="22"/></filter>
<filter id="sh2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
<clipPath id="clip"><path d="{T}"/></clipPath>'''
END=f'<path d="{T}" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="3"/></svg>'

def phone(x,y,w,h,frame,screen,rot=0,extra=''):
    r=w*0.2
    return f'''<g transform="rotate({rot} {x+w/2} {y+h/2})">
<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{frame}"/>
<rect x="{x+w*0.045}" y="{y+w*0.045}" width="{w*0.91}" height="{h-w*0.09}" rx="{r*0.82}" fill="#0C0C12"/>
<rect x="{x+w*0.075}" y="{y+w*0.075}" width="{w*0.85}" height="{h-w*0.15}" rx="{r*0.7}" fill="{screen}"/>
<rect x="{x+w*0.36}" y="{y+w*0.11}" width="{w*0.28}" height="{w*0.075}" rx="{w*0.0375}" fill="#0C0C12"/>{extra}</g>'''

# A — Pedestal: a single phone floating above its own soft shadow, cream studio, very Apple.
A=HEAD+COMMON+'''
<linearGradient id="bgA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FBF8F3"/><stop offset=".62" stop-color="#EEE7DC"/><stop offset=".63" stop-color="#E6DDCF"/><stop offset="1" stop-color="#F3EDE4"/></linearGradient>
<linearGradient id="frA" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8E8A86"/><stop offset=".08" stop-color="#E9E6E1"/><stop offset=".5" stop-color="#C9C5BF"/><stop offset=".92" stop-color="#ECE9E4"/><stop offset="1" stop-color="#7F7B77"/></linearGradient>
<linearGradient id="scA" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2E2A5E"/><stop offset=".55" stop-color="#6B5BB4"/><stop offset="1" stop-color="#E9A27F"/></linearGradient>
</defs><path d="{T}" fill="url(#bgA)" filter="url(#ts)"/><g clip-path="url(#clip)">
<ellipse cx="540" cy="808" rx="190" ry="34" fill="#4A3A28" opacity=".35" filter="url(#sh)"/>
<ellipse cx="520" cy="800" rx="120" ry="14" fill="#2A2018" opacity=".35" filter="url(#sh2)"/>
'''.replace('{T}',T)+phone(392,214,240,520,'url(#frA)','url(#scA)',rot=-9,extra='''
<circle cx="560" cy="330" r="34" fill="#F4C9A8" opacity=".9"/>
<rect x="430" y="440" width="150" height="14" rx="7" fill="#fff" opacity=".85"/>
<rect x="430" y="468" width="100" height="14" rx="7" fill="#fff" opacity=".5"/>
<rect x="430" y="560" width="164" height="92" rx="20" fill="#fff" opacity=".16"/>''')+'''
</g>'''+END


open('icon.svg','w').write(A)

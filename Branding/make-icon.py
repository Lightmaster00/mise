import math
def squircle(x0,y0,size,n=5.0,N=360):
    c=size/2; pts=[]
    for i in range(N):
        t=2*math.pi*i/N; ct,st=math.cos(t),math.sin(t)
        x=abs(ct)**(2/n)*(1 if ct>=0 else -1); y=abs(st)**(2/n)*(1 if st>=0 else -1)
        pts.append((x0+c+c*x,y0+c+c*y))
    return 'M'+' L'.join(f'{a:.2f} {b:.2f}' for a,b in pts)+' Z'
T=squircle(100,100,824)
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B2F6B"/><stop offset="1" stop-color="#14142E"/></linearGradient>
<linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE7B8" stop-opacity=".55"/><stop offset="1" stop-color="#FFE7B8" stop-opacity="0.05"/></linearGradient>
<radialGradient id="pool" cx="512" cy="770" r="260" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FFE2A8" stop-opacity=".55"/><stop offset="1" stop-color="#FFE2A8" stop-opacity="0"/></radialGradient>
<linearGradient id="pedTop" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E7E2F4"/></linearGradient>
<linearGradient id="pedSide" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#B9B2D6"/><stop offset=".5" stop-color="#F2EFFA"/><stop offset="1" stop-color="#A49CC8"/></linearGradient>
<linearGradient id="screen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7B6BFF"/><stop offset="1" stop-color="#FF7AA8"/></linearGradient>
<linearGradient id="phone" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#C9C6D6"/><stop offset=".15" stop-color="#FFFFFF"/><stop offset=".85" stop-color="#F2F0F7"/><stop offset="1" stop-color="#B8B4C8"/></linearGradient>
<filter id="ts" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000" flood-opacity=".35"/></filter>
<filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity=".35"/></filter>
<filter id="blur"><feGaussianBlur stdDeviation="6"/></filter>
<clipPath id="clip"><path d="{T}"/></clipPath></defs>
<path d="{T}" fill="url(#bg)" filter="url(#ts)"/>
<g clip-path="url(#clip)">
  <path d="M452 100 L572 100 L790 790 L234 790 Z" fill="url(#beam)" filter="url(#blur)"/>
  <ellipse cx="512" cy="770" rx="300" ry="90" fill="url(#pool)"/>
  <g filter="url(#soft)">
    <path d="M322 742 L322 800 A190 46 0 0 0 702 800 L702 742 Z" fill="url(#pedSide)"/>
    <ellipse cx="512" cy="742" rx="190" ry="46" fill="url(#pedTop)"/>
  </g>
  <g filter="url(#soft)">
    <rect x="410" y="300" width="204" height="430" rx="44" fill="url(#phone)"/>
    <rect x="420" y="310" width="184" height="410" rx="36" fill="#0E0E14"/>
    <rect x="428" y="318" width="168" height="394" rx="30" fill="url(#screen)"/>
    <rect x="482" y="330" width="60" height="16" rx="8" fill="#0E0E14"/>
    <rect x="446" y="372" width="86" height="12" rx="6" fill="#fff" opacity=".9"/>
    <rect x="446" y="400" width="132" height="90" rx="14" fill="#fff" opacity=".28"/>
    <rect x="446" y="510" width="120" height="10" rx="5" fill="#fff" opacity=".55"/>
    <rect x="446" y="534" width="92" height="10" rx="5" fill="#fff" opacity=".55"/>
    <rect x="446" y="558" width="108" height="10" rx="5" fill="#fff" opacity=".55"/>
  </g>
  <path d="M428 318 L560 318 L428 520 Z" fill="#fff" opacity=".10"/>
</g>
<path d="{T}" fill="none" stroke="#fff" stroke-opacity=".14" stroke-width="3"/></svg>'''
open('icon.svg','w').write(svg)

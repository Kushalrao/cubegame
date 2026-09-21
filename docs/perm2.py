# Right-hand-rule rotation of a POINT by +90 about each axis (centred coords c = p-1)
def rh90(p, ax):
    x,y,z = (p[0]-1, p[1]-1, p[2]-1)
    if ax=='x': n=(x, -z,  y)   # +90 about +X:  y'=-z, z'=y
    if ax=='y': n=(z,  y, -x)   # +90 about +Y:  x'=z,  z'=-x
    if ax=='z': n=(-y, x,  z)   # +90 about +Z:  x'=-y, y'=x
    return (n[0]+1, n[1]+1, n[2]+1)
def rhm90(p, ax):
    q=rh90(p,ax); q=rh90(q,ax); return rh90(q,ax)   # +270 == -90

code = {
 ('row','cw') : (lambda p:(p[2], p[1], 2-p[0]), 'y', -1),   # SCNAction angle -pi/2
 ('row','ccw'): (lambda p:(2-p[2], p[1], p[0]), 'y', +1),
 ('col','cw') : (lambda p:(p[0], 2-p[2], p[1]), 'x', +1),
 ('col','ccw'): (lambda p:(p[0], p[2], 2-p[1]), 'x', -1),
 ('lay','cw') : (lambda p:(2-p[1], p[0], p[2]), 'z', +1),
 ('lay','ccw'): (lambda p:(p[1], 2-p[0], p[2]), 'z', -1),
}
pts=[(0,0,0),(2,0,0),(2,2,2),(0,2,0),(1,0,2),(2,1,0)]
for (name,dirn),(fn,ax,sign) in code.items():
    visual = rh90 if sign>0 else rhm90
    ok_visual = all(fn(p)==visual(p,ax) for p in pts)
    inverse   = rhm90 if sign>0 else rh90
    ok_inverse= all(fn(p)==inverse(p,ax) for p in pts)
    verdict = "MATCHES visual" if ok_visual else ("INVERTED vs visual" if ok_inverse else "?? neither")
    print(f"{name:4}/{dirn:3} SCNAction {sign:+d}90 about {ax.upper()} -> logical perm {verdict}")

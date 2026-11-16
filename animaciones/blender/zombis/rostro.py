"""Piel original generada localmente y relieve facial sobre la cabeza cuadrada R15."""
import bpy, bmesh, math
import numpy as np
from deterioro import pintar_piel, CEREBRO_VISIBLE

def esculpir(head, ns, index, skin, ident):
    bm=bmesh.new(); bm.from_mesh(head.data)
    front=next(f for f in bm.faces if (ns['C'].inverted() @ f.normal).z < -.9)
    bmesh.ops.subdivide_edges(bm,edges=list(front.edges),cuts=19,use_grid_fill=True)
    def gauss(x,y,cx,cy,wx,wy):
        return math.exp(-.5*((x-cx)/wx)**2-.5*((y-cy)/wy)**2)
    for v in bm.verts:
        g=ns['C'].inverted() @ v.co
        if abs(g.z+.39)<.0001:
            fade=max(0,1-(abs(g.x)/.35)**8)*max(0,1-(abs(g.y)/.43)**8)
            relief=0.0
            for side in [-1,1]:
                relief += .009*gauss(g.x,g.y,side*.153,.065,.085,.047)
                relief -= .008*gauss(g.x,g.y,side*.21,-.05,.10,.07)
                relief -= .004*gauss(g.x,g.y,side*.15,.12,.10,.026)
            relief -= .009*gauss(g.x,g.y,0,0,.038,.10)
            relief -= .004*gauss(g.x,g.y,0,-.30,.15,.05)
            g.z += relief*fade
            v.co=ns['C'] @ g
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(head.data); bm.free()
    for face in head.data.polygons:
        face.use_smooth=(ns['C'].inverted() @ face.normal).z < -.9
    # Coordenadas de proyección cúbica, embebidas y transportables al GLB.
    uv=head.data.uv_layers.new(name='UVMap')
    for face in head.data.polygons:
        n=ns['C'].inverted() @ face.normal
        axis=max(range(3),key=lambda i:abs(n[i]))
        for li in face.loop_indices:
            g=ns['C'].inverted() @ head.data.vertices[head.data.loops[li].vertex_index].co
            if axis==2: u,v=g.x/.7+.5,g.y/.86+.5
            elif axis==0: u,v=g.z/.78+.5,g.y/.86+.5
            else: u,v=g.x/.7+.5,g.z/.78+.5
            uv.data[li].uv=(u,v)
    # Variación de piel muy contenida; sin ojeras negras pintadas.
    size=512; rng=np.random.default_rng(9300+index)
    xx,yy=np.meshgrid(np.linspace(-.35,.35,size),np.linspace(-.43,.43,size))
    fine=rng.normal(0,.003,(size,size))
    # Ruido interpolado no periódico: evitar vetas de mármol sobre la frente.
    grid=rng.normal(0,1,(18,18))
    sample=np.linspace(0,17,size)
    lo=np.minimum(sample.astype(int),16); frac=sample-lo
    horizontal=grid[:,lo]*(1-frac)+grid[:,lo+1]*frac
    mottling=(horizontal[lo,:]*(1-frac[:,None])+horizontal[lo+1,:]*frac[:,None])*.006
    color=np.array(skin,dtype=np.float32)/255
    rgb=np.broadcast_to(color,(size,size,3)).copy()
    rgb += (fine+mottling)[...,None]
    for side in [-1,1]:
        eye=np.exp(-.5*((xx-side*.153)/.09)**2-.5*((yy-.038)/.042)**2)
        rgb-=eye[...,None]*np.array([.018,.025,.022])
        # Pliegues finos junto a los ojos y surco nasolabial, sin dibujar círculos negros.
        for offset in [.105,.126]:
            wrinkle=np.exp(-((yy-offset-side*.025*(xx-side*.153))/.0025)**2)*np.exp(-((xx-side*.153)/.085)**4)
            rgb-=wrinkle[...,None]*.012
        fold=np.exp(-((xx-side*(.082+.24*np.maximum(0,-yy)))/.003)**2)*np.exp(-((yy+.16)/.073)**4)
        rgb-=fold[...,None]*.012
    pintar_piel(rgb, xx, yy, index, rng, ident in CEREBRO_VISIBLE)
    pixels=np.ones((size,size,4),dtype=np.float32); pixels[:,:,:3]=np.clip(rgb,0,1)
    image=bpy.data.images.new('PielRostro_%02d'%index,width=size,height=size)
    image.colorspace_settings.name='sRGB'
    image.pixels.foreach_set(pixels.ravel()); image.pack()
    mat=head.data.materials[0].copy(); mat.name='PielRostro_%02d'%index
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.80
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image
    mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    head.data.materials.clear(); head.data.materials.append(mat)

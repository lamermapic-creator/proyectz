"""Deterioro original: sangre en piel/ropa y cráneo abierto en tres variantes."""
import bpy, bmesh, math, random
import numpy as np
from mathutils import Vector

CEREBRO_VISIBLE = {'civil', 'sanitario', 'paciente'}

def pintar_piel(rgb, xx, yy, index, rng, cerebro_visible=False):
    """Mezcla sangre con la piel existente; conserva ojos y contornos faciales legibles."""
    irregular=.14*np.sin(xx*183+yy*119)+.12*np.sin(xx*311-yy*83)
    mouth=((xx-(index%3-1)*.025)/.16)**2+((yy+.285)/.11)**2
    mask=np.clip((1-mouth+irregular)*3,0,1)*.88
    for k in range(4):
        x=-.12+k*.07+rng.uniform(-.01,.01)
        tip=-.42+rng.uniform(0,.065)
        line=np.exp(-((xx-x-.014*np.sin(yy*35+k))/.010)**4)
        line*=((yy<-.27)&(yy>tip))
        mask=np.maximum(mask,line*.85)
    side=-1 if index%2==0 else 1
    slash=np.exp(-((xx-side*.25+.17*(yy-.15))/.018)**2)*np.exp(-((yy-.13)/.13)**4)
    mask=np.maximum(mask,slash*.8)
    for k in range(34):
        x=rng.uniform(-.31,.31); y=rng.uniform(-.36,.33)
        r=rng.uniform(.0018,.006)
        dot=np.exp(-((xx-x)/r)**4-((yy-y)/(r*1.6))**4)
        mask=np.maximum(mask,dot*rng.uniform(.3,.85))
    if cerebro_visible:
        rim=np.exp(-((yy-.208)/.016)**4)*((xx>-.33)&(xx<-.025))
        mask=np.maximum(mask,rim*.94)
        trickle=np.exp(-((xx+.285+.009*np.sin(yy*31))/.010)**4)*((yy>.01)&(yy<.21))
        mask=np.maximum(mask,trickle*.9)
    wet=np.clip(.48+rng.normal(0,.10,xx.shape)+.14*np.exp(-((xx-.03)/.09)**2-((yy+.31)/.08)**2),0,1)
    blood=np.array([.24,.050,.035])+(wet[...,None]*np.array([.18,.025,.018]))
    rgb[:]=rgb*(1-mask[...,None])+blood*mask[...,None]

def aplicar(ns, index, spec, bloque):
    ident=spec[0]; box=ns['caja']; pieces=ns['vacios']; cv=ns['g2b']
    rng=random.Random(12700+index)
    def material(name,color,roughness):
        m=ns['material'](color,'Skin'); m.name=name
        m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=roughness
        return m
    dried=material('SangreSeca',(66,16,12),.82)
    fresh=material('SangreReciente',(116,24,18),.28)
    bone=material('HuesoExpuesto',(166,148,115),.73)
    brain=material('CerebroCorteza',(151,105,105),.45)
    # Una textura RGBA de manchas compartida por las superficies de ropa de esta variante.
    size=512; rand=np.random.default_rng(17000+index)
    xx,yy=np.meshgrid(np.linspace(-1,1,size),np.linspace(-1,1,size))
    a=np.arctan2(yy,xx); radius=np.sqrt(xx*xx+yy*yy)
    edge=.58+.10*np.sin(7*a+index)+.06*np.sin(13*a)+.04*np.sin(23*a)
    alpha=np.clip((edge-radius)*35,0,1)*.9
    for k in range(56):
        x=rand.uniform(-.93,.93); y=rand.uniform(-.93,.93); r=rand.uniform(.008,.042)
        alpha=np.maximum(alpha,np.exp(-((xx-x)/r)**4-((yy-y)/(r*1.2))**4)*rand.uniform(.45,.95))
    for x in [-.28,-.04,.21]:
        line=np.exp(-((xx-x-.025*np.sin(yy*14))/.025)**4)*((yy<-.18)&(yy>-.93))
        alpha=np.maximum(alpha,line*.85)
    noise=rand.random((size,size))
    color=np.array([.25,.045,.030])+noise[...,None]*np.array([.16,.028,.020])
    pixels=np.empty((size,size,4),dtype=np.float32); pixels[:,:,:3]=color; pixels[:,:,3]=alpha
    image=bpy.data.images.new('SangreManchas_%02d'%index,width=size,height=size,alpha=True)
    image.pixels.foreach_set(pixels.ravel()); image.pack()
    decal=bpy.data.materials.new('SangreRopa_%02d'%index); decal.use_nodes=True
    bsdf=decal.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value=.61
    tex=decal.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
    decal.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    decal.node_tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
    decal.surface_render_method='DITHERED'
    # Parche flexible que sigue el volumen de la prenda, con alfa irregular y sin borde rectangular.
    def patch(part,center,width,height,wrap):
        bm=bmesh.new(); uv=bm.loops.layers.uv.new('UVMap'); verts=[]; uvpos={}
        candidates=[ob for ob in pieces[part].children if ob.type=='MESH' and not ob.name.startswith('ManchaSangre')]
        bpy.context.view_layer.update()
        for row in range(5):
            for col in range(5):
                u=col/4; v=row/4
                x=center[0]+(u-.5)*width; y=center[1]+(v-.5)*height
                origin=cv(Vector((x,y,-1.8))-Vector(ns['PIEZAS'][part][1]))
                hits=[]
                for ob in candidates:
                    inv=ob.matrix_local.inverted()
                    hit,loc,_,_=ob.ray_cast(inv@origin,inv.to_3x3()@cv((0,0,1)))
                    if hit:
                        point=ns['C'].inverted()@(ob.matrix_local@loc)+Vector(ns['PIEZAS'][part][1])
                        hits.append(point.z)
                z=min(hits)-.004 if hits else center[2]+wrap*(abs(u-.5)*2)**3
                vert=bm.verts.new((x,y,z)); verts.append(vert if hits else None); uvpos[vert]=(u,v)
        for row in range(4):
            for col in range(4):
                n=row*5+col
                if any(verts[k] is None for k in [n,n+5,n+6,n+1]): continue
                face=bm.faces.new([verts[n],verts[n+5],verts[n+6],verts[n+1]])
                for loop in face.loops: loop[uv].uv=uvpos[loop.vert]
        for vert in bm.verts: vert.co=cv(vert.co-Vector(ns['PIEZAS'][part][1]))
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        me=bpy.data.meshes.new('ManchaSangre'); bm.to_mesh(me); bm.free(); me.materials.append(decal)
        ob=bpy.data.objects.new('ManchaSangre',me); ns['esc'].collection.objects.link(ob); ob.parent=pieces[part]
    # Manchas grandes de arrastre, salpicaduras y manos ensangrentadas.
    shirt_z=-.48 if ident=='policia' else -.43 if ident in ['granjero','excursionista','repartidor'] else -.395
    patch('UpperTorso',(rng.uniform(-.12,.12),.91,shirt_z-.10 if ident=='policia' else shirt_z),1.13,1.20,.055)
    patch('UpperTorso',(-.32,1.34,shirt_z-.014),.49,.43,.012)
    for side,prefix in [(-1,'Left'),(1,'Right')]:
        patch(prefix+'LowerArm',(side*.92,-.12,-.184),.26,.76,.055)
        patch(prefix+'Hand',(side*.92,-.82,-.115),.27,.44,.035)
        patch(prefix+'UpperLeg',(side*.33,-1.05,-.303),.48,.65,.03)
    # Coágulos y cortes en antebrazo: un poco de relieve, sin modificar articulaciones.
    side=-1 if index%2 else 1; arm='LeftLowerArm' if side<0 else 'RightLowerArm'
    cut=box(arm,'HeridaAntebrazo',(side*.92,-.06,-.18),(.105,.29,.025),(66,16,12),'Skin',rot=(0,0,18),bisel=.012)
    cut.data.materials.clear(); cut.data.materials.append(dried)
    for k in range(3):
        ob=bloque(arm,'Coagulo',(side*.92+.017*k,-.13+k*.07,-.20),(.042,.072,.026),(116,24,18),segments=8,rings=6)
        ob.data.materials.clear(); ob.data.materials.append(fresh)
    if ident not in CEREBRO_VISIBLE:
        return
    head=next(ob for ob in pieces['Head'].children if ob.name.startswith('Craneo'))
    # Abertura real por Boolean, atravesando frente y parte superior del cráneo.
    cutter=box('Head','CorteTemporal',(-.18,2.39,-.275),(.30,.32,.35),(166,148,115),'Skin',bisel=.015,segs=1)
    targets=[head]+[ob for ob in pieces['Head'].children if ob.name.startswith(('CabelloSuperior','Mechon'))]
    for ob in targets:
        bpy.context.view_layer.objects.active=ob
        for md in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
        while len(ob.data.materials)<3: ob.data.materials.append(bone)
        cutter.data.materials.clear()
        for mat in ob.data.materials: cutter.data.materials.append(mat)
        for face in cutter.data.polygons: face.material_index=2
        md=ob.modifiers.new('AberturaCraneal','BOOLEAN'); md.operation='DIFFERENCE'; md.solver='EXACT'; md.object=cutter
        bpy.ops.object.modifier_apply(modifier=md.name)
    # Comprobar que el frente está realmente abierto (el primer choque es la pared interior).
    origin=cv(Vector((-.18,2.39,-.8))-Vector(ns['PIEZAS']['Head'][1]))
    hit,loc,_,_=head.ray_cast(origin,cv((0,0,1)))
    assert hit and (ns['C'].inverted() @ loc).z > -.20, 'El cráneo no tiene una abertura real'
    bpy.data.objects.remove(cutter,do_unlink=True)
    # Cerebro de bloques: escalones y surcos ortogonales dentro de la abertura.
    ob=bloque('Head','CerebroVisible',(-.18,2.365,-.245),(.265,.235,.275),(151,105,105))
    ob.data.materials.clear(); ob.data.materials.append(brain)
    for col in range(5):
        for row in range(4):
            x=-.286+col*.052
            y=2.278+row*.055
            z=-.388 if (row+col)%3 else -.377
            ob=box('Head','PliegueCerebral',(x,y,z),(.038,.042,.018),(151,105,105),'Skin',bisel=0)
            ob.data.materials.clear(); ob.data.materials.append(brain)
    for col in range(2):
        ob=box('Head','VasoCerebral',(-.25+col*.11,2.36,-.400),(.008,.15,.005),(116,24,18),'Skin',bisel=0)
        ob.data.materials.clear(); ob.data.materials.append(fresh)

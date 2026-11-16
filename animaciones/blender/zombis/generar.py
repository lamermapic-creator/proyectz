"""Colección original R15. Blender -b -P generar.py; sin dependencias ni recursos externos."""
import bpy, sys, math, json, re, random, hashlib
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'modelos/zombis'
SOURCE = Path(__file__).resolve().parent
PREVIEW = '--vista-previa' in sys.argv
BLEND_OUT = Path('/tmp/zombis-v3') if PREVIEW else SOURCE
if PREVIEW:
    OUT = BLEND_OUT
sys.dont_write_bytecode = True
sys.path.insert(0, str(SOURCE))
from refinado import aplicar as refinar
from deterioro import CEREBRO_VISIBLE
# Reutilizamos las mismas dimensiones, conversión de ejes y primitivas del superviviente.
helpers = (SOURCE.parent / 'personaje/personaje.py').read_text().split('# ================================================================= DISEÑO NUEVO')[0]
VARIANTES = [
 ('civil', 'Civil / camisa', (91,105,99), (51,61,77), 'camisa'),
 ('sanitario', 'Sanitario', (119,161,148), (69,102,96), 'medico'),
 ('obrero', 'Obrero', (181,107,39), (62,66,70), 'obra'),
 ('mecanico', 'Mecánico', (54,76,103), (44,57,72), 'mono'),
 ('policia', 'Policía', (42,51,68), (36,42,53), 'policia'),
 ('bombero', 'Bombero', (100,84,52), (67,59,43), 'bombero'),
 ('excursionista', 'Excursionista', (102,67,51), (65,75,49), 'mochila'),
 ('oficinista', 'Oficinista', (136,134,117), (46,45,48), 'corbata'),
 ('repartidor', 'Repartidor', (132,53,42), (48,57,70), 'gorra'),
 ('paciente', 'Paciente', (145,151,137), (112,122,112), 'paciente'),
 ('granjero', 'Granjero', (104,90,53), (60,74,88), 'peto'),
 ('vagabundo', 'Vagabundo', (78,72,62), (58,53,47), 'capucha'),
]
CLIPS = {'reposo': (72, True), 'caminar': (48, True), 'perseguir': (28, True),
         'atacar': (32, False), 'herido': (22, False), 'morir': (48, False)}

def build(index, spec):
    global bpy
    ident, label, shirt, pants, kind = spec
    ns = {'__name__': '__helpers__'}
    old = sys.argv
    sys.argv = ['blender']
    exec(compile(helpers, 'personaje_helpers', 'exec'), ns)
    # Política de arte estricta: cualquier primitiva del catálogo es un bloque.
    original_box = ns['caja']
    def caja_recta(parte,nombre,centro,tam,col,tipo='Fabric',rot=(0,0,0),bisel=None,segs=1):
        return original_box(parte,nombre,centro,tam,col,tipo,rot,bisel=0,segs=1)
    def accesorio_recto(parte,nombre,centro,diam,largo,col,tipo='Fabric',eje='y',rot=(0,0,0),**kwargs):
        tam={'x':(largo,diam,diam),'y':(diam,largo,diam),'z':(diam,diam,largo)}[eje]
        return caja_recta(parte,nombre,centro,tam,col,tipo,rot)
    ns['caja']=caja_recta
    ns['cil']=accesorio_recto
    bpy.context.preferences.filepaths.save_version = 0
    sys.argv = old
    scene, pieces, centers = ns['esc'], ns['vacios'], ns['PIEZAS']
    box, cyl, cv = ns['caja'], ns['cil'], ns['g2b']
    root = ns['raiz']; root.name = 'Zombi_' + ident
    refinar(ns, index, spec)
    # Comprobación previa a fusionar: ninguna cara suavizada ni bisel redondeado.
    for e in pieces.values():
        for ob in e.children:
            if ob.type == 'MESH':
                assert not any(f.use_smooth for f in ob.data.polygons), ob.name+' suavizado'
                assert not any(m.type in {'BEVEL','SUBSURF'} for m in ob.modifiers), ob.name+' curva'
    # Una malla por pieza, con materiales como superficies (máximo 15 draw objects).
    for part,e in pieces.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in e.children: ob.select_set(True)
        bpy.context.view_layer.objects.active=e.children[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        ob=bpy.context.object; ob.name='M_'+part
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # Jerarquía de pivotes Motor6D: misma C0/C1 que RigPersonaje.
    text=(ROOT/'scripts/jugador/rig_personaje.gd').read_text().split('const MOTORES := [',1)[1].split('\n]',1)[0]
    motors=[]; pivots={}
    for line in text.splitlines():
        names=re.findall(r'"([A-Za-z]+)"',line)
        vec=re.findall(r'Vector3\(([^)]+)\)',line)
        if len(names)!=3 or len(vec)!=2: continue
        joint,parent,part=names
        c0,c1=[Vector(tuple(float(x.strip()) for x in v.split(','))) for v in vec]
        pivot=bpy.data.objects.new('J_'+joint,None); scene.collection.objects.link(pivot)
        pivot.parent=root if parent=='HumanoidRootPart' else pieces[parent]
        pivot.location=cv(c0); pivot.rotation_mode='QUATERNION'
        pieces[part].parent=pivot; pieces[part].location=cv(-c1)
        pivots[joint]=pivot
    # Rotaciones de actuación, ciclos cerrados y acciones con anticipación/recuperación.
    for clip,(frames,loop) in CLIPS.items():
        for joint,pivot in pivots.items():
            pivot.animation_data_create(); action=bpy.data.actions.new(clip+'_'+joint)
            pivot.animation_data.action=action
            for frame in range(1,frames+2):
                u=(frame-1)/frames; s=math.sin(u*math.tau); c=math.cos(u*math.tau)
                pitch=yaw=roll=0.; move=Vector((0,0,0))
                travel=clip in ['caminar','perseguir']; run=clip=='perseguir'
                if joint=='Waist': pitch=-12+2*s; roll=2*c
                if joint=='Neck': pitch=10; roll=9+3*s; yaw=6*s
                if joint=='Root': move.y=-.06+.025*s
                if travel:
                    if joint=='Root': move.y=-.12-abs(s)*(.13 if run else .07); roll=3*s
                    if joint=='Waist': pitch=-24 if run else -17; yaw=-7*s
                    if joint.endswith('Hip'): pitch=s*(34 if run else 20)*(1 if joint.startswith('Left') else -.8)
                    if joint.endswith('Knee'): pitch=-8-max(0,c*(1 if joint.startswith('Left') else -1))*(55 if run else 30)
                    if joint.endswith('Ankle'): pitch=-s*9*(1 if joint.startswith('Left') else -1)
                if joint.endswith('Shoulder'): pitch=55 if run else 12; roll=-8 if joint.startswith('Left') else 12
                if joint.endswith('Elbow'): pitch=18+5*s
                if clip=='atacar':
                    wind=math.sin(min(u/.4,1)*math.pi/2) if u<.4 else max(0,1-(u-.4)/.6)
                    thrust=math.sin(math.pi*max(0,min(1,(u-.35)/.4)))
                    if joint.endswith('Shoulder'): pitch=12+105*wind-40*thrust
                    if joint=='Waist': pitch=-12+15*wind-38*thrust
                    if joint=='Root': move.z=-.35*thrust
                if clip=='herido':
                    hit=math.sin(math.pi*u)**2
                    if joint=='Waist': pitch=30*hit; roll=-18*hit
                    if joint=='Neck': pitch=-26*hit; yaw=15*hit
                if clip=='morir':
                    fall=max(0,min(1,(u-.12)/.65)); fall=fall*fall*(3-2*fall)
                    if joint=='Root': pitch=86*fall; move.y=-2.65*fall; move.z=1.7*fall
                    if joint.endswith('Knee'): pitch=-20*fall
                R=ns['rot_g']((pitch,yaw,roll)); pivot.rotation_quaternion=(ns['C']@R@ns['C'].inverted()).to_quaternion()
                # local C0 translation plus clip displacement only at root
                base=next((Vector(tuple(float(v.strip()) for v in re.findall(r'Vector3\(([^)]+)\)',l)[0].split(','))) for l in text.splitlines() if '"'+joint+'"' in l),Vector())
                pivot.location=cv(base+move)
                pivot.keyframe_insert(data_path='rotation_quaternion',frame=frame)
                pivot.keyframe_insert(data_path='location',frame=frame)
            for fc in action.fcurves:
                for k in fc.keyframe_points: k.interpolation='LINEAR'
            track=pivot.animation_data.nla_tracks.new(); track.name=clip
            track.strips.new(clip,1,action)
            pivot.animation_data.action=None
    scene.render.fps=24; scene.frame_start=1; scene.frame_end=73
    for p in pivots.values():
        for track in p.animation_data.nla_tracks: track.mute=track.name!='reposo'
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT/(ident+'.blend')))
    for p in pivots.values():
        for track in p.animation_data.nla_tracks: track.mute=False
    bpy.ops.export_scene.gltf(filepath=str(OUT/(ident+'.glb')),export_format='GLB',export_yup=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
        export_frame_range=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
    data=(OUT/(ident+'.glb')).read_bytes()
    return {'id':ident,'nombre':label,'cerebro_visible':ident in CEREBRO_VISIBLE,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}

OUT.mkdir(parents=True,exist_ok=True)
result=[build(i,spec) for i,spec in enumerate(VARIANTES) if not PREVIEW or spec[0]=='sanitario']
if not PREVIEW:
    (OUT/'catalogo.json').write_text(json.dumps({'version':7,'presupuesto_triangulos':16000,'unidades':'studs','rig':'R15 Motor6D','origen':'Modelado original local en Blender; sin assets de terceros ni proveedores de pago','animaciones':CLIPS,'modelos':result},indent=2,ensure_ascii=False)+'\n')
print('COLECCION_OK',len(result))

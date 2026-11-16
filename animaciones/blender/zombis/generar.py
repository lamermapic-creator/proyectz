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
    bpy.context.preferences.filepaths.save_version = 0
    sys.argv = old
    scene, pieces, centers = ns['esc'], ns['vacios'], ns['PIEZAS']
    box, cyl, cv = ns['caja'], ns['cil'], ns['g2b']
    root = ns['raiz']; root.name = 'Zombi_' + ident
    rng = random.Random(4100 + index)
    skin = [(125,139,111),(142,136,116),(109,128,122),(147,143,126)][index % 4]
    dark = tuple(int(c*.60) for c in shirt)
    wound, bone, boot = (82,33,31), (190,177,139), (38,33,29)
    for part, (size, pos) in centers.items():
        category = part.replace('Left','').replace('Right','')
        color = skin if category in ['Head','LowerArm','Hand'] else pants if category in ['LowerTorso','UpperLeg','LowerLeg'] else boot if category == 'Foot' else shirt
        width = 1 + (index % 3 - 1)*.065 if 'Torso' in part else 1
        dims = (size[0]*width, size[1], size[2])
        box(part, 'Base_'+part, pos, dims, color, 'Skin' if color == skin else 'Fabric', bisel=.065 if part=='Head' else .035, segs=2)
        if category == 'Hand':
            for f in range(4):
                box(part, 'Dedo', (pos[0]-.105+f*.07,pos[1]-.24,pos[2]-.025), (.055,.22-rng.random()*.06,.10),skin,'Skin',rot=(0,0,(f-1.5)*5),bisel=.015)
            box(part,'Pulgar',(pos[0]+(.17 if part.startswith('Left') else -.17),pos[1]-.08,-.01),(.09,.19,.13),skin,'Skin',rot=(0,0,25),bisel=.02)
        if category in ['UpperLeg','LowerLeg','UpperArm']:
            box(part,'Costura',(pos[0]+size[0]*.48,pos[1],-.03),(.014,size[1]*.82,.035),dark,bisel=.002)
        if category == 'Foot':
            box(part,'Suela',(pos[0],-3.085,-.18),(.48,.065,1.01),boot,'Rubber',bisel=.015)
            for z in range(4):
                box(part,'Cordon',(pos[0],-2.79,-.39+z*.11),(.31,.018,.025),bone,bisel=.003)
    # Cara hundida: cuencas, ojos opacos, pómulos y mandíbula asimétrica.
    for side in [-1,1]:
        box('Head','Cuenca',(side*.17,2.10,-.391),(.25,.19,.045),(49,55,45),'Skin',rot=(0,0,side*9),bisel=.04,segs=2)
        box('Head','Ojo',(side*.17,2.09,-.422),(.105,.065,.025),(185,181,146),'Eye',bisel=.018)
        box('Head','Iris',(side*.18,2.09,-.438),(.026,.034,.009),(83,94,70),'Eye',bisel=.006)
        box('Head','Pomulo',(side*.25,1.94,-.399),(.16,.13,.07),skin,'Skin',rot=(0,0,side*17),bisel=.035)
        box('Head','Oreja',(side*.385,2.02,.01),(.10,.21,.14),skin,'Skin',bisel=.035)
    box('Head','Nariz',(0,2.015,-.43),(.105,.21,.11),skin,'Skin',bisel=.025)
    box('Head','Boca',(0,1.81,-.401),(.36,.16,.035),(37,28,24),'Skin',rot=(0,0,-6),bisel=.03)
    for tooth in range(5):
        box('Head','Diente',(-.14+tooth*.067,1.85,-.428),(.045,.055,.025),bone,'Wood',bisel=.004)
    box('Head','Labio',(0,1.72,-.405),(.34,.035,.04),wound,'Skin',rot=(0,0,-8),bisel=.01)
    for i in range(5):
        box('Head','Cicatriz',(-.28+i*.027,2.22-i*.035,-.407),(.035,.07,.012),wound,'Skin',rot=(0,0,24),bisel=.005)
    if kind not in ['obra','bombero','paciente','capucha']:
        box('Head','PeloNuca',(0,2.23,.32),(.73,.35,.17),(43,39,31),'Hair',bisel=.06)
        for i in range(6):
            box('Head','Mechon',(-.30+i*.12,2.44,.04),(.10,.12+rng.random()*.10,.58),(43,39,31),'Hair',rot=(0,0,rng.uniform(-15,15)),bisel=.025)
    # Roturas superpuestas con borde irregular, remiendos y suciedad geométrica.
    for part in ['UpperTorso','LeftUpperLeg','RightLowerLeg','RightUpperArm']:
        sz, pos = centers[part]
        for i in range(3):
            x=pos[0]+rng.uniform(-sz[0]*.28,sz[0]*.28); y=pos[1]+rng.uniform(-sz[1]*.3,sz[1]*.3)
            z=-sz[2]/2-.008
            box(part,'Rotura',(x,y,z),(.09+rng.random()*.13,.12+rng.random()*.18,.015),skin,'Skin',rot=(0,0,rng.uniform(-25,25)),bisel=.008)
            box(part,'BordeRoto',(x-.05,y,z-.012),(.025,.19,.012),dark,rot=(0,0,15),bisel=.003)
    for side in [-1,1]:
        part='LeftUpperLeg' if side<0 else 'RightUpperLeg'
        box(part,'Bolsillo',(side*.33,-.70,-.295),(.32,.34,.07),pants,bisel=.025)
        box(part,'Solapa',(side*.33,-.52,-.32),(.34,.07,.07),dark,bisel=.01)
    for i in range(4):
        box('UpperTorso','Boton',(.06,.47+i*.27,-.39),(.045,.045,.025),bone,'Plastic',bisel=.01)
    box('LowerTorso','Cinturon',(0,-.05,-.35),(1.23,.12,.055),boot,'Leather',bisel=.01)
    box('LowerTorso','Hebilla',(.08,-.05,-.39),(.18,.14,.035),(115,111,91),'Metal',bisel=.012)
    T='UpperTorso'; H='Head'
    if kind in ['obra','bombero']:
        col=(188,153,53) if kind=='obra' else (91,39,30)
        box(H,'Casco',(0,2.45,.02),(.83,.30,.90),col,'Plastic',bisel=.12,segs=3)
        box(H,'AlaCasco',(0,2.31,-.08),(.98,.06,1.10),col,'Plastic',bisel=.025)
    if kind in ['obra','bombero']:
        for x in [-.45,.45]: box(T,'BandaReflectante',(x,.91,-.395),(.13,1.17,.035),(186,192,128),bisel=.008)
        box(T,'BandaHorizontal',(0,.47,-.40),(1.42,.10,.04),(186,192,128),bisel=.008)
    if kind=='medico':
        box(T,'BolsilloPecho',(-.36,1.06,-.415),(.36,.30,.06),dark,bisel=.018)
        box(T,'Identificacion',(.34,1.12,-.41),(.23,.30,.025),(184,185,160),'Plastic',rot=(0,0,-9),bisel=.008)
        box(T,'Boligrafo',(-.35,1.25,-.45),(.035,.23,.03),(40,52,74),'Plastic',bisel=.004)
        box(H,'MascarillaCaida',(0,1.61,-.35),(.52,.12,.18),(139,167,151),bisel=.025)
    if kind=='policia':
        box(T,'Chaleco',(0,.94,-.42),(1.20,1.07,.14),dark,bisel=.04)
        for x in [-.39,0,.39]: box(T,'Portacargador',(x,.62,-.54),(.25,.36,.13),shirt,bisel=.018)
        box(T,'Placa',(-.29,1.25,-.51),(.19,.23,.025),(167,146,73),'Metal',bisel=.025)
    if kind in ['mochila','gorra']:
        for x in [-.46,.46]: box(T,'Correa',(x,.94,-.40),(.13,1.22,.06),boot,'Leather',bisel=.014)
        box(T,'Mochila',(0,.90,.62),(1.10,1.18,.47),shirt,bisel=.09,segs=2)
        box(T,'BolsilloMochila',(0,.70,.89),(.83,.51,.13),dark,bisel=.03)
    if kind=='gorra':
        box(H,'Gorra',(0,2.40,0),(.76,.19,.81),shirt,bisel=.06)
        box(H,'Visera',(0,2.31,-.51),(.70,.05,.43),shirt,bisel=.04)
    if kind=='corbata':
        box(T,'Corbata',(.04,.97,-.42),(.14,.94,.04),(74,39,36),rot=(0,0,-11),bisel=.012)
        for x in [-.22,.22]: box(T,'Cuello',(x,1.51,-.40),(.26,.25,.045),shirt,rot=(0,0,x*80),bisel=.02)
    if kind=='peto':
        box(T,'Peto',(0,.64,-.42),(.86,.73,.07),pants,bisel=.025)
        for x in [-.40,.40]: box(T,'Tirante',(x,1.19,-.41),(.14,.73,.05),pants,bisel=.01)
    if kind=='capucha':
        box(H,'Capucha',(0,2.26,.17),(.89,.65,.72),shirt,bisel=.12,segs=3)
        box(T,'Bufanda',(0,1.58,-.05),(.84,.24,.72),dark,bisel=.07)
    if kind=='paciente':
        for y in [.5,.75,1,1.25]:
            for x in [-.46,-.17,.17,.46]: box(T,'PatronBata',(x,y,-.38),(.025,.04,.012),dark,bisel=.003)
        box('LeftLowerArm','Pulsera',(-.92,-.42,0),(.36,.08,.40),bone,'Plastic',bisel=.015)
    refinar(ns, index, spec)
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
    (OUT/'catalogo.json').write_text(json.dumps({'version':4,'presupuesto_triangulos':16000,'unidades':'studs','rig':'R15 Motor6D','origen':'Modelado original local en Blender; sin assets de terceros ni proveedores de pago','animaciones':CLIPS,'modelos':result},indent=2,ensure_ascii=False)+'\n')
print('COLECCION_OK',len(result))

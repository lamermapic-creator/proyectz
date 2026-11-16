"""Diseño v2: volúmenes anatómicos y vestuario. Conserva centros y pivotes del R15."""
import bpy, bmesh, math, random
from mathutils import Vector

# Ancho de torso, profundidad, volumen de miembros, ancho de mandíbula y peinado.
PERFILES = {
    'civil': (.94, .95, .96, .89, 'raya'),
    'sanitario': (.89, .90, .90, .83, 'corto'),
    'obrero': (1.04, 1.02, 1.06, 1.02, 'calvo'),
    'mecanico': (1.00, .96, 1.02, .95, 'raya'),
    'policia': (1.04, 1.00, 1.04, .97, 'corto'),
    'bombero': (1.06, 1.08, 1.06, 1.00, 'calvo'),
    'excursionista': (.92, .93, .93, .85, 'largo'),
    'oficinista': (.88, .88, .91, .86, 'raya'),
    'repartidor': (.92, .92, .94, .90, 'corto'),
    'paciente': (.84, .88, .85, .79, 'calvo'),
    'granjero': (1.03, 1.03, 1.03, 1.02, 'barba'),
    'vagabundo': (.93, .97, .91, .88, 'barba'),
}

def aplicar(ns, index, spec):
    ident, _, shirt, pants, kind = spec
    width, depth, limb, jaw, hair = PERFILES[ident]
    rng = random.Random(8300 + index)
    box, cyl = ns['caja'], ns['cil']
    pieces, centers = ns['vacios'], ns['PIEZAS']
    skin = [(125,139,111),(142,136,116),(109,128,122),(147,143,126)][index % 4]
    shadow = tuple(int(c*.63) for c in skin)
    cloth_shadow = tuple(int(c*.68) for c in shirt)
    wound, bone, boot = (82,33,31), (190,177,139), (38,33,29)
    remove = ['Base_', 'Dedo', 'Pulgar', 'Cuenca', 'Ojo', 'Iris', 'Pomulo', 'Oreja', 'Nariz',
              'Boca', 'Diente', 'Labio', 'Cicatriz', 'Mechon', 'PeloNuca', 'Rotura', 'BordeRoto']
    for e in pieces.values():
        for ob in list(e.children):
            if any(ob.name.startswith(prefix) for prefix in remove):
                bpy.data.objects.remove(ob, do_unlink=True)

    def mesh(part, name, bm, pos, color, material='Skin', rot=(0,0,0), smooth=True):
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        ob=ns['_objeto'](part,name,bm,pos,rot,color,material,0,1)
        for p in ob.data.polygons: p.use_smooth=smooth
        return ob

    def oval(part,name,pos,size,color,material='Skin',rot=(0,0,0),segments=12,rings=8):
        bm=bmesh.new()
        bmesh.ops.create_uvsphere(bm,u_segments=segments,v_segments=rings,radius=1)
        for v in bm.verts:
            v.co=Vector((v.co.x*size[0]/2,v.co.y*size[1]/2,v.co.z*size[2]/2))
        return mesh(part,name,bm,pos,color,material,rot)

    def volume(part,name,pos,size,profile,color,material='Fabric',segments=12,square=.75):
        """Anillos transversales: (altura normalizada, radio x, radio z, desplazamiento z)."""
        bm=bmesh.new(); rows=[]
        for height,rx,rz,dz in profile:
            row=[]
            for i in range(segments):
                a=i*math.tau/segments; x=math.cos(a); z=math.sin(a)
                x=math.copysign(abs(x)**square,x); z=math.copysign(abs(z)**square,z)
                row.append(bm.verts.new((x*size[0]*rx/2,height*size[1],z*size[2]*rz/2+dz)))
            rows.append(row)
        for lower,upper in zip(rows,rows[1:]):
            for i in range(segments): bm.faces.new((lower[i],lower[(i+1)%segments],upper[(i+1)%segments],upper[i]))
        bm.faces.new(tuple(reversed(rows[0]))); bm.faces.new(tuple(rows[-1]))
        return mesh(part,name,bm,pos,color,material)

    # La silueta cambia por profesión, conservando los centros de articulación.
    for part,(size,pos) in centers.items():
        category=part.replace('Left','').replace('Right','')
        if category in ['Head','Hand']: continue
        color=skin if category=='LowerArm' else pants if category in ['LowerTorso','UpperLeg','LowerLeg'] else boot if category=='Foot' else shirt
        scale=width if 'Torso' in part else limb
        dims=(size[0]*scale,size[1],size[2]*(depth if 'Torso' in part else 1))
        if category=='UpperTorso':
            profile=[(-.5,.83,.90,0),(-.34,.88,.94,0),(-.05,.98,1,0),(.23,1.03,1.0,0),(.40,.95,.91,0),(.50,.70,.67,0)]
        elif category=='LowerTorso':
            profile=[(-.5,.86,.83,0),(-.3,1,1,0),(.20,1,1,0),(.5,.86,.92,0)]
        elif category=='UpperArm':
            profile=[(-.50,.76,.76,0),(-.30,.94,.98,0),(.05,1.02,1.03,0),(.31,.97,.99,0),(.5,.72,.76,0)]
        elif category=='LowerArm':
            profile=[(-.5,.60,.60,0),(-.20,.73,.78,0),(.12,.96,.95,-.015),(.32,1,1,0),(.5,.76,.79,0)]
        elif category=='UpperLeg':
            profile=[(-.5,.74,.74,0),(-.23,.91,.91,0),(.14,1.0,1.02,0),(.4,.97,.98,0),(.5,.85,.86,0)]
        elif category=='LowerLeg':
            profile=[(-.5,.70,.72,0),(-.23,.77,.85,.015),(.07,1,1.05,.02),(.33,.94,.90,0),(.5,.76,.80,0)]
        else:
            profile=[(-.5,.80,.88,0),(-.30,1,1,-.02),(.14,.95,.90,0),(.5,.70,.75,.08)]
        volume(part,'Anatomia_'+part,pos,dims,profile,color,'Skin' if category=='LowerArm' else 'Leather' if category=='Foot' else 'Fabric')
        if category=='UpperArm':
            # Cubrir la unión hombro/pecho también en las variantes de torso estrecho.
            oval(part,'Hombro',(pos[0]*.90,1.30,0),(.46,.35,.48),shirt,'Fabric')
        if category=='LowerArm':
            # Tendones, radio visible y venas discretas.
            for dx in [-.07,.07]:
                oval(part,'Tendon',(pos[0]+dx,pos[1]-.10,-.15),(.035,.51,.035),shadow,rot=(0,0,dx*55),segments=8,rings=6)
        if category in ['UpperLeg','LowerLeg','UpperArm']:
            for y in [-.20,.12]:
                oval(part,'Pliegue',(pos[0],pos[1]+y,-size[2]*.46),(.30 if 'Leg' in part else .25,.027,.035),tuple(int(c*.82) for c in color),'Fabric',rot=(0,0,rng.uniform(-13,13)),segments=8,rings=6)
    # Cráneo con sienes estrechas y mandíbula hundida, no una caja.
    head_profile=[(-.50,.48,.51,-.04),(-.37,.70*jaw,.70,-.02),(-.21,.89*jaw,.82,0),
                  (.03,.99,.91,0),(.26,1,1,.015),(.42,.85,.85,.02),(.5,.46,.49,.015)]
    volume('Head','Craneo',(0,2.02,0),(.76,.91,.77),head_profile,skin,'Skin',segments=16,square=1)
    for s in [-1,1]:
        eye_y=2.10 + (index%3-1)*s*.014
        oval('Head','Cuenca',(s*.166,eye_y,-.343),(.22,.145,.05),(49,53,43),rot=(0,0,s*9))
        oval('Head','GloboOcular',(s*.166,eye_y-.008,-.389),(.112,.083,.048),(191,185,158),'Eye')
        if not (index%4==1 and s==1):
            oval('Head','Iris',(s*.161,eye_y-.009,-.414),(.036,.044,.009),(81,94,71),'Eye',segments=8,rings=6)
        oval('Head','Parpado',(s*.167,eye_y+.039,-.372),(.18,.027,.035),shadow,rot=(0,0,s*8))
        oval('Head','ArcoCeja',(s*.177,eye_y+.093,-.332),(.24,.060,.07),skin,rot=(0,0,s*12))
        oval('Head','Pomulo',(s*.243,1.96,-.265),(.18,.13,.11),skin,rot=(0,0,s*17))
        oval('Head','Oreja',(s*.377,2.01,.012),(.10,.22,.14),skin,rot=(0,0,s*8))
        oval('Head','OrejaInterior',(s*.408,2.01,-.030),(.027,.124,.065),shadow)
    oval('Head','PuenteNariz',(0,2.025,-.390),(.094,.221,.11),skin)
    oval('Head','PuntaNariz',(.012,1.952,-.444),(.13,.095,.10),skin)
    for s in [-1,1]: oval('Head','FosaNasal',(s*.041,1.922,-.451),(.033,.023,.015),(47,40,30),segments=8,rings=6)
    tilt=(index%3-1)*8
    oval('Head','BocaAbierta',(0,1.79,-.310),(.29,.152,.055),(34,25,22),rot=(0,0,tilt))
    oval('Head','Mandibula',(.018*(index%3-1),1.657,-.14),(.40*jaw,.18,.36),skin,rot=(0,0,tilt))
    for t in range(5):
        if t==(index%6): continue
        box('Head','DienteIrregular',(-.112+t*.055,1.83+rng.uniform(-.012,.008),-.343),(.037,rng.uniform(.037,.060),.025),bone,'Wood',rot=(0,0,rng.uniform(-12,12)),bisel=.009,segs=2)
    for s in [-1,1]: oval('Head','Comisura',(s*.137,1.79,-.324),(.04,.12,.018),wound,rot=(0,0,s*20),segments=8,rings=6)
    # Herida localizada asimétrica en la sien, borde oscuro y tejido opaco.
    side=-1 if index%2==0 else 1
    oval('Head','Contusion',(side*.26,2.22,-.326),(.115,.18,.026),shadow,rot=(0,0,side*20))
    for n in range(3):
        oval('Head','Laceracion',(side*(.22+n*.024),2.24-n*.038,-.348),(.025,.075,.018),wound,rot=(0,0,-side*22),segments=8,rings=6)
    # Peinados con volumen y mechones, barba en las dos variantes mayores.
    hair_col=(42+index%3*7,36+index%3*5,29+index%3*3)
    if kind not in ['obra','bombero','capucha'] and hair!='calvo':
        oval('Head','CabelloSuperior',(0,2.41,.035),(.72,.20,.73),hair_col,'Hair',segments=16)
        for n in range(6):
            x=-.27+n*.105
            oval('Head','Mechon', (x,2.425+.025*math.cos(n),-.10),(.105,.125,.49),hair_col,'Hair',rot=(0,10 if hair=='raya' else -8,n*3-8),segments=8,rings=6)
        if hair=='largo':
            for s in [-1,1]: oval('Head','Melena',(s*.32,2.18,.12),(.16,.53,.51),hair_col,'Hair')
    if hair=='barba':
        oval('Head','Barba',(0,1.67,-.165),(.48,.26,.43),(70,66,53),'Hair')
        for n in range(5): oval('Head','MechonBarba',(-.17+n*.083,1.58,-.28),(.075,.21,.09),(78,75,61),'Hair',segments=8,rings=6)
    # Manos ahuecadas, falanges escalonadas y uñas, manteniendo una pieza por mano.
    for s,prefix in [(-1,'Left'),(1,'Right')]:
        part=prefix+'Hand'; x=s*.92
        oval(part,'Palma',(x,-.765,0),(.27,.34,.20),skin)
        oval(part,'Nudillos',(x,-.895,-.035),(.26,.08,.19),shadow)
        for f in range(4):
            fx=x-.098+f*.065; length=[.17,.205,.19,.145][f]
            oval(part,'Falange',(fx,-.97,-.015),(.055,length,.066),skin,rot=(9,0,(f-1.5)*4),segments=8,rings=6)
            oval(part,'PuntaDedo',(fx,-.97-length*.46,-.052),(.049,.09,.055),skin,rot=(35,0,0),segments=8,rings=6)
            box(part,'Una',(fx,-.98-length*.5,-.078),(.035,.044,.008),bone,'Wood',rot=(15,0,0),bisel=.005)
        oval(part,'Pulgar',(x-s*.159,-.805,-.015),(.10,.235,.115),skin,rot=(0,0,s*30))
    # Parches orgánicos y deshilachados en zonas de roce; no confeti rectangular.
    for part in ['UpperTorso','LeftUpperLeg','RightLowerLeg','RightUpperArm']:
        size,pos=centers[part]
        z=-size[2]/2-.006
        for n in range(2):
            x=pos[0]+rng.uniform(-size[0]*.18,size[0]*.18); y=pos[1]+rng.uniform(-size[1]*.28,size[1]*.28)
            oval(part,'Desgaste',(x,y,z),(.13,.23,.018),cloth_shadow,'Fabric',rot=(0,0,rng.uniform(-30,30)),segments=8,rings=6)
            for k in range(2):
                box(part,'Hilo',(x-.032+k*.045,y-.11,z-.01),(.012,.10+k*.04,.014),pants,'Fabric',rot=(0,0,k*16-8),bisel=.002)
    # Ropa/equipo específicos: capas reales y perfiles distintos por profesión.
    T='UpperTorso'
    if kind in ['medico','mono','camisa','corbata']:
        for s in [-1,1]:
            box(T,'SolapaCuello',(s*.22,1.47,-.335),(.24,.25,.065),shirt,rot=(0,0,s*26),bisel=.035,segs=2)
    if kind=='mono':
        box(T,'Cremallera',(0,.91,-.391),(.045,1.05,.028),(108,105,87),'Metal',bisel=.006)
        for s in [-1,1]:
            box(T,'BolsilloTrabajo',(s*.36,1.10,-.372),(.30,.32,.065),cloth_shadow,bisel=.035,segs=2)
            box('LeftUpperLeg' if s<0 else 'RightUpperLeg','Rodillera',(s*.33,-1.37,-.25),(.38,.25,.075),(40,44,44),'Rubber',bisel=.055,segs=2)
    if kind=='policia':
        box(T,'Radio',(.45,1.23,-.53),(.16,.26,.10),(28,31,29),'Plastic',bisel=.025)
        cyl(T,'Antena',(.48,1.49,-.51),.023,.28,(35,37,31),'Rubber',segs=6,bisel=0)
    if kind=='bombero':
        box(T,'ChaquetonFaldon',(0,.20,.04),(1.25,.27,.68),shirt,bisel=.07,segs=2)
        for s in [-1,1]:
            part='LeftLowerLeg' if s<0 else 'RightLowerLeg'
            volume(part,'BotaAlta',(s*.33,-2.54,0),(.49,.48,.49),[(-.5,.9,.9,0),(.5,1,1,0)],boot,'Leather')
    if kind=='paciente':
        for s in [-1,1]:
            box(T,'BajoBata',(s*.31,.18,-.03),(.61,.32,.68),shirt,rot=(0,0,s*3),bisel=.04,segs=2)
        for y in [.55,.9,1.22]: box(T,'CintaBata',(0,y,.39),(.23,.035,.045),cloth_shadow,bisel=.006)
    if kind in ['mochila','gorra']:
        for s in [-1,1]: box(T,'HebillaCorrea',(s*.46,.66,-.45),(.16,.20,.055),(87,85,74),'Plastic',bisel=.02)
        cyl(T,'Botella',(.66,.86,.52),.22,.61,(92,113,102),'Plastic',segs=12,bisel=.02)
    if kind=='peto':
        for s in [-1,1]: oval(T,'BotonTirante',(s*.4,.91,-.46),(.065,.065,.025),(147,137,95),'Metal',segments=8,rings=6)
    if kind=='capucha':
        for n in range(3): box(T,'ParcheAbrigo',(-.33+n*.24,.6+(n%2)*.36,-.40),(.20,.27,.04),pants,rot=(0,0,n*9-9),bisel=.014)

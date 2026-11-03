# El superviviente de Proyecto Z, modelado en Blender pieza a pieza (estilo "muñeco cuadrado" de Roblox R15, con
# unas tres veces más detalle que el muñeco hecho por código). Todo se escribe en coordenadas de Godot (studs, Y
# arriba, -Z delante, posición de reposo respecto al HumanoidRootPart) y se convierte a Blender (Z arriba).
# Cada pieza del R15 es un vacío con el nombre de la pieza, colocado en su centro de reposo; sus mallas cuelgan de él
# (al exportar se juntan por material: una malla por pieza y material). El juego (RigPersonaje) mete esas mallas en
# las piezas del esqueleto; las cajas de impacto siguen siendo las de siempre (PIEZAS en rig_personaje.gd).
#
# Uso: blender -b -P personaje.py -- [--nuevo|--viejo] [--blend=x.blend] [--glb=x.glb] [--render=prefijo]
import bpy, bmesh, math, sys
from mathutils import Matrix, Vector, Euler

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(nombre, defecto=None):
	for a in ARGS:
		if a.startswith("--" + nombre + "="):
			return a.split("=", 1)[1]
		if a == "--" + nombre:
			return True
	return defecto


bpy.ops.wm.read_factory_settings(use_empty=True)
esc = bpy.context.scene

# ---------------------------------------------------------------- esqueleto (las mismas piezas que el juego)
PIEZAS = {
	"LowerTorso": ((1.2, 0.6, 0.66), (0, -0.08, 0)),
	"UpperTorso": ((1.42, 1.38, 0.74), (0, 0.89, 0)),
	"Head": ((0.7, 0.86, 0.78), (0, 2.02, 0)),
	"LeftUpperArm": ((0.38, 1.05, 0.42), (-0.92, 0.885, 0)),
	"LeftLowerArm": ((0.34, 0.95, 0.38), (-0.92, -0.105, 0)),
	"LeftHand": ((0.28, 0.42, 0.22), (-0.92, -0.79, 0)),
	"RightUpperArm": ((0.38, 1.05, 0.42), (0.92, 0.885, 0)),
	"RightLowerArm": ((0.34, 0.95, 0.38), (0.92, -0.105, 0)),
	"RightHand": ((0.28, 0.42, 0.22), (0.92, -0.79, 0)),
	"LeftUpperLeg": ((0.52, 1.3, 0.56), (-0.33, -0.9, 0)),
	"LeftLowerLeg": ((0.44, 1.25, 0.46), (-0.33, -2.175, 0)),
	"LeftFoot": ((0.46, 0.3, 1.0), (-0.33, -2.95, -0.18)),
	"RightUpperLeg": ((0.52, 1.3, 0.56), (0.33, -0.9, 0)),
	"RightLowerLeg": ((0.44, 1.25, 0.46), (0.33, -2.175, 0)),
	"RightFoot": ((0.46, 0.3, 1.0), (0.33, -2.95, -0.18)),
}

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))   # Godot (x, y, z) -> Blender (x, -z, y)


def g2b(v):
	return C @ Vector(v)


raiz = bpy.data.objects.new("Superviviente", None)
esc.collection.objects.link(raiz)
vacios = {}
for n, (tam, c) in PIEZAS.items():
	e = bpy.data.objects.new(n, None)
	esc.collection.objects.link(e)
	e.parent = raiz
	e.location = g2b(c)
	e.empty_display_size = 0.15
	vacios[n] = e

# ---------------------------------------------------------------- materiales
TIPOS = {  # rugosidad, metálico
	"Fabric": (0.95, 0.0), "Leather": (0.6, 0.0), "Metal": (0.35, 0.85), "Rubber": (0.9, 0.0),
	"Skin": (0.55, 0.0), "Plastic": (0.45, 0.0), "Hair": (0.85, 0.0), "Wood": (0.75, 0.0), "Eye": (0.25, 0.0),
}
mats = {}


def material(col, tipo):
	k = (tuple(col), tipo)
	if k not in mats:
		m = bpy.data.materials.new("%s_%02x%02x%02x" % (tipo, col[0], col[1], col[2]))
		m.use_nodes = True
		b = m.node_tree.nodes["Principled BSDF"]
		lin = [((c / 255.0 + 0.055) / 1.055) ** 2.4 if c / 255.0 > 0.04045 else c / 255.0 / 12.92 for c in col]
		b.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1)
		b.inputs["Roughness"].default_value = TIPOS[tipo][0]
		b.inputs["Metallic"].default_value = TIPOS[tipo][1]
		m.diffuse_color = (lin[0], lin[1], lin[2], 1)
		mats[k] = m
	return mats[k]


def rot_g(r):
	# giro en grados como Rbx.ang (Rx·Ry·Rz), en el espacio de Godot
	return (Matrix.Rotation(math.radians(r[0]), 3, 'X') @ Matrix.Rotation(math.radians(r[1]), 3, 'Y')
		@ Matrix.Rotation(math.radians(r[2]), 3, 'Z'))


cuenta = [0]


def _objeto(parte, nombre, bm, centro, rot, col, tipo, bisel, segs):
	R = rot_g(rot)
	pc = Vector(PIEZAS[parte][1])
	for v in bm.verts:
		v.co = C @ (R @ v.co + Vector(centro) - pc)
	me = bpy.data.meshes.new(nombre)
	bm.to_mesh(me)
	bm.free()
	me.materials.append(material(col, tipo))
	ob = bpy.data.objects.new(nombre, me)
	esc.collection.objects.link(ob)
	ob.parent = vacios[parte]
	if bisel and bisel > 0:
		md = ob.modifiers.new("bisel", 'BEVEL')
		md.width = bisel
		md.segments = segs
		md.limit_method = 'ANGLE'
		md.angle_limit = math.radians(40)
	cuenta[0] += 1
	return ob


def caja(parte, nombre, centro, tam, col, tipo="Fabric", rot=(0, 0, 0), bisel=None, segs=1):
	"""caja de tamaño tam (Godot) centrada en 'centro' (coordenadas de reposo de Godot)"""
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2]))
	if bisel is None:
		bisel = min(0.012, min(tam) * 0.22)
	return _objeto(parte, nombre, bm, centro, rot, col, tipo, bisel, segs)


def cil(parte, nombre, centro, diam, largo, col, tipo="Fabric", eje="y", rot=(0, 0, 0), segs=12, bisel=0.01, diam2=None):
	"""cilindro (o cono si diam2) a lo largo del eje dado (x, y o z de Godot)"""
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=(diam2 or diam) / 2, radius2=diam / 2, depth=largo)
	# create_cone va a lo largo de Z: lo paso a Y (Godot)
	A = {"y": Matrix.Rotation(-math.pi / 2, 3, 'X'), "x": Matrix.Rotation(math.pi / 2, 3, 'Y'), "z": Matrix.Identity(3)}[eje]
	for v in bm.verts:
		v.co = A @ v.co
	return _objeto(parte, nombre, bm, centro, rot, col, tipo, bisel, 1)


def espejo(fn, parte_i, nombre, centro, *a, **k):
	"""lo mismo en los dos lados: parte_i = pieza sin Left/Right (p. ej. 'UpperArm') o una pieza central
	(p. ej. 'Head'); centro con la x del lado derecho"""
	for lado, s in (("Right", 1), ("Left", -1)):
		c = (centro[0] * s, centro[1], centro[2])
		kk = dict(k)
		if "rot" in kk:
			r = kk["rot"]
			kk["rot"] = (r[0], r[1] * s, r[2] * s)
		fn(parte_i if parte_i in PIEZAS else lado + parte_i, nombre + lado[0], c, *a, **kk)


# ================================================================= DISEÑO NUEVO
# Paleta (apagada, realista, como el resto del juego)
PIEL = (186, 138, 104)
PIEL_OSC = (164, 118, 88)
PELO = (40, 30, 24)
BARBA = (54, 40, 31)
GORRO = (118, 50, 40)
GORRO_OSC = (96, 40, 33)
PANUELO = (154, 144, 116)
PANUELO_OSC = (118, 108, 84)
CHAQUETA = (64, 72, 80)
CHAQUETA_OSC = (50, 57, 64)
CHALECO = (128, 108, 78)
CHALECO_OSC = (104, 87, 62)
CINTA = (78, 66, 48)
PANTALON = (72, 74, 57)
PANTALON_OSC = (58, 60, 46)
GUANTE = (38, 36, 33)
GUANTE_OSC = (26, 25, 23)
BOTA = (142, 112, 78)
BOTA_OSC = (112, 86, 58)
SUELA = (30, 27, 24)
NEGRO = (28, 28, 29)
METAL = (150, 150, 145)
MOCHILA = (62, 66, 56)
MOCHILA_OSC = (48, 51, 43)
ESTERILLA = (72, 92, 108)
ROJO = (150, 34, 30)
NARANJA = (186, 104, 40)
BLANCO_OJO = (226, 220, 208)
IRIS = (62, 74, 52)


def nuevo():
	# ------------------------------------------------ cuerpo base (mismas cajas que las de impacto, biseladas)
	base = {"LowerTorso": (PANTALON, "Fabric"), "UpperTorso": (CHAQUETA, "Fabric"), "Head": (PIEL, "Skin"),
		"UpperArm": (CHAQUETA, "Fabric"), "LowerArm": (CHAQUETA, "Fabric"), "Hand": (GUANTE, "Leather"),
		"UpperLeg": (PANTALON, "Fabric"), "LowerLeg": (PANTALON, "Fabric"), "Foot": (BOTA, "Leather")}
	for n, (tam, c) in PIEZAS.items():
		k = n.replace("Left", "").replace("Right", "")
		col, tipo = base[k]
		if k == "Hand":
			continue    # las manos se hacen aparte (palma + dedos)
		if k == "Head":
			caja(n, "Cabeza", c, tam, col, tipo, bisel=0.11, segs=3)
		elif k == "Foot":
			caja(n, "Bota", (c[0], c[1] + 0.03, c[2] + 0.02), (0.46, 0.26, 0.92), col, tipo, bisel=0.05, segs=2)
		else:
			caja(n, "Base" + k, c, tam, col, tipo, bisel=0.045, segs=2)

	# ------------------------------------------------ CABEZA: gorro de lana, barba, cara con volumen
	H = "Head"
	caja(H, "Gorro", (0, 2.37, 0.02), (0.76, 0.22, 0.84), GORRO, "Fabric", bisel=0.08, segs=3)
	caja(H, "GorroVuelta", (0, 2.255, 0.02), (0.78, 0.11, 0.86), GORRO_OSC, "Fabric", bisel=0.04, segs=2)
	for i in range(7):
		x = -0.3 + i * 0.1
		caja(H, "GorroCanale%d" % i, (x, 2.255, -0.432), (0.025, 0.1, 0.012), GORRO, "Fabric", bisel=0.003)
	caja(H, "GorroRemate", (0, 2.49, 0.02), (0.3, 0.05, 0.34), GORRO_OSC, "Fabric", bisel=0.02)
	caja(H, "PeloNuca", (0, 2.12, 0.385), (0.56, 0.16, 0.035), PELO, "Hair", bisel=0.012)
	espejo(caja, "Head", "Patilla", (0.352, 2.1, -0.12), (0.03, 0.2, 0.14), PELO, "Hair", bisel=0.008)
	H_ = lambda nombre, *a, **k: caja(H, nombre, *a, **k)
	espejo(caja, "Head", "Oreja", (0.37, 2.04, 0.02), (0.07, 0.2, 0.14), PIEL_OSC, "Skin", bisel=0.02)
	# ojos: blanco, iris y párpado
	espejo(caja, "Head", "Ojo", (0.15, 2.075, -0.392), (0.13, 0.07, 0.02), BLANCO_OJO, "Eye", bisel=0.006)
	espejo(caja, "Head", "Iris", (0.14, 2.075, -0.401), (0.055, 0.065, 0.012), IRIS, "Eye", bisel=0.004)
	espejo(caja, "Head", "Pupila", (0.14, 2.075, -0.407), (0.025, 0.03, 0.004), (16, 16, 16), "Eye", bisel=0.0)
	espejo(caja, "Head", "Parpado", (0.15, 2.115, -0.398), (0.14, 0.022, 0.024), PIEL_OSC, "Skin", bisel=0.004)
	espejo(caja, "Head", "Ceja", (0.155, 2.165, -0.402), (0.19, 0.045, 0.03), PELO, "Hair", rot=(0, 0, -8), bisel=0.008)
	# nariz: puente y punta
	H_("NarizPuente", (0, 2.03, -0.41), (0.085, 0.15, 0.06), PIEL_OSC, "Skin", bisel=0.015)
	H_("NarizPunta", (0, 1.965, -0.43), (0.11, 0.06, 0.06), PIEL_OSC, "Skin", bisel=0.015)
	# barba corta: mentón, mandíbula, bigote; boca
	H_("Barba", (0, 1.72, -0.31), (0.62, 0.17, 0.2), BARBA, "Hair", bisel=0.04, segs=2)
	espejo(caja, "Head", "Mandibula", (0.3, 1.83, -0.18), (0.11, 0.3, 0.36), BARBA, "Hair", bisel=0.03)
	H_("Bigote", (0, 1.875, -0.405), (0.28, 0.05, 0.04), BARBA, "Hair", bisel=0.01)
	H_("Boca", (0, 1.825, -0.395), (0.15, 0.03, 0.02), (112, 62, 56), "Skin", bisel=0.005)
	H_("Cicatriz", (-0.21, 2.13, -0.404), (0.012, 0.11, 0.008), (205, 150, 135), "Skin", rot=(0, 0, 25), bisel=0.0)

	# ------------------------------------------------ CUELLO: pañuelo (shemagh) y cuello de la chaqueta
	T = "UpperTorso"
	caja(T, "CuelloChaqueta", (0, 1.64, 0.12), (0.86, 0.18, 0.56), CHAQUETA_OSC, "Fabric", bisel=0.03)
	caja(T, "Panuelo", (0, 1.62, -0.06), (0.8, 0.15, 0.62), PANUELO, "Fabric", bisel=0.05, segs=2)
	for i, y in enumerate((1.58, 1.66)):
		caja(T, "PanueloRaya%d" % i, (0, y, -0.375), (0.62, 0.018, 0.01), PANUELO_OSC, "Fabric", bisel=0.0)
	caja(T, "PanueloNudo", (0.05, 1.5, -0.47), (0.2, 0.16, 0.08), PANUELO, "Fabric", rot=(0, 0, 12), bisel=0.03)
	caja(T, "PanueloPunta", (0.02, 1.36, -0.47), (0.16, 0.18, 0.04), PANUELO_OSC, "Fabric", rot=(0, 0, 18), bisel=0.02)

	# ------------------------------------------------ CHALECO (porta-placas) sobre la chaqueta
	caja(T, "ChalecoDelante", (0, 0.93, -0.41), (0.96, 0.86, 0.08), CHALECO, "Fabric", bisel=0.025, segs=2)
	caja(T, "ChalecoDetras", (0, 0.93, 0.41), (0.96, 0.86, 0.08), CHALECO, "Fabric", bisel=0.025, segs=2)
	espejo(caja, "UpperTorso", "Faja", (0.715, 0.72, 0), (0.04, 0.36, 0.86), CHALECO_OSC, "Fabric", bisel=0.01)
	espejo(caja, "UpperTorso", "Hombrera", (0.36, 1.585, 0), (0.24, 0.07, 0.84), CHALECO, "Fabric", bisel=0.02)
	espejo(caja, "UpperTorso", "HombreraAcolchada", (0.36, 1.6, -0.25), (0.22, 0.06, 0.2), CHALECO_OSC, "Fabric", bisel=0.02)
	for i, y in enumerate((1.02, 1.1, 1.18)):
		caja(T, "Molle%d" % i, (0, y, -0.455), (0.9, 0.028, 0.012), CINTA, "Fabric", bisel=0.0)
	caja(T, "Etiqueta", (0, 1.27, -0.455), (0.36, 0.085, 0.01), CHALECO_OSC, "Fabric", bisel=0.0)
	caja(T, "Parche", (-0.27, 1.27, -0.457), (0.12, 0.085, 0.012), NARANJA, "Fabric", bisel=0.0)
	# tres portacargadores con solapa y goma
	for i, x in enumerate((-0.17, 0.07, 0.31)):
		caja(T, "Portacargador%d" % i, (x, 0.66, -0.5), (0.22, 0.32, 0.12), CHALECO, "Fabric", bisel=0.02, segs=2)
		caja(T, "Solapa%d" % i, (x, 0.83, -0.505), (0.23, 0.05, 0.135), CHALECO_OSC, "Fabric", bisel=0.012)
		caja(T, "Goma%d" % i, (x, 0.7, -0.563), (0.03, 0.22, 0.012), NEGRO, "Rubber", bisel=0.0)
	# radio con antena (derecha, arriba)
	caja(T, "Radio", (0.33, 1.13, -0.5), (0.16, 0.26, 0.1), NEGRO, "Plastic", bisel=0.015)
	caja(T, "RadioBoton", (0.33, 1.06, -0.553), (0.08, 0.04, 0.01), (70, 70, 72), "Plastic", bisel=0.0)
	cil(T, "Antena", (0.37, 1.45, -0.5), 0.03, 0.4, NEGRO, "Rubber", segs=6, bisel=0.0)
	# vaina del cuchillo (el cuchillo va aquí, empuñadura abajo: Armas.holster("Cuchillo"))
	caja(T, "Vaina", (-0.42, 0.98, -0.475), (0.11, 0.6, 0.05), NEGRO, "Leather", bisel=0.012)
	for i, y in enumerate((0.8, 1.15)):
		caja(T, "VainaCinta%d" % i, (-0.42, y, -0.5), (0.14, 0.04, 0.012), CINTA, "Fabric", bisel=0.0)
	# bajo de la chaqueta (se ve debajo del chaleco) y cremallera
	caja(T, "Bajo", (0, 0.27, 0), (1.44, 0.1, 0.76), CHAQUETA_OSC, "Fabric", bisel=0.02)

	# ------------------------------------------------ BRAZOS: costuras, parches, coderas, puños
	espejo(caja, "UpperArm", "Costura", (1.112, 0.9, 0), (0.01, 0.95, 0.03), CHAQUETA_OSC, "Fabric", bisel=0.0)
	caja("RightUpperArm", "ParcheBrazo", (1.115, 1.12, -0.01), (0.012, 0.2, 0.24), CHALECO_OSC, "Fabric", bisel=0.0)
	caja("RightUpperArm", "ParcheBrazoCruz", (1.122, 1.12, -0.01), (0.006, 0.1, 0.03), ROJO, "Fabric", bisel=0.0)
	caja("RightUpperArm", "ParcheBrazoCruz2", (1.122, 1.12, -0.01), (0.006, 0.03, 0.1), ROJO, "Fabric", bisel=0.0)
	caja("LeftUpperArm", "BolsilloManga", (-1.115, 1.03, -0.03), (0.016, 0.24, 0.17), CHAQUETA_OSC, "Fabric", bisel=0.004)
	caja("LeftUpperArm", "BolsilloMangaSolapa", (-1.12, 1.15, -0.03), (0.02, 0.05, 0.19), CHAQUETA_OSC, "Fabric", bisel=0.004)
	caja("LeftUpperArm", "Boligrafo", (-1.124, 1.18, 0.02), (0.012, 0.09, 0.02), (40, 60, 120), "Plastic", bisel=0.0)
	espejo(caja, "LowerArm", "Codera", (0.92, 0.24, 0.18), (0.32, 0.26, 0.07), NEGRO, "Rubber", bisel=0.025, segs=2)
	espejo(caja, "LowerArm", "CoderaCinta", (0.92, 0.24, 0.0), (0.36, 0.04, 0.4), NEGRO, "Rubber", bisel=0.008)
	espejo(caja, "LowerArm", "Puno", (0.92, -0.53, 0), (0.37, 0.12, 0.41), CHAQUETA_OSC, "Fabric", bisel=0.02)
	espejo(caja, "LowerArm", "PunoVelcro", (1.095, -0.53, -0.05), (0.02, 0.08, 0.16), CHAQUETA_OSC, "Fabric", bisel=0.004)

	# ------------------------------------------------ MANOS: guante con palma, cuatro dedos, pulgar y nudillos
	for lado, s in (("Right", 1), ("Left", -1)):
		P = lado + "Hand"
		x = 0.92 * s
		caja(P, "Palma", (x, -0.685, 0), (0.28, 0.2, 0.22), GUANTE, "Leather", bisel=0.03, segs=2)
		caja(P, "PunoGuante", (x, -0.6, 0), (0.3, 0.06, 0.24), GUANTE_OSC, "Leather", bisel=0.015)
		for i in range(4):
			z = -0.0825 + i * 0.055
			caja(P, "Dedo%d" % i, (x - 0.01 * s, -0.885, z), (0.24, 0.21, 0.05), GUANTE, "Leather", bisel=0.014)
		caja(P, "Nudillos", (x + 0.135 * s, -0.795, 0), (0.035, 0.07, 0.21), GUANTE_OSC, "Rubber", bisel=0.012)
		caja(P, "Pulgar", (x - 0.06 * s, -0.79, -0.13), (0.11, 0.17, 0.06), GUANTE, "Leather", rot=(12, 0, 0), bisel=0.02)

	# ------------------------------------------------ CINTURÓN y bolsas
	L = "LowerTorso"
	caja(L, "Cinturon", (0, 0.12, 0), (1.26, 0.16, 0.72), CHALECO_OSC, "Fabric", bisel=0.02)
	caja(L, "Hebilla", (0, 0.12, -0.37), (0.2, 0.13, 0.04), NEGRO, "Plastic", bisel=0.01)
	caja(L, "HebillaCentro", (0, 0.12, -0.393), (0.08, 0.05, 0.01), METAL, "Metal", bisel=0.0)
	caja(L, "BolsaCargadores", (-0.45, 0.0, -0.4), (0.24, 0.24, 0.1), CHALECO, "Fabric", bisel=0.015)
	caja(L, "BolsaCargadoresSolapa", (-0.45, 0.115, -0.41), (0.25, 0.04, 0.115), CHALECO_OSC, "Fabric", bisel=0.008)
	caja(L, "Botiquin", (0.38, 0.0, 0.4), (0.26, 0.22, 0.12), CHALECO, "Fabric", bisel=0.015)
	caja(L, "BotiquinCruz", (0.38, 0.0, 0.462), (0.06, 0.15, 0.006), ROJO, "Fabric", bisel=0.0)
	caja(L, "BotiquinCruz2", (0.38, 0.0, 0.462), (0.15, 0.06, 0.006), ROJO, "Fabric", bisel=0.0)
	caja(L, "Cantimplora", (-0.38, -0.02, 0.41), (0.24, 0.28, 0.14), MOCHILA_OSC, "Fabric", bisel=0.03)
	caja(L, "CantimploraTapa", (-0.38, 0.14, 0.41), (0.08, 0.05, 0.08), NEGRO, "Plastic", bisel=0.008)
	espejo(caja, "LowerTorso", "BolsilloCadera", (0.33, -0.17, -0.335), (0.3, 0.06, 0.012), PANTALON_OSC, "Fabric", bisel=0.0)

	# ------------------------------------------------ PIERNAS: bolsillo de carga, rodilleras, funda de la pistola
	caja("LeftUpperLeg", "BolsilloCarga", (-0.615, -1.0, 0.02), (0.06, 0.38, 0.32), PANTALON_OSC, "Fabric", bisel=0.015)
	caja("LeftUpperLeg", "BolsilloCargaSolapa", (-0.625, -0.8, 0.02), (0.07, 0.07, 0.34), PANTALON_OSC, "Fabric", bisel=0.012)
	espejo(caja, "UpperLeg", "CosturaPierna", (0.592, -0.9, -0.18), (0.01, 1.2, 0.02), PANTALON_OSC, "Fabric", bisel=0.0)
	espejo(caja, "LowerLeg", "Rodillera", (0.33, -1.74, -0.25), (0.36, 0.34, 0.08), NEGRO, "Rubber", bisel=0.03, segs=2)
	espejo(caja, "LowerLeg", "RodilleraCinta", (0.33, -1.74, 0.0), (0.46, 0.05, 0.48), NEGRO, "Rubber", bisel=0.008)
	# funda de la pistola en el muslo derecho (la pistola al 65 %: Armas.holster("Pistola") = mango en
	# (0.66, -0.45, 0.33) respecto al centro, cañón hacia abajo y la corredera hacia delante)
	R = "RightUpperLeg"
	caja(R, "Funda", (0.675, -0.74, 0.19), (0.17, 0.5, 0.38), NEGRO, "Leather", bisel=0.025, segs=2)
	caja(R, "FundaBoca", (0.675, -0.5, 0.19), (0.19, 0.04, 0.4), (20, 20, 20), "Leather", bisel=0.01)
	caja(R, "FundaPlaca", (0.62, -0.62, 0.14), (0.04, 0.5, 0.3), NEGRO, "Plastic", bisel=0.01)
	caja(R, "FundaCinta", (0.33, -0.95, 0.0), (0.56, 0.05, 0.6), NEGRO, "Fabric", bisel=0.008)
	caja(R, "FundaCintaHebilla", (0.33, -0.95, -0.302), (0.06, 0.06, 0.012), METAL, "Metal", bisel=0.0)

	# ------------------------------------------------ BOTAS: caña acolchada, cordones, puntera, suela, talón
	for lado, s in (("Right", 1), ("Left", -1)):
		x = 0.33 * s
		LL = lado + "LowerLeg"
		F = lado + "Foot"
		caja(LL, "Cana", (x, -2.6, 0), (0.48, 0.4, 0.5), BOTA, "Leather", bisel=0.03, segs=2)
		caja(LL, "CanaCollar", (x, -2.41, 0), (0.5, 0.07, 0.52), BOTA_OSC, "Leather", bisel=0.02)
		caja(LL, "Lengueta", (x, -2.58, -0.255), (0.18, 0.4, 0.012), BOTA_OSC, "Leather", bisel=0.0)
		for i in range(4):
			y = -2.72 + i * 0.09
			caja(LL, "Cordon%d" % i, (x, y, -0.264), (0.2, 0.018, 0.012), (40, 36, 30), "Fabric", rot=(0, 0, 14 if i % 2 else -14), bisel=0.0)
			espejo_x = (x + 0.11, x - 0.11)
			for j, xx in enumerate(espejo_x):
				caja(LL, "Ojal%d%d" % (i, j), (xx, y, -0.258), (0.025, 0.025, 0.01), METAL, "Metal", bisel=0.0)
		caja(F, "Puntera", (x, -2.97, -0.58), (0.47, 0.2, 0.17), BOTA_OSC, "Leather", bisel=0.05, segs=2)
		caja(F, "Suela", (x, -3.07, -0.18), (0.5, 0.08, 1.04), SUELA, "Rubber", bisel=0.02)
		caja(F, "Tacon", (x, -3.04, 0.2), (0.49, 0.12, 0.26), SUELA, "Rubber", bisel=0.015)
		for i in range(3):
			z = -0.42 + i * 0.1
			caja(F, "CordonPie%d" % i, (x, -2.81, z), (0.18, 0.012, 0.02), (40, 36, 30), "Fabric", rot=(0, 14 if i % 2 else -14, 0), bisel=0.0)

	# ------------------------------------------------ MOCHILA (el rifle va colgado detrás, a z ~0.97: no pasar de ~0.9)
	M = "UpperTorso"
	caja(M, "Mochila", (0, 0.93, 0.66), (1.06, 1.12, 0.44), MOCHILA, "Fabric", bisel=0.06, segs=2)
	caja(M, "MochilaTapa", (0, 1.53, 0.64), (1.0, 0.16, 0.5), MOCHILA_OSC, "Fabric", bisel=0.05, segs=2)
	caja(M, "MochilaBolsillo", (0, 0.72, 0.9), (0.66, 0.46, 0.08), MOCHILA_OSC, "Fabric", bisel=0.03)
	caja(M, "MochilaCremallera", (0, 0.94, 0.942), (0.56, 0.018, 0.01), NEGRO, "Plastic", bisel=0.0)
	for i, x in enumerate((-0.28, 0.28)):
		caja(M, "MochilaCorrea%d" % i, (x, 1.28, 0.885), (0.06, 0.48, 0.012), NEGRO, "Fabric", bisel=0.0)
		caja(M, "MochilaHebilla%d" % i, (x, 1.1, 0.893), (0.08, 0.06, 0.014), (60, 60, 62), "Plastic", bisel=0.0)
	espejo(caja, "UpperTorso", "MochilaCompresion", (0.535, 0.9, 0.66), (0.012, 0.04, 0.4), NEGRO, "Fabric", bisel=0.0)
	cil(M, "Botella", (-0.62, 0.78, 0.66), 0.2, 0.42, (80, 96, 70), "Plastic", segs=12, bisel=0.01)
	cil(M, "BotellaTapon", (-0.62, 1.02, 0.66), 0.12, 0.07, NEGRO, "Plastic", segs=10, bisel=0.0)
	cil(M, "Esterilla", (0, 0.29, 0.66), 0.3, 1.2, ESTERILLA, "Fabric", eje="x", segs=14, bisel=0.01)
	for i, x in enumerate((-0.4, 0.4)):
		cil(M, "EsterillaCinta%d" % i, (x, 0.29, 0.66), 0.315, 0.04, NEGRO, "Fabric", eje="x", segs=14, bisel=0.0)
	caja(M, "Asa", (0, 1.63, 0.6), (0.2, 0.04, 0.05), NEGRO, "Fabric", bisel=0.0)
	cil(M, "Mosqueton", (0.56, 1.25, 0.82), 0.09, 0.012, METAL, "Metal", eje="x", segs=10, bisel=0.0)
	# tirantes de la mochila por encima de los hombros, con la cinta del pecho
	espejo(caja, "UpperTorso", "Tirante", (0.47, 1.45, -0.44), (0.1, 0.32, 0.03), MOCHILA_OSC, "Fabric", bisel=0.008)
	espejo(caja, "UpperTorso", "TiranteHombro", (0.47, 1.6, 0.1), (0.1, 0.03, 0.7), MOCHILA_OSC, "Fabric", bisel=0.008)
	caja(M, "CintaPecho", (0, 1.38, -0.465), (0.86, 0.035, 0.012), NEGRO, "Fabric", bisel=0.0)
	caja(M, "CintaPechoHebilla", (0, 1.38, -0.472), (0.08, 0.05, 0.012), (60, 60, 62), "Plastic", bisel=0.0)


# ================================================================= EL DE ANTES (para comparar)
def viejo(ruta):
	import re
	txt = open(ruta).read()
	def v3(s):
		return tuple(float(x) for x in s.split(","))
	piezas = {}
	for m in re.finditer(r'"(\w+)": \[Vector3\(([^)]*)\), Color8\(([^)]*)\), "(\w+)", Vector3\(([^)]*)\)\]', txt):
		piezas[m.group(1)] = (v3(m.group(2)), tuple(int(x) for x in m.group(3).split(",")), m.group(4), v3(m.group(5)))
	tipo = lambda t: t if t in TIPOS else ("Skin" if t == "SmoothPlastic" else "Fabric")
	for n, (tam, col, t, c) in piezas.items():
		if n == "Head":
			cil(n, "Cabeza", c, tam[2], tam[1], col, "Skin", segs=20, bisel=0.0)
			vacios[n].children[-1].scale = (1, 1, 1)
			ob = vacios[n].children[-1]
			for v in ob.data.vertices:
				v.co.x *= tam[0] / tam[2]
		else:
			caja(n, "Base" + n, c, tam, col, tipo(t), bisel=0.0)
	for m in re.finditer(r'\["(\w+)", "(\w+)", Vector3\(([^)]*)\), Vector3\(([^)]*)\), Color8\(([^)]*)\), "(\w+)", ([-\d.]+), "(\w+)", ([\d.]+)\]', txt):
		nom, parte, pos, tam, col, t, rz, forma = m.group(1), m.group(2), v3(m.group(3)), v3(m.group(4)), tuple(int(x) for x in m.group(5).split(",")), m.group(6), float(m.group(7)), m.group(8)
		if forma == "cylx":
			cil(parte, nom, pos, tam[1], tam[0], col, tipo(t), eje="x", segs=16, bisel=0.0)
		else:
			caja(parte, nom, pos, tam, col, tipo(t), rot=(0, 0, math.degrees(rz)), bisel=0.0)


if arg("viejo"):
	viejo(arg("gd", "/home/claude/v5/scripts/jugador/rig_personaje.gd"))
else:
	nuevo()
print("PIEZAS_MODELO", cuenta[0])


# ================================================================= juntar por pieza y material (menos llamadas de dibujo)
def juntar():
	dg = bpy.context.evaluated_depsgraph_get()
	for parte, e in vacios.items():
		grupos = {}
		for ob in list(e.children):
			grupos.setdefault(ob.active_material.name, []).append(ob)
		for i, (mn, obs) in enumerate(sorted(grupos.items())):
			bm = bmesh.new()
			for ob in obs:
				me = ob.evaluated_get(dg).to_mesh()
				tmp = bpy.data.meshes.new("tmp")
				tmp_bm = bmesh.new()
				tmp_bm.from_mesh(me)
				tmp_bm.to_mesh(tmp)
				tmp_bm.free()
				bm.from_mesh(tmp)
				bpy.data.meshes.remove(tmp)
				ob.evaluated_get(dg).to_mesh_clear()
			me2 = bpy.data.meshes.new("M_%s_%d" % (parte, i))
			bm.to_mesh(me2)
			bm.free()
			me2.materials.append(bpy.data.materials[mn])
			nuevo_ob = bpy.data.objects.new("M_%s_%d" % (parte, i), me2)
			esc.collection.objects.link(nuevo_ob)
			nuevo_ob.parent = e
			for ob in obs:
				bpy.data.objects.remove(ob)


if arg("glb") or arg("juntar"):
	juntar()

if arg("blend"):
	bpy.ops.wm.save_as_mainfile(filepath=arg("blend"))

if arg("glb"):
	bpy.ops.export_scene.gltf(filepath=arg("glb"), export_format='GLB', export_apply=True, export_yup=True,
		use_selection=False, export_materials='EXPORT', export_normals=True, export_texcoords=False,
		export_cameras=False, export_lights=False)
	print("GLB", arg("glb"))


# ================================================================= renders de revisión
def render(prefijo):
	esc.render.engine = 'CYCLES'
	esc.cycles.device = 'CPU'
	esc.cycles.samples = int(arg("muestras", "48"))
	esc.cycles.use_denoising = True
	esc.render.resolution_x = int(arg("ancho", "520"))
	esc.render.resolution_y = int(arg("alto", "860"))
	esc.render.film_transparent = False
	w = bpy.data.worlds.new("w")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.62, 1)
	w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
	esc.world = w
	sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", 'SUN'))
	sol.data.energy = 3.2
	sol.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
	esc.collection.objects.link(sol)
	rel = bpy.data.objects.new("rel", bpy.data.lights.new("rel", 'SUN'))
	rel.data.energy = 1.2
	rel.rotation_euler = (math.radians(60), 0, math.radians(200))
	esc.collection.objects.link(rel)
	# suelo
	bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, -3.11))
	bpy.context.active_object.data.materials.append(material((150, 150, 150), "Plastic"))
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
	esc.collection.objects.link(cam)
	esc.camera = cam
	cam.data.lens = 85
	vistas = [v for v in arg("vistas", "0,0;35,0;90,0;180,0;-35,0").split(";")]
	for i, v in enumerate(vistas):
		az, alt, *rest = [float(x) for x in v.split(",")]
		dist = rest[0] if rest else 26.0
		zf = rest[1] if len(rest) > 1 else -0.25
		# az = 0: de frente (el personaje mira a -Z de Godot = +Y de Blender)
		a = math.radians(az)
		pos = Vector((math.sin(a) * dist, math.cos(a) * dist, zf + math.radians(alt) * dist))
		cam.location = pos
		d = Vector((0, 0, zf)) - pos
		cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
		esc.render.filepath = "%s_%02d.png" % (prefijo, i)
		bpy.ops.render.render(write_still=True)


if arg("render"):
	render(arg("render"))

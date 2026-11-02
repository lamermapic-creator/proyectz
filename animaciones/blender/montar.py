# Monta en Blender el piloto R15 (armadura + piezas) y la moto a partir del JSON que exporta
# tests/moto.gd --modo=exportar. Todo en coordenadas de Godot (Y arriba, -Z delante, studs) dentro de un
# vacío "Godot" girado 90° en X para verlo con Z arriba en Blender.
# Uso: blender -b -P montar.py -- rig_moto.json salida.blend
import bpy, json, sys, math
from mathutils import Matrix, Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
D = json.load(open(args[0]))
SALIDA = args[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
esc = bpy.context.scene


def tf(a):
	# Transform3D de Godot (columnas x, y, z + origen) -> Matrix 4x4
	m = Matrix.Identity(4)
	for c in range(3):
		for r in range(3):
			m[r][c] = a[c * 3 + r]
	m[0][3], m[1][3], m[2][3] = a[9], a[10], a[11]
	return m


def tras(v):
	return Matrix.Translation(Vector(v))


godot = bpy.data.objects.new("Godot", None)
esc.collection.objects.link(godot)
godot.rotation_euler = (math.radians(90), 0, 0)

mats = {}
def material(col):
	k = tuple(round(c, 3) for c in col)
	if k not in mats:
		m = bpy.data.materials.new("m%d" % len(mats))
		m.diffuse_color = (col[0], col[1], col[2], 1)
		m.use_nodes = True
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1)
		bsdf.inputs["Roughness"].default_value = 0.8
		mats[k] = m
	return mats[k]


def malla(datos, nombre):
	caras = datos["caras"]
	verts = [Vector(v) for v in caras]
	tris = [(i, i + 1, i + 2) for i in range(0, len(verts) - 2, 3)]
	me = bpy.data.meshes.new(nombre)
	me.from_pydata(verts, [], tris)
	me.update()
	me.materials.append(material(datos["color"]))
	ob = bpy.data.objects.new(nombre, me)
	esc.collection.objects.link(ob)
	return ob


# ---------------------------------------------------------------- armadura
# reposo: pieza1 = pieza0 * C0 * C1^-1 (sin giro). Hueso de cada motor en la articulación (pieza0 * C0).
# Los huesos de brazos y piernas apuntan hacia abajo (-Y): R = giro de 180° en Z; el resto hacia arriba.
ABAJO = ("Shoulder", "Elbow", "Wrist", "Hip", "Knee", "Ankle")
LARGO = {"Root": 0.3, "Waist": 1.18, "Neck": 0.8, "Shoulder": 1.03, "Elbow": 0.95, "Wrist": 0.4,
	"Hip": 1.275, "Knee": 1.25, "Ankle": 0.35}
prest = {"HumanoidRootPart": Matrix.Identity(4)}
info = {}
for m in D["motores"]:
	j = prest[m["p0"]] @ tras(m["c0"])
	prest[m["p1"]] = j @ tras([-c for c in m["c1"]])
	r = Matrix.Rotation(math.pi, 4, 'Z') if m["nombre"].endswith(ABAJO) else Matrix.Identity(4)
	tipo = next((k for k in LARGO if m["nombre"].endswith(k)), "Root")
	info[m["nombre"]] = {"j": j, "r": r, "largo": LARGO[tipo], "m": m}

arm_d = bpy.data.armatures.new("Piloto")
arm = bpy.data.objects.new("Piloto", arm_d)
esc.collection.objects.link(arm)
arm.parent = godot
arm.matrix_parent_inverse = Matrix.Identity(4)
arm.matrix_basis = tf(D["raiz"])
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
hueso_de_pieza = {}
for m in D["motores"]:
	i = info[m["nombre"]]
	eb = arm_d.edit_bones.new(m["nombre"])
	eb.head = (0, 0, 0)
	eb.tail = (0, i["largo"], 0)
	eb.matrix = i["j"] @ i["r"]
	padre = next((x["nombre"] for x in D["motores"] if x["p1"] == m["p0"]), None)
	if padre:
		eb.parent = arm_d.edit_bones[padre]
	hueso_de_pieza[m["p1"]] = m["nombre"]
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- piezas del piloto (en reposo, emparentadas al hueso)
piezas = {k: tf(v) for k, v in D["piezas"].items()}
for k, md in enumerate(D["mallas_rig"]):
	pieza = md["base"]
	if pieza not in hueso_de_pieza:
		continue
	ob = malla(md, "%s_%d" % (md["nombre"], k))
	local = piezas[pieza].inverted() @ tf(md["t"])
	ob.parent = arm
	ob.parent_type = 'BONE'
	ob.parent_bone = hueso_de_pieza[pieza]
	bpy.context.view_layer.update()
	ob.matrix_world = godot.matrix_world @ tf(D["raiz"]) @ prest[pieza] @ local

# ---------------------------------------------------------------- moto (tal cual, en el mundo)
for k, md in enumerate(D["mallas_moto"]):
	ob = malla(md, "moto_%s_%d" % (md["nombre"], k))
	ob.parent = godot
	ob.matrix_parent_inverse = Matrix.Identity(4)
	ob.matrix_basis = tf(md["t"])

# puños del manillar (vacíos de referencia)
for lado in ("L", "R"):
	e = bpy.data.objects.new("puno" + lado, None)
	esc.collection.objects.link(e)
	e.parent = godot
	e.matrix_basis = tf(D["puno" + lado])
	e.empty_display_size = 0.2


# ---------------------------------------------------------------- pose de conducir (la del juego)
def poner_T(nombre, T):
	i = info[nombre]
	pb = arm.pose.bones[nombre]
	pb.rotation_mode = 'QUATERNION'
	b = i["r"].inverted() @ T @ i["r"]
	pb.matrix_basis = b

for m in D["motores"]:
	q = Quaternion((m["q"][3], m["q"][0], m["q"][1], m["q"][2]))
	T = q.to_matrix().to_4x4()
	T.translation = Vector(m["o"])
	poner_T(m["nombre"], T)
bpy.context.view_layer.update()

# datos para los scripts de animación
esc["datos_rig"] = json.dumps({"r": {n: [list(r) for r in info[n]["r"]] for n in info},
	"handle_en_mano": D["handle_en_mano"], "muzzle": D["muzzle"], "muneca_en_mano": D["muneca_en_mano"],
	"raiz": D["raiz"], "moto": D["moto"], "yaw": D["yaw"], "arma": D["arma"],
	"base": {m["nombre"]: [m["q"], m["o"]] for m in D["motores"]},
	"grip": D.get("grip"), "grip_att": D.get("grip_att"), "puntos": D.get("puntos", {}),
	"poses_viejas": D.get("poses_viejas", {})})
bpy.ops.wm.save_as_mainfile(filepath=SALIDA)
print("MONTADO", len(D["mallas_rig"]), len(D["mallas_moto"]))

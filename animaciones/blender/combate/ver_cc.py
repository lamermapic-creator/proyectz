# Vista previa en Blender del combate cuerpo a cuerpo (diseno_cc.py) sobre el superviviente sin arma (cuerpo.blend,
# montado con ../montar.py desde el juego: ver ../LEEME.md). Brazos y piernas con IK de dos huesos, como el juego.
# Uso:
#   blender -b cuerpo.blend -P combate/ver_cc.py -- "<poses>" "<vistas az,alt,dist;...>" <carpeta>
#   poses, separadas por ';':  guardia:manos   bloqueo:manos   empujon:manos:<variante>:<u>   patada:<variante>:<u>
#   puno:<variante>:<u>   pisoton:<variante>:<u>   suelo:<clase>:<u>
#   (u de 0 a 1; "patada:0:0,0.28,0.42,0.6" = varias u de la misma acción)
# Sale un PNG por pose y vista en <carpeta>/cc_<n>_<vista>.png (Workbench, rápido).
import bpy, sys, os, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diseno_cc as DC
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
lista = args[0].split(";")
vistas = [tuple(float(x) for x in v.split(",")) for v in args[1].split(";")]
carpeta = args[2]

esc = bpy.context.scene
arm = bpy.data.objects["Piloto"]
DR = json.loads(esc["datos_rig"])
R = {n: Matrix(v) for n, v in DR["r"].items()}
MUNECA = Vector(DR["muneca_en_mano"])
LU, LF = 1.03, 0.95          # brazo: hombro-codo, codo-muñeca
PU, PF = 1.3, 1.25           # pierna: cadera-rodilla, rodilla-tobillo
CADERA = {"R": Vector((0.33, -0.27, 0)), "L": Vector((-0.33, -0.27, 0))}   # articulación de la cadera (rig en reposo)
SUELO_Y = -3.11


def ang(x, y, z):
	return Matrix.Rotation(x, 4, 'X') @ Matrix.Rotation(y, 4, 'Y') @ Matrix.Rotation(z, 4, 'Z')


def cf(x, y, z):
	return Matrix.Translation((x, y, z))


def poner_T(n, T):
	arm.pose.bones[n].matrix_basis = R[n].inverted() @ T @ R[n]


def upd():
	bpy.context.view_layer.update()


def reposo():
	for pb in arm.pose.bones:
		pb.matrix_basis = Matrix.Identity(4)
	upd()


def hueso_dir(nombre, y, plano_n):
	pb = arm.pose.bones[nombre]
	y = y.normalized()
	x = plano_n.cross(y)
	if x.length < 1e-4:
		x = Vector((1, 0, 0))
	x.normalize()
	z = x.cross(y)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


def dos_huesos(S, obj, polo, a, b):
	v = obj - S
	d = min(v.length, a + b - 1e-3)
	dirv = v.normalized()
	ca = max(-1.0, min(1.0, (a * a + d * d - b * b) / (2 * a * d)))
	sa = math.sqrt(max(0.0, 1 - ca * ca))
	n = (polo - S) - dirv * (polo - S).dot(dirv)
	n = n.normalized() if n.length > 1e-4 else Vector((0, -1, 0))
	return S + dirv * (a * ca) + n * (a * sa), S + dirv * d, dirv.cross(n), n


def ik_brazo(lado, mano_p, polo, rot=None):
	nombre = "Right" if lado == "R" else "Left"
	S = arm.pose.bones[nombre + "Shoulder"].head.copy()
	# como el juego (modo "pos"): la muñeca queda 0,22 antes del centro de la mano
	muneca = mano_p - (mano_p - S).normalized() * 0.22
	E, W, plano, _ = dos_huesos(S, muneca, polo, LU, LF)
	hueso_dir(nombre + "Shoulder", E - S, plano)
	hueso_dir(nombre + "Elbow", W - arm.pose.bones[nombre + "Elbow"].head, plano)
	pb = arm.pose.bones[nombre + "Wrist"]
	m = (rot.to_4x4() @ R[nombre + "Wrist"]) if rot is not None else arm.pose.bones[nombre + "Elbow"].matrix.copy()
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


def ik_pierna(lado, tobillo, polo, pie_m):
	nombre = "Right" if lado == "R" else "Left"
	S = arm.pose.bones[nombre + "Hip"].head.copy()
	E, W, _, n = dos_huesos(S, tobillo, polo, PU, PF)
	hueso_dir(nombre + "Hip", E - S, n)
	hueso_dir(nombre + "Knee", W - arm.pose.bones[nombre + "Knee"].head, n)
	pb = arm.pose.bones[nombre + "Ankle"]
	m = pie_m @ R[nombre + "Ankle"]
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


def base_mano(c, k):
	"""orientación de la mano (marco de Godot: Y = hacia la muñeca, Z = contra el dorso)"""
	if c.get(k + "rw", 0.0) < 0.5 or (k + "dx") not in c:
		return None
	d = Vector((c[k + "dx"], c[k + "dy"], c[k + "dz"])).normalized()
	b = Vector((c[k + "bx"], c[k + "by"], c[k + "bz"])).normalized()
	y = -d
	z = (-b - y * (-b).dot(y)).normalized()
	x = y.cross(z)
	return Matrix((x, y, z)).transposed()


def poner(c):
	"""una pose (canales de diseno_cc): cuerpo, brazos y pierna que patea"""
	reposo()
	g = lambda k: c.get(k, 0.0)
	poner_T("Root", cf(g("cad_x"), g("cad_y"), g("cad_z")) @ ang(g("pel_p"), g("pel_y"), g("pel_r")))
	poner_T("Waist", ang(0, g("cin_y"), 0) @ ang(g("cin_p"), 0, g("cin_r")))
	poner_T("Neck", ang(0, g("cue_y"), 0) @ ang(g("cue_p"), 0, g("cue_r")))
	upd()
	pecho = (arm.pose.bones["Waist"].matrix @ cf(0, 0.69, 0)).translation
	for s, k, kp in (("R", "mr_", "pr_"), ("L", "ml_", "pl_")):
		if (k + "x") in c:
			p = pecho + Vector((c[k + "x"], c[k + "y"], c[k + "z"]))
			polo = pecho + Vector((c[kp + "x"], c[kp + "y"], c[kp + "z"]))
			ik_brazo(s, p, polo, base_mano(c, k))
	# piernas: las dos en el suelo (bajan con la cadera) y la que patea donde diga la animación
	lado_p = c.get("_lado")
	for s in ("R", "L"):
		nombre = "Right" if s == "R" else "Left"
		hip = arm.pose.bones[nombre + "Hip"].head.copy()
		apoyo = Vector((CADERA[s].x, SUELO_Y + 0.29, -0.1))
		pie_m = Matrix.Translation(apoyo) @ cf(0, 0.0, 0)
		tob = apoyo
		w = g("pie_w") if s == lado_p else 0.0
		if w > 0.0:
			rel = Vector((g("pie_x"), g("pie_y"), g("pie_z")))
			kick = hip + rel
			tob = apoyo.lerp(kick, min(1.0, w))
			pie_m = Matrix.Translation(tob) @ ang(g("pie_inc") * w, 0, 0) @ cf(0, -0.15, -0.2)
		else:
			pie_m = Matrix.Translation(tob) @ cf(0, -0.15, -0.2)
		polo = hip + Vector((g("ro_x"), g("ro_y"), g("ro_z"))) if (w > 0 and "ro_z" in c) else hip + Vector((0, 0.5, -6))
		ik_pierna(s, tob, polo, pie_m)


def pose_de(txt):
	p = txt.split(":")
	if p[0] == "guardia":
		return [dict(DC.GUARDIA[p[1]])]
	if p[0] == "bloqueo":
		return [dict(DC.BLOQUEO[p[1]])]
	if p[0] == "empujon":
		a = DC.EMPUJON[p[1]][int(p[2])]
		return [DC.pose_accion(a, float(u)) for u in p[3].split(",")]
	if p[0] == "suelo":
		a = DC.SUELO
		return [DC.pose_accion(a, float(u)) for u in p[2].split(",")]
	if p[0] == "puno":
		a = DC.PUNOS[int(p[1])]
		return [DC.pose_accion(a, float(u)) for u in p[2].split(",")]
	if p[0] in ("patada", "pisoton"):
		a = (DC.PATADA if p[0] == "patada" else DC.PISOTON)[int(p[1])]
		res = []
		for u in p[2].split(","):
			c = DC.pose_accion(a, float(u))
			c["_lado"] = a["lado"]
			res.append(c)
		return res
	raise ValueError(txt)


# escena: Workbench, suelo y cámara
esc.render.engine = 'BLENDER_WORKBENCH'
esc.display.shading.light = 'STUDIO'
esc.display.shading.color_type = 'MATERIAL'
esc.display.shading.show_shadows = True
esc.display.shading.show_cavity = True
esc.render.resolution_x, esc.render.resolution_y = 420, 520
esc.render.resolution_percentage = 100
if "Suelo" not in bpy.data.objects:
	bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
	bpy.context.active_object.name = "Suelo"
bpy.data.objects["Suelo"].location.z = (arm.matrix_world @ Vector((0, SUELO_Y, 0))).z
if "Cam" not in bpy.data.objects:
	cam_d = bpy.data.cameras.new("Cam")
	cam_d.lens = 40
	cam_o = bpy.data.objects.new("Cam", cam_d)
	esc.collection.objects.link(cam_o)
	esc.camera = cam_o
cam = bpy.data.objects["Cam"]
fwd = arm.matrix_world.to_3x3() @ Vector((0, 0, -1))
yaw = math.atan2(fwd.y, fwd.x)
foco = arm.matrix_world @ Vector((0, -0.6, -0.5))
os.makedirs(carpeta, exist_ok=True)
n = 0
for txt in lista:
	for c in pose_de(txt):
		poner(c)
		for i, (az, alt, dist) in enumerate(vistas):
			# az en grados alrededor del cuerpo (0 = desde su derecha, 90 = desde delante)
			a = math.radians(az) + yaw
			d = Vector((math.cos(a), math.sin(a), alt)).normalized()
			cam.location = foco + d * dist
			cam.rotation_euler = (foco - cam.location).to_track_quat('-Z', 'Y').to_euler()
			esc.render.filepath = os.path.join(carpeta, "cc_%02d_%d.png" % (n, i))
			bpy.ops.render.render(write_still=True)
		n += 1
print("HECHO", carpeta, n)

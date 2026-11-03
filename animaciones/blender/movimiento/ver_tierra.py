# Vista previa en Blender de TUMBARSE (por pb) y REPTAR (por fase) de diseno_mov.py.
# Uso: blender -b cuerpo.blend -P mov/ver_tierra.py -- <"t:pb1,pb2,..." | "r:phi1,phi2,..."> <vistas az,alt,dist;...> <prefijo>
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/home/claude/bl")
import diseno_mov as DM
import vista, json
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
modo, lista = args[0].split(":")
vals = [float(x) for x in lista.split(",")]
vistas = [tuple(float(x) for x in v.split(",")) for v in args[1].split(";")]
pref = args[2]
esc = bpy.context.scene
arm = bpy.data.objects["Piloto"]
DR = json.loads(esc["datos_rig"])
R = {n: Matrix(v) for n, v in DR["r"].items()}
M0 = arm.matrix_basis.copy()


def ang(x, y, z):
	return Matrix.Rotation(x, 4, 'X') @ Matrix.Rotation(y, 4, 'Y') @ Matrix.Rotation(z, 4, 'Z')


def cf(x, y, z):
	return Matrix.Translation((x, y, z))


def poner_T(n, T):
	arm.pose.bones[n].matrix_basis = R[n].inverted() @ T @ R[n]


def upd():
	bpy.context.view_layer.update()


def hueso_dir(nombre, y, plano_n):
	pb = arm.pose.bones[nombre]
	y = y.normalized()
	x = plano_n.cross(y)
	x.normalize()
	z = x.cross(y)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


def ik_brazo(lado, muneca, polo):
	LU, LF = 1.03, 0.95
	S = arm.pose.bones[lado + "Shoulder"].head.copy()
	v = muneca - S
	d = min(v.length, LU + LF - 1e-3)
	dirv = v.normalized()
	ca = max(-1.0, min(1.0, (LU * LU + d * d - LF * LF) / (2 * LU * d)))
	sa = math.sqrt(max(0, 1 - ca * ca))
	n = (polo - S) - dirv * (polo - S).dot(dirv)
	n = n.normalized()
	E = S + dirv * (LU * ca) + n * (LU * sa)
	hueso_dir(lado + "Shoulder", E - S, n)
	W = S + dirv * d
	hueso_dir(lado + "Elbow", W - arm.pose.bones[lado + "Elbow"].head, n)


def ik_pierna(lado, tobillo, polo, pie_m):
	LU, LF = 1.3, 1.25
	S = arm.pose.bones[lado + "Hip"].head.copy()
	v = tobillo - S
	d = min(v.length, LU + LF - 1e-3)
	dirv = v.normalized()
	ca = max(-1.0, min(1.0, (LU * LU + d * d - LF * LF) / (2 * LU * d)))
	sa = math.sqrt(max(0.0, 1 - ca * ca))
	n = (polo - S) - dirv * (polo - S).dot(dirv)
	n = n.normalized()
	E = S + dirv * (LU * ca) + n * (LU * sa)
	hueso_dir(lado + "Hip", E - S, n)
	W = S + dirv * d
	hueso_dir(lado + "Knee", W - arm.pose.bones[lado + "Knee"].head, n)
	pb = arm.pose.bones[lado + "Ankle"]
	m = pie_m @ cf(0, 0.15, 0.2) @ R[lado + "Ankle"]
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


def smooth01(x):
	x = max(0.0, min(1.0, x))
	return x * x * (3 - 2 * x)


def pose(pb, phi, reptando):
	for b in arm.pose.bones:
		b.matrix_basis = Matrix.Identity(4)
	centro = 3.1 + (0.45 - 3.1) * smooth01(pb)
	arm.matrix_basis = Matrix.Translation(Vector((0, centro - 3.1, 0))) @ M0   # (en el espacio de Godot del vacío padre)
	baja = DM.tumbar("baja", pb)
	drop = (centro - 0.48) * baja
	inc = DM.tumbar("inclina", pb)
	py = pr = sube = 0.0
	if reptando:
		py = DM.reptar("pelvis_y", phi)
		pr = DM.reptar("pelvis_r", phi)
		sube = DM.reptar("sube", phi)
	poner_T("Root", cf(0, -drop + sube, 0) @ ang(inc, py, pr))
	wy = DM.reptar("cintura_y", phi) if reptando else 0.0
	wr = DM.reptar("cintura_r", phi) if reptando else 0.0
	poner_T("Waist", ang(0, wy, 0) @ ang(DM.tumbar("cintura_p", pb), 0, wr))
	poner_T("Neck", ang(0, DM.reptar("cuello_y", phi) if reptando else 0.0, 0) @ ang(DM.tumbar("cuello_p", pb), 0, 0))
	upd()
	suelo_g = -3.11 - (centro - 3.1)
	# piernas por IK a sitios del suelo, con el mismo cálculo que el juego (Animador, rama "cuerpo a tierra")
	lay = smooth01((pb - 0.45) / 0.55)
	ca = 1.0 if reptando else 0.0
	atras = Vector((0, 0, 1))
	dcha = Vector((1, 0, 0))
	for s in ("L", "R"):
		lado = "Left" if s == "L" else "Right"
		sg = 1.0 if s == "R" else -1.0
		hip = arm.pose.bones[lado + "Hip"].head.copy()
		an_pl = Vector((sg * 0.33, suelo_g + 0.15, -0.18)) + Vector((0, 0.15, 0.2))
		F_pl = Matrix.Translation(Vector((sg * 0.33, suelo_g + 0.15, -0.18)))
		th = -1.75 + (-2.45 + 1.75) * lay
		Rth = Matrix.Rotation(th, 3, 'X')
		h_a = 0.0
		for cz in (-0.5, 0.5):
			for cy in (-0.15, 0.15):
				h_a = max(h_a, -(Rth @ (Vector((0, cy, cz)) - Vector((0, 0.15, 0.2)))).y)
		knee_y = suelo_g + 0.36
		dzk = math.sqrt(max(0.0, 1.69 - (hip.y - knee_y) ** 2))
		knee = Vector((hip.x, knee_y, hip.z)) + atras * dzk + dcha * (sg * 0.08)
		dza = math.sqrt(max(0.0, 1.5625 - (h_a - 0.36) ** 2))
		an_k = knee + atras * dza + Vector((0, h_a - 0.36, 0))
		polo = hip - atras * 4.0 + Vector((0, -2.0, 0))
		up = DM.reptar("rodilla_sube", phi + (0.5 if s == "L" else 0.0)) * ca
		if up > 0.001:
			base_c = Vector((hip.x, suelo_g + h_a, hip.z))
			an_c = base_c + dcha * (sg * (0.25 + 0.5 * up)) + atras * (2.4 - 0.8 * up)
			an_k = an_k.lerp(an_c, min(1.0, up * 3.0))
			polo = polo.lerp(hip + dcha * (sg * 3.0) + atras * 0.8 + Vector((0, 1.6, 0)), up)
		kk = DM.tumbar(s + "_rodilla", pb)
		an = an_pl.lerp(an_k, kk) + Vector((0, math.sin(math.pi * kk) * 0.6, 0))
		q = F_pl.to_quaternion().slerp(Rth.to_quaternion(), kk)
		F = Matrix.Translation(an) @ q.to_matrix().to_4x4() @ cf(0, -0.15, -0.2)
		ik_pierna(lado, an, polo, F)
	# manos al suelo (como el juego): delante de los hombros, a la altura del suelo
	manos = max(0.0, min(1.0, (pb - 0.3) / 0.3))
	if manos > 0:
		pecho = arm.pose.bones["Waist"].matrix
		base = Matrix.Translation(pecho.translation)
		for s in ("L", "R"):
			sg = -1 if s == "L" else 1
			off = math.sin(phi * 2 * math.pi + (0 if s == "L" else math.pi)) * 0.5 if reptando else 0.0
			reach = (-1.05 - off * 0.7) if pb > 0.95 else -0.85
			p = (base @ cf(sg * 0.7, 0, reach)).translation
			suelo = -3.11 - (centro - 3.1)
			lift = max(0, math.cos(phi * 2 * math.pi + (0 if s == "L" else math.pi))) * 0.18 if reptando else 0
			obj = Vector((p.x, suelo + 0.18 + lift + 0.22, p.z))
			S = arm.pose.bones[("Left" if s == "L" else "Right") + "Shoulder"].head
			obj = S.lerp(obj, manos) if manos < 1 else obj
			ik_brazo("Left" if s == "L" else "Right", obj, (base @ cf(sg * 1.5, -0.3, 0.4)).translation)


vista.preparar((440, 330), 8)
esc.render.engine = 'BLENDER_WORKBENCH'
esc.display.shading.light = 'STUDIO'
esc.display.shading.color_type = 'MATERIAL'
esc.display.shading.show_shadows = True
suelo = bpy.data.objects["Suelo"]
suelo.location.z = (arm.matrix_world @ Vector((0, -3.11, 0))).z
fwd = arm.matrix_world.to_3x3() @ Vector((0, 0, -1))
yaw = math.atan2(fwd.y, fwd.x)
out = os.path.join("/home/claude/bl/renders", pref)
os.makedirs(out, exist_ok=True)
for k, v in enumerate(vals):
	if modo == "t":
		pose(v, 0.0, False)
	else:
		pose(1.0, v, True)
	# alturas sobre el suelo (studs): punta y talón de cada pie, rodillas, manos
	centro = 3.1 + (0.45 - 3.1) * smooth01(v if modo == "t" else 1.0)
	suelo_g = -3.11 - (centro - 3.1)
	alt = {}
	for s, lado in (("L", "Left"), ("R", "Right")):
		J = arm.pose.bones[lado + "Ankle"].matrix @ R[lado + "Ankle"].inverted()
		F = J @ cf(0, -0.15, -0.2)
		alt[s + "punta"] = (F @ Vector((0, -0.15, -0.5))).y - suelo_g
		alt[s + "talon"] = (F @ Vector((0, -0.15, 0.5))).y - suelo_g
		K = arm.pose.bones[lado + "Knee"].matrix @ R[lado + "Knee"].inverted()
		alt[s + "rodilla"] = min((K @ Vector((0, 0, z))).y for z in (-0.23, 0.23)) - suelo_g
		W = arm.pose.bones[lado + "Wrist"].matrix @ R[lado + "Wrist"].inverted()
		alt[s + "mano"] = (W @ Vector((0, -0.4, 0))).y - suelo_g
	print("ALT %s=%.2f " % (modo, v) + " ".join("%s=%.2f" % (k, x) for k, x in alt.items()))
	foco = arm.matrix_world @ Vector((0, -0.6, 0))
	foco.z = max(foco.z, suelo.location.z + 0.9)
	for i, (az, alt, dist) in enumerate(vistas):
		vista.render(os.path.join(out, "v%d_%02d.png" % (i, k)), az, alt, dist, foco=foco, yaw=yaw)
print("HECHO", out)

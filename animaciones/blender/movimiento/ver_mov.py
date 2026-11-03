# Vista previa en Blender de los ciclos de diseno_mov.py sobre el superviviente (cuerpo.blend, montado con montar.py
# desde el juego). Los pies van sobre una cinta (el de apoyo se desplaza hacia atrás a la velocidad de la marcha; el
# del paso sigue las curvas del pie) y las piernas se colocan con IK de dos huesos, como en el juego.
# Uso: blender -b cuerpo.blend -P mov/ver_mov.py -- <ciclo> <vel studs/s> <periodo s> <fotogramas> <vistas az,alt,dist;...> <prefijo> [agachado]
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diseno_mov as DM
from mathutils import Matrix, Vector, Quaternion
import json

args = sys.argv[sys.argv.index("--") + 1:]
ciclo, vel, periodo, nf = args[0], float(args[1]), float(args[2]), int(args[3])
vistas = [tuple(float(x) for x in v.split(",")) for v in args[4].split(";")]
pref = args[5]
bajo = float(args[6]) if len(args) > 6 else 0.0   # cuánto baja la cadera (agachado)

esc = bpy.context.scene
arm = bpy.data.objects["Piloto"]
DR = json.loads(esc["datos_rig"])
R = {n: Matrix(v) for n, v in DR["r"].items()}
MOT = {}


def ang(x, y, z):
	return (Matrix.Rotation(x, 4, 'X') @ Matrix.Rotation(y, 4, 'Y') @ Matrix.Rotation(z, 4, 'Z'))


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
	if x.length < 1e-4:
		x = Vector((1, 0, 0))
	x.normalize()
	z = x.cross(y)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


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
	plano = dirv.cross(n)
	# los huesos de las piernas llevan 180° en Z: su eje Y va hacia abajo (de la cadera a la rodilla)
	hueso_dir(lado + "Hip", E - S, n)
	W = S + dirv * d
	hueso_dir(lado + "Knee", W - arm.pose.bones[lado + "Knee"].head, n)
	pb = arm.pose.bones[lado + "Ankle"]
	m = pie_m @ cf(0, 0.15, 0.2) @ R[lado + "Ankle"]
	m.translation = pb.head.copy()
	pb.matrix = m
	upd()


def reposo():
	for pb in arm.pose.bones:
		pb.matrix_basis = Matrix.Identity(4)
	upd()


FOOT_HALF = 0.15
HIP_X = 0.33


def pose(phi):
	reposo()
	g = lambda n: DM.canal(ciclo, n, phi)
	poner_T("Root", cf(g("raiz_x"), g("raiz_y") - bajo, g("raiz_z")) @ ang(g("pelvis_p"), g("pelvis_y"), g("pelvis_r")))
	poner_T("Waist", ang(0, g("cintura_y"), 0) @ ang(g("cintura_p") - 0.3 * (bajo > 0), 0, g("cintura_r")))
	poner_T("Neck", ang(0, g("cuello_y"), 0) @ ang(g("cuello_p") + 0.24 * (bajo > 0), 0, g("cuello_r")))
	upd()
	for s in ("R", "L"):
		hx, hy, hz, co, mu = DM.brazo(ciclo, s, phi)
		lado = "Right" if s == "R" else "Left"
		poner_T(lado + "Shoulder", ang(hx, hy, hz))
		poner_T(lado + "Elbow", ang(co, 0, 0))
		poner_T(lado + "Wrist", ang(mu, 0, 0))
	upd()
	# piernas animadas (2026-11-03, diseno_mov.pierna: lo mismo que hace el juego). En el espacio del rig: -Z delante;
	# z de la animación = tobillo delante de la cadera; el centro del pie va 0,2 por delante del tobillo
	suelo_y = -3.11
	for s in ("R", "L"):
		lado = "Right" if s == "R" else "Left"
		est = DM.PIERNAS[ciclo]["estrecha"]
		sx = (HIP_X - est) if s == "R" else -(HIP_X - est)
		z, alto, inc = DM.pierna(ciclo, s, phi, vel)
		p = Vector((sx, suelo_y + alto, -(z + 0.2)))
		base = Matrix.Translation(p + Vector((0, FOOT_HALF, 0))) @ ang(0, s == "R" and -0.1 or 0.1, 0)
		piv = Vector((0, -FOOT_HALF, -0.5 if inc < 0 else 0.5))
		F = base @ cf(*piv) @ ang(inc, 0, 0) @ cf(*(-piv))
		polo = Vector((sx, 0.5, -6))
		tob = (F @ cf(0, 0.15, 0.2)).translation
		ik_pierna(lado, tob, polo, F)


sys.path.insert(0, "/home/claude/bl")
import vista
vista.preparar((420, 520), 8)
esc.render.engine = 'BLENDER_WORKBENCH'
esc.display.shading.light = 'STUDIO'
esc.display.shading.color_type = 'MATERIAL'
esc.display.shading.show_shadows = True
esc.display.shading.show_cavity = True
suelo = bpy.data.objects["Suelo"]
suelo.location.z = (arm.matrix_world @ Vector((0, -3.11, 0))).z
fwd = arm.matrix_world.to_3x3() @ Vector((0, 0, -1))
yaw = math.atan2(fwd.y, fwd.x)
foco = arm.matrix_world @ Vector((0, -0.4, 0))
out = os.path.join("/home/claude/bl/renders", pref)
os.makedirs(out, exist_ok=True)
for k in range(nf):
	phi = k / nf
	pose(phi)
	for i, (az, alt, dist) in enumerate(vistas):
		vista.render(os.path.join(out, "v%d_%03d.png" % (i, k)), az, alt, dist, foco=foco, yaw=yaw)
print("HECHO", out)

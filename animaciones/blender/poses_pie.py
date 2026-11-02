# Posturas con armas de fuego DE PIE, diseñadas en Blender sobre el superviviente (pie_<Arma>.blend).
# Cada postura (arma base, estado LOW/HIP/AIM/SPRINT, cabeceo) = giro de cintura y cuello (los mismos números que usa
# el Animador: waistY/P/R y neckY/P/R), dónde va el arma respecto al pecho (marco "aim_base": centro del pecho, girado
# solo con el rumbo) y hacia dónde van los codos (polos de la IK). Los brazos se colocan con IK de dos huesos, como en
# el juego, para ver aquí exactamente lo que se verá allí.
import bpy, json, math
from mathutils import Matrix, Vector, Quaternion

esc = bpy.context.scene
arm = bpy.data.objects["Piloto"]
DR = json.loads(esc["datos_rig"])
R = {n: Matrix(v) for n, v in DR["r"].items()}
BASE = {}
for n, (q, o) in DR["base"].items():
	T = Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()
	T.translation = Vector(o)
	BASE[n] = T
D2R = math.pi / 180.0
LU, LF = 1.03, 0.95


def tf(a):
	m = Matrix.Identity(4)
	for c in range(3):
		for r in range(3):
			m[r][c] = a[c * 3 + r]
	m[0][3], m[1][3], m[2][3] = a[9], a[10], a[11]
	return m


def rx(a):
	return Matrix.Rotation(a, 4, 'X')


def ry(a):
	return Matrix.Rotation(a, 4, 'Y')


def rz(a):
	return Matrix.Rotation(a, 4, 'Z')


def cf(x, y, z):
	return Matrix.Translation((x, y, z))


def ang(x, y, z):
	# Rbx.ang en grados: Rx·Ry·Rz
	return rx(x * D2R) @ ry(y * D2R) @ rz(z * D2R)


def poner_T(nombre, T):
	arm.pose.bones[nombre].matrix_basis = R[nombre].inverted() @ T @ R[nombre]


def leer_T(nombre):
	return R[nombre] @ arm.pose.bones[nombre].matrix_basis @ R[nombre].inverted()


def base():
	for n, T in BASE.items():
		poner_T(n, T)
	poner_T("Waist", Matrix.Identity(4) @ Matrix.Translation(BASE["Waist"].translation))
	poner_T("Neck", Matrix.Identity(4) @ Matrix.Translation(BASE["Neck"].translation))
	bpy.context.view_layer.update()


def hueso_dir(nombre, y, plano_n, pos=None):
	pb = arm.pose.bones[nombre]
	y = y.normalized()
	x = plano_n.cross(y)
	if x.length < 1e-4:
		x = Vector((1, 0, 0))
	x.normalize()
	z = x.cross(y)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = pb.head.copy() if pos is None else pos
	pb.matrix = m
	bpy.context.view_layer.update()


def ik(lado, muneca, polo, mano_rot=None):
	# IK de dos huesos (como Animador.solve): hombro -> codo -> muñeca, el codo hacia el polo
	S = arm.pose.bones[lado + "Shoulder"].head.copy()
	v = muneca - S
	d = min(v.length, LU + LF - 1e-3)
	dirv = v.normalized()
	ca = max(-1.0, min(1.0, (LU * LU + d * d - LF * LF) / (2 * LU * d)))
	sa = math.sqrt(1 - ca * ca)
	n = (polo - S) - dirv * (polo - S).dot(dirv)
	n = n.normalized() if n.length > 1e-4 else Vector((0, -1, 0))
	E = S + dirv * (LU * ca) + n * (LU * sa)
	plano = dirv.cross(n)
	hueso_dir(lado + "Shoulder", E - S, plano)
	W = S + dirv * d
	hueso_dir(lado + "Elbow", W - arm.pose.bones[lado + "Elbow"].head, plano)
	pb = arm.pose.bones[lado + "Wrist"]
	if mano_rot is not None:
		m = mano_rot.to_4x4() @ R[lado + "Wrist"]
	else:
		m = arm.pose.bones[lado + "Elbow"].matrix.copy()   # mano siguiendo al antebrazo
	m.translation = pb.head.copy()
	pb.matrix = m
	bpy.context.view_layer.update()
	return E


GRIP = tf(DR.get("grip", [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]))
GRIP_ATT = tf(DR.get("grip_att", [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]))
PUNTOS = DR.get("puntos", {})
MUNECA = Vector(DR["muneca_en_mano"])


def aplicar(d, pc):
	"""d = diseño de la postura: dict con 'arma'(f(pc)->Matrix), 'w'(wY,wP,wR), 'n'(nY,nP,nR), 'polo_r', 'polo_l'
	(Vector en el marco aim_base) y, si hace falta, 'apoyo' (nombre del punto para la mano izquierda)"""
	base()
	wY, wP, wR = d["w"](pc) if callable(d["w"]) else d["w"]
	nY, nP, nR = d["n"](pc) if callable(d["n"]) else d["n"]
	poner_T("Waist", Matrix.Translation(BASE["Waist"].translation) @ ry(wY) @ rx(wP) @ rz(wR))
	bpy.context.view_layer.update()
	poner_T("Neck", Matrix.Translation(BASE["Neck"].translation) @ ry(nY) @ rx(nP) @ rz(nR))
	bpy.context.view_layer.update()
	pecho = arm.pose.bones["Waist"].matrix @ cf(0, 0.69, 0)
	aim_base = Matrix.Translation(pecho.translation)
	handle = aim_base @ d["arma"](pc)
	mano = handle @ GRIP @ GRIP_ATT.inverted()
	muneca = (mano @ Matrix.Translation(MUNECA)).translation
	ik("Right", muneca, (aim_base @ Vector(d["polo_r"])), mano.to_3x3())
	ap = d.get("apoyo")
	if ap and ap in PUNTOS:
		pos = handle @ Vector(PUNTOS[ap])
		SL = arm.pose.bones["LeftShoulder"].head
		wt = pos - (pos - SL).normalized() * 0.22
		ik("Left", wt, (aim_base @ Vector(d["polo_l"])))
	return handle

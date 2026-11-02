# Poses de apuntado con la pistola en la moto, hechas en Blender sobre el piloto montado (piloto.blend).
# Cada pose: hacia dónde apunta (a = ángulo respecto a la moto, + izquierda; p = cabeceo, + arriba) -> giro de
# cintura y cuello y el brazo derecho colocado por FK: el antebrazo y la pistola en la línea de tiro (muñeca neutra),
# el codo algo flexionado y hacia abajo, el brazo superior por delante del pecho cuando cruza y por fuera del hombro
# cuando apunta hacia atrás. Escribe las rotaciones de las articulaciones (las Transform de los Motor6D) a JSON.
import bpy, json, math, sys
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


def tf(a):
	m = Matrix.Identity(4)
	for c in range(3):
		for r in range(3):
			m[r][c] = a[c * 3 + r]
	m[0][3], m[1][3], m[2][3] = a[9], a[10], a[11]
	return m


HANDLE = tf(DR["handle_en_mano"])   # modelo del arma respecto a la mano
LU, LF = 1.03, 0.95                 # brazo y antebrazo


def poner_T(nombre, T):
	arm.pose.bones[nombre].matrix_basis = R[nombre].inverted() @ T @ R[nombre]


def leer_T(nombre):
	return R[nombre] @ arm.pose.bones[nombre].matrix_basis @ R[nombre].inverted()


def rot_y(a):
	return Matrix.Rotation(a, 4, 'Y')


def rot_x(a):
	return Matrix.Rotation(a, 4, 'X')


def rot_z(a):
	return Matrix.Rotation(a, 4, 'Z')


def base():
	for n, T in BASE.items():
		poner_T(n, T)
	bpy.context.view_layer.update()


def poner_hueso(nombre, eje_y, eje_x):
	# orienta el hueso (en el espacio de la armadura) con su Y a lo largo de eje_y y su X lo más parecido a eje_x,
	# sin moverlo de sitio
	pb = arm.pose.bones[nombre]
	y = eje_y.normalized()
	x = (eje_x - y * eje_x.dot(y)).normalized()
	z = x.cross(y)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = pb.head.copy()
	pb.matrix = m
	bpy.context.view_layer.update()


def perp(v, d):
	w = v - d * v.dot(d)
	return w.normalized() if w.length > 1e-5 else Vector((0, 0, 0))


def pose(a, p, rama="L", detalles=None):
	base()
	# ---- torso: la cintura gira hacia la mira (con límite), el pecho se inclina un poco con el cabeceo
	# (a la izquierda gira bastante más: hacia atrás a la izquierda el pecho casi mira hacia atrás y el brazo cruza
	# por delante; a la derecha el brazo llega solo, por encima del hombro)
	tw = max(-1.2, a * 0.45) if a < 0 else min(1.55, a * 0.55)
	atras_der = max(0.0, min(1.0, (-a - 1.3) / 1.4))   # apuntando atrás por la derecha
	cruce = max(0.0, min(1.0, (a - 0.5) / 1.6))       # cruzando hacia la izquierda
	inclina = -0.10 * atras_der + 0.04 * cruce           # se echa hacia el lado del brazo al mirar atrás
	adel = 0.10 * cruce - 0.05 * atras_der               # se mete sobre el arma al cruzar; algo hacia atrás al girarse
	# (hacia abajo el pecho y la cabeza bajan mucho menos: si no, el piloto se mira el pecho)
	pt = p if p > 0 else p * 0.45
	poner_T("Waist", rot_y(tw) @ BASE["Waist"] @ rot_x(pt * 0.25 - adel) @ rot_z(inclina))
	bpy.context.view_layer.update()
	# ---- cabeza: mira a lo largo del arma
	ny = max(-1.35, min(1.35, (a - tw) * 0.85))
	poner_T("Neck", rot_y(ny) @ BASE["Neck"] @ rot_x(pt * 0.4 + adel * 0.5) @ rot_z(-inclina * 0.5))
	bpy.context.view_layer.update()
	pecho = arm.pose.bones["Waist"].matrix        # marco de la cintura (pecho), espacio de la armadura
	r_c = (pecho.to_3x3() @ Vector((1, 0, 0))).normalized()
	u_c = (pecho.to_3x3() @ Vector((0, 1, 0))).normalized()
	f_c = (pecho.to_3x3() @ Vector((0, 0, -1))).normalized()
	c_c = pecho.translation + u_c * 0.6
	# ---- dirección de tiro (en el espacio de la moto/piloto: -Z delante, Y arriba)
	d = (rot_y(a) @ rot_x(p)).to_3x3() @ Vector((0, 0, -1))
	d.normalize()
	S = arm.pose.bones["RightShoulder"].head.copy()
	# brazo superior: hacia la mira, con el codo un poco flexionado y hacia abajo
	abajo = perp(-u_c, d)
	beta = math.radians(16 + 6 * cruce)
	u = d * math.cos(beta) + abajo * math.sin(beta)
	# cruzando el pecho: el brazo superior va por delante (y algo más bajo)
	u = u + f_c * (0.75 * cruce) - u_c * (0.15 * cruce)
	# hacia atrás: el codo por fuera del hombro
	u = u + r_c * (0.35 * atras_der)
	u.normalize()
	E = S + u * LU
	# el codo nunca dentro del pecho: por delante si cruza hacia la izquierda, por fuera (a la derecha) si va atrás
	el = E - c_c
	x_l, z_l = el.dot(r_c), el.dot(f_c)
	if abs(x_l) < 0.85 and -0.5 < z_l < 0.6:
		if z_l >= -0.05 or x_l < 0.0 and a > 0.0:
			E += f_c * (0.6 - z_l) * min(1.0, (0.85 - abs(x_l)) / 0.4)
		else:
			E += r_c * (0.85 - x_l)
		u = (E - S).normalized()
		E = S + u * LU
	# ---- la pistola: el cañón en la línea de tiro, casi derecha (un poco ladeada hacia dentro, como se sujeta
	# con una mano); la mano la sigue (muñeca neutra) y el antebrazo apunta a la muñeca
	arriba = perp(u_c, d)
	if arriba.length < 0.5:
		arriba = perp(Vector((0, 1, 0)), d)
	canteo = math.radians(10)
	arriba = (Matrix.Rotation(canteo, 3, d) @ arriba).normalized()
	zg = -d
	xg = arriba.cross(zg).normalized()
	G = Matrix((xg, arriba, zg)).transposed().to_4x4()
	# mano en el mundo = arma * handle^-1 ; la muñeca (articulación) respecto a la mano: C1 de RightWrist
	mano = G @ HANDLE.inverted()
	mano_rot = mano.to_3x3()
	# posición: la articulación de la muñeca queda en la punta del antebrazo
	W = E + d * LF
	# huesos: el brazo superior y el antebrazo con la X del hueso como la X de la mano (sin retorcer)
	x_mano = mano_rot @ Vector((-1, 0, 0))  # (los huesos de brazo llevan 180° en Z: su X es -X de la pieza)
	poner_hueso("RightShoulder", u, x_mano)
	f_dir = (W - arm.pose.bones["RightElbow"].head).normalized()
	poner_hueso("RightElbow", f_dir, x_mano)
	pb = arm.pose.bones["RightWrist"]
	m = (mano_rot.to_4x4() @ R["RightWrist"])
	m.translation = pb.head.copy()
	pb.matrix = m
	bpy.context.view_layer.update()
	return {n: leer_T(n) for n in ("Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist")}


def a_lista(T):
	q = T.to_quaternion()
	return [q.x, q.y, q.z, q.w]


def pose_recogida(lado_mira=0.0):
	# pose intermedia del paso por delante del pecho: de frente, el arma recogida delante del pecho derecho con el
	# cañón hacia arriba (y algo hacia delante), el codo abajo; la cabeza ya mira hacia donde va (lado_mira)
	base()
	poner_T("Waist", BASE["Waist"] @ rot_x(0.05))
	bpy.context.view_layer.update()
	poner_T("Neck", rot_y(max(-1.2, min(1.2, lado_mira * 0.6))) @ BASE["Neck"])
	bpy.context.view_layer.update()
	pecho = arm.pose.bones["Waist"].matrix
	r_c = (pecho.to_3x3() @ Vector((1, 0, 0))).normalized()
	u_c = (pecho.to_3x3() @ Vector((0, 1, 0))).normalized()
	f_c = (pecho.to_3x3() @ Vector((0, 0, -1))).normalized()
	u = (-u_c * 0.75 + f_c * 0.55 + r_c * 0.05).normalized()     # brazo: hacia abajo y delante
	f = (u_c * 0.85 + f_c * 0.45 - r_c * 0.25).normalized()      # antebrazo: hacia arriba, hacia el centro
	d = (u_c * 0.8 + f_c * 0.6).normalized()                      # cañón: arriba y algo delante
	arriba = perp(-f_c, d)
	zg = -d
	xg = arriba.cross(zg).normalized()
	G = Matrix((xg, arriba, zg)).transposed().to_4x4()
	mano_rot = (G @ HANDLE.inverted()).to_3x3()
	x_mano = mano_rot @ Vector((-1, 0, 0))
	poner_hueso("RightShoulder", u, x_mano)
	poner_hueso("RightElbow", f, x_mano)
	pb = arm.pose.bones["RightWrist"]
	m = mano_rot.to_4x4() @ R["RightWrist"]
	m.translation = pb.head.copy()
	pb.matrix = m
	bpy.context.view_layer.update()
	return {n: leer_T(n) for n in ("Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist")}

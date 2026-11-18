# COMBATE CUERPO A CUERPO del superviviente (2026-11-08, KangooG): guardia, bloqueo, empujón y patada.
# Es el diseño (claves de animación, sin bpy): lo mismo se ve en Blender (ver_cc.py, sobre cuerpo.blend) y lo lee el
# juego (a_gd_cc.py -> scripts/jugador/combate_cc.gd, CombateCC; Animador._paso_cc).
#
# Marcos (todo en studs y radianes, ejes de Godot: X derecha, Y arriba, -Z delante):
#  - Brazos y arma: respecto al PECHO ("aim_base" del Animador: centro del UpperTorso, girado solo con el rumbo).
#    Hombros en (±0,92, 0,51, 0); la cabeza en (0, 1,13, 0); brazo hasta la muñeca 1,98.
#      mr_x/y/z, ml_x/y/z   mano derecha / izquierda (centro de la mano)
#      pr_x/y/z, pl_x/y/z   hacia dónde va cada codo (polo de la IK)
#      mr_d*, mr_b*, mr_rw  orientación de la mano: d = hacia dónde apuntan los dedos, b = hacia dónde mira el dorso,
#                           rw = cuánto se usa (0 = la mano sigue al antebrazo, como un puño)
#      a_p*, a_f*, a_u*     el arma (Handle): posición, hacia dónde apunta (hoja / cañón) y su "arriba"
#  - Cuerpo: cin_y/p/r (cintura), cue_y/p/r (cuello), cad_x/y/z (la cadera se desplaza; -z = adelante) y pel_p/y/r
#    (giro de la pelvis). Se SUMAN a lo que ya hace el cuerpo.
#    Signos (Rbx.ang): +y gira a la izquierda (el hombro derecho va adelante); +p echa hacia atrás; -p, hacia delante.
#  - Pierna que patea: pie_x/y/z = tobillo respecto a la articulación de la cadera de esa pierna (girado con el
#    rumbo; de pie, el tobillo está en (0, -2,53, -0,1)); pie_inc = inclinación del pie (+ = punta arriba, la planta
#    hacia delante); ro_x/y/z = hacia dónde va la rodilla; pie_w = cuánto manda la animación (0 = pie en el suelo).
#  - avance: cuánto avanza el cuerpo (studs, acumulado): el juego lo mueve de verdad.
#
# Clases (según el arma en la mano): manos (sin arma), corta (cuchillo), larga (machete, palanca, bate, hacha),
# fuego_corta (pistola, revólver, subfusil) y fuego_larga (rifle, escopeta, francotirador). Con armas de fuego no hay
# guardia (el clic derecho apunta), pero sí bloqueo, empujón y patada.
import math

D = math.pi / 180.0


def _n(v):
	l = math.sqrt(sum(x * x for x in v))
	return tuple(x / l for x in v) if l > 1e-9 else v


def mano(lado, p, polo, dedos=None, dorso=None, rw=1.0):
	"""canales de una mano: p = centro de la mano, polo = codo; dedos/dorso = orientación (si no, puño)"""
	k = "mr_" if lado == "R" else "ml_"
	kp = "pr_" if lado == "R" else "pl_"
	c = {k + "x": p[0], k + "y": p[1], k + "z": p[2], kp + "x": polo[0], kp + "y": polo[1], kp + "z": polo[2]}
	if dedos is not None:
		d = _n(dedos)
		b = _n(dorso)
		c.update({k + "dx": d[0], k + "dy": d[1], k + "dz": d[2], k + "bx": b[0], k + "by": b[1], k + "bz": b[2], k + "rw": rw})
	else:
		c[k + "rw"] = 0.0
	return c


def arma(p, f, u, polo=None):
	"""el Handle del arma: posición, dirección de la hoja / el cañón y su arriba (como Armas.at); polo = codo derecho"""
	f = _n(f)
	u = _n(u)
	c = {"a_px": p[0], "a_py": p[1], "a_pz": p[2], "a_fx": f[0], "a_fy": f[1], "a_fz": f[2], "a_ux": u[0], "a_uy": u[1], "a_uz": u[2]}
	if polo is not None:
		c.update({"pr_x": polo[0], "pr_y": polo[1], "pr_z": polo[2]})
	return c


def cuerpo(cin=(0, 0, 0), cue=(0, 0, 0), cad=(0, 0, 0), pel=(0, 0, 0)):
	return {"cin_y": cin[0], "cin_p": cin[1], "cin_r": cin[2], "cue_y": cue[0], "cue_p": cue[1], "cue_r": cue[2],
		"cad_x": cad[0], "cad_y": cad[1], "cad_z": cad[2], "pel_p": pel[0], "pel_y": pel[1], "pel_r": pel[2]}


def pie(p, inc, rodilla, w=1.0):
	return {"pie_x": p[0], "pie_y": p[1], "pie_z": p[2], "pie_inc": inc, "ro_x": rodilla[0], "ro_y": rodilla[1], "ro_z": rodilla[2], "pie_w": w}


def une(*ds):
	r = {}
	for d in ds:
		r.update(d)
	return r


# palma hacia delante (empujar): dedos arriba, dorso hacia el cuerpo
PALMA_D, PALMA_B = (0.0, 1.0, -0.15), (0.0, 0.15, 1.0)
# antebrazo de lado delante de la cara (bloquear con el brazo): dedos hacia el otro lado, dorso hacia delante
BARRA_L_D, BARRA_L_B = (1.0, 0.15, 0.0), (0.0, 0.1, -1.0)

# ---------------------------------------------------------------- GUARDIA (clic derecho con arma blanca o sin arma)
# Puños delante de la cara, el izquierdo adelantado (guardia de boxeo), hombros algo girados, rodillas flexionadas.
GUARDIA = {
	"manos": une(
		mano("R", (0.42, 0.62, -1.5), (1.4, -1.5, 0.0)),
		mano("L", (-0.3, 0.7, -1.85), (-1.3, -1.5, -0.3)),
		cuerpo(cin=(-0.22, -0.08, 0), cue=(0.2, 0.1, 0), cad=(0, -0.24, 0.06))),
	# cuchillo adelante a la altura del pecho, la izquierda guardando la cara
	"corta": une(
		arma((0.5, 0.32, -1.22), (-0.08, 0.35, -0.93), (0, 0.93, 0.35), (1.8, -1.2, 0.4)),
		mano("L", (-0.3, 0.8, -1.55), (-1.4, -1.3, -0.5)),
		cuerpo(cin=(-0.2, -0.1, 0), cue=(0.18, 0.1, 0), cad=(0, -0.32, 0))),
	# arma larga levantada delante del hombro derecho, lista para golpear o parar (la izquierda en el arma si es
	# de dos manos; si no, guardando)
	"larga": une(
		arma((0.55, 0.42, -0.98), (-0.25, 0.85, -0.45), (0.1, 0.45, 0.88), (1.8, -1.0, 0.5)),
		mano("L", (-0.34, 0.78, -1.45), (-1.4, -1.3, -0.5)),
		cuerpo(cin=(-0.15, -0.06, 0), cue=(0.13, 0.06, 0), cad=(0, -0.26, 0))),
}

# ---------------------------------------------------------------- BLOQUEO (clic derecho + Espacio mantenido)
BLOQUEO = {
	# antebrazos delante de la cara, codos juntos y abajo, el cuerpo encogido
	"manos": une(
		mano("R", (0.26, 1.12, -1.02), (0.8, -1.4, -1.3)),
		mano("L", (-0.26, 1.14, -1.06), (-0.8, -1.4, -1.3)),
		cuerpo(cin=(-0.08, -0.16, 0), cue=(0.06, 0.02, 0), cad=(0, -0.38, 0))),
	# el cuchillo en alto delante (la hoja hacia delante) y el antebrazo izquierdo cubriendo la cara
	"corta": une(
		arma((0.42, 0.98, -0.9), (-0.15, 0.25, -0.96), (0, 0.97, 0.25), (1.5, -0.6, -0.3)),
		mano("L", (-0.26, 1.14, -1.06), (-0.8, -1.4, -1.3)),
		cuerpo(cin=(-0.1, -0.15, 0), cue=(0.08, 0.03, 0), cad=(0, -0.38, 0))),
	# el arma atravesada en alto, a dos manos (para el golpe con el mango / la hoja de plano)
	"larga": une(
		arma((0.62, 1.05, -1.02), (-1.0, 0.12, -0.05), (0.12, 1.0, 0.0), (1.5, -0.8, 0.3)),
		{"pl_x": -1.5, "pl_y": -0.8, "pl_z": 0.3},
		cuerpo(cin=(-0.05, -0.12, 0), cue=(0.04, 0.02, 0), cad=(0, -0.36, 0))),
	# pistola recogida junto al pecho (apuntando delante, no se la quitan) y el antebrazo izquierdo de través
	"fuego_corta": une(
		arma((0.48, 0.05, -0.72), (0, -0.15, -0.99), (0, 0.99, -0.15), (1.7, -1.0, 0.6)),
		mano("L", (0.05, 1.12, -1.0), (-1.7, 0.5, -0.1), BARRA_L_D, BARRA_L_B, 0.8),
		cuerpo(cin=(-0.12, -0.14, 0), cue=(0.1, 0.04, 0), cad=(0, -0.36, 0))),
	# el arma larga atravesada en alto delante de la cara (para el golpe con el arma)
	"fuego_larga": une(
		arma((0.75, 1.0, -1.08), (-1.0, 0.06, 0.0), (0.06, 1.0, 0.0), (1.5, -0.9, 0.3)),
		{"pl_x": -1.5, "pl_y": -0.9, "pl_z": 0.3},
		cuerpo(cin=(-0.05, -0.12, 0), cue=(0.04, 0.02, 0), cad=(0, -0.36, 0))),
}

# ---------------------------------------------------------------- acciones por claves
# Cada acción: dur (s), golpe (fracción en que llega el impacto), claves [(t, {canales}), ...] con t de 0 a 1.
# La primera y la última clave son la pose de partida (guardia o arma lista): el juego mezcla con la pose de verdad
# al empezar y al terminar. Los canales que no están en una clave siguen como en la anterior.


def _accion(dur, golpe, claves, **extra):
	d = {"dur": dur, "golpe": golpe, "claves": claves}
	d.update(extra)
	return d


G = GUARDIA
B = BLOQUEO

EMPUJON = {
	"manos": [
		# (2026-11-08, 2: más agresivos) 1) a dos manos al pecho: carga con los codos atrás y el cuerpo encogido y sale
		# de golpe con todo el peso (las manos, el tronco y la cadera a la vez)
		_accion(0.55, 0.38, [
			(0.0, G["manos"]),
			(0.26, une(mano("R", (0.46, 0.34, -0.6), (1.4, -1.0, 1.0), PALMA_D, PALMA_B), mano("L", (-0.46, 0.34, -0.62), (-1.4, -1.0, 1.0), PALMA_D, PALMA_B),
				cuerpo(cin=(0, 0.06, 0), cue=(0, -0.02, 0), cad=(0, -0.34, 0.12)), {"avance": 0.0})),
			(0.38, une(mano("R", (0.32, 0.42, -2.06), (1.3, -0.7, 0.0), PALMA_D, PALMA_B), mano("L", (-0.32, 0.42, -2.06), (-1.3, -0.7, 0.0), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.4, 0), cue=(0, 0.32, 0), cad=(0, -0.2, -0.55)), {"avance": 0.4})),
			(0.56, une(mano("R", (0.34, 0.44, -1.96), (1.3, -0.7, 0.0), PALMA_D, PALMA_B), mano("L", (-0.34, 0.44, -1.96), (-1.3, -0.7, 0.0), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.32, 0), cue=(0, 0.26, 0), cad=(0, -0.2, -0.45)), {"avance": 0.45})),
			(1.0, une(G["manos"], {"avance": 0.45})),
		]),
		# 2) con el hombro: carga girando el tronco y revienta con el hombro y la palma derecha
		_accion(0.55, 0.38, [
			(0.0, G["manos"]),
			(0.26, une(mano("R", (0.66, 0.4, -0.38), (1.6, -1.1, 0.8), PALMA_D, PALMA_B), mano("L", (-0.3, 0.78, -1.25), (-1.4, -1.3, -0.5)),
				cuerpo(cin=(-0.58, 0.02, 0), cue=(0.5, 0.0, 0), cad=(0, -0.36, 0.1), pel=(0, -0.2, 0)), {"avance": 0.0})),
			(0.38, une(mano("R", (0.08, 0.46, -2.08), (1.2, -0.6, -0.1), PALMA_D, PALMA_B), mano("L", (-0.44, 0.48, -1.7), (-1.4, -0.8, 0.0), PALMA_D, PALMA_B),
				cuerpo(cin=(0.48, -0.32, 0), cue=(-0.42, 0.26, 0), cad=(0, -0.2, -0.52), pel=(0, 0.2, 0)), {"avance": 0.4})),
			(0.56, une(mano("R", (0.14, 0.46, -1.96), (1.2, -0.6, -0.1), PALMA_D, PALMA_B), cuerpo(cin=(0.38, -0.26, 0), cue=(-0.33, 0.21, 0), cad=(0, -0.2, -0.42), pel=(0, 0.15, 0)), {"avance": 0.45})),
			(1.0, une(G["manos"], {"avance": 0.45})),
		]),
		# 3) de abajo arriba: baja las manos, se agacha y empuja hacia arriba y adelante (levanta al otro)
		_accion(0.58, 0.4, [
			(0.0, G["manos"]),
			(0.26, une(mano("R", (0.42, -0.05, -0.75), (1.4, -1.2, 0.6), PALMA_D, PALMA_B), mano("L", (-0.42, -0.05, -0.75), (-1.4, -1.2, 0.6), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.12, 0), cue=(0, 0.1, 0), cad=(0, -0.55, 0.05)), {"avance": 0.0})),
			(0.4, une(mano("R", (0.3, 0.66, -1.98), (1.3, -0.9, 0.0), PALMA_D, PALMA_B), mano("L", (-0.3, 0.66, -1.98), (-1.3, -0.9, 0.0), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.26, 0), cue=(0, 0.2, 0), cad=(0, -0.08, -0.5)), {"avance": 0.42})),
			(0.58, une(mano("R", (0.32, 0.7, -1.88), (1.3, -0.9, 0.0), PALMA_D, PALMA_B), mano("L", (-0.32, 0.7, -1.88), (-1.3, -0.9, 0.0), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.2, 0), cue=(0, 0.16, 0), cad=(0, -0.1, -0.42)), {"avance": 0.48})),
			(1.0, une(G["manos"], {"avance": 0.48})),
		]),
	],
	"corta": [
		# 1) palma izquierda al pecho del otro, el cuchillo recogido y listo
		_accion(0.58, 0.42, [
			(0.0, G["corta"]),
			(0.24, une(arma((0.58, 0.22, -0.78), (-0.05, 0.25, -0.97), (0, 0.97, 0.25), (1.8, -1.2, 0.6)),
				mano("L", (-0.36, 0.58, -0.72), (-1.5, -1.2, 0.3), PALMA_D, PALMA_B),
				cuerpo(cin=(0.12, -0.03, 0), cue=(-0.1, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.42, une(arma((0.6, 0.25, -0.82), (-0.05, 0.25, -0.97), (0, 0.97, 0.25)),
				mano("L", (-0.18, 0.48, -2.0), (-1.4, -0.8, 0.1), PALMA_D, PALMA_B),
				cuerpo(cin=(-0.36, -0.22, 0), cue=(0.32, 0.18, 0), cad=(0, -0.22, -0.42)), {"avance": 0.425})),
			(0.6, une(mano("L", (-0.2, 0.48, -1.88), (-1.4, -0.8, 0.1), PALMA_D, PALMA_B), cuerpo(cin=(-0.3, -0.18, 0), cue=(0.26, 0.15, 0), cad=(0, -0.22, -0.34)), {"avance": 0.475})),
			(1.0, une(G["corta"], {"avance": 0.475})),
		]),
		# 2) a dos manos: el puño del cuchillo y la palma izquierda a la vez
		_accion(0.62, 0.44, [
			(0.0, G["corta"]),
			(0.24, une(arma((0.42, 0.48, -0.74), (0, 0.55, -0.83), (0, 0.83, 0.55), (1.6, -1.2, 0.4)),
				mano("L", (-0.42, 0.56, -0.8), (-1.5, -1.2, 0.3), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.02, 0), cue=(0, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.44, une(arma((0.38, 0.55, -1.9), (0, 0.4, -0.92), (0, 0.92, 0.4), (1.4, -0.8, 0.2)),
				mano("L", (-0.34, 0.44, -1.96), (-1.4, -0.8, 0.2), PALMA_D, PALMA_B),
				cuerpo(cin=(0, -0.26, 0), cue=(0, 0.22, 0), cad=(0, -0.22, -0.45)), {"avance": 0.45})),
			(0.6, une(arma((0.4, 0.56, -1.8), (0, 0.4, -0.92), (0, 0.92, 0.4)), cuerpo(cin=(0, -0.2, 0), cue=(0, 0.17, 0), cad=(0, -0.22, -0.35)), {"avance": 0.5})),
			(1.0, une(G["corta"], {"avance": 0.5})),
		]),
	],
	"larga": [
		# 1) con el mango atravesado a dos manos, de frente (como una barra)
		_accion(0.64, 0.44, [
			(0.0, G["larga"]),
			(0.24, une(arma((0.72, 0.5, -0.66), (-1.0, 0.08, 0.02), (0.08, 1.0, 0.0), (1.6, -1.1, 0.5)), {"pl_x": -1.6, "pl_y": -1.1, "pl_z": 0.5},
				cuerpo(cin=(0, -0.02, 0), cue=(0, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.44, une(arma((0.72, 0.58, -1.78), (-1.0, 0.06, -0.04), (0.06, 1.0, 0.0), (1.4, -0.8, 0.2)), {"pl_x": -1.4, "pl_y": -0.8, "pl_z": 0.2},
				cuerpo(cin=(0, -0.26, 0), cue=(0, 0.22, 0), cad=(0, -0.22, -0.45)), {"avance": 0.45})),
			(0.6, une(arma((0.72, 0.58, -1.68), (-1.0, 0.06, -0.04), (0.06, 1.0, 0.0)), cuerpo(cin=(0, -0.2, 0), cue=(0, 0.17, 0), cad=(0, -0.22, -0.35)), {"avance": 0.5})),
			(1.0, une(G["larga"], {"avance": 0.5})),
		]),
		# 2) golpe seco con el extremo del mango (el pomo) hacia delante
		_accion(0.6, 0.42, [
			(0.0, G["larga"]),
			(0.24, une(arma((0.6, 0.32, -0.55), (-0.2, 0.96, 0.18), (0, -0.18, 0.98), (1.7, -1.2, 0.6)), {"pl_x": -1.6, "pl_y": -1.1, "pl_z": 0.4},
				cuerpo(cin=(-0.2, -0.02, 0), cue=(0.18, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.42, une(arma((0.32, 0.42, -1.72), (-0.22, 0.9, 0.38), (0, -0.39, 0.92), (1.4, -0.8, 0.1)), {"pl_x": -1.4, "pl_y": -0.8, "pl_z": 0.1},
				cuerpo(cin=(0.2, -0.24, 0), cue=(-0.18, 0.2, 0), cad=(0, -0.22, -0.42)), {"avance": 0.425})),
			(0.6, une(arma((0.36, 0.42, -1.6), (-0.22, 0.9, 0.38), (0, -0.39, 0.92)), cuerpo(cin=(0.15, -0.18, 0), cue=(-0.13, 0.15, 0), cad=(0, -0.22, -0.33)), {"avance": 0.475})),
			(1.0, une(G["larga"], {"avance": 0.475})),
		]),
	],
	"fuego_corta": [
		# 1) la pistola recogida junto al pecho y la palma izquierda empuja
		_accion(0.58, 0.42, [
			(0.0, {}),
			(0.24, une(arma((0.5, 0.05, -0.7), (0, -0.15, -0.99), (0, 0.99, -0.15), (1.7, -1.1, 0.6)),
				mano("L", (-0.36, 0.58, -0.72), (-1.5, -1.2, 0.3), PALMA_D, PALMA_B),
				cuerpo(cin=(0.12, -0.03, 0), cue=(-0.1, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.42, une(arma((0.52, 0.06, -0.74), (0, -0.15, -0.99), (0, 0.99, -0.15)),
				mano("L", (-0.18, 0.48, -2.0), (-1.4, -0.8, 0.1), PALMA_D, PALMA_B),
				cuerpo(cin=(-0.36, -0.22, 0), cue=(0.32, 0.18, 0), cad=(0, -0.22, -0.42)), {"avance": 0.425})),
			(0.6, une(mano("L", (-0.2, 0.48, -1.88), (-1.4, -0.8, 0.1), PALMA_D, PALMA_B), cuerpo(cin=(-0.3, -0.18, 0), cue=(0.26, 0.15, 0), cad=(0, -0.22, -0.34)), {"avance": 0.475})),
			(1.0, {"avance": 0.475}),
		]),
		# 2) con el antebrazo izquierdo de través (como una barra), la pistola recogida
		_accion(0.6, 0.42, [
			(0.0, {}),
			(0.24, une(arma((0.5, 0.05, -0.7), (0, -0.15, -0.99), (0, 0.99, -0.15), (1.7, -1.1, 0.6)),
				mano("L", (0.1, 0.72, -0.7), (-1.6, 0.4, 0.2), BARRA_L_D, BARRA_L_B, 0.8),
				cuerpo(cin=(0.2, -0.03, 0), cue=(-0.18, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.42, une(arma((0.52, 0.06, -0.74), (0, -0.15, -0.99), (0, 0.99, -0.15)),
				mano("L", (0.15, 0.78, -1.62), (-1.6, 0.6, -0.4), BARRA_L_D, BARRA_L_B, 0.8),
				cuerpo(cin=(-0.3, -0.22, 0), cue=(0.27, 0.18, 0), cad=(0, -0.22, -0.42)), {"avance": 0.425})),
			(0.6, une(mano("L", (0.12, 0.78, -1.52), (-1.6, 0.6, -0.4), BARRA_L_D, BARRA_L_B, 0.8), cuerpo(cin=(-0.24, -0.17, 0), cue=(0.21, 0.14, 0), cad=(0, -0.22, -0.33)), {"avance": 0.475})),
			(1.0, {"avance": 0.475}),
		]),
	],
	"fuego_larga": [
		# 1) con el arma atravesada a dos manos, de frente
		_accion(0.64, 0.44, [
			(0.0, {}),
			(0.24, une(arma((0.8, 0.42, -0.66), (-1.0, 0.1, 0.02), (0.1, 1.0, 0.0), (1.6, -1.1, 0.5)), {"pl_x": -1.6, "pl_y": -1.1, "pl_z": 0.5},
				cuerpo(cin=(0, -0.02, 0), cue=(0, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.44, une(arma((0.8, 0.5, -1.72), (-1.0, 0.08, -0.04), (0.08, 1.0, 0.0), (1.4, -0.8, 0.2)), {"pl_x": -1.4, "pl_y": -0.8, "pl_z": 0.2},
				cuerpo(cin=(0, -0.26, 0), cue=(0, 0.22, 0), cad=(0, -0.22, -0.45)), {"avance": 0.45})),
			(0.6, une(arma((0.8, 0.5, -1.62), (-1.0, 0.08, -0.04), (0.08, 1.0, 0.0)), cuerpo(cin=(0, -0.2, 0), cue=(0, 0.17, 0), cad=(0, -0.22, -0.35)), {"avance": 0.5})),
			(1.0, {"avance": 0.5}),
		]),
		# 2) culatazo: gira el arma, el cañón hacia atrás por encima del hombro y la culata adelante
		_accion(0.66, 0.46, [
			(0.0, {}),
			(0.26, une(arma((0.62, 0.3, -0.42), (0.3, 0.2, 0.93), (0, 0.98, -0.2), (1.8, -1.0, 0.5)), {"pl_x": -1.4, "pl_y": -1.2, "pl_z": -0.4},
				cuerpo(cin=(-0.3, -0.02, 0), cue=(0.27, 0.04, 0), cad=(0, -0.3, 0.05)), {"avance": 0.0})),
			(0.46, une(arma((0.42, 0.58, -1.32), (0.15, 0.55, 0.82), (0, 0.83, -0.56), (1.5, -0.6, 0.2)), {"pl_x": -1.3, "pl_y": -1.0, "pl_z": -0.6},
				cuerpo(cin=(0.25, -0.24, 0), cue=(-0.22, 0.2, 0), cad=(0, -0.22, -0.42)), {"avance": 0.425})),
			(0.62, une(arma((0.46, 0.56, -1.2), (0.15, 0.55, 0.82), (0, 0.83, -0.56)), cuerpo(cin=(0.2, -0.18, 0), cue=(-0.17, 0.15, 0), cad=(0, -0.22, -0.33)), {"avance": 0.475})),
			(1.0, {"avance": 0.475}),
		]),
	],
}

# ---------------------------------------------------------------- PATADAS (G, con cualquier arma)
# (2026-11-08, 2: "mucho más lanzadas, que empujen") Patada frontal de empuje: recoge la rodilla de golpe, la pierna
# sale ENTERA (tobillo a ~2,5 de la cadera) con la planta por delante, la cadera se va hacia delante y la pelvis se
# abre (pel_p +) mientras el tronco se echa atrás; aguanta empujando A TRAVÉS del blanco (la cadera sigue avanzando con
# la pierna estirada) y recoge. Los brazos solo cuentan sin arma: el del lado de la pierna se va atrás para equilibrar.
_R = (0.05, 0.6, -4.0)   # rodilla hacia delante y arriba
_L = (-0.05, 0.6, -4.0)


def _patada(lado, dur, golpe, recoge, sale, empuja, cuerpo_sale, cuerpo_empuja, brazos, avance, **extra):
	"""claves comunes: apoyo, carga, recoge (rodilla arriba), sale (pierna estirada = impacto), empuja (sigue
	estirada mientras la cadera empuja), recoge otra vez y apoya"""
	R_ = _R if lado == "R" else _L
	s = 1.0 if lado == "R" else -1.0
	br_carga, br_sale = brazos
	return _accion(dur, golpe, [
		(0.0, une(pie((0, -2.53, -0.1), 0.0, R_, 0.0), cuerpo(), {"avance": 0.0})),
		(0.08, une(pie((0.02 * s, -2.3, -0.15), 0.05, R_, 0.5), cuerpo(cin=(0, 0.04, 0), cad=(0, -0.18, 0.06)), {"avance": 0.0})),
		(0.2, une(pie(recoge[0], recoge[1], R_, 1.0), cuerpo(cin=(0.06 * s, 0.16, 0), cue=(-0.05 * s, -0.13, 0), cad=(0, -0.08, 0.06), pel=(0.14, 0.06 * s, 0)),
			br_carga, {"avance": avance * 0.15})),
		(golpe, une(pie(sale[0], sale[1], R_, 1.0), cuerpo_sale, br_sale, {"avance": avance * 0.65})),
		(golpe + 0.14, une(pie(empuja[0], empuja[1], R_, 1.0), cuerpo_empuja, br_sale, {"avance": avance})),
		(golpe + 0.3, une(pie(recoge[0], recoge[1] * 0.8, R_, 1.0), cuerpo(cin=(0.04 * s, 0.12, 0), cue=(-0.03 * s, -0.1, 0), cad=(0, -0.1, -0.05), pel=(0.1, 0.04 * s, 0)), br_carga, {"avance": avance})),
		(0.86, une(pie((0.02 * s, -2.32, -0.5), 0.05, R_, 0.6), cuerpo(cad=(0, -0.18, 0)), {"avance": avance})),
		(1.0, une(pie((0, -2.53, -0.1), 0.0, R_, 0.0), cuerpo(), {"avance": avance})),
	], lado=lado, **extra)


# brazos sin arma: (al recoger, al salir la pierna)
_BR_D = (une(mano("R", (0.66, 0.5, -0.55), (1.6, -1.3, 0.5)), mano("L", (-0.3, 0.84, -1.55), (-1.4, -1.3, -0.5))),
	une(mano("R", (0.95, -0.05, 0.25), (1.5, -1.3, 1.3)), mano("L", (-0.28, 0.9, -1.5), (-1.4, -1.3, -0.5))))
_BR_I = (une(mano("L", (-0.66, 0.5, -0.55), (-1.6, -1.3, 0.5)), mano("R", (0.36, 0.8, -1.42), (1.5, -1.3, -0.2))),
	une(mano("L", (-0.95, -0.05, 0.25), (-1.5, -1.3, 1.3)), mano("R", (0.34, 0.86, -1.4), (1.5, -1.3, -0.2))))

PATADA = [
	# frontal con la derecha, al estómago
	_patada("R", 0.72, 0.34, ((0.05, -0.5, -0.8), 0.6), ((0.0, -0.15, -2.5), 1.2), ((0.0, -0.1, -2.5), 1.25),
		cuerpo(cin=(0.12, 0.34, 0), cue=(-0.1, -0.3, 0), cad=(0, -0.12, -0.5), pel=(0.28, 0.12, 0)),
		cuerpo(cin=(0.12, 0.38, 0), cue=(-0.1, -0.33, 0), cad=(0, -0.1, -0.68), pel=(0.32, 0.12, 0)),
		_BR_D, 0.28, nombre="frontal", danio=15.0, empuje=78.0, derribo=0.35),
	# alta, al pecho: recoge más alto y se echa más atrás
	_patada("R", 0.8, 0.36, ((0.05, -0.85, -1.0), 0.6), ((0.0, 0.08, -2.5), 1.35), ((0.0, 0.12, -2.5), 1.4),
		cuerpo(cin=(0.16, 0.52, 0), cue=(-0.12, -0.46, 0), cad=(0, -0.04, -0.4), pel=(0.45, 0.14, 0)),
		cuerpo(cin=(0.16, 0.56, 0), cue=(-0.12, -0.5, 0), cad=(0, -0.02, -0.56), pel=(0.48, 0.14, 0)),
		_BR_D, 0.24, nombre="alta", danio=18.0, empuje=70.0, derribo=0.25),
	# baja con la izquierda, al muslo: corta y seca, con el talón
	_patada("L", 0.6, 0.32, ((-0.04, -1.6, -0.55), 0.25), ((0.0, -1.62, -2.0), 0.1), ((0.0, -1.6, -2.05), 0.12),
		cuerpo(cin=(-0.12, 0.16, 0), cue=(0.1, -0.13, 0), cad=(0, -0.24, -0.4), pel=(0.1, -0.12, 0)),
		cuerpo(cin=(-0.12, 0.18, 0), cue=(0.1, -0.15, 0), cad=(0, -0.24, -0.52), pel=(0.12, -0.12, 0)),
		_BR_I, 0.22, nombre="baja", danio=12.0, empuje=60.0, derribo=0.34),
	# frontal con la izquierda, al estómago
	_patada("L", 0.72, 0.34, ((-0.05, -0.5, -0.8), 0.6), ((0.0, -0.15, -2.5), 1.2), ((0.0, -0.1, -2.5), 1.25),
		cuerpo(cin=(-0.12, 0.34, 0), cue=(0.1, -0.3, 0), cad=(0, -0.12, -0.5), pel=(0.28, -0.12, 0)),
		cuerpo(cin=(-0.12, 0.38, 0), cue=(0.1, -0.33, 0), cad=(0, -0.1, -0.68), pel=(0.32, -0.12, 0)),
		_BR_I, 0.28, nombre="frontal_izq", danio=15.0, empuje=78.0, derribo=0.35),
]



# ---------------------------------------------------------------- PISOTÓN (2026-11-08, 6: G con el zombi en el suelo)
# Sube la rodilla muy alta (el tronco algo atrás, mirando abajo) y baja el pie de golpe con todo el peso: la cadera cae
# y el tronco se echa encima; aprieta un instante y recoge. Aquí pisa el suelo delante (a 1,7 studs); en el juego el pie
# va al cuerpo caído de verdad (ImpactoCC.pie_offset).
def _pisoton(lado, dur, golpe, brazos, **extra):
	s = 1.0 if lado == "R" else -1.0
	R_ = (0.05 * s, 1.2, -4.0)   # rodilla adelante y bien arriba
	br_carga, br_sale = brazos
	return _accion(dur, golpe, [
		(0.0, une(pie((0, -2.53, -0.1), 0.0, R_, 0.0), cuerpo(), {"avance": 0.0})),
		(0.1, une(pie((0.02 * s, -2.3, -0.2), 0.05, R_, 0.5), cuerpo(cad=(0, -0.15, 0.05)), {"avance": 0.0})),
		(0.32, une(pie((0.03 * s, -0.85, -0.9), 0.15, R_, 1.0), cuerpo(cin=(0.04 * s, 0.14, 0), cue=(0, -0.28, 0), cad=(0, 0.05, 0.1), pel=(0.1, 0, 0)),
			br_carga, {"avance": 0.05})),
		(golpe, une(pie((0.0, -2.0, -1.7), -0.05, R_, 1.0), cuerpo(cin=(0.04 * s, -0.3, 0), cue=(0, -0.36, 0), cad=(0, -0.5, -0.3), pel=(-0.12, 0, 0)),
			br_sale, {"avance": 0.15})),
		(golpe + 0.12, une(pie((0.0, -2.05, -1.75), -0.05, R_, 1.0), cuerpo(cin=(0.04 * s, -0.34, 0), cue=(0, -0.38, 0), cad=(0, -0.55, -0.35), pel=(-0.14, 0, 0)),
			br_sale, {"avance": 0.18})),
		(0.8, une(pie((0.02 * s, -1.5, -1.0), 0.1, R_, 1.0), cuerpo(cin=(0, -0.12, 0), cue=(0, -0.15, 0), cad=(0, -0.25, -0.1)), br_carga, {"avance": 0.18})),
		(1.0, une(pie((0, -2.53, -0.1), 0.0, R_, 0.0), cuerpo(), {"avance": 0.18})),
	], lado=lado, **extra)


# (2026-11-08, 11: "que solo haga una animación para pegarle a alguien del piso") un solo pisotón, con la derecha
PISOTON = [
	_pisoton("R", 0.78, 0.5, _BR_D, nombre="pisoton", danio=30.0),
]

# ---------------------------------------------------------------- GOLPES con armas blancas (clic izquierdo)
# (2026-11-08, 2: variedad) Golpes NUEVOS por arma base; el de siempre (Armas.golpe) sigue siendo uno más y se
# alternan al azar sin repetir. "hoja(p, f, mov)": el arma en p apuntando hacia f, moviéndose hacia mov (el filo va
# por delante: el "arriba" del Handle queda al revés del movimiento). La izquierda (armas de una mano) guarda el pecho.
def hoja(p, f, mov, polo=None):
	f = _n(f)
	m = _n(mov)
	u = tuple(-m[i] + f[i] * sum(m[k] * f[k] for k in range(3)) for i in range(3))
	if math.sqrt(sum(x * x for x in u)) < 1e-3:
		# (estocada: se mueve en la misma dirección en que apunta; el filo / el lomo, arriba)
		ref = (0.0, 1.0, 0.0) if abs(f[1]) < 0.9 else (0.0, 0.0, 1.0)
		u = tuple(ref[i] - f[i] * sum(ref[k] * f[k] for k in range(3)) for i in range(3))
	return arma(p, f, u, polo)


_IZQ_GUARDA = mano("L", (-0.36, 0.62, -1.15), (-1.4, -1.3, -0.4))
_LISTA_CUCHILLO = arma((0.62, -0.32, -0.8), (0.05, 0.25, -1), (0, 1, 0))
_LISTA_MACHETE = arma((0.8, -0.2, -0.85), (0.1, 0.55, -0.83), (0, 0.83, 0.55))
_LISTA_BATE = arma((0.55, 0.15, -0.75), (0.15, 0.95, 0.25), (0, -0.25, -0.97))

GOLPES = {
	"Cuchillo": [
		# tajo de revés: de la izquierda a la derecha, a la altura del cuello
		_accion(0.5, 0.38, [
			(0.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.245, une(hoja((-0.3, 0.42, -0.72), (-0.8, 0.15, -0.55), (1, 0, 0), (1.4, -1.0, 0.4)), _IZQ_GUARDA,
				cuerpo(cin=(0.403, -0.018, 0.0), cue=(-0.272, 0.015, 0.0), cad=(0.0, -0.101, 0.0)), {"avance": 0.0})),
			(0.38, une(hoja((0.45, 0.4, -1.62), (0.15, 0.08, -1.0), (1, 0, 0.1), (1.6, -1.0, 0.2)),
				cuerpo(cin=(-0.252, -0.147, 0.0), cue=(0.177, 0.09, 0.0), cad=(0.0, -0.151, -0.205)), {"avance": 0.25})),
			(0.505, une(hoja((1.05, 0.3, -0.95), (0.88, 0.0, -0.48), (1, 0, 0.6), (1.8, -0.9, 0.6)),
				cuerpo(cin=(-0.462, -0.092, 0.0), cue=(0.306, 0.06, 0.0), cad=(0.0, -0.134, -0.148)), {"avance": 0.3})),
			(1.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.3})),
		]),
		# puñalada de arriba abajo, por encima del hombro
		_accion(0.55, 0.4, [
			(0.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.265, une(hoja((0.62, 1.28, -0.25), (0.0, 0.62, -0.78), (0, -1, -0.4), (1.6, 0.4, 0.6)), _IZQ_GUARDA,
				cuerpo(cin=(-0.185, 0.11, 0.0), cue=(0.122, -0.06, 0.0), cad=(0.0, -0.084, 0.041)), {"avance": 0.0})),
			(0.4, une(hoja((0.28, 0.15, -1.55), (-0.05, -0.55, -0.83), (0, -1, -0.3), (1.6, -0.8, 0.0)),
				cuerpo(cin=(0.151, -0.331, 0.0), cue=(-0.102, 0.225, 0.0), cad=(0.0, -0.235, -0.23)), {"avance": 0.25})),
			(0.525, une(hoja((0.22, -0.28, -1.28), (0.0, -0.82, -0.57), (0, -1, 0.3), (1.6, -1.0, 0.2)),
				cuerpo(cin=(0.118, -0.276, 0.0), cue=(-0.082, 0.188, 0.0), cad=(0.0, -0.252, -0.18)), {"avance": 0.3})),
			(1.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.3})),
		]),
		# (2026-11-08, 10) estocada: carga atrás junto a la cadera y entra recto al cuerpo con el brazo estirado, como un
		# directo, la izquierda se recoge al pecho
		_accion(0.46, 0.36, [
			(0.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.225, une(hoja((0.78, 0.12, -0.35), (0.0, 0.1, -1.0), (0, 0, -1), (1.6, -1.2, 0.8)), _IZQ_GUARDA,
				cuerpo(cin=(-0.252, 0.074, 0.0), cue=(0.17, 0.0, 0.0), cad=(0.0, -0.286, 0.098), pel=(0, -0.12, 0)), {"avance": 0.0})),
			(0.36, une(hoja((0.12, 0.22, -2.42), (0.0, 0.0, -1.0), (0, 0, -1), (1.3, -1.0, 0.0)),
				mano("L", (-0.5, 0.5, -0.55), (-1.4, -1.3, 0.4)),
				cuerpo(cin=(0.378, -0.184, 0.0), cue=(-0.272, 0.105, 0.048), cad=(0.034, -0.302, -0.394), pel=(0, 0.2, 0)), {"avance": 0.36})),
			(0.465, une(hoja((0.14, 0.2, -2.3), (0.0, 0.0, -1.0), (0, 0, -1), (1.3, -1.0, 0.0)), {"avance": 0.4})),
			(0.725, une(hoja((0.55, -0.1, -1.1), (0.05, 0.2, -1.0), (0, 0, 1), (1.6, -1.2, 0.4)), _IZQ_GUARDA,
				cuerpo(cin=(0.05, -0.046, 0.0), cue=(-0.034, 0.022, 0.0), cad=(0.0, -0.218, -0.082), pel=(0, 0.03, 0)), {"avance": 0.4})),
			(1.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.4})),
		]),
		# (2026-11-08, 10) tajo de derecha: de arriba a la derecha hacia abajo a la izquierda, cruzando el cuerpo
		_accion(0.52, 0.4, [
			(0.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.245, une(hoja((1.05, 0.9, -0.35), (0.6, 0.5, -0.6), (-1, -0.5, -0.3), (1.8, -0.4, 0.6)), _IZQ_GUARDA,
				cuerpo(cin=(-0.462, 0.046, 0.0), cue=(0.306, 0.0, 0.0), cad=(0.0, -0.134, 0.049), pel=(0, -0.15, 0)), {"avance": 0.0})),
			(0.4, une(hoja((0.1, 0.35, -1.85), (-0.3, 0.0, -1.0), (-1, -0.4, 0), (1.5, -0.9, 0.0)),
				cuerpo(cin=(0.294, -0.147, 0.0), cue=(-0.204, 0.075, 0.0), cad=(0.0, -0.252, -0.262), pel=(0, 0.15, 0)), {"avance": 0.28})),
			(0.525, une(hoja((-0.75, -0.1, -1.1), (-0.85, -0.2, -0.45), (-1, -0.4, 0.4), (1.2, -1.0, -0.4)),
				cuerpo(cin=(0.546, -0.11, 0.0), cue=(-0.374, 0.06, 0.0), cad=(0.0, -0.269, -0.205), pel=(0, 0.22, 0)), {"avance": 0.32})),
			(0.8, une(hoja((0.3, -0.2, -1.0), (0.0, 0.2, -1.0), (1, 0, 0), (1.5, -1.2, 0.4)), _IZQ_GUARDA,
				cuerpo(cin=(0.067, -0.046, 0.0), cad=(0.0, -0.202, -0.066), pel=(0, 0.04, 0)), {"avance": 0.32})),
			(1.0, une(_LISTA_CUCHILLO, _IZQ_GUARDA, cuerpo(), {"avance": 0.32})),
		]),
	],
	"Machete": [
		# tajo horizontal de derecha a izquierda, a la altura del pecho
		_accion(0.75, 0.38, [
			(0.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.245, une(hoja((1.05, 0.55, -0.25), (0.75, 0.35, 0.56), (-1, 0, -0.6), (1.8, -0.6, 0.8)), _IZQ_GUARDA,
				cuerpo(cin=(-0.521, 0.0, 0.0), cue=(0.354, 0.0, 0.0), cad=(0.0, -0.118, 0.041), pel=(0, -0.15, 0)), {"avance": 0.0})),
			(0.38, une(hoja((0.12, 0.38, -1.6), (-0.3, 0.05, -0.95), (-1, 0, -0.2), (1.5, -0.9, 0.0)),
				cuerpo(cin=(0.185, -0.147, 0.0), cue=(-0.136, 0.09, 0.0), cad=(0.0, -0.168, -0.23), pel=(0, 0.1, 0)), {"avance": 0.25})),
			(0.505, une(hoja((-0.75, 0.3, -0.95), (-0.92, 0.0, -0.38), (-1, 0, 0.5), (1.2, -1.1, -0.4)),
				cuerpo(cin=(0.504, -0.092, 0.0), cue=(-0.34, 0.06, 0.0), cad=(0.0, -0.151, -0.164), pel=(0, 0.18, 0)), {"avance": 0.3})),
			(1.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.3})),
		]),
		# de arriba abajo, vertical, con todo el cuerpo
		_accion(0.8, 0.42, [
			(0.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.285, une(hoja((0.62, 1.45, 0.12), (0.05, 0.62, 0.78), (0, -0.5, -1), (1.5, 0.6, 0.6)), _IZQ_GUARDA,
				cuerpo(cin=(-0.151, 0.147, 0.0), cue=(0.102, -0.09, 0.0), cad=(0.0, -0.05, 0.066)), {"avance": 0.0})),
			(0.42, une(hoja((0.32, 0.25, -1.55), (0.0, -0.3, -0.95), (0, -1, 0), (1.6, -0.6, 0.0)),
				cuerpo(cin=(0.05, -0.35, 0.0), cue=(-0.034, 0.24, 0.0), cad=(0.0, -0.269, -0.246)), {"avance": 0.25})),
			(0.545, une(hoja((0.3, -0.5, -1.1), (0.0, -0.86, -0.5), (0, -1, 0.4), (1.6, -1.0, 0.3)),
				cuerpo(cin=(0.042, -0.313, 0.0), cue=(-0.027, 0.21, 0.0), cad=(0.0, -0.286, -0.197)), {"avance": 0.3})),
			(1.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.3})),
		]),
		# (2026-11-08, 10) diagonal: del hombro derecho, por encima, hacia abajo a la izquierda, con todo el cuerpo
		_accion(0.8, 0.42, [
			(0.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.285, une(hoja((0.95, 1.4, 0.05), (0.35, 0.7, 0.6), (-0.6, -1, -0.5), (1.7, 0.3, 0.6)), _IZQ_GUARDA,
				cuerpo(cin=(-0.42, 0.129, 0.0), cue=(0.286, -0.075, 0.0), cad=(0.0, -0.084, 0.066), pel=(0, -0.18, 0)), {"avance": 0.0})),
			(0.42, une(hoja((0.2, 0.45, -1.75), (-0.35, -0.25, -0.9), (-0.6, -0.8, 0), (1.5, -0.7, 0.0)),
				cuerpo(cin=(0.252, -0.276, 0.04), cue=(-0.17, 0.188, 0.0), cad=(0.0, -0.319, -0.295), pel=(0, 0.16, 0)), {"avance": 0.3})),
			(0.565, une(hoja((-0.7, -0.6, -1.05), (-0.75, -0.55, -0.35), (-0.5, -0.8, 0.3), (1.2, -1.1, -0.4)),
				cuerpo(cin=(0.504, -0.294, 0.06), cue=(-0.34, 0.195, 0.0), cad=(0.0, -0.353, -0.23), pel=(0, 0.24, 0)), {"avance": 0.34})),
			(0.82, une(hoja((0.4, 0.0, -0.95), (0.1, 0.5, -0.85), (1, 0.5, 0), (1.7, -1.0, 0.5)), _IZQ_GUARDA,
				cuerpo(cin=(0.084, -0.074, 0.0), cad=(0.0, -0.218, -0.082), pel=(0, 0.05, 0)), {"avance": 0.34})),
			(1.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.34})),
		]),
		# (2026-11-08, 10) revés alto: carga sobre el hombro izquierdo y barre al cuello de izquierda a derecha
		_accion(0.72, 0.4, [
			(0.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.0})),
			(0.265, une(hoja((-0.45, 0.95, -0.3), (-0.6, 0.55, 0.55), (1, -0.2, -0.4), (1.0, -0.4, -0.9)),
				cuerpo(cin=(0.546, 0.018, 0.0), cue=(-0.374, 0.0, 0.0), cad=(0.0, -0.134, 0.049), pel=(0, 0.18, 0)), {"avance": 0.0})),
			(0.4, une(hoja((0.3, 0.6, -1.75), (0.35, 0.1, -0.93), (1, -0.15, 0), (1.6, -0.9, 0.0)),
				cuerpo(cin=(-0.21, -0.129, 0.0), cue=(0.136, 0.075, 0.0), cad=(0.0, -0.218, -0.246), pel=(0, -0.12, 0)), {"avance": 0.28})),
			(0.525, une(hoja((1.05, 0.45, -0.8), (0.9, 0.1, 0.4), (1, -0.1, 0.5), (1.9, -0.8, 0.6)),
				cuerpo(cin=(-0.504, -0.092, 0.0), cue=(0.34, 0.06, 0.0), cad=(0.0, -0.202, -0.18), pel=(0, -0.2, 0)), {"avance": 0.32})),
			(0.8, une(hoja((0.7, 0.1, -0.9), (0.15, 0.6, -0.8), (-1, 0, 0), (1.8, -1.0, 0.5)), _IZQ_GUARDA,
				cuerpo(cin=(-0.084, -0.046, 0.0), cad=(0.0, -0.202, -0.066), pel=(0, -0.04, 0)), {"avance": 0.32})),
			(1.0, une(_LISTA_MACHETE, _IZQ_GUARDA, cuerpo(), {"avance": 0.32})),
		]),
	],
	"Bate": [
		# de arriba abajo, a dos manos, por encima de la cabeza
		_accion(0.95, 0.44, [
			(0.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.0})),
			(0.305, une(hoja((0.4, 1.5, 0.25), (-0.1, 0.55, 0.83), (0, -0.4, -1), (1.4, 0.8, 0.6)),
				cuerpo(cin=(-0.101, 0.166, 0.0), cue=(0.068, -0.105, 0.0), cad=(0.0, -0.05, 0.066)), {"avance": 0.0})),
			(0.44, une(hoja((0.18, 0.3, -1.45), (-0.05, -0.2, -0.98), (0, -1, 0), (1.4, -0.6, 0.0)),
				cuerpo(cin=(0.034, -0.368, 0.0), cue=(-0.02, 0.255, 0.0), cad=(0.0, -0.286, -0.246)), {"avance": 0.25})),
			(0.565, une(hoja((0.15, -0.45, -1.15), (0.0, -0.8, -0.6), (0, -1, 0.4), (1.4, -1.0, 0.3)),
				cuerpo(cin=(0.025, -0.331, 0.0), cue=(-0.014, 0.225, 0.0), cad=(0.0, -0.302, -0.197)), {"avance": 0.3})),
			# (2026-11-09) recoge levantándolo por delante (antes volvía a la guardia pasando por entre las piernas)
			(0.8, une(hoja((0.4, 0.2, -1.0), (0.1, 0.5, -0.86), (0, 1, 0.4), (1.4, -1.0, 0.4)),
				cuerpo(cin=(0.017, -0.11, 0.0), cad=(0.0, -0.202, -0.082)), {"avance": 0.3})),
			(1.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.3})),
		]),
		# de revés: carga detrás del hombro izquierdo y barre de izquierda a derecha
		_accion(0.95, 0.42, [
			(0.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.0})),
			(0.285, une(hoja((-0.35, 0.6, -0.35), (-0.55, 0.55, 0.62), (1, 0, -0.6), (1.2, -0.6, -0.6)),
				cuerpo(cin=(0.588, 0.0, 0.0), cue=(-0.408, 0.0, 0.0), cad=(0.0, -0.118, 0.041), pel=(0, 0.18, 0)), {"avance": 0.0})),
			(0.42, une(hoja((0.22, 0.2, -1.3), (0.25, 0.08, -0.96), (1, 0, -0.1), (1.5, -0.9, 0.0)),
				cuerpo(cin=(-0.168, -0.147, 0.0), cue=(0.116, 0.09, 0.0), cad=(0.0, -0.185, -0.23), pel=(0, -0.1, 0)), {"avance": 0.25})),
			(0.545, une(hoja((0.95, 0.4, -0.65), (0.9, 0.25, 0.35), (1, 0, 0.6), (1.8, -0.6, 0.6)),
				cuerpo(cin=(-0.588, -0.092, 0.0), cue=(0.394, 0.06, 0.0), cad=(0.0, -0.168, -0.164), pel=(0, -0.18, 0)), {"avance": 0.3})),
			(1.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.3})),
		]),
		# (2026-11-08, 10) batazo horizontal (como al béisbol): el bate sobre el hombro derecho, paso, cadera y hombros
		# giran a la vez y barre de derecha a izquierda a la altura de la cabeza
		_accion(0.95, 0.44, [
			(0.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.0})),
			(0.305, une(hoja((0.85, 0.85, 0.15), (0.3, 0.6, 0.75), (-1, 0, -0.6), (1.6, -0.4, 0.8)),
				cuerpo(cin=(-0.588, 0.046, 0.0), cue=(0.408, 0.0, 0.0), cad=(0.0, -0.202, 0.098), pel=(0, -0.25, 0)), {"avance": 0.0})),
			(0.44, une(hoja((0.05, 0.4, -1.55), (-0.85, 0.08, -0.5), (-0.3, 0, -1), (1.4, -0.8, 0.0)),
				cuerpo(cin=(0.21, -0.138, 0.0), cue=(-0.136, 0.075, 0.0), cad=(0.0, -0.269, -0.295), pel=(0, 0.2, 0)), {"avance": 0.3})),
			(0.585, une(hoja((-0.95, 0.6, -0.6), (-0.6, 0.5, 0.6), (-0.5, 0.4, 1), (1.0, -0.6, -0.6)),
				cuerpo(cin=(0.63, -0.074, 0.0), cue=(-0.442, 0.045, 0.0), cad=(0.0, -0.235, -0.213), pel=(0, 0.3, 0)), {"avance": 0.34})),
			(0.84, une(hoja((-0.2, 0.3, -0.8), (0.1, 0.9, 0.3), (1, 0, 0), (1.3, -0.8, 0.2)),
				cuerpo(cin=(0.168, -0.037, 0.0), cue=(-0.102, 0.0, 0.0), cad=(0.0, -0.202, -0.082), pel=(0, 0.08, 0)), {"avance": 0.34})),
			(1.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.34})),
		]),
		# (2026-11-08, 10) golpe con la punta: el bate recto delante, a dos manos, entra como una lanza (corto y seco)
		_accion(0.6, 0.4, [
			(0.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.0})),
			(0.275, une(hoja((0.55, 0.3, -0.35), (0.05, 0.15, -1.0), (0, 0, -1), (1.5, -1.0, 0.6)),
				cuerpo(cin=(-0.126, 0.092, 0.0), cue=(0.082, -0.03, 0.0), cad=(0.0, -0.286, 0.115), pel=(0, -0.06, 0)), {"avance": 0.0})),
			(0.4, une(hoja((0.25, 0.32, -1.65), (0.0, 0.05, -1.0), (0, 0, -1), (1.4, -1.0, -0.2)),
				cuerpo(cin=(0.126, -0.221, 0.0), cue=(-0.068, 0.12, 0.0), cad=(0.0, -0.319, -0.361), pel=(0, 0.06, 0)), {"avance": 0.36})),
			(0.515, une(hoja((0.25, 0.3, -1.55), (0.0, 0.05, -1.0), (0, 0, -1), (1.4, -1.0, -0.2)), {"avance": 0.38})),
			(0.8, une(hoja((0.5, 0.2, -0.75), (0.1, 0.6, -0.8), (0, 0, 1), (1.5, -1.0, 0.5)),
				cuerpo(cin=(0.017, -0.046, 0.0), cad=(0.0, -0.218, -0.082)), {"avance": 0.38})),
			(1.0, une(_LISTA_BATE, cuerpo(), {"avance": 0.38})),
		]),
	],
}

# ---------------------------------------------------------------- PUÑETAZOS (sin arma, clic izquierdo)
# (2026-11-08, 10: "que los puños se estiren más, veo al personaje muy tieso") Todos con el cuerpo detrás del puño:
# carga corta (la rodilla y la cadera se cargan), la cadera y los hombros giran a la vez (cin + pel), el peso pasa a la
# pierna de delante (cad_z, avance), la cabeza se aparta de la línea (cue_r) y la mano que no pega vuelve a la barbilla.
# Los directos llegan con el brazo ESTIRADO (la mano un poco más allá de donde alcanza: la IK lo deja recto) y se
# quedan un instante; al recoger, el cuerpo se pasa un poco (rebote) antes de volver a la guardia.
# Se encadenan alternando manos (Arsenal.punetazo: tras una pausa, siempre el directo de izquierda; luego, al azar entre
# los de la otra mano). "lado" = mano que pega.
_PUNO_D = (0.0, 0.25, -1.0)          # nudillos delante
_PUNO_B_L = (-0.3, 1.0, 0.1)         # dorso arriba (izquierda)
_PUNO_B_R = (0.3, 1.0, 0.1)
_BARBILLA_R = mano("R", (0.3, 0.86, -1.22), (1.3, -1.5, -0.2))   # la derecha guardando la barbilla
_BARBILLA_L = mano("L", (-0.28, 0.88, -1.25), (-1.3, -1.5, -0.2))


def _puno(dur, golpe, claves, **extra):
	return _accion(dur, golpe, [(0.0, une(G["manos"], {"avance": 0.0}))] + claves + [(1.0, une(G["manos"], {"avance": claves[-1][1].get("avance", 0.0)}))], **extra)


PUNOS = [
	# 0) directo de izquierda (jab): rápido, el brazo entero y el hombro tapando la barbilla
	_puno(0.4, 0.3, [
		(0.145, une(mano("L", (-0.3, 0.68, -1.6), (-1.3, -1.0, -0.2)), _BARBILLA_R,
			cuerpo(cin=(-0.074, -0.036, 0.0), cue=(0.054, 0.022, 0.0), cad=(0.0, -0.269, 0.049), pel=(0, -0.04, 0)), {"avance": 0.02})),
		(0.3, une(mano("L", (-0.22, 0.74, -2.62), (-1.4, -0.6, -0.5), _PUNO_D, _PUNO_B_L, 0.75), _BARBILLA_R,
			cuerpo(cin=(-0.311, -0.108, 0.037), cue=(0.245, 0.06, -0.064), cad=(0.0, -0.252, -0.246), pel=(0, -0.16, 0)), {"avance": 0.2})),
		(0.44, une(mano("L", (-0.24, 0.74, -2.5), (-1.4, -0.6, -0.5), _PUNO_D, _PUNO_B_L, 0.75), {"avance": 0.22})),
		(0.685, une(mano("L", (-0.32, 0.72, -1.7), (-1.3, -1.4, -0.3)),
			cuerpo(cin=(-0.03, -0.054, 0.0), cue=(0.027, 0.03, 0.0), cad=(0.0, -0.218, -0.049), pel=(0, 0.03, 0)), {"avance": 0.22})),
	], nombre="directo", lado="L", danio=8.0, empuje=10.0, tambaleo=0.35, pieza="Head"),
	# 1) cruzado de derecha: la cadera derecha empuja, el talón de atrás gira y todo el hombro va detrás
	_puno(0.5, 0.36, [
		(0.185, une(mano("R", (0.5, 0.58, -1.05), (1.6, -1.4, 0.4)), _BARBILLA_L,
			cuerpo(cin=(-0.207, 0.018, 0.0), cue=(0.15, 0.0, 0.0), cad=(0.0, -0.302, 0.082), pel=(0, -0.14, 0)), {"avance": 0.0})),
		(0.36, une(mano("R", (0.0, 0.76, -2.85), (1.3, -0.5, -0.6), _PUNO_D, _PUNO_B_R, 0.75), _BARBILLA_L,
			cuerpo(cin=(0.429, -0.162, -0.046), cue=(-0.34, 0.09, 0.08), cad=(0.043, -0.252, -0.344), pel=(0, 0.3, 0)), {"avance": 0.3})),
		(0.465, une(mano("R", (0.02, 0.75, -2.72), (1.3, -0.5, -0.6), _PUNO_D, _PUNO_B_R, 0.75), {"avance": 0.32})),
		(0.725, une(mano("R", (0.46, 0.66, -1.4), (1.4, -1.5, 0.0)),
			cuerpo(cin=(-0.074, -0.045, 0.0), cue=(0.054, 0.022, 0.0), cad=(0.0, -0.235, -0.066), pel=(0, -0.06, 0)), {"avance": 0.32})),
	], nombre="cruzado", lado="R", danio=11.0, empuje=16.0, tambaleo=0.5, pieza="Head"),
	# 2) gancho de izquierda: el codo a la altura del puño, la cadera y el pie de delante giran juntos
	_puno(0.52, 0.4, [
		(0.205, une(mano("L", (-0.98, 0.7, -0.95), (-1.9, 0.55, 0.2)), _BARBILLA_R,
			cuerpo(cin=(0.222, 0.0, 0.046), cue=(-0.17, 0.0, 0.0), cad=(0.0, -0.319, 0.049), pel=(0, 0.14, 0)), {"avance": 0.0})),
		(0.4, une(mano("L", (0.16, 0.8, -1.72), (-1.5, 0.65, -1.35), (0.9, 0.2, -0.4), (0.0, 1.0, 0.0), 0.6), _BARBILLA_R,
			cuerpo(cin=(-0.503, -0.108, -0.055), cue=(0.408, 0.06, 0.08), cad=(0.0, -0.269, -0.18), pel=(0, -0.32, 0)), {"avance": 0.18})),
		(0.505, une(mano("L", (0.36, 0.78, -1.5), (-1.3, 0.6, -1.4), (0.9, 0.2, -0.4), (0.0, 1.0, 0.0), 0.6), {"avance": 0.2})),
		(0.745, une(mano("L", (-0.3, 0.74, -1.6), (-1.3, -1.2, -0.3)),
			cuerpo(cin=(0.059, -0.045, 0.0), cue=(-0.041, 0.022, 0.0), cad=(0.0, -0.227, -0.041), pel=(0, 0.05, 0)), {"avance": 0.2})),
	], nombre="gancho", lado="L", danio=12.0, empuje=18.0, tambaleo=0.6, pieza="Head"),
	# 3) gancho de abajo de derecha (uppercut): baja con las rodillas y sube con todo el cuerpo
	_puno(0.56, 0.42, [
		(0.245, une(mano("R", (0.48, -0.05, -0.95), (1.4, -1.4, 0.5)), _BARBILLA_L,
			cuerpo(cin=(-0.148, -0.144, 0.055), cue=(0.109, 0.06, 0.0), cad=(0.0, -0.521, 0.049), pel=(0, -0.12, 0)), {"avance": 0.0})),
		(0.42, une(mano("R", (0.1, 1.0, -1.72), (0.9, -1.6, -0.3), (0.0, 1.0, -0.3), (0.0, -0.3, -1.0), 0.6), _BARBILLA_L,
			cuerpo(cin=(0.311, 0.054, -0.046), cue=(-0.245, -0.045, 0.048), cad=(0.0, -0.067, -0.213), pel=(0, 0.24, 0)), {"avance": 0.22})),
		(0.525, une(mano("R", (0.12, 1.05, -1.6), (0.9, -1.6, -0.3), (0.0, 1.0, -0.3), (0.0, -0.3, -1.0), 0.6), {"avance": 0.24})),
		(0.8, une(mano("R", (0.44, 0.66, -1.45), (1.4, -1.5, 0.0)),
			cuerpo(cin=(-0.044, -0.054, 0.0), cue=(0.034, 0.022, 0.0), cad=(0.0, -0.252, -0.066), pel=(0, -0.04, 0)), {"avance": 0.24})),
	], nombre="gancho_abajo", lado="R", danio=13.0, empuje=22.0, tambaleo=0.7, pieza="Head"),
	# 4) gancho de izquierda a la barriga: baja el nivel doblando las rodillas y se inclina hacia la izquierda
	_puno(0.52, 0.4, [
		(0.205, une(mano("L", (-0.95, 0.1, -0.9), (-1.8, 0.2, 0.3)), _BARBILLA_R,
			cuerpo(cin=(0.192, -0.09, 0.11), cue=(-0.136, 0.06, -0.08), cad=(0.0, -0.554, 0.033), pel=(0, 0.12, 0)), {"avance": 0.0})),
		(0.4, une(mano("L", (0.1, -0.25, -1.78), (-1.6, 0.1, -1.3), (0.9, 0.1, -0.4), (0.0, 1.0, 0.0), 0.6), _BARBILLA_R,
			cuerpo(cin=(-0.444, -0.234, 0.129), cue=(0.34, 0.15, -0.096), cad=(0.0, -0.605, -0.197), pel=(0, -0.3, 0.04)), {"avance": 0.2})),
		(0.505, une(mano("L", (0.3, -0.25, -1.55), (-1.4, 0.1, -1.4), (0.9, 0.1, -0.4), (0.0, 1.0, 0.0), 0.6), {"avance": 0.22})),
		(0.8, une(mano("L", (-0.3, 0.72, -1.6), (-1.3, -1.2, -0.3)),
			cuerpo(cin=(0.044, -0.045, 0.0), cue=(-0.034, 0.022, 0.0), cad=(0.0, -0.269, -0.049), pel=(0, 0.04, 0)), {"avance": 0.22})),
	], nombre="al_cuerpo", lado="L", danio=10.0, empuje=20.0, tambaleo=0.7, pieza="LowerTorso"),
	# 5) derechazo largo por encima (overhand): un paso adelante, el puño entra por arriba con todo el peso
	_puno(0.6, 0.42, [
		(0.225, une(mano("R", (0.7, 0.95, -0.7), (1.7, 0.2, 0.6)), _BARBILLA_L,
			cuerpo(cin=(-0.237, 0.108, 0.0), cue=(0.177, -0.045, 0.0), cad=(0.0, -0.286, 0.115), pel=(0, -0.16, 0)), {"avance": 0.0})),
		(0.42, une(mano("R", (-0.05, 0.86, -2.9), (1.3, 0.2, -0.8), (0.0, 0.0, -1.0), (0.3, 1.0, 0.0), 0.75), _BARBILLA_L,
			cuerpo(cin=(0.503, -0.27, -0.074), cue=(-0.394, 0.15, 0.096), cad=(0.051, -0.336, -0.451), pel=(-0.06, 0.34, 0)), {"avance": 0.4})),
		(0.525, une(mano("R", (-0.02, 0.8, -2.76), (1.3, 0.2, -0.8), (0.0, 0.0, -1.0), (0.3, 1.0, 0.0), 0.75), {"avance": 0.44})),
		(0.82, une(mano("R", (0.46, 0.66, -1.4), (1.4, -1.5, 0.0)),
			cuerpo(cin=(-0.059, -0.072, 0.0), cue=(0.041, 0.038, 0.0), cad=(0.0, -0.252, -0.082), pel=(0, -0.05, 0)), {"avance": 0.44})),
	], nombre="derechazo", lado="R", danio=14.0, empuje=24.0, tambaleo=0.8, pieza="Head"),
]

# ---------------------------------------------------------------- muestreo (lo mismo que hace el juego)


def canales(claves):
	"""todos los canales que aparecen en alguna clave"""
	vistos = []
	for _, c in claves:
		for k in c:
			if k not in vistos:
				vistos.append(k)
	return vistos


def _rellenar(claves, k):
	"""valores del canal k en cada clave: si falta, el de la clave anterior (o el de la primera que lo tenga)"""
	vals = []
	ult = None
	for _, c in claves:
		if k in c:
			ult = c[k]
		vals.append(ult)
	primero = next(v for v in vals if v is not None)
	return [primero if v is None else v for v in vals]


_ORIENTACION = ("a_fx", "a_fy", "a_fz", "a_ux", "a_uy", "a_uz")


def muestra(accion, k, u):
	"""canal k de la acción en u (0..1): curva de Hermite que pasa por las claves (tangentes de Catmull-Rom; en los
	extremos, parada: empieza y acaba sin tirones). La orientación del arma (a_f*, a_u*) va aparte: ver _orientacion"""
	if k in _ORIENTACION:
		return _orientacion(accion, u)[_ORIENTACION.index(k)]
	cl = accion["claves"]
	return _hermite([t for t, _ in cl], _rellenar(cl, k), u)


# (2026-11-09: "con el arma blanca larga, al golpear hacia el piso da un giro extraño") la orientación del arma NO se
# interpola canal a canal: entre dos claves casi opuestas (el arma apuntando arriba-atrás y luego abajo-delante) la
# dirección pasaba por casi cero y su "arriba" quedaba paralelo a ella, y el arma daba vueltas sola. Ahora cada clave es
# un giro (cuaternión) y entre claves se gira por el camino más corto (slerp), con el mismo ritmo que las posiciones.
def _q_de_fu(f, up):
	z = _n(tuple(-x for x in f))
	upn = _n(up)
	x = _n((upn[1] * z[2] - upn[2] * z[1], upn[2] * z[0] - upn[0] * z[2], upn[0] * z[1] - upn[1] * z[0]))
	y = (z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0])
	m = ((x[0], y[0], z[0]), (x[1], y[1], z[1]), (x[2], y[2], z[2]))   # columnas x, y, z
	tr = m[0][0] + m[1][1] + m[2][2]
	if tr > 0:
		S = math.sqrt(tr + 1.0) * 2
		return (0.25 * S, (m[2][1] - m[1][2]) / S, (m[0][2] - m[2][0]) / S, (m[1][0] - m[0][1]) / S)
	if m[0][0] > m[1][1] and m[0][0] > m[2][2]:
		S = math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2
		return ((m[2][1] - m[1][2]) / S, 0.25 * S, (m[0][1] + m[1][0]) / S, (m[0][2] + m[2][0]) / S)
	if m[1][1] > m[2][2]:
		S = math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2
		return ((m[0][2] - m[2][0]) / S, (m[0][1] + m[1][0]) / S, 0.25 * S, (m[1][2] + m[2][1]) / S)
	S = math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2
	return ((m[1][0] - m[0][1]) / S, (m[0][2] + m[2][0]) / S, (m[1][2] + m[2][1]) / S, 0.25 * S)


def _fu_de_q(q):
	w, x, y, z = q
	# columnas y (arriba) y z (= -dirección) de la matriz del cuaternión
	col_y = (2 * (x * y - w * z), 1 - 2 * (x * x + z * z), 2 * (y * z + w * x))
	col_z = (2 * (x * z + w * y), 2 * (y * z - w * x), 1 - 2 * (x * x + y * y))
	return (-col_z[0], -col_z[1], -col_z[2], col_y[0], col_y[1], col_y[2])


def _slerp(a, b, t):
	d = sum(a[i] * b[i] for i in range(4))
	if d < 0:
		b = tuple(-x for x in b)
		d = -d
	if d > 0.9995:
		r = tuple(a[i] + (b[i] - a[i]) * t for i in range(4))
	else:
		th = math.acos(d)
		sa, sb = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
		r = tuple(sa * a[i] + sb * b[i] for i in range(4))
	l = math.sqrt(sum(x * x for x in r))
	return tuple(x / l for x in r)


def _q_mul(a, b):
	w1, x1, y1, z1 = a
	w2, x2, y2, z2 = b
	return (w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2, w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
		w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2)


def _angulo(a, b):
	return 2 * math.acos(min(1.0, abs(sum(a[i] * b[i] for i in range(4)))))


_CACHE_Q = {}


def _transporta(up, f0, f1):
	"""el "arriba" del arma cuando su dirección pasa de f0 a f1 por el giro más corto (sin girar sobre su eje)"""
	ax = (f0[1] * f1[2] - f0[2] * f1[1], f0[2] * f1[0] - f0[0] * f1[2], f0[0] * f1[1] - f0[1] * f1[0])
	sn = math.sqrt(sum(x * x for x in ax))
	cs = max(-1.0, min(1.0, sum(f0[i] * f1[i] for i in range(3))))
	if sn < 1e-6:
		r = up
	else:
		k = tuple(x / sn for x in ax)
		ang = math.atan2(sn, cs)
		kv = (k[1] * up[2] - k[2] * up[1], k[2] * up[0] - k[0] * up[2], k[0] * up[1] - k[1] * up[0])
		kd = sum(k[i] * up[i] for i in range(3))
		r = tuple(up[i] * math.cos(ang) + kv[i] * math.sin(ang) + k[i] * kd * (1 - math.cos(ang)) for i in range(3))
	d = sum(r[i] * f1[i] for i in range(3))
	return _n(tuple(r[i] - f1[i] * d for i in range(3)))


def _orientaciones_claves(accion):
	"""el giro del arma en cada clave. La dirección (a_f) es la de la clave; el "arriba" (a_u, hacia dónde mira el filo)
	solo manda en la clave del golpe y en la primera y la última (la pose de partida): en las demás se arrastra desde la
	del golpe sin girar el arma sobre su propio eje. Así el arma barre el aire como un golpe de verdad, sin dar vueltas
	sobre sí misma cuando el "arriba" de hoja() cambia de sentido (al cargar, al recoger)"""
	clave = id(accion)
	if clave in _CACHE_Q:
		return _CACHE_Q[clave]
	cl = accion["claves"]
	ts = [t for t, _ in cl]
	n = len(ts)
	vals = [_rellenar(cl, k) for k in _ORIENTACION]
	fs = [_n((vals[0][j], vals[1][j], vals[2][j])) for j in range(n)]
	ups = [_n((vals[3][j], vals[4][j], vals[5][j])) for j in range(n)]
	g = min(range(n), key=lambda j: abs(ts[j] - accion["golpe"]))
	for j in range(g + 1, n - 1):
		ups[j] = _transporta(ups[j - 1], fs[j - 1], fs[j])
	for j in range(g - 1, 0, -1):
		ups[j] = _transporta(ups[j + 1], fs[j + 1], fs[j])
	qs = [_q_de_fu(fs[j], ups[j]) for j in range(n)]
	# entre dos claves casi opuestas (más de ~165°) el camino corto es ambiguo: se elige el sentido en que, a mitad de
	# camino, el arma apunta hacia donde va la mano y hacia delante (la punta va por delante del movimiento)
	ps = [(_rellenar(cl, "a_px")[j], _rellenar(cl, "a_py")[j], _rellenar(cl, "a_pz")[j]) for j in range(n)]
	largo = []
	for j in range(n - 1):
		a, b = qs[j], qs[j + 1]
		if _angulo(a, b) < math.radians(165):
			largo.append(False)
			continue
		mov = _n(tuple(ps[j + 1][i] - ps[j][i] for i in range(3)))

		def nota(q):
			f = _fu_de_q(q)[:3]
			return f[0] * mov[0] + f[1] * mov[1] + f[2] * mov[2] - 0.5 * f[2]
		d = sum(a[i] * b[i] for i in range(4))
		b_largo = b if d < 0 else tuple(-x for x in b)
		largo.append(nota(_slerp_sin_atajo(a, b_largo, 0.5)) > nota(_slerp(a, b, 0.5)) + 0.05)
	_CACHE_Q[clave] = (qs, largo)
	return _CACHE_Q[clave]


def _slerp_sin_atajo(a, b, t):
	"""slerp sin cambiar el signo de b (para ir por el camino largo)"""
	d = max(-1.0, min(1.0, sum(a[i] * b[i] for i in range(4))))
	th = math.acos(d)
	if math.sin(th) < 1e-6:
		return a
	sa, sb = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
	r = tuple(sa * a[i] + sb * b[i] for i in range(4))
	l = math.sqrt(sum(x * x for x in r))
	return tuple(x / l for x in r)


def _orientacion(accion, u):
	cl = accion["claves"]
	ts = [t for t, _ in cl]
	vals = [_rellenar(cl, k) for k in _ORIENTACION]
	qs, largo = _orientaciones_claves(accion)
	# progreso por las claves (0, 1, 2...) con el mismo ritmo de Hermite que las posiciones
	p = _hermite(ts, list(range(len(ts))), u)
	i = max(0, min(len(ts) - 2, int(p)))
	t = max(0.0, min(1.0, p - i))
	if largo[i]:
		a, b = qs[i], qs[i + 1]
		b = b if sum(a[k] * b[k] for k in range(4)) < 0 else tuple(-x for x in b)
		return _fu_de_q(_slerp_sin_atajo(a, b, t))
	return _fu_de_q(_slerp(qs[i], qs[i + 1], t))


def _hermite(ts, vs, u):
	n = len(ts)
	u = max(0.0, min(1.0, u))
	i = 0
	while i < n - 2 and u > ts[i + 1]:
		i += 1
	t0, t1 = ts[i], ts[i + 1]
	h = max(1e-6, t1 - t0)
	s = (u - t0) / h

	def tg(j):
		if j == 0 or j == n - 1:
			return 0.0
		return (vs[j + 1] - vs[j - 1]) / (ts[j + 1] - ts[j - 1])

	m0, m1 = tg(i) * h, tg(i + 1) * h
	s2, s3 = s * s, s * s * s
	return (2 * s3 - 3 * s2 + 1) * vs[i] + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * vs[i + 1] + (s3 - s2) * m1


def pose_accion(accion, u):
	return {k: muestra(accion, k, u) for k in canales(accion["claves"])}

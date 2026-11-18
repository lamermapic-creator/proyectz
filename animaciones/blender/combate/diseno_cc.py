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

def golpe_arma(lista, dur, poses, dos_manos=False):
	"""Carga, entrada, contacto y salida; la empuñadura dibuja un arco continuo."""
	libre = {} if dos_manos else _IZQ_GUARDA
	claves = [(0, une(lista, libre, cuerpo(), {"avance": 0}))]
	for t, (p, frente, giro), avance in zip((0.19, 0.30, 0.40, 0.56), poses, (0, 0.10, 0.22, 0.24)):
		c = cuerpo(cin=(giro, -0.10, -0.04*giro), cue=(-0.42*giro, 0.06, 0),
			cad=(0.12*giro, -0.18, -avance), pel=(0, 0.33*giro, 0))
		claves.append((t, une(arma(p, frente, (0, 0, -1) if dos_manos else (0, 1, 0),
			(1.27 + 0.22*p[0], -0.83 + 0.32*p[1], 0.24 + 0.20*p[2])), libre, c, {"avance": avance})))
	claves.append((1, une(lista, libre, cuerpo(), {"avance": 0.24})))
	return _accion(dur * 0.81, 0.40, claves)


def arco_arma(lista, dur, altura, amplitud, reverso=False, dos_manos=False):
	s = -1 if reverso else 1
	return golpe_arma(lista, dur, [
		((0.45 + s*amplitud*0.80, altura, -0.60), (s*0.63, 0.73, 0.25), -s*0.46),
		((0.45 + s*0.42, altura*0.85, -1.08), (s*0.48, 0.50, -0.70), -s*0.12),
		((0.34, 0.20, -1.58), (-s*0.18, 0.24, -0.95), s*0.30),
		((0.34 - s*amplitud*0.85, -0.13, -1.04), (-s*0.88, -0.20, -0.42), s*0.47),
	], dos_manos)


def golpe_vertical(lista, dur, dos_manos=False):
	return golpe_arma(lista, dur, [
		((0.60, 0.88, -0.52), (0.30, 0.92, 0.20), -0.28),
		((0.53, 0.76, -1.07), (0.20, 0.70, -0.68), -0.12),
		((0.31, 0.27, -1.64), (-0.10, -0.12, -0.98), 0.19),
		((0.18, -0.34, -1.32), (-0.25, -0.72, -0.63), 0.31),
	], dos_manos)


GOLPES = {
	"Cuchillo": [golpe_arma(_LISTA_CUCHILLO, 0.48, [
		((0.67, -0.15, -0.51), (0.12, 0.23, -1), -0.19),
		((0.53, 0.02, -1.16), (0.04, 0.13, -1), 0.03),
		((0.38, 0.12, -1.91), (-0.04, 0.07, -1), 0.28),
		((0.46, 0.06, -1.36), (0.10, 0.17, -1), 0.18),
	]), arco_arma(_LISTA_CUCHILLO, 0.52, 0.34, 0.51, True), golpe_vertical(_LISTA_CUCHILLO, 0.55)],
	"Machete": [arco_arma(_LISTA_MACHETE, 0.71, 0.86, 0.72),
		arco_arma(_LISTA_MACHETE, 0.69, 0.48, 0.64, True), golpe_vertical(_LISTA_MACHETE, 0.76)],
	"Bate": [arco_arma(_LISTA_BATE, 0.87, 0.72, 0.68, dos_manos=True),
		arco_arma(_LISTA_BATE, 0.82, 0.32, 0.53, True, True), golpe_vertical(_LISTA_BATE, 0.92, True)],
}


def puno(nombre, lado, dur, puntos, danio, empuje, tambaleo, pieza="Head"):
	s = 1 if lado == "R" else -1
	otra = "L" if lado == "R" else "R"
	claves = [(0, une(G["manos"], {"avance": 0}))]
	for t, (x, y, z), giro, avance in zip((0.16, 0.27, 0.38, 0.57),
			puntos, (-0.24, -0.05, 0.38, 0.22), (0, 0.05, 0.19, 0.20)):
		brazo = mano(lado, (s*x, y, z), (s*(1.15+x*0.42), -0.92, -0.28),
			(0, 0.12, -1), (s*0.15, 1, 0.12), 0.72)
		guardia = mano(otra, (-s*0.43, 0.66, -1.13), (-s*1.32, -1.16, -0.1))
		c = cuerpo(cin=(s*giro, -0.12, -s*giro*0.14), cue=(-s*giro*0.48, 0.06, 0),
			cad=(s*giro*0.23, -0.21, -avance), pel=(0, s*giro*0.43, 0))
		claves.append((t, une(c, brazo, guardia, {"avance": avance})))
	claves.append((1, une(G["manos"], {"avance": 0.2})))
	return _accion(dur * 0.84, 0.38, claves, nombre=nombre, lado=lado, danio=danio,
		empuje=empuje, tambaleo=tambaleo, pieza=pieza)


RECTO = [(0.44, 0.67, -1.14), (0.38, 0.69, -1.55), (0.25, 0.70, -2.19), (0.39, 0.68, -1.38)]
GANCHO = [(0.66, 0.46, -1.04), (0.88, 0.58, -1.38), (0.26, 0.63, -1.98), (-0.05, 0.65, -1.46)]
ASCENDENTE = [(0.55, -0.10, -0.99), (0.53, -0.08, -1.45), (0.28, 0.62, -2.19), (0.31, 0.75, -1.36)]
PUNOS = [
	puno("directo", "L", 0.40, RECTO, 8, 10, 0.35),
	puno("cruzado", "R", 0.49, RECTO, 11, 16, 0.5),
	puno("gancho", "L", 0.52, GANCHO, 12, 18, 0.6),
	puno("gancho_abajo", "R", 0.55, ASCENDENTE, 13, 22, 0.7),
	puno("al_cuerpo", "L", 0.47, [(x, y-0.73, z) for x,y,z in RECTO], 10, 20, 0.7, "LowerTorso"),
	puno("derechazo", "R", 0.57, GANCHO, 14, 24, 0.8),
]


# Una trayectoria descendente compartida: centro de la mano o empuñadura según el equipo.
def golpe_bajo():
	claves = []
	for t, p, frente, giro, baja, avance in [
		(0, (0.60, 0.16, -0.95), (0, 0.32, -1), 0, 0, 0),
		(0.22, (0.65, 0.58, -0.65), (0.20, 0.72, -0.62), -0.24, -1.12, 0.06),
		(0.43, (0.24, -1.53, -1.72), (0, -0.95, -0.30), 0.30, -2.05, 0.22),
		(0.62, (0.23, -1.38, -1.59), (0, -0.90, -0.42), 0.23, -1.91, 0.23),
		(1, (0.60, 0.16, -0.95), (0, 0.32, -1), 0, 0, 0.23),
	]:
		claves.append((t, une(mano("R", p, (1.43,-0.56,0.12)), arma(p, frente, (0,0,-1)),
			_IZQ_GUARDA, cuerpo(cin=(giro, baja*0.34, 0), cad=(0,baja,-avance),
			cue=(-0.5*giro,baja*0.14,0)), {"avance": avance})))
	return _accion(0.66, 0.43, claves, lado="R", danio=12, empuje=0, tambaleo=0, pieza="UpperTorso")


SUELO = golpe_bajo()

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

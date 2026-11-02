# DISEÑO de la locomoción del superviviente (andar, correr, agachado), hecho para Blender y el juego.
# Sin bpy: lo usan el script de Blender (vista previa) y el exportador.
#
# Fase de la marcha φ (0..1), la misma que Animador.gait_ph / 2π:
#   φ = 0.00  pie izquierdo pasando (en el aire, a mitad de su paso); el derecho, a mitad del apoyo
#   φ = 0.25  apoya el izquierdo (contacto) y despega el derecho
#   φ = 0.50  pie derecho pasando; el izquierdo, a mitad del apoyo
#   φ = 0.75  apoya el derecho y despega el izquierdo
# Las piernas las coloca el juego (pies anclados al suelo, escaleras, cuestas): de aquí salen el movimiento de la
# pelvis, el torso, la cabeza y los brazos (como claves de animación) y la FORMA del paso (curvas del pie en el aire,
# u = 0 al despegar, 1 al apoyar). Ángulos en grados en las tablas; las funciones devuelven radianes y studs.
# Convenciones del juego: Rbx.ang(x, y, z) = Rx·Ry·Rz. Pelvis: pitch < 0 = adelante; yaw > 0 = gira a la izquierda;
# roll > 0 = sube la cadera derecha. Cintura/cuello: waistP < 0 = se inclina adelante. Brazo: hombro x > 0 = adelante.
import math

R = math.radians


def _cr(p0, p1, p2, p3, t, t01=None):
	# Catmull-Rom uniforme
	t2 = t * t
	t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def per(keys, x):
	"""curva periódica (periodo 1) por claves [(φ, valor), ...] ordenadas en [0, 1)"""
	n = len(keys)
	x = x % 1.0
	i = n - 1
	for k in range(n):
		if keys[k][0] > x:
			i = k - 1
			break
	a = keys[i % n]
	b = keys[(i + 1) % n]
	a0 = a[0] if i >= 0 else a[0] - 1.0
	b0 = b[0] if (i + 1) < n and b[0] >= a0 else b[0] + 1.0
	if b0 <= a0:
		b0 += 1.0
	xx = x if x >= a0 else x + 1.0
	t = (xx - a0) / (b0 - a0)
	return _cr(keys[(i - 1) % n][1], a[1], b[1], keys[(i + 2) % n][1], t)


def cur(keys, x):
	"""curva no periódica por claves [(u, valor), ...] con u de 0 a 1"""
	n = len(keys)
	if x <= keys[0][0]:
		return keys[0][1]
	if x >= keys[-1][0]:
		return keys[-1][1]
	i = 0
	while i < n - 2 and x > keys[i + 1][0]:
		i += 1
	a, b = keys[i], keys[i + 1]
	p0 = keys[i - 1][1] if i > 0 else 2 * a[1] - b[1]
	p3 = keys[i + 2][1] if i + 2 < n else 2 * b[1] - a[1]
	t = (x - a[0]) / (b[0] - a[0])
	return _cr(p0, a[1], b[1], p3, t)


def onda(amp, fase=0.0, armonico=1, media=0.0, n=8):
	"""claves de una onda suave (para las tablas): media + amp·sin(2π·armonico·(φ - fase))"""
	return [(k / n, media + amp * math.sin(2 * math.pi * armonico * (k / n - fase))) for k in range(n)]


# ================================================================= ANDAR (~6,5 studs/s)
# Como lo dibujaría un animador (contacto, bajada, paso, subida): la cadera sube al pasar la pierna y baja justo
# después de apoyar; se desplaza sobre el pie de apoyo; gira con la pierna que avanza; la cadera del lado de la
# pierna en el aire cae un poco. Los hombros giran al revés que la cadera y la cabeza se queda estable.
ANDAR = {
	# pelvis (studs y grados)
	"raiz_x": onda(0.055, fase=-0.25),                       # sobre el pie de apoyo: derecha en φ=0
	"raiz_y": [(0.0, 0.045), (0.1, 0.03), (0.27, -0.045), (0.36, -0.02), (0.5, 0.045), (0.6, 0.03), (0.77, -0.045), (0.86, -0.02)],
	"raiz_z": onda(0.02, fase=0.0, armonico=2),              # pequeño avance y freno con cada apoyo
	"pelvis_p": onda(1.5, fase=0.2, armonico=2, media=-1.0),
	"pelvis_y": onda(-6.0),                                   # cadera izquierda adelante al apoyar el izquierdo
	"pelvis_r": onda(-3.5, fase=0.1),                        # cae la cadera de la pierna en el aire
	# torso
	"cintura_p": onda(1.2, fase=0.27, armonico=2, media=-2.5),
	"cintura_y": onda(9.0, fase=0.03),                       # hombros al revés que la cadera (con un poco de retraso)
	"cintura_r": onda(3.0, fase=0.12),
	"cuello_p": onda(-1.0, fase=0.27, armonico=2, media=1.5),
	"cuello_y": onda(-3.0, fase=0.03),
	"cuello_r": onda(-2.0, fase=0.12),
	# brazo derecho (el izquierdo = el mismo medio ciclo después y en espejo)
	"hombro_p": [(0.0, 2.0), (0.12, 14.0), (0.27, 21.0), (0.4, 12.0), (0.5, -2.0), (0.62, -13.0), (0.77, -17.0), (0.9, -10.0)],
	"hombro_y": [(0.0, -2.0), (0.27, -6.0), (0.5, -1.0), (0.77, 2.0)],
	"hombro_r": [(0.0, 5.0), (0.27, 4.0), (0.5, 5.0), (0.77, 7.0)],
	"codo": [(0.0, 14.0), (0.15, 22.0), (0.3, 30.0), (0.45, 22.0), (0.6, 13.0), (0.8, 10.0)],
	"muneca": [(0.0, 4.0), (0.3, 10.0), (0.55, 2.0), (0.8, -4.0)],
	# forma del paso (u = 0 despega, 1 apoya). alto: normalizado (el juego lo escala con su "arco");
	# avance: 0..1 de donde despegó a donde apoya; inclina: giro del pie (< 0 = talón arriba, girando sobre la punta;
	# > 0 = punta arriba, girando sobre el talón), empalmado con el del pie apoyado al despegar y al apoyar
	"pie_alto": [(0.0, 0.0), (0.05, 0.07), (0.14, 0.48), (0.27, 0.95), (0.36, 1.0), (0.5, 0.84), (0.66, 0.56), (0.82, 0.27), (0.94, 0.07), (1.0, 0.0)],
	"pie_avance": [(0.0, 0.0), (0.12, 0.05), (0.3, 0.25), (0.5, 0.52), (0.7, 0.8), (0.88, 0.96), (1.0, 1.0)],
	"pie_inclina": [(0.0, -36.0), (0.12, -30.0), (0.3, -8.0), (0.5, 3.0), (0.72, 8.0), (0.9, 14.0), (1.0, 14.0)],
	"pie_atras": [(0.0, 0.0), (1.0, 0.0)],
}

# ================================================================= CORRER (~18,5 studs/s)
# La cadera BAJA a mitad del apoyo (amortigua) y sube en el vuelo; mucho más giro de cadera y hombros; brazos
# doblados a ~90° bombeando (la mano sube a la altura del pecho y cruza un poco hacia el centro, y atrás llega a la
# cadera); el talón sube hacia el glúteo al despegar y la rodilla tira hacia delante.
CORRER = {
	"raiz_x": onda(0.03, fase=-0.25),
	"raiz_y": [(0.0, -0.13), (0.1, -0.02), (0.2, 0.11), (0.3, 0.02), (0.5, -0.13), (0.6, -0.02), (0.7, 0.11), (0.8, 0.02)],
	"raiz_z": onda(0.04, fase=0.05, armonico=2),
	"pelvis_p": onda(2.5, fase=0.05, armonico=2, media=-3.0),
	"pelvis_y": onda(-12.0, fase=0.02),
	"pelvis_r": onda(-5.0, fase=0.06),
	"cintura_p": onda(2.5, fase=0.05, armonico=2, media=-3.5),
	"cintura_y": onda(19.0, fase=0.05),
	"cintura_r": onda(3.5, fase=0.1),
	"cuello_p": onda(-2.0, fase=0.05, armonico=2, media=3.0),
	"cuello_y": onda(-7.0, fase=0.05),
	"cuello_r": onda(-3.0, fase=0.1),
	"hombro_p": [(0.0, 8.0), (0.1, 34.0), (0.25, 46.0), (0.38, 30.0), (0.5, -6.0), (0.62, -36.0), (0.75, -44.0), (0.88, -26.0)],
	"hombro_y": [(0.0, -6.0), (0.25, -17.0), (0.5, -4.0), (0.75, 4.0)],
	"hombro_r": [(0.0, 10.0), (0.25, 8.0), (0.5, 10.0), (0.75, 14.0)],
	"codo": [(0.0, 88.0), (0.15, 100.0), (0.3, 106.0), (0.45, 92.0), (0.6, 76.0), (0.75, 70.0), (0.9, 76.0)],
	"muneca": [(0.0, 0.0), (0.3, 8.0), (0.6, -2.0), (0.85, -6.0)],
	# en studs a plena carrera (el juego lo mezcla con el de andar según la velocidad)
	"pie_alto": [(0.0, 0.0), (0.05, 0.06), (0.13, 0.32), (0.25, 0.8), (0.38, 1.1), (0.52, 0.95), (0.68, 0.62), (0.84, 0.28), (0.95, 0.07), (1.0, 0.0)],
	"pie_avance": [(0.0, 0.0), (0.18, 0.04), (0.35, 0.2), (0.55, 0.55), (0.75, 0.9), (0.88, 1.02), (1.0, 1.0)],
	"pie_inclina": [(0.0, -45.0), (0.15, -62.0), (0.32, -55.0), (0.5, -22.0), (0.68, 2.0), (0.85, 10.0), (1.0, 5.0)],
	# cuánto se queda el pie por detrás de la línea recta despegue→apoyo (studs; < 0 = por delante: alcanza y
	# "araña" hacia atrás antes de apoyar)
	"pie_atras": [(0.0, 0.0), (0.06, 0.04), (0.2, 0.28), (0.38, 0.28), (0.58, 0.05), (0.8, -0.13), (0.93, -0.05), (1.0, 0.0)],
}

# ================================================================= AGACHADO (andando agachado, ~3,5 studs/s)
# Pasos suaves y largos, rodando el pie; la cadera se mece poco (se desliza a la misma altura), el torso hacia
# delante con los hombros sueltos y los brazos algo adelantados, doblados, listos.
AGACHADO = {
	"raiz_x": onda(0.07, fase=-0.25),
	"raiz_y": [(0.0, 0.025), (0.27, -0.025), (0.5, 0.025), (0.77, -0.025)],
	"raiz_z": onda(0.015, armonico=2),
	"pelvis_p": onda(1.0, fase=0.2, armonico=2, media=-2.0),
	"pelvis_y": onda(-8.0, fase=0.02),
	"pelvis_r": onda(-2.5, fase=0.1),
	"cintura_p": onda(1.0, fase=0.27, armonico=2, media=-2.0),
	"cintura_y": onda(8.0, fase=0.05),
	"cintura_r": onda(2.5, fase=0.12),
	"cuello_p": onda(-1.0, fase=0.27, armonico=2, media=1.0),
	"cuello_y": onda(-4.0, fase=0.05),
	"cuello_r": onda(-2.0, fase=0.12),
	"hombro_p": [(0.0, 26.0), (0.27, 38.0), (0.5, 24.0), (0.77, 14.0)],
	"hombro_y": [(0.0, -4.0), (0.27, -8.0), (0.5, -3.0), (0.77, 0.0)],
	"hombro_r": [(0.0, 10.0), (0.27, 9.0), (0.5, 10.0), (0.77, 12.0)],
	"codo": [(0.0, 50.0), (0.25, 62.0), (0.5, 50.0), (0.75, 42.0)],
	"muneca": [(0.0, 6.0), (0.3, 12.0), (0.55, 6.0), (0.8, 0.0)],
	"pie_alto": [(0.0, 0.0), (0.06, 0.08), (0.16, 0.42), (0.34, 0.85), (0.52, 0.8), (0.72, 0.5), (0.9, 0.15), (1.0, 0.0)],
	"pie_avance": [(0.0, 0.0), (0.15, 0.06), (0.35, 0.3), (0.55, 0.6), (0.75, 0.86), (0.9, 0.97), (1.0, 1.0)],
	"pie_inclina": [(0.0, -30.0), (0.15, -22.0), (0.35, -4.0), (0.6, 4.0), (0.85, 6.0), (1.0, 4.0)],
	"pie_atras": [(0.0, 0.0), (1.0, 0.0)],
}

CICLOS = {"andar": ANDAR, "correr": CORRER, "agachado": AGACHADO}
CANALES = ["raiz_x", "raiz_y", "raiz_z", "pelvis_p", "pelvis_y", "pelvis_r", "cintura_p", "cintura_y", "cintura_r",
	"cuello_p", "cuello_y", "cuello_r", "hombro_p", "hombro_y", "hombro_r", "codo", "muneca"]
CURVAS_PIE = ["pie_alto", "pie_avance", "pie_inclina", "pie_atras"]
EN_GRADOS = {"pelvis_p", "pelvis_y", "pelvis_r", "cintura_p", "cintura_y", "cintura_r", "cuello_p", "cuello_y",
	"cuello_r", "hombro_p", "hombro_y", "hombro_r", "codo", "muneca", "pie_inclina"}


def canal(ciclo, nombre, phi):
	v = per(CICLOS[ciclo][nombre], phi)
	return R(v) if nombre in EN_GRADOS else v


def brazo(ciclo, lado, phi):
	"""hombro (x, y, z) y codo del brazo 'R' o 'L' (el izquierdo: medio ciclo después y en espejo)"""
	f = phi if lado == "R" else phi + 0.5
	s = 1.0 if lado == "R" else -1.0
	return (canal(ciclo, "hombro_p", f), s * canal(ciclo, "hombro_y", f), s * canal(ciclo, "hombro_r", f),
		canal(ciclo, "codo", f), canal(ciclo, "muneca", f))


def pie(ciclo, nombre, u):
	v = cur(CICLOS[ciclo][nombre], u)
	return R(v) if nombre in EN_GRADOS else v


# ================================================================= SALTO
# Por la fase del salto t (0 = despegue, 0,3 = subiendo con las piernas recogidas, 0,6 = bajando, 1 = a punto de
# tocar el suelo). "a" = la pierna que va delante (la que se levanta) y el brazo de su mismo lado; "b" = la otra.
# Piernas: posición del tobillo respecto a la cadera (y en largos de pierna, < 0 = abajo; z en studs, < 0 = delante);
# "abre" separa los pies a los lados (x la distancia de la cadera). Ángulos en grados.
SALTO = {
	# parado: los brazos, que estaban atrás al agacharse para coger impulso, suben por delante, rodillas recogidas arriba, y al caer las piernas se estiran por delante y
	# los brazos se abren para equilibrarse
	"parado": {
		"pa_y": [(0.0, -0.96), (0.3, -0.6), (0.6, -0.66), (0.85, -0.82), (1.0, -0.88)],
		"pa_z": [(0.0, -0.05), (0.3, -0.32), (0.6, -0.3), (1.0, -0.32)],
		"pb_y": [(0.0, -0.96), (0.3, -0.64), (0.6, -0.7), (0.85, -0.84), (1.0, -0.9)],
		"pb_z": [(0.0, 0.05), (0.3, -0.2), (0.6, -0.18), (1.0, -0.12)],
		"abre": [(0.0, 1.0), (0.3, 1.12), (0.6, 1.2), (1.0, 1.32)],
		"ba_p": [(0.0, -25.0), (0.12, 35.0), (0.28, 92.0), (0.45, 74.0), (0.7, 42.0), (1.0, 28.0)],
		"ba_r": [(0.0, 8.0), (0.3, 12.0), (0.6, 26.0), (1.0, 38.0)],
		"ba_codo": [(0.0, 16.0), (0.15, 22.0), (0.3, 34.0), (0.6, 28.0), (1.0, 24.0)],
		"bb_p": [(0.0, -25.0), (0.12, 35.0), (0.28, 92.0), (0.45, 74.0), (0.7, 42.0), (1.0, 28.0)],
		"bb_r": [(0.0, 8.0), (0.3, 12.0), (0.6, 26.0), (1.0, 38.0)],
		"bb_codo": [(0.0, 16.0), (0.15, 22.0), (0.3, 34.0), (0.6, 28.0), (1.0, 24.0)],
		"pelvis_p": [(0.0, 0.0), (0.3, 5.0), (0.6, 3.0), (1.0, -3.0)],
		"cintura_p": [(0.0, 5.0), (0.3, -3.0), (0.6, -5.0), (1.0, -9.0)],
		"cuello_p": [(0.0, -3.0), (0.3, 3.0), (0.6, 6.0), (1.0, 9.0)],
	},
	# corriendo: zancada en el aire (la rodilla delantera arriba, la pierna de atrás estirada y luego doblada), brazos
	# al revés que las piernas, y al bajar la pierna delantera se estira para recibir el suelo
	"corriendo": {
		"pa_y": [(0.0, -0.88), (0.3, -0.52), (0.6, -0.6), (0.85, -0.8), (1.0, -0.85)],
		"pa_z": [(0.0, -0.4), (0.3, -0.82), (0.6, -0.78), (0.85, -0.6), (1.0, -0.5)],
		"pb_y": [(0.0, -0.95), (0.3, -0.8), (0.6, -0.68), (0.85, -0.78), (1.0, -0.86)],
		"pb_z": [(0.0, 0.55), (0.3, 0.78), (0.6, 0.42), (0.85, 0.12), (1.0, 0.0)],
		"abre": [(0.0, 1.0), (0.5, 1.05), (1.0, 1.2)],
		"ba_p": [(0.0, -30.0), (0.3, -42.0), (0.6, -24.0), (1.0, 8.0)],
		"ba_r": [(0.0, 10.0), (0.3, 14.0), (0.6, 22.0), (1.0, 30.0)],
		"ba_codo": [(0.0, 70.0), (0.3, 75.0), (0.6, 55.0), (1.0, 38.0)],
		"bb_p": [(0.0, 48.0), (0.3, 58.0), (0.6, 42.0), (1.0, 22.0)],
		"bb_r": [(0.0, 8.0), (0.3, 12.0), (0.6, 22.0), (1.0, 30.0)],
		"bb_codo": [(0.0, 88.0), (0.3, 92.0), (0.6, 66.0), (1.0, 42.0)],
		"pelvis_p": [(0.0, 3.0), (0.3, 6.0), (0.6, 3.0), (1.0, -3.0)],
		"cintura_p": [(0.0, -9.0), (0.3, -8.0), (0.6, -5.0), (1.0, -8.0)],
		"cuello_p": [(0.0, 6.0), (0.3, 6.0), (0.6, 7.0), (1.0, 9.0)],
	},
}
SALTO_GRADOS = {"ba_p", "ba_r", "ba_codo", "bb_p", "bb_r", "bb_codo", "pelvis_p", "cintura_p", "cuello_p"}


def salto(tipo, canal, t):
	v = cur(SALTO[tipo][canal], t)
	return R(v) if canal in SALTO_GRADOS else v


# ================================================================= CUERPO A TIERRA
# TUMBARSE por pb (0 de pie .. 1 tumbado boca abajo; al levantarse se recorre al revés). Las PIERNAS van por IK a
# sitios del suelo (así los pies y las rodillas nunca se meten en el suelo ni flotan, también en cuestas):
#   pie plantado (donde estaba) --(peso "X_rodilla")--> arrodillado: la rodilla al suelo bajo la cadera (o detrás si
#   la cadera ya está baja), la espinilla hacia atrás y la punta del pie en el suelo (de puntillas; tumbado, el
#   empeine contra el suelo).
#   0.00-0.30 se agacha (los pies quietos)    0.30-0.48 la rodilla izquierda al suelo    0.50-0.66 la derecha
#   0.45-0.65 manos al suelo                  0.65-1.00 la cadera baja y las piernas se estiran atrás
# "baja" = fracción de la bajada de la pelvis hasta el suelo; "inclina" = pelvis hacia delante (< 0 = la cabeza al
# suelo). Ángulos en grados.
TUMBAR = {
	"inclina": [(0.0, 0.0), (0.3, -16.0), (0.5, -22.0), (0.62, -50.0), (0.75, -70.0), (0.88, -84.0), (1.0, -88.0)],
	"baja": [(0.0, 0.0), (0.3, 0.03), (0.5, 0.05), (0.62, 0.06), (0.75, 0.35), (0.88, 0.78), (1.0, 1.0)],
	"L_rodilla": [(0.0, 0.0), (0.3, 0.0), (0.39, 0.5), (0.48, 1.0), (1.0, 1.0)],
	"R_rodilla": [(0.0, 0.0), (0.5, 0.0), (0.58, 0.5), (0.66, 1.0), (1.0, 1.0)],
	"cintura_p": [(0.0, 0.0), (0.3, -10.0), (0.5, -16.0), (0.62, -12.0), (0.78, 2.0), (1.0, 10.0)],
	"cuello_p": [(0.0, 0.0), (0.3, 6.0), (0.5, 12.0), (0.62, 26.0), (0.78, 52.0), (1.0, 72.0)],
}

# REPTAR (cuerpo a tierra, a lo militar): fase φ = crawl / 2π. La rodilla derecha sube por el COSTADO, a ras de suelo
# (la espinilla plana, el pie nunca hacia el cielo), a la vez que avanza el brazo izquierdo (φ = 0,25); la izquierda
# medio ciclo después. "rodilla_sube" (0..1): cuánto sube la rodilla; con ella el pie se acerca y sale hacia fuera.
REPTAR = {
	"rodilla_sube": [(0.0, 0.35), (0.12, 0.8), (0.25, 1.0), (0.38, 0.8), (0.5, 0.35), (0.62, 0.08), (0.75, 0.0), (0.88, 0.08)],
	"pelvis_y": onda(5.0, fase=0.0),
	"pelvis_r": onda(-8.0, fase=0.02),
	"sube": onda(0.06, fase=0.0, armonico=2, media=0.04),
	"cintura_y": onda(-7.0, fase=0.05),
	"cintura_r": onda(4.0, fase=0.05),
	"cuello_y": onda(4.0, fase=0.05),
}
TIERRA_GRADOS = lambda c: c not in ("baja", "sube", "L_rodilla", "R_rodilla", "rodilla_sube")


def tumbar(canal, pb):
	v = cur(TUMBAR[canal], pb)
	if canal.endswith("_rodilla") or canal == "baja":
		v = max(0.0, min(1.0, v))
	return R(v) if TIERRA_GRADOS(canal) else v


def reptar(canal, phi):
	v = per(REPTAR[canal], phi)
	return R(v) if TIERRA_GRADOS(canal) else v


# ================================================================= SORTEAR OBSTÁCULOS (p = progreso 0..1)
# Curvas de peso 0..1 (todas empiezan y terminan con pendiente cero: sin tirones al empezar ni al acabar).
# VALLA (saltar por encima apoyando las manos): "giro" = cuánto se tumba de lado la cadera al pasar las piernas por
# encima (máximo justo encima); "recoge" = piernas recogidas hacia el lado; "aterriza" = piernas abajo para caer.
# TREPAR (encaramarse a algo alto): "tira" = cuánto tira de los brazos y mete el pecho por encima; "pared" = los
# pies apoyados en la pared; "sube_R" / "sube_L" = la rodilla derecha y luego la izquierda arriba del borde.
SORTEAR = {
	"valla_giro": [(0.0, 0.0), (0.08, 0.02), (0.25, 0.5), (0.42, 0.95), (0.5, 1.0), (0.62, 0.85), (0.78, 0.4), (0.9, 0.1), (1.0, 0.0)],
	"valla_recoge": [(0.0, 0.0), (0.06, 0.12), (0.14, 0.62), (0.22, 0.95), (0.3, 1.0), (1.0, 1.0)],
	"valla_aterriza": [(0.0, 0.0), (0.64, 0.0), (0.72, 0.25), (0.82, 0.75), (0.92, 1.0), (1.0, 1.0)],
	"trepar_tira": [(0.0, 0.0), (0.08, 0.04), (0.25, 0.55), (0.45, 0.98), (0.55, 1.0), (0.72, 0.72), (0.88, 0.22), (1.0, 0.0)],
	"trepar_pared": [(0.0, 0.0), (0.12, 0.0), (0.2, 0.4), (0.3, 0.92), (0.36, 1.0), (1.0, 1.0)],
	"trepar_sube_R": [(0.0, 0.0), (0.42, 0.0), (0.5, 0.25), (0.6, 0.78), (0.68, 1.0), (1.0, 1.0)],
	"trepar_sube_L": [(0.0, 0.0), (0.58, 0.0), (0.66, 0.25), (0.76, 0.78), (0.84, 1.0), (1.0, 1.0)],
}


def sortear(canal, p):
	return max(0.0, min(1.0, cur(SORTEAR[canal], p)))


# ================================================================= COLGADO de una cornisa
# QUIETO (fase = tiempo / 2,8 s): el cuerpo cuelga y se mece despacio como un péndulo (las dos piernas a la vez hacia
# la pared y hacia fuera), una rodilla se dobla buscando apoyo con la punta del pie y luego la otra; respira con
# esfuerzo. MOVER (fase = la del paso de manos, hg.ph / 2π): las piernas siguen a las manos con retraso, la cadera se
# balancea hacia el lado al que va y la rodilla del lado que se adelanta se dobla. Pierna derecha; la izquierda en
# espejo (QUIETO: un poco desfasada; MOVER: medio ciclo después). En studs y grados.
COLGADO = {
	"q_lado": [(0.0, 0.0), (0.25, 0.04), (0.5, 0.0), (0.75, -0.04)],
	"q_alto": [(0.0, 0.0), (0.15, 0.12), (0.3, 0.22), (0.45, 0.1), (0.6, 0.0), (0.8, 0.0)],
	"q_pared": [(0.0, 0.55), (0.25, 0.66), (0.5, 0.74), (0.75, 0.62)],
	"q_cintura_p": [(0.0, 5.0), (0.25, 6.5), (0.5, 7.5), (0.75, 6.0)],
	"q_cintura_r": [(0.0, 0.0), (0.25, 2.5), (0.5, 0.0), (0.75, -2.5)],
	"q_cintura_y": [(0.0, 0.0), (0.25, -3.0), (0.5, 0.0), (0.75, 3.0)],
	"q_cuello_p": [(0.0, 13.0), (0.25, 12.0), (0.5, 11.0), (0.75, 12.0)],
	"q_cuello_y": [(0.0, 0.0), (0.3, 6.0), (0.55, 0.0), (0.8, -6.0)],
	"m_lado": [(0.0, -0.12), (0.25, 0.1), (0.5, 0.36), (0.75, 0.12)],
	"m_alto": [(0.0, 0.0), (0.2, 0.05), (0.45, 0.28), (0.6, 0.38), (0.75, 0.18), (0.9, 0.03)],
	"m_pared": [(0.0, 0.58), (0.3, 0.6), (0.6, 0.74), (0.85, 0.64)],
	"m_cintura_r": [(0.0, -3.0), (0.25, 0.0), (0.5, 3.0), (0.75, 0.0)],
	"m_cadera_lado": [(0.0, -0.06), (0.25, 0.0), (0.5, 0.06), (0.75, 0.0)],
}


def colgado(canal, phi):
	v = per(COLGADO[canal], phi)
	return R(v) if ("cintura" in canal or "cuello" in canal) else v

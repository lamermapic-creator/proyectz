class_name Animador
extends Node
## Port de StarterPlayerScripts.ProceduralAnimator (Roblox): animación 100 % procedural.
## Cada fotograma calcula TODAS las articulaciones del muñeco:
##  · Pies anclados al suelo con IK: pasos colocados según velocidad (sin deslizar), arco de paso,
##    despegue de puntera, desniveles, pasos de ajuste al girar o parar.
##  · Cadera: altura según zancada, rebote, caída y giro con cada paso. Torso: contrarrotación,
##    inclinación por velocidad/aceleración/curvas, respiración. Brazos: balanceo opuesto a las piernas.
##  · Saltos por fases, sortear obstáculos (vault / mantle), agacharse, cuerpo a tierra por fases,
##    reptar, rodar boca arriba, asomarse, reacciones (pared delante, agotamiento, herida) y miradas.
## (Las armas, la moto, el coche y el ragdoll se portan en las siguientes etapas.)

const C = preload("res://scripts/config/zconfig.gd")
const Muelle = Rbx.Muelle

@export var jugador: Jugador

var rig: RigPersonaje
var M := {}
var P := {}

## ---------------------------------------------------------------- estado del rig (r.* en Roblox)
var arm := {}
var leg := {}
var leg_len := 0.0
var hip_x := 0.0
var min_foot_x := 0.0
var foot_half := 0.0
var ankle_in_foot := {}
var wrist_in_hand := {}
var S := {}
var pelvis_drop := 0.0
var pelvis_drop_v := 0.0   # velocidad del muelle de pelvis_drop
## arma contra una pared: primero se recoge hacia el cuerpo (RETRO_MAX studs, sigue apuntando) y solo si no
## basta, extremadamente pegado, se levanta (ALZA_RECORRIDO studs más para quedar del todo levantada)
const ALZA_ACTIVA := false   # levantar el arma pegado a una pared: DESACTIVADO a pedido de KangooG (molestaba
							 # al jugar). Solo se recoge hacia el cuerpo. Poner true para volver a activarlo
const ALZA_MARGEN := 0.1     # studs más allá de la boca del cañón a los que empieza a recogerse
const RETRO_MAX := 0.7       # cuánto se puede recoger el arma hacia el cuerpo
const ALZA_RECORRIDO := 0.8
var arma_retro := 0.0        # 0-1: arma recogida hacia el cuerpo por tener una pared delante
var arma_alzada := 0.0 # 0-1: arma levantada por tener una pared delante (no se puede disparar)
var conv_w := 0.0 # 0-1: cuánto se orienta el cañón hacia el punto de la mira
var conv_q := Quaternion.IDENTITY
var agache_techo := 0.0 # agachado bajo un techo bajo: cuánto más se agacha
var lat_k := 0.0 # 0-1: cuánto se anda de lado (pasos laterales)
var prev_lv := Vector3.ZERO
var acc := Vector3.ZERO
var prev_yaw := 0.0
var yaw_rate := 0.0
var breath_t := 0.0
var heat := 0.0
var look := Vector3.ZERO
var glance_yaw := 0.0
var glance_at := 0.0
var fall_max := 0.0
var idle_t := 0.0
var feet := {}
var replant := false
var prone := 0.0
var crouch_b := 0.0
var lean_s := 0.0
var was_vault := false
var prev_t := {}
var crawl := 0.0
var crawl_amt := 0.0
var roll_t := 0.0
var roll_side := 1.0
var rl := 0.0
# MOVERSE BOCA ARRIBA (2026-11-03, Movimientos.BOCA_ARRIBA)
var sup_ph := 0.0           # fase del ciclo (0..1)
var sup_amt := 0.0          # 0 quieto, 1 moviéndose
var sup_dir := Vector2(1, 0) # dirección de la marcha respecto al cuerpo (x derecha, y hacia atrás = hacia los pies)
var sup_mov_k := 0.0        # peso del ciclo este fotograma (para los brazos)
static var _sup_c := NAN    # centrado de las curvas (media de φ - cadera)
var last_prone_t := -9.0
## estado del suavizado "de muelle" (smooth_j2) de cada articulación
var muelle_q := {}   # estado del muelle de cada articulación (giro), aparte de lo que se muestra
var vel_j := {}
var muelle_p := {}   # (posición, para la cadera)
var vel_p := {}      # velocidad de giro de cada articulación (para el suavizado de muelle)
var get_up = null
var air_start := 0.0
var jump_lead := "R"
var jump_run := 0.0
var air_fall := 0.0
var was_grounded = null
var rel_aim := 0.0
## ---- apuntado en la moto con arma de fuego (2026-10-30; 2026-11-01: SOLO el brazo derecho, la izquierda
## nunca suelta el manillar). Dos "ramas" para cubrir las 360°: "L" = delante, a la derecha y a la izquierda (cruzando
## el brazo por delante del pecho) y "B" = detrás por encima del hombro derecho. Entre ambas, por detrás a la
## izquierda, hay una costura con margen: al cruzarla el brazo pasa el arma por delante del pecho (cañón arriba)
const GOLPE_MOTO_IZQ := 1.15 # golpes en la moto (siempre con la derecha): hasta dónde gira el torso
const GOLPE_MOTO_DER := 2.1
const COSTURA_IZQ := 2.85    # rama "L": cruzando el pecho hasta ~163° a la izquierda...
const COSTURA_ATRAS := 2.6   # ...rama "B": por encima del hombro derecho hasta ~149° a la izquierda (por detrás)
## cuánto tarda el brazo en pasar por delante del pecho: 0,7-1,3 s según el recorrido (ver _dur_cambio)
const MOTO_CAMBIO_DUR := 0.8
const GIRO_W := 7.0          # muelle del giro de torso y brazo al apuntar en la moto (rad/s)
const GIRO_VMAX := 4.5       # velocidad máxima de ese giro (rad/s, ~260°/s)
const GIRO_ACEL := 30.0      # aceleración máxima (rad/s²): sin arranques ni frenazos bruscos
var moto_giro_vel := 0.0
## ---- posturas de pie con armas de fuego hechas en Blender (PosturasPie), suavizadas al cambiar de estado
var pie_k := 0.0             # 0-1: cuánto manda la postura de Blender (de pie con arma de fuego)
var pie_w := Vector3.ZERO    # giro de la cintura (Y, P, R) de la postura
var pie_n := Vector3.ZERO    # giro del cuello (Y, P, R)
var pie_polo_r := Vector3(1.9, -1.4, 0.9)  # polos de los codos (marco del pecho girado con el rumbo)
var pie_polo_l := Vector3(-1.9, -1.5, 0.3)
var moto_fuego := false      # en la moto con un arma de fuego en la mano (este fotograma)
var moto_mano := "R"         # mano que lleva el arma en la moto (siempre la derecha)
var moto_rama := "L"         # "L" por delante / izquierda, "B" por detrás sobre el hombro derecho
var moto_cambio = null       # {t0, de, a, rel_de, dur}: pasando el brazo de una rama a la otra
var moto_apunta_k := 0.0     # 0-1: brazo apuntando (pose de Blender) vs. arma baja (IK)
var moto_rama_brazo := "L"   # rama en la que está el brazo este fotograma
var moto_h_arma := "R"       # mano que sostiene el arma (siempre la derecha)
var moto_pose: Array = []    # pose de Blender de este fotograma: Waist, Neck, RightShoulder, RightElbow, RightWrist
var moto_corr_q := Quaternion.IDENTITY # pequeña corrección de la muñeca para que el cañón vaya a la mira
var feet_aim := 0.0
var _entrada_apuntar := 0.0
var prone_rel := 0.0
var w_side := {"L": 0.0, "R": 0.0}
var step_k := 0.4
var stumble_until := 0.0
var head_corr := 0.0
var fat := 0.0 # cansancio 0..1 (andar con fatiga)
var replant_paso := false # al recolocar los pies, dejar uno adelantado (tras trepar: arranca con paso natural)
var air_runoff := false   # en el aire sin haber saltado (salir corriendo de un borde, tras un salto de valla)
# fase continua de la marcha (brazos y torso fluidos)
var gait_ph := 0.0
var gait_rate := 0.0
var gait_amp := 0.0
# ciclos de la marcha hechos en Blender (Movimientos, 2026-11-02): mezcla andar / correr / agachado y amplitud
var mez_run := 0.0     # 0 andar, 1 correr (según la velocidad, como run01 de los pasos)
var mez_pie_run := 0.0 # lo mismo, para la forma del paso (sin suavizar: el de update_feet)
var amp_ciclo := 0.0   # 0 quieto, 1 a la velocidad para la que está hecho el ciclo
var gait01 := 0.0       # reloj de la marcha (0..1): marca cuándo despega y apoya cada pie (ver update_feet)
var reloj_activo := false
var ultimo_pie := ""     # el último pie que dio un paso con el reloj (el siguiente siempre es el otro)
var ritmo_periodo := 1.0
# PIERNAS ANIMADAS (2026-11-03): en marcha los pies siguen la animación de Blender (Movimientos.PIERNAS)
var anim_w := 0.0              # 0 pies anclados (parado), 1 piernas animadas (mezcla corta al arrancar)
var anim_sentido := 1.0        # 1 la animación va hacia delante; -1 al revés (andar hacia atrás)
var anim_cruce := 0.0          # mezcla al cambiar de sentido
var anim_cruce_desde := {}     # posición de cada pie (respecto al cuerpo) al cambiar de sentido
var anim_local := {}           # posición de cada pie respecto al cuerpo en el último fotograma
var anim_aire := false         # viene de un salto o caída (al aterrizar, sin mezcla)
const ANIM_MIN_X := 0.24
const SUP_CURVA := 1.0       # signo de la curva de la espalda al moverse boca arriba (comprobado en el juego)
var anim_zan := 0.0            # zancada usada (cambia suave: al llegar a una escalera, al acelerar...)
var anim_parando := 0.0
var aire_corto_t := 0.0        # se está parando: el pie que iba en el aire termina el paso (segundos)
# ESCALERAS (2026-11-03): un escalón por paso (corriendo, uno o dos)
var esc_fondo := 0.0           # fondo de los escalones de la escalera por la que va (0 = no hay escalera)
var esc_bordes: Array = []     # bordes de los escalones (puntos del mundo) a lo largo de la marcha
var esc_dir := Vector3.ZERO    # dirección (mundo) en la que se midieron
var esc_visto := -10.0
var _esc_n := 0       # distancia mínima de cada pie a la línea del centro (corriendo se pisa casi en línea)
var air_tj := 0.0      # fase del salto (0 despegue .. 1 a punto de aterrizar), para Movimientos.SALTOS
var sw_prev := {"L": false, "R": false}
var last_step_t := -9.0
var step_start := {"L": -9.0, "R": -9.0}
var run_cycle := 0.0
# armas (r.* del ProceduralAnimator)
var last_tool := ""
var pose_rel = null          # Transform3D: pose del arma relativa al pecho (con inercia)
var reload_st = null         # {w, start, dur, fired}
var melee_st = null          # {w, start, dur}
var draw_st = null           # {t0, tool, start}
var last_shot_t := -9.0
var blade := 0.0
var hand_mag: Node3D = null
var tool_shown := true
var was_hang := false
var swing_arma := 0.0
var levantarse = null     # tras un ragdoll: {t0, arriba} (ver Jugador._ragdoll_levantarse)
var pie_moto := 0.0      # en la moto, parado: el pie izquierdo baja al suelo (0-1)
var moto_de_pie := 0.0   # en la moto, en el aire: se levanta sobre los estribos
var correr_libre := false
# combate cuerpo a cuerpo (2026-11-08; poses de Blender en CombateCC, reglas en Arsenal.cc): ver _paso_cc
var cc_guard_w := 0.0       # guardia (0-1, suave)
var cc_block_w := 0.0       # bloqueo (0-1, suave)
var cc_pose := {}           # canales de este fotograma (brazos y arma: absolutos; cuerpo: se suman)
var cc_w := 0.0             # cuánto mandan los brazos / el arma de CombateCC (0 = la pose de siempre)
var cc_kick = null          # patada: {lado, w} (la pierna en cc_pose: pie_*, ro_*)
var cc_rapido := false      # en plena acción: brazos sin retraso
var cc_clase := ""
var cc_handle_cf = null     # el Handle del arma este fotograma (para la mano izquierda en el arma larga)
const CC_AGARRE := {"Machete": Vector3(0, 0.06, -0.95), "Palanca": Vector3(0, 0, -1.05), "Bate": Vector3(0, 0, -1.2),
	"Hacha": Vector3(0, 0, -1.2), "Cuchillo": Vector3(0, 0, -0.3)}


## Una extremidad para la IK analítica (Motor6D)
class Limb:
	var top: RigPersonaje.Motor
	var mid: RigPersonaje.Motor
	var fin: RigPersonaje.Motor
	var p1: Vector3
	var p2: Vector3
	var q1: Vector3
	var q2: Vector3
	var a: float
	var b: float
	var bU: Transform3D
	var bL: Transform3D
	var hinge: float


func ahora() -> float:
	return jugador.reloj # reloj del juego


## ---------------------------------------------------------------- apuntado en la moto (360°)
## mano que lleva el arma (siempre la derecha; se mantiene la función para quien la consulte)
func moto_mano_obj() -> String:
	return "R"


## rama en la que acaba el brazo (la de destino si está pasando de una a otra)
func moto_rama_obj() -> String:
	return String(moto_cambio.a) if moto_cambio != null else moto_rama


## pasando el brazo de una rama a otra (no se puede disparar hasta que el arma vuelve a salir hacia la mira)
func moto_cambiando() -> bool:
	return moto_cambio != null and ahora() - float(moto_cambio.t0) < float(moto_cambio.dur) * 0.7


## ángulo de la mira respecto a la moto (+ = izquierda) tal y como lo sigue el brazo en la rama dada (sin saltos
## dentro de la rama: en "B", detrás a la izquierda se cuenta como pasado de -180°)
static func _angulo_en_rama(rama: String, rel: float) -> float:
	if rama == "B" and rel > 0.0:
		return rel - TAU
	return rel


func angulo_mira(rel: float) -> float:
	return _angulo_en_rama(moto_rama_obj(), rel)


func _paso_mano_moto(apunta: bool, rel: float, now: float) -> void:
	if moto_cambio != null:
		if now - float(moto_cambio.t0) < float(moto_cambio.dur):
			return
		moto_rama = String(moto_cambio.a)
		moto_cambio = null
	if not apunta:
		if moto_rama == "B" and rel_aim >= -PI:
			moto_rama = "L"
		return
	if moto_rama == "B":
		# por encima del hombro derecho. En el lado derecho las dos ramas coinciden (se cambia sin que se note);
		# si la mira se va a la izquierda por delante, sigue la rama normal (abajo)
		if rel <= 0.0:
			moto_rama = "L"
			return
		if rel >= COSTURA_ATRAS:
			return
		moto_rama = "L"
	if rel > COSTURA_IZQ:
		# detrás a la izquierda, más allá de lo que el brazo alcanza cruzando el pecho: por encima del hombro
		# derecho. Si el brazo va por delante o por la derecha, barre hasta ahí por la derecha; si va cruzado hacia
		# detrás a la izquierda, pasa el arma por delante del pecho (cambio animado) y el ángulo se cuenta desde el
		# otro lado (mismo sitio)
		if rel_aim > PI / 2:
			# (rel_de: hacia donde apuntaba el brazo; sigue ahí mientras lleva el arma al centro)
			moto_cambio = {"t0": now, "de": "L", "a": "B", "rel_de": rel_aim, "dur": _dur_cambio(rel_aim, rel - TAU)}
			rel_aim -= TAU
		else:
			moto_rama = "B"
		return
	# la mira salta por detrás de un lado al otro (de detrás a la derecha a detrás a la izquierda): en vez de dar
	# la vuelta entera con el brazo estirado, el arma pasa por delante del pecho. Hacia delante, en cambio, el
	# brazo barre por su camino natural (el muelle de rel_aim limita la velocidad)
	var viaje := rel - rel_aim
	if absf(viaje) > PI + 0.3 and absf(rel) > PI / 2:
		moto_cambio = {"t0": now, "de": "L", "a": "L", "rel_de": rel_aim, "dur": _dur_cambio(rel_aim, rel)}
		rel_aim += TAU * signf(viaje)


## duración del paso por delante del pecho: de donde apunta el brazo hasta delante, y de delante hasta la mira
static func _dur_cambio(desde: float, hasta: float) -> float:
	return clampf(0.27 * (absf(Rbx.wrap_a(desde)) + absf(Rbx.wrap_a(hasta))), 0.7, 1.3)


## hombro de la cámara al apuntar desde la moto (1 derecha, -1 izquierda de la pantalla). Apuntando hacia atrás
## por encima del hombro derecho, ese brazo queda a la izquierda de la pantalla. Con margen en el costado derecho
var _lado_cam := 1.0
func lado_camara_moto(rel: float) -> float:
	var a := angulo_mira(rel)
	if a < -(PI / 2 + 0.3):
		_lado_cam = -1.0
	elif a > -(PI / 2 - 0.3):
		_lado_cam = 1.0
	return _lado_cam


func _soltar_mano_moto() -> void:
	moto_cambio = null
	moto_rama = "L"
	moto_mano = "R"


## postura de pie de Blender para el arma y el estado: se acerca a ella con suavidad (ritmo del arma)
func _paso_postura_pie(tool: String, estado: String, pc: float, activa: bool, ritmo: float, dt: float) -> void:
	var b := Armas.base(tool)
	var tabla: Dictionary = PosturasPie.DATOS.get(b, {})
	if not activa or tabla.is_empty() or not tabla.has(estado):
		pie_k = Rbx.damp(pie_k, 0.0, 8.0, dt)
		return
	var d: Dictionary = tabla[estado]
	var k := 1.0 if estado in ["AIM", "HIP"] else (0.35 if estado == "LOW" else 0.0)
	var w_obj := Vector3(-float(d.blade), float(d.lean) + PosturasPie.PC_CINTURA * pc * k, 0.0)
	var n_obj := Vector3(float(d.blade) * 0.9, float(d.nP) + PosturasPie.PC_CUELLO * pc * k - float(d.lean) * 0.6, float(d.nR))
	var r := minf(ritmo, 9.0)
	pie_w = pie_w.lerp(w_obj, 1.0 - exp(-r * dt))
	pie_n = pie_n.lerp(n_obj, 1.0 - exp(-r * dt))
	pie_polo_r = pie_polo_r.lerp(d.polo_r, 1.0 - exp(-r * dt))
	pie_polo_l = pie_polo_l.lerp(d.polo_l, 1.0 - exp(-r * dt))
	pie_k = Rbx.damp(pie_k, 1.0, 8.0, dt)


## ---- poses de Blender (PosesMoto): muestreo de la rejilla ángulo x cabeceo (interpolación esférica bilineal)
static func _q_hacia(q: Quaternion, ref: Quaternion) -> Quaternion:
	return -q if q.dot(ref) < 0.0 else q


static func _muestrear(a: float, p: float) -> Array:
	var A: Array = PosesMoto.ANGULOS
	var PP: Array = PosesMoto.CABECEOS
	a = clampf(a, float(A[0]), float(A[A.size() - 1]))
	p = clampf(p, float(PP[0]), float(PP[PP.size() - 1]))
	var fa := (a - float(A[0])) / (float(A[1]) - float(A[0]))
	var ia := clampi(int(floor(fa)), 0, A.size() - 2)
	var ta := clampf(fa - ia, 0.0, 1.0)
	var ip := 0
	while ip < PP.size() - 2 and p > float(PP[ip + 1]):
		ip += 1
	var tp := clampf((p - float(PP[ip])) / (float(PP[ip + 1]) - float(PP[ip])), 0.0, 1.0)
	var f0: Array = PosesMoto.REJILLA[ip]
	var f1: Array = PosesMoto.REJILLA[ip + 1]
	var res := []
	for j in PosesMoto.ARTICULACIONES.size():
		var q00: Quaternion = f0[ia][j]
		var q01: Quaternion = _q_hacia(f0[ia + 1][j], q00)
		var q10: Quaternion = _q_hacia(f1[ia][j], q00)
		var q11: Quaternion = _q_hacia(f1[ia + 1][j], q00)
		var qa := q00.slerp(q01, ta)
		var qb := q10.slerp(q11, ta)
		res.append(qa.slerp(_q_hacia(qb, qa), tp).normalized())
	return res


## pose de apuntado de este fotograma: la de la rejilla, o al cruzar por detrás a la izquierda (moto_cambio) el paso
## por la pose RECOGIDA (arma delante del pecho, cañón arriba) con una curva suave que no se para en medio
func _pose_moto(a: float, p: float, now: float) -> Array:
	var fin := _muestrear(a, p)
	moto_rama_brazo = moto_rama
	if moto_cambio == null:
		return fin
	var u := clampf((now - float(moto_cambio.t0)) / float(moto_cambio.dur), 0.0, 1.0)
	moto_rama_brazo = String(moto_cambio.de) if u < 0.5 else String(moto_cambio.a)
	var ini := _muestrear(float(moto_cambio.rel_de), p)
	var mid: Array = PosesMoto.RECOGIDA[-1 if String(moto_cambio.a) == "B" else 1]
	var e := Rbx.smooth(u)
	var res := []
	for j in fin.size():
		var q0: Quaternion = ini[j]
		var q1: Quaternion = _q_hacia(mid[j], q0)
		var q2: Quaternion = _q_hacia(fin[j], q1)
		var q: Quaternion
		if e < 0.5:
			q = q0.spherical_cubic_interpolate(q1, q0, q2, e * 2.0)
		else:
			q = q1.spherical_cubic_interpolate(q2, q0, q2, e * 2.0 - 1.0)
		res.append(q.normalized())
	return res


## corrección de la muñeca: el cañón real (fotograma anterior) hacia la mira; poco a poco y como mucho ~25°
func _paso_correccion_moto(mdl: Node3D, dt: float) -> void:
	var activa := moto_fuego and moto_apunta_k > 0.9 and moto_cambio == null and mdl != null and mdl.has_node("Muzzle")
	if activa:
		var mz := (mdl.get_node("Muzzle") as Node3D).global_transform
		var cano := (-mz.basis.z).normalized()
		var obj: Vector3 = jugador.arsenal.punto_mira() - mz.origin
		if obj.length() > 3.0 and cano.angle_to(obj) < deg_to_rad(40):
			var err := Quaternion(cano, obj.normalized())
			var mano := (P.RightHand as Node3D).global_transform.basis.orthonormalized()
			var local := Quaternion(mano.inverse() * Basis(err) * mano)
			moto_corr_q = (moto_corr_q * Quaternion.IDENTITY.slerp(local, 1.0 - exp(-12.0 * dt))).normalized()
			if moto_corr_q.get_angle() > deg_to_rad(25):
				moto_corr_q = Quaternion.IDENTITY.slerp(moto_corr_q, deg_to_rad(25) / moto_corr_q.get_angle())
			return
	moto_corr_q = moto_corr_q.slerp(Quaternion.IDENTITY, 1.0 - exp(-6.0 * dt))


## muelle críticamente amortiguado con velocidad y aceleración máximas: [valor, velocidad]
static func _muelle_lim(x: float, v: float, obj: float, w: float, vmax: float, amax: float, dt: float) -> Array:
	var v2 := (v + (obj - x) * w * w * dt) / (1.0 + 2.0 * w * dt + w * w * dt * dt)
	v2 = clampf(v2, v - amax * dt, v + amax * dt)
	v2 = clampf(v2, -vmax, vmax)
	return [x + v2 * dt, v2]


## el modelo del arma va en la mano que la sostiene
func _arma_a_mano(mdl: Node3D, tool: String, h: String) -> void:
	if mdl == null:
		return
	var mano: Node3D = P.RightHand if h == "R" else P.LeftHand
	if mano == null or mdl.get_parent() == mano:
		return
	if mdl.get_parent() != null:
		mdl.get_parent().remove_child(mdl)
	mano.add_child(mdl)
	mdl.transform = Armas.handle_en_mano(tool)


## ---------------------------------------------------------------- IK analítica
static func basis(x: Vector3, bone_dir: Vector3) -> Transform3D:
	var y := -bone_dir.normalized()
	x = (x - y * x.dot(y)).normalized()
	return Rbx.from_matrix(Vector3.ZERO, x, y, x.cross(y))


static func fk(parent_cf: Transform3D, m: RigPersonaje.Motor) -> Transform3D:
	return parent_cf * m.c0 * m.transform * m.c1inv


static func make_limb(top: RigPersonaje.Motor, mid: RigPersonaje.Motor, fin: RigPersonaje.Motor, hinge: float) -> Limb:
	var L := Limb.new()
	L.top = top
	L.mid = mid
	L.fin = fin
	L.p1 = top.c1.origin
	L.p2 = mid.c0.origin
	L.q1 = mid.c1.origin
	L.q2 = fin.c0.origin
	L.a = (L.p2 - L.p1).length()
	L.b = (L.q2 - L.q1).length()
	L.bU = basis(Rbx.XAXIS, L.p2 - L.p1)
	L.bL = basis(Rbx.XAXIS, L.q2 - L.q1)
	L.hinge = hinge
	return L


## lleva la articulación final (muñeca/tobillo) a target; w = mezcla con lo que ya había
static func solve(L: Limb, parent_cf: Transform3D, target: Vector3, pole: Vector3, w: float = 1.0) -> Array:
	var s := (parent_cf * L.top.c0).origin
	var d := target - s
	var dist := clampf(d.length(), 0.05, L.a + L.b - 0.002)
	var dir := d.normalized() if d.length() > 1e-4 else -Rbx.upv(parent_cf)
	var cos_a := clampf((L.a * L.a + dist * dist - L.b * L.b) / (2 * L.a * dist), -1, 1)
	var sin_a := sqrt(1 - cos_a * cos_a)
	var pv := pole - s
	var perp := pv - dir * pv.dot(dir)
	if perp.length() < 1e-3:
		var lk := Rbx.look(parent_cf)
		perp = lk - dir * lk.dot(dir)
	perp = perp.normalized()
	var E := s + dir * (cos_a * L.a) + perp * (sin_a * L.a)
	var u := (E - s).normalized()
	var pc := s + dir * dist
	var l := (pc - E).normalized()
	var wv := l - u * l.dot(u)
	if wv.length() < 1e-3:
		wv = perp
	wv = wv.normalized()
	var X := u.cross(wv).normalized() if L.hinge > 0 else wv.cross(u).normalized()
	var RU := basis(X, u) * L.bU.affine_inverse()
	var UA := Rbx.add(RU, s - RU * L.p1)
	var E2 := UA * L.p2
	var l2 := (pc - E2).normalized() if (pc - E2).length() > 1e-4 else l
	var RL := basis(X, l2) * L.bL.affine_inverse()
	var LA := Rbx.add(RL, E2 - RL * L.q1)
	var t_top := (parent_cf * L.top.c0).affine_inverse() * UA * L.top.c1
	var t_mid := (UA * L.mid.c0).affine_inverse() * LA * L.mid.c1
	if w >= 0.999:
		L.top.transform = t_top
		L.mid.transform = t_mid
	else:
		L.top.transform = L.top.transform.interpolate_with(t_top, w)
		L.mid.transform = L.mid.transform.interpolate_with(t_mid, w)
	var upper := fk(parent_cf, L.top)
	return [upper, fk(upper, L.mid)]


static func set_end(L: Limb, lower_cf: Transform3D, desired: Transform3D, w: float = 1.0) -> void:
	var t := (lower_cf * L.fin.c0).affine_inverse() * desired * L.fin.c1
	t = Rbx.rot(t)
	L.fin.transform = L.fin.transform.interpolate_with(t, w) if w < 0.999 else t


## sin vallar, colgarse ni tumbarse (para tomar un escalón hacia abajo como suelo)
func va_sin_pie_aire() -> bool:
	var L: Dictionary = jugador.L
	return L.vault == null and L.get("hang") == null and float(L.proneP) < 0.01 and not bool(L.knocked)


## ---------------------------------------------------------------- suelo
func ground(pos: Vector3) -> Array:
	var hit := jugador.raycast(pos + Vector3(0, 2.5, 0), Vector3(0, -14, 0))
	if not hit.is_empty():
		return [hit.position.y, hit.normal]
	return [pos.y - 3.1, Vector3.UP]


## ---------------------------------------------------------------- preparación
func _ready() -> void:
	if jugador == null:
		jugador = get_parent() as Jugador
	await get_tree().process_frame
	rig = jugador.rig
	M = rig.M
	P = rig.P
	arm = {"L": make_limb(M.LeftShoulder, M.LeftElbow, M.LeftWrist, 1), "R": make_limb(M.RightShoulder, M.RightElbow, M.RightWrist, 1)}
	leg = {"L": make_limb(M.LeftHip, M.LeftKnee, M.LeftAnkle, -1), "R": make_limb(M.RightHip, M.RightKnee, M.RightAnkle, -1)}
	leg_len = leg.L.a + leg.L.b
	hip_x = absf(M.RightHip.c0.origin.x)
	# distancia mínima de cada pie al eje del cuerpo: medio pie + holgura (nunca se solapan)
	min_foot_x = maxf(hip_x * 0.9, P.RightFoot.get_meta("size").x * 0.5 + 0.08)
	foot_half = P.RightFoot.get_meta("size").y / 2
	ankle_in_foot = {"L": M.LeftAnkle.c1.origin, "R": M.RightAnkle.c1.origin}
	wrist_in_hand = {"L": M.LeftWrist.c1.origin, "R": M.RightWrist.c1.origin}
	S = {
		"leanP": Muelle.new(1.4, 0.8), "leanR": Muelle.new(1.4, 0.8),
		"crouch": Muelle.new(2.5, 0.8), "land": Muelle.new(3.0, 0.45),
		"hitYaw": Muelle.new(2.4, 0.3), "hitPitch": Muelle.new(2.4, 0.3), "hitHead": Muelle.new(3.2, 0.3),
		"flail": Muelle.new(1.5, 0.4),
		"kick": Muelle.new(10, 0.55), "kickRot": Muelle.new(9, 0.5),
	}
	var root := jugador.root_cf()
	prev_yaw = Rbx.yaw_of(root)
	breath_t = randf() * 5
	for s in ["L", "R"]:
		var sx := -1.0 if s == "L" else 1.0
		var p := (root * Rbx.cf(sx * hip_x, 0, -0.18)).origin
		var gy: float = ground(p)[0]
		feet[s] = {"pos": Vector3(p.x, gy, p.z), "side": sx, "swing": null, "normal": Vector3.UP}
	jugador.estado_cambiado.connect(_on_estado)


func _on_estado(nuevo: String) -> void:
	if nuevo == "Landed":
		var f := clampf((fall_max - 9) / 20, 0, 1.4) # calibrado para gravedad casi real
		if f > 0:
			(S.land as Muelle).impulse(-f * 10)
		fall_max = 0
		replant = true


## ---------------------------------------------------------------- pies (locomoción con anclaje)
func _keep_side(frame: Transform3D, f: Dictionary, p: Vector3) -> Vector3:
	var lp := Rbx.to_obj(frame, p)
	if lp.x * f.side < min_foot_x:
		var w := frame * Vector3(f.side * min_foot_x, lp.y, lp.z)
		return Vector3(w.x, p.y, w.z)
	return p


func _ideal(frame: Transform3D, f: Dictionary, vel_h: Vector3, lead: float, extra_t: float = 0.0) -> Array:
	var base := (frame * Rbx.cf(f.side * hip_x, 0, -0.18)).origin
	base += vel_h * (extra_t + lead)
	base = _keep_side(frame, f, base)
	# pared delante del pie: el pie se queda antes de la pared (no se mete dentro)
	var hip_pt := (frame * Rbx.cf(f.side * hip_x, 0, 0)).origin
	var o := Vector3(hip_pt.x, frame.origin.y - 2.2, hip_pt.z)
	var to_b := Vector3(base.x, o.y, base.z) - o
	if to_b.length() > 0.05:
		var dir := to_b.normalized()
		var hw := jugador.raycast(o, to_b + dir * 0.6)
		if not hw.is_empty() and absf(hw.normal.y) < 0.5:
			var lim := maxf(0.0, hw.distance - 0.6)
			base = o + dir * minf(to_b.length(), lim)
	base.y = frame.origin.y
	var g := ground(base)
	# el pie solo puede apoyarse en un suelo al que se llega andando (como mucho un escalón más
	# arriba o más abajo que el suelo bajo el cuerpo). Si no (borde de algo alto, una estructura
	# delante), se queda más cerca de la cadera, donde sí hay suelo válido.
	var body_gy: float = frame.origin.y - jugador.center_cur
	if not _suelo_valido(g[0], body_gy):
		for k in [0.75, 0.5, 0.25, 0.0]:
			var b2 := hip_pt.lerp(Vector3(base.x, hip_pt.y, base.z), k)
			b2.y = frame.origin.y
			var g2 := ground(b2)
			if _suelo_valido(g2[0], body_gy):
				base = b2
				g = g2
				break
	# escalones: si la punta quedaría sobre el escalón de arriba y el talón en el de abajo, el pie
	# se adelanta para apoyarse entero en el escalón (no medio pie metido en el borde). Solo con
	# escalones de verdad (no con el borde de una estructura alta).
	var fwd := Rbx.look(frame)
	var toe_y: float = ground(base + fwd * 0.45)[0]
	var heel_y: float = ground(base - fwd * 0.45)[0]
	if toe_y - heel_y > 0.15 and _suelo_valido(toe_y, body_gy):
		var b3 := base + fwd * 0.5
		var g3 := ground(b3)
		if _suelo_valido(g3[0], body_gy):
			base = b3
			g = g3
	return [Vector3(base.x, g[0], base.z), g[1]]


func _suelo_valido(y: float, body_gy: float) -> bool:
	return y <= body_gy + 1.3 and y >= body_gy - 1.3


## La carrera frontal solo se mezcla cuando el desplazamiento acompaña al cuerpo.
func _factor_carrera_direccion(vel: Vector3, base: Transform3D) -> float:
	var v := Rbx.flat(vel)
	if v.length() < 0.1:
		return 0.0
	return smoothstep(0.35, 0.85, v.normalized().dot(Rbx.flat(Rbx.look(base)).normalized()))


func update_feet(root_cf: Transform3D, vel: Vector3, speed: float, dt: float, grounded: bool) -> void:
	var body_yaw := Rbx.yaw_of(root_cf)
	var yaw_cf := Rbx.ang(0, body_yaw, 0)
	var vel_h := Vector3(vel.x, 0, vel.z)
	var running := speed > 10 and _factor_carrera_direccion(vel_h, root_cf) > 0.5
	# duración del vuelo de cada pie (andando ~0.33 s; el apoyo dura más que el vuelo, como al
	# andar de verdad). Corriendo, pasos rápidos con fase aérea
	var step_dur := clampf(0.36 - speed * 0.005, 0.25, 0.36)
	# corriendo el pie toca el suelo poco tiempo (no se queda atrás arrastrando la pierna)
	var run01 := clampf((speed - 7.0) / 6.0, 0, 1) * _factor_carrera_direccion(vel_h, root_cf)
	mez_pie_run = run01
	var k_thr := lerpf(0.83, 0.5, run01)
	# el pie se apoya delante de la cadera (andando más; corriendo justo bajo el cuerpo)
	var lead := step_dur * (0.25 if running else 0.35)
	var threshold := 0.22 + speed * step_dur * k_thr
	var arc := 0.2 + speed * 0.02
	# con fatiga: pasos más cortos, algo más lentos y arrastrando los pies (poca altura)
	var fw_k := fat * (1.0 - run01)
	step_dur *= 1.0 + 0.15 * fw_k
	arc *= 1.0 - 0.55 * fw_k
	var overlap := 0.55 if running else 0.92 # al correr, fase aérea (los dos pies en el aire)
	if stumble_until > ahora():
		step_dur *= 0.7
		threshold *= 0.6
	var frame := Rbx.cfp(root_cf.origin) * yaw_cf
	# de lado: pasos más cortos y frecuentes (paso lateral), si no el cuerpo adelanta a los pies
	var lvel := Rbx.vec_to_obj(frame, vel_h)
	var lat_f := absf(lvel.x) / speed if speed > 0.1 else 0.0
	threshold = (0.22 + speed * step_dur * k_thr * (1 - 0.65 * lat_f)) * (1.0 - 0.2 * fw_k)
	if lat_f > 0.5:
		step_dur *= 0.85
	# andando de lado (con el arma, el cuerpo no gira hacia donde va): pasos laterales cortos con
	# las rodillas algo dobladas y el pie levantado (si no, las piernas se abren como un compás)
	# (solo si se pide ir de lado con A/D: resbalar a lo largo de una pared no cuenta)
	var md: Vector3 = jugador.move_direction
	var lat_in := absf(Rbx.vec_to_obj(frame, md).x) / md.length() if md.length() > 0.1 else 0.0
	lat_k = Rbx.damp(lat_k, minf(lat_f, lat_in) * (1.0 - run01) if speed > 0.8 else 0.0, 6, dt)
	threshold *= 1.0 - 0.5 * lat_k
	arc += 0.18 * lat_k

	# red de seguridad: un pie apoyado demasiado lejos del cuerpo (teletransporte) se recoloca
	for s in feet:
		if feet[s].swing == null and Vector3(feet[s].pos - root_cf.origin).length() > 9:
			replant = true
	if replant:
		replant = false
		anim_w = 0.0
		anim_aire = false
		for s in feet:
			feet[s].anim = false
			var f: Dictionary = feet[s]
			f.pos = _ideal(frame, f, vel_h, lead, -lead)[0]
			# (2026-10-30) un pie no se queda apoyado sobre una cuesta muy empinada (se metía dentro):
			# se recoge hacia el cuerpo hasta pisar llano
			for _i in 3:
				var gq := ground(f.pos)
				if (gq[1] as Vector3).y > 0.8:
					break
				var hacia: Vector3 = Rbx.flat(frame.origin - (f.pos as Vector3))
				var p2: Vector3 = (f.pos as Vector3) + hacia.limit_length(0.5)
				var g2 := ground(p2)
				f.pos = Vector3(p2.x, g2[0], p2.z)
			f.swing = null
			f.yaw = body_yaw
			f.cur = null
			f.u = null
			f.swingYaw = null
			f.roll = 0.0
			# tras trepar: un pie (el izquierdo) queda adelantado y el otro atrás, como al terminar
			# de subir; así el primer paso sale del pie de atrás y la carrera arranca alternando
			if replant_paso:
				var off := Rbx.look(frame) * (0.7 if s == "L" else -0.5)
				var g := ground(f.pos + off)
				f.pos = Vector3(f.pos.x + off.x, g[0], f.pos.z + off.z)
		if replant_paso:
			replant_paso = false
			step_start = {"L": ahora(), "R": ahora() - 0.3}

	var L: Dictionary = feet.L
	var R: Dictionary = feet.R
	# avanzar pasos en curso
	for f in [L, R]:
		var sw = f.swing
		if sw != null and not sw.has("anim"):
			sw.t += dt
			var u := clampf(sw.t / sw.dur, 0, 1)
			var idl := _ideal(frame, f, vel_h, float(sw.get("lead", lead)), sw.dur - sw.t)
			var to: Vector3 = idl[0]
			# trayectoria del paso: el pie rodea por su lado, sin pasar por delante de la otra pierna.
			# Subiendo (escalón, cuesta) el pie gana la altura al principio para librar el borde;
			# bajando, va bajando poco a poco durante todo el paso (no cae de golpe al final).
			# Encima, un arco pequeño.
			var from_v: Vector3 = sw.from
			var rise := to.y - from_v.y
			var hu := Rbx.smooth((u - 0.05) / 0.5) if rise > 0 else Rbx.smooth(u / lerpf(1.0, 0.55, clampf(-rise / 1.5, 0.0, 1.0)))
			# corriendo el pie sube algo más (la rodilla se dobla sola porque la pierna en el aire
			# nunca va estirada: ver el límite de alcance en la IK de piernas)
			# forma del paso (Blender, Movimientos): cuánto avanza, cuánto sube y, corriendo, el talón hacia el glúteo
			# (el pie se queda atrás al despegar) y la pierna que alcanza por delante y "araña" antes de apoyar
			var r_pie := 0.0 if bool(sw.get("idle", false)) else run01
			var hz := _curva_pie("pie_avance", u, 0.0)
			if r_pie > 0.001:
				hz = lerpf(hz, Movimientos.pie("correr", "pie_avance", u), r_pie)
			var alto_w := arc * _curva_pie("pie_alto", u, 0.0)
			var kick := 0.0
			var atras := 0.0
			if r_pie > 0.001:
				kick = (Movimientos.pie("correr", "pie_alto", u) - alto_w * 0.65) * r_pie
				atras = Movimientos.pie("correr", "pie_atras", u) * r_pie
			# bajando (escaleras, cuesta abajo) el talón no se dispara hacia arriba por detrás
			if rise < 0.0:
				kick *= clampf(1.0 + rise * 0.6, 0.15, 1.0)
				atras *= clampf(1.0 + rise * 0.6, 0.15, 1.0)
			var p := _keep_side(frame, f, from_v.lerp(to, hz) - Rbx.look(frame) * atras)
			f.cur = Vector3(p.x, from_v.y + rise * hu + alto_w + kick, p.z)
			# el pie gira sobre la punta al despegar y sobre el talón al apoyar (curva de Blender), empalmado con el
			# giro que traía del apoyo (sin saltos)
			var r0: float = sw.get("roll0", 0.0)
			f.roll = lerpf(r0, _curva_pie("pie_inclina", u, r_pie), Rbx.smooth(clampf(u / 0.3, 0.0, 1.0)))
			f.u = u
			# el pie gira en el aire hacia la nueva orientación del cuerpo
			var fy: float = sw.fromYaw if sw.fromYaw != null else body_yaw
			f.swingYaw = fy + Rbx.wrap_a(body_yaw - fy) * Rbx.smooth(u)
			if u >= 1:
				# el pie toca el suelo: pisada (ruido que oyen los zombis)
				if grounded:
					Ruido.emitir(jugador, to, Ruido.radio_paso(step_k, bool(sw.get("idle", false))), Ruido.PASO, jugador)
					# pisada que se oye (más fuerte corriendo, casi nada agachado o recolocando los pies)
					var v_paso := clampf(step_k, 0.12, 1.0) * (0.35 if bool(sw.get("idle", false)) else 1.0)
					Efectos.sonido(jugador, "Step", to, 0.25 + 0.75 * v_paso, 0.92 + step_k * 0.12)
				f.pos = to
				f.normal = idl[1]
				f.swing = null
				f.cur = null
				f.u = null
				f.yaw = body_yaw
				f.swingYaw = null
	if not grounded:
		# (en el aire el reloj se para; al aterrizar vuelve a arrancar con el pie que va delante)
		reloj_activo = false
		ultimo_pie = ""
		if anim_w > 0.0:
			anim_w = 0.0
			anim_aire = true
			for k in ["L", "R"]:
				var fa: Dictionary = feet[k]
				fa.anim = false
				if fa.get("cur") != null:
					fa.pos = fa.cur
				fa.cur = null
				fa.swing = null
				fa.u = null
		return
	# PIERNAS ANIMADAS (2026-11-03, a pedido de KangooG: "la animación normal, olvidando los pasos procedurales al
	# 95 %"): en marcha cada pie sigue la animación hecha en Blender (Movimientos.PIERNAS) respecto a la cadera; el juego
	# solo hace avanzar la fase con la distancia recorrida (el pie de apoyo no resbala) y pone el pie a la altura del
	# suelo que pisa. Parado, los pies se quedan anclados y dan pasitos de ajuste como siempre.
	if speed >= (0.4 if anim_w > 0.0 else 0.8):
		anim_parando = 0.0
		_marcha_animada(root_cf, frame, vel_h, speed, dt, run01, fw_k, lat_f, body_yaw)
		return
	if anim_w > 0.0:
		# parándose: si un pie va en el aire, termina su paso con la animación (sin cortarlo) y luego se queda quieto
		var en_aire := bool(feet.L.get("ap_paso", false)) or bool(feet.R.get("ap_paso", false))
		anim_parando += dt
		if en_aire and anim_parando < 0.5 and anim_w >= 1.0:
			_marcha_animada(root_cf, frame, vel_h, speed, dt, run01, fw_k, lat_f, body_yaw)
			return
		anim_parando = 0.0
		_parar_animada(body_yaw)
	reloj_activo = false
	ultimo_pie = ""
	# decidir el siguiente paso (parado: pasos de ajuste)
	var iL: Vector3 = _ideal(frame, L, vel_h, lead, 0)[0]
	var iR: Vector3 = _ideal(frame, R, vel_h, lead, 0)[0]
	var dL := (Vector3(L.pos.x, 0, L.pos.z) - Vector3(iL.x, 0, iL.z)).length()
	var dR := (Vector3(R.pos.x, 0, R.pos.z) - Vector3(iR.x, 0, iR.z)).length()
	# un pie que ya está dando el paso no cuenta como "retrasado" (si no, bloquea al otro y al
	# correr nunca hay fase aérea: un pie arrastraba al otro)
	if L.swing != null:
		dL = 0.0
	if R.swing != null:
		dR = 0.0
	# al girar, el pie apoyado pivota un poco sobre la planta (como una persona)
	for f in [L, R]:
		if f.swing == null and f.get("yaw") != null:
			var d := Rbx.wrap_a(body_yaw - f.yaw)
			if absf(d) > 0.25:
				f.yaw += clampf(d - signf(d) * 0.25, -6 * dt, 6 * dt)
	# pie apoyado que quedó cruzado (el cuerpo giró o se movió de lado) o muy torcido: dar un paso ya
	for f in [L, R]:
		var lp := Rbx.to_obj(frame, f.pos)
		var fyaw: float = f.yaw if f.get("yaw") != null else body_yaw
		var twisted := absf(Rbx.wrap_a(body_yaw - fyaw)) > 0.8
		if f.swing == null and (lp.x * f.side < min_foot_x * 0.7 or twisted):
			if f == L:
				dL = 99
			else:
				dR = 99
	# un pie que se quedó muy atrás (el otro no paraba de dar pasos) tiene prioridad
	if L.swing == null and dL > threshold * 1.6:
		dL = 99
	if R.swing == null and dR > threshold * 1.6:
		dR = 99
	# un pie apoyado al que la pierna ya no llega (se quedaría estirada hacia atrás): paso ya,
	# aunque el otro pie aún no haya terminado el suyo
	var over := {"L": L.swing == null and L.get("overreach", false), "R": R.swing == null and R.get("overreach", false)}
	if over.L:
		dL = 99
	if over.R:
		dR = 99
	# un pie apoyado que se quedó en otro escalón (más alto o más bajo que el suelo bajo el cuerpo)
	# mientras avanzas: cuenta como retrasado (si no, el otro pie repite paso y este se queda atrás)
	var desnivel := {"L": false, "R": false}
	if speed > 2.0:
		var body_gy := root_cf.origin.y - jugador.center_cur
		if L.swing == null and absf(float(L.pos.y) - body_gy) > 1.0:
			dL = maxf(dL, threshold * 1.2)
			if absf(float(L.pos.y) - body_gy) > 1.6:
				over.L = true # muy desnivelado: paso ya (corriendo, aunque el otro pie siga en el aire)
				desnivel.L = true
				dL = 99
		if R.swing == null and absf(float(R.pos.y) - body_gy) > 1.0:
			dR = maxf(dR, threshold * 1.2)
			if absf(float(R.pos.y) - body_gy) > 1.6:
				over.R = true
				desnivel.R = true
				dR = 99
	var forced := {"L": dL >= 99, "R": dR >= 99}
	var first: Dictionary = L
	var second: Dictionary = R
	var df := dL
	var ds := dR
	var first_k := "L"
	var second_k := "R"
	if dR > dL:
		first = R
		second = L
		df = dR
		ds = dL
		first_k = "R"
		second_k = "L"
	# en marcha, siempre alterno: si el elegido acaba de dar el paso y el otro también va atrasado,
	# le toca al otro
	if speed > 2.0 and second.swing == null and not forced[first_k] \
			and float(step_start[first_k]) > float(step_start[second_k]) and ds > threshold * 0.5:
		var tmp: Dictionary = first
		first = second
		second = tmp
		var tmpd := df
		df = ds
		ds = tmpd
		var tk := first_k
		first_k = second_k
		second_k = tk
	# en escaleras y cuestas los pasos son más cortos (un escalón por paso, no tres)
	var thr := threshold * clampf(1.0 - 0.4 * absf(jugador.pendiente), 0.55, 1.0)
	if speed < 0.6:
		# quieto: paso de ajuste si los pies quedaron mal colocados un rato
		idle_t += dt
		thr = 0.25 if idle_t > 0.35 else 99.0
	else:
		idle_t = 0
	# SIEMPRE un pie después del otro: el segundo pie espera a que el primero esté casi apoyado
	var need_f: float = (lerpf(0.45, 0.1, run01) if desnivel[first_k] else 0.45) if over[first_k] else (0.85 if forced[first_k] else (0.85 if lat_f > 0.5 else overlap))
	var need_s: float = (lerpf(0.45, 0.1, run01) if desnivel[second_k] else 0.45) if over[second_k] else (0.85 if forced[second_k] else (0.85 if lat_f > 0.5 else overlap))
	var can_first: bool = second.swing == null or (second.get("u") if second.get("u") != null else 0.0) >= need_f
	var can_second: bool = first.swing == null or (first.get("u") if first.get("u") != null else 0.0) >= need_s
	# corriendo: ritmo simétrico (izquierda-derecha a intervalos iguales). Sin esto la carrera
	# "galopa": un paso sale muy pronto tras el otro y el siguiente tarda el doble
	var thr_f := thr
	var thr_s := thr
	if run01 > 0.3 and run_cycle > 0.0:
		var now_s := ahora()
		var half := run_cycle * 0.5
		# al pie al que le toca y ya pasó medio ciclo, se le adelanta el paso
		if now_s - float(step_start[second_k]) >= half and float(step_start[second_k]) > float(step_start[first_k]):
			thr_f = thr * 0.55
		if now_s - float(step_start[first_k]) >= half and float(step_start[first_k]) > float(step_start[second_k]):
			thr_s = thr * 0.55 / 1.3
		if not forced[first_k] and now_s - float(step_start[second_k]) < half and float(step_start[second_k]) > float(step_start[first_k]):
			can_first = false
		if not forced[second_k] and now_s - float(step_start[first_k]) < half and float(step_start[first_k]) > float(step_start[second_k]):
			can_second = false
	if first.swing == null and df > thr_f and can_first:
		# los pasos de corrección son algo más rápidos
		var dur := 0.3 if speed < 0.6 else step_dur
		if forced[first_k]:
			dur = minf(dur, 0.24)
		_registrar_paso(first_k, run01)
		first.swing = {"from": first.pos, "t": 0.0, "dur": dur, "fromYaw": first.get("yaw") if first.get("yaw") != null else body_yaw, "idle": speed < 0.6, "roll0": first.get("roll", 0.0)}
	elif second.swing == null and ds > thr_s * 1.3 and can_second and first.swing == null:
		# en marcha, si este pie fue el último en dar el paso, le toca al otro (alternar siempre)
		var mover: Dictionary = second
		var mk := second_k
		if speed > 2.0 and float(step_start[second_k]) > float(step_start[first_k]) and can_first:
			mover = first
			mk = first_k
		_registrar_paso(mk, run01)
		mover.swing = {"from": mover.pos, "t": 0.0, "dur": 0.3 if speed < 0.6 else step_dur, "fromYaw": mover.get("yaw") if mover.get("yaw") != null else body_yaw, "idle": speed < 0.6, "roll0": mover.get("roll", 0.0)}


## parámetro de las piernas animadas mezclado andar / agachado / correr (como _curva_pie)
func _par_pierna(nombre: String, run01: float) -> float:
	var v: float = Movimientos.PIERNAS.andar[nombre]
	if crouch_b > 0.001:
		v = lerpf(v, Movimientos.PIERNAS.agachado[nombre], crouch_b)
	if run01 > 0.001:
		v = lerpf(v, Movimientos.PIERNAS.correr[nombre], run01)
	return v


func _curva_pierna(nombre: String, x: float, run01: float) -> float:
	var v := Movimientos.pierna("andar", nombre, x)
	if crouch_b > 0.001:
		v = lerpf(v, Movimientos.pierna("agachado", nombre, x), crouch_b)
	if run01 > 0.001:
		v = lerpf(v, Movimientos.pierna("correr", nombre, x), run01)
	return v


## Pie k de la animación (Blender, Movimientos.PIERNAS / diseno_mov.pierna) en la fase phi: [avance respecto a la
## cadera en studs (+ = hacia donde va), altura, inclinación (rad), en el aire, u (aire) o s (apoyo)]. En el apoyo el
## pie va hacia atrás en línea recta a la velocidad del cuerpo (en el mundo, quieto); en el aire vuelve con la forma de
## Blender más la velocidad con la que despegó (sin tirones).
func _pierna_anim(en_paso: bool, x: float, zan: float, fr: float, run01: float, speed: float) -> Array:
	var delante := _par_pierna("delante", run01)
	var dd := zan * (1.0 - fr)
	if not en_paso:
		var sa := x
		return [dd * (delante - sa), 0.0, _curva_pierna("inclina_apoyo", sa, run01), false, sa]
	var u := x
	var m0 := -fr / (1.0 - fr)
	var a := _curva_pierna("avance", u, run01) + m0 * (u * u * u - 2.0 * u * u + u) + _par_pierna("retrae", run01) * m0 * (u * u * u - u * u)
	var k_alto := clampf(speed / _par_pierna("v_ref", run01), 0.5, 1.15)
	return [dd * (delante - 1.0 + a), _curva_pierna("alto", u, run01) * k_alto, _curva_pierna("inclina_aire", u, run01), true, u]


## posición del tobillo respecto al cuerpo (marco del rumbo) para un avance z de la animación
func _tobillo_anim(k: String, z: float, eje: Vector3, desp_x: float, estrecha: float) -> Vector3:
	var side: float = feet[k].side
	# (frenando de correr a andar, el paso de andar más largo hacía que el pie apoyara demasiado lejos y la cadera se
	# hundía): por delante, el pie no va más allá de lo que alcanza la pierna con la cadera casi a su altura
	if z > 1.1:
		z = 1.1 + 0.3 * tanh((z - 1.1) / 0.3)
	var x := side * (hip_x - estrecha) + eje.x * z + side * desp_x
	if x * side < ANIM_MIN_X:
		x = side * ANIM_MIN_X
	return Vector3(x, 0.0, eje.z * z)


## Cada pie lleva su propio avance (apoyo s / paso u) y no la fase global directamente: así, al pasar de andar a correr
## (cambia la parte del ciclo que va en el aire) ningún pie salta de golpe de apoyado a en el aire; un pequeño ajuste
## lo mantiene a la par de la fase global (siempre alternando).
func _avanza_pie(f: Dictionary, dpsi: float, fr: float) -> void:
	var paso: bool = f.ap_paso
	var x: float = f.ap_x
	var resto := dpsi
	for _i in 4:
		var span := fr if paso else (1.0 - fr)
		var nx := x + resto / span
		if nx > 1.0:
			resto = (nx - 1.0) * span
			paso = not paso
			x = 0.0
		elif nx < 0.0:
			resto = nx * span
			paso = not paso
			x = 1.0
		else:
			x = nx
			break
	f.ap_paso = paso
	f.ap_x = clampf(x, 0.0, 1.0)


func _pie_en_fase(f: Dictionary, psi: float, fr: float) -> void:
	f.ap_paso = psi >= 1.0 - fr
	f.ap_x = (psi - (1.0 - fr)) / fr if f.ap_paso else psi / (1.0 - fr)


## ESCALERAS: mira el suelo a lo largo de la marcha (cada 0,125 studs) y busca bordes de escalón seguidos, del mismo
## sentido y con huellas parecidas. esc_fondo = fondo del escalón (0 si no es una escalera)
func _mirar_escalera(origen: Vector3, dir_w: Vector3, body_gy: float) -> void:
	var d0 := -1.0
	var paso := 0.125
	var n := 38
	var hs: Array = []
	for i in n:
		var pt := origen + dir_w * (d0 + i * paso)
		var hit := jugador.raycast(Vector3(pt.x, body_gy + 2.6, pt.z), Vector3(0, -5.5, 0))
		hs.append((hit.position as Vector3).y if not hit.is_empty() else NAN)
	var bordes: Array = []
	var saltos: Array = []
	for i in n - 1:
		var a: float = hs[i]
		var b: float = hs[i + 1]
		if is_nan(a) or is_nan(b):
			continue
		var dh := b - a
		if absf(dh) > 0.15 and absf(dh) < 1.3:
			bordes.append(d0 + (i + 0.5) * paso)
			saltos.append(dh)
	var fondo := 0.0
	if bordes.size() >= 2:
		var ok := true
		var esp: Array = []
		for i in bordes.size() - 1:
			if signf(saltos[i]) != signf(saltos[i + 1]):
				ok = false
			esp.append(float(bordes[i + 1]) - float(bordes[i]))
		if ok:
			esp.sort()
			var m: float = esp[esp.size() / 2]
			if m >= 0.5 and m <= 2.2 and float(esp[0]) > m * 0.7 and float(esp[esp.size() - 1]) < m * 1.35:
				fondo = m
	var now := ahora()
	if fondo > 0.0:
		esc_fondo = fondo if esc_fondo <= 0.0 else lerpf(esc_fondo, fondo, 0.3)
		esc_visto = now
	elif not (now - esc_visto < 0.5 or (not bordes.is_empty() and now - esc_visto < 1.5)):
		esc_fondo = 0.0
	esc_dir = dir_w
	esc_bordes.clear()
	for d in bordes:
		esc_bordes.append(origen + dir_w * float(d))


## centro de la huella más cercana a un punto (a lo largo de la marcha), o null
func _centro_huella(punto: Vector3) -> Variant:
	if esc_fondo <= 0.0 or esc_bordes.is_empty():
		return null
	var mejor = null
	var md := INF
	for b in esc_bordes:
		for sgn in [-0.5, 0.5]:
			var c: Vector3 = (b as Vector3) + esc_dir * esc_fondo * sgn
			var d := absf((c - punto).dot(esc_dir))
			if d < md:
				md = d
				mejor = c
	return mejor


func _suelo_pie(p: Vector3, body_gy: float) -> Array:
	var g := ground(p)
	if not _suelo_valido(g[0], body_gy):
		return [body_gy, Vector3.UP]
	return g


func _marcha_animada(root_cf: Transform3D, frame: Transform3D, vel_h: Vector3, speed: float, dt: float, run01: float, fw_k: float, lat_f: float, body_yaw: float) -> void:
	idle_t = 0
	# ritmo (Blender, Movimientos.ZANCADA / FRACCION_AIRE): de lado, con fatiga, en escaleras o tropezando, pasos cortos
	var zan := lerpf(Movimientos.zancada("andar", speed), Movimientos.zancada("correr", speed), run01)
	var fr: float = lerpf(Movimientos.FRACCION_AIRE.andar, Movimientos.FRACCION_AIRE.correr, run01)
	if crouch_b > 0.001:
		zan = lerpf(zan, Movimientos.zancada("agachado", speed), crouch_b)
		fr = lerpf(fr, Movimientos.FRACCION_AIRE.agachado, crouch_b)
	var vel_dir := vel_h.normalized() if vel_h.length() > 0.05 else Rbx.look(frame)
	var body_gy0: float = frame.origin.y - jugador.center_cur
	_esc_n += 1
	if _esc_n % 3 == 0:
		_mirar_escalera(Vector3(frame.origin.x, 0.0, frame.origin.z), vel_dir, body_gy0)
	if esc_fondo > 0.0:
		# escalera: UN escalón por paso (corriendo, de dos en dos); la zancada es exactamente eso
		var nn := 2 if speed > esc_fondo * 5.0 else 1
		zan = 2.0 * nn * esc_fondo
	else:
		zan *= clampf(1.0 - 0.4 * absf(jugador.pendiente), 0.55, 1.0)
		zan *= (1.0 - 0.2 * fw_k)
		if stumble_until > ahora():
			zan *= 0.7
	zan *= 1.0 - 0.5 * lat_f
	zan = maxf(zan, 0.8)
	# la zancada no cambia de golpe (si no, el pie que va en el aire cambia de sitio de repente)
	anim_zan = zan if anim_w <= 0.0 or anim_zan <= 0.0 else Rbx.damp(anim_zan, zan, 5.0, dt)
	zan = anim_zan
	# parándose: el pie que va en el aire termina su paso a un ritmo normal
	var v_fase := maxf(speed, 3.0) if anim_parando > 0.0 else speed
	# dirección de la marcha respecto al cuerpo; hacia atrás, la animación se reproduce al revés
	var lv := Rbx.vec_to_obj(frame, vel_h)
	var dir := Vector3(lv.x, 0.0, lv.z).normalized() if speed > 0.05 else Vector3.FORWARD
	var sentido := anim_sentido
	if -dir.z < -0.35:
		sentido = -1.0
	elif -dir.z > 0.35:
		sentido = 1.0
	var arranca := anim_w <= 0.0
	if arranca:
		anim_sentido = sentido
		anim_cruce = 0.0
	elif sentido != anim_sentido:
		anim_sentido = sentido
		anim_cruce = 1.0
		anim_cruce_desde = anim_local.duplicate()
	var eje := dir * anim_sentido
	if arranca:
		var contacto_de := func(k: String) -> float: return 0.25 if k == "L" else 0.75
		if anim_aire:
			# aterriza: apoya el pie que venía delante en el salto
			gait01 = contacto_de.call(jump_lead if jump_lead != "" else "L")
			anim_w = 1.0
		else:
			# arranca: despega primero el pie que está más atrás respecto a hacia donde va
			var dv := vel_h.normalized() if vel_h.length() > 0.05 else Rbx.look(frame)
			var atras_L := -(Vector3(feet.L.pos) - root_cf.origin).dot(dv)
			var atras_R := -(Vector3(feet.R.pos) - root_cf.origin).dot(dv)
			var primero := "L" if atras_L >= atras_R else "R"
			gait01 = fposmod(contacto_de.call(primero) + ((1.0 - fr) if anim_sentido > 0.0 else 0.0), 1.0)
		for k in ["L", "R"]:
			_pie_en_fase(feet[k], fposmod(gait01 - (0.25 if k == "L" else 0.75), 1.0), fr)
			feet[k].erase("anim_paso")
			feet[k].anim_pos0 = feet[k].get("cur") if feet[k].get("cur") != null else feet[k].pos
			feet[k].anim_roll0 = feet[k].get("roll", 0.0)
			# (el pie que está apoyado al arrancar sigue donde estaba: no resbala hasta su sitio de la animación)
			var p0: Vector3 = feet[k].anim_pos0
			feet[k].anim_lock = Vector3(p0.x, 0.0, p0.z)
			feet[k].anim_off = Vector3.ZERO
		anim_aire = false
	anim_w = minf(1.0, anim_w + dt / 0.18)
	anim_cruce = maxf(0.0, anim_cruce - dt / 0.25)
	var dphi := anim_sentido * v_fase * dt / zan
	gait01 = fposmod(gait01 + dphi, 1.0)
	for k in ["L", "R"]:
		var fk: Dictionary = feet[k]
		var psi_obj := fposmod(gait01 - (0.25 if k == "L" else 0.75), 1.0)
		if not fk.has("ap_paso"):
			_pie_en_fase(fk, psi_obj, fr)
			continue
		var psi_f: float = (1.0 - fr) + float(fk.ap_x) * fr if fk.ap_paso else float(fk.ap_x) * (1.0 - fr)
		var e := wrapf(psi_obj - psi_f, -0.5, 0.5)
		# el pie apoyado avanza exactamente con el cuerpo (si no, se queda atrás estirando la pierna); el ajuste para
		# ir a la par de la fase global solo se hace en el aire (paso un poco más rápido o más lento)
		var corr := absf(dphi) * clampf(e * 3.0, -0.35, 0.6) if fk.ap_paso else 0.0
		# pie apoyado que se quedó demasiado atrás (frenada, giro): despega ya
		if not fk.ap_paso and fk.get("anim_lock") != null and anim_w >= 1.0:
			var hip_g := frame * Vector3(fk.side * hip_x, 0.0, 0.0)
			var lk: Vector3 = fk.anim_lock
			if Vector2(lk.x - hip_g.x, lk.z - hip_g.z).length() > leg_len * 0.95 and Vector3(lk.x - hip_g.x, 0.0, lk.z - hip_g.z).dot(vel_dir * anim_sentido) < 0.0:
				fk.ap_paso = true
				fk.ap_x = 0.0
				continue
		_avanza_pie(fk, dphi + corr, fr)
	ritmo_periodo = zan / maxf(v_fase, 0.1)
	reloj_activo = true
	ultimo_pie = ""
	var dd := zan * (1.0 - fr)
	var delante := _par_pierna("delante", run01)
	var estrecha := _par_pierna("estrecha", run01)
	var body_gy: float = frame.origin.y - jugador.center_cur
	var w := Rbx.smooth(anim_w)
	for k in ["L", "R"]:
		var f: Dictionary = feet[k]
		var pa := _pierna_anim(bool(f.ap_paso), float(f.ap_x), zan, fr, run01, v_fase)
		# de lado: cada pie se separa hacia su lado lo justo para no cruzarse con el otro (paso lateral)
		var z_ext := minf(f.side * eje.x * dd * (delante - 1.15), f.side * eje.x * dd * delante)
		var desp_x := maxf(0.0, ANIM_MIN_X - (hip_x - estrecha) - z_ext)
		var loc := _tobillo_anim(k, pa[0], eje, desp_x, estrecha)
		if anim_cruce > 0.0 and anim_cruce_desde.has(k):
			loc = loc.lerp(anim_cruce_desde[k], Rbx.smooth(anim_cruce))
		anim_local[k] = loc
		var fyaw := Rbx.ang(0, body_yaw + f.side * -0.1, 0).basis
		var ank_w := frame * loc
		var p := ank_w + fyaw * Vector3(0, 0, -0.2)   # centro del pie (el tobillo está 0,2 por detrás)
		var en_paso: bool = pa[3]
		var era_paso = f.get("anim_paso")
		var y: float
		if not en_paso:
			# EL 5 % PROCEDURAL: el pie apoyado se queda clavado donde pisó (al frenar, acelerar o girar la animación lo
			# movería un poco); solo se acerca despacio a donde lo pone la animación, y lo que le falte lo recupera en
			# el paso siguiente
			var p_an := Vector3(p.x, 0.0, p.z)
			if era_paso == true or f.get("anim_lock") == null:
				# apoya donde terminó el paso (con lo que se movió para pisar el centro del escalón)
				var eo: Vector3 = f.get("esc_off_v", Vector3.ZERO)
				f.anim_lock = p_an + Vector3(eo.x, 0.0, eo.z)
				f.esc_off_v = Vector3.ZERO
			else:
				var k_lock := 0.0 if (esc_fondo > 0.0 or anim_parando > 0.0) else 2.5
				f.anim_lock = (f.anim_lock as Vector3).lerp(p_an, minf(1.0, dt * k_lock))
			f.anim_off = (f.anim_lock as Vector3) - p_an
			p = Vector3(f.anim_lock.x, p.y, f.anim_lock.z)
			if era_paso == null or era_paso == true:
				# apoya: el pie se queda a la altura del suelo que pisa hasta despegar
				var g := _suelo_pie(p, body_gy)
				f.anim_suelo = g[0]
				f.normal = g[1]
				if era_paso == true and anim_w >= 1.0:
					Ruido.emitir(jugador, p, Ruido.radio_paso(step_k, false), Ruido.PASO, jugador)
					var v_paso := clampf(step_k, 0.12, 1.0)
					Efectos.sonido(jugador, "Step", p, 0.25 + 0.75 * v_paso, 0.92 + step_k * 0.12)
					_registrar_paso(k, run01)
			y = f.anim_suelo
		else:
			if era_paso == null or era_paso == false:
				f.anim_desde = f.get("anim_suelo", body_gy)
				if era_paso == null:
					f.anim_off = Vector3.ZERO
			# dónde apoyará: el suelo de ese sitio (escalones, cuestas)
			var u: float = pa[4]
			# lo que el pie se apartó de la animación mientras estaba apoyado se recupera en la primera mitad del paso
			var off_p: Vector3 = f.get("anim_off", Vector3.ZERO)
			p += off_p * (1.0 - Rbx.smooth(u / 0.6))
			var t_rest := (1.0 - u) * fr * ritmo_periodo
			var aterriza := frame * _tobillo_anim(k, dd * delante, eje, desp_x, estrecha) + vel_h * t_rest + fyaw * Vector3(0, 0, -0.2)
			# escalera: el pie apoya en el centro de la huella (no en el borde ni a medias); el escalón se elige al
			# despegar y el pie se va acercando a él durante el paso
			if era_paso != true:
				f.esc_obj = _centro_huella(aterriza)
			if f.get("esc_obj") != null and esc_fondo > 0.0:
				var off_e := clampf(((f.esc_obj as Vector3) - aterriza).dot(esc_dir), -esc_fondo * 0.6, esc_fondo * 0.6)
				f.esc_off_v = esc_dir * off_e * Rbx.smooth(u / 0.85)
				p += f.esc_off_v
				aterriza += esc_dir * off_e
			else:
				f.esc_off_v = Vector3.ZERO
			var g := _suelo_pie(aterriza, body_gy)
			var y0: float = f.anim_desde
			var rise: float = g[0] - y0
			var hu := Rbx.smooth((u - 0.05) / 0.5) if rise > 0 else Rbx.smooth(u / lerpf(1.0, 0.55, clampf(-rise / 1.5, 0.0, 1.0)))
			y = y0 + rise * hu + float(pa[1])
			f.anim_suelo = g[0]
			f.normal = Vector3.UP.lerp(g[1], u)
		f.anim_paso = en_paso
		var pos := Vector3(p.x, y, p.z)
		var roll: float = pa[2]
		if w < 1.0:
			pos = (f.anim_pos0 as Vector3).lerp(pos, w)
			roll = lerpf(float(f.anim_roll0), roll, w)
		f.anim = true
		f.cur = pos
		f.pos = pos
		f.roll = roll
		f.u = pa[4] if en_paso else null
		f.swing = {"anim": true} if en_paso else null
		f.yaw = body_yaw
		f.swingYaw = null
		f.overreach = false


## se para: los pies se quedan donde están (el que iba en el aire termina su paso hasta donde le toca de pie)
func _parar_animada(body_yaw: float) -> void:
	anim_w = 0.0
	anim_aire = false
	reloj_activo = false
	for k in ["L", "R"]:
		var f: Dictionary = feet[k]
		f.anim = false
		var c: Vector3 = f.cur if f.get("cur") != null else f.pos
		if f.swing != null:
			f.swing = {"from": c, "t": 0.0, "dur": 0.22, "fromYaw": body_yaw, "idle": true, "roll0": f.get("roll", 0.0)}
		else:
			f.pos = Vector3(c.x, f.get("anim_suelo", c.y), c.z)
			f.cur = null
			f.u = null


func _registrar_paso(k: String, run01: float) -> void:
	var now := ahora()
	var c := now - float(step_start[k])
	if run01 > 0.3 and c > 0.2 and c < 1.2:
		run_cycle = c if run_cycle <= 0.0 else lerpf(run_cycle, c, 0.3)
	elif run01 <= 0.3:
		run_cycle = 0.0
	step_start[k] = now


## (red de seguridad) un pie apoyado nunca queda del lado de la otra pierna
func clamp_planted(root_cf: Transform3D) -> void:
	var frame := Rbx.cfp(root_cf.origin) * Rbx.ang(0, Rbx.yaw_of(root_cf), 0)
	for s in feet:
		var f: Dictionary = feet[s]
		if f.swing == null:
			var lp := Rbx.to_obj(frame, f.pos)
			if lp.x * f.side < min_foot_x:
				var w := frame * Vector3(f.side * min_foot_x, lp.y, lp.z)
				f.pos = Vector3(w.x, f.pos.y, w.z)


func foot_cf(f: Dictionary, yaw: float) -> Transform3D:
	var p: Vector3 = f.cur if f.get("cur") != null else f.pos
	var pitch := 0.0
	# (el giro del pie en el aire va en f.roll: sobre la punta al despegar, sobre el talón al apoyar)
	var n: Vector3 = f.normal if f.get("normal") != null else Vector3.UP
	# apoyado, el pie mantiene la orientación con la que pisó (no gira sobre sí mismo)
	var fy: float = yaw
	if f.get("swingYaw") != null:
		fy = f.swingYaw
	elif f.get("yaw") != null:
		fy = f.yaw
	var yaw_cf := Rbx.ang(0, fy + f.side * -0.1, 0)
	var tilt := Transform3D.IDENTITY
	if n.y < 0.999:
		var ax := Vector3.UP.cross(n)
		tilt = Rbx.axis_angle(ax.normalized(), acos(clampf(n.y, -1, 1)))
	var cf := Rbx.cfp(p + Vector3(0, foot_half, 0)) * tilt * yaw_cf * Rbx.ang(pitch, 0, 0)
	# rodar el pie apoyado: negativo = talón levantado (gira sobre la punta); positivo = punta
	# levantada (gira sobre el talón)
	var roll: float = f.get("roll", 0.0)
	if absf(roll) > 1e-4:
		var piv := Vector3(0, -foot_half, -0.5 if roll < 0 else 0.5)
		cf = cf * Rbx.cfp(piv) * Rbx.ang(roll, 0, 0) * Rbx.cfp(-piv)
	return cf


## Pie apoyado lejos de la cadera: en vez de bajar la pelvis (rodillas dobladas), el pie de atrás
## despega el talón y el de delante apoya con el talón (punta arriba), como al andar de verdad.
func update_roll(f: Dictionary, s: String, hip: Vector3, yaw: float, yaw_only: Transform3D, dt: float) -> void:
	if f.swing != null or bool(f.get("anim", false)):
		return
	var reach := leg_len * 0.994
	var prev: float = f.get("roll", 0.0)
	f.roll = 0.0
	var ankle0 := (foot_cf(f, yaw) * Rbx.cfp(ankle_in_foot[s])).origin
	var target := 0.0
	if (ankle0 - hip).length() > reach:
		var behind := Rbx.to_obj(yaw_only, ankle0).z > 0
		var lim := -0.9 if behind else 0.6
		var lo := 0.0
		var hi := lim
		for _i in 10:
			var mid := (lo + hi) * 0.5
			f.roll = mid
			var a := (foot_cf(f, yaw) * Rbx.cfp(ankle_in_foot[s])).origin
			if (a - hip).length() > reach:
				lo = mid
			else:
				hi = mid
		target = hi
	# sin retraso (si no, la pelvis tendría que bajar mientras el pie termina de rodar); pero el pie que acaba de
	# apoyar con el talón (punta arriba) baja la punta en ~0,1 s, no de golpe
	var baja := 3.0 if (prev > 0.0 and target < prev) else 10.0
	f.roll = prev + clampf(target - prev, -baja * dt, 10 * dt)


## suavizado de articulaciones: da peso e inercia al cuerpo (evita movimientos bruscos)
func smooth_j(m: RigPersonaje.Motor, key: String, rate: float, dt: float) -> void:
	if muelle_p.has(key):
		vel_p[key] = Vector3.ZERO
	muelle_q.erase(key)
	muelle_p.erase(key)
	if prev_t.has(key):
		m.transform = (prev_t[key] as Transform3D).interpolate_with(m.transform, 1 - exp(-rate * dt))
		_anota_vel_j(key, prev_t[key], m.transform, dt)
	prev_t[key] = m.transform


## Solo registra la pose de la articulación (y a qué velocidad gira), sin suavizar.
func anota_j(m: RigPersonaje.Motor, key: String, dt: float) -> void:
	muelle_q.erase(key)
	muelle_p.erase(key)
	if prev_t.has(key):
		_anota_vel_j(key, prev_t[key], m.transform, dt)
	prev_t[key] = m.transform


func _anota_vel_j(key: String, ant: Transform3D, nuevo: Transform3D, dt: float) -> void:
	var dq := Quaternion(nuevo.basis.orthonormalized()) * Quaternion(ant.basis.orthonormalized()).inverse()
	if dq.w < 0.0:
		dq = -dq
	vel_j[key] = (dq.get_axis() * dq.get_angle() / maxf(dt, 1e-3)) if dq.get_angle() > 1e-5 else Vector3.ZERO


## Suavizado "de muelle" (amortiguado crítico): la articulación acelera y frena hacia su pose sin tirones,
## aunque la pose objetivo salte. Conserva el giro que llevaba.
func smooth_j2(m: RigPersonaje.Motor, key: String, omega: float, dt: float, a_directo := 0.0) -> void:
	var qt := Quaternion(m.transform.basis.orthonormalized())
	var orig := m.transform.origin
	if not muelle_q.has(key):
		# (empieza desde donde estaba la articulación, con el giro que llevaba)
		muelle_q[key] = Quaternion((prev_t.get(key, m.transform) as Transform3D).basis.orthonormalized())
	var q: Quaternion = muelle_q[key]
	var e := qt * q.inverse()
	if e.w < 0.0:
		e = -e
	var ev := e.get_axis() * e.get_angle() if e.get_angle() > 1e-5 else Vector3.ZERO
	var w: Vector3 = vel_j.get(key, Vector3.ZERO)
	# (paso implícito: estable aunque el fotograma sea largo)
	w = (w + ev * (omega * omega * dt)) / (1.0 + 2.0 * omega * dt + omega * omega * dt * dt)
	var giro := w * dt
	var q2 := ((Quaternion(giro.normalized(), giro.length()) * q) if giro.length() > 1e-6 else q).normalized()
	vel_j[key] = w
	muelle_q[key] = q2
	# la posición (solo la cadera se desplaza) va con el mismo muelle
	if not muelle_p.has(key):
		muelle_p[key] = (prev_t.get(key, m.transform) as Transform3D).origin
	var p: Vector3 = muelle_p[key]
	var vp: Vector3 = vel_p.get(key, Vector3.ZERO)
	vp = (vp + (orig - p) * (omega * omega * dt)) / (1.0 + 2.0 * omega * dt + omega * omega * dt * dt)
	p += vp * dt
	vel_p[key] = vp
	muelle_p[key] = p
	# (a_directo: al final de una transición se va pasando, sin salto, a la pose tal cual)
	var ad := clampf(a_directo, 0.0, 1.0)
	m.transform = Transform3D(Basis(q2.slerp(qt, ad)), p.lerp(orig, ad))
	prev_t[key] = m.transform


## Si el brazo (hombro→codo→mano) entra en la geometría, se recoloca la mano sobre la superficie.
func _brazo_sin_choque(Lm: Limb, s: String, chest: Transform3D) -> void:
	var sh := (chest * Lm.top.c0).origin
	var up_cf := fk(chest, Lm.top)
	var el := (up_cf * Lm.mid.c0).origin
	var hd := fk(fk(up_cf, Lm.mid), Lm.fin).origin
	var tip := hd + (hd - el).normalized() * 0.5
	var hit := jugador.raycast(sh, el - sh)
	if hit.is_empty():
		hit = jugador.raycast(el, tip - el)
	if hit.is_empty():
		return
	var n: Vector3 = hit.normal
	var target: Vector3 = hit.position + n * 1.0
	if n.y > 0.5:
		# mesa o bloque bajo delante: el brazo cuelga por delante del borde (no se mete dentro);
		# si la mano ya está sobre la superficie, se apoya encima
		target = hit.position + n * 0.55
		var a0 := Vector3(sh.x, hd.y - 0.3, sh.z)
		var a1 := Vector3(hd.x, hd.y - 0.3, hd.z)
		var fl := a1 - a0
		if fl.length() > 0.05:
			var hf := jugador.raycast(a0, fl + fl.normalized() * 0.5)
			if not hf.is_empty() and absf((hf.normal as Vector3).y) < 0.5:
				var nf: Vector3 = hf.normal
				target = Vector3(hf.position.x, hd.y, hf.position.z) + Vector3(nf.x, 0, nf.z).normalized() * 0.6
	if hit.position.distance_to(sh) < 0.4:
		target = sh + n * 0.8 + Vector3(0, -1.2, 0)
	var sg := -1.0 if s == "L" else 1.0
	var top0 := Lm.top.transform
	var mid0 := Lm.mid.transform
	solve(Lm, chest, target, (chest * Rbx.cf(sg * 1.8, -1.4, 0.8)).origin, 1.0)
	# (2026-10-30) el brazo se aparta deprisa pero sin saltar de golpe (antes, al pasar junto a una pared, la mano
	# daba un salto de hasta 3 studs en un fotograma)
	Lm.top.transform = top0.interpolate_with(Lm.top.transform, 0.4)
	Lm.mid.transform = mid0.interpolate_with(Lm.mid.transform, 0.4)
	prev_t[s + "Sh"] = Lm.top.transform
	prev_t[s + "El"] = Lm.mid.transform
	muelle_q.erase(s + "Sh")
	muelle_q.erase(s + "El")


## Fase continua de la marcha: un oscilador que avanza al ritmo de los pasos y se sincroniza con el
## pie que está en el aire. Brazos y torso siguen esta onda suave en vez de seguir a saltos la
## posición de los pies (que se paran al apoyar y se disparan al dar el paso).
## sin(gait_ph) = +1 -> brazo derecho delante (pierna izquierda delante).
## ---- ciclos de la marcha de Blender (Movimientos): mezcla según la velocidad y la postura
func _ciclo(canal: String, phi: float) -> float:
	var v := Movimientos.ciclo("andar", canal, phi)
	if mez_run > 0.001:
		v = lerpf(v, Movimientos.ciclo("correr", canal, phi), mez_run)
	if crouch_b > 0.001:
		v = lerpf(v, Movimientos.ciclo("agachado", canal, phi), crouch_b)
	return v


## hombro (x, y, z), codo y muñeca del brazo s ("L" | "R"): el izquierdo va medio ciclo después y en espejo
func _brazo_ciclo(s: String, phi: float) -> Array:
	var f := phi if s == "R" else phi + 0.5
	var sg := 1.0 if s == "R" else -1.0
	return [_ciclo("hombro_p", f), sg * _ciclo("hombro_y", f), sg * _ciclo("hombro_r", f), _ciclo("codo", f), _ciclo("muneca", f)]


## forma del paso (u = 0 despega, 1 apoya): andar / agachado, y correr según run01
func _curva_pie(canal: String, u: float, run01: float) -> float:
	var v := Movimientos.pie("andar", canal, u)
	if crouch_b > 0.001:
		v = lerpf(v, Movimientos.pie("agachado", canal, u), crouch_b)
	if run01 > 0.001:
		v = lerpf(v, Movimientos.pie("correr", canal, u), run01)
	return v


func _fase_marcha(speed: float, dt: float) -> void:
	var now := ahora()
	if reloj_activo:
		# en marcha, la fase del cuerpo ES el reloj de los pasos (siempre a la par, sin tirones)
		gait_ph = gait01 * TAU
		gait_rate = TAU / ritmo_periodo
		last_step_t = now
		gait_amp = Rbx.damp(gait_amp, clampf(speed / 3.0, 0.0, 1.0) if speed > 0.6 else 0.0, 4, dt)
		return
	for s in ["L", "R"]:
		var f: Dictionary = feet[s]
		var sw: bool = f.swing != null
		if sw and not sw_prev[s]:
			var hp := now - last_step_t
			if hp > 0.1 and hp < 1.2:
				gait_rate = lerpf(gait_rate, PI / hp, 0.25) if gait_rate > 0.0 else PI / hp
			last_step_t = now
		sw_prev[s] = sw
	var target = null
	var best_u := 2.0
	for s in ["L", "R"]:
		var f: Dictionary = feet[s]
		if f.swing != null and f.get("u") != null and float(f.u) < best_u:
			best_u = f.u
			target = (-PI * 0.5 if s == "L" else PI * 0.5) + PI * float(f.u)
	if now - last_step_t > 1.2:
		gait_rate = Rbx.damp(gait_rate, 0.0, 3, dt)
	gait_ph += gait_rate * dt
	if target != null:
		# (corrección suave: tirar fuerte de la fase hacía que avanzara a tirones y el cuerpo con ella)
		gait_ph += wrapf(float(target) - gait_ph, -PI, PI) * minf(1.0, dt * 2.5)
	gait_ph = wrapf(gait_ph, 0.0, TAU)
	gait_amp = Rbx.damp(gait_amp, clampf(speed / 3.0, 0.0, 1.0) if speed > 0.6 else 0.0, 4, dt)


## Curva de golpe: posiciones por Catmull-Rom (el arma sigue un arco continuo, sin pararse en cada
## clave) y giro por slerp lineal entre claves.
static func _muestra_golpe(keys: Array, t: float) -> Transform3D:
	var n := keys.size()
	if t <= keys[0][0]:
		return keys[0][1]
	if t >= keys[n - 1][0]:
		return keys[n - 1][1]
	var i := 0
	while i < n - 2 and t > keys[i + 1][0]:
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var u := clampf((t - t0) / maxf(1e-4, t1 - t0), 0.0, 1.0)
	var a: Transform3D = keys[i][1]
	var b: Transform3D = keys[i + 1][1]
	var p0: Vector3 = (keys[i - 1][1] as Transform3D).origin if i > 0 else a.origin
	var p3: Vector3 = (keys[i + 2][1] as Transform3D).origin if i + 2 < n else b.origin
	var pos := a.origin.cubic_interpolate(b.origin, p0, p3, u)
	var q := Quaternion(a.basis.orthonormalized()).slerp(Quaternion(b.basis.orthonormalized()), u)
	return Transform3D(Basis(q), pos)


## Empuja el arma (sin girarla) lo justo para que ningún punto de la hoja o el mango quede dentro de
## las piezas del propio cuerpo. Se prueban puntos a lo largo del arma (-Z del Handle).
const LARGO_ARMA := {"Bate": 2.28, "Machete": 1.67, "Cuchillo": 0.98, "Hacha": 2.0, "Palanca": 1.75}


func _arma_fuera_del_cuerpo(h: Transform3D, tool: String, pelvis_cf: Transform3D, chest_cf: Transform3D) -> Transform3D:
	var largo: float = LARGO_ARMA.get(tool, 1.0)
	var grosor := 0.16 if tool in ["Bate", "Hacha"] else 0.1
	var cajas := [
		[chest_cf, (P.UpperTorso as Node3D).get_meta("size")],
		[fk(chest_cf, M.Neck), (P.Head as Node3D).get_meta("size")],
		[pelvis_cf, (P.LowerTorso as Node3D).get_meta("size")],
		[(P.LeftUpperLeg as Node3D).global_transform, (P.LeftUpperLeg as Node3D).get_meta("size")],
		[(P.RightUpperLeg as Node3D).global_transform, (P.RightUpperLeg as Node3D).get_meta("size")],
	]
	for _it in 4:
		var empuje := Vector3.ZERO
		for k in 11:
			var pt: Vector3 = h * Vector3(0, 0, 0.25 - (largo + 0.25) * k / 10.0)
			for c in cajas:
				var cf: Transform3D = c[0]
				var half: Vector3 = (c[1] as Vector3) * 0.5 + Vector3.ONE * (grosor + (0.12 if c == cajas[1] else 0.0))
				var lp: Vector3 = cf.affine_inverse() * pt
				var dx := half.x - absf(lp.x)
				var dy := half.y - absf(lp.y)
				var dz := half.z - absf(lp.z)
				if dx <= 0 or dy <= 0 or dz <= 0:
					continue
				# sale por el lado más cercano (de lado o por delante; nunca hacia atrás a través del cuerpo)
				var v: Vector3
				if dx < dz:
					v = cf.basis.x.normalized() * signf(lp.x if lp.x != 0 else 1.0) * dx
				else:
					v = cf.basis.z.normalized() * signf(lp.z if lp.z != 0 else -1.0) * dz
				if v.length() > empuje.length():
					empuje = v
		if empuje.length() < 0.005:
			break
		h.origin += empuje * 1.05
	return h


## recorrido por claves (sacar/guardar el arma): curva suave (cúbica) por las posiciones y giros de las claves
## [[u, Transform3D], ...] (u de 0 a 1, en orden)
static func _por_claves(k: Array, u: float) -> Transform3D:
	var n := k.size()
	if u <= float(k[0][0]):
		return k[0][1]
	for i in n - 1:
		var u0: float = k[i][0]
		var u1: float = k[i + 1][0]
		if u > u1 and i < n - 2:
			continue
		var a: Transform3D = k[i][1]
		var b: Transform3D = k[i + 1][1]
		var pa: Transform3D = k[maxi(i - 1, 0)][1]
		var pb2: Transform3D = k[mini(i + 2, n - 1)][1]
		var upa: float = k[maxi(i - 1, 0)][0] if i > 0 else u0 - (u1 - u0)
		var upb: float = k[mini(i + 2, n - 1)][0] if i + 2 < n else u1 + (u1 - u0)
		var s := clampf((u - u0) / maxf(1e-4, u1 - u0), 0.0, 1.0)
		var d := u1 - u0
		var pos := a.origin.cubic_interpolate_in_time(b.origin, pa.origin, pb2.origin, s, d, upa - u0, upb - u0)
		var qa := Quaternion(a.basis.orthonormalized())
		var qb := Quaternion(b.basis.orthonormalized())
		var qpa := Quaternion(pa.basis.orthonormalized())
		var qpb := Quaternion(pb2.basis.orthonormalized())
		var q := qa.spherical_cubic_interpolate_in_time(qb, qpa, qpb, s, d, upa - u0, upb - u0)
		return Transform3D(Basis(q.normalized()), pos)
	return k[n - 1][1]


## armas de fuego: puntos de muestra del modelo (centro de cada pieza y, en las largas, sus dos extremos) en el marco
## de la empuñadura, que es el del propio modelo. Se calculan una vez por arma
var _puntos_arma_cache := {}


func _puntos_arma(mdl: Node3D, tool: String) -> Array:
	if _puntos_arma_cache.has(tool):
		return _puntos_arma_cache[tool]
	var pts: Array = []
	var inv := mdl.global_transform.affine_inverse()
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (mi as MeshInstance3D).get_aabb()
		var t: Transform3D = inv * (mi as MeshInstance3D).global_transform
		pts.append(t * ab.get_center())
		var eje := ab.get_longest_axis()
		if ab.size[ab.get_longest_axis_index()] > 0.3:
			pts.append(t * (ab.get_center() + eje * ab.size[ab.get_longest_axis_index()] * 0.5))
			pts.append(t * (ab.get_center() - eje * ab.size[ab.get_longest_axis_index()] * 0.5))
	_puntos_arma_cache[tool] = pts
	return pts


## las armas de fuego tampoco atraviesan el pecho ni la barriga: lo que quede dentro (la culata en el hombro, el
## guardamanos al llevarla cruzada, la pistola pegada a la tripa) sale siempre HACIA DELANTE, hasta la cara delantera
## del torso (así la culata queda apoyada en el hombro, y nunca da saltos de un lado a otro)
var fuera_w := 0.0
# ARMA APOYADA (2026-11-03): el cuerpo se agacha o el arma sube lo justo para que el arma quede encima del apoyo
var rest_baja := 0.0     # cuánto baja el cuerpo (studs; < 0 = se incorpora)
var rest_alza := 0.0     # cuánto suben los brazos el arma (si el apoyo está algo más alto que el arma)
var _esquinas_arma_cache := {}


## esquinas de las piezas del arma (en el espacio del arma): para saber dónde queda su parte de abajo
func _esquinas_arma(mdl: Node3D, tool: String) -> Array:
	if _esquinas_arma_cache.has(tool):
		return _esquinas_arma_cache[tool]
	var pts: Array = []
	var inv := mdl.global_transform.affine_inverse()
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (mi as MeshInstance3D).get_aabb()
		var t: Transform3D = inv * (mi as MeshInstance3D).global_transform
		for i in 8:
			pts.append(t * ab.get_endpoint(i))
	_esquinas_arma_cache[tool] = pts
	return pts


## Arma apoyada en un muro, una barrera, un alféizar…: la parte de abajo del arma que queda encima del apoyo (más
## allá de su borde) se pone a ras de él. Si el arma flota, el cuerpo baja (rodillas); si se mete dentro, el arma
## sube en ese mismo fotograma (nunca atraviesa) y el cuerpo sube poco a poco. Devuelve el arma corregida.
func _arma_sobre_apoyo(h: Transform3D, mdl: Node3D, tool: String, root_cf: Transform3D, dt: float, ra, solo_subir := false) -> Transform3D:
	if ra == null or bool(ra.get("ground", false)) or bool(ra.get("lado", false)):
		rest_alza = 0.0
		return h
	var fwd := Rbx.flat(-h.basis.z)
	if fwd.length() < 0.1:
		return h
	fwd = fwd.normalized()
	var top: float = ra.top
	var base := root_cf.origin
	# dónde empieza el apoyo (su cara delantera), medido desde el cuerpo a lo largo del arma
	if not ra.has("borde_d") or absf(float(ra.get("borde_top", top)) - top) > 0.05:
		var hb: Dictionary = jugador.raycast(Vector3(base.x, top - 0.08, base.z), fwd * 3.5)
		ra.borde_d = float(hb.distance) if not hb.is_empty() else maxf(0.0, Rbx.flat(ra.point - base).length() - 0.35)
		ra.borde_top = top
	var borde: float = ra.borde_d
	var y_min := INF
	for p in _esquinas_arma(mdl, tool):
		var wp: Vector3 = h * (p as Vector3)
		if (wp - base).dot(fwd) > borde + 0.06:
			y_min = minf(y_min, wp.y)
	if y_min == INF:
		rest_alza = 0.0
		return h
	# (apuntando sin apoyar, solo se evita que lo atraviese: queda un poco por encima)
	var delta := top + (0.06 if solo_subir else 0.02) - y_min   # (> 0: el arma se mete en el apoyo; < 0: flota)
	# el cuerpo baja si el arma flota y sube si se mete (despacio: así no tiembla)
	# (negativo = el cuerpo se levanta: agachado tras una barrera, se incorpora un poco para apoyar el arma)
	rest_baja = clampf(rest_baja - delta * minf(1.0, dt * 6.0), -0.9, 0.0 if solo_subir else 1.1)
	rest_alza = clampf(delta, 0.0, 0.4)
	return Transform3D(h.basis, h.origin + Vector3(0, rest_alza, 0))


func _arma_de_fuego_fuera(h: Transform3D, pts: Array, pelvis_cf: Transform3D, chest_cf: Transform3D, w: float) -> Transform3D:
	if w < 0.001 or pts.is_empty():
		return h
	var cajas := [
		[chest_cf, (P.UpperTorso as Node3D).get_meta("size") as Vector3, 0.04],
		[pelvis_cf, (P.LowerTorso as Node3D).get_meta("size") as Vector3, 0.03],
	]
	for _it in 2:
		var empuje := Vector3.ZERO
		for c in cajas:
			var cf: Transform3D = c[0]
			var half: Vector3 = (c[1] as Vector3) * 0.5
			var m: float = c[2]
			var inv := cf.affine_inverse()
			var adel := -cf.basis.z.normalized()
			var dz_max := 0.0
			for pl in pts:
				var lp: Vector3 = inv * (h * (pl as Vector3))
				if absf(lp.x) >= half.x or absf(lp.y) >= half.y or lp.z >= half.z or lp.z <= -half.z - m:
					continue
				# cuánto le falta para quedar delante de la cara delantera (con un pequeño margen); los puntos que
				# están justo en el borde (de lado, arriba o detrás) empujan menos, para que entrar y salir sea suave
				var borde := minf(minf(half.x - absf(lp.x), half.y - absf(lp.y)), half.z - lp.z)
				dz_max = maxf(dz_max, (lp.z + half.z + m) * clampf(borde / 0.08, 0.0, 1.0))
			if dz_max * adel.length() > empuje.length():
				empuje = adel * dz_max
		if empuje.length() < 0.005:
			break
		h.origin += empuje * w
	return h


## ---------------------------------------------------------------- combate cuerpo a cuerpo (CombateCC)
## Mezcla la guardia, el bloqueo y la acción en curso (empujón / patada) en cc_pose. Los canales de brazos y arma son
## posiciones (se mezclan con la pose de siempre por cc_w); los del cuerpo (cin_*, cue_*, cad_*, pel_*) se suman.
const CC_CUERPO := ["cin_y", "cin_p", "cin_r", "cue_y", "cue_p", "cue_r", "cad_x", "cad_y", "cad_z", "pel_p", "pel_y", "pel_r"]

static func _cc_env(u: float) -> float:
	return Rbx.smooth(u / 0.16) * (1.0 - Rbx.smooth((u - 0.78) / 0.22))


func _paso_cc(now: float, dt: float) -> void:
	var ar = jugador.arsenal
	var cc: Dictionary = ar.cc
	cc_clase = ar.cc_clase()
	var fuego := cc_clase.begins_with("fuego")
	cc_guard_w = Rbx.damp(cc_guard_w, 1.0 if (cc.guardia and not fuego) else 0.0, 10.0, dt)
	cc_block_w = Rbx.damp(cc_block_w, 1.0 if cc.bloqueo else 0.0, 18.0, dt)
	var base := {}
	var base_w := 0.0
	var G: Dictionary = CombateCC.GUARDIA.get(cc_clase, {})
	var B: Dictionary = CombateCC.BLOQUEO.get(cc_clase, {})
	if fuego:
		base = B
		base_w = cc_block_w
	elif not G.is_empty():
		base = G.duplicate()
		for k in B:
			base[k] = lerpf(float(G.get(k, B[k])), float(B[k]), cc_block_w)
		base_w = maxf(cc_guard_w, cc_block_w)
	# respiración en guardia: los puños suben y bajan un poco
	var resp := sin(now * 2.4) * 0.025 * cc_guard_w * (1.0 - cc_block_w)
	cc_pose = {}
	for k in base:
		var v: float = base[k]
		if k in CC_CUERPO:
			v *= base_w
		elif k == "mr_y" or k == "ml_y" or k == "a_py":
			v += resp
		cc_pose[k] = v
	cc_w = base_w
	cc_kick = null
	cc_rapido = false
	var ac = cc.accion
	if ac == null:
		ar.impacto.sumar_cuerpo(cc_pose) # (lo que quede del ajuste al blanco, volviendo suave)
		return
	var u := clampf((now - float(ac.t0)) / float(ac.dur), 0.0, 1.0)
	var a: Dictionary = ar.cc_anim(ac)
	var P := CombateCC.pose(a, u)
	var e := _cc_env(u)
	cc_rapido = true
	var brazos_accion := false
	for k in P:
		if k == "avance" or k.begins_with("pie_") or k.begins_with("ro_"):
			continue
		var es_brazo: bool = k.begins_with("m") or k.begins_with("p") and not k.begins_with("pel") or k.begins_with("a_")
		if es_brazo and (ac.tipo == "patada" or ac.tipo == "pisoton") and cc_clase != "manos":
			continue # con arma, la patada no mueve los brazos
		var v: float = P[k]
		if k in CC_CUERPO:
			cc_pose[k] = lerpf(float(cc_pose.get(k, 0.0)), v, e)
		else:
			brazos_accion = true
			cc_pose[k] = lerpf(float(cc_pose.get(k, v)), v, e) if base_w > 0.01 else v
	if brazos_accion:
		cc_w = lerpf(base_w, 1.0, e)
	if ac.tipo == "patada" or ac.tipo == "pisoton":
		for k in ["pie_x", "pie_y", "pie_z", "pie_inc", "ro_x", "ro_y", "ro_z"]:
			cc_pose[k] = P[k]
		cc_kick = {"lado": str(a.lado), "w": clampf(float(P.pie_w), 0.0, 1.0)}
	# ajuste al blanco (ImpactoCC): la cadera baja y el tronco se inclina hacia él (p. ej. si está en el suelo)
	ar.impacto.sumar_cuerpo(cc_pose)


## mano de CombateCC (marco del pecho) -> objetivo de la IK
func _cc_mano(k: String, kp: String, marco: Transform3D, w: float) -> Dictionary:
	var c := cc_pose
	# (+ el desvío hacia el blanco y el rebote al golpear: ImpactoCC)
	var desv: Vector3 = jugador.arsenal.impacto.mano_local(k)
	var ik := {"pos": marco * (Vector3(c[k + "x"], c[k + "y"], c[k + "z"]) + desv),
		"pole": marco * (Vector3(c.get(kp + "x", 0.0), c.get(kp + "y", -1.0), c.get(kp + "z", 0.0)) + desv), "w": w}
	if float(c.get(k + "rw", 0.0)) > 0.05 and c.has(k + "dx"):
		var d := marco.basis * Vector3(c[k + "dx"], c[k + "dy"], c[k + "dz"])
		var bo := marco.basis * Vector3(c[k + "bx"], c[k + "by"], c[k + "bz"])
		var y := -d.normalized()
		var z := -bo.normalized()
		z = (z - y * z.dot(y)).normalized()
		ik.rot = Basis(y.cross(z), y, z)
		ik.rot_w = float(c[k + "rw"])
	return ik


## el Handle del arma según CombateCC (marco del pecho)
func _cc_handle() -> Transform3D:
	var c := cc_pose
	return Transform3D(Basis.looking_at(Vector3(c.a_fx, c.a_fy, c.a_fz).normalized(), Vector3(c.a_ux, c.a_uy, c.a_uz)),
		Vector3(c.a_px, c.a_py, c.a_pz) + jugador.arsenal.impacto.mano_local("a_p"))


## ---------------------------------------------------------------- eventos de armas (Anim.Fire)
func on_shot(w: String) -> void:
	match w:
		"Rifle":
			S.kick.impulse(3.2)
			S.kickRot.impulse(0.9)
		"Subfusil":
			S.kick.impulse(2.4)
			S.kickRot.impulse(0.7)
		"Escopeta":
			S.kick.impulse(7.0)
			S.kickRot.impulse(2.6)
		"Francotirador":
			S.kick.impulse(6.5)
			S.kickRot.impulse(2.2)
		"Revolver":
			S.kick.impulse(6.0)
			S.kickRot.impulse(2.6)
		_:
			S.kick.impulse(4.5)
			S.kickRot.impulse(1.8)
	last_shot_t = ahora()
	# escopeta: corredera atrás y adelante; fusil: cerrojo (los dos, un instante después del disparo)
	var wc: Dictionary = Armas.WEAPONS.get(w, {})
	if wc.get("Pump", false) or wc.get("Bolt", false):
		accion_t = ahora() + 0.12


## corredera de la escopeta y cerrojo del fusil (se animan moviendo el grupo "Pump" o "Bolt")
var accion_t := -9.0
const ACCION_DUR := 0.42


func _paso_accion(mdl: Node3D) -> void:
	if mdl == null:
		return
	var u := (ahora() - accion_t) / ACCION_DUR
	var k := sin(PI * clampf(u, 0.0, 1.0)) if u >= 0.0 and u <= 1.0 else 0.0
	var pump := mdl.get_node_or_null("Pump") as Node3D
	if pump:
		pump.position = Vector3(0, 0, 0.38 * k)
	var bolt := mdl.get_node_or_null("Bolt") as Node3D
	if bolt:
		# el cerrojo gira hacia arriba y luego va hacia atrás
		var giro := clampf(k * 2.0, 0.0, 1.0)
		var atras := clampf(k * 2.0 - 1.0, 0.0, 1.0)
		var piv := Vector3(0, 0.36, 0.12)
		bolt.transform = Transform3D(Basis.IDENTITY, piv + Vector3(0, 0, 0.32 * atras)) * Transform3D(Basis(Vector3(0, 0, 1), 1.1 * giro), -piv)
	if u >= 0.0 and u <= 1.0 and not get_meta("accion_snd", false) and u > 0.15:
		set_meta("accion_snd", true)
		Efectos.sonido(jugador, "Pump" if pump else "Bolt", jugador.global_position, 0.7, 1.0)
		var mdl2 = jugador.arsenal.modelo_mano
		if mdl2 and mdl2.has_node("Muzzle"):
			jugador.arsenal.expulsar_casquillo((mdl2.get_node("Muzzle") as Node3D).global_transform, pump != null)
	elif u > 1.0:
		set_meta("accion_snd", false)


func on_reload(w: String, dur: float, cartuchos := 0) -> void:
	var R := Armas.recarga(w, cartuchos)
	if not R.is_empty():
		reload_st = {"w": w, "start": ahora(), "dur": dur, "fired": {}, "R": R}


func on_melee(w: String) -> void:
	if not Armas.golpe(w).is_empty():
		melee_st = {"w": w, "start": ahora(), "dur": float(Armas.WEAPONS[w].Cooldown)}


func cancelar_recarga() -> void:
	if reload_st == null:
		return
	reload_st = null
	if hand_mag:
		hand_mag.queue_free()
		hand_mag = null
	var mdl: Node3D = jugador.arsenal.modelo_mano
	if mdl and mdl.has_node("Mag"):
		(mdl.get_node("Mag") as Node3D).visible = true


## el cargador: se suelta (cae al suelo), sale uno nuevo de la bolsa en la mano y se mete
func _mag_visual(ev: String) -> void:
	var mdl: Node3D = jugador.arsenal.modelo_mano
	# escopeta: un cartucho en la mano izquierda y dentro
	if ev.begins_with("shell_new"):
		if hand_mag:
			hand_mag.queue_free()
		var sh := Node3D.new()
		var a := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.033
		cm.bottom_radius = 0.033
		cm.height = 0.19
		a.mesh = cm
		a.material_override = Armas.material(ModelosArmas.ROJO, "Polymer")
		sh.add_child(a)
		var b := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.035
		cm2.bottom_radius = 0.035
		cm2.height = 0.045
		b.mesh = cm2
		b.position = Vector3(0, -0.11, 0)
		b.material_override = Armas.material(ModelosArmas.LATON, "Brass")
		sh.add_child(b)
		(P.LeftHand as Node3D).add_child(sh)
		sh.position = Vector3(0, -0.28, 0)
		sh.rotation = Vector3(PI / 2, 0, 0)
		hand_mag = sh
		return
	if ev.begins_with("shell_in"):
		if hand_mag:
			hand_mag.queue_free()
			hand_mag = null
		jugador.arsenal.cartucho_metido()
		return
	if mdl == null or not mdl.has_node("Mag"):
		return
	var mag := mdl.get_node("Mag") as Node3D
	if ev == "drop":
		mag.visible = false
		# el cargador (todas sus piezas) cae al suelo con física
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1
		var copia := mag.duplicate() as Node3D
		copia.visible = true
		copia.transform = Transform3D.IDENTITY
		rb.add_child(copia)
		var caja := _caja_de(mag)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = caja.size.max(Vector3(0.05, 0.05, 0.05))
		cs.shape = bx
		cs.position = caja.get_center()
		rb.add_child(cs)
		rb.mass = 0.3
		jugador.get_parent().add_child(rb)
		rb.global_transform = mag.global_transform
		rb.linear_velocity = Vector3(0, -6, 0) + jugador.vel_real
		rb.get_tree().create_timer(12.0).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())
	elif ev == "new":
		if hand_mag:
			hand_mag.queue_free()
		var m2 := mag.duplicate() as Node3D
		m2.visible = true
		(P.LeftHand as Node3D).add_child(m2)
		# que el centro del cargador quede en la palma
		var c2 := _caja_de(mag).get_center()
		m2.transform = Transform3D(mag.transform.basis, Vector3(0, -0.3, 0) - mag.transform.basis * c2)
		hand_mag = m2
	elif ev == "insert":
		if hand_mag:
			hand_mag.queue_free()
			hand_mag = null
		mag.visible = true


## caja que envuelve las mallas de un grupo (en el espacio del grupo)
static func _caja_de(n: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var bb: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb()
			if primera:
				caja = bb
				primera = false
			else:
				caja = caja.merge(bb)
	return caja


## ---------------------------------------------------------------- actualización por fotograma
func _process(dt: float) -> void:
	if rig == null or feet.is_empty():
		return
	dt = minf(dt, 0.1)
	update_rig(dt)
	rig.aplicar()


func update_rig(dt: float) -> void:
	var J := jugador
	var L: Dictionary = J.L
	if J.health <= 0 or L.knocked:
		return
	var now := ahora()
	var root_cf := J.root_cf()
	var yaw := Rbx.yaw_of(root_cf)
	var yaw_cf := Rbx.ang(0, yaw, 0)
	var vel := J.vel_real
	var lv := Rbx.vec_to_obj(root_cf, vel)
	var speed := Vector3(vel.x, 0, vel.z).length()
	# EN LA MOTO (L.moto, ver Jugador._estado_moto): el cuerpo va sentado; la velocidad es de la moto,
	# no de las piernas (nada de pasos, carrera ni balanceos de andar)
	var mt = L.get("moto")
	if mt != null:
		speed = 0.0
	acc = acc.lerp((lv - prev_lv) / maxf(dt, 1e-3), minf(1, dt * 6))
	prev_lv = lv
	var dyaw := Rbx.wrap_a(yaw - prev_yaw)
	prev_yaw = yaw
	yaw_rate = Rbx.damp(yaw_rate, dyaw / maxf(dt, 1e-3), 8, dt)
	if J.estado == "Freefall":
		fall_max = maxf(fall_max, -vel.y)
	var grounded := J.en_suelo
	# el sensor da "suelo" un instante después de despegar y antes de tocar el suelo:
	# se confirma con la altura real sobre el suelo
	if grounded:
		var gy_r: float = ground(root_cf.origin)[0]
		if root_cf.origin.y - gy_r > J.hip_height + J.root_size.y / 2 + 0.7:
			grounded = false
	# (2026-11-03) bajando escaleras (o pasando un hueco pequeño) el cuerpo "cae" un instante de escalón en escalón: no
	# es un salto, la marcha sigue (antes las piernas se recogían y el ciclo volvía a empezar). Un salto o una caída
	# de verdad (más de 0,3 s, o deprisa) sí cuentan
	if grounded:
		aire_corto_t = 0.0
	elif J.estado != "Jumping" and anim_w > 0.0 and va_sin_pie_aire() and vel.y > -9.0 and aire_corto_t < 0.3:
		aire_corto_t += dt
		grounded = true
	else:
		aire_corto_t = 9.0
	if mt != null:
		grounded = false

	var pitch: float = L.pitch
	var aiming: bool = L.aiming
	_entrada_apuntar = minf(_entrada_apuntar + dt, 0.45) if aiming else 0.0
	var exhausted: bool = L.exhausted and speed < 1.5
	var sprinting: bool = speed > C.PLAYER.WalkSpeed + 2.5
	heat = clampf(heat + (dt * 0.12 if sprinting else -dt * 0.08), 0, 1)
	var exertion := clampf(1.0 - L.stamina + (0.4 if L.exhausted else 0.0), 0, 1.3)
	# cansancio (de pie y andando se encorva; corriendo o tumbado no igual)
	fat = float(L.get("fatigue", 0.0))
	# fuerza de los pasos: andar ~0.45, correr 1; agachado mucho más sigiloso
	step_k = clampf(speed / C.PLAYER.SprintSpeed, 0.15, 1.1) * (1 - 0.6 * crouch_b)
	var hp_frac := J.health / maxf(1, J.max_health)
	var speed_f := clampf(speed / C.PLAYER.SprintSpeed, 0, 1.2)
	# postura: 0 de pie, 1 agachado, 2 cuerpo a tierra (con mezcla suave entre ellas)
	var stance: int = L.stance
	prone = L.proneP
	# LEVANTARSE tras un ragdoll: parte de la postura del suelo. Boca abajo: manos al suelo, una rodilla
	# debajo y de pie (las fases de cuerpo a tierra al revés). Boca arriba: antes rueda hasta quedar boca abajo
	var gu_rueda := -1.0
	if levantarse != null:
		var gt: float = (now - float(levantarse.t0)) * float(levantarse.get("vel", 1.0))
		var rueda_d := 0.75 if levantarse.arriba else 0.0
		if gt < rueda_d + float(C.PLAYER.ProneTime):
			var gp := 1.0 if gt < rueda_d else 1.0 - (gt - rueda_d) / float(C.PLAYER.ProneTime)
			prone = maxf(prone, gp)
			gu_rueda = (1.0 - gt / rueda_d) if (rueda_d > 0.0 and gt < rueda_d) else 0.0
		else:
			levantarse = null
	crouch_b = Rbx.damp(crouch_b, 1.0 if stance == 1 else 0.0, 4, dt)
	var pb := prone
	# ladeo (asomarse): -1 izquierda, 1 derecha
	var lean_in: float = L.lean
	if pb > 0.1:
		lean_in = 0
	lean_s = Rbx.damp(lean_s, lean_in, 10, dt)
	var ln := lean_s
	# sortear obstáculos
	var va = null
	if L.vault != null:
		var lvt: Dictionary = L.vault
		va = {"kind": lvt.kind, "p": clampf((now - lvt.t0) / lvt.dur, 0, 1), "edge": lvt.edge, "dir": lvt.dir, "topY": lvt.topY, "landY": lvt.landY, "feetY": lvt.feetY}
	if pb > 0.1:
		va = null
	# colgado de una cornisa
	var hg = L.get("hang")
	if hg != null:
		was_hang = true
		grounded = false
	elif was_hang:
		was_hang = false
		replant = true
	if va != null:
		va.right = (va.dir as Vector3).cross(Vector3.UP)
		# (curvas de Blender, Movimientos.SORTEAR: empiezan y acaban sin tirones)
		va.sv = Movimientos.sortear("valla_giro", va.p)
		va.pull = Movimientos.sortear("trepar_tira", va.p)
		was_vault = true
	elif was_vault:
		was_vault = false
		replant = true
		replant_paso = true
	# preparación del salto parado (se agacha una décima antes de impulsarse)
	var prep_k := 0.0
	# recoger algo del suelo: p = progreso (0..1), sq = cuánto se agacha
	var rec = J.arsenal.recogiendo
	var rec_p := -1.0
	var rec_sq := 0.0
	if rec != null:
		rec_p = clampf((now - float(rec.t0)) / float(rec.dur), 0.0, 1.0)
		rec_sq = Rbx.smooth(rec_p / 0.38) * (1.0 - Rbx.smooth((rec_p - 0.52) / 0.4))
	# golpe cuerpo a cuerpo en curso: giro de hombros, inclinación y acometida del cuerpo
	var mel_twist := 0.0
	var mel_lean := 0.0
	var mel_lunge := 0.0
	var mel_t := -1.0
	var mel_keys := {}
	if melee_st != null and now - float(melee_st.start) < float(melee_st.dur) and J.arsenal.equipado == melee_st.w:
		mel_keys = Armas.golpe(melee_st.w)
		mel_t = (now - float(melee_st.start)) * (float(mel_keys.dur) / float(melee_st.dur))
		mel_twist = Rbx.sample(mel_keys.twist, mel_t)
		mel_lean = Rbx.sample(mel_keys.lean, mel_t)
		mel_lunge = Rbx.sample(mel_keys.lunge, mel_t)
	_paso_cc(now, dt)
	if L.jumpPrep != null and grounded:
		var k: float = (now - L.jumpPrep) / 0.11
		if k >= 0 and k < 1.5:
			prep_k = Rbx.smooth(clampf(k, 0, 1))
	# al pivotar tumbado (girar sobre los codos) las piernas se arrastran igual que al reptar
	var pivoting := pb > 0.98 and absf(yaw_rate) > 0.35
	var crawling := pb > 0.98 and (speed > 0.25 or pivoting)

	## ------------------------------------------------ pelvis y piernas
	var crouch := 0.02 # rodillas apenas desbloqueadas (más bajo = piernas más rectas)
	var pelvis_pitch := 0.0
	var pelvis_yaw := 0.0
	var pelvis_roll := 0.0
	var bob := 0.0
	# ciclo de la marcha (Blender): desplazamiento y giro de la pelvis que se suman a los demás
	var cic_x := 0.0
	var cic_z := 0.0
	var cic_p := 0.0
	var cic_y := 0.0
	var cic_r := 0.0
	var ph01 := gait_ph / TAU
	var waistP := 0.0
	var waistY := 0.0
	var waistR := 0.0
	var neckP := 0.0
	var neckY := 0.0
	var neckR := 0.0
	breath_t += dt * (1.5 + exertion * 3)
	var breath := sin(breath_t) * (0.012 + exertion * 0.045)
	var leg_targets := {}
	var pelvis_cf: Transform3D
	var Mr: RigPersonaje.Motor = M.Root

	if mt != null:
		## -------- EN LA MOTO: sentado, el torso inclinado hacia el manillar, los pies en los estribos.
		## Parado, el pie izquierdo baja al suelo; deprisa, se agacha sobre el depósito; en las curvas se
		## mete un poco más que la moto con la cabeza recta; en el aire se levanta sobre los estribos.
		var cpo: Transform3D = mt.cuerpo
		var v_m: float = mt.vel
		var tuck := clampf((absf(v_m) - 25.0) / 40.0, 0.0, 1.0)
		var k_sub: float = mt.subir
		pie_moto = Rbx.damp(pie_moto, 1.0 if (mt.parada and k_sub >= 1.0) else 0.0, 5.0, dt)
		moto_de_pie = Rbx.damp(moto_de_pie, 0.35 if mt.aire else 0.0, 6.0, dt)
		var incl_m: float = mt.incl
		Mr.transform = Rbx.cf(0, moto_de_pie, 0.05) * Rbx.ang(-0.16 - 0.08 * tuck, 0, incl_m * 0.18 - pie_moto * 0.06)
		smooth_j(Mr, "Root", 12, dt)
		pelvis_cf = fk(root_cf, Mr)
		var acel_m: float = mt.acel
		waistP -= 0.42 + 0.3 * tuck - clampf(acel_m * 0.006, -0.15, 0.12) - moto_de_pie * 0.4
		neckP += 0.36 + 0.3 * tuck
		waistR -= incl_m * 0.12
		neckR -= incl_m * 0.5
		neckY += float(mt.direccion) * 0.7
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			var t_m: Vector3 = (mt["estribo" + s] as Vector3) + cpo.basis.y * 0.2
			if s == "L" and pie_moto > 0.01:
				t_m = t_m.lerp((mt.pie_suelo as Vector3) + Vector3(0, 0.32, 0), Rbx.smooth(pie_moto))
			if k_sub < 1.0:
				# al subir: la pierna derecha pasa por encima del asiento; la izquierda viene del suelo
				var arco := sin(PI * clampf(k_sub / 0.85, 0.0, 1.0))
				if s == "R":
					t_m += cpo.basis.y * (arco * 1.7) + cpo.basis.z * (arco * 1.1) + cpo.basis.x * (arco * 0.4)
				else:
					t_m = t_m.lerp((mt.pie_suelo as Vector3) + Vector3(0, 0.32, 0), 1.0 - Rbx.smooth(k_sub))
			leg_targets[s] = t_m
			leg_targets["pole" + s] = (pelvis_cf * Rbx.cf(sgn * (hip_x + 0.9), 0.4, -5.0)).origin
		pelvis_drop = 0.0
		replant = true
	elif pb > 0.001:
		## -------- CUERPO A TIERRA, por fases (como una persona real):
		##  0.00-0.40  se agacha y apoya una rodilla en el suelo
		##  0.30-0.70  se inclina hacia delante y pone las manos en el suelo
		##  0.55-1.00  estira las piernas hacia atrás y se tumba boca abajo
		var lean := Rbx.smooth(clampf((pb - 0.2) / 0.5, 0, 1))
		var lay := Rbx.smooth(clampf((pb - 0.45) / 0.55, 0, 1))
		var gy: float = ground(root_cf.origin)[0]
		var pelvis_stand_y := root_cf.origin.y - 0.08
		var drop := (pelvis_stand_y - (gy + 0.4)) * lay
		# reptar estilo militar: brazo izquierdo adelante con la rodilla derecha y viceversa
		var crawl_prev := crawl
		crawl += (speed * 1.9 + absf(yaw_rate) * 1.6) * dt
		# cada brazada (media fase) hace un poco de ruido; con Shift (reptar rápido) más
		if crawling and floori(crawl / PI) != floori(crawl_prev / PI):
			var r_rep: float = C.RUIDO.ReptarRapido if L.sprinting else C.RUIDO.Reptar
			Ruido.emitir(jugador, root_cf.origin, r_rep, Ruido.REPTAR, jugador)
		# al pivotar, la pelvis se desplaza hacia fuera del giro
		var sweep := clampf(-yaw_rate * 0.18, -0.25, 0.25) * pb
		var ph := crawl
		crawl_amt = Rbx.damp(crawl_amt, 1.0 if crawling else 0.0, 3, dt)
		# LEVANTARSE (2026-11-02, Movimientos.LEVANTAR): boca abajo, con su propia secuencia (flexión, a cuatro patas,
		# un pie adelante, de pie); boca arriba, sentándose y levantándose hacia los pies (el Jugador giró el cuerpo
		# 180° y lo avanzó hasta los pies: aquí la cadera se queda donde estaba y no se ve el giro)
		var subiendo: bool = (stance != 2 and pb < 0.999) or (stance != 2 and L.get("levanta_arriba") != null) or (levantarse != null and gu_rueda <= 0.0)
		var lev_up = L.get("levanta_arriba") if stance != 2 else null
		var q_up := 1.0 - pb
		if lev_up != null and not (lev_up as Dictionary).has("visto"):
			lev_up["visto"] = true
			prev_t.erase("Root")
			roll_t = 0.0
		# boca arriba: rodar sobre el eje de la columna (0 = boca abajo, 1 = boca arriba)
		var sup: bool = L.supine
		if pb < 0.98 or lev_up != null:
			sup = false
		roll_t = roll_t + clampf((1.0 if sup else 0.0) - roll_t, -dt / 0.75, dt / 0.75)
		if gu_rueda >= 0.0:
			roll_t = gu_rueda
		var rlv := Rbx.smooth(roll_t)
		if roll_t <= 0.001 or roll_t >= 0.999:
			roll_side = L.rollSide
		var side := roll_side
		var ay0: float = L.yaw
		var over_head := absf(Rbx.wrap_a(ay0 - yaw)) < PI / 2
		var ca := crawl_amt * (1 - rlv)
		var roll := sin(ph) * 0.13 * ca + sin(now * 0.7) * 0.012
		var sway := sin(ph) * 0.09 * ca
		# pelvis: de inclinada a horizontal y bajando hasta el suelo (curvas de Blender, Movimientos.TUMBAR)
		var tilt := Movimientos.tumbar("inclina", pb)
		drop = (pelvis_stand_y - (gy + 0.4)) * Movimientos.tumbar("baja", pb)
		var zoff := 0.0
		if lev_up != null:
			tilt = Movimientos.levantar("arriba_inclina", q_up)
			drop = (pelvis_stand_y - (gy + 0.4)) * Movimientos.levantar("arriba_baja", q_up)
			zoff = float(lev_up.desp) * Movimientos.levantar("arriba_z", q_up)
		elif subiendo:
			tilt = Movimientos.levantar("abajo_inclina", pb)
			drop = (pelvis_stand_y - (gy + 0.4)) * Movimientos.levantar("abajo_baja", pb)
		# al rodar, a mitad del giro el cuerpo queda de costado (el centro sube un poco)
		var lift := sin(PI * rlv) * 0.3
		# MOVERSE BOCA ARRIBA (2026-11-03, diseño de Blender: Movimientos.BOCA_ARRIBA): pasito de lado con cada pie,
		# puente con la cadera que se lleva de lado y luego arrastra los hombros. El cuerpo (el Jugador) avanza
		# continuo; aquí la cadera, los pies y los hombros van a tirones respecto a él, cada uno en su momento
		var yaw_p0 := Rbx.cfp(root_cf.origin) * yaw_cf
		var sup_k := Rbx.smooth(clampf((rlv - 0.85) / 0.15, 0.0, 1.0)) if (lev_up == null and pb > 0.98 and not subiendo) else 0.0
		var vloc := Rbx.vec_to_obj(yaw_p0, Vector3(vel.x, 0.0, vel.z))
		var vs := Vector2(vloc.x, vloc.z).length()
		var mov_sup := sup_k > 0.0 and vs > 0.08
		sup_amt = Rbx.damp(sup_amt, 1.0 if mov_sup else 0.0, 4.0 if mov_sup else 2.5, dt)
		if mov_sup:
			var dn := Vector2(vloc.x, vloc.z) / vs
			sup_dir = sup_dir.lerp(dn, minf(1.0, dt * 8.0)).normalized() if sup_amt > 0.05 else dn
			sup_ph = fposmod(sup_ph + vs * dt / Movimientos.BOCA_ARRIBA_PASO, 1.0)
		sup_mov_k = sup_amt * sup_k
		var sup_off := Vector3.ZERO
		var sup_rel_g := 0.0
		if sup_mov_k > 0.001:
			if is_nan(_sup_c):
				var acc_c := 0.0
				for i in 64:
					var x := (i + 0.5) / 64.0
					acc_c += x - Movimientos.boca_arriba("cadera", x)
				_sup_c = acc_c / 64.0
			sup_rel_g = Movimientos.BOCA_ARRIBA_PASO * (Movimientos.boca_arriba("cadera", sup_ph) - sup_ph + _sup_c)
			var puente := maxf(0.0, Movimientos.boca_arriba("cadera_sube", sup_ph))
			sup_off = (Vector3(sup_dir.x, 0.0, sup_dir.y) * sup_rel_g + Vector3(0, puente, 0)) * sup_mov_k
			# los hombros se quedan atrás mientras la cadera avanza y luego se arrastran (la espalda se curva de lado)
			var rel_h := Movimientos.BOCA_ARRIBA_PASO * (Movimientos.boca_arriba("hombros", sup_ph) - Movimientos.boca_arriba("cadera", sup_ph))
			waistR += SUP_CURVA * asin(clampf(rel_h * sup_dir.x * sup_mov_k / 1.9, -0.6, 0.6))
			neckP -= 0.35 * maxf(0.0, Movimientos.boca_arriba("hombros_sube", sup_ph)) * sup_mov_k
		Mr.transform = Rbx.cf(sup_off.x, -drop + lift + sup_off.y, zoff + sup_off.z) * Rbx.ang(tilt, sway * lay + sweep * (1 - rlv), roll * lay) * Rbx.ang(0, PI * rlv * side, 0)
		smooth_j(Mr, "Root", 9 if lev_up == null else 30, dt)
		waistY -= sweep * 1.3 # el pecho se queda apuntando mientras la cadera barre
		pelvis_cf = fk(root_cf, Mr)
		# PIERNAS (2026-11-02, diseño de Blender: Movimientos.TUMBAR y REPTAR): por IK a sitios del suelo, así los pies
		# y las rodillas no se meten en el suelo ni flotan. Pie plantado donde estaba -> arrodillado (la rodilla al suelo
		# bajo la cadera, o detrás si la cadera ya está baja; la espinilla hacia atrás; la punta del pie en el suelo: de
		# puntillas y, tumbado, con el empeine). Reptando, la rodilla sube por el costado a ras de suelo.
		# Boca arriba (y al rodar), como antes: rodillas arriba y pies apoyados.
		var yaw_p := Rbx.cfp(root_cf.origin) * yaw_cf
		var atras := -Rbx.look(yaw_p)
		var dcha := Rbx.right(yaw_p)
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			var Lg: Limb = leg[s]
			var f: Dictionary = feet[s]
			var hip_s := (pelvis_cf * Lg.top.c0).origin
			var gy_s: float = ground(Vector3(hip_s.x, root_cf.origin.y, hip_s.z) + atras * 1.2)[0]
			# 1) plantado (al levantarse, debajo del cuerpo: el pie derecho un poco adelantado, es el primero que se apoya)
			var fc_pl := foot_cf(f, yaw)
			if subiendo:
				var pp := (yaw_p * Rbx.cf(sgn * hip_x, 0, -0.18 - (0.45 if s == "R" else 0.0) * (1.0 - Rbx.smooth(clampf(q_up / 0.85, 0, 1))))).origin
				var gq: float = ground(pp)[0]
				fc_pl = Transform3D(Basis(Vector3.UP, yaw + sgn * -0.1), Vector3(pp.x, gq + foot_half, pp.z))
			var an_pl := (fc_pl * Rbx.cfp(ankle_in_foot[s])).origin
			# 2) arrodillado / tumbado
			# giro del pie: de puntillas (arrodillado) -> con el empeine en el suelo (tumbado); el tobillo a la altura
			# justa para que la esquina más baja del pie toque el suelo
			var th := lerpf(-1.75, -2.45, lay) if lev_up == null else 1.25   # (boca arriba: punta arriba, el talón en el suelo)
			var h_a := 0.0
			for cz in [-0.5, 0.5]:
				for cy in [-0.15, 0.15]:
					h_a = maxf(h_a, -(Basis(Vector3.RIGHT, th) * (Vector3(0, cy, cz) - (ankle_in_foot[s] as Vector3))).y)
			var knee_y := gy_s + 0.36
			var dzk := sqrt(maxf(0.0, 1.69 - pow(hip_s.y - knee_y, 2)))
			var knee_p := Vector3(hip_s.x, knee_y, hip_s.z) + atras * dzk + dcha * (sgn * 0.08)
			var dza := sqrt(maxf(0.0, 1.5625 - pow(h_a - 0.36, 2)))
			var an_k := knee_p + atras * dza + Vector3(0, h_a - 0.36, 0)
			var pole_s := hip_s - atras * 4.0 + Vector3(0, -2.0, 0)
			# reptando: la rodilla sube por el costado (el pie se acerca y sale hacia fuera)
			var up_r := Movimientos.reptar("rodilla_sube", ph / TAU + (0.5 if s == "L" else 0.0)) * ca
			if up_r > 0.001:
				var base_c := Vector3(hip_s.x, gy_s + h_a, hip_s.z)
				var an_c := base_c + dcha * (sgn * lerpf(0.25, 0.75, up_r)) + atras * lerpf(2.4, 1.6, up_r)
				an_k = an_k.lerp(an_c, minf(1.0, up_r * 3.0))
				pole_s = pole_s.lerp(hip_s + dcha * (sgn * 3.0) + atras * 0.8 + Vector3(0, 1.6, 0), up_r)
			var kk := Movimientos.tumbar(s + "_rodilla", pb)
			if subiendo:
				kk = Movimientos.levantar("abajo_" + s + "_rodilla", pb)
			if lev_up != null:
				# boca arriba: de las piernas estiradas hacia delante (talón en el suelo) a los pies metidos bajo el cuerpo
				var w_p := Movimientos.levantar("arriba_pies", q_up)
				var hip_g := Vector3(hip_s.x, gy_s, hip_s.z)
				an_k = hip_g - atras * 2.35 + Vector3(0, 0.42, 0)
				kk = 1.0 - w_p
				pole_s = hip_s + Vector3(0, 3.0, 0) - atras * 3.0
			var an := an_pl.lerp(an_k, kk) + Vector3(0, sin(PI * kk) * (0.6 if lev_up == null else 0.35), 0)
			# el pie: plano (plantado) -> de puntillas / con el empeine en el suelo
			var fb_k := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, th)
			var q_pie := Quaternion(fc_pl.basis.orthonormalized()).slerp(Quaternion(fb_k.orthonormalized()), kk)
			var F := Transform3D(Basis(q_pie), an) * Rbx.cfp(-(ankle_in_foot[s] as Vector3))
			var res_p := solve(Lg, pelvis_cf, an, pole_s)
			set_end(Lg, res_p[1], F)
			if rlv > 0.001:
				# boca arriba: rodillas flexionadas hacia arriba y pies apoyados
				var hip_up := Rbx.ang(0.55 + (0.15 if s == "L" else 0.0), 0, sgn * 0.18)
				Lg.top.transform = Lg.top.transform.interpolate_with(hip_up, rlv)
				Lg.mid.transform = Lg.mid.transform.interpolate_with(Rbx.ang(-1.1, 0, 0), rlv)
				Lg.fin.transform = Lg.fin.transform.interpolate_with(Rbx.ang(0.45, 0, 0), rlv)
			if sup_mov_k > 0.001:
				# moviéndose boca arriba: cada pie da su pasito (Movimientos.BOCA_ARRIBA) desde donde lo deja la pose de
				# tumbado, plantado en el suelo el resto del ciclo; las piernas por IK con las rodillas arriba
				var fk_t: Array = [Lg.top.transform, Lg.mid.transform, Lg.fin.transform]
				var up_cf := fk(pelvis_cf, Lg.top)
				var lo_cf := fk(up_cf, Lg.mid)
				var pie_fk := fk(lo_cf, Lg.fin)
				var off_w := yaw_p0.basis * sup_off
				var base_a := (lo_cf * Lg.fin.c0).origin - off_w
				var d_w := yaw_p0.basis * Vector3(sup_dir.x, 0.0, sup_dir.y)
				# el pie del lado hacia donde va da el primer paso
				var lado_pie := (hip_s - root_cf.origin).dot(Rbx.right(yaw_p0))
				var prim := "pie_a" if (signf(lado_pie) == signf(sup_dir.x) or absf(sup_dir.x) < 0.3 and s == "R") else "pie_b"
				var rel_p := Movimientos.BOCA_ARRIBA_PASO * (Movimientos.boca_arriba(prim, sup_ph) - sup_ph + _sup_c)
				var g_p: float = ground(base_a)[0]
				var obj := Vector3(base_a.x, g_p + 0.3, base_a.z) + d_w * rel_p + Vector3(0, maxf(0.0, Movimientos.boca_arriba(prim + "_sube", sup_ph)), 0)
				var F2 := Transform3D(pie_fk.basis.orthonormalized(), obj) * Rbx.cfp(-(ankle_in_foot[s] as Vector3))
				var res_s := solve(Lg, pelvis_cf, obj, hip_s + Vector3(0, 3.0, 0) + atras * 2.0)
				set_end(Lg, res_s[1], F2)
				Lg.top.transform = (fk_t[0] as Transform3D).interpolate_with(Lg.top.transform, sup_mov_k)
				Lg.mid.transform = (fk_t[1] as Transform3D).interpolate_with(Lg.mid.transform, sup_mov_k)
				Lg.fin.transform = (fk_t[2] as Transform3D).interpolate_with(Lg.fin.transform, sup_mov_k)
		# (sin suavizar: van por IK a sitios fijos del suelo; suavizadas se quedaban atrás y se metían en el suelo)
		for s in ["L", "R"]:
			var Lg3: Limb = leg[s]
			for pair in [[Lg3.top, "Hip"], [Lg3.mid, "Knee"], [Lg3.fin, "Ankle"]]:
				if rlv > 0.001:
					smooth_j(pair[0], s + pair[1], 14, dt)
				else:
					anota_j(pair[0], s + pair[1], dt)
		waistR += roll * 0.5 * lay
		waistY -= sway * 1.2 * lay
		# boca abajo: cabeza levantada. Boca arriba: barbilla al pecho para apuntar por encima de los pies,
		# o cabeza echada atrás si apunta por encima de la cabeza
		var sup_neck := -0.8
		var sup_waist := -0.35
		if over_head:
			sup_neck = 0.55
			sup_waist = 0.15
		if lev_up != null:
			waistP += Movimientos.levantar("arriba_cintura_p", q_up)
			neckP += Movimientos.levantar("arriba_cuello_p", q_up)
		elif subiendo:
			waistP += Movimientos.levantar("abajo_cintura_p", pb)
			neckP += Movimientos.levantar("abajo_cuello_p", pb)
		else:
			waistP += Movimientos.tumbar("cintura_p", pb) * (1 - rlv) + sup_waist * rlv * lay
			neckP += Movimientos.tumbar("cuello_p", pb) * (1 - rlv) + sup_neck * rlv * lay
		# a mitad del giro la cabeza se mantiene mirando hacia la mira
		neckY -= sin(PI * rlv) * 0.6 * side
		rl = rlv
		pelvis_drop = 0
		replant = true
		last_prone_t = now
	else:
		update_feet(root_cf, vel, speed, dt, grounded)
		_fase_marcha(speed, dt)
		clamp_planted(root_cf)
		# inercia: inclinarse al acelerar/frenar y hacia dentro en las curvas
		var fwd_speed := -lv.z
		var fwd_acc := -acc.z
		if grounded:
			# (2026-11-03: menos que antes; al arrancar el torso se adelantaba a las piernas)
			S.leanP.target = clampf(-(fwd_speed * 0.008) - fwd_acc * 0.0025, -0.24, 0.1)
			S.leanR.target = clampf(yaw_rate * speed * 0.004, -0.25, 0.25)
		else:
			S.leanP.target = -0.08
			S.leanR.target = 0.0
		var leanP: float = S.leanP.step(dt)
		var leanR: float = S.leanR.step(dt)
		# postura: tensión al apuntar, agotamiento, levantarse
		# (en guardia / bloqueando, la altura la pone la pose de Blender, CombateCC)
		var ct := 0.22 * (1.0 - maxf(cc_guard_w, cc_block_w)) * (1.0 - smoothstep(0.1, 1.5, speed)) if aiming else 0.0
		if exhausted:
			ct = 0.45
			waistP -= 0.6
			neckP += 0.4
		elif fat > 0.02 and stance == 0 and speed >= 1.5:
			# andar con fatiga: encorvado, rodillas algo dobladas, la cabeza cae y se levanta con
			# la respiración, el cuerpo se balancea de lado a lado con cada paso pesado
			var fk2 := fat * (1.0 - clampf((speed - 7.0) / 4.0, 0, 1))
			ct = maxf(ct, 0.12 * fk2)
			waistP -= 0.3 * fk2
			neckP += 0.16 * fk2 + 0.07 * fk2 * sin(breath_t)
			waistR += 0.05 * fk2 * sin(gait_ph)
			pelvis_roll += 0.05 * fk2 * sin(gait_ph)
		if get_up != null:
			var g: float = (now - get_up) / 0.9
			if g < 1:
				ct = maxf(ct, (1 - g) * 1.2)
				waistP -= (1 - g) * 0.8
			else:
				get_up = null
		S.crouch.target = ct
		crouch += S.crouch.step(dt)
		# agachado: la altura la baja el cuerpo (HipHeight) y la IK dobla las rodillas;
		# aquí se inclina el torso hacia delante y se mete la cabeza
		var cb := crouch_b
		waistP -= 0.3 * cb
		neckP += 0.24 * cb
		# corriendo agachado: el torso se echa más hacia delante (y la cabeza mira al frente)
		var crun := cb * clampf((speed - 4.5) / 3.5, 0, 1)
		waistP -= 0.28 * crun
		neckP += 0.22 * crun
		pelvis_pitch -= 0.12 * cb
		var land: float = S.land.step(dt)
		crouch += maxf(0, -land) * 0.12

		# MARCHA (ciclos hechos en Blender, Movimientos): la pelvis sube y baja, se desplaza sobre el pie de apoyo, gira
		# con la pierna que avanza y cae del lado de la pierna en el aire; los hombros giran al revés y la cabeza se
		# queda estable. Mezcla andar / correr / agachado según la velocidad; amplitud según lo deprisa que va
		mez_run = Rbx.damp(mez_run, clampf((speed - 7.0) / 6.0, 0, 1) * _factor_carrera_direccion(jugador.vel_real, jugador.root_cf()), 6.0, dt)
		var v_nom := lerpf(lerpf(6.5, 18.5, mez_run), 3.5, crouch_b)
		amp_ciclo = gait_amp * clampf(speed / v_nom, 0.45, 1.15) if grounded else Rbx.damp(amp_ciclo, 0.0, 8.0, dt)
		ph01 = gait_ph / TAU
		if amp_ciclo > 0.001 and va == null:
			var ac := amp_ciclo
			bob += _ciclo("raiz_y", ph01) * ac
			cic_x = _ciclo("raiz_x", ph01) * ac
			cic_z = _ciclo("raiz_z", ph01) * ac
			cic_p = _ciclo("pelvis_p", ph01) * ac
			cic_y = _ciclo("pelvis_y", ph01) * ac
			cic_r = _ciclo("pelvis_r", ph01) * ac
			waistP += _ciclo("cintura_p", ph01) * ac
			waistY += _ciclo("cintura_y", ph01) * ac
			waistR += _ciclo("cintura_r", ph01) * ac
			neckP += _ciclo("cuello_p", ph01) * ac
			neckY += _ciclo("cuello_y", ph01) * ac
			neckR += _ciclo("cuello_r", ph01) * ac
		# cojera con poca vida
		if hp_frac < 0.35 and speed > 1.5:
			var rf: Dictionary = feet.R
			if rf.swing == null:
				crouch += 0.12 # se hunde al apoyar la pierna herida
			waistR += -0.06 if rf.swing != null else 0.08
		# balanceo de peso en reposo
		if speed < 0.5:
			pelvis_roll += sin(now * 0.45 + breath_t * 0.1) * 0.025

		# de lado: rodillas algo dobladas (ver update_feet)
		crouch += 0.3 * lat_k
		# agachado bajo un techo bajo (túnel): se agacha un poco más para que la cabeza no lo atraviese
		var techo_t := 0.0
		if grounded and stance == 1 and va == null:
			var hd: Vector3 = (P.Head as Node3D).global_position
			var arriba := J.raycast(Vector3(hd.x, root_cf.origin.y, hd.z), Vector3(0, 4.0, 0))
			if not arriba.is_empty():
				techo_t = clampf(agache_techo + (hd.y + 0.56) - ((arriba.position as Vector3).y - 0.1), 0.0, 0.8)
		agache_techo = Rbx.damp(agache_techo, techo_t, 10.0, dt)
		crouch += agache_techo
		# arma apoyada: el cuerpo baja lo justo para que el arma quede encima del apoyo (ver _arma_sobre_apoyo)
		crouch += rest_baja
		# altura de pelvis: bajarla si algún pie no llega (zancadas largas, bordillos)
		var yaw_only := Rbx.cfp(root_cf.origin) * yaw_cf
		# cuánto hay que bajar la pelvis para que la pierna de apoyo llegue al pie (péndulo invertido:
		# la pierna de apoyo va casi recta y la cadera sube y baja con el paso, como al andar de verdad)
		var need := 0.0
		var hip_y: float = (Mr.c0 * Mr.c1inv * (M.RightHip as RigPersonaje.Motor).c0).origin.y
		for s in feet:
			var f: Dictionary = feet[s]
			if grounded:
				var hip0 := (yaw_only * Rbx.cf(f.side * hip_x, hip_y + bob - crouch, 0)).origin
				update_roll(f, s, hip0, yaw, yaw_only, dt)
			else:
				f.roll = 0.0
			var fc := foot_cf(f, yaw)
			var ankle := (fc * Rbx.cfp(ankle_in_foot[s])).origin
			leg_targets[s] = ankle
			# solo cuentan los pies que soportan el peso (y el que está a punto de apoyar)
			var fu: float = f.u if f.get("u") != null else 0.0
			if grounded and (f.swing == null or fu > 0.8):
				var hip := (yaw_only * Rbx.cf(f.side * hip_x, hip_y + bob - crouch, 0)).origin
				var reach := leg_len * 0.994
				var dh := Vector2(hip.x - ankle.x, hip.z - ankle.z).length()
				var dy := hip.y - ankle.y
				if dh * dh + dy * dy > reach * reach:
					need = maxf(need, dy - sqrt(maxf(reach * reach - dh * dh, 0.0)))
		# (muelle críticamente amortiguado: la cadera baja y sube sin tirones; antes la bajada era casi instantánea y
		# corriendo daba un golpe en cada apoyo)
		var obj_d := clampf(need, 0, 0.6)
		var w_d := 32.0 if obj_d > pelvis_drop else 11.0
		pelvis_drop_v += (w_d * w_d * (obj_d - pelvis_drop) - 2.0 * w_d * pelvis_drop_v) * dt
		pelvis_drop += pelvis_drop_v * dt
		if pelvis_drop < 0.0:
			pelvis_drop = 0.0
			pelvis_drop_v = maxf(pelvis_drop_v, 0.0)
		elif pelvis_drop > 0.6:
			pelvis_drop = 0.6
			pelvis_drop_v = minf(pelvis_drop_v, 0.0)
		# preparación del salto: flexiona las rodillas y adelanta el torso
		crouch += 0.38 * prep_k
		# recoger: flexiona rodillas y cadera, el torso se inclina sobre el objeto
		if rec_sq > 0.0:
			var alto_obj: float = (rec.pos as Vector3).y - (root_cf.origin.y - J.center_cur)
			var baja := clampf(1.45 - alto_obj * 0.5, 0.2, 1.45) * (0.45 if stance == 1 else 1.0)
			crouch += baja * rec_sq
			waistP -= 0.5 * rec_sq
			pelvis_pitch -= 0.12 * rec_sq
			neckP -= 0.15 * rec_sq
		waistP -= 0.22 * prep_k
		# levantar una moto tirada: se agacha con la espalda recta y sube empujando con las piernas
		var lev = L.get("levanta")
		if lev != null:
			var lk: float = lev.k
			var sq_l := Rbx.smooth(lk / 0.2) * (1.0 - 0.75 * Rbx.smooth((lk - 0.22) / 0.78))
			crouch += 1.3 * sq_l
			waistP -= 0.7 * sq_l + 0.12
			pelvis_pitch -= 0.18 * sq_l
			neckP += 0.35 * sq_l
		if not grounded and va == null:
			# SALTO por fases: despegue (la pierna de impulso aún estirada), vuelo (carrera: rodilla
			# delantera arriba y pierna trasera atrás; parado: las dos rodillas recogidas) y
			# caída (las piernas bajan y se adelantan para recibir el suelo)
			pelvis_drop = Rbx.damp(pelvis_drop, 0, 6, dt)
			pelvis_drop_v = 0.0
			if was_grounded != false:
				air_start = now
				jump_lead = "R" if feet.R.swing != null else ("L" if feet.L.swing != null else ("R" if randf() < 0.5 else "L"))
				jump_run = clampf((speed - 4) / 8, 0, 1)
				air_runoff = jugador.estado != "Jumping"
			var run := jump_run
			var fall := clampf((3 - vel.y) / 16, 0, 1)
			var ext := clampf((now - air_start) / 0.13, 0, 1)
			# poses del salto hechas en Blender (Movimientos.SALTOS), por la fase del salto: despegue -> subiendo con las
			# rodillas recogidas -> bajando -> recibiendo el suelo (parado y corriendo, mezclados según la carrera)
			air_tj = 0.3 * Rbx.smooth(ext) + 0.7 * fall
			var abre := lerpf(Movimientos.salto("parado", "abre", air_tj), Movimientos.salto("corriendo", "abre", air_tj), run)
			for s in feet:
				var f: Dictionary = feet[s]
				var is_lead: bool = s == jump_lead
				var k_p := "pa_" if is_lead else "pb_"
				var y := leg_len * lerpf(Movimientos.salto("parado", k_p + "y", air_tj), Movimientos.salto("corriendo", k_p + "y", air_tj), run)
				var z := lerpf(Movimientos.salto("parado", k_p + "z", air_tj), Movimientos.salto("corriendo", k_p + "z", air_tj), run)
				# (pose para recibir el suelo: la del final del salto)
				var dnY := leg_len * lerpf(Movimientos.salto("parado", k_p + "y", 1.0), Movimientos.salto("corriendo", k_p + "y", 1.0), run)
				var dnZ := lerpf(Movimientos.salto("parado", k_p + "z", 1.0), Movimientos.salto("corriendo", k_p + "z", 1.0), run)
				if air_runoff and run > 0.3:
					# salir corriendo de un borde: las piernas siguen la zancada (una delante y otra
					# detrás, alternando) en vez de juntarse; al caer mucho se preparan para aterrizar
					var fw: float = sin(gait_ph) * (1.0 if s == "L" else -1.0)
					var ry := -leg_len * 0.9 + 0.5 * maxf(0.0, fw) + 0.35 * maxf(0.0, -fw)
					var rz := -0.95 * fw
					var w_dn := clampf((fall - 0.55) / 0.45, 0, 1) * 0.6
					y = lerpf(ry, dnY, w_dn)
					z = lerpf(rz, dnZ, w_dn)
				# caída larga: pedalea en el aire
				if vel.y < -18:
					var ph2 := now * 9 + (PI if s == "L" else 0.0)
					y += sin(ph2) * 0.35
					z += cos(ph2) * 0.45
				leg_targets[s] = (yaw_only * Rbx.cf(f.side * hip_x * (abre if not (air_runoff and run > 0.3) else 1.0 + 0.35 * fall), y - 0.1, z)).origin
			var k_s := 0.0 if (air_runoff and run > 0.3) else 1.0
			pelvis_pitch += lerpf(Movimientos.salto("parado", "pelvis_p", air_tj), Movimientos.salto("corriendo", "pelvis_p", air_tj), run) * k_s
			waistP += lerpf(Movimientos.salto("parado", "cintura_p", air_tj), Movimientos.salto("corriendo", "cintura_p", air_tj), run) * k_s
			neckP += lerpf(Movimientos.salto("parado", "cuello_p", air_tj), Movimientos.salto("corriendo", "cuello_p", air_tj), run) * k_s
			if k_s < 1.0:
				pelvis_pitch += 0.1 * run * (1 - fall) - 0.06 * fall
				waistP += -0.14 * run * (1 - fall) - 0.1 * fall
				neckP += 0.1 * fall
			air_fall = fall
		was_grounded = grounded or va != null
		# pelvis al sortear: gira y se ladea (vault) o se inclina hacia la pared (encaramarse)
		if va != null:
			if va.kind == "vault":
				pelvis_yaw += 0.55 * va.sv
				pelvis_roll -= 0.35 * va.sv
				pelvis_pitch -= 0.1 * va.sv
				waistP -= 0.35 * va.sv
				waistR += 0.3 * va.sv
				neckP += 0.3 * va.sv
				neckY -= 0.4 * va.sv
			else:
				pelvis_pitch -= 0.35 * va.pull
				waistP -= 0.45 * va.pull
				neckP += 0.5 * va.pull
			pelvis_drop = Rbx.damp(pelvis_drop, 0, 8, dt)
			pelvis_drop_v = 0.0
		pelvis_pitch += leanP * 0.35
		# ladeo: la cadera compensa hacia el lado contrario, el torso se inclina y la cabeza se
		# endereza un poco (como al asomarse por una esquina)
		pelvis_roll -= ln * 0.08
		waistR -= ln * 0.4
		neckR += ln * 0.24
		# acometida del golpe: la cadera avanza, baja un poco y gira con los hombros
		# combate cuerpo a cuerpo (CombateCC): la cadera baja en guardia, avanza al empujar y patear
		var ccp := cc_pose
		Mr.transform = Rbx.cf(-ln * 0.14 + cic_x + float(ccp.get("cad_x", 0.0)), -pelvis_drop + bob - crouch - absf(ln) * 0.06 - mel_lunge * 0.22 + float(ccp.get("cad_y", 0.0)),
			-mel_lunge * 0.35 + cic_z + float(ccp.get("cad_z", 0.0))) \
			* Rbx.ang(pelvis_pitch + cic_p + float(ccp.get("pel_p", 0.0)), pelvis_yaw + mel_twist * 0.35 + cic_y + float(ccp.get("pel_y", 0.0)), pelvis_roll + leanR * 0.3 + cic_r + float(ccp.get("pel_r", 0.0)))
		smooth_j(Mr, "Root", 16, dt)
		pelvis_cf = fk(root_cf, Mr)
		# con la pelvis ya colocada (con su inercia), el pie apoyado rueda lo justo para que la
		# pierna llegue casi recta desde la cadera real
		if grounded and va == null:
			for s in feet:
				var f: Dictionary = feet[s]
				if f.swing == null:
					var hm: RigPersonaje.Motor = M.LeftHip if s == "L" else M.RightHip
					var hip_a := (pelvis_cf * hm.c0).origin
					update_roll(f, s, hip_a, yaw, yaw_only, dt)
					leg_targets[s] = (foot_cf(f, yaw) * Rbx.cfp(ankle_in_foot[s])).origin
					# solo cuenta un pie que se quedó ATRÁS (un pie que acaba de apoyar delante se alcanza
					# solo cuando el cuerpo pasa por encima; si no, se encadenan pasos forzados y la carrera
					# queda en un bucle de pasitos en el aire, sobre todo tras un giro brusco)
					var behind := Rbx.vec_to_obj(yaw_only, leg_targets[s] - hip_a).z > 0.3
					f.overreach = behind and (leg_targets[s] - hip_a).length() > leg_len * 1.02
				else:
					f.overreach = false
		waistP += leanP * 0.8
		waistR += leanR * 0.6
		waistY -= pelvis_yaw * 1.25 # contrarrotación de hombros
		neckP -= (leanP * 0.8 + pelvis_pitch) * 0.7
		# rodillas hacia delante: el punto de referencia está lejos delante y a la altura de la cadera,
		# así la rodilla no puede darse la vuelta aunque el pie suba mucho (cuestas, carrera)
		leg_targets.poleL = (pelvis_cf * Rbx.cf(-hip_x, 0.5, -6)).origin
		leg_targets.poleR = (pelvis_cf * Rbx.cf(hip_x, 0.5, -6)).origin
		# piernas al sortear
		if va != null:
			var d: Vector3 = va.dir
			var rv: Vector3 = va.right
			var p: float = va.p
			var hip_p := pelvis_cf.origin
			var Y := Vector3.UP
			if va.kind == "vault":
				# las piernas se recogen hacia un lado y pasan por encima; al final bajan para aterrizar
				var wT := Movimientos.sortear("valla_recoge", p)
				var wL := Movimientos.sortear("valla_aterriza", p)
				var tuck := {
					"R": hip_p + rv * 0.95 + d * 0.55 - Y * (leg_len * 0.42),
					"L": hip_p + rv * 0.5 + d * 0.2 - Y * (leg_len * 0.6),
				}
				for s in ["L", "R"]:
					var t: Vector3 = tuck[s]
					if p > 0.25 and p < 0.72:
						t = Vector3(t.x, maxf(t.y, va.topY + 0.3), t.z)
					var sgn := -1.0 if s == "L" else 1.0
					var land_p := hip_p + rv * (sgn * hip_x) + d * (0.35 if s == "R" else -0.1)
					land_p = Vector3(land_p.x, maxf(va.landY + 0.35, hip_p.y - leg_len * 0.97), land_p.z)
					var base: Vector3 = leg_targets.get(s, land_p)
					leg_targets[s] = base.lerp(t, wT).lerp(land_p, wL)
				leg_targets.poleL = hip_p + d * 3 + rv * 0.5 + Y * 0.5
				leg_targets.poleR = hip_p + d * 3 + rv * 1.5 + Y * 0.5
			else:
				# encaramarse: pies contra la pared (trepando), rodilla derecha arriba y luego la izquierda
				var face_p: Vector3 = va.edge - d * 0.3
				# los pies siguen en el suelo mientras las manos agarran el borde; solo cuando el cuerpo
				# empieza a subir, los pies pasan a apoyarse en la pared
				var wS := Movimientos.sortear("trepar_pared", p)
				for s in ["L", "R"]:
					var sgn := -1.0 if s == "L" else 1.0
					var scr := maxf(0, sin(p * 22 + (PI if s == "L" else 0.0))) * 0.45 * (1 - clampf((p - 0.4) / 0.2, 0, 1))
					var wall_f := Vector3(face_p.x, 0, face_p.z) + rv * (sgn * 0.4)
					var wy := minf(hip_p.y - leg_len * 0.78 + scr, va.topY - 0.2)
					wall_f = Vector3(wall_f.x, maxf(wy, va.feetY + 0.15), wall_f.z)
					var w_up := Movimientos.sortear("trepar_sube_" + s, p)
					var top_p: Vector3 = va.edge + d * (0.45 if s == "R" else 0.9) + rv * (sgn * hip_x)
					top_p = Vector3(top_p.x, va.topY + 0.35 + sin(PI * w_up) * 0.5, top_p.z)
					var base2: Vector3 = leg_targets.get(s, wall_f)
					leg_targets[s] = base2.lerp(wall_f, wS).lerp(top_p, w_up)
				leg_targets.poleL = hip_p + d * 3 - rv * hip_x + Y * 1.2
				leg_targets.poleR = hip_p + d * 3 + rv * hip_x + Y * 1.2

	# colgado: las piernas cuelgan, con las rodillas un poco dobladas y los pies tocando la pared;
	# al desplazarse de lado se balancean y los pies "caminan" por la pared
	if hg != null and pb < 0.1:
		var n_h: Vector3 = hg.n
		var r_h := (-n_h).cross(Vector3.UP).normalized()
		var hip_c := pelvis_cf.origin
		var mv_h: float = hg.mv
		var ph_h: float = hg.ph
		# (diseño de Blender, Movimientos.COLGADO: quieto se mece despacio y busca apoyo con una rodilla y luego la otra;
		# moviéndose, las piernas siguen a las manos con retraso y la cadera se balancea hacia donde va)
		var am := clampf(absf(mv_h), 0.0, 1.0)
		var dir_m := signf(mv_h) if absf(mv_h) > 0.01 else 1.0
		var fq := now / 2.8
		var fm := ph_h / TAU
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			var fq_s := fq + (0.0 if s == "R" else 0.37)
			var fm_s := fm + (0.0 if s == "R" else 0.5)
			var lado_h := lerpf(Movimientos.colgado("q_lado", fq_s), Movimientos.colgado("m_lado", fm_s) * dir_m, am)
			var alto_x := lerpf(Movimientos.colgado("q_alto", fq_s), Movimientos.colgado("m_alto", fm_s), am)
			var pared_h := lerpf(Movimientos.colgado("q_pared", fq_s), Movimientos.colgado("m_pared", fm_s), am)
			var lat_h := sgn * hip_x * 1.1 + lado_h + Movimientos.colgado("m_cadera_lado", fm) * dir_m * am
			leg_targets[s] = hip_c + r_h * lat_h - n_h * pared_h + Vector3(0, -leg_len * 0.84 + alto_x, 0)
		leg_targets.poleL = hip_c - n_h * 3.0 - r_h * hip_x + Vector3(0, 0.5, 0)
		leg_targets.poleR = hip_c - n_h * 3.0 + r_h * hip_x + Vector3(0, 0.5, 0)
		# torso: cuelga de los brazos (algo arqueado hacia la pared), respira con esfuerzo y se mece
		var resp_h := sin(now * 2.6) * 0.03
		var fq2 := now / 2.8
		waistP += Movimientos.colgado("q_cintura_p", fq2) + resp_h
		waistR += lerpf(Movimientos.colgado("q_cintura_r", fq2), Movimientos.colgado("m_cintura_r", hg.ph / TAU) * signf(mv_h + 1e-6), clampf(absf(mv_h), 0, 1)) - mv_h * 0.04
		waistY += Movimientos.colgado("q_cintura_y", fq2) * (1.0 - clampf(absf(mv_h), 0, 1))
		neckP += Movimientos.colgado("q_cuello_p", fq2) - resp_h
		neckY += Movimientos.colgado("q_cuello_y", fq2) * (1.0 - clampf(absf(mv_h), 0, 1)) + mv_h * 0.25 # mira hacia donde va


	# seguridad: si un pie apoyado quedó a la altura de la cadera (aterrizaje raro), se vuelve a apoyar
	if grounded and pb < 0.01 and va == null:
		for s in feet:
			var f: Dictionary = feet[s]
			if f.swing == null and Rbx.to_obj(root_cf, f.pos).y > -(J.hip_height + J.root_size.y / 2) * 0.3:
				replant = true
	# impactos
	var hitP: float = S.hitPitch.step(dt)
	var hitY: float = S.hitYaw.step(dt)
	var hitH: float = S.hitHead.step(dt)
	var flail: float = S.flail.step(dt)
	waistP += hitP * 0.16
	waistY += hitY * 0.18
	neckP += hitH * 0.14

	# PATADA (CombateCC): la pierna que patea va donde diga la animación (respecto a su cadera); la otra, en el suelo
	var kick_s := ""
	var kick_w := 0.0
	if cc_kick != null and grounded and va == null and pb < 0.01 and mt == null:
		kick_s = cc_kick.lado
		kick_w = cc_kick.w
		var Lk: Limb = leg[kick_s]
		var hip_k := (pelvis_cf * Lk.top.c0).origin
		var obj_k := hip_k + yaw_cf.basis * Vector3(cc_pose.pie_x, cc_pose.pie_y, cc_pose.pie_z)
		# (el pie va al blanco de verdad, p. ej. al cuerpo caído en el pisotón, y rebota al golpear: ImpactoCC)
		obj_k += jugador.arsenal.impacto.pie_offset(hip_k, yaw_cf.basis)
		var base_k: Vector3 = leg_targets.get(kick_s, obj_k)
		leg_targets[kick_s] = base_k.lerp(obj_k, kick_w)
		var pole_k := hip_k + yaw_cf.basis * Vector3(cc_pose.ro_x, cc_pose.ro_y, cc_pose.ro_z)
		var pk := "poleL" if kick_s == "L" else "poleR"
		leg_targets[pk] = (leg_targets[pk] as Vector3).lerp(pole_k, kick_w)
	# piernas por IK
	for s in ["L", "R"]:
		var Lg: Limb = leg[s]
		if leg_targets.has(s):
			var target: Vector3 = leg_targets[s]
			var pole: Vector3 = leg_targets.poleL if s == "L" else leg_targets.poleR
			var f: Dictionary = feet[s]
			# la pierna que da el paso nunca va estirada en el aire (sobre todo al correr, girar o ir
			# de lado): la rodilla se dobla y solo se estira al final para apoyar el talón
			if grounded and va == null and pb < 0.01 and f.swing != null and f.get("u") != null and s != kick_s:
				var hip_w := (pelvis_cf * Lg.top.c0).origin
				var lim := leg_len * lerpf(0.86, 0.99, Rbx.smooth((f.u - 0.6) / 0.4))
				var off := target - hip_w
				if off.length() > lim:
					target = hip_w + off.normalized() * lim
			var res := solve(Lg, pelvis_cf, target, pole)
			# la pierna en el aire no atraviesa muros ni mesas: si la rodilla, la espinilla o la
			# punta del pie chocan con una superficie vertical, el pie se retrasa hasta quedar fuera
			if grounded and va == null and pb < 0.01 and f.swing != null and s != kick_s:
				for _it in 2:
					var hip_c := (pelvis_cf * Lg.top.c0).origin
					var knee := ((res[0] as Transform3D) * Lg.mid.c0).origin
					var toe: Vector3 = target + Rbx.look(root_cf) * 0.8
					var hl := J.raycast(hip_c, knee - hip_c)
					if hl.is_empty():
						hl = J.raycast(knee, target - knee)
					if hl.is_empty():
						hl = J.raycast(target, toe - target)
					if hl.is_empty() or absf((hl.normal as Vector3).y) > 0.5:
						break
					var n: Vector3 = hl.normal
					var pen := 1.0 - (target - (hl.position as Vector3)).dot(n)
					target += Vector3(n.x, 0, n.z).normalized() * maxf(pen, 0.3)
					res = solve(Lg, pelvis_cf, target, pole)
			var lower: Transform3D = res[1]
			if mt != null:
				# en la moto: pie plano sobre el estribo (o el suelo), en la dirección de la moto
				set_end(Lg, lower, Transform3D((mt.cuerpo as Transform3D).basis, target) * Rbx.ang(0.15, 0, 0))
			elif not grounded:
				set_end(Lg, lower, Rbx.cfp(target) * yaw_cf * Rbx.ang(-0.3, 0, 0))
			elif s == kick_s and kick_w > 0.001:
				# el pie que patea: la planta por delante (pie_inc), mezclado con el pie apoyado
				var pie_k := Rbx.cfp(target) * yaw_cf * Rbx.ang(float(cc_pose.pie_inc) * kick_w, 0, 0) * Rbx.cfp(-ankle_in_foot[s])
				set_end(Lg, lower, foot_cf(f, yaw).interpolate_with(pie_k, kick_w))
			else:
				set_end(Lg, lower, foot_cf(f, yaw))
			# justo después de levantarse: mezclar desde la pose de tumbado (sin saltos);
			# el resto del tiempo solo se registra la pose para que el paso a tumbado parta de ella
			var recent := now - last_prone_t < 0.6
			for pair in [[Lg.top, "Hip"], [Lg.mid, "Knee"], [Lg.fin, "Ankle"]]:
				if recent:
					smooth_j(pair[0], s + pair[1], 12.0, dt)
				else:
					anota_j(pair[0], s + pair[1], dt)

	# combate cuerpo a cuerpo (CombateCC): giro e inclinación del tronco y la cabeza (antes del pecho: las manos y el
	# arma se colocan respecto al pecho ya girado, como en Blender)
	waistY += float(cc_pose.get("cin_y", 0.0))
	waistP += float(cc_pose.get("cin_p", 0.0))
	waistR += float(cc_pose.get("cin_r", 0.0))
	neckY += float(cc_pose.get("cue_y", 0.0))
	neckP += float(cc_pose.get("cue_p", 0.0))
	neckR += float(cc_pose.get("cue_r", 0.0))
	## ------------------------------------------------ torso provisional (para calcular el pecho)
	var Mw: RigPersonaje.Motor = M.Waist
	Mw.transform = Rbx.ang(0, waistY, 0) * Rbx.ang(waistP + breath, 0, waistR)
	var chest_cf := fk(pelvis_cf, Mw)
	var chest_yaw_base := Rbx.cfp(chest_cf.origin) * yaw_cf
	jugador.arsenal.impacto.marco(chest_yaw_base)
	# tumbado: el torso y la cabeza cubren la diferencia hasta que el cuerpo termina de pivotar
	var prone_aim := pb > 0.5
	# en la moto se apunta (y se golpea) girando el torso hacia la cámara: la moto sigue recta.
	# Con arma de fuego (2026-10-30): apuntado LIBRE en 360°. Hacia delante, la derecha y detrás por la
	# derecha dispara con la mano derecha; hacia la izquierda y detrás por la izquierda se pasa el arma a la
	# mano izquierda (la derecha va al puño del acelerador). Ver _paso_mano_moto y "apuntado en la moto"
	var rel_obj := 0.0
	moto_fuego = false
	if mt != null:
		var tool_m: String = J.arsenal.equipado
		var cfg_m: Dictionary = Armas.WEAPONS.get(tool_m, {})
		var golpeando: bool = melee_st != null and now - float(melee_st.start) < float(melee_st.dur)
		var apunta_m: bool = tool_m != "" and (aiming or L.firing or now - last_shot_t < 0.8)
		if cfg_m.get("Kind", "") == "Gun":
			moto_fuego = true
			if draw_st != null or L.holster != null:
				_soltar_mano_moto() # sacar/guardar: siempre con la derecha
			var rel_t := Rbx.wrap_a(float(L.yaw) - yaw)
			var ocupado: bool = draw_st != null or L.holster != null or reload_st != null or float(mt.subir) < 1.0
			_paso_mano_moto(apunta_m and not ocupado, rel_t, now)
			if apunta_m:
				rel_obj = angulo_mira(rel_t)
		elif tool_m != "" and (apunta_m or golpeando):
			rel_obj = clampf(Rbx.wrap_a(float(L.yaw) - yaw), -GOLPE_MOTO_DER, GOLPE_MOTO_IZQ)
	else:
		_soltar_mano_moto()
	if mt != null:
		# en la moto el torso y el brazo giran como un cuerpo de verdad (2026-11-01): muelle críticamente
		# amortiguado con velocidad máxima (antes, con un suavizado simple, un tirón del ratón movía la mano a
		# más de 70 studs/s de golpe). Arranca y frena con suavidad; media vuelta tarda ~0,7 s
		var mr := _muelle_lim(rel_aim, moto_giro_vel, rel_obj, GIRO_W, GIRO_VMAX, GIRO_ACEL, dt)
		rel_aim = mr[0]
		moto_giro_vel = mr[1]
	else:
		moto_giro_vel = 0.0
		rel_aim = Rbx.damp(rel_aim, rel_obj, 3.5 if prone_aim else 5.0, dt)
	if mt != null:
		if moto_fuego:
			# APUNTADO EN LA MOTO: la pose (cintura, cuello y brazo derecho) sale de las poses hechas en Blender
			# (PosesMoto), mezcladas según hacia dónde se apunta; se aplica abajo, en "aplicar torso, cuello y brazos"
			moto_pose = _pose_moto(rel_aim, clampf(pitch, -1.2, 1.1), now)
		else:
			waistY += rel_aim * 0.45
			neckY += rel_aim * 0.3
	# (siempre que esté tumbado, no solo al apuntar: si no, al volver a ponerse boca abajo sin apuntar
	# el arma y los brazos se quedaban mirando hacia los pies, hacia atrás)
	if prone_aim:
		var ay: float = L.yaw
		var rel_h := Rbx.wrap_a(ay - yaw)
		var fa := 1.0 if absf(rel_h) > PI / 2 else 0.0
		feet_aim = Rbx.damp(feet_aim, fa * rl, 6, dt)
		var axis := yaw + PI * feet_aim * roll_side
		var rel_a := clampf(Rbx.wrap_a(ay - axis), -0.35, 0.35)
		prone_rel = Rbx.damp(prone_rel, rel_a, 6, dt)
		waistY += prone_rel * 0.35 # el torso acompaña un poco el margen de los brazos
	var rl_now := rl if pb > 0.5 else 0.0

	## ------------------------------------------------ brazos
	# pared o estructura justo delante del pecho: los brazos no se balancean hacia ella
	var wall_ahead := {}
	if pb < 0.5 and mt == null:
		var lk0 := Rbx.look(root_cf)
		var wh := J.raycast(chest_cf.origin, lk0 * 3.4)
		if not wh.is_empty() and absf(wh.normal.y) < 0.6:
			wall_ahead = wh
	var wall_k := clampf((wall_ahead.distance - 1.0) / 1.6, 0.0, 1.0) if not wall_ahead.is_empty() else 1.0
	# balanceo natural (sin arma): opuesto a la pierna del mismo lado
	var arm_t := {}
	var arm_a := {"L": 0.0, "R": 0.0}
	var run_arm := 0.0
	for s in ["L", "R"]:
		var f: Dictionary = feet[s]
		var rel := Rbx.to_obj(root_cf, f.cur if f.get("cur") != null else f.pos)
		# corriendo (de pie o agachado) los brazos bombean: codo doblado, mano adelante a la altura
		# del pecho y atrás hasta la cadera, cruzando un poco por delante del cuerpo
		var run_k := clampf((speed - (4.2 if crouch_b > 0.5 else 7.0)) / 4.0, 0, 1)
		# onda suave de la marcha: el brazo va adelante cuando la pierna contraria va adelante
		var a_run := sin(gait_ph) * (1.0 if s == "R" else -1.0) * gait_amp
		# con fatiga los brazos cuelgan pesados: poco balanceo, algo adelantados y codos sueltos
		var swing_w := a_run * (0.3 + speed_f * 0.35) * (1.0 - 0.55 * fat) + 0.1 * fat
		# carrera: el brazo va desde la cadera (atrás) hasta la altura del pecho (delante)
		arm_a[s] = a_run
		var swing_r := a_run * (0.8 if a_run > 0.0 else 0.85)
		var swing := lerpf(swing_w, swing_r, run_k)
		if swing > 0.0:
			swing *= wall_k
		if not grounded:
			swing = 0
		var air_abd := 0.0
		if not grounded and va == null:
			# en el aire: carrera = brazo contrario a la rodilla delantera; parado = brazos arriba al
			# despegar; cayendo = brazos abiertos para equilibrarse
			var run2 := jump_run
			var fall2 := air_fall
			if air_runoff and run2 > 0.3:
				swing = a_run * 0.8
			elif run2 > 0.3:
				swing = (0.8 if s != jump_lead else -0.6) * run2 * (1 - fall2 * 0.5)
			else:
				swing = 1.0 * (1 - fall2) - 0.1
			air_abd = 0.15 + 0.45 * fall2
		elif not grounded:
			air_abd = 0.3
		if prep_k > 0:
			swing = -0.6 * prep_k
		if not grounded and not (air_runoff and jump_run > 0.3 and va == null):
			run_k = 0.0
		var sgn_a := 1.0 if s == "R" else -1.0
		var abd := sgn_a * (0.07 + 0.05 * run_k + air_abd + flail * 0.25)
		# codo: andando casi recto; corriendo ~80-100° (más doblado cuando el brazo va adelante)
		# corriendo el codo va a ~90°: se cierra cuando el brazo sube por delante y se abre un poco
		# cuando la mano pasa por detrás de la cadera
		var elbow := lerpf(0.18 + absf(swing) * 0.3, lerpf(1.25, 1.65, (sin(gait_ph - 0.35) * (1.0 if s == "R" else -1.0) + 1.0) * 0.5), run_k)
		if flail > 0.05:
			swing += sin(now * 18 + (1.5 if s == "L" else 0.0)) * flail * 0.6
		if speed < 0.5:
			swing = 0.04 + sin(breath_t) * 0.02
			# agachado y quieto: brazos algo adelantados y doblados, listos (como en el ciclo de Blender)
			if grounded and va == null:
				swing += 0.4 * crouch_b
				elbow += 0.75 * crouch_b
		run_arm = maxf(run_arm, run_k)
		# por delante la mano cruza un poco hacia el centro del pecho (sin pasar de la línea media)
		arm_t[s] = {"sh": Rbx.ang(swing + 0.06 * run_k, -sgn_a * 0.28 * run_k * maxf(0.0, a_run), abd), "el": Rbx.ang(elbow, 0, 0)}
		# en el aire (salto): los brazos de las poses de Blender (el del lado de la pierna adelantada y el otro)
		if not grounded and va == null and mt == null and pb < 0.01 and not (air_runoff and jump_run > 0.3) and flail < 0.05:
			var k_b := "ba_" if s == jump_lead else "bb_"
			var r_j := jump_run
			var bp := lerpf(Movimientos.salto("parado", k_b + "p", air_tj), Movimientos.salto("corriendo", k_b + "p", air_tj), r_j)
			var br := lerpf(Movimientos.salto("parado", k_b + "r", air_tj), Movimientos.salto("corriendo", k_b + "r", air_tj), r_j)
			var bc := lerpf(Movimientos.salto("parado", k_b + "codo", air_tj), Movimientos.salto("corriendo", k_b + "codo", air_tj), r_j)
			arm_t[s] = {"sh": Rbx.ang(bp, 0, sgn_a * br), "el": Rbx.ang(bc, 0, 0)}
		# andando o corriendo por el suelo: los brazos del ciclo de Blender (con su retraso y el codo que acompaña)
		if grounded and va == null and amp_ciclo > 0.001 and prep_k <= 0.0 and flail < 0.05:
			var cb := _brazo_ciclo(s, ph01)
			var bx: float = cb[0]
			# con fatiga los brazos cuelgan pesados (menos balanceo, algo adelantados)
			bx = bx * (1.0 - 0.55 * fat) + 0.1 * fat
			if bx > 0.0:
				bx *= wall_k
			var sh_c := Rbx.ang(bx, cb[1], cb[2])
			var el_c := Rbx.ang(float(cb[3]) * (1.0 - 0.3 * fat), 0, 0)
			var k_c := clampf(amp_ciclo * 1.6, 0.0, 1.0)
			arm_t[s] = {"sh": (arm_t[s].sh as Transform3D).interpolate_with(sh_c, k_c), "el": (arm_t[s].el as Transform3D).interpolate_with(el_c, k_c),
				"wr": Rbx.ang(float(cb[4]) * k_c, 0, 0)}
			run_arm = maxf(run_arm, mez_run * k_c)
	# torso de carrera: (desde 2026-11-02 el giro de hombros, el balanceo del pecho y la cabeza estable salen del
	# ciclo de Blender; aquí solo queda la inclinación del pecho hacia delante al correr)
	if run_arm > 0.0 and grounded and va == null and amp_ciclo > 0.001:
		waistP -= 0.1 * run_arm
		neckP += 0.08 * run_arm
	elif run_arm > 0.0 and grounded and va == null:
		var tw: float = 0.2 * run_arm * (float(arm_a.R) - float(arm_a.L)) * 0.5
		waistY += tw
		neckY -= tw * 0.85
		waistP -= 0.1 * run_arm
		neckP += 0.08 * run_arm
		waistR += 0.04 * run_arm * (float(arm_a.R) - float(arm_a.L)) * 0.5
		# el pecho se mece con cada zancada (dos veces por ciclo) y la cabeza lo compensa
		waistP += 0.035 * run_arm * cos(2.0 * gait_ph)
		neckP -= 0.03 * run_arm * cos(2.0 * gait_ph)
	elif gait_amp > 0.05 and grounded and va == null and amp_ciclo <= 0.001:
		# andando: un poco de giro de hombros con los brazos
		var tw2: float = 0.08 * gait_amp * (float(arm_a.R) - float(arm_a.L)) * 0.5
		waistY += tw2
		neckY -= tw2 * 0.8

	var hand_ik := {} # s -> {pos | cf, pole, w}
	var left_free := true
	var tool: String = J.arsenal.equipado
	var w_cfg: Dictionary = Armas.WEAPONS.get(tool, {})
	var right_free := tool == ""

	## ------------------------------------------------ armas (poses, sacar/guardar, recarga, golpes)
	if tool != last_tool:
		last_tool = tool
		pose_rel = null
		cancelar_recarga()
		melee_st = null
		# arma nueva en la mano: animación de sacarla de donde se lleva
		draw_st = {"t0": now, "tool": tool, "start": null} if tool != "" else null
	var kick: float = S.kick.step(dt)
	var kick_rot: float = S.kickRot.step(dt)
	var melee_lean := 0.0
	correr_libre = false
	tool_shown = true
	if tool == "" or w_cfg.get("Kind", "") != "Gun":
		arma_alzada = 0.0
		arma_retro = 0.0
	if tool != "":
		var mdl: Node3D = J.arsenal.modelo_mano
		var kind: String = w_cfg.Kind
		_paso_accion(mdl)
		var target_rel: Transform3D
		var speed_pose := 7.0
		var firing_recent := now - last_shot_t < 0.8
		var pc := clampf(pitch, -1.2, 1.1)
		# eje del arma: hacia donde mira el cuerpo (tumbado: cabeza o pies, con un pequeño margen)
		var aim_base := Rbx.cfp(chest_cf.origin) * Rbx.ang(0, yaw + rel_aim, 0)
		if prone_aim:
			var axis := yaw + PI * feet_aim * roll_side
			aim_base = Rbx.cfp(chest_cf.origin) * Rbx.ang(0, axis + prone_rel, 0)
		elif absf(ln) > 0.01:
			# asomado: el arma sigue al pecho y se ladea un poco
			aim_base = aim_base * Rbx.ang(0, 0, -ln * 0.22)
		var reloading: bool = reload_st != null and now - float(reload_st.start) < float(reload_st.dur)
		if kind == "Gun":
			if reloading:
				var R: Dictionary = reload_st.R
				var t: float = (now - float(reload_st.start)) * (float(R.dur) / float(reload_st.dur))
				target_rel = Armas.pose(tool, "RELOAD") * Rbx.sample(R.gun, t)
				for e in R.events:
					if t >= e[0] and not reload_st.fired.has(e[1]):
						reload_st.fired[e[1]] = true
						_mag_visual(e[1])
			elif va != null or (sprinting and not aiming and not firing_recent):
				target_rel = Armas.pose(tool, "SPRINT")
				speed_pose = 8.0
			elif aiming:
				target_rel = Rbx.ang(pc, 0, 0) * Armas.pose(tool, "AIM")
				speed_pose = lerpf(4.0, 9.0, smoothstep(0.0, 0.45, _entrada_apuntar))
			elif firing_recent or L.firing:
				target_rel = Rbx.ang(pc, 0, 0) * Armas.pose(tool, "HIP")
				speed_pose = 11.0
			else:
				target_rel = Rbx.ang(pc * 0.35, 0, 0) * Armas.pose(tool, "LOW")
				speed_pose = 4.5
			# postura del cuerpo diseñada en Blender (PosturasPie) para este estado
			var est_p := "LOW"
			if reloading:
				est_p = "LOW"
			elif va != null or (sprinting and not aiming and not firing_recent):
				est_p = "SPRINT"
			elif aiming:
				est_p = "AIM"
			elif firing_recent or L.firing:
				est_p = "HIP"
			_paso_postura_pie(tool, est_p, pc, mt == null and pb < 0.5, speed_pose, dt)
			# tumbado: arma apoyada sobre los codos, siempre lista
			if pb > 0.8 and not reloading:
				target_rel = Rbx.ang(pc, 0, 0) * Armas.pose(tool, "PRONE")
				speed_pose = 5.0
			# pegado a una pared: el arma se levanta con el cañón hacia arriba en vez de atravesarla
			# (mientras está alzada no se puede disparar: ver Arsenal.aim_check)
			var alza_t := 0.0
			var retro_t := 0.0
			# con el arma apoyada (X) nunca se levanta: lo que hay delante es el propio apoyo
			if not reloading and pb < 0.5 and mdl and mdl.has_node("Muzzle") and draw_st == null and L.holster == null \
					and not L.get("rested", false):
				var arma_w: Transform3D = aim_base * target_rel
				var mz_w: Vector3 = arma_w * (mdl.get_node("Muzzle") as Node3D).position
				var empu := arma_w.origin
				var c0 := aim_base.origin
				var largo := (mz_w - empu).length()
				if not J.raycast(c0, empu - c0).is_empty():
					# la pared está entre el pecho y la empuñadura: del todo recogida (o levantada, si está activo)
					retro_t = 1.0
					alza_t = 1.0
				elif largo > 0.1:
					# a lo largo del propio cañón (no desde el pecho): apuntando por encima de un muro bajo o
					# junto a una esquina el arma no se levanta. Cerca de la pared, primero el arma se RECOGE
					# hacia el cuerpo (sigue apuntando y se puede disparar); solo si se está extremadamente
					# pegado, y ya no se puede recoger más, se levanta
					var hw := J.raycast(empu, (mz_w - empu) / largo * (largo + ALZA_MARGEN))
					if not hw.is_empty():
						var dentro := largo + ALZA_MARGEN - float(hw.distance)
						retro_t = clampf(dentro / RETRO_MAX, 0.0, 1.0)
						alza_t = clampf((dentro - RETRO_MAX) / ALZA_RECORRIDO, 0.0, 1.0)
			if not ALZA_ACTIVA:
				alza_t = 0.0
			arma_retro = Rbx.damp(arma_retro, retro_t, 12.0, dt)
			arma_alzada = Rbx.damp(arma_alzada, alza_t, 12.0, dt)
			# (al levantarse deja de estar recogida: si no, la culata se iría detrás de la espalda)
			var retro_ef := arma_retro * (1.0 - arma_alzada)
			if retro_ef > 0.001:
				target_rel = Rbx.cf(0, 0, RETRO_MAX * retro_ef) * target_rel
			if arma_alzada > 0.001:
				target_rel = Rbx.cf(0, 0.3 * arma_alzada, 0.8 * arma_alzada) * target_rel * Rbx.ang(1.25 * arma_alzada, 0, 0)
				speed_pose = maxf(speed_pose, 12.0)
			if reload_st != null and not reloading:
				cancelar_recarga()
		else:
			if mel_t >= 0.0:
				# el arma va con el pecho girado (si no, al girar los hombros el brazo se quedaría atrás)
				target_rel = Rbx.ang(0, mel_twist * 0.9, 0) * _muestra_golpe(mel_keys.pose, mel_t)
				speed_pose = 60.0
				waistY += mel_twist
				melee_lean = mel_lean
			elif sprinting:
				target_rel = Armas.pose(tool, "SPRINT")
				speed_pose = 8.0
			else:
				target_rel = Armas.pose(tool, "READY")
		# guardia, bloqueo, empujón (CombateCC): el arma donde diga la pose de Blender (salvo mientras golpea)
		var cc_arma := cc_w > 0.001 and cc_pose.has("a_px") and mel_t < 0.0 and not reloading
		if cc_arma:
			target_rel = target_rel.interpolate_with(Rbx.ang(0, -rel_aim, 0) * _cc_handle(), cc_w)
			speed_pose = maxf(speed_pose, 60.0 if cc_rapido else 16.0)
		if pose_rel == null:
			pose_rel = target_rel
		pose_rel = Rbx.damp_cf(pose_rel, target_rel, speed_pose, dt)
		# balanceo al caminar, inercia al girar, pulso
		var mm := minf(1.0, speed / 12.0) * (0.3 if aiming else 1.0)
		var ph = feet.L.get("u") if feet.L.get("u") != null else feet.R.get("u")
		var phf: float = ph if ph != null else 0.0
		var sway := Vector3(sin(phf * PI) * 0.03 * mm - clampf(yaw_rate * 0.015, -0.12, 0.12), sin(phf * PI) * 0.04 * mm, 0)
		# pulso al apuntar (apoyada, el arma no tiembla)
		if aiming and not L.get("rested", false):
			sway += Vector3(sin(now * 1.3) * 0.006, sin(now * 0.9) * 0.008, 0) * (1 + exertion * 3)
		# andando, el brazo del arma también se balancea (desde el hombro) en vez de ir tieso;
		# las armas largas a dos manos (rifle, bate) mucho menos
		var libre_k := 0.0 if (aiming or firing_recent or reloading or mel_t >= 0.0 or pb > 0.5) else 1.0
		var amp := 0.06 if Armas.base(tool) == "Rifle" and tool != "Subfusil" else (0.12 if Armas.dos_manos(tool) else 0.32)
		swing_arma = Rbx.damp(swing_arma, float(arm_a.R) * amp * libre_k, 12, dt)
		var piv := Vector3(0.92, 0.51, 0)
		var swing_t := Rbx.cfp(piv) * Rbx.ang(swing_arma, 0, 0) * Rbx.cfp(-piv)
		var handle_cf: Transform3D = aim_base * Rbx.cfp(sway) * swing_t * pose_rel * Rbx.cf(0, 0, kick * 0.06) * Rbx.ang(kick_rot * 0.05, 0, 0)
		# APUNTADO EN LA MOTO (arma de fuego, 360°): el brazo derecho lo coloca la pose de Blender (ver
		# _pose_moto y "aplicar torso, cuello y brazos"); aquí solo cuánto está apuntando (0 = arma baja, por IK)
		var h_arma := "R"
		var pole_moto = null
		if moto_fuego and kind == "Gun":
			var apunta_ok: bool = (aiming or firing_recent or L.firing) and draw_st == null and L.holster == null and not reloading
			moto_apunta_k = Rbx.damp(moto_apunta_k, 1.0 if apunta_ok else 0.0, 8.0, dt)
			_paso_correccion_moto(mdl, dt)
		else:
			moto_apunta_k = 0.0
			moto_corr_q = Quaternion.IDENTITY
		_arma_a_mano(mdl, tool, h_arma)
		# CORRER con pistola o arma blanca de una mano: el brazo bombea como al correr sin arma
		# (la muñeca inclina el arma hacia abajo); el bate va al hombro
		correr_libre = sprinting and grounded and va == null and pb < 0.5 and libre_k > 0.5 and (Armas.base(tool) == "Pistola" or (kind == "Melee" and not Armas.dos_manos(tool))) \
			and draw_st == null and L.holster == null

		# SACAR / GUARDAR el arma: la mano va a por ella donde se lleva (muslo, espalda, pecho,
		# mochila), la saca siguiendo un recorrido natural y la lleva a la posición de uso; al
		# guardarla hace el camino inverso
		var support_w := 1.0
		var spot := Armas.holster(tool)
		var spot_part: Node3D = P.get(spot.get("Part", ""))
		var D := Armas.draw(tool)
		var holster_t = null
		var fuera_saca := 0.0   # al sacar o guardar el arma de fuego: cuánto se aparta ya del torso (ver más abajo)
		if L.holster != null and L.holster.name == tool:
			holster_t = (now - float(L.holster.t0)) / Armas.HOLSTER_TIME
		if spot_part and not D.is_empty():
			var holster_w: Transform3D = spot_part.global_transform * spot.CF
			var mid_w: Transform3D = chest_yaw_base * D.mid
			# recorrido por claves (armas largas a la espalda): respecto al pecho, para que vaya siempre por fuera
			var camino_w: Array = []
			for kc in D.get("camino", []):
				camino_w.append([kc[0], (P.UpperTorso as Node3D).global_transform * (kc[1] as Transform3D)])
			if holster_t != null:
				draw_st = null
				var back := 0.72
				if holster_t < back:
					var u := Rbx.smooth(clampf(holster_t / back, 0, 1))
					if camino_w.size() > 0:
						# por el mismo camino que al sacarla, al revés
						var kk: Array = [[0.0, handle_cf]]
						for i in range(camino_w.size() - 1, -1, -1):
							kk.append([1.0 - float(camino_w[i][0]), camino_w[i][1]])
						kk.append([1.0, holster_w])
						handle_cf = _por_claves(kk, u)
						fuera_saca = 1.0 - Rbx.smooth(clampf(u / 0.18, 0, 1))
					else:
						handle_cf = handle_cf.interpolate_with(mid_w, u).interpolate_with(mid_w.interpolate_with(holster_w, u), u)
						fuera_saca = 1.0 - Rbx.smooth(clampf(u / 0.5, 0, 1))
					support_w = 1.0 - Rbx.smooth(clampf(u / 0.35, 0, 1))
				else:
					# ya enfundada: la mano vuelve a su sitio
					var u2 := Rbx.smooth(clampf((holster_t - back) / (1 - back), 0, 1))
					handle_cf = holster_w.interpolate_with(chest_yaw_base * Armas.pose_holster(), u2)
					tool_shown = false
					support_w = 0.0
			elif draw_st != null and draw_st.tool == tool:
				var dur: float = float(w_cfg.get("DrawTime", 0.5))
				var t3: float = (now - float(draw_st.t0)) / dur
				if t3 >= 1.0:
					draw_st = null
				else:
					if draw_st.start == null:
						# de donde esté la mano ahora mismo
						draw_st.start = (P.RightHand as Node3D).global_transform * Armas.grip_att() * Armas.grip(tool).affine_inverse()
					if t3 < float(D.reach):
						# la mano va a por el arma (el arma sigue en la funda)
						handle_cf = (draw_st.start as Transform3D).interpolate_with(holster_w, Rbx.smooth(t3 / float(D.reach)))
						tool_shown = false
						support_w = 0.0
					else:
						# la saca y la lleva a la posición de uso
						var u3 := Rbx.smooth((t3 - float(D.reach)) / (1.0 - float(D.reach)))
						if camino_w.size() > 0:
							var kk: Array = [[0.0, holster_w]]
							kk.append_array(camino_w)
							kk.append([1.0, handle_cf])
							handle_cf = _por_claves(kk, u3)
							fuera_saca = Rbx.smooth(clampf((u3 - 0.8) / 0.18, 0, 1))
						else:
							handle_cf = holster_w.interpolate_with(mid_w, u3).interpolate_with(mid_w.interpolate_with(handle_cf, u3), u3)
							fuera_saca = Rbx.smooth(clampf((u3 - 0.1) / 0.45, 0, 1))
						support_w = Rbx.smooth(clampf((u3 - 0.7) / 0.3, 0, 1))

		# apuntando o disparando, el cañón se orienta hacia lo que marca la mira (la cámara va al hombro,
		# así que sin esto el arma iba paralela a la mira y la bala salía con otra inclinación). La bala
		# sale en la dirección del cañón (Arsenal.shoot), así que lo que se ve es lo que pasa
		var conv_t := 0.0
		if kind == "Gun" and tool_shown and mdl and mdl.has_node("Muzzle") and draw_st == null and holster_t == null \
				and not reloading and va == null and (aiming or firing_recent or L.firing) \
				and not (sprinting and not aiming and not firing_recent):
			conv_t = 1.0 - clampf(arma_alzada * 3.0, 0.0, 1.0)
		conv_w = Rbx.damp(conv_w, conv_t, 10.0, dt)
		if conv_w > 0.001 and mdl and mdl.has_node("Muzzle"):
			var mz_l: Vector3 = (mdl.get_node("Muzzle") as Node3D).position
			var mz_w := handle_cf * mz_l
			var d0 := (-handle_cf.basis.z).normalized()
			var obj: Vector3 = J.arsenal.punto_mira() - mz_w
			if obj.length() > 3.0 and d0.angle_to(obj) < deg_to_rad(35):
				var q := Quaternion(d0, obj.normalized())
				conv_q = conv_q.slerp(q, 1.0 - exp(-25.0 * dt))
			else:
				# la mira está pegada al arma (blanco encima) o muy desviada: sin corrección
				conv_q = conv_q.slerp(Quaternion.IDENTITY, 1.0 - exp(-10.0 * dt))
			var qw := Quaternion.IDENTITY.slerp(conv_q, conv_w)
			# gira alrededor de la empuñadura (la mano no se mueve; el cañón sube/baja/gira un poco)
			handle_cf = Transform3D(Basis(qw) * handle_cf.basis, handle_cf.origin)
		# las armas blancas nunca atraviesan el propio cuerpo (torso, cabeza, cadera, muslos)
		if kind == "Melee" and tool_shown and pb < 0.5:
			handle_cf = _arma_fuera_del_cuerpo(handle_cf, tool, pelvis_cf, chest_cf)
		# las de fuego, el torso (ni tumbado ni en la moto; al sacarla o guardarla, solo en el tramo de delante del
		# cuerpo: al principio y al final del recorrido va o viene de la funda, a la espalda o en el muslo)
		var fuera_t := 1.0 if kind == "Gun" and tool_shown and mdl and pb < 0.5 and mt == null else 0.0
		if draw_st != null or holster_t != null:
			fuera_t *= fuera_saca
			fuera_w = fuera_t   # (fuera_saca ya es suave)
		else:
			fuera_w = Rbx.damp(fuera_w, fuera_t, 8.0, dt)
		if kind == "Gun" and mdl and fuera_w > 0.001:
			# (con el pecho como quedará este fotograma: la postura de pie lo gira y lo inclina más abajo)
			var kp := pie_k
			var t_w := Rbx.ang(0, waistY + pie_w.x * kp - blade, 0) \
					* Rbx.ang(waistP + breath + pie_w.y * kp + pc * 0.35 * (1.0 - kp), 0, waistR + pie_w.z * kp)
			var pecho_fin: Transform3D = pelvis_cf * Mw.c0 * t_w * Mw.c1inv
			handle_cf = _arma_de_fuego_fuera(handle_cf, _puntos_arma(mdl, tool), pelvis_cf, pecho_fin, fuera_w)
		# arma apoyada: a ras del apoyo (ni flotando ni metida dentro). Apuntando junto a una barrera o un muro (sin
		# apoyar, 2026-11-03): el cuerpo se incorpora lo justo para que el arma pase por encima y no lo atraviese
		# (recargando con el arma apoyada también: si no, el cuerpo volvía a bajar y el arma se metía en la barrera)
		var apoyo_ok: bool = kind == "Gun" and mdl and tool_shown and draw_st == null and holster_t == null \
				and (not reloading or L.get("rested", false)) and pb < 0.5 and mt == null
		if apoyo_ok and L.get("rested", false):
			handle_cf = _arma_sobre_apoyo(handle_cf, mdl, tool, root_cf, dt, J.arsenal.rest)
		elif apoyo_ok and aiming and J.arsenal.apoyo_delante != null:
			handle_cf = _arma_sobre_apoyo(handle_cf, mdl, tool, root_cf, dt, J.arsenal.apoyo_delante, true)
		else:
			rest_alza = 0.0
			rest_baja = Rbx.damp(rest_baja, 0.0, 6.0, dt)
		# mano derecha: la que sostiene el arma
		var hand_cf: Transform3D = handle_cf * Armas.grip(tool) * Armas.grip_att().affine_inverse()
		# codo: de pie hacia abajo y atrás; tumbado hacia fuera y delante
		var pole_r := (aim_base * Rbx.cf(1.7, -0.7, -0.3)).origin if pb > 0.5 else (aim_base * Rbx.cf(1.9, -1.4, 0.9)).origin
		if pie_k > 0.001 and pb <= 0.5:
			pole_r = pole_r.lerp(aim_base * pie_polo_r, pie_k)
			if aiming and not L.get("rested", false):
				pole_r += aim_base.basis * Vector3(0, sin(breath_t) * 0.04, sin(breath_t * 0.7) * 0.03)
		if cc_arma and cc_pose.has("pr_x"):
			pole_r = pole_r.lerp(chest_yaw_base * Vector3(cc_pose.pr_x, cc_pose.pr_y, cc_pose.pr_z), cc_w)
		cc_handle_cf = handle_cf
		if not correr_libre:
			hand_ik.R = {"cf": hand_cf, "pole": pole_moto if pole_moto != null else pole_r, "w": 1.0}
		waistP += kick_rot * 0.012

		# mano izquierda
		var support: Node3D = null
		var support_pos := Vector3.ZERO
		if mdl:
			support = mdl.find_child("LeftGrip", true, false) as Node3D
			if support == null:
				support = mdl.get_node_or_null("SupportGrip")
			if support:
				support_pos = Armas.punto_local(mdl, support.name)
		var pole_l := (aim_base * Rbx.cf(-1.7, -0.7, -0.3)).origin if pb > 0.5 else (chest_yaw_base * Rbx.cf(-1.9, -1.5, 0.3)).origin
		if pie_k > 0.001 and pb <= 0.5:
			pole_l = pole_l.lerp(aim_base * pie_polo_l, pie_k)
		if reloading and mdl and h_arma == "R":
			var R2: Dictionary = reload_st.R
			var t4: float = (now - float(reload_st.start)) * (float(R2.dur) / float(reload_st.dur))
			var refs := {"grip": support_pos}
			for k in [["mag", "MagBottom"], ["charge", "ChargingHandle"], ["slide", "SlideRear"]]:
				refs[k[0]] = Armas.punto_local(mdl, k[1])
			var pouch: Vector3 = (P.LowerTorso as Node3D).global_transform * Vector3(-0.25, 0.1, -0.5)
			var H: Array = R2.hand
			var to_w := func(kf: Array) -> Vector3:
				if kf[1] == "pouch":
					return pouch
				return handle_cf * (refs[kf[2]] + (kf[3] if kf.size() > 3 else Vector3.ZERO))
			var pos: Vector3 = to_w.call(H[H.size() - 1])
			for i in H.size() - 1:
				if t4 <= H[i + 1][0]:
					pos = (to_w.call(H[i]) as Vector3).lerp(to_w.call(H[i + 1]), Rbx.smooth((t4 - H[i][0]) / maxf(1e-3, H[i + 1][0] - H[i][0])))
					break
			hand_ik.L = {"pos": pos, "pole": pole_l, "w": 1.0}
			left_free = false
		elif support and h_arma == "R":
			var one_handed: bool = (Armas.base(tool) == "Pistola" and sprinting and not aiming) or (kind == "Melee" and not Armas.dos_manos(tool)) \
				or mt != null # en la moto la izquierda va en el manillar
			if not one_handed:
				hand_ik.L = {"pos": handle_cf * support_pos, "pole": pole_l, "w": support_w}
				left_free = false
		# combate cuerpo a cuerpo (CombateCC): la mano izquierda. Con arma corta (cuchillo, pistola) va donde diga la pose
		# (guardando la cara, empujando con la palma o con el antebrazo); con arma larga, al bloquear y al empujar agarra
		# el arma más arriba (CC_AGARRE), y en guardia, si es de una mano, guarda la cara
		if cc_arma and h_arma == "R":
			var empuja: bool = jugador.arsenal.cc.accion != null and jugador.arsenal.cc.accion.tipo == "empujon"
			var en_arma := cc_clase in ["larga", "fuego_larga"] and (cc_block_w > 0.5 or empuja or Armas.dos_manos(tool) or kind == "Gun")
			if en_arma:
				var pl := chest_yaw_base * Vector3(cc_pose.get("pl_x", -1.5), cc_pose.get("pl_y", -1.0), cc_pose.get("pl_z", 0.2))
				var agarre: Vector3 = CC_AGARRE.get(tool, support_pos) if (cc_block_w > 0.5 or empuja) else support_pos
				if kind == "Gun":
					agarre = support_pos
				hand_ik.L = {"pos": handle_cf * agarre, "pole": pl, "w": 1.0}
				left_free = false
			elif cc_pose.has("ml_x"):
				var ikl := _cc_mano("ml_", "pl_", chest_yaw_base, cc_w)
				if hand_ik.has("L") and cc_w < 0.999:
					# mezcla desde donde estaba (agarrando el arma)
					var prev: Dictionary = hand_ik.L
					var desde: Vector3 = (prev.cf as Transform3D).origin if prev.has("cf") else prev.pos
					ikl.pos = desde.lerp(ikl.pos, cc_w)
					ikl.pole = (prev.pole as Vector3).lerp(ikl.pole, cc_w)
					ikl.w = 1.0
				hand_ik.L = ikl
				left_free = false
		# de pie con un arma de fuego: el pecho, la cintura y la cabeza según la postura de Blender (PosturasPie);
		# en el resto de casos (tumbado, en la moto, armas blancas), como antes
		var k_pie := pie_k if kind == "Gun" else 0.0
		waistY += pie_w.x * k_pie
		waistP += pie_w.y * k_pie
		waistR += pie_w.z * k_pie
		neckY += pie_n.x * k_pie
		neckP += pie_n.y * k_pie
		neckR += pie_n.z * k_pie
		waistP += (pc * 0.35 if kind == "Gun" else pc * 0.12) * (1.0 - k_pie)
		neckP += (pc * 0.35 if kind == "Gun" else pc * 0.2) * (1.0 - k_pie)
		if k_pie > 0.5:
			blade = Rbx.damp(blade, 0.0, 8, dt) # (el giro del pecho ya va en la postura)
		elif Armas.base(tool) == "Rifle" and not sprinting:
			blade = Rbx.damp(blade, 0.4 if aiming else 0.25, 8, dt)
			if aiming:
				neckP -= 0.12
				neckR -= 0.1
		else:
			blade = Rbx.damp(blade, 0.0, 8, dt)
		waistY -= blade
		neckY += blade * 0.9
	waistP += melee_lean
	# SIN ARMA en guardia / bloqueando / empujando / pateando: los dos brazos con las poses de Blender (CombateCC)
	if tool == "" and cc_w > 0.001 and cc_pose.has("mr_x") and va == null and pb < 0.5 and mt == null:
		hand_ik.R = _cc_mano("mr_", "pr_", chest_yaw_base, cc_w)
		hand_ik.L = _cc_mano("ml_", "pl_", chest_yaw_base, cc_w)
		right_free = false
		left_free = false
	J.arsenal.mostrar(tool_shown)

	## ------------------------------------------------ en la moto: manos en los puños del manillar
	if mt != null:
		var cpo2: Transform3D = mt.cuerpo
		var r_m := cpo2.basis.x
		var d_m := (-cpo2.basis.z - cpo2.basis.y * 0.6).normalized()
		var rot_m := Basis(r_m, -d_m, r_m.cross(-d_m)).orthonormalized()
		var w_m := clampf((float(mt.subir) - 0.35) / 0.5, 0.0, 1.0)
		for s in ["L", "R"]:
			if (s == "L" and not left_free) or (s == "R" and (not right_free or hand_ik.has("R"))):
				continue
			var sgn := -1.0 if s == "L" else 1.0
			var pt: Transform3D = mt["puno" + s]
			var pos_pu := pt.origin + cpo2.basis.y * 0.04
			var rot_pw := 1.0
			hand_ik[s] = {"pos": pos_pu, "pole": (chest_cf * Rbx.cf(sgn * 1.7, -1.0, 0.9)).origin,
				"w": w_m, "rot": rot_m, "rot_w": rot_pw}
			if s == "L":
				left_free = false
			else:
				right_free = false

	## ------------------------------------------------ sortear: manos sobre el obstáculo
	if va != null:
		var d: Vector3 = va.dir
		var rv: Vector3 = va.right
		var p: float = va.p
		if va.kind == "vault":
			# una mano (izquierda) apoyada en el borde mientras el cuerpo pasa por encima
			var wP := Rbx.smooth(clampf((p - 0.04) / 0.16, 0, 1)) * (1 - Rbx.smooth(clampf((p - 0.58) / 0.2, 0, 1)))
			var plant: Vector3 = va.edge + d * 0.35 - rv * 0.3
			var plant_p := Vector3(plant.x, va.topY + 0.12, plant.z)
			if left_free:
				hand_ik.L = {"pos": plant_p, "pole": (chest_yaw_base * Rbx.cf(-1.8, 0.4, 0.8)).origin, "w": wP}
				left_free = false
			elif hand_ik.has("L"):
				# con arma: la mano de apoyo suelta el arma, se apoya en el borde y vuelve al arma
				var prev_l: Dictionary = hand_ik.L
				var from_l: Vector3 = (prev_l.cf as Transform3D).origin if prev_l.has("cf") else prev_l.pos
				hand_ik.L = {"pos": from_l.lerp(plant_p, wP), "pole": (prev_l.pole as Vector3).lerp((chest_yaw_base * Rbx.cf(-1.8, 0.4, 0.8)).origin, wP), "w": prev_l.w}
			if right_free:
				# el otro brazo se abre para equilibrarse
				arm_t.R = {"sh": Rbx.ang(0.35 + 0.3 * va.sv, 0, 0.2 + 1.1 * va.sv), "el": Rbx.ang(0.5, 0, 0)}
		else:
			# encaramarse: las dos manos agarran el borde, tiran y empujan hacia abajo
			# 1) las manos suben y llegan al borde por ARRIBA (no a través de la pared)
			# 2) colgado: codos abajo y hacia fuera, tirando
			# 3) el pecho pasa por encima de las manos: empuja hacia abajo con los codos hacia atrás
			# 4) suelta y los brazos vuelven a su sitio
			var reach_k := Rbx.smooth(clampf(p / 0.16, 0, 1))
			var wG := Rbx.smooth(clampf(p / 0.08, 0, 1)) * (1 - Rbx.smooth(clampf((p - 0.74) / 0.18, 0, 1)))
			var hand_rot := Basis(rv, -d, rv.cross(-d)).orthonormalized()
			# al empujar, las manos se apoyan un poco más adentro de la superficie
			var push_pre := Rbx.smooth(clampf((p - 0.4) / 0.3, 0, 1))
			for s in ["L", "R"]:
				var sgn := -1.0 if s == "L" else 1.0
				var g2: Vector3 = va.edge + d * (0.1 + 0.3 * push_pre) + rv * (sgn * 0.7)
				var gP := Vector3(g2.x, va.topY + 0.3, g2.z)
				# camino de la mano: de delante del hombro, hacia arriba y por encima del borde
				var lift := (1.0 - reach_k)
				var tgt: Vector3 = gP + Vector3(0, 1.1 * lift, 0) - d * (0.9 * lift)
				var chest_y: float = chest_cf.origin.y
				var push_k := Rbx.smooth(clampf((chest_y - gP.y - 0.4) / 1.4, 0, 1))
				var pole_hang := (chest_yaw_base * Rbx.cf(sgn * 2.4, -0.5, -0.3)).origin
				var pole_push := (chest_yaw_base * Rbx.cf(sgn * 0.8, 0.8, 2.2)).origin
				var ik_m := {"pos": tgt, "pole": pole_hang.lerp(pole_push, push_k), "w": wG, "rot": hand_rot, "rot_w": reach_k}
				if (s == "L" and left_free) or (s == "R" and right_free):
					hand_ik[s] = ik_m
				elif s == "L" and hand_ik.has("L"):
					# con arma: la izquierda suelta el arma para agarrarse (la derecha la sujeta)
					var prev_m: Dictionary = hand_ik.L
					var from_m: Vector3 = (prev_m.cf as Transform3D).origin if prev_m.has("cf") else prev_m.pos
					hand_ik.L = {"pos": from_m.lerp(tgt, wG), "pole": (prev_m.pole as Vector3).lerp(ik_m.pole, wG), "w": prev_m.w}
			left_free = false
			right_free = false

	## ------------------------------------------------ colgado: manos en el borde (mano sobre mano al desplazarse)
	if hg != null and pb < 0.1:
		var n_c: Vector3 = hg.n
		var r_c := (-n_c).cross(Vector3.UP).normalized()
		var e_c: Vector3 = hg.edge
		var mv_c: float = hg.mv
		var ph_c: float = hg.ph
		# mano plana sobre la parte de arriba (palma abajo, dedos hacia la pared), con la muñeca
		# justo en el borde: así se ve que se agarra de la cornisa y no del aire
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			var fase := sin(ph_c + (0.0 if s == "L" else PI))
			var lat_c := sgn * 0.58 + 0.28 * fase * mv_c
			var alza := maxf(0.0, cos(ph_c + (0.0 if s == "L" else PI))) * 0.22 * absf(mv_c)
			var n_m := n_c
			var mu: Vector3 = e_c + r_c * lat_c + n_c * 0.06 + Vector3(0, 0.12 + alza, 0)
			if hg.get("manos") != null:
				# girando en una esquina: cada mano tiene su sitio (y su cara de la pared)
				mu = hg.manos[s][0]
				n_m = hg.manos[s][1]
			var r_m := (-n_m).cross(Vector3.UP).normalized()
			var rot_m := Basis(r_m, n_m, r_m.cross(n_m)).orthonormalized()
			var pole_c := (chest_yaw_base * Rbx.cf(sgn * 1.9, -0.8, 0.3)).origin
			hand_ik[s] = {"wrist": mu, "pole": pole_c, "w": 1.0, "rot": rot_m, "rot_w": 1.0}
		left_free = false
		right_free = false

	## ------------------------------------------------ cuerpo a tierra: manos al suelo, antebrazos apoyados, reptar
	var hands_down := clampf((pb - 0.3) / 0.3, 0, 1) * (1 - rl_now)
	# levantándose (Movimientos.LEVANTAR): boca abajo, las manos empujan el suelo debajo de los hombros (flexión) y se
	# sueltan al adelantar el pie; boca arriba, la derecha apoyada detrás de la cadera y la izquierda en la rodilla
	var sube_h: bool = pb > 0.001 and L.stance != 2
	var lev_h = L.get("levanta_arriba") if sube_h else null
	if lev_h != null:
		hands_down = 0.0
		var q_h := 1.0 - pb
		var w_at := Movimientos.levantar("arriba_mano_atras", q_h)
		var w_ro := Movimientos.levantar("arriba_mano_rodilla", q_h)
		if right_free and w_at > 0.001:
			var pel := (P.LowerTorso as Node3D).global_position
			var pm := pel - Rbx.look(root_cf) * 0.75 + Rbx.right(root_cf) * 0.6
			var gm: float = ground(pm)[0]
			hand_ik.R = {"pos": Vector3(pm.x, gm + 0.2, pm.z), "pole": (chest_yaw_base * Rbx.cf(1.6, 0.4, 1.2)).origin, "w": w_at}
			right_free = false
		if left_free and w_ro > 0.001:
			hand_ik.L = {"pos": ((P.LeftUpperLeg as Node3D).global_transform * Rbx.cf(0, -0.55, -0.35)).origin, "pole": (chest_yaw_base * Rbx.cf(-1.6, -0.6, 0.5)).origin, "w": w_ro}
			left_free = false
	elif sube_h:
		hands_down = Movimientos.levantar("abajo_manos", pb) * (1 - rl_now)
	# boca arriba sin arma: manos sobre el abdomen (con arma, las manos siguen al arma)
	if rl_now > 0.5:
		for s in ["L", "R"]:
			if (s == "L" and not left_free) or (s == "R" and not right_free):
				continue
			var sgn := -1.0 if s == "L" else 1.0
			var pos_m := (chest_cf * Rbx.cf(sgn * 0.22, -0.45, -0.5)).origin
			var polo_m := (chest_cf * Rbx.cf(sgn * 1.4, 0, 0.6)).origin
			if sup_mov_k > 0.001:
				# moviéndose boca arriba: las manos (con los codos) se apoyan en el suelo junto a la cadera y empujan
				var p_s := (chest_cf * Rbx.cf(sgn * 0.95, -1.0, 0.0)).origin
				p_s.y = float(ground(p_s)[0]) + 0.2
				pos_m = pos_m.lerp(p_s, sup_mov_k)
				polo_m = polo_m.lerp((chest_cf * Rbx.cf(sgn * 2.0, 0.6, 0.4)).origin, sup_mov_k)
			hand_ik[s] = {"pos": pos_m, "pole": polo_m, "w": rl_now}
		left_free = false
		right_free = false
	if hands_down > 0.01:
		var ca2 := crawl_amt
		for s in ["L", "R"]:
			if (s == "L" and left_free) or (s == "R" and right_free):
				var sgn := -1.0 if s == "L" else 1.0
				# el brazo avanza cuando la rodilla contraria sube (reptar militar)
				var off := sin(crawl + (0.0 if s == "L" else PI)) * 0.5 * ca2
				# la mano nunca vuelve por debajo del pecho: se queda delante de los hombros
				var reach2 := (-1.05 - off * 0.7) if pb > 0.95 else -0.85
				if sube_h:
					reach2 = Movimientos.levantar("abajo_manos_z", pb)
				var lat := 0.62 + 0.3 * clampf((reach2 + 1.0) / 0.3, 0, 1)
				var base3 := (chest_yaw_base * Rbx.cf(sgn * lat, 0, reach2)).origin
				var gy3: float = ground(base3)[0]
				# la mano se levanta un poco al avanzar
				var lift2 := maxf(0, cos(crawl + (0.0 if s == "L" else PI))) * 0.18 * ca2
				# (con el pecho aún alto el brazo baja casi vertical y la mano cuelga por debajo de la muñeca: más arriba)
				var alto_m := 0.65 * (1.0 - Rbx.smooth(clampf((pb - 0.62) / 0.33, 0, 1)))
				hand_ik[s] = {"pos": Vector3(base3.x, gy3 + 0.18 + lift2 + alto_m, base3.z), "pole": (chest_yaw_base * Rbx.cf(sgn * 1.5, -0.3, 0.4)).origin, "w": hands_down}
		left_free = false
		right_free = false

	## ------------------------------------------------ reacciones al entorno
	if pb < 0.5:
		# pared delante al ir deprisa: apoyar las manos (la palma en la superficie, no dentro)
		if speed > 5 and not wall_ahead.is_empty():
			var lk := Rbx.look(root_cf)
			var hit := wall_ahead
			if (hit.normal as Vector3).dot(lk) < -0.55:
				var k2 := clampf((3.4 - hit.distance) / 2.2, 0, 1)
				var pw: Vector3 = hit.position + hit.normal * 0.5 + Vector3(0, 0.3, 0)
				if left_free:
					hand_ik.L = {"pos": pw - Rbx.right(root_cf) * 0.45, "pole": (chest_yaw_base * Rbx.cf(-1.6, -1.2, 0.6)).origin, "w": k2}
					left_free = false
				if right_free:
					hand_ik.R = {"pos": pw + Rbx.right(root_cf) * 0.45, "pole": (chest_yaw_base * Rbx.cf(1.6, -1.2, 0.6)).origin, "w": k2}
					right_free = false
				waistP += k2 * 0.06
		# agotado: manos en las rodillas
		if exhausted:
			if left_free:
				hand_ik.L = {"pos": ((P.LeftUpperLeg as Node3D).global_transform * Rbx.cf(0, -0.5, -0.5)).origin, "pole": (chest_yaw_base * Rbx.cf(-1.6, -0.6, 0.5)).origin, "w": 0.9}
				left_free = false
			if right_free:
				hand_ik.R = {"pos": ((P.RightUpperLeg as Node3D).global_transform * Rbx.cf(0, -0.5, -0.5)).origin, "pole": (chest_yaw_base * Rbx.cf(1.6, -0.6, 0.5)).origin, "w": 0.9}
				right_free = false
		# herido: mano en la herida
		if hp_frac < 0.35 and left_free:
			hand_ik.L = {"pos": (chest_cf * Rbx.cf(0.25, -0.5, -0.5)).origin, "pole": (chest_yaw_base * Rbx.cf(-1.5, -1.2, 0)).origin, "w": 0.85}
			left_free = false
			waistP -= 0.1

	## ------------------------------------------------ levantar una moto: manos en el manillar y el asiento
	var lev2 = L.get("levanta")
	if lev2 != null and mt == null:
		var w_lev := Rbx.smooth(float(lev2.k) / 0.15)
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			hand_ik[s] = {"pos": lev2[s], "pole": (chest_yaw_base * Rbx.cf(sgn * 1.8, -0.8, 0.5)).origin, "w": w_lev}
		left_free = false
		right_free = false

	## ------------------------------------------------ recoger: la mano va al objeto, lo coge y lo guarda
	if rec != null and rec_p >= 0.0 and va == null:
		var s_m: String = rec.mano
		var sgn_m := -1.0 if s_m == "L" else 1.0
		var obj: Vector3 = rec.pos
		var wrist_obj := obj + Vector3(0, 0.38, 0)
		var dest: Vector3
		if rec_p < 0.42:
			dest = wrist_obj
		else:
			# ya cogido: sube con él hasta delante del pecho y luego lo lleva a su sitio en el cuerpo
			var pecho := (chest_yaw_base * Rbx.cf(sgn_m * 0.45, -0.45, -0.85)).origin
			var guardar := pecho
			var spot := Armas.holster(String(rec.item.name))
			var parte: Node3D = P.get(spot.get("Part", ""))
			if parte:
				guardar = (parte.global_transform * (spot.CF as Transform3D)).origin
			var k1 := Rbx.smooth((rec_p - 0.45) / 0.3)
			var k2 := Rbx.smooth((rec_p - 0.75) / 0.22)
			dest = wrist_obj.lerp(pecho, k1).lerp(guardar, k2)
		var w_m := Rbx.smooth(rec_p / 0.2) * (1.0 - Rbx.smooth((rec_p - 0.9) / 0.1))
		var x_m := Rbx.right(root_cf)
		var y_m := Vector3.UP if rec_p < 0.5 else (-Rbx.look(root_cf) * 0.3 + Vector3.UP).normalized()
		var rot_m := Basis(x_m, y_m, x_m.cross(y_m)).orthonormalized()
		var pole_m := (chest_yaw_base * Rbx.cf(sgn_m * 1.8, -0.3, 0.6)).origin
		if pb > 0.5:
			pole_m = (chest_yaw_base * Rbx.cf(sgn_m * 1.6, 0.6, 0.2)).origin
		hand_ik[s_m] = {"wrist": dest, "pole": pole_m, "w": w_m, "rot": rot_m, "rot_w": 1.0}
		if s_m == "L":
			left_free = false
		else:
			right_free = false
		# la cabeza mira lo que coge
		neckP -= 0.25 * rec_sq

	## ------------------------------------------------ cabeza
	# sin arma, la cabeza sigue a la cámara
	var cam_look := Rbx.vec_to_obj(root_cf, Rbx.look(J.camara.global_transform))
	var look_y := clampf(atan2(-cam_look.x, -cam_look.z), -1.0, 1.0)
	var look_p := clampf(pitch * 0.6, -0.5, 0.5)
	# apuntando con un arma de fuego: la cabeza va con el arma (no por su cuenta)
	if not w_cfg.is_empty() and w_cfg.Kind == "Gun" and (aiming or now - last_shot_t < 0.8):
		look_y = 0.0
		look_p = 0.0
	if pb > 0.5:
		look_y = 0
		look_p = 0 # tumbado: la cabeza la orienta la postura
	if hg != null:
		# colgado: mira a la pared / al borde (como mucho echa un vistazo de lado hacia donde va)
		look_y = clampf(look_y, -0.35, 0.35) * 0.4
		look_p = 0.0
	look = Vector3(Rbx.damp(look.x, look_y, 3.5, dt), Rbx.damp(look.y, look_p, 3.5, dt), 0)
	neckY += look.x * 0.7
	waistY += look.x * 0.3
	neckP += look.y * 0.8

	## ------------------------------------------------ la cabeza no entra en paredes
	# si la cabeza (fotograma anterior) queda pegada a la pared de delante, el torso se endereza
	var hc_obj := 0.0
	if pb < 0.5 and not wall_ahead.is_empty():
		var hp := (P.Head as Node3D).global_position
		var sd := (hp - (wall_ahead.position as Vector3)).dot(wall_ahead.normal as Vector3)
		hc_obj = clampf(head_corr + (0.75 - sd) / 2.0, 0.0, 0.7)
	head_corr = Rbx.damp(head_corr, hc_obj, 12, dt)
	waistP += head_corr
	neckP -= head_corr * 0.3

	## ------------------------------------------------ aplicar torso, cuello y brazos
	var Mn: RigPersonaje.Motor = M.Neck
	Mw.transform = Rbx.ang(0, waistY, 0) * Rbx.ang(waistP + breath, 0, waistR)
	# Respiración y acompañamiento leve del disparo, sin desplazar la mira.
	if aiming and mt == null and pb < 0.5:
		neckY += sin(breath_t * 0.55) * 0.008
		neckR += sin(breath_t * 0.7) * 0.006
		neckP -= exp(-maxf(0.0, now - last_shot_t) * 18.0) * 0.025
	Mn.transform = Rbx.ang(0, neckY, 0) * Rbx.ang(neckP - breath * 0.5, 0, neckR)
	if moto_fuego and moto_apunta_k > 0.001 and moto_pose.size() == 5:
		# pose de Blender: el giro de la cintura y del cuello respecto a la pose de conducir (sobre lo que ya
		# hace el cuerpo en la moto: agacharse, inclinarse en las curvas, respirar)
		var dw: Quaternion = (moto_pose[0] as Quaternion) * (PosesMoto.BASE[0] as Quaternion).inverse()
		var dn: Quaternion = (moto_pose[1] as Quaternion) * (PosesMoto.BASE[1] as Quaternion).inverse()
		Mw.transform.basis = Basis(Quaternion.IDENTITY.slerp(dw.normalized(), moto_apunta_k)) * Mw.transform.basis
		Mn.transform.basis = Basis(Quaternion.IDENTITY.slerp(dn.normalized(), moto_apunta_k)) * Mn.transform.basis
	smooth_j(Mw, "Waist", 6.0 if pb > 0.01 else (30.0 if (mel_t >= 0.0 or cc_rapido) else 10.0), dt)
	smooth_j(Mn, "Neck", 7, dt)
	chest_cf = fk(pelvis_cf, Mw)
	for s in ["L", "R"]:
		var Lm: Limb = arm[s]
		Lm.top.transform = arm_t[s].sh
		Lm.mid.transform = arm_t[s].el
		Lm.fin.transform = arm_t[s].get("wr", Transform3D.IDENTITY)
		if s == "R" and correr_libre:
			# muñeca: la pistola apunta al suelo por delante; el cuchillo y el machete, hacia abajo
			var wp := -1.15 if Armas.base(tool) == "Pistola" else (-0.6 if tool == "Cuchillo" else -1.25)
			Lm.fin.transform = Rbx.ang(wp, 0, 0)
		if hand_ik.has(s):
			var ik: Dictionary = hand_ik[s]
			w_side[s] = Rbx.damp(w_side[s], ik.w, 16 if (va != null or hg != null or rec != null or cc_rapido or cc_w > 0.05) else 7, dt)
			var wgt: float = w_side[s]
			if ik.has("cf"):
				# mano y muñeca exactas (sujeta el arma)
				var wrist_target: Vector3 = ((ik.cf as Transform3D) * Rbx.cfp(wrist_in_hand[s])).origin
				var res_c := solve(Lm, chest_cf, wrist_target, ik.pole, wgt)
				set_end(Lm, res_c[1], ik.cf, wgt)
			elif ik.has("wrist"):
				var res_w := solve(Lm, chest_cf, ik.wrist, ik.pole, wgt)
				if ik.has("rot"):
					set_end(Lm, res_w[1], Transform3D(ik.rot, Vector3.ZERO), wgt * float(ik.get("rot_w", 1.0)))
			else:
				# solo posición: la muñeca queda un poco antes del punto de agarre
				var sh := (chest_cf * Lm.top.c0).origin
				var dir: Vector3 = ik.pos - sh
				var wt: Vector3 = ik.pos - (dir.normalized() * 0.22 if dir.length() > 0.01 else Vector3.ZERO)
				var res_a := solve(Lm, chest_cf, wt, ik.pole, wgt)
				# mano plana sobre la superficie (palma abajo, dedos hacia delante)
				if ik.has("rot"):
					set_end(Lm, res_a[1], Transform3D(ik.rot, Vector3.ZERO), wgt * float(ik.get("rot_w", 1.0)))
		else:
			w_side[s] = Rbx.damp(w_side[s], 0, 8, dt)
		if s == "R" and moto_fuego and moto_apunta_k > 0.001 and moto_pose.size() == 5:
			# apuntando en la moto: el brazo derecho con la pose de Blender (FK: hombro, codo y muñeca), mezclada
			# con la de la IK (arma baja) mientras sube; la muñeca lleva además la pequeña corrección hacia la mira
			var k_m := moto_apunta_k
			Lm.top.transform = Transform3D(Basis(Quaternion(Lm.top.transform.basis.orthonormalized()).slerp(moto_pose[2], k_m)), Vector3.ZERO)
			Lm.mid.transform = Transform3D(Basis(Quaternion(Lm.mid.transform.basis.orthonormalized()).slerp(moto_pose[3], k_m)), Vector3.ZERO)
			var qw: Quaternion = (moto_pose[4] as Quaternion) * moto_corr_q
			Lm.fin.transform = Transform3D(Basis(Quaternion(Lm.fin.transform.basis.orthonormalized()).slerp(qw.normalized(), k_m)), Vector3.ZERO)
		# brazos suavizados
		# corriendo los brazos van rápidos: poco suavizado para no perder amplitud ni ir con retraso
		var arm_rate := lerpf(9.0, 14.0, run_arm)
		if tool != "" and hand_ik.has(s):
			arm_rate = 14.0 if s == "R" else 12.0
			# golpeando: los brazos siguen al arma sin retraso (si no, el arma se queda atrás y
			# atraviesa el cuerpo)
			if mel_t >= 0.0 or cc_rapido:
				arm_rate = 60.0
			elif draw_st != null or L.holster != null:
				# (la derecha lleva el arma: con retraso, el arma larga atajaba por dentro del pecho)
				arm_rate = 60.0 if s == "R" else 30.0
		if tool == "" and hand_ik.has(s) and cc_w > 0.05:
			arm_rate = 60.0 if cc_rapido else 18.0
		smooth_j(Lm.top, s + "Sh", arm_rate, dt)
		smooth_j(Lm.mid, s + "El", arm_rate, dt)
		smooth_j(Lm.fin, s + "Wr", arm_rate if tool != "" else 9.0, dt)
		# las manos y antebrazos nunca atraviesan paredes ni estructuras
		if pb < 0.5 and not (hand_ik.has(s) and w_side[s] > 0.3):
			_brazo_sin_choque(Lm, s, chest_cf)

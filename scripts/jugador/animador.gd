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
var last_prone_t := -9.0
var get_up = null
var air_start := 0.0
var jump_lead := "R"
var jump_run := 0.0
var air_fall := 0.0
var was_grounded = null
var rel_aim := 0.0
var feet_aim := 0.0
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
var correr_libre := false


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


func update_feet(root_cf: Transform3D, vel: Vector3, speed: float, dt: float, grounded: bool) -> void:
	var body_yaw := Rbx.yaw_of(root_cf)
	var yaw_cf := Rbx.ang(0, body_yaw, 0)
	var vel_h := Vector3(vel.x, 0, vel.z)
	var running := speed > 10
	# duración del vuelo de cada pie (andando ~0.33 s; el apoyo dura más que el vuelo, como al
	# andar de verdad). Corriendo, pasos rápidos con fase aérea
	var step_dur := clampf(0.36 - speed * 0.005, 0.25, 0.36)
	# corriendo el pie toca el suelo poco tiempo (no se queda atrás arrastrando la pierna)
	var run01 := clampf((speed - 7.0) / 6.0, 0, 1)
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
		for s in feet:
			var f: Dictionary = feet[s]
			f.pos = _ideal(frame, f, vel_h, lead, -lead)[0]
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
		if sw != null:
			sw.t += dt
			var u := clampf(sw.t / sw.dur, 0, 1)
			var idl := _ideal(frame, f, vel_h, lead, sw.dur - sw.t)
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
			var hz := Rbx.smooth(u)
			var kick := run01 * 0.75 * sin(PI * u)
			# bajando (escaleras, cuesta abajo) el talón no se dispara hacia arriba por detrás
			if rise < 0.0:
				kick *= clampf(1.0 + rise * 0.6, 0.15, 1.0)
			var p := _keep_side(frame, f, from_v.lerp(to, hz))
			f.cur = Vector3(p.x, from_v.y + rise * hu + arc * sin(PI * u) + kick, p.z)
			f.roll = Rbx.damp(f.get("roll", 0.0), 0.0, 12, dt)
			f.u = u
			# el pie gira en el aire hacia la nueva orientación del cuerpo
			var fy: float = sw.fromYaw if sw.fromYaw != null else body_yaw
			f.swingYaw = fy + Rbx.wrap_a(body_yaw - fy) * Rbx.smooth(u)
			if u >= 1:
				# el pie toca el suelo: pisada (ruido que oyen los zombis)
				if grounded:
					Ruido.emitir(jugador, to, Ruido.radio_paso(step_k, bool(sw.get("idle", false))), Ruido.PASO, jugador)
				f.pos = to
				f.normal = idl[1]
				f.swing = null
				f.cur = null
				f.u = null
				f.yaw = body_yaw
				f.swingYaw = null
	if not grounded:
		return
	# decidir el siguiente paso
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
		first.swing = {"from": first.pos, "t": 0.0, "dur": dur, "fromYaw": first.get("yaw") if first.get("yaw") != null else body_yaw, "idle": speed < 0.6}
	elif second.swing == null and ds > thr_s * 1.3 and can_second and first.swing == null:
		# en marcha, si este pie fue el último en dar el paso, le toca al otro (alternar siempre)
		var mover: Dictionary = second
		var mk := second_k
		if speed > 2.0 and float(step_start[second_k]) > float(step_start[first_k]) and can_first:
			mover = first
			mk = first_k
		_registrar_paso(mk, run01)
		mover.swing = {"from": mover.pos, "t": 0.0, "dur": 0.3 if speed < 0.6 else step_dur, "fromYaw": mover.get("yaw") if mover.get("yaw") != null else body_yaw, "idle": speed < 0.6}


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
	if f.get("u") != null:
		var u: float = f.u
		if u < 0.3:
			pitch = -0.55 * (1 - u / 0.3)          # despegue de puntera
		elif u > 0.65:
			pitch = 0.25 * (u - 0.65) / 0.35       # talón primero al apoyar
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
	if f.swing != null:
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
	# sin retraso (si no, la pelvis tendría que bajar mientras el pie termina de rodar)
	f.roll = prev + clampf(target - prev, -10 * dt, 10 * dt)


## suavizado de articulaciones: da peso e inercia al cuerpo (evita movimientos bruscos)
func smooth_j(m: RigPersonaje.Motor, key: String, rate: float, dt: float) -> void:
	if prev_t.has(key):
		m.transform = (prev_t[key] as Transform3D).interpolate_with(m.transform, 1 - exp(-rate * dt))
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
	solve(Lm, chest, target, (chest * Rbx.cf(sg * 1.8, -1.4, 0.8)).origin, 1.0)
	prev_t[s + "Sh"] = Lm.top.transform
	prev_t[s + "El"] = Lm.mid.transform


## Fase continua de la marcha: un oscilador que avanza al ritmo de los pasos y se sincroniza con el
## pie que está en el aire. Brazos y torso siguen esta onda suave en vez de seguir a saltos la
## posición de los pies (que se paran al apoyar y se disparan al dar el paso).
## sin(gait_ph) = +1 -> brazo derecho delante (pierna izquierda delante).
func _fase_marcha(speed: float, dt: float) -> void:
	var now := ahora()
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
		gait_ph += wrapf(float(target) - gait_ph, -PI, PI) * minf(1.0, dt * 5.0)
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
const LARGO_ARMA := {"Bate": 2.28, "Machete": 1.67, "Cuchillo": 0.98}


func _arma_fuera_del_cuerpo(h: Transform3D, tool: String, pelvis_cf: Transform3D, chest_cf: Transform3D) -> Transform3D:
	var largo: float = LARGO_ARMA.get(tool, 1.0)
	var grosor := 0.16 if tool == "Bate" else 0.1
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


## ---------------------------------------------------------------- eventos de armas (Anim.Fire)
func on_shot(w: String) -> void:
	if w == "Rifle":
		S.kick.impulse(3.2)
		S.kickRot.impulse(0.9)
	else:
		S.kick.impulse(4.5)
		S.kickRot.impulse(1.8)
	last_shot_t = ahora()


func on_reload(w: String, dur: float) -> void:
	if not Armas.recarga(w).is_empty():
		reload_st = {"w": w, "start": ahora(), "dur": dur, "fired": {}}


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
	if mdl == null or not mdl.has_node("Mag"):
		return
	var mag := mdl.get_node("Mag") as MeshInstance3D
	if ev == "drop":
		mag.visible = false
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = (mag.mesh as BoxMesh).size
		cs.shape = bx
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = mag.mesh
		mi.material_override = mag.material_override
		rb.add_child(mi)
		rb.mass = 0.3
		jugador.get_parent().add_child(rb)
		rb.global_transform = mag.global_transform
		rb.linear_velocity = Vector3(0, -6, 0) + jugador.vel_real
		rb.get_tree().create_timer(12.0).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())
	elif ev == "new":
		if hand_mag:
			hand_mag.queue_free()
		var m2 := MeshInstance3D.new()
		m2.mesh = mag.mesh
		m2.material_override = mag.material_override
		(P.LeftHand as Node3D).add_child(m2)
		m2.position = Vector3(0, -0.3, 0)
		hand_mag = m2
	elif ev == "insert":
		if hand_mag:
			hand_mag.queue_free()
			hand_mag = null
		mag.visible = true


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

	var pitch: float = L.pitch
	var aiming: bool = L.aiming
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
		va.sv = sin(PI * clampf((va.p - 0.1) / 0.75, 0, 1))
		va.pull = sin(PI * clampf((va.p - 0.08) / 0.82, 0, 1))
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

	if pb > 0.001:
		## -------- CUERPO A TIERRA, por fases (como una persona real):
		##  0.00-0.40  se agacha y apoya una rodilla en el suelo
		##  0.30-0.70  se inclina hacia delante y pone las manos en el suelo
		##  0.55-1.00  estira las piernas hacia atrás y se tumba boca abajo
		var kneel := sin(PI * clampf(pb / 0.8, 0, 1))
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
		# boca arriba: rodar sobre el eje de la columna (0 = boca abajo, 1 = boca arriba)
		var sup: bool = L.supine
		if pb < 0.98:
			sup = false
		roll_t = roll_t + clampf((1.0 if sup else 0.0) - roll_t, -dt / 0.75, dt / 0.75)
		var rlv := Rbx.smooth(roll_t)
		if roll_t <= 0.001 or roll_t >= 0.999:
			roll_side = L.rollSide
		var side := roll_side
		var ay0: float = L.yaw
		var over_head := absf(Rbx.wrap_a(ay0 - yaw)) < PI / 2
		var ca := crawl_amt * (1 - rlv)
		var roll := sin(ph) * 0.13 * ca + sin(now * 0.7) * 0.012
		var sway := sin(ph) * 0.09 * ca
		var tilt := -1.2 * lean * (1 - lay) - 1.54 * lay # pelvis: de inclinada a horizontal
		# al rodar, a mitad del giro el cuerpo queda de costado (el centro sube un poco)
		var lift := sin(PI * rlv) * 0.3
		Mr.transform = Rbx.cf(0, -drop + lift, 0) * Rbx.ang(tilt, sway * lay + sweep * (1 - rlv), roll * lay) * Rbx.ang(0, PI * rlv * side, 0)
		smooth_j(Mr, "Root", 9, dt)
		waistY -= sweep * 1.3 # el pecho se queda apuntando mientras la cadera barre
		pelvis_cf = fk(root_cf, Mr)
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			# tumbado: piernas algo abiertas, punteras hacia el suelo; al reptar la rodilla sube hacia el costado
			var up := maxf(0, sin(ph + (PI if s == "L" else 0.0))) * ca
			var Lg: Limb = leg[s]
			# boca arriba: rodillas flexionadas hacia arriba y pies apoyados
			var hip_down := Rbx.ang(0.12 * up, sgn * -0.12, sgn * (0.2 + 0.85 * up))
			var hip_up := Rbx.ang(0.55 + (0.15 if s == "L" else 0.0), 0, sgn * 0.18)
			Lg.top.transform = Transform3D.IDENTITY.interpolate_with(hip_down.interpolate_with(hip_up, rlv), lay)
			Lg.mid.transform = Transform3D.IDENTITY.interpolate_with(Rbx.ang((-0.12 - 1.35 * up) * (1 - rlv) - 1.1 * rlv, 0, 0), lay)
			Lg.fin.transform = Transform3D.IDENTITY.interpolate_with(Rbx.ang((-0.25 + 0.3 * up) * (1 - rlv) + 0.45 * rlv, sgn * 0.25 * (1 - rlv), 0), lay)
		# fase de rodilla: pose arrodillada por ángulos directos (rodilla izquierda al suelo, pie derecho plantado)
		var kw := minf(1, kneel * (1 - lay) * 1.6)
		if kw > 0.01:
			var kneel_pose := {
				"L": [Rbx.ang(0.25, 0, -0.08), Rbx.ang(-1.75, 0, 0), Rbx.ang(0.6, 0, 0)],
				"R": [Rbx.ang(1.35, 0, 0.1), Rbx.ang(-1.45, 0, 0), Rbx.ang(0.15, 0, 0)],
			}
			for s in ["L", "R"]:
				var Lg2: Limb = leg[s]
				var kp: Array = kneel_pose[s]
				Lg2.top.transform = Lg2.top.transform.interpolate_with(kp[0], kw)
				Lg2.mid.transform = Lg2.mid.transform.interpolate_with(kp[1], kw)
				Lg2.fin.transform = Lg2.fin.transform.interpolate_with(kp[2], kw)
		for s in ["L", "R"]:
			var Lg3: Limb = leg[s]
			smooth_j(Lg3.top, s + "Hip", 7, dt)
			smooth_j(Lg3.mid, s + "Knee", 7, dt)
			smooth_j(Lg3.fin, s + "Ankle", 7, dt)
		waistR += roll * 0.5 * lay
		waistY -= sway * 1.2 * lay
		# boca abajo: cabeza levantada. Boca arriba: barbilla al pecho para apuntar por encima de los pies,
		# o cabeza echada atrás si apunta por encima de la cabeza
		var sup_neck := -0.8
		var sup_waist := -0.35
		if over_head:
			sup_neck = 0.55
			sup_waist = 0.15
		waistP += (0.18 * (1 - rlv) + sup_waist * rlv) * lay - 0.35 * lean * (1 - lay)
		neckP += (1.3 * (1 - rlv) + sup_neck * rlv) * lay + 0.3 * lean * (1 - lay)
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
			S.leanP.target = clampf(-(fwd_speed * 0.011) - fwd_acc * 0.005, -0.36, 0.16)
			S.leanR.target = clampf(yaw_rate * speed * 0.004, -0.25, 0.25)
		else:
			S.leanP.target = -0.08
			S.leanR.target = 0.0
		var leanP: float = S.leanP.step(dt)
		var leanR: float = S.leanR.step(dt)
		# postura: tensión al apuntar, agotamiento, levantarse
		var ct := 0.22 if aiming else 0.0
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

		# rebote, giro y caída de cadera con cada paso
		for s in feet:
			var f: Dictionary = feet[s]
			if f.get("u") != null:
				var sw := sin(PI * f.u)
				bob += sw * (0.05 + speed_f * 0.1)
				pelvis_yaw += f.side * -0.16 * speed_f * sw
				pelvis_roll += f.side * 0.05 * sw
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
		pelvis_drop = Rbx.damp(pelvis_drop, clampf(need, 0, 0.6), 20.0 if need > pelvis_drop else 12.0, dt)
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
		if not grounded and va == null:
			# SALTO por fases: despegue (la pierna de impulso aún estirada), vuelo (carrera: rodilla
			# delantera arriba y pierna trasera atrás; parado: las dos rodillas recogidas) y
			# caída (las piernas bajan y se adelantan para recibir el suelo)
			pelvis_drop = Rbx.damp(pelvis_drop, 0, 6, dt)
			if was_grounded != false:
				air_start = now
				jump_lead = "R" if feet.R.swing != null else ("L" if feet.L.swing != null else ("R" if randf() < 0.5 else "L"))
				jump_run = clampf((speed - 4) / 8, 0, 1)
				air_runoff = jugador.estado != "Jumping"
			var run := jump_run
			var fall := clampf((3 - vel.y) / 16, 0, 1)
			var ext := clampf((now - air_start) / 0.13, 0, 1)
			for s in feet:
				var f: Dictionary = feet[s]
				var is_lead: bool = s == jump_lead
				var upY := -leg_len * ((0.6 - 0.06 * run) if is_lead else (0.66 + 0.18 * run))
				var upZ := (-0.3 - 0.45 * run) if is_lead else (-0.1 + 0.95 * run)
				var dnY := -leg_len * (0.84 if is_lead else 0.9)
				var dnZ := -0.4 if is_lead else -0.05
				var y := upY + (dnY - upY) * fall
				var z := upZ + (dnZ - upZ) * fall
				if air_runoff and run > 0.3:
					# salir corriendo de un borde: las piernas siguen la zancada (una delante y otra
					# detrás, alternando) en vez de juntarse; al caer mucho se preparan para aterrizar
					var fw: float = sin(gait_ph) * (1.0 if s == "L" else -1.0)
					var ry := -leg_len * 0.9 + 0.5 * maxf(0.0, fw) + 0.35 * maxf(0.0, -fw)
					var rz := -0.95 * fw
					var w_dn := clampf((fall - 0.55) / 0.45, 0, 1) * 0.6
					y = lerpf(ry, dnY, w_dn)
					z = lerpf(rz, dnZ, w_dn)
				elif ext < 1:
					y = -leg_len * 0.96 + (y + leg_len * 0.96) * Rbx.smooth(ext)
				# caída larga: pedalea en el aire
				if vel.y < -18:
					var ph2 := now * 9 + (PI if s == "L" else 0.0)
					y += sin(ph2) * 0.35
					z += cos(ph2) * 0.45
				leg_targets[s] = (yaw_only * Rbx.cf(f.side * hip_x * (1 + 0.35 * fall), y - 0.1, z)).origin
			pelvis_pitch += 0.1 * run * (1 - fall) - 0.06 * fall
			waistP += -0.14 * run * (1 - fall) + 0.08 * (1 - fall) * (1 - run) - 0.1 * fall
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
		pelvis_pitch += leanP * 0.35
		# ladeo: la cadera compensa hacia el lado contrario, el torso se inclina y la cabeza se
		# endereza un poco (como al asomarse por una esquina)
		pelvis_roll -= ln * 0.08
		waistR -= ln * 0.4
		neckR += ln * 0.24
		# acometida del golpe: la cadera avanza, baja un poco y gira con los hombros
		Mr.transform = Rbx.cf(-ln * 0.14, -pelvis_drop + bob - crouch - absf(ln) * 0.06 - mel_lunge * 0.22, -mel_lunge * 0.35) * Rbx.ang(pelvis_pitch, pelvis_yaw + mel_twist * 0.35, pelvis_roll + leanR * 0.3)
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
				var wT := Rbx.smooth(clampf(p / 0.2, 0, 1))
				var wL := Rbx.smooth(clampf((p - 0.66) / 0.26, 0, 1))
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
				var wS := Rbx.smooth(clampf((p - 0.12) / 0.2, 0, 1))
				for s in ["L", "R"]:
					var sgn := -1.0 if s == "L" else 1.0
					var scr := maxf(0, sin(p * 22 + (PI if s == "L" else 0.0))) * 0.45 * (1 - clampf((p - 0.4) / 0.2, 0, 1))
					var wall_f := Vector3(face_p.x, 0, face_p.z) + rv * (sgn * 0.4)
					var wy := minf(hip_p.y - leg_len * 0.78 + scr, va.topY - 0.2)
					wall_f = Vector3(wall_f.x, maxf(wy, va.feetY + 0.15), wall_f.z)
					var t0 := 0.42 if s == "R" else 0.6
					var w_up := Rbx.smooth(clampf((p - t0) / 0.24, 0, 1))
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
		for s in ["L", "R"]:
			var sgn := -1.0 if s == "L" else 1.0
			var off_s := 0.0 if s == "L" else PI
			var paso_h := sin(ph_h + off_s)
			# quieto: las piernas no cuelgan rígidas; una rodilla algo más doblada que la otra y un
			# pequeño vaivén lento (buscando apoyo con la punta del pie en la pared)
			var reposo := sin(now * 0.8 + off_s * 0.7) * 0.5 + 0.5
			var lat_h := sgn * hip_x * 1.1 + mv_h * 0.35 * paso_h + sin(now * 0.6 + off_s) * 0.06
			var alto_h := -leg_len * (0.84 - 0.1 * reposo * (1.0 - absf(mv_h))) + maxf(0.0, -paso_h) * 0.45 * absf(mv_h)
			var hacia_pared := 0.55 + 0.2 * reposo * (1.0 - absf(mv_h)) + 0.15 * maxf(0.0, paso_h) * absf(mv_h)
			leg_targets[s] = hip_c + r_h * lat_h - n_h * hacia_pared + Vector3(0, alto_h, 0)
		leg_targets.poleL = hip_c - n_h * 3.0 - r_h * hip_x + Vector3(0, 0.5, 0)
		leg_targets.poleR = hip_c - n_h * 3.0 + r_h * hip_x + Vector3(0, 0.5, 0)
		# torso: cuelga de los brazos (algo arqueado hacia la pared), respira con esfuerzo y se mece
		var resp_h := sin(now * 2.6) * 0.03
		waistP += 0.08 + resp_h
		waistR += sin(now * 0.7) * 0.04 - mv_h * 0.06
		waistY += sin(now * 0.5) * 0.05
		neckP += 0.22 - resp_h
		neckY += sin(now * 0.37) * 0.12 + mv_h * 0.25 # mira hacia donde va


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

	# piernas por IK
	for s in ["L", "R"]:
		var Lg: Limb = leg[s]
		if leg_targets.has(s):
			var target: Vector3 = leg_targets[s]
			var pole: Vector3 = leg_targets.poleL if s == "L" else leg_targets.poleR
			var f: Dictionary = feet[s]
			# la pierna que da el paso nunca va estirada en el aire (sobre todo al correr, girar o ir
			# de lado): la rodilla se dobla y solo se estira al final para apoyar el talón
			if grounded and va == null and pb < 0.01 and f.swing != null and f.get("u") != null:
				var hip_w := (pelvis_cf * Lg.top.c0).origin
				var lim := leg_len * lerpf(0.86, 0.99, Rbx.smooth((f.u - 0.6) / 0.4))
				var off := target - hip_w
				if off.length() > lim:
					target = hip_w + off.normalized() * lim
			var res := solve(Lg, pelvis_cf, target, pole)
			# la pierna en el aire no atraviesa muros ni mesas: si la rodilla, la espinilla o la
			# punta del pie chocan con una superficie vertical, el pie se retrasa hasta quedar fuera
			if grounded and va == null and pb < 0.01 and f.swing != null:
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
			if not grounded:
				set_end(Lg, lower, Rbx.cfp(target) * yaw_cf * Rbx.ang(-0.3, 0, 0))
			else:
				set_end(Lg, lower, foot_cf(f, yaw))
			# justo después de levantarse: mezclar desde la pose de tumbado (sin saltos);
			# el resto del tiempo solo se registra la pose para que el paso a tumbado parta de ella
			var recent := now - last_prone_t < 0.6
			for pair in [[Lg.top, "Hip"], [Lg.mid, "Knee"], [Lg.fin, "Ankle"]]:
				if recent:
					smooth_j(pair[0], s + pair[1], 12, dt)
				else:
					prev_t[s + pair[1]] = (pair[0] as RigPersonaje.Motor).transform

	## ------------------------------------------------ torso provisional (para calcular el pecho)
	var Mw: RigPersonaje.Motor = M.Waist
	Mw.transform = Rbx.ang(0, waistY, 0) * Rbx.ang(waistP + breath, 0, waistR)
	var chest_cf := fk(pelvis_cf, Mw)
	var chest_yaw_base := Rbx.cfp(chest_cf.origin) * yaw_cf
	# tumbado: el torso y la cabeza cubren la diferencia hasta que el cuerpo termina de pivotar
	var prone_aim := pb > 0.5
	rel_aim = Rbx.damp(rel_aim, 0, 3.5 if prone_aim else 5.0, dt)
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
	if pb < 0.5:
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
		run_arm = maxf(run_arm, run_k)
		# por delante la mano cruza un poco hacia el centro del pecho (sin pasar de la línea media)
		arm_t[s] = {"sh": Rbx.ang(swing + 0.06 * run_k, -sgn_a * 0.28 * run_k * maxf(0.0, a_run), abd), "el": Rbx.ang(elbow, 0, 0)}
	# torso de carrera: los hombros giran con los brazos (contrarios a la pelvis), el pecho se
	# inclina hacia delante y la cabeza se mantiene estable mirando al frente
	if run_arm > 0.0 and grounded and va == null:
		var tw: float = 0.2 * run_arm * (float(arm_a.R) - float(arm_a.L)) * 0.5
		waistY += tw
		neckY -= tw * 0.85
		waistP -= 0.1 * run_arm
		neckP += 0.08 * run_arm
		waistR += 0.04 * run_arm * (float(arm_a.R) - float(arm_a.L)) * 0.5
		# el pecho se mece con cada zancada (dos veces por ciclo) y la cabeza lo compensa
		waistP += 0.035 * run_arm * cos(2.0 * gait_ph)
		neckP -= 0.03 * run_arm * cos(2.0 * gait_ph)
	elif gait_amp > 0.05 and grounded and va == null:
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
				var R := Armas.recarga(reload_st.w)
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
				speed_pose = 9.0
			elif firing_recent or L.firing:
				target_rel = Rbx.ang(pc, 0, 0) * Armas.pose(tool, "HIP")
				speed_pose = 11.0
			else:
				target_rel = Rbx.ang(pc * 0.35, 0, 0) * Armas.pose(tool, "LOW")
				speed_pose = 4.5
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
		var amp := 0.06 if tool == "Rifle" else (0.12 if tool == "Bate" else 0.32)
		swing_arma = Rbx.damp(swing_arma, float(arm_a.R) * amp * libre_k, 12, dt)
		var piv := Vector3(0.92, 0.51, 0)
		var swing_t := Rbx.cfp(piv) * Rbx.ang(swing_arma, 0, 0) * Rbx.cfp(-piv)
		var handle_cf: Transform3D = aim_base * Rbx.cfp(sway) * swing_t * pose_rel * Rbx.cf(0, 0, kick * 0.06) * Rbx.ang(kick_rot * 0.05, 0, 0)
		# CORRER con pistola o arma blanca de una mano: el brazo bombea como al correr sin arma
		# (la muñeca inclina el arma hacia abajo); el bate va al hombro
		correr_libre = sprinting and grounded and va == null and pb < 0.5 and libre_k > 0.5 and tool in ["Pistola", "Cuchillo", "Machete"] \
			and draw_st == null and L.holster == null

		# SACAR / GUARDAR el arma: la mano va a por ella donde se lleva (muslo, espalda, pecho,
		# mochila), la saca siguiendo un recorrido natural y la lleva a la posición de uso; al
		# guardarla hace el camino inverso
		var support_w := 1.0
		var spot := Armas.holster(tool)
		var spot_part: Node3D = P.get(spot.get("Part", ""))
		var D := Armas.draw(tool)
		var holster_t = null
		if L.holster != null and L.holster.name == tool:
			holster_t = (now - float(L.holster.t0)) / Armas.HOLSTER_TIME
		if spot_part and not D.is_empty():
			var holster_w: Transform3D = spot_part.global_transform * spot.CF
			var mid_w: Transform3D = chest_yaw_base * D.mid
			if holster_t != null:
				draw_st = null
				var back := 0.72
				if holster_t < back:
					var u := Rbx.smooth(clampf(holster_t / back, 0, 1))
					handle_cf = handle_cf.interpolate_with(mid_w, u).interpolate_with(mid_w.interpolate_with(holster_w, u), u)
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
						handle_cf = holster_w.interpolate_with(mid_w, u3).interpolate_with(mid_w.interpolate_with(handle_cf, u3), u3)
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
		# mano derecha: la que sostiene el arma
		var hand_cf: Transform3D = handle_cf * Armas.grip(tool) * Armas.grip_att().affine_inverse()
		# codo: de pie hacia abajo y atrás; tumbado hacia fuera y delante
		var pole_r := (aim_base * Rbx.cf(1.7, -0.7, -0.3)).origin if pb > 0.5 else (aim_base * Rbx.cf(1.9, -1.4, 0.9)).origin
		if not correr_libre:
			hand_ik.R = {"cf": hand_cf, "pole": pole_r, "w": 1.0}
		waistP += kick_rot * 0.012

		# mano izquierda
		var support: Node3D = null
		if mdl:
			support = mdl.get_node_or_null("LeftGrip")
			if support == null:
				support = mdl.get_node_or_null("SupportGrip")
		var pole_l := (aim_base * Rbx.cf(-1.7, -0.7, -0.3)).origin if pb > 0.5 else (chest_yaw_base * Rbx.cf(-1.9, -1.5, 0.3)).origin
		if reloading and mdl:
			var R2 := Armas.recarga(reload_st.w)
			var t4: float = (now - float(reload_st.start)) * (float(R2.dur) / float(reload_st.dur))
			var refs := {"grip": support.position if support else Vector3.ZERO}
			for k in [["mag", "MagBottom"], ["charge", "ChargingHandle"], ["slide", "SlideRear"]]:
				var nd := mdl.get_node_or_null(k[1])
				refs[k[0]] = (nd as Node3D).position if nd else Vector3.ZERO
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
		elif support:
			var one_handed: bool = (tool == "Pistola" and sprinting and not aiming) or (kind == "Melee" and tool != "Bate")
			if not one_handed:
				hand_ik.L = {"pos": handle_cf * support.position, "pole": pole_l, "w": support_w}
				left_free = false
		waistP += (pc * 0.35 if kind == "Gun" else pc * 0.12)
		neckP += (pc * 0.35 if kind == "Gun" else pc * 0.2)
		if tool == "Rifle" and not sprinting:
			blade = Rbx.damp(blade, 0.4 if aiming else 0.25, 8, dt)
			if aiming:
				neckP -= 0.12
				neckR -= 0.1
		else:
			blade = Rbx.damp(blade, 0.0, 8, dt)
		waistY -= blade
		neckY += blade * 0.9
	waistP += melee_lean
	J.arsenal.mostrar(tool_shown)

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
	# boca arriba sin arma: manos sobre el abdomen (con arma, las manos siguen al arma)
	if rl_now > 0.5:
		for s in ["L", "R"]:
			if (s == "L" and not left_free) or (s == "R" and not right_free):
				continue
			var sgn := -1.0 if s == "L" else 1.0
			hand_ik[s] = {"pos": (chest_cf * Rbx.cf(sgn * 0.22, -0.45, -0.5)).origin, "pole": (chest_cf * Rbx.cf(sgn * 1.4, 0, 0.6)).origin, "w": rl_now}
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
				var lat := 0.62 + 0.3 * clampf((reach2 + 1.0) / 0.3, 0, 1)
				var base3 := (chest_yaw_base * Rbx.cf(sgn * lat, 0, reach2)).origin
				var gy3: float = ground(base3)[0]
				# la mano se levanta un poco al avanzar
				var lift2 := maxf(0, cos(crawl + (0.0 if s == "L" else PI))) * 0.18 * ca2
				hand_ik[s] = {"pos": Vector3(base3.x, gy3 + 0.18 + lift2, base3.z), "pole": (chest_yaw_base * Rbx.cf(sgn * 1.5, -0.3, 0.4)).origin, "w": hands_down}
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
	Mn.transform = Rbx.ang(0, neckY, 0) * Rbx.ang(neckP - breath * 0.5, 0, neckR)
	smooth_j(Mw, "Waist", 6.0 if pb > 0.01 else (30.0 if mel_t >= 0.0 else 10.0), dt)
	smooth_j(Mn, "Neck", 7, dt)
	chest_cf = fk(pelvis_cf, Mw)
	for s in ["L", "R"]:
		var Lm: Limb = arm[s]
		Lm.top.transform = arm_t[s].sh
		Lm.mid.transform = arm_t[s].el
		Lm.fin.transform = Transform3D.IDENTITY
		if s == "R" and correr_libre:
			# muñeca: la pistola apunta al suelo por delante; el cuchillo y el machete, hacia abajo
			var wp := -1.15 if tool == "Pistola" else (-0.6 if tool == "Cuchillo" else -1.25)
			Lm.fin.transform = Rbx.ang(wp, 0, 0)
		if hand_ik.has(s):
			var ik: Dictionary = hand_ik[s]
			w_side[s] = Rbx.damp(w_side[s], ik.w, 16 if (va != null or hg != null or rec != null) else 7, dt)
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
		# brazos suavizados
		# corriendo los brazos van rápidos: poco suavizado para no perder amplitud ni ir con retraso
		var arm_rate := lerpf(9.0, 14.0, run_arm)
		if tool != "" and hand_ik.has(s):
			arm_rate = 14.0 if s == "R" else 12.0
			# golpeando: los brazos siguen al arma sin retraso (si no, el arma se queda atrás y
			# atraviesa el cuerpo)
			if mel_t >= 0.0:
				arm_rate = 60.0
			elif draw_st != null or L.holster != null:
				arm_rate = 30.0
		smooth_j(Lm.top, s + "Sh", arm_rate, dt)
		smooth_j(Lm.mid, s + "El", arm_rate, dt)
		smooth_j(Lm.fin, s + "Wr", arm_rate if tool != "" else 9.0, dt)
		# las manos y antebrazos nunca atraviesan paredes ni estructuras
		if pb < 0.5 and not (hand_ik.has(s) and w_side[s] > 0.3):
			_brazo_sin_choque(Lm, s, chest_cf)

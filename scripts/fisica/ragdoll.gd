class_name Ragdoll
extends Node3D
## RAGDOLL ACTIVO (estilo GTA IV / Euphoria), port del "Euphoria" del juego de Roblox.
## Sirve para cualquier muñeco R15 (RigPersonaje): jugador, zombis y maniquíes.
##
## Cada pieza del cuerpo pasa a ser un RigidBody3D, unido a su padre con una articulación con límites
## anatómicos (rótula = ConeTwistJoint3D; codo y rodilla = HingeJoint3D). En cada articulación hay un
## "músculo": un par de fuerzas (PD) que lleva la articulación hacia una postura objetivo con cierta fuerza.
## La postura y la fuerza las decide el COMPORTAMIENTO, según la situación:
##   caer         derribado / sale despedido: brazos hacia el suelo para protegerse, las piernas ceden,
##                la cabeza se aparta del golpe. Al pararse en el suelo pasa a "retorcerse".
##   caida_libre  caída larga: agita los brazos y pedalea; al acercarse al suelo se prepara (brazos y
##                rodillas) para el impacto.
##   impacto      golpe contra el suelo: un instante sin fuerza y luego aturdido se retuerce (más débil
##                cuanto peor fue el golpe).
##   retorcerse   en el suelo con dolor: se sujeta la herida, encoge las piernas, levanta la cabeza.
##   morir        se agarra la herida, le fallan las rodillas, cae, se retuerce cada vez más débil y
##                queda inerte (con algún espasmo).
##   inerte       sin fuerza.
##
## Uso:  var r := Ragdoll.iniciar(dueno, rig, velocidad, {"comportamiento": "caer", "impulso": v, ...})
##       señales: impacto(velocidad) cuando el cuerpo se estrella; recuperado() cuando se para tras
##       "duracion" segundos (el dueño decide cómo levantarse y llama a terminar(mezcla)).
## Mientras dura, el rig va suelto (top_level) y sus articulaciones las escribe este nodo; al terminar,
## mezcla la postura del ragdoll con la animación del dueño durante "mezcla" segundos.
## Capa de colisión 16 (ragdolls): chocan con el escenario (1), los cuerpos (4) y otros ragdolls (16).

signal impacto(velocidad: float)
signal recuperado

const CAPA := 16
const MASCARA := 1 | 4 | 16
const MAX_ACTIVOS := 12          # ragdolls simulándose a la vez (los más viejos y quietos se congelan)
static var activos: Array = []

## articulación -> [tipo, cono/rango (grados), giro (grados), fuerza base, grupo]
const ART := {
	"Waist": ["bola", 35.0, 30.0, 1.0, "core"],
	"Neck": ["bola", 50.0, 55.0, 0.55, "neck"],
	"LeftShoulder": ["bola", 95.0, 70.0, 0.5, "arm"],
	"RightShoulder": ["bola", 95.0, 70.0, 0.5, "arm"],
	"LeftElbow": ["bisagra", 74.0, 0.0, 0.42, "arm"],
	"RightElbow": ["bisagra", 74.0, 0.0, 0.42, "arm"],
	"LeftWrist": ["bola", 50.0, 40.0, 0.22, "arm"],
	"RightWrist": ["bola", 50.0, 40.0, 0.22, "arm"],
	"LeftHip": ["bola", 68.0, 35.0, 0.9, "leg"],
	"RightHip": ["bola", 68.0, 35.0, 0.9, "leg"],
	"LeftKnee": ["bisagra", 71.0, 0.0, 0.75, "leg"],
	"RightKnee": ["bisagra", 71.0, 0.0, 0.75, "leg"],
	"LeftAnkle": ["bola", 30.0, 20.0, 0.35, "leg"],
	"RightAnkle": ["bola", 30.0, 20.0, 0.35, "leg"],
}
## postura en la que se crean las articulaciones = centro de su rango de movimiento (los límites de Godot
## se miden desde la postura de creación): caderas y hombros algo adelantados, codos y rodillas a media
## flexión (así el codo va de 0 a ~150° y la rodilla de 0 a ~-143°)
const CENTRO := {
	"LeftShoulder": Vector3(0.5, 0.0, -0.35), "RightShoulder": Vector3(0.5, 0.0, 0.35),
	"LeftElbow": Vector3(1.29, 0.0, 0.0), "RightElbow": Vector3(1.29, 0.0, 0.0),
	"LeftHip": Vector3(0.6, 0.0, -0.1), "RightHip": Vector3(0.6, 0.0, 0.1),
	"LeftKnee": Vector3(-1.24, 0.0, 0.0), "RightKnee": Vector3(-1.24, 0.0, 0.0),
	"Waist": Vector3(0.05, 0.0, 0.0),
}
const KP := 520.0               # rigidez de los músculos (rad/s² por radian) a fuerza 1
const ACEL_MAX := 260.0         # tope de aceleración angular de un músculo (estabilidad)

var dueno: Node3D
var rig: RigPersonaje
var cuerpos := {}               # pieza -> RigidBody3D
var _uniones: Array[Joint3D] = []
var _inercia := {}              # pieza -> inercia aproximada
var comportamiento := "caer"
var vivo := true
var duracion := 2.0             # s mínimos antes de poder recuperarse (-1 = nunca: muerto)
var gravedad := 0.5             # 0..1 lo grave que fue (impacto)
var fuerza_mult := 1.0
var lado_herida := 1.0
var _t := 0.0
var _t_comp := 0.0
var _semilla := 0.0
var _fase := 0                  # 0 = creado en la postura central (congelado), 1 = simulando
var _pose_real := {}            # pieza -> Transform3D (postura con la que empieza)
var _vel0 := Vector3.ZERO
var _giro0 := Vector3.ZERO
var _impulso := Vector3.ZERO
var _pieza_golpe := "UpperTorso"
var _v_prev := Vector3.ZERO
var _golpe_t := -9.0
var _caida_max := 0.0
var _ultimo_valor := 0.0
var _ultimo_impacto := -9.0
var _quieto_t := 0.0
var _avisado := false
var _congelado := false
var _rig_top0 := false
var _rig_local0 := Transform3D.IDENTITY
var _dist_suelo := 99.0
# mezcla final con la animación del dueño
var _mezcla := -1.0
var _mezcla_dur := 0.3
var _mezcla_t := 0.0
var _final_motores := {}
var _final_raiz := Transform3D.IDENTITY


## crea el ragdoll del rig "r" de "d". vel = velocidad del cuerpo. opciones: comportamiento, vivo, duracion,
## impulso (cambio de velocidad en la pieza golpeada), pieza, giro (velocidad angular), gravedad
static func iniciar(d: Node3D, r: RigPersonaje, vel: Vector3, opciones := {}) -> Ragdoll:
	var rd := Ragdoll.new()
	rd.name = "Ragdoll"
	rd.dueno = d
	rd.rig = r
	rd.comportamiento = opciones.get("comportamiento", "caer")
	rd.vivo = opciones.get("vivo", true)
	rd.duracion = float(opciones.get("duracion", 2.0))
	rd.gravedad = float(opciones.get("gravedad", 0.5))
	rd._vel0 = vel
	rd._giro0 = opciones.get("giro", Vector3.ZERO)
	rd._impulso = opciones.get("impulso", Vector3.ZERO)
	rd._pieza_golpe = opciones.get("pieza", "UpperTorso")
	rd._semilla = randf() * 100.0
	d.add_child(rd)
	rd._construir()
	activos.append(rd)
	_limitar_activos()
	return rd


## muchos ragdolls a la vez: se congelan los más antiguos que ya están quietos (cadáveres)
static func _limitar_activos() -> void:
	var vivos := activos.filter(func(a): return is_instance_valid(a) and not a._congelado and a._mezcla < 0.0)
	if vivos.size() <= MAX_ACTIVOS:
		return
	for a in vivos:
		if vivos.size() <= MAX_ACTIVOS:
			break
		if not a.vivo:
			a._congelar()
			vivos.erase(a)


func _ready() -> void:
	process_physics_priority = -10 # los músculos antes del paso de física


## ---------------------------------------------------------------- construcción
func _construir() -> void:
	# postura real (la de la animación ahora mismo)
	rig.aplicar()
	for n in rig.P:
		if n != "HumanoidRootPart":
			_pose_real[n] = (rig.P[n] as Node3D).global_transform
	# postura central de las articulaciones (solo para crearlas; no llega a verse)
	var guardado := {}
	for mn in rig.M:
		var m: RigPersonaje.Motor = rig.M[mn]
		guardado[mn] = m.transform
		var c: Vector3 = CENTRO.get(mn, Vector3.ZERO)
		m.transform = Transform3D(Rbx.angb(c.x, c.y, c.z), Vector3.ZERO) if mn != "Root" else m.transform
	rig.aplicar()
	var centro := {}
	for n in rig.P:
		if n != "HumanoidRootPart":
			centro[n] = (rig.P[n] as Node3D).global_transform
	for mn in guardado:
		(rig.M[mn] as RigPersonaje.Motor).transform = guardado[mn]
	rig.aplicar()
	# el rig va suelto mientras dure el ragdoll (lo coloca este nodo)
	_rig_top0 = rig.top_level
	_rig_local0 = rig.transform
	var g_rig := rig.global_transform
	rig.top_level = true
	rig.global_transform = g_rig
	# cuerpos rígidos
	var mat := PhysicsMaterial.new()
	mat.friction = 0.85
	mat.bounce = 0.05
	for n in centro:
		var tam: Vector3 = (rig.P[n] as Node3D).get_meta("size")
		var b := RigidBody3D.new()
		b.name = "C_" + n
		b.top_level = true
		b.transform = centro[n]
		b.mass = maxf(0.05, tam.x * tam.y * tam.z * (0.6 if n == "Head" else 1.0))
		b.physics_material_override = mat
		b.linear_damp = 0.08
		b.angular_damp = 0.6
		b.continuous_cd = true
		b.collision_layer = 0
		b.collision_mask = 0
		b.freeze = true
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = tam * 0.94
		cs.shape = bx
		b.add_child(cs)
		add_child(b)
		cuerpos[n] = b
		var l := maxf(tam.x, maxf(tam.y, tam.z))
		_inercia[n] = b.mass * l * l / 6.0
	# articulaciones (en la postura central)
	for mn in ART:
		var m: RigPersonaje.Motor = rig.M[mn]
		var pa: RigidBody3D = cuerpos[m.part0]
		var hi: RigidBody3D = cuerpos[m.part1]
		hi.add_collision_exception_with(pa)
		var t_pa: Transform3D = centro[m.part0]
		var pivote: Vector3 = (t_pa * m.c0).origin
		var def: Array = ART[mn]
		var j: Joint3D
		var base: Basis
		if def[0] == "bola":
			var hueso: Vector3 = ((centro[m.part1] as Transform3D).origin - pivote)
			if hueso.length() < 0.01:
				hueso = -(t_pa.basis.y)
			var x := hueso.normalized()
			var y := x.cross(t_pa.basis.z)
			if y.length() < 0.1:
				y = x.cross(t_pa.basis.x)
			y = y.normalized()
			base = Basis(x, y, x.cross(y).normalized())
			var ct := ConeTwistJoint3D.new()
			ct.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(def[1]))
			ct.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(def[2]))
			j = ct
		else:
			# bisagra: gira alrededor del eje X del padre (como el codo y la rodilla del rig)
			var z := t_pa.basis.x.normalized()
			var x2 := t_pa.basis.y.normalized()
			base = Basis(x2, z.cross(x2).normalized(), z)
			var hj := HingeJoint3D.new()
			hj.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			hj.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-def[1]))
			hj.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(def[1]))
			j = hj
		j.name = "J_" + mn
		j.top_level = true
		j.transform = Transform3D(base.orthonormalized(), pivote)
		j.node_a = NodePath("../" + pa.name)
		j.node_b = NodePath("../" + hi.name)
		j.exclude_nodes_from_collision = true
		add_child(j)
		_uniones.append(j)


## primer paso de física: de la postura central a la real, con su velocidad
func _arrancar() -> void:
	var c_torso: Vector3 = (_pose_real["UpperTorso"] as Transform3D).origin
	for n in cuerpos:
		var b: RigidBody3D = cuerpos[n]
		b.global_transform = _pose_real[n]
		b.collision_layer = CAPA
		b.collision_mask = MASCARA
		b.freeze = false
		b.linear_velocity = _vel0 + _giro0.cross((_pose_real[n] as Transform3D).origin - c_torso)
		b.angular_velocity = _giro0
	if _impulso.length() > 0.01:
		var bp: RigidBody3D = cuerpos.get(_pieza_golpe, cuerpos.UpperTorso)
		bp.apply_central_impulse(_impulso * bp.mass)
		var bt: RigidBody3D = cuerpos.UpperTorso
		bt.apply_central_impulse(_impulso * 0.35 * bt.mass)
		# par que desequilibra el cuerpo en la dirección del golpe (de espaldas / de bruces / de lado)
		var plano := Vector3(_impulso.x, 0, _impulso.z)
		if plano.length() > 0.5:
			var eje := Vector3.UP.cross(plano.normalized())
			bt.apply_torque_impulse(eje * minf(plano.length(), 60.0) * _inercia.UpperTorso * 0.9)
		var lp := bt.global_transform.affine_inverse() * bp.global_position
		lado_herida = 1.0 if lp.x >= 0.0 else -1.0
	_v_prev = _vel_centro()
	_fase = 1


## ---------------------------------------------------------------- consultas
func pelvis() -> Vector3:
	return (cuerpos.LowerTorso as RigidBody3D).global_position


func torso() -> RigidBody3D:
	return cuerpos.UpperTorso


func velocidad() -> float:
	return (cuerpos.UpperTorso as RigidBody3D).linear_velocity.length()


## boca arriba (el pecho mira al cielo)
func boca_arriba() -> bool:
	# (el pecho mira hacia -Z de la pieza: boca arriba si -Z apunta hacia arriba)
	return torso().global_transform.basis.z.y < 0.0


## hacia dónde apunta la cabeza a lo largo del suelo (para levantarse mirando hacia ahí)
func direccion_cabeza() -> Vector3:
	var d := Rbx.flat((cuerpos.Head as RigidBody3D).global_position - pelvis())
	if d.length() < 0.2:
		d = Rbx.flat(-torso().global_transform.basis.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func cambiar(nuevo: String, t_desfase := 0.0) -> void:
	if comportamiento == nuevo:
		return
	comportamiento = nuevo
	_t_comp = t_desfase


## golpe sobre el cuerpo ya caído (balas, patadas): sacude la pieza
func golpe(pieza: String, impulso: Vector3) -> void:
	if not cuerpos.has(pieza):
		pieza = "UpperTorso"
	if _congelado:
		_descongelar()
	var b: RigidBody3D = cuerpos[pieza]
	b.apply_central_impulse(impulso * maxf(b.mass, 0.3))
	_quieto_t = 0.0


func morir() -> void:
	vivo = false
	duracion = -1.0
	if comportamiento != "morir":
		cambiar("morir", 1.2 if comportamiento in ["retorcerse", "impacto"] else 0.0)


## ---------------------------------------------------------------- simulación
func _physics_process(dt: float) -> void:
	if _mezcla >= 0.0 or _congelado:
		return
	if _fase == 0:
		_arrancar()
		return
	_t += dt
	_t_comp += dt
	var bt: RigidBody3D = torso()
	var v := _vel_centro()
	# golpes del cuerpo contra algo: frenazo brusco del torso (suelo, pared, coche...)
	# (cayendo: la velocidad de caída máxima; el golpe es cuando el torso se frena de golpe)
	var dv := (v - _v_prev).length()
	if v.y < 0.0:
		_caida_max = maxf(_caida_max, -v.y)
	var choque := dv
	if _caida_max > 8.0 and v.y > -_caida_max * 0.35:
		choque = maxf(choque, _caida_max)
		_caida_max = 0.0
	if choque > 9.0 and _t > 0.08 and _t - _golpe_t > 0.25:
		_golpe_t = _t
		var k := clampf((choque - 7.0) / 22.0, 0.12, 1.0)
		Efectos.sonido(dueno, "Blunt", bt.global_position, 0.35 + 0.8 * k, 0.55 + randf() * 0.15)
	# (un golpe mayor que el anterior siempre cuenta, aunque haya sido hace nada)
	if choque > 12.0 and _t > 0.25 and (_t - _ultimo_impacto > 0.6 or choque > _ultimo_valor * 1.3):
		_ultimo_impacto = _t
		_ultimo_valor = choque
		impacto.emit(choque)
	_v_prev = v
	# distancia al suelo (para prepararse antes de caer)
	var q := PhysicsRayQueryParameters3D.create(bt.global_position, bt.global_position + Vector3(0, -60, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	_dist_suelo = maxf(0.0, bt.global_position.distance_to(r.position) - 1.2) if not r.is_empty() else 99.0
	# transiciones automáticas
	if comportamiento == "caer" and _t_comp > 0.8 and v.length() < 6.0 and _dist_suelo < 1.5:
		cambiar("retorcerse" if vivo else "morir", 1.2 if not vivo else 0.0)
	elif comportamiento == "caida_libre" and _dist_suelo < 0.5 and absf(v.y) < 6.0 and _t > 0.4:
		cambiar("impacto")
		if duracion > 0.0:
			duracion = minf(duracion, _t + 1.5)
	# músculos
	var res: Array = _comportamiento(_t_comp)
	var pose: Dictionary = res[0]
	var fuerzas: Dictionary = res[1]
	for mn in ART:
		var def: Array = ART[mn]
		var s: float = float(fuerzas.get(def[4], 0.1)) * float(def[3]) * fuerza_mult
		if s <= 0.001:
			continue
		var m: RigPersonaje.Motor = rig.M[mn]
		var pa: RigidBody3D = cuerpos[m.part0]
		var hi: RigidBody3D = cuerpos[m.part1]
		var rp := pa.global_transform.basis.orthonormalized()
		var rc := hi.global_transform.basis.orthonormalized()
		var actual := rp.inverse() * rc
		var obj: Basis = pose.get(mn, Basis.IDENTITY)
		var err := Quaternion(obj * actual.inverse())
		if err.w < 0.0:
			err = -err
		var ang := 2.0 * acos(clampf(err.w, -1.0, 1.0))
		var eje := Vector3(err.x, err.y, err.z)
		eje = eje.normalized() if eje.length() > 1e-5 else Vector3.ZERO
		var kp := KP * s
		var kd := 2.0 * sqrt(kp) * 0.85
		var alfa := (rp * eje) * (kp * ang) - (hi.angular_velocity - pa.angular_velocity) * kd
		if alfa.length() > ACEL_MAX:
			alfa = alfa.normalized() * ACEL_MAX
		var tq := alfa * minf(_inercia[m.part1], _inercia[m.part0])
		hi.apply_torque(tq)
		pa.apply_torque(-tq)
	# espasmos (muriendo)
	if comportamiento == "morir" and _t_comp > 1.2 and _t_comp < 4.0 and randf() < 0.012:
		var bp: RigidBody3D = cuerpos.UpperTorso if randf() < 0.5 else cuerpos.Head
		bp.apply_central_impulse(Vector3(randf() - 0.5, randf() * 0.5, randf() - 0.5) * bp.mass * 5.0)
	# ¿se ha parado? (tumbado, sentado o de rodillas: lo que cuenta es que el cuerpo ya no se mueve)
	if v.length() < 1.2 and bt.angular_velocity.length() < 1.5:
		_quieto_t += dt
	else:
		_quieto_t = 0.0
	if vivo and not _avisado and duracion >= 0.0 and _t > duracion and _quieto_t > 0.35 and v.length() < 4.0:
		_avisado = true
		recuperado.emit()
	# cadáver quieto: se congela (no gasta física)
	if not vivo and _t > 6.0 and _quieto_t > 2.0:
		_congelar()


func _congelar() -> void:
	if _congelado:
		return
	_congelado = true
	for n in cuerpos:
		(cuerpos[n] as RigidBody3D).freeze = true


func _descongelar() -> void:
	_congelado = false
	_quieto_t = 0.0
	_t = maxf(_t, 4.0)
	for n in cuerpos:
		(cuerpos[n] as RigidBody3D).freeze = false


## velocidad del centro de masas de todo el cuerpo (los brazos que se agitan no la cambian)
func _vel_centro() -> Vector3:
	var suma := Vector3.ZERO
	var masa := 0.0
	for n in cuerpos:
		var b: RigidBody3D = cuerpos[n]
		suma += b.linear_velocity * b.mass
		masa += b.mass
	return suma / maxf(masa, 1e-3)


## el rig sigue a los cuerpos (en _process: después de la animación del dueño, que así no lo pisa)
func _process(dt: float) -> void:
	if _mezcla >= 0.0:
		_paso_mezcla(dt)
		return
	if _fase == 0:
		return
	_copiar_al_rig()


func _copiar_al_rig() -> void:
	for mn in rig.M:
		var m: RigPersonaje.Motor = rig.M[mn]
		if mn == "Root":
			m.transform = Transform3D.IDENTITY
			continue
		var pa: Transform3D = (cuerpos[m.part0] as RigidBody3D).global_transform
		var hi: Transform3D = (cuerpos[m.part1] as RigidBody3D).global_transform
		m.transform = m.c0.affine_inverse() * (pa.affine_inverse() * hi) * m.c1
	# HumanoidRootPart: LowerTorso = HRP * C0 * T * C1⁻¹, con T = identidad
	var raiz: RigPersonaje.Motor = rig.M.Root
	rig.global_transform = (cuerpos.LowerTorso as RigidBody3D).global_transform * raiz.c1 * raiz.c0.affine_inverse()
	rig.aplicar()


## ---------------------------------------------------------------- terminar
## quita la física y devuelve el control a la animación del dueño, mezclando durante "mezcla" segundos
## (0 = de golpe). El dueño ya debe haberse colocado donde quedó el cuerpo.
func terminar(mezcla := 0.3) -> void:
	if _mezcla >= 0.0:
		return
	if _fase == 1:
		_copiar_al_rig()
	for mn in rig.M:
		_final_motores[mn] = (rig.M[mn] as RigPersonaje.Motor).transform
	_final_raiz = rig.global_transform
	for j in _uniones:
		j.queue_free()
	_uniones.clear()
	for n in cuerpos:
		(cuerpos[n] as RigidBody3D).queue_free()
	cuerpos.clear()
	activos.erase(self)
	rig.top_level = _rig_top0
	rig.transform = _rig_local0
	_mezcla_dur = maxf(mezcla, 0.0)
	_mezcla = 0.0
	_mezcla_t = 0.0
	if _mezcla_dur <= 0.0:
		queue_free()


func _paso_mezcla(dt: float) -> void:
	_mezcla_t += dt
	var k := Rbx.smooth(clampf(_mezcla_t / _mezcla_dur, 0.0, 1.0))
	# (el dueño ya ha animado este fotograma: se mezcla desde la postura en que quedó el cuerpo)
	for mn in _final_motores:
		var m: RigPersonaje.Motor = rig.M[mn]
		m.transform = (_final_motores[mn] as Transform3D).interpolate_with(m.transform, k)
	var padre := rig.get_parent() as Node3D
	if padre:
		var desde := padre.global_transform.affine_inverse() * _final_raiz
		rig.transform = desde.interpolate_with(_rig_local0, k)
	rig.aplicar()
	if k >= 1.0:
		rig.transform = _rig_local0
		queue_free()


func _exit_tree() -> void:
	activos.erase(self)


## ---------------------------------------------------------------- comportamientos
## devuelven [pose: motor -> Basis (rotación relativa al padre), fuerzas: grupo -> 0..1]
func _comportamiento(t: float) -> Array:
	match comportamiento:
		"caer":
			return _b_caer(t)
		"caida_libre":
			return _b_caida_libre(t)
		"impacto":
			return _b_impacto(t)
		"retorcerse":
			return _b_retorcerse(t)
		"morir":
			return _b_morir(t)
	return [{}, {"core": 0.02, "neck": 0.03, "arm": 0.02, "leg": 0.02}]


static func _ang(x: float, y := 0.0, z := 0.0) -> Basis:
	return Rbx.angb(x, y, z)


## rotación que lleva el hueso (que en reposo apunta hacia abajo) hacia "dir" (en el espacio del padre)
static func _apuntar(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var desde := Vector3.DOWN
	var eje := desde.cross(d)
	if eje.length() < 1e-4:
		return Basis.IDENTITY if d.y < 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(eje.normalized(), acos(clampf(desde.dot(d), -1.0, 1.0)))


func _ruido(t: float, s: float) -> float:
	return sin(t * 1.7 + s) * 0.55 + sin(t * 2.9 + s * 1.37) * 0.3 + sin(t * 0.63 + s * 2.1) * 0.15


func _b_caer(t: float) -> Array:
	var bt := torso()
	var v := bt.linear_velocity
	var d := v.normalized() if v.length() > 2.0 else -bt.global_transform.basis.y
	var dl := bt.global_transform.basis.inverse() * (d + Vector3(0, -0.8, 0)).normalized()
	var espalda := dl.z > 0.0 # cayendo de espaldas
	var brazo_l := _apuntar(dl + Vector3(-0.35, 0, 0))
	var brazo_r := _apuntar(dl + Vector3(0.35, 0, 0))
	if espalda:
		brazo_l = _apuntar(Vector3(-0.5, -1, 0.9))
		brazo_r = _apuntar(Vector3(0.5, -1, 0.9))
	return [{
		"LeftShoulder": brazo_l, "RightShoulder": brazo_r,
		"LeftElbow": _ang(0.35), "RightElbow": _ang(0.35),
		"LeftWrist": _ang(-0.5), "RightWrist": _ang(-0.5),
		"Neck": _ang(0.55) if espalda else _ang(-0.45),
		"Waist": _ang(0.25) if espalda else _ang(-0.15),
		"LeftHip": _ang(0.35, 0, -0.08), "RightHip": _ang(0.25, 0, 0.08),
		"LeftKnee": _ang(-0.6), "RightKnee": _ang(-0.4),
	}, {"core": 0.7, "neck": 0.9, "arm": 0.85, "leg": 0.06 if t < 0.7 else 0.35}]


func _b_retorcerse(t: float) -> Array:
	var s := _semilla
	var lado := lado_herida
	var k := 0.6 + 0.4 * _ruido(t * 0.4, s)
	var agarra_sh := _ang(0.7, 0, -0.55 * lado)
	var agarra_el := _ang(2.0)
	var libre := _apuntar(Vector3(-lado * (0.6 + 0.3 * _ruido(t * 0.7, s + 3.0)), -0.6, -0.5 + _ruido(t * 0.5, s + 4.0)))
	var pose := {
		"Neck": _ang(-0.3 + 0.35 * _ruido(t * 0.8, s + 1.0), 0.5 * _ruido(t * 0.3, s + 2.0), 0),
		"Waist": _ang(0.25 * _ruido(t * 0.6, s + 5.0), 0.3 * _ruido(t * 0.4, s + 6.0), 0),
		"LeftHip": _ang(0.5 + 0.5 * _ruido(t * 0.5, s + 7.0)), "RightHip": _ang(0.5 + 0.5 * _ruido(t * 0.45, s + 8.0)),
		"LeftKnee": _ang(-0.9 - 0.6 * _ruido(t * 0.5, s + 9.0)), "RightKnee": _ang(-0.9 - 0.6 * _ruido(t * 0.5, s + 10.0)),
	}
	if lado > 0.0:
		pose.RightShoulder = agarra_sh
		pose.RightElbow = agarra_el
		pose.LeftShoulder = libre
		pose.LeftElbow = _ang(0.6)
	else:
		pose.LeftShoulder = agarra_sh
		pose.LeftElbow = agarra_el
		pose.RightShoulder = libre
		pose.RightElbow = _ang(0.6)
	return [pose, {"core": 0.35 * k, "neck": 0.45 * k, "arm": 0.45 * k, "leg": 0.3 * k}]


## caída larga: molinillo con los brazos y pedaleo; cerca del suelo, se prepara para el golpe
func _b_caida_libre(t: float) -> Array:
	var ph := t * 8.0 + _semilla
	var vy := torso().linear_velocity.y
	var tti := _dist_suelo / -vy if vy < -1.0 else 9.0
	var prepara := clampf((0.5 - tti) / 0.35, 0.0, 1.0)
	var viento := {
		"LeftShoulder": _apuntar(Vector3(-0.75, -cos(ph) * 0.9, -sin(ph) * 0.9)),
		"RightShoulder": _apuntar(Vector3(0.75, -cos(ph + 2.3) * 0.9, -sin(ph + 2.3) * 0.9)),
		"LeftElbow": _ang(0.5 + 0.35 * sin(ph)), "RightElbow": _ang(0.5 + 0.35 * sin(ph + 2.3)),
		"LeftWrist": _ang(-0.3), "RightWrist": _ang(-0.3),
		"Neck": _ang(-0.3, 0.3 * sin(t * 3.1 + _semilla), 0),
		"Waist": _ang(0.12 * sin(ph * 0.5), 0.18 * sin(t * 2.3), 0),
		"LeftHip": _ang(0.45 + 0.6 * sin(ph * 0.7), 0, -0.12), "RightHip": _ang(0.45 - 0.6 * sin(ph * 0.7), 0, 0.12),
		"LeftKnee": _ang(-0.7 - 0.6 * maxf(0.0, cos(ph * 0.7))), "RightKnee": _ang(-0.7 - 0.6 * maxf(0.0, -cos(ph * 0.7))),
	}
	if prepara <= 0.0:
		return [viento, {"core": 0.5, "neck": 0.8, "arm": 0.55, "leg": 0.35}]
	var bp: Dictionary = _b_caer(1.0)[0]
	bp.LeftHip = _ang(0.4, 0, -0.1)
	bp.RightHip = _ang(0.3, 0, 0.1)
	bp.LeftKnee = _ang(-0.5)
	bp.RightKnee = _ang(-0.6)
	var pose := {}
	for k in viento:
		pose[k] = (viento[k] as Basis).slerp(bp.get(k, viento[k]), prepara)
	for k in bp:
		if not pose.has(k):
			pose[k] = bp[k]
	return [pose, {"core": 0.5 + 0.25 * prepara, "neck": 0.85, "arm": 0.55 + 0.35 * prepara, "leg": 0.35 + 0.35 * prepara}]


## impacto contra el suelo: un instante sin fuerza; después, aturdido, se retuerce (más débil si fue grave)
func _b_impacto(t: float) -> Array:
	if t < 0.35:
		return [{}, {"core": 0.03, "neck": 0.04, "arm": 0.03, "leg": 0.03}]
	var r := _b_retorcerse(t)
	var k := (0.2 + 0.65 * (1.0 - gravedad)) * minf(1.0, (t - 0.35) / 0.8)
	var f: Dictionary = r[1]
	for g in f:
		f[g] = float(f[g]) * k
	return r


## muerte: se agarra la herida, las rodillas ceden, cae protegiéndose, se retuerce y se apaga
func _b_morir(t: float) -> Array:
	if t < 0.35:
		var pose: Dictionary = _b_retorcerse(t)[0]
		pose.LeftKnee = _ang(-1.1)
		pose.RightKnee = _ang(-1.2)
		pose.LeftHip = _ang(0.6)
		pose.RightHip = _ang(0.7)
		pose.Waist = _ang(-0.35)
		return [pose, {"core": 0.6, "neck": 0.7, "arm": 0.7, "leg": 0.12}]
	elif t < 1.2:
		var r := _b_caer(t)
		var f: Dictionary = r[1]
		var m := 1.0 - (t - 0.35) / 0.85 * 0.6
		for g in f:
			f[g] = float(f[g]) * m
		f.leg = float(f.leg) * 0.5
		return r
	elif t < 4.0:
		var r2 := _b_retorcerse(t)
		var m2 := maxf(0.05, 1.0 - (t - 1.2) / 2.8)
		var f2: Dictionary = r2[1]
		for g in f2:
			f2[g] = float(f2[g]) * m2 * 0.8
		return r2
	return [{}, {"core": 0.02, "neck": 0.03, "arm": 0.02, "leg": 0.02}]

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
##       señales: impacto(velocidad) cuanEdo el cuerpo se estrella; recuperado() cuando se para tras
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
## (2026-10-28) músculos de verdad: antes cada músculo solo podía mover su propia pieza (inercia de la pieza) y el
## cuerpo se "derramaba" como agua. Ahora cada articulación mueve TODO lo que cuelga de ella (inercia de la rama:
## la cadera sostiene el tronco, el hombro el brazo entero) y, vivo, nunca baja de un tono mínimo (TONO).
const KP := 1100.0              # rigidez de los músculos (rad/s² por radián) a fuerza 1
const AMORT := 0.75             # amortiguación (1 = crítica)
const ACEL_MAX := 1400.0        # tope de aceleración angular de un músculo (estabilidad)
## tono mínimo de cada grupo mientras está vivo (consciente): el cuerpo no se desarma nunca
const TONO := {"core": 0.55, "neck": 0.6, "arm": 0.4, "leg": 0.45}
## cuánto se amplían los gestos (EXAGERA) y la velocidad de los movimientos "nerviosos" (NERVIO)
## músculos resueltos por el motor de física (muelles de Generic6DOFJoint3D) en vez de pares calculados a mano
const MUSCULOS_JOLT := true
const KS := 1500.0              # rigidez de los músculos implícitos (par por radián y por unidad de inercia) a fuerza 1
static var CONV_ORDEN := EULER_ORDER_ZYX  # (comprobado: con esta convención el error es 0,1°)
static var CONV_SIGNO := -1.0
const EXAGERA := 1.6
const NERVIO := 1.25

var dueno: Node3D
var rig: RigPersonaje
var cuerpos := {}               # pieza -> RigidBody3D
var _uniones: Array[Joint3D] = []
var _inercia := {}              # pieza -> inercia aproximada
var _inercia_art := {}          # articulación -> inercia de lo que mueve (la rama más ligera de las dos)
var error_medio := 0.0          # error medio de los músculos (rad), para las pruebas
var pose_prueba := {}
var _ignorados: Array = []      # [cuerpo, segundos que quedan] con los que no choca (ver ignorar)           # comportamiento "pose" (pruebas): postura fija
var _j6 := {}                   # articulación -> Generic6DOFJoint3D (músculos implícitos)
var _jl := {}                   # articulación -> base de la articulación en el espacio del padre
var _rc := {}                   # articulación -> rotación del hijo respecto al padre en la postura central
var _base_union := {}
var _ultimo_musculo := {}       # articulación -> [k, equilibrio] puestos la última vez
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
		if MUSCULOS_JOLT:
			j = _crear_union_6dof(mn, def, t_pa, centro, pivote)
			base = _base_union[mn]
		elif def[0] == "bola":
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
	_calcular_inercias(centro)


## (2026-10-28) articulación con músculos "implícitos": Generic6DOFJoint3D con límites por eje y un muelle
## angular en cada eje que resuelve el propio motor de física (Jolt). Un muelle así puede ser todo lo rígido que
## haga falta sin temblar (los pares calculados a mano temblaban en cuanto se subía la fuerza).
## Ejes de la articulación: X = el hueso (giro sobre sí mismo) en las rótulas; X = el eje de la bisagra en codos y
## rodillas (Y y Z bloqueados).
func _crear_union_6dof(mn: String, def: Array, t_pa: Transform3D, centro: Dictionary, pivote: Vector3) -> Joint3D:
	var m: RigPersonaje.Motor = rig.M[mn]
	var base: Basis
	var lim := Vector3.ZERO
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
		lim = Vector3(deg_to_rad(def[2]), deg_to_rad(def[1]), deg_to_rad(def[1]))
	else:
		var x2 := t_pa.basis.x.normalized()
		var y2 := t_pa.basis.y.normalized()
		base = Basis(x2, y2, x2.cross(y2).normalized())
		lim = Vector3(deg_to_rad(def[1]), 0.0, 0.0)
	base = base.orthonormalized()
	_base_union[mn] = base
	_jl[mn] = t_pa.basis.orthonormalized().inverse() * base
	_rc[mn] = t_pa.basis.orthonormalized().inverse() * (centro[m.part1] as Transform3D).basis.orthonormalized()
	var g := Generic6DOFJoint3D.new()
	var ejes := ["x", "y", "z"]
	for i in 3:
		var l: float = lim[i]
		_set_eje(g, i, "lim", l)
		_set_eje(g, i, "muelle", l > 0.0)
	_j6[mn] = g
	return g


func _set_eje(g: Generic6DOFJoint3D, i: int, que: String, v) -> void:
	match que:
		"lim":
			var f := Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT
			var lo := Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT
			var up := Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT
			match i:
				0: g.set_flag_x(f, true); g.set_param_x(lo, -float(v)); g.set_param_x(up, float(v))
				1: g.set_flag_y(f, true); g.set_param_y(lo, -float(v)); g.set_param_y(up, float(v))
				2: g.set_flag_z(f, true); g.set_param_z(lo, -float(v)); g.set_param_z(up, float(v))
		"muelle":
			var f2 := Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING
			match i:
				0: g.set_flag_x(f2, bool(v))
				1: g.set_flag_y(f2, bool(v))
				2: g.set_flag_z(f2, bool(v))


## músculo implícito: lleva la articulación hacia "obj" (rotación del hijo respecto al padre) con rigidez k y
## amortiguación c
func _musculo_6dof(mn: String, obj: Basis, k: float, c: float) -> void:
	var g: Generic6DOFJoint3D = _j6[mn]
	var jl: Basis = _jl[mn]
	var delta: Basis = jl.inverse() * (obj * (_rc[mn] as Basis).inverse()) * jl
	var e := delta.get_euler(CONV_ORDEN) * CONV_SIGNO
	# (solo se tocan los parámetros si han cambiado algo: cambiarlos cuesta)
	var prev: Array = _ultimo_musculo.get(mn, [])
	if not prev.is_empty() and absf(prev[0] - k) < 0.04 * k and (prev[1] as Vector3).distance_to(e) < 0.012:
		return
	_ultimo_musculo[mn] = [k, e]
	var K := Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS
	var D := Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING
	var E := Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_EQUILIBRIUM_POINT
	g.set_param_x(K, k); g.set_param_x(D, c); g.set_param_x(E, e.x)
	if ART[mn][0] == "bola":
		g.set_param_y(K, k); g.set_param_y(D, c); g.set_param_y(E, e.y)
		g.set_param_z(K, k); g.set_param_z(D, c); g.set_param_z(E, e.z)


## inercia que mueve cada músculo: la de la rama que cuelga de la articulación (o la del resto del cuerpo, si es
## más ligera), respecto al pivote. Así la cadera puede sostener el tronco y el hombro el brazo entero.
func _calcular_inercias(centro: Dictionary) -> void:
	var hijos := {}
	for mn in rig.M:
		var m: RigPersonaje.Motor = rig.M[mn]
		if not hijos.has(m.part0):
			hijos[m.part0] = []
		hijos[m.part0].append(m.part1)
	for mn in ART:
		var m: RigPersonaje.Motor = rig.M[mn]
		var pivote: Vector3 = ((centro[m.part0] as Transform3D) * m.c0).origin
		var rama := {}
		var pila: Array = [m.part1]
		while not pila.is_empty():
			var n: String = pila.pop_back()
			if rama.has(n) or not cuerpos.has(n):
				continue
			rama[n] = true
			pila.append_array(hijos.get(n, []))
		var i_rama := 0.0
		var i_resto := 0.0
		for n in cuerpos:
			var b: RigidBody3D = cuerpos[n]
			var d2 := ((centro[n] as Transform3D).origin - pivote).length_squared()
			var i: float = b.mass * d2 + float(_inercia[n])
			if rama.has(n):
				i_rama += i
			else:
				i_resto += i
		_inercia_art[mn] = minf(i_rama, i_resto)


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


## no chocar con "obj" durante "seg" segundos (el piloto que sale despedido no se engancha en su moto)
func ignorar(obj: PhysicsBody3D, seg: float) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	for n in cuerpos:
		(cuerpos[n] as RigidBody3D).add_collision_exception_with(obj)
	_ignorados.append([obj, seg])


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
	for ig in _ignorados:
		ig[1] = float(ig[1]) - dt
		if float(ig[1]) <= 0.0 and is_instance_valid(ig[0]):
			for n in cuerpos:
				(cuerpos[n] as RigidBody3D).remove_collision_exception_with(ig[0])
	_ignorados = _ignorados.filter(func(ig): return float(ig[1]) > 0.0 and is_instance_valid(ig[0]))
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
		Efectos.sonido(dueno, "BodyFall", bt.global_position, 0.35 + 0.8 * k, 0.9 + randf() * 0.15)
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
	if vivo and not _avisado and duracion >= 0.0 and _t > duracion and _dist_suelo < 2.5 and v.length() < 7.0 \
			and comportamiento in ["caer", "impacto", "retorcerse"]:
		cambiar("prepararse")
	var res: Array = _comportamiento(_t_comp)
	var pose: Dictionary = res[0]
	var fuerzas: Dictionary = res[1]
	# vivo y consciente: los músculos nunca se sueltan del todo (salvo el instante del golpe contra el suelo)
	var con_tono := vivo and comportamiento != "inerte" and not (comportamiento == "impacto" and _t_comp < 0.12)
	var err_suma := 0.0
	var err_peso := 0.0
	for mn in ART:
		var def: Array = ART[mn]
		var f_g: float = float(fuerzas.get(def[4], 0.1))
		if con_tono:
			f_g = maxf(f_g, float(TONO[def[4]]))
		var s: float = maxf(f_g * float(def[3]) * fuerza_mult, 0.0)
		if s <= 0.001 and not MUSCULOS_JOLT:
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
		err_suma += ang * float(def[3])
		err_peso += float(def[3])
		if MUSCULOS_JOLT:
			var i_a: float = _inercia_art[mn]
			var k_m := maxf(KS * s * i_a, 0.02)
			_musculo_6dof(mn, obj, k_m, 2.0 * AMORT * sqrt(k_m * i_a))
			continue
		var kp := KP * s
		var kd := 2.0 * sqrt(kp) * AMORT
		var alfa := (rp * eje) * (kp * ang) - (hi.angular_velocity - pa.angular_velocity) * kd
		if alfa.length() > ACEL_MAX:
			alfa = alfa.normalized() * ACEL_MAX
		var tq := alfa * float(_inercia_art[mn])
		hi.apply_torque(tq)
		pa.apply_torque(-tq)
	error_medio = err_suma / maxf(err_peso, 1e-3)
	# espasmos (muriendo)
	if comportamiento in ["morir", "retorcerse"] and _t_comp > 0.8 and _t_comp < (6.0 if comportamiento == "morir" else 99.0) \
			and randf() < (0.07 if comportamiento == "morir" else 0.025) * dt * 60.0:
		var piezas := ["UpperTorso", "Head", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm"]
		var bp: RigidBody3D = cuerpos[piezas[randi() % piezas.size()]]
		bp.apply_central_impulse(Vector3(randf() - 0.5, randf() * 0.7, randf() - 0.5) * bp.mass * 12.0)
	# ¿se ha parado? (tumbado, sentado o de rodillas: lo que cuenta es que el cuerpo ya no se mueve)
	if v.length() < 1.2 and bt.angular_velocity.length() < 1.5:
		_quieto_t += dt
	else:
		_quieto_t = 0.0
	# se levanta cuando se para... o, preparado para levantarse, en cuanto ha tenido un momento (no espera a que el
	# cuerpo esté quieto del todo: si no, a veces no se levantaba nunca)
	if vivo and not _avisado and duracion >= 0.0 and _t > duracion and _dist_suelo < 2.5 \
			and ((_quieto_t > 0.2 and v.length() < 5.0) or (comportamiento == "prepararse" and _t_comp > 0.9 and v.length() < 9.0)):
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


var _mezcla_q := {}


func _paso_mezcla(dt: float) -> void:
	_mezcla_t += dt
	var k := Rbx.smooth(clampf(_mezcla_t / _mezcla_dur, 0.0, 1.0))
	# (el dueño ya ha animado este fotograma: se mezcla desde la postura en que quedó el cuerpo)
	for mn in _final_motores:
		var m: RigPersonaje.Motor = rig.M[mn]
		var tf: Transform3D = _final_motores[mn]
		# (2026-10-30) giro continuo: la animación de levantarse va girando (rodar boca abajo) y, cuando su diferencia
		# con la pose final del ragdoll pasaba de 180°, "el camino más corto" cambiaba de lado y el cuerpo daba un salto
		var qf := Quaternion(tf.basis.orthonormalized())
		var qt := Quaternion(m.transform.basis.orthonormalized())
		var q_ant = _mezcla_q.get(mn)
		if q_ant == null:
			if qf.dot(qt) < 0.0:
				qt = -qt
		elif (q_ant as Quaternion).dot(qt) < 0.0:
			qt = -qt
		_mezcla_q[mn] = qt
		m.transform = Transform3D(Basis(qf.slerpni(qt, k)), tf.origin.lerp(m.transform.origin, k))
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
		"prepararse":
			return _b_prepararse(t)
		"pose":
			return [pose_prueba, {"core": 1.0, "neck": 1.0, "arm": 1.0, "leg": 1.0}]
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
	# los brazos buscan el suelo (o se echan atrás de espaldas) agitándose: manotazos de pánico
	var ag := t * 9.0 * NERVIO + _semilla
	var tembl := Vector3(sin(ag) * 0.45, cos(ag * 1.3) * 0.35, sin(ag * 0.7) * 0.4) * EXAGERA
	var brazo_l := _apuntar(dl + Vector3(-0.55, 0, 0) + tembl)
	var brazo_r := _apuntar(dl + Vector3(0.55, 0, 0) - tembl)
	if espalda:
		brazo_l = _apuntar(Vector3(-0.9, -0.7, 1.0) + tembl)
		brazo_r = _apuntar(Vector3(0.9, -0.7, 1.0) - tembl)
	# las piernas patalean buscando apoyo
	var pt := t * 7.0 * NERVIO + _semilla * 2.0
	return [{
		"LeftShoulder": brazo_l, "RightShoulder": brazo_r,
		"LeftElbow": _ang(0.35 + 0.5 * maxf(0.0, sin(ag))), "RightElbow": _ang(0.35 + 0.5 * maxf(0.0, -sin(ag))),
		"LeftWrist": _ang(-0.7), "RightWrist": _ang(-0.7),
		"Neck": _ang(0.75, 0.3 * sin(ag * 0.8), 0) if espalda else _ang(-0.6, 0.3 * sin(ag * 0.8), 0),
		"Waist": _ang(0.45, 0.25 * sin(pt * 0.5), 0) if espalda else _ang(-0.35, 0.25 * sin(pt * 0.5), 0),
		"LeftHip": _ang(0.55 + 0.55 * sin(pt), 0, -0.15), "RightHip": _ang(0.45 - 0.55 * sin(pt), 0, 0.15),
		"LeftKnee": _ang(-0.8 - 0.6 * maxf(0.0, cos(pt))), "RightKnee": _ang(-0.6 - 0.6 * maxf(0.0, -cos(pt))),
	}, {"core": 0.85, "neck": 1.0, "arm": 1.0, "leg": 0.35 if t < 0.7 else 0.6}]


func _b_retorcerse(t: float) -> Array:
	var s := _semilla
	var lado := lado_herida
	var tn := t * NERVIO
	var E := EXAGERA
	var k := 0.85 + 0.25 * _ruido(tn * 0.5, s)
	# convulsiones: cada poco el cuerpo se encoge de golpe (dolor) y vuelve a estirarse
	var encoge := pow(maxf(0.0, sin(tn * 2.2 + s)), 6.0)
	var agarra_sh := _ang(0.9, 0, -0.75 * lado)
	var agarra_el := _ang(2.2)
	var libre := _apuntar(Vector3(-lado * (0.7 + 0.5 * E * _ruido(tn * 1.1, s + 3.0)), -0.4 + 0.5 * _ruido(tn * 0.9, s + 11.0),
		-0.5 + 0.9 * _ruido(tn * 0.8, s + 4.0)))
	var pose := {
		"Neck": _ang(-0.35 + 0.45 * E * _ruido(tn * 1.2, s + 1.0) - 0.4 * encoge, 0.6 * E * _ruido(tn * 0.6, s + 2.0), 0),
		"Waist": _ang(0.35 * E * _ruido(tn * 0.9, s + 5.0) - 0.6 * encoge, 0.45 * E * _ruido(tn * 0.7, s + 6.0), 0),
		"LeftHip": _ang(0.6 + 0.6 * E * _ruido(tn * 0.8, s + 7.0) + 0.7 * encoge),
		"RightHip": _ang(0.6 + 0.6 * E * _ruido(tn * 0.75, s + 8.0) + 0.7 * encoge),
		"LeftKnee": _ang(-1.0 - 0.7 * E * absf(_ruido(tn * 0.9, s + 9.0)) - 0.6 * encoge),
		"RightKnee": _ang(-1.0 - 0.7 * E * absf(_ruido(tn * 0.9, s + 10.0)) - 0.6 * encoge),
		"LeftAnkle": _ang(0.4 * _ruido(tn * 1.3, s + 12.0)), "RightAnkle": _ang(0.4 * _ruido(tn * 1.3, s + 13.0)),
	}
	if lado > 0.0:
		pose.RightShoulder = agarra_sh
		pose.RightElbow = agarra_el
		pose.LeftShoulder = libre
		pose.LeftElbow = _ang(0.5 + 0.8 * absf(_ruido(tn, s + 14.0)))
	else:
		pose.LeftShoulder = agarra_sh
		pose.LeftElbow = agarra_el
		pose.RightShoulder = libre
		pose.RightElbow = _ang(0.5 + 0.8 * absf(_ruido(tn, s + 14.0)))
	var f := 1.0 + 0.6 * encoge
	return [pose, {"core": 0.6 * k * f, "neck": 0.75 * k * f, "arm": 0.8 * k, "leg": 0.6 * k * f}]


## caída larga: molinillo con los brazos y pedaleo; cerca del suelo, se prepara para el golpe
func _b_caida_libre(t: float) -> Array:
	var ph := t * 8.0 * NERVIO + _semilla
	var vy := torso().linear_velocity.y
	var tti := _dist_suelo / -vy if vy < -1.0 else 9.0
	var prepara := clampf((0.5 - tti) / 0.35, 0.0, 1.0)
	var viento := {
		"LeftShoulder": _apuntar(Vector3(-0.75, -cos(ph) * 0.9 * EXAGERA, -sin(ph) * 0.9 * EXAGERA)),
		"RightShoulder": _apuntar(Vector3(0.75, -cos(ph + 2.3) * 0.9 * EXAGERA, -sin(ph + 2.3) * 0.9 * EXAGERA)),
		"LeftElbow": _ang(0.5 + 0.6 * sin(ph)), "RightElbow": _ang(0.5 + 0.6 * sin(ph + 2.3)),
		"LeftWrist": _ang(-0.3), "RightWrist": _ang(-0.3),
		"Neck": _ang(-0.3, 0.55 * sin(t * 4.5 + _semilla), 0),
		"Waist": _ang(0.3 * sin(ph * 0.5), 0.35 * sin(t * 3.4), 0),
		"LeftHip": _ang(0.5 + 1.0 * sin(ph * 0.7), 0, -0.15), "RightHip": _ang(0.5 - 1.0 * sin(ph * 0.7), 0, 0.15),
		"LeftKnee": _ang(-0.7 - 1.0 * maxf(0.0, cos(ph * 0.7))), "RightKnee": _ang(-0.7 - 1.0 * maxf(0.0, -cos(ph * 0.7))),
	}
	if prepara <= 0.0:
		return [viento, {"core": 0.7, "neck": 0.9, "arm": 1.0, "leg": 0.8}]
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
	if t < 0.12:
		return [{}, {"core": 0.03, "neck": 0.04, "arm": 0.03, "leg": 0.03}]
	var r := _b_retorcerse(t)
	var k := (0.55 + 0.6 * (1.0 - gravedad)) * minf(1.0, (t - 0.12) / 0.35)
	var f: Dictionary = r[1]
	for g in f:
		f[g] = float(f[g]) * k
	return r


## a punto de levantarse: deja de retorcerse y coloca el cuerpo (boca abajo: manos bajo los hombros y cabeza
## arriba; boca arriba: rodillas dobladas y barbilla al pecho), con fuerza
func _b_prepararse(t: float) -> Array:
	var k := minf(1.0, t / 0.4)
	if boca_arriba():
		return [{
			"Neck": _ang(0.55), "Waist": _ang(0.25),
			"LeftHip": _ang(1.0, 0, -0.12), "RightHip": _ang(0.85, 0, 0.12),
			"LeftKnee": _ang(-1.7), "RightKnee": _ang(-1.5),
			"LeftShoulder": _apuntar(Vector3(-0.6, -0.8, 0.25)), "RightShoulder": _apuntar(Vector3(0.6, -0.8, 0.25)),
			"LeftElbow": _ang(0.9), "RightElbow": _ang(0.9),
		}, {"core": 0.7 + 0.3 * k, "neck": 1.0, "arm": 0.8, "leg": 0.8}]
	return [{
		"Neck": _ang(-0.7), "Waist": _ang(-0.15),
		"LeftHip": _ang(0.35, 0, -0.1), "RightHip": _ang(0.25, 0, 0.1),
		"LeftKnee": _ang(-0.7), "RightKnee": _ang(-0.5),
		"LeftShoulder": _apuntar(Vector3(-0.35, -0.7, -0.9)), "RightShoulder": _apuntar(Vector3(0.35, -0.7, -0.9)),
		"LeftElbow": _ang(1.4), "RightElbow": _ang(1.4),
		"LeftWrist": _ang(-0.8), "RightWrist": _ang(-0.8),
	}, {"core": 0.7 + 0.3 * k, "neck": 1.0, "arm": 0.9, "leg": 0.7}]


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
	elif t < 6.0:
		var r2 := _b_retorcerse(t * 1.3)
		var m2 := maxf(0.08, 1.0 - pow((t - 1.2) / 4.8, 2.5))
		var f2: Dictionary = r2[1]
		for g in f2:
			f2[g] = float(f2[g]) * m2
		return r2
	return [{}, {"core": 0.02, "neck": 0.03, "arm": 0.02, "leg": 0.02}]

class_name Maniqui
extends Node3D
## Muñeco de pruebas para el combate (hasta que haya zombis). Mismo esqueleto R15 que el jugador.
## · Recibe daño por zonas (cabeza x HeadMult, brazos/piernas x LimbMult), igual que DamageZombie.
## · Reacciona: se le va el torso y la cabeza con el impacto, retrocede con los golpes, el bate lo
##   tumba (y se levanta), y al morir cae y vuelve a levantarse con la vida llena a los pocos segundos.
## · Vida encima de la cabeza.
## Origen del nodo = entre los pies. Unidades: studs.

const CENTRO := 3.1
const PARTES_LIMB := ["LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]

@export var max_health := 100.0
@export var reaparecer := 4.0

var health := 100.0
var rig: RigPersonaje
var etiqueta: Label3D
var cuerpo: StaticBody3D

var _yaw0 := 0.0
var _base := Vector3.ZERO     # posición de los pies (se desplaza al empujarlo)
var _vel := Vector3.ZERO
var _t := 0.0
var _estado := "pie"          # pie, caido, muerto
var _caida := 0.0             # 0 de pie .. 1 en el suelo
var _caida_dir := Vector3.FORWARD
var _hasta := 0.0             # cuándo se levanta
var _stagger_hasta := 0.0
var _flash := 0.0
## ragdoll (v0.4): derribado o "muerto" cae con física y se levanta donde quedó
var _ragdoll: Ragdoll = null
var _impulso_golpe := Vector3.ZERO
var _bala := {} # contexto solo durante recibir_disparo; el contrato cuerpo a cuerpo no cambia
var _reaccion_balas := ImpactoBalistico.new()
var _pieza_golpe := "UpperTorso"
var _sale_ragdoll_t := -1.0
var S := {
	"hitPitch": Rbx.Muelle.new(2.4, 0.3), "hitYaw": Rbx.Muelle.new(2.4, 0.3), "hitHead": Rbx.Muelle.new(3.2, 0.3),
	"hitRoll": Rbx.Muelle.new(2.0, 0.35),
}


func _ready() -> void:
	add_to_group("maniquies")
	add_to_group("objetivos") # blanco de las armas (ver "contrato de objetivo" en docs/RUIDO_Y_ZOMBIS.md)
	health = max_health
	_yaw0 = rotation.y
	_base = global_position
	rig = RigPersonaje.new()
	rig.name = "Rig"
	rig.maniqui = true
	add_child(rig)
	rig.position = Vector3(0, CENTRO, 0)
	# zonas de impacto: una caja por pieza (capa 2: las balas sí, el movimiento no)
	for n in rig.P:
		if n == "HumanoidRootPart":
			continue
		var nd: Node3D = rig.P[n]
		var sb := StaticBody3D.new()
		sb.name = "Zona_" + n
		sb.collision_layer = 2
		sb.collision_mask = 0
		sb.set_meta("maniqui", self)
		sb.set_meta("objetivo", self)
		sb.set_meta("pieza", n)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = nd.get_meta("size")
		cs.shape = bx
		sb.add_child(cs)
		nd.add_child(sb)
	# cuerpo sólido (para no atravesarlo andando)
	cuerpo = StaticBody3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.collision_layer = 4
	cuerpo.collision_mask = 0
	var cc := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 5.8
	cc.shape = cap
	cc.position = Vector3(0, 2.9, 0)
	cuerpo.add_child(cc)
	add_child(cuerpo)
	# vida encima de la cabeza
	etiqueta = Label3D.new()
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.font_size = 48
	etiqueta.pixel_size = 0.01
	etiqueta.outline_size = 10
	etiqueta.no_depth_test = false
	etiqueta.position = Vector3(0, 6.4, 0)
	add_child(etiqueta)
	_actualizar_etiqueta()


func centro() -> Vector3:
	return (rig.P.UpperTorso as Node3D).global_position


func vivo() -> bool:
	return _estado != "muerto" and health > 0


func en_pie() -> bool:
	return _estado == "pie"


func _actualizar_etiqueta() -> void:
	if _estado == "muerto":
		etiqueta.text = "MUERTO"
		etiqueta.modulate = Color8(230, 60, 50)
		return
	var n := int(ceil(health))
	var barras := int(round(10.0 * health / max_health))
	etiqueta.text = "%s %d" % ["■".repeat(barras) + "□".repeat(10 - barras), n]
	var f := health / max_health
	etiqueta.modulate = Color(1.0, 0.35 + 0.65 * f, 0.3 + 0.5 * f)


## Daño (como ZShared.DamageZombie): devuelve true si lo ha matado
## Entrada opcional de las armas: conserva el punto exacto y separa balas de golpes/atropellos.
func recibir_disparo(cantidad: float, pieza: String, impulso: Vector3, punto: Vector3) -> bool:
	_bala = {"pieza": pieza, "punto_local": ImpactoBalistico.punto_local(rig, pieza, punto)}
	if _ragdoll != null and is_instance_valid(_ragdoll):
		_ragdoll.disparo(pieza, impulso, punto)
	elif vivo():
		_reaccion_balas.registrar(rig, pieza, impulso, punto)
	var muerto := recibir_danio(cantidad, pieza, impulso)
	_bala = {}
	return muerto


func recibir_danio(cantidad: float, pieza: String, impulso: Vector3) -> bool:
	if _bala.is_empty() and _ragdoll != null and is_instance_valid(_ragdoll):
		_ragdoll.golpe(pieza, impulso * 0.15)
	if not vivo():
		return false
	_impulso_golpe = impulso
	_pieza_golpe = pieza
	health = maxf(0.0, health - cantidad)
	_flash = 1.0
	var killed := health <= 0
	var dir := Rbx.flat(impulso)
	dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	if _bala.is_empty():
		var k := clampf(cantidad / 30.0, 0.3, 1.6)
		# reacción: el torso y la cabeza se van con el golpe
		var d_loc := Rbx.vec_to_obj(Rbx.ang(0, _yaw0, 0), dir)
		S.hitPitch.impulse(d_loc.z * 3.5 * k)
		S.hitYaw.impulse(-d_loc.x * 3.0 * k)
		S.hitRoll.impulse(d_loc.x * 2.0 * k)
		S.hitHead.impulse((d_loc.z * 4.5 if pieza != "Head" else 9.0) * k)
	if killed:
		_estado = "muerto"
		_caer(dir, reaparecer)
		if not _bala.is_empty():
			_ragdoll.morir(true)
			_ragdoll.vivo = true # muñeco de entrenamiento: reaparece, no es un cadáver permanente
	elif _estado == "pie":
		_vel += dir * (minf(impulso.length() * 0.14, 9.0) if _bala.is_empty() else 0.0)
		_stagger_hasta = _t + 0.3
	_actualizar_etiqueta()
	return killed


## empujón de un golpe cuerpo a cuerpo (retrocede tambaleándose)
func empujar(vel: Vector3, dur: float) -> void:
	if _estado != "pie":
		return
	_vel += Rbx.flat(vel)
	_stagger_hasta = _t + dur
	# (2026-11-08, Claude de KangooG: combate cuerpo a cuerpo) el cuerpo se echa hacia atrás según lo fuerte que le
	# empujan, con los mismos muelles que al recibir un golpe
	var f := Rbx.flat(vel)
	if f.length() > 0.5:
		var d_loc := Rbx.vec_to_obj(global_transform, f.normalized())
		var k := clampf(f.length() / 10.0, 0.2, 2.2)
		S.hitPitch.impulse(d_loc.z * 3.0 * k)
		S.hitRoll.impulse(d_loc.x * 1.5 * k)
		S.hitHead.impulse(d_loc.z * 3.5 * k)


## (2026-11-08, Claude de KangooG: combate cuerpo a cuerpo, opcional en el contrato de objetivo) un golpe del jugador
## con la mano, el pie o el arma: la pieza golpeada se hunde (la cabeza da un latigazo, al pecho se echa atrás, a la
## barriga se dobla, a las piernas se tuerce). fuerza = Δv del golpe (studs/s, ~5 flojo, ~16 fuerte)
func reaccion_golpe(pieza: String, dir: Vector3, fuerza: float) -> void:
	if not en_pie():
		return # (en el suelo lo sacude el ragdoll)
	var f := Rbx.flat(dir)
	f = f.normalized() if f.length() > 0.01 else -global_transform.basis.z
	var d_loc := Rbx.vec_to_obj(global_transform, f)
	var k := clampf(fuerza / 10.0, 0.2, 2.0)
	match pieza:
		"Head":
			S.hitHead.impulse(d_loc.z * 8.0 * k)
			S.hitYaw.impulse(-d_loc.x * 3.0 * k)
			S.hitPitch.impulse(d_loc.z * 1.0 * k)
		"UpperTorso":
			S.hitPitch.impulse(d_loc.z * 3.5 * k)
			S.hitHead.impulse(-d_loc.z * 2.5 * k) # (la cabeza se queda atrás: latigazo hacia delante)
			S.hitRoll.impulse(d_loc.x * 1.5 * k)
		"LowerTorso":
			S.hitPitch.impulse(-d_loc.z * 0.8 * k) # (se dobla un poco sobre la barriga: la cabeza va hacia delante)
			S.hitHead.impulse(-d_loc.z * 3.5 * k)
		_:
			S.hitRoll.impulse((1.0 if "Left" in pieza else -1.0) * 2.5 * k)
			S.hitYaw.impulse((1.0 if "Left" in pieza else -1.0) * 2.0 * k)
			S.hitPitch.impulse(-d_loc.z * 1.2 * k)


## derribo (batazo): cae y se levanta pasado un rato
func derribar(impulso: Vector3, dur: float) -> void:
	if _estado != "pie":
		return
	_impulso_golpe = impulso
	_estado = "caido"
	_caer(Rbx.flat(impulso).normalized(), dur)


func _caer(dir: Vector3, dur: float) -> void:
	_caida_dir = dir if dir.length() > 0.01 else -global_transform.basis.z
	_hasta = _t + dur
	cuerpo.process_mode = Node.PROCESS_MODE_DISABLED
	(cuerpo.get_child(0) as CollisionShape3D).disabled = true
	if _ragdoll == null or not is_instance_valid(_ragdoll):
		var imp := _impulso_golpe if not _bala.is_empty() else _impulso_golpe * 0.3
		if _bala.is_empty():
			if imp.length() > 16.0:
				imp = imp.normalized() * 16.0
			if imp.length() < 2.0:
				imp = _caida_dir * 4.0 + Vector3(0, 1.0, 0)
		_ragdoll = Ragdoll.iniciar(self, rig, _vel, {"comportamiento": "caer" if _estado != "muerto" else "morir",
			"vivo": true, "impulso": imp, "pieza": _pieza_golpe, "balistica": not _bala.is_empty(), "punto_local": _bala.get("punto_local", Vector3.ZERO), "duracion": dur})
		_ragdoll.recuperado.connect(_ragdoll_levantar)


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	_t += dt
	if _estado == "muerto" and _t >= _hasta and is_instance_valid(_ragdoll) and _sale_ragdoll_t < 0.0 and _ragdoll.comportamiento == "morir":
		# La agonía no estaba entre los estados recuperables: el muñeco muerto no reaparecía.
		_ragdoll.vivo = true
		_ragdoll.duracion = _ragdoll._t
		_ragdoll.cambiar("retorcerse")
	if _ragdoll != null or _sale_ragdoll_t >= 0.0:
		# en el suelo con física (o mezclando al levantarse): de pie en su sitio y sin la caída de antes
		if _sale_ragdoll_t >= 0.0 and _t > _sale_ragdoll_t:
			_sale_ragdoll_t = -1.0
			_ragdoll = null
			_estado = "pie"
			(cuerpo.get_child(0) as CollisionShape3D).disabled = false
			cuerpo.process_mode = Node.PROCESS_MODE_INHERIT
			_actualizar_etiqueta()
		global_transform = Transform3D(Basis(Vector3.UP, _yaw0), _base)
		_caida = 0.0
		_pose(dt, 0.0)
		etiqueta.visible = _ragdoll == null or _sale_ragdoll_t >= 0.0
		return
	# levantarse
	if _estado != "pie" and _t > _hasta and _caida >= 0.999:
		if _estado == "muerto":
			health = max_health
		_estado = "levantando"
		_actualizar_etiqueta()
	var objetivo := 1.0 if (_estado == "caido" or _estado == "muerto") else 0.0
	if objetivo > _caida:
		# cae como un tronco: cada vez más deprisa
		_caida = minf(1.0, _caida + dt * (0.6 + 4.0 * _caida))
	else:
		_caida = maxf(0.0, _caida - dt * 1.1)
		if _estado == "levantando" and _caida <= 0.0:
			_estado = "pie"
			(cuerpo.get_child(0) as CollisionShape3D).disabled = false
			cuerpo.process_mode = Node.PROCESS_MODE_INHERIT
			_actualizar_etiqueta()
	# deslizamiento del empujón
	_vel = _vel.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	_base += _vel * dt
	var ease_c := _caida * _caida * (3.0 - 2.0 * _caida)
	var eje := Vector3.UP.cross(_caida_dir).normalized() if _caida_dir.length() > 0.01 else Vector3.RIGHT
	var giro := Basis(eje, ease_c * PI * 0.5) if ease_c > 0.0 else Basis.IDENTITY
	global_transform = Transform3D(giro * Basis(Vector3.UP, _yaw0), _base + Vector3(0, 0.45 * ease_c, 0))
	_pose(dt, ease_c)


func _pose(dt: float, caido: float) -> void:
	var M := rig.M
	var hp: float = S.hitPitch.step(dt)
	var hy: float = S.hitYaw.step(dt)
	var hh: float = S.hitHead.step(dt)
	var hr: float = S.hitRoll.step(dt)
	var resp := sin(_t * 1.6) * 0.015
	var tamb := clampf((_stagger_hasta - _t) / 0.3, 0.0, 1.0)
	(M.Waist as RigPersonaje.Motor).transform = Rbx.ang(0, hy * 0.16, 0) * Rbx.ang(resp + hp * 0.16 - 0.1 * tamb, 0, hr * 0.12)
	(M.Neck as RigPersonaje.Motor).transform = Rbx.ang(hh * 0.14 - resp * 0.5, 0, 0)
	# brazos: cuelgan; al caer se abren; con el golpe se agitan un poco
	var abre := caido * 1.1 + absf(hp) * 0.08
	(M.LeftShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.05 + hp * 0.1, 0, -0.08 - abre)
	(M.RightShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.05 + hp * 0.1, 0, 0.08 + abre)
	(M.LeftElbow as RigPersonaje.Motor).transform = Rbx.ang(0.15 + caido * 0.4, 0, 0)
	(M.RightElbow as RigPersonaje.Motor).transform = Rbx.ang(0.15 + caido * 0.4, 0, 0)
	# piernas: algo flexionadas al caer
	(M.LeftHip as RigPersonaje.Motor).transform = Rbx.ang(caido * 0.25, 0, -caido * 0.12)
	(M.RightHip as RigPersonaje.Motor).transform = Rbx.ang(caido * 0.15, 0, caido * 0.15)
	(M.LeftKnee as RigPersonaje.Motor).transform = Rbx.ang(-caido * 0.4, 0, 0)
	(M.RightKnee as RigPersonaje.Motor).transform = Rbx.ang(-caido * 0.2, 0, 0)
	_reaccion_balas.aplicar(rig, dt)
	rig.aplicar()
	_flash = maxf(0.0, _flash - dt * 6.0)
	etiqueta.visible = caido < 0.5 or _estado == "muerto"


## ¿qué multiplicador de daño tiene esta pieza? (cabeza / extremidades / torso)
static func mult_pieza(pieza: String, w: Dictionary) -> float:
	if pieza == "Head":
		return w.HeadMult
	if pieza in PARTES_LIMB:
		return w.get("LimbMult", 1.0)
	return 1.0


## se ha parado: se levanta donde quedó el cuerpo (el "muerto" vuelve con la vida llena)
func _ragdoll_levantar() -> void:
	if _ragdoll == null:
		return
	if _t < _hasta:
		_ragdoll._avisado = false
		_ragdoll.duracion = _ragdoll._t + (_hasta - _t)
		return
	var pel := _ragdoll.pelvis()
	var dir := _ragdoll.direccion_cabeza()
	var q := PhysicsRayQueryParameters3D.create(pel + Vector3(0, 3, 0), pel + Vector3(0, -12, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var gy: float = (r.position as Vector3).y if not r.is_empty() else pel.y - 0.5
	_base = Vector3(pel.x, gy, pel.z)
	_yaw0 = atan2(-dir.x, -dir.z)
	_vel = Vector3.ZERO
	if _estado == "muerto":
		health = max_health
	global_transform = Transform3D(Basis(Vector3.UP, _yaw0), _base)
	_ragdoll.terminar(0.8)
	_sale_ragdoll_t = _t + 0.8

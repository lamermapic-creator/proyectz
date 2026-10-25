class_name Zombi
extends CharacterBody3D
## ZOMBI v0 (guía completa en docs/RUIDO_Y_ZOMBIS.md). De momento solo OYE (no tiene vista):
## reacciona a los ruidos del sistema Ruido y nota al jugador si lo tiene pegado (Contacto).
##
##   DEAMBULAR ──oye algo──► INVESTIGAR ──llega──► BUSCAR ──nada en "Buscar" s──► DEAMBULAR
##                             │    ▲
##        ruidos del jugador   │    │ deja de oírle "PerseguirMemoria" s
##        seguidos, alerta alta▼    │
##                            PERSEGUIR ──a "Alcance"──► ATACAR ──► PERSEGUIR
##   cualquiera ──bate──► CAIDO ──se levanta──► PERSEGUIR      cualquiera ──vida 0──► MUERTO
##
## Al empezar a perseguir gruñe: el gruñido es un ruido más, y los zombis cercanos van a ver qué pasa.
## Cumple el "contrato de objetivo" de las armas (vivo, en_pie, centro, recibir_danio, empujar, derribar,
## rig), así que se le dispara y se le golpea igual que a un maniquí.
## Unidades: studs. El origen del nodo es el centro del cuerpo, a CENTRO studs del suelo (como el jugador).
## La física y las decisiones van en _physics_process; la animación, en _process.

signal murio(zombi: Zombi)
signal estado_cambiado(nuevo: Estado)

const C = preload("res://scripts/config/zconfig.gd")
const CENTRO := 3.1            # altura del centro del cuerpo sobre el suelo
const PIERNA := 2.55           # largo de la pierna (muslo + espinilla)

enum Estado { DEAMBULAR, INVESTIGAR, PERSEGUIR, BUSCAR, ATACAR, CAIDO, MUERTO }
const NOMBRE_ESTADO := ["DEAMBULAR", "INVESTIGAR", "PERSEGUIR", "BUSCAR", "ATACAR", "CAIDO", "MUERTO"]

## pruebas: todos los zombis ignoran los ruidos (F7 en desarrollo)
static var sordos := false

## si es false se queda en su sitio cuando no oye nada (útil en pruebas)
@export var deambula := true


## Lo último que le ha llamado la atención: dónde, cuándo (reloj del zombi), con qué fuerza (0..1)
## y si sabe que lo ha hecho el jugador
class Pista extends RefCounted:
	var pos: Vector3
	var t: float
	var fuerza: float
	var del_jugador: bool

	func _init(p: Vector3, tt: float, f: float, j: bool) -> void:
		pos = p
		t = tt
		fuerza = f
		del_jugador = j


var estado: Estado = Estado.DEAMBULAR
var health: float = C.ZOMBI.Vida
var max_health: float = C.ZOMBI.Vida
var alerta := 0.0               # 0 tranquilo .. 1 furioso; baja sola con el tiempo
var oido := 1.0                 # multiplicador de los radios de ruido (cada zombi ±15 %)
var pista: Pista = null
var casa := Vector3.ZERO        # punto del suelo alrededor del que deambula
var reloj := 0.0                # reloj propio (se para con la pausa)
var rig: RigPersonaje

var _rng := RandomNumberGenerator.new()
var _estado_t := 0.0
var _destino = null             # Vector3 o null
var _camino := PackedVector3Array()
var _camino_i := 0
var _camino_t := -9.0
var _pausa_hasta := 0.0
var _progreso_t := 0.0
var _progreso_pos := Vector3.ZERO
var _atascos := 0
var _dir := Vector3.ZERO        # dirección deseada (horizontal)
var _vel := 0.0                 # velocidad deseada
var _empuje := Vector3.ZERO
var _tambaleo_hasta := 0.0
var _golpe_hecho := false
var _grunido_t := -99.0
var _gemido_t := 0.0
var _caida := 0.0               # 0 de pie .. 1 en el suelo
var _caida_dir := Vector3.FORWARD
var _levantar_t := 0.0
var _levantando := false
var _muerte_t := 0.0
## RAGDOLL (añadido por el Claude de KangooG, v0.4 — ver CLAUDE.md "Mensajes"): al derribarlo o matarlo el
## cuerpo cae con física (scripts/fisica/ragdoll.gd); al levantarse se mezcla con la animación
var _ragdoll: Ragdoll = null
var _impulso_golpe := Vector3.ZERO
var _pieza_golpe := "UpperTorso"
var _sale_ragdoll_t := -1.0     # mezclando la postura del suelo con la de pie (hasta esta hora)
var _fase := 0.0                # fase de la zancada
var _brazos := 0.0              # 0 colgando .. 1 al frente
var _var := 0.0                 # variación individual (desfase de los movimientos)
var _j: Node3D = null
var _forma: CollisionShape3D
var _voz: AudioStreamPlayer3D
var _etiqueta: Label3D
var S := {
	"hitPitch": Rbx.Muelle.new(2.4, 0.3), "hitYaw": Rbx.Muelle.new(2.4, 0.3), "hitHead": Rbx.Muelle.new(3.2, 0.3),
	"hitRoll": Rbx.Muelle.new(2.0, 0.35),
}


func _ready() -> void:
	_rng.randomize()
	_var = _rng.randf() * TAU
	oido = float(C.ZOMBI.Oido) * _rng.randf_range(0.85, 1.15)
	add_to_group("zombis")
	add_to_group("objetivos")       # blanco de las armas
	add_to_group(Ruido.GRUPO)       # oye los ruidos
	motion_mode = MOTION_MODE_FLOATING
	# capas: 4 = cuerpos (el jugador choca con él); choca con el escenario y con otros cuerpos
	collision_layer = 4
	collision_mask = 1 | 4
	_forma = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.85
	cap.height = 4.4                # de 1.4 studs sobre el suelo hasta la coronilla: pasa escalones
	_forma.shape = cap
	_forma.position = Vector3(0, 0.5, 0)
	add_child(_forma)
	rig = RigPersonaje.new()
	rig.name = "Rig"
	add_child(rig)
	_aspecto()
	_cuerpo_de_impacto()
	_voz = AudioStreamPlayer3D.new()
	_voz.unit_size = 12.0
	_voz.max_distance = 400.0
	_voz.position = Vector3(0, 2.0, 0)
	add_child(_voz)
	_etiqueta = Label3D.new()
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.font_size = 40
	_etiqueta.pixel_size = 0.01
	_etiqueta.outline_size = 8
	_etiqueta.no_depth_test = true
	_etiqueta.position = Vector3(0, 3.4, 0)
	_etiqueta.visible = false
	add_child(_etiqueta)
	casa = _pies()
	_gemido_t = _rng.randf_range(4.0, 14.0)


## ---------------------------------------------------------------- contrato de objetivo (armas)
func vivo() -> bool:
	return estado != Estado.MUERTO


func en_pie() -> bool:
	return estado != Estado.CAIDO and estado != Estado.MUERTO


func centro() -> Vector3:
	return (rig.P.UpperTorso as Node3D).global_position


func recibir_danio(cantidad: float, pieza: String, impulso: Vector3) -> bool:
	if _ragdoll != null and is_instance_valid(_ragdoll):
		# en el suelo (o muerto): el golpe sacude el cuerpo
		_ragdoll.golpe(pieza, impulso * 0.15)
	if not vivo():
		return false
	_impulso_golpe = impulso
	_pieza_golpe = pieza
	health = maxf(0.0, health - cantidad)
	var dir := Rbx.flat(impulso)
	dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	var k := clampf(cantidad / 30.0, 0.3, 1.6)
	var d_loc := Rbx.vec_to_obj(global_transform, dir)
	S.hitPitch.impulse(d_loc.z * 3.5 * k)
	S.hitYaw.impulse(-d_loc.x * 3.0 * k)
	S.hitRoll.impulse(d_loc.x * 2.0 * k)
	S.hitHead.impulse((d_loc.z * 4.5 if pieza != "Head" else 9.0) * k)
	if health <= 0.0:
		_morir(dir)
		return true
	# nota de dónde le han dado: se gira y va a por quien ha sido (al jugador)
	var j := _jugador()
	if j:
		_percibir(j.global_position, 1.0, true)
	if en_pie():
		_empuje += dir * minf(impulso.length() * 0.1, 6.0)
		_tambaleo_hasta = reloj + 0.25
	return false


func empujar(vel: Vector3, dur: float) -> void:
	if not en_pie():
		return
	_empuje += Rbx.flat(vel)
	_tambaleo_hasta = reloj + dur


func derribar(impulso: Vector3, dur: float) -> void:
	if not en_pie():
		return
	_impulso_golpe = impulso
	_caer(Rbx.flat(impulso), dur)
	_cambiar(Estado.CAIDO)


## ---------------------------------------------------------------- oído
## Lo llama Ruido.emitir para cada ruido del mundo (ver scripts/ruido/ruido.gd)
func oir(ev: Ruido.Evento) -> void:
	if sordos or estado == Estado.MUERTO:
		return
	var oreja := global_position + Vector3(0, 1.9, 0)
	var excluir: Array[RID] = [get_rid()]
	var r := Ruido.radio_percibido(ev, oreja, get_world_3d(), excluir, oido)
	var d := oreja.distance_to(ev.posicion)
	if d > r:
		return
	var fuerza := (1.0 - d / r) * Ruido.peso(ev.tipo)
	var del_jugador := ev.fuente != null and ev.fuente.is_in_group("jugador")
	_percibir(ev.posicion, maxf(fuerza, 0.05), del_jugador)


## algo le ha llamado la atención en pos (fuerza 0..1)
func _percibir(pos: Vector3, fuerza: float, del_jugador: bool) -> void:
	if estado == Estado.MUERTO:
		return
	alerta = clampf(maxf(alerta, fuerza) + 0.15 * fuerza, 0.0, 1.0)
	# ¿cambia de pista? lo nuevo manda si es al menos parecido a lo que recuerda (que se va olvidando);
	# un ruido nuevo del jugador siempre actualiza el rastro del jugador
	var actual := 0.0
	if pista != null:
		actual = pista.fuerza * exp(-(reloj - pista.t) / 4.0)
	if pista == null or fuerza >= actual * 0.6 or (del_jugador and pista.del_jugador):
		# (un ruido fuerte del entorno, como una bala contra una pared, puede distraerle del jugador)
		pista = Pista.new(pos, reloj, fuerza, del_jugador)
		if estado == Estado.INVESTIGAR or estado == Estado.PERSEGUIR:
			_ir_a(pos)
	if estado == Estado.DEAMBULAR or estado == Estado.BUSCAR:
		_cambiar(Estado.INVESTIGAR)
	if estado == Estado.INVESTIGAR and _toca_perseguir():
		_cambiar(Estado.PERSEGUIR)


func _toca_perseguir() -> bool:
	return pista != null and pista.del_jugador and reloj - pista.t < float(C.ZOMBI.PerseguirMemoria) \
		and alerta >= float(C.ZOMBI.PerseguirAlerta)


## pegado al jugador lo nota aunque no haga ruido (lo roza, lo huele)
func _sentir_contacto() -> void:
	var j := _jugador()
	if j == null or float(j.get("health")) <= 0.0:
		return
	if _dist_h(j.global_position) < float(C.ZOMBI.Contacto) and absf(j.global_position.y - global_position.y) < 4.0:
		_percibir(j.global_position, 1.0, true)


## ---------------------------------------------------------------- cerebro (paso de física)
func _physics_process(dt: float) -> void:
	reloj += dt
	if estado == Estado.MUERTO:
		_paso_caida(dt)
		if reloj - _muerte_t > float(C.ZOMBI.Cadaver):
			queue_free()
		return
	if estado == Estado.CAIDO:
		_paso_caida(dt)
		return
	alerta = maxf(0.0, alerta - float(C.ZOMBI.AlertaDecae) * dt)
	if not sordos:
		_sentir_contacto()
	_dir = Vector3.ZERO
	_vel = 0.0
	match estado:
		Estado.DEAMBULAR:
			_paso_deambular()
		Estado.INVESTIGAR:
			_paso_investigar()
		Estado.PERSEGUIR:
			_paso_perseguir()
		Estado.BUSCAR:
			_paso_buscar()
		Estado.ATACAR:
			_paso_atacar()
	_mover(dt)


func _cambiar(nuevo: Estado) -> void:
	if nuevo == estado:
		return
	var antes := estado
	estado = nuevo
	_estado_t = reloj
	_atascos = 0
	_progreso_t = reloj
	_progreso_pos = global_position
	match nuevo:
		Estado.DEAMBULAR:
			_destino = null
			casa = _pies()
			_pausa_hasta = reloj + _rng.randf_range(1.0, 4.0)
		Estado.INVESTIGAR, Estado.PERSEGUIR:
			if pista != null:
				_ir_a(pista.pos)
			if nuevo == Estado.PERSEGUIR and antes != Estado.ATACAR:
				_grunir(true)
		Estado.BUSCAR, Estado.ATACAR:
			_destino = null
			_golpe_hecho = false
	estado_cambiado.emit(nuevo)


func _paso_deambular() -> void:
	# de vez en cuando gime (no hace ruido para los demás: solo ambiente)
	if reloj > _gemido_t:
		_gemido_t = reloj + _rng.randf_range(10.0, 25.0)
		_grunir(false)
	if not deambula:
		return
	if _destino == null:
		if reloj < _pausa_hasta:
			return
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * float(C.ZOMBI.Deambular)
		_ir_a(_punto_navegable(casa + Vector3(cos(a) * r, 0, sin(a) * r)))
	if _llegado(2.0) or _atascado() or reloj - _estado_t > 30.0:
		_destino = null
		_estado_t = reloj
		_pausa_hasta = reloj + _rng.randf_range(2.0, 6.0)
		return
	_seguir_camino(float(C.ZOMBI.Andar) * 0.75)


func _paso_investigar() -> void:
	if _quiere_atacar():
		_cambiar(Estado.ATACAR)
		return
	if _toca_perseguir():
		_cambiar(Estado.PERSEGUIR)
		return
	if _destino == null or _llegado(2.5) or _atascado():
		_cambiar(Estado.BUSCAR)
		return
	# cuanto más alerta, más prisa
	var k := clampf(alerta / float(C.ZOMBI.PerseguirAlerta), 0.0, 1.0)
	_seguir_camino(lerpf(float(C.ZOMBI.Andar), float(C.ZOMBI.Trotar), k))


func _paso_perseguir() -> void:
	if _quiere_atacar():
		_cambiar(Estado.ATACAR)
		return
	# hace rato que no oye al jugador: va (más despacio) a donde lo oyó por última vez
	if pista == null or reloj - pista.t > float(C.ZOMBI.PerseguirMemoria):
		_cambiar(Estado.INVESTIGAR)
		return
	if _destino == null or _llegado(1.5) or _atascado():
		# está donde lo oyó y no hay nada nuevo: mira alrededor
		if reloj - pista.t > 0.8:
			_cambiar(Estado.BUSCAR)
		return
	_seguir_camino(float(C.ZOMBI.Correr))


func _paso_buscar() -> void:
	# quieto, girando la cabeza (y el cuerpo) a un lado y a otro
	var giro := sin((reloj - _estado_t) * 1.3 + _var) * 1.2
	rotation.y = Rbx.wrap_a(rotation.y + giro * 0.8 * get_physics_process_delta_time())
	if reloj - _estado_t > float(C.ZOMBI.Buscar):
		_cambiar(Estado.DEAMBULAR)


func _paso_atacar() -> void:
	var j := _jugador()
	var t := reloj - _estado_t
	if j:
		_mirar_hacia(j.global_position, 10.0)
	if not _golpe_hecho and t >= float(C.ZOMBI.PreparaGolpe):
		_golpe_hecho = true
		if j and float(j.get("health")) > 0.0 and _dist_h(j.global_position) <= float(C.ZOMBI.Alcance) + 0.8:
			var al := Rbx.flat(j.global_position - global_position).normalized()
			if al.dot(Rbx.look(global_transform)) > 0.2 and j.has_method("recibir_danio"):
				j.call("recibir_danio", float(C.ZOMBI.Danio), global_position)
	if t >= float(C.ZOMBI.Cadencia):
		var vivo_j := j != null and float(j.get("health")) > 0.0
		_cambiar(Estado.PERSEGUIR if (vivo_j and pista != null) else Estado.BUSCAR)


func _quiere_atacar() -> bool:
	var j := _jugador()
	if j == null or float(j.get("health")) <= 0.0 or alerta < 0.3:
		return false
	return _dist_h(j.global_position) <= float(C.ZOMBI.Alcance) and absf(j.global_position.y - global_position.y) < 4.0


## ---------------------------------------------------------------- movimiento
func _mover(dt: float) -> void:
	var v := velocity
	var h := Vector3(v.x, 0, v.z)
	var obj_h := _dir * _vel
	if reloj < _tambaleo_hasta:
		obj_h *= 0.2
	obj_h += _empuje
	_empuje = _empuje.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	h = h.lerp(obj_h, 1.0 - exp(-6.0 * dt)) # algo de inercia: arranca y frena con peso
	# suelo: el cuerpo flota a CENTRO studs (como el Humanoid del jugador): sube escalones sin saltar
	var gy = _suelo_y()
	if gy != null and global_position.y - float(gy) <= CENTRO + 0.6:
		v.y = clampf((float(gy) + CENTRO - global_position.y) * 15.0, -30.0, 40.0)
	else:
		v.y -= float(C.WORLD.Gravity) * dt
	velocity = Vector3(h.x, v.y, h.z)
	move_and_slide()
	if _dir.length() > 0.1 and estado != Estado.ATACAR:
		_mirar_hacia(global_position + _dir, float(C.ZOMBI.Giro))


func _mirar_hacia(p: Vector3, rapidez: float) -> void:
	var d := Rbx.flat(p - global_position)
	if d.length() < 0.05:
		return
	var ty := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, ty, minf(1.0, rapidez * get_physics_process_delta_time()))


func _suelo_y():
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -(CENTRO + 2.0), 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or (r.normal as Vector3).y < 0.5:
		return null
	return (r.position as Vector3).y


func _pies() -> Vector3:
	return global_position - Vector3(0, CENTRO, 0)


func _dist_h(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## ---------------------------------------------------------------- navegación
## Camino por la malla de navegación que hornea el DirectorZombis (si no hay malla, va en línea recta).
func _ir_a(p: Vector3) -> void:
	_destino = p
	_camino_t = -9.0
	_progreso_t = reloj
	_progreso_pos = global_position


func _recalcular_camino() -> void:
	_camino_t = reloj
	_camino = PackedVector3Array()
	_camino_i = 0
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return
	_camino = NavigationServer3D.map_get_path(mapa, _pies(), _destino, true)
	_camino_i = 1 if _camino.size() > 1 else 0


func _seguir_camino(velocidad: float) -> void:
	if _destino == null:
		return
	if reloj - _camino_t > 1.0:
		_recalcular_camino()
	var meta: Vector3 = _destino
	if not _camino.is_empty():
		while _camino_i < _camino.size() - 1 and _dist_h(_camino[_camino_i]) < 1.2:
			_camino_i += 1
		meta = _camino[_camino_i]
	var d := Rbx.flat(meta - global_position)
	if d.length() > 0.05:
		_dir = d.normalized()
		_vel = velocidad


## ha llegado al destino (o al punto más cercano al que se puede llegar)
func _llegado(margen: float) -> bool:
	if _destino == null:
		return true
	if _dist_h(_destino) < margen:
		return true
	if not _camino.is_empty() and reloj - _camino_t < 1.0 and _camino_i >= _camino.size() - 1:
		return _dist_h(_camino[_camino.size() - 1]) < margen
	return false


## sin avanzar apenas en un buen rato (otro zombi, un muñeco, una esquina): se rinde
func _atascado() -> bool:
	if reloj - _progreso_t < 1.5:
		return false
	var avance := _dist_h(_progreso_pos)
	_progreso_t = reloj
	_progreso_pos = global_position
	_atascos = _atascos + 1 if avance < 0.6 else 0
	return _atascos >= 2


func _punto_navegable(p: Vector3) -> Vector3:
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return p
	return NavigationServer3D.map_get_closest_point(mapa, p)


## ---------------------------------------------------------------- caer, morir, levantarse
func _caer(dir: Vector3, dur: float) -> void:
	_caida_dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	_levantar_t = reloj + dur
	_levantando = false
	_forma.disabled = true
	# ragdoll: el golpe (bate, atropello, bala) lanza el cuerpo en su dirección
	if _ragdoll == null or not is_instance_valid(_ragdoll):
		var imp := _impulso_golpe * 0.3
		if imp.length() > 16.0:
			imp = imp.normalized() * 16.0
		if imp.length() < 2.0:
			imp = _caida_dir * 4.0 + Vector3(0, 1.0, 0)
		_ragdoll = Ragdoll.iniciar(self, rig, velocity, {"comportamiento": "caer", "impulso": imp, "pieza": _pieza_golpe,
			"duracion": minf(dur, 30.0)})
		_ragdoll.recuperado.connect(_ragdoll_levantar)
	velocity = Vector3.ZERO


func _morir(dir: Vector3) -> void:
	_caer(dir, 1e9)
	if _ragdoll != null and is_instance_valid(_ragdoll):
		_ragdoll.morir()
	_muerte_t = reloj
	_cambiar(Estado.MUERTO)
	remove_from_group(Ruido.GRUPO)
	collision_layer = 0
	murio.emit(self)


func _paso_caida(dt: float) -> void:
	if _ragdoll != null or _sale_ragdoll_t >= 0.0:
		# con ragdoll: la física lleva el cuerpo; al recuperarse, mientras se mezcla con la postura de pie
		if _sale_ragdoll_t >= 0.0 and reloj > _sale_ragdoll_t:
			_sale_ragdoll_t = -1.0
			_ragdoll = null
			_caida = 0.0
			_forma.disabled = false
			alerta = 1.0
			var jr := _jugador()
			if jr:
				_percibir(jr.global_position, 1.0, true)
			_cambiar(Estado.PERSEGUIR if _toca_perseguir() else Estado.INVESTIGAR)
		return
	if estado == Estado.CAIDO and reloj > _levantar_t and _caida >= 0.999:
		_levantando = true
	if _levantando:
		_caida = maxf(0.0, _caida - dt * 1.1)
		if _caida <= 0.0:
			_levantando = false
			_forma.disabled = false
			alerta = 1.0
			var j := _jugador()
			if j:
				_percibir(j.global_position, 1.0, true)
			_cambiar(Estado.PERSEGUIR if _toca_perseguir() else Estado.INVESTIGAR)
	else:
		# cae como un tronco: cada vez más deprisa
		_caida = minf(1.0, _caida + dt * (0.6 + 4.0 * _caida))
	# girar el muñeco alrededor de los pies
	var e := _caida * _caida * (3.0 - 2.0 * _caida)
	var eje_m := Vector3.UP.cross(_caida_dir)
	var eje := (global_transform.basis.inverse() * eje_m).normalized() if eje_m.length() > 0.01 else Vector3.RIGHT
	var r := Basis(eje, e * PI * 0.5)
	var pies := Vector3(0, -CENTRO, 0)
	rig.transform = Transform3D(r, pies - r * pies + Vector3(0, 0.45 * e, 0))


## ---------------------------------------------------------------- animación (barata, para hordas)
## Sin IK: ángulos directos por fase de zancada. La fase avanza con la distancia recorrida para que los
## pies apenas resbalen. Brazos al frente cuando está alerta (el clásico), colgando cuando deambula.
func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	var M := rig.M
	var t := reloj + _var
	var vh := Vector2(velocity.x, velocity.z).length() if en_pie() else 0.0
	var a := clampf(0.22 + vh * 0.05, 0.22, 0.6)            # ángulo de la zancada
	_fase += PI * vh / maxf(0.3, 2.0 * PIERNA * sin(a)) * dt
	var amp := clampf(vh / 1.5, 0.0, 1.0)
	var s := sin(_fase)
	var cs := cos(_fase)
	var hp: float = S.hitPitch.step(dt)
	var hy: float = S.hitYaw.step(dt)
	var hh: float = S.hitHead.step(dt)
	var hr: float = S.hitRoll.step(dt)
	# ataque: levanta los brazos (preparación) y se lanza (golpe)
	var atk := 0.0
	var lanza := 0.0
	if estado == Estado.ATACAR:
		var ta := reloj - _estado_t
		var pg := float(C.ZOMBI.PreparaGolpe)
		atk = Rbx.smooth(ta / pg) * (1.0 - Rbx.smooth((ta - pg) / 0.25))
		lanza = Rbx.smooth((ta - pg + 0.1) / 0.15) * (1.0 - Rbx.smooth((ta - pg - 0.2) / 0.4))
	var brazos_obj := 1.0 if (estado == Estado.INVESTIGAR or estado == Estado.PERSEGUIR or estado == Estado.ATACAR) else 0.0
	_brazos = Rbx.damp(_brazos, brazos_obj, 3.0, dt)
	var caido := _caida
	# pelvis: baja con la zancada (las piernas en ángulo "acortan" el cuerpo) y cojea un poco
	var baja := PIERNA * (1.0 - cos(a * amp * absf(s))) + 0.08
	(M.Root as RigPersonaje.Motor).transform = Rbx.cf(0, -baja, -lanza * 0.4) * Rbx.ang(-0.06 - lanza * 0.15, s * 0.1 * amp, s * 0.06 * amp + 0.04)
	# tronco encorvado, balanceándose
	(M.Waist as RigPersonaje.Motor).transform = Rbx.ang(0, -s * 0.14 * amp + hy * 0.16, 0) \
		* Rbx.ang(-0.3 + hp * 0.16 + atk * 0.25 - lanza * 0.35 + sin(t * 0.9) * 0.03, 0, sin(t * 0.5) * 0.05 + hr * 0.12)
	# cabeza: cae hacia un lado y se bambolea; buscando, mira a todas partes
	var mira := sin(t * 1.2) * 0.6 if estado == Estado.BUSCAR else sin(t * 0.6) * 0.25
	(M.Neck as RigPersonaje.Motor).transform = Rbx.ang(0, mira, 0) * Rbx.ang(0.22 + hh * 0.14 + sin(t * 1.3) * 0.05, 0, 0.2 + sin(t * 0.7) * 0.12)
	# piernas: la derecha arrastra (menos zancada y menos rodilla)
	(M.LeftHip as RigPersonaje.Motor).transform = Rbx.ang(s * a * amp + caido * 0.25, 0, -0.04 - caido * 0.12)
	(M.RightHip as RigPersonaje.Motor).transform = Rbx.ang(-s * a * amp * 0.75 + caido * 0.15, 0, 0.06 + caido * 0.15)
	(M.LeftKnee as RigPersonaje.Motor).transform = Rbx.ang(-0.12 - maxf(0.0, cs) * 0.75 * amp - caido * 0.4, 0, 0)
	(M.RightKnee as RigPersonaje.Motor).transform = Rbx.ang(-0.1 - maxf(0.0, -cs) * 0.45 * amp - caido * 0.2, 0, 0)
	(M.LeftAnkle as RigPersonaje.Motor).transform = Rbx.ang(-s * a * amp * 0.4, 0, 0)
	(M.RightAnkle as RigPersonaje.Motor).transform = Rbx.ang(s * a * amp * 0.3, 0, 0)
	# brazos: colgando con el paso, o al frente (y más arriba al atacar)
	for lado in ["L", "R"]:
		var sg := -1.0 if lado == "L" else 1.0
		var colgando := 0.06 + (-s if lado == "L" else s) * 0.22 * amp
		var frente := 1.3 + sin(t * 1.7 + sg) * 0.08 + atk * 0.5 - lanza * 0.1
		var pitch_b := lerpf(colgando, frente, _brazos)
		var sh: RigPersonaje.Motor = M.LeftShoulder if lado == "L" else M.RightShoulder
		var el: RigPersonaje.Motor = M.LeftElbow if lado == "L" else M.RightElbow
		var wr: RigPersonaje.Motor = M.LeftWrist if lado == "L" else M.RightWrist
		sh.transform = Rbx.ang(pitch_b + hp * 0.1, sg * 0.05 * _brazos, sg * (0.1 + caido * 1.1 - 0.04 * _brazos))
		el.transform = Rbx.ang(lerpf(0.2, 0.3, _brazos) + caido * 0.4 - lanza * 0.2, 0, 0)
		wr.transform = Rbx.ang(-0.35 * _brazos, 0, 0)
	rig.aplicar()
	_etiqueta.visible = Ruido.ver
	if Ruido.ver:
		_etiqueta.text = "%s\nalerta %.2f" % [NOMBRE_ESTADO[estado], alerta]
		_etiqueta.modulate = Color(1, 1.0 - alerta * 0.7, 1.0 - alerta * 0.8)


## ---------------------------------------------------------------- aspecto
const OCULTAR := ["Backpack", "BackpackPocket", "Bedroll", "Holster", "MagPouch1", "MagPouch2", "Buckle", "Zipper"]
const PIEL := ["Head", "EarL", "EarR", "Nose", "LeftHand", "RightHand"]
static var _mats := {}


## el mismo muñeco que el superviviente, sin mochila ni equipo, con piel enferma y ropa sucia
func _aspecto() -> void:
	var piel: Color = [Color8(118, 132, 104), Color8(132, 128, 110), Color8(108, 118, 112)][_rng.randi() % 3]
	for n in rig.find_children("M_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nombre := String(mi.name).substr(2)
		if nombre in OCULTAR:
			mi.visible = false
			continue
		var base := mi.material_override as StandardMaterial3D
		if base == null:
			continue
		var c := base.albedo_color
		if nombre in PIEL:
			c = piel
		elif nombre.begins_with("Eye"):
			c = Color8(150, 40, 30)
		elif nombre == "Mouth":
			c = Color8(70, 22, 20)
		else:
			c = c.lerp(Color8(70, 58, 45), 0.35).darkened(0.25)
		mi.material_override = _material(c, base.roughness)


static func _material(c: Color, rugosidad: float) -> StandardMaterial3D:
	var k := c.to_html() + str(rugosidad)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rugosidad
		_mats[k] = m
	return _mats[k]


## Cuerpo de impacto de las balas (capa 2): UNA caja que envuelve todo el cuerpo (con los brazos al frente).
## No hay un cuerpo físico por pieza como en el maniquí: mover 15 cuerpos por zombi en cada fotograma
## cuesta ~30 % más (medido: 0,12 frente a 0,09 ms por zombi). La pieza exacta se calcula solo cuando una
## bala entra en la caja (impacto_bala). Cuelga del Rig, así que solo se mueve con el zombi (y cae con él).
func _cuerpo_de_impacto() -> void:
	var sb := StaticBody3D.new()
	sb.name = "Impacto"
	sb.collision_layer = 2
	sb.collision_mask = 0
	sb.set_meta("objetivo", self)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.6, 5.65, 2.9)
	cs.shape = bx
	cs.position = Vector3(0, -0.33, -0.85)
	sb.add_child(cs)
	rig.add_child(sb)


## Una bala que entra por "origen" en dirección "dir": ¿qué pieza del muñeco toca primero?
## Devuelve {pieza, punto} o {} si pasa sin tocar ninguna (entre los brazos…): la bala sigue su camino.
## (parte del contrato de objetivo para blancos con un único cuerpo de impacto; ver la guía)
func impacto_bala(origen: Vector3, dir: Vector3) -> Dictionary:
	var mejor_t := INF
	var mejor := ""
	for n in rig.P:
		if n == "HumanoidRootPart":
			continue
		var nd: Node3D = rig.P[n]
		var t := _rayo_caja(nd.global_transform, nd.get_meta("size"), origen, dir)
		if t >= 0.0 and t < mejor_t:
			mejor_t = t
			mejor = n
	if mejor == "":
		return {}
	return {"pieza": mejor, "punto": origen + dir * mejor_t}


## distancia a lo largo del rayo hasta una caja orientada (o -1 si no la toca). Método de las "losas".
static func _rayo_caja(caja: Transform3D, tam: Vector3, origen: Vector3, dir: Vector3) -> float:
	var inv := caja.affine_inverse()
	var o := inv * origen
	var d := inv.basis * dir
	var medio := tam * 0.5
	var t0 := -INF
	var t1 := INF
	for eje in 3:
		if absf(d[eje]) < 1e-8:
			if absf(o[eje]) > medio[eje]:
				return -1.0
			continue
		var a := (-medio[eje] - o[eje]) / d[eje]
		var b := (medio[eje] - o[eje]) / d[eje]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	if t1 < maxf(t0, 0.0):
		return -1.0
	return maxf(t0, 0.0)


## ---------------------------------------------------------------- voz
## gruñido: fuerte = al empezar a perseguir (los zombis cercanos lo oyen); flojo = gemido de ambiente
func _grunir(fuerte: bool) -> void:
	if fuerte:
		if reloj - _grunido_t < float(C.ZOMBI.GrunidoCada):
			return
		_grunido_t = reloj
		Ruido.emitir(self, global_position + Vector3(0, 1.9, 0), C.RUIDO.Grunido, Ruido.GRUNIDO, self)
	_voz.stream = _voz_sintetica(_rng.randi() % 3)
	_voz.pitch_scale = _rng.randf_range(0.85, 1.1)
	_voz.volume_db = 4.0 if fuerte else -6.0
	_voz.play()


static var _voces: Array[AudioStreamWAV] = []
static var _en_escena := 0 # zombis vivos en el árbol: el último que sale vacía la caché de voces


func _enter_tree() -> void:
	_en_escena += 1


func _exit_tree() -> void:
	_en_escena -= 1
	if _en_escena <= 0:
		_voces.clear() # si no, Godot avisa de recursos "perdidos" al cerrar


## no hay archivos de audio todavía: gruñido sintetizado (grave, áspero, con vibrato)
static func _voz_sintetica(i: int) -> AudioStreamWAV:
	if _voces.is_empty():
		for k in 3:
			_voces.append(_sintetizar(k))
	return _voces[i % _voces.size()]


static func _sintetizar(semilla: int) -> AudioStreamWAV:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + semilla
	var dur := 1.1 + 0.25 * semilla
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var f0 := 68.0 + 11.0 * semilla
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := pow(sin(PI * t / dur), 0.6)
		var f := f0 + sin(TAU * 5.3 * t) * 5.0 + sin(TAU * 0.8 * t) * 12.0
		ph += TAU * f / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var v := (sin(ph) + 0.55 * sin(2.0 * ph + 0.3) + 0.3 * sin(3.0 * ph + 1.1)) * 0.3 + lp * 0.9
		v *= env * (0.8 + 0.2 * sin(TAU * 13.0 * t))
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## ---------------------------------------------------------------- utilidades
func _jugador() -> Node3D:
	if not is_instance_valid(_j):
		_j = get_tree().get_first_node_in_group("jugador") as Node3D
	return _j


func nombre_estado() -> String:
	return NOMBRE_ESTADO[estado]


## el ragdoll se ha parado y ya toca levantarse: de pie donde quedó el cuerpo, mirando hacia su cabeza
func _ragdoll_levantar() -> void:
	if _ragdoll == null or estado != Estado.CAIDO or reloj < _levantar_t - 0.01:
		# (aún no: el Ragdoll vuelve a avisar en cuanto se pare, si se le pide)
		if _ragdoll != null and estado == Estado.CAIDO:
			_ragdoll._avisado = false
			_ragdoll.duracion = maxf(_ragdoll.duracion, _ragdoll._t + 0.3)
		return
	var pel := _ragdoll.pelvis()
	var dir := _ragdoll.direccion_cabeza()
	var q := PhysicsRayQueryParameters3D.create(pel + Vector3(0, 3, 0), pel + Vector3(0, -12, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var gy: float = (r.position as Vector3).y if not r.is_empty() else pel.y - 0.5
	global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), Vector3(pel.x, gy + CENTRO, pel.z))
	_ragdoll.terminar(0.9)
	_sale_ragdoll_t = reloj + 0.9

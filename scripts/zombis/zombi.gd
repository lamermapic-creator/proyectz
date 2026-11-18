class_name Zombi
extends CharacterBody3D
## ZOMBI (guía completa en docs/RUIDO_Y_ZOMBIS.md). OYE los ruidos del sistema Ruido, VE al jugador (cono de
## visión + periférica según la postura, con una "sospecha" que sube poco a poco) y lo nota si lo tiene pegado.
##
##   DEAMBULAR ──oye / ve algo──► INVESTIGAR ──llega──► BUSCAR (varios sitios) ──nada──► DEAMBULAR
##                                   │    ▲
##     le ve del todo, o ruidos del  │    │ le pierde: va a donde iba el jugador (anticipa)
##     jugador seguidos (alerta alta)▼    │ o deja de oírle "PerseguirMemoria" s
##                                  PERSEGUIR ──a "Alcance"──► ATACAR ──► PERSEGUIR
##   cualquiera ──bate──► CAIDO ──se levanta──► PERSEGUIR      cualquiera ──vida 0──► MUERTO
##   herido de lejos sin haberte oído ni visto ──► INVESTIGAR hacia donde vino el golpe (no sabe dónde estás)
##   Para pegarte (o notarte por contacto) necesita camino libre: las paredes lo impiden (_alcanzable).
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
## pruebas: todos los zombis están ciegos (F8 en desarrollo)
static var ciegos := false

## si es false se queda en su sitio cuando no oye nada (útil en pruebas)
@export var deambula := true
## Vacío = aspecto clásico; aleatorio = colección de Blender; o id del catálogo (civil, sanitario...).
@export var variante_visual := "aleatorio"
const VARIANTES_VISUALES := ["civil", "sanitario", "obrero", "mecanico", "policia", "bombero",
	"excursionista", "oficinista", "repartidor", "paciente", "granjero", "vagabundo"]


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
var sospecha := 0.0             # 0..1: cuánto cree haber visto al jugador (1 = le ha visto)
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
var _bala := {} # contexto solo durante recibir_disparo; el contrato cuerpo a cuerpo no cambia
var _reaccion_balas := ImpactoBalistico.new()
var _pieza_golpe := "UpperTorso"
var _sale_ragdoll_t := -1.0     # mezclando la postura del suelo con la de pie (hasta esta hora)
var _fase := 0.0                # fase de la zancada
var _brazos := 0.0              # 0 colgando .. 1 al frente
var _var := 0.0                 # variación individual (desfase de los movimientos)
var _j: Node3D = null
# vista e ingenio (v1)
var _visto := false             # le está viendo ahora mismo (sospecha llena)
var _ultima_vista_t := -99.0
var _ultima_vista_pos := Vector3.ZERO
var _ultima_vista_vel := Vector3.ZERO
var _vista_t := 0.0             # próxima comprobación de vista
var _vislumbre_t := -99.0       # última vez que "le pareció ver algo"
var _reaccion_hasta := 0.0      # girándose hacia lo que ha oído/visto antes de moverse
var _busqueda: Array[Vector3] = []   # sitios que le quedan por registrar
var _busqueda_dir := Vector3.ZERO    # hacia dónde creía que iba el jugador
var _mirar_hasta := 0.0         # mirando alrededor en un sitio de la búsqueda
var _buscar_limite := 6.0       # s máximos en BUSCAR (más si busca al jugador)
var _desvio = null              # punto para rodear un obstáculo (Vector3 o null)
var _desvio_t := 0.0
var _rodeos := 0
var _cono: MeshInstance3D = null # cono de visión (solo depuración, F6)
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
	var variante := variante_visual
	if variante == "aleatorio":
		variante = VARIANTES_VISUALES[_rng.randi() % VARIANTES_VISUALES.size()]
	if variante in VARIANTES_VISUALES:
		rig.modelo = "zombi_" + variante
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


func separar_extremidad(pieza: String, direccion: Vector3) -> void:
	if not vivo() and is_instance_valid(_ragdoll):
		_ragdoll.separar(pieza, direccion)


func recibir_danio(cantidad: float, pieza: String, impulso: Vector3) -> bool:
	if _bala.is_empty() and _ragdoll != null and is_instance_valid(_ragdoll):
		# en el suelo (o muerto): el golpe sacude el cuerpo
		_ragdoll.golpe(pieza, impulso * 0.15)
	if not vivo():
		return false
	_impulso_golpe = impulso
	_pieza_golpe = pieza
	health = maxf(0.0, health - cantidad)
	var dir := Rbx.flat(impulso)
	dir = dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z
	if _bala.is_empty():
		var k := clampf(cantidad / 30.0, 0.3, 1.6)
		var d_loc := Rbx.vec_to_obj(global_transform, dir)
		S.hitPitch.impulse(d_loc.z * 3.5 * k)
		S.hitYaw.impulse(-d_loc.x * 3.0 * k)
		S.hitRoll.impulse(d_loc.x * 2.0 * k)
		S.hitHead.impulse((d_loc.z * 4.5 if pieza != "Head" else 9.0) * k)
	if health <= 0.0:
		_morir(dir)
		return true
	# nota de qué lado le han dado (y, si lo tiene cerca o ya lo había notado, quién ha sido)
	_notar_golpe(impulso)
	if en_pie():
		_empuje += dir * (minf(impulso.length() * 0.1, 6.0) if _bala.is_empty() else 0.0)
		_tambaleo_hasta = reloj + 0.25
	return false


func empujar(vel: Vector3, dur: float) -> void:
	if not en_pie():
		return
	_empuje += Rbx.flat(vel)
	_tambaleo_hasta = reloj + dur
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
			_ir_a_si_cambia(pos)
	if estado == Estado.DEAMBULAR or estado == Estado.BUSCAR:
		_cambiar(Estado.INVESTIGAR)
	if estado == Estado.INVESTIGAR and _toca_perseguir():
		_cambiar(Estado.PERSEGUIR)


func _toca_perseguir() -> bool:
	return pista != null and pista.del_jugador and reloj - pista.t < float(C.ZOMBI.PerseguirMemoria) \
		and alerta >= float(C.ZOMBI.PerseguirAlerta)


## Le han hecho daño. El golpe le dice DE QUÉ LADO vino (el impulso lleva la dirección de la bala o del arma), no
## dónde está quien lo hizo. Solo sabe quién ha sido si lo tiene cerca (HeridaCerca: cuerpo a cuerpo, a quemarropa),
## si le está viendo o si le acaba de oír (el estampido llega antes que la bala). Si no, va a mirar HeridaRastro
## studs hacia donde vino el golpe: un disparo lejano y sin oír lo enfurece y lo acerca, pero no te delata.
func _notar_golpe(impulso: Vector3) -> void:
	var j := _jugador()
	if j == null or estado == Estado.MUERTO:
		return
	if _visto or (_dist_h(j.global_position) <= float(C.ZOMBI.HeridaCerca) and absf(j.global_position.y - global_position.y) < 8.0):
		_percibir(j.global_position, 1.0, true)
		return
	if pista != null and pista.del_jugador and reloj - pista.t < float(C.ZOMBI.PerseguirMemoria):
		# ya sabía dónde estaba (lo acaba de oír o de ver): el golpe solo lo enfurece
		_percibir(pista.pos, 1.0, true)
		return
	var de := -Rbx.flat(impulso)
	if de.length() < 0.01:
		_percibir(_pies(), 1.0, false) # ni idea de dónde vino: mira a su alrededor
		return
	_percibir(_punto_navegable(_pies() + de.normalized() * float(C.ZOMBI.HeridaRastro)), 1.0, false)


## pegado al jugador lo nota aunque no haga ruido (lo roza, lo huele), salvo que haya una pared en medio
func _sentir_contacto() -> void:
	var j := _jugador()
	if j == null or float(j.get("health")) <= 0.0:
		return
	if _dist_h(j.global_position) < float(C.ZOMBI.Contacto) and absf(j.global_position.y - global_position.y) < 4.0 \
			and _alcanzable(j):
		_percibir(j.global_position, 1.0, true)


## ¿hay camino libre para las manos (y la nariz) hasta el jugador? Los mismos rayos que la vista (cabeza, pecho y
## cadera, contra el escenario, capa 1): con una pared en medio ni lo nota por contacto ni le puede pegar; por
## encima de una barrera baja sí (basta con que una de las tres partes quede a tiro).
## (2026-11-10: antes se miraba solo la distancia y pegaba a través de paredes de menos de ~2 studs)
func _alcanzable(j: Node3D) -> bool:
	var ojos := global_position + Vector3(0, 2.0, 0)
	if j.get("rig") == null:
		# blanco sin muñeco: un solo rayo a su centro
		var q := PhysicsRayQueryParameters3D.create(ojos, j.global_position, 1)
		q.exclude = _no_tapan(j)
		return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	return _fraccion_visible(j, ojos) > 0.0


## cuerpos que no cuentan como pared entre el zombi y el jugador: los de los dos y la moto que conduce (la moto
## está en la capa 1 y taparía a su propio piloto; una moto aparcada sí tapa)
func _no_tapan(j: Node3D) -> Array[RID]:
	var excluir: Array[RID] = [get_rid()]
	if j is CollisionObject3D:
		excluir.append((j as CollisionObject3D).get_rid())
	var m = j.get("moto")
	if m is CollisionObject3D and is_instance_valid(m):
		excluir.append((m as CollisionObject3D).get_rid())
	return excluir


## ---------------------------------------------------------------- vista (v1)
## Cada "VistaIntervalo" s mira si ve al jugador. Lo que ve llena la SOSPECHA (0..1): más deprisa cuanto más
## cerca, más en el centro de la vista, más se mueva el jugador y más alerta esté el zombi. Con la sospecha
## a medias "le parece ver algo" y se acerca a mirar; llena, le ha visto y le persigue sabiendo dónde está.
## Si le pierde de vista, va a donde estaría el jugador si siguió igual (anticipa) y luego le busca.
func _paso_vista() -> void:
	if reloj < _vista_t:
		return
	var intervalo := float(C.ZOMBI.VistaIntervalo)
	_vista_t = reloj + intervalo
	var ve := 0.0 if ciegos else _cuanto_ve()
	if ve > 0.0:
		sospecha = minf(1.0, sospecha + ve * intervalo)
	else:
		sospecha = maxf(0.0, sospecha - float(C.ZOMBI.VistaOlvido) * intervalo)
	var j := _jugador()
	if ve > 0.0 and sospecha >= 1.0:
		# le ha visto: sabe dónde está y hacia dónde va
		_visto = true
		_ultima_vista_t = reloj
		_ultima_vista_pos = j.global_position
		_ultima_vista_vel = j.get("vel_real")
		_percibir(j.global_position, 1.0, true)
	elif _visto and reloj - _ultima_vista_t > 0.4:
		_perder_vista()
	elif ve > 0.0 and sospecha >= float(C.ZOMBI.VistaSospecha) and reloj - _vislumbre_t > 0.5:
		_vislumbre_t = reloj
		_vislumbrar(j.global_position)


## sospecha por segundo que le da lo que ve ahora mismo (0 = no ve al jugador)
func _cuanto_ve() -> float:
	var j := _jugador()
	if j == null or float(j.get("health")) <= 0.0:
		return 0.0
	# de pie, agachado o tumbado: hasta dónde se le ve y cuánto se le nota alrededor (ZConfig.STANCE)
	var postura: Dictionary = C.STANCE[clampi(int(j.get("stance")), 0, 2)]
	var ojos := global_position + Vector3(0, 2.0, 0)
	var hacia := j.global_position - ojos
	var d := hacia.length()
	var alcance := float(C.ZOMBI.VistaAlcance) * float(postura.Sight) * (1.0 + 0.3 * alerta)
	var periferica := float(C.ZOMBI.VistaPeriferica) * float(postura.Near)
	if d > maxf(alcance, periferica):
		return 0.0
	var plano := Rbx.flat(hacia)
	var ang := rad_to_deg(Rbx.flat(Rbx.look(global_transform)).angle_to(plano)) if plano.length() > 0.05 else 0.0
	var en_cono := ang <= float(C.ZOMBI.VistaAngulo) and d <= alcance
	if not en_cono and d > periferica:
		return 0.0
	var visible := _fraccion_visible(j, ojos)
	if visible <= 0.0:
		return 0.0
	var k_dist := 0.3 + 1.4 * clampf(1.0 - d / maxf(alcance, 0.1), 0.0, 1.0)
	var k_ang := (0.6 + 0.4 * (1.0 - ang / float(C.ZOMBI.VistaAngulo))) if en_cono else 0.5
	var rapidez_j := Rbx.flat(j.get("vel_real")).length()
	var k_mov := 0.7 if rapidez_j < 0.5 else 1.0 + minf(rapidez_j / 14.0, 1.0) * 0.8 # quieto se ve menos
	return float(C.ZOMBI.VistaRapidez) * visible * k_dist * k_ang * k_mov * (1.0 + 0.8 * alerta)


## parte del jugador a la vista (0..1): rayos a su cabeza, pecho y cadera (las piezas reales del muñeco, así
## agachado o tumbado están más bajas). Tapa el escenario (capa 1); los cuerpos de los dos (y la moto que
## conduce el jugador) no cuentan.
func _fraccion_visible(j: Node3D, ojos: Vector3) -> float:
	var r = j.get("rig")
	if r == null:
		return 0.0
	var piezas: Dictionary = r.P
	var excluir := _no_tapan(j)
	var espacio := get_world_3d().direct_space_state
	var vistas := 0
	for n in ["Head", "UpperTorso", "LowerTorso"]:
		var nd: Node3D = piezas.get(n)
		if nd == null:
			continue
		var q := PhysicsRayQueryParameters3D.create(ojos, nd.global_position, 1)
		q.exclude = excluir
		if espacio.intersect_ray(q).is_empty():
			vistas += 1
	return vistas / 3.0


## le parece haber visto algo: va a mirar, sin saber todavía que es el jugador (no le persigue)
func _vislumbrar(pos: Vector3) -> void:
	if estado == Estado.PERSEGUIR or estado == Estado.ATACAR:
		return
	alerta = maxf(alerta, 0.3)
	var actual := pista.fuerza * exp(-(reloj - pista.t) / 4.0) if pista != null else 0.0
	if pista == null or 0.3 >= actual * 0.6:
		pista = Pista.new(pos, reloj, 0.3, false)
		if estado == Estado.INVESTIGAR:
			_ir_a_si_cambia(pos)
	if estado == Estado.DEAMBULAR or estado == Estado.BUSCAR:
		_cambiar(Estado.INVESTIGAR)


## le ha perdido de vista: va a donde ESTARÍA el jugador si siguió igual (anticipa) y luego le busca por allí
func _perder_vista() -> void:
	_visto = false
	var v := Rbx.flat(_ultima_vista_vel)
	var destino := _ultima_vista_pos
	_busqueda_dir = Vector3.ZERO
	if v.length() > 1.0:
		_busqueda_dir = v.normalized()
		destino += _busqueda_dir * minf(v.length() * float(C.ZOMBI.Anticipar), 12.0)
	destino = _punto_navegable(destino)
	pista = Pista.new(destino, reloj, 1.0, true)
	if estado == Estado.PERSEGUIR or estado == Estado.INVESTIGAR:
		_ir_a(destino)


## ---------------------------------------------------------------- cerebro (paso de física)
func _physics_process(dt: float) -> void:
	reloj += dt
	if _fuera_del_mundo():
		return
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
	_paso_vista()
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


## FONDO DEL MUNDO (2026-11-10): si se cae del mapa (él o su cuerpo en ragdoll) por debajo de ZConfig.WORLD.FondoMundo
## desaparece, en vez de caer para siempre. Cuenta como muerto para quien escucha "murio" (el director lo repone).
func _fuera_del_mundo() -> bool:
	var y := global_position.y
	# en el suelo manda el cuerpo del ragdoll (el nodo se queda donde cayó); mientras se levanta (mezcla) el
	# ragdoll ya no tiene cuerpos y vuelve a mandar el nodo
	if _ragdoll != null and is_instance_valid(_ragdoll) and _sale_ragdoll_t < 0.0 and _ragdoll.cuerpos.has("LowerTorso"):
		y = _ragdoll.pelvis().y
	if y >= float(C.WORLD.FondoMundo):
		return false
	if estado != Estado.MUERTO:
		estado = Estado.MUERTO
		remove_from_group(Ruido.GRUPO)
		murio.emit(self)
	set_physics_process(false)
	queue_free()
	return true


func _cambiar(nuevo: Estado) -> void:
	if nuevo == estado:
		return
	var antes := estado
	estado = nuevo
	_estado_t = reloj
	_atascos = 0
	_rodeos = 0
	_desvio = null
	_progreso_t = reloj
	_progreso_pos = global_position
	match nuevo:
		Estado.DEAMBULAR:
			_destino = null
			casa = _pies()
			_pausa_hasta = reloj + _rng.randf_range(1.0, 4.0)
			_busqueda.clear()
			_busqueda_dir = Vector3.ZERO
		Estado.INVESTIGAR, Estado.PERSEGUIR:
			if pista != null:
				_ir_a(pista.pos)
			# estando tranquilo, primero se gira hacia lo que ha oído o visto (da un respiro al jugador)
			if antes == Estado.DEAMBULAR:
				_reaccion_hasta = reloj + float(C.ZOMBI.Reaccion)
			if nuevo == Estado.PERSEGUIR and antes != Estado.ATACAR:
				_grunir(true)
		Estado.BUSCAR:
			_destino = null
			_preparar_busqueda()
		Estado.ATACAR:
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
	if _reaccionando():
		return
	if _destino == null or _llegado(2.5) or (_atascado() and not _rodear()):
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
	if _reaccionando():
		return
	if _destino == null or _llegado(1.5) or (_atascado() and not _rodear()):
		# está donde lo oyó y no hay nada nuevo: mira alrededor
		if reloj - pista.t > 0.8:
			_cambiar(Estado.BUSCAR)
		return
	_seguir_camino(float(C.ZOMBI.Correr))


## Registra la zona. Si buscaba al jugador, recorre varios sitios cercanos (el primero, hacia donde creía que
## iba) y en cada uno mira alrededor; si solo era un ruido cualquiera, mira alrededor un rato y se va.
func _paso_buscar() -> void:
	if reloj - _estado_t > _buscar_limite:
		_cambiar(Estado.DEAMBULAR)
		return
	if reloj < _mirar_hasta or (_destino == null and _busqueda.is_empty()):
		# quieto, girando la cabeza (y el cuerpo) a un lado y a otro
		var giro := sin((reloj - _estado_t) * 1.3 + _var) * 1.2
		rotation.y = Rbx.wrap_a(rotation.y + giro * 0.8 * get_physics_process_delta_time())
		if _destino == null and _busqueda.is_empty() and reloj >= _mirar_hasta \
				and reloj - _estado_t > float(C.ZOMBI.Buscar):
			_cambiar(Estado.DEAMBULAR) # ya lo ha registrado todo
		return
	if _destino == null:
		_ir_a(_busqueda.pop_front())
	if _llegado(2.0) or (_atascado() and not _rodear()):
		_destino = null
		_mirar_hasta = reloj + float(C.ZOMBI.BuscarMirar)
		return
	_seguir_camino(float(C.ZOMBI.Andar) * 1.15)



## sitios a registrar: al buscar al jugador, BuscarPuntos sitios alrededor de donde le perdió
func _preparar_busqueda() -> void:
	_busqueda.clear()
	_mirar_hasta = reloj + float(C.ZOMBI.BuscarMirar)
	_buscar_limite = float(C.ZOMBI.Buscar)
	if pista == null or not pista.del_jugador:
		return
	_buscar_limite = float(C.ZOMBI.BuscarTiempo)
	var base := pista.pos
	var dir := _busqueda_dir
	if dir.length() < 0.1:
		# no sabe hacia dónde iba: supone que se alejaba de él
		dir = Rbx.flat(base - global_position)
		dir = dir.normalized() if dir.length() > 0.1 else Vector3(sin(_var), 0, cos(_var))
	var radio := float(C.ZOMBI.BuscarRadio)
	for i in int(C.ZOMBI.BuscarPuntos):
		# el primero, hacia donde iba; los demás, a un lado y a otro y algo más lejos
		var ang := 0.0 if i == 0 else _rng.randf_range(0.6, 1.6) * (1.0 if i % 2 == 1 else -1.0)
		var dist := radio * (0.5 if i == 0 else _rng.randf_range(0.6, 1.0))
		_busqueda.append(_punto_navegable(base + dir.rotated(Vector3.UP, ang) * dist))


## estando tranquilo, al oír o ver algo primero se gira hacia allí (sin moverse) un instante
func _reaccionando() -> bool:
	if reloj >= _reaccion_hasta:
		return false
	if pista != null:
		_mirar_hacia(pista.pos, float(C.ZOMBI.Giro) * 1.5)
	return true


func _paso_atacar() -> void:
	var j := _jugador()
	var t := reloj - _estado_t
	if j:
		_mirar_hacia(j.global_position, 10.0)
	if not _golpe_hecho and t >= float(C.ZOMBI.PreparaGolpe):
		_golpe_hecho = true
		if j and float(j.get("health")) > 0.0 and _dist_h(j.global_position) <= float(C.ZOMBI.Alcance) + 0.8 \
				and _alcanzable(j): # (si se ha metido tras una pared mientras levantaba los brazos, falla)
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
	return _dist_h(j.global_position) <= float(C.ZOMBI.Alcance) and absf(j.global_position.y - global_position.y) < 4.0 \
		and _alcanzable(j)


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


## como _ir_a, pero sin rehacer el camino si el sitio nuevo está casi donde el anterior (ruidos seguidos)
func _ir_a_si_cambia(p: Vector3) -> void:
	if _destino == null or (p - (_destino as Vector3)).length() > 1.5:
		_ir_a(p)
	else:
		_destino = p


## atascado (otro zombi, un muñeco, una esquina): prueba a rodearlo por un lado (2 veces como mucho)
func _rodear() -> bool:
	if _rodeos >= 2 or _destino == null:
		return false
	var hacia := Rbx.flat((_destino as Vector3) - global_position)
	if hacia.length() < 0.1:
		return false
	_rodeos += 1
	_atascos = 0
	var lado := hacia.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_desvio = _punto_navegable(global_position + lado * 5.0 + hacia.normalized() * 1.5)
	_desvio_t = reloj
	return true


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
	# rodeando un obstáculo: primero al punto de desvío
	if _desvio != null:
		var dd := Rbx.flat((_desvio as Vector3) - global_position)
		if dd.length() < 1.2 or reloj - _desvio_t > 2.5:
			_desvio = null
			_camino_t = -9.0
		else:
			_dir = dd.normalized()
			_vel = velocidad
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
		var imp := _impulso_golpe if not _bala.is_empty() else _impulso_golpe * 0.3
		if _bala.is_empty():
			if imp.length() > 16.0:
				imp = imp.normalized() * 16.0
			if imp.length() < 2.0:
				imp = _caida_dir * 4.0 + Vector3(0, 1.0, 0)
		_ragdoll = Ragdoll.iniciar(self, rig, velocity, {"comportamiento": "caer", "impulso": imp, "pieza": _pieza_golpe, "balistica": not _bala.is_empty(), "reaccion_bala": _reaccion_balas, "punto_local": _bala.get("punto_local", Vector3.ZERO),
			"duracion": minf(dur, 30.0)})
		_ragdoll.recuperado.connect(_ragdoll_levantar)
	velocity = Vector3.ZERO


func _morir(dir: Vector3) -> void:
	_caer(dir, 1e9)
	if _ragdoll != null and is_instance_valid(_ragdoll):
		_ragdoll.morir(not _bala.is_empty())
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
			_notar_golpe(_impulso_golpe) # se levanta buscando a quien le tiró (si lo tiene cerca, sabe quién fue)
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
			_notar_golpe(_impulso_golpe)
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
	_reaccion_balas.aplicar(rig, dt)
	rig.aplicar()
	_etiqueta.visible = Ruido.ver
	if Ruido.ver:
		_etiqueta.text = "%s\nalerta %.2f · vista %.2f" % [NOMBRE_ESTADO[estado], alerta, sospecha]
		_etiqueta.modulate = Color(1, 1.0 - alerta * 0.7, 1.0 - alerta * 0.8)
	_dibujar_cono()


## ---------------------------------------------------------------- aspecto
const OCULTAR := ["Backpack", "BackpackPocket", "Bedroll", "Holster", "MagPouch1", "MagPouch2", "Buckle", "Zipper"]
const PIEL := ["Head", "EarL", "EarR", "Nose", "LeftHand", "RightHand"]
static var _mats := {}


## el mismo muñeco que el superviviente, sin mochila ni equipo, con piel enferma y ropa sucia
func _aspecto() -> void:
	# Las mallas de Blender ya llevan piel, heridas y ropa; no teñir sus materiales.
	if rig.modelo.begins_with("zombi_") and rig._usa_modelo():
		return
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


## ---------------------------------------------------------------- depuración (F6)
## cono de visión (alcance de pie y semiángulo) a la altura de los ojos; amarillo -> rojo con la sospecha
func _dibujar_cono() -> void:
	if not Ruido.ver or estado == Estado.MUERTO:
		if _cono:
			_cono.visible = false
		return
	if _cono == null:
		_cono = MeshInstance3D.new()
		_cono.mesh = ImmediateMesh.new()
		_cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = true
		_cono.material_override = m
		_cono.position = Vector3(0, 2.0, 0)
		add_child(_cono)
	_cono.visible = true
	var im := _cono.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(Color(1.0, 1.0 - sospecha, 0.2 * (1.0 - sospecha)))
	var alcance := float(C.ZOMBI.VistaAlcance) * (1.0 + 0.3 * alerta)
	var a := deg_to_rad(float(C.ZOMBI.VistaAngulo))
	var previo := Vector3.ZERO
	for i in 13:
		var p := Vector3(0, 0, -alcance).rotated(Vector3.UP, lerpf(-a, a, i / 12.0))
		if i == 0 or i == 12:
			im.surface_add_vertex(Vector3.ZERO)
			im.surface_add_vertex(p)
		if i > 0:
			im.surface_add_vertex(previo)
			im.surface_add_vertex(p)
		previo = p
	im.surface_end()


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

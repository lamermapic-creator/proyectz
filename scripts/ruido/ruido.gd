class_name Ruido
## SISTEMA DE RUIDO (guía completa en docs/RUIDO_Y_ZOMBIS.md).
## Todo lo que suena en el mundo pasa por aquí: quien hace ruido llama a Ruido.emitir(...) y todos los
## nodos del grupo "oyentes_ruido" reciben el evento en su método oir(ev). Cada oyente decide si lo oye
## (distancia, paredes en medio con radio_percibido()) y qué hace con él.
##
##   Emitir:   Ruido.emitir(self, posicion, radio_en_studs, Ruido.DISPARO, self)
##   Escuchar: add_to_group(Ruido.GRUPO)  +  func oir(ev: Ruido.Evento) -> void
##
## Los radios están en studs y se configuran en ZConfig.RUIDO (los disparos, en el "Alert" de cada arma).

const C = preload("res://scripts/config/zconfig.gd")

const GRUPO := "oyentes_ruido"

## tipos de ruido (texto para que se lean bien en la depuración y en las pruebas)
const PASO := "paso"
const REPTAR := "reptar"
const ATERRIZAJE := "aterrizaje"
const SORTEAR := "sortear"
const DISPARO := "disparo"
const IMPACTO := "impacto"
const GOLPE := "golpe"
const ARMA := "arma"            # recargar, clic sin balas
const GRUNIDO := "grunido"      # zombis

## cuánto alarma cada tipo a un zombi (0..1): un disparo alarma más que una pisada del mismo volumen
const PESO := {
	PASO: 0.6, REPTAR: 0.5, ATERRIZAJE: 0.7, SORTEAR: 0.7, DISPARO: 1.0, IMPACTO: 0.7,
	GOLPE: 0.9, ARMA: 0.6, GRUNIDO: 0.5,
}

## color de cada tipo en la vista de depuración (F6)
const COLOR := {
	PASO: Color(0.4, 0.9, 0.4), REPTAR: Color(0.3, 0.7, 0.3), ATERRIZAJE: Color(1.0, 0.8, 0.3),
	SORTEAR: Color(1.0, 0.8, 0.3), DISPARO: Color(1.0, 0.25, 0.2), IMPACTO: Color(1.0, 0.55, 0.2),
	GOLPE: Color(1.0, 0.4, 0.6), ARMA: Color(0.6, 0.8, 1.0), GRUNIDO: Color(0.7, 0.4, 1.0),
}


## Un ruido: dónde, cuánto se oye (radio en studs), de qué tipo y quién lo hizo (null = el entorno)
class Evento extends RefCounted:
	var posicion: Vector3
	var radio: float
	var tipo: String
	var fuente: Node

	func _init(p: Vector3, r: float, t: String, f: Node) -> void:
		posicion = p
		radio = r
		tipo = t
		fuente = f


## vista de depuración: anillos con el radio de cada ruido (F6, solo en desarrollo)
static var ver := false
## contador y último evento (para las pruebas automáticas y la depuración)
static var emitidos := 0
static var ultimo: Evento = null


## Emite un ruido. ctx = cualquier nodo del árbol (para llegar a la escena). fuente = quién lo hace
## (el oyente que lo hizo no se oye a sí mismo; los zombis distinguen los ruidos del jugador).
static func emitir(ctx: Node, posicion: Vector3, radio: float, tipo: String, fuente: Node = null) -> void:
	if radio <= 0.0 or ctx == null or not ctx.is_inside_tree():
		return
	var ev := Evento.new(posicion, radio, tipo, fuente)
	emitidos += 1
	ultimo = ev
	for o in ctx.get_tree().get_nodes_in_group(GRUPO):
		if o != fuente and o.has_method("oir"):
			o.oir(ev)
	if ver:
		_anillo(ctx, ev)


## Radio con el que llega un ruido a un oyente: si hay una pared (capa 1, el escenario) entre el ruido y
## la oreja, el ruido llega amortiguado. excluir = RIDs que no cuentan como pared (el propio oyente…).
## oido = multiplicador del oyente (un zombi con buen oído, 1.15, oye un 15 % más lejos).
static func radio_percibido(ev: Evento, oreja: Vector3, mundo: World3D, excluir: Array[RID] = [], oido := 1.0) -> float:
	var r := ev.radio * oido
	var d := oreja.distance_to(ev.posicion)
	if d > r:
		return r # ni sin paredes llega: no hace falta mirar
	var desde := ev.posicion + Vector3(0, 1.0, 0) # un poco por encima (las pisadas están en el suelo)
	var q := PhysicsRayQueryParameters3D.create(desde, oreja, 1)
	var ex := excluir.duplicate()
	if ev.fuente is CollisionObject3D:
		ex.append((ev.fuente as CollisionObject3D).get_rid()) # el cuerpo de quien hace el ruido no tapa
	q.exclude = ex
	if not mundo.direct_space_state.intersect_ray(q).is_empty():
		return r * float(C.RUIDO.Oclusion)
	return r


## Radio de una pisada. fuerza: 0 (muy suave) .. 1 (corriendo); la calcula el Animador (step_k), que
## ya tiene en cuenta la velocidad y si va agachado. ajuste = pasito de recolocar los pies, parado.
static func radio_paso(fuerza: float, ajuste := false) -> float:
	var r := lerpf(float(C.RUIDO.PasoMin), float(C.RUIDO.PasoMax), clampf(fuerza, 0.0, 1.0))
	return r * (float(C.RUIDO.PasoAjuste) if ajuste else 1.0)


## Radio al aterrizar según la velocidad de impacto (studs/s). Un salto normal llega a ~12.
static func radio_aterrizaje(vel_impacto: float) -> float:
	if vel_impacto < 8.0:
		return 0.0
	var k := clampf((vel_impacto - 10.0) / 30.0, 0.0, 1.0)
	return lerpf(float(C.RUIDO.AterrizajeMin), float(C.RUIDO.AterrizajeMax), k)


static func peso(tipo: String) -> float:
	return float(PESO.get(tipo, 0.5))


## ---------------------------------------------------------------- depuración (F6)
static func _anillo(ctx: Node, ev: Evento) -> void:
	var arbol := ctx.get_tree()
	var raiz: Node = arbol.current_scene if arbol.current_scene else arbol.root
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.outer_radius = ev.radio
	tm.inner_radius = maxf(0.0, ev.radio - 0.35)
	tm.ring_segments = 6
	tm.rings = 48
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = COLOR.get(ev.tipo, Color.WHITE)
	mi.material_override = m
	raiz.add_child(mi)
	mi.global_position = ev.posicion + Vector3(0, 0.2, 0)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(mi.queue_free)

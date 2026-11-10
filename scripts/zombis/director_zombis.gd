class_name DirectorZombis
extends Node3D
## Director de zombis (guía en docs/RUIDO_Y_ZOMBIS.md):
## · Hornea la malla de navegación del nivel al cargarlo (a partir de la colisión del escenario, capa 1).
## · Coloca zombis (crear_zombi) y, si "reaparecer" está activo, los repone un rato después de morir.
## · Red de seguridad del nivel: si el jugador se cae del mapa (ZConfig.WORLD.FondoMundo), muere y el nivel
##   se reinicia, en vez de caer para siempre.
## · Teclas de depuración (solo en desarrollo): F6 ver los ruidos, el cono de visión y el estado de los
##   zombis, F7 zombis sordos y F8 zombis ciegos (para probar otras cosas sin que te molesten).
## Uso desde un nivel:
##   var dz := DirectorZombis.new(); add_child(dz); dz.preparar($Geometria); dz.crear_zombi(pies, giro)

signal zombi_creado(z: Zombi)

const C = preload("res://scripts/config/zconfig.gd")

## malla de navegación (en studs). La celda decide la precisión y lo que tarda en hornearse.
const CELDA := 0.5
const ALTO_CELDA := 0.25

## nivel de pruebas: un zombi muerto vuelve a aparecer en su sitio pasado este tiempo
@export var reaparecer := true
@export var reaparecer_tras := 20.0

var region: NavigationRegion3D
var tiempo_horneado_ms := 0.0


## Hornea la navegación con la geometría (StaticBody3D, capa 1) que cuelga de "geometria".
## limites: si se da, solo se hornea esa zona (más rápido en mapas grandes).
func preparar(geometria: Node3D, limites := AABB()) -> void:
	var t0 := Time.get_ticks_msec()
	var nm := NavigationMesh.new()
	nm.cell_size = CELDA
	nm.cell_height = ALTO_CELDA
	# el zombi: 5.5 studs de alto, 1 de radio; sube escalones como el jugador (PASO_MAX = 1.25)
	nm.agent_height = 5.5
	nm.agent_radius = 1.0
	nm.agent_max_climb = 1.25
	nm.agent_max_slope = 46.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 # solo el escenario (no maniquíes ni zonas de impacto)
	if limites.has_volume():
		nm.filter_baking_aabb = limites
	var datos := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, datos, geometria)
	NavigationServer3D.bake_from_source_geometry_data(nm, datos)
	# el mapa tiene que usar la misma celda que la malla
	var mapa := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(mapa, CELDA)
	NavigationServer3D.map_set_cell_height(mapa, ALTO_CELDA)
	region = NavigationRegion3D.new()
	region.name = "Navegacion"
	region.navigation_mesh = nm
	add_child(region)
	tiempo_horneado_ms = Time.get_ticks_msec() - t0


## Pone un zombi con los pies en "pies" (studs, coordenadas del mundo) mirando hacia "giro_grados".
func crear_zombi(pies: Vector3, giro_grados := 0.0, deambula := true) -> Zombi:
	var z := Zombi.new()
	z.name = "Zombi_%d" % get_child_count()
	z.deambula = deambula
	z.position = pies + Vector3(0, Zombi.CENTRO, 0) - global_position
	z.rotation.y = deg_to_rad(giro_grados)
	add_child(z)
	z.murio.connect(_al_morir.bind(pies, giro_grados, deambula))
	zombi_creado.emit(z)
	return z


func zombis() -> Array[Node]:
	return get_tree().get_nodes_in_group("zombis")


func _al_morir(_z: Zombi, pies: Vector3, giro: float, deambula: bool) -> void:
	if reaparecer:
		get_tree().create_timer(reaparecer_tras, false).timeout.connect(_reaparecer.bind(pies, giro, deambula))


func _reaparecer(pies: Vector3, giro: float, deambula: bool) -> void:
	crear_zombi(pies, giro, deambula)


## ---------------------------------------------------------------- fondo del mundo
var _j: Node3D = null
var _inicio_j = null            # dónde estaban los pies del jugador al empezar (Vector3 o null)


## RED DE SEGURIDAD (2026-11-10): el suelo del nivel tiene bordes y nada paraba la caída (a los 12 s el jugador iba
## por y = -1374, vivo y sin reinicio). Por debajo de FondoMundo recibe un daño mortal por el contrato de siempre
## (Jugador.recibir_danio): muere y el nivel se reinicia solo. Con el truco "invencible" no puede morir: vuelve al
## punto de partida. No toca jugador.gd; si algún día el Jugador trae su propio fondo, esto se puede quitar.
func _physics_process(_dt: float) -> void:
	if not is_instance_valid(_j):
		_j = get_tree().get_first_node_in_group("jugador") as Node3D
		if _j == null:
			return
		_inicio_j = _j.global_position - Vector3(0, Zombi.CENTRO, 0)
	if _j.global_position.y >= float(C.WORLD.FondoMundo) or float(_j.get("health")) <= 0.0:
		return
	if _j.get("invencible") == true:
		if _j.has_method("teletransportar"):
			_j.call("teletransportar", _inicio_j, 0.0)
		return
	if _j.has_method("notify"):
		_j.call("notify", "Te has caído del mapa")
	if _j.has_method("recibir_danio"):
		_j.call("recibir_danio", 1e6) # (sin "desde": un daño sin origen no se puede bloquear)


## ---------------------------------------------------------------- depuración
func _unhandled_input(e: InputEvent) -> void:
	if not OS.is_debug_build() or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match (e as InputEventKey).physical_keycode:
		KEY_F6:
			Ruido.ver = not Ruido.ver
			_avisar("Ver ruido y zombis: " + ("SÍ" if Ruido.ver else "NO"))
		KEY_F7:
			Zombi.sordos = not Zombi.sordos
			_avisar("Zombis sordos: " + ("SÍ" if Zombi.sordos else "NO"))
		KEY_F8:
			Zombi.ciegos = not Zombi.ciegos
			_avisar("Zombis ciegos: " + ("SÍ" if Zombi.ciegos else "NO"))


func _avisar(txt: String) -> void:
	var j := get_tree().get_first_node_in_group("jugador")
	if j and j.has_method("notify"):
		j.call("notify", txt)

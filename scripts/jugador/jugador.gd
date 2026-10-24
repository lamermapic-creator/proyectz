class_name Jugador
extends CharacterBody3D
## Port del cliente de Roblox (StarterPlayerScripts.ZClient): movimiento realista con estamina,
## posturas (de pie / agachado / cuerpo a tierra), saltar y sortear obstáculos (vault / mantle),
## asomarse (Q/E), cámara al hombro y HUD. Además emula el Humanoid de Roblox: el cuerpo "flota"
## sobre el suelo a la altura de la cadera (HipHeight) y sube escalones solo.
## Unidades: studs (1 stud ~ 0.31 m), gravedad 35 studs/s² como en el juego original.

signal estado_cambiado(nuevo: String) # Running, Jumping, Freefall, Landed, Physics

const C = preload("res://scripts/config/zconfig.gd")
const STAND_SIZE := Vector3(1.6, 1.8, 0.8)
const PRONE_SIZE := Vector3(1.6, 0.6, 0.8)
const PASO_MAX := 1.25 # lo más alto que se sube andando (más alto hay que sortearlo con Espacio)

@onready var rig: RigPersonaje = $Rig
@onready var camara: Camera3D = $Camara
@onready var forma_cuerpo: CollisionShape3D = $FormaCuerpo
@onready var forma_piernas: CollisionShape3D = $FormaPiernas

## ---------------------------------------------------------------- "Humanoid"
var health := 100.0
var max_health := 100.0
var walk_speed: float = C.PLAYER.WalkSpeed
var jump_height: float = C.PLAYER.JumpHeight
var hip_height := 2.2
var root_size := STAND_SIZE
var estado := "Running"          # Running, Jumping, Freefall, Physics
var en_suelo := true              # hum.FloorMaterial ~= Air
var normal_suelo := Vector3.UP
var move_direction := Vector3.ZERO
var _move_override = null         # hum:Move() en el aire
var vel_real := Vector3.ZERO      # root.AssemblyLinearVelocity
var _salto_pedido := false
var _salto_t := -9.0               # último salto (para agarrarse a un borde en el aire)
var colgado = null               # colgado de una cornisa (ver step_colgado)
var _soltado_t := -9.0
var _subir_a = null               # escalada pendiente (ir hasta la estructura y subir)

## ---------------------------------------------------------------- estado (ZClient)
var yaw := 0.0
var pitch := -0.15
var side := 1.0
var aiming := false
var firing := false
var stamina: float = C.PLAYER.StaminaMax
var exhausted := false
var fatiga := 0.0                  # 0..1: cansancio (poca estamina) -> andar con fatiga
var estamina_infinita: bool = C.PLAYER.get("InfiniteStamina", false) # F4 la activa/desactiva
var cam_dist := 9.0
# zoom de la cámara con la rueda del ratón (multiplica la distancia normal; apuntando no cambia)
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.6
const ZOOM_PASO := 0.1
var zoom_cam := 1.0
var apretado_cur := 0.0 # 0-1: sin sitio detrás de la cámara (espalda contra una pared)
var cam_fov := 70.0
var fade_cur := 0.0
var vaulting = null
var air_vel = null
var air_cap := 0.0
var fall_bias := 0.0
var getup_p := 0.0
var cur_move := 0.0
var side_cur := 1.0
var cam_pivot = null
var comp_cur := 1.0
var height_cur := 0.4
var land_off := 0.0
var land_vel := 0.0
var prev_vel_y := 0.0
var lean_cur := 0.0
var lean_max := 1.0
var rest_lower_cur := 0.0
var stance := 0
var stance_change_t := -10.0
var supine := false
var roll_side := 1.0
var prone_turn_rate := 0.0
var stance_from := 0
var non_prone_c: float = C.STANCE[0].Center
var center_cur: float = C.STANCE[0].Center
var prone_p := 0.0
var eye_cur: float = C.STANCE[0].Eye
var shake := 0.0
var free_mouse := false
var jump_prep_t := -9.0
var slow_until := 0.0

## estado compartido con el animador (AnimShared.Local)
var L := {
	"pitch": 0.0, "aiming": false, "firing": false, "stamina": 1.0, "exhausted": false, "fatigue": 0.0,
	"sprinting": false, "stance": 0, "stanceT": -10.0, "stanceFrom": 0, "proneP": 0.0,
	"yaw": 0.0, "supine": false, "rollSide": 1.0, "lean": 0.0, "vault": null, "jumpPrep": null,
	"knocked": false, "gettingUp": false, "hang": null, "restGap": null, "rested": false, "holster": null,
}

var _hud: Dictionary = {}
var arsenal: Arsenal
var empuje := Vector3.ZERO
var _notif_hasta := 0.0


## reloj del juego (avanza con el tiempo de juego, no con el del ordenador)
var reloj := 0.0
## pendiente del camino (subida por metro avanzado; escaleras y cuestas) para ir más despacio
var pendiente := 0.0
var _suelo_prev = null


func ahora() -> float:
	return reloj


func _ready() -> void:
	add_to_group("jugador") # así lo encuentran los zombis (y sus ruidos llevan esta marca)
	motion_mode = MOTION_MODE_FLOATING
	camara.top_level = true
	yaw = rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_crear_hud()
	# capas: 1 = escenario, 2 = zonas de impacto de los muñecos (solo balas), 4 = cuerpos de los muñecos
	collision_mask = 1 | 4
	arsenal = Arsenal.new()
	arsenal.name = "Arsenal"
	add_child(arsenal)
	# menú de pausa (Esc) y opciones guardadas
	var pausa := MenuPausa.new()
	pausa.name = "MenuPausa"
	add_child(pausa)
	# menú de trucos (F1), solo en desarrollo
	if OS.is_debug_build():
		var trucos := MenuTrucos.new()
		trucos.name = "MenuTrucos"
		add_child(trucos)
	# medidor de ruido del HUD (lo que oyen los zombis)
	var medidor := MedidorRuido.new()
	medidor.name = "MedidorRuido"
	add_child(medidor)
	Opciones.aplicar(get_tree())
	# en el ejecutable final no hay trucos de pruebas
	if not OS.is_debug_build():
		estamina_infinita = false


## ---------------------------------------------------------------- utilidades de física
func raycast(desde: Vector3, dir: Vector3, excluir_extra: Array = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(desde, desde + dir, 1)
	q.exclude = [get_rid()] + excluir_extra
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	r["distance"] = desde.distance_to(r.position)
	return r


## ¿una esfera en ese punto toca el escenario?
func _esfera_choca(p: Vector3, radio: float) -> bool:
	var sh := SphereShape3D.new()
	sh.radius = radio
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## workspace:Spherecast: devuelve la distancia recorrida hasta chocar (o -1 si no choca)
func spherecast(desde: Vector3, radio: float, dir: Vector3) -> float:
	var sh := SphereShape3D.new()
	sh.radius = radio
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, desde)
	q.motion = dir
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(q, 1).is_empty():
		return 0.0
	var res := space.cast_motion(q)
	if res[0] >= 1.0:
		return -1.0
	return res[0] * dir.length()


func root_cf() -> Transform3D:
	return global_transform


## ---------------------------------------------------------------- HUD
func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var caja := VBoxContainer.new()
	caja.position = Vector2(24, 24)
	capa.add_child(caja)
	for k in ["vida", "estamina"]:
		var fondo := ColorRect.new()
		fondo.custom_minimum_size = Vector2(260, 14)
		fondo.color = Color(0, 0, 0, 0.45)
		caja.add_child(fondo)
		var barra := ColorRect.new()
		barra.size = Vector2(260, 14)
		barra.color = Color8(170, 30, 30) if k == "vida" else Color8(220, 190, 80)
		fondo.add_child(barra)
		_hud[k] = barra
	var aviso := Label.new()
	aviso.add_theme_font_size_override("font_size", 22)
	aviso.anchor_left = 0.5
	aviso.anchor_right = 0.5
	aviso.anchor_top = 0.72
	aviso.offset_left = -300
	aviso.offset_right = 300
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capa.add_child(aviso)
	_hud["aviso"] = aviso
	var ayuda := Label.new()
	ayuda.text = "1-4: armas · Clic der: apuntar · Clic izq: disparar/golpear · R: recargar · X: apoyar arma · F: recoger · Shift: correr · C: agacharse · Z: cuerpo a tierra · Espacio: saltar/sortear · Q/E: asomarse · V: hombro · Rueda: acercar/alejar cámara · Colgado: A/D moverse (Shift: rápido), Espacio subir, S soltarse · Esc: pausa" + (" · F1: trucos · F4: estamina infinita · F5: balas infinitas · F6: ver ruido · F7: zombis sordos · F8: zombis ciegos" if OS.is_debug_build() else "")
	ayuda.add_theme_font_size_override("font_size", 14)
	ayuda.modulate = Color(1, 1, 1, 0.7)
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.offset_top = -32
	ayuda.offset_left = 24
	capa.add_child(ayuda)
	Arsenal._ignorar_raton(capa)


func notify(txt: String) -> void:
	_hud["aviso"].text = txt
	_notif_hasta = ahora() + 2.5


func _update_hud() -> void:
	_hud["vida"].size.x = 260.0 * clampf(health / max_health, 0, 1)
	_hud["estamina"].size.x = 260.0 * stamina / C.PLAYER.StaminaMax
	_hud["estamina"].color = Color8(150, 90, 40) if exhausted else Color8(220, 190, 80)
	if ahora() > _notif_hasta:
		_hud["aviso"].text = ""


## ---------------------------------------------------------------- entrada
## el ratón de la cámara se lee antes que la interfaz (si no, cualquier elemento del HUD que quede
## bajo el puntero capturado, como la mira en el centro, se tragaba el movimiento)
func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := (0.0017 if aiming else 0.0032) * Opciones.sensibilidad
		var rel: Vector2 = e.relative
		if Opciones.invertir_y:
			rel.y = -rel.y
		_mouse_delta += rel * sens


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			aiming = e.pressed
		elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# rueda: acercar / alejar la cámara (no cambia la distancia al apuntar)
			var paso := -ZOOM_PASO if e.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_PASO
			zoom_cam = clampf(zoom_cam + paso, ZOOM_MIN, ZOOM_MAX)
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not free_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and not e.echo:
		var k: int = e.physical_keycode
		if e.pressed:
			match k:
				KEY_C, KEY_CTRL:
					if colgado != null:
						soltar_cornisa()
					else:
						set_stance(0 if stance == 1 else 1)
				KEY_Z:
					set_stance(1 if stance == 2 else 2)
				KEY_SPACE:
					# agachado/tumbado sube un nivel; de pie salta o sortea el obstáculo de delante;
					# colgado de una cornisa, sube
					if colgado != null:
						trepar_cornisa()
					elif stance > 0:
						set_stance(stance - 1)
					else:
						jump_or_vault()
				KEY_V:
					side = -side
				KEY_F4:
					# pruebas: estamina infinita sí/no (para probar el cansancio). Solo en desarrollo
					if not OS.is_debug_build():
						return
					estamina_infinita = not estamina_infinita
					notify("Estamina infinita: " + ("SÍ" if estamina_infinita else "NO"))
				KEY_ALT:
					free_mouse = true
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			if k == KEY_ALT:
				free_mouse = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

var _mouse_delta := Vector2.ZERO


func _leer_movimiento() -> Vector3:
	var f := 0.0
	var r := 0.0
	if Input.is_physical_key_pressed(KEY_W): f += 1
	if Input.is_physical_key_pressed(KEY_S): f -= 1
	if Input.is_physical_key_pressed(KEY_D): r += 1
	if Input.is_physical_key_pressed(KEY_A): r -= 1
	if f == 0 and r == 0:
		return Vector3.ZERO
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var der := Vector3(cos(yaw), 0, -sin(yaw))
	return (fwd * f + der * r).normalized()


## ---------------------------------------------------------------- posturas
func headroom(height: float) -> bool:
	# ¿hay espacio para incorporarse? (techo bajo, debajo de un coche...)
	var base := global_position - Vector3(0, center_cur - 0.3, 0)
	return raycast(base, Vector3(0, height, 0)).is_empty()


func set_stance(n: int) -> void:
	if health <= 0 or L.knocked or vaulting != null:
		return
	if n == stance:
		return
	if prone_p > 0.001 and prone_p < 0.999:
		return
	arsenal.al_cambiar_postura(n)
	# no se puede cambiar a mitad de una transición de cuerpo a tierra
	if prone_p > 0.001 and prone_p < 0.999:
		return
	if n < stance:
		var need := 5.6 if n == 0 else 3.9
		if not headroom(need):
			notify("No hay espacio para levantarse")
			return
	if n == 2 and not en_suelo:
		return
	stance_from = stance
	stance = n
	stance_change_t = ahora()


## ---------------------------------------------------------------- saltar y sortear obstáculos
## Frente a un obstáculo bajo y estrecho: SALTARLO (vault) apoyando una mano.
## Frente a uno más alto (hasta ~5.5 studs) o ancho: ENCARAMARSE (mantle) con las dos manos.
## Si no hay nada que sortear: salto normal (parado se agacha un instante antes de impulsarse).
static func _flat_unit(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0, v.z)
	return f.normalized() if f.length() > 1e-3 else Vector3(0, 0, -1)


func find_vault(lejos := false, en_aire := false):
	if stance != 0 or prone_p > 0.01:
		return null
	var md := move_direction
	var fwd := _flat_unit(md) if md.length() > 0.1 else _flat_unit(Rbx.look(root_cf()))
	var Cst: float = C.STANCE[0].Center
	var feet_y := global_position.y - center_cur
	var base := Vector3(global_position.x, 0, global_position.z)
	# 1) cara del obstáculo delante (a la altura de la rodilla o de la cintura)
	var face := {}
	for hgt in [0.9, 1.9]:
		# corriendo se detecta desde más lejos (el salto empieza antes)
		# "lejos": para decidir si al pulsar saltar hay que ir hasta la estructura y escalarla
		var hs_v := Vector3(vel_real.x, 0, vel_real.z).length()
		# lejos: un poco antes de llegar (~1.4 m parado, ~2 m corriendo); si no, junto a la estructura
		var reach := (4.6 + minf(2.0, hs_v * 0.15)) if lejos else (3.0 + minf(1.8, hs_v * 0.12))
		if en_aire:
			reach = 1.4 # en el aire solo si ya está junto a la pared
		face = raycast(base + Vector3(0, feet_y + hgt, 0), fwd * reach)
		if not face.is_empty():
			break
	if face.is_empty() or absf(face.normal.y) > 0.35:
		return null
	var d := _flat_unit(-face.normal)
	if d.dot(fwd) < 0.6:
		return null # hay que ir de frente
	# 2) la parte de arriba
	var probe_xz: Vector3 = face.position + d * 0.3
	var top := raycast(Vector3(probe_xz.x, feet_y + 6.2, probe_xz.z), Vector3(0, -6.0, 0))
	if top.is_empty() or top.normal.y < 0.7:
		return null
	var top_y: float = top.position.y
	var h := top_y - feet_y
	if h < 1.2 or h > 5.6:
		return null
	# no puede haber techo justo encima del borde
	if not raycast(Vector3(probe_xz.x, top_y + 0.1, probe_xz.z), Vector3(0, 3.2, 0)).is_empty():
		return null
	# 3) profundidad del obstáculo (dónde termina la parte de arriba)
	var depth = null
	for k in range(1, 10):
		var px: Vector3 = face.position + d * (0.3 + 0.4 * k)
		var rr := raycast(Vector3(px.x, top_y + 0.6, px.z), Vector3(0, -1.1, 0))
		if rr.is_empty():
			depth = 0.3 + 0.4 * k - 0.2
			break
	var edge := Vector3(face.position.x, top_y, face.position.z)
	# ¿saltarlo por encima? (bajo, estrecho y con suelo al otro lado)
	if h <= 3.6 and depth != null and depth <= 2.9:
		var land_xz: Vector3 = edge + d * (depth + 1.5)
		var land := raycast(Vector3(land_xz.x, top_y + 1, land_xz.z), Vector3(0, -14, 0))
		if not land.is_empty() and land.position.y > feet_y - 5 and land.position.y < top_y - 0.8:
			# el cuerpo cabe por encima
			var clear := spherecast(Vector3(edge.x, top_y + 1.6, edge.z) - d * 0.6, 0.7, d * (depth + 2)) < 0
			if clear:
				return {"kind": "vault", "edge": edge, "dir": d, "topY": top_y, "landY": land.position.y, "h": h, "depth": depth, "feetY": feet_y}
	# ¿encaramarse? (hay sitio para ponerse de pie arriba)
	if depth != null and depth < 1.3:
		return null
	var stand_xz := edge + d * 1.1
	var flo := raycast(Vector3(stand_xz.x, top_y + 0.6, stand_xz.z), Vector3(0, -1.2, 0))
	if flo.is_empty():
		return null
	if not raycast(flo.position + Vector3(0, 0.1, 0), Vector3(0, Cst + 2.4, 0)).is_empty():
		return null
	# encaramarse directamente solo si está cerca; desde lejos primero se acerca (o salta y se cuelga)
	var face_d := (Vector3(face.position.x, 0, face.position.z) - base).dot(d)
	if not lejos and not en_aire and face_d > 1.9:
		return null
	# muros por encima del pecho: desde el suelo no se sube de golpe; se salta y se cuelga de la cornisa
	if not en_aire and h > 4.3:
		return null
	# en el aire: si el borde queda muy arriba, mejor colgarse
	if en_aire and top_y - global_position.y >= COLGAR_ALTO_MIN:
		return null
	return {"kind": "mantle", "edge": edge, "dir": d, "topY": flo.position.y, "landY": flo.position.y, "h": h, "feetY": feet_y}


## curva cuadrática que pasa por p_mid en t = 0.5
static func thru(p0: Vector3, p_mid: Vector3, p1: Vector3, t: float) -> Vector3:
	var c := p_mid * 2 - (p0 + p1) * 0.5
	return p0 * pow(1 - t, 2) + c * (2 * t * (1 - t)) + p1 * (t * t)


static func smooth01(x: float) -> float:
	x = clampf(x, 0, 1)
	return x * x * (3 - 2 * x)


func start_vault(v: Dictionary) -> bool:
	var Cst: float = C.STANCE[0].Center
	var hs := Vector3(vel_real.x, 0, vel_real.z).length()
	var cost: float = C.PLAYER.JumpCost * (0.6 if v.kind == "vault" else 1.3)
	if stamina < cost:
		notify("Estás demasiado cansado")
		return false
	stamina -= cost
	var p0 := global_position
	var d: Vector3 = v.dir
	var e: Vector3 = v.edge
	var face_dist := maxf(0.5, (Vector3(e.x, 0, e.z) - Vector3(p0.x, 0, p0.z)).dot(d))
	if v.kind == "vault":
		# rápido si vas corriendo, más pausado si vas andando
		v.dur = clampf(0.95 - hs * 0.028, 0.55, 0.9) + v.h * 0.04
		var over: Vector3 = e + d * (v.depth * 0.5)
		v.pMid = Vector3(over.x, v.topY + 1.45, over.z)
		var land: Vector3 = e + d * (v.depth + 1.4)
		v.p1 = Vector3(land.x, v.landY + Cst, land.z)
		# arranque: primero se acerca al borde (sin subir), luego el arco por encima
		v.pre = Vector3(e.x, p0.y, e.z) - d * 0.9
		v.k = 0.25 if face_dist > 1.2 else 0.0
		v.exitVel = d * maxf(hs, 7)
	else:
		v.dur = 0.85 + v.h * 0.14
		v.hang = Vector3(e.x, 0, e.z) - d * 0.75
		v.pullY = v.topY - Cst * 0.15
		# agarrado en el aire (más alto que la posición de colgar): no baja para volver a subir
		v.pullY = maxf(v.pullY, minf(p0.y - 0.15, v.topY + Cst * 0.4))
		var p_top: Vector3 = e + d * 1.05
		v.pEnd = Vector3(p_top.x, v.topY + Cst, p_top.z)
		v.exitVel = Vector3.ZERO
	v.p0 = p0
	v.t0 = ahora()
	v.prev = p0
	Ruido.emitir(self, e, C.RUIDO.Sortear if v.kind == "vault" else C.RUIDO.Encaramarse, Ruido.SORTEAR, self)
	vaulting = v
	L.vault = v
	collision_layer = 0
	collision_mask = 0
	_set_estado("Physics")
	return true


func _vault_path(v: Dictionary, t: float) -> Vector3:
	var p0: Vector3 = v.p0
	if v.kind == "vault":
		var k: float = v.k
		if t < k:
			return p0.lerp(v.pre, t / k)
		var u := (t - k) / (1 - k)
		return thru(v.pre if k > 0 else p0, v.pMid, v.p1, u)
	var a := smooth01(t / 0.18)       # pegarse a la pared
	var b := smooth01((t - 0.12) / 0.5) # tirar hacia arriba
	var c := smooth01((t - 0.55) / 0.4) # subir el cuerpo encima
	var p_end: Vector3 = v.pEnd
	var xz := Vector3(p0.x, 0, p0.z).lerp(v.hang, a).lerp(Vector3(p_end.x, 0, p_end.z), c)
	var pull_y: float = v.pullY
	var y := p0.y + (pull_y - p0.y) * b
	y += (p_end.y - y) * c
	return Vector3(xz.x, y, xz.z)


func step_vault(dt: float) -> void:
	var v: Dictionary = vaulting
	var t: float = (ahora() - v.t0) / v.dur
	var pos := _vault_path(v, minf(t, 1))
	global_transform = Rbx.look_at(pos, pos + v.dir)
	vel_real = (pos - v.prev) / maxf(dt, 1.0 / 240)
	velocity = vel_real
	v.prev = pos
	if t >= 1:
		vaulting = null
		L.vault = null
		collision_layer = 1
		collision_mask = 1 | 4
		velocity = v.exitVel
		vel_real = velocity
		_set_estado("Freefall" if v.kind == "vault" else "Running")
		cur_move = (v.exitVel as Vector3).length()


func jump_or_vault() -> void:
	if health <= 0 or vaulting != null or L.knocked or L.gettingUp:
		return
	if not en_suelo or ahora() - jump_prep_t < 0.3:
		return
	var v = find_vault()
	if v != null and start_vault(v):
		return
	# estructura escalable un poco más lejos: no salta, va hasta ella y la escala
	var vl = find_vault(true)
	if vl != null:
		_subir_a = {"t": ahora(), "dir": vl.dir}
		return
	if jump_height <= 0:
		return
	var hs := Vector3(vel_real.x, 0, vel_real.z).length()
	jump_prep_t = ahora()
	_salto_t = ahora()
	if hs < 3:
		# salto parado: se agacha y se impulsa
		L.jumpPrep = jump_prep_t
		get_tree().create_timer(0.11).timeout.connect(_impulso_salto)
	else:
		L.jumpPrep = null
		_salto_pedido = true


func _impulso_salto() -> void:
	if en_suelo and vaulting == null and jump_height > 0:
		_salto_pedido = true


## Tras pulsar saltar cerca (pero no pegado) de algo escalable: avanza hacia ello y lo escala en
## cuanto está a distancia. Se cancela si vas hacia atrás, te caes o tarda demasiado.
func _aproximar_escalada() -> void:
	# saltando hacia algo escalable: al llegar al borde se agarra y sube (no se choca con la pared)
	if _subir_a == null and not en_suelo and vaulting == null and colgado == null and ahora() - _salto_t < 0.8 and health > 0:
		var va = find_vault(false, true)
		if va != null and start_vault(va):
			return
	# en el aire frente a una cornisa demasiado alta para encaramarse: agarrarse a ella
	if colgado == null and vaulting == null and not en_suelo and health > 0 and stance == 0 and not L.knocked \
			and ahora() - _soltado_t > 0.6 and vel_real.y > -30.0 and not Input.is_physical_key_pressed(KEY_S):
		var fw := Rbx.flat(Rbx.look(root_cf())).normalized()
		var c := buscar_cornisa(fw)
		if not c.is_empty():
			if stamina < 4.0 and not estamina_infinita:
				notify("Estás demasiado cansado para agarrarte")
			else:
				colgarse(c)
				return
	if _subir_a == null:
		return
	var d: Vector3 = _subir_a.dir
	if health <= 0 or vaulting != null or not en_suelo or stance != 0 or ahora() - _subir_a.t > 1.6 \
			or (move_direction.length() > 0.1 and move_direction.normalized().dot(d) < -0.3):
		_subir_a = null
		return
	move_direction = d
	var v = find_vault()
	if v != null and start_vault(v):
		_subir_a = null


## ---------------------------------------------------------------- colgarse de una cornisa
## En el aire frente a un muro cuyo borde está al alcance de las manos (más alto de lo que se puede
## encaramar de un salto): se agarra. Colgado: A/D se desplaza por el borde (en las esquinas exteriores
## e interiores la rodea), Espacio/W sube, S/C se suelta. Gasta estamina; sin estamina se suelta.
const COLGAR_ALTO_MIN := 2.4   # borde respecto al centro del cuerpo: entre esto y COLGAR_ALTO_MAX
const COLGAR_ALTO_MAX := 3.9
const COLGAR_BAJO := 3.0       # el centro del cuerpo cuelga 3 studs por debajo del borde
const COLGAR_SEP := 0.8        # separación del centro del cuerpo a la pared
const COLGAR_VEL := 2.6        # studs/s desplazándose de lado
const COLGAR_GASTO := 2.0      # estamina/s colgado quieto
const COLGAR_GASTO_MOV := 5.0  # estamina/s desplazándose
const COLGAR_RAPIDO := 1.9     # con Shift: velocidad x1.9 (y el doble de gasto)


## borde superior de la pared en (punto de la pared w, normal n): devuelve top_y o NAN
func _borde_en(w: Vector3, n: Vector3, y_ref: float) -> float:
	var desde := Vector3(w.x, y_ref + 1.6, w.z) - n * 0.3
	if not raycast(Vector3(desde.x, y_ref + 0.2, desde.z) + n * 0.6, Vector3(0, 1.4, 0)).is_empty():
		return NAN # hay techo encima del borde: no se puede agarrar
	var top := raycast(desde, Vector3(0, -2.4, 0))
	if top.is_empty() or top.normal.y < 0.7:
		return NAN
	return top.position.y


func buscar_cornisa(dir_h: Vector3) -> Dictionary:
	if dir_h.length() < 0.1:
		return {}
	var c := global_position
	for hgt in [2.6, 1.9, 1.2]:
		# solo pegado a la pared (si no, el cuerpo "volaba" hasta ella)
		var w := raycast(c + Vector3(0, hgt, 0), dir_h * 1.6)
		if w.is_empty() or absf(w.normal.y) > 0.3:
			continue
		var n := Rbx.flat(w.normal).normalized()
		if dir_h.dot(-n) < 0.5:
			continue
		var top_y := _borde_en(w.position, n, c.y + 2.6)
		if is_nan(top_y):
			continue
		var rel := top_y - c.y
		if rel < COLGAR_ALTO_MIN or rel > COLGAR_ALTO_MAX:
			continue
		return {"edge": Vector3(w.position.x, top_y, w.position.z), "n": n, "top": top_y}
	return {}


func colgarse(c: Dictionary) -> void:
	colgado = {"edge": c.edge, "n": c.n, "top": c.top, "ph": 0.0, "mv": 0.0, "rapido": false, "giro": null, "t0": ahora(),
		"desde": global_position}
	vaulting = null
	L.vault = null
	_subir_a = null
	air_vel = null
	_move_override = null
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_set_estado("Physics")
	Ruido.emitir(self, c.edge, C.RUIDO.Colgarse, Ruido.SORTEAR, self)
	if not estamina_infinita:
		stamina = maxf(0.0, stamina - 3.0)
	# las manos hacen falta: se guarda el arma
	arsenal.guardar_ya()
	shake = minf(1.0, shake + 0.25)


func _pos_colgado(edge: Vector3, n: Vector3) -> Vector3:
	return edge + n * COLGAR_SEP + Vector3(0, -COLGAR_BAJO, 0)


func soltar_cornisa(msg := "") -> void:
	if colgado == null:
		return
	var n: Vector3 = colgado.n
	colgado = null
	L.hang = null
	collision_layer = 1
	collision_mask = 1 | 4
	_soltado_t = ahora()
	velocity = n * 2.5
	vel_real = velocity
	_set_estado("Freefall")
	en_suelo = false
	if msg != "":
		notify(msg)


func trepar_cornisa() -> void:
	if colgado == null or colgado.giro != null:
		return
	var edge: Vector3 = colgado.edge
	var n: Vector3 = colgado.n
	var d := -n
	# sitio para ponerse de pie arriba
	var stand := edge + d * 1.1
	var flo := raycast(Vector3(stand.x, colgado.top + 0.6, stand.z), Vector3(0, -1.2, 0))
	if flo.is_empty() or not raycast(flo.position + Vector3(0, 0.1, 0), Vector3(0, C.STANCE[0].Center + 2.4, 0)).is_empty():
		notify("No hay sitio para subir")
		return
	var feet_y := global_position.y - C.STANCE[0].Center
	var v := {"kind": "mantle", "edge": Vector3(edge.x, colgado.top, edge.z), "dir": d, "topY": flo.position.y,
		"landY": flo.position.y, "h": colgado.top - feet_y, "feetY": feet_y}
	var guardado = colgado
	colgado = null
	L.hang = null
	if not start_vault(v):
		colgado = guardado
		collision_layer = 0
		collision_mask = 0
		_set_estado("Physics")


## GIRO EN UNA ESQUINA, como una persona: la mano que va delante se estira y agarra la otra cara,
## el cuerpo se acerca a la esquina, gira alrededor de ella (exterior) o en el sitio (interior)
## colgando de las dos manos, y la mano de atrás la sigue al final.
##   e0, n0: borde y normal de la cara actual · e1, n1: borde y normal de la cara nueva
##   c: punto de la esquina a la altura del borde · a: dirección del movimiento · lado: +1 der / -1 izq
func _nuevo_giro(tipo: String, e0: Vector3, n0: Vector3, e1: Vector3, n1: Vector3, c: Vector3, a: Vector3, lado: float) -> Dictionary:
	var r0 := (-n0).cross(Vector3.UP).normalized()
	var r1 := (-n1).cross(Vector3.UP).normalized()
	var g := {"tipo": tipo, "t0": ahora(), "dur": 1.1 if tipo == "exterior" else 0.95, "lado": lado,
		"e0": e0, "n0": n0, "e1": e1, "n1": n1, "c": c, "a": a,
		"ang": n0.signed_angle_to(n1, Vector3.UP), "cuerpo0": _pos_colgado(e0, n0)}
	var up := Vector3(0, 0.12, 0)
	# muñecas: [inicio, agarre junto a la esquina, final] (en el borde, la mano sobre la cornisa)
	g.lead0 = e0 + r0 * (lado * 0.58) + n0 * 0.06 + up
	g.trail0 = e0 - r0 * (lado * 0.58) + n0 * 0.06 + up
	g.lead2 = e1 + r1 * (lado * 0.58) + n1 * 0.06 + up
	g.trail2 = e1 - r1 * (lado * 0.58) + n1 * 0.06 + up
	if tipo == "exterior":
		# la mano de delante agarra la cara nueva justo pasada la esquina; la de atrás se acerca a ella
		g.lead1 = c - n0 * 0.45 + n1 * 0.06 + up
		g.trail1 = c - a * 0.4 + n0 * 0.06 + up
		g.cuerpo1 = c + n0 * COLGAR_SEP + Vector3(0, -COLGAR_BAJO, 0)
		g.cuerpo2 = c + n1 * COLGAR_SEP + Vector3(0, -COLGAR_BAJO, 0)
	else:
		# esquina interior: la mano de delante pasa a la pared de enfrente, el cuerpo queda en diagonal
		g.lead1 = c - a * 0.06 + n0 * 0.45 + up
		g.trail1 = c - a * 0.45 + n0 * 0.06 + up
		g.cuerpo1 = c - a * COLGAR_SEP + n0 * COLGAR_SEP + Vector3(0, -COLGAR_BAJO, 0)
		g.cuerpo2 = g.cuerpo1
	g.cuerpo3 = _pos_colgado(e1, n1)
	return g


## mueve una mano de p a q durante [t0, t1] levantándola un poco a mitad del recorrido
static func _mano(p: Vector3, q: Vector3, u: float, t0: float, t1: float) -> Vector3:
	var k := Rbx.smooth((u - t0) / (t1 - t0))
	return p.lerp(q, k) + Vector3(0, sin(PI * k) * 0.3, 0)


## devuelve [posición del cuerpo, normal a la que mira, {L, R} manos, u]
func _paso_giro(g: Dictionary, _dt: float) -> Array:
	var u := clampf((ahora() - float(g.t0)) / float(g.dur), 0.0, 1.0)
	var cuerpo: Vector3
	var cara: Vector3
	var lead: Vector3
	var trail: Vector3
	if g.tipo == "exterior":
		# A: mano delantera rodea la esquina y el cuerpo se pone frente a ella
		# B: el cuerpo gira alrededor de la esquina (arco) colgando de las dos manos
		# C: la mano de atrás pasa a la cara nueva y el cuerpo se coloca
		var kA := Rbx.smooth(u / 0.32)
		var kB := Rbx.smooth((u - 0.3) / 0.42)
		var kC := Rbx.smooth((u - 0.7) / 0.3)
		cara = (g.n0 as Vector3).rotated(Vector3.UP, float(g.ang) * kB)
		if u < 0.3:
			cuerpo = (g.cuerpo0 as Vector3).lerp(g.cuerpo1, kA)
		elif u < 0.72:
			cuerpo = (g.c as Vector3) + cara * COLGAR_SEP + Vector3(0, -COLGAR_BAJO, 0)
		else:
			cuerpo = (g.cuerpo2 as Vector3).lerp(g.cuerpo3, kC)
		lead = _mano(g.lead0, g.lead1, u, 0.0, 0.3)
		if u > 0.75:
			lead = (g.lead1 as Vector3).lerp(g.lead2, kC)
		trail = _mano(g.trail0, g.trail1, u, 0.08, 0.32)
		if u > 0.5:
			trail = _mano(g.trail1, g.trail2, u, 0.55, 0.92)
	else:
		# A: el cuerpo se arrima a la esquina y la mano delantera agarra la pared de enfrente
		# B: el cuerpo gira en el sitio (en diagonal) · C: se coloca frente a la pared nueva
		var kA := Rbx.smooth(u / 0.4)
		var kB := Rbx.smooth((u - 0.3) / 0.4)
		var kC := Rbx.smooth((u - 0.62) / 0.38)
		cara = (g.n0 as Vector3).rotated(Vector3.UP, float(g.ang) * kB)
		cuerpo = (g.cuerpo0 as Vector3).lerp(g.cuerpo1, kA)
		if u > 0.62:
			cuerpo = (g.cuerpo1 as Vector3).lerp(g.cuerpo3, kC)
		lead = _mano(g.lead0, g.lead1, u, 0.0, 0.32)
		if u > 0.62:
			lead = (g.lead1 as Vector3).lerp(g.lead2, kC)
		trail = _mano(g.trail0, g.trail1, u, 0.1, 0.4)
		if u > 0.5:
			trail = _mano(g.trail1, g.trail2, u, 0.55, 0.92)
	var lado: float = g.lado
	# cada mano se orienta según la cara de la pared en la que está apoyada
	var n_lead: Vector3 = g.n0 if u < 0.15 else g.n1
	var n_trail: Vector3 = g.n0 if u < 0.7 else g.n1
	var ml := [lead, n_lead]
	var mt := [trail, n_trail]
	var manos := {"R": ml, "L": mt} if lado > 0 else {"L": ml, "R": mt}
	return [cuerpo, cara, manos, u]


## un paso por el borde: devuelve el nuevo punto del borde (o null si la pared no sigue)
func _seguir_borde(edge: Vector3, n: Vector3, top: float) -> Variant:
	var w := raycast(edge + n * 1.2 + Vector3(0, -0.4, 0), -n * 2.0)
	if w.is_empty() or (w.normal as Vector3).dot(n) < 0.8:
		return null
	var t := _borde_en(w.position, n, top)
	if is_nan(t) or absf(t - top) > 0.8:
		return null
	return Vector3(w.position.x, t, w.position.z)


func step_colgado(dt: float) -> void:
	var cg: Dictionary = colgado
	aiming = false
	firing = false
	var n: Vector3 = cg.n
	var edge: Vector3 = cg.edge
	var lat := 0.0
	if cg.giro == null and free_mouse == false:
		if Input.is_physical_key_pressed(KEY_D): lat += 1.0
		if Input.is_physical_key_pressed(KEY_A): lat -= 1.0
		if Input.is_physical_key_pressed(KEY_W):
			trepar_cornisa()
			return
		if Input.is_physical_key_pressed(KEY_S):
			soltar_cornisa()
			return
	var manos = null
	var cuerpo = null   # posición del cuerpo forzada (durante los giros)
	var cara := n       # hacia dónde mira el cuerpo (la normal de la pared que tiene delante)
	if cg.giro != null:
		var g: Dictionary = cg.giro
		var r_ = _paso_giro(g, dt)
		cuerpo = r_[0]
		cara = r_[1]
		manos = r_[2]
		cg.mv = 0.0
		cg.n = cara
		cg.edge = (cuerpo as Vector3) - cara * COLGAR_SEP + Vector3(0, COLGAR_BAJO, 0)
		if float(r_[3]) >= 1.0:
			cg.edge = g.e1
			cg.n = g.n1
			cg.top = (g.e1 as Vector3).y
			cg.giro = null
			cuerpo = null
			manos = null
			cara = g.n1
	elif lat != 0.0:
		var r := (-n).cross(Vector3.UP).normalized()
		var a := r * lat
		# con Shift se desplaza más rápido (y gasta más estamina)
		cg.rapido = Input.is_physical_key_pressed(KEY_SHIFT) and stamina > 0.0
		var paso := COLGAR_VEL * (COLGAR_RAPIDO if cg.rapido else 1.0) * dt
		# ¿esquina interior? (otra pared justo delante, en la dirección del movimiento)
		var wi := raycast(edge + n * 0.6 + Vector3(0, -0.4, 0), a * 1.0)
		var giro_i := false
		if not wi.is_empty() and (wi.normal as Vector3).dot(-a) > 0.8:
			var nn := Rbx.flat(wi.normal).normalized()
			var to_e: Vector3 = (wi.position as Vector3) + n * 0.25
			var t2 := _borde_en(to_e, nn, cg.top)
			cg.mv = 0.0
			giro_i = true
			if not is_nan(t2) and absf(t2 - cg.top) < 0.8:
				var ci := Vector3((wi.position as Vector3).x, cg.top, (wi.position as Vector3).z) - n * 0.6
				cg.giro = _nuevo_giro("interior", edge, n, Vector3(to_e.x, t2, to_e.z), nn, ci, a, lat)
		if not giro_i:
			var sig = _seguir_borde(edge + a * (paso + 0.75), n, cg.top)
			if sig != null:
				var ahora_e = _seguir_borde(edge + a * paso, n, cg.top)
				if ahora_e != null:
					cg.edge = ahora_e
					cg.top = (ahora_e as Vector3).y
				cg.mv = lat
				cg.ph += lat * dt * 6.0 * (COLGAR_RAPIDO if cg.rapido else 1.0)
			else:
				cg.mv = 0.0
				# ¿esquina exterior? (la pared se acaba y gira hacia dentro)
				var q := edge + a * 1.6 - n * 0.6 + Vector3(0, -0.4, 0)
				var we := raycast(q, -a * 2.0)
				if not we.is_empty() and (we.normal as Vector3).dot(a) > 0.8:
					var to_e2: Vector3 = (we.position as Vector3) - n * 0.25
					var t3 := _borde_en(to_e2, a, cg.top)
					if not is_nan(t3) and absf(t3 - cg.top) < 0.8:
						var ce := Vector3((we.position as Vector3).x, cg.top, (we.position as Vector3).z) + n * 0.6
						cg.giro = _nuevo_giro("exterior", edge, n, Vector3(to_e2.x, t3, to_e2.z), a, ce, a, lat)
	else:
		cg.mv = 0.0
	# estamina
	if not estamina_infinita:
		var gasto := COLGAR_GASTO_MOV if (absf(float(cg.mv)) > 0.1 or cg.giro != null) else COLGAR_GASTO
		if cg.get("rapido", false) and absf(float(cg.mv)) > 0.1:
			gasto *= 2.0
		stamina = maxf(0.0, stamina - gasto * dt)
		if stamina <= 0.0:
			soltar_cornisa("Te has quedado sin fuerzas")
			return
	# colocar el cuerpo (con un tirón suave al agarrarse)
	var obj: Vector3 = cuerpo if cuerpo != null else _pos_colgado(cg.edge, cg.n)
	# el cuerpo no va clavado: al desplazarse se queda un poco atrás de las manos y se balancea;
	# quieto, sube y baja un poco con la respiración
	var r_c := (-(cg.n as Vector3)).cross(Vector3.UP).normalized()
	cg.lag = Rbx.damp(float(cg.get("lag", 0.0)), -float(cg.mv) * 0.22, 5.0, dt)
	obj += r_c * float(cg.lag) + Vector3(0, sin(ahora() * 2.6) * 0.035, 0)
	var ag := Rbx.smooth(clampf((ahora() - float(cg.t0)) / 0.25, 0.0, 1.0))
	var pos: Vector3 = (cg.desde as Vector3).lerp(obj, ag)
	var prev := global_position
	global_transform = Rbx.look_at(pos, pos - cara)
	# leve péndulo de lado (más al desplazarse) y algo inclinado hacia la pared
	var balanceo := sin(ahora() * 1.1) * 0.03 + float(cg.lag) * 0.35
	global_transform.basis = global_transform.basis * Basis(Vector3(0, 0, 1), balanceo) * Basis(Vector3(1, 0, 0), -0.05)
	yaw = Rbx.wrap_a(yaw) # la cámara es libre
	vel_real = (pos - prev) / maxf(dt, 1.0 / 240)
	velocity = Vector3.ZERO
	en_suelo = false
	L.hang = {"edge": cg.edge, "n": cg.n, "top": cg.top, "mv": cg.mv, "ph": cg.ph, "giro": cg.giro != null, "manos": manos}


## ---------------------------------------------------------------- bucle principal
func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	reloj += dt
	move_direction = _leer_movimiento() if health > 0 else Vector3.ZERO
	_aproximar_escalada()
	arsenal.dirigir()
	update_character(dt)
	arsenal.actualizar(dt)
	humanoid_step(dt)
	update_camera(dt)
	_paso_salud(dt)
	_update_hud()


## ---------------------------------------------------------------- teletransporte (menú de trucos)
var invencible := false # truco: no recibe daño


## pone al jugador de pie en "pies" (studs) mirando hacia "giro"; suelta la cornisa o el salto en curso
func teletransportar(pies: Vector3, giro: float) -> void:
	if colgado != null:
		soltar_cornisa()
	if vaulting != null:
		vaulting = null
		L.vault = null
	_subir_a = null
	collision_layer = 1
	collision_mask = 1 | 4
	global_position = pies + Vector3(0, center_cur + 0.1, 0)
	velocity = Vector3.ZERO
	vel_real = Vector3.ZERO
	cur_move = 0.0
	yaw = giro
	rotation.y = giro
	pitch = -0.12
	cam_pivot = null
	var an := get_node_or_null("Animador") as Animador
	if an:
		an.replant = true


## ---------------------------------------------------------------- daño, vida y muerte
## (de momento solo hacen daño los zombis; ver docs/RUIDO_Y_ZOMBIS.md)
const MUERTE_REINICIO := 4.0 # s desde que muere hasta que se reinicia el nivel
var _danio_t := -99.0
var _muerte_t := -1.0
var _reiniciando := false


## recibe un golpe de cantidad puntos desde la posición "desde" (para el empujón y la reacción)
func recibir_danio(cantidad: float, desde: Vector3 = Vector3.ZERO) -> void:
	if health <= 0.0 or cantidad <= 0.0 or invencible:
		return
	health = maxf(0.0, health - cantidad)
	_danio_t = reloj
	shake = minf(1.0, shake + 0.45)
	var dir := Rbx.flat(global_position - desde)
	if dir.length() > 0.01:
		empuje += dir.normalized() * 6.0
	# el cuerpo encaja el golpe (muelles de impacto del animador)
	var an := get_node_or_null("Animador") as Animador
	if an and not an.S.is_empty():
		(an.S.hitPitch as Rbx.Muelle).impulse(-4.0)
		(an.S.hitHead as Rbx.Muelle).impulse(-5.0)
	if health <= 0.0:
		_morir()


func _morir() -> void:
	_muerte_t = reloj
	if colgado != null:
		soltar_cornisa()
	if vaulting != null:
		# a mitad de un salto de valla: recupera la colisión (el salto la quita) y cae
		vaulting = null
		L.vault = null
		collision_layer = 1
		collision_mask = 1 | 4
		_set_estado("Freefall")
	firing = false
	aiming = false
	arsenal.guardar_ya()
	notify("HAS MUERTO")
	_notif_hasta = reloj + MUERTE_REINICIO + 1.0


## regenera vida si lleva un rato sin recibir daño (ZConfig.PLAYER.RegenDelay / RegenRate); muerto,
## el cuerpo cae y el nivel se reinicia
func _paso_salud(dt: float) -> void:
	if health > 0.0:
		if health < max_health and reloj - _danio_t > C.PLAYER.RegenDelay:
			health = minf(max_health, health + C.PLAYER.RegenRate * dt)
		return
	# cae de espaldas alrededor de los pies (el animador deja de animar al morir)
	var k := Rbx.smooth((reloj - _muerte_t) / 0.9)
	var r := Basis(Vector3.RIGHT, k * PI * 0.5)
	var pies := Vector3(0, -center_cur, 0)
	rig.transform = Transform3D(r, pies - r * pies + Vector3(0, 0.45 * k, 0))
	if reloj - _muerte_t > MUERTE_REINICIO and get_tree().current_scene and not _reiniciando:
		_reiniciando = true
		get_tree().reload_current_scene()


func update_character(dt: float) -> void:
	if health <= 0:
		if vaulting != null:
			vaulting = null
			L.vault = null
		return
	if vaulting != null:
		if L.knocked:
			vaulting = null
			L.vault = null
		else:
			step_vault(dt)
	if colgado != null:
		step_colgado(dt)

	# estamina y velocidad
	var moving := move_direction.length() > 0.1
	var want_sprint := Input.is_physical_key_pressed(KEY_SHIFT) and moving and not aiming and not firing
	# tumbado: Shift = reptar rápido (solo boca abajo y ya tumbado); agachado se corre agachado
	if stance == 2:
		want_sprint = want_sprint and not supine and prone_p > 0.98
	# modo pruebas: estamina infinita (ZConfig.PLAYER.InfiniteStamina)
	if estamina_infinita:
		stamina = C.PLAYER.StaminaMax
		exhausted = false
	if stamina <= 0:
		exhausted = true
	if exhausted and stamina > C.PLAYER.StaminaMax * C.PLAYER.ExhaustRecover:
		exhausted = false
	var sprinting := want_sprint and not exhausted
	var crouch_sprint := sprinting and stance == 1
	var prone_sprint := sprinting and stance == 2
	# dirección de la carrera respecto a hacia dónde mira el cuerpo: de lado o hacia atrás se va más lento
	var fwd_k := 1.0
	var back_k := 0.0
	var lk := Rbx.look(root_cf())
	var fl := Vector3(lk.x, 0, lk.z)
	if move_direction.length() > 0.1 and fl.length() > 0.1:
		var a := move_direction.normalized().dot(fl.normalized())
		fwd_k = clampf(a, 0, 1)
		back_k = clampf(-a, 0, 1)
	if sprinting:
		var drain: float = C.PLAYER.SprintDrain * (C.PLAYER.CrouchSprintDrain if crouch_sprint else (C.PLAYER.ProneSprintDrain if prone_sprint else 1.0))
		stamina = maxf(0, stamina - drain * dt)
	else:
		stamina = minf(C.PLAYER.StaminaMax, stamina + C.PLAYER.StaminaRegen * dt * (0.6 if moving else 1.0))
	var speed: float
	if prone_sprint:
		speed = C.PLAYER.ProneSprintSpeed
	elif crouch_sprint:
		speed = C.PLAYER.CrouchSprintSpeed
	elif sprinting:
		speed = C.PLAYER.SprintSpeed
	else:
		speed = (C.PLAYER.AimSpeed if aiming else C.PLAYER.WalkSpeed) * C.STANCE[stance].Speed
	if sprinting:
		# de frente a tope; de lado ~60 %; hacia atrás ~50 %
		speed *= 0.6 + 0.4 * pow(fwd_k, 1.5) - 0.1 * back_k
	else:
		speed *= 0.9 + 0.1 * fwd_k - 0.12 * back_k
	# cansancio: por debajo del 40 % de estamina se va notando; agotado, del todo
	var fat_obj := 1.0 if exhausted else clampf((0.4 - stamina / C.PLAYER.StaminaMax) / 0.4, 0.0, 1.0)
	fatiga = Rbx.damp(fatiga, fat_obj, 1.5, dt)
	if sprinting:
		speed *= lerpf(1.0, 0.85, fatiga)
	else:
		speed *= lerpf(1.0, 0.72, fatiga) # andar con fatiga: más lento y pesado
	if ahora() < slow_until:
		speed *= 0.55
	if health / max_health < 0.3:
		speed *= 0.85 # herido: más lento
	# pared delante: se frena antes de chocar (no se mete en las paredes)
	if move_direction.length() > 0.1 and stance != 2:
		var md := move_direction.normalized()
		var wall := raycast(global_position + Vector3(0, 0.6, 0), md * 3.5)
		if not wall.is_empty() and absf(wall.normal.y) < 0.5 and (wall.normal as Vector3).dot(md) < -0.5:
			speed *= clampf((wall.distance - RADIO_CUERPO - 0.15) / 2.0, 0.0, 1.0)
	# escaleras y cuestas: subiendo se va más despacio (bajando un poco también)
	# pendiente efectiva: la medida del camino (escaleras) o la de la cuesta bajo los pies, la que
	# más pese (la del suelo es instantánea: al entrar en una rampa empinada se nota enseguida)
	var pend_ef := pendiente
	if en_suelo and move_direction.length() > 0.1 and normal_suelo.y < 0.999:
		var md0 := move_direction.normalized()
		var gi := -(normal_suelo.x * md0.x + normal_suelo.z * md0.z) / maxf(normal_suelo.y, 0.3)
		pend_ef = maxf(pendiente, gi) if gi > 0 else minf(pendiente, gi)
	if pend_ef > 0:
		speed *= clampf(1.0 - 0.45 * pend_ef, 0.5, 1.0)
	else:
		speed *= clampf(1.0 + 0.2 * pend_ef, 0.75, 1.0)

	# ladeo (Q izquierda / E derecha, mantener): no se puede corriendo ni tumbado;
	# una pared en ese lado limita cuánto te puedes asomar
	var lean_in := 0.0
	if stance != 2 and not sprinting and not L.knocked and not free_mouse:
		if Input.is_physical_key_pressed(KEY_Q): lean_in -= 1
		if Input.is_physical_key_pressed(KEY_E): lean_in += 1
	if lean_in != 0:
		var chest := global_position + Vector3(0, 1.2, 0)
		var dir_r := Rbx.right(Rbx.ang(0, yaw, 0)) * lean_in
		var wh := raycast(chest, dir_r * 1.7)
		lean_max = clampf((wh.distance - 0.55) / 1.15, 0, 1) if not wh.is_empty() else 1.0
	else:
		lean_max = 1.0
	var lean_t := lean_in * lean_max
	lean_cur += (lean_t - lean_cur) * minf(1, dt * 6)
	if absf(lean_cur) > 0.2:
		speed *= 0.55 # asomado: te mueves despacio
	# tumbado: reptar hacia delante (hacia la cámara) a velocidad normal; de lado o hacia atrás más lento.
	if stance != 2:
		supine = false
	if stance == 2 and prone_p > 0.98 and move_direction.length() > 0.1:
		var fw := Rbx.look(Rbx.ang(0, yaw, 0))
		var align := maxf(0, fw.dot(move_direction.normalized()))
		speed *= 0.4 + 0.6 * align
		if supine:
			speed *= 0.5
	# durante la transición de cuerpo a tierra no te mueves
	var in_transition := prone_p > 0.001 and prone_p < 0.999
	getup_p = maxf(0.0, getup_p - dt / C.PLAYER.ProneTime * 1.15)
	if getup_p > 0:
		in_transition = true
	L.gettingUp = getup_p > 0
	# recogiendo algo del suelo: quieto
	if arsenal.recogiendo != null:
		in_transition = true
	if in_transition:
		speed = 0.01
	# inercia: se tarda un momento en alcanzar la velocidad (y en frenar la carrera)
	if moving:
		var rate: float = (C.PLAYER.SprintAccel if sprinting else C.PLAYER.Accel) if speed > cur_move else C.PLAYER.Accel * 1.6
		cur_move = cur_move + (speed - cur_move) * (1 - exp(-rate * dt))
	else:
		cur_move = minf(cur_move, 3)
	walk_speed = 0.0 if in_transition else maxf(0.8 if stance == 2 else 2.5, cur_move)
	jump_height = C.PLAYER.JumpHeight if (stamina >= C.PLAYER.JumpCost and stance == 0 and not in_transition) else 0.0
	# EN EL AIRE se conserva la inercia: no se puede frenar ni girar en seco (solo un poco de control)
	if (estado == "Freefall" or estado == "Jumping") and vaulting == null and not L.knocked:
		var hv := Vector3(vel_real.x, 0, vel_real.z)
		if air_vel == null:
			air_vel = hv
			air_cap = maxf(hv.length(), 3)
		# chocó con algo (pared): la inercia se pierde
		if hv.length() < (air_vel as Vector3).length() * 0.5:
			air_vel = hv
		air_vel += move_direction * C.WORLD.AirControl * dt
		if (air_vel as Vector3).length() > air_cap:
			air_vel = (air_vel as Vector3).normalized() * air_cap
		walk_speed = (air_vel as Vector3).length()
		_move_override = (air_vel as Vector3).normalized() if walk_speed > 0.05 else Vector3.ZERO
	else:
		air_vel = null
		_move_override = null
	# altura del cuerpo según la postura. Tumbarse avanza a ritmo constante (fases de la animación)
	var p_t := 1.0 if stance == 2 else 0.0
	prone_p = prone_p + clampf(p_t - prone_p, -dt / C.PLAYER.ProneTime, dt / C.PLAYER.ProneTime)
	var base_c: float = C.STANCE[1 if stance == 2 else stance].Center
	non_prone_c += (base_c - non_prone_c) * minf(1, dt * 3.5)
	var sp := smooth01(maxf(prone_p, getup_p))
	center_cur = non_prone_c + (C.STANCE[2].Center - non_prone_c) * sp
	# cápsula baja al tumbarse: cabe por debajo de un coche
	root_size = PRONE_SIZE if center_cur < 1.3 else STAND_SIZE
	hip_height = maxf(0.05, center_cur - root_size.y / 2)
	_actualizar_formas()

	# orientación
	if not L.knocked and vaulting == null and colgado == null:
		var cy := Rbx.yaw_of(root_cf())
		if stance == 2:
			# cuerpo a tierra (como Ghost Recon): el cuerpo SIEMPRE sigue a la cámara
			#  · boca abajo: la cabeza apunta hacia donde mira la cámara
			#  · si miras hacia atrás (>115°) o hacia arriba: rueda y queda boca arriba
			#  · si vuelves a mirar al frente y abajo: rueda de nuevo boca abajo
			var rel_head := Rbx.wrap_a(yaw - cy)
			var target_yaw = null
			if prone_p > 0.98:
				if not supine and (absf(rel_head) > deg_to_rad(115) or pitch > 0.62):
					supine = true
					roll_side = 1.0 if rel_head >= 0 else -1.0
				elif supine and absf(rel_head) < deg_to_rad(65) and pitch < 0.3:
					supine = false
					roll_side = 1.0 if rel_head >= 0 else -1.0
				if not supine:
					target_yaw = yaw
				elif absf(rel_head) > deg_to_rad(90):
					target_yaw = yaw + PI # boca arriba: los pies hacia la mira
			if target_yaw != null:
				var diff := Rbx.wrap_a(target_yaw - cy)
				var dz := deg_to_rad(4)
				var excess := (diff - signf(diff) * dz) if absf(diff) > dz else 0.0
				# giro con peso: acelera y frena suavemente
				var want_rate := clampf(excess * 5, -deg_to_rad(150), deg_to_rad(150))
				prone_turn_rate = prone_turn_rate + (want_rate - prone_turn_rate) * minf(1, dt * 7)
				var step := prone_turn_rate * dt
				if absf(step) > 1e-5:
					rotation = Vector3(0, cy + step, 0)
		elif arsenal.recogiendo != null:
			# recogiendo: el cuerpo se gira hacia lo que coge (lo deja un poco del lado de la mano)
			var rp: Vector3 = arsenal.recogiendo.pos
			var dv := Rbx.flat(rp - global_position)
			if dv.length() > 0.3:
				var lado_m := 0.35 if arsenal.recogiendo.mano == "R" else -0.35
				var ty := atan2(-dv.x, -dv.z) + lado_m
				rotation = Vector3(0, cy + Rbx.wrap_a(ty - cy) * minf(1, dt * 8), 0)
		elif aiming or arsenal.armado():
			# con arma o apuntando, el cuerpo sigue a la mira con algo de peso
			var diff2 := Rbx.wrap_a(yaw - cy)
			rotation = Vector3(0, cy + diff2 * minf(1, dt * 10), 0)
		else:
			# sin arma: el cuerpo gira hacia donde se mueve CON PESO: los pies tienen tiempo de dar
			# sus pasos y las piernas no se cruzan al machacar WASD
			var md := move_direction
			if md.length() > 0.1 and getup_p <= 0:
				var ty := atan2(-md.x, -md.z)
				var diff3 := Rbx.wrap_a(ty - cy)
				var max_step := deg_to_rad(400 if stance == 1 else 560) * dt
				var step_a := clampf(diff3 * minf(1, dt * 10), -max_step, max_step)
				if absf(step_a) > 1e-5:
					rotation = Vector3(0, cy + step_a, 0)

	# estado para el sistema de animación
	L.pitch = pitch
	L.aiming = aiming and vaulting == null
	L.firing = firing and vaulting == null
	L.stamina = stamina / C.PLAYER.StaminaMax
	L.exhausted = exhausted
	L.fatigue = fatiga
	L.sprinting = sprinting
	L.stance = stance
	L.stanceT = stance_change_t
	L.stanceFrom = stance_from
	L.proneP = prone_p
	L.yaw = yaw
	L.supine = supine
	L.rollSide = roll_side
	L.lean = lean_cur


## Formas de colisión: el tronco (HumanoidRootPart) y una caja para las piernas que impide
## subir andando a lo que sea más alto que PASO_MAX (eso se sortea con Espacio).
## De pie o agachado el cuerpo choca como una cápsula que cubre pecho, brazos y mochila (con la
## caja estrecha de Roblox medio cuerpo se metía en las paredes); tumbado, la caja baja de Roblox.
var _capsula: CapsuleShape3D
var _caja_tumbado: BoxShape3D
var _cil_piernas: CylinderShape3D
const RADIO_CUERPO := 0.85
const CABEZA_ALTO := 2.45 # coronilla de pie, sobre el centro del cuerpo (studs)
var _caja_cabeza: BoxShape3D
var forma_cabeza: CollisionShape3D


func _actualizar_formas() -> void:
	if _capsula == null:
		_capsula = CapsuleShape3D.new()
		_capsula.radius = RADIO_CUERPO
		_capsula.height = STAND_SIZE.y
		_caja_tumbado = BoxShape3D.new()
		_caja_tumbado.size = PRONE_SIZE
		_cil_piernas = CylinderShape3D.new()
		_cil_piernas.radius = 0.7
		forma_piernas.shape = _cil_piernas
	var prone_shape := root_size.y < STAND_SIZE.y - 0.01
	var want: Shape3D = _caja_tumbado if prone_shape else _capsula
	if forma_cuerpo.shape != want:
		forma_cuerpo.shape = want
	# la cápsula llega desde la cintura hasta la cabeza (el centro del cuerpo + 1.6 studs)
	if not prone_shape:
		forma_cuerpo.position = Vector3(0, 0.35, 0)
		_capsula.height = maxf(STAND_SIZE.y + 0.7, RADIO_CUERPO * 2.0)
	else:
		forma_cuerpo.position = Vector3.ZERO
	# cabeza (solo de pie): una caja de techo plano entre lo alto de la cápsula y la coronilla. La
	# cápsula llega a los hombros; sin esto la cabeza atravesaba los techos bajos (túneles) y la
	# cápsula, redondeada arriba, se colaba por debajo del borde
	if _caja_cabeza == null:
		_caja_cabeza = BoxShape3D.new()
		_caja_cabeza.size = Vector3(0.9, CABEZA_ALTO - 1.25, 0.9)
		forma_cabeza = CollisionShape3D.new()
		forma_cabeza.name = "FormaCabeza"
		forma_cabeza.shape = _caja_cabeza
		forma_cabeza.position = Vector3(0, (1.25 + CABEZA_ALTO) * 0.5, 0)
		add_child(forma_cabeza)
	forma_cabeza.disabled = prone_shape or stance != 0 or getup_p > 0.001
	var top := -root_size.y / 2
	var bottom := -center_cur + PASO_MAX
	if top - bottom > 0.1:
		forma_piernas.disabled = false
		_cil_piernas.height = top - bottom
		forma_piernas.position = Vector3(0, (top + bottom) / 2, 0)
	else:
		forma_piernas.disabled = true


## ---------------------------------------------------------------- Humanoid (física del cuerpo)
func _set_estado(n: String) -> void:
	if n == estado:
		return
	estado = n
	estado_cambiado.emit(n)


func _sondear_suelo(largo: float) -> Dictionary:
	# el suelo es el que hay justo debajo del centro del cuerpo. Si el centro ya pasó el borde de
	# algo alto (debajo no hay suelo cerca), NO cuenta el suelo de alrededor: el cuerpo cae.
	# Solo si el centro está sobre una superficie muy inclinada se usan los rayos de alrededor.
	var c := raycast(global_position, Vector3(0, -largo, 0))
	if not c.is_empty() and c.normal.y >= 0.3:
		return c
	if c.is_empty():
		return {}
	var best := {}
	var b := Basis(Vector3.UP, rotation.y)
	for off in [Vector3(0.5, 0, 0.25), Vector3(-0.5, 0, 0.25), Vector3(0.5, 0, -0.25), Vector3(-0.5, 0, -0.25)]:
		var o: Vector3 = global_position + b * off
		var r := raycast(o, Vector3(0, -largo, 0))
		if r.is_empty() or r.normal.y < 0.3:
			continue
		if best.is_empty() or r.position.y > best.position.y:
			best = r
	return best


func humanoid_step(dt: float) -> void:
	if estado == "Physics":
		en_suelo = false
		return
	var g: float = C.WORLD.Gravity
	var v := velocity
	var mov: Vector3 = move_direction if _move_override == null else _move_override
	var horiz := mov * walk_speed
	# empujón propio (acometida de un golpe): se suma y se apaga enseguida
	if en_suelo:
		horiz += empuje
	empuje = empuje.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * dt))
	var pos := global_position
	if estado == "Running":
		# en el suelo: el cuerpo flota a la altura de la cadera; baja escalones pegado al suelo
		var gnd := _sondear_suelo(center_cur + 1.6)
		if not gnd.is_empty():
			var target: float = gnd.position.y + center_cur
			# en cuesta el cuerpo sube/baja a la vez que avanza (sin quedarse atrás y doblar las piernas)
			var n: Vector3 = gnd.normal
			var ff := -(n.x * horiz.x + n.z * horiz.z) / maxf(n.y, 0.3)
			# la velocidad es a lo largo de la cuesta: en horizontal se avanza menos cuanto más
			# empinada (si no, en una rampa se iba más rápido que en llano)
			var hl := Vector2(horiz.x, horiz.z).length()
			if hl > 0.01 and absf(ff) > 0.01:
				var ks := hl / sqrt(hl * hl + ff * ff)
				horiz *= ks
				ff *= ks
			v.y = clampf(ff + (target - pos.y) * 25.0, -40.0, 60.0)
			en_suelo = true
			normal_suelo = gnd.normal
			# pendiente media del camino recorrido (en escaleras el suelo sube a saltos)
			var gp: Vector3 = gnd.position
			if _suelo_prev != null:
				var dh := Vector2(gp.x - _suelo_prev.x, gp.z - _suelo_prev.z).length()
				if dh > 0.6:
					pendiente = Rbx.damp(pendiente, clampf((gp.y - _suelo_prev.y) / dh, -1.5, 1.5), 4, dt)
					_suelo_prev = gp
				elif dh < 0.01 and move_direction.length() < 0.1:
					pendiente = Rbx.damp(pendiente, 0.0, 2, dt)
			else:
				_suelo_prev = gp
		else:
			_suelo_prev = null
			pendiente = 0.0
			_set_estado("Freefall")
			en_suelo = false
	if estado == "Jumping" or estado == "Freefall":
		en_suelo = false
		v.y -= g * dt
		if estado == "Jumping" and v.y < 0:
			_set_estado("Freefall")
		if v.y <= 0:
			var gnd2 := _sondear_suelo(center_cur + maxf(0.2, -v.y * dt))
			if not gnd2.is_empty() and pos.y - gnd2.position.y <= center_cur + 0.05:
				# aterrizaje: cuanto más fuerte el golpe, más lejos se oye
				Ruido.emitir(self, gnd2.position, Ruido.radio_aterrizaje(-v.y), Ruido.ATERRIZAJE, self)
				_set_estado("Landed")
				_set_estado("Running")
				en_suelo = true
				v.y = 0
	if _salto_pedido:
		_salto_pedido = false
		if en_suelo and jump_height > 0:
			v.y = sqrt(2.0 * g * jump_height)
			en_suelo = false
			# distancia FIJA: si te mueves, el salto siempre recorre JumpDistance studs en la dirección
			# en la que vas (da igual si andas o corres). Sin moverte, salto vertical.
			if mov.length() > 0.1:
				var t_aire := 2.0 * v.y / g
				var hs: float = C.PLAYER.JumpDistance / t_aire
				horiz = Vector3(mov.x, 0, mov.z).normalized() * hs
				air_vel = horiz
				air_cap = hs
			stamina = maxf(0, stamina - C.PLAYER.JumpCost)
			_set_estado("Jumping")
	velocity = Vector3(horiz.x, v.y, horiz.z)
	move_and_slide()
	# techo: deja de subir
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var cn := col.get_normal()
		if cn.y < -0.7 and velocity.y > 0:
			velocity.y = 0
		# cayendo y apoyado en un borde (el centro ya está fuera): el cuerpo resbala hacia fuera
		# y termina de caer (no se queda colgado del borde)
		if estado == "Freefall" and cn.y > 0.2:
			var nxz := Vector3(cn.x, 0, cn.z)
			if nxz.length() < 0.05:
				# borde casi justo debajo: empujar en la dirección en la que iba (o hacia delante)
				nxz = Rbx.flat(vel_real) if Rbx.flat(vel_real).length() > 0.1 else Rbx.look(global_transform)
			global_position += nxz.normalized() * 5.0 * dt
	vel_real = get_real_velocity()


## ---------------------------------------------------------------- cámara al hombro
func update_camera(dt: float) -> void:
	var now_t := ahora()
	var alive := health > 0
	if alive and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= _mouse_delta.x
		pitch = clampf(pitch - _mouse_delta.y, -1.35, 1.2)
		# tumbado boca abajo no puedes mirar muy arriba (si insistes, el personaje rueda boca arriba)
		if stance == 2:
			pitch = clampf(pitch, -0.3, 1.35) if supine else clampf(pitch, -0.5, 0.75)
		# arma apoyada: se puede girar sobre el apoyo hasta cierto punto (y poco arriba/abajo)
		var ra = arsenal.rest
		if ra != null and not ra.ground:
			var lim := deg_to_rad(C.REST.YawLimit)
			var rel := Rbx.wrap_a(yaw - float(ra.yaw0))
			if absf(rel) > lim:
				yaw = float(ra.yaw0) + signf(rel) * lim
			pitch = clampf(pitch, -0.06, 0.3)
	_mouse_delta = Vector2.ZERO

	# el hombro se desplaza de un lado a otro (no se teletransporta); al asomarse, la cámara
	# pasa automáticamente al lado del ladeo
	var want_side := side
	if absf(lean_cur) > 0.15:
		want_side = 1.0 if lean_cur > 0 else -1.0
	side_cur += (want_side - side_cur) * minf(1, dt * 5)

	# la cámara baja con la postura (altura de ojos relativa al centro del cuerpo)
	var eye_base: float = C.STANCE[1 if stance == 2 else stance].Eye
	var eye_prone: float = C.STANCE[2].Eye
	var eye_t := eye_base + (eye_prone - eye_base) * smooth01(maxf(prone_p, getup_p))
	eye_cur += (eye_t - eye_cur) * minf(1, dt * 4)
	var pivot := global_position + Vector3(0, eye_cur - rest_lower_cur, 0)
	# ladeo: la cabeza (y la cámara) salen hacia el lado y bajan un poco
	pivot += Rbx.right(Rbx.ang(0, yaw, 0)) * lean_cur * 1.15 - Vector3(0, absf(lean_cur) * 0.18, 0)
	# la cámara de carrera (más lejos, más campo de visión, balanceo) solo si de verdad se corre: chocando
	# contra una pared con Shift pulsado el personaje se para y la cámara también
	var vel_h := Vector2(vel_real.x, vel_real.z).length()
	var sprinting: bool = walk_speed > C.PLAYER.WalkSpeed + 1 and vel_h > C.PLAYER.WalkSpeed + 1
	var dist := 4.6 if aiming else (9.5 if sprinting else 8.5)
	if stance == 2:
		dist = 4.0 if aiming else 6.5
	if not aiming:
		dist *= zoom_cam
	var fov := (62.0 if aiming else (76.0 if sprinting else 70.0)) + (Opciones.fov - 70.0)
	var shoulder := (2.1 if aiming else 2.4) * side_cur
	var height := 0.55 if aiming else 0.4
	if absf(lean_cur) > 0.05:
		shoulder *= 1 - absf(lean_cur) * 0.35

	# seguimiento con peso: el punto que sigue la cámara va un pelín por detrás del personaje
	if cam_pivot == null or (cam_pivot - pivot).length() > 15:
		cam_pivot = pivot
	var kH := 15.0
	var kV := 9.0
	# cayendo rápido: la cámara no se queda atrás (sigue al cuerpo) y mira un poco hacia abajo
	var fall_v := maxf(0, -vel_real.y)
	if fall_v > 12:
		kV = 9 + (fall_v - 12) * 1.2
	fall_bias += (clampf((fall_v - 14) / 40, 0, 0.55) - fall_bias) * minf(1, dt * 3)
	var cp: Vector3 = cam_pivot
	cam_pivot = Vector3(
		cp.x + (pivot.x - cp.x) * minf(1, dt * kH),
		cp.y + (pivot.y - cp.y) * minf(1, dt * kV),
		cp.z + (pivot.z - cp.z) * minf(1, dt * kH))
	pivot = cam_pivot

	# aterrizajes: la cámara se hunde y rebota (muelle)
	var vy := vel_real.y
	if prev_vel_y < -12 and vy > prev_vel_y * 0.4:
		land_vel -= minf(10, -prev_vel_y * 0.22)
	prev_vel_y = vy
	land_vel += (-land_off * 90 - land_vel * 13) * dt
	land_off += land_vel * dt
	pivot += Vector3(0, land_off, 0)

	var rot := Rbx.ang(0, yaw, 0) * Rbx.ang(clampf(pitch - fall_bias, -1.35, 1.2), 0, 0)

	# techo bajo: la cámara baja y se acerca
	var up_hit := raycast(pivot, Vector3(0, 2.4, 0))
	if not up_hit.is_empty():
		height = minf(height, up_hit.distance - 0.7)
		dist = minf(dist, 5.5)
	height_cur += (height - height_cur) * minf(1, dt * 8)

	# pared al lado del hombro: la cámara se comprime hacia el centro (rápido al entrar, suave al salir)
	var comp := 1.0
	if absf(shoulder) > 0.05:
		var side_vec := Rbx.right(rot) * shoulder
		var sh := spherecast(pivot, 0.35, side_vec)
		if sh >= 0:
			comp = clampf((sh - 0.15) / absf(shoulder), 0, 1)
	comp_cur += (comp - comp_cur) * minf(1, dt * (18.0 if comp < comp_cur else 3.5))
	shoulder *= comp_cur
	# hombro bloqueado: la cámara sube por encima de la cabeza para no quedar tapada por el cuerpo
	if stance != 2:
		height_cur = maxf(height_cur, height + (1 - comp_cur) * 0.55)

	# poco sitio detrás (de espaldas a una pared): la cámara sube por encima de la cabeza para ver por
	# encima de ella en vez de pegarse a la nuca (sin pasar del techo)
	var apretado := clampf((4.5 - cam_dist) / 3.0, 0.0, 1.0) if stance != 2 else 0.0
	apretado_cur += (apretado - apretado_cur) * minf(1, dt * (10.0 if apretado > apretado_cur else 3.0))
	var sube := apretado_cur * 1.4
	if not up_hit.is_empty():
		sube = minf(sube, maxf(0.0, up_hit.distance - 0.7 - height_cur))
	# colisión esférica hacia atrás: acercarse al instante, alejarse despacio
	var shoulder_pt := (Rbx.cfp(pivot) * rot * Rbx.cf(shoulder, height_cur + sube, 0)).origin
	# el punto de partida nunca puede quedar dentro de una pared (girando la cámara pegado a una
	# pared, el hombro acababa dentro y la cámara se iba a la nuca): se acerca al centro hasta que cabe
	if _esfera_choca(shoulder_pt, 0.42):
		for k in [0.66, 0.33, 0.0]:
			var p2 := (Rbx.cfp(pivot) * rot * Rbx.cf(shoulder * k, height_cur + sube, 0)).origin
			shoulder_pt = p2
			if not _esfera_choca(p2, 0.42):
				break
	var back := -Rbx.look(rot) * dist
	var c_hit := spherecast(shoulder_pt, 0.4, back)
	var allowed := maxf(0.5, c_hit - 0.1) if c_hit >= 0 else dist
	if allowed < cam_dist:
		cam_dist = allowed
	else:
		cam_dist += (allowed - cam_dist) * minf(1, dt * (3.0 if c_hit >= 0 else 7.0))
	cam_fov += (fov - cam_fov) * minf(1, dt * 8)
	camara.fov = cam_fov
	var want := shoulder_pt - Rbx.look(rot) * cam_dist

	# temblor
	shake = maxf(0, shake - dt * 2.5)
	var t := now_t
	var shk := shake * 0.02
	var shake_rot := Rbx.ang(sin(t * 37.1) * shk, sin(t * 29.3 + 1.0) * shk, sin(t * 23.7 + 2.0) * shk * 0.5)
	# balanceo al correr
	var bob := Transform3D.IDENTITY
	if move_direction.length() > 0.1 and en_suelo and vel_h > 0.5:
		var k := minf(walk_speed, vel_h) / 20.0
		bob = Rbx.ang(sin(t * 9 * k) * 0.004 * k, 0, sin(t * 4.5 * k) * 0.006 * k)
	# ladeo: la cámara se inclina un poco con el cuerpo
	var roll := Rbx.ang(0, 0, -lean_cur * 0.08)
	camara.global_transform = Rbx.cfp(want) * Rbx.rot(rot) * shake_rot * bob * roll

	# si la cámara queda pegada al cuerpo (paredes, rincones), el personaje se vuelve semitransparente
	var head: Node3D = rig.P.get("Head")
	var fade_t := 0.0
	if head:
		var d := (want - head.global_position).length()
		fade_t = clampf((2.6 - d) / 1.4, 0, 1) * 0.75
		if comp_cur < 0.5 and cam_dist < 5:
			fade_t = maxf(fade_t, (0.5 - comp_cur) * 1.1)
		fade_t = maxf(fade_t, apretado_cur * 0.9)
	fade_cur += (fade_t - fade_cur) * minf(1, dt * 10)
	if fade_cur < 0.01:
		fade_cur = 0
	rig.set_fade(fade_cur)

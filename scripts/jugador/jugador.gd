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
const PAUSA_TRAS_CARRERA := 0.16
var _carrera_hasta := -9.0
var _apuntar_pedido := false
var _frenar_combate_hasta := -9.0
var _vel_giro_cuerpo := 0.0
var _shift_postura_previo := false
var _pedir_levantarse_carrera := false
var _levantarse_carrera_hasta := -9.0
var _tumbar_rapido_hasta := -9.0
var _vel_tumbar_rapido := Vector3.ZERO
var _salto_pedido := false
var _direccion_salto := Vector3.ZERO
var _salto_recto := false
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
var hud_danio: HudDanio
var _notif_inicio := false
var _vel_inercia := Vector3.ZERO # velocidad horizontal con inercia (ver humanoid_step)
var dist_suave := -1.0  # distancia deseada de la cámara, suavizada (ver update_camera)
# zoom de la cámara con la rueda del ratón (multiplica la distancia normal; apuntando no cambia)
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.6
const ZOOM_PASO := 0.1
var zoom_cam := 1.0
var apretado_cur := 0.0 # 0-1: sin sitio detrás de la cámara (espalda contra una pared)
var cam_fov := 70.0
var mira_tele := false # apuntando con la mira telescópica (francotirador)
var fade_cur := 0.0
var vaulting = null
var air_vel = null
var air_cap := 0.0
var fall_bias := 0.0
var getup_p := 0.0
var _sin_choque_motos: Array = [] # motos caídas con las que no choca mientras se levanta a su lado
var _getup_vel := 1.0 # (tras un ragdoll se levanta algo más deprisa que al salir de cuerpo a tierra)
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
var rest_cam := 0.0     # 0..1: cámara de arma apoyada (más cerca, el personaje a un lado, más zoom)
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
	"yaw": 0.0, "supine": false, "levanta_arriba": null, "rollSide": 1.0, "lean": 0.0, "vault": null, "jumpPrep": null,
	"knocked": false, "gettingUp": false, "hang": null, "restGap": null, "rested": false, "holster": null,
	"moto": null, "levanta": null,
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
	# el superviviente hecho en Blender (el Rig de la escena se construye con el muñeco clásico; se rehace aquí, antes
	# de que el animador lea sus piezas)
	rig.modelo = "superviviente"
	rig.construir()
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
	# los sonidos se cargan ya (si no, el primer disparo/golpe daba un tirón al prepararlos)
	Efectos.precargar()
	# en el ejecutable final no hay trucos de pruebas
	if not OS.is_debug_build():
		estamina_infinita = false


## ---------------------------------------------------------------- utilidades de física
var _consulta_rayo := PhysicsRayQueryParameters3D.new()
var _consulta_esfera := PhysicsShapeQueryParameters3D.new()
var _esferas_consulta: Dictionary[float, SphereShape3D] = {}


func raycast(desde: Vector3, dir: Vector3, excluir_extra: Array = []) -> Dictionary:
	var q := _consulta_rayo
	q.from = desde
	q.to = desde + dir
	q.collision_mask = 1
	var exclusiones := _excluir()
	exclusiones.append_array(excluir_extra)
	q.exclude = exclusiones
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	r["distance"] = desde.distance_to(r.position)
	return r


func _preparar_consulta_esfera(p: Vector3, radio: float, movimiento: Vector3) -> PhysicsShapeQueryParameters3D:
	var esfera := _esferas_consulta.get(radio) as SphereShape3D
	if esfera == null:
		esfera = SphereShape3D.new()
		esfera.radius = radio
		if _esferas_consulta.size() < 8:
			_esferas_consulta[radio] = esfera
	var q := _consulta_esfera
	q.shape = esfera
	q.transform = Transform3D(Basis.IDENTITY, p)
	q.motion = movimiento
	q.collision_mask = 1
	q.exclude = _excluir()
	return q


## ¿una esfera en ese punto toca el escenario?
func _esfera_choca(p: Vector3, radio: float) -> bool:
	var q := _preparar_consulta_esfera(p, radio, Vector3.ZERO)
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## workspace:Spherecast: devuelve la distancia recorrida hasta chocar (o -1 si no choca)
func spherecast(desde: Vector3, radio: float, dir: Vector3) -> float:
	var q := _preparar_consulta_esfera(desde, radio, dir)
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(q, 1).is_empty():
		return 0.0
	var res := space.cast_motion(q)
	if res[0] >= 1.0:
		return -1.0
	return res[0] * dir.length()


func root_cf() -> Transform3D:
	return global_transform


## lo que los rayos del jugador no ven: él mismo y la moto que conduce
func _excluir() -> Array:
	if moto != null and is_instance_valid(moto):
		return [get_rid(), moto.get_rid()]
	return [get_rid()]


## ---------------------------------------------------------------- HUD
func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var caja := VBoxContainer.new()
	caja.position = Vector2(24, 24)
	capa.add_child(caja)
	for k in ["vida", "estamina"]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		caja.add_child(fila)
		var fondo := ColorRect.new()
		fondo.custom_minimum_size = Vector2(260, 14)
		fondo.color = Color(0, 0, 0, 0.45)
		fila.add_child(fondo)
		var barra := ColorRect.new()
		barra.size = Vector2(260, 14)
		barra.color = Color8(170, 30, 30) if k == "vida" else Color8(220, 190, 80)
		fondo.add_child(barra)
		_hud[k] = barra
		# rótulo (y la vida en número)
		var rot := Label.new()
		rot.text = "VIDA" if k == "vida" else "ESTAMINA"
		rot.add_theme_font_size_override("font_size", 12)
		rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rot.custom_minimum_size = Vector2(0, 14)
		_contorno(rot, 4)
		rot.modulate = Color(1, 1, 1, 0.85)
		fila.add_child(rot)
		_hud[k + "_txt"] = rot
	var aviso := Label.new()
	aviso.add_theme_font_size_override("font_size", 22)
	aviso.anchor_left = 0.5
	aviso.anchor_right = 0.5
	aviso.anchor_top = 0.63  # (2026-10-27) más arriba: no pisa la barra de armas (abajo a la derecha)
	aviso.offset_left = -300
	aviso.offset_right = 300
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contorno(aviso, 6)
	capa.add_child(aviso)
	_hud["aviso"] = aviso
	var ayuda := Label.new()
	ayuda.text = "Tab: rueda de armas · I: inventario · Clic der: apuntar (arma de fuego) / guardia (arma blanca o sin arma) · Clic izq: disparar/golpear (sin arma: puñetazos) · Clic der + Espacio: bloquear (a tiempo: parada) · Clic der + doble Espacio: empujón · G: patada (en el suelo: pisotón) · R: recargar · X: apoyar arma · F: recoger / subir a la moto · Shift: correr (tumbado: levantarse y correr) · C: agacharse · Z: cuerpo a tierra (corriendo: rápido) · Espacio: saltar/sortear · Q/E: asomarse · V: hombro · H: esta ayuda · Rueda: acercar/alejar cámara · Colgado: A/D moverse (Shift: rápido), Espacio subir, S soltarse · Esc: pausa" + (" · F1: trucos · F4: estamina infinita · F5: balas infinitas · F6: ver ruido · F7: zombis sordos · F8: zombis ciegos" if OS.is_debug_build() else "")
	# ayuda de controles: oculta (H la muestra/oculta), en un recuadro que no se sale de la pantalla
	ayuda.add_theme_font_size_override("font_size", 15)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.anchor_right = 0.62
	ayuda.offset_top = -170
	ayuda.offset_bottom = -24
	ayuda.offset_left = 24
	ayuda.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var sb_ay := StyleBoxFlat.new()
	sb_ay.bg_color = Color(0, 0, 0, 0.55)
	sb_ay.set_corner_radius_all(6)
	sb_ay.set_content_margin_all(10)
	ayuda.add_theme_stylebox_override("normal", sb_ay)
	ayuda.visible = false
	capa.add_child(ayuda)
	_hud["ayuda"] = ayuda
	_hud["ayuda_pie"] = ayuda.text
	# velocímetro de la moto (abajo a la izquierda; solo en la moto)
	var velo := Label.new()
	velo.add_theme_font_size_override("font_size", 40)
	velo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	velo.add_theme_constant_override("outline_size", 6)
	velo.anchor_left = 0.0
	velo.anchor_right = 0.0
	velo.anchor_top = 1.0
	velo.anchor_bottom = 1.0
	velo.offset_left = 28
	velo.offset_right = 290
	velo.offset_top = -150
	velo.offset_bottom = -44
	velo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	velo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	velo.visible = false
	capa.add_child(velo)
	_hud["velo"] = velo
	# daño (viñeta, de dónde te pegan) y pantalla de muerte
	hud_danio = HudDanio.new()
	add_child(hud_danio)
	Arsenal._ignorar_raton(capa)
	Arsenal._ignorar_raton(hud_danio)
	_notif_inicio = true


## contorno negro para que un texto se lea sobre cualquier fondo (suelo claro, cielo, paredes blancas)
static func _contorno(l: Label, px := 5) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)


func notify(txt: String) -> void:
	_hud["aviso"].text = txt
	_notif_hasta = ahora() + 2.5


func _update_hud() -> void:
	if _notif_inicio and reloj > 0.5:
		_notif_inicio = false
		notify("H: ver los controles")
	_hud["vida"].size.x = 260.0 * clampf(health / max_health, 0, 1)
	_hud["vida_txt"].text = "VIDA %d" % ceili(health)
	if hud_danio and camara.is_inside_tree():
		hud_danio.actualizar(get_process_delta_time(), health / max_health, camara.global_rotation.y, health <= 0.0,
			MUERTE_REINICIO - (reloj - _muerte_t))
	_hud["estamina"].size.x = 260.0 * stamina / C.PLAYER.StaminaMax
	_hud["estamina"].color = Color8(150, 90, 40) if exhausted else Color8(220, 190, 80)
	if ahora() > _notif_hasta:
		_hud["aviso"].text = ""
	# en la moto: velocidad (km/h: 1 stud = 0.31 m), marcha y ayuda de los mandos
	var velo: Label = _hud["velo"]
	velo.visible = moto != null
	if moto != null:
		var kmh := absf(moto.velocidad()) * C.STUD * 3.6
		var m_txt := "R" if moto.velocidad() < -0.5 else str(moto.marcha)
		velo.text = "%d km/h\n%sª%s" % [roundi(kmh), m_txt, " · luces" if moto.luces else ""]
		_hud["ayuda"].text = "W: gas · S: freno / marcha atrás · A/D: girar · Espacio: freno de mano (derrapar) · En el aire: Shift/Ctrl inclinarse · Clic der: apuntar · Clic izq: disparar/golpear · Tab: rueda de armas de una mano · F: bajarse (en marcha, saltar) · L: luces · V: hombro · H: esta ayuda · Esc: pausa"
	else:
		_hud["ayuda"].text = _hud["ayuda_pie"]


## ---------------------------------------------------------------- entrada
## el ratón de la cámara se lee antes que la interfaz (si no, cualquier elemento del HUD que quede
## bajo el puntero capturado, como la mira en el centro, se tragaba el movimiento)
func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := (0.0017 if aiming else 0.0032) * Opciones.sensibilidad
		# con la mira telescópica, el ratón va mucho más fino (proporcional al aumento)
		if mira_tele:
			sens *= cam_fov / 62.0
		var rel: Vector2 = e.relative
		if Opciones.invertir_y:
			rel.y = -rel.y
		_mouse_delta += rel * sens


func _unhandled_input(e: InputEvent) -> void:
	if arsenal.interfaz.abierto() or not arsenal.cambio_mochila.is_empty():
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			_apuntar_pedido = e.pressed
			if e.pressed and L.sprinting:
				_carrera_hasta = ahora() + PAUSA_TRAS_CARRERA
			aiming = e.pressed and ahora() >= _carrera_hasta
		elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# rueda: acercar / alejar la cámara (no cambia la distancia al apuntar)
			var paso := -ZOOM_PASO if e.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_PASO
			zoom_cam = clampf(zoom_cam + paso, ZOOM_MIN, ZOOM_MAX)
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not free_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and not e.echo:
		var k: int = e.physical_keycode
		if e.pressed and moto != null:
			# en la moto: F bajar, L luces, V hombro de la cámara (el resto lo lleva _paso_moto)
			match k:
				KEY_F:
					bajar_moto()
				KEY_L:
					moto.luces = not moto.luces
				KEY_H:
					_hud["ayuda"].visible = not _hud["ayuda"].visible
				KEY_V:
					side = -side
				KEY_ALT:
					free_mouse = true
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
		if e.pressed:
			match k:
				KEY_F:
					# subir a una moto cercana (o levantarla si está tirada); si no, F es recoger (Arsenal)
					var mc := moto_cercana()
					if mc != null and levantando_moto == null:
						if mc.caida:
							levantar_moto(mc)
						else:
							_pedir_montar(mc)
				KEY_C, KEY_CTRL:
					if colgado != null:
						soltar_cornisa()
					else:
						set_stance(0 if stance == 1 else 1)
				KEY_Z:
					set_stance(1 if stance == 2 else 2)
				KEY_SPACE:
					# agachado/tumbado sube un nivel; de pie salta o sortea el obstáculo de delante;
					# colgado de una cornisa, sube. Con el clic derecho mantenido: bloquear (y doble = empujón; Arsenal)
					if colgado == null and arsenal.cc_quiere_espacio():
						arsenal.cc_espacio(true)
					elif colgado != null:
						trepar_cornisa()
					elif stance > 0:
						set_stance(stance - 1)
					else:
						jump_or_vault()
				KEY_V:
					side = -side
				KEY_H:
					_hud["ayuda"].visible = not _hud["ayuda"].visible
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
			elif k == KEY_SPACE:
				arsenal.cc_espacio(false)

var _mouse_delta := Vector2.ZERO


func _leer_movimiento() -> Vector3:
	if arsenal != null and arsenal.interfaz != null and (arsenal.interfaz.abierto() or not arsenal.cambio_mochila.is_empty()):
		return Vector3.ZERO
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
	# levantarse estando BOCA ARRIBA (2026-11-02): ya no rueda a boca abajo para levantarse (se veía girar el cuerpo
	# de forma extraña); se sienta, mete los pies y se levanta hacia donde tiene los pies. Para eso el cuerpo gira
	# 180° y avanza hasta los pies (el Animador lo compensa en el primer fotograma: no se ve ningún salto)
	L.levanta_arriba = null
	if stance == 2 and n < 2 and supine and prone_p > 0.98:
		var desp := 1.3
		var adelante := -Rbx.look(root_cf())   # boca arriba, los pies quedan detrás del cuerpo
		var bajo := global_position - Vector3(0, center_cur - 0.35, 0)
		var hit := raycast(bajo, adelante * (desp + 0.6))
		if not hit.is_empty():
			desp = clampf(bajo.distance_to(hit.position) - 0.7, 0.0, desp)
		rotation.y += PI
		global_position += adelante * desp
		L.levanta_arriba = {"desp": desp, "t0": ahora()}
		supine = false
	if n != 2:
		_tumbar_rapido_hasta = -9.0
	if n == 2 and stance == 0 and en_suelo and L.sprinting and moto == null and ragdoll == null:
		_tumbar_rapido_hasta = ahora() + 0.45
		_vel_tumbar_rapido = Rbx.flat(vel_real).limit_length(C.PLAYER.SprintSpeed)
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
	# 1) cara del obstáculo delante (a la altura de la rodilla o de la cintura; y más arriba, hasta la cabeza, para un
	# muro con hueco debajo como el techo de un túnel o un dintel: antes los rayos pasaban por el hueco y no se veía; 2026-11-08)
	var face := {}
	for hgt in [0.9, 1.9, 2.9, 3.9, 4.8]:
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


## Interpolación de Hermite. Las tangentes se expresan en distancia por tramo.
static func _tramo_vault(origen: Vector3, destino: Vector3, entrada: Vector3, salida: Vector3, t: float) -> Vector3:
	return origen.bezier_interpolate(origen + entrada / 3.0, destino - salida / 3.0, destino, t)


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
		var over: Vector3 = e + d * (v.depth * 0.42)
		v.pMid = Vector3(over.x, maxf(v.topY + 1.58, p0.y + 0.42), over.z)
		var land: Vector3 = e + d * (v.depth + 1.4)
		v.p1 = Vector3(land.x, v.landY + Cst, land.z)
		# arranque: primero se acerca al borde (sin subir), luego el arco por encima
		v.pre = Vector3(e.x, p0.y, e.z) - d * 0.9
		v.k = 0.25 if face_dist > 1.2 else 0.0
		var inicio_arco: Vector3 = v.pre if v.k > 0.0 else p0
		var medio: Vector3 = v.pMid
		var fin: Vector3 = v.p1
		var medio_t: float = (1.0 - v.k) * v.dur * 0.5
		var subida := maxf(0.0, (medio - inicio_arco).dot(d)) / medio_t
		var bajada := maxf(0.0, (fin - medio).dot(d)) / medio_t
		var entrada_max := subida
		if v.k > 0.0:
			entrada_max = maxf(0.0, (inicio_arco - p0).dot(d)) / (v.k * v.dur)
		v.vel_entrada = d * minf(hs, entrada_max * 2.0)
		v.vel_arco = d * minf(entrada_max, subida) if v.k > 0.0 else v.vel_entrada
		v.vel_medio = d * minf(subida, bajada)
		v.exitVel = d * minf(maxf(hs, 5.5), bajada * 2.0)
	else:
		v.dur = 0.85 + v.h * 0.14
		v.hang = Vector3(e.x, 0, e.z) - d * 0.75
		v.pullY = v.topY - Cst * 0.15
		# agarrado en el aire (más alto que la posición de colgar): no baja para volver a subir
		v.pullY = maxf(v.pullY, minf(p0.y - 0.15, v.topY + Cst * 0.4))
		var p_top: Vector3 = e + d * 1.05
		v.pEnd = Vector3(p_top.x, v.topY + Cst, p_top.z)
		v.exitVel = Vector3.ZERO
		# velocidad con la que llega a la pared (a lo largo de d): el acercamiento parte de ella y frena hasta pegarse
		var dist_h := maxf(0.05, (v.hang - Vector3(p0.x, 0, p0.z)).dot(d))
		v.v0 = maxf(Vector3(vel_real.x, 0, vel_real.z).dot(d), 0.0)
		v.dist0 = dist_h
	v.p0 = p0
	v.yaw_inicial = rotation.y
	# (empieza ya en este fotograma: si no, el cuerpo se quedaba quieto un fotograma justo al empezar)
	v.t0 = ahora() - get_physics_process_delta_time()
	v.prev = p0
	Ruido.emitir(self, e, C.RUIDO.Sortear if v.kind == "vault" else C.RUIDO.Encaramarse, Ruido.SORTEAR, self)
	# encaramarse a algo alto (2026-11-02): se guarda el arma para subir con las dos manos y al terminar se vuelve a sacar
	if v.kind != "vault":
		arsenal.guardar_para_trepar()
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
			var segundos: float = k * v.dur
			return _tramo_vault(p0, v.pre, v.vel_entrada * segundos, v.vel_arco * segundos, t / k)
		var u := (t - k) / (1.0 - k)
		var medio_t: float = (1.0 - k) * v.dur * 0.5
		if u < 0.5:
			return _tramo_vault(v.pre if k > 0.0 else p0, v.pMid, v.vel_arco * medio_t, v.vel_medio * medio_t, u * 2.0)
		return _tramo_vault(v.pMid, v.p1, v.vel_medio * medio_t, v.exitVel * medio_t, u * 2.0 - 1.0)
	var s_a := clampf(t / 0.3, 0.0, 1.0)  # pegarse a la pared (más largo que antes: sin tirón hacia ella)
	var b := smooth01((t - 0.12) / 0.5) # tirar hacia arriba
	var c := smooth01((t - 0.55) / 0.4) # subir el cuerpo encima
	var p_end: Vector3 = v.pEnd
	# (2026-11-03) el acercamiento empieza con la velocidad que traía y frena hasta pegarse, sin pasarse (muelle
	# críticamente amortiguado): antes se paraba en seco y luego daba un tirón hacia la pared
	var p0h := Vector3(p0.x, 0, p0.z)
	var dv: Vector3 = v.dir
	var hang_v: Vector3 = v.hang
	var dist0: float = float(v.get("dist0", (hang_v - p0h).dot(dv)))
	var v0: float = float(v.get("v0", 0.0))
	var tau := t * float(v.dur)
	var kk := maxf(6.0, v0 / maxf(dist0, 0.05))   # (6/s: parado o andando despacio se acerca sin tirón)
	var err := (-dist0 + (v0 - kk * dist0) * tau) * exp(-kk * tau)
	var lat0 := p0h - dv * p0h.dot(dv)
	var lat1 := hang_v - dv * hang_v.dot(dv)
	var xz_a := lat0.lerp(lat1, smooth01(s_a)) + dv * (hang_v.dot(dv) + err)
	var xz := xz_a.lerp(Vector3(p_end.x, 0, p_end.z), c)
	var pull_y: float = v.pullY
	var y := p0.y + (pull_y - p0.y) * b
	y += (p_end.y - y) * c
	return Vector3(xz.x, y, xz.z)


func step_vault(dt: float) -> void:
	var v: Dictionary = vaulting
	var t: float = (ahora() - v.t0) / v.dur
	var pos := _vault_path(v, minf(t, 1))
	global_position = pos
	var rumbo := Rbx.yaw_of(Rbx.look_at(pos, pos + v.dir))
	rotation.y = lerp_angle(float(v.yaw_inicial), rumbo, smooth01(t / 0.24))
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
		_vel_inercia = Rbx.flat(v.exitVel)
		_set_estado("Freefall" if v.kind == "vault" else "Running")
		cur_move = (v.exitVel as Vector3).length()
		if v.kind != "vault":
			arsenal.sacar_tras_trepar()


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
	_direccion_salto = Rbx.flat(Rbx.look(root_cf())).normalized() if _leer_movimiento().length() > 0.1 else Vector3.ZERO
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
	# las manos hacen falta: se guarda el arma (y se vuelve a sacar al subir o al soltarse)
	arsenal.recordar_para_trepar()
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
	arsenal.sacar_tras_trepar()
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
func _physics_process(dt: float) -> void:
	reloj += dt
	if ragdoll != null:
		arsenal.cancelar_mochila()
		# en el suelo / por los aires: el cuerpo lo lleva la física (Ragdoll); el jugador solo lo sigue
		_paso_ragdoll(dt)
		_paso_salud(dt)
		return
	if moto != null:
		_paso_moto(dt)
		if moto != null:
			arsenal.actualizar(dt)
			_paso_salud(dt)
			return
	move_direction = _leer_movimiento() if health > 0 else Vector3.ZERO
	if levantando_moto != null:
		_paso_levantar()
	_aproximar_escalada()
	arsenal.dirigir()
	update_character(dt)
	if levantando_moto != null:
		rotation.y = lerp_angle(float(levantando_moto.desde), float(levantando_moto.giro), Rbx.smooth((reloj - float(levantando_moto.t0)) / LEVANTAR_AGARRE))
	arsenal.actualizar(dt)
	humanoid_step(dt)
	_paso_salud(dt)


func _process(dt: float) -> void:
	update_camera(minf(dt, 0.1))
	_update_hud()


## ---------------------------------------------------------------- teletransporte (menú de trucos)
var invencible := false # truco: no recibe daño


## pone al jugador de pie en "pies" (studs) mirando hacia "giro"; suelta la cornisa o el salto en curso
func teletransportar(pies: Vector3, giro: float) -> void:
	_cancelar_levantar_moto()
	if ragdoll != null:
		ragdoll.terminar(0.0)
		ragdoll = null
		L.knocked = false
		collision_layer = 1
		collision_mask = 1 | 4
	if moto != null:
		bajar_moto(true)
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
	# bloqueando de frente (Arsenal.cc_bloquear): pasa solo una parte; parado a tiempo, nada
	var parte := arsenal.cc_bloquear(cantidad, desde) if arsenal != null else 1.0
	if desde != Vector3.ZERO and is_equal_approx(parte, 1.0):
		Efectos.sonido(self, "Punch", global_position + Vector3.UP, 0.9)
	var bloqueado := parte < 1.0
	if parte <= 0.0:
		var an0 := get_node_or_null("Animador") as Animador
		if an0 and not an0.S.is_empty():
			(an0.S.hitPitch as Rbx.Muelle).impulse(-1.5)
		return
	cantidad *= parte
	health = maxf(0.0, health - cantidad)
	_danio_t = reloj
	shake = minf(1.0, shake + 0.45)
	if hud_danio:
		var origen = null
		if desde != Vector3.ZERO and Rbx.flat(desde - global_position).length() > 0.6:
			origen = desde
		hud_danio.golpe(cantidad, global_position, origen)
	var dir := Rbx.flat(global_position - desde)
	if dir.length() > 0.01:
		empuje += dir.normalized() * 6.0
		_golpe_dir = dir.normalized()
	if ragdoll != null and dir.length() > 0.01:
		# ya en el suelo: el golpe sacude el cuerpo
		ragdoll.golpe("UpperTorso", dir.normalized() * minf(cantidad * 0.3, 8.0) + Vector3(0, 1, 0))
	elif health > 0.0 and moto == null and ragdoll == null and cantidad >= 15.0 and reloj - _ragdoll_t > DERRIBO_ESPERA \
			and colgado == null and vaulting == null and not bloqueado:
		# un golpe fuerte puede tirarte al suelo (más fácil si ya estás muy herido)
		var prob := 0.12 + (0.3 if health < max_health * 0.35 else 0.0) + clampf((cantidad - 25.0) / 40.0, 0.0, 0.5)
		if randf() < prob:
			var dd := dir.normalized() if dir.length() > 0.01 else -Rbx.look(root_cf())
			ragdoll_iniciar(vel_real, {"comportamiento": "caer", "impulso": dd * (8.0 + cantidad * 0.15) + Vector3(0, 2.5, 0),
				"pieza": "UpperTorso", "duracion": 1.4})
	# el cuerpo encaja el golpe (muelles de impacto del animador)
	var an := get_node_or_null("Animador") as Animador
	if an and not an.S.is_empty():
		(an.S.hitPitch as Rbx.Muelle).impulse(-4.0)
		(an.S.hitHead as Rbx.Muelle).impulse(-5.0)
	if health <= 0.0:
		_morir()


func _morir() -> void:
	_muerte_t = reloj
	if moto != null:
		expulsar_moto(moto.vel_h * 0.6 + Vector3(0, 4, 0), 0.0, "muerte")
	_cancelar_levantar_moto()
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
	# muere con el ragdoll activo: se agarra la herida, le fallan las piernas, cae y se apaga
	if ragdoll != null:
		ragdoll.morir()
	else:
		ragdoll_iniciar(vel_real, {"comportamiento": "morir", "vivo": false, "duracion": -1.0,
			"impulso": _golpe_dir * 9.0 + Vector3(0, 2, 0), "pieza": "UpperTorso"})
	# (la pantalla de muerte la pone HudDanio)


## regenera vida si lleva un rato sin recibir daño (ZConfig.PLAYER.RegenDelay / RegenRate); muerto,
## el cuerpo cae y el nivel se reinicia
func _paso_salud(dt: float) -> void:
	if health > 0.0:
		if health < max_health and reloj - _danio_t > C.PLAYER.RegenDelay:
			health = minf(max_health, health + C.PLAYER.RegenRate * dt)
		return
	# (el cuerpo cae con el ragdoll; ver _morir)
	if reloj - _muerte_t > MUERTE_REINICIO and get_tree().current_scene and not _reiniciando:
		_reiniciando = true
		get_tree().reload_current_scene()


## Giro con aceleración y frenada, sin saltos al cambiar de dirección.
func _girar_cuerpo_hacia(destino: float, dt: float, rapidez: float) -> void:
	var error := Rbx.wrap_a(destino - rotation.y)
	var objetivo := clampf(error * rapidez, -deg_to_rad(300), deg_to_rad(300))
	_vel_giro_cuerpo = move_toward(_vel_giro_cuerpo, objetivo, deg_to_rad(1200) * dt)
	var paso := _vel_giro_cuerpo * dt
	if paso * error > 0.0 and absf(paso) > absf(error):
		paso = error
		_vel_giro_cuerpo = 0.0
	rotation.y += paso


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

	# Una pulsación nueva de Shift levanta; mantenerlo al tirarse no cancela la caída.
	var shift_postura := Input.is_physical_key_pressed(KEY_SHIFT)
	if shift_postura and not _shift_postura_previo and stance == 2:
		_pedir_levantarse_carrera = true
	_shift_postura_previo = shift_postura
	if not shift_postura:
		_pedir_levantarse_carrera = false
	if _pedir_levantarse_carrera and move_direction.length() > 0.1 and stance == 2 and en_suelo and not L.knocked and not L.gettingUp and ragdoll == null and colgado == null and vaulting == null and levantando_moto == null and arsenal.recogiendo == null:
		if (prone_p <= 0.001 or prone_p >= 0.999) and headroom(5.6):
			var desde_arriba := supine
			set_stance(0)
			if stance == 0:
				_levantarse_carrera_hasta = ahora() + (C.PLAYER.ProneTime if desde_arriba else 0.65)
				_pedir_levantarse_carrera = false
	# estamina y velocidad
	var moving := move_direction.length() > 0.1
	if _apuntar_pedido:
		aiming = ahora() >= _carrera_hasta and (arsenal.cfg().get("Kind", "") == "Gun" or Rbx.flat(vel_real).length() <= C.PLAYER.WalkSpeed * 1.1)
	var want_sprint: bool = Input.is_physical_key_pressed(KEY_SHIFT) and moving and not aiming and not _apuntar_pedido and ahora() >= _frenar_combate_hasta and (not firing or arsenal.cfg().get("Slot", "") == "Corta")
	if arsenal.cc.accion != null and arsenal.cc.accion.tipo in ["patada", "pisoton"]:
		want_sprint = false
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
	if sprinting:
		_carrera_hasta = ahora() + PAUSA_TRAS_CARRERA
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
		# bloqueando o en plena patada / empujón: casi sin moverse (combate cuerpo a cuerpo, Arsenal.cc)
		if arsenal.cc.bloqueo:
			speed *= 0.55
		elif arsenal.cc.accion != null:
			speed *= 0.3
	if sprinting:
		# de frente a tope; de lado ~60 %; hacia atrás ~50 %
		speed *= 0.6 + 0.4 * pow(fwd_k, 1.5) - 0.1 * back_k
		# Pasos tácticos laterales/atrás: no arrastrar la marcha a velocidad de carrera frontal.
		if stance == 0:
			speed = minf(speed, lerpf(C.PLAYER.WalkSpeed * (1.3 - 0.1 * back_k), C.PLAYER.SprintSpeed, pow(fwd_k, 2.0)))
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
	# (2026-11-03) en una escalera se pisa un escalón por paso (corriendo, dos): como mucho ~3,4 pasos por segundo
	# andando y ~4 corriendo (si no, las piernas tendrían que ir a toda velocidad o saltarse escalones)
	var an_esc := get_node_or_null("Animador") as Animador
	if an_esc != null and an_esc.esc_fondo > 0.0 and en_suelo and stance != 2:
		speed = minf(speed, an_esc.esc_fondo * (8.0 if sprinting else 3.4))

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
	getup_p = maxf(0.0, getup_p - dt / C.PLAYER.ProneTime * 1.15 * _getup_vel)
	if getup_p <= 0.0:
		_getup_vel = 1.0
		if not _sin_choque_motos.is_empty() and reloj - _ragdoll_t > 1.0:
			for fis in _sin_choque_motos:
				if is_instance_valid(fis) and not _esfera_choca_con(fis, global_position, 1.2):
					remove_collision_exception_with(fis)
			_sin_choque_motos = _sin_choque_motos.filter(func(f): return is_instance_valid(f) and f in get_collision_exceptions())
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
		if not _salto_recto:
			air_vel += move_direction * C.WORLD.AirControl * dt
		if (air_vel as Vector3).length() > air_cap:
			air_vel = (air_vel as Vector3).normalized() * air_cap
		walk_speed = (air_vel as Vector3).length()
		_move_override = (air_vel as Vector3).normalized() if walk_speed > 0.05 else Vector3.ZERO
	else:
		_salto_recto = false
		air_vel = null
		_move_override = null
	# Z durante carrera: caída rápida y deslizamiento frenado, resuelto por move_and_slide.
	var tumbar_rapido: bool = stance == 2 and ahora() < _tumbar_rapido_hasta and en_suelo and not L.knocked and vaulting == null and ragdoll == null
	if tumbar_rapido:
		var avance_t := clampf(1.0 - (_tumbar_rapido_hasta - ahora()) / 0.45, 0.0, 1.0)
		walk_speed = _vel_tumbar_rapido.length() * (1.0 - smoothstep(0.0, 1.0, avance_t))
		_move_override = _vel_tumbar_rapido.normalized()
		jump_height = 0.0
	# Dar los primeros pasos al terminar de incorporarse, antes de acelerar a carrera.
	if stance == 0 and ahora() < _levantarse_carrera_hasta and prone_p < 0.3 and getup_p <= 0.0 and en_suelo:
		walk_speed = C.PLAYER.WalkSpeed * (1.0 - smoothstep(0.0, 0.3, prone_p))
		cur_move = walk_speed
		_move_override = move_direction
	# altura del cuerpo según la postura. Tumbarse avanza a ritmo constante (fases de la animación)
	var p_t := 1.0 if stance == 2 else 0.0
	var tiempo_tumbar: float = 0.4 if tumbar_rapido else C.PLAYER.ProneTime
	if stance == 0 and ahora() < _levantarse_carrera_hasta and L.levanta_arriba == null:
		tiempo_tumbar = 0.6
	prone_p = prone_p + clampf(p_t - prone_p, -dt / tiempo_tumbar, dt / tiempo_tumbar)
	var base_c: float = C.STANCE[1 if stance == 2 else stance].Center
	non_prone_c = Rbx.damp(non_prone_c, base_c, 3.5, dt)
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
		elif not sprinting and (aiming or arsenal.armado()):
			# con arma o apuntando, el cuerpo sigue a la mira con algo de peso
			var yaw_apuntado := yaw
			if aiming and arsenal.cfg().get("Kind", "") == "Gun":
				var punto_cerca := arsenal.punto_mira()
				var hacia_cerca := Rbx.flat(punto_cerca - global_position)
				if hacia_cerca.length() > 0.3 and hacia_cerca.length() < 10.0:
					var giro_cerca := atan2(-hacia_cerca.x, -hacia_cerca.z)
					yaw_apuntado += Rbx.wrap_a(giro_cerca - yaw) * (1.0 - smoothstep(6.0, 10.0, hacia_cerca.length()))
			var diff2 := Rbx.wrap_a(yaw_apuntado - cy)
			var margen := deg_to_rad(4.0) if arsenal.cfg().get("Slot", "") == "Larga" and (aiming or firing) else 0.0
			_girar_cuerpo_hacia(yaw_apuntado - signf(diff2) * minf(absf(diff2), margen), dt, 6.0)
		else:
			# sin arma o corriendo: el cuerpo sigue el movimiento; los pies tienen tiempo de dar
			# sus pasos y las piernas no se cruzan al machacar WASD
			var md := move_direction
			if md.length() > 0.1 and getup_p <= 0:
				var ty := atan2(-md.x, -md.z)
				_girar_cuerpo_hacia(ty, dt, 10.0)

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
	L.yaw = rotation.y if sprinting and not firing else yaw
	L.supine = supine
	if L.levanta_arriba != null and (stance == 2 or prone_p <= 0.001):
		L.levanta_arriba = null
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
	var want: Shape3D = _capsula
	if prone_shape:
		want = _caja_tumbado
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
		# (2026-11-03) la inercia sigue a la velocidad real mientras se sortea o se trepa: antes se quedaba con la
		# de antes de trepar y, al terminar, el personaje salía disparado hacia delante (y la cámara con él)
		_vel_inercia = Rbx.flat(vel_real)
		return
	var g: float = C.WORLD.Gravity
	var v := velocity
	var mov: Vector3 = move_direction if _move_override == null else _move_override
	var horiz := mov * walk_speed
	# INERCIA en el suelo (2026-10-27): al soltar las teclas se frena en uno o dos pasos (antes se paraba en seco,
	# también corriendo) y al cambiar de sentido se pasa por cero en vez de girar al instante
	if estado == "Running" and _move_override == null and vaulting == null and colgado == null:
		var obj := Vector3(horiz.x, 0, horiz.z)
		var a: float = 60.0
		if obj.length() < 0.05:
			a = C.PLAYER.Frenada
		elif obj.dot(_vel_inercia) < 0.0 or obj.length() < _vel_inercia.length() - 0.5:
			a = C.PLAYER.Frenada * 1.4
		_vel_inercia = _vel_inercia.move_toward(obj, a * dt)
		horiz = Vector3(_vel_inercia.x, horiz.y, _vel_inercia.z)
	else:
		_vel_inercia = Rbx.flat(vel_real)
	var horiz_pedido := Rbx.flat(horiz)
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
		_aire_t += dt
		if _caida_ragdoll(v):
			return
		if estado == "Jumping" and v.y < 0:
			_set_estado("Freefall")
		if v.y <= 0:
			var gnd2 := _sondear_suelo(center_cur + maxf(0.2, -v.y * dt))
			if not gnd2.is_empty() and pos.y - gnd2.position.y <= center_cur + 0.05:
				# aterrizaje: cuanto más fuerte el golpe, más lejos se oye
				Ruido.emitir(self, gnd2.position, Ruido.radio_aterrizaje(-v.y), Ruido.ATERRIZAJE, self)
				var golpe_pies := -v.y
				if golpe_pies > 9.0:
					Efectos.sonido(self, "Land", gnd2.position, clampf(golpe_pies / 30.0, 0.3, 1.2), 1.0)
				_set_estado("Landed")
				_set_estado("Running")
				en_suelo = true
				v.y = 0
				_aterrizaje_fuerte(golpe_pies)
	if estado != "Jumping" and estado != "Freefall":
		_aire_t = 0.0
	if _salto_pedido:
		_salto_pedido = false
		if en_suelo and jump_height > 0:
			v.y = sqrt(2.0 * g * jump_height)
			en_suelo = false
			# Conserva el rumbo del cuerpo al pulsar Espacio, aunque se mueva la cámara.
			_salto_recto = true
			if _direccion_salto.length_squared() > 0.1:
				var t_aire := 2.0 * v.y / g
				var hs: float = C.PLAYER.JumpDistance / t_aire
				horiz = _direccion_salto * hs
				air_vel = horiz
				air_cap = hs
			else:
				horiz = Vector3.ZERO
				air_vel = Vector3.ZERO
				air_cap = 0.0
			stamina = maxf(0, stamina - C.PLAYER.JumpCost)
			_set_estado("Jumping")
	velocity = Vector3(horiz.x, v.y, horiz.z)
	move_and_slide()
	# contra una pared la inercia no se acumula (no sale disparado al dejar de tocarla)
	if estado == "Running" and horiz_pedido.length() > 0.5:
		var real_h := Rbx.flat(get_real_velocity())
		var k_real := real_h.length() / horiz_pedido.length()
		if k_real < 0.85:
			_vel_inercia *= maxf(k_real, 0.0)
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
const REST_CAM_DIST := 3.4          # arma apoyada: distancia de la cámara (de pie o agachado)
const REST_CAM_DIST_TUMBADO := 3.0
const REST_CAM_HOMBRO := 3.1        # hacia el lado (el personaje queda a un lado de la pantalla)
const REST_CAM_FOV := 50.0          # zoom (con el campo de visión de las opciones en 70)
func update_camera(dt: float) -> void:
	var now_t := ahora()
	var alive := health > 0
	if _mouse_delta.length() > 0.0005:
		_moto_raton_t = now_t
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
			# apoyada de lado contra una pared se puede subir y bajar bastante más
			pitch = clampf(pitch, -0.5, 0.6) if ra.get("lado", false) else clampf(pitch, -0.06, 0.3)
	_mouse_delta = Vector2.ZERO
	# en la moto: si no tocas el ratón, la cámara vuelve sola detrás de la moto (como en un vehículo)
	var en_moto := moto != null
	var v_moto := absf(moto.velocidad()) if en_moto else 0.0
	if en_moto and alive and not aiming and not firing and now_t - _moto_raton_t > 0.9 and v_moto > 0.5:
		# (entra poco a poco con la velocidad: sin saltos al arrancar o casi parado)
		var k_c := (1.0 - exp(-dt * clampf(v_moto / 8.0, 1.6, 3.2))) * clampf((v_moto - 0.5) / 4.0, 0.0, 1.0)
		yaw = yaw + Rbx.wrap_a(moto.rumbo - yaw) * k_c
		pitch = Rbx.damp(pitch, -0.2, 1.5, dt)

	# el hombro se desplaza de un lado a otro (no se teletransporta); al asomarse, la cámara
	# pasa automáticamente al lado del ladeo
	var want_side := side
	if en_moto and not aiming:
		want_side = 0.0 # en la moto la cámara va centrada detrás (al apuntar, al hombro)
	elif en_moto and arsenal.anim != null and arsenal.anim.moto_fuego:
		# apuntando desde la moto: la cámara va al hombro del brazo que dispara (apuntando hacia atrás con la
		# derecha, ese brazo queda a la izquierda de la pantalla: si no, el cuerpo tapaba el arma)
		want_side = arsenal.anim.lado_camara_moto(Rbx.wrap_a(yaw - moto.rumbo))
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
	var sprinting: bool = walk_speed > C.PLAYER.WalkSpeed + 1 and vel_h > C.PLAYER.WalkSpeed + 1 and not en_moto
	var dist := 5.2 if aiming else (9.5 if sprinting else 8.5)
	if en_moto:
		# más lejos y más campo de visión cuanto más deprisa (sensación de velocidad)
		dist = 6.0 if aiming else 8.5 + clampf(v_moto / 72.0, 0.0, 1.0) * 2.5
	if stance == 2:
		dist = 4.4 if aiming else 7.5
	if not aiming:
		dist *= zoom_cam
	# ARMA APOYADA (2026-11-03, a pedido de KangooG): la cámara se acerca con zoom y deja al personaje a un lado,
	# para apuntar con calma (la mira se hace más pequeña: Arsenal)
	rest_cam = Rbx.damp(rest_cam, 1.0 if (arsenal.rest != null and alive and not en_moto) else 0.0, 6.0, dt)
	if rest_cam > 0.001:
		dist = lerpf(dist, REST_CAM_DIST_TUMBADO if stance == 2 else REST_CAM_DIST, rest_cam)
	var fov := (62.0 if aiming else (76.0 if sprinting else 70.0)) + (Opciones.fov - 70.0)
	if rest_cam > 0.001:
		fov = lerpf(fov, REST_CAM_FOV + (Opciones.fov - 70.0), rest_cam)
	if en_moto and not aiming:
		fov += clampf((v_moto - 15.0) / 55.0, 0.0, 1.0) * 14.0
	# mira telescópica (francotirador): aumento y el personaje no tapa la vista
	var wcfg: Dictionary = arsenal.cfg()
	mira_tele = aiming and wcfg.has("Scope") and arsenal.recargando <= 0.0 and arsenal.switching == null \
		and arsenal.ahora() >= arsenal.draw_until and health > 0
	if mira_tele:
		fov = float(wcfg.Scope)
	# apuntando, la cámara va más al hombro: el personaje tapa menos pantalla
	var shoulder := (2.6 if aiming else 2.4) * side_cur
	var height := 0.55 if aiming else 0.4
	# cuerpo a tierra: la cámara se pone más alta y hacia la cabeza, para ver por encima del cuerpo (antes las
	# piernas, estiradas hacia la cámara, tapaban media pantalla)
	var k_tumb := smooth01(prone_p) if not supine else 0.0
	if k_tumb > 0.0 and not en_moto:
		height = lerpf(height, 0.75 if aiming else 1.7, k_tumb)
		pivot += Rbx.look(Rbx.ang(0, yaw, 0)) * (1.2 if not aiming else 0.6) * k_tumb
	if en_moto:
		height = 0.95 if aiming else 1.3
		if aiming:
			shoulder = 2.7 * side_cur # más hacia el hombro: el cuerpo inclinado tapa menos
	if absf(lean_cur) > 0.05:
		shoulder *= 1 - absf(lean_cur) * 0.35
	if rest_cam > 0.001:
		shoulder = lerpf(shoulder, REST_CAM_HOMBRO * side_cur, rest_cam)
		height = lerpf(height, 0.45 if stance != 2 else 0.7, rest_cam)

	# seguimiento con peso: el punto que sigue la cámara va un pelín por detrás del personaje
	if cam_pivot == null or (cam_pivot - pivot).length() > 15:
		cam_pivot = pivot
	var kH := 15.0 if not en_moto else 22.0
	# sorteando o trepando, la cámara sigue con más calma (el cuerpo frena de golpe contra la pared y sube: la cámara
	# no da el tirón con él)
	if vaulting != null:
		kH = 7.0
	var kV := 9.0 if not en_moto else 12.0
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
	# (sube al momento: girando de espaldas a una pared la cámara no puede pasar por dentro de la cabeza)
	if apretado > apretado_cur:
		apretado_cur = apretado
	else:
		apretado_cur += (apretado - apretado_cur) * minf(1, dt * 3.0)
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
	# la distancia deseada cambia con suavidad (apuntar, tumbarse, dejar de correr): antes saltaba de golpe
	# hasta 4 studs en un fotograma. Las paredes siguen acercándola al instante (abajo)
	if dist_suave < 0.0:
		dist_suave = dist

	# (acercarse rápido solo al apuntar; dejar de correr, frenar contra una pared o trepar la acercan con calma: antes
	# daba un tirón)
	dist_suave += (dist - dist_suave) * minf(1, dt * (13.0 if (dist < dist_suave and (aiming or rest_cam > 0.05)) else 5.0))
	var back := -Rbx.look(rot) * dist_suave
	var c_hit := spherecast(shoulder_pt, 0.4, back)
	var allowed := maxf(0.5, c_hit - 0.1) if c_hit >= 0 else dist_suave
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
	if en_moto:
		# la cámara se inclina un poco con la moto en las curvas
		_cam_roll_moto = Rbx.damp(_cam_roll_moto, moto.inclinacion * 0.12, 4.0, dt)
		roll = Rbx.ang(0, 0, _cam_roll_moto)
	else:
		_cam_roll_moto = 0.0
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
		# cámara metida en la cabeza (o casi): el personaje no se dibuja
		if d < 1.0:
			fade_t = 1.0
	# se vuelve transparente AL MOMENTO (si no, durante unos fotogramas se veía el interior de la cabeza);
	# vuelve a verse poco a poco
	if fade_t > fade_cur:
		fade_cur = fade_t
	else:
		fade_cur += (fade_t - fade_cur) * minf(1, dt * 10)
	if fade_cur < 0.01:
		fade_cur = 0
	rig.set_fade(fade_cur)
	# con la mira telescópica puesta (ya con aumento) el personaje no se dibuja
	rig.visible = not (mira_tele and cam_fov < 30.0)


## ---------------------------------------------------------------- MOTO (v0.4)
## F junto a una moto: subir (o levantarla si está tirada). En la moto: W gas, S freno / marcha atrás,
## A/D girar, Espacio freno de mano (derrape), Shift/Ctrl en el aire echar el cuerpo atrás/adelante,
## F bajar (en marcha, salta), L luces, ratón para mirar (la cámara vuelve sola detrás de la moto).
## Armas: solo las de una mano (Armas.en_moto): se dispara/golpea con la derecha, la izquierda
## sigue en el manillar. Ver scripts/vehiculos/moto.gd.
var moto: Moto = null
var _moto_t0 := -9.0
var _moto_desde := Transform3D.IDENTITY
var _moto_raton_t := -9.0
var _moto_v_prev := 0.0
var _moto_acel := 0.0
var _cam_roll_moto := 0.0
var _moto_parada := true
const MOTO_SUBIR_DUR := 0.72 # s que tarda en pasar la pierna y sentarse


const MOTO_BAJAR_DUR := 0.68
var _moto_subir_dur := MOTO_SUBIR_DUR
var _moto_montaje_rapido := false
var _moto_lado := -1.0
var _moto_bajar_t := -1.0


func _al_alcance_moto(m: Moto) -> bool:
	var asiento := m.asiento_cf().origin
	var delta := global_position - asiento
	var lateral := absf(delta.dot(Rbx.flat(m.derecha()).normalized()))
	return lateral >= 1.2 and lateral <= 3.3 and absf(delta.dot(Rbx.flat(m.adelante()).normalized())) < 1.6 and absf(delta.y) < 1.4


func _pedir_montar(m: Moto) -> void:
	if not en_suelo or levantando_moto != null or not _al_alcance_moto(m):
		return
	var tramo := m.asiento_cf().origin - global_position
	if not raycast(global_position, tramo, [m.get_rid()]).is_empty():
		return
	subir_moto(m, true)


func _sitio_moto(m: Moto, lado: float) -> Vector3:
	var pie := m.asiento_cf().origin + Rbx.flat(m.derecha()).normalized() * (lado * 2.5)
	var piso := raycast(pie + Vector3.UP * 2.0, Vector3.DOWN * 8.0, [m.get_rid()])
	if piso.is_empty() or (piso.normal as Vector3).y < 0.43:
		return Vector3.INF
	return piso.position


## la moto más cercana a la que se puede subir (o levantar), o null
func moto_cercana() -> Moto:
	var mejor: Moto = null
	var dmin := Moto.ALCANCE_SUBIR
	for m in get_tree().get_nodes_in_group(Moto.GRUPO):
		var mm := m as Moto
		if mm == null or mm.piloto != null:
			continue
		var d := (mm.global_position + Vector3(0, 2.0, 0) - global_position).length()
		if d < dmin and (_al_alcance_levantar(mm) if mm.caida else mm.se_puede_subir() and absf(mm.velocidad()) < 0.8 and _al_alcance_moto(mm)):
			dmin = d
			mejor = mm
	return mejor


func subir_moto(m: Moto, desde_f := false) -> void:
	if not desde_f and (L.sprinting or ahora() < _carrera_hasta):
		return
	if moto != null or m == null or not m.se_puede_subir():
		return
	if health <= 0 or colgado != null or vaulting != null or L.knocked or L.gettingUp:
		return
	if stance == 2 or prone_p > 0.01:
		notify("Levántate primero")
		return
	if arsenal.recogiendo != null:
		return
	arsenal.ir_a_recoger = null
	arsenal.end_rest()
	# las armas de dos manos se guardan (en la moto una mano va en el manillar)
	if arsenal.switching != null or (arsenal.armado() and not Armas.en_moto(arsenal.equipado)):
		arsenal.guardar_ya()
	if stance == 1:
		set_stance(0)
	lean_cur = 0.0
	_subir_a = null
	air_vel = null
	_move_override = null
	_moto_bajar_t = -1.0
	_moto_montaje_rapido = desde_f and L.sprinting
	_moto_subir_dur = 0.52 if _moto_montaje_rapido else MOTO_SUBIR_DUR
	_moto_lado = 1.0 if (global_position - m.global_position).dot(m.derecha()) > 0.0 else -1.0
	moto = m
	m.subir(self)
	collision_layer = 0
	collision_mask = 0
	_moto_t0 = reloj
	_moto_desde = global_transform
	_moto_v_prev = 0.0
	_moto_raton_t = -9.0
	_vel_inercia = Vector3.ZERO
	velocity = Vector3.ZERO
	L.moto = _estado_moto(0.0)
	notify("MOTO: W gas · S freno · A/D girar · Espacio derrapar · F bajar · L luces")


## mandos y cuerpo sobre el asiento (cada fotograma, en lugar de andar)
func _paso_moto(dt: float) -> void:
	var m := moto
	if not is_instance_valid(m):
		moto = null
		_fin_moto(null)
		return
	var mandos := {"freno_mano": true} if _moto_bajar_t >= 0.0 else {}
	if health > 0 and not free_mouse and not arsenal.interfaz.abierto() and _moto_bajar_t < 0.0 and reloj - _moto_t0 >= _moto_subir_dur:
		var g := 1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0
		var f := 1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0
		var giro := 0.0
		if Input.is_physical_key_pressed(KEY_D): giro += 1.0
		if Input.is_physical_key_pressed(KEY_A): giro -= 1.0
		mandos = {"gas": g, "freno": f, "giro": giro, "freno_mano": Input.is_physical_key_pressed(KEY_SPACE)}
	m.paso(dt, mandos)
	if moto == null:
		return # se ha caído en este paso (expulsar_moto ya lo ha colocado)
	# el cuerpo va sentado (al subir, pasa de donde estaba al asiento)
	var objetivo := m.asiento_cf()
	var k := Rbx.smooth((reloj - _moto_t0) / _moto_subir_dur)
	if _moto_bajar_t >= 0.0:
		k = 1.0 - Rbx.smooth((reloj - _moto_bajar_t) / MOTO_BAJAR_DUR)
		if k <= 0.0:
			moto = null
			m.bajar()
			_fin_moto(m)
			return
	if k < 1.0:
		var desde := _moto_desde.interpolate_with(objetivo, k)
		if _moto_bajar_t < 0.0:
			# Primero carga el pie de apoyo, luego cruza la cadera mientras gira hacia el manillar.
			var cruce := smoothstep(0.0 if _moto_montaje_rapido else 0.10, 0.86, k)
			var giro := smoothstep(0.03, 0.62, k)
			desde.basis = _moto_desde.basis.slerp(objetivo.basis, giro)
			desde.origin = _moto_desde.origin.lerp(objetivo.origin, cruce)
			desde.origin += m.adelante() * (sin(PI * cruce) * 0.24)
			desde.origin.y += sin(PI * cruce) * (0.75 if _moto_montaje_rapido else 0.56) - sin(PI * clampf(k / 0.28, 0.0, 1.0)) * 0.16
		else:
			var desnivel := absf(_moto_desde.origin.y - objetivo.origin.y)
			desde.origin.y += sin(PI * k) * (0.48 + desnivel * 0.45)
		global_transform = desde
	else:
		global_transform = objetivo
	var v := m.velocidad()
	_moto_acel = Rbx.damp(_moto_acel, (v - _moto_v_prev) / maxf(dt, 1e-3), 6.0, dt)
	_moto_v_prev = v
	vel_real = m.vel_mundo()
	velocity = Vector3.ZERO
	en_suelo = true
	empuje = Vector3.ZERO
	cur_move = 0.0
	move_direction = Vector3.ZERO
	# estamina: sentado se recupera
	if not estamina_infinita:
		stamina = minf(C.PLAYER.StaminaMax, stamina + C.PLAYER.StaminaRegen * dt)
	if stamina > C.PLAYER.StaminaMax * C.PLAYER.ExhaustRecover:
		exhausted = false
	# estado para el animador
	L.pitch = pitch
	L.aiming = aiming
	L.firing = firing
	L.stamina = stamina / C.PLAYER.StaminaMax
	L.exhausted = false
	L.fatigue = 0.0
	L.sprinting = false
	L.stance = 0
	L.proneP = 0.0
	L.yaw = yaw
	L.lean = 0.0
	L.moto = _estado_moto(k)


## lo que el animador necesita saber de la moto (ver Animador, rama "EN LA MOTO")
func _estado_moto(k_subir: float) -> Dictionary:
	var m := moto
	var cpo := m.cuerpo_cf()
	var izq := m.derecha() * (_moto_lado if k_subir < 1.0 else -1.0)
	# pie al suelo: con margen (si no, a ~2 studs/s el pie sube y baja sin parar)
	var vm := absf(m.velocidad())
	if m.en_aire or vm > 3.2:
		_moto_parada = false
	elif vm < 1.4:
		_moto_parada = true
	# donde apoyaría el pie izquierdo parado (en el suelo, junto a la moto)
	var pie := _moto_desde.origin - Vector3.UP * center_cur if k_subir < 1.0 else m.global_position + izq * 1.25 + m.adelante() * 0.35
	var gs := raycast(pie + Vector3(0, 3.0, 0), Vector3(0, -6.0, 0))
	if not gs.is_empty():
		pie = gs.position
	return {
		"cuerpo": cpo, "vel": m.velocidad(), "acel": _moto_acel, "incl": m.inclinacion,
		"aire": m.en_aire, "direccion": m.direccion, "subir": k_subir, "lado": _moto_lado, "montaje_rapido": _moto_montaje_rapido and _moto_bajar_t < 0.0,
		"punoL": m.puno("L"), "punoR": m.puno("R"),
		"estriboL": m.estribo("L"), "estriboR": m.estribo("R"),
		"pie_suelo": pie, "parada": _moto_parada,
	}


## para la moto en el aire (Moto._cabeceo_aire): Shift = cuerpo atrás (morro arriba), Ctrl = adelante
func _mando_inclinar() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_SHIFT): v += 1.0
	if Input.is_physical_key_pressed(KEY_CTRL): v -= 1.0
	return v


## bajarse con F. Parado: se baja por la izquierda (o la derecha si hay pared). En marcha: salta
func bajar_moto(inmediato := false) -> void:
	var m := moto
	if m == null:
		return
	if not inmediato and (_moto_bajar_t >= 0.0 or reloj - _moto_t0 < _moto_subir_dur):
		return
	if not inmediato and absf(m.velocidad()) <= 0.8 and not m.en_aire:
		var pie := _sitio_moto(m, -1.0)
		var lado_salida := -1.0
		if not _salida_moto_libre(m, pie):
			lado_salida = 1.0
			pie = _sitio_moto(m, lado_salida)
		if not _salida_moto_libre(m, pie):
			notify("No hay espacio para bajar")
			return
		m.vel_h = Vector3.ZERO
		_moto_lado = lado_salida
		_moto_desde = Transform3D(Basis(Vector3.UP, m.rumbo), pie + Vector3.UP * center_cur)
		_moto_bajar_t = reloj
		return
	var vh := m.vel_h
	var rapida := not inmediato and (absf(m.velocidad()) > 0.8 or m.en_aire)
	var asiento := m.asiento_cf().origin
	moto = null
	m.bajar()
	_fin_moto(m)
	var izq := -m.derecha()
	var base := m.global_position
	var lado := izq
	if not raycast(base + Vector3(0, 2.5, 0), izq * 3.0).is_empty():
		lado = -izq
	if rapida:
		# salta en marcha: sale por el lado con la inercia de la moto
		global_position = asiento + lado * 1.0 + Vector3(0, 0.4, 0)
		var vel := vh + lado * 6.0 + Vector3(0, 7.0, 0)
		var vv := vh.length()
		if vv > 14.0:
			# demasiado deprisa para caer de pie: rueda por el suelo (los golpes hacen el daño)
			ragdoll_iniciar(vel, {"comportamiento": "caer", "giro": Vector3.UP.cross(Rbx.flat(vh).normalized()) * 3.0, "duracion": 1.4})
		else:
			_lanzar(vel)
		notify("¡Saltas de la moto!")
		return
	var sitio := base + lado * 2.5
	var gs := raycast(sitio + Vector3(0, 5.0, 0), Vector3(0, -10.0, 0))
	var y_pies := (gs.position as Vector3).y if not gs.is_empty() else base.y
	global_position = Vector3(sitio.x, y_pies + center_cur + 0.1, sitio.z)
	velocity = Vector3.ZERO
	vel_real = Vector3.ZERO


func _salida_moto_libre(m: Moto, pie: Vector3) -> bool:
	if pie == Vector3.INF:
		return false
	var desde := m.asiento_cf().origin
	var hasta := pie + Vector3.UP * center_cur
	# En una ladera el trayecto primero sube, luego pasa la pierna y aterriza.
	var altura := maxf(desde.y, hasta.y) + 0.55
	var sobre_asiento := Vector3(desde.x, altura, desde.z)
	var sobre_pie := Vector3(hasta.x, altura, hasta.z)
	return raycast(desde, sobre_asiento - desde).is_empty() \
		and raycast(sobre_asiento, sobre_pie - sobre_asiento).is_empty() \
		and raycast(hasta, Vector3.UP * maxf(2.5, altura - hasta.y)).is_empty()


## la moto tira al piloto (choque, mal aterrizaje): sale despedido con "imp" y recibe "danio"
func expulsar_moto(imp: Vector3, danio: float, motivo := "") -> void:
	var m := moto
	if m == null:
		return
	var pose_asiento := global_transform
	moto = null
	_fin_moto(m)
	global_transform = pose_asiento
	global_position += Vector3.UP * 0.42
	_soltado_t = reloj # sale despedido: no se agarra a ningún borde
	shake = 1.0
	# sale despedido con el ragdoll activo: vuela, se protege con los brazos y rueda por el suelo
	var plano := Rbx.flat(imp)
	var giro := Vector3.UP.cross(plano.normalized()) * clampf(plano.length() * 0.15, 1.0, 6.0) if plano.length() > 0.5 else Vector3.ZERO
	ragdoll_iniciar(imp, {"comportamiento": "caida_libre", "giro": giro, "duracion": 1.8})
	# (2026-10-28) sale volando por encima de su moto: no se engancha en ella (antes chocaba con el manillar y caía a
	# un metro, fuera cual fuera la velocidad)
	if ragdoll != null:
		var fis = m.get("_fisica")
		if fis != null:
			ragdoll.ignorar(fis, 0.48)
		ragdoll.ignorar(m, 0.48)
	if motivo != "muerte":
		notify("¡Te has caído de la moto!")
	if danio > 0.0:
		recibir_danio(danio, global_position - Rbx.flat(imp))


func _lanzar(vel: Vector3) -> void:
	velocity = vel
	vel_real = vel
	en_suelo = false
	_set_estado("Freefall")
	air_vel = Rbx.flat(vel)
	air_cap = maxf(3.0, (air_vel as Vector3).length())


## de vuelta a pie: colisiones, cuerpo derecho y los pies vuelven a apoyarse
func _fin_moto(m: Moto) -> void:
	_vel_inercia = Vector3.ZERO
	_moto_bajar_t = -1.0
	collision_layer = 1
	collision_mask = 1 | 4
	L.moto = null
	var giro := m.rumbo if m != null else rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, giro), global_position)
	_set_estado("Running")
	stance = 0
	var an := get_node_or_null("Animador") as Animador
	if an:
		an.replant = true
		an.rel_aim = 0.0


## ---------------------------------------------------------------- levantar una moto tirada (F junto a ella)
## Se pone al lado del asiento mirando a la moto, se agacha, la agarra del manillar y del asiento y la
## levanta empujando con las piernas (Animador: "levanta"). La moto acaba en la pata de cabra.
var levantando_moto = null # {moto, t0, dir, giro}
const LEVANTAR_AGARRE := 0.35 # s agachándose y agarrándola antes de empezar a subirla


func _al_alcance_levantar(m: Moto) -> bool:
	if not m.se_puede_levantar() or not m.de_lado(global_position):
		return false
	var asiento := m.cuerpo_cf() * ModeloMoto.ASIENTO
	return Rbx.flat(asiento - global_position).length() <= 3.5 and absf(asiento.y - global_position.y) < 3.4


func _cancelar_levantar_moto() -> void:
	if levantando_moto == null:
		return
	var m: Moto = levantando_moto.moto
	if is_instance_valid(m):
		m.cancelar_levantar()
	levantando_moto = null
	L.levanta = null


func levantar_moto(m: Moto) -> void:
	if not en_suelo or not _al_alcance_levantar(m):
		return
	if L.sprinting or ahora() < _carrera_hasta:
		return
	if health <= 0 or colgado != null or vaulting != null or L.knocked or arsenal.recogiendo != null:
		return
	if stance == 2 or prone_p > 0.01:
		notify("Levántate primero")
		return
	if stance == 1:
		set_stance(0)
	arsenal.ir_a_recoger = null
	if arsenal.armado() or arsenal.switching != null:
		arsenal.guardar_ya() # hacen falta las dos manos
	arsenal.end_rest()
	var hacia_contacto := Rbx.flat(m.cuerpo_cf() * ModeloMoto.ASIENTO - global_position)
	var giro := atan2(-hacia_contacto.x, -hacia_contacto.z)
	var puno_alto := "R" if m.puno("R").origin.y > m.puno("L").origin.y else "L"
	var asiento := m.cuerpo_cf() * (ModeloMoto.ASIENTO + Vector3(0, 0.1, 0.55))
	var a_mano := m.puno(puno_alto).origin
	if not raycast(global_position, (asiento + a_mano) * 0.5 - global_position, m.exclusion_levantar()).is_empty():
		return
	var derecha := Basis(Vector3.UP, giro).x
	m.empezar_a_levantar()
	_vel_inercia = Vector3.ZERO
	levantando_moto = {"moto": m, "t0": reloj, "giro": giro, "desde": rotation.y,
		"puno": puno_alto, "puno_derecha": (a_mano - asiento).dot(derecha) > 0.0}
	notify("Levantando la moto…")


func _paso_levantar() -> void:
	var lm: Dictionary = levantando_moto
	var m: Moto = lm.moto
	move_direction = Vector3.ZERO
	if not is_instance_valid(m) or health <= 0 or not en_suelo:
		_cancelar_levantar_moto()
		return
	var t := reloj - float(lm.t0)
	var total := LEVANTAR_AGARRE + Moto.LEVANTAR_DUR
	var k := clampf(t / total, 0.0, 1.0)
	m.lev_k = clampf((t - LEVANTAR_AGARRE) / Moto.LEVANTAR_DUR, 0.0, 1.0)
	# Las manos conservan la asignación durante todo el levantamiento.
	var puno_alto: Vector3 = m.puno(lm.puno).origin
	var asiento: Vector3 = m.cuerpo_cf() * (ModeloMoto.ASIENTO + Vector3(0, 0.1, 0.55))
	var mano_r := puno_alto if lm.puno_derecha else asiento
	var mano_l := asiento if lm.puno_derecha else puno_alto
	L.levanta = {"k": k, "L": mano_l, "R": mano_r}
	if k >= 1.0:
		levantando_moto = null
		L.levanta = null
		if m.caida:
			m.levantar()
		notify("Moto levantada · [F] para subir")


## ---------------------------------------------------------------- RAGDOLL (cuerpo con física, estilo GTA IV)
## Se activa cuando la situación lo pide: salir despedido de la moto (o saltar de ella deprisa), caídas
## largas (en el aire) o aterrizajes fuertes, golpes fuertes de zombi (a veces) y al morir. Los golpes del
## cuerpo contra el suelo hacen daño (ZShared.FallDamage de Roblox). Al pararse, se levanta solo: boca
## abajo se apoya en las manos y se pone de pie; boca arriba primero rueda (Animador.levantarse).
var ragdoll: Ragdoll = null
var _ragdoll_t := -99.0
var _golpe_dir := Vector3.ZERO
var _aire_t := 0.0
const LEVANTARSE_VEL := 1.4 # rapidez de la animación de levantarse tras un ragdoll (1 = la de cuerpo a tierra)
const DERRIBO_ESPERA := 6.0 # s mínimos entre dos derribos por golpes


func ragdoll_iniciar(vel: Vector3, op := {}) -> void:
	if ragdoll != null:
		if op.has("impulso"):
			ragdoll.golpe(op.get("pieza", "UpperTorso"), op.impulso)
		return
	if colgado != null:
		soltar_cornisa()
	if vaulting != null:
		vaulting = null
		L.vault = null
	_cancelar_levantar_moto()
	_subir_a = null
	arsenal.ir_a_recoger = null
	arsenal.recogiendo = null
	if arsenal.armado() or arsenal.switching != null:
		arsenal.guardar_ya()
	arsenal.end_rest()
	firing = false
	aiming = false
	L.knocked = true
	collision_layer = 0
	collision_mask = 0
	stance = 0
	prone_p = 0.0
	getup_p = 0.0
	supine = false
	lean_cur = 0.0
	velocity = Vector3.ZERO
	_ragdoll_t = reloj
	var an := get_node_or_null("Animador") as Animador
	if an:
		an.levantarse = null
	ragdoll = Ragdoll.iniciar(self, rig, vel, op)
	ragdoll.impacto.connect(_ragdoll_impacto)
	ragdoll.recuperado.connect(_ragdoll_levantarse)


func _paso_ragdoll(dt: float) -> void:
	move_direction = Vector3.ZERO
	if ragdoll.cuerpos.is_empty():
		return
	var pel := ragdoll.pelvis()
	# el "jugador" (cámara, zombis que lo buscan) va con la pelvis
	global_position = pel
	# por si acaso: vivo y en el suelo, nunca se queda más de 3 s pasado su tiempo sin levantarse
	if health > 0.0 and ragdoll.vivo and ragdoll.duracion >= 0.0 and ragdoll._t > ragdoll.duracion + 3.0 \
			and ragdoll._dist_suelo < 3.0:
		_ragdoll_levantarse()
		return
	vel_real = ragdoll.torso().linear_velocity
	en_suelo = false
	if not estamina_infinita:
		stamina = minf(C.PLAYER.StaminaMax, stamina + C.PLAYER.StaminaRegen * 0.5 * dt)


## daño por velocidad de impacto (curva de Roblox: leve al principio, se dispara en caídas altas)
static func danio_caida(vel: float) -> float:
	var F: Dictionary = C.FALL
	if vel <= F.SafeSpeed:
		return 0.0
	return pow((vel - F.SafeSpeed) / (F.LethalSpeed - F.SafeSpeed), 1.5) * 110.0


## el cuerpo (en ragdoll) se estrella contra algo
func _ragdoll_impacto(vel: float) -> void:
	if ragdoll == null or health <= 0.0:
		return
	# caer de cabeza o de espaldas hace más daño que caer de pie
	var arriba := ragdoll.torso().global_transform.basis.y.y
	var mult := 1.5 if arriba < -0.25 else (1.15 if arriba < 0.45 else 1.0)
	var dmg := danio_caida(vel) * mult
	if dmg > 0.5:
		recibir_danio(dmg, ragdoll.pelvis() - Vector3(0, 2.5, 0))
	if health <= 0.0:
		return
	var sev := clampf(dmg / 70.0, 0.0, 1.0)
	if dmg > 0.5 or ragdoll.comportamiento == "caida_libre":
		ragdoll.gravedad = sev
		ragdoll.duracion = ragdoll._t + 0.6 + sev * 1.5
		if ragdoll.comportamiento in ["caer", "caida_libre"]:
			ragdoll.cambiar("impacto")


## caída larga: pierde el equilibrio en el aire y cae como un muñeco (ZClient de Roblox: RagdollSpeed,
## RagdollMinAir, RagdollGround). Devuelve true si ha empezado el ragdoll
func _caida_ragdoll(v: Vector3) -> bool:
	var F: Dictionary = C.FALL
	if ragdoll != null or moto != null or colgado != null or vaulting != null or health <= 0.0:
		return false
	if _aire_t > float(F.RagdollMinAir) and -v.y > float(F.RagdollSpeed):
		var g := raycast(global_position, Vector3(0, -90, 0))
		if g.is_empty() or float(g.distance) - center_cur > float(F.RagdollGround):
			ragdoll_iniciar(Vector3(vel_real.x, v.y, vel_real.z), {"comportamiento": "caida_libre", "duracion": 30.0,
				"giro": Vector3(randf() - 0.5, (randf() - 0.5) * 0.4, randf() - 0.5) * 1.5})
			return true
	return false


## aterrizó de pie: si fue muy fuerte hace daño y, pasado un punto, las piernas no aguantan y se desploma
func _aterrizaje_fuerte(vel: float) -> void:
	var F: Dictionary = C.FALL
	if vel <= float(F.SafeSpeed) or health <= 0.0:
		return
	var dmg := danio_caida(vel)
	recibir_danio(dmg, global_position + Vector3(0, -3, 0))
	if health > 0.0 and vel >= float(F.KnockSpeed) and ragdoll == null:
		var sev := clampf(dmg / 70.0, 0.0, 1.0)
		ragdoll_iniciar(Rbx.flat(vel_real) * 0.3 + Vector3(0, -2, 0), {"comportamiento": "impacto", "gravedad": sev,
			"duracion": 0.6 + sev * 1.5})


## suelo bajo "p" (sin contar las motos, que no son suelo para ponerse de pie) y si cabe de pie ahí; prueba
## alrededor hasta 4,5 studs. Devuelve el punto del suelo donde levantarse.
func _sitio_para_levantarse(p: Vector3) -> Vector3:
	var sin_motos: Array = []
	for mt in get_tree().get_nodes_in_group("motos"):
		sin_motos.append((mt as CollisionObject3D).get_rid())
		var fis = mt.get("_fisica")
		if fis != null and is_instance_valid(fis):
			sin_motos.append((fis as CollisionObject3D).get_rid())
	var primero := Vector3.INF
	for r: float in [0.0, 1.5, 3.0, 4.5]:
		for i in (1 if r == 0.0 else 8):
			var a := TAU * float(i) / 8.0
			var c := p + Vector3(cos(a), 0, sin(a)) * r
			var gs := raycast(c + Vector3(0, 3.0, 0), Vector3(0, -12.0, 0), sin_motos)
			if gs.is_empty():
				continue
			var g: Vector3 = gs.position
			if primero == Vector3.INF:
				primero = g
			if g.y > p.y + 2.5:
				continue # (encima de algo alto: no)
			if _cabe_de_pie(g):
				return g
	return primero if primero != Vector3.INF else p - Vector3(0, 0.5, 0)


## ¿una esfera en "p" toca el cuerpo "obj"? (para saber si ya se ha separado de la moto caída)
func _esfera_choca_con(obj: CollisionObject3D, p: Vector3, radio: float) -> bool:
	var sh := SphereShape3D.new()
	sh.radius = radio
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p)
	q.collision_mask = obj.collision_layer
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		if r.collider == obj:
			return true
	return false


## ¿cabe el jugador en el suelo "g", tumbado (al empezar a levantarse) y de pie? (con margen; la moto caída cuenta)
func _cabe_de_pie(g: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var caja := BoxShape3D.new()
	caja.size = Vector3(2.6, 0.9, 2.6)
	q.shape = caja
	q.transform = Transform3D(Basis.IDENTITY, g + Vector3(0, 0.6, 0))
	if not space.intersect_shape(q, 1).is_empty():
		return false
	var cap := CapsuleShape3D.new()
	cap.radius = 0.95
	cap.height = 4.4
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, g + Vector3(0, 2.75, 0))
	return space.intersect_shape(q, 1).is_empty()


## el cuerpo se ha parado: se levanta donde quedó, mirando hacia donde apunta la cabeza
func _ragdoll_levantarse() -> void:
	if ragdoll == null or health <= 0.0:
		return
	var arriba := ragdoll.boca_arriba()
	var dir := ragdoll.direccion_cabeza()
	var pel := ragdoll.pelvis()
	# (2026-10-28) sitio libre para ponerse de pie: antes, junto a la moto caída (o pegado a una pared) aparecía
	# dentro de ella y se quedaba atascado en el suelo
	var sitio := _sitio_para_levantarse(pel)
	var giro := atan2(-dir.x, -dir.z)
	global_transform = Transform3D(Basis(Vector3.UP, giro), Vector3(sitio.x, sitio.y + float(C.STANCE[2].Center), sitio.z))
	velocity = Vector3.ZERO
	vel_real = Vector3.ZERO
	collision_layer = 1
	collision_mask = 1 | 4
	L.knocked = false
	stance = 0
	prone_p = 0.0
	supine = false
	# levantarse lleva lo que la animación de cuerpo a tierra (y antes, rodar si está boca arriba)
	getup_p = 1.0 + (0.75 * 1.15 / float(C.PLAYER.ProneTime) if arriba else 0.0)
	_getup_vel = LEVANTARSE_VEL
	center_cur = float(C.STANCE[2].Center)
	_set_estado("Running")
	en_suelo = true
	var an := get_node_or_null("Animador") as Animador
	if an:
		an.levantarse = {"t0": an.ahora(), "arriba": arriba, "vel": LEVANTARSE_VEL}
		an.replant = true
	ragdoll.terminar(0.35)
	ragdoll = null
	# mientras se levanta no choca con una moto caída que tenga al lado (el cuerpo que la sostenía desaparece y la
	# moto se recoloca; si chocaran, el jugador la empujaría como un muro)
	for mt in get_tree().get_nodes_in_group("motos"):
		var fis = mt.get("_fisica")
		if fis != null and is_instance_valid(fis) and ((fis as Node3D).global_position - global_position).length() < 9.0:
			add_collision_exception_with(fis)
			_sin_choque_motos.append(fis)

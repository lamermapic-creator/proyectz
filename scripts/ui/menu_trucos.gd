class_name MenuTrucos
extends CanvasLayer
## Menú de trucos para probar las mecánicas (F1). SOLO en desarrollo (OS.is_debug_build()): en el
## ejecutable final no existe. Mientras está abierto el juego se pausa y el ratón queda libre.
## Interruptores (estamina/balas infinitas, invencible, ver ruido, zombis sordos/ciegos, cámara lenta),
## acciones (vida, estamina, munición, armas al suelo, muñecos, zombis) y teletransporte a cada zona
## del nivel de pruebas.

const M := 1.0 / 0.31

## [nombre, pies en metros, hacia dónde mira (grados: 0 = -Z, 180 = +Z, -90 = +X)]
const ZONAS := [
	["Inicio", Vector3(0, 0, 0), 0.0],
	["Bloques (saltar / trepar)", Vector3(-3, 0, -5.5), 0.0],
	["Rampas 15° / 30° / 50°", Vector3(16, 0, -8.5), 0.0],
	["Escalera", Vector3(-20, 0, 1.5), 180.0],
	["Túneles (1.4 m y 0.8 m)", Vector3(8, 0, 15.5), 0.0],
	["Muros bajos y mesa (apoyar)", Vector3(-2, 0, 12.3), 180.0],
	["Pared alta (cámara / arma)", Vector3(0, 0, 18.6), 180.0],
	["Cornisa en L (colgarse)", Vector3(-35, 0, -22.6), 0.0],
	["Zona de tiro (muñecos)", Vector3(24.2, 0, 0), -90.0],
	["Tras la pared (zombi)", Vector3(-4, 0, 24), 180.0],
	["Zona de motos (rampas y muro)", Vector3(6, 0, -27), 0.0],
]

var J: Jugador
var _raiz: Control
var _checks := {}
var _abierto := false
var _raton_antes := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	J = get_parent() as Jugador
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.visible = false
	add_child(_raiz)
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.35)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(velo)
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = 24 + 700
	panel.offset_bottom = -24
	_raiz.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	v.add_child(EstiloUI.titulo("TRUCOS", 34))
	var sub := Label.new()
	sub.text = "Solo en desarrollo · F1 o Esc para cerrar"
	sub.add_theme_color_override("font_color", EstiloUI.TEXTO_SUAVE)
	sub.add_theme_font_size_override("font_size", 14)
	v.add_child(sub)

	_seccion(v, "Interruptores")
	var g1 := _rejilla(v)
	_check(g1, "estamina", "Estamina infinita (F4)", func(on): J.estamina_infinita = on)
	_check(g1, "balas", "Balas infinitas (F5)", func(on): J.arsenal.balas_infinitas = on)
	_check(g1, "invencible", "Invencible", func(on): J.invencible = on)
	_check(g1, "lenta", "Cámara lenta (x0.3)", func(on): Engine.time_scale = 0.3 if on else 1.0)
	_check(g1, "ruido", "Ver ruido y zombis (F6)", func(on): Ruido.ver = on)
	_check(g1, "sordos", "Zombis sordos (F7)", func(on): Zombi.sordos = on)
	_check(g1, "ciegos", "Zombis ciegos (F8)", func(on): Zombi.ciegos = on)

	_seccion(v, "Jugador")
	var g2 := _rejilla(v)
	_accion(g2, "Vida al máximo", func():
		J.health = J.max_health)
	_accion(g2, "Herido (25 % de vida)", func():
		J.health = J.max_health * 0.25)
	_accion(g2, "Agotado (sin estamina)", func():
		J.estamina_infinita = false
		J.stamina = 2.0
		_refrescar())
	_accion(g2, "Estamina al máximo", func():
		J.stamina = float(ZConfig.PLAYER.StaminaMax))
	# ragdoll (v0.4): probar las caídas con física
	_accion(g2, "Derribarme (empujón)", func():
		cerrar()
		J.ragdoll_iniciar(J.vel_real, {"comportamiento": "caer", "impulso": -Rbx.look(J.root_cf()) * 12.0 + Vector3(0, 3, 0),
			"pieza": "UpperTorso", "duracion": 1.4}))
	_accion(g2, "Caer desde 12 m", func():
		cerrar()
		J.global_position += Vector3(0, 12.0 * M, 0))

	_seccion(v, "Armas")
	var g3 := _rejilla(v)
	_accion(g3, "Munición al máximo", _municion_max)
	_accion(g3, "Recargar el arma", func():
		J.arsenal.reload())
	# todas las armas (v0.4: revólver, subfusil, escopeta, francotirador, hacha y palanca incluidas)
	for nombre in Armas.todas():
		var n_arma: String = nombre
		_accion(g3, "%s al suelo" % n_arma, func(): _arma_al_suelo(n_arma))

	_seccion(v, "Mundo")
	var g4 := _rejilla(v)
	_accion(g4, "Revivir los muñecos", _revivir_munecos)
	_accion(g4, "Zombi delante", _zombi_delante)
	_accion(g4, "Moto delante", _moto_delante)
	_accion(g4, "Levantar las motos caídas", func():
		for m in J.get_tree().get_nodes_in_group(Moto.GRUPO):
			(m as Moto).levantar())

	_seccion(v, "Ir a…")
	var g5 := _rejilla(v)
	for z in ZONAS:
		var zona: Array = z
		_accion(g5, zona[0], func():
			J.teletransportar(zona[1] * M, deg_to_rad(zona[2]))
			cerrar())


func _seccion(padre: Control, txt: String) -> void:
	var l := Label.new()
	l.text = txt.to_upper()
	l.add_theme_color_override("font_color", EstiloUI.ACENTO)
	l.add_theme_font_size_override("font_size", 15)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 6)
	padre.add_child(esp)
	padre.add_child(l)


func _rejilla(padre: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	padre.add_child(g)
	return g


func _accion(padre: Control, txt: String, f: Callable) -> void:
	var b := EstiloUI.boton(txt, func():
		f.call()
		J.notify(txt))
	b.custom_minimum_size = Vector2(320, 38)
	b.add_theme_font_size_override("font_size", 16)
	padre.add_child(b)


func _check(padre: Control, id: String, txt: String, f: Callable) -> void:
	var c := CheckBox.new()
	c.text = txt
	c.custom_minimum_size = Vector2(320, 34)
	c.toggled.connect(func(on: bool): f.call(on))
	padre.add_child(c)
	_checks[id] = c


## pone las casillas como está el juego ahora (también lo que se cambió con F4-F8)
func _refrescar() -> void:
	var estado := {
		"estamina": J.estamina_infinita, "balas": J.arsenal.balas_infinitas, "invencible": J.invencible,
		"lenta": Engine.time_scale < 0.99, "ruido": Ruido.ver, "sordos": Zombi.sordos, "ciegos": Zombi.ciegos,
	}
	for id in estado:
		(_checks[id] as CheckBox).set_pressed_no_signal(estado[id])


func abierto() -> bool:
	return _abierto


func abrir() -> void:
	if _abierto:
		return
	_abierto = true
	_raton_antes = Input.mouse_mode
	_refrescar()
	_raiz.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	_raiz.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).physical_keycode
	if k == KEY_F1:
		get_viewport().set_input_as_handled()
		if _abierto:
			cerrar()
		elif not get_tree().paused and not J.arsenal.interfaz.abierto():
			abrir()
	elif k == KEY_ESCAPE and _abierto:
		get_viewport().set_input_as_handled()
		cerrar()


## ---------------------------------------------------------------- acciones
func _municion_max() -> void:
	for h in J.arsenal.inventario:
		var d: Dictionary = J.arsenal.inventario[h]
		var w: Dictionary = Armas.WEAPONS[d.name]
		if w.has("Mag"):
			d.mag = int(w.Mag)
			d.reserve = int(w.get("MaxReserve", w.get("StartReserve", 0)))


func _arma_al_suelo(nombre: String) -> void:
	var w: Dictionary = Armas.WEAPONS[nombre]
	var root := J.root_cf()
	var p := J.global_position + Rbx.look(root) * 3.0
	var g := J.raycast(p + Vector3(0, 4, 0), Vector3(0, -60, 0))
	var pos: Vector3 = g.position if not g.is_empty() else p - Vector3(0, J.center_cur, 0)
	J.arsenal.soltar_en_suelo({"name": nombre, "mag": int(w.get("Mag", 0)), "reserve": int(w.get("StartReserve", 0))}, pos, randf() * TAU)


func _revivir_munecos() -> void:
	var nivel := J.get_parent()
	var viejos := nivel.get_node_or_null("Maniquies")
	if viejos:
		viejos.name = "Maniquies_viejos"
		viejos.queue_free()
	if nivel.has_method("_crear_maniquies"):
		nivel.call("_crear_maniquies")


func _zombi_delante() -> void:
	var dz := J.get_parent().get_node_or_null("Zombis")
	if dz == null or not dz.has_method("crear_zombi"):
		J.notify("En este nivel no hay director de zombis")
		return
	var root := J.root_cf()
	var p := J.global_position + Rbx.look(root) * 14.0
	var g := J.raycast(p + Vector3(0, 6, 0), Vector3(0, -60, 0))
	var pies: Vector3 = g.position if not g.is_empty() else p - Vector3(0, J.center_cur, 0)
	# mirando hacia el jugador
	var giro := rad_to_deg(J.yaw) + 180.0
	dz.call("crear_zombi", pies, giro)


## una moto nueva unos pasos por delante, mirando hacia donde mira el jugador
func _moto_delante() -> void:
	if J.moto != null:
		J.notify("Bájate primero de la moto")
		return
	var nivel := J.get_parent()
	var cont := nivel.get_node_or_null("Motos")
	if cont == null:
		cont = Node3D.new()
		cont.name = "Motos"
		nivel.add_child(cont)
	var fwd := Rbx.flat(Rbx.look(J.camara.global_transform)).normalized()
	var p := J.global_position + fwd * 7.0
	var g := J.raycast(p + Vector3(0, 6, 0), Vector3(0, -60, 0))
	var pies: Vector3 = g.position if not g.is_empty() else p - Vector3(0, J.center_cur, 0)
	var m := Moto.new()
	m.name = "Moto_%d" % cont.get_child_count()
	m.position = pies - (cont as Node3D).global_position
	m.rotation = Vector3(0, J.yaw + PI / 2, 0) # de lado: se ve entera y se sube por la izquierda
	cont.add_child(m)

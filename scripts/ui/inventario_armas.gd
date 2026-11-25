extends CanvasLayer
## Dos vistas del inventario del Arsenal. La pausa modal se comparte entre ambas.

var arsenal: Arsenal
var _raiz: ColorRect
var _centro: CenterContainer
var _raton_anterior := Input.MOUSE_MODE_CAPTURED
var _rueda := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz = ColorRect.new()
	_raiz.color = Color(0.025, 0.035, 0.04, 0.87)
	_raiz.theme = EstiloUI.tema()
	_raiz.hide()
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_centro = CenterContainer.new()
	_raiz.add_child(_centro)
	_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	var tecla: int = evento.physical_keycode
	if _raiz.visible:
		if tecla == KEY_ESCAPE or tecla == (KEY_TAB if _rueda else KEY_I):
			_cerrar()
		elif tecla in [KEY_I, KEY_TAB]:
			_mostrar(tecla == KEY_TAB)
		elif tecla >= KEY_1 and tecla <= KEY_4:
			_elegir(tecla - KEY_1)
		else:
			return
	elif tecla in [KEY_I, KEY_TAB] and not get_tree().paused and arsenal.J.health > 0:
		_mostrar(tecla == KEY_TAB)
	else:
		return
	get_viewport().set_input_as_handled()


func _mostrar(rueda: bool) -> void:
	if not _raiz.visible:
		_raton_anterior = Input.mouse_mode
		arsenal.J.firing = false
		arsenal.J.aiming = false
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_raiz.show()
	_rueda = rueda
	for hijo in _centro.get_children():
		_centro.remove_child(hijo)
		hijo.queue_free()
	var pila := VBoxContainer.new()
	pila.add_theme_constant_override("separation", 12)
	_centro.add_child(pila)
	var titulo := EstiloUI.titulo("RUEDA DE ARMAS" if rueda else "INVENTARIO", 26)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pila.add_child(titulo)
	if rueda:
		_crear_rueda(pila)
	else:
		for i in Armas.SLOTS.size():
			pila.add_child(_boton_hueco(i, true))
	var cerrar := EstiloUI.boton("Cerrar · Esc", _cerrar)
	pila.add_child(cerrar)


func _crear_rueda(pila: VBoxContainer) -> void:
	var disco := Control.new()
	disco.custom_minimum_size = Vector2(356, 256)
	pila.add_child(disco)
	var centro := Vector2(178, 128)
	disco.draw.connect(func():
		disco.draw_circle(centro, 119, Color("20292c"), true, -1.0, true)
		disco.draw_arc(centro, 119, 0.0, TAU, 64, Color("657478"), 2.0, true)
	)
	var direcciones := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for i in Armas.SLOTS.size():
		var boton := _boton_hueco(i, false)
		disco.add_child(boton)
		boton.custom_minimum_size = Vector2.ZERO
		boton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.size = Vector2(120, 42)
		boton.position = centro + direcciones[i] * Vector2(110, 96) - boton.size / 2.0
	var guardar := EstiloUI.boton("Guardar", _guardar)
	disco.add_child(guardar)
	guardar.custom_minimum_size = Vector2.ZERO
	guardar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	guardar.size = Vector2(100, 42)
	guardar.position = centro - guardar.size / 2.0
	guardar.disabled = arsenal.equipado.is_empty()


func _boton_hueco(i: int, detalle: bool) -> Button:
	var hueco: Dictionary = Armas.SLOTS[i]
	var item: Dictionary = arsenal.inventario.get(hueco.Id, {})
	var nombre: String = item.get("name", "Vacío")
	var equipado: bool = not item.is_empty() and arsenal.equipado == nombre
	var texto := "%d · %s" % [i + 1, nombre]
	if detalle:
		texto += "  ·  " + String(hueco.Name)
		if not item.is_empty() and Armas.WEAPONS[nombre].Kind == "Gun":
			texto += "  ·  %d / %s balas" % [item.mag, "∞" if arsenal.balas_infinitas else str(item.reserve)]
	if equipado:
		texto += "  ✓"
	var boton := EstiloUI.boton(texto, func(): _elegir(i))
	boton.disabled = item.is_empty()
	return boton


func _elegir(i: int) -> void:
	if arsenal.arma_en_hueco(Armas.SLOTS[i].Id).is_empty():
		return
	_cerrar()
	arsenal.select_slot(i)


func _guardar() -> void:
	for i in Armas.SLOTS.size():
		if arsenal.arma_en_hueco(Armas.SLOTS[i].Id) == arsenal.equipado:
			_elegir(i)
			return


func _cerrar() -> void:
	_raiz.hide()
	get_tree().paused = false
	Input.mouse_mode = _raton_anterior

extends CanvasLayer
## Dos vistas del inventario del Arsenal con una escala de tiempo compartida.
const FACTOR_TIEMPO := 0.2
const RADIO_INTERIOR := 60.0
const RADIO_EXTERIOR := 164.0
const SEPARACION := 0.065
var _indices_rueda: Array[int] = []

var _filtro: ColorRect
var _transicion: Tween
var _intensidad := 0.0

var arsenal: Arsenal
var _raiz: ColorRect
var _centro: CenterContainer
var _raton_anterior := Input.MOUSE_MODE_CAPTURED
var _rueda := false
var _escala_anterior := 1.0
var _velocidad_audio_anterior := 1.0


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_filtro = ColorRect.new()
	_filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/ui/efecto_rueda.gdshader")
	_filtro.material = mat
	_filtro.hide()
	add_child(_filtro)
	_filtro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		else:
			return
	elif tecla in [KEY_I, KEY_TAB] and not get_tree().paused and arsenal.J.health > 0 and arsenal.cambio_mochila.is_empty():
		_mostrar(tecla == KEY_TAB)
	else:
		return
	get_viewport().set_input_as_handled()


func abierto() -> bool:
	return is_instance_valid(_raiz) and _raiz.visible


func _process(_dt: float) -> void:
	if abierto() and (arsenal.J.health <= 0 or get_tree().paused):
		_cerrar()


func _exit_tree() -> void:
	if abierto():
		_cerrar(false)


func _mostrar(rueda: bool) -> void:
	if not _raiz.visible:
		_raton_anterior = Input.mouse_mode
		arsenal.J.firing = false
		arsenal.J.aiming = false
		arsenal.J._apuntar_pedido = false
		arsenal.impacto.soltar()
		_escala_anterior = Engine.time_scale
		Engine.time_scale = _escala_anterior * FACTOR_TIEMPO
		_velocidad_audio_anterior = AudioServer.playback_speed_scale
		AudioServer.playback_speed_scale = _velocidad_audio_anterior * FACTOR_TIEMPO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_raiz.show()
	_rueda = rueda
	_raiz.color.a = 0.23 if rueda else 0.72
	_animar_filtro(rueda)
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
		var capacidad := Label.new()
		capacidad.text = "%d / %d armas · %s" % [arsenal.inventario.size(), arsenal.capacidad(), "Mochila puesta" if arsenal.mochila_puesta else "Sin mochila"]
		pila.add_child(capacidad)
		for i in Armas.SLOTS.size():
			var id: String = Armas.SLOTS[i].Id
			if not arsenal.mochila_puesta and (id == "BlancaCorta" or id == "BlancaLarga"):
				continue
			var fila := Label.new()
			fila.text = _texto_hueco(i, true)
			pila.add_child(fila)
		var accion := "Quitar mochila · dejar el excedente en el suelo" if arsenal.mochila_puesta else "Ponerse la mochila"
		var boton_mochila := EstiloUI.boton(accion, func():
			_cerrar()
			arsenal.solicitar_mochila()
		)
		boton_mochila.disabled = not arsenal.mochila_puesta and not arsenal.mochila_al_alcance()
		pila.add_child(boton_mochila)
	var cerrar := EstiloUI.boton("Cerrar · Esc", _cerrar)
	cerrar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pila.add_child(cerrar)


func _animar_filtro(visible_filtro: bool) -> void:
	if _transicion != null:
		_transicion.kill()
	if not visible_filtro and not _filtro.visible:
		return
	_filtro.show()
	var mat := _filtro.material as ShaderMaterial
	_transicion = create_tween().set_ignore_time_scale(true)
	_transicion.tween_method(func(valor: float):
		_intensidad = valor
		mat.set_shader_parameter("intensidad", valor)
	, _intensidad, 1.0 if visible_filtro else 0.0, 0.16)
	if not visible_filtro:
		_transicion.tween_callback(_filtro.hide)


func _crear_rueda(pila: VBoxContainer) -> void:
	_indices_rueda.clear()
	for i in Armas.SLOTS.size():
		if arsenal.mochila_puesta or Armas.SLOTS[i].Id in ["Corta", "Corta2", "Larga"]:
			_indices_rueda.append(i)
	var disco := Control.new()
	disco.custom_minimum_size = Vector2.ONE * (RADIO_EXTERIOR * 2.0 + 8.0)
	disco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pila.add_child(disco)
	var centro := disco.custom_minimum_size / 2.0
	disco.draw.connect(func():
		var resaltado := _sector(disco.get_local_mouse_position() - centro)
		for i in _indices_rueda.size():
			var nombre := arsenal.arma_en_hueco(Armas.SLOTS[_indices_rueda[i]].Id)
			var color := Color("24343d") if not nombre.is_empty() else Color("182027")
			if not nombre.is_empty() and i == resaltado:
				color = Color("406e80")
			var poligono := _poligono_sector(centro, i)
			disco.draw_colored_polygon(poligono, color)
			poligono.append(poligono[0])
			var equipado := not nombre.is_empty() and nombre == arsenal.equipado
			disco.draw_polyline(poligono, Color("e7ab75") if equipado else Color("658492"), 1.5, true)
	)
	disco.mouse_exited.connect(disco.queue_redraw)
	disco.gui_input.connect(func(evento: InputEvent):
		if evento is InputEventMouseMotion:
			disco.queue_redraw()
		elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
			var i := _sector(evento.position - centro)
			if i >= 0:
				_elegir(_indices_rueda[i])
	)
	for i in _indices_rueda.size():
		var rotacion := -PI / 2.0 + i * TAU / _indices_rueda.size()
		var rotulo := Label.new()
		rotulo.text = _texto_hueco(_indices_rueda[i], false)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disco.add_child(rotulo)
		rotulo.size = Vector2(104, 38)
		rotulo.position = centro + Vector2.from_angle(rotacion) * 112.0 - rotulo.size / 2.0
	var guardar := EstiloUI.boton("Guardar", _guardar)
	guardar.custom_minimum_size = Vector2.ZERO
	guardar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	disco.add_child(guardar)
	guardar.size = Vector2(92, 40)
	guardar.position = centro - guardar.size / 2.0
	guardar.disabled = arsenal.equipado.is_empty()


func _poligono_sector(centro: Vector2, indice: int) -> PackedVector2Array:
	var angulo := -PI / 2.0 + indice * TAU / _indices_rueda.size()
	var puntos := PackedVector2Array()
	var semi := PI / _indices_rueda.size() - SEPARACION
	for paso in range(21):
		var direccion := Vector2.from_angle(angulo + lerpf(-semi, semi, paso / 20.0))
		puntos.append(centro + direccion * RADIO_EXTERIOR)
	for paso in range(20, -1, -1):
		var direccion := Vector2.from_angle(angulo + lerpf(-semi, semi, paso / 20.0))
		puntos.append(centro + direccion * RADIO_INTERIOR)
	return puntos


func _sector(desde_centro: Vector2) -> int:
	var radio := desde_centro.length()
	if radio < RADIO_INTERIOR or radio > RADIO_EXTERIOR:
		return -1
	var angulo := desde_centro.angle() + PI / 2.0
	var paso := TAU / _indices_rueda.size()
	var indice := roundi(angulo / paso)
	if absf(angulo - indice * paso) > paso / 2.0 - SEPARACION:
		return -1
	return posmod(indice, _indices_rueda.size())


func _texto_hueco(i: int, detalle: bool) -> String:
	var hueco: Dictionary = Armas.SLOTS[i]
	var item: Dictionary = arsenal.inventario.get(hueco.Id, {})
	var nombre: String = item.get("name", "Vacío")
	var texto := "%s  ·  %s" % [hueco.Name, nombre] if detalle else nombre
	if not item.is_empty() and Armas.WEAPONS[nombre].Kind == "Gun":
		var municion := "%d / %s" % [item.mag, "∞" if arsenal.balas_infinitas else str(item.reserve)]
		texto += "  ·  " + municion + " balas" if detalle else "\n" + municion
	if detalle and not item.is_empty() and arsenal.equipado == nombre:
		texto += "  ✓"
	return texto


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


func _cerrar(animar := true) -> void:
	_raiz.hide()
	if animar:
		_animar_filtro(false)
	arsenal.impacto.soltar()
	Engine.time_scale = _escala_anterior
	AudioServer.playback_speed_scale = _velocidad_audio_anterior
	if not get_tree().paused:
		Input.mouse_mode = _raton_anterior

class_name PanelOpciones
extends PanelContainer
## Panel de opciones básicas (se usa en el menú principal y en el de pausa).

signal cerrado

var ocultar_al_cerrar := true

var _filas := VBoxContainer.new()


func _ready() -> void:
	Opciones.cargar()
	theme = EstiloUI.tema()
	custom_minimum_size = Vector2(560, 0)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	add_child(caja)
	caja.add_child(EstiloUI.titulo("OPCIONES", 30))
	_filas.add_theme_constant_override("separation", 10)
	caja.add_child(_filas)

	_seccion("Control")
	_deslizador("Sensibilidad del ratón", 0.3, 2.5, 0.05, Opciones.sensibilidad, func(v): Opciones.sensibilidad = v, func(v): return "%.2f" % v)
	_casilla("Invertir eje vertical", Opciones.invertir_y, func(v): Opciones.invertir_y = v)
	_seccion("Vídeo")
	_desplegable("Calidad gráfica", Opciones.CALIDADES, Opciones.calidad, func(i): Opciones.calidad = i)
	_deslizador("Campo de visión", 60, 90, 1, Opciones.fov, func(v): Opciones.fov = v, func(v): return "%d°" % int(v))
	if not OS.has_feature("web"):
		_casilla("Pantalla completa", Opciones.pantalla_completa, func(v): Opciones.pantalla_completa = v)
		_casilla("Sincronización vertical (VSync)", Opciones.vsync, func(v): Opciones.vsync = v)
	_seccion("Audio")
	_deslizador("Volumen general", 0, 1, 0.01, Opciones.volumen, func(v): Opciones.volumen = v, func(v): return "%d %%" % int(round(v * 100)))

	var volver := EstiloUI.boton("Volver", _cerrar)
	volver.custom_minimum_size = Vector2(180, 44)
	volver.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_child(volver)
	caja.add_child(pie)


func abrir() -> void:
	visible = true
	await get_tree().process_frame
	var primero := _filas.find_children("*", "Control", true, false)
	for c in primero:
		if (c as Control).focus_mode != Control.FOCUS_NONE:
			(c as Control).grab_focus()
			break


func _cerrar() -> void:
	Opciones.guardar()
	if ocultar_al_cerrar:
		visible = false
	cerrado.emit()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cerrar()


func _cambio() -> void:
	Opciones.aplicar(get_tree())


func _seccion(txt: String) -> void:
	var l := Label.new()
	l.text = txt.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", EstiloUI.ACENTO)
	_filas.add_child(l)


func _fila(txt: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = txt
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	_filas.add_child(h)
	return h


func _deslizador(txt: String, mn: float, mx: float, paso: float, val: float, fijar: Callable, formato: Callable) -> void:
	var h := _fila(txt)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = paso
	s.value = val
	s.custom_minimum_size = Vector2(180, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Label.new()
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = formato.call(val)
	v.add_theme_color_override("font_color", EstiloUI.TEXTO_SUAVE)
	s.value_changed.connect(func(x):
		fijar.call(x)
		v.text = formato.call(x)
		_cambio())
	h.add_child(s)
	h.add_child(v)


func _casilla(txt: String, val: bool, fijar: Callable) -> void:
	var h := _fila(txt)
	var c := CheckBox.new()
	c.button_pressed = val
	c.text = "Sí" if val else "No"
	c.toggled.connect(func(x):
		fijar.call(x)
		c.text = "Sí" if x else "No"
		_cambio())
	h.add_child(c)


func _desplegable(txt: String, ops: Array, val: int, fijar: Callable) -> void:
	var h := _fila(txt)
	var o := OptionButton.new()
	for t in ops:
		o.add_item(t)
	o.select(val)
	o.custom_minimum_size = Vector2(180, 0)
	o.item_selected.connect(func(i):
		fijar.call(i)
		_cambio())
	h.add_child(o)

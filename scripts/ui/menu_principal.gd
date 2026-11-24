extends Node3D
## Menú de cuarentena. UI de referencia 1280×720 escalada a la ventana.
const JUEGO := "res://escenas/pruebas_movimiento.tscn"
const FONDO := preload("res://scripts/ui/fondo_menu.gd")
const FUENTE_TITULO := preload("res://assets/fuentes/OpenSans-CondBold.ttf")
const FUENTE := preload("res://assets/fuentes/OpenSans-Regular.ttf")
const ROJO := Color("e27b52")
const TEXTO := Color("e2ded3")
const SUAVE := Color("969f9d")

static func version_texto() -> String:
	return "%s · prototipo" % str(ProjectSettings.get_setting("application/config/version", "?"))

var _botones: VBoxContainer
var _opciones: PanelOpciones
var _controles: PanelContainer
var _fundido: ColorRect
var _saliendo := false
var _referencia: Control
var _portada: Control
var _ventanas: Control
var _descripcion: Label
var _tema: Theme
var _marco: PanelContainer
var _tween_panel: Tween
var _tween_fundido: Tween
var _cerrando := false

func _ready() -> void:
	Opciones.cargar()
	get_window().title = "Proyecto Z · %s" % str(ProjectSettings.get_setting("application/config/version", "?"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	add_child(FONDO.new())
	_crear_ui()
	Opciones.aplicar(get_tree())
	call_deferred("_aplicar_calidad")
	get_viewport().size_changed.connect(_ajustar_ui)
	_ajustar_ui()

func _aplicar_calidad() -> void:
	Opciones.aplicar_calidad(get_tree())

func _texto(padre: Node, texto: String, pos: Vector2, tam: int, color := TEXTO, titulo := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.add_theme_font_override("font", FUENTE_TITULO if titulo else FUENTE)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(l)
	return l

func _rect(padre: Node, pos: Vector2, tam: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = tam
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(r)
	return r

func _estilo(bg: Color, borde: Color, grosor := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.content_margin_left = 54
	s.content_margin_right = 22
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

func _boton(texto: String, indice: int, accion: Callable, principal := false) -> Button:
	var b := Button.new()
	b.name = ["Jugar", "Opciones", "Controles", "Salir"][indice]
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(400, 66 if principal else 44)
	b.add_theme_font_override("font", FUENTE_TITULO if principal else FUENTE)
	b.add_theme_font_size_override("font_size", 28 if principal else 17)
	b.add_theme_stylebox_override("normal", _estilo(Color("39251e") if principal else Color(0.05, 0.07, 0.07, 0.35), Color("735145") if principal else Color(0.5, 0.6, 0.6, 0.13)))
	b.add_theme_stylebox_override("hover", _estilo(Color("3b2923"), ROJO))
	b.add_theme_stylebox_override("pressed", _estilo(Color("5b3428"), ROJO))
	b.add_theme_stylebox_override("focus", _estilo(Color(0, 0, 0, 0), ROJO, 2))
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.pressed.connect(accion)
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func():
		_descripcion.text = ["La ciudad escucha cada paso.", "Ajusta la experiencia a tu equipo.", "Aprende a moverte sin hacer ruido.", "Volver al escritorio."][indice])
	_rect(b, Vector2(18, 13), Vector2(2, 40 if principal else 18), ROJO if principal else Color("65706b"))
	_texto(b, "→", Vector2(359, 17 if principal else 7), 22, ROJO)
	return b

func _crear_ui() -> void:
	_tema = EstiloUI.tema().duplicate(true) as Theme
	_tema.default_font = FUENTE
	_tema.default_font_size = 17
	var capa := CanvasLayer.new()
	add_child(capa)
	var raiz := Control.new()
	capa.add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = _tema
	var sombra := TextureRect.new()
	var textura := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	grad.colors = PackedColorArray([Color(0.015, 0.025, 0.027, 0.98), Color(0.015, 0.025, 0.027, 0.88), Color(0.015, 0.025, 0.027, 0.18), Color(0, 0, 0, 0)])
	textura.gradient = grad
	textura.fill_from = Vector2.ZERO
	textura.fill_to = Vector2.RIGHT
	sombra.texture = textura
	raiz.add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atmosfera := _rect(raiz, Vector2.ZERO, Vector2.ZERO, Color.WHITE)
	atmosfera.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/atmosfera_menu.gdshader")
	atmosfera.material = material
	_referencia = Control.new()
	_referencia.name = "InterfazMenu"
	_referencia.size = Vector2(1280, 720)
	_referencia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_referencia)
	_portada = Control.new()
	_portada.size = Vector2(1280, 720)
	_portada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_referencia.add_child(_portada)
	_rect(_portada, Vector2(76, 70), Vector2(28, 3), ROJO)
	_texto(_portada, "PROYECTO", Vector2(68, 105), 78, TEXTO, true)
	_texto(_portada, "Z", Vector2(69, 166), 147, ROJO, true)
	_rect(_portada, Vector2(165, 230), Vector2(1, 52), Color("57615c"))
	_texto(_portada, "SOBREVIVE.\nNO HAGAS RUIDO.", Vector2(183, 230), 17, TEXTO)
	_botones = VBoxContainer.new()
	_botones.name = "Acciones"
	_botones.position = Vector2(76, 345)
	_botones.size = Vector2(400, 238)
	_botones.add_theme_constant_override("separation", 8)
	_portada.add_child(_botones)
	_descripcion = _texto(_portada, "La ciudad escucha cada paso.", Vector2(76, 596), 13, SUAVE)
	_botones.add_child(_boton("JUGAR", 0, _jugar, true))
	_botones.add_child(_boton("Opciones", 1, func(): _abrir(_opciones)))
	_botones.add_child(_boton("Controles", 2, func(): _abrir(_controles)))
	_botones.add_child(_boton("Salir", 3, _salir))
	for i in 4:
		var b := _botones.get_child(i) as Button
		b.focus_neighbor_top = b.get_path_to(_botones.get_child(posmod(i - 1, 4)))
		b.focus_neighbor_bottom = b.get_path_to(_botones.get_child((i + 1) % 4))
	_rect(_referencia, Vector2(76, 657), Vector2(1128, 1), Color(0.6, 0.65, 0.63, 0.20))
	_texto(_referencia, "↑ ↓  NAVEGAR     ENTER  SELECCIONAR", Vector2(76, 674), 11, SUAVE)
	var version := _texto(_referencia, version_texto(), Vector2(930, 670), 13, SUAVE)
	version.size.x = 274
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_crear_ventanas()
	_fundido = _rect(raiz, Vector2.ZERO, Vector2.ZERO, Color.BLACK)
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundido.mouse_filter = Control.MOUSE_FILTER_STOP
	_portada.modulate.a = 0.0
	_portada.position.x = -12.0
	_tween_fundido = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_fundido.tween_property(_fundido, "color:a", 0.0, 0.70)
	_tween_fundido.tween_property(_portada, "modulate:a", 1.0, 0.52)
	_tween_fundido.tween_property(_portada, "position:x", 0.0, 0.52)
	_tween_fundido.chain().tween_callback(func(): _fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	(_botones.get_child(0) as Button).grab_focus()

func _crear_ventanas() -> void:
	_ventanas = Control.new()
	_ventanas.name = "PanelesMenu"
	_ventanas.size = Vector2(1280, 720)
	_referencia.add_child(_ventanas)
	_rect(_ventanas, Vector2.ZERO, Vector2(1280, 720), Color(0.015, 0.022, 0.024, 0.94))
	var marco := PanelContainer.new()
	_marco = marco
	marco.position = Vector2(220, 48)
	marco.size = Vector2(840, 602)
	_ventanas.add_child(marco)
	var estilo := _estilo(Color("111a1c"), Color("46514e"))
	estilo.content_margin_left = 26
	estilo.content_margin_right = 26
	estilo.content_margin_top = 22
	estilo.content_margin_bottom = 22
	marco.add_theme_stylebox_override("panel", estilo)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	marco.add_child(scroll)
	var contenido := VBoxContainer.new()
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenido)
	_opciones = PanelOpciones.new()
	_opciones.ocultar_al_cerrar = false
	contenido.add_child(_opciones)
	_opciones.theme = _tema
	_opciones.cerrado.connect(_volver)
	_opciones.visible = false
	_controles = _panel_controles()
	contenido.add_child(_controles)
	_controles.visible = false
	_ventanas.visible = false

func _panel_controles() -> PanelContainer:
	var p := PanelContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	col.add_child(EstiloUI.titulo("CONTROLES", 30))
	var filas := [
		["WASD / Shift", "Moverse / correr"], ["Espacio", "Saltar, sortear o trepar"],
		["C o Ctrl / Z", "Agacharse / cuerpo a tierra"], ["Q / E", "Asomarse"],
		["1 – 4 / F", "Elegir arma / recoger"], ["Clic derecho", "Apuntar o ponerse en guardia"],
		["Clic izquierdo", "Disparar o golpear"], ["G", "Patada; pisotón al enemigo caído"],
		["Clic derecho + Espacio", "Bloquear; doble Espacio: empujón"],
		["R / X", "Recargar / apoyar el arma"], ["V / rueda", "Cambiar de hombro / acercar cámara"],
		["Colgado", "A/D moverse · Espacio subir · S soltarse"], ["Esc", "Pausa"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 9)
	for fila in filas:
		var tecla := Label.new()
		tecla.text = fila[0]
		tecla.add_theme_color_override("font_color", ROJO)
		grid.add_child(tecla)
		var accion := Label.new()
		accion.text = fila[1]
		grid.add_child(accion)
	col.add_child(grid)
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	var volver := EstiloUI.boton("Volver", _volver)
	volver.custom_minimum_size = Vector2(160, 44)
	pie.add_child(volver)
	col.add_child(pie)
	return p

func _ajustar_ui() -> void:
	var tam := get_viewport().get_visible_rect().size
	var factor := minf(tam.x / 1280.0, tam.y / 720.0)
	_referencia.scale = Vector2.ONE * factor
	_referencia.position = (tam - Vector2(1280, 720) * factor) * 0.5

func _abrir(panel: Control) -> void:
	if _saliendo or _cerrando or _ventanas.visible:
		return
	_portada.visible = false
	_botones.visible = false
	_ventanas.visible = true
	_opciones.visible = false
	_controles.visible = false
	if panel == _opciones:
		_opciones.abrir()
	else:
		panel.visible = true
		(panel.find_children("*", "Button", true, false)[0] as Button).grab_focus()

	_ventanas.modulate.a = 0.0
	_marco.position.y = 63.0
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_ventanas, "modulate:a", 1.0, 0.24)
	_tween_panel.tween_property(_marco, "position:y", 48.0, 0.28)


func _volver() -> void:
	if _cerrando or not _ventanas.visible:
		return
	_cerrando = true
	if _tween_panel != null and _tween_panel.is_valid():
		_tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_ventanas, "modulate:a", 0.0, 0.16)
	_tween_panel.tween_property(_marco, "position:y", 55.0, 0.16)
	_tween_panel.chain().tween_callback(func():
		_opciones.visible = false
		_controles.visible = false
		_ventanas.visible = false
		_portada.visible = true
		_botones.visible = true
		_cerrando = false
		(_botones.get_child(0) as Button).grab_focus())
	_portada.modulate.a = 0.0
	_tween_panel.chain().tween_property(_portada, "modulate:a", 1.0, 0.16)


func _unhandled_input(event: InputEvent) -> void:
	if not _saliendo and not _cerrando and event.is_action_pressed("ui_cancel") and _ventanas.visible:
		if _opciones.visible:
			_opciones._cerrar()
		else:
			_volver()
		get_viewport().set_input_as_handled()

func _jugar() -> void:
	_transicion(func(): PantallaCarga.ir_a(get_tree(), JUEGO))

func _salir() -> void:
	_transicion(func(): get_tree().quit())

func _transicion(accion: Callable) -> void:
	if _saliendo:
		return
	_saliendo = true
	for b in _botones.get_children():
		(b as Button).disabled = true
	_fundido.mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween_fundido != null and _tween_fundido.is_valid():
		_tween_fundido.kill()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fundido, "color:a", 1.0, 0.46)
	tw.tween_property(_portada, "position:x", -18.0, 0.38)
	tw.chain().tween_callback(accion)

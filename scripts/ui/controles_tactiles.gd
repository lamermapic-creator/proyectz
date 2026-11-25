extends CanvasLayer
## Controles básicos para la versión web en pantallas táctiles.

var jugador: Jugador
var _panel: Control
var _dedo_camara := -1
var _teclas: Array[Key] = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	jugador = get_parent() as Jugador
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boton("↑", KEY_W, Vector2(74, -157), false)
	_boton("←", KEY_A, Vector2(17, -101), false)
	_boton("↓", KEY_S, Vector2(74, -101), false)
	_boton("→", KEY_D, Vector2(131, -101), false)
	_boton("Saltar", KEY_SPACE, Vector2(-204, -150))
	_boton("Usar", KEY_F, Vector2(-107, -150))
	_boton("Armas", KEY_TAB, Vector2(-204, -210))
	_boton("Recarga", KEY_R, Vector2(-107, -210))
	_boton("Pausa", KEY_ESCAPE, Vector2(-107, -270))
	_boton("Apuntar", KEY_NONE, Vector2(-204, -90))
	_boton("Atacar", KEY_NONE, Vector2(-107, -90))


func _boton(texto: String, tecla: Key, pos: Vector2, derecha := true) -> void:
	var control := TouchScreenButton.new()
	control.shape = RectangleShape2D.new()
	control.shape.size = Vector2(88, 48) if derecha else Vector2(52, 48)
	control.shape_centered = false
	var ancla := Control.new()
	ancla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(ancla)
	ancla.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if derecha else Control.PRESET_BOTTOM_LEFT)
	ancla.position += pos
	ancla.add_child(control)
	var fondo := ColorRect.new()
	fondo.size = control.shape.size
	fondo.color = Color(0.06, 0.09, 0.1, 0.8)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(fondo)
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.size = fondo.size
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(rotulo)
	if tecla != KEY_NONE:
		control.pressed.connect(_tecla.bind(true, tecla))
		control.released.connect(_tecla.bind(false, tecla))
	elif texto == "Apuntar":
		control.pressed.connect(func(): jugador._apuntar_pedido = true)
		control.released.connect(func():
			jugador._apuntar_pedido = false
			jugador.aiming = false)
	else:
		control.pressed.connect(func():
			var a := jugador.arsenal
			if a.es_arma_fuego():
				jugador.firing = true
				a.shoot()
			elif a.armado():
				a.melee()
			else:
				a.punetazo())
		control.released.connect(func(): jugador.firing = false)


func _tecla(pulsada: bool, tecla: Key) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	evento.keycode = tecla
	evento.pressed = pulsada
	if pulsada and not _teclas.has(tecla):
		_teclas.append(tecla)
	elif not pulsada:
		_teclas.erase(tecla)
	Input.parse_input_event(evento)


func _process(_dt: float) -> void:
	var activa: bool = not get_tree().paused and not jugador.arsenal.interfaz.abierto() and jugador.health > 0
	if not activa and _panel.visible:
		for tecla in _teclas.duplicate():
			_tecla(false, tecla)
		_dedo_camara = -1
	if activa and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = activa


func _unhandled_input(evento: InputEvent) -> void:
	if not _panel.visible or jugador.arsenal.interfaz.abierto():
		return
	if evento is InputEventScreenTouch and not evento.pressed and evento.index == _dedo_camara:
		_dedo_camara = -1
	elif evento is InputEventScreenDrag and (_dedo_camara == evento.index or _dedo_camara == -1):
		_dedo_camara = evento.index
		jugador._mouse_delta += evento.relative * 0.004
		get_viewport().set_input_as_handled()

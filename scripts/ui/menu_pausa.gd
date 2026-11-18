class_name MenuPausa
extends CanvasLayer
## Menú de pausa (Esc): Continuar, Opciones, Volver al menú principal, Salir del juego.

const MENU_PRINCIPAL := "res://escenas/menu_principal.tscn"

var _raiz: Control
var _botones: VBoxContainer
var _opciones: PanelOpciones
var _raton_antes := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.visible = false
	add_child(_raiz)
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(velo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(centro)
	var pila := VBoxContainer.new()
	pila.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(pila)
	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 10)
	pila.add_child(_botones)
	_botones.add_child(EstiloUI.titulo("PAUSA", 44))
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 12)
	_botones.add_child(esp)
	_botones.add_child(EstiloUI.boton("Continuar", continuar))
	_botones.add_child(EstiloUI.boton("Opciones", _abrir_opciones))
	_botones.add_child(EstiloUI.boton("Volver al menú principal", _al_menu))
	_botones.add_child(EstiloUI.boton("Salir del juego", func(): get_tree().quit()))
	# la versión, al final (los botones se buscan por su posición: get_child(2) = Continuar)
	var ver := Label.new()
	ver.text = "%s · prototipo" % str(ProjectSettings.get_setting("application/config/version", "?"))
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_botones.add_child(ver)
	_opciones = PanelOpciones.new()
	_opciones.visible = false
	_opciones.cerrado.connect(func():
		_botones.visible = true
		(_botones.get_child(2) as Button).grab_focus())
	pila.add_child(_opciones)


func pausado() -> bool:
	return _raiz.visible


func pausar() -> void:
	if _raiz.visible:
		return
	_raton_antes = Input.mouse_mode
	_raiz.visible = true
	_botones.visible = true
	_opciones.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_botones.get_child(2) as Button).grab_focus()


func continuar() -> void:
	_raiz.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _abrir_opciones() -> void:
	_botones.visible = false
	_opciones.abrir()


func _al_menu() -> void:
	# la pantalla de carga tapa el cambio (y quita la pausa al cambiar de escena)
	PantallaCarga.ir_a(get_tree(), MENU_PRINCIPAL)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		if _opciones.visible:
			return # lo cierra el propio panel
		get_viewport().set_input_as_handled()
		if _raiz.visible:
			continuar()
		else:
			pausar()


## si la ventana pierde el foco (Alt+Tab), el juego se pausa solo
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not OS.has_feature("editor") and not _raiz.visible:
		pausar()

extends Node3D
## Menú principal: el superviviente en el nivel de pruebas al atardecer, con la cámara girando
## despacio alrededor, y el menú a la izquierda (Jugar, Opciones, Controles, Salir).

const JUEGO := "res://escenas/pruebas_movimiento.tscn"
const NIVEL := preload("res://scripts/nivel/nivel_pruebas.gd")
const VERSION := "v0.2 · prototipo"

var cam: Camera3D
var rig: RigPersonaje
var _t := 0.0
var _botones: VBoxContainer
var _opciones: PanelOpciones
var _controles: PanelContainer
var _fundido: ColorRect
var _saliendo := false
var _cabecera: Array = []


func _ready() -> void:
	Opciones.cargar()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	# escenario de fondo (el mismo nivel, sin muñecos)
	var nivel := Node3D.new()
	nivel.set_script(NIVEL)
	nivel.set_meta("sin_maniquies", true)
	add_child(nivel)
	# el superviviente, de pie con el rifle
	rig = RigPersonaje.new()
	add_child(rig)
	rig.position = Vector3(0, 3.1, 0)
	rig.rotation.y = deg_to_rad(-25)
	var rifle := Armas.construir_modelo("Rifle")
	(rig.P.RightHand as Node3D).add_child(rifle)
	rifle.transform = Armas.handle_en_mano("Rifle")
	_pose(0.0)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.current = true
	_crear_ui()
	Opciones.aplicar(get_tree())
	call_deferred("_atardecer")


## luz cálida y baja para el fondo del menú
func _atardecer() -> void:
	for n in find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		l.rotation_degrees = Vector3(-14, 120, 0)
		l.light_color = Color8(255, 196, 140)
		l.light_energy = 1.4
	for n in find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sm := env.sky.sky_material as ProceduralSkyMaterial
			sm.sky_top_color = Color8(52, 66, 96)
			sm.sky_horizon_color = Color8(222, 150, 104)
			sm.ground_horizon_color = Color8(120, 96, 80)
			env.fog_enabled = true
			env.fog_light_color = Color8(200, 150, 120)
			env.fog_density = 0.004
	Opciones.aplicar_calidad(get_tree())


func _process(dt: float) -> void:
	_t += dt
	var a := _t * 0.08 + 0.6
	var foco := Vector3(0, 3.6, 0)
	cam.global_position = foco + Vector3(sin(a) * 13.0, 1.4 + sin(_t * 0.2) * 0.4, cos(a) * 13.0)
	cam.look_at(foco + Vector3(-2.2, 0, 0).rotated(Vector3.UP, a), Vector3.UP)
	_pose(_t)


## pose de reposo: peso en una pierna, rifle bajo, respiración y mirada que va y viene
func _pose(t: float) -> void:
	var M := rig.M
	var resp := sin(t * 1.6) * 0.02
	(M.Root as RigPersonaje.Motor).transform = Rbx.cf(0.06, -0.05, 0) * Rbx.ang(0, 0.05, 0.03)
	(M.Waist as RigPersonaje.Motor).transform = Rbx.ang(0, -0.2, 0) * Rbx.ang(resp - 0.05, 0, -0.03)
	(M.Neck as RigPersonaje.Motor).transform = Rbx.ang(0, sin(t * 0.3) * 0.35 + 0.15, 0) * Rbx.ang(-0.05 - resp * 0.5, 0, 0)
	(M.LeftHip as RigPersonaje.Motor).transform = Rbx.ang(0.08, 0, -0.06)
	(M.LeftKnee as RigPersonaje.Motor).transform = Rbx.ang(-0.2, 0, 0)
	(M.LeftAnkle as RigPersonaje.Motor).transform = Rbx.ang(0.12, 0, 0)
	(M.RightHip as RigPersonaje.Motor).transform = Rbx.ang(-0.04, 0, 0.04)
	# brazos: el rifle cruzado por delante, cañón hacia abajo
	(M.RightShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.35, 0.2, 0.15)
	(M.RightElbow as RigPersonaje.Motor).transform = Rbx.ang(1.2, 0, 0)
	(M.RightWrist as RigPersonaje.Motor).transform = Rbx.ang(-0.9, 0.4, 0)
	(M.LeftShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.7, -0.35, -0.1)
	(M.LeftElbow as RigPersonaje.Motor).transform = Rbx.ang(1.1, 0, 0)
	rig.aplicar()


func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = EstiloUI.tema()
	capa.add_child(raiz)
	# degradado oscuro a la izquierda para que se lea el menú
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.82))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.anchor_bottom = 1.0
	grad.anchor_right = 0.55
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(grad)
	var col := VBoxContainer.new()
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 80
	col.offset_right = 760
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	raiz.add_child(col)
	var tit := EstiloUI.titulo("PROYECTO Z", 84)
	col.add_child(tit)
	var sub := Label.new()
	sub.text = "Sobrevive. No hagas ruido."
	sub.add_theme_color_override("font_color", EstiloUI.TEXTO_SUAVE)
	sub.add_theme_font_size_override("font_size", 20)
	col.add_child(sub)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 30)
	col.add_child(esp)
	_cabecera = [tit, sub, esp]
	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 10)
	col.add_child(_botones)
	_botones.add_child(EstiloUI.boton("Jugar", _jugar))
	_botones.add_child(EstiloUI.boton("Opciones", func(): _abrir(_opciones)))
	_botones.add_child(EstiloUI.boton("Controles", func(): _abrir(_controles)))
	_botones.add_child(EstiloUI.boton("Salir", func(): get_tree().quit()))
	_opciones = PanelOpciones.new()
	_opciones.visible = false
	_opciones.cerrado.connect(_volver)
	col.add_child(_opciones)
	_controles = _panel_controles()
	_controles.visible = false
	col.add_child(_controles)
	var ver := Label.new()
	ver.text = VERSION
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -260
	ver.offset_top = -40
	ver.offset_right = -24
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	raiz.add_child(ver)
	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 1)
	_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_fundido)
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", 0.0, 1.2)
	(_botones.get_child(0) as Button).grab_focus()


func _panel_controles() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(EstiloUI.titulo("CONTROLES", 30))
	var lista := [
		["WASD", "Moverse"], ["Shift", "Correr (tumbado: reptar rápido)"], ["Espacio", "Saltar / sortear / trepar"],
		["C o Ctrl", "Agacharse"], ["Z", "Cuerpo a tierra"], ["Q / E", "Asomarse"],
		["1 - 4", "Armas"], ["Clic derecho", "Apuntar"], ["Clic izquierdo", "Disparar / golpear"],
		["R", "Recargar"], ["X", "Apoyar el arma"], ["F", "Recoger"], ["V", "Cambiar de hombro"],
		["Colgado", "A/D moverse · Espacio subir · S soltarse"], ["Esc", "Pausa"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	for f in lista:
		var k := Label.new()
		k.text = f[0]
		k.add_theme_color_override("font_color", EstiloUI.ACENTO)
		var d := Label.new()
		d.text = f[1]
		grid.add_child(k)
		grid.add_child(d)
	v.add_child(grid)
	var volver := EstiloUI.boton("Volver", _volver)
	volver.custom_minimum_size = Vector2(180, 44)
	volver.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_child(volver)
	v.add_child(pie)
	return p


func _abrir(panel: Control) -> void:
	_botones.visible = false
	# los paneles ocupan su sitio (el título se oculta para que quepan en pantallas bajas)
	for c in _cabecera:
		(c as Control).visible = false
	if panel == _opciones:
		_opciones.abrir()
	else:
		panel.visible = true
		(panel.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func _volver() -> void:
	_opciones.visible = false
	_controles.visible = false
	_botones.visible = true
	for c in _cabecera:
		(c as Control).visible = true
	(_botones.get_child(0) as Button).grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE and _controles.visible:
		_volver()


func _jugar() -> void:
	if _saliendo:
		return
	_saliendo = true
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", 1.0, 0.6)
	tw.tween_callback(func(): get_tree().change_scene_to_file(JUEGO))

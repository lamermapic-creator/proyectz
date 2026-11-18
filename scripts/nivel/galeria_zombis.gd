extends Node3D
## Galería independiente: flechas cambian animación; espacio pausa; ratón/rueda orbitan.
const CLIPS := ["reposo", "caminar", "perseguir", "atacar", "herido", "morir"]
var jugadores: Array[AnimationPlayer] = []
var clip := 0
var pausa := false
var camara: Camera3D
var texto: Label
var angulo := 0.0
var distancia := 31.0

func _ready() -> void:
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, -25, 0)
	luz.light_energy = 1.6
	add_child(luz)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color("20272c")
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color("c3ccd1")
	entorno.environment.ambient_light_energy = 0.65
	add_child(entorno)
	for i in Zombi.VARIANTES_VISUALES.size():
		var id: String = Zombi.VARIANTES_VISUALES[i]
		var modelo := load(RigPersonaje.MODELOS["zombi_" + id]) as PackedScene
		var inst := modelo.instantiate() as Node3D
		inst.position = Vector3((i % 4 - 1.5) * 4.5, 3.1, (floori(i / 4.0) - 1) * 7.0)
		add_child(inst)
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			jugadores.append(ap)
		var etiqueta := Label3D.new()
		etiqueta.text = id.capitalize()
		etiqueta.position = inst.position + Vector3(0, -2.95, -1.0)
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.font_size = 38
		etiqueta.pixel_size = 0.012
		add_child(etiqueta)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(25, 28)
	suelo.mesh = plano
	add_child(suelo)
	camara = Camera3D.new()
	camara.current = true
	add_child(camara)
	var ui := CanvasLayer.new()
	add_child(ui)
	texto = Label.new()
	texto.position = Vector2(20, 16)
	ui.add_child(texto)
	_reproducir()
	_actualizar_camara()

func _reproducir() -> void:
	for ap in jugadores:
		for nombre in ap.get_animation_list():
			if String(nombre).get_file() == CLIPS[clip]:
				var anim := ap.get_animation(nombre)
				anim.loop_mode = Animation.LOOP_LINEAR # Solo en la vitrina: repetir acciones únicas.
				ap.play(nombre)
				ap.speed_scale = 0.0 if pausa else 1.0
	texto.text = "ZOMBIS / %s  ·  ← → animación  ·  Espacio pausa  ·  Arrastrar / rueda cámara" % CLIPS[clip]

func _actualizar_camara() -> void:
	camara.position = Vector3(sin(angulo) * distancia, 19, -cos(angulo) * distancia)
	camara.look_at(Vector3(0, 1.6, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT, KEY_LEFT]:
			clip = posmod(clip + (1 if event.keycode == KEY_RIGHT else -1), CLIPS.size())
			_reproducir()
		elif event.keycode == KEY_SPACE:
			pausa = not pausa
			for ap in jugadores:
				ap.speed_scale = 0.0 if pausa else 1.0
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		angulo -= event.relative.x * 0.006
		_actualizar_camara()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia = maxf(12.0, distancia - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia = minf(65.0, distancia + 2)
		_actualizar_camara()

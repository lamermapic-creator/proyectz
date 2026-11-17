extends Node3D
## Decoración del menú: sin IA, navegación ni combate.
var _luz_roja: OmniLight3D
var _actores: Array[RigPersonaje] = []
var _tiempo := 0.0
var _materiales := {}

func _ready() -> void:
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	var env := ambiente.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111a20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("83979f")
	env.ambient_light_energy = 0.32
	env.fog_enabled = true
	env.fog_light_color = Color("26383d")
	env.fog_density = 0.018
	# Gris suave en la imagen 3D: ambiente apagado sin teñir el HUD.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_brightness = 0.98
	env.adjustment_contrast = 0.98
	add_child(ambiente)
	var luna := DirectionalLight3D.new()
	luna.rotation_degrees = Vector3(-36, -38, 0)
	luna.light_color = Color("97b4be")
	luna.light_energy = 0.95
	luna.shadow_enabled = true
	add_child(luna)
	_luz_roja = OmniLight3D.new()
	_luz_roja.position = Vector3(6, 5.8, 2)
	_luz_roja.light_color = Color("e34d34")
	_luz_roja.light_energy = 3.4
	_luz_roja.omni_range = 17
	add_child(_luz_roja)
	var relleno := OmniLight3D.new()
	relleno.position = Vector3(2, 7, 5)
	relleno.light_color = Color("9bb5b9")
	relleno.light_energy = 1.6
	relleno.omni_range = 18
	add_child(relleno)
	var suelo := _caja(Vector3(0, -0.2, -3), Vector3(70, 0.4, 90), Color("252d2e"))
	var asfalto := ShaderMaterial.new()
	asfalto.shader = preload("res://scripts/ui/suelo_menu.gdshader")
	suelo.material_override = asfalto
	_ampliar_puesto()
	for z in range(-40, 16, 7):
		_caja(Vector3(1, 0.015, z), Vector3(0.10, 0.025, 3.3), Color("8b8b73"))
	for x in [-7.0, 10.0]:
		_caja(Vector3(x, 0.75, -1), Vector3(5, 1.5, 1.1), Color("555750"))
		for i in range(7):
			var raya := _caja(Vector3(x - 2.1 + i * 0.7, 0.83, -0.435), Vector3(0.29, 0.95, 0.025), Color("a68d48"))
			raya.rotation.z = -0.32
	for x in range(-15, 20, 4):
		_caja(Vector3(x, 2.5, -6), Vector3(0.12, 5, 0.12), Color("495556"))
	for y in [0.65, 2.8, 4.5]:
		_caja(Vector3(2, y, -6), Vector3(34, 0.045, 0.045), Color("4e5a5b"))
	for x in range(-15, 20):
		for signo in [-1, 1]:
			var alambre := _caja(Vector3(x, 2.5, -6), Vector3(0.018, 5.1, 0.018), Color("354347"))
			alambre.rotation.z = signo * 0.24
	_caja(Vector3(8, 3.4, -5.82), Vector3(3.5, 1.4, 0.10), Color("343b37"))
	var cartel := Label3D.new()
	cartel.text = "CUARENTENA\nNO PASAR"
	cartel.font_size = 48
	cartel.pixel_size = 0.012
	cartel.modulate = Color("d3c9a7")
	cartel.outline_size = 0
	cartel.position = Vector3(8, 3.4, -5.74)
	add_child(cartel)
	_caja(Vector3(9.8, 3, 0), Vector3(0.16, 6, 0.16), Color("3c4546"))
	var bombilla := _caja(Vector3(9.8, 6.05, 0), Vector3(0.24, 0.24, 0.24), Color("cf3527"))
	var m := bombilla.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color("b53223")
	m.emission_energy_multiplier = 2
	for datos in [[Vector3(4, 3.1, 0), "civil", -12.0], [Vector3(0, 3.1, -10), "obrero", 25.0], [Vector3(10, 3.1, -13), "vagabundo", -30.0]]:
		var actor := RigPersonaje.new()
		actor.modelo = "zombi_" + str(datos[1])
		actor.position = datos[0]
		actor.rotation_degrees.y = 180.0 + float(datos[2])
		add_child(actor)
		_actores.append(actor)
	var camara := Camera3D.new()
	camara.fov = 46
	add_child(camara)
	camara.position = Vector3(8.5, 4.5, 15.5)
	camara.look_at(Vector3(0.5, 2.6, -1))
	camara.current = true

func _caja(pos: Vector3, tam: Vector3, color: Color) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = tam
	obj.mesh = mesh
	obj.position = pos
	var clave := color.to_html()
	if not _materiales.has(clave):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.92
		_materiales[clave] = mat
	obj.material_override = _materiales[clave]
	add_child(obj)
	return obj

func _process(dt: float) -> void:
	_tiempo += minf(dt, 0.1)
	_luz_roja.light_energy = 3.2 + sin(_tiempo * 1.4) * 0.25
	for i in _actores.size():
		var actor := _actores[i]
		var t := _tiempo + i * 2.1
		(actor.M.Waist as RigPersonaje.Motor).transform = Rbx.ang(-0.13 + sin(t * 0.8) * 0.015, 0, 0.025)
		(actor.M.Neck as RigPersonaje.Motor).transform = Rbx.ang(0.12, sin(t * 0.24) * 0.12, 0.09)
		(actor.M.LeftShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.14, 0, -0.08)
		(actor.M.RightShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.22, 0, 0.08)
		actor.aplicar()

func _ampliar_puesto() -> void:
	# Fachadas y ventanales: profundidad sin IA ni cuerpos físicos.
	for lado in [-1.0, 1.0]:
		for i in range(4):
			var x: float = lado * (17.0 + float(i % 2) * 2.0)
			var z := -13.0 - i * 13.0
			var alto := 12.0 + float(i % 3) * 4.0
			_caja(Vector3(x, alto / 2.0, z), Vector3(9, alto, 11), Color("242e32"))
			_caja(Vector3(x, alto, z), Vector3(9.5, 0.35, 11.5), Color("394247"))
			for piso in range(1, int(alto / 3.0)):
				for columna in range(3):
					var ventana := _caja(Vector3(x - 2.8 + columna * 2.8, piso * 3.0, z + 5.53), Vector3(1.45, 1.85, 0.05), Color("111b21"))
					if (piso + columna + i) % 5 == 0:
						var mat := StandardMaterial3D.new()
						mat.albedo_color = Color("766a4c")
						mat.emission_enabled = true
						mat.emission = Color("8e754c")
						mat.emission_energy_multiplier = 0.7
						ventana.material_override = mat
		# Bordillo y acera delimitan la calle.
		_caja(Vector3(lado * 12, 0.10, -12), Vector3(3, 0.22, 65), Color("424849"))
	# Garita con puerta, cristales y marquesina al fondo derecho.
	_caja(Vector3(10, 2.2, -9), Vector3(5.2, 4.4, 4), Color("4c5753"))
	_caja(Vector3(10, 4.5, -8.8), Vector3(6, 0.25, 4.8), Color("283238"))
	_caja(Vector3(9.2, 2.65, -6.96), Vector3(2.6, 1.5, 0.06), Color("18292e"))
	_caja(Vector3(11.3, 1.6, -6.94), Vector3(1.1, 3.1, 0.08), Color("303a3b"))
	for x in [7.5, 12.5]:
		_caja(Vector3(x, 3, -4), Vector3(.12, 6, .12), Color("525c5b"))
	_caja(Vector3(10, 6, -4), Vector3(5.4, .18, .25), Color("525c5b"))
	var foco := SpotLight3D.new()
	foco.position = Vector3(10, 5.8, -3.9)
	foco.light_color = Color("e2c99a")
	foco.light_energy = 7.0
	foco.spot_range = 23.0
	foco.spot_angle = 52.0
	foco.shadow_enabled = true
	add_child(foco)
	foco.look_at(Vector3(4, 0, 2))
	# Luminarias prácticas, no luces por cada ventana.
	for z in [-15.0, -29.0]:
		_caja(Vector3(-10, 5, z), Vector3(.15, 10, .15), Color("3c4546"))
		_caja(Vector3(-8.5, 9.8, z), Vector3(3, .12, .15), Color("3c4546"))
		var luz := OmniLight3D.new()
		luz.position = Vector3(-7, 9.5, z)
		luz.light_color = Color("acbaba")
		luz.light_energy = 2.6
		luz.omni_range = 16
		add_child(luz)
	# Cajas de suministro, palés y sacos alrededor del control.
	for i in range(6):
		var x := 11.5 + float(i % 3) * .9
		var y := .45 + float(i / 3) * .85
		_caja(Vector3(x, y, -1.8), Vector3(.8, .8, .9), Color("615e4b"))
		_caja(Vector3(x, y, -1.34), Vector3(.08, .8, .015), Color("302f29"))
	var azar := RandomNumberGenerator.new()
	azar.seed = 56192
	for i in range(32):
		var resto := _caja(Vector3(azar.randf_range(-10, 13), .04, azar.randf_range(-9, 8)), Vector3(azar.randf_range(.12, .38), .02, azar.randf_range(.18, .46)), Color("6e756c"))
		resto.rotation.y = azar.randf_range(-PI, PI)

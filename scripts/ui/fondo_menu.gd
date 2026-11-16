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
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color("26383d")
	env.fog_density = 0.018
	add_child(ambiente)
	var luna := DirectionalLight3D.new()
	luna.rotation_degrees = Vector3(-36, -38, 0)
	luna.light_color = Color("97b4be")
	luna.light_energy = 0.75
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
	_caja(Vector3(0, -0.2, -3), Vector3(70, 0.4, 90), Color("252d2e"))
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

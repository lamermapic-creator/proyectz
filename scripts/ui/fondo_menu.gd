extends Node3D
## Corredor de descontaminación del menú. Los actores son rigs decorativos.
var _actores: Array[RigPersonaje] = []
var _tiempo := 0.0
var _camara: Camera3D
var _baliza: OmniLight3D
var _materiales := {}


func _ready() -> void:
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	ambiente.environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10141d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("778aa8")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_radius = 1.5
	env.glow_intensity = 0.36
	env.fog_enabled = true
	env.fog_light_color = Color("3f5265")
	env.fog_density = 0.031
	add_child(ambiente)
	_construir_corredor()
	var rim := _luz(Vector3(2.1, 7.0, -6.4), Color("74c7ff"), 6.2, 23.0)
	rim.shadow_enabled = true
	var emergencia := _luz(Vector3(7.1, 5.6, -13), Color("ff6d36"), 7.6, 21.0)
	emergencia.shadow_enabled = true
	_baliza = _luz(Vector3(8.2, 3.2, -0.8), Color("fb3d23"), 3.0, 10.0)
	_luz(Vector3(1.5, 4.0, 3.5), Color("8eadc5"), 2.6, 18.0)
	_poner_actor("sanitario", Vector3(5.0, 3.1, -3.7), 154.0)
	_poner_actor("policia", Vector3(1.5, 3.1, -13.5), 172.0)
	_poner_actor("obrero", Vector3(7.0, 3.1, -20.5), 207.0)
	_camara = Camera3D.new()
	_camara.fov = 47.0
	add_child(_camara)
	_encuadrar()
	_camara.current = true


func _construir_corredor() -> void:
	var pavimento := _caja(Vector3(0, -0.22, -12), Vector3(29, 0.44, 53), Color("312f35"))
	var asfalto := ShaderMaterial.new()
	asfalto.shader = preload("res://scripts/ui/suelo_menu.gdshader")
	pavimento.material_override = asfalto
	_caja(Vector3(0, 8.2, -14), Vector3(24, 0.45, 48), Color("1c252f"))
	_caja(Vector3(10.8, 3.9, -14), Vector3(0.5, 8.0, 48), Color("343e48"))
	_caja(Vector3(-10.8, 3.9, -14), Vector3(0.5, 8.0, 48), Color("232a34"))
	_caja(Vector3(0, 4, -33), Vector3(23, 8.0, 0.6), Color("323942"))
	for z in [1.0, -6.0, -13.0, -20.0, -27.0]:
		for x in [-9.8, 9.8]:
			_caja(Vector3(x, 3.9, z), Vector3(0.54, 7.8, 0.70), Color("63717a"))
			_caja(Vector3(x, 0.42, z), Vector3(0.8, 0.85, 0.87), Color("323b43"))
		_caja(Vector3(0, 7.6, z), Vector3(20, 0.48, 0.72), Color("414f5e"))
		_caja(Vector3(3.5, 7.3, z + 0.18), Vector3(4.8, 0.07, 0.25), Color("a9eaff"), true)
		_caja(Vector3(10.47, 1.18, z - 2.8), Vector3(0.08, 2.2, 4.9), Color("242f39"))
		_caja(Vector3(10.4, 1.1, z - 2.8), Vector3(0.07, 0.20, 4.9), Color("976348"))
	for x in [-8.6, 8.6]:
		_caja(Vector3(x, 0.012, -13.0), Vector3(0.12, 0.024, 37.0), Color("af8751"))
		_caja(Vector3(x, 6.8, -13.5), Vector3(0.23, 0.24, 37.0), Color("586471"))
	for i in 12:
		var x := -5.2 + i * 0.9
		var raya := _caja(Vector3(x, 0.022, -10), Vector3(0.42, 0.026, 1.2), Color("997143"))
		raya.rotation.y = 0.33
	_caja(Vector3(2.2, 3.1, -31.9), Vector3(9, 6.2, 0.36), Color("3e4650"))
	for fila in 12:
		_caja(Vector3(2.2, 0.35 + fila * 0.48, -31.68), Vector3(8.7, 0.055, 0.085), Color("222a32"))
	for x in [-2.5, 6.9]:
		_caja(Vector3(x, 3.0, -31.5), Vector3(0.19, 5.9, 0.14), Color("ff793e"), true)
	_caja(Vector3(2.2, 6.85, -31.55), Vector3(7.8, 0.82, 0.13), Color("19222a"))
	var cartel := Label3D.new()
	cartel.text = "DESCONTAMINACIÓN"
	cartel.font_size = 52
	cartel.pixel_size = 0.018
	cartel.outline_size = 0
	cartel.modulate = Color("f5b98d")
	cartel.position = Vector3(2.2, 6.85, -31.45)
	add_child(cartel)
	# Módulos de cobertura y mangueras cuadradas en el primer plano.
	for i in 3:
		var z := -0.8 - i * 2.2
		_caja(Vector3(9.1, 0.54, z), Vector3(1.05, 1.08, 1.50), Color("465859"))
		_caja(Vector3(9.1, 1.1, z), Vector3(1.12, 0.13, 1.56), Color("687672"))
		_caja(Vector3(8.56, 0.72, z), Vector3(0.055, 0.26, 0.75), Color("b39966"))
	_caja(Vector3(8.3, 3.1, -0.8), Vector3(0.12, 0.19, 0.39), Color("ff6238"), true)


func _caja(pos: Vector3, tam: Vector3, color: Color, emite := false) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = tam
	obj.mesh = mesh
	obj.position = pos
	var clave := color.to_html() + str(emite)
	if not _materiales.has(clave):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.76
		if emite:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 2.1
		_materiales[clave] = mat
	obj.material_override = _materiales[clave]
	add_child(obj)
	return obj


func _luz(pos: Vector3, color: Color, potencia: float, alcance: float) -> OmniLight3D:
	var luz := OmniLight3D.new()
	luz.position = pos
	luz.light_color = color
	luz.light_energy = potencia
	luz.omni_range = alcance
	add_child(luz)
	return luz


func _poner_actor(variante: String, pos: Vector3, giro: float) -> void:
	var actor := RigPersonaje.new()
	actor.modelo = "zombi_" + variante
	actor.position = pos
	actor.rotation_degrees.y = giro
	add_child(actor)
	_actores.append(actor)


func _encuadrar() -> void:
	_camara.position = Vector3(0.8 + sin(_tiempo * 0.15) * 0.42, 3.25, 8.5)
	_camara.look_at(Vector3(1.35, 3.4, -11.0))


func _process(dt: float) -> void:
	_tiempo += minf(dt, 0.1)
	_encuadrar()
	_baliza.light_energy = 2.4 + 1.3 * pow(0.5 + 0.5 * sin(_tiempo * 2.0), 3.0)
	for i in _actores.size():
		var actor := _actores[i]
		var t := _tiempo + i * 2.1
		(actor.M.Waist as RigPersonaje.Motor).transform = Rbx.ang(-0.21 + sin(t * 0.8) * 0.025, 0, 0.065)
		(actor.M.Neck as RigPersonaje.Motor).transform = Rbx.ang(0.17, sin(t * 0.31) * 0.16, -0.12)
		(actor.M.LeftShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.12, 0, -0.08)
		(actor.M.RightShoulder as RigPersonaje.Motor).transform = Rbx.ang(0.28, 0, 0.11)
		actor.aplicar()

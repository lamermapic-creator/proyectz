extends Node3D
## Bodegón del menú. El arma es una malla de exhibición del modelo del juego.
const TABLERO_Y := 2.4
# X, giro sobre Y, Z.
const CASQUILLOS := [Vector3(2.97, 0.7, 0.92), Vector3(3.35, -0.5, 1.02), Vector3(3.0, -1.1, 1.37)]
var _camara: Camera3D
var _tiempo := 0.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101215")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("75879b")
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_radius = 0.55
	env.glow_intensity = 0.24
	var entorno := WorldEnvironment.new()
	entorno.environment = env
	add_child(entorno)
	_habitacion()
	_posar_arma()
	_iluminar()
	_camara = Camera3D.new()
	_camara.fov = 39.0
	_camara.near = 0.6
	_camara.far = 38.0
	add_child(_camara)
	_encuadrar()
	_camara.current = true


func _material(color: Color, rugosidad: float, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rugosidad
	mat.metallic = metal
	return mat


func _caja(pos: Vector3, tam: Vector3, mat: Material) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tam
	nodo.mesh = malla
	nodo.position = pos
	nodo.material_override = mat
	add_child(nodo)
	return nodo


func _habitacion() -> void:
	var muro := _material(Color("333a3d"), 0.94)
	_caja(Vector3(0, -0.2, 0), Vector3(40, 0.4, 35), muro)
	_caja(Vector3(0, 4.0, -4.6), Vector3(27, 8, 0.35), muro)
	var acero := _material(Color("414245"), 0.49, 0.5)
	var madera := ShaderMaterial.new()
	madera.shader = preload("res://scripts/ui/tablero_menu.gdshader")
	madera.set_shader_parameter("casquillos", PackedVector3Array(CASQUILLOS))
	var mesa := _caja(Vector3(0, TABLERO_Y - 0.13, 0), Vector3(12, 0.26, 6.2), madera)
	mesa.name = "Mesa"
	for x in [-5.5, 5.5]:
		for z in [-2.65, 2.65]:
			_caja(Vector3(x, 1.1, z), Vector3(0.21, 2.2, 0.23), acero)
	_caja(Vector3(0, 2.12, 2.92), Vector3(11.8, 0.20, 0.19), acero)
	# Lámpara industrial fuera del centro del encuadre.
	_caja(Vector3(4.65, 2.46, -2.39), Vector3(0.85, 0.12, 0.64), acero)
	_caja(Vector3(4.77, 3.38, -2.55), Vector3(0.10, 1.80, 0.1), acero)
	_caja(Vector3(4.32, 4.3, -2.48), Vector3(1.02, 0.24, 0.54), acero)
	var tubo := _material(Color("ffe0af"), 0.33)
	tubo.emission_enabled = true
	tubo.emission = Color("ffcc8f")
	tubo.emission_energy_multiplier = 2.0
	_caja(Vector3(4.25, 4.163, -2.46), Vector3(0.72, 0.04, 0.28), tubo)
	# Un cuaderno usado, con cubierta oscura y canto de papel.
	var papel := _material(Color("978c73"), 0.93)
	var cubierta := _material(Color("343b32"), 0.85)
	_caja(Vector3(4.32, 2.456, 1.17), Vector3(1.12, 0.09, 1.5), papel).rotation.y = -0.2
	_caja(Vector3(4.32, 2.514, 1.17), Vector3(1.15, 0.025, 1.53), cubierta).rotation.y = -0.2
	var laton := _material(Color("9b702d"), 0.32, 0.65)
	for datos in CASQUILLOS:
		var casquillo := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = 0.039
		malla.bottom_radius = 0.044
		malla.height = 0.27
		malla.radial_segments = 12
		casquillo.mesh = malla
		casquillo.material_override = laton
		# Inclina el cilindro primero y después gíralo alrededor de la vertical.
		casquillo.basis = Basis(Vector3.UP, datos.y) * Basis(Vector3.RIGHT, PI * 0.5)
		casquillo.position = Vector3(datos.x, TABLERO_Y + malla.bottom_radius - 0.001, datos.z)
		add_child(casquillo)


func _posar_arma() -> void:
	var arma := Armas.construir_modelo("Rifle")
	arma.name = "RifleExpuesto"
	arma.position = Vector3(2.2, TABLERO_Y, 0)
	arma.basis = Basis(Vector3.UP, -1.08) * Basis(Vector3.FORWARD, PI * 0.5)
	arma.scale = Vector3.ONE * 1.44
	add_child(arma)
	var fondo := INF
	for nodo in arma.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		# El corte del receptor y el cargador tienen superficies que se solapan.
		# Se separan solo en la copia de exhibición.
		if pieza.name in ["Lower", "MagUpper"] and pieza.mesh is BoxMesh:
			var caja_pieza := pieza.mesh.duplicate() as BoxMesh
			caja_pieza.size.x -= 0.004
			pieza.mesh = caja_pieza
		var mat := (pieza.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.roughness = maxf(mat.roughness, 0.46)
		pieza.material_override = mat
		var caja := pieza.global_transform * pieza.get_aabb()
		fondo = minf(fondo, caja.position.y)
	if is_finite(fondo):
		arma.position.y += TABLERO_Y + 0.009 - fondo


func _iluminar() -> void:
	var lampara := SpotLight3D.new()
	lampara.position = Vector3(4.25, 4.09, -2.46)
	lampara.light_color = Color("ffd19a")
	lampara.light_energy = 7.2
	lampara.spot_range = 13.0
	lampara.spot_angle = 57.0
	lampara.shadow_enabled = true
	lampara.shadow_bias = 0.055
	lampara.shadow_normal_bias = 0.42
	lampara.shadow_blur = 1.55
	lampara.light_size = 0.14
	add_child(lampara)
	lampara.look_at(Vector3(2.45, TABLERO_Y, 0.05))
	var relleno := OmniLight3D.new()
	relleno.position = Vector3(0.2, 5.5, 3.2)
	relleno.light_color = Color("89b9dd")
	relleno.light_energy = 5.0
	relleno.omni_range = 12
	add_child(relleno)


func _encuadrar() -> void:
	_camara.position = Vector3(0.4 + sin(_tiempo * 0.17) * 0.18, 7.0, 7.65)
	_camara.look_at(Vector3(0.3, 2.44, -0.35))


func _process(dt: float) -> void:
	_tiempo += dt
	_encuadrar()

extends Node3D
## Valle decorativo generado de forma determinista. Solo mallas y un entorno de render.
const PASO := 2.5
const COLUMNAS := 173
const FILAS := 173
const ORIGEN := Vector2(-215, -405)
const PUNTOS := [
	Vector4(-124, -155, 87, 3.0), Vector4(-188, -255, 132, 4.3),
	Vector4(-103, -315, 156, 5.0), Vector4(8, -350, 146, 4.7),
	Vector4(84, -310, 178, 4.0), Vector4(145, -265, 146, 4.7),
	Vector4(152, -171, 104, 5.2), Vector4(123, -90, 49, 5.0),
]
var _ruido := FastNoiseLite.new()
var _camara: Camera3D
var _tiempo := 0.0


func _ready() -> void:
	_ruido.seed = 6143
	_ruido.frequency = 0.033
	_entorno()
	_terreno()
	_lago()
	_bosque()
	_camara = Camera3D.new()
	_camara.fov = 50.0
	_camara.far = 780.0
	add_child(_camara)
	_encuadrar()
	_camara.current = true


func _entorno() -> void:
	var cielo := ShaderMaterial.new()
	cielo.shader = preload("res://scripts/ui/cielo_menu.gdshader")
	var sky := Sky.new()
	sky.sky_material = cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9baeca")
	env.ambient_light_energy = 0.66
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color("818faa")
	env.fog_density = 0.0026
	env.fog_sun_scatter = 0.19
	env.fog_sky_affect = 0.32
	var mundo := WorldEnvironment.new()
	mundo.environment = env
	add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-15, -151, 0)
	sol.light_color = Color("ffd2a1")
	sol.light_energy = 1.55
	sol.light_angular_distance = 1.5
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 200.0
	add_child(sol)


func _altura(x: float, z: float) -> float:
	var valle := absf(x - 13.0 * sin(z * 0.017))
	var costa := smoothstep(31.0, 83.0, valle)
	var ruido := _ruido.get_noise_2d(x, z)
	var wx := x + _ruido.get_noise_2d(x * 0.48 + 250, z * 0.48) * 24.0
	var wz := z + _ruido.get_noise_2d(z * 0.41 - 120, x * 0.41) * 22.0
	var montana := 0.0
	for p: Vector4 in PUNTOS:
		var dx := (wx - p.x) / (p.w * 14.0)
		var dz := (wz - p.y + dx * 23.0) / (p.w * 17.0)
		montana = maxf(montana, p.z * 0.81 * exp(-0.80 * (dx * dx + dz * dz)))
	var quebrada := absf(_ruido.get_noise_2d(x * 0.73 + 90, z * 0.73))
	var grava := _ruido.get_noise_2d(x * 2.6, z * 2.6)
	var relieve := (ruido * 23.0 - quebrada * 25.0 + grava * 5.0) * smoothstep(8.0, 72.0, montana)
	var perfil_valle := maxf(smoothstep(22.0, 78.0, valle), 1.0 - smoothstep(-290.0, -220.0, z))
	var ladera := costa * (10.0 + ruido * 12.0) + (montana + relieve) * perfil_valle
	var mirador := 24.0 * smoothstep(-49.0, 13.0, z) * (1.0 - smoothstep(-16.0, 33.0, x))
	return -3.0 + ladera + mirador + ruido * 3.0


func _terreno() -> void:
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	for fila in FILAS:
		var z := ORIGEN.y + fila * PASO
		for columna in COLUMNAS:
			var x := ORIGEN.x + columna * PASO
			vertices.append(Vector3(x, _altura(x, z), z))
			var dx := _altura(x - 1, z) - _altura(x + 1, z)
			var dz := _altura(x, z - 1) - _altura(x, z + 1)
			normales.append(Vector3(dx, 2.0, dz).normalized())
			if fila < FILAS - 1 and columna < COLUMNAS - 1:
				var i := fila * COLUMNAS + columna
				indices.append_array([i, i + 1, i + COLUMNAS, i + 1, i + COLUMNAS + 1, i + COLUMNAS])
	var datos := []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = vertices
	datos[Mesh.ARRAY_NORMAL] = normales
	datos[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	var terreno := MeshInstance3D.new()
	terreno.name = "TerrenoAlpino"
	terreno.mesh = malla
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/terreno_menu.gdshader")
	terreno.material_override = material
	add_child(terreno)


func _lago() -> void:
	var lago := MeshInstance3D.new()
	lago.name = "LagoAlpino"
	var plano := PlaneMesh.new()
	plano.size = Vector2(390, 395)
	lago.mesh = plano
	lago.position = Vector3(0, 0.1, -183)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/agua_menu.gdshader")
	lago.material_override = material
	add_child(lago)


func _bosque() -> void:
	var malla := SurfaceTool.new()
	malla.begin(Mesh.PRIMITIVE_TRIANGLES)
	for nivel in 10:
		var y := 0.45 + nivel * 0.38
		var radio := 1.3 * (1.0 - nivel * 0.087)
		for i in 14:
			var a := i * TAU / 14.0 + nivel * 0.73
			var b := a + TAU / 14.0
			var r0 := radio * (1.0 if i % 2 == 0 else 0.62) * (0.93 + 0.13 * sin(a * 3.0))
			var r1 := radio * (0.62 if i % 2 == 0 else 1.0) * (0.93 + 0.13 * sin(b * 3.0))
			var verde := Color("1b352c").lerp(Color("4c6547"), float((i + nivel) % 5) / 8.0)
			for v in [Vector3(cos(a) * r0, y + 0.10 * sin(i), sin(a) * r0),
				Vector3(0.07 * sin(nivel), y + 0.96, 0), Vector3(cos(b) * r1, y + 0.10 * sin(i + 1), sin(b) * r1)]:
				malla.set_color(verde)
				malla.add_vertex(v)
	malla.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	malla.set_material(mat)
	var bosque := MultiMesh.new()
	bosque.mesh = malla.commit()
	bosque.transform_format = MultiMesh.TRANSFORM_3D
	var azar := RandomNumberGenerator.new()
	azar.seed = 2121
	var poses: Array[Transform3D] = []
	for i in 8400:
		var x := azar.randf_range(-200, 200)
		var z := azar.randf_range(-325, 18)
		var altura := _altura(x, z)
		if (z > 1.0 and absf(x + 22.0) < 8.0) or altura < 1.1 or altura > 60.0 or absf(_altura(x + 1, z) - altura) > 0.85:
			continue
		var escala := azar.randf_range(0.62, 1.51)
		var base := Basis(Vector3.UP, azar.randf_range(0, TAU)).scaled(Vector3(escala, escala, escala))
		poses.append(Transform3D(base, Vector3(x, altura, z)))
	bosque.instance_count = poses.size()
	for i in poses.size():
		bosque.set_instance_transform(i, poses[i])
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = bosque
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)


func _encuadrar() -> void:
	_camara.position = Vector3(-20.0 + sin(_tiempo * 0.11) * 0.9, 34.0, 12.0)
	_camara.look_at(Vector3(2.0, 42.0, -172.0))


func _process(dt: float) -> void:
	_tiempo += dt
	_encuadrar()

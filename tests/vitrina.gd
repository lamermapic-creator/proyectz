extends Node3D
## Vitrina de armas: muestra cada modelo de lado (para revisar los modelos). Un arma cada 8 fotogramas.
## --arma=<nombre> para ver solo una (vista de 3/4 que gira).
var armas: Array = []
var i := 0
var f := 0
var actual: Node3D
var cam: Camera3D
var solo := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arma="):
			solo = a.split("=")[1]
	armas = [solo] if solo != "" else Armas.todas()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.64, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 50, 0)
	sol.light_energy = 1.4
	add_child(sol)
	var sol2 := DirectionalLight3D.new()
	sol2.rotation_degrees = Vector3(-20, -140, 0)
	sol2.light_energy = 0.5
	add_child(sol2)
	cam = Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.current = true
	_poner()

var pivote: Node3D

func _poner() -> void:
	if pivote:
		pivote.queue_free()
	pivote = Node3D.new()
	add_child(pivote)
	actual = Armas.construir_modelo(armas[i])
	pivote.add_child(actual)
	# caja del arma en su propio espacio (las piezas de los grupos también)
	var caja := AABB()
	var prim := true
	for n in actual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t := mi.transform
		var pa := mi.get_parent() as Node3D
		while pa != actual:
			t = pa.transform * t
			pa = pa.get_parent() as Node3D
		var bb := t * mi.get_aabb()
		if prim:
			caja = bb
			prim = false
		else:
			caja = caja.merge(bb)
	actual.position = -caja.get_center()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(caja.size.z, caja.size.y * 1.8) * 1.15
	cam.position = Vector3(10, 0.0, 0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	print("VITRINA ", armas[i], " piezas=", actual.find_children("*", "MeshInstance3D", true, false).size())

func _process(_dt: float) -> void:
	f += 1
	if solo != "":
		pivote.rotation.y = f * 0.04
		if f > 160:
			get_tree().quit()
		return
	if f % 8 == 0:
		i += 1
		if i >= armas.size():
			get_tree().quit()
			return
		_poner()

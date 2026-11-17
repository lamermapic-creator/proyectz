@tool
extends Node3D
## Nivel de pruebas de movimiento. Se construye solo (en el editor y al jugar).
## Bloques de 0.2 a 2 m, rampas de 15/30/50 grados, escalera de 18 cm,
## tuneles de 1.4 m y 0.8 m, pared para probar la camara y postes cada 10 m.

const GRIS := Color(0.55, 0.56, 0.58)
const GRIS_OSCURO := Color(0.32, 0.33, 0.35)
const NARANJA := Color(0.9, 0.45, 0.15)
const AZUL := Color(0.25, 0.45, 0.8)
const VERDE := Color(0.3, 0.6, 0.3)
## Las medidas de este archivo están en metros; el juego usa studs (como en Roblox): 1 m = 3.2258 studs
const M := 1.0 / 0.31

@export var reconstruir := false:
	set(v):
		if v:
			_construir()

var _mats := {}


func _ready() -> void:
	if get_node_or_null("Geometria") == null:
		_construir()
	if not Engine.is_editor_hint() and not has_meta("sin_maniquies"):
		_crear_maniquies()
		_crear_zombis()
	if not Engine.is_editor_hint() and not has_meta("sin_motos"):
		_crear_motos()


## motos (v0.4, scripts/vehiculos/moto.gd): una junto al inicio (mirando a -X, hacia campo abierto) y dos
## en la zona de motos
func _crear_motos() -> void:
	var cont := Node3D.new()
	cont.name = "Motos"
	add_child(cont)
	for d in [[Vector3(-8, 0, -4), 90.0], [Vector3(4, 0, -30), 0.0], [Vector3(8, 0, -30), 0.0]]:
		var m := Moto.new()
		m.name = "Moto_%d" % cont.get_child_count()
		m.position = d[0] * M
		m.rotation_degrees = Vector3(0, d[1], 0)
		cont.add_child(m)


## zombis de prueba (solo al jugar; ver docs/RUIDO_Y_ZOMBIS.md). El director hornea la navegación
## siempre; los zombis por defecto se omiten con la meta "sin_zombis" (lo usan las pruebas automáticas).
func _crear_zombis() -> void:
	var dz := DirectorZombis.new()
	dz.name = "Zombis"
	add_child(dz)
	dz.preparar(get_node("Geometria"))
	if has_meta("sin_zombis"):
		return
	# [pies en metros, giro]: tras la pared alta (probar que las paredes tapan el ruido), junto a la
	# cornisa, en una esquina y más allá de la zona de tiro (disparar ahí los atrae)
	for d in [[Vector3(2, 0, 26), 180.0], [Vector3(-30, 0, -14), 90.0], [Vector3(-15, 0, 32), 0.0],
			[Vector3(58, 0, 8), 90.0]]:
		dz.crear_zombi(d[0] * M, d[1])


## muñecos de prueba para el combate (solo al jugar)
func _crear_maniquies() -> void:
	var cont := Node3D.new()
	cont.name = "Maniquies"
	add_child(cont)
	# [posición en metros, giro]: a 7, 13 y 21 m de la barrera, y uno cerca para golpear
	for d in [[Vector3(32, 0, 0), 90.0], [Vector3(38, 0, 3), 90.0], [Vector3(46, 0, -3), 90.0],
			[Vector3(29, 0, 6), 90.0], [Vector3(8, 0, -3), 180.0]]:
		var m := Maniqui.new()
		m.name = "Maniqui_%d" % cont.get_child_count()
		m.position = d[0] * M
		m.rotation_degrees = Vector3(0, d[1], 0)
		cont.add_child(m)


func _construir() -> void:
	var viejo := get_node_or_null("Geometria")
	if viejo:
		remove_child(viejo)
		viejo.free()
	var g := Node3D.new()
	g.name = "Geometria"
	add_child(g)

	# Suelo 200 x 200 m con cuadricula de 1 m
	_caja(g, "Suelo", Vector3(0, -0.5, 0), Vector3(200, 1, 200), _mat_cuadricula())

	# Bloques de distintas alturas (subir, saltar, vault)
	var alturas := [0.2, 0.4, 0.6, 0.9, 1.2, 1.5, 2.0]
	for i in alturas.size():
		var h: float = alturas[i]
		_caja(g, "Bloque_%dcm" % int(h * 100), Vector3(-12 + i * 3.0, h * 0.5, -10), Vector3(2, h, 2), _mat(NARANJA))

	# Rampas de 15, 30 y 50 grados
	var angulos := [15.0, 30.0, 50.0]
	for i in angulos.size():
		_rampa(g, angulos[i], Vector3(10 + i * 6.0, 0, -12))

	# Escalera: 12 escalones de 18 cm x 30 cm
	for i in 12:
		var alto := 0.18 * (i + 1)
		_caja(g, "Escalon_%d" % i, Vector3(-20, alto * 0.5, 4 + i * 0.3), Vector3(3, alto, 0.3), _mat(GRIS))
	_caja(g, "Descanso", Vector3(-20, 1.08, 9.1), Vector3(3, 2.16, 3), _mat(GRIS))

	# Tuneles: 1.4 m (agachado) y 0.8 m (tumbado)
	_tunel(g, "Tunel_1_4m", Vector3(4, 0, 10), 1.4)
	_tunel(g, "Tunel_0_8m", Vector3(12, 0, 10), 0.8)

	# Pared alta para probar la colision de la camara
	_caja(g, "Pared", Vector3(0, 2, 20), Vector3(16, 4, 0.4), _mat(GRIS_OSCURO))

	# Postes cada 10 m para medir distancias
	for x in range(-50, 51, 10):
		for z in [-40, 40]:
			_caja(g, "Poste_%d_%d" % [x, z], Vector3(x, 1.5, z), Vector3(0.2, 3, 0.2), _mat(AZUL), false)

	# Mesa y muro bajo para apoyar el arma (80 cm y 1.1 m)
	_caja(g, "Mesa_80cm", Vector3(-6, 0.4, 14), Vector3(2.5, 0.8, 1), _mat(VERDE))
	_caja(g, "Muro_110cm", Vector3(-2, 0.55, 14), Vector3(2.5, 1.1, 0.3), _mat(VERDE))
	# muro alto (1.3 m): para apoyar el arma de pie
	_caja(g, "Muro_130cm", Vector3(2, 0.65, 14), Vector3(2.5, 1.3, 0.3), _mat(VERDE))

	# Muro para colgarse de la cornisa (2.5 m, en L: esquinas exteriores e interior)
	_caja(g, "Cornisa_A", Vector3(-35, 1.25, -25), Vector3(10, 2.5, 2), _mat(Color(0.6, 0.5, 0.42)))
	_caja(g, "Cornisa_B", Vector3(-39, 1.25, -20), Vector3(2, 2.5, 8), _mat(Color(0.6, 0.5, 0.42)))

	# Zona de tiro: barrera para apoyar el arma (1 m) mirando a los muñecos
	_caja(g, "Barrera_tiro", Vector3(26, 0.5, 0), Vector3(0.3, 1.0, 3.0), _mat(GRIS))
	_caja(g, "Linea_tiro", Vector3(25, 0.005, 0), Vector3(0.1, 0.01, 12), _mat(Color(0.85, 0.75, 0.2)), false)

	# Zona de motos (v0.4): dos rampas de salto (12° y 20°) y un muro para probar los choques
	_rampa_salto(g, 12.0, 6.0, Vector3(5, 0, -48))
	_rampa_salto(g, 20.0, 5.0, Vector3(15, 0, -48))
	_caja(g, "Muro_choque", Vector3(30, 1.5, -62), Vector3(14, 3, 0.5), _mat(GRIS_OSCURO))

	# Luz y ambiente
	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.shadow_enabled = true
	sol.light_energy = 1.2
	g.add_child(sol)

	var we := WorldEnvironment.new()
	we.name = "Ambiente"
	var env := Environment.new()
	var cielo := Sky.new()
	cielo.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	# Gris suave en la imagen 3D: ambiente apagado sin teñir el HUD.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_brightness = 0.98
	env.adjustment_contrast = 0.98
	we.environment = env
	g.add_child(we)


func _caja(padre: Node, nombre: String, pos: Vector3, tam: Vector3, mat: Material, con_colision := true) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = pos * M
	tam = tam * M
	padre.add_child(cuerpo)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	cuerpo.add_child(mi)
	if con_colision:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = tam
		cs.shape = sh
		cuerpo.add_child(cs)
	return cuerpo


func _rampa(padre: Node, grados: float, base: Vector3) -> void:
	var largo := 6.0
	var a := deg_to_rad(grados)
	var alto := sin(a) * largo
	var cuerpo := _caja(padre, "Rampa_%d" % int(grados), Vector3.ZERO, Vector3(3, 0.3, largo), _mat(GRIS))
	cuerpo.rotation.x = a
	cuerpo.position = (base + Vector3(0, alto * 0.5 - 0.1, -cos(a) * largo * 0.5)) * M
	# Plataforma arriba
	_caja(padre, "Plataforma_%d" % int(grados), base + Vector3(0, alto * 0.5, -cos(a) * largo - 1.5), Vector3(3, alto, 3), _mat(GRIS))


## rampa para saltar con la moto (sube hacia -Z, sin plataforma arriba)
func _rampa_salto(padre: Node, grados: float, largo: float, base: Vector3) -> void:
	var a := deg_to_rad(grados)
	var alto := sin(a) * largo
	var cuerpo := _caja(padre, "RampaSalto_%d" % int(grados), Vector3.ZERO, Vector3(3.5, 0.3, largo), _mat(Color(0.75, 0.6, 0.3)))
	cuerpo.rotation.x = a
	cuerpo.position = (base + Vector3(0, alto * 0.5 - 0.1, -cos(a) * largo * 0.5)) * M
	# el hueco de debajo, cerrado (para que no se meta nada debajo de la rampa)
	var relleno := _caja(padre, "RampaSaltoBase_%d" % int(grados), base + Vector3(0, alto * 0.25, -cos(a) * largo * 0.8), Vector3(3.3, alto * 0.5, cos(a) * largo * 0.4), _mat(Color(0.5, 0.4, 0.25)))
	relleno.name = "RampaSaltoBase_%d" % int(grados)


func _tunel(padre: Node, nombre: String, pos: Vector3, alto_libre: float) -> void:
	var largo := 6.0
	var ancho := 2.0
	var grosor := 0.3
	var t := Node3D.new()
	t.name = nombre
	t.position = pos * M
	padre.add_child(t)
	_caja(t, "Techo", Vector3(0, alto_libre + grosor * 0.5, 0), Vector3(ancho + grosor * 2, grosor, largo), _mat(GRIS_OSCURO))
	_caja(t, "ParedIzq", Vector3(-(ancho + grosor) * 0.5, alto_libre * 0.5, 0), Vector3(grosor, alto_libre, largo), _mat(GRIS_OSCURO))
	_caja(t, "ParedDer", Vector3((ancho + grosor) * 0.5, alto_libre * 0.5, 0), Vector3(grosor, alto_libre, largo), _mat(GRIS_OSCURO))


func _mat(c: Color) -> StandardMaterial3D:
	if _mats.has(c):
		return _mats[c]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	_mats[c] = m
	return m


func _mat_cuadricula() -> StandardMaterial3D:
	# Cuadricula de 1 m generada por codigo (proyeccion triplanar en mundo)
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.44, 0.42))
	for i in 64:
		for j in 2:
			img.set_pixel(i, j, Color(0.3, 0.32, 0.3))
			img.set_pixel(j, i, Color(0.3, 0.32, 0.3))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.31 # cuadros de 1 m
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

extends SceneTree
func _initialize() -> void:
	probar.call_deferred()
func probar() -> void:
	var mundo := (load("res://escenas/pruebas_movimiento.tscn") as PackedScene).instantiate()
	root.add_child(mundo)
	current_scene = mundo
	var rampa: StaticBody3D = mundo.find_child("Rampa_50", true, false)
	var m: Moto = mundo.get_node("Motos/Moto_2")
	await physics_frame
	var base := rampa.global_position
	m.global_position = base + Vector3.UP * 3.0
	m.rumbo = 0.0
	m.piloto = Node.new()
	m.add_child(m.piloto)
	m.motor_on = true
	m.aparcada = false
	m._poner_en_el_suelo()
	m.cabeceo = deg_to_rad(50)
	m.cab_suelo = m.cabeceo
	m._pend_del = m.cabeceo
	m._pend_tras = m.cabeceo
	m.global_position.y += ModeloMoto.R_RUEDA * (1.0 / cos(m.cabeceo) - cos(m.cabeceo))
	m.apoyo = 2
	m.en_aire = false
	for i in 240:
		await process_frame
		m.paso(1.0/60.0, {"freno":1.0})
	var salio := m.global_position.y < 1.0 and m.global_position.z > -12.0 / 0.31
	print("MOTO_REVERSA_RAMPA salió=", salio, " posición=", m.global_position)
	quit(0 if salio else 1)

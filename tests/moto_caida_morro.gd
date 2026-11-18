extends SceneTree
func _initialize() -> void:
	probar.call_deferred()
func probar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var suelo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(120, 0.12, 120)
	forma.shape = caja
	suelo.add_child(forma)
	suelo.position.y = -0.06
	mundo.add_child(suelo)
	var m := Moto.new()
	mundo.add_child(m)
	await physics_frame
	await process_frame
	m.global_position = Vector3(0, 8, 25)
	m.aparcada = false
	m.cabeceo = -0.98
	m.cab_w = -0.7
	m.apoyo = 0
	m.en_aire = true
	m.vel_h = m.adelante() * 31.0
	m.vel_v = -43.0
	var fisico := false
	var minimo := 100.0
	var giro := 0.0
	for i in 145:
		await physics_frame
		await process_frame
		if is_instance_valid(m._fisica):
			fisico = true
			giro = maxf(giro, m._fisica.angular_velocity.length())
			minimo = minf(minimo, m._fisica.global_position.y)
	var ok := fisico and giro > 3.0 and minimo > -0.45
	print("MOTO_MORRO_FISICA ok=", ok, " y_min=", minimo, " giro=", giro)
	quit(0 if ok else 1)

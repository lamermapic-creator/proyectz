extends SceneTree
## Conservación de velocidad al girar, agarre combinado, FPS y pausa freno/marcha atrás.
var fallos := 0
var comprobaciones := 0

func _initialize() -> void:
	probar.call_deferred()

func comprobar(ok: bool, texto: String) -> void:
	comprobaciones += 1
	if not ok:
		fallos += 1
		printerr("MAL manejo: ", texto)

func curva(fps: int) -> float:
	var m := Moto.new()
	var piloto := Node.new()
	m.piloto = piloto
	m.vel_h = m.adelante() * 20.0
	var error_v := 0.0
	for i in 4 * fps:
		m._paso_direccion(1.0 / fps, 0.6, false, m.velocidad(), m.vel_h.dot(m.derecha()), 0.0)
		error_v = maxf(error_v, absf(m.vel_h.length() - 20.0))
	comprobar(error_v < 0.001, "girar no consume velocidad por proyección numérica")
	var rumbo := m.rumbo
	print("MANEJO curva fps=%d rumbo=%.5f velocidad=%.5f" % [fps, rumbo, m.vel_h.length()])
	m.free()
	piloto.free()
	return rumbo

func probar() -> void:
	var r30 := curva(30)
	var r60 := curva(60)
	var r120 := curva(120)
	comprobar(absf(Rbx.wrap_a(r30 - r120)) < 0.045, "curva 30/120 FPS difiere menos de 2.6 grados en cuatro segundos")
	comprobar(absf(Rbx.wrap_a(r60 - r120)) < 0.02, "curva 60/120 FPS difiere menos de 1.2 grados")
	var prueba := Moto.new()
	var piloto := Node.new()
	prueba.piloto = piloto
	prueba.vel_h = prueba.adelante() * 30.0
	var lateral := sqrt(pow(Moto.AGARRE_RUEDA * Moto.GRAV, 2) - 30.0 * 30.0)
	var max_lateral := 0.0
	for i in 120:
		prueba._paso_direccion(1.0 / 60.0, 1.0, false, 30.0, 0.0, 30.0)
		max_lateral = maxf(max_lateral, absf(prueba.yaw_rate * 30.0))
	comprobar(max_lateral <= lateral + 0.01, "frenar y girar comparten el agarre")
	prueba.free()
	piloto.free()
	await frenos()
	print("MANEJO_MOTO comprobaciones=%d fallos=%d" % [comprobaciones, fallos])
	quit(1 if fallos else 0)

func frenos() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(400, 0.5, 400)
	forma.shape = caja
	piso.position.y = -0.25
	piso.add_child(forma)
	mundo.add_child(piso)
	var m := Moto.new()
	mundo.add_child(m)
	var p := Node.new()
	mundo.add_child(p)
	m.piloto = p
	m.aparcada = false
	m.motor_on = true
	m.vel_h = m.adelante() * 15.0
	var parado := -1
	var primera_atras := -1
	for i in 150:
		await process_frame
		m.paso(1.0 / 60.0, {"freno": 1.0})
		if parado < 0 and m.velocidad() <= 0.01:
			parado = i
		if primera_atras < 0 and m.velocidad() < -0.05:
			primera_atras = i
	comprobar(parado >= 0 and primera_atras > parado + 17, "S detiene y hace pausa antes de retroceder")
	comprobar(m.velocidad() < -1.0 and m.velocidad() >= -Moto.ATRAS - 0.01, "marcha atrás controlada con velocidad limitada")
	print("MANEJO freno parado=%d atras=%d pausa=%.3f velocidad=%.3f" % [parado, primera_atras, (primera_atras-parado)/60.0, m.velocidad()])
	m.vel_h = Vector3.ZERO
	for i in 40:
		await process_frame
		m.paso(1.0 / 60.0, {"gas": 1.0, "freno": 1.0})
	comprobar(absf(m.velocidad()) < 0.05, "el freno tiene prioridad sobre el acelerador")
	for pendiente in [-0.10, 0.10]:
		piso.rotation.x = pendiente
		m.global_position = Vector3(30, 0, 0)
		m.rumbo = 0.0
		m.vel_h = Vector3.ZERO
		m.vel_v = 0.0
		m.cab_w = 0.0
		m._espera_atras = 0.0
		m.apoyo = 2
		m.en_aire = false
		m._poner_en_el_suelo()
		for i in 100:
			await process_frame
			m.paso(1.0 / 60.0, {"freno": 1.0})
		comprobar(m.velocidad() < -0.8 and not m.caida, "la pendiente no reinicia la espera de marcha atrás")
	mundo.free()

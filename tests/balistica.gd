extends SceneTree
## Integración física: impulso/punto, disparos reales de Arsenal, cadáver y recuperación del muñeco.
var mundo: Node3D
var fallos := 0
var comprobaciones := 0

func _initialize() -> void:
	probar.call_deferred()

func comprobar(ok: bool, texto: String) -> void:
	comprobaciones += 1
	if not ok:
		fallos += 1
		printerr("MAL balística: ", texto)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func crear(zombi := false):
	var obj = Zombi.new() if zombi else Maniqui.new()
	if zombi:
		obj.deambula = false
	else:
		obj.reaparecer = 30.0
	obj.position = Vector3(0, 12, 0)
	mundo.add_child(obj)
	obj.set_process(false)
	return obj

func momento(rd: Ragdoll) -> Vector3:
	var p := Vector3.ZERO
	for b in rd.cuerpos.values():
		p += b.mass * b.linear_velocity
	return p

func tiro(zombi: bool, pieza: String, j: Vector3, local: Vector3, perdigones := 1) -> Dictionary:
	var obj = crear(zombi)
	var p: Vector3 = obj.rig.P[pieza].global_transform * local
	for i in perdigones:
		obj.recibir_disparo(10000.0, pieza, j, p)
	var rd: Ragdoll = obj._ragdoll
	comprobar(rd != null and rd._muerte_bala, "la muerte usa física balística")
	for b in rd.cuerpos.values():
		b.gravity_scale = 0.0 # aislar la cantidad de movimiento de gravedad y suelo
	await frames(3)
	var bp: RigidBody3D = rd.cuerpos[pieza]
	var result := {"p": momento(rd), "w": bp.angular_velocity, "v": bp.linear_velocity}
	comprobar(result.p.dot(j) > 0.0, "el movimiento sigue a la bala")
	comprobar(result.p.length() < j.length() * perdigones * 1.15, "sin impulso extra que lance el cuerpo")
	comprobar(rd.cuerpos[pieza].has_meta("objetivo") and (rd.cuerpos[pieza].collision_layer & 2) != 0, "cadáver alcanzable por rayos")
	var fuerzas: Dictionary = rd._b_morir(1.0)[1]
	comprobar(fuerzas.values().all(func(f): return is_zero_approx(f)), "sin agonía ni músculos activos tras morir")
	obj.free()
	await frames(1)
	return result

func probar() -> void:
	seed(31)
	mundo = Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(200, 0.5, 200)
	cs.shape = caja
	suelo.position.y = -0.25
	suelo.add_child(cs)
	mundo.add_child(suelo)
	Zombi.sordos = true
	Zombi.ciegos = true
	for zombi in [false, true]:
		var izq := await tiro(zombi, "UpperTorso", Vector3(0, 0, 0.65), Vector3(-0.45, 0, -0.37))
		var der := await tiro(zombi, "UpperTorso", Vector3(0, 0, 0.65), Vector3(0.45, 0, -0.37))
		comprobar(izq.w.y * der.w.y < 0.0, "los impactos opuestos producen giros opuestos")
		var atras := await tiro(zombi, "UpperTorso", Vector3(0, 0, -0.65), Vector3(0, 0, 0.37))
		comprobar(atras.p.z < 0.0 and izq.p.z > 0.0, "frente/espalda tienen resultados distintos")
		var cabeza := await tiro(zombi, "Head", Vector3(0.65, 0, 0), Vector3(0, 0.15, -0.39))
		var pierna := await tiro(zombi, "LeftLowerLeg", Vector3(0.65, 0, 0), Vector3(0, -0.3, -0.23))
		comprobar(cabeza.w.distance_to(pierna.w) > 0.1, "cabeza y pierna reaccionan de forma diferente")
		var uno := await tiro(zombi, "UpperTorso", Vector3(0, 0, 0.20), Vector3(0, 0, -0.37))
		var nueve := await tiro(zombi, "UpperTorso", Vector3(0, 0, 0.20), Vector3(0, 0, -0.37), 9)
		comprobar(nueve.p.z > uno.p.z * 7.0 and nueve.p.z < uno.p.z * 10.0, "se conservan los nueve perdigones antes del arranque")
	await probar_reaccion_viva()
	await probar_cadaver()
	await probar_arma()
	await probar_reaparicion()
	print("BALISTICA comprobaciones=%d fallos=%d" % [comprobaciones, fallos])
	mundo.free()
	quit(1 if fallos else 0)

func probar_arma() -> void:
	var j := load("res://escenas/jugador.tscn").instantiate() as Jugador
	j.position = Vector3(0, 3.1, 15)
	mundo.add_child(j)
	await frames(3)
	j.set_process(false)
	j.get_node("Animador").set_process(false)
	j.arsenal.set_process(false)
	j.arsenal._equipar("Pistola")
	j.arsenal.modelo_mano = null # cañón de prueba: el rayo sale de la cámara, con dispersión real
	j.arsenal.draw_until = -100.0
	j.arsenal.last_shot = -100.0
	j.aiming = true
	j.en_suelo = true
	var obj := Maniqui.new()
	obj.health = 20.0
	mundo.add_child(obj)
	obj.health = 20.0
	obj.set_process(false)
	j.camara.global_position = Vector3(0, obj.centro().y, 15)
	j.camara.look_at(obj.centro())
	await frames(2)
	j.arsenal.shoot()
	comprobar(not obj.vivo() and is_instance_valid(obj._ragdoll) and obj._ragdoll._balistica, "Arsenal transmite el impacto balístico real")
	if is_instance_valid(obj._ragdoll):
		await frames(3)
		obj._ragdoll._congelar()
		var p: Vector3 = obj._ragdoll.cuerpos.UpperTorso.global_position
		j.camara.global_position = p + Vector3(0, 0, 15)
		j.camara.look_at(p)
		var marcador := j.arsenal.hit_t
		j.arsenal.last_shot = -100.0
		j.arsenal.shoot()
		comprobar(not obj._ragdoll._congelado, "Arsenal alcanza y despierta el cadáver")
		comprobar(j.arsenal.hit_t == marcador, "disparar al cadáver no concede otra baja")
	obj.free()
	j.free()
	await frames(2)

func probar_reaparicion() -> void:
	var obj := Maniqui.new()
	obj.reaparecer = 0.5
	mundo.add_child(obj)
	await frames(1)
	obj.recibir_disparo(10000, "Head", Vector3(0, 0, 0.65), obj.rig.P.Head.global_position)
	for i in 420:
		await frames(1)
		if obj.vivo() and obj.en_pie():
			break
	comprobar(obj.vivo() and obj.en_pie() and obj.health == obj.max_health, "el muñeco se recupera tras el disparo mortal")
	obj.free()

func probar_cadaver() -> void:
	var z := Zombi.new()
	z.variante_visual = "civil"
	z.deambula = false
	z.position = Vector3(0, 3.1, 0)
	mundo.add_child(z)
	await frames(12)
	z.recibir_disparo(10000, "Head", Vector3(0, 0, 0.95), z.rig.P.Head.global_position + Vector3(0.15, 0, -0.38))
	var rd: Ragdoll = z._ragdoll
	var estira := 0.0
	var max_vel := 0.0
	for i in 540:
		await frames(1)
		max_vel = maxf(max_vel, rd.velocidad())
		for mn in Ragdoll.ART:
			var m: RigPersonaje.Motor = z.rig.M[mn]
			var pa: RigidBody3D = rd.cuerpos[m.part0]
			var hi: RigidBody3D = rd.cuerpos[m.part1]
			estira = maxf(estira, (pa.global_transform * m.c0).origin.distance_to((hi.global_transform * m.c1).origin))
	comprobar(estira < 0.6, "las articulaciones conservan su unión al caer por disparo")
	comprobar(max_vel < 25.0, "el disparo no catapulta el cadáver")
	comprobar(rd._congelado or rd.velocidad() < 1.2, "el cadáver se asienta sin espasmos repetidos")
	print("BALISTICA caída estiramiento=%.3f velocidad_max=%.3f quieto=%s" % [estira, max_vel, str(rd._congelado)])
	z.free()
	await frames(2)

func probar_reaccion_viva() -> void:
	for zombi in [false, true]:
		var obj = crear(zombi)
		if zombi:
			obj._var = 0.0
			obj._process(0.0)
		else:
			obj._pose(0.0, 0.0)
		var derecha: RigPersonaje.Motor = obj.rig.M.RightShoulder
		var izquierda: RigPersonaje.Motor = obj.rig.M.LeftShoulder
		var antes_d: Basis = derecha.transform.basis
		var antes_i: Basis = izquierda.transform.basis
		var vida: float = obj.health
		obj.recibir_disparo(10.0, "RightUpperArm", Vector3(0, 0, 0.65), obj.rig.P.RightUpperArm.global_position)
		for i in 5:
			if zombi:
				obj._process(1.0/60.0)
			else:
				obj._pose(1.0/60.0, 0.0)
		var cambia_d := antes_d.get_rotation_quaternion().angle_to(derecha.transform.basis.get_rotation_quaternion())
		var cambia_i := antes_i.get_rotation_quaternion().angle_to(izquierda.transform.basis.get_rotation_quaternion())
		comprobar(obj.vivo() and obj._ragdoll == null and obj.health == vida - 10.0, "el disparo no mortal conserva control y daño")
		comprobar(cambia_d > cambia_i + 0.015, "reacción viva localizada en el brazo alcanzado")
		obj.free()
		await frames(1)

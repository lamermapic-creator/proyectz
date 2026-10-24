extends Node
## Prueba automática: el jugador camina/corre contra cada estructura desde varios ángulos y
## se mide si alguna pieza del cuerpo queda dentro de la geometría y cuánto suben los pies.
var j: Jugador
var a: Animador
var casos := []
var i := -1
var t := 0.0
var dur := 2.6
var peor := {}

func _key(k: int, p: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = p
	Input.parse_input_event(ev)

func _ready() -> void:
	j = get_parent().get_node("Jugador")
	a = j.get_node("Animador")
	var M := 1.0 / 0.31
	# objetivos: centro (m) y tamaño (m) de estructuras del nivel
	var objs := [
		["bloque60", Vector3(-6, 0.3, -10), Vector3(2, 0.6, 2)],
		["bloque90", Vector3(-3, 0.45, -10), Vector3(2, 0.9, 2)],
		["bloque120", Vector3(0, 0.6, -10), Vector3(2, 1.2, 2)],
		["bloque200", Vector3(6, 1.0, -10), Vector3(2, 2.0, 2)],
		["descanso", Vector3(-20, 1.08, 9.1), Vector3(3, 2.16, 3)],
		["pared", Vector3(0, 2, 20), Vector3(16, 4, 0.4)],
		["muro110", Vector3(-2, 0.55, 14), Vector3(2.5, 1.1, 0.3)],
		["mesa80", Vector3(-6, 0.4, 14), Vector3(2.5, 0.8, 1)],
		["plataforma30", Vector3(16, 1.5, -18.7), Vector3(3, 3, 3)],
	]
	for o in objs:
		var c: Vector3 = o[1] * M
		var s: Vector3 = o[2] * M
		for ang in [0.0, 30.0, 60.0, 90.0, 135.0, 180.0, 270.0]:
			for correr in [false, true]:
				var dir := Vector3(sin(deg_to_rad(ang)), 0, cos(deg_to_rad(ang)))
				# punto de salida fuera de la caja, a 9 studs del borde
				var r := maxf(s.x, s.z) * 0.5 + 9.0
				var p := Vector3(c.x, 3.2, c.z) + dir * r
				# en la fila de bloques solo de frente y por detrás (a los lados hay otros bloques)
				if str(o[0]).begins_with("bloque") and not (ang in [0.0, 180.0]):
					continue
				casos.append([o[0] + "_%d%s" % [ang, "_c" if correr else ""], p, correr])
	_siguiente()

func _siguiente() -> void:
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	i += 1
	if i >= casos.size():
		for k in peor:
			print("RESULTADO ", k, " ", peor[k])
		get_tree().quit()
		return
	var cso: Array = casos[i]
	j.global_position = cso[1]
	j.velocity = Vector3.ZERO
	j.cur_move = 0
	j.estado = "Running"
	j.stance = 0
	j.prone_p = 0
	# mirar hacia el objetivo (centro de la estructura, misma recta de salida)
	var nm: String = cso[0]
	var ang := float(nm.split("_")[1])
	j.yaw = deg_to_rad(ang) + PI
	j.yaw = atan2(sin(deg_to_rad(ang)), cos(deg_to_rad(ang)))
	j.rotation.y = j.yaw
	a.replant = true
	t = 0.0
	await get_tree().process_frame
	_key(KEY_W, true)
	if cso[2]:
		_key(KEY_SHIFT, true)

func _process(dt: float) -> void:
	if i < 0 or i >= casos.size():
		return
	t += dt
	var space := j.get_world_3d().direct_space_state
	var dentro := 0
	var partes := []
	for n in j.rig.P:
		if n == "HumanoidRootPart":
			continue
		var nd: Node3D = j.rig.P[n]
		var q := PhysicsPointQueryParameters3D.new()
		q.position = nd.global_position
		q.exclude = [j.get_rid()]
		var hits := space.intersect_point(q, 1)
		if not hits.is_empty():
			dentro += 1
			partes.append(n)
			if n == "Head":
				print("DET ", casos[i][0], " t=%.2f " % t, n, " en ", (hits[0].collider as Node).name, " cuerpo=", j.global_position, " estado=", j.estado)
	# altura de los pies sobre el suelo bajo el cuerpo
	var gy := j.global_position.y - j.center_cur
	var pie := maxf(j.rig.P.LeftFoot.global_position.y, j.rig.P.RightFoot.global_position.y) - gy
	var nm: String = casos[i][0]
	var w: Dictionary = peor.get(nm, {"dentro": 0, "partes": [], "pie": 0.0})
	if dentro > w.dentro:
		w.dentro = dentro
		w.partes = partes
	if j.en_suelo and pie > w.pie:
		w.pie = snappedf(pie, 0.01)
	peor[nm] = w
	if t > dur:
		_siguiente()

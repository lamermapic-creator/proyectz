extends Node
## Prueba del ragdoll activo con un muñeco suelto (sin jugador): --modo=empuje|alto|morir|limites
## Imprime "RAG ..." con la altura de la pelvis, la velocidad y si alguna articulación se sale de sus límites.
var t := 0.0
var modo := "empuje"
var cam: Camera3D
var d: Node3D
var rig: RigPersonaje
var rd: Ragdoll
var M := 1.0 / 0.31
var max_estiramiento := 0.0
var impactos := []
var recuperado_t := -1.0

var J: Jugador
var de_pie_t := -1.0
var vida_min := 100.0
var vida_tras := -1.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modo="):
			modo = a.split("=")[1]
	J = get_parent().get_node_or_null("Jugador")
	if modo.begins_with("j_"):
		cam = Camera3D.new()
		add_child(cam)
		cam.fov = 45
		call_deferred("_inicio_jugador")
		return
	if J:
		J.teletransportar(Vector3(-40, 0, 40) * M, 0.0)
	d = Node3D.new()
	d.name = "Muneco"
	get_parent().add_child.call_deferred(d)
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 45
	call_deferred("_inicio")

func _inicio() -> void:
	rig = RigPersonaje.new()
	rig.name = "Rig"
	d.add_child(rig)
	var alto := 3.1 if modo != "alto" else 22.0
	d.global_position = Vector3(-10, 0, 25) * M + Vector3(0, alto, 0)
	await get_tree().process_frame
	await get_tree().physics_frame
	var op := {"comportamiento": "caer", "impulso": Vector3(0, 2, 14), "pieza": "UpperTorso", "duracion": 2.0}
	match modo:
		"alto":
			op = {"comportamiento": "caida_libre", "duracion": 3.0}
		"morir":
			op = {"comportamiento": "morir", "vivo": false, "impulso": Vector3(-6, 1, 0), "duracion": -1.0}
		"limites":
			op = {"comportamiento": "inerte", "impulso": Vector3(0, 6, 25), "pieza": "Head", "giro": Vector3(6, 2, 4)}
	rd = Ragdoll.iniciar(d, rig, Vector3.ZERO, op)
	rd.impacto.connect(func(v): impactos.append(v); print("RAG impacto %.1f t=%.2f" % [v, t]))
	rd.recuperado.connect(func(): recuperado_t = t; print("RAG recuperado t=%.2f" % t))

## pruebas con el JUGADOR: j_derribo (golpe fuerte), j_caida (caída larga), j_aterriza (caída media, de pie),
## j_morir. Comprueba que el ragdoll empieza, que hace daño cuando toca y que se levanta y vuelve a andar.
func _inicio_jugador() -> void:
	J.estamina_infinita = true
	J.teletransportar(Vector3(-10, 0, 25) * M, 0.0)
	await get_tree().create_timer(0.6).timeout
	match modo:
		"j_derribo":
			J.ragdoll_iniciar(Vector3.ZERO, {"comportamiento": "caer", "impulso": Vector3(0, 2.5, 13), "duracion": 1.4})
		"j_caida":
			J.global_position += Vector3(0, 40, 0) # ~12 m
		"j_aterriza":
			J.global_position += Vector3(0, 18, 0) # cae a ~33 studs/s: duele
		"j_moto":
			# moto caída justo al lado y el jugador derribado encima de ella: tiene que levantarse fuera, libre
			var mt: Moto = null
			for x in get_tree().get_nodes_in_group("motos"):
				mt = x
				break
			mt.global_position = J.global_position + Vector3(0, 0, 2.5)
			mt.caer(1.0)
			await get_tree().create_timer(0.8).timeout
			J.ragdoll_iniciar(Vector3.ZERO, {"comportamiento": "caer", "impulso": Vector3(0, 3, 9), "duracion": 1.4})
		"j_morir":
			J._reiniciando = true # (en la prueba no se reinicia el nivel)
			J.recibir_danio(500.0, J.global_position + Vector3(0, 0, -3))

func _proceso_jugador(dt: float) -> void:
	vida_min = minf(vida_min, J.health)
	if J.ragdoll != null and not notas_j.has("rag"):
		notas_j.rag = t
		J.ragdoll.impacto.connect(func(v): print("RAG impacto jugador %.1f" % v))
	if notas_j.has("rag") and J.ragdoll == null and J.health > 0 and de_pie_t < 0.0 and not J.L.gettingUp and J.getup_p <= 0.0:
		de_pie_t = t
	# moto caída al lado: al levantarse no tiene que salir disparada (el jugador la empujaba como un muro)
	if modo == "j_moto" and J.ragdoll == null and notas_j.has("rag"):
		for x in get_tree().get_nodes_in_group("motos"):
			var f = x.get("_fisica")
			if f != null and is_instance_valid(f):
				moto_v_tras = maxf(moto_v_tras, f.linear_velocity.length())
	if fmod(t, 0.5) < dt:
		print("RAG t=%.2f jugador ragdoll=%s vida=%.0f comp=%s getup=%.2f stance=%d pos_y=%.2f" % [t, str(J.ragdoll != null), J.health,
			J.ragdoll.comportamiento if J.ragdoll else "-", J.getup_p, J.stance, J.global_position.y])
	cam.current = true
	var foco := J.global_position
	cam.global_position = foco + Vector3(14, 6, 6)
	cam.look_at(foco, Vector3.UP)
	if t > 9.0:
		var fallos := []
		if not notas_j.has("rag"): fallos.append("no hay ragdoll")
		match modo:
			"j_derribo":
				if de_pie_t < 0.0: fallos.append("no se levanta")
			"j_caida":
				if vida_min >= 100.0: fallos.append("la caída no hace daño")
				if J.health > 0 and de_pie_t < 0.0: fallos.append("no se levanta")
			"j_aterriza":
				if vida_min >= 100.0: fallos.append("el aterrizaje no hace daño")
			"j_morir":
				if J.ragdoll == null: fallos.append("el muerto no queda en ragdoll")
			"j_moto":
				if de_pie_t < 0.0: fallos.append("no se levanta")
				elif J._esfera_choca(J.global_position + Vector3(0, -0.3, 0), 0.7): fallos.append("se levanta dentro de algo")
				if moto_v_tras > 8.0: fallos.append("la moto sale disparada al levantarse (%.0f studs/s)" % moto_v_tras)
		print("RAG fin vida_min=%.0f de_pie=%.2f" % [vida_min, de_pie_t])
		print(("OK ragdoll_" + modo) if fallos.is_empty() else ("MAL ragdoll_%s: %s" % [modo, ", ".join(fallos)]))
		get_tree().quit()

var notas_j := {}
var _mov_acc := 0.0
var moto_v_tras := 0.0

func _process(dt: float) -> void:
	t += dt
	if modo.begins_with("j_"):
		_proceso_jugador(dt)
		return
	if rd == null or not is_instance_valid(rd) or rd.cuerpos.is_empty():
		return
	var p := rd.pelvis()
	# estiramiento de las articulaciones (distancia entre los dos lados del pivote)
	for mn in Ragdoll.ART:
		var m: RigPersonaje.Motor = rig.M[mn]
		var pa: RigidBody3D = rd.cuerpos[m.part0]
		var hi: RigidBody3D = rd.cuerpos[m.part1]
		var e := ((pa.global_transform * m.c0).origin - (hi.global_transform * m.c1).origin).length()
		max_estiramiento = maxf(max_estiramiento, e)
	# movimiento de los miembros respecto al torso (rad/s medio): mide lo "vivo" que se mueve el cuerpo
	var wt: Vector3 = rd.torso().angular_velocity
	var wsum := 0.0
	for n in rd.cuerpos:
		wsum += ((rd.cuerpos[n] as RigidBody3D).angular_velocity - wt).length()
	_mov_acc += wsum / rd.cuerpos.size() * dt
	if fmod(t, 0.5) < dt:
		print("RAG t=%.2f comp=%s pelvis_y=%.2f v=%.1f estira=%.2f arriba=%s mov=%.2f err=%.0f°" % [t, rd.comportamiento, p.y,
			rd.velocidad(), max_estiramiento, str(rd.boca_arriba()), _mov_acc / 0.5, rad_to_deg(rd.error_medio)])
		_mov_acc = 0.0
	cam.current = true
	var foco := p + Vector3(0, 0.5, 0)
	cam.global_position = foco + Vector3(14, 6, 6)
	cam.look_at(foco, Vector3.UP)
	if t > 7.0:
		var ok := max_estiramiento < 0.6
		print("RAG fin estira=%.2f impactos=%d recuperado=%.2f" % [max_estiramiento, impactos.size(), recuperado_t])
		print(("OK" if ok else "MAL") + " ragdoll_" + modo)
		get_tree().quit()

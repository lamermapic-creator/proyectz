extends Node
## Golpes a un zombi EN EL SUELO (2026-11-08, 6: ImpactoCC): el personaje se agacha / inclina hacia él y le da.
## --golpe=pisoton|puno|cuchillo, --veces=N. Imprime cada impacto (y el parón de ImpactoCC), cuánto baja la cabeza del
## jugador y la vida que pierde el zombi; al final "SUELO golpe=... impactos=x/N baja_cabeza=... danio=..." y OK/MAL.
var j: Jugador
var obj
var t := 0.0
var golpe := "pisoton"
var veces := 5
var hechos := 0
var proximo := 3.5
var impactos := 0
var ult_imp_t := -1.0
var ult_paron_t := -1.0
var cabeza0 := -1.0
var baja_max := 0.0
var vida0 := 0.0
var parones := 0
var distancia := 2.8   # --distancia=N: a cuántos studs del pecho se pone el jugador (4 = con las piernas delante)
var muerto := false    # --muerto: el zombi está muerto (cadáver)
var grupo := false     # --grupo: además del caído, dos zombis DE PIE delante: hay que pegar a los de pie
var mira_abajo := false   # --mira_abajo: (con --grupo) la cámara mira al suelo: entonces sí, al caído
var de_pie := []
var al_suelo := 0
var a_de_pie := 0
var cam_lado: Camera3D = null   # --lado: cámara de lado para grabar (--write-movie)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--golpe="):
			golpe = a.split("=")[1]
		if a.begins_with("--veces="):
			veces = int(a.split("=")[1])
		if a.begins_with("--distancia="):
			distancia = float(a.split("=")[1])
		if a == "--muerto":
			muerto = true
		if a == "--grupo":
			grupo = true
		if a == "--mira_abajo":
			mira_abajo = true
	seed(5)
	j = get_parent().get_node("Jugador")
	j.global_position = Vector3(-100, 3.2, 100)
	j.yaw = 0.0
	j.estamina_infinita = true
	j.invencible = true
	Zombi.sordos = true
	Zombi.ciegos = true
	if OS.get_cmdline_user_args().has("--lado"):
		cam_lado = Camera3D.new()
		cam_lado.fov = 50
		add_child(cam_lado)

func _cabeza() -> float:
	return (j.rig.P.Head as Node3D).global_position.y - j.global_position.y

func _process(dt: float) -> void:
	t += dt
	var a := j.arsenal
	if golpe in ["cuchillo", "bate"] and t > 0.4 and a.equipado == "" and hechos == 0:
		a.select_slot(2 if golpe == "cuchillo" else 3)
	if t > 0.3 and obj == null:
		obj = get_parent().get_node("Zombis").crear_zombi(j.global_position + Vector3(0, -3.1, -3.4), 0.0, false)
	if obj == null:
		return
	if cam_lado:
		var medio: Vector3 = (j.global_position + (obj.rig.P.UpperTorso as Node3D).global_position) * 0.5
		cam_lado.global_position = medio + Vector3(12, 2.0, 1.0)
		cam_lado.look_at(medio + Vector3(0, -0.6, 0))
		cam_lado.make_current()
	if t > 1.0 and t < 1.1 and obj.en_pie():
		obj.health = 2000.0
		if muerto:
			obj.recibir_danio(99999.0, "UpperTorso", Vector3(0, 6, -40))
		else:
			obj.derribar(Vector3(0, 6, -10), 120.0)
	if t > 2.3 and t < 2.4:
		# el jugador se pone a 2,8 studs del cuerpo caído, mirándolo
		var tor: Vector3 = (obj.rig.P.UpperTorso as Node3D).global_position
		j.global_position = Vector3(tor.x, j.global_position.y, tor.z + distancia)
	if t > 2.7 and cabeza0 < 0.0:
		cabeza0 = _cabeza()
		vida0 = obj.health
		print("SUELO muerto=%s distancia=%.1f" % [str(not obj.vivo()), distancia])
		if grupo:
			# dos zombis de pie: uno delante algo a la izquierda (más lejos que el caído) y otro a la derecha
			for x in [-1.6, 1.8]:
				var z = get_parent().get_node("Zombis").crear_zombi(j.global_position + Vector3(x, -3.1, -3.3), 0.0, false)
				de_pie.append(z)
				z.set_meta("casa", j.global_position + Vector3(x, 0, -3.3))
		var zp: Vector3 = (obj.rig.P.UpperTorso as Node3D).global_position - j.global_position
		print("SUELO zombi tumbado a %.2f studs delante, %.2f por debajo" % [Rbx.flat(zp).length(), -zp.y])
	if OS.get_cmdline_user_args().has("--traza") and cabeza0 > 0.0 and t > proximo - 2.3 and t < proximo - 0.6:
		print("TRAZA t=%.2f acc=%s w=%.2f cad_y=%.2f cin_p=%.2f cabeza=%.2f guard=%.2f" % [t, str(a.cc.accion.tipo) if a.cc.accion else "-", a.impacto._w,
			float(a.anim.cc_pose.get("cad_y", 0.0)), float(a.anim.cc_pose.get("cin_p", 0.0)), cabeza0 - _cabeza(), a.anim.cc_guard_w])
	if cabeza0 > 0.0 and a.cc.accion != null:
		baja_max = maxf(baja_max, cabeza0 - _cabeza())
	if grupo:
		j.pitch = -1.0 if mira_abajo else -0.15
		for z in de_pie:
			if is_instance_valid(z) and z.en_pie():
				z.health = 2000.0
				z.velocity = Vector3.ZERO
	if hechos < veces and t > proximo - 0.4 and t < proximo - 0.35 and cabeza0 > 0.0 and not grupo:
		# (el cuerpo se mueve con cada golpe: el jugador se vuelve a poner a 2,8 studs)
		var tor2: Vector3 = (obj.rig.P.UpperTorso as Node3D).global_position
		j.global_position = Vector3(tor2.x, j.global_position.y, tor2.z + distancia)
	if grupo and hechos < veces and t > proximo - 0.3 and t < proximo - 0.25:
		for z in de_pie:
			if is_instance_valid(z) and z.en_pie():
				z.global_position = z.get_meta("casa")
	if hechos < veces and t > proximo and cabeza0 > 0.0:
		hechos += 1
		proximo = t + 2.2
		print("SUELO intento %d t=%.1f" % [hechos, t])
		match golpe:
			"pisoton":
				a.patada()
			"cuchillo", "bate":
				a.melee()
			_:
				a.punetazo()
		if a.cc.accion != null:
			print("SUELO accion=%s" % str(a.cc.accion.tipo))
	var imp: Dictionary = a.cc_ultimo_impacto
	if not imp.is_empty() and float(imp.get("t", -1.0)) != ult_imp_t:
		ult_imp_t = float(imp.get("t", -1.0))
		impactos += 1
		if imp.get("suelo", false):
			al_suelo += 1
		else:
			a_de_pie += 1
		print("SUELO impacto %s dv=%.1f pieza=%s danio=%.0f" % [imp.tipo, float(imp.dv), imp.pieza, float(imp.get("danio", 0.0))])
	var ul: Dictionary = a.impacto.ultimo
	if not ul.is_empty() and float(ul.t) != ult_paron_t:
		ult_paron_t = float(ul.t)
		parones += 1
		print("SUELO paron=%.3f detencion=%.3f escala=%.2f" % [float(ul.paron), float(ul.detencion), Engine.time_scale])
		if golpe == "cuchillo" or golpe == "bate":
			impactos += 1
			if ul.get("suelo", false):
				al_suelo += 1
			else:
				a_de_pie += 1
	if hechos >= veces and t > proximo + 0.5 or t > 40.0:
		var danio: float = vida0 - obj.health
		print("SUELO golpe=%s impactos=%d/%d parones=%d baja_cabeza=%.2f danio=%.0f escala_final=%.2f" % [golpe, impactos, hechos, parones, baja_max, danio, Engine.time_scale])
		var ok := impactos >= int(ceil(hechos * 0.6)) and (danio > 0.0 or muerto) and parones > 0 and Engine.time_scale > 0.99 \
			and baja_max > (0.5 if golpe == "pisoton" else 0.9)
		if grupo:
			print("SUELO grupo: al_suelo=%d a_de_pie=%d baja_cabeza=%.2f" % [al_suelo, a_de_pie, baja_max])
			if mira_abajo:
				ok = impactos >= int(ceil(hechos * 0.6)) and al_suelo > a_de_pie and baja_max > 0.5
			else:
				# (los de pie están algo a los lados: no todas las patadas llegan; lo que importa es que NINGUNA va al suelo)
				ok = a_de_pie >= 2 and al_suelo == 0 and (golpe == "pisoton" or baja_max < 0.6)
		print("OK suelo_" + golpe if ok else "MAL suelo_%s" % golpe)
		get_tree().quit()

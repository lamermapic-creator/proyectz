extends Node
## Prueba de combate: equipar, disparar a un muñeco, recargar, golpear con armas blancas.
## --modo=<pistola|rifle|cuchillo|bate|machete|cambiar|apoyar> ; con --video la cámara sigue al jugador.
## --arma=<Nombre> (cualquier arma de Armas.WEAPONS, p. ej. Escopeta): se la da y la prueba igual.
## --cc=<todo|guardia|bloqueo|empujon|patada> (2026-11-08): combate cuerpo a cuerpo junto al muñeco, sin arma o con
## --arma=<Nombre>: guardia, patada, empujón (doble Espacio), parada y bloqueo (golpes de mentira al jugador).
## Imprime "CC ..." y al final "OK cc_<arma>" o "MAL cc_<arma>: ...".
var cc_acc := ""
var cc_vida0 := 0.0
var cc_res := {}
var j: Jugador
var t := 0.0
var modo := "pistola"
var cam: Camera3D
var hecho := {}
var M := 1.0 / 0.31
var man: Maniqui
var arma_x := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modo="):
			modo = a.split("=")[1]
		if a.begins_with("--arma="):
			arma_x = a.split("=")[1]
			var w: Dictionary = Armas.WEAPONS[arma_x]
			modo = ("rifle" if w.Auto else "pistola") if w.Kind == "Gun" else "cuchillo"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cc="):
			cc_acc = a.split("=")[1]
			modo = "cc"
			seed(7) # variantes siempre en el mismo orden (para comparar vídeos)
		if a.begins_with("--cc_semilla="):
			seed(int(a.split("=")[1]))
	j = get_parent().get_node("Jugador")
	if OS.get_cmdline_user_args().has("--video") and not OS.get_cmdline_user_args().has("--camjuego"):
		cam = Camera3D.new()
		add_child(cam)
		cam.fov = 45
	call_deferred("_inicio")

func _inicio() -> void:
	man = get_parent().get_node("Maniquies/Maniqui_0")
	var cerca := modo in ["cuchillo", "bate", "machete", "cc"]
	# frente a la barrera de tiro mirando a los muñecos (+X), o pegado al muñeco para golpear
	var x := 25.0 * M - 1.5 if not cerca else 32.0 * M - 4.0
	if modo == "apoyar":
		x = 26.0 * M - 0.48 - 1.4
	j.global_position = Vector3(x, 3.2, -2.1 if not (cerca or modo == "apoyar") else 0.0)
	j.yaw = -PI / 2
	j.rotation.y = j.yaw
	j.pitch = -0.05

func _una(clave: String, cond: bool) -> bool:
	if cond and not hecho.has(clave):
		hecho[clave] = true
		return true
	return false

func _log(txt: String) -> void:
	print("COMBATE t=%.2f %s | arma=%s vida_muneco=%.0f estado=%s" % [t, txt, j.arsenal.equipado, man.health if man else -1, man._estado if man else "-"])

func _process(dt: float) -> void:
	t += dt
	var a := j.arsenal
	var slot: int = {"pistola": 0, "rifle": 1, "cuchillo": 2, "bate": 3, "machete": 3, "cambiar": 0, "apoyar": 1, "cc": -1}[modo]
	if arma_x != "":
		if _una("dar", t > 0.2):
			a.dar_arma(arma_x, false)
		for k in Armas.SLOTS.size():
			if a.arma_en_hueco(Armas.SLOTS[k].Id) == arma_x:
				slot = k
	if modo == "machete" and _una("coger", t > 0.2):
		# el machete está en el suelo cerca del inicio: se lleva al jugador
		var s = a.suelo[0]
		j.global_position = (s.nodo as Node3D).global_position + Vector3(0, 3.2, 0)
		a._recoger()
		_inicio()
		_log("recogido")
	if _una("equipar", t > 0.5) and slot >= 0:
		a.select_slot(slot)
		_log("equipar")
	if modo == "cc":
		_paso_cc(a, dt)
	if modo in ["pistola", "rifle", "apoyar"]:
		# (la barrera mide 1 m: agachado, que es la altura buena para apoyar el arma)
		if modo == "apoyar" and _una("agachar", t > 1.0) and not OS.get_cmdline_user_args().has("--de_pie"):
			j.set_stance(1)
		if modo == "apoyar" and _una("x", t > 2.0):
			j.aiming = true
			if not OS.get_cmdline_user_args().has("--sin_apoyar"):
				a.set_rest(true)
			_log("apoyar rest=%s gap=%s motivo=%s pos=%s" % [str(a.rest != null), str(a.rest.gap if a.rest else -1), a.rest_motivo, j.global_position])
		if t > 1.8 and t < 4.5:
			j.aiming = true
			if modo == "rifle":
				j.firing = t > 2.2 and t < 3.4
			elif fmod(t, 0.4) < dt and t > 2.2:
				a.shoot()
		if OS.get_cmdline_user_args().has("--logarma_y") and fmod(t, 0.1) < dt and a.modelo_mano != null:
			var an8: Animador = j.get_node("Animador")
			var ymin8 := INF
			for p8 in an8._esquinas_arma(a.modelo_mano, a.equipado):
				ymin8 = minf(ymin8, ((a.modelo_mano as Node3D).global_transform * (p8 as Vector3)).y)
			# parte de delante (más de 1,4 studs por delante del cuerpo: lo que queda sobre un apoyo)
			var yfr := INF
			var fw8 := Rbx.flat(-(a.modelo_mano as Node3D).global_transform.basis.z).normalized()
			for p9 in an8._esquinas_arma(a.modelo_mano, a.equipado):
				var w9: Vector3 = (a.modelo_mano as Node3D).global_transform * (p9 as Vector3)
				if (w9 - j.global_position).dot(fw8) > 1.4:
					yfr = minf(yfr, w9.y)
			print("ARMA_Y t=%.2f stance=%d aim=%s abajo_rel_centro=%.2f delante=%.2f ojo=%.2f" % [t, j.stance, str(j.aiming), ymin8 - j.global_position.y, yfr - j.global_position.y, j.eye_cur])
		if OS.get_cmdline_user_args().has("--logapoyo") and fmod(t, 0.1) < dt and a.rest != null:
			# parte de abajo del arma sobre el apoyo respecto a la cara de arriba del apoyo (0 = apoyada)
			var an7: Animador = j.get_node("Animador")
			var mdl7: Node3D = a.modelo_mano
			var ymin := INF
			var fw7 := Rbx.flat(-mdl7.global_transform.basis.z).normalized()
			for p7 in an7._esquinas_arma(mdl7, a.equipado):
				var wp7: Vector3 = mdl7.global_transform * (p7 as Vector3)
				if (wp7 - j.global_position).dot(fw7) > float(a.rest.get("borde_d", 1.0)) + 0.06:
					ymin = minf(ymin, wp7.y)
			print("APOYO t=%.2f hueco=%.3f baja=%.3f alza=%.3f top=%.2f borde=%.2f" % [t, ymin - float(a.rest.top), an7.rest_baja, an7.rest_alza, float(a.rest.top), float(a.rest.get("borde_d", -1))])
		if OS.get_cmdline_user_args().has("--logmira") and fmod(t, 0.25) < dt:
			var l0: ColorRect = a._hud.lineas[0]
			print("MIRA t=%.2f vis=%s esc=%.2f pos0=%s size0=%s rest=%s cam_fov=%.1f" % [t, str(a._hud.mira.visible and l0.visible), a.mira_esc, l0.position, l0.size, str(a.rest != null), j.cam_fov])
		if _una("fin_tiro", t > 3.6):
			_log("tras disparar mag=%d reserva=%d" % [a.datos_equipado().mag, a.datos_equipado().reserve])
			j.firing = false
			j.aiming = false
			a.reload()
			_log("recargando")
		if _una("tras_recarga", t > 6.6):
			_log("tras recargar mag=%d reserva=%d" % [a.datos_equipado().mag, a.datos_equipado().reserve])
	elif modo in ["cuchillo", "bate", "machete"]:
		if t > 1.8 and fmod(t, 1.0) < dt and t < 6:
			a.melee()
		if fmod(t, 0.5) < dt:
			_log("golpes")
	elif modo == "cambiar":
		for k in [[1.6, 1], [2.8, 2], [4.0, 3], [5.2, 0], [6.4, 0]]:
			if _una("c%s" % k[0], t > k[0]):
				a.select_slot(k[1])
				_log("cambiar a hueco %d" % k[1])
	# armas de fuego (2026-11-01): ¿atraviesa el arma el torso o la cabeza? Se miran las esquinas y el centro de cada
	# pieza del modelo (no las manos ni los antebrazos, que la agarran). --pitch=<rad> fija el cabeceo
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pitch="):
			j.pitch = float(arg.split("=")[1])
	if OS.get_cmdline_user_args().has("--info_arma") and _una("info", t > 1.6):
		var an3: Animador = j.get_node("Animador")
		var pts: Array = an3._puntos_arma(a.modelo_mano, a.equipado)
		var zmin := 99.0
		var zmax := -99.0
		var ymin := 99.0
		var ymax := -99.0
		for p in pts:
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
			ymin = minf(ymin, p.y)
			ymax = maxf(ymax, p.y)
		print("INFO_ARMA %s z=[%.2f, %.2f] y=[%.2f, %.2f] torso=%s barriga=%s cuello=%s" % [a.equipado, zmin, zmax, ymin, ymax,
			j.rig.P.UpperTorso.get_meta("size"), j.rig.P.LowerTorso.get_meta("size"), (j.rig.P.UpperTorso as Node3D).global_transform.affine_inverse() * (j.rig.P.Head as Node3D).global_position])
	if OS.get_cmdline_user_args().has("--choque_arma") and a.modelo_mano and a.modelo_mano.visible and Armas.WEAPONS.get(a.equipado, {}).get("Kind", "") == "Gun":
		var an2: Animador = j.get_node("Animador")
		var peor2 := ""
		var pmax2 := 0.0
		for mi in a.modelo_mano.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).get_aabb()
			var pts := [ab.get_center()]
			for c in 8:
				pts.append(ab.get_endpoint(c))
			for pl in pts:
				var pt: Vector3 = (mi as MeshInstance3D).global_transform * (pl as Vector3)
				for n in (["UpperTorso", "LowerTorso", "Head", "LeftUpperArm", "LeftUpperLeg", "RightUpperLeg"] if OS.get_cmdline_user_args().has("--todo_cuerpo") else ["UpperTorso", "LowerTorso"]):
					var nd: Node3D = j.rig.P[n]
					var sz: Vector3 = nd.get_meta("size")
					var lp: Vector3 = nd.global_transform.affine_inverse() * pt
					var pen := minf(minf(sz.x * 0.5 - absf(lp.x), sz.y * 0.5 - absf(lp.y)), sz.z * 0.5 - absf(lp.z))
					if pen > pmax2:
						pmax2 = pen
						peor2 = "%s en %s lp=(%.2f,%.2f,%.2f) h=%s" % [mi.name, n, lp.x, lp.y, lp.z, (j.rig.P.UpperTorso as Node3D).global_transform.affine_inverse() * a.modelo_mano.global_position]
		if pmax2 > 0.03:
			var est := "AIM" if j.aiming else ("HIP" if j.firing or t - an2.last_shot_t < 0.8 else "LOW")
			if an2.reload_st != null:
				est = "RELOAD"
			print("CHOQUE_ARMA t=%.2f %s pen=%.2f %s pitch=%.2f saca=%s fw=%.2f" % [t, est, pmax2, peor2, j.pitch, an2.draw_st != null, an2.fuera_w])
	if OS.get_cmdline_user_args().has("--choque") and a.modelo_mano and a.equipado in ["Bate", "Machete", "Cuchillo"]:
		var largo := {"Bate": 2.28, "Machete": 1.67, "Cuchillo": 0.98}[a.equipado] as float
		var hcf: Transform3D = a.modelo_mano.global_transform
		var peor := ""
		var pmax := 0.0
		for k in 13:
			var pt: Vector3 = hcf * Vector3(0, 0, 0.3 - (largo + 0.3) * k / 12.0)
			for n in j.rig.P:
				if n in ["HumanoidRootPart", "RightHand", "RightLowerArm", "LeftHand", "LeftLowerArm"]:
					continue
				var nd: Node3D = j.rig.P[n]
				var sz: Vector3 = nd.get_meta("size")
				var lp: Vector3 = nd.global_transform.affine_inverse() * pt
				var pen := minf(minf(sz.x * 0.5 - absf(lp.x), sz.y * 0.5 - absf(lp.y)), sz.z * 0.5 - absf(lp.z))
				if pen > pmax:
					pmax = pen
					peor = "%s k=%d" % [n, k]
		var an: Animador = j.get_node("Animador")
		var mt: float = (t - float(an.melee_st.start)) if an.melee_st != null else -1.0
		if pmax > 0.0:
			print("CHOQUE t=%.2f golpe_t=%.2f pen=%.2f %s" % [t, mt, pmax, peor])
	if cam:
		cam.current = true
		var p := j.global_position + Vector3(0, -0.8, 0)
		var r := Basis(Vector3.UP, j.yaw) * Vector3(1, 0, -0.6).normalized()
		var foco := p + Vector3(0, 1, 0)
		var dist := 11.0
		if modo in ["cuchillo", "bate", "machete", "cc"]:
			# de lado, viendo al jugador y al muñeco
			foco = (p + man.global_position + Vector3(0, 2.3, 0)) * 0.5
			r = Basis(Vector3.UP, j.yaw) * (Vector3(1, 0, -1.3).normalized() if OS.get_cmdline_user_args().has("--cam34") else Vector3(1, 0, 0))
			dist = 16.0
		# --cam_az=<grados respecto al frente del jugador> --cam_alt=<studs> --cam_dist=<studs>: vista cercana
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--cam_az="):
				var az := deg_to_rad(float(arg.split("=")[1]))
				r = Basis(Vector3.UP, j.yaw + az) * Vector3(0, 0, -1)
				foco = j.global_position + Vector3(0, 0.6, 0)
				dist = 6.0
			if arg.begins_with("--cam_dist="):
				dist = float(arg.split("=")[1])
		var alt := 1.0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--cam_alt="):
				alt = float(arg.split("=")[1])
		cam.global_position = foco + r * dist + Vector3(0, alt, 0)
		cam.look_at(foco, Vector3.UP)
	if t > (9.5 if modo == "cc" else 7.5):
		_log("fin")
		if modo == "cc":
			_fin_cc()
		get_tree().quit()


## combate cuerpo a cuerpo: guardia (1-1,5 s), patada (1,6), empujón (3,0), parada (4,4), bloqueo (5,2), sin bloquear
## (6,4) y otra patada y otro empujón (otras variantes)
func _paso_cc(a: Arsenal, dt: float) -> void:
	var an: Animador = j.get_node("Animador")
	j.estamina_infinita = true
	var quiere := cc_acc
	if t > 1.0 and t < 9.0 and quiere != "golpes":
		j.aiming = true
	if _una("guardia", t > 1.45) and quiere != "golpes":
		cc_res.guardia = a.cc.guardia or a.cc_clase().begins_with("fuego")
		print("CC t=%.2f guardia=%s clase=%s cc_w=%.2f" % [t, str(a.cc.guardia), a.cc_clase(), an.cc_w])
	if quiere in ["todo", "patada"] and _una("patada", t > 1.6):
		cc_vida0 = man.health
		a.patada()
		print("CC t=%.2f patada var=%s" % [t, str(a.cc.accion["var"]) if a.cc.accion else "-"])
	if quiere in ["todo", "patada"] and _una("tras_patada", t > 2.6):
		cc_res.patada = man.health < cc_vida0 or man._estado != "pie"
		print("CC t=%.2f tras la patada vida_muneco=%.0f (antes %.0f) estado=%s" % [t, man.health, cc_vida0, man._estado])
	if quiere in ["todo", "empujon"] and _una("emp1", t > 3.0):
		a.cc_espacio(true)
		a.cc_espacio(false)
	if quiere in ["todo", "empujon"] and _una("emp2", t > 3.1):
		a.cc_espacio(true)
		a.cc_espacio(false)
		cc_res.empujon = a.cc.accion != null and a.cc.accion.tipo == "empujon"
		print("CC t=%.2f empujon=%s var=%s" % [t, str(cc_res.empujon), str(a.cc.accion["var"]) if a.cc.accion else "-"])
	var desde := man.global_position
	if quiere in ["todo", "bloqueo"]:
		if _una("bloq_on", t > 4.3):
			a.cc_espacio(true)
		if _una("parada", t > 4.45):
			var v0 := j.health
			j.recibir_danio(20.0, desde)
			cc_res.parada = j.health == v0
			print("CC t=%.2f parada: vida %.0f -> %.0f bloqueo=%s" % [t, v0, j.health, str(a.cc.bloqueo)])
		if _una("bloqueo", t > 5.2):
			var v1 := j.health
			j.recibir_danio(20.0, desde)
			cc_res.bloqueo = j.health < v1 and j.health > v1 - 10.0
			print("CC t=%.2f bloqueo: vida %.0f -> %.0f" % [t, v1, j.health])
		if _una("bloq_off", t > 5.8):
			a.cc_espacio(false)
		if _una("sin_bloquear", t > 6.4):
			var v2 := j.health
			j.invencible = false
			j.recibir_danio(4.0, desde)
			cc_res.sin_bloquear = absf((v2 - j.health) - 4.0) < 0.01
			print("CC t=%.2f sin bloquear: vida %.0f -> %.0f" % [t, v2, j.health])
	if quiere == "todo":
		if _una("patada2", t > 7.0):
			a.patada()
			print("CC t=%.2f patada 2 var=%s" % [t, str(a.cc.accion["var"]) if a.cc.accion else "-"])
		if _una("emp3", t > 8.2):
			a.cc_espacio(true)
			a.cc_espacio(false)
			a.cc_espacio(true)
			a.cc_espacio(false)
			print("CC t=%.2f empujon 2 var=%s" % [t, str(a.cc.accion["var"]) if a.cc.accion else "-"])
	if quiere == "golpes":
		# clic izquierdo cada 0,9 s (sin arma: puñetazos; con arma blanca: sus golpes, el de siempre y los nuevos)
		if t < 9.3:
			cc_res["vida_min"] = minf(float(cc_res.get("vida_min", 100.0)), man.health)
		if _una("muneco_duro", t > 1.5) and a.equipado != "":
			man.health = 100.0 # (que el machete no lo mate a los dos golpes: se repone abajo)
		if man.vivo() and man.health < 60.0 and a.equipado != "":
			man.health = 100.0
		var cada := 0.55 if a.equipado == "" else 1.15
		# (2026-11-08, 11: con el muñeco en el suelo el golpe es siempre el de suelo; para ver la variedad se espera a
		# que esté de pie)
		if t > 1.6 and t < 9.0 and fmod(t, cada) < dt and (man.en_pie() or a.equipado == ""):
			if a.equipado == "":
				a.punetazo()
			else:
				a.melee()
			var ac = a.cc.accion
			var tipo: String = (str(ac.tipo) + str(ac["var"])) if ac != null else ("clasico" if an.melee_st != null else "-")
			if ac != null and ac.get("bajo", false):
				tipo = "suelo_" + str(ac.tipo)
			cc_res["vistos"] = cc_res.get("vistos", {})
			print("CC t=%.2f golpe %s vida_muneco=%.0f" % [t, tipo, man.health])
			if tipo != "-":
				(cc_res.vistos as Dictionary)[tipo] = true
		if _una("fin_golpes", t > 9.3):
			var n_vistos: int = (cc_res.get("vistos", {}) as Dictionary).size()
			var vmin: float = cc_res.get("vida_min", 100.0)
			cc_res.erase("vistos")
			cc_res.erase("vida_min")
			cc_res.variedad = n_vistos >= 3
			cc_res.danio = vmin < 100.0
			print("CC golpes distintos=%d vida_muneco=%.0f" % [n_vistos, man.health])
	# impactos con física (Arsenal._cc_impacto): uno por línea
	var imp: Dictionary = a.cc_ultimo_impacto
	if not imp.is_empty() and float(imp.get("t", -1.0)) != float(cc_res.get("_imp_t", -2.0)):
		cc_res["_imp_t"] = float(imp.get("t", -1.0))
		print("CC impacto %s dv=%.1f v_golpe=%.1f pieza=%s cae=%s p=%.2f pos_muneco=%s" % [imp.tipo, float(imp.dv), float(imp.get("v_golpe", 0.0)),
			imp.pieza, str(imp.cae), float(imp.get("p", 0.0)), str(man.global_position)])
	if OS.get_cmdline_user_args().has("--logcc") and fmod(t, 0.1) < dt:
		print("CCLOG t=%.2f w=%.2f guard=%.2f block=%.2f kick=%s acc=%s pos=%s pelvis_rel=%.2f pecho_rel=%s pieR=%s" % [t, an.cc_w, an.cc_guard_w, an.cc_block_w, str(an.cc_kick), str(a.cc.accion.tipo) if a.cc.accion else "-", j.global_position, (j.rig.P.LowerTorso as Node3D).global_position.y - j.global_position.y, str(j.root_cf().affine_inverse() * (j.rig.P.UpperTorso as Node3D).global_position), str(j.root_cf().affine_inverse() * (j.rig.P.RightFoot as Node3D).global_position)])


func _fin_cc() -> void:
	var fallos := []
	cc_res.erase("_imp_t")
	for k in cc_res:
		if not cc_res[k]:
			fallos.append(k)
	var nombre := arma_x if arma_x != "" else "manos"
	print(("OK cc_" + nombre) if fallos.is_empty() else ("MAL cc_%s: falla %s" % [nombre, ", ".join(fallos)]))

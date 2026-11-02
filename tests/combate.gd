extends Node
## Prueba de combate: equipar, disparar a un muñeco, recargar, golpear con armas blancas.
## --modo=<pistola|rifle|cuchillo|bate|machete|cambiar|apoyar> ; con --video la cámara sigue al jugador.
## --arma=<Nombre> (cualquier arma de Armas.WEAPONS, p. ej. Escopeta): se la da y la prueba igual.
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
	j = get_parent().get_node("Jugador")
	if OS.get_cmdline_user_args().has("--video") and not OS.get_cmdline_user_args().has("--camjuego"):
		cam = Camera3D.new()
		add_child(cam)
		cam.fov = 45
	call_deferred("_inicio")

func _inicio() -> void:
	man = get_parent().get_node("Maniquies/Maniqui_0")
	var cerca := modo in ["cuchillo", "bate", "machete"]
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
	var slot: int = {"pistola": 0, "rifle": 1, "cuchillo": 2, "bate": 3, "machete": 3, "cambiar": 0, "apoyar": 1}[modo]
	if arma_x != "":
		if _una("dar", t > 0.2):
			a.dar_arma(arma_x, false)
		for k in Armas.SLOTS.size():
			if Armas.SLOTS[k].Id == Armas.WEAPONS[arma_x].Slot:
				slot = k
	if modo == "machete" and _una("coger", t > 0.2):
		# el machete está en el suelo cerca del inicio: se lleva al jugador
		var s = a.suelo[0]
		j.global_position = (s.nodo as Node3D).global_position + Vector3(0, 3.2, 0)
		a._recoger()
		_inicio()
		_log("recogido")
	if _una("equipar", t > 0.5):
		a.select_slot(slot)
		_log("equipar")
	if modo in ["pistola", "rifle", "apoyar"]:
		if modo == "apoyar" and _una("x", t > 2.0):
			j.aiming = true
			a.set_rest(true)
			_log("apoyar rest=%s gap=%s" % [str(a.rest != null), str(a.rest.gap if a.rest else -1)])
		if t > 1.8 and t < 4.5:
			j.aiming = true
			if modo == "rifle":
				j.firing = t > 2.2 and t < 3.4
			elif fmod(t, 0.4) < dt and t > 2.2:
				a.shoot()
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
				for n in ["UpperTorso", "LowerTorso"]:
					var nd: Node3D = j.rig.P[n]
					var sz: Vector3 = nd.get_meta("size")
					var lp: Vector3 = nd.global_transform.affine_inverse() * pt
					var pen := minf(minf(sz.x * 0.5 - absf(lp.x), sz.y * 0.5 - absf(lp.y)), sz.z * 0.5 - absf(lp.z))
					if pen > pmax2:
						pmax2 = pen
						peor2 = "%s en %s" % [mi.name, n]
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
		if modo in ["cuchillo", "bate", "machete"]:
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
	if t > 7.5:
		_log("fin")
		get_tree().quit()

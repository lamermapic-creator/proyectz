extends Node
## RECORRIDO de jugabilidad (revisión 2026-10-27): escenarios jugados como un jugador, con la CÁMARA DEL JUEGO.
## --escenario=<nombre>; --video para grabar (con --write-movie). Imprime "RECORRIDO <escenario> ..." con medidas:
##   cam_tiron   = mayor tirón de la cámara (cambio brusco de su velocidad entre fotogramas, studs/fotograma)
##   cam_dentro  = fotogramas con la cámara metida en el escenario
##   pie_resbala = mayor deslizamiento de un pie apoyado (studs/s) y fotogramas con resbalón > 2 studs/s
##   ms_jugador  = coste medio del _process (ms)
var j: Jugador
var t := 0.0
var esc := "andar"
var evs: Array = []
var cam_lado: Camera3D = null
var posturas := {}
var _hist := {}
var giro := 0.0          # rad/s de giro de la cámara (ratón)
var giro_p := 0.0
var fuego := false
var M := 1.0 / 0.31
var medidas := {"cam_tiron": 0.0, "cam_dentro": 0, "pie_resbala": 0.0, "resbalones": 0, "ms": 0.0, "n": 0, "vmax": 0.0}
var _cam_prev = null
var _cam_v_prev = null
var _pies_prev := {}
var _mag_prev := -1

## [posición (studs), yaw, duración, eventos [t, acción, valor]]
## acciones: k (tecla abajo), ku (tecla arriba), giro (rad/s de yaw), pitch (rad/s), apunta (bool), fuego (bool),
## golpe, ranura (0..3)
const ESC := {
	"andar": [Vector3(-100, 3.2, 100), 0.0, 7.0, [[0.4, "k", KEY_W], [2.2, "ku", KEY_W], [2.6, "giro", 1.6], [3.6, "giro", 0.0],
		[3.8, "k", KEY_W], [4.6, "k", KEY_A], [5.4, "ku", KEY_A], [5.4, "ku", KEY_W], [5.5, "k", KEY_S], [6.4, "ku", KEY_S]]],
	"correr_giro": [Vector3(-100, 3.2, 100), 0.0, 7.0, [[0.4, "k", KEY_W], [0.4, "k", KEY_SHIFT], [2.0, "giro", -1.2],
		[3.6, "giro", 0.0], [4.0, "giro", 2.5], [4.6, "giro", 0.0], [5.2, "ku", KEY_W], [5.2, "ku", KEY_SHIFT]]],
	"saltos": [Vector3(-100, 3.2, 100), 0.0, 6.0, [[0.6, "k", KEY_SPACE], [0.65, "ku", KEY_SPACE], [2.2, "k", KEY_W],
		[2.2, "k", KEY_SHIFT], [3.2, "k", KEY_SPACE], [3.25, "ku", KEY_SPACE], [4.6, "ku", KEY_W], [4.6, "ku", KEY_SHIFT]]],
	"agacharse": [Vector3(-100, 3.2, 100), 0.0, 10.0, [[0.4, "k", KEY_C], [0.45, "ku", KEY_C], [1.0, "k", KEY_W], [3.0, "ku", KEY_W],
		[3.4, "k", KEY_Z], [3.45, "ku", KEY_Z], [5.2, "k", KEY_W], [7.2, "ku", KEY_W], [7.6, "k", KEY_SPACE], [7.65, "ku", KEY_SPACE],
		[8.6, "k", KEY_SPACE], [8.65, "ku", KEY_SPACE]]],
	"vallar": [Vector3(-6.45, 3.2, 33), PI, 4.0, [[0.3, "k", KEY_W], [0.3, "k", KEY_SHIFT], [0.7, "k", KEY_SPACE], [0.75, "ku", KEY_SPACE],
		[2.8, "ku", KEY_W], [2.8, "ku", KEY_SHIFT]]],
	"trepar": [Vector3(0, 3.2, -17), 0.0, 5.0, [[0.3, "k", KEY_W], [0.3, "k", KEY_SHIFT], [1.0, "k", KEY_SPACE], [1.05, "ku", KEY_SPACE],
		[3.0, "ku", KEY_W], [3.0, "ku", KEY_SHIFT]]],
	# muro con hueco debajo (techo del túnel de 1,4 m: la cara empieza a la altura de la cabeza; 2026-11-08)
	"dintel": [Vector3(12.9, 3.2, 17.0), PI, 5.0, [[0.3, "k", KEY_W], [1.3, "k", KEY_SPACE], [1.35, "ku", KEY_SPACE], [3.5, "ku", KEY_W]]],
	"dintel_bajo": [Vector3(38.7, 3.2, 17.0), PI, 5.0, [[0.3, "k", KEY_W], [1.3, "k", KEY_SPACE], [1.35, "ku", KEY_SPACE], [3.5, "ku", KEY_W]]],
	"cornisa": [Vector3(-112.9, 3.2, -76.4), 0.0, 8.0, [[0.4, "k", KEY_SPACE], [0.45, "ku", KEY_SPACE], [1.6, "k", KEY_A], [4.6, "ku", KEY_A],
		[5.2, "k", KEY_SPACE], [5.25, "ku", KEY_SPACE]]],
	"escalera": [Vector3(-64.5, 3.2, 4), PI, 8.0, [[0.3, "k", KEY_W], [4.0, "ku", KEY_W], [4.2, "giro", 3.14], [5.2, "giro", 0.0],
		[5.3, "k", KEY_W], [7.8, "ku", KEY_W]]],
	"pared_cam": [Vector3(0, 3.2, 62.6), 0.0, 9.0, [[0.5, "giro", 0.8], [8.4, "giro", 0.0]]],
	"rifle": [Vector3(70, 3.2, 0), -PI / 2, 9.0, [[0.3, "ranura", 1], [1.4, "apunta", true], [1.8, "fuego", true], [2.4, "fuego", false],
		[2.8, "fuego", true], [3.6, "fuego", false], [3.8, "k", KEY_A], [4.8, "ku", KEY_A], [4.8, "fuego", true], [5.4, "fuego", false],
		[5.6, "apunta", false], [5.8, "k", KEY_R], [5.85, "ku", KEY_R]]],
	"giro_disparo": [Vector3(-100, 3.2, 100), 0.0, 4.0, [[0.3, "ranura", 1], [1.4, "apunta", true], [1.6, "giro", 20.0], [1.7, "giro", 0.0],
		[1.7, "fuego", true], [3.5, "fuego", false]]],
	"danio": [Vector3(70, 3.2, 0), -PI / 2, 9.0, [[0.4, "ranura", 1], [1.0, "danio", [18.0, Vector3(0, 0, 10)]], [2.0, "danio", [22.0, Vector3(10, 0, 0)]],
		[3.0, "danio", [25.0, Vector3(-8, 0, -8)]], [4.2, "danio", [40.0, Vector3(0, 0, -10)]]]],
	# (sentado); W mirando abajo: se deja resbalar sentado hasta abajo
	"rampa50": [Vector3(71, 3.2, -33), 0.0, 6.0, [[0.4, "k", KEY_W], [5.0, "ku", KEY_W]]],
	"derribo_llano": [Vector3(-100, 3.2, 100), 0.0, 7.0, [[1.0, "derriba", 0]]],
	"pistola_bate": [Vector3(70, 3.2, 0), -PI / 2, 9.0, [[0.3, "ranura", 0], [1.3, "apunta", true], [1.6, "fuego", true], [1.65, "fuego", false],
		[2.0, "fuego", true], [2.05, "fuego", false], [2.4, "fuego", true], [2.45, "fuego", false], [2.8, "apunta", false],
		[3.0, "ranura", 3], [4.0, "k", KEY_W], [5.6, "ku", KEY_W], [5.7, "golpe", 0], [6.6, "golpe", 0], [7.4, "golpe", 0]]],
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--escenario="):
			esc = a.split("=")[1]
	j = get_parent().get_node("Jugador")
	var e: Array = ESC[esc]
	evs = (e[3] as Array).duplicate(true)
	call_deferred("_inicio")


func _inicio() -> void:
	var e: Array = ESC[esc]
	j.teletransportar(e[0], e[1])
	j.yaw = e[1]
	j.pitch = -0.12
	if esc == "pistola_bate":
		# un muñeco delante, a tiro de bate después de andar un poco
		var man := Maniqui.new()
		man.position = Vector3(48, 0, 0)
		man.rotation = Vector3(0, PI / 2, 0)
		get_parent().add_child(man)


func _key(k: int, p: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = p
	Input.parse_input_event(ev)


func _process(dt: float) -> void:
	t += dt
	while not evs.is_empty() and t >= float(evs[0][0]):
		var ev: Array = evs.pop_front()
		match str(ev[1]):
			"k": _key(int(ev[2]), true)
			"ku": _key(int(ev[2]), false)
			"giro": giro = float(ev[2])
			"pitch": giro_p = float(ev[2])
			"apunta": j.aiming = bool(ev[2])
			"fuego":
				fuego = bool(ev[2])
				j.firing = fuego
				if fuego:
					j.arsenal.shoot()
			"golpe": j.arsenal.melee()
			"danio":
				var dd: Array = ev[2]
				j.recibir_danio(float(dd[0]), j.global_position + (dd[1] as Vector3))
			"ranura": j.arsenal.select_slot(int(ev[2]))
			"estamina": j.stamina = float(ev[2])
			"derriba": j.ragdoll_iniciar(Vector3(0, 6, 10), {"comportamiento": "caer", "duracion": 1.2})
	if OS.get_cmdline_user_args().has("--cam_lado"):
		# cámara fija de lado (para ver posturas), en vez de la del juego
		if cam_lado == null:
			cam_lado = Camera3D.new()
			add_child(cam_lado)
			cam_lado.fov = 40
		cam_lado.current = true
		var foco := j.global_position + Vector3(0, 0.5, 0)
		cam_lado.global_position = foco + Vector3(16, 3.5, 2)
		# --cam_az=<grados> --cam_dist=<studs> --cam_alt=<studs>: de cerca, desde donde se pida (2026-10-29)
		var az := 1e9
		var dist_c := 9.0
		var alt_c := 2.0
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("--cam_az="): az = deg_to_rad(float(a2.split("=")[1]))
			if a2.begins_with("--cam_dist="): dist_c = float(a2.split("=")[1])
			if a2.begins_with("--cam_alt="): alt_c = float(a2.split("=")[1])
			if a2.begins_with("--cam_fov="): cam_lado.fov = float(a2.split("=")[1])
		if az < 1e8:
			foco = (j.rig.P.LowerTorso as Node3D).global_position
			cam_lado.global_position = foco + Vector3(cos(az), 0, sin(az)) * dist_c + Vector3(0, alt_c, 0)
		cam_lado.look_at(foco, Vector3.UP)
	if OS.get_cmdline_user_args().has("--suavidad"):
		# tirones de la animación: salto de cada pieza (respecto a donde "debería" estar siguiendo su velocidad)
		var post := "-"
		for pz in ["Head", "LowerTorso", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
			var pp: Vector3 = (j.rig.P[pz] as Node3D).global_position
			var hist: Array = _hist.get(pz, [])
			if hist.size() >= 2:
				var pred: Vector3 = hist[-1] + (hist[-1] - hist[-2])
				var err := (pp - pred).length()
				if err > 0.25:
					print("TIRON t=%.2f %s %.2f studs postura=%s" % [t, pz, err, post])
			hist.append(pp)
			if hist.size() > 2:
				hist.pop_front()
			_hist[pz] = hist
	if esc == "derribo_llano" and t > 0.5:
		_auditar(dt)
	j.yaw += giro * dt
	j.pitch = clampf(j.pitch + giro_p * dt, -1.2, 1.2)
	if fuego:
		j.firing = true
	_medir(dt)
	if esc == "giro_disparo" and t > 1.55 and t < 2.6:
		var mg := int(j.arsenal.datos_equipado().get("mag", -1))
		if fuego and fmod(t, 0.02) < dt:
			j.arsenal.shoot()
		if mg != _mag_prev:
			print("DISPARO t=%.3f mag=%d giro_cuerpo=%.2f yaw=%.2f" % [t, mg, Rbx.yaw_of(j.root_cf()), j.yaw])
		_mag_prev = mg
	if OS.get_cmdline_user_args().has("--velocidades") and fmod(t, 0.1) < dt:
		print("VEL t=%.2f v=%.2f yaw_cuerpo=%.2f yaw_cam=%.2f" % [t, Rbx.flat(j.vel_real).length(), Rbx.yaw_of(j.root_cf()), j.yaw])
	if t > float(ESC[esc][2]):
		print("RECORRIDO %s cam_tiron=%.3f cam_dentro=%d pie_resbala=%.2f resbalones=%d ms_jugador=%.2f vmax=%.1f estado=%s vida=%.0f" % [
			esc, medidas.cam_tiron, medidas.cam_dentro, medidas.pie_resbala, medidas.resbalones,
			medidas.ms / maxf(1.0, medidas.n), medidas.vmax, j.estado, j.health])
		if esc.begins_with("dintel"):
			# tiene que acabar encima del techo del túnel (1,4 m: 5,48 studs; 0,8 m: 3,55)
			var pies := j.global_position.y - j.center_cur
			var alto := 5.48 if esc == "dintel" else 3.55
			print("DINTEL pies_y=%.2f pos=%s" % [pies, str(j.global_position)])
			print(("OK recorrido_" + esc) if absf(pies - alto) < 0.3 else ("MAL recorrido_%s: no subió (pies a %.2f, techo a %.2f)" % [esc, pies, alto]))
		if esc == "derribo_llano":
			print("AUDITORIA %s metido=%d (max pieza %s) tirones=%d max=%.2f %s" % [esc, aud.metido, str(aud.metido_pz), aud.tiron, aud.tiron_max, str(aud.tiron_pz)])
			var fallos := []
			if aud.tiron_max > 1.6: fallos.append("tirón de %.1f studs en un fotograma (al levantarse)" % aud.tiron_max)
			print(("OK recorrido_" + esc) if fallos.is_empty() else ("MAL recorrido_%s: %s" % [esc, ", ".join(fallos)]))
		get_tree().quit()


## AUDITORÍA (2026-10-30): partes del cuerpo metidas en el escenario, tirones, personaje invisible,
## cuerpo separado de su cápsula, disparos que no van a la mira, caídas por el suelo
var aud := {"metido": 0, "metido_max": 0.0, "metido_pz": {}, "tiron": 0, "tiron_max": 0.0, "tiron_pz": {}, "invisible": 0,
	"separado": 0, "disparo_desvio": 0.0, "disparos": 0, "y_min": 1e9, "y_max": -1e9, "salidas": 0}
var _aud_prev := {}
var _aud_en := false
var _aud_mag := -1


func _auditar(dt: float) -> void:
	var en := false
	if en != _aud_en:
		if not en:
			aud.salidas += 1
		_aud_en = en
	aud.y_min = minf(aud.y_min, j.global_position.y)
	aud.y_max = maxf(aud.y_max, j.global_position.y)
	if j.ragdoll != null:
		_aud_prev.clear()
		return
	var space := j.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1
	q.exclude = j._excluir()
	for pz in ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand",
			"RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"]:
		var nd: Node3D = j.rig.P.get(pz)
		if nd == null:
			continue
		var pp := nd.global_position
		# ¿metida en el escenario? (el centro de la pieza dentro de algo sólido)
		q.position = pp
		if not space.intersect_point(q, 1).is_empty():
			aud.metido += 1
			var clave_m: String = pz
			aud.metido_pz[clave_m] = int(aud.metido_pz.get(clave_m, 0)) + 1
			if OS.get_cmdline_user_args().has("--metido"):
				print("AUD metido t=%.2f %s" % [t, clave_m])
		# tirón: salto respecto a seguir con la misma velocidad
		var h: Array = _aud_prev.get(pz, [])
		if h.size() >= 2:
			var err := (pp - ((h[-1] as Vector3) * 2.0 - (h[-2] as Vector3))).length()
			if err > 0.55:
				aud.tiron += 1
				aud.tiron_pz[pz] = int(aud.tiron_pz.get(pz, 0)) + 1
				if OS.get_cmdline_user_args().has("--detalle"):
					print("AUD tiron t=%.2f %s %.2f postura=%s" % [t, pz, err, "-"])
			aud.tiron_max = maxf(aud.tiron_max, err)
		h.append(pp)
		if h.size() > 2:
			h.pop_front()
		_aud_prev[pz] = h
	if j.fade_cur > 0.6:
		aud.invisible += 1
	var lt: Vector3 = (j.rig.P.LowerTorso as Node3D).global_position
	if lt.distance_to(j.global_position) > 3.5:
		aud.separado += 1
	# disparos: ¿la bala va a donde marca la mira?
	var mg := int(j.arsenal.datos_equipado().get("mag", -1)) if j.arsenal.equipado != "" else -1
	if _aud_mag >= 0 and mg >= 0 and mg < _aud_mag:
		aud.disparos += 1
		var mdl: Node3D = j.arsenal.modelo_mano
		if mdl and mdl.has_node("Muzzle"):
			var mz := (mdl.get_node("Muzzle") as Node3D).global_transform
			var obj: Vector3 = j.arsenal.punto_mira() - mz.origin
			var ang := rad_to_deg((-mz.basis.z).angle_to(obj))
			# (la mira sobre el suelo a un paso no cuenta: el arma no puede apuntar a sus pies)
			if obj.length() > 4.0:
				aud.disparo_desvio = maxf(aud.disparo_desvio, ang)
			if OS.get_cmdline_user_args().has("--detalle"):
				print("AUD disparo t=%.2f desvio=%.1f° postura=%s dist_mira=%.1f mz=%s dir=%s obj=%s cam=%s" % [t, ang, "-", obj.length(), mz.origin, -mz.basis.z, obj.normalized(), j.camara.global_position])
	_aud_mag = mg


func _medir(dt: float) -> void:
	if t < 0.8 or dt <= 0.0:
		return
	medidas.n += 1
	medidas.ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	medidas.vmax = maxf(medidas.vmax, Rbx.flat(j.vel_real).length())
	var c: Vector3 = j.camara.global_position
	if _cam_prev != null:
		var v: Vector3 = c - (_cam_prev as Vector3)
		if _cam_v_prev != null:
			var tir := (v - (_cam_v_prev as Vector3)).length()
			if tir > 0.25 and OS.get_cmdline_user_args().has("--detalle"):
				var hd: Vector3 = (j.rig.P.Head as Node3D).global_position
				print("TIRON t=%.2f %.2f aiming=%s estado=%s stance=%d cam_cabeza=%.2f fade=%.2f cam_dist=%.2f" % [t, tir, str(j.aiming), j.estado, j.stance, c.distance_to(hd), j.fade_cur, j.cam_dist])
			medidas.cam_tiron = maxf(medidas.cam_tiron, tir)
		_cam_v_prev = v
	_cam_prev = c
	# ¿cámara metida en el escenario?
	var q := PhysicsPointQueryParameters3D.new()
	q.position = c
	q.collision_mask = 1
	if not j.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
		medidas.cam_dentro += 1
	# pies apoyados que resbalan
	var an := j.get_node_or_null("Animador") as Animador
	if an == null or j.moto != null:
		return
	for s in ["L", "R"]:
		var f: Dictionary = an.feet[s]
		var nodo: Node3D = j.rig.P.LeftFoot if s == "L" else j.rig.P.RightFoot
		# talón y punta de la suela (el pie apoyado rueda sobre uno de los dos: ese no debe moverse)
		var tf := nodo.global_transform
		var talon := tf * Vector3(0, -0.15, 0.5)
		var punta := tf * Vector3(0, -0.15, -0.5)
		if f.swing == null and j.estado == "Running" and j.stance < 2 and _pies_prev.has(s):
			var pr: Array = _pies_prev[s]
			var vt := Rbx.flat(talon - (pr[0] as Vector3)).length() / dt
			var vp := Rbx.flat(punta - (pr[1] as Vector3)).length() / dt
			var vel := minf(vt, vp)
			if vel > 2.0:
				medidas.resbalones += 1
				if OS.get_cmdline_user_args().has("--detalle"):
					print("RESBALA t=%.2f pie=%s v_pie=%.1f v_cuerpo=%.1f" % [t, s, vel, Rbx.flat(j.vel_real).length()])
			medidas.pie_resbala = maxf(medidas.pie_resbala, vel)
		_pies_prev[s] = [talon, punta]

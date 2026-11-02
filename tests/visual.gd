extends Node
## Prueba visual: guía al jugador por distintos escenarios y una cámara lateral lo sigue.
## Escenario elegido con el argumento --escenario=<nombre> (tras "--").
var j: Jugador
var cam: Camera3D
var t := 0.0
var esc := "plano"
var keys := {}
var evs: Array = []

const ESC := {
	# nombre: [posición inicial (studs), yaw, duración, eventos [t, tecla, pulsada]]
	"plano": [Vector3(-100, 3.2, 100), 0.0, 4.0, [[0.3, KEY_W, true]]],
	"correr": [Vector3(-100, 3.2, 100), 0.0, 4.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"rampa30": [Vector3(51.6, 3.2, -26), 0.0, 4.0, [[0.3, KEY_W, true]]],
	"rampa30c": [Vector3(51.6, 3.2, -26), 0.0, 3.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"rampa15": [Vector3(32.3, 3.2, -26), 0.0, 4.0, [[0.3, KEY_W, true]]],
	"escalera": [Vector3(-64.5, 3.2, 4), PI, 5.0, [[0.3, KEY_W, true]]],
	"trepar": [Vector3(0, 3.2, -24), 0.0, 4.0, [[0.3, KEY_W, true], [1.3, KEY_SPACE, true], [1.35, KEY_SPACE, false], [1.6, KEY_SPACE, true], [1.65, KEY_SPACE, false]]],
	"saltar": [Vector3(-19.35, 3.2, -22), 0.0, 3.5, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [0.95, KEY_SPACE, true], [1.05, KEY_SPACE, false]]],
	"bajar": [Vector3(-64.5, 9.9, 33), 0.0, 4.0, [[0.3, KEY_W, true]]],
	"bajar_c": [Vector3(-64.5, 9.9, 33), 0.0, 3.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"rampa_bajar_c": [Vector3(51.6, 12.8, -63), PI, 3.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"strafe_c": [Vector3(-100, 3.2, 100), 0.0, 4.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.3, KEY_A, true], [2.0, KEY_A, false], [2.0, KEY_D, true], [2.8, KEY_D, false]]],
	"strafe_ad": [Vector3(-100, 3.2, 100), 0.0, 4.0, [[0.3, KEY_SHIFT, true], [0.3, KEY_A, true], [1.2, KEY_A, false], [1.2, KEY_D, true], [2.1, KEY_D, false], [2.1, KEY_A, true], [3.0, KEY_A, false]]],
	"borde": [Vector3(0, 7.0, -32.3), PI, 3.5, [[0.3, KEY_W, true], [1.1, KEY_W, false], [1.8, KEY_W, true], [2.0, KEY_W, false]]],
	"mesa": [Vector3(-19.35, 3.2, 36), PI, 3.5, [[0.3, KEY_W, true]]],
	"mesa_c": [Vector3(-19.35, 3.2, 33), PI, 3.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"correr_girar": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"correr_girar_d": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.5, KEY_D, true], [2.5, KEY_D, false], [3.0, KEY_A, true], [4.0, KEY_A, false]]],
	"trepar_cerca": [Vector3(0, 3.2, -24.5), 0.0, 3.5, [[0.4, KEY_SPACE, true], [0.45, KEY_SPACE, false]]],
	"trepar_lejos": [Vector3(0, 3.2, -23), 0.0, 4.0, [[0.5, KEY_SPACE, true], [0.55, KEY_SPACE, false]]],
	"trepar_lejos_c": [Vector3(0, 3.2, -10), 0.0, 4.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.05, KEY_SPACE, true], [1.1, KEY_SPACE, false]]],
	"trepar_c": [Vector3(0, 3.2, -17), 0.0, 4.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.0, KEY_SPACE, true], [1.05, KEY_SPACE, false]]],
	"saltar_pared": [Vector3(0, 3.2, -13), 0.0, 4.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.0, KEY_SPACE, true], [1.05, KEY_SPACE, false]]],
	"reptar": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.2, KEY_Z, true], [0.25, KEY_Z, false], [1.8, KEY_W, true]]],
	"reptar_c": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.2, KEY_Z, true], [0.25, KEY_Z, false], [1.8, KEY_W, true], [1.8, KEY_SHIFT, true]]],
	"fatiga": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.3, KEY_W, true]]],
	# 2026-11-02: marcha agachado y transiciones (andar -> correr -> andar -> parar)
	"agachado_andar": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.2, KEY_C, true], [0.25, KEY_C, false], [1.0, KEY_W, true]]],
	"agachado_correr": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.2, KEY_C, true], [0.25, KEY_C, false], [1.0, KEY_W, true], [1.0, KEY_SHIFT, true]]],
	"trepar_rifle": [Vector3(0, 3.2, -15), 0.0, 6.0, [[1.4, KEY_W, true], [1.4, KEY_SHIFT, true], [2.05, KEY_SPACE, true], [2.1, KEY_SPACE, false]]],
	"levantarse_boca_arriba": [Vector3(-100, 3.2, 100), 0.0, 8.0, [[0.2, KEY_Z, true], [0.25, KEY_Z, false], [4.6, KEY_SPACE, true], [4.65, KEY_SPACE, false], [6.2, KEY_SPACE, true], [6.25, KEY_SPACE, false]]],
	"levantarse_boca_abajo": [Vector3(-100, 3.2, 100), 0.0, 7.0, [[0.2, KEY_Z, true], [0.25, KEY_Z, false], [2.6, KEY_SPACE, true], [2.65, KEY_SPACE, false], [4.4, KEY_SPACE, true], [4.45, KEY_SPACE, false]]],
	"salto_parado": [Vector3(-100, 3.2, 100), 0.0, 3.5, [[0.8, KEY_SPACE, true], [0.85, KEY_SPACE, false], [2.2, KEY_SPACE, true], [2.25, KEY_SPACE, false]]],
	"salto_correr": [Vector3(-100, 3.2, 100), 0.0, 4.5, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.6, KEY_SPACE, true], [1.65, KEY_SPACE, false], [3.0, KEY_SPACE, true], [3.05, KEY_SPACE, false]]],
	"transiciones": [Vector3(-100, 3.2, 100), 0.0, 7.0, [[0.3, KEY_W, true], [1.8, KEY_SHIFT, true], [3.6, KEY_SHIFT, false], [5.0, KEY_W, false]]],
	"correr_rifle": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.4, KEY_W, true], [1.4, KEY_SHIFT, true]]],
	"andar_pistola": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.4, KEY_W, true]]],
	"tumbado_rifle": [Vector3(-100, 3.2, 100), 0.0, 6.0, [[1.4, KEY_Z, true], [1.45, KEY_Z, false], [3.6, KEY_W, true], [4.6, KEY_W, false]]],
	"cuchillo_correr": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.2, KEY_W, true], [1.2, KEY_SHIFT, true]]],
	"pistola_correr": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.2, KEY_W, true], [1.2, KEY_SHIFT, true]]],
	"bate_correr": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.2, KEY_W, true], [1.2, KEY_SHIFT, true]]],
	"pistola_andar": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.2, KEY_W, true]]],
	"rampa15c": [Vector3(32.3, 3.2, -26), 0.0, 3.5, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"rampa50c": [Vector3(70.97, 3.2, -26), 0.0, 3.5, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"rampa50": [Vector3(70.97, 3.2, -26), 0.0, 4.5, [[0.3, KEY_W, true]]],
	"colgar": [Vector3(-112.9, 3.2, -76.4), 0.0, 9.0, [[0.4, KEY_SPACE, true], [0.45, KEY_SPACE, false], [1.6, KEY_A, true], [6.2, KEY_A, false], [6.8, KEY_SPACE, true], [6.85, KEY_SPACE, false]]],
	"colgar_rapido": [Vector3(-112.9, 3.2, -76.4), 0.0, 6.0, [[0.4, KEY_SPACE, true], [0.45, KEY_SPACE, false], [1.6, KEY_SHIFT, true], [1.6, KEY_A, true], [4.0, KEY_A, false], [4.0, KEY_SHIFT, false]]],
	"colgar_lento": [Vector3(-112.9, 3.2, -76.4), 0.0, 6.0, [[0.4, KEY_SPACE, true], [0.45, KEY_SPACE, false], [1.6, KEY_A, true], [4.0, KEY_A, false]]],
	"colgar_d": [Vector3(-101.0, 3.2, -76.4), 0.0, 7.0, [[0.4, KEY_SPACE, true], [0.45, KEY_SPACE, false], [1.6, KEY_D, true], [5.5, KEY_D, false], [6.0, KEY_S, true], [6.1, KEY_S, false]]],
	"colgar_salto": [Vector3(19.35, 3.2, -16), 0.0, 6.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [0.95, KEY_SPACE, true], [1.0, KEY_SPACE, false], [1.0, KEY_W, false], [1.0, KEY_SHIFT, false], [3.0, KEY_SPACE, true], [3.05, KEY_SPACE, false]]],
	"colgar_corre": [Vector3(-110.0, 3.2, -62), 0.0, 5.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [1.0, KEY_SPACE, true], [1.05, KEY_SPACE, false], [1.05, KEY_W, false], [1.05, KEY_SHIFT, false]]],
	"boca_arriba_rifle": [Vector3(-100, 3.2, 100), 0.0, 8.0, [[1.4, KEY_Z, true], [1.45, KEY_Z, false]]],
	"recoger": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[0.6, KEY_F, true], [0.65, KEY_F, false]]],
	"recoger_pistola": [Vector3(-100, 3.2, 100), 0.0, 5.5, [[1.4, KEY_F, true], [1.45, KEY_F, false]]],
	"recoger_tumbado": [Vector3(-97, 3.2, 99), 0.0, 5.0, [[0.3, KEY_Z, true], [0.35, KEY_Z, false], [2.2, KEY_F, true], [2.25, KEY_F, false]]],
	"pared": [Vector3(0, 3.2, 54), PI, 3.0, [[0.3, KEY_W, true]]],
	"pared_c": [Vector3(0, 3.2, 44), PI, 3.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true]]],
	"vallar": [Vector3(-6.45, 3.2, 36), PI, 3.0, [[0.3, KEY_W, true], [0.8, KEY_SPACE, true], [0.85, KEY_SPACE, false], [1.0, KEY_SPACE, true], [1.05, KEY_SPACE, false], [1.2, KEY_SPACE, true], [1.25, KEY_SPACE, false]]],
	"strafe_rifle": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.4, KEY_A, true], [2.8, KEY_A, false], [2.8, KEY_D, true], [4.4, KEY_D, false]]],
	"strafe_pistola": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.4, KEY_A, true], [2.8, KEY_A, false], [2.8, KEY_D, true], [4.4, KEY_D, false]]],
	"strafe_rifle_apunta": [Vector3(-100, 3.2, 100), 0.0, 5.0, [[1.4, KEY_A, true], [2.8, KEY_A, false], [2.8, KEY_D, true], [4.4, KEY_D, false]]],
	"strafe_libre": [Vector3(-100, 3.2, 100), 0.0, 4.0, [[0.4, KEY_A, true], [1.8, KEY_A, false], [1.8, KEY_D, true], [3.4, KEY_D, false]]],
	"pared_rifle": [Vector3(0, 3.2, 56), PI, 6.0, [[1.4, KEY_W, true], [3.4, KEY_W, false]]],
	"pared_pistola": [Vector3(0, 3.2, 56), PI, 6.0, [[1.4, KEY_W, true], [3.4, KEY_W, false]]],
	"pared_espalda": [Vector3(0, 3.2, 62.6), 0.0, 7.0, []],
	"pared_lado": [Vector3(0, 3.2, 62.6), -PI / 2, 7.0, []],
	"zoom": [Vector3(-100, 3.2, 100), 0.0, 5.0, []],
	"tiro_campo": [Vector3(-100, 3.2, 100), 0.0, 4.5, []],
	"vallar_c": [Vector3(-6.45, 3.2, 33), PI, 3.0, [[0.3, KEY_W, true], [0.3, KEY_SHIFT, true], [0.7, KEY_SPACE, true], [0.75, KEY_SPACE, false], [0.85, KEY_SPACE, true], [0.9, KEY_SPACE, false], [1.0, KEY_SPACE, true], [1.05, KEY_SPACE, false]]],
}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--escenario="):
			esc = a.split("=")[1]
	j = get_parent().get_node("Jugador")
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 45
	cam.current = true
	var e: Array = ESC[esc]
	j.global_position = e[0]
	j.rotation.y = e[1]
	j.yaw = e[1]
	evs = (e[3] as Array).duplicate(true)

func _key(k: int, p: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = p
	Input.parse_input_event(ev)

func _process(dt: float) -> void:
	t += dt
	var e: Array = ESC[esc]
	if esc == "correr_girar":
		# ratón: giro continuo y luego un giro brusco
		if t > 1.3 and t < 2.6:
			j.yaw += 1.6 * dt
		elif t > 3.2 and t < 3.5:
			j.yaw -= 6.0 * dt
	while not evs.is_empty() and t >= evs[0][0]:
		var ev: Array = evs.pop_front()
		_key(ev[1], ev[2])
	cam.current = not OS.get_cmdline_user_args().has("--camjuego")
	if not cam.current:
		j.camara.current = true
	var armas_esc := {"recoger_pistola": 0, "boca_arriba_rifle": 1, "pistola_correr": 0, "bate_correr": 3, "pistola_andar": 0, "correr_rifle": 1, "andar_pistola": 0, "tumbado_rifle": 1, "cuchillo_correr": 2, "strafe_rifle": 1, "strafe_pistola": 0, "strafe_rifle_apunta": 1, "pared_rifle": 1, "pared_pistola": 0, "tiro_campo": 1, "trepar_rifle": 1}
	if armas_esc.has(esc) and t > 0.1 and j.arsenal.equipado == "" and j.arsenal.switching == null and not get_meta("eq", false):
		set_meta("eq", true)
		j.arsenal.select_slot(armas_esc[esc])
	if esc == "recoger_tumbado" and t > 2.0 and not get_meta("mov", false) and j.arsenal.suelo.size() > 0:
		set_meta("mov", true)
		var it: Dictionary = j.arsenal.suelo[0]
		var fwd := Rbx.look(j.root_cf())
		(it.nodo as Node3D).global_position = Vector3(j.global_position.x, 0.12, j.global_position.z) + fwd * 2.6 + Rbx.right(j.root_cf()) * 0.7
	if esc == "boca_arriba_rifle":
		if t > 3.2 and not get_meta("vuelta", false):
			set_meta("vuelta", true)
			j.yaw += PI
		if t > 5.6 and not get_meta("vuelta2", false):
			set_meta("vuelta2", true)
			j.yaw -= PI
		j.aiming = (t > 4.0 and t < 5.4) or t > 6.6
	if esc == "tumbado_rifle":
		j.aiming = t > 3.0 and t < 3.6 or t > 4.8
	if OS.get_cmdline_user_args().has("--logcam") and Engine.get_process_frames() % 15 == 0:
		print("CAM t=%.2f z=%.3f fov=%.1f dist=%.2f vel=%.1f ws=%.1f md=%.1f camy=%.3f camrot=%s" % [t, j.global_position.z, j.camara.fov, j.cam_dist, Vector2(j.vel_real.x, j.vel_real.z).length(), j.walk_speed, j.move_direction.length(), j.camara.global_position.y, str(j.camara.global_rotation)])
	if esc == "levantarse_boca_arriba" and t > 1.8 and t < 4.4:
		# mira hacia atrás para quedar boca arriba
		j.yaw = PI
	if OS.get_cmdline_user_args().has("--logarma") and Engine.get_process_frames() % 6 == 0:
		print("ARMA t=%.2f equipado=%s switching=%s vault=%s rearmar=%s" % [t, j.arsenal.equipado, str(j.arsenal.switching != null), str(j.vaulting != null), j.arsenal.rearmar])
	if esc == "tiro_campo":
		j.aiming = t > 1.5
		j.pitch = -0.08
		j.firing = t > 2.6 and t < 3.4
	if esc in ["pared_rifle", "pared_pistola"]:
		j.aiming = t > 4.0
		if OS.get_cmdline_user_args().has("--disparar"):
			j.firing = t > 4.6 and t < 5.6
		if OS.get_cmdline_user_args().has("--logpared") and Engine.get_process_frames() % 6 == 0:
			var ac: Array = j.arsenal.aim_check()
			print("PARED t=%.2f z=%.2f retro=%.2f alza=%.2f disparo=%s" % [t, j.global_position.z, j.get_node("Animador").arma_retro, j.get_node("Animador").arma_alzada, str(ac)])
	if esc in ["pared_espalda", "pared_lado"]:
		# gira la cámara despacio alrededor del personaje (como con el ratón)
		if t > 1.0:
			j.yaw += 0.9 * get_process_delta_time()
		if Engine.get_process_frames() % 10 == 0:
			var hd: Vector3 = j.rig.P.Head.global_position
			print("CAM t=%.2f yaw=%.2f dist=%.2f a_cabeza=%.2f" % [t, j.yaw, j.cam_dist, j.camara.global_position.distance_to(hd)])
	if esc == "zoom":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var rueda := 0
		if t > 1.0 and t < 2.0 and Engine.get_process_frames() % 6 == 0:
			rueda = MOUSE_BUTTON_WHEEL_DOWN
		elif t > 2.5 and t < 4.5 and Engine.get_process_frames() % 6 == 0:
			rueda = MOUSE_BUTTON_WHEEL_UP
		if rueda != 0:
			var mb := InputEventMouseButton.new()
			mb.button_index = rueda
			mb.pressed = true
			Input.parse_input_event(mb)
		if Engine.get_process_frames() % 15 == 0:
			print("CAM t=%.2f zoom=%.2f dist=%.2f" % [t, j.zoom_cam, j.cam_dist])
	if esc == "strafe_rifle_apunta":
		j.aiming = t > 1.2
	if esc == "fatiga":
		j.estamina_infinita = false
		j.stamina = 2.0
	if OS.get_cmdline_user_args().has("--logf"):
		var an2: Animador = j.get_node("Animador")
		print("F t=%.2f ph=%.2f sin=%.2f rate=%.2f amp=%.2f L=%s R=%s" % [t, an2.gait_ph, sin(an2.gait_ph), an2.gait_rate, an2.gait_amp, "sw%.2f" % float(an2.feet.L.u) if an2.feet.L.get("u") != null and an2.feet.L.swing != null else "pl", "sw%.2f" % float(an2.feet.R.u) if an2.feet.R.get("u") != null and an2.feet.R.swing != null else "pl"])
	if OS.get_cmdline_user_args().has("--logrec") and Engine.get_process_frames() % 6 == 0:
		print("REC t=%.2f pos=%s ir=%s rec=%s armas=%s" % [t, j.global_position, str(j.arsenal.ir_a_recoger != null), str(j.arsenal.recogiendo != null), str(j.arsenal.inventario.keys().map(func(k): return j.arsenal.inventario[k].name))])
	if OS.get_cmdline_user_args().has("--loghang") and Engine.get_process_frames() % 6 == 0:
		print("HANG t=%.2f pos=%s est=%s colg=%s vault=%s st=%.0f" % [t, j.global_position, j.estado, str(j.colgado != null), str(j.vaulting != null), j.stamina])
	if OS.get_cmdline_user_args().has("--logvel") and Engine.get_process_frames() % 6 == 0:
		var vr: Vector3 = j.vel_real
		print("VEL t=%.2f y=%.2f horiz=%.2f total=%.2f pend=%.2f" % [t, j.global_position.y, Vector2(vr.x, vr.z).length(), vr.length(), j.pendiente])
	if OS.get_cmdline_user_args().has("--logv") and Engine.get_process_frames() % 3 == 0:
		print("V t=%.2f z=%.2f y=%.2f est=%s vault=%s sub=%s" % [t, j.global_position.z, j.global_position.y, j.estado, j.vaulting != null, j._subir_a != null])
	if OS.get_cmdline_user_args().has("--log") and Engine.get_process_frames() % 6 == 0:
		var an: Animador = j.get_node("Animador")
		var fl: Dictionary = an.feet.L
		var fr: Dictionary = an.feet.R
		var hp: Vector3 = j.rig.P.LowerTorso.global_position
		print("LOG t=%.2f v=%.1f drop=%.2f yr=%.2f L=%s R=%s dL=%.2f dR=%.2f hipy=%.2f bodyy=%.2f" % [t, j.cur_move, an.pelvis_drop, an.yaw_rate, "sw%.2f" % fl.u if fl.swing != null else "pl", "sw%.2f" % fr.u if fr.swing != null else "pl", (j.rig.P.LeftFoot.global_position - hp).length(), (j.rig.P.RightFoot.global_position - hp).length(), hp.y, j.global_position.y])
	_registrar()
	_contactos()
	var p := j.global_position + Vector3(0, -0.8, 0)
	var r := Basis(Vector3.UP, j.yaw) * (Vector3(1, 0, -1).normalized() if OS.get_cmdline_user_args().has("--cam34") else Vector3(1, 0, 0))
	var alto := 7.0 if esc in ["trepar", "saltar", "borde", "correr_girar", "correr_girar_d", "trepar_lejos", "trepar_lejos_c", "trepar_c", "saltar_pared", "colgar", "colgar_d", "colgar_salto", "colgar_corre"] else 1.0
	var dist_c := 14.0
	if OS.get_cmdline_user_args().has("--cam=atras"):
		r = Basis(Vector3.UP, j.yaw) * Vector3(0.45, 0, 1).normalized()
		dist_c = 11.0
		alto = 4.0
	elif OS.get_cmdline_user_args().has("--cam=frente"):
		r = Basis(Vector3.UP, j.yaw) * Vector3(0.25, 0, -1).normalized()
		dist_c = 11.0
		alto = 2.0
	elif OS.get_cmdline_user_args().has("--cam=cerca"):
		dist_c = 9.0
		alto = 2.5
	cam.global_position = p + r * dist_c + Vector3(0, alto, 0)
	cam.look_at(p, Vector3.UP)
	if esc == "recoger_tumbado":
		cam.global_position = j.global_position + Vector3(7, 3.5, -6)
		cam.look_at(j.global_position + Vector3(0, -0.2, -2.0), Vector3.UP)
	elif esc.begins_with("recoger"):
		cam.global_position = Vector3(-83, 6, 104)
		cam.look_at(Vector3(-96, 2.0, 97), Vector3.UP)
	elif esc == "boca_arriba_rifle":
		cam.global_position = j.global_position + Vector3(7, 5, 3)
		cam.look_at(j.global_position + Vector3(0, -0.2, -0.5), Vector3.UP)
	elif OS.get_cmdline_user_args().has("--camlado") and j.colgado != null:
		var nn: Vector3 = j.colgado.n
		var rr2 := (-nn).cross(Vector3.UP)
		var foco2 := j.global_position + Vector3(0, 2.2, 0)
		cam.global_position = foco2 + rr2 * 7.0 + nn * 4.5 + Vector3(0, 2.0, 0)
		cam.look_at(foco2, Vector3.UP)
	elif OS.get_cmdline_user_args().has("--camfija") and esc in ["colgar", "colgar_d"]:
		var foco := Vector3(-97, 5.5, -78) if esc == "colgar_d" else Vector3(-122, 5.5, -77)
		cam.global_position = foco + (Vector3(14, 7, 13) if esc == "colgar_d" else Vector3(13, 7, 13))
		cam.look_at(foco, Vector3.UP)
	elif esc.begins_with("colgar") and not OS.get_cmdline_user_args().has("--camlado"):
		# detrás del jugador, en diagonal y algo elevada (la pared delante)
		var bk := -Rbx.look(j.root_cf())
		var rr := Rbx.right(j.root_cf())
		cam.global_position = j.global_position + bk * 11 + rr * 6 + Vector3(0, 3, 0)
		cam.look_at(j.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	if t > e[2]:
		get_tree().quit()


## --registro=<ruta>: cada fotograma, la posición de las piezas principales (respecto al cuerpo, en el marco de su
## rumbo, y en el mundo), para medir lo suave que es el movimiento (tests/fluidez.py)
var _reg: FileAccess = null
func _registrar() -> void:
	var ruta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--registro="):
			ruta = a.split("=")[1]
	if ruta == "":
		return
	if _reg == null:
		_reg = FileAccess.open(ruta, FileAccess.WRITE)
		_reg.store_line("t,v,pieza,lx,ly,lz,wx,wy,wz")
	var rc := j.root_cf()
	var marco := Transform3D(Basis(Vector3.UP, Rbx.yaw_of(rc)), rc.origin)
	var v := Vector2(j.vel_real.x, j.vel_real.z).length()
	for n in ["Head", "UpperTorso", "LowerTorso", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftLowerArm", "RightLowerArm"]:
		var w: Vector3 = (j.rig.P[n] as Node3D).global_position
		var l := marco.affine_inverse() * w
		_reg.store_line("%.4f,%.3f,%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [t, v, n, l.x, l.y, l.z, w.x, w.y, w.z])
	_reg.flush()


## --contactos: cuánto se mete en el suelo (o flota) cada pieza de las piernas y las manos (studs; < 0 = dentro)
var _cont_max := {}
func _contactos() -> void:
	if not OS.get_cmdline_user_args().has("--contactos"):
		return
	var linea := ""
	for n in ["LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftHand", "RightHand", "LowerTorso", "Head"]:
		var nd: Node3D = j.rig.P[n]
		var sz: Vector3 = nd.get_meta("size")
		var hit := j.raycast(nd.global_position + Vector3(0, 3, 0), Vector3(0, -12, 0))
		if hit.is_empty():
			continue
		var gy: float = (hit.position as Vector3).y
		var mn := 99.0
		for c in 8:
			var lp := Vector3(sz.x * (0.5 if c & 1 else -0.5), sz.y * (0.5 if c & 2 else -0.5), sz.z * (0.5 if c & 4 else -0.5))
			mn = minf(mn, (nd.global_transform * lp).y - gy)
		linea += " %s=%.2f" % [n, mn]
		_cont_max[n] = minf(_cont_max.get(n, 99.0), mn)
	if Engine.get_process_frames() % 3 == 0:
		print("CONT t=%.2f pb=%.2f%s" % [t, float(j.L.proneP), linea])

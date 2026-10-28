extends Node
## Pruebas de la MOTO (v0.4). --modo=<vitrina|conducir|salto|morro|cuesta|bloque|lento|levantar|atropello|zombi|choque|
## disparar|golpear|derrape|bajar|empinada|bajada>; empinada con --angulo=15|30|50 (las rampas del nivel)
## --video: cámara de seguimiento propia (de lado/3/4); --camjuego: la cámara del juego.
## Simula las teclas con Input.parse_input_event (W, A, D, S, Espacio, F) e imprime "MOTO ..." con los datos.
var j: Jugador
var t := 0.0
var modo := "conducir"
var cam: Camera3D
var hecho := {}
var M := 1.0 / 0.31
var moto: Moto
var man: Maniqui
var teclas := {}
var min_y := 1e9
var max_y := -1e9
var aire_max := 0.0
var fin := 9.0
var zom: Node3D
var v_max := 0.0
var incl_max := 0.0
var notas := {}
var _prev_cam = null
var _prev_mano := Vector3.ZERO
var _prev_dc := 0.0
var _prev_dm := 0.0
var temblor := 0.0
var _n_med := 0
var modo_fuerte := OS.get_cmdline_user_args().has("--fuerte")
var temblor_mano := 0.0
var angulo := 50
var vel_obj := 40.0
var obst := "muro"


func _key(k: int, p: bool) -> void:
	if teclas.get(k, false) == p:
		return
	teclas[k] = p
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = p
	Input.parse_input_event(ev)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modo="):
			modo = a.split("=")[1]
		if a.begins_with("--angulo="):
			angulo = int(a.split("=")[1])
		if a.begins_with("--vel="):
			vel_obj = float(a.split("=")[1])
		if a.begins_with("--obst="):
			obst = a.split("=")[1]
	j = get_parent().get_node("Jugador")
	var args := OS.get_cmdline_user_args()
	if (args.has("--video") and not args.has("--camjuego")) or modo == "vitrina":
		cam = Camera3D.new()
		add_child(cam)
		cam.fov = 40
	call_deferred("_inicio")


func _moto(nombre: String) -> Moto:
	return get_parent().get_node("Motos/" + nombre) as Moto


func _inicio() -> void:
	match modo:
		"vitrina":
			moto = _moto("Moto_1")
			j.teletransportar(Vector3(-40, 0, 40) * M, 0.0)
			fin = 4.0
		"conducir", "derrape", "bajar", "golpear", "disparar", "lento":
			moto = _moto("Moto_0")
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			fin = {"conducir": 11.0, "derrape": 9.0, "bajar": 11.0, "golpear": 9.0, "disparar": 9.0, "lento": 8.0}[modo]
			if modo in ["golpear", "disparar"]:
				# un muñeco junto al camino (a la derecha), algo más adelante
				# (en el espacio de la moto: x a la derecha, -z delante)
				man = Maniqui.new()
				man.name = "ManiquiMoto"
				var off := Vector3(4.0, 0, -60.0) if modo == "golpear" else Vector3(14.0, 0, -70.0)
				man.position = moto.global_position + Basis(Vector3.UP, moto.rumbo) * off
				man.rotation = Vector3(0, moto.rumbo - PI / 2, 0)
				get_parent().add_child(man)
		"salto":
			moto = _moto("Moto_1")
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			fin = 9.0
		"morro":
			# salto por la rampa de 20° cayendo de morro (Ctrl en el aire): debe aterrizar sobre las dos ruedas,
			# enderezarse y seguir (sin quedarse sobre una rueda ni salir disparado)
			moto = _moto("Moto_2")
			moto.global_position = Vector3(15, 0, -28) * M
			moto.rumbo = 0.0
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			fin = 9.0
		"cuesta", "bloque":
			# cuesta: la rampa de 15° del nivel (sube hacia -Z). bloque: de frente contra el bloque de 60 cm
			moto = _moto("Moto_2")
			moto.global_position = (Vector3(10, 0, 8) if modo == "cuesta" else Vector3(-6, 0, -2)) * M
			moto.rumbo = 0.0
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			fin = 8.0
		"levantar":
			moto = _moto("Moto_1")
			moto.caer(1.0)
			var lado_x := 5.0 if OS.get_cmdline_user_args().has("--otro_lado") else -5.0
			j.teletransportar(moto.global_position + Vector3(lado_x, 0, 0.5), 0.0)
			fin = 5.0
		"zombi":
			# atropellar a un zombi de verdad (el de Juan): se usa su contrato de objetivo
			moto = _moto("Moto_1")
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			zom = get_parent().get_node("Zombis").crear_zombi(moto.global_position + Vector3(0.5, 0, -40.0), 0.0)
			fin = 6.0
		"atropello":
			moto = _moto("Moto_1")
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			man = Maniqui.new()
			man.name = "ManiquiMoto"
			man.position = moto.global_position + Vector3(0, 0, -45.0)
			get_parent().add_child(man)
			fin = 6.0
		"empinada":
			# a fondo contra las rampas del nivel (15°, 30° o 50°, --angulo=N; suben hacia -Z con plataforma arriba):
			# debe subirla siguiendo la cuesta (el morro con la pendiente), salir por arriba y caer sin estrellarse
			moto = _moto("Moto_2")
			var x_r: float = {15: 10.0, 30: 16.0, 50: 22.0}[angulo]
			moto.global_position = Vector3(x_r, 0, 14) * M
			moto.rumbo = 0.0
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			fin = 9.0
		"bajada":
			# desde la plataforma de la rampa de 30°, cuesta abajo: el morro debe bajar con la cuesta, la gravedad
			# la acelera y llega abajo sin estrellarse
			moto = _moto("Moto_2")
			moto.global_position = Vector3(16, 3.0, -19.6) * M
			moto.rumbo = PI
			j.teletransportar(moto.global_position + Vector3(2.6, 0, -0.5), PI)
			fin = 7.0
		"eyecta":
			# --vel=<studs/s> contra --obst=<muro|bloque20|bloque10|bordillo>: a esa velocidad, ¿tira al piloto?
			# ¿a dónde sale despedido? ¿cómo cae la moto? (2026-10-28)
			moto = _moto("Moto_2")
			moto.global_position = Vector3(-40, 0, 60) * M
			moto.rumbo = 0.0
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			var alto: float = {"muro": 3.0, "bloque20": 0.2, "bloque30": 0.3, "bloque10": 0.1, "bordillo": 0.15, "bloque40": 0.4}.get(obst, 3.0) / 0.31
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(30, alto, 4)
			cs.shape = bx
			sb.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = bx.size
			mi.mesh = bm
			sb.add_child(mi)
			get_parent().add_child(sb)
			sb.global_position = moto.global_position + Vector3(0, alto * 0.5, -24)
			notas.z_obst = sb.global_position.z
			fin = 5.5
		"choque":
			moto = _moto("Moto_2")
			# de frente al muro de la zona de motos
			moto.global_position = Vector3(30, 0, -40) * M
			moto.rumbo = 0.0
			j.teletransportar(moto.global_position + Vector3(-2.6, 0, 0.5), 0.0)
			fin = 9.0
	if modo != "vitrina":
		j.yaw = 0.0
		j.pitch = -0.2


func _una(clave: String, cond: bool) -> bool:
	if cond and not hecho.has(clave):
		hecho[clave] = true
		return true
	return false


func _log(txt: String) -> void:
	var m := moto
	print("MOTO t=%.2f %s | v=%.1f incl=%.1f° cab=%.1f° aire=%s y=%.2f marcha=%d rpm=%.2f piloto=%s caida=%s vida_j=%.0f%s" % [
		t, txt, m.velocidad(), rad_to_deg(m.inclinacion), rad_to_deg(m.cabeceo), str(m.en_aire), m.global_position.y,
		m.marcha, m.rpm, str(m.piloto != null), str(m.caida), j.health,
		(" muneco=%.0f/%s" % [man.health, man._estado]) if man else ((" zombi=%.0f/%s" % [zom.health, str(zom.estado)]) if zom else "")])


func _process(dt: float) -> void:
	t += dt
	if moto == null:
		return
	var en := j.moto != null
	if en:
		min_y = minf(min_y, moto.global_position.y)
		max_y = maxf(max_y, moto.global_position.y)
	if moto.en_aire:
		aire_max = maxf(aire_max, moto.t_aire)
	v_max = maxf(v_max, moto.velocidad())
	if man:
		notas.man_min = minf(float(notas.get("man_min", 100.0)), man.health)
	if not moto.caida:
		incl_max = maxf(incl_max, absf(rad_to_deg(moto.inclinacion)))
	# subir a la moto
	if not modo in ["vitrina", "levantar"] and _una("subir", t > 0.6):
		_key(KEY_F, true)
	if _una("soltarF", t > 0.7):
		_key(KEY_F, false)
		_log("subido=%s" % str(j.moto != null))
	match modo:
		"conducir":
			_key(KEY_W, t > 1.5 and t < 6.5)
			_key(KEY_A, t > 4.0 and t < 5.5)
			_key(KEY_D, t > 7.5 and t < 8.6)
			_key(KEY_S, t > 6.8 and t < 7.4 or t > 9.0)
		"cuesta":
			# acelera en llano, suelta el gas al empezar la rampa: cuesta arriba debe frenar mucho más
			_key(KEY_W, t > 1.2 and moto.global_position.z > -4.0 * M)
			if en and moto.global_position.z < -12.0 * M and moto.global_position.z > -15.5 * M and not moto.en_aire:
				if not notas.has("v_rampa0"):
					notas.v_rampa0 = moto.velocidad()
					notas.t_rampa0 = t
				notas.v_rampa1 = moto.velocidad()
				notas.t_rampa1 = t
			if en and moto.global_position.z < -2.0 * M and moto.global_position.z > -6.0 * M:
				if not notas.has("v_llano0"):
					notas.v_llano0 = moto.velocidad()
					notas.t_llano0 = t
				notas.v_llano1 = moto.velocidad()
				notas.t_llano1 = t
		"bloque":
			# gas a fondo contra el bloque: debe pararse (sin meterse dentro, sin salir volando ni acumular velocidad)
			_key(KEY_W, t > 1.2 and t < 5.5)
			_key(KEY_S, t > 5.8)
			if en and t > 3.5 and t < 5.5:
				notas.v_contra = maxf(float(notas.get("v_contra", 0.0)), absf(moto.velocidad()))
			notas.z_min = minf(float(notas.get("z_min", 1e9)), moto.global_position.z)
		"levantar":
			if _una("F_lev", t > 1.0):
				_key(KEY_F, true)
			if _una("F_lev2", t > 1.1):
				_key(KEY_F, false)
			if t > 1.6 and t < 2.0:
				notas.anim = j.L.get("levanta") != null
		"lento":
			# girar despacio (a poca velocidad, con el manillar a tope): no debe temblar nada
			_key(KEY_W, t > 1.2 and t < 1.9 or (t > 3.0 and fmod(t, 0.6) < 0.15))
			_key(KEY_A, t > 2.2)
			if t > 2.5 and en:
				var cam_t := j.camara.global_transform
				var mano: Vector3 = (j.rig.P.LeftHand as Node3D).global_position
				if _prev_cam != null:
					var dc: float = (cam_t.origin - (_prev_cam as Transform3D).origin).length()
					var dm: float = (mano - _prev_mano).length()
					var acc_c := absf(dc - _prev_dc)
					if _n_med > 1:
						temblor = maxf(temblor, acc_c)
						temblor_mano = maxf(temblor_mano, absf(dm - _prev_dm))
					_n_med += 1
					if OS.get_cmdline_user_args().has("--diag") and (acc_c > 0.02 or absf(dm - _prev_dm) > 0.03):
						print("DIAG t=%.3f dc=%.3f dm=%.3f rumbo=%.4f incl=%.4f dir=%.4f yaw=%.4f pitch=%.3f camdist=%.2f v=%.2f marcha=%d" % [t, dc, dm, moto.rumbo, moto.inclinacion, moto.direccion, j.yaw, j.pitch, j.cam_dist, moto.velocidad(), moto.marcha])
					_prev_dc = dc
					_prev_dm = dm
				_prev_cam = cam_t
				_prev_mano = mano
		"derrape":
			_key(KEY_W, t > 1.2 and t < 4.5)
			_key(KEY_D, t > 3.6 and t < 5.5)
			_key(KEY_SPACE, t > 3.8 and t < 5.0)
		"salto":
			_key(KEY_W, t > 1.2 and t < 4.6)
		"empinada":
			_key(KEY_W, t > 1.2 and t < 6.0)
			_key(KEY_S, t > 6.5)
			var zr := -12.0 * M
			var largo := 6.0 * M * cos(deg_to_rad(angulo))
			var p := moto.global_position
			if en and not notas.has("v_pie") and p.z < zr + 1.0:
				notas.v_pie = moto.velocidad()
			# en la cuesta (con las dos ruedas): el cabeceo debe ser el de la rampa
			if en and not moto.en_aire and p.z < zr - 3.0 and p.z > zr - largo + 2.5:
				notas.cab_rampa = maxf(float(notas.get("cab_rampa", 0.0)), moto.cabeceo)
				notas.v_rampa = moto.velocidad()
			if moto.en_aire and en:
				notas.cab_aire_min = minf(float(notas.get("cab_aire_min", 9.0)), moto.cabeceo)
				notas.cab_aire_max = maxf(float(notas.get("cab_aire_max", -9.0)), moto.cabeceo)
			if not en and hecho.has("soltarF") and not notas.has("cae_t"):
				notas.cae_t = t
				notas.cae_z = p.z
				_log("SE CAE")
		"morro":
			# (frena antes de llegar al borde del suelo, a 100 m)
			_key(KEY_W, t > 1.2 and t < 6.0)
			_key(KEY_S, t > 6.3)
			# un poco de morro (no hasta pasarse: eso sí debe tirarlo)
			var t_ctrl := 9.0 if modo_fuerte else 0.8
			_key(KEY_CTRL, en and moto.en_aire and moto.t_aire < t_ctrl)
			if moto.en_aire:
				notas.volo = true
				notas.t_aire_fin = t
				notas.cab_aire = minf(float(notas.get("cab_aire", 0.0)), moto.cabeceo)
			elif notas.get("volo", false):
				# (cuenta desde el último aterrizaje: el del salto grande)
				if not notas.has("t_toca") or float(notas.get("t_aire_fin", 0.0)) > float(notas.t_toca):
					notas.t_toca = t
				if t - float(notas.t_toca) > 1.0:
					notas.cab_luego = maxf(float(notas.get("cab_luego", 0.0)), absf(moto.cabeceo))
		"atropello", "zombi":
			_key(KEY_W, t > 1.2 and t < 5.0)
		"bajada":
			_key(KEY_W, t > 1.2 and t < 1.6)
			var zr2 := -12.0 * M
			var p2 := moto.global_position
			if en and not moto.en_aire and p2.z > zr2 - 6.0 * M * cos(deg_to_rad(30.0)) + 3.0 and p2.z < zr2 - 3.0:
				notas.cab_bajada = minf(float(notas.get("cab_bajada", 0.0)), moto.cabeceo)
				notas.v_bajada = maxf(float(notas.get("v_bajada", 0.0)), moto.velocidad())
		"eyecta":
			# lanzada a vel_obj hacia el obstáculo (con gas para mantenerla)
			if en and t > 1.0 and not notas.has("lanzada"):
				notas.lanzada = true
				moto.vel_h = moto.adelante() * vel_obj
				moto.marcha = 5
			_key(KEY_W, t > 1.0 and t < 4.0)
			if OS.get_cmdline_user_args().has("--traza") and absf(moto.global_position.z - float(notas.get("z_obst", 0.0))) < 9.0:
				print("TRAZA t=%.3f z=%.2f y=%.2f v=%.1f cab=%.2f apoyo=%d aire=%s piloto=%s del=%s tras=%s" % [t, moto.global_position.z - float(notas.z_obst), moto.global_position.y, moto.velocidad(), moto.cabeceo, moto.apoyo, str(moto.en_aire), str(moto.piloto != null), str(moto.suelo_del), str(moto.suelo_tras)])
			if not en and notas.has("lanzada") and not notas.has("choco"):
				notas.choco = t
				notas.p_choque = moto.global_position
				notas.v_choque = moto.ultimo_choque
			if notas.has("choco"):
				notas.j_fin = j.global_position
				var f = moto.get("_fisica")
				if f != null and is_instance_valid(f):
					notas.giro_moto = maxf(float(notas.get("giro_moto", 0.0)), (f as RigidBody3D).angular_velocity.length())
					notas.moto_fin = (f as RigidBody3D).global_position
		"choque":
			# hacia el muro de la zona de motos
			_key(KEY_W, t > 1.2 and t < 8.0)
			if en:
				var obj := Vector3(30, 0, -62) * M - moto.global_position
				var rel := Rbx.wrap_a(atan2(-obj.x, -obj.z) - moto.rumbo)
				_key(KEY_A, rel > 0.05)
				_key(KEY_D, rel < -0.05)
			else:
				_key(KEY_A, false)
				_key(KEY_D, false)
		"bajar":
			_key(KEY_W, t > 1.2 and t < 3.0 or t > 6.0 and t < 7.6)
			_key(KEY_S, t > 3.0 and t < 4.6)
			if _una("bajar1", t > 4.8):
				_key(KEY_F, true)
			if _una("bajar1b", t > 4.9):
				_key(KEY_F, false)
				_log("bajado parado: piloto=%s pos_j=%s" % [str(j.moto != null), str(j.global_position)])
				notas.bajado = j.moto == null
			if _una("subir2", t > 5.5):
				_key(KEY_F, true)
			if _una("subir2b", t > 5.6):
				_key(KEY_F, false)
				notas.resubido = j.moto != null
			if _una("bajar2", t > 7.8):
				_key(KEY_F, true)
			if _una("bajar2b", t > 7.9):
				_key(KEY_F, false)
				_log("saltado en marcha: estado=%s vel=%s" % [j.estado, str(j.vel_real)])
				notas.saltado = j.moto == null and (j.estado == "Freefall" or j.ragdoll != null)
		"disparar":
			if _una("pistola", t > 1.0):
				j.arsenal.select_slot(0)
			_key(KEY_W, t > 1.6 and t < 3.6)
			_key(KEY_S, t > 5.5)
			# apuntar hacia el muñeco (a la derecha del camino) y disparar
			if t > 3.0 and t < 6.5 and en:
				var obj2 := man.centro() - j.camara.global_position
				j.yaw = atan2(-obj2.x, -obj2.z)
				j.pitch = asin(clampf(obj2.normalized().y, -1, 1))
				j.aiming = true
				if fmod(t, 0.35) < dt and t > 3.6:
					j.arsenal.shoot()
					_log("disparo mag=%d" % j.arsenal.datos_equipado().mag)
			else:
				j.aiming = false
		"golpear":
			if _una("machete", t > 0.2):
				j.arsenal.dar_arma("Machete", true)
			if _una("sacar", t > 1.0):
				j.arsenal.select_slot(3)
			_key(KEY_W, t > 1.4 and t < 3.4)
			if en and man:
				var d := man.centro() - moto.global_position
				var adelante := d.dot(moto.adelante())
				if adelante < 7.0 and adelante > -2.0:
					j.yaw = atan2(-d.x, -d.z)
					if _una("golpe", true):
						j.arsenal.melee()
						_log("golpe")
		"vitrina":
			pass
	if fmod(t, 0.5) < dt or (OS.get_cmdline_user_args().has("--cada") and en):
		_log("")
	# cámara
	if cam:
		cam.current = true
		var foco := moto.global_position + Vector3(0, 2.5, 0)
		var dist := 15.0
		var r := Basis(Vector3.UP, moto.rumbo) * Vector3(1, 0.25, -0.35).normalized()
		if modo == "vitrina":
			r = Basis(Vector3.UP, t * 0.9) * Vector3(1, 0.3, 0).normalized()
			dist = 13.0
		elif modo in ["salto", "choque", "empinada", "bajada", "morro"]:
			r = Basis(Vector3.UP, moto.rumbo) * Vector3(1, 0.2, 0).normalized()
			dist = 26.0
		if OS.get_cmdline_user_args().has("--cerca"):
			# de cerca a la altura de las ruedas (ver cómo se aplastan los neumáticos)
			foco = moto.global_position + Vector3(0, 1.0, 0)
			r = Basis(Vector3.UP, moto.rumbo) * Vector3(1, 0.12, -0.25).normalized()
			dist = 7.5
		if modo == "levantar":
			foco = moto.global_position + Vector3(0, 2.0, 0)
			r = Vector3(1, 0.35, 0.6).normalized()
			dist = 15.0
		cam.global_position = foco + r * dist
		cam.look_at(foco, Vector3.UP)
	if t > fin:
		_log("fin min_y=%.2f max_y=%.2f aire_max=%.2f atropellos=%d choque=%.1f v_max=%.1f incl_max=%.1f" % [min_y, max_y, aire_max, moto.atropellos, moto.ultimo_choque, v_max, incl_max])
		_veredicto()
		get_tree().quit()


## para tests/ejecutar_pruebas.sh: "OK moto_<modo>" o "MAL moto_<modo>: ..."
func _veredicto() -> void:
	var fallos := []
	var monta := hecho.has("soltarF")
	match modo:
		"conducir":
			if v_max < 30.0: fallos.append("no acelera (v_max %.1f)" % v_max)
			if incl_max < 20.0: fallos.append("no se inclina en la curva (%.1f°)" % incl_max)
			if moto.velocidad() > -1.0: fallos.append("no hace marcha atrás")
		"salto":
			if aire_max < 0.4: fallos.append("no salta en la rampa (%.2f s)" % aire_max)
			if moto.piloto == null: fallos.append("el piloto se ha caído al aterrizar")
		"atropello":
			if moto.atropellos < 1 or float(notas.get("man_min", 100.0)) >= 100.0: fallos.append("no atropella al muñeco")
		"zombi":
			if moto.atropellos < 1 or zom.health >= 100.0: fallos.append("no atropella al zombi")
		"eyecta":
			if notas.has("choco"):
				var d: Vector3 = notas.j_fin - notas.p_choque
				var dm: Vector3 = notas.get("moto_fin", notas.p_choque) - notas.p_choque
				print("MOTO eyecta vel=%.0f obst=%s: TIRA AL PILOTO (choque %.1f) sale %.1f studs (%.1f m) por delante; la moto acaba a %.1f studs y gira hasta %.1f rad/s" % [vel_obj, obst, float(notas.v_choque), -d.z, -d.z * 0.31, dm.length(), float(notas.get("giro_moto", 0.0))])
				if obst in ["bloque10", "bloque20"]: fallos.append("un bloque de %s tira al piloto" % obst)
				if obst == "bloque40" and vel_obj >= 45.0 and -d.z < 15.0: fallos.append("sale despedido muy poco (%.1f studs)" % -d.z)
			else:
				print("MOTO eyecta vel=%.0f obst=%s: NO tira al piloto (v final %.1f, %s el obstáculo)" % [vel_obj, obst, moto.velocidad(),
					"pasa" if moto.global_position.z < float(notas.z_obst) - 2.0 else "NO pasa"])
				if obst == "muro" and vel_obj >= 35.0: fallos.append("chocar contra el muro no tira al piloto")
				if obst == "bloque40" and vel_obj >= 45.0: fallos.append("a esa velocidad contra un bloque de 40 cm no pasa nada")
				if obst in ["bloque30", "bloque40"] and moto.global_position.z < float(notas.z_obst) - 2.0: fallos.append("la moto trepa el bloque")
		"choque":
			# sale despedido hacia delante (hacia el muro, por encima del manillar), nunca hacia atrás
			var adel_j: float = (j.global_position - moto.global_position).dot(Vector3(0, 0, -1))
			print("MOTO choque: el piloto acaba %.1f studs por delante de la moto" % adel_j)
			if adel_j < -1.0: fallos.append("sale despedido hacia atrás")
			if moto.piloto != null or not moto.caida: fallos.append("no tira al piloto contra el muro")
			if j.health >= 100.0: fallos.append("el choque no hace daño")
		"disparar":
			if int(j.arsenal.datos_equipado().get("mag", 12)) > 9: fallos.append("no dispara desde la moto")
		"golpear":
			if float(notas.get("man_min", 100.0)) >= 100.0: fallos.append("el machete no golpea desde la moto")
		"morro":
			print("MOTO morro: cabeceo en el aire %.1f°, 1 s después de aterrizar %.1f°, vida %.0f, piloto %s, choque %.1f" % [rad_to_deg(float(notas.get("cab_aire", 0))), rad_to_deg(float(notas.get("cab_luego", 0))), j.health, str(moto.piloto != null), moto.ultimo_choque])
			if not notas.get("volo", false): fallos.append("no salta")
			if float(notas.get("cab_aire", 0)) > -0.25: fallos.append("no cae de morro")
			if float(notas.get("cab_luego", 0)) > 0.12: fallos.append("se queda sobre una rueda")
			if aire_max > 1.3: fallos.append("se queda colgada en el aire (%.1f s)" % aire_max)
			if modo_fuerte:
				# todo el vuelo de morro: puede caerse al tocar, pero nunca quedarse colgada ni morir de la nada
				if j.health < 60.0: fallos.append("demasiado daño (%.0f)" % j.health)
			elif j.health < 100.0 or moto.piloto == null: fallos.append("sale disparado / se hace daño")
		"empinada":
			var cr := float(notas.get("cab_rampa", 0.0))
			print("MOTO rampa %d°: v al pie %.1f, en la rampa %.1f, cabeceo en la rampa %.1f°, en el aire %.1f°..%.1f°, aire %.2f s, max_y %.1f, piloto %s, vida %.0f" % [angulo, float(notas.get("v_pie", 0)), float(notas.get("v_rampa", 0)), rad_to_deg(cr), rad_to_deg(float(notas.get("cab_aire_min", 0))), rad_to_deg(float(notas.get("cab_aire_max", 0))), aire_max, max_y, str(moto.piloto != null), j.health])
			if moto.piloto == null: fallos.append("se estrella (t=%.1f z=%.1f)" % [float(notas.get("cae_t", 0)), float(notas.get("cae_z", 0))])
			if absf(rad_to_deg(cr) - angulo) > 6.0: fallos.append("el morro no sigue la cuesta (%.0f° en una de %d°)" % [rad_to_deg(cr), angulo])
			if float(notas.get("v_pie", 0)) < 35.0: fallos.append("no llega deprisa")
			if aire_max < 0.3: fallos.append("no sale volando por arriba")
		"bajada":
			print("MOTO bajada: cabeceo %.1f°, v máx en la cuesta %.1f, piloto %s, vida %.0f, aire %.2f" % [rad_to_deg(float(notas.get("cab_bajada", 0))), float(notas.get("v_bajada", 0)), str(moto.piloto != null), j.health, aire_max])
			if moto.piloto == null: fallos.append("se estrella")
			if absf(rad_to_deg(float(notas.get("cab_bajada", 0))) + 30.0) > 5.0: fallos.append("el morro no baja con la cuesta")
			if float(notas.get("v_bajada", 0)) < 12.0: fallos.append("la gravedad no la acelera cuesta abajo")
		"cuesta":
			var dec_r := (float(notas.get("v_rampa0", 0)) - float(notas.get("v_rampa1", 0))) / maxf(0.01, float(notas.get("t_rampa1", 0)) - float(notas.get("t_rampa0", 0)))
			print("MOTO frenada en la cuesta de 15° sin gas: %.1f studs/s² (gravedad: %.1f)" % [dec_r, 35.0 * sin(deg_to_rad(15.0))])
			if not notas.has("v_rampa0"): fallos.append("no llega a la rampa")
			elif dec_r < 35.0 * sin(deg_to_rad(15.0)) * 0.8: fallos.append("la cuesta no frena (%.1f studs/s²)" % dec_r)
		"bloque":
			var cara := (-10.0 + 1.0) * M # cara del bloque (z en studs)
			print("MOTO contra el bloque: v=%.1f z_min=%.2f (cara %.2f) max_y=%.2f" % [float(notas.get("v_contra", 0)), float(notas.z_min), cara, max_y])
			if float(notas.get("v_contra", 99)) > 3.0: fallos.append("acumula velocidad contra el bloque")
			if max_y > 0.5: fallos.append("se sube/sale volando con el bloque (y %.2f)" % max_y)
			if float(notas.z_min) < cara + 2.0: fallos.append("se mete dentro del bloque")
			if moto.velocidad() > -1.0: fallos.append("no sale marcha atrás")
		"levantar":
			if moto.caida or not moto.aparcada: fallos.append("no se levanta")
			if not notas.get("anim", false): fallos.append("sin animación de levantar")
			if absf(moto.inclinacion) > 0.4: fallos.append("queda torcida (%.2f)" % moto.inclinacion)
			if j.health < 100.0: fallos.append("levantarla hace daño al jugador (%.0f)" % j.health)
		"lento":
			print("MOTO temblor camara=%.3f mano=%.3f" % [temblor, temblor_mano])
			if temblor > 0.08 or temblor_mano > 0.12: fallos.append("tiembla al girar despacio (cámara %.3f, mano %.3f)" % [temblor, temblor_mano])
		"derrape":
			if moto.caida or moto.piloto == null: fallos.append("se cae al derrapar")
		"bajar":
			for k in ["bajado", "resubido", "saltado"]:
				if not notas.get(k, false): fallos.append("falla: " + k)
	if not modo in ["vitrina", "levantar"] and not monta:
		fallos.append("no se sube")
	if modo in ["empinada", "bajada"] and min_y < -1.0:
		fallos.append("atraviesa el suelo (y %.1f)" % min_y)
	if fallos.is_empty():
		print("OK moto_" + modo)
	else:
		print("MAL moto_%s: %s" % [modo, ", ".join(fallos)])

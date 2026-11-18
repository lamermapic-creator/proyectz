extends Node
## Pruebas de la MOTO (v0.4). --modo=<vitrina|conducir|salto|morro|cuesta|bloque|lento|levantar|atropello|zombi|choque|
## disparar|golpear|derrape|bajar|empinada|bajada|apuntar360 (--mover)>; empinada con --angulo=15|30|50 (las rampas del nivel)
## --video: cámara de seguimiento propia (de lado/3/4); --camjuego: la cámara del juego.
## Simula las teclas con Input.parse_input_event (W, A, D, S, Espacio, F) e imprime "MOTO ..." con los datos.
var j: Jugador
var t := 0.0
var modo := "conducir"
var montar_corriendo := OS.get_cmdline_user_args().has("--montar-corriendo")
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
var bloque_i := 1      # --bloque=<0..6>: bloque naranja del nivel (20, 40, 60, 90, 120, 150, 200 cm)
var ang_atasco := 0.0  # --ang=<grados>: rumbo respecto a ir de frente
var lado_atasco := 0.0 # --lado=<metros>: desplazamiento lateral (darle por la esquina)


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
		if a.begins_with("--bloque="):
			bloque_i = int(a.split("=")[1])
		if a.begins_with("--ang="):
			ang_atasco = deg_to_rad(float(a.split("=")[1]))
		if a.begins_with("--lado="):
			lado_atasco = float(a.split("=")[1])
	j = get_parent().get_node("Jugador")
	var args := OS.get_cmdline_user_args()
	if (args.has("--video") and not args.has("--camjuego")) or modo == "vitrina":
		cam = Camera3D.new()
		add_child(cam)
		cam.fov = 40
	call_deferred("_inicio")


## al lado de la moto (para subirse hay que estar a su lado): -1 izquierda, 1 derecha
func _al_lado(lado: float, dist := 2.6) -> Vector3:
	return moto.global_position + Basis(Vector3.UP, moto.rumbo) * Vector3(lado * dist, 0, 0.5)


func _moto(nombre: String) -> Moto:
	return get_parent().get_node("Motos/" + nombre) as Moto


func _inicio() -> void:
	match modo:
		"vitrina":
			moto = _moto("Moto_1")
			j.teletransportar(Vector3(-40, 0, 40) * M, 0.0)
			fin = 4.0
		"exportar_pie":
			# 2026-11-01: el superviviente de pie con un arma (--arma=Pistola|Rifle) para las poses de Blender
			moto = _moto("Moto_0")
			j.teletransportar(moto.global_position + Vector3(40, 0, 40), 0.0)
			fin = 4.0
		"exportar":
			# 2026-11-01: vuelca el piloto sentado (pose de conducir, pistola en la mano) y la moto a JSON para montarlos
			# en Blender (tests/blender/). --salida=<ruta>
			moto = _moto("Moto_0")
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 4.0
		"giros":
			# 2026-11-01: el ratón salta de golpe de un lado a otro apuntando: la mano debe ir con naturalidad
			# (velocidad y aceleración de la mano limitadas, sin tirones), mide en el espacio de la moto
			moto = _moto("Moto_0")
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 13.0
		"apuntar360":
			# apuntado libre en la moto (2026-10-30): la mira da la vuelta entera por la izquierda y luego por la
			# derecha (con el cabeceo subiendo y bajando) disparando sin parar; --mover: en marcha
			moto = _moto("Moto_0")
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 17.0
		"conducir", "derrape", "bajar", "golpear", "disparar", "lento":
			moto = _moto("Moto_0")
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = {"conducir": 11.0, "derrape": 9.0, "bajar": 11.0, "golpear": 9.0, "disparar": 9.0, "lento": 8.0}[modo]
			if modo == "bajar":
				j.teletransportar(_al_lado(-1.0, 6.7 if montar_corriendo else 5.2),
					moto.rumbo - PI / 2.0 if montar_corriendo else 0.0)
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
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 9.0
		"morro":
			# salto por la rampa de 20° cayendo de morro (Ctrl en el aire): debe aterrizar sobre las dos ruedas,
			# enderezarse y seguir (sin quedarse sobre una rueda ni salir disparado)
			moto = _moto("Moto_2")
			moto.global_position = Vector3(15, 0, -28) * M
			moto.rumbo = 0.0
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 9.0
		"cuesta", "bloque":
			# cuesta: la rampa de 15° del nivel (sube hacia -Z). bloque: de frente contra el bloque de 60 cm
			moto = _moto("Moto_2")
			moto.global_position = (Vector3(10, 0, 8) if modo == "cuesta" else Vector3(-6, 0, -2)) * M
			moto.rumbo = 0.0
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 8.0
		"levantar":
			moto = _moto("Moto_1")
			moto.caer(1.0)
			var lado_x := 5.0 if OS.get_cmdline_user_args().has("--otro_lado") else -5.0
			j.teletransportar(moto.global_position + Vector3(lado_x, 0, 0.5), 0.0)
			fin = 5.0
		"levantar_hueco":
			# (2026-10-29) caída a medias entre dos bloques (la rueda de delante en el hueco): levantarla y subirse no
			# debe tirarla hacia delante ni hundirla en el suelo
			moto = _moto("Moto_2")
			moto.rumbo = -PI / 2.0 + ang_atasco
			moto.rotation = Vector3(0, moto.rumbo, 0)
			var x_h := -35.68
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--x="): x_h = float(a2.split("=")[1])
			moto.global_position = Vector3(x_h, 0.4, -32.26 + lado_atasco * M)
			moto.caer(1.0)
			j.teletransportar(_al_lado(-1.0, 3.4) + Vector3(0, 0.7, 0), PI)
			fin = 8.0
		"zombi":
			# atropellar a un zombi de verdad (el de Juan): se usa su contrato de objetivo
			moto = _moto("Moto_1")
			j.teletransportar(_al_lado(-1.0), 0.0)
			zom = get_parent().get_node("Zombis").crear_zombi(moto.global_position + Vector3(0.5, 0, -40.0), 0.0)
			fin = 6.0
		"atropello":
			moto = _moto("Moto_1")
			j.teletransportar(_al_lado(-1.0), 0.0)
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
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 9.0
		"bajada":
			# desde la plataforma de la rampa de 30°, cuesta abajo: el morro debe bajar con la cuesta, la gravedad
			# la acelera y llega abajo sin estrellarse
			moto = _moto("Moto_2")
			moto.global_position = Vector3(16, 3.0, -19.6) * M
			moto.rumbo = PI
			j.teletransportar(_al_lado(1.0), PI)
			fin = 7.0
		"eyecta":
			# --vel=<studs/s> contra --obst=<muro|bloque20|bloque10|bordillo>: a esa velocidad, ¿tira al piloto?
			# ¿a dónde sale despedido? ¿cómo cae la moto? (2026-10-28)
			moto = _moto("Moto_2")
			moto.global_position = Vector3(-40, 0, 60) * M
			moto.rumbo = 0.0
			j.teletransportar(_al_lado(-1.0), 0.0)
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
		"fila":
			# (2026-10-29) a lo largo de la fila de bloques naranjas (20, 40, 60 cm... con 1 m de hueco entre ellos):
			# se queda entre dos bloques; luego marcha atrás (S) debe sacarla
			moto = _moto("Moto_2")
			moto.rumbo = -PI / 2.0
			moto.global_position = Vector3(-16.0 * M, 0, -10.0 * M + lado_atasco * M)
			j.teletransportar(_al_lado(-1.0), -PI / 2.0)
			fin = 10.0
		"suspension":
			# (2026-10-29) ver la suspensión: sube el bloque de 20 cm despacio, baja de él, frena en seco y acelera
			moto = _moto("Moto_2")
			moto.rumbo = 0.0
			moto.global_position = Vector3(-12.0 * M, 0, -10.0 * M + 9.0 * M)
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 8.0
		"atasco":
			# contra los bloques naranjas DEL NIVEL a --vel (con gas todo el rato): ¿se queda atascada? (2026-10-29)
			moto = _moto("Moto_2")
			var bx := (-12.0 + bloque_i * 3.0 + lado_atasco) * M
			var bz := -10.0 * M
			var d0 := 7.0 * M
			moto.rumbo = ang_atasco
			moto.global_position = Vector3(bx, 0, bz) + Vector3(sin(ang_atasco), 0, cos(ang_atasco)) * d0
			j.teletransportar(_al_lado(-1.0), ang_atasco)
			fin = 9.0
		"choque":
			moto = _moto("Moto_2")
			# de frente al muro de la zona de motos
			moto.global_position = Vector3(30, 0, -40) * M
			moto.rumbo = 0.0
			j.teletransportar(_al_lado(-1.0), 0.0)
			fin = 9.0
	if modo != "vitrina":
		j.yaw = 0.0
		j.pitch = -0.2


## exportar: todo lo que hace falta para montar el piloto y la moto en Blender, en coordenadas de Godot (studs)
func _mallas(raiz: Node, lista: Array, base: Callable) -> void:
	for c in raiz.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).visible:
			var mi := c as MeshInstance3D
			var col := Color(0.6, 0.6, 0.6)
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(0)
			if mat == null and mi.mesh.get_surface_count() > 0:
				mat = mi.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				col = (mat as StandardMaterial3D).albedo_color
			var caras := mi.mesh.get_faces()
			var arr := []
			for v in caras:
				arr.append([snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)])
			lista.append({"nombre": String(mi.name), "base": base.call(mi), "t": _tf(mi.global_transform),
				"color": [col.r, col.g, col.b], "caras": arr})
		_mallas(c, lista, base)


func _tf(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


func _volcar_blender(con_moto := true) -> void:
	var rig: RigPersonaje = j.rig
	var P: Dictionary = rig.P
	var d := {"motores": [], "piezas": {}, "mallas_rig": [], "mallas_moto": []}
	for m in RigPersonaje.MOTORES:
		var mo = rig.M[m[0]]
		var q := Quaternion(mo.transform.basis.orthonormalized())
		d.motores.append({"nombre": m[0], "p0": m[1], "p1": m[2], "c0": [m[3].x, m[3].y, m[3].z], "c1": [m[4].x, m[4].y, m[4].z],
			"q": [q.x, q.y, q.z, q.w], "o": [mo.transform.origin.x, mo.transform.origin.y, mo.transform.origin.z]})
	for nombre in P:
		d.piezas[nombre] = _tf((P[nombre] as Node3D).global_transform)
	# a qué pieza pertenece cada malla del piloto (la pieza más cercana hacia arriba)
	var pieza_de := func(n: Node) -> String:
		var x: Node = n
		while x != null:
			for nombre in P:
				if P[nombre] == x and nombre != "HumanoidRootPart":
					return nombre
			x = x.get_parent()
		return ""
	_mallas(P.HumanoidRootPart, d.mallas_rig, pieza_de)
	if con_moto:
		_mallas(moto, d.mallas_moto, func(_n): return "")
	d.raiz = _tf(rig.global_transform)
	d.moto = _tf(moto.global_transform)
	d.punoL = _tf(moto.puno("L"))
	d.punoR = _tf(moto.puno("R"))
	var tool: String = j.arsenal.equipado
	d.arma = tool
	d.handle_en_mano = _tf(Armas.handle_en_mano(tool))
	var mdl: Node3D = j.arsenal.modelo_mano
	d.muzzle = _tf((mdl.get_node("Muzzle") as Node3D).transform) if mdl and mdl.has_node("Muzzle") else []
	d.puntos = {}
	if mdl:
		for pn in ["Muzzle", "LeftGrip", "SupportGrip", "MagBottom", "ChargingHandle", "SlideRear"]:
			if mdl.find_child(pn, true, false) != null:
				var pv := Armas.punto_local(mdl, pn)
				d.puntos[pn] = [pv.x, pv.y, pv.z]
	d.grip = _tf(Armas.grip(tool))
	d.grip_att = _tf(Armas.grip_att())
	d.poses_viejas = {}
	for k in ["LOW", "HIP", "AIM", "SPRINT", "PRONE", "RELOAD"]:
		d.poses_viejas[k] = _tf(Armas.pose(tool, k))
	d.muneca_en_mano = [j.arsenal.anim.wrist_in_hand.R.x, j.arsenal.anim.wrist_in_hand.R.y, j.arsenal.anim.wrist_in_hand.R.z]
	d.yaw = Rbx.yaw_of(j.root_cf())
	var ruta := "/tmp/rig_moto.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salida="):
			ruta = a.split("=")[1]
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	print("MOTO exportar: %d mallas del piloto, %d de la moto -> %s" % [d.mallas_rig.size(), d.mallas_moto.size(), ruta])


## apuntar360: el cañón apunta a la mira, el arma y los brazos no se meten en el torso ni en la cabeza
var _mano_prev := ""
var _pos_mano_prev = null
func _medir_apuntado(an: Animador, rel_t: float) -> void:
	var P: Dictionary = j.rig.P
	if an.moto_rama_brazo != _mano_prev:
		if _mano_prev != "":
			notas.cambios = int(notas.get("cambios", 0)) + 1
		_mano_prev = an.moto_rama_brazo
	# la mano izquierda nunca suelta el manillar
	var pl: Vector3 = (moto.puno("L") as Transform3D).origin if moto.has_method("puno") else Vector3.ZERO
	if pl != Vector3.ZERO:
		var dl := ((j.rig.P.LeftHand as Node3D).global_position - pl).length()
		notas.izq_max = maxf(float(notas.get("izq_max", 0.0)), dl)
	var mdl: Node3D = j.arsenal.modelo_mano
	if mdl == null or not mdl.has_node("Muzzle"):
		return
	var mz := (mdl.get_node("Muzzle") as Node3D).global_transform
	# saltos de la mano que lleva el arma (fotograma a fotograma)
	var mano_p := (mdl.global_position)
	if _pos_mano_prev != null and not an.moto_cambiando():
		var tr := (mano_p - (_pos_mano_prev as Vector3)).length()
		if tr > 0.6 and OS.get_cmdline_user_args().has("--detalle"):
			print("TIRON t=%.2f %.2f rel=%.0f° mano=%s paso=%.2f k=%.2f v=%.1f" % [t, tr, rad_to_deg(rel_t), an.moto_h_arma, (1.0 if an.moto_cambio != null else 0.0), an.moto_apunta_k, moto.velocidad()])
		notas.tiron = maxf(float(notas.get("tiron", 0.0)), tr)
	_pos_mano_prev = mano_p
	# error del cañón respecto a la mira, ya asentado (sin cambiar de mano y con el torso ya girado)
	var obj := _angulo_obj(an, rel_t)
	if an.moto_apunta_k > 0.95 and not an.moto_cambiando() and absf(an.rel_aim - obj) < 0.05:
		var err := rad_to_deg((-mz.basis.z).angle_to(j.arsenal.punto_mira() - mz.origin))
		notas.err_max = maxf(float(notas.get("err_max", 0.0)), err)
		notas.err_sum = float(notas.get("err_sum", 0.0)) + err
		notas.err_n = int(notas.get("err_n", 0)) + 1
		if err > 8.0 and OS.get_cmdline_user_args().has("--detalle"):
			print("ERR t=%.2f err=%.1f rel=%.0f° pitch=%.2f mano=%s dist_mira=%.1f" % [t, err, rad_to_deg(rel_t), j.pitch, an.moto_h_arma, (j.arsenal.punto_mira() - mz.origin).length()])
		if err > float(notas.get("err_max_prev", 0.0)):
			notas.err_max_prev = err
			notas.err_donde = "rel=%.0f° pitch=%.2f" % [rad_to_deg(rel_t), j.pitch]
	# puntos del brazo que dispara y del arma, dentro del torso o la cabeza
	var s: String = an.moto_h_arma
	var lado := "Right" if s == "R" else "Left"
	var puntos := {
		"codo": ((P[lado + "LowerArm"] as Node3D).global_transform * Vector3(0, 0.4, 0)),
		"antebrazo": (P[lado + "LowerArm"] as Node3D).global_position,
		"mano": (P[lado + "Hand"] as Node3D).global_position,
		"arma": mdl.global_position,
		"boca": mz.origin,
	}
	var cajas := {"UpperTorso": Vector3(0.71, 0.69, 0.37), "Head": Vector3(0.42, 0.5, 0.45), "LowerTorso": Vector3(0.6, 0.3, 0.33)}
	for nombre in puntos:
		for c in cajas:
			var lp: Vector3 = (P[c] as Node3D).global_transform.affine_inverse() * (puntos[nombre] as Vector3)
			var hb: Vector3 = cajas[c] - Vector3(0.05, 0.05, 0.05)
			if absf(lp.x) < hb.x and absf(lp.y) < hb.y and absf(lp.z) < hb.z:
				notas.dentro = int(notas.get("dentro", 0)) + 1
				notas.dentro_que = "%s en %s (rel=%.0f°, t=%.1f)" % [nombre, c, rad_to_deg(rel_t), t]
				if OS.get_cmdline_user_args().has("--detalle"):
					print("DENTRO t=%.2f %s en %s lp=%s rel=%.0f° rel_aim=%.2f mano=%s paso=%.2f k=%.2f pitch=%.2f" % [t, nombre, c, str(lp), rad_to_deg(rel_t), an.rel_aim, s, (1.0 if an.moto_cambio != null else 0.0), an.moto_apunta_k, j.pitch])


## ángulo que busca el Animador para la mano actual (para saber cuándo el torso ya ha girado)
func _angulo_obj(an: Animador, rel_t: float) -> float:
	return an.angulo_mira(Rbx.wrap_a(rel_t))


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
	if OS.get_cmdline_user_args().has("--trazav") and int(t * 60) % 6 == 0:
		print("TV t=%.2f pos=%s v=%.1f vmundo=%.1f vh=%.1f vv=%.1f cab=%.2f apoyo=%d" % [t, moto.global_position, moto.velocidad(), moto.vel_mundo().length(), moto.vel_h.length(), moto.vel_v, moto.cabeceo, moto.apoyo])
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
	if modo == "bajar" and montar_corriendo:
		_key(KEY_SHIFT, t > 0.33 and t < 0.85)
	if not modo in ["vitrina", "levantar", "exportar_pie"] and _una("subir", t > 0.6):
		if modo == "bajar" and montar_corriendo:
			notas.corria = j.L.sprinting
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
		"levantar_hueco":
			if _una("F_lh", t > 1.5):
				_key(KEY_F, true)
			if _una("F_lh2", t > 1.6):
				_key(KEY_F, false)
			if _una("F_lh3", t > 4.0):
				_key(KEY_F, true)
			if _una("F_lh4", t > 4.1):
				_key(KEY_F, false)
			if en:
				notas.subio = true
				notas.y_min = minf(float(notas.get("y_min", 99.0)), moto.global_position.y)
			if t > 4.5 and notas.get("subio", false) and (moto.caida or not en):
				notas.se_cae = true
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
		"fila":
			_key(KEY_W, t > 1.0 and t < 5.0 and moto.velocidad() < vel_obj)
			_key(KEY_S, t > 5.5 and t < 9.5)
			if en and t > 5.0 and t < 5.5:
				notas.x_parada = moto.global_position.x
			if en and t > 9.4 and not notas.has("x_atras"):
				notas.x_atras = moto.global_position.x
			if not en and not notas.has("cae_t"):
				notas.cae_t = t
		"suspension":
			_key(KEY_W, (t > 1.0 and t < 3.6 and moto.velocidad() < 12.0) or (t > 5.6 and t < 7.0))
			_key(KEY_S, t > 4.2 and t < 5.4)
			if en:
				notas.d_max = maxf(float(notas.get("d_max", 0.0)), moto.sus_d)
				notas.t_max = maxf(float(notas.get("t_max", 0.0)), moto.sus_t)
				if t > 4.4 and t < 5.2:
					notas.d_frena = maxf(float(notas.get("d_frena", 0.0)), moto.sus_d - moto.sus_t)
			if int(t * 60) % 6 == 0:
				print("SUSP t=%.2f v=%.1f del=%.2f tras=%.2f y=%.2f" % [t, moto.velocidad(), moto.sus_d, moto.sus_t, moto.global_position.y])
		"atasco":
			if en and t > 1.0 and not notas.has("lanzada"):
				notas.lanzada = true
				moto.vel_h = moto.adelante() * vel_obj
				moto.marcha = clampi(int(vel_obj / 10.0), 1, 5)
			_key(KEY_W, t > 1.0 and t < 8.5)
			if en and t > 2.0:
				var v_a := absf(moto.velocidad())
				if v_a < 1.0:
					notas.quieta_t = float(notas.get("quieta_t", 0.0)) + dt
					notas.quieta_max = maxf(float(notas.get("quieta_max", 0.0)), float(notas.quieta_t))
					notas.quieta_pos = moto.global_position
				else:
					notas.quieta_t = 0.0
			if OS.get_cmdline_user_args().has("--traza") and int(t * 30) % 3 == 0:
				print("TRAZA t=%.2f pos=%s v=%.1f cab=%.2f apoyo=%d aire=%s del=%s tras=%s piloto=%s" % [t, moto.global_position, moto.velocidad(), moto.cabeceo, moto.apoyo, str(moto.en_aire), str(moto.suelo_del), str(moto.suelo_tras), str(moto.piloto != null)])
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
			_key(KEY_W, (montar_corriendo and t > 0.33 and t < 0.85) or (t > 7.4 and t < 9.2))
			if _una("montaje_inicial", t > 2.8):
				notas.montado = j.moto == moto
			if _una("bajar1", t > 3.4):
				_key(KEY_F, true)
			if _una("bajar1b", t > 3.5):
				_key(KEY_F, false)
				notas.bajando = j.moto != null and j._moto_bajar_t >= 0.0
			if _una("bajar1fin", t > 4.3):
				notas.bajado = notas.get("bajando", false) and j.moto == null
			if _una("subir2", t > 4.7):
				_key(KEY_F, true)
			if _una("subir2b", t > 4.8):
				_key(KEY_F, false)
			if _una("subir2fin", t > 7.3):
				notas.resubido = j.moto != null
			if _una("bajar2", t > 9.0):
				notas.vel_salto = absf(moto.velocidad()) > 0.8
				_key(KEY_F, true)
			if _una("bajar2b", t > 9.05):
				_key(KEY_F, false)
				notas.saltado = notas.get("vel_salto", false) and j.moto == null and (j.estado == "Freefall" or j.ragdoll != null)
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
		"exportar_pie":
			var arma_e := "Rifle"
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--arma="):
					arma_e = a.split("=")[1]
			if _una("arma", t > 1.0) and arma_e != "ninguna":
				j.arsenal.select_slot(0 if arma_e == "Pistola" else 1)
			j.yaw = 0.0
			j.pitch = 0.0
			if _una("volcar", t > 3.5):
				_volcar_blender(false)
		"exportar":
			if _una("pistola", t > 1.0):
				j.arsenal.select_slot(0)
			# mirando al frente y sin cabeceo: la pose base, sin el giro de cabeza/cintura de seguir a la cámara
			j.yaw = moto.rumbo
			j.pitch = 0.0
			if _una("volcar", t > 3.5):
				_volcar_blender()
		"giros":
			if _una("pistola", t > 1.0):
				j.arsenal.select_slot(0)
			var objetivos := [-1.4, 1.5, -2.7, 2.2, 0.0, 3.0, -3.0, 1.0, -0.6, 2.9]
			if t > 2.4 and en:
				var i := clampi(int((t - 2.4) / 1.0), 0, objetivos.size() - 1)
				j.yaw = moto.rumbo + float(objetivos[i])
				j.pitch = 0.1
				j.aiming = true
				var an2: Animador = j.arsenal.anim
				var mdl2: Node3D = j.arsenal.modelo_mano
				if mdl2 and t > 2.6:
					var dt2 := get_process_delta_time()
					var pl2: Vector3 = moto.global_transform.affine_inverse() * mdl2.global_position
					if notas.has("pl_prev"):
						var v2: Vector3 = (pl2 - (notas.pl_prev as Vector3)) / dt2
						if notas.has("v_prev"):
							var a2 := ((v2 - (notas.v_prev as Vector3)) / dt2).length()
							if a2 > float(notas.get("a_max", 0.0)):
								notas.a_donde = "t=%.2f objetivo=%.0f° rel_aim=%.2f cambio=%s" % [t, rad_to_deg(float(objetivos[i])), an2.rel_aim, str(an2.moto_cambio != null)]
							notas.a_max = maxf(float(notas.get("a_max", 0.0)), a2)
							notas.a_sum = float(notas.get("a_sum", 0.0)) + a2
							notas.a_n = int(notas.get("a_n", 0)) + 1
						var kv := "v_max_c" if an2.moto_cambio != null else "v_max_n"
						notas[kv] = maxf(float(notas.get(kv, 0.0)), v2.length())
						if v2.length() > float(notas.get("v_max", 0.0)):
							notas.v_max = v2.length()
							notas.v_donde = "t=%.2f objetivo=%.0f° rel_aim=%.2f cambio=%s" % [t, rad_to_deg(float(objetivos[i])), an2.rel_aim, str(an2.moto_cambiando())]
						notas.v_prev = v2
					notas.pl_prev = pl2
					if OS.get_cmdline_user_args().has("--detalle") and int(t * 60) % 3 == 0:
						print("GIRO t=%.2f obj=%.0f° rel_aim=%.2f rama=%s cambio=%s mano=%s" % [t, rad_to_deg(float(objetivos[i])), an2.rel_aim, an2.moto_rama_brazo, str(an2.moto_cambiando()), str(pl2)])
		"apuntar360":
			if _una("pistola", t > 1.0):
				j.arsenal.select_slot(0)
			var mover := OS.get_cmdline_user_args().has("--mover")
			_key(KEY_W, mover and t > 2.0 and t < 15.0 and moto.velocidad() < 22.0)
			if t > 2.4 and t < 15.5 and en:
				var rel_t := 0.0
				if t < 8.5:
					rel_t = (t - 2.5) / 6.0 * TAU
				else:
					rel_t = -(t - 8.5) / 6.0 * TAU
				rel_t = clampf(rel_t, -TAU, TAU)
				j.yaw = moto.rumbo + rel_t
				j.pitch = 0.45 * sin(t * 1.7) - 0.05
				j.aiming = true
				var an: Animador = j.arsenal.anim
				if fmod(t, 0.2) < get_process_delta_time():
					j.arsenal.datos_equipado().mag = 12
					var antes := an.last_shot_t
					j.arsenal.shoot()
					if an.last_shot_t != antes or j.arsenal.pending_shot != null:
						var b := int(floor(fposmod(rel_t + PI / 8.0, TAU) / (TAU / 8.0))) % 8
						notas["oct%d" % b] = int(notas.get("oct%d" % b, 0)) + 1
				_medir_apuntado(an, rel_t)
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
		elif modo == "suspension":
			foco = moto.global_position + Vector3(0, 1.8, 0)
			r = Basis(Vector3.UP, moto.rumbo) * Vector3(1, 0.1, 0).normalized()
			dist = 11.0
		elif modo in ["salto", "choque", "empinada", "bajada", "morro"]:
			r = Basis(Vector3.UP, moto.rumbo) * Vector3(1, 0.2, 0).normalized()
			dist = 26.0
		if OS.get_cmdline_user_args().has("--cerca"):
			# de cerca a la altura de las ruedas (ver cómo se aplastan los neumáticos)
			foco = moto.global_position + Vector3(0, 1.0, 0)
			r = Basis(Vector3.UP, moto.rumbo) * Vector3(1, 0.12, -0.25).normalized()
			dist = 7.5
		if modo in ["apuntar360", "giros"]:
			# piloto de cerca; --cam_az=<grados> (0 = desde la derecha, 90 = desde delante), --cam_alt
			var az := 35.0
			var alt := 0.35
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--cam_az="):
					az = float(a.split("=")[1])
				if a.begins_with("--cam_alt="):
					alt = float(a.split("=")[1])
			foco = moto.global_position + Vector3(0, 4.0, 0)
			r = Basis(Vector3.UP, moto.rumbo + deg_to_rad(az)) * Vector3(1, alt, 0).normalized()
			dist = 10.0
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
		"levantar_hueco":
			print("MOTO levantar_hueco: subio=%s se_cae=%s y_min=%.2f y_fin=%.2f caida=%s" % [str(notas.get("subio", false)), str(notas.get("se_cae", false)), float(notas.get("y_min", 0.0)), moto.global_position.y, str(moto.caida)])
			if not notas.get("subio", false): fallos.append("no se sube después de levantarla")
			if notas.get("se_cae", false): fallos.append("al subirse se cae")
			if float(notas.get("y_min", 0.0)) < -0.5: fallos.append("se hunde en el suelo")
		"fila":
			var xp := float(notas.get("x_parada", 0.0))
			var xa := float(notas.get("x_atras", xp))
			print("MOTO fila vel=%.0f lado=%.1f: parada en x=%.2f, marcha atras hasta x=%.2f (retrocede %.2f), y=%.2f, se cae=%s" % [vel_obj, lado_atasco, xp, xa, xp - xa, moto.global_position.y, str(notas.get("cae_t", "no"))])
			if notas.has("x_parada") and xp - xa < 2.0: fallos.append("no sale marcha atrás (retrocede %.2f)" % (xp - xa))
		"suspension":
			print("MOTO suspension: compresion max delante %.2f detras %.2f; al frenar delante %.2f mas que detras" % [float(notas.get("d_max", 0)), float(notas.get("t_max", 0)), float(notas.get("d_frena", 0))])
			if float(notas.get("d_max", 0)) < 0.3 or float(notas.get("t_max", 0)) < 0.3: fallos.append("la suspension casi no se mueve al subir el bloque")
			if float(notas.get("d_frena", 0)) < 0.12: fallos.append("al frenar no se hunde delante")
		"atasco":
			var qm := float(notas.get("quieta_max", 0.0))
			print("MOTO atasco bloque=%d vel=%.0f ang=%.0f lado=%.1f: quieta con gas %.1f s en %s; final %s v=%.1f piloto=%s" % [bloque_i, vel_obj, rad_to_deg(ang_atasco), lado_atasco, qm, str(notas.get("quieta_pos", "-")), moto.global_position, moto.velocidad(), str(moto.piloto != null)])
			if qm > 1.0: fallos.append("se queda atascada %.1f s con gas" % qm)
		"choque":
			# sale despedido hacia delante (hacia el muro, por encima del manillar), nunca hacia atrás
			var adel_j: float = (j.global_position - moto.global_position).dot(Vector3(0, 0, -1))
			print("MOTO choque: el piloto acaba %.1f studs por delante de la moto" % adel_j)
			if adel_j < -1.0: fallos.append("sale despedido hacia atrás")
			if moto.piloto != null or not moto.caida: fallos.append("no tira al piloto contra el muro")
			if j.health >= 100.0: fallos.append("el choque no hace daño")
		"disparar":
			if int(j.arsenal.datos_equipado().get("mag", 12)) > 9: fallos.append("no dispara desde la moto")
		"giros":
			print("MOTO giros: v max sin cambio %.1f, en el cambio %.1f" % [float(notas.get("v_max_n", 0.0)), float(notas.get("v_max_c", 0.0))])
			print("MOTO giros: mano (en la moto) velocidad max %.1f studs/s (%s), aceleracion max %.0f (%s) media %.0f studs/s2" % [float(notas.get("v_max", 0.0)), str(notas.get("v_donde", "-")), float(notas.get("a_max", 0.0)), str(notas.get("a_donde", "-")), float(notas.get("a_sum", 0.0)) / maxf(1.0, float(notas.get("a_n", 0)))])
			if float(notas.get("v_max_n", 0.0)) > 14.0: fallos.append("la mano va demasiado rápida girando (%.1f studs/s)" % float(notas.get("v_max_n", 0.0)))
			if float(notas.get("v_max_c", 0.0)) > 20.0: fallos.append("la mano va demasiado rápida al pasar el arma por delante (%.1f studs/s)" % float(notas.get("v_max_c", 0.0)))
			if float(notas.get("a_max", 0.0)) > 400.0: fallos.append("la mano da tirones (aceleracion %.0f)" % float(notas.get("a_max", 0.0)))
		"apuntar360":
			var octs := []
			for b in 8:
				octs.append(int(notas.get("oct%d" % b, 0)))
			print("MOTO apuntar360: disparos por octante (0=delante, 2=izq, 4=detras, 6=der) %s; cañon-mira max %.1f° (media %.1f°); dentro del cuerpo %d fotogramas (%s); cambios de rama %d; mano izq. a %.2f del puño como mucho; tiron mano max %.2f studs/fotograma" % [
				str(octs), float(notas.get("err_max", 0.0)), float(notas.get("err_sum", 0.0)) / maxf(1.0, float(notas.get("err_n", 0))),
				int(notas.get("dentro", 0)), str(notas.get("dentro_que", "-")), int(notas.get("cambios", 0)), float(notas.get("izq_max", 0.0)), float(notas.get("tiron", 0.0))])
			for b in 8:
				if octs[b] == 0: fallos.append("no dispara en el octante %d" % b)
			if float(notas.get("err_max", 0.0)) > 12.0: fallos.append("el cañón no apunta a la mira (%.1f°)" % float(notas.get("err_max", 0.0)))
			if int(notas.get("dentro", 0)) > 3: fallos.append("el brazo o el arma atraviesan el cuerpo (%d fotogramas)" % int(notas.get("dentro", 0)))
			if int(notas.get("cambios", 0)) < 2: fallos.append("no pasa el brazo de delante a detrás")
			if float(notas.get("izq_max", 0.0)) > 0.8: fallos.append("la mano izquierda suelta el manillar (%.2f)" % float(notas.get("izq_max", 0.0)))
			if float(notas.get("tiron", 0.0)) > 1.2: fallos.append("la mano da un salto (%.2f)" % float(notas.get("tiron", 0.0)))
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
			for k in ["montado", "bajado", "resubido", "saltado"] + (["corria"] if montar_corriendo else []):
				if not notas.get(k, false): fallos.append("falla: " + k)
	if not modo in ["vitrina", "levantar", "levantar_hueco"] and not monta:
		fallos.append("no se sube")
	if modo in ["empinada", "bajada"] and min_y < -1.0:
		fallos.append("atraviesa el suelo (y %.1f)" % min_y)
	if fallos.is_empty():
		print("OK moto_" + modo)
	else:
		print("MAL moto_%s: %s" % [modo, ", ".join(fallos)])

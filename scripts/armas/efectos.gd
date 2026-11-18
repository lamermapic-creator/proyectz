class_name Efectos
## Efectos de combate (port de las funciones de ZClient: burst, splat, bloodAt, tracer, muzzleFlash), fogonazo con
## humo, casquillos y sonidos: grabaciones CC0 en `res://sonidos/` (ver `sonido`) o, si falta el archivo, sintetizados.

static var _decals := 0
static var _sonidos := {}
static var _mat_cache := {}
static var _vigilando := false


## las cachés estáticas (materiales, texturas, sonidos) se vacían al cerrar el juego; si no, Godot avisa de
## "resources still in use at exit"
static func _vigilar() -> void:
	if _vigilando:
		return
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.root == null:
		return
	_vigilando = true
	arbol.root.tree_exiting.connect(limpiar)


static func limpiar() -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol:
		for n in arbol.get_nodes_in_group("efectos_audio"):
			n.stop()
			n.stream = null
	_sonidos.clear()
	_mat_cache.clear()
	_variantes.clear()
	_ultima.clear()
	_tex_destello = null
	_tex_humo = null
	_casquillos.clear()
	_vigilando = false


static func _raiz(nodo: Node) -> Node:
	var arbol := nodo.get_tree()
	var fx := arbol.root.get_node_or_null("FX_Combate")
	if fx == null:
		fx = Node3D.new()
		fx.name = "FX_Combate"
		arbol.root.add_child(fx)
	return fx


static func _mat_unshaded(c: Color, emit := false) -> StandardMaterial3D:
	var k := c.to_html() + str(emit)
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit:
		m.emission_enabled = true
		m.emission = c
	_vigilar()
	_mat_cache[k] = m
	return m


static func _borrar_en(nodo: Node, t: float) -> void:
	# (referencia débil: si el nodo ya se borró antes, p. ej. el casquillo nº 31, la lambda no avisa de un error)
	var ref: WeakRef = weakref(nodo)
	nodo.get_tree().create_timer(t).timeout.connect(func():
		var n = ref.get_ref()
		if n != null:
			(n as Node).queue_free())


## chispas / salpicaduras: count partículas en un cono alrededor de la normal
static func burst(ctx: Node, pos: Vector3, normal: Vector3, color: Color, count: int, speed: float, size: float, life: float, gravity: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, count)
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = 3.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1))
	curva.add_point(Vector2(1, 0.3))
	p.scale_amount_curve = curva
	# gotitas / esquirlas pequeñas (esferas de pocos polígonos)
	var q := SphereMesh.new()
	q.radius = size * 0.22
	q.height = size * 0.44
	q.radial_segments = 6
	q.rings = 3
	q.material = _mat_unshaded(color)
	p.mesh = q
	_raiz(ctx).add_child(p)
	p.global_position = pos
	p.emitting = true
	_borrar_en(p, life + 0.5)


## mancha plana sobre una superficie (agujero de bala, charco de sangre)
static func splat(ctx: Node, pos: Vector3, normal: Vector3, color: Color, size: float, life: float) -> void:
	if _decals > 70:
		return
	_decals += 1
	var mi := MeshInstance3D.new()
	# mancha redonda (disco muy fino) pegada a la superficie. Material OPACO y compartido por color (antes era uno
	# transparente por mancha: hasta 70 materiales distintos que dibujar); al final se encoge en vez de desvanecerse
	var q := CylinderMesh.new()
	q.top_radius = size * 0.5
	q.bottom_radius = size * 0.5
	q.height = 0.02
	q.radial_segments = 12
	q.rings = 1
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var k := "splat" + color.to_html()
	if not _mat_cache.has(k):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
		mat.roughness = 0.6
		_vigilar()
		_mat_cache[k] = mat
	mi.material_override = _mat_cache[k]
	_raiz(ctx).add_child(mi)
	var n := normal.normalized()
	var ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(n).normalized()
	var z := x.cross(n).normalized()
	var b := Basis(x, n, z).rotated(n, randf() * TAU)
	# un poco irregular: ligeramente ovalada
	b = b * Basis.from_scale(Vector3(1.0, 1.0, 0.7 + randf() * 0.5))
	mi.global_transform = Transform3D(b, pos + n * 0.02)
	var tw := mi.create_tween()
	tw.tween_interval(life)
	tw.tween_property(mi, "scale", Vector3(0.01, 1.0, 0.01), 1.5)
	tw.tween_callback(func():
		_decals -= 1
		mi.queue_free())


static func blood_at(ctx: Node, pos: Vector3, normal: Vector3) -> void:
	burst(ctx, pos, normal, Color8(95, 5, 5), 16, 22, 0.35, 0.55, 70)
	burst(ctx, pos, normal, Color8(60, 0, 0), 6, 8, 0.8, 0.4, 20)
	# charco en el suelo
	var space := (ctx as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -12, 0), 1)
	var g := space.intersect_ray(q)
	if not g.is_empty():
		splat(ctx, g.position, g.normal, Color8(55, 4, 4), 1.0 + randf() * 1.6, 25)


## trazadora: un trazo luminoso que viaja de la boca del cañón al impacto
static func tracer(ctx: Node, from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 2:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 1.0)
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _mat_unshaded(Color8(255, 210, 140), true)
	_raiz(ctx).add_child(mi)
	var dir := (to - from) / dist
	var largo := minf(14.0, dist * 0.6)
	var viaje := maxf(dist / 900.0, 0.016)
	var tw := mi.create_tween()
	tw.tween_method(func(a: float):
		var head := from + dir * (dist * a)
		var tail := from + dir * maxf(0.0, dist * a - largo)
		var l := maxf(0.1, head.distance_to(tail))
		var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
		mi.global_transform = Transform3D(Basis.looking_at(dir, up).scaled_local(Vector3(1, 1, l)), (head + tail) * 0.5), 0.0, 1.0, viaje)
	tw.tween_callback(mi.queue_free)


## fogonazo: destello en estrella con brillo (dos planos: uno de frente y otro a lo largo del cañón), luz muy breve
## y una bocanada de humo que sale por la boca y se queda flotando
static var _tex_destello: Texture2D
static var _tex_humo: Texture2D


static func _textura_destello() -> Texture2D:
	if _tex_destello == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
				var r := d.length()
				var ang := atan2(d.y, d.x)
				# núcleo redondo + 5 puntas irregulares
				var puntas := pow(absf(cos(ang * 2.5 + 0.3)), 6.0) * 0.75 + pow(absf(cos(ang * 4.0)), 10.0) * 0.35
				var a := clampf(1.0 - r / (0.28 + puntas), 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				img.set_pixel(x, y, Color(1.0, 0.85 + 0.15 * (1.0 - r), 0.55 + 0.45 * maxf(0.0, 1.0 - r * 2.5), a))
		_vigilar()
		_tex_destello = ImageTexture.create_from_image(img)
	return _tex_destello


static func _textura_humo() -> Texture2D:
	if _tex_humo == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var ruido := FastNoiseLite.new()
		ruido.frequency = 0.09
		for y in n:
			for x in n:
				var r := Vector2(x - n * 0.5, y - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - r, 0.0, 1.0)
				a = a * a * (0.6 + 0.4 * (ruido.get_noise_2d(x, y) * 0.5 + 0.5))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_vigilar()
		_tex_humo = ImageTexture.create_from_image(img)
	return _tex_humo


static func _mat_destello() -> StandardMaterial3D:
	if not _mat_cache.has("destello"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = _textura_destello()
		m.albedo_color = Color(1.0, 0.8, 0.5)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		_vigilar()
		_mat_cache["destello"] = m
	return _mat_cache["destello"]


static func muzzle_flash(ctx: Node, mz: Transform3D, fuerza := 1.0) -> void:
	var raiz := _raiz(ctx)
	var luz := OmniLight3D.new()
	luz.light_color = Color8(255, 185, 105)
	luz.omni_range = 11
	luz.light_energy = 4.5 * fuerza
	raiz.add_child(luz)
	luz.global_position = (mz * Rbx.cf(0, 0, -0.3)).origin
	var t := 0.25 * fuerza * (0.85 + randf() * 0.4)
	# de frente (siempre mirando a la cámara)
	var f := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(t * 4.0, t * 4.0)
	f.mesh = qm
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _mat_cache.has("destello_bb"):
		var mf := _mat_destello().duplicate() as StandardMaterial3D
		mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_vigilar()
		_mat_cache["destello_bb"] = mf
	f.material_override = _mat_cache["destello_bb"]
	raiz.add_child(f)
	f.global_position = (mz * Rbx.cf(0, 0, -0.35 * fuerza)).origin
	f.rotation.z = randf() * TAU
	# a lo largo del cañón (se ve bien de lado): dos planos cruzados alargados
	for k in 2:
		var l := MeshInstance3D.new()
		var ql := QuadMesh.new()
		ql.size = Vector2(t * 2.4, t * 6.0)
		l.mesh = ql
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.material_override = _mat_destello()
		raiz.add_child(l)
		var base := mz * Transform3D(Basis(Vector3.BACK, k * PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -t * 3.0))
		l.global_transform = base
		_borrar_en(l, 0.035)
	_borrar_en(luz, 0.045)
	_borrar_en(f, 0.04)
	humo(ctx, mz, fuerza)


static func humo(ctx: Node, mz: Transform3D, fuerza := 1.0) -> void:
	# unas bocanadas (planos que miran a la cámara) que salen por la boca, crecen, suben y se desvanecen
	if not _mat_cache.has("humo"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _textura_humo()
		m.albedo_color = Color(0.93, 0.92, 0.9, 0.55)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_vigilar()
		_mat_cache["humo"] = m
	var raiz := _raiz(ctx)
	var adelante := -mz.basis.z.normalized()
	for k in int(2 + 2 * fuerza):
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.7, 0.7)
		mi.mesh = q
		mi.material_override = _mat_cache["humo"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		var p0 := mz.origin + adelante * (0.2 + k * 0.35)
		mi.global_position = p0
		mi.transparency = 0.35
		var dur := 0.8 + randf() * 0.5
		var deriva := adelante * (0.6 + randf() * 0.8) * fuerza + Vector3((randf() - 0.5) * 0.4, 0.5 + randf() * 0.5, (randf() - 0.5) * 0.4)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "global_position", p0 + deriva, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(mi, "scale", Vector3.ONE * (2.2 + randf()) * fuerza, dur).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "transparency", 1.0, dur).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)


## casquillo que sale despedido por la ventana de expulsión, rebota en el suelo (sonando) y se queda un rato
static var _casquillos: Array = []
const MAX_CASQUILLOS := 30


static func casquillo(ctx: Node, pos: Vector3, dir: Vector3, escopeta := false, vel_base := Vector3.ZERO) -> void:
	var b := RigidBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 1
	b.mass = 0.05
	b.continuous_cd = true
	b.contact_monitor = true
	b.max_contacts_reported = 1
	b.angular_damp = 0.8
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.6
	b.physics_material_override = pm
	var largo := 0.3 if escopeta else 0.16
	var radio := 0.065 if escopeta else 0.035
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(radio * 2.0, radio * 2.0, largo)
	cs.shape = bx
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radio
	cm.bottom_radius = radio
	cm.height = largo
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.rotation.x = PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var k := "casq" + str(escopeta)
	if not _mat_cache.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color8(170, 35, 30) if escopeta else Color8(205, 160, 70)
		m.metallic = 0.0 if escopeta else 0.85
		m.roughness = 0.5 if escopeta else 0.3
		_vigilar()
		_mat_cache[k] = m
	mi.material_override = _mat_cache[k]
	b.add_child(mi)
	_raiz(ctx).add_child(b)
	b.global_position = pos
	b.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	b.linear_velocity = vel_base + dir.normalized() * (7.0 + randf() * 3.0) + Vector3(0, 3.0, 0)
	b.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 30.0
	var sonado := [false]
	b.body_entered.connect(func(_o):
		if not sonado[0] and is_instance_valid(b):
			sonado[0] = true
			sonido(b, "Shell", b.global_position, 0.5, 1.0))
	_casquillos.append(b)
	while _casquillos.size() > MAX_CASQUILLOS:
		var v = _casquillos.pop_front()
		if is_instance_valid(v):
			v.queue_free()
	_borrar_en(b, 9.0)


## impacto de bala según lo que se golpea
static func impacto(ctx: Node, pos: Vector3, normal: Vector3, tipo: String) -> void:
	if tipo == "flesh":
		blood_at(ctx, pos, normal)
		sonido(ctx, "BulletBody", pos, 0.8, 0.9 + randf() * 0.2)
	elif tipo == "surface":
		burst(ctx, pos, normal, Color8(150, 140, 125), 8, 14, 0.3, 0.6, 30)
		burst(ctx, pos, normal, Color8(255, 200, 120), 3, 30, 0.08, 0.15, 0)
		splat(ctx, pos, normal, Color8(20, 20, 20), 0.28, 20)
		sonido(ctx, "Ricochet" if randf() < 0.35 else "BulletSurface", pos, 0.45, 0.9 + randf() * 0.2)


## ---------------------------------------------------------------- sonidos sintetizados
const RATE := 22050


static func _wav(datos: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(datos.size() * 2)
	for i in datos.size():
		bytes.encode_s16(i * 2, int(clampf(datos[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _generar(tipo: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tipo)
	var dur := 0.3
	match tipo:
		"Pistol": dur = 0.45
		"Rifle": dur = 0.4
		"Empty": dur = 0.05
		"Reload": dur = 0.5
		"Swing": dur = 0.3
		"Flesh": dur = 0.25
		"Blunt": dur = 0.3
		"Ricochet": dur = 0.25
		"Hit": dur = 0.05
		"Draw": dur = 0.2
		"Revolver": dur = 0.55
		"SMG": dur = 0.3
		"Shotgun": dur = 0.7
		"Sniper": dur = 0.9
		"Pump": dur = 0.35
		"Bolt": dur = 0.4
		"Shell": dur = 0.12
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var ruido := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match tipo:
			"Pistol", "Rifle", "SMG":
				# estampido: ruido con caída rápida + golpe grave + cola de eco
				var k := 38.0 if tipo == "Pistol" else (48.0 if tipo == "Rifle" else 60.0)
				lp += (ruido - lp) * (0.45 if tipo != "SMG" else 0.6)
				v = lp * exp(-t * k) * 1.3 + sin(TAU * (95.0 if tipo != "SMG" else 120.0) * t) * exp(-t * 22.0) * 0.9
				lp2 += (ruido - lp2) * 0.08
				v += lp2 * exp(-t * 7.0) * 0.35
			"Revolver", "Shotgun", "Sniper":
				# estampidos más graves y largos (más pólvora): golpe bajo fuerte y eco largo
				var k2 := {"Revolver": 26.0, "Shotgun": 18.0, "Sniper": 14.0}[tipo] as float
				var f := {"Revolver": 75.0, "Shotgun": 55.0, "Sniper": 48.0}[tipo] as float
				lp += (ruido - lp) * 0.35
				v = lp * exp(-t * k2) * 1.4 + sin(TAU * f * t) * exp(-t * 12.0) * 1.1
				lp2 += (ruido - lp2) * 0.05
				v += lp2 * exp(-t * 3.5) * 0.45
			"Pump":
				# corredera: dos golpes metálicos (atrás y adelante)
				for c0 in [0.0, 0.2]:
					var tc: float = t - c0
					if tc >= 0:
						v += (sin(TAU * 900.0 * tc) * 0.4 + ruido * 0.6) * exp(-tc * 60.0) * 0.8
			"Bolt":
				for c0 in [0.0, 0.12, 0.26, 0.34]:
					var tc2: float = t - c0
					if tc2 >= 0:
						v += (sin(TAU * 1500.0 * tc2) * 0.5 + ruido * 0.5) * exp(-tc2 * 110.0) * 0.6
			"Shell":
				v = (sin(TAU * 1100.0 * t) * 0.4 + ruido * 0.4) * exp(-t * 70.0)
			"Empty", "Hit":
				v = sin(TAU * 2400.0 * t) * exp(-t * 160.0) * 0.6
			"Reload":
				# dos chasquidos metálicos (cargador fuera / dentro)
				for c0 in [0.0, 0.3]:
					var tc: float = t - c0
					if tc >= 0:
						v += (sin(TAU * 1800.0 * tc) * 0.5 + ruido * 0.5) * exp(-tc * 90.0) * 0.7
			"Swing":
				# silbido: ruido filtrado con envolvente suave
				lp += (ruido - lp) * 0.12
				v = lp * sin(PI * t / dur) * 1.6
			"Flesh":
				lp += (ruido - lp) * 0.2
				v = lp * exp(-t * 25.0) * 1.2 + sin(TAU * 70.0 * t) * exp(-t * 30.0) * 0.8
			"Blunt":
				lp += (ruido - lp) * 0.3
				v = lp * exp(-t * 30.0) + sin(TAU * 55.0 * t) * exp(-t * 18.0) * 1.1
			"Ricochet":
				v = (sin(TAU * (3000.0 - 6000.0 * t) * t) * 0.4 + ruido * 0.3) * exp(-t * 18.0)
			"Draw":
				lp += (ruido - lp) * 0.5
				v = lp * exp(-t * 30.0) * 0.5
		out[i] = v
	return _wav(out)


## Sonidos GRABADOS (2026-10-27): `res://sonidos/<tipo>_<n>.ogg` (CC0 de Freesound, ver docs/SONIDOS.md). Si hay
## varias variantes se elige una al azar sin repetir la anterior; si no hay archivo, se sintetiza como antes.
## Con un sonido grabado, el tono pedido (pensado para los sintetizados) se suaviza: un tono muy cambiado suena falso.
static var _variantes := {}       # tipo -> Array[AudioStream] (vacío = no hay grabación)
static var _ultima := {}          # tipo -> índice de la última variante usada
const CARPETA_SONIDOS := "res://sonidos/"


static func _grabados(tipo: String) -> Array:
	if not _variantes.has(tipo):
		var lista := []
		var n := 1
		while ResourceLoader.exists(CARPETA_SONIDOS + "%s_%d.ogg" % [tipo, n]):
			lista.append(load(CARPETA_SONIDOS + "%s_%d.ogg" % [tipo, n]))
			n += 1
		_vigilar()
		_variantes[tipo] = lista
	return _variantes[tipo]


## carga (o genera) de antemano todos los sonidos: el primer disparo ya no da un tirón
static func precargar() -> void:
	for tipo in ["Pistol", "Revolver", "Rifle", "SMG", "Shotgun", "Sniper", "Pump", "Bolt", "ReloadRifle", "ReloadPistol",
			"Reload", "Empty", "Draw", "Shell", "Swing", "Flesh", "Blunt", "Ricochet", "Impact", "Step", "Land", "BodyFall", "Hit"]:
		if _grabados(tipo).is_empty() and not _sonidos.has(tipo):
			_vigilar()
			_sonidos[tipo] = _generar(tipo)
	for tipo in BASE_IMPACTO:
		_grabados(tipo)
	_limitador_master()
	# y las texturas del fogonazo y del humo (se generan por código)
	_textura_destello()
	_textura_humo()


## limitador en el bus Master (solo en tiempo de juego, no toca default_bus_layout): varios disparos a la vez no
## saturan (se oían "rotos")
static func _limitador_master() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	lim.release = 0.12
	AudioServer.add_bus_effect(0, lim)


const BASE_IMPACTO := {
	"Punch": "Blunt", "Kick": "Blunt", "Stomp": "BodyFall", "Block": "Blunt",
	"Blade": "Flesh", "BatHit": "Blunt", "BulletBody": "Flesh",
	"BulletSurface": "Impact", "Crash": "Impact",
}


static func _stream(tipo: String) -> Array:
	# sin ventana (pruebas --headless) no se oye nada: se usa el sintetizado, que no deja archivos .ogg
	# reproduciéndose al salir (el servidor de audio "dummy" no los suelta → "resources still in use at exit")
	var g: Array = [] if DisplayServer.get_name() == "headless" else _grabados(tipo)
	if not g.is_empty():
		var i := randi() % g.size()
		if g.size() > 1 and i == int(_ultima.get(tipo, -1)):
			i = (i + 1) % g.size()
		_ultima[tipo] = i
		return [g[i], true]
	tipo = BASE_IMPACTO.get(tipo, tipo)
	if not _sonidos.has(tipo):
		_vigilar()
		_sonidos[tipo] = _generar(tipo)
	return [_sonidos[tipo], false]


static func sonido(ctx: Node, tipo: String, pos, vol := 1.0, tono := 1.0) -> void:
	var sel := _stream(tipo)
	if sel[1]:
		tono = clampf(lerpf(1.0, tono, 0.35), 0.82, 1.22) * (0.96 + randf() * 0.08)
	var raiz := _raiz(ctx)
	if pos == null:
		var p2 := AudioStreamPlayer.new()
		p2.add_to_group("efectos_audio")
		p2.stream = sel[0]
		p2.volume_db = linear_to_db(vol)
		p2.pitch_scale = tono
		raiz.add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)
		return
	var p := AudioStreamPlayer3D.new()
	p.add_to_group("efectos_audio")
	p.stream = sel[0]
	# (2026-10-27) antes +6 dB y hasta +3 dB más por la distancia: los .ogg ya vienen casi a 0 dBFS, así que todo
	# saturaba (sobre todo las ráfagas del rifle). Ahora -4 dB, sin ganancia extra de cerca y un limitador en Master.
	p.volume_db = linear_to_db(vol) - 4.0
	p.max_db = 0.0
	p.pitch_scale = tono
	p.unit_size = 12.0 # escala en studs
	p.max_distance = 600.0
	# los disparos se oyen de lejos (y no se cortan en seco al alejarse)
	if tipo in ["Pistol", "Revolver", "Rifle", "SMG", "Shotgun", "Sniper"]:
		p.unit_size = 40.0
		p.max_distance = 1400.0
	raiz.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

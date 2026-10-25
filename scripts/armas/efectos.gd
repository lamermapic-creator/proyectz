class_name Efectos
## Efectos de combate (port de las funciones de ZClient: burst, splat, bloodAt, tracer, muzzleFlash)
## y sonidos sintetizados (no hay archivos de audio todavía: se generan al vuelo, gratis).

static var _decals := 0
static var _sonidos := {}
static var _mat_cache := {}


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
	_mat_cache[k] = m
	return m


static func _borrar_en(nodo: Node, t: float) -> void:
	nodo.get_tree().create_timer(t).timeout.connect(func(): if is_instance_valid(nodo): nodo.queue_free())


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
	# mancha redonda (disco muy fino) pegada a la superficie
	var q := CylinderMesh.new()
	q.top_radius = size * 0.5
	q.bottom_radius = size * 0.5
	q.height = 0.02
	q.radial_segments = 12
	q.rings = 1
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
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
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 1.5)
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


static func muzzle_flash(ctx: Node, mz: Transform3D) -> void:
	var raiz := _raiz(ctx)
	var luz := OmniLight3D.new()
	luz.light_color = Color8(255, 190, 110)
	luz.omni_range = 16
	luz.light_energy = 6
	raiz.add_child(luz)
	luz.global_position = mz.origin
	var f := MeshInstance3D.new()
	var s := SphereMesh.new()
	var r := 0.25 * (0.8 + randf() * 0.5)
	s.radius = r
	s.height = r * 2
	f.mesh = s
	f.material_override = _mat_unshaded(Color8(255, 200, 120), true)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(f)
	f.global_position = (mz * Rbx.cf(0, 0, -0.2)).origin
	_borrar_en(luz, 0.05)
	_borrar_en(f, 0.04)


## impacto de bala según lo que se golpea
static func impacto(ctx: Node, pos: Vector3, normal: Vector3, tipo: String) -> void:
	if tipo == "flesh":
		blood_at(ctx, pos, normal)
		sonido(ctx, "Flesh", pos, 0.8, 0.9 + randf() * 0.2)
	elif tipo == "surface":
		burst(ctx, pos, normal, Color8(150, 140, 125), 8, 14, 0.3, 0.6, 30)
		burst(ctx, pos, normal, Color8(255, 200, 120), 3, 30, 0.08, 0.15, 0)
		splat(ctx, pos, normal, Color8(20, 20, 20), 0.28, 20)
		sonido(ctx, "Ricochet", pos, 0.35, 0.8 + randf() * 0.4)


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


static func sonido(ctx: Node, tipo: String, pos, vol := 1.0, tono := 1.0) -> void:
	if not _sonidos.has(tipo):
		_sonidos[tipo] = _generar(tipo)
	var raiz := _raiz(ctx)
	if pos == null:
		var p2 := AudioStreamPlayer.new()
		p2.stream = _sonidos[tipo]
		p2.volume_db = linear_to_db(vol)
		p2.pitch_scale = tono
		raiz.add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _sonidos[tipo]
	p.volume_db = linear_to_db(vol) + 6.0
	p.pitch_scale = tono
	p.unit_size = 12.0 # escala en studs
	p.max_distance = 600.0
	raiz.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

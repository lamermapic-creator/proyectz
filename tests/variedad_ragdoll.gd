extends SceneTree
## Ocho posturas/tiros idénticos: medir diversidad física, contracciones y reposo final.
## --capturas=/ruta permite revisar los mismos casos con un renderizador.
var mundo: Node3D
var fallos := 0
var comprobaciones := 0
var destino := ""
var titulo: Label
var detalle := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--detalle":
			detalle = true
		if arg.begins_with("--capturas="):
			destino = arg.trim_prefix("--capturas=")
	probar.call_deferred()

func comprobar(ok: bool, texto: String) -> void:
	comprobaciones += 1
	if not ok:
		fallos += 1
		printerr("MAL variedad: ",texto)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func postura(rd: Ragdoll) -> Array[Vector3]:
	var p := rd.pelvis()
	return [(rd.cuerpos.Head as RigidBody3D).global_position-p,
		(rd.cuerpos.LeftHand as RigidBody3D).global_position-p,
		(rd.cuerpos.RightFoot as RigidBody3D).global_position-p]

func distancia(a: Array, b: Array) -> float:
	var d := 0.0
	for i in a.size(): d += (a[i] as Vector3).distance_to(b[i])
	return d

func probar() -> void:
	mundo = Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var piso := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(200,0.5,200)
	col.shape = caja
	piso.add_child(col)
	piso.position.y = -0.25
	mundo.add_child(piso)
	if not destino.is_empty():
		preparar_vista()
	Zombi.ciegos = true
	Zombi.sordos = true
	var actores: Array[Zombi] = []
	var semillas := [11,22,33,44,55,66,77,88]
	for i in semillas.size():
		var z := Zombi.new()
		z.variante_visual = "civil"
		z.deambula = false
		z.position = Vector3((i%4-1.5)*9,3.1,-float(i/4)*14)
		mundo.add_child(z)
		z.set_process(false)
		z.set_physics_process(false)
		z._var = 0.0
		z._process(0.0)
		actores.append(z)
		if not destino.is_empty():
			var label := Label3D.new()
			label.text = str(i+1)
			label.font_size = 60
			label.pixel_size = 0.018
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = z.position+Vector3(0,3.0,0)
			mundo.add_child(label)
	var estira := 0.0
	var velocidad_max := 0.0
	var contraccion_max := 0.0
	var izquierda := 0
	var derecha := 0
	var muestras: Array = []
	for frame in 645:
		if frame==30:
			for i in actores.size():
				var z := actores[i]
				var punto: Vector3 = z.rig.P.UpperTorso.global_transform*Vector3(0,0.1,-0.37)
				z.recibir_disparo(10000,"UpperTorso",Vector3(0,0,0.65),punto)
				comprobar(not z._ragdoll._perfil_muerte.is_empty(), "la muerte activa la variedad automáticamente en el juego")
				z._ragdoll._preparar_muerte(semillas[i])
		await frames(1)
		if frame>=30:
			for z in actores:
				var rd: Ragdoll = z._ragdoll
				velocidad_max = maxf(velocidad_max,rd.velocidad())
				for mn in Ragdoll.ART:
					var m: RigPersonaje.Motor = z.rig.M[mn]
					var pa: RigidBody3D = rd.cuerpos[m.part0]
					var hi: RigidBody3D = rd.cuerpos[m.part1]
					estira = maxf(estira,(pa.global_transform*m.c0).origin.distance_to((hi.global_transform*m.c1).origin))
				if rd._t_comp>2.0 and rd.torso().global_position.y<1.6:
					for evento in rd._nervios_activos:
						var m: RigPersonaje.Motor = z.rig.M[evento.mn]
						var real: Basis = (rd.cuerpos[m.part0] as RigidBody3D).global_basis.inverse()*(rd.cuerpos[m.part1] as RigidBody3D).global_basis
						var ang := (evento.base as Basis).get_rotation_quaternion().angle_to(real.get_rotation_quaternion())
						contraccion_max = maxf(contraccion_max,ang)
		if frame==150:
			for z in actores:
				var x: float = (z._ragdoll.cuerpos.Head as RigidBody3D).global_position.x-z._ragdoll.pelvis().x
				if x < -0.2: izquierda += 1
				if x > 0.2: derecha += 1
		if not destino.is_empty():
			titulo.text = "MISMO DISPARO · CAÍDAS Y CONTRACCIONES DISTINTAS · %.2f s" % ((frame-30)/60.0)
			if frame%12==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(destino.path_join("%03d.png"%frame))
	for i in actores.size():
		var rd: Ragdoll = actores[i]._ragdoll
		var p := postura(rd)
		if muestras.all(func(a): return distancia(a,p)>1.0): muestras.append(p)
		comprobar(rd._nervios_emitidos>=4,"hay contracciones nerviosas programadas por muerte")
		comprobar(rd._congelado or rd.velocidad()<1.2,"el cadáver termina quieto")
		comprobar(rd._nervios_activos.is_empty() and rd._nervios.is_empty(),"la actividad nerviosa termina")
		print("VARIEDAD semilla=%d cabeza=%s contracciones=%d quieto=%s"%[semillas[i],p[0],rd._nervios_emitidos,str(rd._congelado)])
	comprobar(muestras.size()>=4,"al menos cuatro posturas distintas con el mismo disparo")
	comprobar(izquierda>0 and derecha>0,"hay caídas hacia ambos lados")
	comprobar(contraccion_max>deg_to_rad(4.0),"hay movimiento articular visible durante las contracciones en el suelo")
	comprobar(estira<0.6,"las articulaciones permanecen unidas")
	comprobar(velocidad_max<25.0,"la variación no catapulta el cuerpo")
	print("VARIEDAD posturas=%d izquierda=%d derecha=%d contraccion=%.2f grados estira=%.3f vmax=%.2f"%[muestras.size(),izquierda,derecha,rad_to_deg(contraccion_max),estira,velocidad_max])
	print("VARIEDAD_RAGDOLL comprobaciones=%d fallos=%d"%[comprobaciones,fallos])
	mundo.free()
	quit(1 if fallos else 0)

func preparar_vista() -> void:
	root.size = Vector2i(1200,800)
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(destino)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202a32")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b4c7d1")
	env.environment.ambient_light_energy = 0.6
	mundo.add_child(env)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55,-25,0)
	luz.light_energy = 1.4
	luz.shadow_enabled = true
	mundo.add_child(luz)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200,200)
	suelo.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("44505a")
	suelo.material_override = mat
	mundo.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 38
	mundo.add_child(cam)
	cam.position = Vector3(18,23,-34)
	cam.look_at(Vector3(0,1.5,-6))
	if detalle:
		cam.size = 10
		cam.position = Vector3(11.5,8,-23)
		cam.look_at(Vector3(4.5,1.5,-15))
	cam.current = true
	var capa := CanvasLayer.new()
	root.add_child(capa)
	titulo = Label.new()
	titulo.position = Vector2(20,20)
	titulo.add_theme_font_size_override("font_size",22)
	capa.add_child(titulo)

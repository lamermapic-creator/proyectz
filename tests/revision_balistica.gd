extends SceneTree
## Revisión visual reproducible de seis impactos. --capturas=/ruta guarda fotogramas reales de Godot.
var destino := ""
var detalle := false

func _initialize() -> void:
	detalle = OS.get_cmdline_user_args().has("--detalle")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			destino = arg.trim_prefix("--capturas=")
	iniciar.call_deferred()

func iniciar() -> void:
	seed(73)
	root.size = Vector2i(1200, 800)
	root.msaa_3d = Viewport.MSAA_2X
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("202a32")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("b4c7d1")
	ambiente.environment.ambient_light_energy = 0.6
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, -25, 0)
	luz.light_energy = 1.4
	luz.shadow_enabled = true
	mundo.add_child(luz)
	var piso := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(200, 0.5, 200)
	col.shape = forma
	piso.add_child(col)
	piso.position.y = -0.25
	mundo.add_child(piso)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200, 200)
	suelo.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("44505a")
	suelo.material_override = mat
	mundo.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 29
	mundo.add_child(cam)
	cam.position = Vector3(17, 22, 32)
	cam.look_at(Vector3(0, 1.5, -5))
	cam.current = true
	Zombi.ciegos = true
	Zombi.sordos = true
	var casos := [
		["CABEZA · FRENTE", "Head", Vector3(0, 0, 0.65), Vector3(0.12, 0.15, -0.39)],
		["TORSO · IZQUIERDA", "UpperTorso", Vector3(0, 0, 0.65), Vector3(-0.5, 0.1, -0.37)],
		["TORSO · DERECHA", "UpperTorso", Vector3(0, 0, 0.65), Vector3(0.5, 0.1, -0.37)],
		["TORSO · ESPALDA", "UpperTorso", Vector3(0, 0, -0.65), Vector3(0.2, 0.1, 0.37)],
		["PIERNA · LATERAL", "LeftLowerLeg", Vector3(0.65, 0, 0), Vector3(-0.22, 0, 0)],
		["BRAZO · LATERAL", "RightUpperArm", Vector3(-0.65, 0, 0), Vector3(0.19, 0.25, 0)],
	]
	if detalle:
		casos = [["TORSO · ENTRADA FRONTAL", "UpperTorso", Vector3(0,0,0.65), Vector3(-0.25,0.1,-0.37)]]
		cam.size = 8.5
		cam.position = Vector3(7,5.5,-13)
		cam.look_at(Vector3(0,2.7,0))
	var actores: Array[Zombi] = []
	for i in casos.size():
		var z := Zombi.new()
		z.variante_visual = "civil"
		z.deambula = false
		z.position = Vector3(0,3.1,0) if detalle else Vector3((i % 3 - 1) * 9, 3.1, -float(i / 3) * 12)
		mundo.add_child(z)
		z._rng.seed = 73
		z._var = 0.0 # misma postura inicial: comparar el punto de impacto
		actores.append(z)
		var label := Label3D.new()
		label.text = casos[i][0]
		label.visible = not detalle
		label.font_size = 48
		label.pixel_size = 0.018
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = z.position + Vector3(0, 3.0, 0)
		mundo.add_child(label)
	var capa := CanvasLayer.new()
	root.add_child(capa)
	var titulo := Label.new()
	titulo.position = Vector2(25, 20)
	titulo.add_theme_font_size_override("font_size", 24)
	capa.add_child(titulo)
	if not destino.is_empty():
		DirAccess.make_dir_recursive_absolute(destino)
	for frame in 300:
		if frame == 45 or (detalle and frame == 105):
			for i in actores.size():
				var z := actores[i]
				var pieza: String = casos[i][1]
				var punto: Vector3 = z.rig.P[pieza].global_transform * casos[i][3]
				z.recibir_disparo(10.0 if detalle and frame==45 else 10000.0, pieza, casos[i][2], punto)
		titulo.text = "REACCIÓN FÍSICA A DISPAROS · %.2f s" % ((frame - 45) / 60.0)
		if detalle:
			titulo.text = "ANTES DEL DISPARO" if frame < 45 else ("TORSO · IMPACTO NO MORTAL" if frame < 105 else "TORSO · IMPACTO MORTAL") + " · %.2f s" % ((frame - (45 if frame < 105 else 105)) / 60.0)
		await process_frame
		if not destino.is_empty() and frame % 6 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destino.path_join("%03d.png" % frame))
	print("REVISION_BALISTICA seis casos, simulación completa")
	quit()

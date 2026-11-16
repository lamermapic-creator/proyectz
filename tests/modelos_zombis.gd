extends SceneTree
## Importación real, seis clips con movimiento y contrato de combate de cada variante.
var fallos := 0
var comprobaciones := 0

func _initialize() -> void:
	probar.call_deferred()

func comprobar(ok: bool, mensaje: String) -> void:
	comprobaciones += 1
	if not ok:
		fallos += 1
		printerr("MAL ", mensaje)

func probar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	for id in Zombi.VARIANTES_VISUALES:
		var recurso := load(RigPersonaje.MODELOS["zombi_" + id]) as PackedScene
		comprobar(recurso != null, id + " recurso")
		if recurso == null:
			continue
		var modelo := recurso.instantiate() as Node3D
		mundo.add_child(modelo)
		var ap := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
		comprobar(ap != null, id + " AnimationPlayer")
		if ap:
			var cintura := modelo.find_child("J_Waist", true, false) as Node3D
			for clip in ["reposo", "caminar", "perseguir", "atacar", "herido", "morir"]:
				comprobar(ap.has_animation(clip), id + " clip " + clip)
				if not ap.has_animation(clip):
					continue
				ap.play(clip)
				ap.seek(0.0, true)
				var antes := cintura.transform
				ap.seek(ap.get_animation(clip).length * 0.35, true)
				var despues := cintura.transform
				var raiz := modelo.find_child("J_Root", true, false) as Node3D
				comprobar(not antes.is_equal_approx(despues) or (clip == "morir" and raiz.position.y < -0.1), id + " movimiento " + clip)
		modelo.free()
		var z := Zombi.new()
		z.variante_visual = id
		z.deambula = false
		mundo.add_child(z)
		comprobar(z.rig.modelo == "zombi_" + id, id + " selección")
		for parte in RigPersonaje.PIEZAS:
			var pieza := z.rig.P[parte] as Node3D
			var meshes := pieza.find_children("M_*", "MeshInstance3D", false, false)
			comprobar(meshes.size() == 1, id + " malla " + parte)
			comprobar(pieza.get_meta("size") == RigPersonaje.PIEZAS[parte][0], id + " tamaño impacto " + parte)
			if parte == "Head":
				var piel_embebida := false
				var relieve_embebido := false
				for mi in meshes:
					for superficie in mi.mesh.get_surface_count():
						var mat := mi.mesh.surface_get_material(superficie) as BaseMaterial3D
						if mat and mat.normal_enabled and mat.normal_texture:
							relieve_embebido = mat.normal_texture.get_width() == 512
						if mat and mat.albedo_texture:
							piel_embebida = mat.albedo_texture.get_width() == 512 and mat.albedo_texture.get_height() == 512
				comprobar(piel_embebida, id + " piel embebida 512x512")
				comprobar(relieve_embebido, id + " normales de piel embebidas")
			if parte in ["Head", "UpperTorso"]:
				var detalle := false
				for mi in meshes:
					for superficie in mi.mesh.get_surface_count():
						var mat := mi.mesh.surface_get_material(superficie) as BaseMaterial3D
						if mat:
							if parte == "Head" and mat.resource_name.begins_with("Cerebro"):
								detalle = true
							if parte == "UpperTorso" and mat.resource_name.begins_with("SangreRopa") and mat.albedo_texture:
								detalle = mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				if parte == "Head":
					comprobar(detalle == (id in ["civil", "sanitario", "paciente"]), id + " cerebro solo en variantes previstas")
				else:
					comprobar(detalle, id + " sangre con textura y transparencia")
		var vida := z.health
		z.recibir_danio(10, "UpperTorso", Vector3.FORWARD)
		comprobar(z.health < vida, id + " recibir daño")
		z.derribar(Vector3(1, 2, 0), 5)
		comprobar(not z.en_pie(), id + " derribo")
		z.recibir_danio(10000, "Head", Vector3(1, 2, 0))
		comprobar(not z.vivo(), id + " muerte")
		z.free()
	mundo.free()
	print("MODELOS_ZOMBIS comprobaciones=%d fallos=%d" % [comprobaciones, fallos])
	quit(1 if fallos else 0)

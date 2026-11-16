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

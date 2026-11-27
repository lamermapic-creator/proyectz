extends SceneTree
## Ejecutar con --headless --fixed-fps 60 en la zona de pruebas.

func _initialize() -> void:
	call_deferred("_probar")

func _probar() -> void:
	change_scene_to_file("res://escenas/pruebas_movimiento.tscn")
	await scene_changed
	var j := current_scene.get_node("Jugador") as Jugador
	j.teletransportar(Vector3(0,0,-54),0)
	for i in 20:
		await process_frame
	var peor := 0.0
	var anterior := {}
	for postura in [1, 0, 2, 0]:
		j.set_stance(postura)
		for i in 105:
			await process_frame
			for parte in ["LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
				var pieza: Node3D = j.rig.P[parte]
				var pos := pieza.global_position
				if anterior.has(parte):
					peor = maxf(peor, pos.distance_to(anterior[parte]))
				anterior[parte] = pos
		print("POSTURA ", postura, " actual=", j.stance, " tumbado=", j.prone_p, " pico=", peor)
		if j.stance != postura or not is_equal_approx(j.prone_p, 1.0 if postura == 2 else 0.0):
			quit(1)
			return
	quit(0 if peor < 0.37 else 1)

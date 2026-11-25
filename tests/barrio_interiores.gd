extends SceneTree

func _initialize() -> void:
	call_deferred("_probar")


func _probar() -> void:
	change_scene_to_file("res://escenas/barrio_canal.tscn")
	await scene_changed
	for i in 4:
		await physics_frame
	var j := current_scene.get_node("Jugador") as Jugador
	for i in 4:
		var casa := current_scene.get_node("Casa%d" % i) as Node3D
		var entrada := casa.to_global(Vector3(0,0,17))
		j.teletransportar(entrada,casa.rotation.y)
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_W
		tecla.pressed = true
		Input.parse_input_event(tecla)
		for k in 150:
			await physics_frame
		tecla.pressed = false
		Input.parse_input_event(tecla)
		var local := casa.to_local(j.global_position)
		print("Casa ",i," interior ",local)
		if local.z >= 12 or local.z < -13 or local.y < 0:
			quit(1)
			return
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_probar")

func _tecla(codigo: Key, pulsada: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = codigo
	e.keycode = codigo
	e.pressed = pulsada
	Input.parse_input_event(e)

func _probar() -> void:
	change_scene_to_file("res://escenas/pruebas_movimiento.tscn")
	await scene_changed
	var j := current_scene.get_node("Jugador") as Jugador
	var casos := {KEY_A: Vector3.LEFT, KEY_S: Vector3.BACK, KEY_D: Vector3.RIGHT}
	for tecla in casos:
		j.teletransportar(Vector3(0,0,-54),0)
		for i in 12:
			await physics_frame
		j.yaw = PI / 2
		j.rotation.y = 0
		var inicio := j.global_position
		_tecla(tecla,true)
		_tecla(KEY_SPACE,true)
		for i in 3:
			await physics_frame
		_tecla(tecla,false)
		_tecla(KEY_SPACE,false)
		for i in 12:
			await physics_frame
		var delta := j.global_position - inicio
		print("SALTO ASD ", OS.get_keycode_string(tecla), " ", delta)
		if delta.dot(casos[tecla]) < 0.5 or delta.y < 0.5 or j.vaulting != null or j.colgado != null:
			quit(1)
			return
		for i in 85:
			await physics_frame
	quit()

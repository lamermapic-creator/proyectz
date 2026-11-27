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
	for tecla in [KEY_A, KEY_S, KEY_D]:
		j.teletransportar(Vector3(0, 0, -54), 0)
		for i in 12:
			await physics_frame
		_tecla(tecla, true)
		_tecla(KEY_SPACE, true)
		for i in 18:
			await physics_frame
			if not j.en_suelo:
				break
		if j.en_suelo:
			quit(1)
			return
		var inicio_vuelo := j.global_position
		for i in 10:
			await physics_frame
		var delta := j.global_position - inicio_vuelo
		_tecla(tecla, false)
		_tecla(KEY_SPACE, false)
		print("SALTO ASD ", OS.get_keycode_string(tecla), " ", delta)
		if Rbx.flat(delta).length() > 0.05 or delta.y < 0.5 or j.vaulting != null or j.colgado != null:
			quit(1)
			return
		for i in 85:
			await physics_frame
	quit()

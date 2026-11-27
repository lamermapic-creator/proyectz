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
	var casos := [
		[[KEY_W], Vector3.FORWARD, 1.0],
		[[KEY_A], Vector3.LEFT, 1.0],
		[[KEY_S], Vector3.BACK, 1.0],
		[[KEY_D], Vector3.RIGHT, 1.0],
		[[KEY_W, KEY_A], Vector3.FORWARD + Vector3.LEFT, 1.0],
		[[KEY_W, KEY_D], Vector3.FORWARD + Vector3.RIGHT, 1.0],
		[[KEY_W, KEY_S], Vector3.ZERO, 0.0],
		[[KEY_A, KEY_S], Vector3.LEFT + Vector3.BACK, 1.0],
		[[KEY_S, KEY_D], Vector3.BACK + Vector3.RIGHT, 1.0],
		[[KEY_A, KEY_S, KEY_D], Vector3.BACK, 1.0],
		[[KEY_A, KEY_D], Vector3.ZERO, 0.0],
	]
	for armado in [false, true]:
		if armado:
			j.arsenal.select_slot(0)
			for i in 60:
				await physics_frame
		for caso in casos:
			j.teletransportar(Vector3(0, 0, -54), 0)
			for i in 12:
				await physics_frame
			# La cámara y el personaje empiezan mirando en direcciones diferentes.
			j.yaw = PI / 2
			j.rotation.y = 0
			for tecla in caso[0]:
				_tecla(tecla, true)
			_tecla(KEY_SPACE, true)
			for i in 24:
				await physics_frame
				if not j.en_suelo:
					break
			if j.en_suelo:
				quit(1)
				return
			var esperado := (caso[1] as Vector3).normalized().rotated(Vector3.UP, PI / 2)
			var direccion_correcta := j._direccion_salto.is_equal_approx(esperado)
			var mira_correcta: bool = armado or esperado.is_zero_approx() or (-j.global_basis.z).dot(esperado) > 0.99
			var escala: float = caso[2]
			if armado and not caso[0].has(KEY_W):
				escala *= 0.28
			var distancia_correcta := is_equal_approx(j._distancia_salto, float(ZConfig.PLAYER.JumpDistance) * escala)
			var inicio := j.global_position
			for i in 12:
				await physics_frame
			var delta := j.global_position - inicio
			for tecla in caso[0]:
				_tecla(tecla, false)
			_tecla(KEY_SPACE, false)
			var vuelo_correcto := Rbx.flat(delta).length() < 0.05 if escala == 0.0 else Rbx.flat(delta).normalized().dot(esperado) > 0.99
			print("SALTO armado=", armado, " teclas=", caso[0], " delta=", delta)
			if not (direccion_correcta and mira_correcta and distancia_correcta and vuelo_correcto) or delta.y < 0.35:
				quit(1)
				return
			for i in 85:
				await physics_frame
	quit()

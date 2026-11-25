extends SceneTree
## Ejecutar con --fixed-fps 30, 60 o 120 para comparar el mismo recorrido.

func _initialize() -> void:
	call_deferred("_probar")

func _probar() -> void:
	change_scene_to_file("res://escenas/pruebas_movimiento.tscn")
	await scene_changed
	for i in 12:
		await physics_frame
	var jugador := current_scene.get_node("Jugador") as Jugador
	var inicio := jugador.global_position
	var t0 := jugador.reloj
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_W
	tecla.pressed = true
	Input.parse_input_event(tecla)
	for i in 120:
		await physics_frame
	var desplazamiento := jugador.global_position.distance_to(inicio)
	print("PASO_FIJO segundos=%.4f distancia=%.4f" % [jugador.reloj - t0, desplazamiento])
	quit(0 if absf(desplazamiento - 8.2609) < 0.05 and is_equal_approx(jugador.reloj - t0, 2.0) else 1)

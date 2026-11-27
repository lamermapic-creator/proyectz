extends SceneTree
## Ejecutar con --headless --fixed-fps 60. Mide los pies del rig al cambiar de ritmo y dirección.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://escenas/pruebas_movimiento.tscn")
	await scene_changed
	await process_frame
	var j := current_scene.get_node("Jugador") as Jugador
	var muestras: Array[float] = []
	var previo := {}
	for entrada in [[KEY_W,KEY_SHIFT],[KEY_W],[KEY_D],[KEY_A],[KEY_S],[KEY_W],[]]:
		for tecla in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SHIFT]:
			var e := InputEventKey.new()
			e.physical_keycode = tecla
			e.pressed = entrada.has(tecla)
			Input.parse_input_event(e)
		for n in 38:
			await process_frame
			for nombre in ["LeftFoot","RightFoot"]:
				var pos: Vector3 = j.rig.P[nombre].global_position
				if previo.has(nombre):
					muestras.append(pos.distance_to(previo[nombre]))
				previo[nombre] = pos
	muestras.sort()
	print("ZANCADAS pico=", muestras[-1]," p95=",muestras[int(muestras.size()*0.95)])
	quit(0 if muestras[-1] < 1.0 else 1)

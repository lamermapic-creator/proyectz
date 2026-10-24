extends Node
## Prueba: túnel de 1.4 m (techo a 4.52 studs). De pie no se puede entrar (la cabeza choca);
## agachado sí. Mide también la altura de la cabeza en cada postura.
## --agachado: entra agachado. Imprime la z alcanzada y si la cabeza quedó dentro del techo.
var j: Jugador
var t := 0.0
var agachado := false
var max_pen := 0.0

func _key(k: int, p: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = p
	Input.parse_input_event(ev)

func _ready() -> void:
	agachado = OS.get_cmdline_user_args().has("--agachado")
	j = get_parent().get_node("Jugador")
	# túnel 1.4 m en (4, 0, 10) m, largo 6 m en z: entrada sur en z = 13 m
	j.global_position = Vector3(4 / 0.31, 3.2, 16.5 / 0.31)
	j.yaw = 0.0
	j.estamina_infinita = true

func _process(dt: float) -> void:
	t += dt
	if agachado and t > 0.3 and not has_meta("c"):
		set_meta("c", true)
		_key(KEY_C, true)
	if agachado and t > 0.5 and not has_meta("c2"):
		set_meta("c2", true)
		_key(KEY_C, false)
	if t > 1.2 and not has_meta("w"):
		set_meta("w", true)
		_key(KEY_W, true)
		if OS.get_cmdline_user_args().has("--correr"):
			_key(KEY_SHIFT, true)
	var head: Node3D = j.rig.P.Head
	var top := head.global_position.y + 0.6
	var techo := 1.4 / 0.31
	var z_m := j.global_position.z * 0.31
	if z_m < 13.0 and z_m > 7.0:
		max_pen = maxf(max_pen, top - techo)
	if Engine.get_process_frames() % 30 == 0:
		print("TUNEL t=%.1f z=%.2fm cabeza=%.2f techo=%.2f postura=%d rel=%.2f" % [t, z_m, top, techo, j.stance, top - j.global_position.y])
	if t > 7.0:
		print("TUNEL FIN z=%.2fm cabeza_dentro_del_techo=%.2f studs" % [z_m, max_pen])
		get_tree().quit()

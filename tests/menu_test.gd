extends Node
## abre el menú principal; a los 2.5 s abre Opciones y a los 4 s Controles; a los 5.5 s pulsa Jugar
## y a los 8 s abre la pausa (Esc) y luego sus opciones
var t := 0.0
var hecho := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# este nodo sobrevive al cambio de escena (se cuelga de la raíz)
	reparent.call_deferred(get_tree().root)

func _una(k: String, c: bool) -> bool:
	if c and not hecho.has(k):
		hecho[k] = true
		return true
	return false

func _key(k: int) -> void:
	for p in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = p
		Input.parse_input_event(ev)

func _process(dt: float) -> void:
	t += dt
	if _una("ir", t > 0.1):
		get_tree().change_scene_to_file("res://escenas/menu_principal.tscn")
		return
	var esc := get_tree().current_scene
	if esc == null or t < 0.5:
		return
	if _una("op", t > 2.5):
		esc._abrir(esc._opciones)
		print("MENU opciones abiertas")
	if _una("cerrar_op", t > 3.5):
		esc._volver()
	if _una("ctl", t > 4.0):
		esc._abrir(esc._controles)
	if _una("cerrar_ctl", t > 5.0):
		esc._volver()
	if _una("jugar", t > 5.5):
		esc._jugar()
	if _una("destino", t > 5.9):
		esc._destinos.get_child(1).pressed.emit()
	if _una("pausa", t > 8.5):
		_key(KEY_ESCAPE)
	if _una("pinfo", t > 9.0):
		print("MENU pausado=", get_tree().paused, " escena=", get_tree().current_scene.name)
	if _una("popc", t > 10.0):
		var mp: MenuPausa = get_tree().current_scene.get_node("Jugador/MenuPausa")
		mp._abrir_opciones()
	if _una("cont", t > 11.5):
		var mp2: MenuPausa = get_tree().current_scene.get_node("Jugador/MenuPausa")
		mp2._opciones._cerrar()
		mp2.continuar()
		print("MENU tras continuar pausado=", get_tree().paused)
	# pantalla de carga al pulsar Jugar
	if Engine.get_process_frames() % 10 == 0 and ((t > 5.5 and t < 8.5) or t > 15.0):
		var pc := get_tree().root.get_children().filter(func(n): return n is PantallaCarga)
		if not pc.is_empty():
			print("CARGA t=%.2f fase=%d esp=%d ms=%d progreso=%.2f escena=%s" % [t, pc[0]._fase, pc[0]._esperar, Time.get_ticks_msec() - pc[0]._t0, pc[0]._mostrado, get_tree().current_scene.name if get_tree().current_scene else "-"])
	# menú de trucos (F1)
	if _una("f1", t > 13.0):
		_key(KEY_F1)
	if _una("f1info", t > 13.5):
		var mt: MenuTrucos = get_tree().current_scene.get_node("Jugador/MenuTrucos")
		print("TRUCOS abierto=", mt.abierto(), " pausado=", get_tree().paused)
		mt._checks.invencible.button_pressed = true
		mt._checks.balas.button_pressed = true
		var j: Jugador = get_tree().current_scene.get_node("Jugador")
		print("TRUCOS invencible=", j.invencible, " balas=", j.arsenal.balas_infinitas)
	if _una("f1fin", t > 14.0):
		_key(KEY_ESCAPE)
	if _una("f1fin2", t > 14.5):
		var mt2: MenuTrucos = get_tree().current_scene.get_node("Jugador/MenuTrucos")
		print("TRUCOS tras Esc abierto=", mt2.abierto(), " pausado=", get_tree().paused)
	# volver al menú desde la pausa (con pantalla de carga)
	if _una("menu", t > 15.0):
		var mp3: MenuPausa = get_tree().current_scene.get_node("Jugador/MenuPausa")
		mp3.pausar()
		mp3._al_menu()
	if _una("menuinfo", t > 18.5):
		print("MENU vuelta escena=", get_tree().current_scene.name, " pausado=", get_tree().paused, " cargas=", get_tree().root.get_children().filter(func(n): return n is PantallaCarga).size())
	if t > 19.0:
		get_tree().quit()

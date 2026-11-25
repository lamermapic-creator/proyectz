extends SceneTree
## Navegación real con teclado, paneles, cinco tamaños y transición al nivel.
## --capturas=/ruta: guarda el viewport cuando hay un renderizador (no en headless).
var fallos := 0
var comprobaciones := 0
var destino := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			destino = arg.trim_prefix("--capturas=")
	probar.call_deferred()

func comprobar(ok: bool, texto: String) -> void:
	comprobaciones += 1
	if not ok:
		fallos += 1
		printerr("MAL menú: ", texto)

func esperar(frames: int) -> void:
	for i in frames:
		await process_frame

func tecla(codigo: int) -> void:
	for pressed in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = codigo
		evento.physical_keycode = codigo
		evento.pressed = pressed
		Input.parse_input_event(evento)
		await esperar(2)

func captura(nombre: String) -> void:
	if destino.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(destino)
	var error := root.get_texture().get_image().save_png(destino.path_join(nombre + ".png"))
	comprobar(error == OK, "guardar captura " + nombre)

func probar() -> void:
	# Las pruebas no dejan cambios en las preferencias guardadas del usuario.
	var tenia_config := FileAccess.file_exists(Opciones.RUTA)
	var config := FileAccess.get_file_as_bytes(Opciones.RUTA) if tenia_config else PackedByteArray()
	Opciones.cargar()
	Opciones.pantalla_completa = false
	Opciones.vsync = false
	Opciones.calidad = 0
	root.size = Vector2i(1280, 720)
	var menu = load("res://escenas/menu_principal.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await esperar(80)
	var jugar: Button = menu._botones.get_child(0)
	var opciones: Button = menu._botones.get_child(1)
	var controles: Button = menu._botones.get_child(2)
	comprobar(jugar.has_focus(), "foco inicial en Jugar")
	var mesa := menu.find_child("MesaMenu", true, false) as Node3D
	comprobar(mesa != null and mesa.has_node("Mesa") and mesa.has_node("RifleExpuesto"), "el menú muestra el arma sobre la mesa")
	if mesa != null:
		var casquillos := mesa.get_children().filter(func(n): return n is MeshInstance3D and n.mesh is CylinderMesh)
		var tablero := mesa.get_node("Mesa") as MeshInstance3D
		var superficie: float = (tablero.global_transform * tablero.get_aabb()).end.y
		comprobar(casquillos.size() == 3 and casquillos.all(func(n):
			var base: float = (n.global_transform * n.get_aabb()).position.y
			return absf(base - superficie) < 0.003 and absf(n.global_basis.y.y) < 0.001
		), "los tres casquillos están tumbados y apoyados en la mesa")

	var actores: Array[Node] = menu.find_children("*", "Node3D", true, false)
	comprobar(actores.all(func(n): return not (n is RigPersonaje or n is CharacterBody3D or n is NavigationRegion3D)), "la portada está libre de personajes y navegación")
	await captura("principal")
	await tecla(KEY_DOWN)
	comprobar(opciones.has_focus(), "flecha abajo selecciona Opciones")
	await tecla(KEY_ENTER)
	await esperar(19)
	comprobar(menu._opciones.is_visible_in_tree(), "Enter abre Opciones")
	comprobar(not menu._botones.is_visible_in_tree(), "el panel oculta las acciones")
	await captura("opciones")
	await tecla(KEY_ESCAPE)
	comprobar(menu._ventanas.visible and menu._opciones.visible and menu._cerrando, "Opciones sigue visible durante el fundido de salida")
	await esperar(20)
	comprobar(not menu._ventanas.visible and jugar.has_focus(), "Esc vuelve al menú y restaura el foco")
	await tecla(KEY_DOWN)
	await tecla(KEY_DOWN)
	comprobar(controles.has_focus(), "navegar a Controles")
	await tecla(KEY_ENTER)
	await esperar(19)
	comprobar(menu._controles.is_visible_in_tree(), "Enter abre Controles")
	await captura("controles")
	await tecla(KEY_ESCAPE)
	await esperar(20)
	comprobar(not menu._ventanas.visible and jugar.has_focus(), "cerrar Controles con Esc")
	for tam in [Vector2i(640, 360), Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = tam
		await esperar(4)
		var anterior := -1.0
		for b in menu._botones.get_children():
			# canvas_items mantiene una resolución lógica mínima; convertir a píxeles de ventana.
			var rect: Rect2 = root.get_final_transform() * b.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, b.size)
			comprobar(rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= tam.x + 1 and rect.end.y <= tam.y + 1, "botón dentro de %s: rect=%s viewport=%s escala=%s" % [tam, rect, root.get_visible_rect().size, menu._referencia.scale])
			comprobar(rect.position.y >= anterior, "filas sin solapar en " + str(tam))
			anterior = rect.end.y
		if tam == Vector2i(800, 600):
			await captura("principal_4_3")
	root.size = Vector2i(1280, 720)
	await esperar(4)
	jugar.grab_focus()
	await tecla(KEY_ENTER)
	comprobar(menu._destinos.is_visible_in_tree(), "Jugar abre el selector de destino")
	if "--barrio" in OS.get_cmdline_user_args():
		await tecla(KEY_DOWN)
	await tecla(KEY_ENTER)
	comprobar(menu._saliendo and jugar.disabled, "Elegir destino inicia una única transición")
	await tecla(KEY_ENTER)
	var limite := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < limite:
		if current_scene != menu and current_scene != null and current_scene.has_node("Jugador"):
			break
		await process_frame
		# En headless los FPS fijos avanzan más rápido que el hilo real de carga.
		OS.delay_msec(2)
	comprobar(current_scene != null and current_scene.scene_file_path == ("res://escenas/barrio_canal.tscn" if "--barrio" in OS.get_cmdline_user_args() else "res://escenas/pruebas_movimiento.tscn"), "Jugar llega al destino elegido")
	var cargas := root.get_children().filter(func(n): return n is PantallaCarga)
	comprobar(cargas.size() <= 1, "Enter repetido no duplica la carga")
	if tenia_config:
		var archivo := FileAccess.open(Opciones.RUTA, FileAccess.WRITE)
		archivo.store_buffer(config)
		archivo.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Opciones.RUTA))
	print("MENU_REDISENADO comprobaciones=%d fallos=%d" % [comprobaciones, fallos])
	quit(1 if fallos else 0)

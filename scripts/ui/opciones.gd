class_name Opciones
## Opciones del jugador (se guardan en user://opciones.cfg y se aplican al arrancar y al cambiarlas).

const RUTA := "user://opciones.cfg"
const CALIDADES := ["Baja", "Media", "Alta"]

static var sensibilidad := 1.0     # multiplicador del ratón (0.3 .. 2.5)
static var invertir_y := false
static var fov := 70.0             # campo de visión base (60 .. 90)
static var volumen := 0.8          # 0 .. 1
static var calidad := 2            # 0 baja, 1 media, 2 alta
static var pantalla_completa := true
static var vsync := true
static var _cargado := false


static func cargar() -> void:
	if _cargado:
		return
	_cargado = true
	if OS.has_feature("web"):
		calidad = 0
		pantalla_completa = false
	var cf := ConfigFile.new()
	if cf.load(RUTA) != OK:
		return
	sensibilidad = cf.get_value("control", "sensibilidad", sensibilidad)
	invertir_y = cf.get_value("control", "invertir_y", invertir_y)
	fov = cf.get_value("video", "fov", fov)
	volumen = cf.get_value("audio", "volumen", volumen)
	calidad = cf.get_value("video", "calidad", calidad)
	pantalla_completa = cf.get_value("video", "pantalla_completa", pantalla_completa)
	vsync = cf.get_value("video", "vsync", vsync)


static func guardar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("control", "sensibilidad", sensibilidad)
	cf.set_value("control", "invertir_y", invertir_y)
	cf.set_value("video", "fov", fov)
	cf.set_value("audio", "volumen", volumen)
	cf.set_value("video", "calidad", calidad)
	cf.set_value("video", "pantalla_completa", pantalla_completa)
	cf.set_value("video", "vsync", vsync)
	cf.save(RUTA)


## aplica todo (ventana, audio y calidad gráfica de la escena actual)
static func aplicar(arbol: SceneTree) -> void:
	cargar()
	# en el editor no se toca el modo de ventana (el juego va incrustado)
	if not OS.has_feature("editor") and not OS.has_feature("web"):
		var modo := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != modo:
			DisplayServer.window_set_mode(modo)
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volumen, 0.0001)))
	AudioServer.set_bus_mute(0, volumen <= 0.001)
	aplicar_calidad(arbol)


static func aplicar_calidad(arbol: SceneTree) -> void:
	var vp := arbol.root
	match calidad:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 0.75
		1:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 1.0
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][calidad] if OS.has_feature("web") else [2048, 4096, 8192][calidad], true)
	var escena := arbol.current_scene
	if escena == null:
		return
	for n in escena.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env:
			env.ssao_enabled = calidad >= 2
			env.glow_enabled = calidad >= 1
	for n in escena.find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		l.shadow_enabled = true
		l.directional_shadow_max_distance = [80.0, 150.0, 250.0][calidad]
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if calidad == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

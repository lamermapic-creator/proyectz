extends AudioStreamPlayer3D
## La distancia y la altura las calcula Godot en 3D. Los obstáculos añaden pérdida y filtrado.

var nivel_fuente_db := 0.0:
	set(valor):
		nivel_fuente_db = valor
		volume_db = valor - _perdida
var _perdida := 0.0
var _corte := 20500.0
var _espera := 0.0


func reproducir() -> void:
	if DisplayServer.get_name() != "headless":
		play()


func _physics_process(dt: float) -> void:
	if not playing or DisplayServer.get_name() == "headless":
		return
	_espera -= dt
	if _espera > 0.0:
		return
	var intervalo := 0.08
	_espera = intervalo
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var destino := camara.global_position
	var trayecto := destino - global_position
	var perdida := 0.0
	var corte := 20500.0
	if trayecto.length_squared() > 0.36:
		var q := PhysicsRayQueryParameters3D.create(global_position, destino, 1)
		var espacio := get_world_3d().direct_space_state
		for i in 6:
			var hit := espacio.intersect_ray(q)
			if hit.is_empty():
				break
			if hit.collider is StaticBody3D and not hit.collider is AnimatableBody3D:
				var suelo := absf((hit.normal as Vector3).y) > 0.55
				perdida = 16.0 if suelo else 11.0
				corte = 850.0 if suelo else 1450.0
				break
			var excluidos := q.exclude
			excluidos.append(hit.rid)
			q.exclude = excluidos
	_perdida = lerpf(_perdida, perdida, 0.6)
	_corte = lerpf(_corte, corte, 0.6)
	volume_db = nivel_fuente_db - _perdida
	attenuation_filter_cutoff_hz = _corte
	attenuation_filter_db = -18.0

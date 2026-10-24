extends Node
## Prueba: disparar a un zombi (o a un muñeco) pegado al jugador. --dist=<studs> --muneco
var j: Jugador
var t := 0.0
var obj: Node3D
var hp0 := -1.0
var dist := 2.5
var tiros := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dist="):
			dist = float(a.split("=")[1])
	j = get_parent().get_node("Jugador")
	j.global_position = Vector3(-100, 3.2, 100)
	j.yaw = 0.0
	Zombi.sordos = true

func _process(dt: float) -> void:
	t += dt
	if t > 0.2 and not has_meta("eq"):
		set_meta("eq", true)
		j.arsenal.select_slot(1 if OS.get_cmdline_user_args().has("--rifle") else 0)
		var pies := Vector3(-100, 0, 100 - dist - 0.0)
		if OS.get_cmdline_user_args().has("--muneco"):
			obj = Maniqui.new()
			get_parent().add_child(obj)
			obj.position = pies
		else:
			var dz = get_parent().get_node("Zombis")
			obj = dz.crear_zombi(pies, 0.0, false)
	if obj == null or t < 1.5:
		return
	j.aiming = true
	var tgt: Vector3 = (obj.rig.P.UpperTorso as Node3D).global_position
	var d := tgt - j.camara.global_position
	j.yaw = atan2(-d.x, -d.z)
	j.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	if t > 2.5 and hp0 < 0:
		hp0 = obj.health
		print("CERCA distancia real=%.2f alzada=%.2f" % [j.global_position.distance_to(obj.global_position), j.get_node("Animador").arma_alzada])
	if t > 2.5 and tiros < 3 and fmod(t, 0.4) < dt:
		j.arsenal.shoot()
		tiros += 1
	if t > 4.0:
		print("CERCA dist=%.1f vida %.0f -> %.0f : %s" % [dist, hp0, obj.health, "LE DIO" if obj.health < hp0 else "NO LE DIO"])
		get_tree().quit()

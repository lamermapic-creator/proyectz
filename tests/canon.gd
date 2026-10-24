extends Node
## Prueba: la bala sale del cañón. Muro bajo entre el arma y un muñeco, por debajo de la línea de la
## cámara y por encima de la del cañón: la mira ve al muñeco, pero la bala debe dar en el muro.
## --sin_muro: el mismo disparo sin muro (el muñeco debe recibir los disparos).
var j: Jugador
var t := 0.0
var m: Maniqui
var muro: StaticBody3D
var disparos := 0
var hp0 := 0.0
var sin_muro := false

func _ready() -> void:
	sin_muro = OS.get_cmdline_user_args().has("--sin_muro")
	j = get_parent().get_node("Jugador")
	j.global_position = Vector3(-100, 3.2, 100)
	j.yaw = 0.0
	j.estamina_infinita = true
	m = Maniqui.new()
	get_parent().add_child.call_deferred(m)
	m.position = Vector3(-99, 0, 70)

func _process(dt: float) -> void:
	if m.rig == null:
		return
	t += dt
	if t > 0.2 and j.arsenal.equipado == "" and not has_meta("eq"):
		set_meta("eq", true)
		j.arsenal.select_slot(1)
	if t > 1.5:
		j.aiming = true
		# la cámara apunta al pecho del muñeco
		var obj: Vector3 = (m.rig.P.UpperTorso as Node3D).global_position
		var cam := j.camara.global_transform
		var d := obj - cam.origin
		j.yaw = atan2(-d.x, -d.z)
		j.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	if t > 3.0 and muro == null and not sin_muro:
		var mz: Vector3 = (j.arsenal.modelo_mano.get_node("Muzzle") as Node3D).global_position
		var cam := j.camara.global_transform
		var obj: Vector3 = (m.rig.P.UpperTorso as Node3D).global_position
		var pw := mz.lerp(obj, 0.25)
		# altura de cada línea en ese punto
		var k_c := Vector2(pw.x - cam.origin.x, pw.z - cam.origin.z).length() / Vector2(obj.x - cam.origin.x, obj.z - cam.origin.z).length()
		var y_cam := lerpf(cam.origin.y, obj.y, k_c)
		var y_mz := pw.y
		var top := (y_cam + y_mz) * 0.5
		print("CANON y_cam=%.2f y_cañón=%.2f muro_top=%.2f" % [y_cam, y_mz, top])
		muro = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(6, top, 0.5)
		cs.shape = bs
		muro.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		muro.add_child(mi)
		get_parent().add_child(muro)
		muro.global_position = Vector3(pw.x, top * 0.5, pw.z)
	if t > 3.6 and disparos == 0:
		hp0 = m.health
	if t > 3.6 and disparos < 3 and fmod(t, 0.5) < dt:
		j.arsenal.shoot()
		disparos += 1
	if t > 5.5:
		print("CANON vida muñeco antes=%.0f después=%.0f -> %s" % [hp0, m.health, "LE DIO" if m.health < hp0 else "NO LE DIO"])
		get_tree().quit()

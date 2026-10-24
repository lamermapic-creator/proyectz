extends Node
## Prueba del menú de trucos: teletransporta a cada zona y comprueba que el jugador queda de pie en
## el suelo y sin piezas del cuerpo dentro de la geometría; prueba también las acciones.
var j: Jugador
var mt: MenuTrucos
var t := 0.0
var i := -1
var fallos := 0

func _ready() -> void:
	j = get_parent().get_node("Jugador")

func _process(dt: float) -> void:
	t += dt
	if mt == null:
		mt = j.get_node_or_null("MenuTrucos")
		return
	if t < 1.0:
		return
	if i == -1:
		i = 0
		_ir()
		return
	if t > 1.5 + (i + 1) * 1.6:
		_comprobar()
		i += 1
		if i >= MenuTrucos.ZONAS.size():
			_acciones()
			print("TRUCOS FIN fallos=%d" % fallos)
			get_tree().quit()
			return
		_ir()

func _ir() -> void:
	var z: Array = MenuTrucos.ZONAS[i]
	j.teletransportar(z[1] * MenuTrucos.M, deg_to_rad(z[2]))

func _comprobar() -> void:
	var z: Array = MenuTrucos.ZONAS[i]
	var space := j.get_world_3d().direct_space_state
	var dentro := []
	for n in j.rig.P:
		if n == "HumanoidRootPart":
			continue
		var q := PhysicsPointQueryParameters3D.new()
		q.position = (j.rig.P[n] as Node3D).global_position
		q.exclude = [j.get_rid()]
		if not space.intersect_point(q, 1).is_empty():
			dentro.append(n)
	var objetivo: Vector3 = z[1] * MenuTrucos.M
	var lejos := Vector2(j.global_position.x - objetivo.x, j.global_position.z - objetivo.z).length()
	var ok := j.en_suelo and dentro.is_empty() and lejos < 2.0
	if not ok:
		fallos += 1
	print("TRUCOS %s %s en_suelo=%s dentro=%s desvío=%.2f" % ["bien" if ok else "MAL ", z[0], j.en_suelo, dentro, lejos])

func _acciones() -> void:
	var n0: int = j.arsenal.suelo.size()
	mt._arma_al_suelo("Machete")
	print("TRUCOS arma al suelo: %d -> %d" % [n0, j.arsenal.suelo.size()])
	j.health = 30
	j.invencible = true
	j.recibir_danio(20)
	print("TRUCOS invencible: vida=%.0f (debe seguir en 30)" % j.health)
	mt._revivir_munecos()
	mt._zombi_delante()
	mt._municion_max()
	print("TRUCOS acciones sin errores")

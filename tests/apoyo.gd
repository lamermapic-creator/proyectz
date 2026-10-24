extends Node
## Prueba: ¿se puede apoyar el arma? (barrera 1 m, muro 1.1 m, mesa 0.8 m; de pie y agachado; tumbado)
var j: Jugador
var t := 0.0
var M := 1.0 / 0.31
var casos := []
var i := -1
var tc := 0.0

func _ready() -> void:
	j = get_parent().get_node("Jugador")
	# [nombre, pos (studs), yaw, postura, boca arriba]
	casos = [
		["barrera_pie", Vector3(26 * M - 1.4, 3.2, 0), -PI / 2, 0, false],
		["barrera_agachado", Vector3(26 * M - 1.4, 3.2, 0), -PI / 2, 1, false],
		["muro110_pie", Vector3(-2 * M, 3.2, 14 * M - 1.4), PI, 0, false],
		["muro110_agachado", Vector3(-2 * M, 3.2, 14 * M - 1.4), PI, 1, false],
		["mesa80_pie", Vector3(-6 * M, 3.2, 14 * M - 2.6), PI, 0, false],
		["mesa80_agachado", Vector3(-6 * M, 3.2, 14 * M - 2.6), PI, 1, false],
		["muro130_pie", Vector3(2 * M, 3.2, 14 * M - 1.4), PI, 0, false],
		["tumbado", Vector3(-100, 3.2, 100), 0.0, 2, false],
		["boca_arriba", Vector3(-100, 3.2, 100), 0.0, 2, true],
	]
	call_deferred("_sig")

func _sig() -> void:
	i += 1
	if i >= casos.size():
		get_tree().quit()
		return
	var c: Array = casos[i]
	j.set_stance(0)
	j.stance = c[3]
	j.prone_p = 1.0 if c[3] == 2 else 0.0
	j.supine = c[4]
	j.global_position = c[1]
	j.yaw = c[2]
	j.rotation.y = c[2]
	j.pitch = 0.0
	tc = 0.0
	if j.arsenal.equipado != "Rifle" and j.arsenal.switching == null:
		j.arsenal.select_slot(1)

func _process(dt: float) -> void:
	t += dt
	tc += dt
	if i < 0 or i >= casos.size():
		return
	var c: Array = casos[i]
	j.supine = c[4]
	if tc > 2.2:
		j.arsenal.set_rest(true)
		var r = j.arsenal.rest
		print("APOYO ", c[0], " -> ", "SI gap=%.2f" % r.gap if r != null else "NO (" + j._hud["aviso"].text + ")")
		j.arsenal.end_rest()
		_sig()

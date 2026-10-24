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
		["pared_lado_izq_pie", Vector3(0, 3.2, 62.6), PI / 2, 0, false],
		["pared_lado_der_pie", Vector3(0, 3.2, 62.6), -PI / 2, 0, false],
		["pared_lado_agachado", Vector3(0, 3.2, 62.6), PI / 2, 1, false],
		["campo_abierto", Vector3(-100, 3.2, 100), 0.0, 0, false],
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
	if tc > 2.2 and not has_meta("x%d" % i):
		set_meta("x%d" % i, true)
		j.arsenal.set_rest(true)
		var r = j.arsenal.rest
		print("APOYO ", c[0], " -> ", ("SI gap=%.2f%s" % [r.gap, " (de lado)" if r.get("lado", false) else ""]) if r != null else "NO (" + j._hud["aviso"].text + ")")
		if r == null:
			_sig()
	elif tc > 3.4:
		# apoyada y apuntando, el arma no se levanta (antes el muro de delante la levantaba)
		print("APOYO   %s arma_alzada=%.2f circulo=%s" % [c[0], j.get_node("Animador").arma_alzada, str(j.arsenal._hud.impacto.visible)])
		var sb: Array = j.arsenal.salida_bala()
		var forz: Dictionary = sb[2]
		var r2: Dictionary = forz if not forz.is_empty() else j.arsenal._rayo_bala(sb[3], sb[1], 300.0)
		var dist_imp: float = (r2.position as Vector3).distance_to(sb[0]) if not r2.is_empty() else 999.0
		print("APOYO   %s bala: forzada=%s impacto a %.1f studs del cañón%s" % [c[0], str(not forz.is_empty()), dist_imp, "  <-- MAL" if dist_imp < 3.0 else ""])
		j.arsenal.end_rest()
		_sig()

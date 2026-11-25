extends SceneTree
## Ejecutar con Godot --headless --fixed-fps 60 -s tests/inventario_mochila.gd

func _initialize() -> void:
	call_deferred("_probar")

func _esperar_mochila(a: Arsenal) -> void:
	for i in 160:
		await process_frame
		if a.cambio_mochila.is_empty():
			return
	assert(false)

func _probar() -> void:
	change_scene_to_file("res://escenas/pruebas_movimiento.tscn")
	await scene_changed
	for i in 20:
		await process_frame
	var j := current_scene.get_node("Jugador") as Jugador
	var a := j.arsenal
	assert(a.mochila.get_child_count() > 5)
	assert(a.mochila.get_parent() == j.rig.P.UpperTorso)
	assert(a.capacidad() == 5 and a.inventario.size() == 4)
	assert(a.anclaje_arma("Rifle").CF.origin.x > 0.4)
	assert(a.anclaje_arma("Bate").CF.origin.x < -0.4)
	a.dar_arma("Revolver", true, 4, 10)
	assert(a.inventario.size() == 5 and a.arma_en_hueco("Corta3") == "Revolver")
	assert(a.enfundadas.Revolver.get_parent() == j.rig.P.UpperTorso)
	assert(a.solicitar_mochila())
	await _esperar_mochila(a)
	assert(not a.mochila_puesta and a.capacidad() == 3 and a.inventario.size() == 3)
	assert(a.suelo.any(func(i): return i.name == "Bate"))
	assert(a.suelo.any(func(i): return i.name == "Revolver" and i.mag == 4 and i.reserve == 10))
	assert(a.arma_en_hueco("Corta2") == "Cuchillo")
	a.select_slot(2)
	assert(a.equipado == "Cuchillo")
	a.dar_arma("Machete", true)
	assert(a.inventario.size() == 3 and a.arma_en_hueco("Larga") == "Machete")
	assert(a.mochila.get_parent() == j.get_parent())
	assert(a.solicitar_mochila())
	await _esperar_mochila(a)
	assert(a.mochila_puesta and a.mochila.get_parent() == j.rig.P.UpperTorso)
	a.dar_arma("Rifle", true)
	a.dar_arma("Escopeta", true, 3, 8)
	assert(a.arma_en_hueco("BlancaLarga") == "Rifle")
	a.select_slot(1)
	assert(a.equipado == "Escopeta" and a.datos_equipado().mag == 3)
	a.inventario.erase("Corta2")
	a.dar_arma("Revolver", true)
	var muslo: Node3D = j.rig.P.LeftUpperLeg
	var funda := muslo.get_node("FundaIzquierda") as Node3D
	assert(a.enfundadas.Revolver.get_parent() == muslo)
	assert(funda.transform.is_equal_approx(a.enfundadas.Revolver.transform))
	a._equipar("Revolver")
	a.mostrar(true)
	assert(not a.enfundadas.Revolver.visible)
	assert(funda.visible)
	print("Mochila original, límites, anclajes, dejar y recoger, y munición verificados")
	quit()

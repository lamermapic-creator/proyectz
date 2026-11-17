extends SceneTree
func _initialize() -> void:
 probar.call_deferred()
func probar() -> void:
 var escena: Node = load("res://escenas/pruebas_movimiento.tscn").instantiate()
 root.add_child(escena)
 current_scene=escena
 var j := escena.get_node("Jugador") as Jugador
 j.invencible=true
 Zombi.ciegos=true
 Zombi.sordos=true
 j.teletransportar(Vector3(-100,3.2,100),0)
 var blanco := StaticBody3D.new()
 blanco.collision_layer=2
 var col := CollisionShape3D.new()
 var caja := BoxShape3D.new()
 caja.size=Vector3(10,12,0.2)
 col.shape=caja
 blanco.add_child(col)
 escena.add_child(blanco)
 var fallos := 0
 for arma in ["Rifle","Pistola","Escopeta"]:
  j.arsenal._equipar(arma)
  j.arsenal.switching=null
  j.arsenal.draw_until=-100
  j.aiming=true
  for distancia in [3.0,5.0,8.0]:
   blanco.global_position=Vector3(-100,3,100-distancia)
   var maximo := 0.0
   for i in 360:
    await physics_frame
    await process_frame
    if i>=300:
     var mz := j.arsenal.modelo_mano.get_node("Muzzle") as Node3D
     var d := j.arsenal.punto_mira()-mz.global_position
     maximo=maxf(maximo,rad_to_deg((-mz.global_basis.z).angle_to(d)))
   print("PRECISION_CERCA arma=",arma," distancia=",distancia," error_max=",maximo)
   if maximo>0.25: fallos+=1
   var salida := j.arsenal.salida_bala()
   var impacto := j.arsenal._rayo_bala(salida[3],salida[1],30.0)
   if impacto.get("collider") != blanco: fallos+=1
 print("PRECISION_CERCA fallos=",fallos)
 quit(fallos)

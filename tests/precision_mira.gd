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
 var fallos := 0
 for arma in ["Rifle","Pistola","Escopeta"]:
  j.arsenal._equipar(arma)
  j.arsenal.switching=null
  j.arsenal.draw_until=-100
  j.aiming=true
  var maximo := 0.0
  for i in 360:
   await physics_frame
   await process_frame
   if i>=300:
    var mz := j.arsenal.modelo_mano.get_node("Muzzle") as Node3D
    var d := j.arsenal.punto_mira()-mz.global_position
    maximo=maxf(maximo,rad_to_deg((-mz.global_basis.z).angle_to(d)))
  print("PRECISION arma=",arma," error_max=",maximo)
  if maximo>0.25: fallos+=1
 print("PRECISION_MIRA fallos=",fallos)
 quit(fallos)

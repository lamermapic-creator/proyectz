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
 for arma in ["Pistola","Revolver","Subfusil","Rifle","Escopeta","Francotirador"]:
  j.arsenal._equipar(arma)
  j.arsenal.switching=null
  j.arsenal.draw_until=-100
  j.aiming=true
  for i in 300:
   await physics_frame
   await process_frame
  var modelo := j.arsenal.modelo_mano
  var derecha: Node3D=j.rig.P.RightHand
  var union_mano := derecha.global_transform*Armas.grip_att()
  var union_arma := modelo.global_transform*Armas.grip(arma)
  var error_d:=union_mano.origin.distance_to(union_arma.origin)
  var error_i:=0.0
  var giro_i:=0.0
  var apoyo := modelo.find_child("LeftGrip",true,false) as Node3D
  if apoyo==null: apoyo=modelo.find_child("SupportGrip",true,false) as Node3D
  if Armas.WEAPONS[arma].get("Slot", "") == "Larga" and apoyo!=null:
   var izquierda: Node3D=j.rig.P.LeftHand
   error_i=(izquierda.global_transform*Armas.grip_att()).origin.distance_to(apoyo.global_position)
   giro_i=(izquierda.global_basis*Armas.grip_att().basis).get_rotation_quaternion().angle_to(modelo.global_basis.get_rotation_quaternion())
  print("AGARRE arma=",arma," derecha=",error_d," izquierda=",error_i)
  if error_d>0.01 or error_i>0.1 or giro_i>deg_to_rad(2): fallos+=1
 print("AGARRE_ARMAS fallos=",fallos)
 quit(fallos)

extends SceneTree
func _initialize() -> void:
 probar.call_deferred()
func probar() -> void:
 var mundo := Node3D.new()
 root.add_child(mundo)
 current_scene = mundo
 var j := load("res://escenas/jugador.tscn").instantiate() as Jugador
 mundo.add_child(j)
 await physics_frame
 await process_frame
 await physics_frame
 await process_frame
 j.set_process(false)
 j.set_physics_process(false)
 j.arsenal._equipar("Pistola")
 var a := j.arsenal
 var fallos := 0
 for alzada in [0.0,1.0]:
  a.anim.arma_alzada = alzada
  for angulo in [-90.0,-60.0,60.0,90.0]:
   a.modelo_mano.global_rotation = Vector3(0,deg_to_rad(angulo),0)
   var boca := a.modelo_mano.get_node("Muzzle") as Node3D
   var real := -boca.global_basis.z.normalized()
   var salida := a.salida_bala()
   if (salida[1] as Vector3).angle_to(real)>0.0001: fallos+=1
   if (salida[0] as Vector3).distance_to(boca.global_position)>0.0001: fallos+=1
   if ((salida[0] as Vector3)-(salida[3] as Vector3)).cross(real).length()>0.0001: fallos+=1
 var modelo := a.modelo_mano
 a.modelo_mano = null
 a.draw_until = -100
 a.last_shot = -100
 a.switching = null
 j.reloj = 10.0
 var municion := int(a.datos_equipado().mag)
 a.shoot()
 if int(a.datos_equipado().mag)!=municion: fallos+=1
 a.modelo_mano = modelo
 print("SALIDA_CANON comprobaciones=25 fallos=",fallos)
 mundo.queue_free()
 await process_frame
 quit(fallos)

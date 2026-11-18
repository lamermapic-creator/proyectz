extends SceneTree
func _initialize() -> void:
 probar.call_deferred()
func tecla(k: int,p: bool) -> void:
 var e:=InputEventKey.new()
 e.physical_keycode=k
 e.pressed=p
 Input.parse_input_event(e)
 Input.flush_buffered_events()
func frames(n: int) -> void:
 for i in n:
  await physics_frame
  await process_frame
func probar() -> void:
 var escena: Node=load("res://escenas/pruebas_movimiento.tscn").instantiate()
 root.add_child(escena)
 current_scene=escena
 var j:=escena.get_node("Jugador") as Jugador
 j.invencible=true
 j.estamina_infinita=true
 Zombi.ciegos=true
 Zombi.sordos=true
 j.teletransportar(Vector3(-100,3.2,100),0)
 await frames(60)
 j.set_stance(2)
 await frames(100)
 var estaba_tumbado: bool=j.stance==2 and j.prone_p>0.98
 var con_techo := OS.get_cmdline_user_args().has("--techo")
 if con_techo:
  var techo := StaticBody3D.new()
  var col := CollisionShape3D.new()
  var caja := BoxShape3D.new()
  caja.size=Vector3(40,0.3,40)
  col.shape=caja
  techo.add_child(col)
  escena.add_child(techo)
  techo.global_position=Vector3(j.global_position.x,j.global_position.y-j.center_cur+2.4,j.global_position.z)
  await frames(3)
  print("TECHO headroom=",j.headroom(5.6)," postura=",j.stance)
 tecla(KEY_W,true)
 tecla(KEY_SHIFT,true)
 await frames(75)
 var ok: bool=j.stance==2 if con_techo else j.stance==0 and j.prone_p<0.01 and j.L.sprinting and Rbx.flat(j.vel_real).length()>ZConfig.PLAYER.WalkSpeed
 ok = ok and estaba_tumbado
 print("LEVANTARSE_CORRIENDO techo=",con_techo," ok=",ok," postura=",j.stance," velocidad=",Rbx.flat(j.vel_real).length())
 tecla(KEY_W,false)
 tecla(KEY_SHIFT,false)
 quit(0 if ok else 1)

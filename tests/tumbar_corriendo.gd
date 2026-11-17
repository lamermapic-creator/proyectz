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
 tecla(KEY_W,true)
 tecla(KEY_SHIFT,true)
 await frames(90)
 var corria: bool=j.L.sprinting
 var p:=j.global_position
 var con_pared := OS.get_cmdline_user_args().has("--pared")
 var z_pared := p.z-1.5
 if con_pared:
  var pared := StaticBody3D.new()
  var col := CollisionShape3D.new()
  var caja := BoxShape3D.new()
  caja.size=Vector3(8,8,0.3)
  col.shape=caja
  pared.add_child(col)
  escena.add_child(pared)
  pared.global_position=Vector3(p.x,4,z_pared)
 j.set_stance(2)
 tecla(KEY_W,false)
 tecla(KEY_SHIFT,false)
 await frames(27)
 var d:=Rbx.flat(j.global_position-p).length()
 var ok: bool=corria and j.stance==2 and j.prone_p>0.98 and (d>0.3 or con_pared) and d<5.0 and j.ragdoll==null
 if con_pared: ok = ok and j.global_position.z >= z_pared+0.15
 print("TUMBAR_CORRIENDO rapido=",ok," avance=",d," postura=",j.prone_p)
 quit(0 if ok else 1)

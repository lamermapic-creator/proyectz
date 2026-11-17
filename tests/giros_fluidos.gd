extends SceneTree
func _initialize() -> void:
 var fallos := 0
 for fps in [30,60,120]:
  var j := Jugador.new()
  var dt: float = 1.0/fps
  var maximo := 0.0
  var aceleracion := 0.0
  var anterior := 0.0
  for i in fps*4:
   var objetivo := PI/2 if i<fps*2 else -PI/2
   var antes := j.rotation.y
   j._girar_cuerpo_hacia(objetivo,dt,6.0)
   var v: float = Rbx.wrap_a(j.rotation.y-antes)/dt
   maximo = maxf(maximo,absf(v))
   aceleracion = maxf(aceleracion,absf(v-anterior)/dt)
   anterior = v
  var error := absf(Rbx.wrap_a(j.rotation.y+PI/2))
  print("GIRO fps=",fps," error=",rad_to_deg(error)," vmax=",rad_to_deg(maximo)," amax=",rad_to_deg(aceleracion))
  if error>deg_to_rad(2) or maximo>deg_to_rad(301) or aceleracion>deg_to_rad(1210): fallos+=1
  j.free()
 print("GIRO_Fluido fallos=",fallos)
 quit(fallos)

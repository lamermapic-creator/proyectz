extends SceneTree
## Regresión: zancadas acotadas delante y detrás, sin picos en el vuelo del pie.
func _initialize() -> void:
 var a := Animador.new()
 a.hip_x = 0.5
 a.feet = {"L":{"side":-1.0},"R":{"side":1.0}}
 var fallos := 0
 var salto_max := 0.0
 for z in [-20.0,-5.0,-1.0,0.0,1.0,5.0,20.0]:
  for k in ["L","R"]:
   var p := a._tobillo_anim(k,z,Vector3.FORWARD,0.0,0.0)
   if absf(p.z)>1.401: fallos+=1
 for mezcla in [0.0,0.5,1.0]:
  var previo := Vector2.ZERO
  for i in 101:
   var p := a._pierna_anim(true,i/100.0,5.0,0.4,mezcla,14.0)
   var actual := Vector2(p[0],p[1])
   if i>0: salto_max=maxf(salto_max,actual.distance_to(previo))
   previo=actual
 if salto_max>0.2: fallos+=1
 print("PASOS_SUAVES salto_muestra=%.3f fallos=%d"%[salto_max,fallos])
 a.free()
 quit(fallos)

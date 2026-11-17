extends SceneTree
## Giros bruscos: anticipación acotada para rifle, sin cambiar la libertad de arma corta.
func _initialize() -> void:
 var fallos := 0
 for grados in [-180,-90,-30,-8,0,8,30,90,180]:
  var a := deg_to_rad(float(grados))
  var larga := Animador._limitar_anticipacion_arma(a,true)
  var corta := Animador._limitar_anticipacion_arma(a,false)
  if absf(larga)>deg_to_rad(8.001): fallos+=1
  if absf(Rbx.wrap_a(corta-a))>0.0001: fallos+=1
 print("ANTICIPACION_ARMA comprobaciones=18 fallos=",fallos)
 quit(fallos)

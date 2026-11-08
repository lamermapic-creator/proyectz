# Animaciones hechas en Blender (Proyecto Z)

Godot NO importa esta carpeta (`.gdignore`). Aquí están el piloto montado en Blender y los scripts que generan las
poses de apuntado con la pistola en la moto. Blender 4.2 LTS (gratis, https://www.blender.org).

## Qué hay
- `piloto.blend`: el superviviente (esqueleto R15 con todas sus piezas) sentado en la moto, con la pose de conducir
  del juego. Acción `Apuntado_barrido`: abre el archivo y dale a Play para ver las poses (la mira da la vuelta).
- `rig_moto.json`: el piloto y la moto exportados desde el juego (`tests/moto.gd --modo=exportar --salida=...`).
- `montar.py`: monta `piloto.blend` a partir de `rig_moto.json` (armadura, piezas, moto, pose de conducir).
- `poses.py`: **el diseño de las poses** (cintura, cuello y brazo derecho para cada dirección y cabeceo, y la pose
  "recogida" del paso por delante del pecho). Es lo que hay que tocar para cambiar cómo apunta.
- `exportar.py` → `moto_apuntado.json` → `a_gd.py` → `scripts/jugador/poses_moto.gd` (lo que lee el juego).
- `ver3.py` + `hoja2.py`: renders de poses sueltas para revisarlas; `accion.py`: rehace la acción de ejemplo;
  `video_accion.py`: vídeo de la acción (Workbench).

## Rehacer las poses después de cambiar `poses.py`
```
blender -b piloto.blend -P exportar.py -- moto_apuntado.json
python3 a_gd.py moto_apuntado.json ../../scripts/jugador/poses_moto.gd
```
Ver unas poses (a = ángulo en rad, + izquierda; p = cabeceo; 99,x = pose recogida):
```
blender -b piloto.blend -P ver3.py -- "0,0;1.6,0;-3.1,0" "999,0.3,7;60,0.25,8" prueba
python3 hoja2.py prueba 3 2 "0,0;1.6,0;-3.1,0"   (hoja en renders/)
```
Si cambia el muñeco o la moto en el juego: volver a exportar `rig_moto.json` y `blender -b -P montar.py -- rig_moto.json piloto.blend`.

## Cómo se usan en el juego
`Animador._pose_moto`: mezcla las poses de la rejilla (ángulo x cabeceo) según hacia dónde apunta la mira (con
muelles de velocidad limitada) y aplica las rotaciones a la cintura, el cuello y el brazo derecho; la muñeca lleva una
pequeña corrección para que el cañón vaya exacto a la mira. Al cruzar por detrás a la izquierda, curva suave
pose actual → pose recogida → pose final.

## Posturas de pie con armas de fuego (2026-11-01)
- `pie_Rifle.blend` / `pie_Pistola.blend` (de `pie_*.json`, exportados con `tests/moto.gd --modo=exportar_pie --arma=Rifle|Pistola`).
- `poses_pie.py`: coloca el cuerpo y los brazos (IK de dos huesos, igual que el juego) para una postura.
- `diseno_pie.py`: **el diseño** (`NUEVO`): por arma base y estado (LOW, HIP, AIM, SPRINT) el giro del pecho (blade),
  la inclinación, la cabeza y hacia dónde van los codos. `viejo()` reproduce las posturas de antes, para comparar.
- Ver: `blender -b pie_Rifle.blend -P ver_pie.py -- Rifle nuevo "AIM,0;LOW,0" "-40,0.1,6.5;-95,0.05,6.5" prueba`
- Pasar al juego: `python3 a_gd_pie.py diseno_pie.py ../../scripts/jugador/posturas_pie.gd` (`PosturasPie`).

## El superviviente (modelo del personaje, 2026-11-01)
- `personaje/personaje.py`: **el modelo entero, pieza a pieza** (~200 piezas biseladas, estilo muñeco cuadrado R15):
  gorro de lana, barba, pañuelo, chaqueta, chaleco porta-placas con portacargadores, radio y vaina del cuchillo,
  guantes con dedos, cinturón con bolsas, pantalón de carga con rodilleras, funda de la pistola en el muslo derecho,
  botas con cordones y mochila con esterilla y botella. Todo en coordenadas de Godot (studs, posición de reposo).
  Cada pieza del R15 es un vacío con su nombre; al exportar las mallas se juntan por pieza y material.
- Exportar al juego (Godot lo importa solo):
```
blender -b -P personaje.py -- --nuevo --glb=../../../modelos/superviviente.glb
```
- Renders para revisar (5 vistas): `blender -b -P personaje.py -- --nuevo --render=prueba` (`--viejo` = el muñeco
  de antes, leído de `rig_personaje.gd`, para comparar). `--blend=x.blend` guarda el archivo para abrirlo en Blender.
- En el juego: `RigPersonaje.modelo = "superviviente"` (el jugador y el menú). Las piezas, sus tamaños (cajas de
  impacto) y el ragdoll no cambian. Los zombis siguen con el muñeco clásico (lo tiñen ellos).
- Si se mueve el equipo, respetar dónde van las armas enfundadas (`Armas.holster`): pistola en el muslo derecho,
  cuchillo en el pecho a la izquierda, rifle a la espalda detrás de la mochila (z ≈ 0,97), bate/machete en la mochila.

## Movimiento del superviviente: andar, correr, agachado, saltar, tumbarse, reptar, vallas y trepar (2026-11-02)
- `movimiento/diseno_mov.py`: **el diseño** (claves de animación, sin bpy):
  - Ciclos de la marcha (`ANDAR`, `CORRER`, `AGACHADO`) por la fase de la marcha φ (0 = pie izquierdo pasando,
    0,25 = apoya el izquierdo...): pelvis (sube/baja, se desplaza sobre el pie de apoyo, gira y cae del lado de la
    pierna en el aire), torso (hombros al revés que la cadera), cabeza estable, brazos (con retraso y el codo que
    acompaña) y la forma del paso (altura del pie, avance, giro sobre la punta/el talón, talón al glúteo corriendo).
  - `SALTO` (parado / corriendo) por la fase del salto; `TUMBAR` por pb y `REPTAR` por la fase de reptar;
    `SORTEAR` (vallas y encaramarse) por el progreso; `COLGADO`; `LEVANTAR` (boca abajo / boca arriba).
  - `RITMO`: zancada según la velocidad y fracción del ciclo en el aire: marca cuándo despega y apoya cada pie
    (los pasos siempre alternan).
  - `PIERNAS` (2026-11-03): **la animación de las piernas** (andar, correr, agachado). Cada pie respecto a la cadera:
    en el apoyo va hacia atrás en línea recta a la velocidad del cuerpo; en el aire vuelve con las curvas `avance`,
    `alto` e `inclina_aire` (más la velocidad de despegue, sin tirones; `retrae` = cuánto "araña" hacia atrás antes
    de apoyar); `delante` = dónde apoya; `inclina_apoyo` = talón al apoyar y punta al despegar; `estrecha` = pisar
    hacia el centro. `pierna(tipo, lado, φ, v)` es exactamente lo que hace el juego (`Animador._pierna_anim`).
  - `BOCA_ARRIBA` (2026-11-03): moverse tumbado boca arriba (pasito de cada pie, puente de cadera, hombros).
- Ver en Blender (sobre el personaje montado desde el juego: `tests/moto.gd --modo=exportar_pie --arma=ninguna
  --salida=cuerpo.json` y `blender -b -P montar.py -- cuerpo.json cuerpo.blend`):
  `blender -b cuerpo.blend -P movimiento/ver_mov.py -- andar 6.5 1.0 24 "0,0.15,9;60,0.15,9" prueba` (cuerpo y
  piernas animadas; en Blender la cadera no baja, en el juego sí cuando la pierna no llega) y
  `blender -b cuerpo.blend -P movimiento/ver_tierra.py -- "t:0,0.3,0.5,0.7,1" "90,0.12,10" prueba --ik`
  (este último imprime cuánto se meten en el suelo los pies, las rodillas y las manos).
- Al juego: `python3 movimiento/a_gd_mov.py ../../scripts/jugador/movimientos.gd` (`Movimientos`, generado: no
  editar a mano). Lo usa el Animador: `_ciclo`, `_brazo_ciclo`, `_curva_pie`, el salto (`air_tj`), las piernas al
  tumbarse (IK a sitios del suelo) y las curvas de vallas/trepar. En marcha, las piernas son la animación `PIERNAS`
  (`_marcha_animada`); parado, los pies quedan anclados y dan pasitos de ajuste.
- Medir: `tests/visual.gd --registro=x.csv` + `python3 tests/fluidez.py x.csv` (tirón del cuerpo y de los pies) y
  `--contactos` (cuánto se mete cada pieza en el suelo).

## Combate cuerpo a cuerpo (2026-11-08): guardia, bloqueo, empujón y patada
- `combate/diseno_cc.py`: **el diseño** (sin bpy). Poses fijas `GUARDIA` (manos, corta, larga) y `BLOQUEO` (y para
  armas de fuego), y acciones por claves `EMPUJON` (por clase, con variantes), `PATADA` (frontal derecha e izquierda, alta, baja),
  `GOLPES` (golpes nuevos de cuchillo, machete y bate) y `PUNOS` (directo, cruzado, gancho, gancho de abajo). Canales: manos y arma respecto al pecho, giro del tronco, cadera, y la pierna que patea respecto a
  su cadera (ver la cabecera del archivo).
- Ver en Blender (sobre el superviviente sin arma, `cuerpo.blend`, ver "Movimiento" arriba):
  `blender -b cuerpo.blend -P combate/ver_cc.py -- "guardia:manos;bloqueo:manos;empujon:manos:0:0.24,0.44;patada:0:0.28,0.42" "90,0.1,10" renders/cc`
  (las poses con arma se ven en el juego: `tests/combate.gd --cc=todo --arma=Bate --video` con `--write-movie`).
- Pasar al juego: `python3 combate/a_gd_cc.py ../../scripts/jugador/combate_cc.gd` (`CombateCC`; lo usa `Animador._paso_cc`).

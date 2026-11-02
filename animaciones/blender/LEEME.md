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

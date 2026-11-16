# Colección de zombis — 2026-11-16

Doce variantes originales creadas localmente con Blender 4.3.2, para el estilo segmentado R15 de Proyecto Z.
No son esculturas fotorrealistas: siguen las proporciones del superviviente y añaden detalle geométrico,
materiales, caras hundidas, dientes, dedos, cicatrices, roturas, costuras, bolsillos y equipo por profesión.
No hay descargas de terceros, créditos de generación ni servicios de pago. Se conservan las condiciones
de uso del proyecto; esta incorporación no concede una licencia distinta sobre el repositorio.

## Catálogo

| Id | Aspecto particular |
| --- | --- |
| civil | Camisa, botones, pelo y pantalón con bolsillos |
| sanitario | Uniforme verde, identificación, bolígrafo y mascarilla caída |
| obrero | Casco amarillo y bandas reflectantes |
| mecanico | Ropa de trabajo azul, costuras y roturas |
| policia | Chaleco, placa y portacargadores |
| bombero | Casco rojo, ropa ocre y bandas reflectantes |
| excursionista | Mochila y correas |
| oficinista | Cuello de camisa y corbata torcida |
| repartidor | Gorra con visera y mochila |
| paciente | Bata estampada y pulsera |
| granjero | Peto y tirantes |
| vagabundo | Capucha y bufanda |

`modelos/zombis/catalogo.json` registra los hashes SHA-256, tamaños e identidad de los GLB.
Cada modelo tiene 15 mallas segmentadas, materiales PBR sin texturas externas y entre 5.632 y 6.148
triángulos. Una malla puede tener varias superficies/materiales: 15 mallas **no** significa 15 llamadas
de dibujo. La colección ocupa aproximadamente 4,6 MB en GLB; no se ha medido rendimiento de hordas
en GPU. El equipo y la ropa no amplían las cajas de impacto.

## Abrir y probar

Abrir `escenas/galeria_zombis.tscn` en Godot 4.7.2 y ejecutar esa escena (F6). Flechas izquierda/derecha:
animación; espacio: pausa; arrastrar con botón izquierdo: órbita; rueda: distancia. Muestra los doce GLB
con sus animaciones exportadas. Esta escena es una vitrina, sin navegación ni IA.

En el juego, `Zombi.variante_visual` admite `aleatorio` (predeterminado), un id de la tabla, o `""`
para el aspecto clásico. El director existente crea variantes automáticamente. Para forzar una variante,
asignar la propiedad **antes de añadir el zombi al árbol**. Las instancias comparten recursos importados.

## Animaciones y compatibilidad

Los doce GLB incluyen el mismo conjunto de seis clips, a 24 FPS, animados mediante pivotes Motor6D:
reposo (3 s), caminar (2 s), perseguir (1,17 s), atacar (1,33 s), herido (0,92 s), morir (2 s).
Hay anticipación y recuperación en el ataque, balanceo del tronco, cabeza ladeada y marcha asimétrica.
No son 72 coreografías distintas: seis movimientos compartidos entre doce aspectos.

Los archivos `.blend` contienen los clips en pistas NLA con los mismos nombres. Al abrirlos está visible
`reposo`; para editar otro clip, desactivar esa pista y activar la deseada en el editor NLA. La vitrina
repite incluso los clips de acción única para facilitar su revisión.

**En los zombis con IA se usan las nuevas mallas y se conserva la animación procedural existente.**
`RigPersonaje` traslada las mallas a sus piezas y no conserva el AnimationPlayer importado. Así los
golpes siguen sincronizados con `PreparaGolpe` y la muerte/derribo siguen usando el ragdoll físico.
Las animaciones nuevas están disponibles en Blender y en la vitrina; sustituir el controlador de combate
por estos clips requeriría otro trabajo de sincronización, mezcla y contacto con el suelo. La caída
artística de `morir` es solo de muestra; no reemplaza el ragdoll. No hay animación facial ni skinning
continuo: articulación rígida por segmentos, igual que el personaje actual.

## Fuentes y regeneración

Desde la raíz del repositorio:

```bash
blender -b -t 4 -P animaciones/blender/zombis/generar.py
blender -b -t 4 -P animaciones/blender/zombis/render_catalogo.py
```

El primer comando sobrescribe los doce `.blend`, los doce `.glb` y `catalogo.json`. Los cambios artísticos
deben llevarse a `generar.py` antes de regenerar, o guardarse en otra fuente para no perder ediciones
manuales. El generador reutiliza las dimensiones y primitivas de `personaje/personaje.py` y lee C0/C1
de `RigPersonaje.MOTORES`; si se cambia el rig, regenerar y repetir las pruebas.
`render_catalogo.py` lee las fuentes y escribe `catalogo.png`. Blender usa CPU; no requiere GPU.

No se modifican `movimientos.gd`, `poses_moto.gd`, `posturas_pie.gd` ni `combate_cc.gd`.
La geometría y la actuación nuevas se editan en las fuentes de Blender de esta colección.

## Verificación

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/modelos_zombis.gd
tests/ejecutar_pruebas.sh /ruta/a/Godot_4.7.2
```

Usar el binario 4.7.2, no el `godot` 4.6.3 del PATH de la máquina de onboarding. En la nube, exportar
`XDG_CACHE_HOME=/workspace/.cache`, `XDG_CONFIG_HOME=/workspace/.config` y
`XDG_DATA_HOME=/workspace/.local/share` antes de ejecutar.

La prueba específica ejecuta 576 comprobaciones: doce importaciones reales, seis clips por modelo
con movimiento, 15 piezas y sus tamaños, selección de variante, daño, derribo y muerte. La galería
también se ejecutó sin ventana. El render de catálogo revisa la geometría en Blender; no acredita
calidad visual ni rendimiento del renderizador Forward+ de Godot en una GPU.

Resultado de esta entrega: **576/576** comprobaciones específicas y catálogo de bytes/hashes correcto.
La batería general terminó con **101/102 OK**; falló únicamente `moto_zombi` (no atropella al zombi),
intermitencia ya registrada en `CLAUDE.md`. Su repetición aislada pasó (`atropellos=1`). No se oculta
el fallo de la batería original. Las pruebas de combate, suelo, ragdoll, menú y nivel pasaron.
La prueba existente de CPU midió 1,19 ms/fotograma sin zombis y 3,34 ms con 30 (~0,072 ms por zombi)
en modo headless; ese dato no incluye el coste de dibujar las nuevas mallas en GPU.
Persisten avisos `ObjectDB ... leaked at exit` ya observados durante el onboarding.
Registros locales: `/workspace/setup-logs/zombis-modelos-test.log`, `zombis-regresion.log`,
`zombis-moto-repeticion.log` y `zombis-galeria.log`.

Vistas entregadas: `animaciones/blender/zombis/catalogo.png` y `caminar.gif` (12 fotogramas con poses
distintas). Para rehacer el GIF: ejecutar `render_animacion.py` con Blender y montar los 12 PNG de
`/tmp/zombis-preview` a 167 ms por fotograma con Pillow o un editor de imágenes. El GIF ilustra la
marcha del sanitario; los otros cinco clips y las doce variantes se revisan en la galería.

> Dirección vigente: [v7, bloques limpios sin repliegues](MODELOS_LIMPIOS_V7.md).

> Dirección vigente: [v6, todas las piezas cuadradas](CORRECCION_CUADRADA_V6.md).

> Revisión visual vigente: [v5](REVISION_VISUAL_V5.md). Conserva el estilo cuadrado de v4, contratos y flujo.

# Colección de zombis — 2026-11-16

## Revisión vigente: v4, sangre y tres cráneos abiertos

Se mantiene el arte cuadrado aprobado en v3 y se añade deterioro sanguinario solicitado por el usuario:
sangre seca y reciente alrededor de boca/barbilla, salpicaduras en cara, cortes, coágulos y manchas de
arrastre en ropa, antebrazos, manos y pantalones. Las cuencas negras exageradas no vuelven.

Solo **civil, sanitario y paciente** tienen cerebro visible. El generador corta de verdad frente y parte
superior del cráneo (también el pelo) mediante Boolean; comprueba mediante un rayo que la superficie
frontal haya desaparecido en la abertura. La corteza está dentro, con pliegues continuos y vasos, hueso
y un borde ensangrentado. No es un dibujo de cerebro pegado sobre una cabeza cerrada.

El aspecto es estático al crear el zombi: no es un sistema nuevo de desmembramiento ni heridas por
impacto. Todo sigue unido a las 15 piezas R15, con sus clips y el ragdoll actuales. Las cajas de impacto
siguen completas: la abertura visual no cambia qué disparos pueden acertar a la cabeza.

`deterioro.py` es la fuente del diseño. `rostro.py` la usa para pintar la piel y `refinado.py` para
proyectar manchas sobre las prendas y construir las heridas. Se usan dos imágenes originales de
512×512 por modelo: piel y manchas RGBA. Ambas están embebidas en GLB/Blender; la ropa emplea
transparencia para evitar rectángulos de color. No requiere servicios ni material de terceros.

El catálogo v4 registra `cerebro_visible` por modelo. `validar.py` comprueba que sean exactamente esas
tres variantes, que sus materiales de corteza estén presentes solo en ellas, y que existan las dos
imágenes embebidas, UV y materiales de sangre con alfa. Se mantiene el techo de 16.000 triángulos.
El coste de transparencias en hordas debe medirse en GPU; los renders de revisión son de Blender CPU.
Los archivos v4 tienen 12.360–15.144 triángulos. La pintura de sangre se mantiene separada de las
zonas de ojos para respetar la corrección de cuencas exageradas. Los coágulos usan otro material,
con rugosidad baja frente al acabado mate de sangre seca. No se añade ningún cambio de daño o IA.

Validación v4: **612/612** comprobaciones específicas y **102/102** pruebas generales correctas
(`TODO BIEN`). Importación y galería sin errores; selección de las tres variantes con cerebro,
texturas/alfa, UV, hashes y presupuesto verificados. Renders de catálogo, detalle y marcha revisados.
Registros locales: `/workspace/setup-logs/zombis-v4-test.log`, `zombis-v4-regresion.log`,
`zombis-v4-validacion.log` y `zombis-v4-import.log`.

## Base artística v3, conservada en v4

El usuario rechazó las cuencas negras exageradas y el aspecto redondeado de la revisión v2.
La dirección vigente es **cuadrada**, como el superviviente R15: cabeza de caja biselada, planos claros
y relieves faciales discretos. El realismo se busca en las proporciones, los detalles de piel y la
expresión contenida, manteniendo el estilo del juego.

Se retiraron las manchas oscuras alrededor de los ojos, ojos saltones, pómulos y cejas gruesos y boca
negra abierta. Los ojos ahora son estrechos y cercanos a la piel, con párpados finos, iris pequeño y
variantes de opacidad. Nariz, labios y marcas de infección tienen poco relieve. El pelo recupera
formas cuadradas y los cuerpos usan sección cuadrada y caras planas, conservando prendas y equipo.

`rostro.py` genera el relieve sobre la cara y una textura original de piel de **512×512** por modelo,
con variación no periódica suave, poros y pequeños pliegues. Está embebida en GLB y `.blend`, con sus
coordenadas UV. No hay imágenes de terceros, claves, servicios de pago ni archivos externos necesarios.
`validar.py` comprueba que haya una única imagen PNG embebida de esa resolución y UV en las superficies
que la usan, además de geometría, clips y hashes. El presupuesto máximo sigue siendo 16.000 triángulos.
La colección v3 tiene 11.898–12.766 triángulos por modelo y unos 9,2 MB de GLB en total.
Los `.glb.import` usan `gltf/embedded_image_handling=3` (Embed as Uncompressed, Godot 4.7.2),
para conservar la textura en la escena importada sin extraer copias PNG al árbol de fuentes.

Previsualizar el sanitario sin modificar la colección:

```bash
blender -b -t 3 -P animaciones/blender/zombis/generar.py -- --vista-previa
blender -b -t 3 -P animaciones/blender/zombis/render_animacion.py -- --vista-previa --detalle
```

El resultado está en `/tmp/zombis-v3/detalle.png`. Para exportar la colección completa, ejecutar
`generar.py` sin `--vista-previa`, y después los scripts de catálogo y marcha sin esa opción.
Los apartados v2 y sus resultados siguientes se conservan como historial de colaboración.

Validación v3: **588/588** comprobaciones específicas, importación y galería sin errores, PNG embebido,
UV y hashes verificados. Batería general **101/102 OK**: solo falló `moto_zombi`, intermitencia ya
documentada; pasó al repetirlo aislado con un atropello. Combate, suelo, ragdoll, menú y nivel pasaron.
Registros locales: `/workspace/setup-logs/zombis-v3-test.log`, `zombis-v3-regresion.log`,
`zombis-v3-moto-repeticion.log` y `zombis-v3-import-embebido.log`. Persiste el límite de no haber
medido/renderizado una horda en GPU; los renders de revisión son de Blender en CPU.

## Revisión visual v2

Rehechas las formas principales: torso con cintura y hombros, bíceps, antebrazos con tendones,
muslos y pantorrillas afinados, palmas y dedos con falanges/uñas. La cabeza usa un cráneo redondeado,
mandíbula estrecha, orejas con interior, nariz con fosas, párpados, dientes irregulares y heridas
asimétricas. Hay ojos nublados, mandíbulas y peinados diferentes, incluida melena y barba.

Los perfiles de cada profesión se definen en `animaciones/blender/zombis/refinado.py`: ancho y
profundidad de torso, volumen de miembros, mandíbula y pelo. También se añadieron solapas, pliegues,
deshilachados, bolsillos de trabajo, rodilleras del mecánico, radio/antena del policía, faldón y botas
del bombero, bajo de bata del paciente, hebillas y botella del excursionista/repartidor y parches del
abrigo. Los centros de articulación, las 15 piezas de impacto y los seis clips se conservan.

El generador llama al módulo de refinado antes de unir/exportar las mallas. Editar ambos archivos
fuente para mantener la regeneración reproducible. La anatomía sigue articulándose por segmentos;
esta revisión no introduce skinning continuo ni texturas de piel de alta resolución.

Presupuesto v2: hasta **16.000 triángulos** por modelo, frente al techo de 7.000 de la primera versión.
Los archivos finales tienen 13.016–14.216 triángulos. Es un aumento deliberado para dar volumen a las
formas; no debe interpretarse como una mejora de rendimiento. Falta medir el coste de renderizado de
una horda en GPU. Las 15 mallas conservan varias superficies por material.

Vistas actualizadas: `catalogo.png`, `caminar.gif` y `detalle.png`. Para regenerar el primer plano:
`blender -b -t 2 -P animaciones/blender/zombis/render_animacion.py -- --detalle`.

Validación v2: importación y galería sin errores; **576/576** comprobaciones específicas y hashes correctos.
La batería general terminó con **101/102 OK**: falló `suelo_pisoton --muerto`, con 2 impactos de 5
cuando el test exige al menos 3. Su repetición aislada pasó con 5 impactos de 5. Es una observación de
variabilidad de ese caso, distinta del fallo de `moto_zombi` de la primera entrega; la causa no quedó
determinada. No se modificaron lógica de combate, cajas de impacto, ragdoll ni aserciones para ocultarlo.
Registros: `/workspace/setup-logs/zombis-v2-test.log`, `zombis-v2-regresion.log`,
`zombis-v2-pisoton-repeticion.log` y `zombis-v2-galeria.log`.

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
Cada modelo v3 tiene 15 mallas segmentadas, materiales PBR con piel embebida y entre 11.898 y 12.766
triángulos. Una malla puede tener varias superficies/materiales: 15 mallas **no** significa 15 llamadas
de dibujo. La colección ocupa aproximadamente 9,2 MB en GLB; no se ha medido rendimiento de hordas
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

La prueba específica vigente ejecuta 612 comprobaciones: doce importaciones reales, seis clips por modelo
con movimiento, 15 piezas y sus tamaños, selección de variante, daño, derribo y muerte. La galería
también se ejecutó sin ventana. V3 añade doce comprobaciones de la textura embebida de cada cabeza.
V4 añade doce de selección de cerebro y doce de sangre con textura/transparencia.
El render de catálogo revisa la geometría en Blender; no acredita
calidad visual ni rendimiento del renderizador Forward+ de Godot en una GPU.

Resultado de la primera entrega (antes de v2): **576/576** comprobaciones específicas y catálogo de bytes/hashes correcto.
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

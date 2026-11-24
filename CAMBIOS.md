## 2026-11-17 — Levantarse para correr

- El fondo del menú se renderiza en Godot. Usa terreno alpino procedural, bosque instanciado, lago con oleaje animado, cielo atmosférico, iluminación solar y niebla.

- La portada muestra un paisaje fotorrealista de un valle alpino al atardecer. La imagen WebP llena la ventana y se recorta proporcionalmente.

- La portada estrena un corredor interior de descontaminación, con fluorescentes, luz de emergencia ámbar y un sanitario en primer plano.

- Menú principal: puesto de cuarentena con luces frías y luces de trabajo cálidas, lluvia en movimiento, cámara con deriva sutil y más detalle en el escenario. La portada y los paneles entran y salen con fundido y desplazamiento.

- Depuración: corregidas advertencias de GDScript en los scripts del juego y el aviso de audio de motor al terminar pruebas sin ventana.

- Depuración: ambos perfiles de exportación incluyen la clave de ejecución que espera Godot 4.6. Los efectos de audio puntuales se omiten en pruebas sin ventana para evitar avisos de recursos de audio al cerrar.

- Locomoción: al cambiar de ritmo, el pie atrasado adelanta el despegue y la pierna mantiene más flexión. La compensación de cadera usa un muelle estable con fotogramas largos.

- Moto: barrido de la rueda delantera al caer de morro y transferencia a cuerpo rígido en impactos fuertes, con inercia y vuelco. F levanta desde cerca cuando la moto se estabiliza, con giro suave, pies en sitio y agarres fijos.

- Salto con WASD: el impulso toma el rumbo del cuerpo al pulsar Espacio. Sin movimiento, el salto es vertical. Al bajar una rampa, la sonda de la moto solo busca bordillos en caras opuestas al avance.

- Moto en rampas: la retención automática se limita al terreno casi plano, el motor mantiene la fuerza disponible al rodar hacia atrás y la sonda distingue la subida continua de un bordillo.

- Choques de moto: el piloto conserva la velocidad del impacto y entra en ragdoll en el aire. La marcha atrás compensa la pendiente y la salida en parado comprueba el arco sobre la ladera. El audio 3D atenúa por distancia y altura, amortigua detrás de paredes y pisos y refuerza el roce de neumáticos al derrapar.

- El freno de mano reduce la velocidad longitudinal también en derrape y tiene prioridad sobre el acelerador y la marcha atrás.

- Moto: F monta desde la posición actual dentro del alcance lateral. El montaje en carrera es más corto y levanta antes la pierna. Más agarre lateral y derrape controlado al girar con el freno de mano. El neumático suena según el deslizamiento real.

- Montaje de moto: F conserva una aproximación rápida si se pulsa en carrera. El último paso frena y enlaza con apoyo, giro, inclinación y cruce de la pierna, con tiempos propios para la cadera y la orientación.

- Moto: F hace caminar al personaje hasta un costado de la moto disponible. El montaje y la salida en parado pasan la pierna sobre el asiento y usan apoyo en el suelo. Si la moto avanza o retrocede, el salto conserva su inercia.

- Sangre: 20 gotas por impacto de intensidad base, con un máximo de 192 gotas activas y 140 manchas simultáneas.

- Sangre simulada durante los pasos de física, con gravedad, arrastre y expansión de la mancha al tocar el escenario estático. Se descartan las colisiones del jugador y la moto para evitar manchas suspendidas.

- Desmembramiento de zombis: un impacto letal de machete, hacha o francotirador en una extremidad suelta la articulación y deja las piezas bajo el ragdoll, con marcas en el corte.

- Daño visual: heridas por bala y cortes adheridos a las piezas del zombi, hasta cuatro por pieza. Las gotas siguen trayectorias con gravedad y dejan manchas en la primera superficie.

- Audio: retirado el bucle sintético del derrape de moto. Las armas cuerpo a cuerpo usan contactos cortos de grabaciones CC0 y se elimina el efecto de aire al iniciar esos ataques.

- Audio de impactos con dos variantes por familia para puños, patadas, pisotones, armas blancas, bloqueos, balas y choques de moto. Créditos y mezclas en [Sonidos](docs/SONIDOS.md).

Versión actual de Proyecto Z: **0.6V**.

- Golpes rápidos: anticipación corta, retorno del puño junto al rostro y codo que sigue el arco del arma. El tiempo del clip de Blender gobierna la animación; el cooldown regula la siguiente entrada.

- Animaciones de ataque: 16 acciones CC_ editables en `animaciones/blender/combate/golpes.blend` (Blender 4.3). Seleccionar Piloto en el editor de acciones. Las curvas del grupo Controles IK se exportan ejecutando `python3 animaciones/blender/combate/a_gd_cc.py scripts/jugador/combate_cc.gd` desde la raíz. El marcador Contacto identifica el fotograma de impacto.

- Contacto cuerpo a cuerpo: Arsenal cruza el segmento del arma visible con las cajas orientadas del rig durante el golpe. El puñetazo usa la mano animada.

- Combate a pie: nuevas trayectorias de puño, cuchillo, machete y bate. Clic contra un caído usa un golpe descendente compartido de brazo; G conserva el pisotón.

Tumbado, pulsa Shift y una dirección para incorporarte y salir corriendo, con aceleración
progresiva. Respeta techos bajos. Mantener Shift al lanzarte cuerpo a tierra no cancela
la caída: para levantarte, suéltalo y púlsalo de nuevo. Carrera agachada conservada.

## 2026-11-17 — Agarre de armas y gráficos del nivel

Empuñaduras ajustadas al modelo y palma izquierda anclada al guardamanos con orientación
completa. Mejoradas paleta del cielo, luz, sombras, tonemapping y profundidad ambiental.
Se conserva el estilo cuadrado y gris. Detalle y capturas: `docs/AGARRE_Y_GRAFICOS.md`.

## 2026-11-17 — Tumbarse rápido al correr

Z durante la carrera permite tirarse cuerpo a tierra en 0,4 s, con un breve deslizamiento
que conserva el impulso y se frena. Respeta colisiones; fuera de carrera se mantiene la
transición normal. Comprobado en espacio libre y contra pared.

## 2026-11-17 — Facilitar disparos a corta distancia

Corregidos paralaje de cámara lateral, corte de alineación a menos de 3 studs y sobrepaso
del cañón en blancos pegados. Postura y arma se adaptan suavemente a la distancia; las
balas mantienen dirección física. Pruebas a 3/5/8 studs con tres armas y regresión lejana.

## 2026-11-17 — Actualizar mapa del proyecto

Añadido `docs/MAPA_PROYECTO.md` con estado vigente, archivos, pruebas y límites de cobertura
de Graphify. Incluye cambios de movimiento, modelos v7, balística, precisión y ragdoll.

## 2026-11-16 — Recuperar precisión de la mira sin desviar la bala

Ajuste suave y acotado de la postura del arma para cerrar el error residual del IK al
apuntar. La bala sigue saliendo en dirección real del cañón. Medición con rifle, pistola
y escopeta en `tests/precision_mira.gd`; dispersión de cada arma conservada.

## 2026-11-16 — Disparo en dirección real del cañón

Eliminada asistencia que dirigía la bala hacia la mira al levantar el arma y la salida
desde el pecho a corta distancia. Sin cañón visual disponible no se dispara. Se conservan
dispersión y obstáculos. Pruebas de desalineación y balística con Muzzle real.

## 2026-11-16 — Corregir brazos durante giro del arma larga

Limitada la anticipación del rifle y su velocidad acumulada al alcanzar el límite.
El cuerpo sigue más cerca al arma, evitando forzar el alcance de los brazos. Armas cortas
conservan su movimiento libre. Regresión de 18 comprobaciones y prueba de giro con disparos.

## 2026-11-16 — Pasos menos trabados y exagerados

Suavizada la mezcla de caminar/correr, limitado el alcance posterior y frontal y reducida
la elevación excesiva. El pie despega antes de estirar demasiado la pierna y avanza sin
un fotograma congelado; corregido el despegue hacia atrás. Prueba de continuidad y alcance
en `tests/pasos_suaves.gd`; captura real en `docs/fisica/pasos-suaves.gif`.

## 2026-11-16 — Arma primero y giros suaves

El arma larga inicia el giro con margen respecto al cuerpo. Armas cortas con una mano,
excepto durante la recarga. Giro de arma y cuerpo con aceleración y frenado progresivos.
Prueba de inversión de giro a 30, 60 y 120 FPS incluida.

## 2026-11-16 — Carrera con pistola y frenada antes de golpear

Disparar con pistola desde la cadera mantiene la carrera y libera el brazo izquierdo.
Torso y cabeza acompañan el tiro suavemente. Los golpes pedidos al correr esperan una
frenada breve antes de ejecutarse; giro hacia la mira más gradual.

## 2026-11-16 — Entrada suave al apuntado

Arma y postura entran más lentamente al apuntar; el codo respira conservando el agarre.
La cabeza acompaña suavemente la respiración y el disparo sin modificar la mira.

## 2026-11-16 — Correr sin fijación a la mira

El cuerpo armado se orienta hacia el movimiento durante la carrera. La animación recibe
esa orientación para evitar retorcer torso y piernas hacia la cámara.

## 2026-11-16 — Pasos laterales y hacia atrás

Mezcla direccional de carrera y velocidad ajustada a pasos rápidos de lado/atrás, evitando
reproducir la carrera frontal a velocidad excesiva en esas direcciones.

## 2026-11-16 — Apuntado caminando y transición tras carrera

Eliminada flexión adicional de piernas al caminar apuntando. Pausa de 0,16 s tras correr
antes de apuntar, subir a la moto o levantarla.

## 2026-11-16 — Filtro gris suave

Desaturación ligera de la imagen 3D del juego y fondo del menú para un ambiente más triste.
Brillo y contraste suavemente reducidos; HUD y textos mantienen sus colores.

## 2026-11-16 — Saltos frontales y patadas sin carrera

Bloqueados los saltos hacia atrás, laterales y diagonales laterales. Se mantienen el salto
vertical y hacia delante. G no inicia patada/pisotón al correr y Shift no activa carrera
durante esos ataques. La dirección vuelve a comprobarse al despegar.

## 2026-11-16 — Caídas distintas y contracciones en el ragdoll

NPC y zombis sortean por muerte el equilibrio del torso, brazos y pérdida de apoyo de cada
pierna. La bala conserva su reacción localizada; las colisiones y la gravedad resuelven la
caída. Contracciones breves en rodillas, codos, tobillos o cuello, con tiempos e intensidad
variables que se debilitan hasta detenerse. No se repite un clip de muerte.

Prueba de ocho tiros iguales con variedad física, movimiento en el suelo, estabilidad y
reposo final; añadida a la batería general. Captura reproducible en `docs/FISICA_Y_MANEJO.md`.

## 2026-11-16 — Mostrar el impacto antes del desplome

Corregida la reacción mortal que quedaba registrada pero no llegaba al ragdoll. Se transfiere
su estado sin duplicar la pose existente y se conserva brevemente el apoyo para que se vea
el golpe localizado antes de caer. Reacciones vivas más legibles; el impulso de las balas no
aumenta. Prueba contra la versión anterior: detecta el torso sin reacción y pasa con el cambio.
Capturas de primer plano y resultados en `docs/FISICA_Y_MANEJO.md`.

## 2026-11-16 — Disparos localizados y conducción de moto

Las balas conservan punto, dirección y pieza de impacto; aplican impulsos modestos por arma y
perdigón. Reacciones vivas locales y muerte física desde la pose actual, sin agonía prefijada
repetida ni lanzamiento global del cuerpo. Cadáveres alcanzables y recuperación del muñeco.

Moto con dirección progresiva, curva sin pérdida numérica de velocidad, margen de giro según
agarre/frenada y transición frenada–marcha atrás con pausa, también en pendiente. Nuevas pruebas
y grabaciones reales de Godot en `docs/FISICA_Y_MANEJO.md`. Arte v7 conservado.

## 2026-11-16 — Zombis limpios según referencias del usuario (v7)

Rehechas las doce variantes con bloques sencillos y detalles mínimos de oficio. Eliminados
pliegues y parches superpuestos, heridas volumétricas, cerebro expuesto y microrelieve; piel
uniforme y sangre pequeña por píxeles. Se conservan rig, clips y combate. Las pruebas visuales
cambian su expectativa a cráneo cerrado y ausencia de normales: es la dirección solicitada,
no una reducción de las comprobaciones funcionales. Ver `docs/MODELOS_LIMPIOS_V7.md`.

## 2026-11-16 — Corrección de todas las piezas de zombis a bloques

Sustituidos los detalles ovalados que seguían en v5 por cajas rectas: cara, manos, barba,
pliegues, heridas, cerebro y accesorios. Sección rectangular del cuerpo, sin redondeo ni
suavizado. Se conservan pivotes y contratos R15. Ver `docs/CORRECCION_CUADRADA_V6.md`.

## 2026-11-16 — Zombis v5 y escenario de cuarentena

Estilo cuadrado conservado por petición expresa, microrelieve de piel y tejido en GLB, y un puesto
urbano de cuarentena con mayor profundidad, iluminación y asfalto húmedo. Se mantienen rig,
IA, combate, clips y navegación del menú. Fuentes y validación: `docs/REVISION_VISUAL_V5.md`.

# Registro de cambios — Proyecto Z

Cada Claude (o persona) que cambie algo en el proyecto añade una entrada **arriba del todo**,
en el mismo commit que el cambio. Formato:

```
## AAAA-MM-DD · Autor (quién pidió el cambio) · Claude/persona
**Qué:** una o dos frases.
**Archivos:** lista de archivos tocados.
**Cómo probarlo:** qué hacer en el juego para verlo.
**Pendiente / avisos:** lo que quedó a medias o lo que el otro debe saber (opcional).
```

---

## 2026-11-16 · Usuario · Codex — rediseñar el menú principal
**Qué:** portada de cuarentena nocturna con escenario propio, zombis decorativos, nueva tipografía,
botones numerados y acento rojo. Opciones/Controles en paneles escalables, foco visible, Esc para
volver y protección frente a cargas duplicadas. Conservadas las cuatro acciones del menú.
**Archivos:** `scripts/ui/menu_principal.gd`, nuevos `fondo_menu.gd` y `atmosfera_menu.gdshader`,
fuentes/licencias en `assets/fuentes/`, `tests/menu_redisenado.gd`, `docs/MENU_PRINCIPAL.md`, `CLAUDE.md`.
**Cómo probarlo:** ejecutar el juego normalmente. Abrir Opciones/Controles con ratón o flechas/Enter,
volver con Esc y pulsar Jugar. Cambiar tamaño de ventana; probar 16:9, 4:3 y pantalla ancha.
**Pendiente / avisos:** el fondo no es el nivel jugable ni tiene zombis activos. No se modificaron
la escena de entrada, `project.godot`, el jugador ni el menú de pausa. Fuentes bajo Apache 2.0 con
avisos incluidos. Capturas reales y reproducción: `docs/MENU_PRINCIPAL.md`.
**Validación específica:** 52 comprobaciones correctas sin ventana y 56 con renderizado (cuatro
capturas reales incluidas en `docs/capturas/`). Recorrido antiguo: menú, nivel, pausa/opciones y vuelta
al menú sin errores, sin pausa residual ni pantalla de carga pendiente. Cinco tamaños verificados.
**Batería general:** 101/102 OK; solo falló `moto_zombi`, ya documentado como intermitente, y pasó
aislado. Se conserva el resultado original en `menu-nuevo-regresion.log`; no se alteraron sus aserciones.

## 2026-11-16 · Usuario · Codex — zombis ensangrentados y cerebro visible en tres variantes (v4)
**Qué:** sangre seca/reciente en piel, boca, ropa y extremidades; cortes y coágulos en antebrazos.
Civil, sanitario y paciente tienen abertura real de cráneo, corteza con pliegues/vasos, borde herido
y hueso expuesto. Los otros nueve mantienen la cabeza cerrada. Conservada la estética cuadrada.
**Archivos:** nuevo `deterioro.py`, `rostro.py`, `refinado.py`, `generar.py`, `validar.py`, modelos y
fuentes de Blender, catálogo y vistas, `tests/modelos_zombis.gd`, `CLAUDE.md`, `docs/MODELOS_ZOMBIS.md`.
**Cómo probarlo:** F6 en `escenas/galeria_zombis.tscn`; comparar civil/sanitario/paciente con las otras
nueve variantes y cambiar los clips con las flechas. Prueba de recursos: `tests/modelos_zombis.gd`.
**Pendiente / avisos:** el deterioro es parte del aspecto inicial del modelo, no heridas que se generen
al recibir un disparo. No cambian daño, colisiones ni comportamiento. La sangre en ropa añade una
superficie transparente por pieza afectada; falta medir una horda en GPU.
**Validación específica v4:** 612/612 comprobaciones; importación y galería sin errores, dos texturas
embebidas/UV/hashes correctos, tres variantes con corteza y nueve sin ella, techo de geometría respetado.
**Batería general v4:** 102/102 OK (`TODO BIEN`), incluyendo moto, combate, suelo, ragdoll y arranque
de menú/nivel. Catálogo, primer plano y GIF de marcha renderizados y revisados. No se alteraron
las aserciones ni los umbrales de las pruebas existentes para obtener ese resultado.

## 2026-11-16 · Usuario · Codex — corregir rostros y recuperar el arte cuadrado (v3)
**Qué:** retirada la apariencia de cuencas negras, ojos saltones, cejas/pómulos de goma y boca negra
abierta. Cabeza cuadrada R15 con relieve facial bajo, ojos estrechos, párpados finos, nariz proporcionada,
labios discretos y señales de infección contenidas. Añadida piel original con variación suave y pliegues
mediante una textura de 512×512 embebida. Cuerpo con caras planas y secciones cuadradas, conservando equipo.
**Archivos:** `refinado.py`, nuevo `rostro.py`, `generar.py`, `validar.py`, `render_animacion.py`, doce
fuentes `.blend`, doce `.glb`, catálogo y vistas de revisión; `CLAUDE.md` y `docs/MODELOS_ZOMBIS.md`.
También los doce `.glb.import` (piel embebida) y `tests/modelos_zombis.gd` (comprobación de textura).
**Cómo probarlo:** abrir `escenas/galeria_zombis.tscn` con F6 y revisar las caras de cerca; ver `detalle.png`
y `catalogo.png`. Validación de importación/rig/combate: `tests/modelos_zombis.gd`.
**Pendiente / avisos:** la revisión v2 queda como antecedente, no como dirección artística vigente.
Se conserva el sistema de animación actual; la textura está dentro de los archivos, sin rutas externas.
**Validación específica:** 588/588 comprobaciones, importación y galería sin errores; catálogo, PNG
embebido de 512×512, UV y hashes verificados. Primer plano revisado antes de exportar la colección.
**Batería general v3:** 101/102 OK; único fallo `moto_zombi`, ya documentado como intermitente;
repetición aislada OK. Pasaron combate, golpes al suelo, ragdoll, menú y nivel. No se ocultó el fallo.

## 2026-11-16 · Usuario · Codex — segunda revisión visual de los doce zombis
**Qué:** anatomía más natural y siluetas/ropa diferenciadas: cráneo y mandíbula, párpados y ojos nublados,
dientes irregulares, orejas/nariz, peinados y barbas; manos con falanges/uñas, brazos y piernas afinados,
pliegues, deshilachados y equipo adicional por profesión. Corregida la unión visual de los hombros.
**Archivos:** fuentes `generar.py`, nuevo `refinado.py`, `validar.py`, `render_animacion.py`; doce `.blend`,
doce `.glb`, `catalogo.json`, vistas PNG/GIF, `docs/MODELOS_ZOMBIS.md`, `CLAUDE.md` y este registro.
**Cómo probarlo:** ejecutar `escenas/galeria_zombis.tscn` con F6 y revisar variantes desde distintos ángulos;
flechas cambian clip. Ejecutar el nivel para verlas con la IA. `tests/modelos_zombis.gd` verifica la
compatibilidad y `python3 animaciones/blender/zombis/validar.py` verifica los bytes del catálogo.
**Pendiente / avisos:** mayor geometría (13.016–14.216 triángulos; techo de 16.000), con las mismas 15 piezas.
No se ha medido una horda en GPU. Se mantienen los seis clips existentes y el controlador procedural/ragdoll
del juego. Los materiales siguen sin texturas externas ni servicios de pago.
**Validación:** importación y galería sin errores, 576/576 comprobaciones específicas, doce GLB con
hash y presupuesto correctos. Batería general: 101/102 OK; falló `suelo_pisoton --muerto` (2/5 impactos)
y pasó aislado (5/5). Causa de la variación pendiente; se conserva el fallo original en los registros.
Catálogo, primer plano y marcha renderizados y revisados. Sin cambios de código ni pruebas de combate.

## 2026-11-16 · Usuario · Codex — 12 modelos de zombis y seis clips de animación
**Qué:** colección original R15 con doce aspectos de infectados, ropa/equipo por profesión, caras,
dedos, dientes, cicatrices, roturas y costuras. Fuentes `.blend`, generador reproducible, GLB con seis
clips compartidos (reposo, caminar, perseguir, atacar, herido y morir), catálogo con hashes y vitrina
interactiva. Los zombis del juego eligen un aspecto al crearse; se puede fijar o volver al clásico.
**Archivos:** `animaciones/blender/zombis/`, `modelos/zombis/`, `scripts/jugador/rig_personaje.gd`
(registro de modelos), `scripts/zombis/zombi.gd` (selección visual), `scripts/nivel/galeria_zombis.gd`,
`escenas/galeria_zombis.tscn`, `tests/modelos_zombis.gd`, `docs/MODELOS_ZOMBIS.md`, `CLAUDE.md`.
**Cómo probarlo:** ejecutar `escenas/galeria_zombis.tscn` con F6; flechas cambian clip, espacio pausa,
arrastrar y rueda controlan cámara. Jugar el nivel para ver variantes con IA. Prueba sin ventana:
`Godot_4.7.2 --headless --path . -s res://tests/modelos_zombis.gd` (576 comprobaciones).
**Pendiente / avisos:** estética segmentada del juego, sin esculturas fotorrealistas ni texturas de
alta resolución. Los GLB llevan los clips nuevos para Blender/vitrina; la IA sigue usando su animador
procedural y el ragdoll para conservar los tiempos del combate. No se ha medido rendimiento de hordas
en GPU. Ver `docs/MODELOS_ZOMBIS.md` para regenerar y no perder ediciones manuales de Blender.
**Validación realizada:** Godot 4.7.2: importación sin errores, 576/576 comprobaciones específicas;
catálogo GLB/hashes correcto; galería arrancada y abierta por Godot AI. Batería general: 101/102 OK,
único fallo `moto_zombi`, ya documentado como intermitente; repetición aislada OK. Combate, suelo,
ragdoll, menú y nivel pasaron. Catálogo renderizado en CPU y GIF de marcha revisados.

## 2026-11-10 · Juan · Claude — zombis: ya no pegan a través de paredes, heridas de lejos y fondo del mundo
**Qué:** Juan pidió una auditoría "bajo pruebas de acero" (Godot 4.7.2 real, sin ventana: la batería del repo más
sondas propias) y arreglar los fallos de su parte. Tres fallos comprobados ejecutando y un cabo suelto:
1. **El zombi pegaba y notaba al jugador a través de paredes.** `_quiere_atacar`, el golpe de `_paso_atacar` y
   `_sentir_contacto` solo miraban la distancia. *Medido antes:* pared de 1 stud (31 cm), jugador quieto y en
   silencio a 3 studs → el zombi lo detecta, ataca y la vida baja de 100 a 80. Ahora los tres piden camino libre
   (`Zombi._alcanzable`: los mismos rayos de la vista, a la cabeza, el pecho y la cadera, contra la capa 1). Por
   encima de una barrera de 1 m sigue llegando; si te metes tras una pared mientras levanta los brazos, falla.
   De paso, la moto que CONDUCE el jugador ya no cuenta como pared para la vista ni para el ataque (`_no_tapan`).
2. **Un zombi herido sabía la posición exacta del jugador a cualquier distancia.** *Medido antes:* a 280 studs
   (87 m), herido sin oír nada → `PERSEGUIR` con la pista a 0,0 studs del jugador. Ahora `Zombi._notar_golpe`: el
   golpe le dice de qué lado vino. Sabe quién fue solo si lo tiene a ≤ 12 studs (`HeridaCerca`), si le está viendo o
   si le oyó hace menos de `PerseguirMemoria` (el estampido llega antes que la bala); si no, se enfurece e investiga
   30 studs (`HeridaRastro`) hacia donde vino el golpe. Lo mismo al levantarse tras un derribo.
3. **Nadie paraba una caída fuera del mapa.** *Medido antes:* a los 12 s de salirse del suelo, el jugador iba por
   y = −1374, vivo y sin reinicio; un zombi, por −2515. Ahora `ZConfig.WORLD.FondoMundo` (−200 studs): el zombi (o su
   cuerpo en ragdoll) que lo cruza se borra y emite `murio`; al jugador lo mata el `DirectorZombis` por su
   `recibir_danio` de siempre (muere, "Te has caído del mapa", y el nivel se reinicia a los 4 s). Con el truco
   "invencible" vuelve al punto de partida. **No se ha tocado `jugador.gd`.**
4. El ruido `"motor"` de la moto no estaba en las tablas de `Ruido`: ahora `Ruido.MOTOR`, con el mismo peso que
   tenía por omisión (0,5: el juego no cambia) y color propio en la vista F6.
Además: respondidos en `CLAUDE.md` los 8 mensajes pendientes del Claude de KangooG (el más antiguo, del 24 de
octubre) y un mensaje nuevo para él con lo que le afecta; anotados en "Problemas conocidos" dos fallos medidos de
su parte que no se han tocado (cadencia según los FPS, efectos que sobreviven al volver al menú).
**Archivos:** `scripts/zombis/zombi.gd`, `scripts/zombis/director_zombis.gd`, `scripts/ruido/ruido.gd`,
`scripts/config/zconfig.gd` (claves nuevas `WORLD.FondoMundo`, `ZOMBI.HeridaCerca`, `ZOMBI.HeridaRastro`),
`tests/pruebas_ruido.gd` (pruebas `ataque_pared`, `herida_lejos`, `fondo_mundo`; `unidad` comprueba las tablas de
tipos de ruido), `tests/ejecutar_pruebas.sh`, `docs/RUIDO_Y_ZOMBIS.md`, `CLAUDE.md`, `README.md`.
**Cómo probarlo:** `tests/ejecutar_pruebas.sh <Godot> ataque_pared herida_lejos fondo_mundo unidad`. Batería
completa del 2026-11-10 (Godot 4.7.2, Linux, sin ventana; 102 comprobaciones, ~6,5 min): las 29 de ruido y
zombis en verde; en la última pasada, 101 de 102. Los únicos fallos del día fueron de dos pruebas que ya eran
inestables ANTES de estos cambios (medido repitiéndolas): `moto_zombi` (2 de 12 antes, 2 de 16 después) y
`suelo_puno --grupo --mira_abajo` (2 de 48 antes, 1 de 24 después). Las tres pruebas nuevas, repetidas:
`ataque_pared` 64 de 64, `herida_lejos` 24 de 24, `fondo_mundo` 24 de 24.
**Lo que cazó la batería por el camino (para que se vea por qué se pasa entera):** la primera versión de
`_fuera_del_mundo` preguntaba la altura al ragdoll también mientras el zombi se levanta, cuando el ragdoll ya no
tiene cuerpos: `fisica_empujon` y `fisica_patada` se pusieron rojas con un error de script. Corregido y cubierto
en `fondo_mundo` (un zombi derribado en mitad del suelo se levanta y sigue ahí). Y `ataque_pared` falló 1 de 32
veces porque el golpe puede tirar al jugador al suelo: ahora espera a que esté de pie (`_esperar_de_pie`).
**Qué debe probar Juan jugando (F5) — nadie lo ha MIRADO, solo se ha medido sin ventana:**
- Ponte pegado a la pared alta del nivel con un zombi al otro lado (F6 para ver su estado): no debe notarte ni
  pegarte. Al otro lado de la barrera baja de la zona de tiro sí debe alcanzarte.
- Pulsa F7 (zombis sordos: si oye el disparo, sabe dónde estás, como siempre) y dispara con el rifle desde lejos
  a un zombi que no te mire: debe venir hacia ti por tramos y mirando alrededor, no en línea recta hasta tu
  sitio. Sin F7, y de cerca con cuchillo o bate, todo como antes.
- Súbete a la moto y sal por el borde del suelo: debes morir a los ~4 s de caída y reiniciarse el nivel. Empuja o
  atropella a un zombi junto al borde: su cuerpo desaparece al caer y reaparece en su sitio a los 20 s.
- Juega un rato normal con los 4 zombis: ¿se siente igual de justo que antes cuando te persiguen y te pegan?
**Pendiente / avisos:**
- El fondo del mundo del jugador es una red de seguridad del director: un nivel sin `DirectorZombis` no la tiene,
  y una moto sin piloto que se salga del mapa sigue cayendo (es de KangooG). Un mapa con zonas por debajo de −200
  studs necesita bajar `FondoMundo`.
- Herido de lejos, el zombi adivina siempre 30 studs por golpe, esté el tirador a 50 o a 500.
- Fallos medidos en la parte de KangooG, sin tocar: ver "Problemas conocidos" en `CLAUDE.md`.

## 2026-11-09 · KangooG · Claude — el arma larga ya no da un giro raro al golpear al suelo
**Qué:** KangooG: "cuando uso el arma blanca larga y golpea hacia el piso da un giro extraño". La orientación del arma
(`a_f*` dirección, `a_u*` "arriba") se interpolaba canal a canal: entre dos claves casi opuestas (el arma arriba-atrás y
luego abajo-delante) la dirección pasaba por casi cero y su "arriba" quedaba paralelo a ella, y el arma daba vueltas
sola. Pasaba en el golpe al suelo y, menos, en otros de arriba abajo. Ahora (`diseno_cc.py`, `_orientacion`) cada clave
es un giro (cuaternión) y entre claves gira por el camino más corto (slerp) con el ritmo de las posiciones; el "arriba"
solo manda en la clave del golpe y en la primera y la última (en las demás se arrastra sin girar el arma sobre su
eje); entre claves casi opuestas se elige el sentido en que la punta va por delante del movimiento (por encima de la
cabeza, no por detrás). Además: `hoja()` daba un "arriba" nulo en las estocadas (la dirección igual al movimiento), el
golpe de arriba abajo del bate recoge por delante (nueva clave) y `ImpactoCC` apunta con el trozo de arma que da (no
con la empuñadura: con el arma larga ya no se agacha de más).
**Archivos:** `animaciones/blender/combate/diseno_cc.py`, `scripts/jugador/combate_cc.gd` (generado),
`scripts/jugador/impacto_cc.gd`, `tests/suelo_cc.gd` (`--golpe=bate`), `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F5, con el bate o el machete, pegar a un zombi tirado y a uno de pie.

## 2026-11-08 (11) · KangooG · Claude — una sola animación para pegar al que está en el suelo
**Qué:** KangooG: "que solo haga una animación para pegarle a alguien del piso". Antes, a uno tumbado se le daba con
cualquiera de los golpes de pie, deformado hacia abajo. Ahora hay una animación propia por clase, hecha en Blender
(`diseno_cc.py`, `SUELO` → `CombateCC.SUELO`), y es SIEMPRE esa: sin arma, agachado y puñetazo hacia abajo con la
derecha (la izquierda apoyada delante); cuchillo, agachado y puñalada hacia abajo; arma larga (machete, hacha, bate,
palanca), golpe de arriba abajo al suelo. El pisotón (G) queda en uno solo (pie derecho). `Arsenal.punetazo` y `melee`
la eligen con `cc_blanco` (los de pie siguen teniendo prioridad); la acción lleva `suelo = clase` y `cc_anim` la
devuelve. `ImpactoCC` tiene en cuenta lo que la animación ya baja el cuerpo (antes se agachaba de más).
**Archivos:** `animaciones/blender/combate/{diseno_cc.py, a_gd_cc.py, ver_cc.py}`, `scripts/jugador/combate_cc.gd`
(generado), `scripts/jugador/arsenal.gd`, `scripts/jugador/impacto_cc.gd`.
**Cómo probarlo:** F5, tirar a un zombi y darle en el suelo con clic izquierdo (sin arma, cuchillo, machete o bate).

## 2026-11-08 (10) · KangooG · Claude — puñetazos estirados y sueltos, y más golpes con armas blancas (Blender)
**Qué:** KangooG: "más animaciones de pegada para más variedad, que los puños se estiren más al pegar, veo al
personaje muy tieso". En `animaciones/blender/combate/diseno_cc.py`:
- **Puñetazos rehechos y 6 en vez de 4** (directo, cruzado, gancho, gancho de abajo y NUEVOS gancho a la barriga y
  derechazo largo por encima). Los directos llegan con el **brazo estirado** (la mano algo más allá del alcance: la IK
  lo deja recto, ~2,2 studs desde el hombro) y se quedan un instante; todos con carga corta, cadera y hombros girando a
  la vez (`cin` + `pel`), el peso a la pierna de delante, la cabeza fuera de la línea y la otra mano a la barbilla.
  Se encadenan alternando manos (`Arsenal.punetazo`: tras una pausa, el directo; luego al azar entre los de la otra
  mano sin repetir los dos últimos; cada puñetazo lleva `lado`).
- **Armas blancas: 4 golpes de Blender por arma** (+ el de siempre): Cuchillo + estocada y tajo de derecha; Machete
  (y las que lo usan de base) + diagonal y revés alto; Bate (y palanca) + batazo horizontal y golpe con la punta.
**Archivos:** `animaciones/blender/combate/diseno_cc.py`, `scripts/jugador/combate_cc.gd` (generado),
`scripts/jugador/arsenal.gd` (`punetazo`, `_puno_ult`).
**Cómo probarlo:** F5, sin arma clic izquierdo seguido; con cuchillo, machete o bate, varios golpes.
Vista previa: `blender -b cuerpo.blend -P combate/ver_cc.py -- "puno:0:0.3;puno:5:0.42" "0,0.15,8" salida`.

## 2026-11-08 (9) · KangooG · Claude — en grupo, pega a los de pie (no al suelo)
**Qué:** KangooG: "si vienen en grupo el personaje se confunde y pega al suelo". Con un cuerpo en el suelo más cerca que
los zombis de pie, el ajuste al blanco elegía el del suelo (se agachaba) y el pisotón salía en vez de la patada. Ahora
hay un solo criterio, `Arsenal.cc_blanco(alcance)`: **primero los que están de pie**; uno del suelo solo si no hay nadie
de pie a tiro **o si la cámara mira claramente hacia abajo** (`CC_MIRA_SUELO`: para rematar a uno caído con otros
cerca). Lo usan el ajuste (`ImpactoCC.preparar`), el pisotón (`patada`), el golpe de Blender forzado (`melee`) y el
avance (`_cc_extra`). En el contacto (`_cc_impacto`) los cuerpos del suelo solo cuentan si la acción va al suelo
(`ImpactoCC.va_al_suelo`) o es un pisotón, y `_resolver_golpe` (armas blancas) solo les da si no hay nadie de pie (o
mirando abajo).
**Archivos:** `scripts/jugador/arsenal.gd`, `scripts/jugador/impacto_cc.gd`, `tests/suelo_cc.gd` (`--grupo`,
`--mira_abajo`), `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F5 con varios zombis, uno de ellos tirado: pega a los de pie; para rematar al del suelo, mira hacia
abajo con la cámara.

## 2026-11-08 (8) · KangooG · Claude — pegar a los cuerpos en el suelo (también cadáveres)
**Qué:** KangooG: "no le puedo pegar a los cuerpos en el piso". (1) Los cadáveres no contaban como blanco (solo los
vivos): ahora puñetazos, pisotón y armas blancas también les dan (sin daño que hacer: el ragdoll se sacude, sangre,
parón). (2) Con un cuerpo tumbado la distancia se medía a su pecho: con las piernas delante quedaba "fuera de alcance";
ahora cuenta su pieza más cercana (`Arsenal._cc_blancos`) y, si el pecho / la cabeza quedan lejos, el golpe va a la
pieza que se alcanza (`ImpactoCC._elegir_pieza`). (3) `_resolver_golpe` (armas blancas) también da a los del suelo
(detrás de los que estén de pie) con el golpe hacia abajo.
**Archivos:** `scripts/jugador/arsenal.gd`, `scripts/jugador/impacto_cc.gd`, `tests/suelo_cc.gd` (`--muerto`,
`--distancia=N`), `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F5, matar o tirar a un zombi y pegarle tumbado (G, clic izquierdo sin arma o con arma blanca),
también desde sus pies.

## 2026-11-08 (7) · KangooG · Claude — golpes que se sienten y cuerpo que se ajusta al blanco (pisotón)
**Qué:** KangooG: "las colisiones no se sienten reales, es como si le pegara a una imagen" y "que el personaje se
ajuste a la pegada: si el zombi está en el suelo, que se incline a pegarle". Archivo nuevo `scripts/jugador/impacto_cc.gd`
(`ImpactoCC`, `Arsenal.impacto`):
- **Al tocar** (patada, empujón, puñetazo, pisotón y golpes con arma blanca): parón de 50-90 ms (`Engine.time_scale`
  0,12 un instante; más largo cuanto más fuerte), el miembro se queda un momento en el punto de contacto (la acción se
  detiene 40-90 ms: no atraviesa el cuerpo) y rebota hacia atrás, la pieza golpeada se hunde (cabeza: latigazo; pecho:
  se echa atrás y la cabeza se queda; barriga: se dobla un poco; piernas: se tuerce), sacudida y golpe de zoom de la
  cámara y sonido de carne bajo el golpe.
- **Ajuste al blanco:** al empezar la acción elige el blanco (también caído) y la pieza; hasta el golpe la cadera baja,
  el tronco se inclina y mira hacia allí, y la mano / el arma / el pie se desvían hasta la pieza (con topes). Con un
  zombi en el suelo se agacha a pegarle (puños y armas blancas: siempre uno de los golpes de Blender). De pie y a la
  altura normal apenas cambia nada.
- **Pisotón:** G con un zombi en el suelo delante (`Arsenal.pisoton`, `CombateCC.PISOTON`, derecho e izquierdo, hecho
  en Blender en `diseno_cc.py`): rodilla arriba y pie abajo con todo el peso, 30 de daño (x1,8 en la cabeza); el pie va
  al cuerpo de verdad. Con el zombi más lejos, patada normal.
- Contrato de objetivo: método nuevo **opcional** `reaccion_golpe(pieza, dir, fuerza)` (zombi y maniquí). `_cc_blancos`
  apunta el rayo de visión algo por encima del centro (con el zombi tumbado chocaba con el suelo).
**Archivos:** `scripts/jugador/impacto_cc.gd` (nuevo), `arsenal.gd`, `animador.gd` (5 líneas: `sumar_cuerpo`, `marco`,
`mano_local`, `pie_offset`, pisotón como patada), `combate_cc.gd` (generado), `animaciones/blender/combate/{diseno_cc.py,
a_gd_cc.py, ver_cc.py}`, `scripts/zombis/zombi.gd` y `scripts/nivel/maniqui.gd` (solo `reaccion_golpe`, nuevo),
`tests/suelo_cc.gd` + `tests/escena_suelo_cc.tscn` (nuevos), `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F5, tirar a un zombi (patada o bate) y con él en el suelo: G (pisotón), clic izquierdo sin arma
(puñetazo agachado) o con cuchillo / machete / bate. De pie: cada golpe hace un parón corto y el zombi reacciona
según dónde le des. Prueba: `tests/suelo_cc.gd --golpe=pisoton|puno|cuchillo [--lado] [--traza]`.
**Avisos:** el parón cambia `Engine.time_scale` un instante y lo devuelve a lo que hubiera (la cámara lenta de F1
sigue funcionando). Para Juan: `reaccion_golpe` en `zombi.gd` solo mueve vuestros muelles `S.hit*`.

## 2026-11-08 (6) · KangooG · Claude — Versión 0.5
**Qué:** el juego pasa a la versión **V0.5** (KangooG: "pon en todos lados que avanzamos a la V0.5"):
`application/config/version = "0.5"` en project.godot (fuente única; se ve en el menú principal, la pausa y el título
de la ventana). Exportación: `../versiones/v0.5/V0.5.exe`, versión de archivo y de producto 0.5.0.0. Incluye el combate
cuerpo a cuerpo (guardia, bloqueo, parada, empujón, patada, puñetazos y golpes variados) con física al impactar.
Las menciones antiguas "v0.4" en comentarios son historia y se dejan.
**Archivos:** `project.godot`, `export_presets.cfg`, `CLAUDE.md`, `CAMBIOS.md`.
**Cómo probarlo:** F5: el menú dice "V0.5 · prototipo" y la ventana "Proyecto Z · V0.5".

## 2026-11-08 (5) · KangooG · Claude — física real en el empujón, la patada y los puñetazos
**Qué:**
- **Solo hay impacto si el pie o la mano llega de verdad al cuerpo** (a la caja de una de sus piezas, sin contar los
  brazos), en una ventana alrededor del momento del golpe; si el blanco está fuera de alcance, el golpe falla.
- **Lo que le pasa sale de la cantidad de movimiento:** Δv = parte de la masa del jugador que va en el golpe ×
  (velocidad real del pie / la mano + lo que el otro venía hacia ti) / masa del otro (80 y 70 kg; el empujón lleva el
  peso del cuerpo, la patada la pierna y la cadera, el puñetazo el brazo). Un zombi que viene hacia ti se lleva más.
- **Empujón:** ya no lo manda lejos: retrocede ~2,5 studs (unos 75 cm) tambaleándose, **se echa hacia atrás** (unos
  20°) y puede **perder el equilibrio y caer** (~20 %; si ya iba tambaleándose por otro empujón, bastante más).
- **Patada:** retrocede más y cae más fácil cuanto más fuerte y más abajo le das (a las piernas, mucho más). La
  frontal ahora sube la rodilla y extiende recta a la tripa (antes daba en el muslo).
- Al caer, el ragdoll sale con ese mismo impulso desde la pieza golpeada. El jugador nota un poco de retroceso.
**Archivos:** `scripts/jugador/arsenal.gd` (`_cc_impacto`, `_cc_seguir_miembros`, `CC_MASA_*`, `CC_VEL_MAX`,
`CC_TROPIEZO`, `CC_CAIDA_*`), `scripts/zombis/zombi.gd` y `scripts/nivel/maniqui.gd` (`empujar`: se echan hacia atrás
con los muelles de impacto), `animaciones/blender/combate/diseno_cc.py` (patadas), `scripts/jugador/combate_cc.gd`,
`tests/fisica_cc.gd` + `tests/escena_fisica_cc.tscn` (nuevos), `tests/combate.gd`, `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** junto a un zombi: clic derecho + doble Espacio varias veces seguidas (al segundo empujón seguido se
cae más fácil), y patadas (G).
**Pendiente / avisos:** tocamos `zombi.gd` (Juan) solo en `empujar` (ver el mensaje en `CLAUDE.md`).

## 2026-11-08 (4) · KangooG · Claude — patadas lanzadas, empujón agresivo, golpes variados y puñetazos
**Qué:**
- **Patadas rediseñadas en Blender** (4: frontal derecha, frontal izquierda, alta, baja): recoge la rodilla de golpe,
  la pierna sale entera con la planta por delante, la cadera empuja a través del blanco y el tronco se echa atrás. La
  patada **empuja de verdad** (empuje 60-78, antes 34-46) y deja al zombi tambaleándose.
- **Empujón con las manos más agresivo** (3 variantes: a dos manos, con el hombro y de abajo arriba): carga con los
  codos atrás y sale de golpe con todo el cuerpo; empuja más (46).
- **Menos "dash":** el cuerpo avanza la mitad al empujar, patear y golpear (avance de las animaciones, `CC_ACERCA`
  0,7 y la acometida de los golpes de siempre a la mitad).
- **Variedad de ataques:** cada arma blanca tiene 2 golpes nuevos además del de siempre (cuchillo: tajo de revés y
  puñalada de arriba; machete, hacha y palanca: tajo horizontal y de arriba abajo; bate: de arriba abajo y de revés),
  que salen en orden al azar sin repetir hasta haberlos usado todos. **Sin arma, clic izquierdo = puñetazos**
  encadenados: directo, cruzado, gancho y gancho de abajo (y después de pegar se queda un momento en guardia).
**Archivos:** `animaciones/blender/combate/diseno_cc.py` (PATADA, EMPUJON, GOLPES, PUNOS), `a_gd_cc.py`, `ver_cc.py`
(`puno:`), `scripts/jugador/combate_cc.gd` (generado), `scripts/jugador/arsenal.gd` (`melee` con variantes,
`punetazo`, `cc_anim`, bolsa de variantes), `scripts/jugador/animador.gd`, `tests/combate.gd` (`--cc=golpes`),
`tests/ejecutar_pruebas.sh`, `README.md`, ayuda H.
**Cómo probarlo:** junto al muñeco: G varias veces (patadas), clic derecho + doble Espacio (empujones), clic izquierdo
sin arma (puñetazos) y con cada arma blanca (golpes distintos).

## 2026-11-08 (3) · KangooG · Claude — combate cuerpo a cuerpo: guardia, bloqueo, parada, empujón y patada
**Qué:**
- **Guardia:** clic derecho mantenido con arma blanca o sin arma (con arma de fuego sigue siendo apuntar): puños
  delante de la cara (sin arma), cuchillo adelante con la izquierda guardando, o el arma larga levantada.
- **Bloqueo:** con el clic derecho, **Espacio mantenido**. Los golpes de frente hacen un 25 % del daño, gastan
  estamina y no te tiran al suelo; sin estamina la guardia se rompe. Si lo pones **justo antes del golpe** (0,28 s) es
  una **parada**: no hace daño y el zombi se tambalea. Con arma de fuego también se bloquea (antebrazo de través con la
  pistola recogida, o el arma larga atravesada).
- **Empujón:** con el clic derecho, **doble Espacio**. Arma corta o sin arma: con las manos (a dos manos, con el
  hombro, la palma izquierda, el antebrazo); arma larga: con el arma (atravesada, con el pomo, culatazo). Aparta y
  desequilibra (con el arma larga, algo de daño).
- **Patada:** **G**, con cualquier arma, de pie: frontal, alta (al pecho) o baja con la izquierda. Daño (12-18),
  empuje y a veces lo tira al suelo; gasta 14 de estamina. Si el blanco está algo lejos, el cuerpo avanza para llegar.
- Varias variantes de cada acción que se alternan al azar (sin repetir la anterior). **Animaciones diseñadas en
  Blender**: `animaciones/blender/combate/` (`diseno_cc.py` → `a_gd_cc.py` → `scripts/jugador/combate_cc.gd`;
  `ver_cc.py` las enseña en Blender sobre el superviviente).
**Archivos:** `scripts/jugador/combate_cc.gd` (nuevo, generado), `scripts/jugador/arsenal.gd` (sección "combate
cuerpo a cuerpo", tecla G, no disparar ni golpear en plena acción), `scripts/jugador/animador.gd` (`_paso_cc`, brazos,
arma, cadera, torso y pierna de la patada), `scripts/jugador/jugador.gd` (Espacio con clic derecho, bloqueo en
`recibir_danio`, más lento bloqueando, ayuda H), `animaciones/blender/combate/*`, `tests/combate.gd` (`--cc=`),
`tests/ejecutar_pruebas.sh` (5 pruebas nuevas), `README.md`.
**Cómo probarlo:** junto al muñeco del inicio o a un zombi: clic derecho (guardia), G (patada), doble Espacio
(empujón); con un zombi atacando, Espacio justo antes del golpe (parada) o mantenido (bloqueo).
**Pendiente / avisos:** no se toca `zombi.gd`: la parada llama a `empujar()` del zombi más cercano al golpe.

## 2026-11-08 (2) · KangooG · Claude — subirse a muros con hueco debajo (techo de los túneles)
**Qué:** no se podía escalar el techo de los túneles (ni un dintel o cualquier muro cuya cara empieza a media altura):
`Jugador.find_vault` buscaba la cara del obstáculo solo a la altura de la rodilla y la cintura y esos rayos pasaban por
el hueco de debajo; solo se podían escalar las paredes laterales, que llegan al suelo. Ahora también mira más arriba
(hasta la cabeza). El techo del túnel de 1,4 m (a la altura del pecho) se sube saltando: se agarra y se encarama; el de
0,8 m, directamente con Espacio.
**Archivos:** `scripts/jugador/jugador.gd` (`find_vault`), `tests/recorrido.gd` (escenarios `dintel`, `dintel_bajo`),
`tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F1 → túneles; ir de frente a la entrada de un túnel y pulsar Espacio.

## 2026-11-08 · KangooG · Claude — plugin Godot AI: dock atascado en "Starting server…"
**Qué:** el plugin lanzaba el servidor bien, pero para comprobar el proceso ejecutaba un PowerShell con dos consultas
seguidas que en este PC se queda colgado para siempre (comprobado: cada consulta sola tarda ~1,5 s; las dos juntas no
terminan nunca), y el dock no pasaba de "Starting server…". Parche de una línea en el plugin: se hacen las dos consultas
por separado.
**Archivos:** `addons/godot_ai/utils/port_resolver.gd` (`capture_process_kill_grant`), `tests/diag_puertos.gd`
(diagnóstico, solo mira), `CLAUDE.md`.
**Pendiente / avisos:** al actualizar el plugin se pierde el parche (buscar "Proyecto Z" en `port_resolver.gd`).

## 2026-11-03 (10) — Desactivado apoyar el arma de lado contra paredes (KangooG)
- KangooG: "que se desactive apoyar el arma en superficies verticales, como paredes" (primero se desactivó por error
  el apoyo horizontal; corregido). Con X ya no se apoya el arma de lado contra una pared o una esquina
  (`Arsenal.APOYO_LATERAL = false`; ponerlo a `true` lo vuelve a activar tal cual). Sigue funcionando apoyarla ENCIMA
  de muros, barreras y alféizares (`APOYO_HORIZONTAL = true`) y tumbado en el suelo. Apuntando junto a una barrera,
  el cuerpo se sigue incorporando para que el arma no la atraviese (`Arsenal.apoyo_delante`).
- **Archivos:** `scripts/jugador/arsenal.gd` (`_apoyo_horizontal`, `_apoyo_lateral`), `scripts/jugador/animador.gd`.

## 2026-11-03 (9) — Apuntando junto a una barrera el arma no la atraviesa (KangooG)
- KangooG: "si me agacho y apunto, que también se ajuste a la altura de la barrera para que no atraviese".
  Apuntando (sin apoyar) con un apoyo delante (`Arsenal.rest_avail`, el mismo que enseña "[X] apoyar el arma"),
  `_arma_sobre_apoyo(..., solo_subir = true)` hace que el cuerpo se incorpore lo justo para que el arma pase ~6 cm por
  encima del borde (nunca baja el cuerpo: si el arma ya pasa por encima, no cambia nada). La cámara sube con él.
  Con el arma apoyada, el ajuste sigue también durante la recarga (antes el cuerpo volvía a bajar y el arma se metía).
- **Archivos:** `scripts/jugador/animador.gd`, `scripts/jugador/arsenal.gd`.
- **Cómo probarlo:** F5: agachado junto a la barrera de tiro, apuntar con clic derecho.
- Arreglado de paso (`scripts/fisica/ragdoll.gd`, `golpe`): disparar a un zombi justo cuando terminaba su ragdoll
  (al levantarse) paraba el juego con un error ("UpperTorso" en un diccionario vacío). Ahora no hace nada.

## 2026-11-03 (8) — El arma apoyada se apoya de verdad (KangooG)
- KangooG: "al apoyar el arma, que el personaje se ajuste a la altura de la estructura: el arma la atraviesa".
  Antes el cuerpo no cambiaba de altura (solo bajaba la cámara) y la altura del arma se estimaba desde los ojos, así
  que agachado tras la barrera el rifle quedaba ~30 cm DENTRO de ella. Ahora `Animador._arma_sobre_apoyo` mide la
  parte de abajo del arma que queda encima del apoyo (esquinas de sus piezas, `_esquinas_arma`) y la deja a ras:
  si flota, el cuerpo baja doblando las rodillas (`rest_baja`); si se mete, agachado se incorpora y los brazos la
  suben en el mismo fotograma (`rest_alza`, nunca la atraviesa). La cámara sube/baja con el cuerpo. `find_rest` usa la
  altura real del arma al apuntar (`REST_DELANTE_PIE` 0,5 / `AGACHADO` 0,15 sobre el centro) y acepta apoyos más
  bajos o más altos porque el cuerpo se ajusta. Medido: queda a ~2 cm del apoyo en ~0,3 s, de pie y agachado.
- **Archivos:** `scripts/jugador/animador.gd`, `scripts/jugador/arsenal.gd`, `tests/combate.gd` (`--logapoyo`,
  `--logarma_y`, `--de_pie`, `--sin_apoyar`).
- **Cómo probarlo:** F5: junto a la barrera de tiro (o un muro a la altura del pecho), apuntar y pulsar X, de pie y agachado.

## 2026-11-03 (7) — Trepar sin acelerón y cámara de arma apoyada (KangooG)
- KangooG: "cuando trepo un obstáculo el jugador hace como un dash hacia delante y la cámara se mueve con él; al
  apoyar el arma, que se haga zoom con el jugador de lado para apuntar y la mira más pequeña".
- **Trepar:** mientras se sorteaba o se trepaba, la inercia (`Jugador._vel_inercia`) se quedaba con la velocidad de
  antes de trepar y, al terminar, el personaje salía disparado hacia delante a esa velocidad. Ahora sigue a la velocidad
  real durante el movimiento (`humanoid_step` en "Physics") y al terminar arranca en la de salida. Además, al
  encaramarse se acerca a la pared con la velocidad que traía y frena sin pasarse (antes se paraba en seco y daba un
  tirón hacia la pared), empieza ya en el primer fotograma (antes se quedaba quieto uno) y la valla ya no acelera al
  que va despacio (salida al menos 5,5 en vez de 7 studs/s). Cámara: sigue con más calma mientras se trepa y al dejar
  de correr ya no se acerca de golpe (solo al apuntar). Medido (`recorrido.gd`, tirón de la cámara): trepar 0,26 → 0,14,
  vallar 0,41 → 0,37, saltos 0,42 → 0,15; el resto igual.
- **Arma apoyada (X):** la cámara se acerca con zoom (`REST_CAM_DIST` 3,4, tumbado 3,0; `REST_CAM_FOV` 50) y se va
  hacia el lado (`REST_CAM_HOMBRO` 3,1): el personaje queda a un lado de la pantalla. La mira se encoge a algo más de la
  mitad (`Arsenal.mira_esc`). Todo con transición suave (`Jugador.rest_cam`).
- **Archivos:** `scripts/jugador/jugador.gd`, `scripts/jugador/arsenal.gd`, `tests/combate.gd` (`--modo=apoyar` se
  agacha antes de apoyar: la barrera es baja; `--logmira`), `tests/visual.gd` (`--logpos`).
- **Cómo probarlo:** F5: trepar a un bloque andando y corriendo; agacharse junto a la barrera de tiro y pulsar X.

## 2026-11-03 (6) — Revisión de la fusión con los zombis v1 de Juan (KangooG)
- Al aceptar el PR #2 de Juan (zombis v1: vista e ingenio) se quedaron fuera cosas nuestras al resolver los choques:
  este archivo había vuelto a la versión del 2026-10-24 (se perdían todas las entradas desde entonces), la ayuda de
  controles (H) perdía "subir a la moto", "H: esta ayuda" y el ajuste de líneas, y en `CLAUDE.md` faltaba el problema
  conocido de la moto. Recuperado todo y unido con lo de Juan (su entrada del 2026-10-24 (5) está en su sitio, F8 en la
  ayuda). El código de los zombis, `zconfig.gd`, el menú de trucos y las pruebas de Juan se fusionaron bien.
- Arreglado en `zombi.gd` (de Juan): con F6 (ver ruido y zombis) el juego se paraba con un error
  (`ImmediateMesh.add_vertex` no existe en Godot 4: es `surface_add_vertex`). Con las 26 pruebas en verde.
- **Archivos:** `CAMBIOS.md`, `CLAUDE.md`, `scripts/jugador/jugador.gd`, `scripts/zombis/zombi.gd` (`_dibujar_cono`).

## 2026-11-03 (5) — Se une Jesús al proyecto (KangooG)
- **Qué:** Jesús entra en el equipo (trabaja con Claude). Añadido a "Reparto" en `CLAUDE.md` (parte por decidir) y un
  mensaje de bienvenida para su Claude en "Mensajes entre los Claude" con las normas para empezar.
- **Archivos:** `CLAUDE.md`, `CAMBIOS.md`.

## 2026-11-03 (4) — Moverse de lado boca arriba (KangooG)
- KangooG: "añádele una animación para moverse de costado boca arriba". Antes, tumbado boca arriba el cuerpo se
  deslizaba quieto. Ahora hace la "gamba" (diseño de Blender: `diseno_mov.BOCA_ARRIBA` → `Movimientos.BOCA_ARRIBA`):
  con las rodillas dobladas da un pasito de lado con el pie de ese lado y luego con el otro, levanta un poco la cadera
  (puente) y la lleva de lado, la baja y arrastra los hombros (la espalda se curva y se endereza); sin arma, las
  manos se apoyan en el suelo junto a la cadera. Vale también hacia la cabeza o hacia los pies. El cuerpo avanza
  continuo y la cadera, los pies y los hombros van a tirones, cada uno en su momento (en el suelo, quietos).
- **Archivos:** `scripts/jugador/animador.gd` (`sup_ph`, `sup_amt`, `sup_dir`, `sup_mov_k`), `movimientos.gd`
  (generado), `animaciones/blender/movimiento/{diseno_mov.py, a_gd_mov.py}`, `tests/visual.gd` (escenario
  `boca_arriba_lado`, `--cam=arriba`, `--logtorso`).
- **Cómo probarlo:** F5, Z para tumbarse, mirar hacia atrás para quedar boca arriba y moverse con A / D.

## 2026-11-03 (3) — Versión 0.4 (KangooG)
- **Qué:** el juego pasa a la versión **V0.4** (`application/config/version` de project.godot; se ve en el menú, la
  pausa y el título de la ventana). Exportación: `../versiones/v0.4/V0.4.exe`, versión de archivo 0.4.0.0.
- **Archivos:** `project.godot`, `export_presets.cfg`, `CLAUDE.md`.

## 2026-11-03 (2) — Escaleras escalón a escalón y marcha más fluida (KangooG)
- KangooG: "en las escaleras el personaje sube andando de 2 en 2; también haz las animaciones más fluidas".
- **Escaleras:** el Animador mira el suelo a lo largo de la marcha (`_mirar_escalera`, cada 3 fotogramas) y reconoce
  una escalera (bordes seguidos, del mismo sentido, con huellas parecidas): entonces la zancada es exactamente un
  escalón por paso andando (dos por paso corriendo) y cada pie apoya en el centro de la huella (`_centro_huella`,
  elegido al despegar). En una escalera se va como mucho a ~3,4 pasos por segundo andando y ~4 corriendo
  (`Jugador`: velocidad limitada a `esc_fondo` × 3,4 / × 8; antes se iba igual de deprisa que por una cuesta y las
  piernas no podían pisar todos los escalones). Bajando, el cuerpo "cae" un instante de escalón en escalón: ya no
  se toma por un salto (`aire_corto_t`, hasta 0,3 s si no es un salto), la marcha sigue.
- **Más fluido:** las tablas de Blender se leen con interpolación cúbica (`Movimientos._ciclica/_abierta`; antes
  lineal: pequeños tirones en cada muestra); cada pie lleva su propio avance (`ap_paso`/`ap_x`, `_avanza_pie`): al
  pasar de andar a correr ningún pie salta de golpe de apoyado a en el aire (el ajuste a la fase global solo en el
  aire); la zancada cambia suave (`anim_zan`); al pararse, el pie que va en el aire termina su paso (`anim_parando`);
  un pie apoyado que se queda muy atrás despega; por delante el pie no apoya más lejos de lo que alcanza la pierna
  (frenando, la cadera se hundía de golpe).
- **Archivos:** `scripts/jugador/{animador.gd, jugador.gd, movimientos.gd (generado)}`,
  `animaciones/blender/movimiento/a_gd_mov.py`, `tests/visual.gd` (`escalera_c`, `--pisadas`, `--curL`), docs.
- **Cómo probarlo:** F5: subir y bajar la escalera andando y corriendo; correr y soltar Shift; pararse.

## 2026-11-03 — Piernas con animación normal hecha en Blender (KangooG)
- KangooG: "el movimiento de las piernas está muy exagerado (el pie procedural); quiero la animación normal, olvidando
  los pasos procedurales al 95 %, en Blender; además el torso avanza primero que las piernas".
  **Qué:** en marcha las piernas ya no las decide el juego paso a paso: cada pie sigue una animación cíclica fija
  respecto a la cadera, diseñada en Blender (`diseno_mov.PIERNAS` → `Movimientos.PIERNAS`), para andar, correr y
  agachado (mezcladas según la velocidad); hacia atrás se reproduce al revés y de lado con pasos laterales. Lo
  procedural queda en lo mínimo: el pie se pone a la altura del suelo que pisa (escalones, cuestas), el de apoyo se
  queda clavado donde pisó y, al arrancar, una mezcla corta desde los pies parados. Las piernas se mueven a la vez que
  el cuerpo (antes los pies esperaban anclados y el torso se adelantaba); además menos inclinación del torso al
  acelerar y a la carrera. Zancadas algo más cortas (`RITMO`) para que la pierna de apoyo no se estire de más.
  Medido: tirón de los pies ~3 veces menor (`fluidez.py`: pies_p98 6308 andando y 5924 corriendo, antes 19182 y
  21029), pasos siempre alternos, menos resbalones (`recorrido.gd`).
- **Archivos:** `animaciones/blender/movimiento/{diseno_mov.py, a_gd_mov.py, ver_mov.py}`, `scripts/jugador/
  {movimientos.gd (generado), animador.gd}`, `tests/visual.gd` (escenarios `atras`, `diagonal_atras`; `--geom`),
  `animaciones/blender/LEEME.md`, `CLAUDE.md`.
- **Cómo probarlo:** F5: andar, correr, agachado, hacia atrás (S), de lado con un arma, escaleras y saltar corriendo.
- **Pendiente / avisos:** parado se siguen dando pasitos de ajuste (girar sin moverse). Los zombis no cambian.

## 2026-11-02 (2) — Pasos siempre en orden, levantarse del suelo y guardar el arma para trepar (KangooG)
- KangooG: "arregla las piernas, que los pasos se hagan en orden; cuando corre las dos piernas se van adelante".
  Los pasos ya no se deciden "cuando un pie se queda atrás": un **reloj de la marcha** avanza con la distancia
  recorrida y cada pie despega y apoya en su momento, SIEMPRE alternando (la izquierda apoya en φ = 0,25 y la derecha
  en 0,75). Ritmo diseñado en Blender (`diseno_mov.RITMO` → `Movimientos.ZANCADA` / `FRACCION_AIRE`): zancada según
  la velocidad (como personas reales a escala) y fracción del ciclo en el aire (andando 0,40, con apoyo doble;
  corriendo 0,70, con vuelo). Acelerando o frenando, pasos más cortos y seguidos; en el aire el reloj se para y al
  aterrizar arranca con el pie que quedó atrás; un pie al que la pierna ya no llega despega antes (sin repetir pie).
  La fase del cuerpo es ese mismo reloj. Parado, los pasos de ajuste como antes. Medido: 0 pasos repetidos con el
  mismo pie andando, corriendo, agachado, girando y de lado.
- **Levantarse boca arriba**: ya no rueda a boca abajo (el cuerpo giraba raro); se sienta con la mano derecha
  apoyada detrás, mete los pies, echa el peso adelante y se levanta hacia los pies (`Jugador.set_stance` gira el
  cuerpo 180° y lo avanza hasta los pies, `L.levanta_arriba`; el Animador lo compensa: no se ve el giro).
  **Boca abajo**: flexión (el pecho sube con los brazos), a cuatro patas, adelanta el pie derecho, se incorpora
  apoyando la mano en la rodilla y de pie (`Movimientos.LEVANTAR`). También al levantarse tras un ragdoll boca abajo.
- **Trepar con las dos manos**: al encaramarse a algo alto se guarda el arma (`Arsenal.guardar_para_trepar`) y al
  terminar se vuelve a sacar (`sacar_tras_trepar`); también tras colgarse de una cornisa (al subir o al soltarse).
- Pruebas: `tests/visual.gd --escenario=trepar_rifle|levantarse_boca_arriba|levantarse_boca_abajo`, `--logarma`.

## 2026-11-02 — Andar, correr, agacharse, saltar, tumbarse, reptar, vallas y trepar hechos en Blender (KangooG)
- KangooG: "haz las animaciones de correr, saltar, agacharse, acostarse, colgarse y trepar en Blender… que se vean
  súper fluidas y naturales (ahora se ven rígidas, rústicas, con transiciones bruscas)", con los pies adaptándose al
  suelo como hasta ahora. Todas a la vez.
- Diseño en `animaciones/blender/movimiento/diseno_mov.py` (claves de animación, vistas en Blender sobre el
  personaje nuevo con `ver_mov.py` / `ver_tierra.py`) → `scripts/jugador/movimientos.gd` (`Movimientos`, generado).
- **Andar / correr / agachado**: ciclos por la fase de la marcha (`Animador._ciclo`, `_brazo_ciclo`): la pelvis sube
  y baja (corriendo baja al apoyar, como de verdad; antes subía), se desplaza sobre el pie de apoyo, gira con la
  pierna que avanza y cae del lado de la pierna en el aire; los hombros giran al revés y la cabeza se queda estable;
  brazos con retraso y codo que acompaña (corriendo, a ~90° bombeando); agachado, brazos adelantados y listos.
  Forma del paso (`_curva_pie`): el pie despega girando sobre la punta y apoya con el talón, empalmado con el apoyo
  (antes daba un salto), corriendo el talón sube al glúteo y la pierna alcanza y "araña" antes de apoyar.
  La fase de la marcha se corrige más suave y la bajada de la cadera es un muelle amortiguado (antes, un golpe en
  cada apoyo al correr). Medido (`tests/fluidez.py`): tirón del cuerpo andando −60 %, agachado −40 %.
- **Salto** parado y corriendo por fases (`Movimientos.SALTOS`, `air_tj`): los brazos salen desde atrás (de coger
  impulso) y suben por delante; rodillas recogidas; al caer, piernas adelante y brazos abiertos.
- **Tumbarse / levantarse**: se agacha, apoya la rodilla izquierda, la derecha, las manos y se estira; las piernas
  van por IK a sitios del suelo (`Movimientos.TUMBAR`): antes las piernas iban por ángulos fijos y los pies y las
  rodillas se metían en el suelo o flotaban. **Reptar**: la rodilla sube por el costado a ras de suelo (antes el pie
  se levantaba hacia el cielo). Medido con `tests/visual.gd --contactos`.
- **Vallas y trepar**: curvas suaves (`Movimientos.SORTEAR`) en vez de senos recortados (que daban tirones al
  empezar y al acabar). **Colgado**: quieto se mece despacio y busca apoyo con una rodilla y luego la otra;
  desplazándose, las piernas siguen a las manos con retraso y la cadera se balancea (`Movimientos.COLGADO`).
- Pruebas nuevas: `tests/visual.gd --escenario=agachado_andar|agachado_correr|transiciones|salto_parado|salto_correr`,
  `--registro=<csv>` (+ `tests/fluidez.py`) y `--contactos`. Suite completa: TODO BIEN.

## 2026-11-01 (8) — Personaje nuevo hecho en Blender y pistola a tamaño real (KangooG)
- KangooG: "haz el modelo del personaje en Blender, el triple de mejorado manteniendo todo el arte" (más detalle,
  mismo estilo y "que parezca otro personaje"; guantes con dedos marcados).
- **Superviviente nuevo** (`animaciones/blender/personaje/personaje.py` → `modelos/superviviente.glb`): mismo estilo
  de muñeco cuadrado R15 con bordes biselados y ~200 piezas (antes 48): gorro de lana, barba, ojos con iris, pañuelo
  al cuello, chaqueta gris azulada, chaleco porta-placas coyote (portacargadores, radio con antena, vaina del
  cuchillo, parche naranja), coderas, guantes con dedos y nudillos, cinturón con bolsas (botiquín, cantimplora),
  pantalón de carga verde oliva con rodilleras, funda de pistola en el muslo derecho, botas con cordones y puntera y
  mochila con esterilla, botella y mosquetón. Las mallas se juntan por pieza y material (~45 mallas).
- `RigPersonaje.modelo` ("" = el muñeco clásico por código; "superviviente" = el de Blender). Lo usan el jugador
  (`Jugador._ready` rehace el rig) y el menú principal. Mismo esqueleto, mismas piezas y tamaños (cajas de impacto,
  ragdoll, animaciones). **Los zombis no cambian** (siguen con el muñeco clásico y lo tiñen en `Zombi._aspecto`).
- **Pistola al 65 %** (`ModelosArmas.ESCALA`): medía ~31 cm al lado de un personaje de 1,76 m; ahora ~20 cm, como una
  real. Se escalan las piezas, los puntos (boca, apoyo de la izquierda, cargador) y la empuñadura (`Armas.grip`).

## 2026-11-01 (7) — El arma larga ya no atraviesa el pecho al sacarla ni al guardarla (KangooG)
- KangooG: "el arma larga atraviesa el pecho cuando se desenfunda". El rifle (y escopeta y fusil) iba de la espalda a
  la posición de uso girando por dentro del pecho (hasta 0,37 studs), y el brazo, que lo sigue con suavizado, atajaba
  aún más por dentro.
- Recorrido nuevo por claves (`Armas.draw("Rifle").camino`, respecto al UpperTorso): sale de la espalda por el costado
  derecho, vertical detrás del hombro, baja el cañón hacia delante junto al costado (cargador hacia delante, culata
  atrás) y ya delante se endereza hasta la posición de uso. Al guardarla, el mismo camino al revés. Curva suave
  (cúbica) por las claves: `Animador._por_claves`. Mientras saca/guarda, el brazo derecho sigue al arma sin retraso
  (`arm_rate` 60). El empuje fuera del torso solo actúa en el último tramo, delante del cuerpo.
- Medido (`tests/combate.gd --choque_arma --todo_cuerpo`, con `--arma=Escopeta|Francotirador` y `--modo=cambiar`):
  0 al sacar y al guardar el rifle, la escopeta y el fusil.

## 2026-11-01 (6) — Las armas de fuego ya no atraviesan el torso (KangooG)
- KangooG: "el arma atraviesa el torso". Medido con `tests/combate.gd --choque_arma [--pitch=<rad>]` (nuevo: mira
  las piezas del arma contra el pecho y la barriga): la culata del rifle se metía hasta 0,37 studs en el pecho con el
  arma baja, al apuntar y al recargar (con las posturas nuevas el pecho gira más, y el arma no lo seguía).
- `Animador._arma_de_fuego_fuera`: lo que quede dentro del pecho o la barriga sale siempre HACIA DELANTE, hasta la
  cara delantera del torso (la culata queda apoyada en el hombro, sin saltos), usando el pecho tal y como quedará en
  ese fotograma. Puntos de muestra por arma en `_puntos_arma` (se calculan una vez). No se aplica tumbado ni en la
  moto; al sacar/guardar el arma solo en el tramo de delante del cuerpo. Ahora: ≤ 0,05 studs en pose (≤ 0,11 un
  instante al pasar a apuntar mirando muy arriba).
- `tests/combate.gd`: también `--cam_az=<grados> --cam_alt --cam_dist` para verlo de cerca desde cualquier lado.

## 2026-11-01 (5) — Animaciones en Blender, grupo 1 (armas a pie), parte 1: posturas con armas de fuego (KangooG)
- KangooG pidió hacer TODAS las animaciones en Blender, en este orden: armas a pie, andar/correr/agacharse,
  saltos/vallas/cornisas y el resto de la moto. Primera parte: las posturas de pie con pistola y rifle (arma baja,
  desde la cadera, apuntando y corriendo).
- Diseñadas en Blender sobre el superviviente (`animaciones/blender/pie_Rifle.blend`, `pie_Pistola.blend`,
  `diseno_pie.py`): rifle con la culata en el hombro, el codo derecho más alto, el izquierdo bajo el guardamanos, el
  cuerpo de perfil y la mejilla en la culata; pistola en isósceles con los dos brazos estirados y el pecho de frente.
- Al juego: `scripts/jugador/posturas_pie.gd` (generado) y `Animador._paso_postura_pie` (pecho, cabeza y codos; las
  manos siguen por IK sobre el arma). Sustituye al antiguo giro "blade". Suite completa: TODO BIEN.

## 2026-11-01 (4) — Moto: poses de apuntado hechas en Blender (KangooG)
- A pedido de KangooG ("el brazo se mueve rarísimo, ¿puedes hacer las animaciones en Blender?"): el piloto y la moto
  se montan en Blender 4.2 (`animaciones/blender/piloto.blend`, ver `LEEME.md`) y las poses de apuntado con la pistola
  se diseñan ahí (`poses.py`): antebrazo y pistola en la línea de tiro con la muñeca neutra, codo algo flexionado,
  cruzando por delante del pecho a la izquierda, por fuera del hombro hacia atrás, cintura y cuello girando hacia la
  mira; más la pose "recogida" para pasar el arma por delante del pecho.
- Se exportan a `scripts/jugador/poses_moto.gd` (rejilla 28 ángulos x 7 cabeceos, generado) y el Animador las mezcla
  según hacia dónde apuntas (interpolación entre articulaciones: el brazo describe arcos naturales en vez de ir en
  línea recta); la muñeca corrige unos grados para que el cañón vaya exacto a la mira. La izquierda sigue en el manillar.
- `tests/moto.gd --modo=exportar` vuelca el piloto y la moto para Blender. Suite completa: TODO BIEN.
- La carpeta `animaciones/blender` tiene `.gdignore` (Godot no la importa). El .blend pesa ~5 MB.

## 2026-11-01 (3) — Moto: el brazo gira con naturalidad al apuntar (KangooG)
- Al girar la mira de un lado a otro la mano iba muy rápida y brusca (más de 70 studs/s de golpe). Ahora el ángulo,
  la cintura y el cuello van con muelles con velocidad y aceleración máximas: arrancan y frenan con suavidad (media
  vuelta ~0,7 s; la mano a ≤ 12 studs/s girando).
- Hacia delante o desde la derecha el brazo barre por su camino natural; solo al cruzar por detrás a la izquierda pasa
  el arma por delante del pecho, ahora más despacio (0,7-1,25 s según el recorrido) y sin cambios bruscos al final.
- Prueba nueva `tests/moto.gd --modo=giros` (saltos bruscos de la mira; mide velocidad y aceleración de la mano), en
  ejecutar_pruebas.sh.

## 2026-11-01 (2) — Moto: apuntado con UN SOLO BRAZO (KangooG)
- A pedido de KangooG ya no se pasa el arma a la mano izquierda: se apunta y dispara SIEMPRE con el brazo derecho
  en 360° y la izquierda nunca suelta el manillar.
- Hacia la izquierda el brazo derecho cruza por delante del pecho (la cintura gira más, hasta ~70°); hacia atrás va
  por encima del hombro derecho. Por detrás a la izquierda, al pasar de una postura a otra, el arma pasa por delante
  del pecho con el cañón arriba (0,34 s, sin disparar en ese instante).
- Prueba `tests/moto.gd --modo=apuntar360 [--mover]` ahora comprueba también que la izquierda sigue en el manillar.

## 2026-11-01 — Moto: apuntado libre en 360° (KangooG)
- Desde la moto ya se apunta y dispara en CUALQUIER dirección (también hacia atrás y muy arriba/abajo); se quitan
  los límites `Arsenal.MOTO_IZQ/DER/ARRIBA/ABAJO`.
- Animaciones nuevas (Animador, "APUNTADO EN LA MOTO"): el brazo se estira desde su hombro hacia la mira, la cintura
  gira y la cabeza mira por encima del hombro. Hacia la izquierda y detrás por la izquierda el arma pasa a la mano
  IZQUIERDA (la derecha al acelerador): el torso se pone de frente, el arma rodea el cuerpo con el cañón arriba, la
  otra mano la coge delante del pecho y la que la soltó vuelve al manillar (0,34 s, sin disparar en ese instante).
- La cámara va al hombro del brazo que dispara (antes, apuntando atrás con la derecha, el cuerpo tapaba el arma).
- Arreglado: con muchos disparos seguidos salía "Lambda capture ... was freed" (Efectos._borrar_en).
- Prueba nueva `tests/moto.gd --modo=apuntar360 [--mover]` (en ejecutar_pruebas.sh). Suite completa: TODO BIEN.

## 2026-10-30 (2) · KangooG · Claude — mecánica de trepar cuestas ELIMINADA

Pedido: "elimina esa mecánica, es demasiado tortuoso, muchos fallos".

- Quitada entera: trepar con las manos, posturas (tumbado, sentado, de costado, resbalar), Espacio para agarrarse,
  C en la cuesta, la cámara especial de la cuesta, las armas a una mano en la cuesta y la zona "Cuesta de 50°" de F1.
- Las cuestas vuelven a ser como antes: se suben andando.
- Se quedan los arreglos generales que salieron de ella: al levantarse de una caída ya no da un salto a mitad de rodar;
  el brazo se aparta de las paredes sin saltar; los pies no se quedan clavados en una cuesta muy empinada.
- Pruebas de la cuesta quitadas; queda `recorrido --escenario=derribo_llano` (levantarse sin tirones). TODO BIEN.
- El diseño queda guardado en el documento del proyecto `mecanica-pendientes.md` por si se retoma.
- Archivos: scripts/jugador/jugador.gd, animador.gd, arsenal.gd, scripts/ui/menu_trucos.gd, tests/recorrido.gd,
  tests/ejecutar_pruebas.sh, CLAUDE.md.

## 2026-10-30 · KangooG · Claude — cuestas: prueba completa detalle por detalle y arreglos

Pedido: "prueba la mecánica completa detalle por detalle y arréglala totalmente".

Se probó con 22 recorridos automáticos (`tests/recorrido.gd --escenario=cu_*` y `cuesta*`) y un auditor que mide
en cada fotograma: piezas del cuerpo metidas en el escenario, tirones, cuerpo separado, disparos que no van a la mira.
Todos en verde, también a 30 FPS. Lo encontrado y arreglado:

- **Disparos en la cuesta:** el arma quedaba torcida (hasta 75° de la mira): la mano que la lleva perdía la orientación
  mientras llegaba a su sitio. Ahora apunta a la mira (≤ 3°).
- **De costado no disparaba:** el cuerpo miraba al lado contrario de la cámara y el disparo se bloqueaba. Ahora mira
  hacia el lado de la cámara y dispara hacia fuera.
- **Manos y pies metidos en la cuesta:** muelles de las articulaciones demasiado blandos (se quedaban atrás) y apoyos
  muy bajos. Ahora van firmes, más altos y nunca por dentro del suelo (−85 %).
- **Bajar desde arriba:** el personaje se quedaba clavado en el borde (el canto de la rampa se tomaba por una cuesta
  al revés). Ahora: si pisas la cuesta sin agarrarte, **resbalas sentado** hasta abajo; **Espacio te agarra**.
- **Agarrarse desde arriba:** Espacio en lo alto te descuelga por el borde de cara a la cuesta para bajar.
- **Agarrarse parado al pie:** el personaje va solo hasta la cuesta (antes se tumbaba en el suelo).
- **Al pie sin agarrarse:** se para delante como ante una pared (antes subía un paso y andaba en el sitio).
- **Cuestas de más de 62°:** avisa "Demasiado empinado" en vez de saltar.
- **Derribado en la cuesta:** deja de estar agarrado y cae rodando de verdad.
- **Al levantarse de cualquier caída (también en llano):** a mitad de rodar el cuerpo daba un salto; arreglado.
- **Cuchillo en la cuesta:** la mano ya no se mete dentro de la cuesta.
- **Al caer por el borde lateral:** sin saltos de la mano ni de la cámara.
- **Ayuda (H)** actualizada con todos los controles de las cuestas.
- Archivos: scripts/jugador/jugador.gd, animador.gd, arsenal.gd, scripts/fisica/ragdoll.gd, tests/recorrido.gd,
  tests/ejecutar_pruebas.sh, CLAUDE.md.

## 2026-10-29 (3) · KangooG · Claude — cuestas (bajar, entrar, Espacio, arma) y moto (disparo, atascos, levantarla)

Pedido: "al bajar la cuesta se deforma; el arma no se mueve libre (tumbado, a una mano siguiendo la cámara y la otra
en la estructura); bajando de frente las piernas no van con el cuerpo; al empezar a subir se mete bajo el piso (que
primero se incline) y un poco más erguido"; "desde la moto el brazo traspasa el cuerpo y la bala sale rarísimo; la
moto se trababa sin marcha atrás; al levantarla y montarme se caía al frente y caí al vacío; triplica su velocidad en
cuestas"; "para montarse y levantarla, estar al lado; un botón para subir la cuesta, que no sea automático".

- **Cuestas:** pasos nuevos por distancia, en pares diagonales: el par que se queda medio paso atrás da el paso. Va
  sincronizado subiendo, bajando y de lado, y nunca se estira de más (se acabó la deformación al bajar).
- **Entrar:** el cuerpo ya no se mete en el suelo (el plano de la cuesta se mide sobre la cuesta de verdad); parte de
  la postura de pie y primero se inclina; un poco más erguido al trepar.
- **Espacio para agarrarse:** las cuestas empinadas ya no se trepan solas. Sin pulsar Espacio no se suben andando
  (aviso en pantalla). Espacio delante de la cuesta (o encima) = agarrarse.
- **Arma en la cuesta:** quieto (tumbado, sentado, de costado) la pistola va a una mano y sigue a la cámara; la otra
  mano se apoya en la cuesta.
- **Moto, disparo:** solo se dispara donde el brazo llega de verdad (delante, derecha y algo atrás por la derecha;
  poco a la izquierda; ni muy arriba ni muy abajo). Fuera de eso no dispara.
- **Moto, atasco entre bloques:** marcha atrás ahora la saca (el piloto empuja con los pies y aguanta el peso).
- **Moto, levantarla:** busca dónde cabe de pie (antes, en el hueco entre bloques, quedaba con una rueda dentro del
  bloque, daba vueltas y atravesaba el suelo con el piloto). Red de seguridad si alguna vez atraviesa el suelo.
- **Moto, cuestas:** la rueda no empuja más de lo que agarra: cuestas de más de ~40° ya no se suben acelerando.
- **Moto, subirse/levantarla:** solo desde un lado (no delante ni detrás). Bajarse marcha atrás la deja en la pata.
- Pruebas nuevas: moto `fila`, `levantar_hueco`; recorrido `cuesta_sin_espacio`, `cuesta_bajar`. TODO BIEN.
- Archivos: scripts/jugador/animador.gd, jugador.gd, arsenal.gd, scripts/vehiculos/moto.gd, tests/moto.gd,
  tests/recorrido.gd, tests/ejecutar_pruebas.sh, CLAUDE.md.

## 2026-10-29 (2) · KangooG · Claude — cuestas: trepar erguido, cámara libre y tecla C

Pedido: "trepar hacia el frente parece una araña, la cámara se bloquea horrible, que sea mucho más libre; que solo
se cambie de postura con C para salir de la posición de frente; el resto con el ratón".

- **Trepar:** erguido, como escalando: pies juntos bajo la cadera, rodillas hacia delante (nada abiertas), codos abajo
  y la mano que sube estirada a por el siguiente apoyo.
- **Tecla C:** al entrar en la cuesta estás DE FRENTE (trepas al moverte, te tumbas quieto) y girar la cámara ya no te
  cambia la postura. C te saca: desde ahí la cámara elige (abajo = sentado, W resbala; a un lado o arriba = de
  costado, A/D anda de lado). C otra vez: de frente.
- **Cámara:** la normal de ir a pie. Gira alrededor del pecho del personaje (antes, de un punto separado de la cuesta:
  "giraba alrededor de algo"), ya no se fuerza la vista hacia el personaje, al chocar con la cuesta se acerca rápido
  pero sin saltos y la cuesta de detrás no vuelve transparente al personaje.
- Prueba nueva `recorrido --escenario=cuesta_frente` (mirar a los lados de frente no cambia la postura). TODO BIEN.
- Archivos: scripts/jugador/animador.gd, jugador.gd, tests/recorrido.gd, tests/ejecutar_pruebas.sh, CLAUDE.md.

## 2026-10-29 · KangooG · Claude — animación de las cuestas rehecha, moto sin atascos y con suspensión

Pedido: "la moto se queda estancada, no parece que tiene suspensión, las animaciones de la mecánica nueva son
horribles y el personaje es muy tieso: reinventa la animación".

- **Cuestas, animación nueva:** cada postura se diseña sobre la propia cuesta (cadera colocada en el mundo, columna
  casi paralela a la cuesta). Trepar = a cuatro patas pegado a la cuesta, manos y pies en diagonal, con vaivén de
  cadera, giro de hombros y respiración; tumbado = boca abajo sobre los antebrazos, piernas estiradas; sentado = de
  espaldas, rodillas arriba y pies clavados; de costado = echado hacia la cuesta con la mano de arriba apoyada.
  Pies y manos se apoyan en el suelo real (arriba del todo se agarra al borde).
- **Por qué se veía tieso:** la corrección "la cabeza no entra en la pared" tomaba la cuesta por una pared y enderezaba
  el torso hasta 40°. En la cuesta ya no se aplica.
- **Cámara sentado mirando abajo:** antes no se veía al personaje (la cuesta de detrás pegaba la cámara a la nuca);
  ahora sube por la cuesta y se le ve.
- **Moto atascada:** contra el bloque de 20 cm, despacio o en diagonal, se quedaba con una rueda arriba y otra abajo
  para siempre (el canto del bloque se tomaba por pared). Ahora sube bordillos de hasta ~22 cm despacio y ~24 deprisa;
  los de 40 cm siguen siendo un muro (marcha atrás con S).
- **Suspensión de la moto:** horquilla que se hunde (las botellas suben por las barras), basculante que gira con los
  amortiguadores, el cuerpo y el piloto se mueven sobre las ruedas: se hunde al frenar, se agacha al acelerar, absorbe
  baches, bordillos y aterrizajes y rebota un poco.
- Pruebas nuevas: `moto --modo=atasco` (4 casos) y `--modo=suspension`. Todas: TODO BIEN.
- Archivos: scripts/jugador/animador.gd, jugador.gd, scripts/vehiculos/moto.gd, modelo_moto.gd, tests/moto.gd,
  tests/recorrido.gd, tests/ejecutar_pruebas.sh, CLAUDE.md.

## 2026-10-28 (3) · KangooG · Claude — versión V0.3.5

Pedido: "pon en todos lados que estamos en la V0.3.5".

- project.godot: `application/config/version = "0.3.5"` (fuente única de la versión).
- Menú principal (abajo a la derecha) y menú de pausa (bajo "PAUSA"): "V0.3.5 · prototipo", leído de project.godot.
- Título de la ventana: "Proyecto Z · V0.3.5".
- Exportación (export_presets.cfg): `../versiones/v0.3.5/V0.3.5.exe`, versión del archivo y del producto 0.3.5.0, producto "Proyecto Z".
- CLAUDE.md: ruta del ejecutable actualizada. (Las menciones antiguas "v0.4" en comentarios son historia y se dejan.)

## 2026-10-28 (2) · KangooG · Claude — animación de las cuestas fluida

Pedido: "no se ve nada fluida la animación de la mecánica nueva".

- Piernas, brazos y cadera en la cuesta van con un "muelle" (amortiguado crítico): aceleran y frenan hacia su pose en vez de saltar. Al salir de la cuesta el muelle pasa poco a poco a la animación normal (0,8 s), sin salto final.
- Los pasos de manos y pies solo empiezan al principio de su parte del ciclo (antes, al cambiar de postura, un pie "saltaba" al sitio nuevo en un fotograma).
- Al entrar andando, el pie que iba por el aire termina su paso hasta la cuesta en vez de pararse en seco.
- De costado, la mano de fuera descansa sobre el muslo (antes colgaba contra la cuesta y daba tirones al chocar).
- Las manos cambian entre arma y cuesta con muelle (antes a velocidad fija, con arranque y parada bruscos).
- Medido con `--suavidad`: los tirones de la cuesta bajan de ~0,9 a ≤0,5 studs por fotograma (como andar normal). Pruebas: TODO BIEN.
- Archivos: scripts/jugador/animador.gd (y jugador.gd, tests/recorrido.gd del cambio anterior).

## 2026-10-28 · KangooG · Claude — ragdoll rígido, levantarse siempre, choques de moto realistas y trepar cuestas
**Qué:**
- **Ragdoll con músculos de verdad:** antes el cuerpo se "derramaba como agua". Ahora cada articulación lleva músculos
  que resuelve el motor de física (muelles de `Generic6DOFJoint3D`, rígidos y sin temblar) y cada músculo mueve todo lo
  que cuelga de él (la cadera sostiene el tronco). Vivo, el cuerpo nunca se desarma; muerto, se apaga poco a poco.
  Medido: los músculos llegan a su postura con 5-20° de error (antes 35-50°) y las articulaciones ya no se estiran.
- **Levantarse:** antes esperaba a que el cuerpo estuviera quieto del todo (a veces nunca). Ahora se prepara (manos bajo
  los hombros o rodillas arriba) y se levanta enseguida, con un tope de seguridad; la animación es algo más rápida.
  Busca un sitio libre para ponerse de pie (no dentro de la moto caída) y la moto ya no sale disparada al levantarse
  a su lado. Derribo: de pie en ~4 s (antes ~4); caída de 12 m: ~5 s (antes 8,5).
- **Moto:** el piloto sale despedido según la velocidad y el choque: contra un bloque bajo a ~55 km/h vuela ~15 m por
  encima del manillar; contra una pared alta se estrella contra ella. Bordillos y bloques de hasta ~20 cm ya no te tiran
  (se suben de un golpe y se frena). La moto cae según el golpe (vuelta de campana, rebote de lado, vuelco) y no
  siempre igual. Al levantarla, el jugador va por el lado en que está. Arreglado de paso: la moto podía "trepar"
  bloques de 40 cm (fallo al tantear el suelo con las ruedas).
- **Cuestas de 35° a 60°:** trepa con las manos (manos y pies alternos; con la pistola solo apoya la otra mano y va más
  lento). Quieto, la postura la elige la cámara: mirando cuesta arriba se tumba (repta con clic derecho o S y cerca de
  lo alto se asoma), a un lado se pega de costado (W/S anda de lado), cuesta abajo se sienta de espaldas con los pies
  clavados (W: se deja resbalar sentado). Se puede disparar con la pistola en todas. Las posturas no gastan estamina y
  la recuperan a la mitad; trepar la gasta y sin estamina resbala un poco y descansa. Más de 60°: resbala. Solo armas
  de una mano. Zona nueva en F1: "Cuesta de 50°".
**Archivos:** `scripts/fisica/ragdoll.gd`, `scripts/jugador/{jugador,animador,arsenal}.gd`, `scripts/vehiculos/moto.gd`,
`scripts/ui/menu_trucos.gd`, `tests/{moto,ragdoll,recorrido}.gd`, `tests/ejecutar_pruebas.sh` (8 pruebas nuevas),
`CLAUDE.md`.
**Cómo probarlo:** F1 → "Cuesta de 50°" y subir con W; quieto, girar la cámara arriba/al lado/abajo; con la pistola (1)
disparar sentado y tumbado. F1 → zona de motos: chocar contra los bloques y el muro a distintas velocidades. Recibir
golpes fuertes / caer desde alto para ver el ragdoll y cómo se levanta.
**Pendiente / avisos:** Juan: vuestros zombis usan el mismo ragdoll (más rígido ahora; la API no cambia). Ver mensaje
en CLAUDE.md.

## 2026-10-27 (4) · KangooG · Claude — sonido nuevo del rifle de asalto y fin de la saturación
**Qué:** el disparo del rifle sonaba "roto": el archivo anterior eran dos soplidos de ruido sin golpe, y además todos
los sonidos se reproducían +6 dB (+3 dB más de cerca) por encima de archivos que ya están casi a 0 dBFS, así que
saturaban, sobre todo en ráfaga. Ahora:
- 4 variantes nuevas (`Rifle_1..4.ogg`), **secas como la pistola** (pedido de KangooG): disparo real de un AR-15 de la
  misma serie de grabaciones que la pistola (michorvath, CC0), con la cola recortada (~0,4 s, sin eco) para que cada
  disparo de la ráfaga se oiga separado; varían un poco de tono y brillo y no se repite la misma dos veces seguidas.
- Volumen: los sonidos 3D suenan a −4 dB sin ganancia extra de cerca, y hay un limitador en el bus Master (se añade
  al empezar, `Efectos._limitador_master`). Medido en una ráfaga del juego: pico −2,5 dBFS, 0 muestras saturadas.
  Al quitar la saturación, el resto de sonidos (pasos, golpes...) también se oyen más limpios y algo más bajos.
**Archivos:** `sonidos/Rifle_1..4.ogg`, `scripts/armas/efectos.gd`, `docs/SONIDOS.md`, `CLAUDE.md`.
**Cómo probarlo:** F5, rifle (2) y disparar a ráfagas; comparar con la pistola.

## 2026-10-27 (3) · KangooG · Claude — versión V0.3 en el menú
**Qué:** el menú principal muestra "V0.3 · prototipo" (abajo a la derecha) en vez de "v0.2".
**Archivos:** `scripts/ui/menu_principal.gd` (`VERSION`).
**Cómo probarlo:** abrir el juego y mirar la esquina inferior derecha del menú.

## 2026-10-27 (2) · KangooG · Claude — pulido de la jugabilidad: sonido, efectos, cámara, inercia, HUD y ragdoll
Antes se hizo una revisión jugando escenarios con la cámara del juego y midiendo (`docs/REVISION_JUGABILIDAD.md`,
19 puntos). KangooG eligió: armas y sonido, interfaz, movimiento, cámara y un ragdoll mucho más exagerado.
**Qué:**
- **Sonidos reales** (46 archivos `.ogg`, Freesound CC0, créditos en `docs/SONIDOS.md`): disparos de cada arma,
  corredera/cerrojo, recargas, recámara vacía, sacar arma, casquillos cayendo, golpes, rebotes, impactos, **pasos**
  (12 variantes, volumen según andar/correr/agachado), aterrizaje y cuerpo que cae. Carpeta `sonidos/`, nombres
  `Tipo_n.ogg`: para añadir una variante basta con soltar `Tipo_<n+1>.ogg` ahí. Sin archivo se usa el sintetizado de
  antes (y sin ventana, en las pruebas `--headless`, siempre el sintetizado). Se precargan al empezar (adiós al tirón
  del primer disparo).
- **Disparo:** fogonazo con destello en estrella, luz y humo (fuerza según el arma); **casquillos** que salen
  despedidos, rebotan y suenan (escopeta: cartucho rojo al bombear; francotirador: al abrir el cerrojo). Agujeros de
  bala con material compartido (menos coste).
- **Movimiento:** **inercia** al correr/andar: ya no se para en seco (frena en ~0,5 s corriendo, ~0,2 s andando;
  `ZConfig.PLAYER.Frenada`) y contra una pared se corta. `InfiniteStamina` ahora es `false` también en el editor
  (F4 sigue activándola para probar).
- **Cámara:** acercarse al apuntar, tumbarse o dejar de correr es suave (`dist_suave`); de espaldas a una pared ya no
  se mete en la cabeza (se acerca al instante y el personaje se difumina); al apuntar, un poco más lejos y más al hombro;
  tumbado, más alta y adelantada para ver por encima de las piernas.
- **Interfaz:** textos con contorno y sombra (munición, avisos, huecos); barras con rótulo "VIDA n" / "ESTAMINA";
  barra de armas abajo a la derecha, se oculta sola a los 3 s (vuelve al cambiar de arma o recoger); la ayuda de
  controles se muestra/oculta con **H** (al empezar sale "H: ver los controles"). **Daño** (`scripts/ui/hud_danio.gd`,
  `HudDanio`): viñeta roja al recibir golpes, latido con poca vida, arcos que señalan de dónde viene el golpe y
  pantalla de muerte con cuenta atrás.
- **Ragdoll mucho más exagerado** (a pedido de KangooG): constantes `EXAGERA` (2.0) y `NERVIO` (2.0) en `ragdoll.gd`
  que agrandan y aceleran todos los gestos; músculos más fuertes (`KP` 680, `ACEL_MAX` 480); al caer manotea y patalea;
  en el suelo se retuerce con convulsiones (se encoge de golpe y se estira); muriendo, espasmos frecuentes en tronco,
  cabeza, brazos y piernas durante ~6 s; la caída larga hace un molinillo enorme. Medido: el cuerpo se mueve 10-30 veces
  más que antes en el suelo (`tests/ragdoll.gd` imprime ahora `mov=`).
**Archivos:** `scripts/armas/efectos.gd`, `scripts/jugador/{jugador,arsenal,animador}.gd`, `scripts/config/zconfig.gd`,
`scripts/fisica/ragdoll.gd`, `scripts/ui/hud_danio.gd` (nuevo), `sonidos/` (nuevo), `docs/SONIDOS.md`,
`docs/REVISION_JUGABILIDAD.md`, `tests/recorrido.gd` + `tests/escena_recorrido.tscn` (nuevos: recorridos con la cámara
del juego que miden tirones de cámara, pies que patinan, etc.), `tests/ragdoll.gd`.
**Cómo probarlo:** F5 y: disparar cada arma (sonido, fogonazo, casquillos); correr y soltar W (frena en un paso);
apuntar y tumbarse (cámara suave); pegarse de espaldas a una pared y girar la cámara; H (ayuda); dejar que un zombi
te pegue (viñeta y flecha) y morir; F1 → tirarse desde alto o recibir un golpe fuerte para ver el ragdoll.
**Pendiente / avisos:** Juan: los zombis usan el mismo ragdoll, así que también se mueven mucho más al caer/morir (si
os parece demasiado, bajad `EXAGERA`/`NERVIO`). `Efectos.sonido` sirve para vuestros gruñidos: soltad
`sonidos/Growl_1.ogg`… y llamad `Efectos.sonido(self, "Growl", pos)`. Quedan de la revisión: teclas configurables y
mando (5), munición/botiquines en el mapa (13), simulación del jugador en `_physics_process` (18).

## 2026-10-27 · KangooG · Claude — plugin Godot AI actualizado a 4.3.1 (a mano)
**Qué:** el botón "Actualizar" del plugin 4.3.0 dejaba Godot congelado (fallo del propio actualizador, corregido en
4.3.1: "fix(update): type the activation runner's loop variables"). Se instaló 4.3.1 a mano con Godot cerrado: zip
oficial `godot-ai-v4-plugin.zip`, cada archivo comprobado con el manifiesto de la versión (313 archivos, mismos que
antes; cambian 6).
**Archivos:** `addons/godot_ai/` (plugin.cfg, update_activation_runner.gd, filesystem_handler.gd,
filesystem_mutation.gd, game_helper.gd, path_validator.gd).
**Pendiente / avisos:** Juan: al hacer pull tendrás también 4.3.1 (no pulses "Actualizar" si te sale en 4.3.0). El
servidor tiene que ser de la MISMA versión que el plugin: en la config de Claude Desktop, `godot-ai==4.3.1` (si sigue en
4.3.0, el dock se queda en "Restarting server...").
Si el dock dice "Incompatible server on port 8001" (un servidor viejo suelto, p. ej. un `pythonw -m godot_ai` del Python
del sistema), abrir `herramientas/liberar_puerto_mcp.gd` y Archivo → Ejecutar (Ctrl+Shift+X): cierra solo ese servidor y
deja el resultado en `herramientas/liberar_puerto_mcp.log`; después Proyecto → Recargar proyecto actual.

## 2026-10-25 (3) · KangooG · Claude — moto: cuestas empinadas, gravedad y cabeceo de verdad
**Qué:**
- **Rampas empinadas a toda velocidad:** antes la moto tomaba una cuesta de más de ~49° por una pared, se estrellaba y el
  piloto salía hacia atrás. Ahora cada rueda es un cilindro que tantea el suelo donde va a estar: ve la cuesta antes de
  llegar y la sube (hasta ~60°), rueda por encima de un bordillo bajo y se para contra lo que es más alto (bloque,
  pared), igual a 30 que a 144 FPS.
- **Se frenaba sola:** al rozar una cuesta con el cuerpo, el choque le quitaba velocidad. Ahora las cuestas no son
  choques y la velocidad va a lo largo de la cuesta: al empezar una rampa no se pierde nada; la gravedad frena cuesta
  arriba y acelera cuesta abajo.
- **Cabeceo y gravedad:** la moto es un cuerpo rígido (altura + cabeceo) apoyado en las dos ruedas. El morro sigue la
  cuesta exactamente (sin bailar en las de 50°); una cresta la lanza si va deprisa; con una sola rueda pivota sobre ella
  (el peso baja la otra). En el aire el morro sigue la trayectoria (sube al despegar, baja al caer) y Shift/Ctrl lo
  mueven. Al tocar el suelo, lo que va contra él es el golpe y lo que va a lo largo, la velocidad que sigue. La
  suspensión se come los golpes de un canto (no sale disparada por un bordillo).
- **El piloto sale hacia delante** (por encima del manillar), nunca hacia atrás.
**Archivos:** `scripts/vehiculos/moto.gd` (`_mover`, `_apoyo_rueda`, `_tantear`, `_cabeceo_aire`, `_aterrizar`; fuera
`_paso_vertical`/`_suelo_en`), `scripts/jugador/jugador.gd` (`vel_real` = `Moto.vel_mundo()`), `tests/moto.gd` (pruebas
nuevas `empinada --angulo=15|30|50` y `bajada`; `choque` comprueba que sale hacia delante), `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F1 → "Zona de motos" o ir a las rampas de 15/30/50° junto a los bloques, y subirlas a fondo; bajar la
de 30° desde la plataforma.

## 2026-10-25 (2) · KangooG · Claude — ragdoll "tipo GTA 4" y caída física de la moto
**Qué:**
- **Ragdoll activo** (`scripts/fisica/ragdoll.gd`, clase `Ragdoll`): al activarse, cada pieza del rig R15 pasa a ser
  un cuerpo rígido unido por articulaciones con límites de un cuerpo real (rodillas y codos solo doblan hacia un lado).
  Además tiene "músculos" (fuerzas que llevan cada articulación a una pose) que cambian según la situación, como el
  Euphoria de GTA 4: **caer** (brazos por delante para frenar la caída, cabeza protegida), **caída libre** (agita
  brazos y piernas), **impacto** (se encoge y queda tirado), **retorcerse** (en el suelo, se agarra la parte herida),
  **morir** (espasmos y se apaga) e **inerte**. Golpes y disparos mientras está en el suelo lo sacuden.
- **Cuándo salta (jugador):** al salir despedido de la moto (choque o al bajarse a más de ~50 km/h), caídas desde
  altura (en el aire con velocidad de caída alta; el daño se calcula al golpear el suelo, más en cabeza/espalda),
  aterrizajes muy fuertes, golpes fuertes de zombi (probabilidad según el daño y la vida que te queda, como mucho
  1 vez cada 6 s) y al morir. Se levanta solo con animación (rueda si quedó boca arriba).
- **Zombis y muñecos:** derribos, atropellos y golpes de bate/hacha los tiran en ragdoll con el impulso del golpe;
  se levantan solos al acabar; al morir se quedan en ragdoll y se congelan quietos para no gastar CPU (máx. 12 activos).
- **Moto que cae de verdad:** al caer pasa a ser un cuerpo rígido (masa, centro de masas alto, ruedas, manillar y
  estribos con forma propia): vuelca, rebota, se arrastra con chispas y ruido de chapa y se para tumbada. Levantarla
  la lleva de esa pose a la pata.
**Archivos:** `scripts/fisica/ragdoll.gd` (nuevo), `scripts/jugador/jugador.gd`, `scripts/jugador/animador.gd`,
`scripts/jugador/arsenal.gd`, `scripts/zombis/zombi.gd` (ganchos, ver mensaje a Juan en CLAUDE.md),
`scripts/nivel/maniqui.gd`, `scripts/vehiculos/moto.gd`, `scripts/ui/menu_trucos.gd`, `tests/ragdoll.gd` +
`tests/escena_ragdoll.tscn` (nuevos), `tests/moto.gd`, `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F1 → "Derribarme (empujón)" o "Caer desde 12 m"; en la zona de motos, chocar contra un bloque o
bajarse en marcha; atropellar zombis o golpear al muñeco con el bate.
**Pendiente / avisos:** capa de colisión 16 = ragdolls (no la uséis para otra cosa). Mientras el jugador está en
ragdoll no puede disparar ni golpear.

## 2026-10-25 · KangooG · Claude — moto: caer de morro y más par
**Qué:**
- **Caer de morro:** la moto se quedaba sobre la rueda de delante rodando y, de repente, el piloto salía disparado
  y moría. Causa: al venir inclinada, la rueda de delante tomaba el suelo por un "muro", la moto se quedaba colgada
  de sus formas de choque acumulando velocidad de caída y al final aterrizaba con un golpe enorme. Ahora: cada rueda
  busca el suelo bajo su posición real y recuerda su último apoyo (cuesta ≠ escalón); en el aire aterriza en cuanto
  toca cualquier rueda; con una sola rueda apoyada el centro va a su altura y el peso baja la otra; apoyada en algo
  que los rayos no ven no sigue "cayendo"; el golpe del aterrizaje está limitado. En el aire el morro se mueve menos
  solo (Shift/Ctrl siguen inclinándola).
- **Más par:** aceleración 19 con curva de par fuerte abajo (0→~40 km/h en ~2 s, sube bien las cuestas) y menos
  rozamiento arriba (llega cerca de la punta de ~56 km/h).
**Archivos:** `scripts/vehiculos/moto.gd`, `tests/moto.gd` (prueba nueva `morro`, también `--fuerte`),
`tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F1 → "Zona de motos", rampa de 20° a fondo y Ctrl en el aire para caer de morro.

## 2026-10-24 (11) · KangooG · Claude — moto: arreglos tras probarla
**Qué:**
- **Cuestas con gravedad:** cuesta arriba frena (y sin gas se va hacia atrás), cuesta abajo empuja; parada con
  piloto se queda sujeta.
- **Rampas sin "disparos":** la velocidad vertical ya no sale de la diferencia de alturas entre fotogramas (un
  bordillo o el borde de la rampa la lanzaban, y peor con muchos FPS); ahora es la del terreno, filtrada, así que
  al final de la rampa sale con la velocidad de la rampa y nada más. Cada rueda busca el suelo donde debe estar
  según la inclinación (antes, en una rampa, la rueda de delante "no veía" el suelo y la moto se quedaba frenada).
- **Choques sin atascos:** colisión del cuerpo + una esfera en cada rueda que se inclinan con la moto; escalones de
  más de ~14 cm son obstáculos (antes se metía dentro de los bloques de 30-40 cm); contra una pared la velocidad es
  la real (no acumula velocidad), el golpe cuenta una vez (no "rebota" cada fotograma) y rozando una pared la moto
  se endereza a lo largo de ella.
- **Neumáticos nuevos:** perfil redondeado de goma "inflada" (malla de revolución), se aplastan contra el suelo con
  el peso y el flanco se abomba (shader `NEUMATICO_SHADER` en `modelo_moto.gd`), dibujo de la banda que gira, flanco
  con letras; llanta con perfil, radios dobles, pinzas de freno.
- **Disparo libre en la moto:** sin ángulos bloqueados; el torso gira más (`rel_aim` -2.7..2.3).
- **Interfaz:** el velocímetro pasa abajo a la izquierda (se tapaba con la munición).
- **Girar despacio:** sin tirones: la cámara vuelve detrás de forma progresiva con la velocidad, el pie al suelo
  tiene margen (no sube y baja a ~2 studs/s), marchas con más margen y el motor suena más grave.
- **Levantar la moto con animación** (F junto a una moto tirada): se coloca junto al asiento, se agacha, la agarra
  del manillar y del asiento y la levanta con las piernas (`Jugador.levantar_moto`, `Animador` "levanta").
- **Más lenta:** velocidad máxima 50 studs/s (~56 km/h, antes 72), aceleración 13.5, choque fuerte desde 30.
**Archivos:** `scripts/vehiculos/moto.gd`, `scripts/vehiculos/modelo_moto.gd`, `scripts/jugador/jugador.gd`,
`scripts/jugador/animador.gd`, `scripts/jugador/arsenal.gd`, `tests/moto.gd` (nuevas pruebas `cuesta`, `bloque`,
`lento`, `levantar`), `tests/ejecutar_pruebas.sh`.
**Cómo probarlo:** F1 → "Rampas 15°/30°/50°" y sube en moto sin gas; contra los bloques naranjas; F1 → "Moto delante",
tírala contra el muro de la zona de motos y levántala con F.

## 2026-10-24 (10) · KangooG · Claude — v0.4: MOTO y armas nuevas
**Qué (moto):** moto conducible hecha por código (`Moto`, ~110 piezas: chasis, motor con aletas, escape, horquilla
inclinada, manillar que gira, ruedas con radios y discos, faro con luz, pata de cabra).
- Física de bicicleta: aceleración por marchas (5 + atrás), dirección que se cierra con la velocidad, inclinación en
  las curvas (hasta 48°, la que equilibra la curva), freno de mano para derrapar, saltos en rampas (sale despedida),
  bordillos de hasta ~28 cm, aterrizajes (mal alineado = caída), choques (≥ 40 studs/s contra una pared = sales
  despedido y te haces daño; la moto se queda tumbada, F para levantarla).
- Piloto: sube pasando la pierna, sentado con las manos en los puños y los pies en los estribos; parado baja el pie
  izquierdo; deprisa se agacha sobre el depósito; en las curvas se mete con la moto y la cabeza recta; en el aire se
  levanta. F para bajarse (en marcha salta, con daño si va muy rápido).
- Armas en la moto: solo las de una mano (pistola, revólver, subfusil, cuchillo, machete, palanca). Se dispara con la
  derecha girando el torso hacia la cámara (delante, a la derecha y bastante hacia atrás por ese lado; a la izquierda
  poco); la izquierda sigue en el manillar (al recargar la suelta). Golpes cuerpo a cuerpo de lado al pasar (la
  velocidad suma daño). Las de dos manos se guardan al subir.
- Atropellos: usa el contrato de objetivo (`recibir_danio`, `derribar`, `empujar`) — no toca el código de los zombis.
  Por encima de ~9 studs/s derriba o mata; a un caído le pasa por encima.
- Motor que suena (sintetizado, sube de tono con las revoluciones y los cambios de marcha), chirrido al derrapar,
  ruido para los zombis (`Ruido.emitir(..., "motor")`, radio 26-95 studs según las vueltas).
- Cámara: detrás de la moto, vuelve sola si no tocas el ratón, se aleja y abre el campo de visión con la velocidad y
  se inclina un poco en las curvas; al apuntar va al hombro. Velocímetro (km/h y marcha) en el HUD.
- Nivel: una moto junto al inicio y dos en la nueva "Zona de motos" (rampas de 12° y 20° y un muro para chocar).
  Trucos (F1): "Moto delante", "Levantar las motos caídas", ir a la zona de motos y todas las armas al suelo.
**Qué (armas):** modelos 3 veces más detallados (`ModelosArmas`) y 6 armas nuevas: revólver, subfusil, escopeta
(cartucho a cartucho, corredera), francotirador (cerrojo, mira telescópica), hacha y palanca. Ver la entrada de
armas en `CLAUDE.md`.
**Archivos:** nuevos `scripts/vehiculos/moto.gd`, `scripts/vehiculos/modelo_moto.gd`, `scripts/armas/modelos_armas.gd`,
`tests/moto.gd` + `tests/escena_moto.tscn`, `tests/vitrina.gd` + `tests/escena_vitrina.tscn`. Cambiados `jugador.gd`
(subir/bajar, cámara, HUD), `animador.gd` (pose en la moto), `arsenal.gd` (armas en la moto, armas nuevas),
`armas.gd`, `efectos.gd`, `nivel_pruebas.gd` (`_crear_motos`, `_rampa_salto`, meta `sin_motos`), `menu_trucos.gd`,
`tests/combate.gd` (`--arma=`), `tests/ejecutar_pruebas.sh` (9 pruebas de moto).
**Cómo probarlo:** F junto a la moto del inicio (a la izquierda). W/S/A/D, Espacio derrapar, F bajarse, L luces.
F1 → "Zona de motos" para las rampas y el muro. Saca la pistola (1) en marcha y apunta a un muñeco.
**Pendiente / avisos:** sin ragdoll al caerse (el cuerpo sale volando y aterriza de pie); el coche sigue pendiente.
Juan: los zombis oyen la moto con el tipo de ruido `"motor"` (peso 0.5 por defecto en `Ruido.peso`); si queréis que
alarme más, añadid `"motor"` a `Ruido.PESO`. La moto está en la capa 1 (para vuestros rayos es una pared más).

## 2026-10-24 (9) · KangooG · Claude
**Qué:** `CLAUDE.md`: nueva sección **"Mensajes entre los Claude"** con una pregunta para el Claude de Juan (¿trabaja
con el editor de Godot o directamente sobre GitHub?) y "Reparto" rellenado (KangooG: jugabilidad; Juan: zombis).
Juan: si el reparto no os cuadra, cambiadlo. Incluye recomendaciones para trabajar sin el editor abierto
(no editar `.tscn`/`project.godot` a mano, grabar o jugar los cambios visuales, no renombrar archivos, avisar antes de
cambiar valores de juego, lista de "qué probar" en cada PR).

## 2026-10-24 (8) · KangooG · Claude
**Qué:** quitado el "arma hacia arriba" pegado a una pared (dificultaba jugar). Ahora cerca de una pared el arma
solo se recoge hacia el cuerpo y sigue apuntando y disparando; si la boca del cañón queda dentro de la pared, la
bala da en la pared. Se puede volver a activar con `Animador.ALZA_ACTIVA = true`.
**Archivos:** `scripts/jugador/animador.gd`.

## 2026-10-24 (7) · KangooG · Claude
**Qué:** con el arma apoyada en un muro (barrera agachado, muro de 1.3 m de pie) la bala chocaba contra el propio
muro junto al torso: la comprobación "¿el cañón está metido en la pared?" iba del pecho a la boca y esa línea rozaba
el muro. Ahora se mira a lo largo del arma (empuñadura → boca) y el rayo de la bala empieza en la empuñadura.
**Archivos:** `scripts/jugador/arsenal.gd` (`salida_bala`), `tests/apoyo.gd` (comprueba dónde da la bala apoyada).

## 2026-10-24 (6) · KangooG · Claude
**Qué:** más libertad con el arma cerca de las paredes.
- Cerca de una pared el arma primero se **recoge** hacia el cuerpo (`Animador.arma_retro`, hasta `RETRO_MAX` 0.7
  studs) y sigue apuntando; solo **extremadamente pegado** (ya no se puede recoger más, o la pared entre el pecho
  y la empuñadura) se levanta.
- Círculo rojo: nunca con el arma apoyada, más pequeño (12 px) y sale menos (obstáculo a menos de 3 studs del
  cañón y separado al menos 28 px de la mira). Constantes `CIRCULO_*` en `arsenal.gd`.
**Archivos:** `scripts/jugador/animador.gd`, `scripts/jugador/arsenal.gd`, `tests/apoyo.gd`, `tests/visual.gd`.

## 2026-10-24 (5) · KangooG · Claude
**Qué:** apoyar el arma.
- Con el arma apoyada (X) ya no se levanta: antes el propio muro en el que se apoyaba (barrera agachado, muro de
  1.3 m de pie) la levantaba del todo. Además, para decidir si se levanta se mira a lo largo del cañón (desde la
  empuñadura), no desde el pecho: apuntando por encima de un muro bajo o junto a una esquina ya no se levanta.
- **Apoyo lateral:** de lado a una pared (izquierda o derecha, de pie o agachado) se puede apoyar el arma contra
  ella (`find_rest` → `lado: true`, pared vertical a menos de `LADO_ALCANCE` 2 studs y más o menos paralela a donde
  se apunta). Apoyada de lado se puede mirar más arriba/abajo que sobre un muro.
**Archivos:** `scripts/jugador/animador.gd`, `scripts/jugador/arsenal.gd`, `scripts/jugador/jugador.gd`,
`tests/apoyo.gd` (casos de pared de lado y campo abierto; comprueba que apoyada no se levanta).

## 2026-10-24 (5) · Juan · Claude
**Qué:** zombis v1, **vista e ingenio**, sin cambiar sus velocidades. Ven en un cono de 120° y con visión periférica
según tu postura (de pie ~15 m, agachado ~9 m, tumbado ~5 m; usa `STANCE[].Sight/Near`, que no se usaban), con una
**sospecha gradual**: primero "les parece ver algo" y van a mirar; si te siguen viendo, te persiguen. Al perderte van a
donde estarías (anticipan), registran 3 sitios alrededor y se rinden; tardan 0,5 s en reaccionar a un ruido; rodean
obstáculos si se atascan. Indicador **"visto"** en el HUD (bajo el de ruido). F8 = zombis ciegos (también en F1).
**Archivos:** `scripts/zombis/zombi.gd`, `scripts/zombis/director_zombis.gd`, `scripts/config/zconfig.gd` (claves nuevas en
`ZOMBI`), `scripts/ui/medidor_ruido.gd`, `tests/pruebas_ruido.gd` (+10 pruebas), `tests/ejecutar_pruebas.sh`, `docs/RUIDO_Y_ZOMBIS.md`,
`CLAUDE.md`, `README.md`. **De KangooG (mínimo):** `scripts/ui/menu_trucos.gd` (+ casilla "Zombis ciegos (F8)", 2 líneas),
`scripts/jugador/jugador.gd` ("F8" en el texto de ayuda), `tests/cerca.gd` (+ `Zombi.ciegos = true`, 1 línea).
**Cómo probarlo:** F5 → Jugar → F6 (ves el cono de cada zombi y su sospecha). Ponte delante de uno de pie y luego
agachado; escóndete tras la pared alta y mira cómo te busca. Automático: `tests/ejecutar_pruebas.sh` (26/26).
**Pendiente / avisos:** KangooG: los zombis ahora **ven**; tu acción "Zombi delante" (F1) crea uno que te descubre en
~1-2 s y viene a por ti. Si alguna prueba tuya necesita un zombi quieto, pon `Zombi.ciegos = true` además de `sordos`
(ya hecho en `tests/cerca.gd`, que vuelve a dar exactamente lo de antes). Tus escenas de prueba se pasaron antes y
después: sin cambios salvo tiempos que ya variaban. Anotado en "Problemas conocidos" un detalle de `cerca -- --muneco`.

## 2026-10-24 (4) · KangooG · Claude
**Qué:** con un zombi pegado ya se le puede disparar (la boca del cañón quedaba dentro de él y la bala lo
atravesaba sin tocarlo; ahora el rayo empieza en la línea del cañón a la altura del pecho y cuenta los blancos
pegados, `hit_from_inside`). El arma solo se levanta muy pegado a la pared (`Animador.ALZA_MARGEN` 0.15 /
`ALZA_RECORRIDO` 1.0; antes empezaba ~1 stud antes).
**Archivos:** `scripts/jugador/arsenal.gd` (`salida_bala`, `_rayo_bala`), `scripts/jugador/animador.gd`.
Prueba nueva: `tests/cerca.gd` + `escena_cerca.tscn` (`-- --dist=2 [--rifle] [--muneco]`): le da a 1.5–6 studs.

## 2026-10-24 (3) · KangooG · Claude
**Qué:** menú de trucos, pantalla de carga y el círculo rojo solo pegado a una estructura.
- **Menú de trucos (F1, solo en el editor):** pausa el juego y deja el ratón libre. Interruptores: estamina y balas
  infinitas, invencible, cámara lenta, ver ruido (F6), zombis sordos (F7). Acciones: vida al máximo / herido /
  agotado / estamina al máximo, munición al máximo, recargar, armas al suelo (machete, pistola, rifle, cuchillo),
  revivir muñecos, zombi delante. "Ir a…": inicio, bloques, rampas, escalera, túneles, muros y mesa, pared alta,
  cornisa, zona de tiro, tras la pared. F1 o Esc lo cierran.
- **Pantalla de carga** al pulsar Jugar y al volver al menú desde la pausa: título, un consejo al azar y barra de
  progreso (carga en segundo plano + el nivel construyéndose), luego se desvanece.
- **Círculo rojo:** solo si lo que tapa el cañón es una estructura a menos de 6 studs (no muñecos ni zombis).
**Archivos:** nuevos `scripts/ui/menu_trucos.gd` (MenuTrucos) y `scripts/ui/pantalla_carga.gd` (PantallaCarga);
`scripts/jugador/jugador.gd` (crea MenuTrucos en desarrollo; `teletransportar()`; `invencible`: una línea en
`recibir_danio` de Juan), `scripts/jugador/arsenal.gd`, `scripts/ui/menu_principal.gd` y `menu_pausa.gd` (usan la
pantalla de carga). Pruebas: `tests/trucos.gd` + `escena_trucos.tscn` (todas las zonas: de pie, en el suelo y sin
meterse en nada), `tests/menu_test.gd` amplía a la carga, F1 y volver al menú.
**Cómo probarlo:** F5 → Jugar (pantalla de carga) → F1.

## 2026-10-24 (2) · KangooG · Claude
**Qué:** ajustes del disparo y la cámara pedidos por KangooG:
- La bala sale del cañón **en la dirección del cañón**. Al apuntar o disparar, el arma se orienta hacia lo que
  marca la mira (`Animador.conv_w`/`conv_q`), así que la trazadora ya no sale con otra inclinación que el arma.
  (Primer disparo desde la pose baja: la bala va al punto de la mira mientras el arma sube.)
- Pegado a una pared **ya no se bloquea el disparo**: sale hacia donde apunta el arma (levantada). Si el cañón
  está metido en la pared, la bala da en la pared.
- **Círculo rojo** en el HUD donde va a dar la bala cuando no coincide con la mira (pared, esquina, muro bajo).
- Chocando contra algo corriendo, la cámara deja el modo carrera (FOV, distancia y balanceo según la velocidad real).
**Archivos:** `scripts/jugador/arsenal.gd` (`punto_mira`, `salida_bala`, `_actualizar_circulo`; `aim_check` ya
no bloquea por pared), `scripts/jugador/animador.gd`, `scripts/jugador/jugador.gd`, `tests/visual.gd`.
**Cómo probarlo:** pegarse a una pared con el rifle y disparar; apuntar al muñeco por encima de un muro bajo
(círculo rojo en el muro); correr contra una esquina. Las 16 pruebas siguen en verde.

## 2026-10-24 · KangooG · Claude
**Qué:** seis arreglos de jugabilidad pedidos por KangooG:
1. La bala sale del **cañón** (antes salía de la cámara): la mira marca el punto, pero si entre el arma y ese
   punto hay algo (esquina, muro bajo), la bala da ahí.
2. **Cámara:** rueda del ratón para acercar/alejar (`zoom_cam`, 0.45–1.6; apuntando no cambia). De espaldas a una
   pared la cámara sube por encima de la cabeza y el personaje se transparenta; girando pegado a una pared la
   cámara ya no se va a la nuca (el hombro nunca queda dentro de la pared).
3. Pegado a una pared, el **arma de fuego se levanta** (cañón arriba) en vez de atravesarla, y no se puede
   disparar (`Animador.arma_alzada`, lo mira `Arsenal.aim_check`).
4. **Colisión de la cabeza:** caja `FormaCabeza` (solo de pie): ya no se entra de pie en el túnel de 1.4 m.
   Agachado bajo un techo bajo, el personaje se agacha un poco más para que la cabeza no lo atraviese.
5. **Colgado + Shift:** se desplaza por la cornisa x1.9 más rápido (y gasta el doble de estamina).
6. **Andar de lado con el arma (A/D):** pasos laterales más cortos, rodillas algo dobladas y pie levantado
   (antes una pierna iba recta y la otra se abría como un compás).
**Archivos:** `scripts/jugador/jugador.gd`, `scripts/jugador/animador.gd`, `scripts/jugador/arsenal.gd`,
`scripts/ui/menu_principal.gd` (controles). Suben también las pruebas de KangooG a `tests/` (AUDITORIA §5.3):
`choques`, `combate`, `salto`, `apoyo`, `visual`, `menu_test` y las nuevas `canon` y `tunel` (todas con la meta
`sin_zombis`).
**Cómo probarlo:** F5 → Jugar. Rueda del ratón; de espaldas a la pared alta girar la cámara; ir con el rifle
contra una pared; intentar entrar de pie en el túnel gris de 1.4 m; colgarse de la cornisa y A/D con Shift;
andar con A/D con el rifle. Automático: `tests/escena_canon.tscn`, `tests/escena_tunel.tscn` (`-- --agachado`).
Las 16 pruebas de `tests/ejecutar_pruebas.sh` siguen en verde.
**Pendiente / avisos:** Juan: en `arsenal.gd` el rayo de la bala ahora está en `_rayo_bala()` (mismo
"contrato de objetivo", sin cambios para los zombis).

## 2026-10-23 · Juan · Claude
**Qué:** sistema de RUIDO y ZOMBIS v0 (la "idea estrella" de la auditoría). Todo lo que hace el jugador suena
(pisadas según velocidad y postura, disparos, golpes, caídas…) y los zombis lo oyen: investigan, persiguen
siguiendo los ruidos, atacan, buscan y se rinden; al perseguir gruñen y avisan a otros. Las paredes amortiguan el
ruido. Medidor de ruido en el HUD. El jugador ya recibe daño, regenera y muere (el nivel se reinicia). Primeras
pruebas automáticas en el repo. Arreglado: los golpes cuerpo a cuerpo ya no atraviesan paredes (AUDITORIA §7.1).
**Archivos nuevos:** `scripts/ruido/ruido.gd`, `scripts/zombis/zombi.gd`, `scripts/zombis/director_zombis.gd`,
`scripts/ui/medidor_ruido.gd`, `tests/pruebas_ruido.gd`, `tests/ejecutar_pruebas.sh`, `docs/RUIDO_Y_ZOMBIS.md`
(+ sus `.uid`).
**Archivos de KangooG tocados (cambios pequeños y comentados; detalle en `docs/RUIDO_Y_ZOMBIS.md` §14):**
`zconfig.gd` (tablas `RUIDO` y `ZOMBI` al final), `animador.gd` (ruido de pisadas y de reptar), `jugador.gd`
(grupo `jugador`, medidor, ruidos de aterrizar/valla/cornisa, daño/regeneración/muerte, F6/F7 en la ayuda),
`arsenal.gd` (ruidos de armas, blancos genéricos `objetivos` en vez de `Maniqui`, golpes sin atravesar paredes),
`maniqui.gd` (2 líneas: grupo y meta `objetivo`), `nivel_pruebas.gd` (`_crear_zombis`). Sin tocar escenas ni
`project.godot`. También `CLAUDE.md`, `README.md` y una nota en `AUDITORIA.md`.
**Cómo probarlo:** F5 → Jugar. Agachado no te oyen; corriendo o disparando, sí. F6 enseña los ruidos y el estado de
cada zombi; F7 los deja sordos. Automático: `tests/ejecutar_pruebas.sh <ruta a Godot>` (16/16 en verde).
**Pendiente / avisos:** los zombis aún no ven (solo oyen). La muerte del jugador es provisional (sin pantalla ni
ragdoll). Siguen abiertos los fallos de la auditoría §7.2 (cadencia según FPS) y §7.3 (efectos tras cambiar de escena).

## 2026-10-23 · Juan · Claude
**Qué:** auditoría técnica completa del proyecto (arquitectura, fallos comprobados con Godot 4.7.2 headless,
deuda técnica, ideas de mejora y hoja de ruta). Solo documentación: no se ha tocado código ni escenas.
**Archivos:** `AUDITORIA.md` (nuevo), `CAMBIOS.md`.
**Cómo probarlo:** leer `AUDITORIA.md`; la sección 11 explica cómo repetir las pruebas.
**Pendiente / avisos:** hay 3 fallos comprobados que conviene arreglar pronto (golpes a través de paredes,
cadencia que depende de los FPS, efectos que sobreviven al cambiar de escena). Las pruebas `tests/` que cita
`CLAUDE.md` no están en el repo: quien las tenga, que las suba.

## 2026-10-21 · KangooG · Claude
**Qué:** preparación del repositorio para trabajar entre dos: `.gitignore`, `.gitattributes`,
`README.md` (cómo abrir el proyecto y configurar Godot AI), `CLAUDE.md` (diseño, estado y normas)
y este registro de cambios.
**Archivos:** `.gitignore`, `.gitattributes`, `README.md`, `CLAUDE.md`, `CAMBIOS.md`.

## 2026-10-21 · KangooG · Claude
**Qué:** menú principal, menú de pausa (Esc) con opciones básicas guardadas en `user://opciones.cfg`,
y primer ejecutable de Windows. F4/F5 (trucos) solo en el editor.
**Archivos:** `escenas/menu_principal.tscn`, `scripts/ui/*`, `scripts/jugador/jugador.gd`, `scripts/jugador/arsenal.gd`, `scripts/nivel/nivel_pruebas.gd`.
**Cómo probarlo:** F5 en el editor → menú → Jugar → Esc.

## 2026-10-21 · KangooG · Claude
**Qué:** animación de recoger objetos (F), apoyar el arma según su altura (no boca arriba),
brazos con arma boca arriba, colgarse de cornisas (A/D, esquinas, subir, soltarse), balas infinitas (F5).
**Archivos:** `scripts/jugador/*`, `scripts/config/zconfig.gd`, `scripts/nivel/nivel_pruebas.gd`.

## 2026-10-20 · KangooG · Claude
**Qué:** sistema de combate portado de Roblox (pistola, rifle, cuchillo, machete, bate; apuntar,
retroceso, recarga, apoyar arma, golpes), muñecos de prueba, reptar rápido, andar con fatiga,
y muchos ajustes de animación (carrera, escaleras, rampas, trepar, choques con paredes).
**Archivos:** `scripts/armas/*`, `scripts/jugador/*`, `scripts/nivel/maniqui.gd`.

## 2026-10-20 · KangooG · Claude
**Qué:** personaje y movimiento portados del juego de Roblox (rig R15 cuadrado, animación procedural,
estamina, posturas, saltar/sortear, cámara al hombro) en Godot 4.7.2.

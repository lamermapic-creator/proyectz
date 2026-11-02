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

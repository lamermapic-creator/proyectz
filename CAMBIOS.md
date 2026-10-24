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

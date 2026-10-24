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

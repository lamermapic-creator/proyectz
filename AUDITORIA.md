# 🔍 AUDITORÍA TÉCNICA — Proyecto Z

> **Documento independiente.** No sustituye al `README.md` ni a `CLAUDE.md`: es una revisión externa del
> proyecto tal y como estaba el **2026-10-23** (commit `7498278`), hecha como la haría un ingeniero senior
> que ve el repositorio por primera vez. Vive en su propia rama para no mezclarse con el trabajo diario.
>
> **Actualización 2026-10-23 (tarde):** §7.1 (golpes a través de paredes) **arreglado**; la idea §9.3.1
> (sistema de ruido) y los zombis v0 **implementados** (ver `docs/RUIDO_Y_ZOMBIS.md`); ya hay pruebas
> automáticas en `tests/` (§5.3/§8.6, en parte). Este documento no se reescribe: es la foto del día de la auditoría.
>
> **Cómo se hizo:** lectura completa del código propio (~6.400 líneas de GDScript, más escenas y configuración),
> del historial de git y de la documentación, y **verificación con Godot 4.7.2 real** (Linux, headless) dentro
> de un contenedor: importación del proyecto, compilación de los 15 scripts, ejecución del menú y del nivel de
> pruebas, y un banco de pruebas temporal para medir los fallos sospechosos. Lo marcado con ✅ **está
> comprobado ejecutando el juego**; lo demás sale de la lectura del código.

---

## Índice

1. [Resumen ejecutivo (para leer en 2 minutos)](#1-resumen-ejecutivo)
2. [Qué es el proyecto y en qué punto está](#2-qué-es-el-proyecto-y-en-qué-punto-está)
3. [Motor, tecnología y configuración](#3-motor-tecnología-y-configuración)
4. [Arquitectura del código](#4-arquitectura-del-código)
5. [Colaboradores y documentos de progreso](#5-colaboradores-y-documentos-de-progreso)
6. [Verificación realizada](#6-verificación-realizada)
7. [Fallos encontrados (por prioridad)](#7-fallos-encontrados-por-prioridad)
8. [Deuda técnica y riesgos de arquitectura](#8-deuda-técnica-y-riesgos-de-arquitectura)
9. [Lluvia de ideas: cómo mejorar mucho el proyecto](#9-lluvia-de-ideas-cómo-mejorar-mucho-el-proyecto)
10. [Hoja de ruta propuesta](#10-hoja-de-ruta-propuesta)
11. [Apéndice: cómo reproducir las pruebas](#11-apéndice-cómo-reproducir-las-pruebas)

---

## 1. Resumen ejecutivo

**Veredicto:** es un prototipo **muy por encima de la media** en lo que más cuesta: el movimiento y la
animación procedural del personaje. La animación (pies anclados con IK, pelvis como péndulo invertido,
recargas con cargador físico, colgarse de cornisas con giro en esquinas…) es de nivel profesional. El código
está muy comentado y explica el *porqué* de cada decisión, cosa poco habitual.

Los problemas no están en la calidad del detalle, sino en **la estructura que hará falta para crecer**.
Ahora mismo todo gira alrededor de un único personaje controlado por teclado. La siguiente etapa del plan
(zombis) obligará a repensar varias piezas.

| | Lo mejor | Lo más urgente |
|---|---|---|
| 🟢 | Animación procedural de calidad AAA-indie | — |
| 🟢 | Código muy documentado, en un único idioma de dominio (español) | — |
| 🟢 | Proyecto limpio: compila y arranca **sin un solo error ni aviso** | — |
| 🔴 | — | El bate y los cuchillos **golpean a través de las paredes** ✅ |
| 🔴 | — | La cadencia del rifle **depende de los FPS** (480 en vez de 620 RPM a 24 FPS) ✅ |
| 🟠 | — | Los efectos (sangre, agujeros) **sobreviven al volver al menú** ✅ |
| 🟠 | — | La simulación corre en `_process` (fotograma) en vez de `_physics_process` |
| 🟠 | — | Un personaje cuesta **~0,9 ms/fotograma y 74 mallas** ✅: 30 zombis así no caben en 16 ms |
| 🟠 | — | Las pruebas automáticas (`tests/`) que cita `CLAUDE.md` **no están en el repo** |
| 🟡 | — | Contradicción de objetivos: "jugable en web" frente a renderizador Forward+ y sombras de 8192 px por defecto |

---

## 2. Qué es el proyecto y en qué punto está

**Proyecto Z** es un juego de **zombis en tercera persona, realista y de sigilo** (el lema del menú es
*"Sobrevive. No hagas ruido."*). Presupuesto: **0 €**, solo recursos gratuitos.

### Historia del motor

```
Roblox Studio  ──►  Unity 6  ──►  Godot 4.7.2 (actual)
(v0.1.6 jugable)   (Mixamo, abandonado)   (port 1:1 de los scripts de Roblox)
```

La decisión clave fue **portar el juego de Roblox casi línea a línea**: mismo muñeco R15 cuadrado, mismos
Motor6D, mismas unidades (*studs*, 1 stud ≈ 0,31 m) y misma gravedad (35). Para ello existe `Rbx`
(`scripts/util/rbx.gd`), una pequeña capa que traduce la API de Roblox (`CFrame`, `Lerp`, muelles de
`AnimShared`…) a Godot. Es como haber traído los muebles de una casa vieja a una nueva **con las mismas
medidas de pared**: todo encaja a la primera, pero los muebles nuevos que compres (modelos de Kenney,
Quaternius…) vendrán en otra unidad (metros) y habrá que escalarlos.

### Estado por etapas (según `CLAUDE.md` y lo comprobado en el código)

| Etapa | Estado real |
|---|---|
| 1. Personaje y cámara | ✅ Hecho y muy pulido. Faltan caídas con daño, ragdoll y sonidos reales |
| 2. Armas | ✅ Hecho: pistola, rifle, cuchillo, machete y bate; apuntar, apoyar el arma, retroceso, recargas, recoger |
| — Menús | ✅ Menú principal, pausa, opciones guardadas y primer `.exe` |
| 3. Zombis | ❌ No empezado (hay maniquíes de madera como blancos) |
| 4. Vehículos | ❌ No empezado (los valores de Roblox están anotados) |
| 5. Mapa, luz, sonido | ❌ Solo un nivel de pruebas generado por código; sonidos sintetizados |
| 6. Multijugador | ❌ Opcional |

**Lo que se puede hacer hoy en el juego:** andar, correr, agacharse, tumbarse y reptar (también boca
arriba), asomarse (Q/E), saltar, saltar vallas, encaramarse, colgarse de cornisas y moverse por ellas
(doblando esquinas), cambiar entre 4 armas que se sacan de su funda, disparar, apuntar, apoyar el arma en
muros, recargar, golpear y recoger un machete del suelo. Con estamina, fatiga y cámara al hombro con
colisiones.

---

## 3. Motor, tecnología y configuración

| Elemento | Valor | Comentario |
|---|---|---|
| Motor | **Godot 4.7.2** (estándar, GDScript) | Sin C# ni GDExtensions propias |
| Física | **Jolt Physics** | ✔ Buena elección: más estable y rápida que la física por defecto |
| Renderizador | **Forward+**, D3D12 en Windows | ⚠ Incompatible con exportar a **web** (que requiere *Compatibility*) |
| Unidades | **studs** (1 stud = 0,31 m), gravedad 35 | Por fidelidad a Roblox |
| Escena inicial | `escenas/menu_principal.tscn` | |
| Autoload | `_mcp_game_helper` (del plugin Godot AI) | Se quita solo al exportar (lo hace el propio plugin) ✔ |
| Plugin | **Godot AI v4.3.0** (`addons/godot_ai`, ~300 archivos) | Deja a Claude Desktop controlar el editor |
| Exportación | Windows x86_64, PCK embebido, ~110 MB | Sin metadatos (nombre, versión, icono vacíos) |
| Entrada | Teclas físicas leídas a mano | ⚠ No hay `InputMap`: ni reasignar teclas ni mando |
| Recursos externos | Ninguno todavía | Todo (mallas, texturas, sonidos) se genera por código |

**Dato curioso que vale la pena destacar:** *no hay ni un solo modelo, textura ni sonido en el repo*. El
personaje se construye con 48 piezas (cajas y cilindros), las armas pieza a pieza, el suelo con una textura de cuadrícula hecha
píxel a píxel y los disparos con ondas sintetizadas. Es elegante y deja el repo ligero, pero el día que lleguen
los recursos reales el repo crecerá rápido (ver [Git LFS](#9-lluvia-de-ideas-cómo-mejorar-mucho-el-proyecto)).

---

## 4. Arquitectura del código

### 4.1 Mapa de archivos (código propio)

| Archivo | Líneas | Clase | Qué hace |
|---|---:|---|---|
| `scripts/jugador/animador.gd` | 1940 | `Animador` | Animación procedural completa (port de ProceduralAnimator) |
| `scripts/jugador/jugador.gd` | 1420 | `Jugador` | Entrada, movimiento, "Humanoid", posturas, vault, cornisas, cámara, HUD |
| `scripts/jugador/arsenal.gd` | 915 | `Arsenal` | Inventario, disparo, golpes, recarga, apoyar, recoger, HUD de armas |
| `scripts/armas/armas.gd` | 354 | `Armas` | Datos de armas, fundas, poses, golpes, recargas y modelos |
| `scripts/armas/efectos.gd` | 280 | `Efectos` | Partículas, manchas, trazadoras, fogonazo y sonidos sintetizados |
| `scripts/ui/menu_principal.gd` | 242 | — | Menú principal con el nivel de fondo al atardecer |
| `scripts/jugador/rig_personaje.gd` | 235 | `RigPersonaje` | El muñeco R15: 15 Motor6D + 48 piezas |
| `scripts/nivel/maniqui.gd` | 225 | `Maniqui` | Blanco de pruebas con daño por zonas y caídas |
| `scripts/nivel/nivel_pruebas.gd` | 193 | — | Nivel de pruebas generado por código |
| `scripts/util/rbx.gd` | 168 | `Rbx` | Traductor Roblox → Godot (CFrame, muelles, curvas) |
| `scripts/ui/panel_opciones.gd` | 131 | `PanelOpciones` | Panel de opciones reutilizable |
| `scripts/ui/menu_pausa.gd` | 96 | `MenuPausa` | Pausa con Esc y al perder el foco |
| `scripts/ui/opciones.gd` | 87 | `Opciones` | Opciones guardadas en `user://opciones.cfg` |
| `scripts/ui/estilo.gd` | 83 | `EstiloUI` | Tema oscuro con acento ocre |
| `scripts/config/zconfig.gd` | 58 | `ZConfig` | Constantes de diseño (velocidades, estamina, posturas) |

### 4.2 Cómo se conectan las piezas

```
                        menu_principal.tscn ──"Jugar"──► pruebas_movimiento.tscn
                                                              │
                                     NivelPruebas (@tool) ────┤ genera geometría, luz, cielo y 5 Maniquíes
                                                              │
                                     Jugador (CharacterBody3D)┘
                                      ├─ Rig (RigPersonaje) ........ 15 Motor6D, 48 mallas
                                      ├─ Camara (top_level)
                                      ├─ Animador ................... lee  Jugador.L  (diccionario compartido)
                                      ├─ Arsenal (creado en código) . escribe Jugador.L.holster / rested…
                                      └─ MenuPausa (creado en código)

   Bucle por fotograma (_process):
   Jugador._process ─► _leer_movimiento ─► _aproximar_escalada ─► arsenal.dirigir
                    ─► update_character ─► arsenal.actualizar ─► humanoid_step (move_and_slide)
                    ─► update_camera ─► HUD
   Animador._process ─► update_rig (≈1100 líneas) ─► rig.aplicar()
```

**La analogía:** `Jugador` es el **director de orquesta**, `Animador` es **el cuerpo de baile** que mira
una pizarra (`Jugador.L`) para saber qué tiene que bailar, y `Arsenal` es **el armero**, que también escribe
en esa misma pizarra. Funciona, pero la pizarra es un diccionario con claves de texto (`"stanceT"`,
`"holster"`, `"restGap"`…): si alguien escribe `"stanceT"` en un sitio y `"stance_t"` en otro, nadie se queja
hasta que algo falla en silencio.

### 4.3 Puntos fuertes de la arquitectura

- **La capa `Rbx`** es una decisión muy buena: aísla la traducción de Roblox en un solo sitio y permite
  portar código casi literal.
- **IK analítica propia** (`Animador.solve`) con la fórmula exacta de Motor6D (`pieza1 = pieza0·C0·T·C1⁻¹`).
- **Reloj de juego propio** (`Jugador.reloj`): ya no depende del reloj del ordenador. Bien pensado.
- **Movimiento independiente de los FPS** ✅: andando 4 s, el personaje recorre 18,01 / 17,97 / 17,93 studs
  a 20 / 60 / 144 FPS (diferencia < 0,5 %).
- **Configuración centralizada** en `ZConfig` y `Armas.WEAPONS`.
- **Opciones y menús** sencillos pero completos, con tema propio.

---

## 5. Colaboradores y documentos de progreso

### 5.1 Quién ha trabajado

- **Todo el código** se subió el 21-22 de octubre de 2026 en 5 commits, firmados en git por el usuario
  **lamermapic-creator** (3 de ellos por subida web de GitHub, "Add files via upload").
- `CAMBIOS.md` atribuye el trabajo a **KangooG** asistido por Claude (probablemente la misma persona que
  lamermapic-creator).
- `CLAUDE.md` habla de dos personas: **KangooG** y **"Amigo"**, pero la sección **"Reparto" está vacía**.
- Las ramas `main` y `claude/clever-goldberg-vhqazl` eran idénticas antes de esta auditoría.

### 5.2 Documentos donde está el progreso (léelos en este orden)

| Documento | Qué contiene | Valoración |
|---|---|---|
| `CLAUDE.md` | **La memoria del proyecto**: normas de trabajo entre dos, diseño, estado, decisiones, valores de Roblox, cómo conectar Claude con Godot y Roblox Studio | ⭐ Muy valioso. Es el documento más importante |
| `CAMBIOS.md` | Registro de cambios con formato fijo (qué, archivos, cómo probarlo) | ✔ Bien planteado; 5 entradas |
| `README.md` | Cómo abrir el proyecto, controles, plugin y exportar | ✔ Correcto y conciso |
| `addons/godot_ai/README.md` | Documentación del plugin de terceros | — |

### 5.3 Información importante que **no** está en el repo (y se puede perder)

`CLAUDE.md` menciona cosas que **solo existen en el ordenador o en el contenedor de KangooG**:

- 🔴 **`tests/visual.gd`, `tests/escena_visual.tscn`, `tests/combate.gd`, `tests/escena_combate.tscn`**: las
  pruebas visuales y de combate. **No están en el repo.** Si ese contenedor se pierde, se pierden.
- 🟠 `/home/claude/hoja.py` (generador de hojas de fotogramas) y `/home/claude/roblox_src/` (copias de los
  scripts de Roblox): el propio `CLAUDE.md` avisa de que se pierden al cerrar la sesión.
- 🟠 `proyecto Z v0.1.6 prototipo jugable.rbxl`: el juego original de Roblox, **la referencia de todo el port**,
  no está versionado.

### 5.4 Desajustes entre documentación y código

| Dónde | Documentación dice | El código dice |
|---|---|---|
| `CLAUDE.md` › Valores clave | WalkSpeed 6.5, SprintSpeed 18.5, AimSpeed 4.5 | `zconfig.gd`: 4.8, 14.0, 3.6 (se bajaron a propósito) |
| `CLAUDE.md` › Pruebas | `tests/…` | No existen en el repo |
| `CLAUDE.md` › Estado | "Estado actual (2026-10-20)" | Ya hay menús y `.exe` (21-10) |
| `CLAUDE.md` | Rutas personales `C:\Users\ferna\…` | Solo sirven en un ordenador; para el otro colaborador son ruido |

---

## 6. Verificación realizada

Con **Godot 4.7.2 oficial para Linux** en modo headless:

| Prueba | Resultado |
|---|---|
| Importar el proyecto desde cero | ✅ Sin errores |
| Compilar los 15 scripts propios (`--check-only`) | ✅ 0 errores, 0 avisos |
| Ejecutar el nivel de pruebas 10 s | ✅ Sin errores en la salida |
| Ejecutar el menú principal 5 s | ✅ Sin errores en la salida |
| Movimiento a 20 / 60 / 144 FPS | ✅ Independiente de los FPS (±0,5 %) |
| Cadencia del rifle (620 RPM) a 24 / 30 / 60 / 144 FPS | ❌ **480** / 620 / 620 / 620 RPM |
| Golpe con bate a un muñeco detrás de una pared | ❌ **Le quita 38 de vida** a través de la pared |
| Efectos tras volver al menú | ❌ El nodo `FX_Combate` **sigue vivo con 6 efectos** dentro |
| Coste por fotograma de un personaje (lógica + animación) | ≈ **0,88 ms** de CPU, **74 mallas** |

---

## 7. Fallos encontrados (por prioridad)

Leyenda: 🔴 alta · 🟠 media · 🟡 baja · ✅ comprobado ejecutando.

### 🔴 7.1 Las armas blancas golpean a través de las paredes ✅

`scripts/jugador/arsenal.gd:622-651` (`_resolver_golpe`) busca a los muñecos solo por **distancia y ángulo**
(un cono delante del jugador). No comprueba si hay algo en medio.

*Prueba:* muñeco a 5 studs detrás de una pared de 10×10 → el bate le quitó 38 de vida.

*Por qué importa:* con zombis será un fallo jugable grave (matar a través de puertas y muros).

*Arreglo:* antes de aplicar el daño, lanzar un rayo (o un `ShapeCast3D`) desde el pecho del jugador hasta el
objetivo con la máscara del escenario y descartar el golpe si choca. Mejor aún: una forma de barrido que siga
el arma durante el golpe (ver ideas, §9).

### 🔴 7.2 La cadencia de disparo depende de los FPS ✅

`arsenal.gd:514` (`if now - last_shot < 60.0 / w.RPM: return`) junto con el disparo automático, que se
llama una vez por fotograma (`arsenal.gd:711-712`).

Es como un **reloj de arena que solo miras cuando parpadeas**: si parpadeas despacio (pocos FPS), el disparo
llega tarde aunque la arena ya haya caído. A 24 FPS el rifle dispara a **480 RPM** en vez de 620 (−23 %). En
equipos modestos, justo el público objetivo, el rifle es peor.

*Arreglo:* acumular el tiempo y disparar **tantas balas como hayan "vencido"** en este fotograma:
```gdscript
var intervalo := 60.0 / w.RPM
if now - last_shot > intervalo * 2.0:
    last_shot = now - intervalo   # tras una pausa larga no se dispara una ráfaga acumulada
while J.firing and now - last_shot >= intervalo:
    last_shot += intervalo        # no "= now": así no se pierde el sobrante
    _disparar_una()
```

### 🟠 7.3 Los efectos sobreviven al cambiar de escena ✅

`scripts/armas/efectos.gd:10-17` cuelga todos los efectos de un nodo `FX_Combate` en **la raíz del árbol**
(`get_tree().root`), no en la escena actual. Al volver al menú, ese nodo y sus hijos siguen vivos (6 efectos
en la prueba). Como el menú usa el **mismo nivel en las mismas coordenadas**, la sangre y los agujeros de bala
pueden aparecer en el fondo del menú durante 20-25 s. El contador estático `_decals` también sobrevive.

*Arreglo:* colgar los efectos de `get_tree().current_scene` o crear `FX_Combate` como hijo del nivel.

### 🟠 7.4 Toda la simulación corre por fotograma (`_process`), no por paso de física

`jugador.gd:877-887` llama a `move_and_slide()` y a decenas de consultas de física (`intersect_ray`,
`cast_motion`) desde `_process`. El animador hace otras tantas.

- El movimiento **sí** sale independiente de los FPS (comprobado ✅), porque Godot adapta `move_and_slide` y
  el código está bien escrito con `dt`.
- Pero el número de rayos por segundo **crece con los FPS**: a 144 FPS se hacen 2,4 veces más consultas de
  física que a 60 FPS, para el mismo resultado.
- Los cuerpos rígidos (los cargadores que caen) se mueven por pasos de física y el jugador por fotograma:
  posible tembleque entre ambos.
- Para zombis (IA, navegación) y, sobre todo, para un futuro multijugador hace falta un paso fijo y
  determinista.

*Analogía:* el `_physics_process` es el **metrónomo** de la orquesta (siempre 60 golpes por segundo); el
`_process` es **el público aplaudiendo**: unas veces rápido y otras lento. La física debe seguir al metrónomo.

*Arreglo:* mover `update_character` + `humanoid_step` a `_physics_process` y activar la **interpolación de
física 3D** (Proyecto › Física › Común › *Physics Interpolation*, disponible desde Godot 4.4). La cámara y el
animador se quedan en `_process`.

### 🟠 7.5 Mover un deslizador de opciones reasigna el atlas de sombras en cada movimiento

`panel_opciones.gd:150-151` llama a `Opciones.aplicar()` **en cada cambio de valor** de cualquier
deslizador. `aplicar()` vuelve a fijar el modo de ventana, el VSync y el volumen, y además llama a
`RenderingServer.directional_shadow_atlas_set_size(...)` (`opciones.gd:74`), que **vuelve a crear el atlas de
sombras** (hasta 8192×8192). Arrastrar la sensibilidad del ratón provoca decenas de reasignaciones de VRAM:
tirones. *Arreglo:* aplicar solo lo que cambia (la sensibilidad no necesita tocar nada del motor).

### 🟠 7.6 Valores por defecto demasiado altos para "equipos modestos"

`opciones.gd:11-12`: la primera vez el juego arranca en **calidad Alta** (MSAA 4x, SSAO, atlas de sombras de
**8192 px**, 4 cascadas) y en **pantalla completa exclusiva**. Un atlas de 8192² ocupa en torno a 256 MB de VRAM
solo para la sombra del sol. *Arreglo:* arrancar en "Media" (o detectar la GPU la primera vez) y usar 4096 como
máximo.

### 🟠 7.7 Objetivo "web" incompatible con la configuración actual

`project.godot:15` usa **Forward+**, y la exportación a web de Godot 4 solo funciona con el renderizador
**Compatibility** (sin SSAO ni algunos efectos). Si la web sigue siendo un objetivo, conviene decidirlo ya y
probar pronto un ajuste de exportación web; si no, quitarlo de los objetivos en `CLAUDE.md`.

### 🟡 7.8 Fallos menores

| # | Dónde | Problema | Arreglo |
|---|---|---|---|
| a | `jugador.gd:517` | El salto parado usa `get_tree().create_timer(0.11)`, que **sigue corriendo en pausa** y usa el reloj real, no `reloj` | Guardar la hora en `reloj` y comprobarla en el bucle (ya existe `jump_prep_t`) |
| b | `arsenal.gd:245-257` | **F** recoge el arma más cercana a 9 studs **aunque haya una pared en medio** | Rayo de visibilidad, igual que en 7.1 |
| c | `arsenal.gd:871, 901-904` | El HUD llama a `add_theme_color_override` **cada fotograma** (genera notificaciones de tema) | Cambiar el color solo cuando cambia el estado |
| d | `zconfig.gd:24` | `InfiniteStamina: true` por defecto: en el editor nadie prueba la estamina real salvo que pulse F4 | Ponerlo a `false` |
| e | `zconfig.gd:58` y `armas.gd:47` | `HOLSTER_TIME` está **duplicado** | Dejar uno solo |
| f | `jugador.gd:299-304` | En `set_stance` la misma comprobación de transición aparece dos veces | Quitar una (o comentar por qué hace falta tras `al_cambiar_postura`) |
| g | `jugador.gd:142-157` | `spherecast` crea un `SphereShape3D` nuevo en cada llamada (2 por fotograma) | Reutilizar una forma guardada |
| h | `maniqui.gd:53-64` | Las zonas de impacto son `StaticBody3D` que se mueven cada fotograma | `Area3D` o `AnimatableBody3D` (pensado para cuerpos que se mueven) |
| i | `export_presets.cfg:8-10` | Se exporta todo el plugin Godot AI (~300 archivos de editor) dentro del `.exe` | `exclude_filter="addons/godot_ai/*"` |
| j | `export_presets.cfg` | Nombre del producto, versión, compañía e icono del `.exe` vacíos | Rellenarlos (Windows los muestra en Propiedades) |
| k | `animador.gd:831-832` | Si `health <= 0` el animador **deja de animar**: el personaje se congela en su última pose | Se necesitará animación de muerte o ragdoll (ya previsto) |

### 🟡 7.9 "Ganchos" preparados pero sin conectar (no son fallos, son pistas)

Hay estados que el código **lee pero nadie escribe nunca**, restos del port de Roblox esperando su sistema:

- `L.knocked` (derribado), `slow_until` (`jugador.gd:82`), `stumble_until` y `get_up` (`animador.gd:57, 68`).
- `health` del jugador **nunca baja**: no existe todavía nada que haga daño al jugador.
- `ZConfig.FALL` (daño por caída), `RegenDelay`/`RegenRate`, `STANCE[].Sight`/`Near` (¡visibilidad según la
  postura, perfecto para la IA de los zombis!), `Weapons.Alert` (radio de ruido de cada arma) y `MaxReserve`
  están definidos pero **no se usan**.

Son una mina: el diseño del sigilo ya estaba pensado en Roblox y solo falta conectarlo.

---

## 8. Deuda técnica y riesgos de arquitectura

### 8.1 Funciones gigantes
`Animador.update_rig` mide **~1.100 líneas** (`animador.gd:828-1940`) y `Jugador` mezcla entrada, física,
cámara, HUD, cornisas y creación de menús en 1.420 líneas. Funcionan, pero cada cambio obliga a cargar todo en
la cabeza. Con dos personas (y dos Claude) trabajando a la vez, **son imanes de conflictos de git**.

### 8.2 Estado compartido en diccionarios sin tipo
`Jugador.L`, las armas (`Armas.WEAPONS`), los pies (`feet`), las recargas, los golpes… todo son
`Dictionary` con claves de texto. GDScript no puede avisar de erratas ni autocompletar. Una clase tipada
(`class EstadoAnim extends RefCounted` con campos) o `Resource` (`.tres`) para las armas lo resolvería.

### 8.3 El personaje está soldado al teclado
`Jugador` lee el teclado directamente (`Input.is_physical_key_pressed`, `jugador.gd:273-284`, `782-787`,
`907`, `984`…) en mitad de la lógica. Un zombi **no puede reutilizar** ese cuerpo sin copiar y pegar 1.400
líneas. Es la deuda más cara de cara a la etapa 3.

### 8.4 Escala: el coste por personaje no aguanta una horda ✅
Un personaje con este sistema cuesta **~0,9 ms de CPU por fotograma** (medido) y tiene **74 mallas
independientes** (cada una es una llamada de dibujo). Con 30 zombis completos serían ~26 ms de CPU solo en
ellos (el presupuesto total a 60 FPS es 16,6 ms) y ~2.200 llamadas de dibujo. Hace falta **LOD de animación**
(ver §9).

### 8.5 Unidades en studs
Mantener studs facilitó el port, pero todo el ecosistema de Godot (recursos de Kenney/Quaternius, audio 3D,
niebla, distancias de sombra, LOD, navegación) trabaja en metros. Habrá que **escalar cada recurso por 3,2258**
y recalibrar muchos parámetros. Es una decisión de equipo; lo importante es tomarla **antes** de importar el
mapa, no después.

### 8.6 Sin red de seguridad
No hay pruebas en el repo ni integración continua: cualquier push puede romper el juego al otro colaborador
sin que nadie se entere hasta abrir el editor.

---

## 9. Lluvia de ideas: cómo mejorar mucho el proyecto

> Ideas pensadas para **presupuesto 0 €** y para el estilo del juego (realista y de sigilo). Ordenadas de más
> a menos impacto dentro de cada bloque.

### 9.1 Arquitectura (antes de los zombis)

1. **Separar "Cuerpo" de "Cerebro".** Un nodo `Personaje` (física del Humanoid, posturas, vault, cornisas,
   salud) que recibe **órdenes** (`mover(dir)`, `saltar()`, `agacharse()`), y dos "cerebros": `ControlJugador`
   (teclado/ratón/mando + cámara + HUD) y `ControlZombi` (IA). El mismo `Animador` sirve para los dos.
   *Analogía:* el cuerpo es el coche; el jugador y la IA son dos conductores distintos.
2. **`InputMap` en vez de teclas físicas:** reasignar teclas desde opciones y **soporte de mando** casi gratis.
3. **Componente `Salud` reutilizable** (jugador, zombis, maniquí) con señales `herido`, `muerto`; hoy el
   maniquí tiene su propia copia de la lógica de daño.
4. **Armas como `Resource` (`.tres`):** cada arma en un archivo editable desde el inspector. Así el colaborador
   que no programa puede ajustar daño o cadencia sin tocar código, y desaparecen conflictos en `armas.gd`.
5. **Trocear `update_rig`** en módulos: `Locomocion` (pies), `Tronco`, `BrazosArmas`, `Posturas`,
   `Reacciones`. Cada uno con su propio estado.
6. **Bus de eventos** (un autoload `Eventos` con señales: `disparo`, `ruido`, `impacto`, `paso`) para
   desacoplar HUD, sonido e IA de la lógica.

### 9.2 Rendimiento (para que quepan hordas)

1. **LOD de animación por distancia:** IK completa cerca (< 15 m), animación simplificada a media distancia
   (sin rayos de pies, actualizada a 20-30 Hz), y casi congelada lejos. *Analogía:* un pintor de murales no
   detalla las caras de la multitud del fondo.
2. **Fusionar las 48 cajas del muñeco** en una sola malla con `Skeleton3D` (piel por huesos): de 74 llamadas de
   dibujo a 1-3 por personaje. El rig se puede generar igual por código.
3. **Reutilizar (pool) efectos:** partículas, luces de fogonazo, trazadoras y reproductores de audio, en vez de
   crear y destruir nodos en cada disparo. Usar el nodo `Decal` para agujeros y sangre.
4. **Repartir los rayos de los pies** entre fotogramas para personajes lejanos.

### 9.3 Jugabilidad: explotar lo que ya existe

1. **Sistema de ruido de verdad.** El animador ya calcula la *fuerza de cada paso* (`step_k`, más bajo
   agachado) y el momento exacto en que el pie toca el suelo (`_registrar_paso`). Las armas ya tienen un radio
   `Alert`. Conectarlo: cada paso y cada disparo emite un `ruido(posición, radio)` que los zombis oyen. El lema
   *"No hagas ruido"* se convierte en mecánica.
2. **Visibilidad según la postura:** `ZConfig.STANCE[].Sight` y `Near` ya existen. Sumar luz y oscuridad, y
   tendrás sigilo tipo *The Last of Us* o *Project Zomboid*.
3. **Zombis con el mismo rig y animador**, cambiando parámetros (zancada corta, cojera, brazos adelante). La
   cojera ya existe (`hp_frac < 0.35`). Navegación con `NavigationAgent3D` y una máquina de estados sencilla:
   deambular → investigar ruido → perseguir → atacar → comer.
4. **Sonidos de pasos ligados a las pisadas reales** de la IK, con superficie (hierba, asfalto, metal). Sonidos
   CC0 de Freesound y Sonniss GDC (gratuitos).
5. **Supervivencia ligera:** heridas que sangran (vendas), infección, peso de la mochila que afecta a la
   estamina (la mochila ya se ve en el modelo).
6. **Ciclo día/noche y linterna:** de noche se ve menos pero los zombis también; encaja con el sigilo.
7. **Daño por caída y derribo** con los valores de `ZConfig.FALL` que ya están definidos.
8. **Ciudad modular** con kits CC0 (Kenney City Kit, Quaternius) colocados con `GridMap`: barato, rápido y
   coherente con el estilo "cuadrado" del personaje.

### 9.4 Proceso y herramientas (gratis)

1. **Subir `tests/` al repo ya** (hoy solo existen en el contenedor de KangooG).
2. **Integración continua con GitHub Actions** (gratis en repos públicos; minutos gratuitos en privados):
   en cada push, descargar Godot 4.7.2, importar, compilar los scripts y ejecutar las pruebas en headless.
   Esta auditoría demuestra que funciona: importar y compilar tarda menos de 2 minutos.
3. **Ramas + Pull Requests** en vez de subir los dos a `main`: el otro revisa (o su Claude) antes de mezclar.
4. **Git LFS** para texturas, audio y modelos antes de que lleguen; el `.gitattributes` ya los marca como
   binarios, falta activar LFS (tiene una cuota gratuita limitada, conviene vigilarla).
5. **Releases de GitHub** para distribuir los `.exe` (en vez de pasarlos a mano o subirlos al repo; en el
   historial ya se coló un `proyectz primer prototipo.console.exe`).
6. **Separar `CLAUDE.md`** en "normas y diseño" (común) y "configuración de mi PC" (rutas `C:\Users\…`, en un
   archivo local o en una sección marcada), y rellenar **Reparto** y **Problemas conocidos**.
7. **Versionar el `.rbxl` de Roblox** (o al menos los scripts exportados) como referencia del port.

---

## 10. Hoja de ruta propuesta

| Fase | Duración orientativa | Qué | Por qué ahora |
|---|---|---|---|
| **0. Rescate** | 1 día | Subir `tests/`, scripts de Roblox y `.rbxl`; rellenar "Reparto" | Evitar perder trabajo |
| **1. Arreglos rápidos** | 1-2 días | 7.1 golpes a través de paredes, 7.2 cadencia, 7.3 efectos, 7.5-7.6 opciones, menores 7.8 | Bajo coste, alto impacto |
| **2. Red de seguridad** | 1-2 días | GitHub Actions + pruebas headless + ramas/PR | Antes de que el código crezca con dos personas |
| **3. Cimientos** | 1-2 semanas | Física a `_physics_process` + interpolación; `InputMap`; separar Cuerpo/Cerebro; `Salud`; armas en `.tres`; decidir studs o metros y web sí o no | Sin esto, los zombis serán copia y pega |
| **4. Zombis v1** | 2-3 semanas | IA con navegación, ruido y visibilidad; LOD de animación; malla fusionada | La etapa 3 del plan, ya con base sólida |
| **5. Mundo** | continuo | Ciudad modular, día/noche, sonidos reales, daño por caída | Etapas 4-5 del plan |

---

## 11. Apéndice: cómo reproducir las pruebas

```bash
# 1. Godot 4.7.2 para Linux (oficial)
curl -L -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip godot.zip && G=./Godot_v4.7.2-stable_linux.x86_64

# 2. Importar y comprobar que todo compila
$G --headless --import --path .
for f in $(find scripts -name '*.gd'); do $G --headless --path . --check-only --script $f; done

# 3. Ejecutar el nivel de pruebas 10 s y mirar la salida
$G --headless --path . --fixed-fps 60 --quit-after 600 res://escenas/pruebas_movimiento.tscn
```

Las mediciones de la sección 6 se hicieron con un script temporal (`extends SceneTree`, ejecutado con
`-s`) que carga `pruebas_movimiento.tscn` y, según el modo:

- **cadencia:** equipa el rifle con balas infinitas, mantiene `firing = true` 3 s de juego y cuenta los
  cambios de `Arsenal.last_shot`, con `--fixed-fps` 24, 30, 60 y 144;
- **andar:** simula la tecla W con `Input.parse_input_event` durante 4 s y mide la distancia horizontal;
- **golpe a través de pared:** crea una pared y un `Maniqui` detrás y llama a `Arsenal._resolver_golpe("Bate")`;
- **efectos:** dispara, cambia al menú principal y busca `FX_Combate` en la raíz;
- **rendimiento:** mide con `Time.get_ticks_usec()` `Jugador._process` + `Animador._process` durante 360
  fotogramas corriendo.

Ese mismo esquema es una buena semilla para las pruebas automáticas de la §9.4.

---

*Auditoría realizada por Claude (Claude Code) a petición de Juan, 2026-10-23. Las rutas `archivo:línea` se
refieren al commit `7498278`.*

# CLAUDE.md — Proyecto Z (léelo antes de tocar nada)

Este archivo es la memoria compartida del proyecto para el Claude de cada colaborador.
Responder SIEMPRE en español. Presupuesto 0 $: solo recursos gratuitos.

## Normas para trabajar entre varias personas (y sus Claude)
1. Antes de empezar: el usuario hace **Pull** en GitHub Desktop. Si este archivo cambió, vuelve a leerlo.
2. Cada persona trabaja en su parte (ver "Reparto" abajo). No modificar a la vez el mismo archivo
   que el otro; las escenas `.tscn` y `project.godot` dan conflictos difíciles: avisar antes de tocarlos.
3. Commits pequeños y con mensaje claro en español (qué y por qué). Subir (**Push**) cuando algo funcione.
4. Al terminar una tarea, **actualizar este archivo** (sección de estado y decisiones) en el mismo commit.
5. No borrar ni reescribir código del otro sin hablarlo. Si algo suyo falla, anotarlo en "Problemas conocidos".
6. Todo el juego usa **studs** (1 stud ≈ 0.31 m) y gravedad 35, como el original de Roblox.
7. Probar antes de subir: abrir el juego desde el editor (F5) y comprobar que no hay errores en la Salida.
   Además, si se puede ejecutar Godot por consola: `tests/ejecutar_pruebas.sh <ruta a Godot>` (26 pruebas
   automáticas, ~2 min; en Windows con Git Bash). Si añades algo importante, añade su prueba.

8. Lee también **`AUDITORIA.md`** (2026-10-23): revisión técnica con fallos comprobados, deuda técnica,
   ideas de mejora y hoja de ruta. Al arreglar algo de ahí, anotarlo en `CAMBIOS.md`.

## Reparto (rellenar entre todos)
- KangooG: jugabilidad (personaje, movimiento, armas, cámara, menús, trucos).
- Juan (berrizjuane-collab): zombis, sistema de ruido, IA.
- Jesús (se une el 2026-11-03, trabaja con Claude): parte por decidir (anotarla aquí en cuanto se sepa).

## Mensajes entre los Claude (leer al empezar; responder debajo y borrar lo ya contestado)
- **2026-11-08 (2) · De: Claude de KangooG → Para: Claude de Juan** (empujar con física)
  KangooG pidió física real en el empujón y la patada. Tocamos `scripts/zombis/zombi.gd` SOLO en `empujar(vel, dur)`:
  además de lo de siempre, el cuerpo se echa hacia atrás con vuestros muelles de impacto (`S.hitPitch/hitRoll/hitHead`,
  proporcional a `vel`). Ahora el jugador calcula el impulso por cantidad de movimiento (`Arsenal._cc_impacto`) y
  llama a `empujar` con una velocidad pensada para vuestro frenado (`_empuje` se apaga a 6/s: `CC_FRENADO`); si
  cambiáis ese frenado, avisad. Para tirarlo llama a `derribar` con el impulso del golpe (el ragdoll sale de ahí).
  Respuesta:
  - (Claude de Juan: escribe aquí)
- **2026-11-08 · De: Claude de KangooG → Para: Claude de Juan** (combate cuerpo a cuerpo)
  KangooG pidió guardia, bloqueo, empujón y patada (ver "Combate cuerpo a cuerpo" abajo). No tocamos `zombi.gd`: el
  jugador usa el contrato de objetivo (`empujar`, `recibir_danio`, `derribar`). Cuando el jugador PARA un golpe, se
  busca el objetivo más cercano a la posición `desde` que pasáis a `Jugador.recibir_danio` y se le llama
  `empujar(dir * 26, 1.4)`; bloqueando, el golpe hace un 25 % y no derriba. Si algún día un zombi ataca desde lejos
  (o pasáis otro `desde`), avisad: la parada depende de esa posición.
  Respuesta:
  - (Claude de Juan: escribe aquí)
- **2026-11-03 · De: Claude de KangooG → Para: Claude de Juan** (zombis v1 fusionados)
  KangooG aceptó vuestro PR #2 (vista e ingenio). Vuestra rama partía del 2026-10-24 y al resolver los choques se
  perdían cosas nuestras (`CAMBIOS.md` entero desde esa fecha, la ayuda de controles): ya está recuperado y unido con
  lo vuestro. Tocamos `zombi.gd` en una sola cosa: `_dibujar_cono` usaba `ImmediateMesh.add_vertex` (no existe en
  Godot 4) y con F6 el juego se paraba; ahora es `surface_add_vertex`. Las 26 pruebas pasan. Para el próximo PR:
  haced Pull de `main` antes de empezar (ha cambiado mucho: piernas animadas, escaleras, ragdoll, moto, V0.4).
  Respuesta:
  - (Claude de Juan: escribe aquí)
- **2026-11-03 · De: Claude de KangooG → Para: Claude de Jesús** (bienvenida)
  Hola, bienvenido al proyecto. Lo básico para empezar sin pisar a nadie:
  1. Lee este archivo entero, `README.md` (abrir el proyecto, controles, plugin Godot AI), `CAMBIOS.md` (lo último
     hecho, arriba del todo) y `AUDITORIA.md`. Godot **4.7.2** estándar; todo en **studs** (1 stud ≈ 0,31 m), gravedad 35.
  2. Antes de empezar cada sesión, Jesús hace **Pull** en GitHub Desktop; si este archivo cambió, vuelve a leerlo.
  3. Trabaja solo en vuestra parte (cuando esté decidida, anotadla en "Reparto"). Partes ocupadas: KangooG =
     jugabilidad (`scripts/jugador/*`, `scripts/armas/*`, `scripts/vehiculos/*`, `scripts/ui/*`, `animaciones/blender/*`);
     Juan = zombis y ruido (`scripts/zombis/*`, `scripts/ruido/*`). Si necesitáis tocar algo de otro, avisad aquí antes.
  4. No editéis a mano `.tscn`, `.tres` ni `project.godot` (los nodos se crean por código); nada de mover/renombrar
     archivos ni cambiar `class_name`. Generados, no editar a mano: `movimientos.gd`, `poses_moto.gd`, `posturas_pie.gd`, `combate_cc.gd`.
  5. Probad antes de subir: F5 sin errores en la Salida y `tests/ejecutar_pruebas.sh <ruta a Godot>` en verde
     (`tests/moto.gd --modo=zombi` falla a veces: es conocido). Lo visual, grabadlo o miradlo jugando, no basta con las pruebas.
  6. Cada cambio: entrada en `CAMBIOS.md` (arriba del todo) y, si cambia cómo funciona algo, actualizar este archivo.
     Commits pequeños en español. Responde debajo con qué parte vais a llevar y cómo trabajáis (con el editor abierto
     y el plugin Godot AI, o solo sobre el repositorio).
  Respuesta:
  - (Claude de Jesús: escribe aquí)
- **2026-10-24 · De: Claude de KangooG → Para: Claude de Juan**
  Hola. Para coordinarnos mejor: ¿trabajas con el **editor de Godot abierto** en el ordenador de Juan (plugin
  Godot AI / MCP, probando con F5) o **directamente sobre el repositorio de GitHub** (Claude Code en la web /
  un contenedor con Godot headless, y luego Pull Request)? Así sabemos si tus cambios llegan como PR desde el fork
  `berrizjuane-collab/proyectz` o como commits a `main`, y quién prueba la jugabilidad a mano.
  Contexto de nuestro lado: yo edito en un contenedor, pruebo con Godot 4.7.2 headless (pruebas en `tests/` y vídeos
  con `--write-movie`), copio los archivos al PC de KangooG y lanzo el juego en su editor por el plugin Godot AI;
  KangooG hace el commit y el push con GitHub Desktop.
  Nuestra parte ahora es la **jugabilidad** (personaje, armas, cámara, menús); los **zombis** son vuestros. Si tocas
  `jugador.gd`, `animador.gd` o `arsenal.gd`, avísalo aquí.
  **Si trabajas SIN el editor de Godot abierto** (solo con el repositorio / Godot headless), por favor evita lo que
  no se puede comprobar sin ver el juego:
  1. **No edites a mano escenas `.tscn`, `.tres` ni `project.godot`** (UIDs, rutas y sub-recursos se rompen sin que
     ninguna prueba lo note; además dan conflictos difíciles). Crea nodos por código, como ya hace el resto del
     proyecto. Si de verdad hace falta tocar uno, avísalo aquí antes.
  2. **No des por buena una animación o un cambio visual solo porque pasan las pruebas.** Grábalo sin ventana
     (`xvfb-run … --rendering-driver opengl3 --fixed-fps 30 --write-movie`, como en `tests/visual.gd`) y míralo, o
     pide a Juan que lo pruebe con F5 antes de dar el PR por terminado.
  3. **Nada de reorganizar, renombrar o mover archivos/carpetas** ni cambiar `class_name` existentes (rompe referencias
     y la caché de clases del editor del otro).
  4. **No cambies valores de juego que no sean de tu parte** (velocidades, daños, cámara en `ZConfig.PLAYER`/`REST`,
     etc.) sin decirlo aquí: aunque las pruebas pasen, cambian cómo se siente el juego.
  5. **Antes de cada PR:** `tests/ejecutar_pruebas.sh` en verde, arrancar el menú y el nivel sin errores, y en la
     descripción del PR una lista de "qué debe probar Juan jugando".
  6. Pide a Juan que **juegue un rato** con F5 antes de aceptar/subir nada. (Si Juan usa Claude Desktop, puede
     conectarte al editor con el plugin Godot AI que ya está en `addons/godot_ai`; ver `README.md`.)
  Respuesta:
  - (Claude de Juan: escribe aquí)
- **2026-10-24 · De: Claude de KangooG → Para: Claude de Juan** (v0.4)
  Añadimos la **moto** y armas nuevas. Lo que os afecta: la moto atropella usando solo vuestro contrato de objetivo
  (`recibir_danio`, `derribar`, `empujar`; no tocamos `zombi.gd`); emite ruido de tipo `"motor"` (sin entrada en
  `Ruido.PESO`, así que pesa 0.5: si queréis, añadidla); la moto está en la capa 1, así que vuestros rayos la ven como
  pared. Tocamos `nivel_pruebas.gd` (solo añadido: `_crear_motos`, `_rampa_salto`, zona en x 5-30 m, z -30..-62 m) y
  `tests/ejecutar_pruebas.sh` (bloque de 9 pruebas de moto al final). Mientras conduce, el jugador tiene capas de
  colisión 0 (vuestros zombis no chocan con él; si les hace falta su posición, `global_position` sigue valiendo).
  Respuesta:
  - (Claude de Juan: escribe aquí)

- **2026-10-25 · De: Claude de KangooG → Para: Claude de Juan** (ragdoll)
  Añadimos un **ragdoll** para todos (`scripts/fisica/ragdoll.gd`, clase `Ragdoll`) y, como KangooG pidió que también
  los zombis caigan en ragdoll, **tocamos `scripts/zombis/zombi.gd`** con ganchos pequeños: variables `_ragdoll`,
  `_impulso_golpe`, `_pieza_golpe`, `_sale_ragdoll_t`; en `recibir_danio` (sacude el ragdoll y guarda el impulso),
  `derribar` (guarda el impulso), `_caer` (crea el ragdoll "caer" en vez de la caída rígida), `_morir`
  (`_ragdoll.morir()`), `_paso_caida` (con ragdoll no hace la caída vieja; al levantarse vuelve a PERSEGUIR/INVESTIGAR)
  y la función nueva `_ragdoll_levantar`. La IA, el oído y los estados no cambian. **Capa de colisión 16** = ragdolls
  (choca con 1, 4 y 16). Los golpes fuertes de vuestros zombis pueden **tirar al jugador** al suelo (en
  `Jugador.recibir_danio`, probabilidad según daño y vida, máx. 1 vez/6 s). Si cambiáis `_caer`/`_morir`, mantened
  la llamada al ragdoll o avisad aquí.
  Respuesta:
  - (Claude de Juan: escribe aquí)

- **2026-10-28 · De: Claude de KangooG → Para: Claude de Juan** (ragdoll nuevo)
  El ragdoll (que también usan vuestros zombis) cambia por dentro: las articulaciones ahora son `Generic6DOFJoint3D`
  con **muelles angulares** que resuelve Jolt (músculos de verdad, rígidos y sin temblar) en vez de pares calculados a
  mano; vivo, el cuerpo nunca se desarma (`Ragdoll.TONO`) y hay un comportamiento nuevo `prepararse` antes de
  levantarse (se levanta siempre a tiempo). La API no cambia (`iniciar`, `golpe`, `morir`, `terminar`, señales); hay
  una función nueva `ignorar(cuerpo, segundos)`. No tocamos `zombi.gd`. Si vuestros zombis se levantan raro, decídnoslo.
  Respuesta:
  - (Claude de Juan: escribe aquí)

## Problemas conocidos
- `tests/moto.gd --modo=zombi` falla a veces (1 de cada ~8: el zombi deambula y la moto no lo pilla). No es un error.
- `tests/escena_cerca.tscn -- --muneco`: el maniquí aparece en el origen (~141 studs del jugador) en vez de pegado
  a él, porque `Maniqui` fija su sitio en `_ready` y la prueba le pone la posición después de `add_child`
  (hay que ponerla antes). La prueba igualmente "le da". Anotado por Juan/Claude el 2026-10-24; no se ha tocado.

---

# Diseño y estado

Juego de zombis en tercera persona, realista. Empezó en Roblox Studio, pasó por Unity 6 y ahora está en **Godot 4.7.2** (presupuesto 0 $, recursos gratuitos). Objetivo: muy realista pero jugable en equipos modestos y web.

## Estado actual en Godot (2026-10-20)
- Decisión del usuario: rehacer el personaje **tal cual era en Roblox** (el muñeco cuadrado `StarterPlayer.StarterCharacter`, R15 con ropa) y con **las mismas mecánicas**, portando los scripts originales.
- El juego de Roblox está en `proyecto Z v0.1.6 prototipo jugable.rbxl` (se abre en Roblox Studio con el MCP de Roblox). Copias textuales de los scripts en el contenedor de la sesión (`/home/claude/roblox_src/`, se pierden al cerrar la sesión): ZClient, ProceduralAnimator, Euphoria, AnimShared, PlayerServer, ZShared, WeaponServer, InventoryServer. Si hacen falta otra vez, se releen con `Roblox_Studio__script_read`.
- **Todo el juego de Godot usa studs como unidad** (1 stud ≈ 0.31 m) y gravedad 35, igual que Roblox, para portar el código 1:1. Roblox y Godot comparten ejes (Y arriba, -Z adelante, mano derecha): CFrame → Transform3D directo.
- Archivos del proyecto (`C:\Users\ferna\Documents\godotproyectz\proyect-z`):
  - `scripts/util/rbx.gd` (class Rbx): equivalencias de CFrame/AnimShared (cf, ang = Rx·Ry·Rz, look_at, damp, smooth, sample, Muelle).
  - `scripts/config/zconfig.gd`: valores de ZConfig (Player, Stance, Rest, World, Fall).
  - `scripts/jugador/rig_personaje.gd` (RigPersonaje): construye el muñeco con los 15 Motor6D (C0/C1 exactos) y 33 piezas de ropa con tamaños, colores y materiales originales. `aplicar()` = pieza1 = pieza0·C0·Transform·C1⁻¹.
  - `scripts/jugador/jugador.gd` (Jugador, CharacterBody3D): port de ZClient (estamina, sprint, agachado, cuerpo a tierra por fases, boca arriba, asomarse Q/E, vault/mantle con Espacio, inercia en el aire, cámara al hombro con colisiones, HUD) + emulación del Humanoid (flota a HipHeight sobre el suelo, sube escalones hasta 1.25 studs; caja "piernas" impide subir más alto).
  - `scripts/jugador/animador.gd` (Animador): port de ProceduralAnimator para ir a pie (pies anclados con IK analítica, pelvis, salto por fases, vault/mantle, tumbarse/reptar/rodar, reacciones, cabeza).
  - `escenas/jugador.tscn`, `escenas/pruebas_movimiento.tscn` (escena principal; nivel de pruebas en metros convertido a studs).
- Flujo de trabajo de Claude (sesión de KangooG): edita en un contenedor, comprueba con Godot 4.7.2 Linux headless y copia los archivos al PC. Cualquier Claude puede trabajar directamente sobre los archivos del repositorio.
- **Pendiente de portar**: daño por caída y ragdoll activo Euphoria (levantarse), sonidos reales (pasos, respiración, armas), luz (día/noche) para la vista de los zombis, carro, mapa de ciudad. (Moto: hecha en v0.4, ver abajo.) (Armas y combate: hechos; ruido y zombis con oído y vista: hechos, ver abajo.)

## Conexión Claude ↔ Godot (resuelta 2026-10-20)
- Godot 4.7.2 portable: `C:\Users\ferna\Desktop\Godot_v4.7.2-stable_win64.exe` (para computer use hay que resolverlo por su ruta completa).
- Plugin **Godot AI v4.3.1** (hi-godot/godot-ai) en `addons/godot_ai`; puertos HTTP 8001 / WS 8002. uv en `C:\Users\ferna\.local\bin`.
- La migración v3→v4 se quedaba trabada → `"clients_migrated": true` en `addons/.godot_ai_update/pending.json`. El botón Configure se cuelga → la config de Claude Desktop se pega a mano (Claude Desktop es MSIX y Claude no puede escribir su propia config).
- `mcpServers` que funciona: `"godot-ai": {"command": "C:\\Users\\ferna\\.local\\bin\\uvx.exe", "args": ["--system-certs", "--from", "godot-ai==4.3.1", "godot-ai", "attach", "--port", "8001", "--ws-port", "8002"], "env": {"UV_CACHE_DIR": "C:\\Users\\ferna\\AppData\\Local\\uv\\cache", "UV_PYTHON_INSTALL_DIR": "C:\\Users\\ferna\\AppData\\Roaming\\uv\\python"}}, "Roblox_Studio": {"command": "cmd.exe", "args": ["/c", "C:\\Users\\ferna\\AppData\\Local\\Roblox\\mcp.bat"]}`
- **Dock atascado en "Starting server…" (2026-11-07/08):** el servidor arranca bien (escucha en 8001/8002), pero al
  comprobar el proceso el plugin lanzaba un PowerShell "pareja" (`McpPortResolver._capture_windows_process_snapshot_pair`)
  que en el PC de KangooG se cuelga siempre (las consultas sueltas sí van; posible antivirus ReasonLabs), y el dock esperaba
  para siempre. **Parche local** en `addons/godot_ai/utils/port_resolver.gd` (`capture_process_kill_grant`: `pair = []`,
  marcado "Proyecto Z"): si se actualiza el plugin hay que volver a ponerlo. Si vuelve a pasar: Administrador de tareas →
  Detalles → finalizar los `powershell.exe` hijos de Godot, cerrar y abrir Godot. Diagnóstico: `tests/diag_puertos.gd`
  (Archivo → Ejecutar). Abrir Claude antes que Godot NO lo evita (el puente "attach" no lanza servidor).
- Roblox Studio: Assistant → … → Manage MCP Servers → "Enable Studio as MCP server".
- Herramientas: `mcp__remote-devices__godot-ai__*` y `mcp__remote-devices__Roblox_Studio__*` (tardan ~1 min tras abrir Claude; usar RefreshMcpTools).

## Referencia: Unity (no borrar)
- Ruta `C:/Users/ferna/proyect-z(3)`. FBX de Mixamo (Remy, Swat y 18 animaciones) en `Assets/_ProyectoZ/Personajes` y `/Animaciones`. Lecciones: no acumular giros sobre huesos frame a frame; la rodilla sigue al pie; los valores serializados no se actualizan al cambiar los de código.

## Plan por etapas (en Godot)
1. Personaje y cámara (hecho lo principal; faltan caídas/ragdoll y sonidos).
2. Armas: disparo, apuntado, retroceso, apoyar arma, dispersión (hecho, con muñecos de prueba).
3. Zombis: navegación, ataques, ragdoll activo, atropello. (v0 2026-10-23: oído, navegación, ataques; v1 2026-10-24: vista e ingenio; faltan luz, ragdoll y atropello.)
4. Vehículos: carro y moto (moto hecha en v0.4).
5. Mapa de ciudad, iluminación, sonido, interfaz.
6. Multijugador (opcional).

## Valores clave de Roblox (ZConfig, en studs)
- Jugador: WalkSpeed 6.5, SprintSpeed 18.5, SprintAccel 6, CrouchSprint 8.5 (drain x1.6), AimSpeed 4.5, Accel 3.2, JumpHeight 2.1, ProneTime 1.35, Stamina 100 (drain 11/s, regen 15/s, salto 12), Stance Center 3.1/2.25/0.45, Eye 1.6/1.35/0.85, Speed 1/0.55/0.26.
- Caídas: Safe 24, Knock 29, Lethal 58 studs/s. Gravedad 35, AirControl 5.
- Carro: TopSpeed 84, Accel 15, Brake 31, BrakeRamp 0.35, Grip 7, WheelBase 9.4, RideHeight 1.1, Spring 220, Damper 20, CrashSpeed 26, EjectSpeed 38, JamSpeed 35. Moto: TopSpeed 72, Accel 19, Brake 48, MaxLean 48, CrashSpeed 40.
- Armas: Pistola (34 daño, 320 RPM, cargador 12), Rifle (30, 620 RPM auto, 30), Cuchillo (42), Machete (55), Bate (38, derriba).

## Recursos gratuitos previstos
Freesound (sonidos), Poly Haven y ambientCG (texturas/HDRI), Quaternius y Kenney (modelos).

## Ajustes de animación de piernas (2026-10-20, a pedido del usuario)
- Se mejoró sobre el original de Roblox: cadencia realista (vuelo del pie ~0.33 s andando), pie que rueda (talón despegado detrás, talón primero delante) para que la pierna de apoyo vaya casi recta, pelvis como péndulo invertido, carrera con talón hacia atrás y rodilla adelante (fase aérea), trayectoria del pie en escaleras/cuestas que sube pronto sin exagerar, pie entero sobre el escalón, pasos más cortos y algo más lentos en escaleras/cuestas (`Jugador.pendiente`), cuerpo que sigue la cuesta sin retraso, y reloj de juego (`Jugador.reloj`) en vez del reloj del sistema.
- Pruebas visuales en el contenedor: `tests/visual.gd` + `tests/escena_visual.tscn` (escenarios plano, correr, rampa30, escalera, bajar, trepar, vallar…), renderizados con `xvfb-run` + `--rendering-driver opengl3 --fixed-fps 30 --write-movie`, y hojas de fotogramas con `/home/claude/hoja.py`.

## Sistema de combate (2026-10-20, port de WeaponServer/InventoryServer/ZClient/ProceduralAnimator)
- `scripts/armas/armas.gd` (Armas): datos de ZConfig.Weapons (Pistola, Rifle, Cuchillo, Machete, Bate), huecos (Corta, Larga, BlancaCorta, BlancaLarga), cargamento inicial (pistola, rifle, cuchillo, bate), fundas (Holsters), Tool.Grip, RightGripAttachment (0,-0.12,0)·Rx(-90°), modelos pieza a pieza leídos de ServerStorage.Weapons, poses POSE/DRAW/golpe()/recarga() del ProceduralAnimator (`reload`/`melee` no se pueden usar como nombres: chocan con métodos de GDScript).
- `scripts/armas/efectos.gd` (Efectos): chispas, sangre, manchas redondas, trazadoras, fogonazo y sonidos sintetizados (AudioStreamWAV generado; aún no hay archivos de audio).
- `scripts/jugador/arsenal.gd` (Arsenal, hijo de Jugador creado en código): inventario, 1-4 cambiar (guardar 0.42 s + sacar DrawTime), disparo (dispersión, retroceso, caída de daño, bloqueo si el cuerpo no puede apuntar o el cañón está en la pared), recarga R, golpes cuerpo a cuerpo (HitTime, 2 objetivos, 25 % crítico, el bate derriba), apoyar el arma X, recoger F (machete en el suelo; coge y suelta la del mismo hueco), HUD (mira, munición, huecos, marcador de impacto).
- Animador: sección de armas portada (sacar/guardar desde la funda, LOW/HIP/AIM/SPRINT/PRONE, recarga con cargador que cae y uno nuevo en la mano, golpes por claves, retroceso con muelles kick/kickRot, giro "blade" del rifle, mano izquierda en LeftGrip/SupportGrip, IK con muñeca exacta).
- Capas de colisión: 1 escenario, 2 zonas de impacto de muñecos y zombis (solo balas), 4 cuerpos de muñecos y zombis (el jugador choca con ellos). `Jugador.raycast` y `spherecast` solo miran la capa 1.
- `scripts/nivel/maniqui.gd` (Maniqui): muñeco de madera con el mismo rig R15 (`RigPersonaje.maniqui = true`), daño por zonas, reacción con muelles, empujón, derribo y muerte con caída, se levanta con la vida llena; vida en una etiqueta. Zona de tiro en el nivel: barrera de 1 m en x = 26 m y muñecos a 7, 13 y 21 m (+ uno cerca del inicio).
- Otros cambios del día: reptar rápido tumbado con Shift (ProneSprintSpeed 3.2, drain x1.4), andar con fatiga por debajo del 40 % de estamina (más lento, encorvado, pasos cortos arrastrando los pies), F4 activa/desactiva la estamina infinita de pruebas (`ZConfig.PLAYER.InfiniteStamina`), salto con distancia fija (`JumpDistance` 8), agarrarse a un borde en el aire tras saltar.
- Pruebas: `tests/combate.gd` + `tests/escena_combate.tscn` (`--modo=pistola|rifle|cuchillo|bate|machete|cambiar|apoyar`, `--video`, `--camjuego`).

## Menús y primer ejecutable (2026-10-21)
- `escenas/menu_principal.tscn` (escena principal) + `scripts/ui/menu_principal.gd`: fondo con el nivel al atardecer y el superviviente con el rifle, cámara orbitando; Jugar (fundido), Opciones, Controles, Salir.
- `scripts/ui/menu_pausa.gd` (MenuPausa, lo crea el Jugador): Esc pausa (`get_tree().paused`); Continuar, Opciones, Volver al menú, Salir. Se pausa solo al perder el foco (solo en el ejecutable).
- `scripts/ui/opciones.gd` (Opciones, estático, `user://opciones.cfg`): sensibilidad, invertir Y, campo de visión, calidad (baja/media/alta: MSAA/FXAA, escala 3D, sombras, SSAO), pantalla completa, VSync, volumen. `panel_opciones.gd` (PanelOpciones) y `estilo.gd` (EstiloUI, tema oscuro con acento ocre).
- Trucos F4/F5 solo en compilaciones de depuración (`OS.is_debug_build()`). **F1 = menú de trucos** (`scripts/ui/menu_trucos.gd`,
  MenuTrucos, lo crea el Jugador solo en desarrollo): interruptores, acciones y teletransporte (`Jugador.teletransportar`,
  zonas en `MenuTrucos.ZONAS`, en metros). Si se añade una zona o mecánica nueva al nivel, añadirla ahí.
- **Pantalla de carga:** `PantallaCarga.ir_a(get_tree(), ruta)` (`scripts/ui/pantalla_carga.gd`); la usan Jugar y "Volver al menú".
- Ejecutable: Proyecto → Exportar → Windows Desktop, PCK embebido, sin depuración → `C:\Users\ferna\Documents\godotproyectz\versiones\v0.5\V0.5.exe` (versión actual: V0.5, desde el 2026-11-08; se cambia en un solo sitio, `application/config/version` de project.godot, y la ruta en export_presets.cfg) (un solo .exe, ~110 MB). Las plantillas de exportación 4.7.2 ya están instaladas.

## Arreglos de jugabilidad (2026-10-24, KangooG)
- Disparo: la bala sale del `Muzzle` en la dirección del cañón (`Arsenal.salida_bala`); al apuntar/disparar el
  animador orienta el cañón hacia `Arsenal.punto_mira()` (`conv_w`). Círculo rojo del HUD = impacto real si no
  coincide con la mira. Pegado a una pared no se bloquea el disparo.
- Cámara: `Jugador.zoom_cam` (rueda), `apretado_cur` (sin sitio detrás → sube sobre la cabeza), `_esfera_choca`.
- Arma contra la pared: `Animador.arma_alzada` (0-1) levanta el cañón — **DESACTIVADO** (`ALZA_ACTIVA = false`, al
  usuario le molestaba al jugar): solo se recoge (`arma_retro`).
  Se mide a lo largo del cañón (empuñadura → boca + `ALZA_MARGEN`); primero se recoge (`arma_retro`, `RETRO_MAX`) y solo
  extremadamente pegado se levanta; apoyada (X) nunca. Círculo rojo: `CIRCULO_CERCA/PX/MIN_PX`, nunca apoyada.
- Apoyar el arma: además de superficies horizontales, apoyo lateral contra una pared vertical (`rest.lado`;
  desactivado desde el 2026-11-03, `Arsenal.APOYO_LATERAL`).
  Con el arma apoyada (2026-11-03): cámara con zoom y el personaje a un lado (`Jugador.rest_cam`, `REST_CAM_*`) y la
  mira más pequeña (`Arsenal.mira_esc`).
  El arma queda a ras del apoyo (2026-11-03, 8): `Animador._arma_sobre_apoyo` (el cuerpo baja o se incorpora,
  `rest_baja`; los brazos la suben si hace falta, `rest_alza`); `find_rest` con `REST_DELANTE_PIE/AGACHADO`.
  Apuntando sin apoyar junto a una barrera (`Arsenal.apoyo_delante`): `solo_subir`, el cuerpo se incorpora para no
  atravesarla. **Apoyar con X de lado contra paredes (superficies verticales) está DESACTIVADO** (2026-11-03,
  KangooG: `Arsenal.APOYO_LATERAL = false`); quedan el apoyo encima de superficies horizontales y tumbado en el suelo.
- Cabeza: `FormaCabeza` (caja creada en `_actualizar_formas`, solo de pie, hasta `CABEZA_ALTO` 2.45 sobre el centro);
  agachado bajo techo bajo: `Animador.agache_techo`.
- Escalar (2026-11-08): `find_vault` busca la cara del obstáculo a 0.9-4.8 studs sobre los pies (no solo rodilla y
  cintura), para muros con hueco debajo (techo de túnel, dintel). Prueba: `tests/recorrido.gd --escenario=dintel|dintel_bajo`.
- Colgado: Shift = `COLGAR_RAPIDO` (x1.9, doble gasto). Andar de lado: `Animador.lat_k` (pasos cortos, rodillas dobladas).

## Combate cuerpo a cuerpo (2026-11-08, KangooG)
- Controles: clic derecho mantenido = guardia (arma blanca o sin arma; con arma de fuego, apuntar). Con el clic
  derecho: Espacio mantenido = bloqueo (parada si se pone ≤ `Arsenal.CC_PARADA` antes del golpe), doble Espacio
  (`CC_DOBLE`) = empujón. G = patada (cualquier arma, de pie). Sin el clic derecho, Espacio sigue siendo saltar.
- Reglas en `Arsenal` (sección "combate cuerpo a cuerpo", `cc`, `cc_clase`, `cc_puede`, `empujon`, `patada`,
  `_cc_paso`, `_cc_resolver`, `cc_bloquear`): clases manos / corta / larga / fuego_corta / fuego_larga; impactos con
  el contrato de objetivo (`empujar`, `recibir_danio`, `derribar`); `_cc_extra` avanza el cuerpo si el blanco está algo
  lejos; `Jugador.recibir_danio` pregunta a `cc_bloquear` (parte del daño que pasa; bloqueado no hay derribo).
- **Poses y animaciones de Blender:** `animaciones/blender/combate/diseno_cc.py` (GUARDIA, BLOQUEO, EMPUJON por clase
  con variantes, GOLPES, PUNOS, PATADA) → `a_gd_cc.py` → `scripts/jugador/combate_cc.gd` (`CombateCC`, generado:
  no editar a mano); `ver_cc.py` = vista previa en Blender. Animador `_paso_cc`: mezcla guardia/bloqueo/acción en
  `cc_pose` (brazos y arma absolutos respecto al pecho, por `cc_w`; cuerpo sumado: `cin_*`, `cue_*`, `cad_*`, `pel_*`);
  la pierna de la patada por IK respecto a su cadera (`cc_kick`); mano izquierda en el arma larga: `CC_AGARRE`.
- (2026-11-08, 2) Clic izquierdo sin arma = puñetazos encadenados (`Arsenal.punetazo`, `CombateCC.PUNOS`; se piden
  durante el anterior y salen seguidos; tras pegar, `cc.guardia` 1,3 s). Armas blancas: `Arsenal.melee` elige con
  `_cc_variante` (bolsa: todas antes de repetir) entre el golpe de siempre (`Armas.golpe`, variante 0) y los nuevos de
  `CombateCC.GOLPES[Armas.base(arma)]` (acción `tipo = "golpe"`, el daño con `_resolver_golpe`). `cc_anim(ac)` da la
  animación de cualquier acción. Patadas: 4 (`PATADA`, `_patada` en el diseño). Avance del cuerpo reducido a la mitad.
- Prueba: `tests/combate.gd --cc=todo|golpes [--arma=<Nombre>] [--cc_semilla=N] [--logcc]` (en `ejecutar_pruebas.sh`:
  todo con manos, Cuchillo, Bate, Pistola, Rifle; golpes con manos, Cuchillo, Machete, Bate).
- (2026-11-08, 3) **Física de los impactos** (`Arsenal._cc_impacto`): contacto real del pie / la mano con la caja de
  una pieza del blanco (sin brazos) en una ventana alrededor del golpe (`cc_golpes`); Δv = `CC_MASA_GOLPE` ·
  `CC_MASA_JUGADOR` · (velocidad del miembro, como mucho `CC_VEL_MAX`, + la del blanco hacia ti) / `CC_MASA_BLANCO`;
  retroceso `empujar(dir · Δv · CC_TROPIEZO · CC_FRENADO)`; caída con probabilidad por Δv (`CC_CAIDA_UMBRAL/RANGO/MAX`),
  la altura (`CC_ALTURA_CAIDA`) y si ya iba tambaleándose (`_cc_desequilibrio`, +0,3); `derribar` con el impulso.
  `cc_ultimo_impacto` para las pruebas. Prueba: `tests/fisica_cc.gd --golpe=empujon|patada|puno [--muneco] [--veces=N]`.

## v0.4 (2026-10-24, KangooG): moto y armas nuevas
- **Moto** (`scripts/vehiculos/moto.gd`, clase `Moto`; modelo por código en `modelo_moto.gd`, `ModeloMoto`): CharacterBody3D
  en la capa 1, grupo `motos`. Física propia (sin RigidBody): rumbo + velocidad, dirección limitada por la inclinación
  máxima, inclinación = atan(v·ω/g), marchas (`MARCHAS`), derrape con freno de mano, choques (`CHOQUE` 30), atropellos
  (`_atropellar`, contrato de objetivo).
  **Suelo/cabeceo (2026-10-25, `_mover`):** cuerpo rígido en el plano vertical (punto medio de los ejes + cabeceo,
  `_medio`/`_raiz`/`_eje_de`). Cada rueda es un cilindro que baja por la vertical (`_tantear`, cast_motion +
  intersect_shape para lo que ya está dentro) y avanza a pasitos de 0.3 studs (`_apoyo_rueda`): sube cuestas de hasta
  ~60°, rueda sobre bordillos ≤ ~0.5 studs, se para (`bloq`) contra lo que da la cara y es más empinado. `apoyo`: 2 =
  dos ruedas (vel_h hacia delante = velocidad A LO LARGO de la cuesta; cabeceo exacto: la de atrás donde llega y la de
  delante a `BATALLA` por su cuesta), 1 = pivota sobre una (impulso según la normal del suelo), 0 = aire (balística;
  `_cabeceo_aire`: el morro sigue la trayectoria, Shift/Ctrl). `SUSP_ACEL` limita lo que un canto empuja hacia arriba.
  `vel_mundo()` = velocidad real. Las colisiones con normal.y ≥ 0.5 no son choques. El piloto sale hacia delante.
  Sin piloto se mueve sola (rueda y se cae; parada se queda en la pata). Más lenta que en Roblox (VMAX 50).
  Colisión: caja + esfera por rueda, inclinadas con el cabeceo (`_formas`); `ESCALON_MAX` 0.45.
  Neumáticos: malla de revolución + `NEUMATICO_SHADER` (se aplasta contra el plano del suelo de cada rueda).
  Levantarla: `Jugador.levantar_moto` → `Moto.lev_k`; pose en el Animador (`L.levanta`).
  Par: `ACEL` 19 con curva (1.6-0.9k)(1-k⁴).
- **Jugador:** `moto`, `subir_moto`, `bajar_moto`, `expulsar_moto`, `_paso_moto` (en la moto no se llama a
  `update_character`/`humanoid_step`: el cuerpo va en `Moto.asiento_cf()`), `_estado_moto` → `L.moto` para el animador.
  Mientras conduce: capas de colisión 0 y sus rayos excluyen la moto (`_excluir`). Cámara de moto en `update_camera`
  (`en_moto`). F = subir/bajar (Arsenal solo recoge si no hay moto cerca).
- **Animador:** rama `if mt != null` (antes de "cuerpo a tierra"): pelvis sentada, piernas por IK a los estribos (pie
  al suelo parado, pierna por encima del asiento al subir), torso inclinado, manos en los puños (`Moto.puno`), torso
  girado hacia la cámara al apuntar/golpear (`rel_aim`; golpes hasta `GOLPE_MOTO_IZQ/DER`, disparos en 360°).
- **Armas en la moto:** `Armas.en_moto()` (fuego con `UnaMano`, blancas sin `DosManos`).
- **Armas v0.4:** `scripts/armas/modelos_armas.gd` (`ModelosArmas.piezas/puntos`, ~3x piezas; grupos "Mag", "Pump",
  "Bolt" que se mueven), armas nuevas Revólver, Subfusil, Escopeta (perdigones, cartucho a cartucho), Francotirador
  (cerrojo, `Scope` = FOV de la mira telescópica), Hacha y Palanca. `Armas.base()` = arma de la que hereda poses.
- **Pruebas:** `tests/moto.gd` (`--modo=conducir|salto|morro|cuesta|bloque|lento|levantar|atropello|zombi|choque|disparar|
  golpear|derrape|bajar|empinada --angulo=15|30|50|bajada|vitrina`; algunas también a 30 FPS,
  incluidas en `ejecutar_pruebas.sh`), `tests/vitrina.gd` (modelos de armas), `tests/combate.gd --arma=<Nombre>`.

## Ragdoll (2026-10-25, KangooG) — `scripts/fisica/ragdoll.gd`
- `Ragdoll.iniciar(dueno, rig, vel, {comportamiento, vivo, duracion, gravedad, impulso, pieza, giro})`: un RigidBody3D
  por pieza del R15 (capa 16, máscara 1|4|16), ConeTwistJoint3D en rótulas y HingeJoint3D en codos/rodillas, creados
  en una pose media (`CENTRO`) porque Godot mide los límites desde la pose de creación; los cuerpos empiezan
  congelados y en el primer fotograma de física se ponen en la pose y velocidad reales. El rig pasa a `top_level`
  y sus Motor se recalculan desde los cuerpos (`T = c0⁻¹·(P⁻¹·C)·c1`).
- Músculos PD por articulación (`ART`: tipo, límites, fuerza, grupo) y comportamientos `caer`, `caida_libre`,
  `impacto`, `retorcerse`, `morir`, `inerte` (transiciones solas al tocar suelo / quedarse quieto). Señales
  `impacto(velocidad)` (daño de caída lo calcula el dueño) y `recuperado` (vivo, pasada `duracion` y quieto).
  `terminar(mezcla)` quita la física y mezcla la pose final con la animación del dueño. Máx. 12 activos; los muertos
  quietos se congelan.
- Jugador: `ragdoll_iniciar`, `_caida_ragdoll` (en el aire, tras `FALL.MinAir` con caída > `RagdollSpeed` y suelo a
  más de `RagdollGround`), `_aterrizaje_fuerte` (≥ `FALL.Knock`), `danio_caida` (fórmula FallDamage de Roblox),
  `_ragdoll_levantarse` (→ `Animador.levantarse`, rueda si boca arriba). En ragdoll el Arsenal no dispara ni golpea.
- Moto caída: `Moto.caer()` → `_crear_fisica()` (RigidBody3D masa 25, centro de masas alto, formas de ruedas, manillar
  y estribos); `_paso_fisica` sigue al cuerpo; `empezar_a_levantar`/`levantar` la vuelven a la pata.
- Pruebas: `tests/ragdoll.gd --modo=empuje|alto|morir|limites|j_derribo|j_caida|j_aterriza|j_morir`.

## Pulido de jugabilidad (2026-10-27, KangooG) — revisión en `docs/REVISION_JUGABILIDAD.md`
- **Sonido:** `sonidos/Tipo_n.ogg` (Freesound CC0, créditos en `docs/SONIDOS.md`). `Efectos.sonido(ctx, tipo, pos, vol,
  tono)` elige una variante al azar (sin repetir la anterior); sin archivo, sintetizado; en `--headless` siempre
  sintetizado. `Efectos.precargar()` en `Jugador._ready`. Para sonidos nuevos: procesar a mono 44,1 kHz Vorbis y
  volumen normalizado como los demás.
  **Volumen:** los .ogg vienen con picos cerca de 0 dBFS; los 3D suenan a `vol` − 4 dB con `max_db` 0 y hay un
  `AudioEffectHardLimiter` en Master (`Efectos._limitador_master`, se añade en tiempo de juego). No subir la ganancia
  por encima de 0 dB: antes (+6 dB) saturaba todo y el rifle sonaba roto.
- **Efectos:** `Efectos.muzzle_flash(ctx, muzzle, fuerza)`, `humo`, `casquillo` (RigidBody3D capa 0, máx. 30);
  `Arsenal.expulsar_casquillo`. Cachés estáticas que se vacían al salir (`Efectos.limpiar`).
- **Inercia:** `Jugador._vel_inercia` en `humanoid_step` (solo en "Running" sin vallar/colgarse/mover forzado);
  en "Physics" (vallas, trepar) sigue a `vel_real` (2026-11-03: si no, al terminar salía disparado);
  `ZConfig.PLAYER.Frenada`. Si se añade un movimiento forzado nuevo, ponerlo en `_move_override` o la inercia lo frenará.
- **Cámara:** `dist_suave` (la distancia se acerca suave y al instante si choca), `apretado_cur` sube al instante.
- **HUD:** `Jugador._contorno(label, px)`, ayuda con H (`_hud.ayuda`), barra de armas auto-oculta (`Arsenal._barra_t`),
  `HudDanio` (`hud_danio.golpe(cantidad, pos, desde)` desde `recibir_danio`; `desde` = null si no se sabe de dónde).
- **Ragdoll:** `Ragdoll.EXAGERA` / `NERVIO` escalan todos los gestos (pedido: "muchísimo más exagerado"; desde el
  2026-10-28 en 1.6 / 1.25, con músculos rígidos: ver abajo).
- **Pruebas de recorrido:** `tests/recorrido.gd` + `tests/escena_recorrido.tscn` `--escenario=<andar|correr_giro|saltos|
  agacharse|vallar|trepar|cornisa|escalera|pared_cam|rifle|giro_disparo|danio|pistola_bate>` (`--detalle`,
  `--velocidades`): imprime `RECORRIDO … cam_tiron cam_dentro pie_resbala vmax`. Con `--write-movie` se ve como en el juego.
- `InfiniteStamina` ahora es `false` (F4 la activa para probar).

## Ragdoll rígido, moto y cuestas (2026-10-28, KangooG)
- **Ragdoll:** músculos implícitos (`MUSCULOS_JOLT`): cada articulación es un `Generic6DOFJoint3D` con límites por eje
  y un muelle angular por eje (`_crear_union_6dof`, `_musculo_6dof`: objetivo → ángulos de Euler **ZYX con signo −**,
  comprobado: error 0,1°). Rigidez `KS · fuerza · inercia de la rama` (`_calcular_inercias`: lo que cuelga de la
  articulación). Vivo: tono mínimo `TONO`. `prepararse` (manos bajo los hombros / rodillas arriba) y se levanta en
  cuanto ha tenido un momento (no espera a estar quieto); tope de seguridad en `Jugador._paso_ragdoll` (+3 s).
  `Jugador._sitio_para_levantarse` / `_cabe_de_pie` buscan sitio libre (la moto caída cuenta); mientras se levanta no
  choca con una moto caída a su lado (`_sin_choque_motos`). `LEVANTARSE_VEL` 1.4.
- **Moto, choques:** `_altura_obstaculo`: contra algo más bajo que `OBST_BAJO` (~43 cm) hace falta `CHOQUE_BAJO` (40)
  para tirar al piloto y sale por encima del manillar con casi toda su velocidad; contra una pared alta, `CHOQUE` (30) y
  se estrella contra ella. `_caida_segun_golpe`: vuelta de campana / rebote de lado / vuelco al azar. El piloto no
  choca con su moto 0,7 s (`Ragdoll.ignorar`). Escalones: `_escalon()` (14 cm despacio, ~19 cm deprisa) y un canto de
  escalón no se toma por cuesta. Arreglado: `_tantear` suponía suelo plano si no había punto de contacto (la moto
  trepaba bloques de 40 cm). `Moto._paso_fisica` recorta cambios de velocidad bruscos con el jugador al lado (el
  jugador, cinemático, la lanzaba por los aires). `Jugador.levantar_moto`: desde el lado en que está el jugador.
- **Cuestas: mecánica de trepar ELIMINADA (2026-10-30, a pedido de KangooG: "demasiado tortuosa, muchos fallos").**
  Se quitaron `Jugador._paso_cuesta` y todo el estado `cuesta`, la rama de la cuesta del Animador, la tecla C/Espacio
  de la cuesta, la cámara especial y la zona de F1. Las cuestas vuelven a ser como antes (se suben andando). Quedan
  arreglos generales que salieron de ella: `Ragdoll._paso_mezcla` (al levantarse ya no salta a mitad de rodar),
  `_brazo_sin_choque` suave y pies que no se quedan sobre una cuesta muy empinada al replantar (`smooth_j2`/`muelle_*`
  quedan sin uso). Prueba: `tests/recorrido.gd --escenario=derribo_llano` (auditor de tirones).
- **Moto, atascos y suspensión (2026-10-29):** la rueda que toca el CANTO de un escalón que puede subir (≤ `_escalon()`,
  ahora 22-24 cm) rueda por encima (antes la normal del canto, muy inclinada, la paraba: se quedaba a medio subir un
  bloque de 20 cm). Suspensión visible: `sus_d`/`sus_t` (muelles con amortiguación: peso, baches y aterrizajes por el
  cambio de velocidad vertical de cada eje, frenar hunde delante, acelerar agacha detrás); `_susp_cf()` mueve el cuerpo
  (y al piloto) sobre las ruedas, `_susp_ruedas()` desliza las botellas de la horquilla (`ModeloMoto` "Deslizante") y
  gira el basculante ("Basculante", eje `PIVOTE_BASC`) con los amortiguadores (`ModeloMoto.amortiguador`).
- **Moto (2026-10-29, 3):** subirse y levantarla solo DE LADO (`Moto.de_lado`). (Lo de limitar el disparo
  desde la moto quedó sustituido el 2026-10-30: ver "Apuntado libre en la moto".) El motor no empuja más de lo que agarra la
  rueda (`AGARRE_RUEDA`): cuestas de más de ~40° ya no se suben acelerando. Marcha atrás más fuerte y el piloto aguanta
  casi todo el peso en cuesta (salía del hueco entre bloques). `_pose_de_pie` busca dónde cabe de pie (antes, tumbada
  en el hueco, se levantaba con una rueda dentro de un bloque, daba vueltas y atravesaba el suelo);
  `_no_atravesar_suelo` = red de seguridad. Bajarse marcha atrás la deja en la pata.
- **Apuntado libre en la moto (2026-10-30; 2026-11-01 con UN SOLO BRAZO y POSES HECHAS EN BLENDER, a pedido de
  KangooG):** con arma de fuego se apunta y dispara en 360° (detrás incluido) y con cualquier cabeceo, siempre con el
  brazo DERECHO; la izquierda nunca suelta el manillar. **Las poses salen de Blender** (`animaciones/blender/`, ver su
  `LEEME.md`): el piloto montado en Blender (`piloto.blend`, a partir de `tests/moto.gd --modo=exportar`), las poses
  diseñadas en `poses.py` (antebrazo y pistola en la línea de tiro con la muñeca neutra, codo algo flexionado y abajo,
  cruzando por delante del pecho a la izquierda, por fuera del hombro hacia atrás) y exportadas a
  `scripts/jugador/poses_moto.gd` (`PosesMoto`, generado: no editar a mano): rejilla de 28 ángulos x 7 cabeceos con
  las rotaciones de Waist, Neck y del brazo derecho, más la pose RECOGIDA. Animador: `_pose_moto` mezcla la rejilla
  (`_muestrear`, interpolación esférica) según `rel_aim` (muelle con velocidad y aceleración máximas: `_muelle_lim`,
  `GIRO_W/VMAX/ACEL`) y la aplica por FK en "aplicar torso, cuello y brazos" (cintura y cuello como giro sobre la pose
  de conducir; el brazo mezclado con la IK del arma baja por `moto_apunta_k`); la muñeca lleva `moto_corr_q` (≤ 25°)
  para que el cañón vaya exacto a la mira. Ramas (`moto_rama`): "L" delante/derecha/izquierda cruzando, "B" detrás por
  encima del hombro derecho; costura detrás a la izquierda (`COSTURA_IZQ`/`COSTURA_ATRAS`): al cruzarla desde el lado
  cruzado (`moto_cambio`, 0,7-1,3 s según el recorrido, `_dur_cambio`; sin disparar el 70 % del tiempo) curva suave
  pose actual → RECOGIDA → pose final (`spherical_cubic_interpolate`). La cámara va al hombro que deja ver el brazo
  (`lado_camara_moto`). Pruebas: `tests/moto.gd --modo=apuntar360 [--mover] [--detalle]` y `--modo=giros`.
- **Pruebas nuevas:** `tests/moto.gd --modo=fila --vel --lado`, `--modo=levantar_hueco --x --ang`, `--trazav`;
  `tests/moto.gd --modo=atasco --bloque=0..6 --vel --ang --lado` y `--modo=suspension`;
  `tests/moto.gd --modo=eyecta --obst=<muro|bloque10..40> --vel=N`, `tests/ragdoll.gd --modo=j_moto`.

## Animaciones hechas en Blender (2026-11-01, a pedido de KangooG: "haz todas las animaciones en Blender")
- Plan por grupos, en este orden: (1) armas a pie, (2) andar/correr/agacharse, (3) saltos/vallas/cornisas/levantarse,
  (4) resto de la moto. Todo en `animaciones/blender/` (Godot la ignora: `.gdignore`; ver su `LEEME.md`). Blender 4.2
  LTS. Lo que no puede ser una animación fija sigue con código encima (pies sobre el terreno, ragdoll, puntería exacta).
- Hecho: apuntado en la moto (`PosesMoto`, ver arriba) y **posturas de pie con armas de fuego** (`PosturasPie`,
  generado desde `diseno_pie.py`): por arma base (Pistola, Rifle) y estado (LOW/HIP/AIM/SPRINT), giro del pecho, inclinación,
  cabeza y polos de los codos; el arma va donde dice `Armas.pose` y las manos por IK. Animador: `_paso_postura_pie`
  (`pie_k`, `pie_w`, `pie_n`, `pie_polo_r/l`; solo de pie, no tumbado ni en la moto); sustituye al antiguo "blade".
- Las armas de fuego no atraviesan el torso: `_arma_de_fuego_fuera` (empuja HACIA DELANTE lo que quede dentro del
  pecho/barriga, con el pecho final del fotograma; peso `fuera_w`). Comprobar con `tests/combate.gd --choque_arma`
  (y `--pitch=`); vista cercana con `--video --cam_az=<grados>`.
- Sacar/guardar armas largas: `Armas.draw(...).camino` (claves [u, Handle respecto al UpperTorso], por fuera del
  cuerpo; al guardar, al revés) + `Animador._por_claves`. Comprobar con `--choque_arma --todo_cuerpo` (`--modo=cambiar`).
- **Modelo del superviviente en Blender** (2026-11-01): `animaciones/blender/personaje/personaje.py` →
  `modelos/superviviente.glb` (ver `LEEME.md` de esa carpeta). `RigPersonaje.modelo = "superviviente"` (jugador y
  menú; los zombis y maniquíes siguen con el muñeco por código). Las cajas de impacto siguen siendo `PIEZAS`.
- Pistola al 65 % (`ModelosArmas.ESCALA`, también escala sus puntos y `Armas.grip`).
- **Movimiento (2026-11-02)**: andar/correr/agachado, salto, tumbarse/reptar, vallas, trepar y colgado salen de
  `animaciones/blender/movimiento/diseno_mov.py` → `Movimientos` (generado). Animador: `_ciclo`, `_brazo_ciclo`,
  `_curva_pie` (mezcla por `mez_run`, `crouch_b`; amplitud `amp_ciclo`), `air_tj` (salto), piernas al tumbarse por
  IK a sitios del suelo, `pelvis_drop_v` (muelle). En marcha, piernas animadas (ver abajo). Medir: `tests/visual.gd
  --registro=x.csv` + `tests/fluidez.py`, y `--contactos`.
- **Piernas animadas** (2026-11-03, sustituye a los "pasos por reloj" del 2026-11-02; KangooG: "animación normal,
  olvidando los pasos procedurales al 95 %"): en marcha (arranca a `speed >= 0.8`, para por debajo de 0.4)
  `update_feet` → `_marcha_animada`: cada pie sigue `Movimientos.PIERNAS` (`_pierna_anim`) respecto a la cadera, con
  la fase `gait01` avanzando con la distancia (`ZANCADA`/`FRACCION_AIRE`; hacia atrás la animación va al revés,
  `anim_sentido`; de lado los pies se separan lo justo para no cruzarse). Lo procedural (el 5 %): altura del suelo
  donde pisa (`_suelo_pie`, el paso apunta al suelo donde apoyará), pie apoyado clavado (`anim_lock`, se acerca
  despacio a la animación y lo que falte lo recupera en el paso: `anim_off`) y mezcla corta al arrancar (`anim_w`).
  Parado, el código de pasos de ajuste de siempre (`_parar_animada` al pararse). `update_roll` no toca un pie animado.
  Menos inclinación del torso por velocidad/aceleración (`S.leanP`).
  Escaleras (2026-11-03, 2): `_mirar_escalera` → `esc_fondo`/`esc_bordes`; un escalón por paso (dos corriendo),
  pie al centro de la huella (`_centro_huella`, `esc_off_v`), `Jugador` limita la velocidad en escaleras; bajando,
  `aire_corto_t` (caer un escalón no es un salto). Cada pie con su avance (`ap_paso`/`ap_x`, `_avanza_pie`),
  `anim_zan` suave, `anim_parando`. `Movimientos` se lee con interpolación cúbica.
  Levantarse: `Movimientos.LEVANTAR` (boca abajo por pb; boca arriba por 1 - pb con `L.levanta_arriba`).
  Moverse boca arriba (2026-11-03, 4): `Movimientos.BOCA_ARRIBA` (pies, puente de cadera, hombros por la fase
  `sup_ph`; la cadera se desplaza en el Root, los pies por IK desde la pose de tumbado, `waistR` curva la espalda).
  Trepar con arma: `Arsenal.guardar_para_trepar` / `sacar_tras_trepar` / `rearmar`.
- Pendiente: recarga, sacar/guardar y golpes (grupo 1, parte 2) y el resto de la moto.

## Ruido y zombis v0 (2026-10-23, a pedido de Juan) — guía completa: `docs/RUIDO_Y_ZOMBIS.md`
- **Sistema de ruido** (`scripts/ruido/ruido.gd`, clase estática `Ruido`, sin autoload): quien hace ruido llama a
  `Ruido.emitir(ctx, pos, radio_studs, tipo, fuente)`; los nodos del grupo `oyentes_ruido` reciben `oir(ev)`.
  Una pared (capa 1) entre el ruido y quien escucha lo reduce al 45 % (`Ruido.radio_percibido`). Radios en `ZConfig.RUIDO`.
- **Fuentes:** pisadas (Animador, al apoyar cada pie, según `step_k`: agachado ~5, andando ~13, corriendo ~32 studs),
  reptar, aterrizajes, vallas, cornisas (Jugador), disparos (`Alert` de cada arma), impacto de la bala (sin fuente:
  sirve para distraer), golpes, recarga (Arsenal) y gruñidos (Zombi).
- **Zombi v0** (`scripts/zombis/zombi.gd`): solo oye (sin vista). Estados DEAMBULAR → INVESTIGAR → PERSEGUIR →
  ATACAR, BUSCAR, CAIDO, MUERTO. Persigue siguiendo los ruidos del jugador (no conoce su posición); al empezar a
  perseguir gruñe y alerta a los cercanos. Animación barata sin IK (~0,09 ms por zombi). Valores en `ZConfig.ZOMBI`.
- **DirectorZombis** (`scripts/zombis/director_zombis.gd`): hornea la navegación al cargar (~0,5 s), coloca y repone
  zombis. El nivel de pruebas trae 4 (`nivel_pruebas.gd`, `_crear_zombis`; meta `sin_zombis` para no crearlos).
- **Contrato de objetivo:** las armas golpean a cualquier nodo del grupo `objetivos` con `vivo`, `en_pie`, `centro`,
  `recibir_danio`, `empujar`, `derribar` y `rig`; las balas buscan cuerpos de la capa 2 con meta `objetivo` (y `pieza`,
  o el método `impacto_bala`). Los golpes ya no atraviesan paredes (AUDITORIA §7.1 arreglado).
- **Jugador:** grupo `jugador`; `recibir_danio(cantidad, desde)`, regenera con `RegenDelay`/`RegenRate`, muere y el
  nivel se reinicia a los 4 s. Medidor de ruido bajo la estamina (`scripts/ui/medidor_ruido.gd`).
- **Depuración (solo editor):** F6 ver ruidos, cono de visión y estado de los zombis; F7 zombis sordos; F8 zombis ciegos
  (también en el menú de trucos F1).
- **Pruebas:** `tests/pruebas_ruido.gd` + `tests/ejecutar_pruebas.sh` (26 pruebas, incluidas regresiones de movimiento,
  cadencia y maniquí). Ojo: la oclusión es real; en el nivel, los bloques naranjas tapan el ruido.

## Zombis v1: vista e ingenio (2026-10-24, a pedido de Juan) — detalle en `docs/RUIDO_Y_ZOMBIS.md` §6
- **Vista:** cono de 120° y visión periférica según la postura del jugador (`ZConfig.STANCE[].Sight/Near`, que venían
  de Roblox y no se usaban): de pie te ven hasta ~15 m, agachado ~9 m, tumbado ~5 m; pegado (de pie ~3 m) te notan
  aunque no miren. Rayos a cabeza, pecho y cadera del jugador (tapa la capa 1). **Sospecha gradual** (`Zombi.sospecha`,
  0..1): a 0,45 "le parece ver algo" y va a mirar; a 1 te ha visto y te persigue sabiendo dónde estás.
- **Ingenio:** al perderte de vista va a donde estarías (`Anticipar`); `BUSCAR` registra 3 sitios alrededor (el
  primero hacia donde ibas); tarda 0,5 s en reaccionar a un ruido estando tranquilo; rodea obstáculos si se atasca.
- **Dificultad:** las velocidades no cambian. Tabla de cuánto tardan en verte en la guía; para ajustarla, `VistaRapidez`
  y `VistaAlcance` en `ZConfig.ZOMBI`.
- **HUD:** indicador "visto" bajo el de ruido (`MedidorRuido.visto`): blanco → naranja (va a mirar) → rojo (te ha visto).
- **Ojo en pruebas propias:** los zombis ahora ven. Si una prueba necesita un zombi pasivo, pon `Zombi.ciegos = true`
  además de `Zombi.sordos = true` (así se hizo en `tests/cerca.gd`).

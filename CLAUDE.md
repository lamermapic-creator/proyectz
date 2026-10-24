# CLAUDE.md — Proyecto Z (léelo antes de tocar nada)

Este archivo es la memoria compartida del proyecto para el Claude de cada colaborador.
Responder SIEMPRE en español. Presupuesto 0 $: solo recursos gratuitos.

## Normas para trabajar entre dos personas (y sus Claude)
1. Antes de empezar: el usuario hace **Pull** en GitHub Desktop. Si este archivo cambió, vuelve a leerlo.
2. Cada persona trabaja en su parte (ver "Reparto" abajo). No modificar a la vez el mismo archivo
   que el otro; las escenas `.tscn` y `project.godot` dan conflictos difíciles: avisar antes de tocarlos.
3. Commits pequeños y con mensaje claro en español (qué y por qué). Subir (**Push**) cuando algo funcione.
4. Al terminar una tarea, **actualizar este archivo** (sección de estado y decisiones) en el mismo commit.
5. No borrar ni reescribir código del otro sin hablarlo. Si algo suyo falla, anotarlo en "Problemas conocidos".
6. Todo el juego usa **studs** (1 stud ≈ 0.31 m) y gravedad 35, como el original de Roblox.
7. Probar antes de subir: abrir el juego desde el editor (F5) y comprobar que no hay errores en la Salida.
   Además, si se puede ejecutar Godot por consola: `tests/ejecutar_pruebas.sh <ruta a Godot>` (16 pruebas
   automáticas, ~1 min; en Windows con Git Bash). Si añades algo importante, añade su prueba.

8. Lee también **`AUDITORIA.md`** (2026-10-23): revisión técnica con fallos comprobados, deuda técnica,
   ideas de mejora y hoja de ruta. Al arreglar algo de ahí, anotarlo en `CAMBIOS.md`.

## Reparto (rellenar entre los dos)
- KangooG: jugabilidad (personaje, movimiento, armas, cámara, menús, trucos).
- Juan (berrizjuane-collab): zombis, sistema de ruido, IA.

## Mensajes entre los Claude (leer al empezar; responder debajo y borrar lo ya contestado)
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

## Problemas conocidos
- (ninguno anotado)

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
- **Pendiente de portar**: daño por caída y ragdoll activo Euphoria (levantarse), sonidos reales (pasos, respiración, armas), vista de los zombis, moto, carro, mapa de ciudad. (Armas y combate: hechos; ruido y zombis v0: hechos, ver abajo.)

## Conexión Claude ↔ Godot (resuelta 2026-10-20)
- Godot 4.7.2 portable: `C:\Users\ferna\Desktop\Godot_v4.7.2-stable_win64.exe` (para computer use hay que resolverlo por su ruta completa).
- Plugin **Godot AI v4.3.0** (hi-godot/godot-ai) en `addons/godot_ai`; puertos HTTP 8001 / WS 8002. uv en `C:\Users\ferna\.local\bin`.
- La migración v3→v4 se quedaba trabada → `"clients_migrated": true` en `addons/.godot_ai_update/pending.json`. El botón Configure se cuelga → la config de Claude Desktop se pega a mano (Claude Desktop es MSIX y Claude no puede escribir su propia config).
- `mcpServers` que funciona: `"godot-ai": {"command": "C:\\Users\\ferna\\.local\\bin\\uvx.exe", "args": ["--system-certs", "--from", "godot-ai==4.3.0", "godot-ai", "attach", "--port", "8001", "--ws-port", "8002"], "env": {"UV_CACHE_DIR": "C:\\Users\\ferna\\AppData\\Local\\uv\\cache", "UV_PYTHON_INSTALL_DIR": "C:\\Users\\ferna\\AppData\\Roaming\\uv\\python"}}, "Roblox_Studio": {"command": "cmd.exe", "args": ["/c", "C:\\Users\\ferna\\AppData\\Local\\Roblox\\mcp.bat"]}`
- Roblox Studio: Assistant → … → Manage MCP Servers → "Enable Studio as MCP server".
- Herramientas: `mcp__remote-devices__godot-ai__*` y `mcp__remote-devices__Roblox_Studio__*` (tardan ~1 min tras abrir Claude; usar RefreshMcpTools).

## Referencia: Unity (no borrar)
- Ruta `C:/Users/ferna/proyect-z(3)`. FBX de Mixamo (Remy, Swat y 18 animaciones) en `Assets/_ProyectoZ/Personajes` y `/Animaciones`. Lecciones: no acumular giros sobre huesos frame a frame; la rodilla sigue al pie; los valores serializados no se actualizan al cambiar los de código.

## Plan por etapas (en Godot)
1. Personaje y cámara (hecho lo principal; faltan caídas/ragdoll y sonidos).
2. Armas: disparo, apuntado, retroceso, apoyar arma, dispersión (hecho, con muñecos de prueba).
3. Zombis: navegación, ataques, ragdoll activo, atropello. (v0 hecha el 2026-10-23: oído, navegación, ataques; faltan vista, ragdoll y atropello.)
4. Vehículos: carro y moto.
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
- Ejecutable: Proyecto → Exportar → Windows Desktop, PCK embebido, sin depuración → `C:\Users\ferna\Documents\godotproyectz\versiones\v0.2 con menu\ProyectoZ.exe` (un solo .exe, ~110 MB). Las plantillas de exportación 4.7.2 ya están instaladas.

## Arreglos de jugabilidad (2026-10-24, KangooG)
- Disparo: la bala sale del `Muzzle` en la dirección del cañón (`Arsenal.salida_bala`); al apuntar/disparar el
  animador orienta el cañón hacia `Arsenal.punto_mira()` (`conv_w`). Círculo rojo del HUD = impacto real si no
  coincide con la mira. Pegado a una pared no se bloquea el disparo.
- Cámara: `Jugador.zoom_cam` (rueda), `apretado_cur` (sin sitio detrás → sube sobre la cabeza), `_esfera_choca`.
- Arma contra la pared: `Animador.arma_alzada` (0-1) levanta el cañón — **DESACTIVADO** (`ALZA_ACTIVA = false`, al
  usuario le molestaba al jugar): solo se recoge (`arma_retro`).
  Se mide a lo largo del cañón (empuñadura → boca + `ALZA_MARGEN`); primero se recoge (`arma_retro`, `RETRO_MAX`) y solo
  extremadamente pegado se levanta; apoyada (X) nunca. Círculo rojo: `CIRCULO_CERCA/PX/MIN_PX`, nunca apoyada.
- Apoyar el arma: además de superficies horizontales, apoyo lateral contra una pared vertical (`rest.lado`).
- Cabeza: `FormaCabeza` (caja creada en `_actualizar_formas`, solo de pie, hasta `CABEZA_ALTO` 2.45 sobre el centro);
  agachado bajo techo bajo: `Animador.agache_techo`.
- Colgado: Shift = `COLGAR_RAPIDO` (x1.9, doble gasto). Andar de lado: `Animador.lat_k` (pasos cortos, rodillas dobladas).

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
- **Depuración (solo editor):** F6 ver ruidos y estado de los zombis; F7 zombis sordos.
- **Pruebas:** `tests/pruebas_ruido.gd` + `tests/ejecutar_pruebas.sh` (16 pruebas, incluidas regresiones de movimiento,
  cadencia y maniquí). Ojo: la oclusión es real; en el nivel, los bloques naranjas tapan el ruido.

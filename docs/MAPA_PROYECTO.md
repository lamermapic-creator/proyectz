# Mapa de Proyecto Z

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

- Audio de impactos con dos variantes por familia para puños, patadas, pisotones, armas blancas, bloqueos, balas y choques de moto. Créditos y mezclas en [Sonidos](SONIDOS.md).

Versión actual de Proyecto Z: **0.6V**.

- Golpes rápidos: anticipación corta, retorno del puño junto al rostro y codo que sigue el arco del arma. El tiempo del clip de Blender gobierna la animación; el cooldown regula la siguiente entrada.

- Animaciones de ataque: 16 acciones CC_ editables en `animaciones/blender/combate/golpes.blend` (Blender 4.3). Seleccionar Piloto en el editor de acciones. Las curvas del grupo Controles IK se exportan ejecutando `python3 animaciones/blender/combate/a_gd_cc.py scripts/jugador/combate_cc.gd` desde la raíz. El marcador Contacto identifica el fotograma de impacto.

- Contacto cuerpo a cuerpo: Arsenal cruza el segmento del arma visible con las cajas orientadas del rig durante el golpe. El puñetazo usa la mano animada.

- Combate a pie: nuevas trayectorias de puño, cuchillo, machete y bate. Clic contra un caído usa un golpe descendente compartido de brazo; G conserva el pisotón.

Actualizado: 2026-11-17. Repositorio: `lamermapic-creator/proyectz`.
Base de código verificada: `2f0e2282ad3cbe51ca1d99cc3307e8d4a60c523b` (main al consultar).

## Graphify y cobertura

- Grafo consultado: mismo commit `2f0e228`, **216 nodos y 389 relaciones**, 17 comunidades.
- Cobertura parcial: la consulta general recupera principalmente fuentes Python de Blender;
  `graphify_file_neighbors(file="scripts/jugador/jugador.gd")` devuelve archivo no encontrado.
  Esto NO significa que el archivo ni sus dependencias estén ausentes del proyecto.
- Este mapa combina Graphify con el checkout y revisiones posteriores; el apartado de corto
  alcance fue actualizado el 2026-11-17. El snapshot del grafo puede quedar atrás del código.
- Consultar con `repository_id="lamermapic-creator/proyectz"` y empezar por
  `query_graph(skeleton=true, budget=1000–2000)`. Ampliar solo símbolos necesarios.
- Comparar siempre `commitSha` con HEAD y leer archivos actuales ante resultados vacíos,
  parciales o desactualizados. Los recuentos del grafo no equivalen a cobertura de pruebas.

## Motor y entrada

- Godot 4.7.2 según documentación del proyecto; `project.godot` declara 4.7 / Forward Plus.
  Validaciones recientes ejecutadas con Godot 4.6.3: no sustituyen comprobar 4.7.2.
- GDScript, Jolt Physics; studs (1 ≈ 0,31 m), gravedad 35; recursos gratuitos.
- `project.godot` → `escenas/menu_principal.tscn`.
- `scripts/ui/menu_principal.gd`: Jugar, Opciones, Controles, Salir; teclado y paneles escalables.
- Jugar → `escenas/pruebas_movimiento.tscn`.
- `scripts/ui/fondo_menu.gd`: cuarentena nocturna; zombis decorativos sin IA.
- `scripts/ui/atmosfera_menu.gdshader`, `suelo_menu.gdshader`: efectos visuales del fondo.
- `scripts/nivel/nivel_pruebas.gd`: escenario, maniquíes, zombis y motos; cielo frío, sol cálido
  sutil, ACES, sombras suaves y niebla ligera. Ver `docs/AGARRE_Y_GRAFICOS.md`.
- Filtro gris suave en los Environment del nivel y fondo del menú: saturación 0,78,
  brillo 0,98; contraste 1,03 en nivel / 0,98 en menú. No afecta al HUD. `scripts/ui/opciones.gd`: calidad y opciones.

## Jugador, movimiento y animación

- `scripts/jugador/jugador.gd`: control, posturas, estamina, cámara, salto y entrada/salida de moto.
- `scripts/jugador/animador.gd`: marcha procedural/IK, pies, brazos, arma, torso y cabeza.
- `scripts/jugador/rig_personaje.gd`: rig compartido y registro `RigPersonaje.MODELOS`.
- Saltos verticales o frontales respecto a cámara; bloqueados atrás/laterales y diagonales laterales.
- Patadas bloqueadas durante carrera. Golpe de arma/puñetazo solicitado corriendo espera frenada;
  petición caduca a 0,7 s. Guardia con clic derecho espera bajar la velocidad.
- Z corriendo: tumbarse rápido en 0,4 s con deslizamiento frenado de 0,45 s; respeta
  colisiones. Prueba `tests/tumbar_corriendo.gd` (también `--pared`).
- Tumbado: nueva pulsación de Shift + dirección permite incorporarse y salir corriendo,
  si hay espacio; no cancela la caída por mantener Shift. `tests/levantarse_corriendo.gd`,
  incluido `--techo`, y regresión de caída con `--mantener-shift`.
- Pausa de 0,16 s tras correr antes de apuntar, subir a moto o levantarla.
- Al correr, cuerpo sigue movimiento incluso armado; cámara queda libre. Giro con aceleración/frenada.
- Marcha lateral/posterior ajustada; mezcla caminar/correr amortiguada y alcance de pies acotado
  delante/detrás. Persisten resbalones puntuales en giros: no dar la fluidez por totalmente resuelta.
- Entrada progresiva al apuntado; se elimina flexión adicional de piernas al caminar apuntando.
- Armas cortas de fuego a una mano, izquierda libre salvo recarga/tareas. Pistola permite disparar
  durante carrera; cabeza/torso acompañan. Armas largas frenan al disparar y mantienen dos manos.
- Rifle: anticipación del arma limitada a ±8°, margen corporal de 4°, para no forzar brazos/IK.

## Armas, balística y física

- `scripts/jugador/arsenal.gd`: inventario, disparo, recarga, guardia y cuerpo a cuerpo.
- `scripts/armas/armas.gd`, `modelos_armas.gd` y resto de `scripts/armas/`: datos, modelos y efectos.
- `Armas.grip()`: referencia por empuñadura; apoyo izquierdo con posición y orientación IK.
  `tests/agarre_armas.gd` comprueba el contacto de las manos.
- `Arsenal.salida_bala()` toma posición y dirección del **Muzzle real**, con dispersión del arma.
  Eliminadas correcciones de trayectoria hacia mira/pecho; sin Muzzle visible no dispara.
- `Animador` alinea suavemente la postura del arma con el punto de mira al estabilizar apuntado:
  corrección de muñeca máxima 3° lejos y 15° cerca, pausada durante retroceso y giros rápidos. No desvía la bala.
- A corta distancia, cuerpo/arma convergen al punto de mira y el arma se recoge suavemente;
  sin el antiguo corte de convergencia a 3 studs. `tests/precision_cerca.gd`: tres armas a 3/5/8 studs.
- `scripts/fisica/impacto_balistico.gd`: reacción localizada de articulaciones; estado transferido al ragdoll.
- `scripts/fisica/ragdoll.gd`: cuerpos/articulaciones Jolt, impacto localizado y cadáveres alcanzables.
  NPC/zombis sortean pérdida de apoyo, torso/brazos/caderas y 4–7 contracciones breves decrecientes.
  La secuencia termina en reposo; otros disparos no la reinician. Límite de ragdolls activos existente.
- `scripts/nivel/maniqui.gd`: blanco de entrenamiento, contrato de daño y recuperación.
- `scripts/vehiculos/`: moto y modelo; dirección progresiva, agarre/derrape y freno/marcha atrás.

## Ruido e IA

- `scripts/ruido/ruido.gd`: `Ruido.emitir(...)` envía eventos al grupo `oyentes_ruido` mediante `oir(evento)`.
- `scripts/zombis/director_zombis.gd`: navegación y creación de zombis.
- `scripts/zombis/zombi.gd`: oído, visión, sospecha; deambular, investigar, buscar, perseguir,
  atacar, caído y muerto. No deducir cambios de IA a partir de ajustes del ragdoll.
- Contrato de objetivos: `recibir_danio`, `empujar`, `derribar`, `vivo`, `en_pie`, `centro`, `rig`.
  Zombi/Maniqui añaden `recibir_disparo(cantidad,pieza,impulso,punto)` para balística localizada.

## Modelos y fuentes generadas

- `modelos/zombis/`: 12 GLB: civil, sanitario, obrero, mecanico, policia, bombero,
  excursionista, oficinista, repartidor, paciente, granjero y vagabundo.
- `Zombi.variante_visual`: aleatorio por defecto; permite fijar variante.
- Dirección vigente **v7, bloques cuadrados limpios**, pocos detalles; sin partes circulares,
  pliegues superpuestos ni realismo de piel. Cráneos cerrados en todas las variantes.
  Sustituye la decisión antigua de tres cráneos abiertos.
- `animaciones/blender/zombis/`: generar.py, refinado.py, rostro.py, deterioro.py;
  validar.py y render_*.py para validación/revisión. Ver `docs/MODELOS_LIMPIOS_V7.md`.
- `escenas/galeria_zombis.tscn` + `scripts/nivel/galeria_zombis.gd`: revisión de modelos/clips.
  Reposo, caminar, perseguir, atacar, herido, morir. Juego conserva procedural y ragdoll.
- NO editar a mano `scripts/jugador/movimientos.gd`, `poses_moto.gd`, `posturas_pie.gd`, `combate_cc.gd`.
  Modificar fuentes en `animaciones/blender/` y regenerar; movimiento en `movimiento/diseno_mov.py`,
  combate en `combate/diseno_cc.py`. Los ajustes recientes de IK no modificaron estas tablas.

## Documentación y comprobaciones

- Leer `CLAUDE.md` antes de modificar; actualizarlo junto con `CAMBIOS.md` en cada entrega.
- `AUDITORIA.md`: deuda/problemas conocidos. `scripts/config/zconfig.gd`: parámetros compartidos.
- `docs/MODELOS_ZOMBIS.md`: índice histórico; prevalece v7. `docs/MENU_PRINCIPAL.md`: menú.
- `docs/RUIDO_Y_ZOMBIS.md`: ruido/IA/contratos. `docs/FISICA_Y_MANEJO.md`: física, moto y evidencia.
- `tests/ejecutar_pruebas.sh <Godot>`: batería general. No todos los scripts nuevos están integrados
  como grupos del ejecutor: comprobar su lista; también pueden ejecutarse individualmente con `-s`.
- `tests/modelos_zombis.gd`, `menu_redisenado.gd`: modelos/contratos y navegación/tamaños/transición.
- `tests/balistica.gd`: 97 comprobaciones en la última validación; impacto/daño/cadáver/recuperación.
- `tests/salida_canon.gd`: 25 comprobaciones, cañón desalineado y ausencia de modelo.
- `tests/precision_mira.gd`: error cañón/mira estabilizado, rifle/pistola/escopeta (<0,05° medido a 30/60 FPS).
- `tests/variedad_ragdoll.gd`: ocho muertes iguales con semillas distintas, diversidad/contracciones/reposo.
- `tests/manejo_moto.gd`: conducción. `giros_fluidos.gd`: inversión de giro a 30/60/120 FPS.
- `tests/anticipacion_arma.gd`: límite de anticipación. `pasos_suaves.gd`: alcance/continuidad de pies.
- `tests/recorrido.gd` con `escena_recorrido.tscn`: escenarios reales y métricas de pasos/cámara.
- Evidencia en `docs/fisica/`: GIF de pasos, giro de brazos, caídas y reacción a disparos.
- Intermitencias conocidas: `moto_zombi`, algunos casos de combate en suelo. Registrar fallos y
  repeticiones; no presentar comprobaciones aisladas como una batería completa sin fallos.
- `addons/godot_ai/`: integración del editor; presencia no confirma conexión activa.

Este mapa orienta búsquedas. Consultar dependencias exactas y código actual para cada cambio.

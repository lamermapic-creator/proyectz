# Ruido y zombis — guía del sistema (v0)

> **Para quién:** cualquier persona o Claude que vaya a tocar el sigilo, los zombis o añadir algo que
> haga ruido. **Estado:** v0 terminada y probada el 2026-10-23 (16 pruebas automáticas en verde).
> Si cambias algo de esto, actualiza este documento en el mismo commit.

## Índice
1. [La idea en 30 segundos](#1-la-idea-en-30-segundos)
2. [Plan seguido y estado](#2-plan-seguido-y-estado)
3. [Arquitectura](#3-arquitectura)
4. [El sistema de ruido (`Ruido`)](#4-el-sistema-de-ruido-ruido)
5. [Qué hace ruido y cuánto](#5-qué-hace-ruido-y-cuánto)
6. [El zombi v0 (`Zombi`)](#6-el-zombi-v0-zombi)
7. [El director (`DirectorZombis`) y la navegación](#7-el-director-directorzombis-y-la-navegación)
8. [Contrato de objetivo (lo que deben cumplir los blancos de las armas)](#8-contrato-de-objetivo)
9. [Daño, vida y muerte del jugador](#9-daño-vida-y-muerte-del-jugador)
10. [Herramientas de depuración](#10-herramientas-de-depuración)
11. [Pruebas](#11-pruebas)
12. [Rendimiento medido](#12-rendimiento-medido)
13. [Limitaciones conocidas y siguientes pasos](#13-limitaciones-conocidas-y-siguientes-pasos)
14. [Archivos tocados](#14-archivos-tocados)

---

## 1. La idea en 30 segundos

El lema del juego es *"Sobrevive. No hagas ruido."*, y ahora es una mecánica. Todo lo que hace el jugador
produce un **ruido**: un evento con una posición y un **radio** (hasta dónde se oye en campo abierto, en
studs). Los zombis **oyen**: si están dentro del radio van a mirar, y si el ruido es del jugador, fuerte y
seguido, le persiguen. Una pared entre el ruido y el zombi lo amortigua.

*Analogía:* el ruido es como una piedra que cae en un estanque. Cuanto más fuerte el golpe, más lejos llegan
las ondas (el radio). Los zombis son patos que sienten las ondas que les llegan, y un muro dentro del agua
frena las ondas. Andar agachado es dejar caer una piedrecita; disparar es tirar un ladrillo.

Lo que se nota al jugar:
- **Agachado** (~5 studs, 1,5 m) pasas casi pegado a un zombi sin que se entere. **Andando** (~13 studs,
  4 m) te oyen de cerca. **Corriendo** (~32 studs, 10 m) te oyen bastante lejos. Un **disparo** de pistola,
  a 180 studs (56 m).
- Si te oyen poco, **van a mirar** despacio a donde sonó; si te oyen mucho y seguido, **te persiguen**
  corriendo (más que tú andando, menos que tú corriendo: corriendo puedes escapar).
- Si dejas de hacer ruido, van a donde te oyeron por última vez, **buscan** un rato y se rinden.
- Un zombi que empieza a perseguir **gruñe**, y el gruñido es otro ruido: los zombis cercanos acuden
  (efecto jauría).
- Una bala que golpea una pared **suena allí**: disparar lejos sirve para distraerlos.
- Un **medidor de ruido** bajo la estamina enseña cuánto ruido acabas de hacer.

---

## 2. Plan seguido y estado

| Fase | Qué | Estado |
|---|---|---|
| 1 | Núcleo del sistema de ruido: eventos, oyentes, oclusión por paredes, vista de depuración | ✅ |
| 2 | Fuentes de ruido del jugador (pisadas desde la IK, reptar, aterrizajes, vallas, cornisas, disparos, impactos, golpes, recarga) | ✅ |
| 3 | Zombi v0: oye, investiga, persigue, busca, ataca, gruñe; recibe daño; cae con el bate y muere | ✅ |
| 4 | Director: navegación horneada al cargar, aparición y reaparición, teclas F6/F7 | ✅ |
| 5 | Consecuencias: el jugador recibe daño, regenera y muere (reinicio automático) | ✅ |
| 6 | Medidor de ruido en el HUD | ✅ |
| 7 | 16 pruebas automáticas + regresión de lo existente | ✅ |
| 8 | Documentación (esta guía, `CLAUDE.md`, `CAMBIOS.md`, `README.md`) | ✅ |

Reglas respetadas: **no se han tocado escenas `.tscn` ni `project.godot`** (todo se crea por código);
los cambios en archivos que ya existían son pequeños y están listados en la [sección 14](#14-archivos-tocados).

---

## 3. Arquitectura

```
  FUENTES (hacen ruido)                         RUIDO (scripts/ruido/ruido.gd)          OYENTES (grupo "oyentes_ruido")
  ─────────────────────                         ──────────────────────────────          ───────────────────────────────
  Animador   pisadas, reptar  ─┐                                                    ┌─► Zombi.oir(ev)      decide si lo oye
  Jugador    aterrizar, vallas ├──► Ruido.emitir(ctx, pos, radio, tipo, fuente) ───┤      (distancia + paredes) y reacciona
  Arsenal    disparo, impacto, │     · crea un Ruido.Evento                         ├─► MedidorRuido.oir  barra del HUD
             golpe, recarga    │     · se lo pasa a TODOS los oyentes              └─► (pruebas) Escucha  apunta los eventos
  Zombi      gruñido          ─┘     · F6: dibuja un anillo con el radio
```

- **Quien emite no sabe quién escucha, y quien escucha no sabe quién emite.** Para añadir una fuente nueva
  (una botella que se rompe, una alarma de coche) o un oyente nuevo (un perro, un NPC humano) no hay que
  tocar el resto.
- **La decisión de si se oye la toma el oyente** (con la ayuda `Ruido.radio_percibido`), porque cada uno
  tiene su oído y su posición.
- **No hay autoload:** `Ruido` es una clase estática (como `Efectos`), así que no se toca `project.godot`.

Grupos de nodos que usa el sistema:

| Grupo | Quién está | Para qué |
|---|---|---|
| `oyentes_ruido` (`Ruido.GRUPO`) | zombis, medidor de ruido | reciben `oir(ev)` |
| `jugador` | el `Jugador` | los zombis lo encuentran; sus ruidos cuentan como "del jugador" |
| `zombis` | los zombis | el director y las pruebas los recorren |
| `objetivos` | maniquíes y zombis | blancos de las armas (ver [contrato](#8-contrato-de-objetivo)) |

---

## 4. El sistema de ruido (`Ruido`)

### Emitir un ruido
```gdscript
Ruido.emitir(self, posicion, radio_en_studs, Ruido.DISPARO, self)
#            ctx   dónde     hasta dónde se oye  tipo      quién lo hace (null = el entorno)
```
- `ctx`: cualquier nodo dentro del árbol (sirve para llegar a la escena).
- `fuente`: quién lo hace. Si es el jugador (grupo `jugador`), los zombis saben que es él; si es `null`
  (una bala contra una pared), solo saben que algo ha sonado allí. El que emite no se oye a sí mismo.
- Tipos: `PASO`, `REPTAR`, `ATERRIZAJE`, `SORTEAR`, `DISPARO`, `IMPACTO`, `GOLPE`, `ARMA`, `GRUNIDO`. Cada
  tipo tiene un **peso** (`Ruido.PESO`) que dice cuánto alarma a un zombi: un disparo alarma más que una
  pisada del mismo volumen.

### Escuchar
```gdscript
func _ready() -> void:
	add_to_group(Ruido.GRUPO)

func oir(ev: Ruido.Evento) -> void:   # ev.posicion, ev.radio, ev.tipo, ev.fuente
	var r := Ruido.radio_percibido(ev, mi_oreja, get_world_3d(), [get_rid()], mi_oido)
	if mi_oreja.distance_to(ev.posicion) <= r:
		pass # lo he oído
```
`radio_percibido` aplica la **oclusión**: si un rayo (capa 1, el escenario) entre el ruido y la oreja choca
con algo, el radio se multiplica por `ZConfig.RUIDO.Oclusion` (0,45). El cuerpo de quien hace el ruido no
cuenta como pared.

### Ayudas
- `Ruido.radio_paso(fuerza, ajuste)`: radio de una pisada a partir de la fuerza (0..1) que calcula el
  Animador (`step_k`: velocidad y si va agachado).
- `Ruido.radio_aterrizaje(velocidad_impacto)`: 0 si es suave; 8..45 según la velocidad de la caída.
- `Ruido.emitidos` y `Ruido.ultimo`: contador y último evento (para pruebas y depuración).

---

## 5. Qué hace ruido y cuánto

Todos los valores están en **`ZConfig.RUIDO`** (`scripts/config/zconfig.gd`) y se ajustan sin tocar código.
Los disparos usan el `Alert` que cada arma ya tenía en Roblox (`Armas.WEAPONS`).

| Acción | Radio (studs) | ≈ metros | Dónde se emite |
|---|---:|---:|---|
| Pisada agachado | ~5 | 1,5 | `Animador.update_feet`, al apoyar el pie |
| Pisada andando | ~13 | 4 | ídem (radio = `PasoMin`..`PasoMax` según la fuerza) |
| Pisada corriendo | ~32 | 10 | ídem |
| Pasito de recolocar los pies, parado | 40 % | — | ídem |
| Reptar / reptar con Shift | 3 / 7 | 1 / 2 | `Animador` (cada brazada) |
| Aterrizar tras un salto / caída fuerte | ~10 / hasta 45 | 3 / 14 | `Jugador.humanoid_step` |
| Saltar una valla / encaramarse / agarrarse a una cornisa | 12 / 10 / 8 | | `Jugador.start_vault`, `colgarse` |
| Disparo de pistola / rifle | 180 / 260 | 56 / 80 | `Arsenal.shoot` |
| Bala contra una superficie (sin fuente) | 25 | 8 | `Arsenal.shoot` |
| Blandir un arma blanca | 5 | | `Arsenal.melee` |
| Acertar con cuchillo o machete / con el bate | 16 / 28 | | `Arsenal._resolver_golpe` |
| Recargar / clic sin balas | 10 / 5 | | `Arsenal.reload`, `shoot` |
| Gruñido de un zombi que empieza a perseguir | 45 | 14 | `Zombi._grunir` |

Medido en el juego (prueba `pasos`): agachado **5,2**, andando **12,4**, corriendo **31,7** studs de media.

---

## 6. El zombi v0 (`Zombi`)

`scripts/zombis/zombi.gd`. Un `CharacterBody3D` con el **mismo muñeco R15** que el superviviente (sin
mochila ni equipo, piel enferma y ropa sucia). De momento **solo oye**: no tiene vista.

### Máquina de estados
```
DEAMBULAR ──oye algo──► INVESTIGAR ──llega──► BUSCAR ──nada en "Buscar" s──► DEAMBULAR
                          │    ▲
     ruidos del jugador   │    │ deja de oírle "PerseguirMemoria" s
     seguidos, alerta alta▼    │
                         PERSEGUIR ──a "Alcance"──► ATACAR ──► PERSEGUIR
cualquiera ──bate──► CAIDO ──se levanta──► PERSEGUIR      cualquiera ──vida 0──► MUERTO
```

- **Alerta** (0..1): sube con cada ruido oído (más si es fuerte, cercano o de un tipo que alarma) y baja
  sola (`AlertaDecae`). Decide la prisa: anda, trota o corre.
- **Pista** (`Zombi.Pista`): lo último que le llamó la atención (posición, hora, fuerza y si sabe que es el
  jugador). Un ruido nuevo sustituye a la pista si es al menos parecido a lo que recuerda (que se va
  olvidando); un ruido nuevo del jugador siempre actualiza el rastro. Así, **perseguir no es hacer trampa**:
  el zombi no conoce la posición del jugador, sigue sus ruidos.
- **Contacto:** a menos de `Contacto` (4 studs, 1,2 m) nota al jugador aunque no haga ruido.
- **Perseguir** necesita: pista del jugador reciente (`PerseguirMemoria`) y alerta ≥ `PerseguirAlerta`.
- **Atacar:** levanta los brazos (`PreparaGolpe`), golpea si el jugador sigue al alcance y delante
  (`Danio`), y repite cada `Cadencia` segundos.
- **Gruñidos:** al empezar a perseguir (con `GrunidoCada` de espera) emite un ruido `GRUNIDO`; los demás
  zombis lo oyen como un ruido **que no es del jugador**, así que van a mirar sin "saber" dónde está él.
  Deambulando gime de vez en cuando (solo ambiente: no emite ruido). Voces sintetizadas (no hay audios aún).
- **Daño:** cumple el [contrato de objetivo](#8-contrato-de-objetivo). Recibir un golpe le pone en alerta
  máxima hacia el jugador. Con el bate puede caer y levantarse; con vida 0 muere, deja de oír y el cuerpo
  desaparece a los `Cadaver` segundos.
- **Física:** el cuerpo flota a 3,1 studs del suelo como el Humanoid del jugador (sube escalones sin
  saltar). Decisiones y movimiento en `_physics_process`; animación en `_process`.
- **Animación barata (para hordas):** sin IK; ángulos directos por fase de zancada, con la fase ligada a la
  distancia recorrida para que los pies apenas resbalen. Brazos al frente cuando está alerta, colgando
  cuando deambula; cojea de la pierna derecha.

Todos los números están en **`ZConfig.ZOMBI`**.

---

## 7. El director (`DirectorZombis`) y la navegación

`scripts/zombis/director_zombis.gd`. Uso desde un nivel:
```gdscript
var dz := DirectorZombis.new()
add_child(dz)
dz.preparar($Geometria)                 # hornea la navegación con la colisión del escenario (capa 1)
dz.crear_zombi(pies, giro_grados)       # pies = punto del suelo en studs
```
- **Navegación:** al cargar se hornea una malla con los `StaticBody3D` de la capa 1 (en el nivel de pruebas,
  ~0,5-0,6 s y ~300 polígonos). Parámetros del zombi: 5,5 de alto, 1 de radio, escalones de hasta 1,25 y
  cuestas de hasta 46°. Los túneles de 1,4 m quedan fuera (el zombi no cabe), igual que para el jugador de
  pie. El zombi pide caminos con `NavigationServer3D.map_get_path` y los sigue en horizontal. Si no hay
  malla, va en línea recta.
- **Reaparecer** (`reaparecer`, `reaparecer_tras`): en el nivel de pruebas un zombi muerto vuelve a su sitio
  a los 20 s.
- En el **nivel de pruebas** (`nivel_pruebas.gd`, función `_crear_zombis`) hay 4 zombis: tras la pared alta
  (para comprobar que las paredes tapan el ruido), junto a la cornisa, en una esquina y más allá de la zona
  de tiro (disparar allí los atrae). Con la meta `sin_zombis` en el nivel no se crean (las pruebas la usan).
  El menú principal no tiene ni director ni zombis.

---

## 8. Contrato de objetivo

Las armas (`Arsenal`) ya no dependen de la clase `Maniqui`: cualquier blanco que cumpla esto recibe balas y
golpes. Hoy lo cumplen `Maniqui` y `Zombi`.

| Requisito | Para qué |
|---|---|
| Estar en el grupo `objetivos` | los golpes cuerpo a cuerpo los buscan ahí |
| `vivo() -> bool`, `en_pie() -> bool`, `centro() -> Vector3` | elegir a quién se golpea |
| `recibir_danio(cantidad, pieza, impulso) -> bool` (true si lo mata) | balas y golpes |
| `empujar(vel, dur)`, `derribar(impulso, dur)` | golpes (el bate derriba) |
| `rig: RigPersonaje` | posición de las piezas (sangre, cabeza) |
| Cuerpos de impacto en la **capa 2** con la meta `objetivo` = el blanco | las balas (rayo con máscara 1\|2) |

Para las balas hay dos maneras, y el `Arsenal` acepta las dos:
1. **Un cuerpo por pieza** con la meta `pieza` (así lo hace el maniquí).
2. **Un único cuerpo** que envuelve todo el muñeco y un método `impacto_bala(origen, dir) -> {pieza, punto}`
   (devuelve `{}` si la bala pasa sin tocar ninguna pieza; entonces la bala sigue su camino). Así lo hace el
   zombi: es un ~25 % más barato porque no hay que mover 15 cuerpos por zombi en cada fotograma.

Además, los golpes cuerpo a cuerpo **ya no atraviesan paredes**: arreglado el fallo de la auditoría §7.1.

---

## 9. Daño, vida y muerte del jugador

En `jugador.gd`:
- `recibir_danio(cantidad, desde)`: quita vida, sacude la cámara, empuja y hace que el cuerpo encaje el
  golpe (muelles del animador). Con menos de un 35 % de vida ya existían la cojera y la mano en la herida.
- **Regeneración:** tras `ZConfig.PLAYER.RegenDelay` (10 s) sin daño, recupera `RegenRate` (1,2 vida/s).
  Estos dos valores ya estaban en la configuración desde Roblox pero no se usaban.
- **Muerte:** "HAS MUERTO", el cuerpo cae de espaldas y a los 4 s (`MUERTE_REINICIO`) se reinicia el nivel.
  Es provisional: no hay pantalla de muerte ni ragdoll todavía.

---

## 10. Herramientas de depuración

Solo en compilaciones de desarrollo (desde el editor):

| Tecla | Qué hace |
|---|---|
| **F6** | Ver el ruido: un anillo con el radio de cada ruido (color según el tipo) y, encima de cada zombi, su estado y su alerta |
| **F7** | Zombis sordos: ignoran todos los ruidos (para probar otras cosas sin que te molesten) |

`Ruido.ver` y `Zombi.sordos` son variables estáticas: se mantienen al reiniciar el nivel.

---

## 11. Pruebas

Por primera vez, las pruebas **están en el repositorio**:
- `tests/pruebas_ruido.gd`: 16 pruebas. Cada una carga el nivel real, simula teclas y comprueba el resultado.
- `tests/ejecutar_pruebas.sh`: lo ejecuta todo (importar, compilar cada script, las 16 pruebas y arrancar el
  menú y el nivel 10 s buscando errores) y da un resumen. Sale con código 0 si todo va bien: listo para
  GitHub Actions.

```bash
tests/ejecutar_pruebas.sh /ruta/a/Godot_v4.7.2           # todas (~1 minuto)
tests/ejecutar_pruebas.sh /ruta/a/Godot_v4.7.2 sigilo    # solo una
# En Windows, con Git Bash: tests/ejecutar_pruebas.sh "C:/Users/.../Godot_v4.7.2-stable_win64.exe"
```

| Prueba | Qué comprueba |
|---|---|
| `unidad` | radios de pisadas y aterrizajes, oclusión con pared, que la fuente no se oiga a sí misma |
| `pasos` | andando hay pisadas, parado no; agachado < andando < corriendo |
| `disparo` | un disparo = un ruido con el `Alert` del arma, más el impacto sin fuente |
| `oye_disparo` | un zombi a 60 studs no se entera del jugador quieto, oye el disparo y se acerca |
| `sigilo` | agachado y andando a ~22-25 studs no le oye; corriendo a ~15 sí |
| `oclusion` | corriendo a 20 studs con una pared en medio, no le oye |
| `jauria` | el zombi A oye al jugador y persigue; B solo oye el gruñido de A y va a mirar |
| `navegacion` | un zombi rodea la pared alta del nivel para llegar al otro lado |
| `ataque_y_muerte` | un zombi llega y ataca; con vida 0 el jugador muere y el nivel se reinicia |
| `regeneracion` | no regenera antes de 10 s; después sí |
| `danio_zombi` | balas (cuerpo, cabeza de un tiro, por el costado no cuenta), bate, bate a través de pared (no) |
| `maniqui` | el maniquí sigue funcionando con las armas (regresión) |
| `andar` | el movimiento recorre exactamente lo mismo que antes (17,97 studs en 4 s) |
| `cadencia` | la cadencia del rifle es la misma que antes (regresión) |
| `completo` | partida con los 4 zombis del nivel: el disparo alerta a alguno, sin errores |
| `rendimiento` | coste por zombi (informativo; falla si pasa de 0,5 ms) |

**Cuidado al escribir pruebas nuevas:** la oclusión funciona de verdad. Si el jugador corre hacia la fila de
bloques naranjas del nivel, los bloques amortiguan sus pisadas y el zombi no le oye. Las pruebas usan la zona
despejada (hacia −X desde el inicio).

Resultado del 2026-10-23 con Godot 4.7.2 (Linux, headless): **16/16 en verde**, menú y nivel sin errores. El
script de la auditoría da exactamente los mismos números que antes en movimiento (18,011 / 17,972 / 17,927 studs
a 20 / 60 / 144 FPS) y en cadencia.

---

## 12. Rendimiento medido

Tiempo real por fotograma (CPU; en headless, así que **no** incluye dibujar):

| Caso | ms por fotograma |
|---|---:|
| Nivel sin zombis | ~1,0 |
| Con 30 zombis deambulando | ~3,6 |
| **Coste de un zombi** | **~0,09** (animación ~0,05 + cerebro y física ~0,04) |
| Para comparar: el jugador (lógica + IK completa) | ~0,6-0,9 |

Un zombi cuesta unas 10 veces menos que el jugador. Lo que falta medir es la **GPU**: cada zombi son ~50
mallas sueltas (ver siguientes pasos).

*Nota sobre cómo medir:* los contadores `Performance.TIME_PROCESS`/`TIME_PHYSICS_PROCESS` en headless con
`--fixed-fps` reparten el tiempo de forma engañosa (llegaron a sugerir 1 ms por zombi). Usa tiempo real entre
fotogramas, como hace la prueba `rendimiento`.

---

## 13. Limitaciones conocidas y siguientes pasos

Limitaciones de la v0:
- **Sin vista:** el zombi solo oye (y nota el contacto). Siguiente paso natural: visión con los valores
  `ZConfig.STANCE[].Sight`/`Near` que ya existen (más difícil de ver agachado o tumbado) y la luz.
- **Animación sencilla:** los pies pueden resbalar algo; sin IK ni reacciones elaboradas.
- **Sin ragdoll** ni para el zombi ni para el jugador (caen "como un tronco", igual que el maniquí).
- **Superficie:** todas las pisadas suenan igual (falta hierba/asfalto/metal: bastaría un multiplicador en
  `radio_paso` según el material del suelo).
- **Voces y sonidos sintetizados:** placeholders hasta tener audios reales (Freesound, CC0).
- **Avisos al cerrar:** si al cerrar el juego está sonando un sonido, Godot avisa de recursos "leaked". Pasa
  también con el código original (comprobado con un disparo): es del motor y no afecta al juego.
- **Jolt:** una vez, con la CPU del contenedor saturada, salió un aviso interno de Jolt (`CreateJob`). No se
  reprodujo en ejecuciones repetidas.

Siguientes pasos propuestos (por orden):
1. Visión (con postura y luz) + memoria compartida entre zombis cercanos.
2. Objetos arrojables para distraer (botellas, latas): son solo `Ruido.emitir` en el punto de impacto.
3. LOD: zombis lejanos sin animar o a menos Hz; fusionar las ~50 mallas del muñeco en una con `Skeleton3D`.
4. Sonidos reales y pisadas según superficie.
5. Hordas y oleadas desde el director; zombis que comen / se quedan junto al cadáver.

---

## 14. Archivos tocados

**Nuevos:** `scripts/ruido/ruido.gd`, `scripts/zombis/zombi.gd`, `scripts/zombis/director_zombis.gd`,
`scripts/ui/medidor_ruido.gd`, `tests/pruebas_ruido.gd`, `tests/ejecutar_pruebas.sh`, este documento (y los
`.uid` de los scripts nuevos).

**Existentes (cambios mínimos, todos comentados en el código):**

| Archivo | Cambio |
|---|---|
| `scripts/config/zconfig.gd` | + tablas `RUIDO` y `ZOMBI` (al final; nada existente cambia) |
| `scripts/jugador/animador.gd` | + ruido de pisada al apoyar el pie (3 líneas) y de reptar (5 líneas) |
| `scripts/jugador/jugador.gd` | + grupo `jugador`, medidor de ruido, ruidos de aterrizar/valla/cornisa, `recibir_danio`/muerte/regeneración, F6/F7 en el texto de ayuda |
| `scripts/jugador/arsenal.gd` | + ruidos de armas; blancos genéricos (grupo `objetivos`, meta `objetivo`) en vez de `Maniqui`; balas con `impacto_bala`; golpes sin atravesar paredes |
| `scripts/nivel/maniqui.gd` | + grupo `objetivos` y meta `objetivo` (2 líneas; se conservan `maniquies` y `maniqui`) |
| `scripts/nivel/nivel_pruebas.gd` | + `_crear_zombis()` (director + 4 zombis) |

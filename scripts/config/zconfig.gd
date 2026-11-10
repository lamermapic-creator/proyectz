class_name ZConfig
## Configuración central (copiada de ReplicatedStorage.ZConfig del juego de Roblox).
## Unidades en studs: el personaje mide ~5.8 studs (1.80 m) -> 1 stud ~ 0.31 m.

const STUD := 0.31 # metros por stud

const PLAYER := {
	# (más lentas que en Roblox, a pedido: 6.5 / 18.5 / 8.5 / 4.5 se veían demasiado rápidas)
	"WalkSpeed": 4.8,          # ~1.5 m/s (andar normal)
	"SprintSpeed": 14.0,       # ~4.3 m/s (carrera realista; aún se deja atrás a los zombies que caminan)
	"SprintAccel": 5.0,        # arranque de la carrera (más explosivo que andar)
	"CrouchSprintSpeed": 6.8,  # correr agachado
	"CrouchSprintDrain": 1.6,  # gasta un 60 % más de estamina que correr de pie
	"ProneSprintSpeed": 3.2,   # reptar rápido tumbado (Shift), ~1 m/s
	"ProneSprintDrain": 1.4,   # reptar deprisa cansa bastante
	"ExhaustRecover": 0.25,    # agotado: no puedes volver a correr hasta recuperar este % de estamina
	"AimSpeed": 3.6,           # caminar apuntando
	"Accel": 3.2,              # inercia al arrancar/frenar (más bajo = más peso)
	"Frenada": 26.0,           # deceleración al soltar las teclas (studs/s²): andando ~0,2 s, corriendo ~0,5 s
	"JumpHeight": 2.1,
	"JumpDistance": 8.0,       # distancia fija del salto en movimiento (~2.5 m), andando o corriendo
	"ProneTime": 1.35,         # segundos que tarda en tirarse al suelo / levantarse (por fases)
	"ProneRootHeight": 0.6,    # tumbado, la cápsula de colisión es baja
	"StaminaMax": 100.0,
	"InfiniteStamina": false,   # SOLO PARA PRUEBAS: poner en false para volver a la estamina normal
	"SprintDrain": 11.0,       # por segundo (~9 s de carrera con la estamina llena)
	"StaminaRegen": 15.0,
	"JumpCost": 12.0,
	"RegenDelay": 10.0,        # s sin daño antes de regenerar vida
	"RegenRate": 1.2,          # hp/s
}

## posturas: 0 = de pie, 1 = agachado, 2 = cuerpo a tierra
## Center = altura del centro del HumanoidRootPart sobre el suelo; Eye = altura de cámara sobre ese centro
const STANCE := [
	{"Speed": 1.0, "Center": 3.1, "Eye": 1.6, "Spread": 1.0, "Recoil": 1.0, "Sight": 1.0, "Near": 30},
	{"Speed": 0.55, "Center": 2.25, "Eye": 1.35, "Spread": 0.7, "Recoil": 0.75, "Sight": 0.6, "Near": 16},
	{"Speed": 0.26, "Center": 0.45, "Eye": 0.85, "Spread": 0.45, "Recoil": 0.5, "Sight": 0.35, "Near": 9},
]

## APOYAR EL ARMA (tecla X)
const REST := {
	"Spread": 0.3, "ProneSpread": 0.6, "Recoil": 0.35, "YawLimit": 50.0,
	"MaxGapStand": 0.4, "MaxGapCrouch": 0.5,   # cuánto puede quedar el apoyo por debajo del arma
}

## FÍSICA DEL MUNDO
const WORLD := {
	"Gravity": 35.0,     # casi real
	"AirControl": 5.0,   # studs/s² de control en el aire
	# FONDO DEL MUNDO (2026-11-10): quien cae por debajo de esta altura (studs) se ha salido del mapa. El zombi
	# desaparece (Zombi) y el jugador muere y el nivel se reinicia (red de seguridad del DirectorZombis).
	"FondoMundo": -200.0,
}

## CAÍDAS (velocidades de impacto en studs/s)
const FALL := {
	"SafeSpeed": 24.0, "KnockSpeed": 29.0, "LethalSpeed": 58.0,
	"RagdollSpeed": 20.0, "RagdollMinAir": 0.35, "RagdollGround": 4.5,
}

const HOLSTER_TIME := 0.42

## RUIDO (ver docs/RUIDO_Y_ZOMBIS.md). Cada valor es un RADIO en studs: hasta dónde se oye ese ruido
## en campo abierto. Una pared entre el ruido y quien escucha lo reduce (Oclusion).
## Los disparos usan el "Alert" de cada arma (Armas.WEAPONS).
const RUIDO := {
	"PasoMin": 3.0,          # pisada más suave (agachado, muy despacio)
	"PasoMax": 32.0,         # pisada corriendo (~10 m). Andar ~13 (~4 m), agachado ~5 (~1.5 m)
	"PasoAjuste": 0.4,       # pasitos de recolocar los pies (parado): multiplicador
	"Reptar": 3.0,           # tumbado, cada brazada
	"ReptarRapido": 7.0,     # tumbado con Shift
	"AterrizajeMin": 8.0,    # caer de un salto normal
	"AterrizajeMax": 45.0,   # caída fuerte (velocidad de impacto >= 40 studs/s)
	"Sortear": 12.0,         # saltar una valla (manos y pies golpean el obstáculo)
	"Encaramarse": 10.0,
	"Colgarse": 8.0,
	"Impacto": 25.0,         # bala contra una superficie (sirve para distraer)
	"GolpeAire": 5.0,        # blandir un arma blanca
	"GolpeCarne": 16.0,      # cuchillo o machete que acierta
	"GolpeContundente": 28.0, # bate que acierta
	"Recarga": 10.0,
	"Vacio": 5.0,            # clic del arma sin balas
	"Grunido": 45.0,         # un zombi que empieza a perseguir avisa a los de alrededor
	"Oclusion": 0.45,        # pared en medio: el radio se multiplica por esto
}

## ZOMBIS v0 (ver docs/RUIDO_Y_ZOMBIS.md). Velocidades en studs/s: el jugador anda a 4.8 y corre a 14.
const ZOMBI := {
	"Vida": 100.0,
	"Andar": 2.4,            # deambular (~0.75 m/s)
	"Trotar": 4.2,           # investigar un ruido con prisa
	"Correr": 7.5,           # perseguir (más que andar, menos que correr: corriendo se escapa)
	"Giro": 5.0,             # rapidez al girarse
	"Oido": 1.0,             # multiplicador del radio de los ruidos (cada zombi varía ±15 %)
	"AlertaDecae": 0.06,     # por segundo (de 1 a 0 en ~16 s)
	"PerseguirAlerta": 0.55, # alerta necesaria para perseguir al jugador
	"PerseguirMemoria": 2.5, # s que sigue persiguiendo sin oír nada nuevo del jugador
	"Contacto": 4.0,         # a esta distancia nota al jugador aunque no haga ruido (~1.2 m)
	"Alcance": 3.4,          # distancia de ataque
	"Danio": 20.0,
	"PreparaGolpe": 0.45,    # s desde que levanta los brazos hasta que golpea
	"Cadencia": 1.4,         # s entre ataques
	"Buscar": 6.0,           # s mirando alrededor al llegar a donde oyó el ruido
	"Deambular": 18.0,       # radio alrededor de su sitio por el que deambula
	"GrunidoCada": 8.0,      # s mínimos entre gruñidos de alerta
	"Cadaver": 30.0,         # s que se queda el cuerpo antes de desaparecer
	# VISTA (v1). Verte no es instantáneo: la "sospecha" sube (0..1) mientras te ve y al llegar a 1 te ha visto.
	# El alcance y la visión periférica dependen de tu postura (STANCE[].Sight y .Near).
	"VistaAlcance": 50.0,    # studs de pie (~15 m); agachado x0.6 (~9 m), tumbado x0.35 (~5 m)
	"VistaAngulo": 60.0,     # semiángulo del cono de visión (grados): 120° en total
	"VistaPeriferica": 0.35, # x STANCE.Near: te nota alrededor aunque no mire (de pie ~3 m, agachado ~1.7 m)
	"VistaRapidez": 0.7,     # rapidez de la sospecha: de pie y quieto, de frente a 6 m tarda ~1.6 s (tabla en la guía)
	"VistaOlvido": 0.3,      # cuánto baja la sospecha por segundo cuando no te ve
	"VistaSospecha": 0.45,   # a partir de aquí "le parece ver algo" y se acerca a mirar (sin perseguir)
	"VistaIntervalo": 0.1,   # s entre comprobaciones de vista (rendimiento)
	# INGENIO (v1)
	"Anticipar": 1.2,        # al perderte de vista, va a donde estarías en este tiempo (máx. 12 studs)
	"Reaccion": 0.5,         # s que tarda en reaccionar (girarse) a un ruido estando tranquilo
	"BuscarPuntos": 3,       # sitios que registra al buscarte (además de mirar alrededor)
	"BuscarRadio": 12.0,     # studs alrededor de donde te perdió
	"BuscarMirar": 1.6,      # s mirando alrededor en cada sitio
	"BuscarTiempo": 20.0,    # s máximos buscándote antes de rendirse
	# HERIDAS (2026-11-10). Un golpe o una bala le dicen DE QUÉ LADO vino, no dónde está quien lo hizo.
	"HeridaCerca": 12.0,     # studs (~3,7 m): a esta distancia sí sabe quién le ha dado (cuerpo a cuerpo, a quemarropa)
	"HeridaRastro": 30.0,    # studs (~9 m) que avanza hacia donde vino el golpe para ver qué ha sido
}

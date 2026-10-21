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
	"JumpHeight": 2.1,
	"JumpDistance": 8.0,       # distancia fija del salto en movimiento (~2.5 m), andando o corriendo
	"ProneTime": 1.35,         # segundos que tarda en tirarse al suelo / levantarse (por fases)
	"ProneRootHeight": 0.6,    # tumbado, la cápsula de colisión es baja
	"StaminaMax": 100.0,
	"InfiniteStamina": true,   # SOLO PARA PRUEBAS: poner en false para volver a la estamina normal
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
}

## CAÍDAS (velocidades de impacto en studs/s)
const FALL := {
	"SafeSpeed": 24.0, "KnockSpeed": 29.0, "LethalSpeed": 58.0,
	"RagdollSpeed": 20.0, "RagdollMinAir": 0.35, "RagdollGround": 4.5,
}

const HOLSTER_TIME := 0.42

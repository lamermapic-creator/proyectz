# Sonidos del juego (`sonidos/`)

Todos son **CC0 (dominio público)** de [Freesound](https://freesound.org): se pueden usar, cambiar y vender sin pedir
permiso ni citar al autor. Aun así se apuntan aquí por orden y por si alguien quiere el original.
Recortados, pasados a mono, nivelados por volumen y guardados en OGG con `/home/claude/sfx/proc.py` (sesión de Claude).

Los nombres siguen `<Tipo>_<n>.ogg`: `Efectos.sonido(ctx, "Tipo", ...)` elige una variante al azar. Para añadir
variantes basta con poner `Tipo_<n+1>.ogg` en la carpeta. Si un tipo no tiene archivo, se sintetiza como antes.

| Archivos | Original en Freesound | Autor |
|---|---|---|
| Pistol_1.ogg | [9mm pistol shot](https://freesound.org/s/427592/) | michorvath |
| Revolver_1.ogg | [22 magnum pistol shot](https://freesound.org/s/427594/) | michorvath |
| Rifle_1-4.ogg | [AR15 rifle shot](https://freesound.org/s/427596/), de la misma serie que la pistola; cola recortada para que suene seco y 4 variantes de tono/brillo (2026-10-27; script `/home/claude/sfx/rifle_build2.py`) | michorvath |
| SMG_1.ogg | [Thompson SMG Shot](https://freesound.org/s/258198/) | wadaltmon |
| SMG_2.ogg | [M3 Grease Gun Firing](https://freesound.org/s/258257/) | wadaltmon |
| Shotgun_1.ogg | [20 gauge shotgun gunshot](https://freesound.org/s/427595/) | michorvath |
| Sniper_1.ogg | [FPS Sniper Shot](https://freesound.org/s/816114/) | qubodup |
| Pump_1.ogg | [Pump Action Shotgun](https://freesound.org/s/387190/) | awrmacd |
| Bolt_1.ogg | [22 Bolt](https://freesound.org/s/204204/) | Danwardvs |
| ReloadRifle_1.ogg | [Rifle-or-shotgun-reload](https://freesound.org/s/432141/) | MaximBomba |
| ReloadPistol_1.ogg | [PistolReloadSound](https://freesound.org/s/432139/) | MaximBomba |
| Empty_1.ogg | [Gun Hammer Click](https://freesound.org/s/523087/) | magnuswaker |
| Draw_1.ogg | [Holster Pistol](https://freesound.org/s/388819/) | nioczkus |
| Shell_1.ogg | [12 guage shotgun shell drop](https://freesound.org/s/773860/) | MrGungus |
| Shell_2.ogg, Shell_3.ogg, Shell_4.ogg, Shell_5.ogg | [Brass bullet shell casing drop onto concrete](https://freesound.org/s/210102/) | GrayJoy |
| Swing_1.ogg | [Whoosh](https://freesound.org/s/60013/) | qubodup |
| Swing_2.ogg | [SWOSH-01](https://freesound.org/s/59988/) | qubodup |
| Flesh_1.ogg | [Knife Stab](https://freesound.org/s/179222/) | Mixedupmoviestuff |
| Flesh_2.ogg | [body_hit](https://freesound.org/s/276600/) | insanity54 |
| Blunt_1.ogg | [Foley_Punch_Edu_01](https://freesound.org/s/344394/) | soleilmadrid |
| Blunt_2.ogg | [Hit by metal baseball bat](https://freesound.org/s/684607/) | trader_one |
| Ricochet_1.ogg, Ricochet_2.ogg, Ricochet_3.ogg, Ricochet_4.ogg | [ricochet](https://freesound.org/s/148840/) | cedarstudios |
| Ricochet_5.ogg | [Ricochet 2](https://freesound.org/s/392975/) | morganpurkis |
| Impact_1.ogg | [HeavyBulletPing](https://freesound.org/s/351371/) | wilhellboy |
| Step_1.ogg, Step_2.ogg, Step_3.ogg, Step_4.ogg, Step_5.ogg, Step_6.ogg | [Hiking Boot Footsteps on Stone](https://freesound.org/s/521590/) | Fission9 |
| Step_7.ogg, Step_8.ogg, Step_9.ogg, Step_10.ogg, Step_11.ogg, Step_12.ogg | [Footsteps on concrete](https://freesound.org/s/459964/) | florianreichelt |
| Land_1.ogg | [Human Impact on Ground](https://freesound.org/s/364690/) | alegemaate |
| Land_2.ogg | [Jump Landing](https://freesound.org/s/172960/) | qubodup |
| BodyFall_1.ogg | [Body fall](https://freesound.org/s/417994/) | DylanTheFish |
| BodyFall_2.ogg | [BODY FALL - V HVY - DIRT](https://freesound.org/s/504626/) | leonelmail |


## Impactos de 0.6V

Cada familia tiene dos variantes OGG mono. Las mezclas recortan y combinan las grabaciones CC0 de la tabla. El audio se reproduce en el punto del contacto y, en los ataques físicos, el volumen sigue la fuerza del impacto.

| Familia | Grabaciones base |
|---|---|
| Punch | Blunt_1 y Flesh_2 |
| Kick | Flesh_2 y Land_1 |
| Stomp | Land_1 y BodyFall_2 |
| Block | Blunt_1 y Step_8 |
| Blade | Flesh_1 y Flesh_2 |
| BatHit | Blunt_2 y Flesh_2 |
| BulletBody | Flesh_2 y Flesh_1 |
| BulletSurface | Step_8 e Impact_1 |
| Crash | BodyFall_1 e Impact_1 |

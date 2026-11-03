# Revisión de jugabilidad — 2026-10-27

Revisión antes de pulir la jugabilidad. Hecha jugando escenarios con la **cámara del juego** (`tests/recorrido.gd`,
grabados a 30 FPS) y midiendo: tirones de cámara, cámara dentro de paredes, pies que patinan, velocidad al
arrancar/parar, tiempo hasta poder disparar tras girar y coste por fotograma.
Prioridad: 🔴 se nota mucho · 🟠 mejora clara · 🟡 detalle.

## Lo que ya está bien (comprobado)
- Disparar tras girar 115° de golpe: el primer tiro sale a los ~17 ms; cadencia del rifle exacta (600 RPM).
- La cámara nunca acaba dentro de una pared (0 fotogramas en todos los escenarios).
- Vallar, trepar al muro, agacharse, escaleras: sin atascos.

## Cámara y controles
1. 🔴 **De espaldas a una pared, al girar la cámara se mete en la cabeza del personaje** (se ve el interior de la
   cabeza unos fotogramas y luego desaparece el personaje). Medido: salto de 3,7 studs en un fotograma.
2. 🟠 **Saltos bruscos de cámara**: al apuntar se acerca ~4 studs de golpe (en 1 fotograma), al tumbarse 2 y al dejar
   de correr 1. Causa: la distancia deseada se aplica al instante (`update_camera`: `allowed < cam_dist`).
3. 🟠 **Tumbado, las piernas tapan media pantalla** al reptar y cuesta ver hacia delante.
4. 🟡 Al apuntar, el personaje ocupa casi un tercio de la pantalla (cabeza y rifle a la espalda).
5. 🟠 Teclas fijas en el código: no se pueden cambiar ni hay soporte de mando.

## Movimiento y animación
6. 🟠 **Se para en seco**: al soltar W la velocidad pasa a 0 en un fotograma, también corriendo a 14 studs/s
   (~4,3 m/s); al arrancar salta a 2,5 al instante. Una persona tarda 1–2 pasos en frenar.
7. 🟡 Al correr, el pie apoyado patina hasta 0,4 studs (~12 cm) antes de levantarse.
8. 🟡 En el editor (F5) se juega con **estamina infinita** (`InfiniteStamina: true`); el .exe sí la tiene. Se ajusta la
   jugabilidad sin cansancio.

## Armas y combate
9. 🔴 **Sonido**: todos los sonidos son sintéticos (generados por código) y no hay pasos que se oigan. Cambiarlos por
   sonidos reales gratuitos (Freesound CC0 / Sonniss GDC) es el mayor salto de calidad posible.
10. 🟠 **Tirón en el primer disparo** (~27 ms): cada sonido se genera la primera vez que suena → precargarlos.
11. 🟠 El **fogonazo** es una bola amarilla opaca: mejor un destello con brillo, humo y casquillos que salen.
12. 🟡 Cada agujero de bala crea su propio material transparente (hasta 70): más coste del necesario.
13. 🟠 No hay **munición ni botiquines** que recoger en el mapa (solo con el menú F1).

## Interfaz
14. 🟠 **Legibilidad**: la munición (blanco sobre suelo claro) casi no se ve; los avisos ("BAJA") igual. Falta
    contorno/sombra.
15. 🟠 La barra de armas (centro abajo) tapa los pies del personaje y la línea de ayuda de controles está siempre
    visible y se sale de la pantalla por la derecha.
16. 🟠 Sin **indicador de daño** (de dónde te pegan) ni viñeta roja; al morir solo sale "HAS MUERTO" y se reinicia.
17. 🟡 Barras de vida/estamina sin rótulo ni números.

## Técnico
18. 🟡 La simulación del jugador sigue en `_process` (AUDITORIA §7.4).
19. 🟡 `CLAUDE.md` → "Problemas conocidos" dice que no hay ragdoll en la moto (ya lo hay).

## Estado tras el pulido (2026-10-27)
Hecho: 1, 2, 3, 4 (cámara), 6 (inercia; 7 medido de nuevo: el pie no patina, era el talón/punta rodando),
8 (`InfiniteStamina` false), 9, 10, 11, 12 (sonido y efectos), 14, 15, 16, 17 (interfaz), 19 (CLAUDE.md).
Medidas después: tirón de cámara al apuntar 3,9 → 0,76 studs/fotograma, al tumbarse 2,0 → 0,22, al dejar de correr
1,04 → 0,41; de espaldas a la pared la cámara ya no entra en la cabeza; frenar corriendo ~0,5 s, andando ~0,18 s.
Además: ragdoll "muchísimo más exagerado" (pedido aparte; ver CAMBIOS.md).
Quedan: 5 (teclas configurables / mando), 13 (munición y botiquines en el mapa), 18 (`_physics_process`).

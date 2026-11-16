#!/usr/bin/env bash
# Ejecuta TODAS las pruebas automáticas del proyecto en modo headless (sin ventana).
# Uso:   tests/ejecutar_pruebas.sh [ruta/a/godot]        (o variable de entorno GODOT)
#        tests/ejecutar_pruebas.sh godot sigilo pasos    (solo esas pruebas)
# Necesita Godot 4.7.2 (en Windows sirve con Git Bash: ruta al .exe de Godot).
# Guía: docs/RUIDO_Y_ZOMBIS.md, sección "Pruebas".
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-${GODOT:-godot}}"
shift || true
SOLO=("$@")

if ! "$GODOT" --version >/dev/null 2>&1; then
	echo "No encuentro Godot ('$GODOT'). Pásalo como primer argumento o en la variable GODOT."
	exit 2
fi

MODOS=(unidad pasos disparo oye_disparo sigilo oclusion jauria navegacion ataque_y_muerte regeneracion
	danio_zombi maniqui andar cadencia completo rendimiento
	vista_frente vista_espalda vista_pared vista_lejos vista_postura vista_sigue anticipar busqueda reaccion indicador
	ataque_pared herida_lejos fondo_mundo)
[ ${#SOLO[@]} -gt 0 ] && MODOS=("${SOLO[@]}")

fallos=0
resumen=()
# errores de verdad en la salida (los avisos de recursos "leaked" al cerrar no cuentan)
hay_errores() { grep -E "SCRIPT ERROR|^ERROR:|Parse Error" <<<"$1" | grep -v "leaked" ; }

echo "== Importando el proyecto"
"$GODOT" --headless --path "$RAIZ" --import >/dev/null 2>&1

echo "== Compilando scripts"
while IFS= read -r f; do
	salida="$("$GODOT" --headless --path "$RAIZ" --check-only --script "res://$f" 2>&1)"
	errores="$(hay_errores "$salida")"
	if [ -n "$errores" ]; then
		echo "  [MAL] $f"; echo "$errores" | head -5
		fallos=$((fallos + 1)); resumen+=("FALLO compilar $f")
	fi
done < <(cd "$RAIZ" && find scripts tests -name '*.gd' | sort)
[ $fallos -eq 0 ] && resumen+=("OK    compilar todos los scripts")

for m in "${MODOS[@]}"; do
	salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 -s res://tests/pruebas_ruido.gd -- "$m" 2>&1)"
	echo "$salida" | grep -E "^== |\[bien\]|\[MAL\]|^  " | grep -vE "game_helper|at: cleanup"
	errores="$(hay_errores "$salida")"
	if grep -q "^OK $m" <<<"$salida" && [ -z "$errores" ]; then
		resumen+=("OK    $m")
	else
		[ -n "$errores" ] && echo "$errores" | head -10
		fallos=$((fallos + 1)); resumen+=("FALLO $m")
	fi
done

if [ ${#SOLO[@]} -eq 0 ]; then
	# Balística, variedad física de muertes y manejo de moto.
	for prueba in balistica:BALISTICA manejo_moto:MANEJO_MOTO variedad_ragdoll:VARIEDAD_RAGDOLL; do
		archivo="${prueba%%:*}"; marca="${prueba##*:}"
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 -s "res://tests/$archivo.gd" 2>&1)"
		grep -E "^($marca|MANEJO |VARIEDAD |MAL )" <<<"$salida"
		errores="$(hay_errores "$salida")"
		if grep -q "^$marca .*fallos=0$" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    $archivo")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO $archivo"); fi
	done
	# moto (v0.4, tests/moto.gd): conducir, saltar, cuestas, bloques, girar despacio, levantarla, atropellar,
	# chocar, armas, derrapar, bajarse
	# (empinada_N: a fondo contra las rampas de 15/30/50°; bajada: cuesta abajo por la de 30°; 30fps: lo mismo a 30 FPS)
	for m in conducir salto morro cuesta bloque lento levantar atropello zombi choque disparar golpear derrape bajar suspension \
			empinada_15 empinada_30 empinada_50 bajada morro_30fps empinada_50_30fps; do
		modo="${m%%_*}"; extra=(); fps=60
		[[ "$m" == empinada_* ]] && { a="${m#empinada_}"; extra=(--angulo="${a%%_*}"); }
		[[ "$m" == *_30fps ]] && fps=30
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps $fps res://tests/escena_moto.tscn -- --modo=$modo "${extra[@]}" 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^(OK|MAL) moto_" <<<"$salida"
		if grep -q "^OK moto_$modo" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    moto_$m")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO moto_$m"); fi
	done
	# choques de la moto (2026-10-28, tests/moto.gd --modo=eyecta): un bloque de 20 cm no tira al piloto; uno de
	# 40 cm a 50 studs/s lo lanza lejos por encima del manillar; un muro a 35 lo tira
	for c in bloque20:50 bloque40:50 muro:35; do
		o="${c%%:*}"; v="${c##*:}"
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_moto.tscn -- --modo=eyecta --obst=$o --vel=$v 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^MOTO eyecta|^(OK|MAL) moto_" <<<"$salida"
		if grep -q "^OK moto_eyecta" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    moto_eyecta_${o}_$v")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO moto_eyecta_${o}_$v"); fi
	done
	# atascos (2026-10-29, tests/moto.gd --modo=atasco): contra el bloque naranja de 20 cm del nivel, despacio y de
	# lado, la moto lo sube y sigue (antes se quedaba con una rueda arriba y otra abajo)
	# moto entre bloques: marcha atrás la saca; levantarla en el hueco no la hunde ni la tira (2026-10-29)
	# apuntado libre en 360° desde la moto, parada y en marcha (2026-10-30): dispara en todas direcciones, el cañón
	# va a la mira, solo con el brazo derecho, sin atravesar el cuerpo; "giros": tirones del ratón de un lado a
	# otro, la mano se mueve con naturalidad (velocidad y aceleración limitadas, 2026-11-01)
	for c in "fila --vel=6" "fila --vel=12 --lado=0.6" "levantar_hueco --x=-33.9 --ang=45" "levantar_hueco --x=-35.68 --ang=0" \
			"apuntar360" "apuntar360 --mover" "giros"; do
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_moto.tscn -- --modo=$c 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^MOTO (fila|levantar_hueco|apuntar360|giros)|^(OK|MAL) moto_" <<<"$salida"
		if grep -q "^OK moto_" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    moto_${c// /_}")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO moto_${c// /_}"); fi
	done
	for c in 0:3:0 0:3:25 0:16:25 0:8:50; do
		IFS=: read -r bq v a <<<"$c"
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_moto.tscn -- --modo=atasco --bloque=$bq --vel=$v --ang=$a 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^MOTO atasco|^(OK|MAL) moto_" <<<"$salida"
		if grep -q "^OK moto_atasco" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    moto_atasco_${bq}_${v}_$a")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO moto_atasco_${bq}_${v}_$a"); fi
	done
	# levantarse tras un derribo sin tirones (2026-10-30, tests/recorrido.gd --escenario=derribo_llano)
	# y subirse a un muro con hueco debajo, el techo de los túneles (2026-11-08, --escenario=dintel / dintel_bajo)
	for e in derribo_llano dintel dintel_bajo; do
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_recorrido.tscn -- --escenario=$e 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^(OK|MAL) recorrido_" <<<"$salida"
		if grep -q "^OK recorrido_$e" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    $e")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO $e"); fi
	done
	# combate cuerpo a cuerpo (2026-11-08, tests/combate.gd --cc=todo): guardia, patada, empujón, parada y bloqueo
	# y golpes variados (--cc=golpes: puñetazos sin arma, golpes de siempre y nuevos con armas blancas)
	for prueba in todo:manos todo:Cuchillo todo:Bate todo:Pistola todo:Rifle golpes:manos golpes:Cuchillo golpes:Machete golpes:Bate; do
		acc="${prueba%%:*}"; w="${prueba##*:}"
		arg=""
		[ "$w" != "manos" ] && arg="--arma=$w"
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_combate.tscn -- --cc=$acc $arg 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^(OK|MAL) cc_" <<<"$salida"
		if grep -q "^OK cc_$w" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    cc_${acc}_$w")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO cc_${acc}_$w"); fi
	done
	# física de los golpes (2026-11-08, tests/fisica_cc.gd): empujones y patadas a un zombi quieto (retrocede, se echa
	# atrás y a veces cae)
	for g in empujon patada; do
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_fisica_cc.tscn -- --golpe=$g 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^FISICA golpe|^(OK|MAL) fisica_" <<<"$salida"
		if grep -q "^OK fisica_$g" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    fisica_$g")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO fisica_$g"); fi
	done
	# golpes a un zombi en el suelo (2026-11-08, 6, tests/suelo_cc.gd): se agacha / inclina y le da (pisotón con G)
	# (también a cadáveres, --muerto, y con las piernas delante y el pecho lejos, --distancia=4.2; --grupo: con zombis de
	# pie delante se pega a ellos y no al del suelo, salvo mirando hacia abajo, --mira_abajo)
	for caso in pisoton puno cuchillo bate "pisoton --muerto" "cuchillo --muerto --distancia=4.0" "puno --distancia=4.2" \
		"puno --grupo" "pisoton --grupo" "cuchillo --grupo" "puno --grupo --mira_abajo" "pisoton --grupo --mira_abajo"; do
		g="${caso%% *}"; extra=""; [ "$caso" != "$g" ] && extra="${caso#* }"
		nombre="suelo_$g${extra:+ $extra}"
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_suelo_cc.tscn -- --golpe=$g $extra 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^SUELO golpe|^(OK|MAL) suelo_" <<<"$salida"
		if grep -q "^OK suelo_$g" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    $nombre")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO $nombre"); fi
	done
	# ragdoll (tests/ragdoll.gd): muñeco suelto y jugador (derribo, caída larga, aterrizaje fuerte, muerte)
	for m in empuje alto morir limites j_derribo j_caida j_aterriza j_morir j_moto; do
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 res://tests/escena_ragdoll.tscn -- --modo=$m 2>&1)"
		errores="$(hay_errores "$salida")"
		grep -E "^(OK|MAL) ragdoll_" <<<"$salida"
		if grep -q "^OK ragdoll_$m" <<<"$salida" && [ -z "$errores" ]; then resumen+=("OK    ragdoll_$m")
		else [ -n "$errores" ] && echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO ragdoll_$m"); fi
	done
	for escena in "" "res://escenas/pruebas_movimiento.tscn"; do
		nombre="${escena:-menú principal}"
		salida="$("$GODOT" --headless --path "$RAIZ" --fixed-fps 60 --quit-after 600 $escena 2>&1)"
		errores="$(hay_errores "$salida")"
		if [ -z "$errores" ]; then resumen+=("OK    arrancar $nombre 10 s sin errores")
		else echo "$errores" | head -10; fallos=$((fallos + 1)); resumen+=("FALLO arrancar $nombre"); fi
	done
fi

echo
echo "================ RESUMEN ================"
printf '%s\n' "${resumen[@]}"
echo "========================================="
[ $fallos -eq 0 ] && echo "TODO BIEN" || echo "$fallos FALLO(S)"
exit $fallos

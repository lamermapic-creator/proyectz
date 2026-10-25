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
	danio_zombi maniqui andar cadencia completo rendimiento)
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
	# moto (v0.4, tests/moto.gd): conducir, saltar, cuestas, bloques, girar despacio, levantarla, atropellar,
	# chocar, armas, derrapar, bajarse
	# (empinada_N: a fondo contra las rampas de 15/30/50°; bajada: cuesta abajo por la de 30°; 30fps: lo mismo a 30 FPS)
	for m in conducir salto morro cuesta bloque lento levantar atropello zombi choque disparar golpear derrape bajar \
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
	# ragdoll (tests/ragdoll.gd): muñeco suelto y jugador (derribo, caída larga, aterrizaje fuerte, muerte)
	for m in empuje alto morir limites j_derribo j_caida j_aterriza j_morir; do
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

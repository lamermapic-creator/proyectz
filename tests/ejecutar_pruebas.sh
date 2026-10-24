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

# Proyecto Z

Juego de zombis en tercera persona, realista y de sigilo, hecho en **Godot 4.7.2** (empezó en Roblox).
Estado: prototipo de movimiento, combate y zombis v0 que se guían por el ruido (nivel de pruebas; aún sin mapa).
Todo lo que haces suena: agachado no te oyen, corriendo o disparando sí. Ver `docs/RUIDO_Y_ZOMBIS.md`.

## Abrir el proyecto
1. Instala **Godot 4.7.2** (versión estándar, no .NET): https://godotengine.org/download/archive/
2. Clona este repositorio con **GitHub Desktop** (File → Clone repository).
3. Abre Godot → **Importar** → elige el archivo `project.godot` de la carpeta clonada.
4. La primera vez tarda un poco (Godot crea su caché `.godot/`). Pulsa **F5** para jugar.

## Controles
WASD moverse · Shift correr (tumbado: reptar rápido) · Espacio saltar/sortear/trepar · C o Ctrl agacharse ·
Z cuerpo a tierra · Q/E asomarse · 1-4 armas · Clic der. apuntar · Clic izq. disparar/golpear · R recargar ·
X apoyar el arma · F recoger · V cambiar de hombro · Colgado: A/D moverse, Espacio subir, S soltarse · Esc pausa.
Solo en el editor: F4 estamina infinita, F5 balas infinitas, F6 ver el ruido y el estado de los zombis,
F7 zombis sordos.

## Pruebas automáticas
`tests/ejecutar_pruebas.sh <ruta a Godot 4.7.2>` importa el proyecto, compila todos los scripts, pasa las
16 pruebas (ruido, zombis y regresión) y arranca el menú y el nivel buscando errores (~1 minuto, sin
ventana). En Windows se ejecuta con Git Bash. Detalle en `docs/RUIDO_Y_ZOMBIS.md`, sección "Pruebas".

## Trabajar con Claude en Godot (opcional)
El proyecto incluye el plugin **Godot AI** (`addons/godot_ai`), que deja a Claude Desktop controlar el editor.
1. Instala **uv**: https://docs.astral.sh/uv/getting-started/installation/
2. Abre el proyecto en Godot; en el panel **Godot AI** debe poner "Server connected".
3. En Claude Desktop → Configuración → Desarrollador → Editar configuración, añade dentro de `"mcpServers"`
   (cambia `TU_USUARIO` por tu usuario de Windows):
```json
"godot-ai": {
  "command": "C:\\Users\\TU_USUARIO\\.local\\bin\\uvx.exe",
  "args": ["--system-certs", "--from", "godot-ai==4.3.0", "godot-ai", "attach", "--port", "8001", "--ws-port", "8002"],
  "env": {
    "UV_CACHE_DIR": "C:\\Users\\TU_USUARIO\\AppData\\Local\\uv\\cache",
    "UV_PYTHON_INSTALL_DIR": "C:\\Users\\TU_USUARIO\\AppData\\Roaming\\uv\\python"
  }
}
```
4. Reinicia Claude Desktop con Godot abierto.
5. Pide a Claude que lea **CLAUDE.md** antes de empezar: ahí están el diseño, el estado y las normas de trabajo.

## Exportar un ejecutable
Proyecto → Exportar → Windows Desktop → Exportar proyecto (sin "Exportar con depuración").
Hace falta instalar las plantillas de exportación de 4.7.2 la primera vez (Editor → Gestionar plantillas).

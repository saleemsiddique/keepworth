#!/usr/bin/env bash
# Regenera el proyecto Xcode cuando cambia la definición de Tuist.
# Evita el fallo clásico de declarar un módulo y seguir trabajando sobre un
# .xcodeproj desactualizado que no lo contiene.
set -uo pipefail

payload=$(cat)
file_path=$(printf '%s' "$payload" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
    2>/dev/null)

case "$(basename "$file_path")" in
    Project.swift | Workspace.swift | Package.swift) ;;
    *) exit 0 ;;
esac

if ! command -v tuist >/dev/null 2>&1; then
    echo "tuist no disponible: instálalo con 'mise install tuist' antes de continuar." >&2
    exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

tuist install >/dev/null 2>&1
if ! tuist generate --no-open; then
    # Se devuelve 2 para que Claude vea el error y corrija el manifiesto.
    echo "tuist generate ha fallado: revisa Project.swift." >&2
    exit 2
fi

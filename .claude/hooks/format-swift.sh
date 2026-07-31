#!/usr/bin/env bash
# Formatea con swift-format el archivo Swift que Claude acaba de editar.
# Recibe por stdin el JSON del hook PostToolUse.
set -uo pipefail

payload=$(cat)
file_path=$(printf '%s' "$payload" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
    2>/dev/null)

[[ "$file_path" == *.swift ]] || exit 0
[[ -f "$file_path" ]] || exit 0

if ! xcrun --find swift-format >/dev/null 2>&1; then
    # Sin Xcode 16+ el hook queda inerte. Se avisa una vez en lugar de fallar en silencio.
    echo "swift-format no disponible: instala Xcode 16 o superior." >&2
    exit 0
fi

config="${CLAUDE_PROJECT_DIR:-.}/.swift-format"
if [[ -f "$config" ]]; then
    xcrun swift-format format --in-place --configuration "$config" "$file_path"
else
    xcrun swift-format format --in-place "$file_path"
fi

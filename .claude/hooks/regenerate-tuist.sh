#!/usr/bin/env bash
# Regenerates the Xcode project whenever the Tuist definition changes.
# Avoids the classic failure of declaring a module and carrying on against a stale
# .xcodeproj that does not contain it.
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
    echo "tuist unavailable: install it with 'mise install tuist' before continuing." >&2
    exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

tuist install >/dev/null 2>&1
if ! tuist generate --no-open; then
    # Exit 2 so the agent sees the failure and fixes the manifest.
    echo "tuist generate failed: check Project.swift." >&2
    exit 2
fi

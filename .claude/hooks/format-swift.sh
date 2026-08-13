#!/usr/bin/env bash
# Runs swift-format over the Swift file the agent has just edited.
# Reads the PostToolUse hook JSON from stdin.
set -uo pipefail

payload=$(cat)
file_path=$(printf '%s' "$payload" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
    2>/dev/null)

[[ "$file_path" == *.swift ]] || exit 0
[[ -f "$file_path" ]] || exit 0

if ! xcrun --find swift-format >/dev/null 2>&1; then
    # Without Xcode 16+ the hook is inert. Say so once rather than fail silently.
    echo "swift-format unavailable: install Xcode 16 or later." >&2
    exit 0
fi

config="${CLAUDE_PROJECT_DIR:-.}/.swift-format"
if [[ -f "$config" ]]; then
    xcrun swift-format format --in-place --configuration "$config" "$file_path"
else
    xcrun swift-format format --in-place "$file_path"
fi

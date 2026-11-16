#!/usr/bin/env bash
# Build the console. Dependencies are installed when the lockfile changed, and
# the build is skipped when nothing it reads is newer than the last one.
set -euo pipefail

if [[ "$#" != 1 || "$1" == --help ]]; then
    echo 'usage: build-ui.sh /path/to/ui' >&2
    [[ "${1:-}" == --help ]] && exit 0
    exit 1
fi
cd "$1"

if [[ "${MESH_LLM_BUILD_PROFILE:-debug}" == release ]]; then
    export VITE_MESH_LLM_DEBUG_UI=false
else
    export VITE_MESH_LLM_DEBUG_UI="${VITE_MESH_LLM_DEBUG_UI:-true}"
fi

# The stamp records the settings the last build used.
stamp=dist/.mesh-llm-ui-build-env
settings="$(env | grep '^VITE_' | LC_ALL=C sort)"
inputs=(package.json pnpm-lock.yaml vite.config.ts tsconfig.json tsconfig.app.json
    tsconfig.node.json biome.json index.html .env .env.local .env.production
    .env.production.local src public)
existing=()
for input in "${inputs[@]}"; do
    [[ -e "$input" ]] && existing+=("$input")
done
if [[ -f "$stamp" && "$(cat "$stamp")" == "$settings" ]] \
    && [[ -z "$(find "${existing[@]}" -newer "$stamp" -print -quit)" ]]; then
    echo "console is up to date"
    exit 0
fi

if [[ ! -d node_modules || package.json -nt node_modules || pnpm-lock.yaml -nt node_modules ]]; then
    pnpm install --frozen-lockfile
fi
rm -f "$stamp"
pnpm run build
printf '%s\n' "$settings" > "$stamp"

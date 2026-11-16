#!/usr/bin/env bash
# Build the Node SDK's native addon, load it from a packed SDK, and package it
# as mesh-llm-node-sdk-addon-<version>-<platform>.tar.gz with its checksum.
#   ci/simple/package-node-addon.sh <version> <output-dir>
set -euo pipefail

version="${1#v}" output="$2"
sdk=mesh/sdk/node
target="$(node -p 'process.platform + "-" + process.arch')"
case "$target" in
    darwin-arm64) backend=metal ;;
    linux-arm64 | linux-x64 | win32-x64) backend=cpu ;;
    *) echo "no Node SDK addon release for $target" >&2; exit 1 ;;
esac
sha256_of() { node -e 'const fs=require("fs"),c=require("crypto");console.log(c.createHash("sha256").update(fs.readFileSync(process.argv[1])).digest("hex"))' "$1"; }

npm test --prefix "$sdk"
LLAMA_STAGE_BACKEND="${LLAMA_STAGE_BACKEND:-$backend}" npm run build:native --prefix "$sdk"
addon="$sdk/native/$target/mesh_llm_nodejs.node"
test -s "$addon"

# Install the packed SDK into an empty project and load the addon from it.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/tarball" "$work/consumer" "$work/stage/$target" "$output"
(cd "$sdk" && npm pack --pack-destination "$work/tarball")
(cd "$work/consumer" && npm init --yes >/dev/null && npm install "$work"/tarball/*.tgz)
node - "$work/consumer" "$version" <<'NODE'
const [root, expected] = process.argv.slice(2)
const sdk = require(require.resolve("@mesh-llm/sdk", { paths: [root] }))
const actual = sdk.currentMeshVersion()
if (actual !== expected) {
  throw new Error(`native addon version mismatch: expected ${expected}, got ${actual}`)
}
NODE

cp "$addon" "$work/stage/$target/mesh_llm_nodejs.node"
printf '{\n  "schema": "mesh-llm-node-sdk-addon-v1",\n  "version": "%s",\n  "target": "%s",\n  "file": "mesh_llm_nodejs.node",\n  "sha256": "%s"\n}\n' \
    "$version" "$target" "$(sha256_of "$addon")" > "$work/stage/$target/manifest.json"
archive="mesh-llm-node-sdk-addon-$version-$target.tar.gz"
tar -C "$work/stage" -czf "$output/$archive" "$target"
printf '%s  %s\n' "$(sha256_of "$output/$archive")" "$archive" > "$output/$archive.sha256"
echo "packaged $output/$archive"

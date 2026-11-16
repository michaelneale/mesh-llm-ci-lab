#!/usr/bin/env bash
# Build the native SDK runtime for this platform, check it, and package it as
# meshllm-native-<os>-<arch>-<backend>.tar.gz with its checksum, plus the Rust
# crate that carries it.
#   ci/simple/package-native-sdk.sh <output-dir>
set -euo pipefail

output="$1"
case "$(uname -s)" in
    Darwin) backend=metal ;;
    Linux) backend=cpu ;;
    *) echo "no native SDK release for $(uname -s)" >&2; exit 1 ;;
esac

# Keep macOS tar from adding ._ metadata entries beside the artifact directory.
export COPYFILE_DISABLE=1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
scripts/package-native-sdk.sh --build --backend "$backend" --profile release --out "$work/sdk"
archive="$(echo "$work"/sdk/meshllm-native-*.tar.gz)"
unpacked="${archive%.tar.gz}"
scripts/verify-native-sdk-package.sh "$archive"
scripts/verify-native-sdk-package.sh "$unpacked"
scripts/package-native-sdk-crate.sh --out "$work/crates" "$unpacked"

mkdir -p "$output"
cp "$archive" "$archive.sha256" "$work"/crates/*/target/package/*.crate "$output/"
echo "packaged $(basename "$archive") and its crate into $output"

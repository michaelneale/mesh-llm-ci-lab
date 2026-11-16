#!/usr/bin/env bash
# Package the release Skippy CLI built by `just release-build*` as
# skippy-<version>-<os>-<arch>-cli.tar.gz, with its checksum.
#   ci/simple/package-skippy-cli.sh <version> <output-dir>
set -euo pipefail

version="$1" output="$2"
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) target=darwin-aarch64 ;;
    Linux-x86_64) target=linux-x86_64 ;;
    Linux-aarch64) target=linux-aarch64 ;;
    MINGW*-x86_64 | MSYS*-x86_64) target=windows-x86_64 ;;
    *) echo "no Skippy CLI release for $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

binary=skippy
checks=(--max-glibc declared)
if [[ "$target" == windows-* ]]; then
    binary=skippy.exe
    checks=(--format pe)
fi
built="$(find target -maxdepth 3 -type f -path '*/release/*' -name "$binary" | head -n 1)"
[[ -n "$built" ]] || { echo "no release $binary under target/" >&2; exit 1; }

input="$(mktemp -d)"
cp "$built" "$input/$binary"
# The report records which system libraries the binary needs.
cargo xtool native verify-host-dependencies "$input/$binary" --bind-sha256 \
    --report "$input/host-imports.json" "${checks[@]}"
hash="$(if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi < "$input/$binary" | awk '{print $1}')"
printf '%s  %s\n' "$hash" "$binary" > "$input/$binary.sha256"
skippy/scripts/package-cli-release.sh "$version" "$target" "$input" "$output"

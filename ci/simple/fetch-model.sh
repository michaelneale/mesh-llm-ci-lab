#!/usr/bin/env bash
# Download one pinned test model from a manifest under ci/model-artifacts and
# check its size and SHA-256. Prints the model path.
#   ci/simple/fetch-model.sh <manifest.json> <artifact-id> <dir>
set -euo pipefail

manifest="$1" id="$2" dir="$3"
entry="$(jq -ce --arg id "$id" '.artifacts[] | select(.id == $id)' "$manifest")"
file="$(jq -r '.files[0]' <<<"$entry")"
url="$(jq -r '.urls[0]' <<<"$entry")"
sha="$(jq -r --arg f "$file" '.file_integrity[$f].blob_id' <<<"$entry")"
size="$(jq -r --arg f "$file" '.file_integrity[$f].size_bytes' <<<"$entry")"

# Hash from standard input: given a Windows path, sha256sum escapes its output.
hash_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi < "$1" | awk '{print $1}'
}

mkdir -p "$dir"
path="$dir/$file"
if [[ ! -f "$path" || "$(hash_of "$path")" != "$sha" ]]; then
    curl --fail --location --silent --show-error --retry 5 --retry-all-errors --retry-delay 5 \
        --output "$path" "$url"
fi
[[ "$(wc -c < "$path" | tr -d ' ')" == "$size" ]] || { echo "$file: wrong size" >&2; exit 1; }
[[ "$(hash_of "$path")" == "$sha" ]] || { echo "$file: wrong sha256" >&2; exit 1; }
printf '%s\n' "$path"

#!/usr/bin/env bash
# Run `cargo test -p <crate>` for one shard of the workspace, one crate at a
# time so each is built with its own feature set, as a developer would run it.
#   ci/simple/test-crates.sh <shard-index> <shard-count>
set -euo pipefail

index="$1" count="$2"

# skippy-ffi has no tests CI runs; xtask is repository automation with its own
# suite (`just ci-automation-contracts`).
mapfile -t crates < <(cargo metadata --locked --no-deps --format-version 1 \
    | jq -r '.packages[].name' | grep -Evx 'skippy-ffi|xtask' | sort \
    | awk -v i="$index" -v n="$count" 'NR % n == i')

for crate in "${crates[@]}"; do
    echo "::group::cargo test -p $crate"
    start=$SECONDS
    cargo test --locked -p "$crate"
    echo "::endgroup::"
    echo "$crate: $((SECONDS - start))s"
done

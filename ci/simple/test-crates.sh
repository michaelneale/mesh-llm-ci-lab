#!/usr/bin/env bash
# Run `cargo test -p <crate>` for one shard of the workspace, one crate at a
# time so each is built with its own feature set, as a developer would run it.
# Every crate in the shard runs even after a failure, so one run shows them all.
#   ci/simple/test-crates.sh <shard-index> <shard-count>
set -euo pipefail

index="$1" count="$2"

# skippy-ffi has no tests CI runs. ci-controller is the planner behind the
# previous CI; its suite asserts workflows this CI replaced.
mapfile -t crates < <(cargo metadata --locked --no-deps --format-version 1 \
    | jq -r '.packages[].name' | grep -Evx 'skippy-ffi|ci-controller' | sort \
    | awk -v i="$index" -v n="$count" 'NR % n == i')

failed=()
for crate in "${crates[@]}"; do
    echo "::group::cargo test -p $crate"
    start=$SECONDS
    status=ok
    cargo test --locked -p "$crate" || { status=FAILED; failed+=("$crate"); }
    echo "::endgroup::"
    echo "$crate: $status in $((SECONDS - start))s"
done

if ((${#failed[@]})); then
    echo "::error::tests failed in: ${failed[*]}"
    exit 1
fi

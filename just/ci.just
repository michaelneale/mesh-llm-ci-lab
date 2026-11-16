# ── Full Validation Gate ───────────────────────────────────────

# Gate on println!/eprintln!/print!/eprint! and direct io::stdout()/io::stderr()
# handles in Rust files under crates/ (excluding tests, non-product crates, helper
# bins and build.rs). There is no allowlist: route output through mesh-llm-events.
no-console-print:
    cargo run -p xtask -- repo-consistency no-console-print

# Shellcheck the explicitly supplied changed shell scripts.
ci-shellcheck *scripts:
    shellcheck {{ scripts }}

# Run CI's format check, Clippy and every crate's tests on this machine.
test-all:
    #!/usr/bin/env bash
    set -euo pipefail
    cargo fmt --all -- --check
    just no-console-print
    scripts/prepare-llama.sh pinned
    scripts/build-llama.sh
    cargo clippy --locked --workspace --exclude skippy-ffi --all-targets -- -D warnings
    ci/simple/test-crates.sh 0 1

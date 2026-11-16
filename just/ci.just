# ── Full Validation Gate ───────────────────────────────────────

# Gate on println!/eprintln!/print!/eprint! and direct io::stdout()/io::stderr()
# handles in Rust files under crates/ (excluding tests, non-product crates, helper
# bins and build.rs). There is no allowlist: route output through mesh-llm-events.
no-console-print:
    cargo run -p xtask -- repo-consistency no-console-print

# Shellcheck the explicitly supplied changed shell scripts.
ci-shellcheck *scripts:
    shellcheck {{ scripts }}

# Restore the pinned external research checkout into .sdk-source/research,
# matching .github/actions/prepare-python-research-source. Admission is Rust-owned.
research-source-restore:
    #!/usr/bin/env bash
    set -euo pipefail
    repository="$(jq -er .repository ci/python-research-source.json)"
    revision="$(jq -er .revision ci/python-research-source.json)"
    target=.sdk-source/research
    if [[ ! -d "$target/.git" ]]; then
        git init --quiet "$target"
        git -C "$target" remote add origin "https://github.com/$repository.git"
    fi
    git -C "$target" fetch --quiet --depth 1 origin "$revision"
    git -C "$target" checkout --quiet --detach "$revision"

# Run all checks: repo consistency, Rust tests, author exemplars, fmt, clippy, UI/docs builds, and E2E smoke.
test-all:
    #!/usr/bin/env bash
    set -euo pipefail

    # Source-dependent Skippy benchmark tests consume a restored immutable
    # research checkout. This local gate admits it without acquiring SDKs.
    if [[ -z "${MESH_PYTHON_RESEARCH_SOURCE:-}" ]]; then
        just research-source-restore
        export MESH_PYTHON_RESEARCH_SOURCE="$PWD/.sdk-source/research"
    fi
    export MESH_PYTHON_RESEARCH_SOURCE

    # A full workspace gate otherwise leaves hundreds of incompatible
    # incremental feature graphs behind. CI already builds non-incrementally;
    # use the same bounded-disk behavior here unless explicitly overridden.
    export CARGO_INCREMENTAL="${CARGO_INCREMENTAL:-0}"
    dynamic_target_dir="${MESH_TEST_ALL_DYNAMIC_TARGET_DIR:-$PWD/target/test-all-dynamic}"

    native_backend="${LLAMA_STAGE_BACKEND:-${SKIPPY_LLAMA_BACKEND:-${LLAMA_BACKEND:-}}}"
    if [[ -z "$native_backend" ]]; then
        case "$(uname -s)" in
            Darwin) native_backend="metal" ;;
            *) native_backend="cpu" ;;
        esac
    fi
    export LLAMA_STAGE_BACKEND="$native_backend"

    if [[ -z "${LLAMA_STAGE_BUILD_DIR:-}" ]]; then
        LLAMA_STAGE_BUILD_DIR="$(scripts/build-llama.sh --print-build-dir)"
        export LLAMA_STAGE_BUILD_DIR
    fi

    echo "=== Native llama.cpp ABI ($LLAMA_STAGE_BACKEND) ==="
    echo "Build dir: $LLAMA_STAGE_BUILD_DIR"
    scripts/prepare-llama.sh
    scripts/build-llama.sh
    echo ""

    # Each UI step runs in a subshell so cd doesn't leak between steps.
    echo "=== 2/11 Rust format check ==="
    just with-lld cargo fmt --all -- --check
    echo ""
    echo "=== 3/11 GPU bench crate check ==="
    just with-lld cargo check -p skippy-gpu-bench
    echo ""
    echo "=== 4-5/11 Rust validation ==="
    # Keep Clippy and tests adjacent for each compatible feature graph. Switching
    # dynamic -> static -> dynamic -> static forces Cargo to relink both graphs.
    echo "--- Dynamic-runtime bindings: Clippy ---"
    CARGO_TARGET_DIR="$dynamic_target_dir" just with-lld cargo clippy \
        -p mesh-llm-ffi \
        -p mesh-llm-nodejs \
        -p skippy-ffi \
        -p skippy-quantize \
        --all-targets -- -D warnings
    echo "--- Dynamic-runtime bindings: tests ---"
    CARGO_TARGET_DIR="$dynamic_target_dir" just with-lld cargo test \
        -p mesh-llm-ffi \
        -p mesh-llm-nodejs \
        -p skippy-ffi \
        -p skippy-quantize
    echo "--- Static development workspace: Clippy ---"
    just with-lld cargo clippy --workspace --all-targets \
        --exclude mesh-llm-ffi \
        --exclude mesh-llm-nodejs \
        --exclude skippy-ffi \
        --exclude skippy-quantize \
        -- -D warnings
    echo "--- Static development workspace: tests ---"
    just with-lld cargo test --workspace \
        --exclude mesh-llm-ffi \
        --exclude mesh-llm-nodejs \
        --exclude skippy-ffi \
        --exclude skippy-quantize \
        --exclude skippy-package-builder \
        --exclude skippy-runtime \
        --exclude skippy-serving \
        --exclude skippy-cli
    echo "--- Static Skippy package-builder tests ---"
    just with-lld cargo test --package skippy-package-builder --no-default-features
    echo "--- Static Skippy runtime tests ---"
    just with-lld cargo test --package skippy-runtime --no-default-features --lib
    echo "--- Static Skippy server tests ---"
    just with-lld cargo test --package skippy-serving --no-default-features --lib
    echo ""
    echo "--- Static Skippy CLI tests ---"
    just with-lld cargo test --package skippy-cli --no-default-features
    echo "=== 6/11 Plugin author exemplar ==="
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) echo "--- Installed OpenAI exchange conformance is Unix-only; skipping on Windows ---" ;;
        *) just test-openai-exchange-conformance ;;
    esac
    just with-lld cargo run --quiet --manifest-path mesh/docs/plugins/exemplars/web-ui/Cargo.toml -- --print-package-manifest > target/web-ui-exemplar-manifest.json
    diff -u <(jq -S . mesh/docs/plugins/exemplars/web-ui/plugin.package.json) <(jq -S . target/web-ui-exemplar-manifest.json)
    node --check mesh/docs/plugins/exemplars/web-ui/bundle/register-mesh-plugin-ui.js
    (cd "{{ ui_dir }}" && pnpm exec tsc --ignoreConfig --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --lib ES2022,DOM ../../docs/plugins/exemplars/web-ui/bundle/register-mesh-plugin-ui.ts)
    echo ""
    echo "=== 7-10/11 Parallel portable checks and builds ==="
    scripts/test-portable.sh
    echo ""
    echo "=== 11/11 E2E smoke tests (Playwright) ==="
    (cd "{{ ui_dir }}" && pnpm run test:e2e)
    echo ""
    echo "All checks passed."

# CI

Two workflows, both on GitHub's own runners.

## Pull requests and main: `.github/workflows/ci.yml`

Every job runs commands you can run on your own machine. The pull request's own
copy of the workflow is the one that runs.

| Job | What it runs |
| --- | --- |
| Changes | `ci/simple/changes.sh`, which decides from the changed paths whether the code, console and website jobs are needed. Documentation-only changes skip all three. |
| Format and repository checks | `cargo fmt --all -- --check`, `cargo machete`, `actionlint`, and the pull request title against Conventional Commits. |
| Clippy | `cargo clippy --workspace --all-targets -- -D warnings`. |
| Tests (four shards) | `ci/simple/test-crates.sh`: `cargo test -p <crate>` for every crate, against the patched llama.cpp and two small pinned models. |
| Build and smoke | `just build`, then `ci/simple/smoke.sh`: start the built `mesh-llm` with a small model and require a real chat completion. Runs on Linux (CPU), Linux (Vulkan build), macOS (Metal) and Windows (CPU). |
| Console | `pnpm run lint`, `typecheck`, `test` and `test:e2e` in `mesh/crates/mesh-llm-ui`. |
| Website | `just cli-inventory-check`, `just website-build` and the website tests. |
| CI | Passes when every job that ran passed. This is the one required check. |

To reproduce a failure, run the command from the table. Nothing in CI depends on
state outside the checkout apart from the pinned models, which
`ci/simple/fetch-model.sh` downloads.

### What GitHub's runners cannot do

They have no GPU. The Metal build runs on the macOS runner's GPU. The Vulkan
build is compiled, started and answers on the CPU, because MeshLLM does not use
software Vulkan drivers. CUDA and ROCm are compiled and packaged by the release
workflow but are not executed anywhere in CI.

### Caches

GitHub keeps 10 GB of caches per repository. Only main saves caches; pull
requests read them. `setup-build` restores one compiler cache per job and
`save-build-cache` saves it. The test shards share one cache and the Vulkan
build reads the Linux CPU cache, so the whole set fits.

## Releases: `.github/workflows/binaries.yml`

Runs when a `v*` tag is pushed, or by hand. For each platform it runs the
release recipe (`just release-build…`), packages with `just release-bundle`,
unpacks the archive, and requires a chat completion from the packaged binary.
It then attaches every archive to a GitHub release, with `native-runtimes.json`
listing the native runtime archives MeshLLM downloads.

To release: set the version in the workspace, merge, then push the tag.

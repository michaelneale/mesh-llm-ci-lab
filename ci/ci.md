# CI

Two workflows, both on GitHub's own runners.

## Pull requests and main: `.github/workflows/ci.yml`

Every job runs commands you can run on your own machine. The pull request's own
copy of the workflow is the one that runs.

| Job | What it runs |
| --- | --- |
| Changes | `ci/simple/changes.sh`, which decides from the changed paths whether the code, console and website jobs are needed. Documentation-only changes skip all three. |
| Format and repository checks | `cargo fmt --all -- --check`, `cargo machete`, `actionlint`, a check of the client Dockerfile, and the pull request title against Conventional Commits. |
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
`save-build-cache` saves it, keeping only the objects that job used so a cache
does not grow from run to run. The test shards share one cache and the Vulkan
build reads the Linux CPU cache, so the whole set fits.

## Releases: `.github/workflows/binaries.yml`

To release, run `just release v1.2.3`. It starts the workflow, which sets that
version in the source, builds every archive, and then commits the version to
main, tags it and publishes the GitHub release. Pushing a `v*` tag whose source
already carries the version does the same.

For each platform the workflow runs the release recipe (`just release-build…`)
and packages with `just release-bundle`. Each platform produces the MeshLLM
archive, the native runtime archive MeshLLM downloads, the Skippy CLI archive
and the Node SDK addon. macOS and Linux also produce the native SDK archive and
its Rust crate. The release also carries `native-runtimes.json`, which lists the
native runtime archives. The Swift framework is not built here.

| Platform | Archives | Checked before publishing |
| --- | --- | --- |
| macOS arm64 | Metal | Unpacked, answers a chat on the GPU |
| Linux x86_64 | CPU, Vulkan, CUDA 12, CUDA 13, ROCm | CPU and Vulkan unpacked and answer a chat on the CPU |
| Linux arm64 | CPU, CUDA 12, CUDA 13 | CPU unpacked and answers a chat |
| Windows x86_64 | CPU, Vulkan, CUDA 12, CUDA 13, ROCm | CPU unpacked and answers a chat |

The CUDA and ROCm archives are compiled and packaged but never started: GitHub's
runners have no NVIDIA or AMD card. A cold CUDA or ROCm build of llama.cpp takes
two to three hours. Nothing is published unless every platform succeeds.

Packaging signs `mesh-llm` and checks the signature when the
`MESH_RELEASE_ATTESTATION_SIGNING_KEY_FILE` and
`MESH_RELEASE_ATTESTATION_PUBLIC_KEY_FILE` secrets are set. Without them the
binary is published unsigned.

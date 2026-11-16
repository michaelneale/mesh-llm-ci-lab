# Test model artifacts

Each file in `manifests/` pins the models one consumer downloads: an immutable
Hugging Face revision, the exact files, their sizes and their SHA-256 digests.

| Manifest | Read by |
| --- | --- |
| `product-smoke.json` | The build-and-smoke jobs in CI and the release workflow. |
| `skippy-correctness.json` | The test jobs in CI. |
| `hf-download-smoke.json` | `skippy-model-hf`'s download test. |
| `competitive-benchmark.json` | `skippy/docs/COMPETITIVE_BENCHMARK.md`. |

`ci/simple/fetch-model.sh <manifest> <artifact-id> <directory>` downloads one
artifact, checks its digest and prints the path. Edit a manifest by hand when a
model changes, and take the digests from the Hugging Face file listing.

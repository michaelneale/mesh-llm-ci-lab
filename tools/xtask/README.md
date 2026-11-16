# xtask

`xtask` is the small Rust command runner the build, CI and release scripts
call. It is not published. Run it from the workspace root as
`cargo xtool <domain> <command>`; `cargo xtool --help` lists the commands.

| Domain | Called by | What it does |
| --- | --- | --- |
| `artifact` | `skippy/scripts/prepare-llama.sh` | Hashes the llama.cpp inputs. |
| `native` | Native runtime and release packaging scripts | Writes and checks native runtime manifests and the system libraries a binary needs. |
| `prepared-input` | `mesh/scripts/package-native-sdk.sh` and its verify and crate scripts | Writes and checks the native SDK manifest. |
| `product` | `mesh/scripts/package-release.sh`, `.ps1` | Composes and archives the release product. |
| `release-attestation` | Release packaging | Stamps and inspects the signed release footer. |
| `repository` | `just`, the commit hook, CI | Checks commit and pull request titles; resolves Cargo's target directory. |
| `repo-consistency no-console-print` | `just no-console-print` | Forbids direct printing in product code. |

Keep it to what those callers need. CI steps belong in `just` recipes or
`ci/simple/` scripts, not here.

# Create release archive(s) for the current platform.

# `version` should be a tag like v0.30.0.
[unix]
release-bundle version output="dist" flavor="" arch="":
    @MESH_RELEASE_FLAVOR="{{ flavor }}" MESH_RELEASE_ARCH="{{ arch }}" scripts/package-release.sh "{{ version }}" "{{ output }}"

# PowerShell 7 (`pwsh`) writes zip entries with forward slashes; Windows
# PowerShell 5 writes backslashes, which other platforms' unzip tools reject.
[windows]
release-bundle version output="dist" flavor="":
    @pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/package-release.ps1 -Version "{{ version }}" -OutputDir "{{ output }}" -Flavor "{{ flavor }}"

# Run one release-attestation xtask action through the repository toolchain.
release-attestation *ARGS:
    @just with-lld cargo run -q -p xtask -- release-attestation {{ ARGS }}

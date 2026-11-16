#!/usr/bin/env bash
# Start an unpacked GPU archive on a machine that has no card. mesh-llm is told
# a matching card is there, so it loads the archive's GPU runtime; the chat
# then runs on CPU. This proves the archive is complete and its GPU libraries
# load. It does not prove the GPU code computes: that needs a real card.
#   ci/simple/smoke-no-card.sh <unpacked-archive-dir> <model.gguf>
set -euo pipefail

product="$1" model="$2"
binary="$(find "$product" -type f \( -name mesh-llm -o -name mesh-llm.exe \) | head -n 1)"
backend="$(jq -c '.runtime.backend' "$(find "$product" -name manifest.json | head -n 1)")"
kind="$(jq -r '.kind' <<<"$backend")"
case "$kind" in
cuda)
    MESH_LLM_CUDA_DRIVER_MAX_MAJOR="$(jq -r '.cuda.toolkit_major' <<<"$backend")"
    MESH_LLM_CUDA_GPU_ARCHES="$(jq -r '.cuda.gpu_arches[0] // empty' <<<"$backend")"
    export MESH_LLM_CUDA_DRIVER_MAX_MAJOR MESH_LLM_CUDA_GPU_ARCHES
    ;;
rocm)
    MESH_LLM_ROCM_GPU_ARCHES="$(jq -r '.rocm.gpu_arches[0]' <<<"$backend")"
    export MESH_LLM_ROCM_GPU_ARCHES
    ;;
vulkan) export MESH_LLM_VULKAN_AVAILABLE=1 ;;
*) echo "not a GPU archive: $backend" >&2 && exit 1 ;;
esac

# llama.cpp's GPU library: ggml-cuda, ggml-hip (ROCm) or ggml-vulkan.
SMOKE_LOADED="ggml-${kind/rocm/hip}" "$(dirname "$0")/smoke.sh" "$binary" "$model" CPU

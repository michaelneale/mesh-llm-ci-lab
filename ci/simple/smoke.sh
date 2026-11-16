#!/usr/bin/env bash
# Start the built mesh-llm with a small model and require one real chat
# completion from it over the OpenAI API.
#   ci/simple/smoke.sh <mesh-llm-binary> <model.gguf> [device]
set -euo pipefail

binary="$1" model="$2" device="${3:-CPU}"
port=9337
log="$(mktemp)"
export MESH_LLM_EPHEMERAL_KEY=1
HOME="$(mktemp -d)"
export HOME

"$binary" serve --model "$model" --no-draft --device "$device" --ctx-size 256 \
    --port "$port" --console 3131 --bind-port 47916 --bind-ip 127.0.0.1 \
    --mesh-discovery-mode mdns --headless >"$log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT

fail() {
    echo "smoke failed: $1" >&2
    grep -v "model listing" "$log" | tail -n 150 >&2
    exit 1
}

# The model is listed once it has loaded; that is the state to wait for.
for _ in $(seq 1 300); do
    kill -0 "$pid" 2>/dev/null || fail "mesh-llm exited before it was ready"
    grep -q "^startup model .* failed" "$log" && fail "the model failed to load"
    if curl -fsS "http://127.0.0.1:$port/v1/models" 2>/dev/null | jq -e '.data | length > 0' >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
[[ "${ready:-}" == 1 ]] || fail "no model was listed within 300 seconds"

name="$(curl -fsS "http://127.0.0.1:$port/v1/models" | jq -r '.data[0].id')"
request="$(jq -cn --arg model "$name" \
    '{model: $model, max_tokens: 16, messages: [{role: "user", content: "Say hello."}]}')"
reply="$(curl -fsS --max-time 120 -H 'content-type: application/json' \
    -d "$request" "http://127.0.0.1:$port/v1/chat/completions")" || fail "the chat request failed"
jq -e '.choices[0].message.content | length > 0' <<<"$reply" >/dev/null || fail "the reply was empty: $reply"
echo "smoke passed: $name replied $(jq -c '.choices[0].message.content' <<<"$reply")"

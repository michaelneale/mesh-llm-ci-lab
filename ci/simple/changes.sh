#!/usr/bin/env bash
# Decide which job groups a change needs, from the paths it touches.
#   ci/simple/changes.sh <base-sha> <head-sha>   (no arguments: everything)
# Prints code=, ui= and website= lines for $GITHUB_OUTPUT.
set -euo pipefail

if [[ $# -lt 2 ]]; then
    printf 'code=true\nui=true\nwebsite=true\n'
    exit 0
fi

files="$(git diff --name-only "$1...$2")"
has() { grep -Eq "$1" <<<"$files" && echo true || echo false; }
other() { grep -Evq "$1" <<<"$files" && echo true || echo false; }

docs='(\.md$|^docs/|^\.agents/|^\.omo/|^LICENSE$|^\.github/(ISSUE_TEMPLATE|pr-samples|pr-screenshots|assets)/)'
ui='^mesh/crates/mesh-llm-ui/'
website='^mesh/website/'

# Code is anything that is not documentation, console or website source.
code="$(other "($docs|$ui|$website)")"
echo "code=$code"
echo "ui=$(has "$ui")"
if [[ "$code" == true ]]; then echo "website=true"; else echo "website=$(has "$website")"; fi

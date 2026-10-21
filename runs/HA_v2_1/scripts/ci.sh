#!/usr/bin/env bash
#
# Build and test only what changed relative to the production artifacts, plus everything downstream
# of it, into the ci target. Unchanged upstream models are not rebuilt: with --defer, every reference
# to an unselected model resolves to its production relation (see prod-artifacts/). Exits non-zero if
# any selected model or test fails.
#
# Usage: scripts/ci.sh            (no arguments)
#
set -euo pipefail

cd "$(dirname "$0")/.."

ARTIFACTS=prod-artifacts

if [ ! -f "$ARTIFACTS/manifest.json" ]; then
    echo "ci: $ARTIFACTS/manifest.json not found. Run a production build (dbt build --target prod)" >&2
    echo "    and save target/manifest.json there before running CI." >&2
    exit 1
fi

dbt build \
    --profiles-dir . \
    --target ci \
    --select "state:modified+" \
    --state "$ARTIFACTS" \
    --defer \
    --favor-state

#!/usr/bin/env bash
#
# Pull request CI. Builds and tests only the models that changed relative to the production state in
# prod-artifacts/, plus everything downstream of them, into the ci target (F1_DBT_HC_v2_1_CI).
# Everything unchanged is read from prod through --defer, so it is never rebuilt.
#
# Usage, from the project root, with no arguments:
#   scripts/ci.sh
#
# Exits non-zero if the state is missing, or if any model, test or snapshot fails.

set -euo pipefail

if [ "$#" -ne 0 ]; then
    echo "usage: scripts/ci.sh (takes no arguments)" >&2
    exit 2
fi

cd "$(dirname "$0")/.."

STATE_DIR="prod-artifacts"
SELECTOR="state:modified+"
PROFILE_ARGS=(--profiles-dir . --target ci)

if [ ! -f "$STATE_DIR/manifest.json" ]; then
    echo "error: $STATE_DIR/manifest.json is missing. Run a production build (dbt build --target prod) and save its" >&2
    echo "       artifacts there before running CI." >&2
    exit 1
fi

echo "CI: selecting models changed relative to $STATE_DIR (plus downstream)"

# Count the nodes that would build. dbt ls prints one line per selected node, plus header and warning lines.
# Node names are plain identifiers, so only those lines are counted.
selected=$(dbt ls "${PROFILE_ARGS[@]}" --select "$SELECTOR" --state "$STATE_DIR" --output name 2>/dev/null \
    | grep -cE '^[A-Za-z0-9_]+$' || true)

if [ "$selected" -eq 0 ]; then
    echo "CI: nothing changed relative to prod. Nothing to build."
    exit 0
fi

echo "CI: $selected changed or downstream node(s). Building into the ci target, reading the rest from prod."

# The weekly full-table audit is left out of pull request runs (see tests/assert_telemetry_keys_unique_full_scan.sql).
dbt build "${PROFILE_ARGS[@]}" \
    --select "$SELECTOR" \
    --exclude "tag:weekly_full_scan" \
    --defer --state "$STATE_DIR"

echo "CI: passed."

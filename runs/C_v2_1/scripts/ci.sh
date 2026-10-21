#!/usr/bin/env bash
# Pull-request CI: build and test only what changed relative to production.
#
# Selects state:modified+ (models, seeds, snapshots and tests whose definition
# differs from prod-artifacts/manifest.json, plus everything downstream). It
# builds them into the `ci` target. Everything unchanged upstream is read from
# production through --defer, not rebuilt. Exits non-zero if any step fails.
#
# Usage (from the project root, no arguments):  scripts/ci.sh
set -euo pipefail

STATE_DIR="prod-artifacts"
TARGET="ci"
TARGET_PATH="target-ci"     # keeps CI artifacts apart from dev's target/
SELECTOR="state:modified+"
STATE_FLAGS=(--state "$STATE_DIR")
DEFER_FLAGS=(--defer --favor-state --state "$STATE_DIR")
COMMON_FLAGS=(--target "$TARGET" --target-path "$TARGET_PATH")

if [[ ! -f dbt_project.yml ]]; then
    echo "ci.sh: run from the dbt project root" >&2
    exit 2
fi
if [[ ! -f "$STATE_DIR/manifest.json" ]]; then
    echo "ci.sh: $STATE_DIR/manifest.json not found. Run a production build and save its artifacts first." >&2
    exit 2
fi

echo "==> Resolving changes relative to $STATE_DIR"
selected=$(dbt ls "${COMMON_FLAGS[@]}" "${STATE_FLAGS[@]}" --select "$SELECTOR" \
    --resource-type model --resource-type seed --resource-type snapshot \
    --output json --output-keys unique_id 2>/dev/null | grep '^{' || true)
if [[ -z "$selected" ]]; then
    echo "No models, seeds or snapshots changed relative to production. Nothing to build."
    exit 0
fi
echo "$selected" | sed -E 's/.*"unique_id": *"([^"]+)".*/    \1/'

echo "==> Resetting CI schemas"
dbt run-operation reset_ci_schemas "${COMMON_FLAGS[@]}"

# Incremental models in the selection are first created empty (schema only,
# no data scanned). Their unit tests mock `this` and need the relation to
# exist. The build below then loads them incrementally into the empty table,
# which gives the same result as a full refresh.
incremental=$(dbt ls "${COMMON_FLAGS[@]}" "${STATE_FLAGS[@]}" \
    --select "$SELECTOR,config.materialized:incremental" --resource-type model \
    --output json --output-keys unique_id 2>/dev/null | grep '^{' || true)
if [[ -n "$incremental" ]]; then
    echo "==> Creating empty incremental models"
    dbt run "${COMMON_FLAGS[@]}" "${DEFER_FLAGS[@]}" \
        --select "$SELECTOR,config.materialized:incremental" --empty
fi

echo "==> Building and testing $SELECTOR (unchanged upstream deferred to prod)"
dbt build "${COMMON_FLAGS[@]}" "${DEFER_FLAGS[@]}" --select "$SELECTOR"

echo "==> CI passed"

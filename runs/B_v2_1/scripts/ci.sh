#!/usr/bin/env bash
# CI build for pull requests. Run from the project root with no arguments:
#
#     scripts/ci.sh
#
# Builds and tests only the resources that changed relative to the production
# manifest in prod-artifacts/ (state:modified), plus everything downstream of
# them (+), into the `ci` target (schemas F1_DBT_B_v2_1_CI*). Every unchanged
# upstream model is read from production via --defer instead of being rebuilt.
# Exits non-zero if anything fails.
set -euo pipefail

cd "$(dirname "$0")/.."

STATE_DIR="prod-artifacts"
TARGET_PATH="target-ci"
COMMON=(--profiles-dir . --target ci --target-path "$TARGET_PATH")

if [[ ! -f "$STATE_DIR/manifest.json" ]]; then
    echo "ci.sh: $STATE_DIR/manifest.json not found. Refresh it from a production build (see README, CI)." >&2
    exit 2
fi

echo "==> Changed resources (state:modified+) relative to $STATE_DIR:"
dbt list "${COMMON[@]}" --select state:modified+ --state "$STATE_DIR" --quiet --output name || true

# Start from empty CI schemas, so every relation the build doesn't create
# resolves to production through --defer, never to a stale CI leftover.
echo "==> Dropping old CI schemas"
dbt run-operation "${COMMON[@]}" drop_target_schemas

echo "==> Building changed resources and their children into the ci target (deferring to prod)"
dbt build "${COMMON[@]}" \
    --select state:modified+ \
    --state "$STATE_DIR" \
    --defer

echo "==> CI build passed"

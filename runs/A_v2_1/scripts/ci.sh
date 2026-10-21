#!/usr/bin/env bash
# Slim CI: build and test only what changed relative to production, plus
# everything downstream of it, into the ci target. Unchanged upstream models
# are read from production via --defer.
#
# Usage (from the project root, no arguments):  scripts/ci.sh
# Exits non-zero if any model, test, seed or snapshot fails.
set -euo pipefail

cd "$(dirname "$0")/.."

STATE_DIR="prod-artifacts"
PROFILES_DIR="."
TARGET="ci"

if [[ ! -f "${STATE_DIR}/manifest.json" ]]; then
    echo "ci.sh: ${STATE_DIR}/manifest.json not found. Refresh production artifacts first (see README)." >&2
    exit 2
fi

echo "==> Selected (state:modified+ relative to ${STATE_DIR}):"
dbt ls --profiles-dir "${PROFILES_DIR}" --target "${TARGET}" \
    --select "state:modified+" --state "${STATE_DIR}" --resource-type model seed snapshot --output name

echo "==> Resetting ${TARGET} schemas so nothing stale is deferred to"
dbt run-operation drop_ci_schemas --profiles-dir "${PROFILES_DIR}" --target "${TARGET}"

echo "==> Building changed nodes and their dependents"
dbt build \
    --profiles-dir "${PROFILES_DIR}" \
    --target "${TARGET}" \
    --target-path target/ci \
    --select "state:modified+" \
    --state "${STATE_DIR}" \
    --defer

echo "==> CI passed"

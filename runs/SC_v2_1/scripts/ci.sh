#!/usr/bin/env bash
# Slim CI: build and test only what changed relative to the last production run
# (prod-artifacts/manifest.json), plus everything downstream, into the `ci` target
# (schema F1_DBT_SC_v2_1_CI). Unchanged upstream models are read from prod through
# deferral (--defer --favor-state), never rebuilt. Exits non-zero if anything fails.
#
# Usage (from the project root, no arguments):   scripts/ci.sh
# Override the state directory with STATE_DIR, the target with CI_TARGET if needed.
set -euo pipefail

cd "$(dirname "$0")/.."

STATE_DIR="${STATE_DIR:-prod-artifacts}"
CI_TARGET="${CI_TARGET:-ci}"

if [[ ! -f "${STATE_DIR}/manifest.json" ]]; then
  echo "ci.sh: ${STATE_DIR}/manifest.json not found. Run a full production build and copy" >&2
  echo "       target/manifest.json (and run_results.json) into ${STATE_DIR}/ first." >&2
  exit 2
fi

selector="state:modified+"

echo "== Changed nodes and everything downstream (vs ${STATE_DIR}) =="
selected="$(dbt ls --target "${CI_TARGET}" --select "${selector}" --state "${STATE_DIR}" \
  --resource-type model seed snapshot test unit_test --quiet)"
if [[ -z "${selected}" ]]; then
  echo "Nothing changed relative to ${STATE_DIR}; nothing to build."
  exit 0
fi
echo "${selected}"
echo

echo "== Building into target '${CI_TARGET}' (unchanged upstream deferred to prod) =="
dbt build \
  --target "${CI_TARGET}" \
  --select "${selector}" \
  --state "${STATE_DIR}" \
  --defer \
  --favor-state

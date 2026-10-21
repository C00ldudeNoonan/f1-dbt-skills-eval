#!/usr/bin/env bash
# Pull request CI: build and test only what changed relative to the production artifacts, plus everything
# downstream, into the `ci` target. Unchanged upstream models are read from prod (deferral), not rebuilt.
#
# Usage (from the project root, no arguments):  scripts/ci.sh
# Exits non-zero if the build or any test fails. Requires prod-artifacts/manifest.json (see README).
set -euo pipefail

cd "$(dirname "$0")/.."

STATE_DIR="prod-artifacts"
DBT="${DBT:-dbt}"

if [[ ! -f "${STATE_DIR}/manifest.json" ]]; then
  echo "ERROR: ${STATE_DIR}/manifest.json not found. Run scripts/prod_build.sh (or copy the artifacts of the latest prod build) first." >&2
  exit 2
fi

# "Modified" = changed SQL/body, config, contract or macros. state:modified.relation is deliberately excluded:
# the artifacts were built against the prod schemas and CI builds into its own, so every node's relation
# differs and it would flag the whole project as changed.
SELECTION="state:modified.body+ state:modified.configs+ state:modified.contract+ state:modified.macros+ state:new+"

echo "==> Changed models relative to ${STATE_DIR} (plus downstream):"
"${DBT}" ls --target ci --profiles-dir . --select ${SELECTION} --state "${STATE_DIR}" || true

echo "==> Building and testing into the ci target; unchanged upstream models are deferred to prod"
"${DBT}" build \
  --target ci \
  --profiles-dir . \
  --select ${SELECTION} \
  --state "${STATE_DIR}" \
  --defer \
  --favor-state

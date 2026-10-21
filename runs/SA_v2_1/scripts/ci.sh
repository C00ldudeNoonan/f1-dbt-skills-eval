#!/usr/bin/env bash
# Slim CI: build and test only what changed relative to the production artifacts, plus everything
# downstream of it, into the `ci` target. Unchanged upstream models are read from prod (--defer),
# not rebuilt. Run from the project root with no arguments; exits non-zero on any failure.
set -euo pipefail

cd "$(dirname "$0")/.."

STATE_DIR="prod-artifacts"
PROFILES=(--profiles-dir .)

if [[ ! -f "${STATE_DIR}/manifest.json" ]]; then
    echo "ci.sh: ${STATE_DIR}/manifest.json is missing. Build prod first and refresh the artifacts:" >&2
    echo "       dbt build --target prod --profiles-dir . && cp target/manifest.json ${STATE_DIR}/" >&2
    exit 2
fi

echo "==> Resetting the CI schema"
dbt run-operation reset_ci_schema --target ci "${PROFILES[@]}"

echo "==> Changed nodes (vs ${STATE_DIR}) and everything downstream:"
dbt ls --target ci "${PROFILES[@]}" --select "state:modified+" --state "${STATE_DIR}" --output name || true

echo "==> Building and testing into the ci target (unchanged parents deferred to prod)"
# --defer + --state: refs to models that are not selected resolve to the prod relations.
# --favor-state: always use prod for unselected parents even if a copy exists in the CI schema.
# Unit tests on incremental models need the model to exist already (dbt Fusion types them from the
# built relation), so they are tagged `needs_built_model`, left out of the build and run right after.
dbt build --target ci "${PROFILES[@]}" \
    --select "state:modified+" \
    --exclude "tag:needs_built_model" \
    --defer --favor-state --state "${STATE_DIR}"

echo "==> Unit tests for modified incremental models (built above)"
dbt test --target ci "${PROFILES[@]}" \
    --select "state:modified+,tag:needs_built_model" \
    --defer --favor-state --state "${STATE_DIR}"

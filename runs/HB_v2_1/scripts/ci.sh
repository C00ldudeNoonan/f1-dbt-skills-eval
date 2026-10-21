#!/usr/bin/env bash
#
# Pull request build. Builds and tests only what changed relative to the production baseline,
# plus everything downstream of it, into the ci target. Unchanged upstream models are read from
# prod (deferred), not rebuilt. Takes no arguments; run it from anywhere. Exits non-zero if any
# step fails.
#
# Baseline: prod-artifacts/manifest.json, saved from a full production build (see README).
#
# Three steps, in this order, because dbt runs a unit test before the model it tests. In a fresh
# schema an incremental model has no table yet, so its unit tests need the model built first:
#   1. seeds and snapshots  2. models  3. tests (including unit tests)
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

state_dir="prod-artifacts"
if [[ ! -f "$state_dir/manifest.json" ]]; then
    echo "ci.sh: no baseline at $state_dir/manifest.json. Run a full prod build and save its artifacts (see README)." >&2
    exit 1
fi

selector="state:modified+"
common=(--profiles-dir . --target ci --select "$selector"
        --defer --favor-state --state "$state_dir")

echo "ci.sh: changed selection ($selector against $state_dir)"
dbt ls --profiles-dir . --target ci --select "$selector" --state "$state_dir" --output name

echo "ci.sh: step 1 of 3, seeds and snapshots"
dbt build "${common[@]}" --resource-type seed --resource-type snapshot

echo "ci.sh: step 2 of 3, models"
dbt run "${common[@]}"

# Reconciliation checks scan whole tables. They run on a schedule, not per pull request.
echo "ci.sh: step 3 of 3, tests"
dbt test "${common[@]}" --exclude tag:reconciliation
echo "ci.sh: done"

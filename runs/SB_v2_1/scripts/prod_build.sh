#!/usr/bin/env bash
# Full production build, then refresh prod-artifacts/ (the state CI compares against).
# Run from the project root on the main branch after merging:  scripts/prod_build.sh
# Commit the updated prod-artifacts/ together with (or right after) the merge.
set -euo pipefail

cd "$(dirname "$0")/.."
DBT="${DBT:-dbt}"

"${DBT}" build --target prod --profiles-dir .

mkdir -p prod-artifacts
cp target/manifest.json target/run_results.json prod-artifacts/
[[ -f target/semantic_manifest.json ]] && cp target/semantic_manifest.json prod-artifacts/
echo "Refreshed prod-artifacts/ from target/"

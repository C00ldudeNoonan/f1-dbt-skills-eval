#!/usr/bin/env bash
# Production build. Builds the whole project into the `prod` target and
# refreshes prod-artifacts/, the comparison point for scripts/ci.sh. Run it
# after every merge to main and commit the updated prod-artifacts/.
#
# Usage (from the project root):  scripts/prod.sh
set -euo pipefail

TARGET_PATH="target-prod"
[[ -f dbt_project.yml ]] || { echo "prod.sh: run from the dbt project root" >&2; exit 2; }

# Create any incremental model that doesn't exist yet as an empty table
# (schema only). Their unit tests mock `this` and need the relation. On
# existing tables this inserts nothing.
dbt run --target prod --target-path "$TARGET_PATH" --select config.materialized:incremental --empty

dbt build --target prod --target-path "$TARGET_PATH"

mkdir -p prod-artifacts
cp "$TARGET_PATH/manifest.json" "$TARGET_PATH/run_results.json" prod-artifacts/
[[ -f "$TARGET_PATH/semantic_manifest.json" ]] && cp "$TARGET_PATH/semantic_manifest.json" prod-artifacts/
echo "Production built; prod-artifacts/ refreshed. Commit it."

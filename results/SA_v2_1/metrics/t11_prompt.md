We're setting up CI so pull requests don't rebuild the whole project.

1. Add a `prod` target to `profiles.yml` that builds into `F1_DBT_SA_v2_1_PROD` (custom schema suffixes allowed) and a `ci` target that builds into `F1_DBT_SA_v2_1_CI`. Keep `dev` as the default target.
2. Run a full production build now so prod is current, and save its artifacts in `prod-artifacts/` in the repo.
3. Write `scripts/ci.sh`. Run from the project root with no arguments, it must build and test only the models that changed relative to `prod-artifacts/`, plus everything downstream of them, into the `ci` target. Unchanged upstream models must be read from prod, not rebuilt. It must exit non-zero if anything fails.

Make sure `dbt build` still succeeds on dev, and document how CI works in the project README.

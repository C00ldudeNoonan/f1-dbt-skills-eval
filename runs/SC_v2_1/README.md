# F1 analytics dbt project

Builds Formula 1 facts, dimensions and marts from the raw Ergast/Kaggle tables in
`ANALYTICS_DEV.F1_RAW_SC_V2_1` (read-only) into `F1_DBT_SC_v2_1`.

```
models/
  staging/f1/      1:1 with raw tables: typing, \N -> null, time text -> ms (views, *_staging schema)
  intermediate/    shared logic reused by marts, e.g. season completeness (views)
  marts/           public contracts, enforced column names and types (tables)
macros/            clean_raw, time_text_to_ms
seeds/             ref_world_champions: real-world history used only by tests
tests/             generic tests + singular business-rule tests
```

Run: `dbt build --profiles-dir .`

## Conventions
- Raw columns are text and nulls are `\N` (sometimes `''`); only staging touches raw.
- Marts have enforced contracts. Renaming or retyping a column is a breaking change: version the model.
- Season "complete" = every race on the calendar has results (`int_f1__season_status`).
- Standings come from the raw standings snapshot at the latest completed round, not from summed race points.

## Vendor schema changes
The raw feed is guarded at the source: `dbt test --select source:f1_raw` (also part of `dbt build`,
and it runs before any model that depends on the table). `source_columns_missing` errors when a
column or table we rely on is renamed or dropped, `source_columns_added` warns about new columns,
and `matches_regex` pins the text formats staging parses (dates, times, numerics). Renamed raw
tables are mapped with `identifier:` in `_f1__sources.yml`; renamed columns are fixed in staging only.
Note: `adapter.get_columns_in_relation` can return a stale cached schema on dbt 2.x; the source tests use a live `DESCRIBE`.

## Raw data quality gates
Source tests run before any model that reads the table, so bad vendor data stops the build
instead of reaching a dashboard: duplicate keys (`duplicate_key_rows`, warn; staging
de-duplicates), duplicates that disagree (`no_conflicting_duplicates`, error), untrimmed text
(warn), plausible numeric ranges (`values_between`), and formats. `assert_facts_conserve_staging_rows`
checks that marts neither drop nor fan out rows. Known benign quirks: red-flag laps up to ~2h
and odd pit `stop` numbers (Monaco 2024) are inside the allowed ranges.

## Public interfaces (group `f1_analytics`)
`fct_results` and `dim_drivers` are `access: public` with enforced contracts; everything else is
protected. `dim_drivers` is versioned: v2 (latest) has `first_name`/`last_name`; v1 (`full_name`)
is deprecated 2027-01-01 and builds as `dim_drivers_v1`. The unsuffixed `dim_drivers` view always
points at the latest version. Pin with `ref('dim_drivers', v=1)`. Both versions are thin selects over
`int_f1__driver_profiles`, so they never differ in numbers, and both carry placeholder drivers.

## Semantic layer
Metrics (all Grand Prix only): `race_starts`, `wins`, `podiums`, `championship_points`, `podium_rate`,
`points_per_start`, defined on `fct_results` (latest-spec YAML in `models/marts/_marts__models.yml`).
`dim_drivers` (latest version only) supplies `driver__nationality`; `time_spine_daily` (1949-2039)
powers `metric_time`. Example queries (`mf query` locally, `dbt sl query` on the dbt platform):

    dbt sl query --metrics wins,podiums,race_starts --group-by driver__nationality --where "{{ Dimension('result__season') }} = 2023"
    dbt sl query --metrics championship_points,points_per_start --group-by result__constructor_name --where "{{ Dimension('result__season') }} = 2023" --order -championship_points
    dbt sl query --metrics wins,podium_rate --group-by metric_time__year,driver__nationality
    dbt sl query --metrics podium_rate --group-by driver__driver_ref --where "{{ Dimension('result__season') }} >= 2020"

## Vendor B cross-check
`dim_session_crosswalk` and `dim_driver_crosswalk` map Vendor B ids to ours automatically (sessions by
date, then venue; drivers by results fingerprint plus name/code evidence; see model comments). Anything
unmatched/ambiguous gets a null id and fails `not_null`/`unique` tests; fix it by adding a row to
`ref_vendor_b_session_overrides` / `ref_vendor_b_driver_overrides` (normally empty).
`mart_vendor_result_discrepancies` lists points/position/missing differences; our feed is the system of record.

## Telemetry (cost-aware)
`fct_telemetry` / `mart_lap_telemetry_summary` are incremental by `_loaded_at` (landing time), reloading only
races that received rows since the watermark (minus `telemetry_lookback_hours`), so late samples for old races
are picked up. No row-level tests on the raw source; model tests look at the latest batch only
(`--vars '{full_telemetry_tests: true}'` for a full check). A correction that changes old rows without a new
delivery needs `--full-refresh` of `fct_telemetry+`.

## Targets and slim CI
| target | schema | use |
|---|---|---|
| `dev` (default) | `F1_DBT_SC_v2_1` | local development |
| `prod` | `F1_DBT_SC_v2_1_PROD` | production builds (`dbt build --target prod`) |
| `ci` | `F1_DBT_SC_v2_1_CI` | pull-request checks (`scripts/ci.sh`) |

(Layers add suffixes: `_STAGING`, `_INTERMEDIATE`, `_SNAPSHOTS`, `_REFERENCE`.) The raw schema is read-only for every target.

**How CI works.** `prod-artifacts/` holds the `manifest.json` / `run_results.json` of the last production build.
`scripts/ci.sh` (run from the project root, no arguments) selects `state:modified+` against that manifest, i.e. every
model, seed, snapshot, test and unit test that changed plus everything downstream, and runs
`dbt build --target ci --defer --favor-state --state prod-artifacts`. Unchanged upstream models are not rebuilt:
deferral makes `ref()` read them from the PROD schema. If nothing changed it exits 0 without building; any build or
test failure (or a parse error) exits non-zero.

**After every production build, refresh the baseline:**
`cp target/manifest.json target/run_results.json prod-artifacts/` and commit it. A stale baseline makes CI rebuild
more than necessary (never less: changes are always detected relative to the baseline).

Gotchas: a modified *incremental* model builds from scratch in the CI schema (e.g. `fct_telemetry` is a 20M-row load);
the prod snapshot history starts at the first prod run; unit tests on incremental models set
`overrides: macros: is_incremental: false` so they also pass on a fresh schema.

## Analysis
`docs/analysis/leadership-questions.md` answers "which drivers overperform their car" (`mart_driver_teammate_performance`) and
"are pit stops getting faster" (`mart_pit_stop_trend_by_season`, `mart_pit_stop_trend_summary`), with definitions and caveats.

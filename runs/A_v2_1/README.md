# F1 analytics dbt project

Formula 1 models built from the Ergast / Kaggle CSV extract in Snowflake.

- Source (read-only): `ANALYTICS_DEV.F1_RAW_A_v2_1`, 14 all-text tables.
- Targets: marts in `F1_DBT_A_v2_1`; staging, intermediate and seeds in
  `F1_DBT_A_v2_1_STAGING`, `_INTERMEDIATE` and `_REFERENCE`.

```bash
dbt build --profiles-dir .
```

## Public interfaces (for other dbt projects)

All models belong to the `f1_analytics` group (owner: F1 Analytics Engineering)
and are `protected` by default. Only these are `public`, with enforced contracts
(column names, types and not-null constraints are checked on every build):

| Model | Version | Relation | Status |
|---|---|---|---|
| `fct_results` | (unversioned) | `FCT_RESULTS` | current |
| `dim_drivers` | **2 (latest)** | `DIM_DRIVERS_V2` | current: `first_name`, `last_name` |
| `dim_drivers` | 1 | `DIM_DRIVERS` | **deprecated 2027-01-01**: `forename`, `surname`, `full_name` |
| | pointer | `DIM_DRIVERS_LATEST` (view) | always the latest version |

From another project (with this one as a dependency):

```sql
select * from {{ ref('f1', 'fct_results') }}
select * from {{ ref('f1', 'dim_drivers') }}         -- latest (v2)
select * from {{ ref('f1', 'dim_drivers', v=2) }}    -- pin v2 (recommended)
select * from {{ ref('f1', 'dim_drivers', v=1) }}    -- old shape, warns: deprecated
```

`dim_drivers` v1 → v2 migration: replace `full_name` with
`first_name || ' ' || last_name`; replace `forename`/`surname` with
`first_name`/`last_name`. Every other column is identical in name, type, order
and value. Placeholder rows (`is_placeholder = true`, a driver whose record
hasn't arrived yet) have `first_name = 'Unknown'` and `last_name = 'Driver <id>'`
in v2 (never null), versus null forename/surname and
`full_name = 'Unknown driver <id>'` in v1. Filter on `is_placeholder` rather
than on names.

Anything not listed here (staging, intermediate, the other marts) is protected:
other projects can't `ref` it and it may change without a version bump.

## Semantic Layer (self-serve metrics)

Defined with the new model-level spec (in the model YAML files):

| Semantic model | Built on | Entity (primary) | Dimensions |
|---|---|---|---|
| `results` | `fct_results` | `result` (foreign: `driver`, `constructor`, `race`) | `race_date` (time, day), `season`, `round`, `race_name`, `status`, `is_classified` |
| `drivers` | `dim_drivers` v2 | `driver` | `driver_ref`, `first_name`, `last_name`, `nationality`, `driver_code`, `is_placeholder` |
| `constructors` | `dim_constructors` | `constructor` | `constructor_ref`, `constructor_name`, `nationality` |

Metrics (Grand Prix results only; default time dimension `race_date`):

| Metric | Definition |
|---|---|
| `race_starts` | count of result entries (every entry, including DNQs) |
| `wins` | entries with finish_position 1 |
| `podiums` | entries with finish_position 1–3 |
| `championship_points` | sum of Grand Prix points as awarded (no sprints, no dropped scores) |
| `podium_rate` | `podiums / race_starts` |
| `points_per_start` | `championship_points / race_starts` |

`metricflow_time_spine` (daily, 1950–2049) lets metrics be grouped by
`metric_time` at day/week/month/quarter/year. `championship_points` is not the
official championship total (sprints and dropped scores); use
`mart_driver_season_standings` for official standings.

Example queries (dbt Cloud CLI or Fusion with a dbt Cloud project; `dbt sl query`):

```bash
dbt sl query --metrics wins,podiums,race_starts --group-by constructor__constructor_name --where "{{ Dimension('result__season') }} = 2023" --order-by -wins
```

```bash
dbt sl query --metrics podium_rate,points_per_start,race_starts --group-by driver__nationality --order-by -podium_rate
```

```bash
dbt sl query --metrics wins,championship_points --group-by metric_time__year --where "{{ Dimension('driver__driver_ref') }} = 'max_verstappen'" --order-by metric_time__year
```

```bash
dbt sl query --metrics championship_points,points_per_start --group-by result__season,driver__last_name --where "{{ Dimension('result__season') }} >= 2020" --order-by -championship_points --limit 20
```

```bash
dbt sl query --metrics wins --group-by metric_time__month,constructor__constructor_name --start-time 2024-01-01 --end-time 2024-12-31
```

## Vendor B cross-check feed

`VB_DRIVERS`, `VB_SESSIONS`, `VB_RESULTS` (2018 onwards) share no ids with the
primary feed. Mapping is automatic and re-evaluated on every run:

- **`dim_session_crosswalk`**: same season and session type, Vendor B
  `meeting_name` = our circuit `location` (case- and accent-insensitive), nearest
  date within `var('vendor_b_session_date_tolerance_days')` (2). Same-venue
  double-headers resolve by date; a renamed venue still matches on an exact date.
- **`dim_driver_crosswalk`**: candidates are only our drivers who raced in the
  same sessions. Each is scored on grid agreement (share of the vendor driver's
  entries with the same grid slot), three-letter code and surname (0–1 each, max
  3). Accepted with score ≥ 2 and a margin ≥ 1 over the runner-up. Codes alone
  are never trusted (Michael and Mick Schumacher are both `MSC`).
- **Overrides**: `seeds/vendor_b_driver_overrides.csv` and
  `seeds/vendor_b_session_overrides.csv`, only for genuinely ambiguous cases.
  Both are empty today.
- **Fails loudly**: an unmatched or ambiguous driver or session gets a null id,
  and `every_vendor_b_driver_is_matched` / `every_vendor_b_session_is_matched`
  fail the build and name it. The discrepancy mart is skipped rather than built
  on bad mappings. One-to-one tests stop two vendor ids mapping to one of ours.
  A warn test flags automatic driver matches made on partial evidence.
- **`mart_vendor_result_discrepancies`**: every season Vendor B covers from
  2018; one row per entry per `points` / `position` / `missing_in_vendor_b` /
  `missing_in_vendor_a`. Our feed is the system of record.

## Telemetry (cost-aware incremental design)

`CAR_TELEMETRY` (~20M rows, 2022+, ~4 samples/s/car) is append-only and samples
can land weeks after the race, so everything is keyed on **arrival**
(`_LOADED_AT`), never on race date:

- **`fct_telemetry`**: incremental merge on `(race_id, driver_id, lap,
  sample_index)`. Each run reads raw rows with `loaded_at` above the table's own
  high-water mark minus `var('telemetry_lookback_hours')` (3 h, for loads that
  commit out of order). Late samples for old races are picked up by arrival; a
  re-sent sample replaces its earlier copy. Clustered by `race_id`.
- **`mart_lap_telemetry_summary`**: laps touched since its own high-water mark
  are found from the same narrow raw slice, recomputed in full from
  `fct_telemetry` (pruned by `race_id`) and merged. Figures stay exact without
  full refreshes, because a touched lap is always re-aggregated from all its samples.
- **Tests stay cheap**: the fact's key test only checks the last
  `var('telemetry_test_window_days')` (14) days of loads.
  `tests/assert_lap_summary_matches_fact.sql` compares the summary with a
  from-scratch aggregation for every recently touched race.

Measured on the 20M-row table:

| Run | fct_telemetry | lap summary |
|---|---|---|
| Full rebuild | 716 MB scanned, 4.7 s | 350 MB, 6.6 s |
| Routine, nothing new | ~40–50 MB, ~1.5 s | ~30 MB, ~1 s |
| Routine, late samples for a 2022 race | ~60 MB, 1.6 s | ~145 MB, 0.8 s |

The routine floor is the 3-hour lookback, which re-reads the most recent load
(about one race) plus the merge's key lookup on the target. It grows with what
arrived, not with history. A full refresh is never needed for correctness; use
`--full-refresh -s fct_telemetry+` only after changing the models' logic.

## Environments and CI

| Target | Schema (custom suffixes appended, e.g. `_STAGING`) | Use |
|---|---|---|
| `dev` (default) | `F1_DBT_A_v2_1` | local development |
| `prod` | `F1_DBT_A_v2_1_PROD` | the deployed project |
| `ci` | `F1_DBT_A_v2_1_CI` | pull-request checks |

**Production deploy** (refreshes the CI baseline):

```bash
dbt build --profiles-dir . --target prod --target-path target/prod
```

```bash
cp target/prod/manifest.json target/prod/run_results.json target/prod/semantic_manifest.json prod-artifacts/
```

Commit `prod-artifacts/` with the deploy, so CI always compares against what is
actually in production.

**CI** (`scripts/ci.sh`, run from the project root, no arguments):

1. Lists the nodes selected by `state:modified+` against `prod-artifacts/`: any
   model, seed, snapshot, macro, test or config that differs from production,
   plus everything downstream of it.
2. Drops every `F1_DBT_A_v2_1_CI*` schema (`drop_ci_schemas`, which refuses to
   run on any other target), so each run starts clean and nothing stale can be
   deferred to.
3. Runs `dbt build --target ci --select state:modified+ --state prod-artifacts --defer`.
   Selected nodes are built and tested in the CI schemas; every unselected
   upstream `ref` resolves to the production relation, so unchanged models are
   read from prod, not rebuilt.
4. Exits non-zero if any model, test (data or unit), seed or snapshot fails
   (`set -euo pipefail`; dbt's exit code propagates).

With no changes it builds nothing and passes. Changing `fct_qualifying`, for
example, builds only `fct_qualifying` and `mart_teammate_head_to_head` (plus
their tests), reading `stg_ergast__*` and `fct_results` from `F1_DBT_A_v2_1_PROD*`.
Changed incremental models build from scratch in CI, because the CI schemas
start empty.

## Analyses

Answers to leadership questions, with method, assumptions and limitations:
[docs/leadership_questions.md](docs/leadership_questions.md).

- `mart_driver_vs_car`: same-car (teammate) pace per driver, adjusted for
  teammate strength by a weighted least-squares fit over the teammate
  network (`int_driver_network_ratings`, a Python/Snowpark model), with 95%
  intervals and an `is_trusted_overperformer` flag.
- `mart_pit_stop_trend`: pit-lane time per season compared with each
  circuit's own norm, with 95% intervals.

## Layout

| Layer | Path | Materialization | Purpose |
|---|---|---|---|
| Staging | `models/staging/ergast` | view | One model per source table. Nulls the `\N` sentinel, casts types, snake_case names. No business logic beyond parsing. |
| Intermediate | `models/intermediate` | view | Shared logic reused by marts (season completeness). |
| Marts | `models/marts/{core,standings,performance}` | table | The public contract other teams build on. |
| Seeds | `seeds/` | table | Hand-maintained reference data for reconciliation tests. |

Marts read only from staging, intermediate or other marts, never from sources.

## Public models

| Model | Grain |
|---|---|
| `fct_results` | Grand Prix result entry (`result_id`), sprints excluded |
| `fct_session_results` | Result entry across Grand Prix and sprint sessions (`session_type`, `source_result_id`) |
| `dim_drivers` | Driver |
| `fct_qualifying` | Qualifying entry (`qualify_id`) |
| `mart_driver_standings_by_round` | Driver × round in the official standings |
| `mart_driver_season_standings` | Driver × season, as of latest completed round (derived from by-round) |
| `mart_alt_points_standings` | Points system × season × driver, what-if re-scoring |
| `mart_constructor_season_pit_stops` | Constructor × season with pit data |
| `mart_teammate_head_to_head` | Season × constructor × driver × teammate (both orderings) |
| `fct_driver_race_pace` | Driver × race with lap data and ≥1 green-flag lap |
| `fct_lap_times` | Driver × race × lap (incremental) |
| `fct_stints` | Driver × race × stint, races with pit data (incremental) |
| `snp_drivers` | Driver × version (type 2 snapshot, schema `_SNAPSHOTS`) |
| `audit_orphan_driver_results` | Result whose driver record hasn't arrived (live view) |
| `audit_raw_schema_drift` | Difference between the raw schema and the agreed contract (live view) |
| `audit_raw_duplicates` | Duplicate and conflicting rows per raw table, by natural key (live view) |

Column definitions live in the YAML next to each model (`dbt docs generate` to browse).

## Key rules

- **Season complete**: every race on the season calendar has results
  (`int_seasons__completion`). Titles only count for complete seasons.
- **Standings** come from the published `DRIVER_STANDINGS` snapshot at the latest
  completed round, not from summing race points. Official totals use era rules
  (dropped scores before 1991, shared drives, half points, sprint points from
  2021) that results alone don't reproduce. `tests/assert_champions_match_official_history.sql`
  reconciles every completed season's champion and points to `seeds/known_world_champions.csv`.
- **finish_position** comes from `positiontext` (digits only), so null means not classified.
- **Pit stops over 60 s** are excluded (`var('pit_stop_max_seconds')`).
- **Green-flag laps** exclude lap 1, the pit lap, the lap after it, and laps over
  130% of the race's fastest lap (`var('green_lap_max_ratio')`).

## What-if points systems

`mart_alt_points_standings` re-scores every season under each system in
`seeds/points_systems.csv` (`points_system, position, points`). To add a system,
add its rows (unlisted positions score 0) and run `dbt build`; no SQL changes.
Rules are fixed for all systems: Grand Prix only, classified finishers by
`position_order`, each entry scores separately, ties broken by countback
(`var('alt_points_countback_depth')` = 10) then lowest `driver_id`. Filter on
`points_system` for one row per driver per season.

## Incremental lap models

- `fct_lap_times` is `delete+insert` by `race_id`. Each run loads races it doesn't
  have yet and reloads the `var('lap_correction_window_races')` (2) most recent
  races already loaded, so corrected lap times flow through. Whole races are
  replaced, so withdrawn laps disappear too. `dbt_updated_at` stamps each reload.
- `fct_stints` is also `delete+insert` by `race_id`. It rebuilds every race whose
  `fct_lap_times.dbt_updated_at` is newer than its own `source_updated_at`
  watermark, plus races with pit data but no stints yet.
- `tests/assert_lap_times_match_source.sql` fails if the fact drifts from staging,
  for example a correction to a race older than the window. Fix with
  `dbt build --full-refresh -s fct_lap_times+`.

## Driver history and late-arriving drivers

- `snp_drivers` (`snapshots/snp_drivers.yml`) is a check-strategy snapshot of
  `stg_ergast__drivers` on all columns. `dbt build` runs it, so every run records
  changes to numbers, codes or names. History begins with the first run.
- `dim_drivers` is built on `int_drivers__spine`: every real driver plus any
  driver_id seen in results, sprints, qualifying or standings without a DRIVERS
  record. Those rows have `is_placeholder = true`, `full_name = 'Unknown driver <id>'`
  and real career stats, and take real values on the next run after the record
  lands. Facts never join to drivers, so orphan results are never dropped.
- `select count(*) from audit_orphan_driver_results` gives the live orphan count.
  The `warn_orphan_driver_results_exist` test warns on every build while any exist.

## Vendor contract guards

The vendor can rename, drop or reformat raw data without warning (it did in
October 2026: `LAP_TIMES` → `LAP_TIMING`, `POSITIONORDER` → `POSITION_ORDER`,
`PIT_STOPS.DURATION` dropped, `RACES.DATE` → `DD/MM/YYYY`, missing qualifying
times `\N` → empty string). Every raw table now has three source tests that run
first in `dbt build`:

| Test | Severity | Catches |
|---|---|---|
| `raw_<table>__no_missing_columns` | error | a column in `seeds/raw_schema_contract.csv` is gone (renamed/dropped column or table) |
| `raw_<table>__no_unexpected_columns` | warn | the vendor added or renamed a column |
| `raw_<table>__values_parse` | error | a present value no longer parses with the staging parser (format change) |
| `raw_<table>__no_conflicting_duplicates` | error | a natural key arrives with copies whose cleaned values disagree |
| `raw_<table>__no_duplicate_rows` | warn | the feed sent identical copies of a row (staging collapses them) |

Staging keeps exactly one row per natural key (`dedupe_on`), so a duplicated
raw row can never fan out a join. In October 2026 a second copy of Ferrari's
`CONSTRUCTORS` row (differing only by a trailing space) doubled every Ferrari
result. Duplicates are compared on cleaned values (`raw_row_hash`), the way
staging sees them.

`tests/assert_constructor_totals_match_official_standings.sql` independently
reconciles summed race and sprint points and wins per constructor season (1979
onwards) with the published constructor standings, so any inflated team total
fails with the team and season named. Documented FIA exceptions live in
`seeds/constructor_points_exceptions.csv`.

Run production with `dbt build`, not `dbt run`: the source and staging tests are
what stop bad data before the marts are replaced.

A failing guard **skips** the staging models on that table and everything
downstream, so yesterday's tables stay in place instead of being overwritten with
nulls. `select * from audit_raw_schema_drift` lists layout differences at any time.

Parsing lives in macros shared by staging and `values_parse` (`to_int`,
`to_decimal`, `to_date`, `to_time`, `duration_to_ms`), so a passing guard means
staging loses nothing. Accepted date formats are `var('raw_date_formats')`.

When the vendor changes something on purpose: fix staging, add the format to
`raw_date_formats` if relevant, regenerate the affected rows of
`raw_schema_contract.csv`, then compare the marts before and after (see the
October 2026 commit for a worked example). `var('raw_schema')` points the
sources at another schema, for example a Time Travel clone of the raw data.

## Maintaining

- When a season finishes, add its champion to `seeds/known_world_champions.csv`.
- New raw tables: add to `_ergast__sources.yml` and create a `stg_ergast__*` model.
- Tests: generic tests in YAML, custom generics in `macros/tests`, reconciliation
  tests in `tests/`, unit tests for the trickiest logic next to the marts.

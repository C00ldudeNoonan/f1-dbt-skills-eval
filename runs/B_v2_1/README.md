# F1 analytics dbt project

Models the Ergast / Kaggle Formula 1 dataset (`ANALYTICS_DEV.F1_RAW_B_v2_1`,
read-only) into `ANALYTICS_DEV.F1_DBT_B_v2_1_*` on Snowflake.

```bash
dbt build --profiles-dir .
```

## Environments and CI

| Target | Schemas | Used for |
|---|---|---|
| `dev` (default) | `F1_DBT_B_v2_1_*` | local development: `dbt build --profiles-dir .` |
| `prod` | `F1_DBT_B_v2_1_PROD_*` | scheduled production builds |
| `ci` | `F1_DBT_B_v2_1_CI_*` | pull-request builds via `scripts/ci.sh` |

**Production build** (refresh `prod-artifacts/` afterwards and commit it):

```bash
dbt build --profiles-dir . --target prod --target-path target-prod
```

```bash
cp target-prod/manifest.json target-prod/run_results.json target-prod/semantic_manifest.json prod-artifacts/
```

**CI** (`scripts/ci.sh`, run from the project root with no arguments):

1. Lists what changed: `state:modified+` compares the project with
   `prod-artifacts/manifest.json`, covering SQL, YAML config, tests, seeds and
   macros, plus everything downstream (`+`).
2. Drops all `F1_DBT_B_v2_1_CI*` schemas (`drop_target_schemas` macro, which
   refuses to run for any target other than `ci`). Every relation the build
   doesn't create then resolves to prod, never to a stale CI leftover.
3. Runs `dbt build --select state:modified+ --state prod-artifacts --defer`
   into the `ci` target. Changed models and their children (with their tests
   and unit tests) are built in CI schemas. Every unchanged parent is read from
   `F1_DBT_B_v2_1_PROD_*`, not rebuilt.
4. Exits non-zero if any model, test or unit test fails (`set -euo pipefail`,
   and dbt's exit code). No changes means nothing is selected, and it exits 0.

Verified on 2026-10-21:
- No changes: nothing was built, and it exited 0.
- A one-line change to `fct_qualifying`: only that model, its 9 tests and its
  unit test ran, and it read `F1_DBT_B_v2_1_PROD_staging.stg_ergast__qualifying`.
- A deliberately broken change: it exited 1 on the failing unit test.

Things to know:
- `prod-artifacts/` must match what's deployed. Refresh it after every
  production build, or CI compares against an old baseline and builds more
  than it needs to.
- A changed incremental model (e.g. the telemetry models) builds from scratch
  in CI, because CI schemas start empty. Correct, but `fct_telemetry` then
  scans all of raw (~1 GB).
- A changed `snp_drivers` snapshots into an empty CI schema (no history).
  Prod's snapshot was seeded from dev's history on 2026-10-21
  (`bootstrap_prod_snapshots` macro).

## Layers

| Layer | Schema | Materialization | Purpose |
|---|---|---|---|
| `staging/ergast` | `F1_DBT_B_v2_1_STAGING` | view | 1:1 with each raw table. Renames, `\N`/empty-string to null, typed casts, time strings to ms. No joins. |
| `intermediate` | `F1_DBT_B_v2_1_INTERMEDIATE` | view | Reusable business logic: season completeness, official standings snapshot, race entries, green-flag lap flags. |
| `marts` | `F1_DBT_B_v2_1_MARTS` | table | Public, contract-enforced interface for downstream teams. |
| `audit` | `F1_DBT_B_v2_1_AUDIT` | view | Always-current data-quality views (e.g. orphan results). |
| `snapshots` | `F1_DBT_B_v2_1_SNAPSHOTS` | snapshot | Type 2 history of source tables. Never drop or full-refresh. |
| `seeds` | `F1_DBT_B_v2_1_REFERENCE` | table | Reference data for reconciliation tests. |

## Public interfaces (for other dbt projects)

Only two models are `public`, both in group `f1_core` (owner: F1 Analytics
Engineering), both with enforced contracts:

| Model | Versions | Relation |
|---|---|---|
| `fct_results` | unversioned | `F1_DBT_B_v2_1_MARTS.FCT_RESULTS` |
| `dim_drivers` | **v2 (latest)**, v1 (deprecated 2027-01-01) | v2: `DIM_DRIVERS_V2`, v1: `DIM_DRIVERS` |

Everything else is `protected`: usable inside this project only, and it may
change without notice.

**Consuming them** (with this project declared in your `dependencies.yml`):

```sql
select * from {{ ref('f1_analytics', 'fct_results') }}
select * from {{ ref('f1_analytics', 'dim_drivers') }}         -- latest = v2
select * from {{ ref('f1_analytics', 'dim_drivers', v=1) }}    -- pin during migration
```

**`dim_drivers` v1 to v2 migration:**
- Removed: `full_name`, `forename`, `surname`.
- Added: `first_name` (was `forename`), `last_name` (was `surname`). Both are
  never null. Rebuild a display name as `first_name || ' ' || last_name`.
- Placeholder rows (driver referenced by a feed before the driver record
  arrives, `is_placeholder = true`): v2 has `first_name = 'Unknown'` and
  `last_name = 'Driver <id>'`. v1 keeps `full_name = 'Unknown driver <id>'`
  with null `forename`/`surname`. Filter on `is_placeholder`, not on names.
- Every other column is identical in name, type, meaning and values.
- An unpinned `ref` resolves to v2 now. Pin `v=1` if you need time. v1 is
  removed after 2027-01-01, and referencing it shows a deprecation warning.
- v1 keeps the original table name (`DIM_DRIVERS`) and column order, so direct
  SQL or BI readers of that table are unaffected until it's removed.

Contract changes to a public model must be additive (new columns) or ship as a
new version.

## Insights for leadership

`docs/leadership_answers.md` answers "which drivers overperform their car?"
(`mart_driver_car_overperformance`: teammate-adjusted, same-session
qualifying pace with 95% intervals, 2006+) and "are pit stops getting
faster?" (`mart_pit_stop_trends`: circuit-adjusted pit-lane time, 2011+). It
covers the definitions, assumptions and limitations.

## Telemetry (cost-aware incremental)

`CAR_TELEMETRY` (~20M rows, 2022 onward, ~180 MB compressed) is appended in
load order, so it's naturally clustered by `_LOADED_AT`. Both telemetry models
are incremental and replace data **a race at a time** (`delete+insert` on
`race_id`):

1. `fct_telemetry` runs one cheap query for the races with raw rows loaded
   after its newest `loaded_at`, minus `telemetry_lookback_hours` (6) for
   out-of-order commits. It then re-reads only those races from raw, using a
   literal `race_id` list so partitions are pruned, and replaces them. A late
   sample has a new `_LOADED_AT`, so its race is rebuilt however old it is. A
   re-delivered sample replaces the old copy (the latest delivery wins).
2. `mart_lap_telemetry_summary` finds races that `fct_telemetry` rewrote since
   its own newest `source_ingested_at`, and recomputes every lap of those races
   from all their samples. It never patches with deltas, so max, average and
   percentages are always exact.

The race lists are computed in the model body (macros in `macros/telemetry.sql`),
not in `config()`. Fusion fixes config at parse time, so a run-time
`incremental_predicates` value is silently ignored. That was tried and produced
duplicates, which the uniqueness test caught.

Measured on 2026-10-21 (bytes scanned, from Snowflake query history):

| Run | Scanned | Notes |
|---|---|---|
| Full rebuild (`--full-refresh`) | ~1,025 MB | 716 MB reading all of raw + 309 MB for the summary |
| Routine run, nothing new | ~40 MB (~4%) | ~10 MB race-list lookup on raw + re-reading the latest race (lookback) |
| Routine run, late samples for a 2022 race | ~110 MB (~11%) | rebuilds that race and the latest one |

Cost grows with the number of races touched, not with table size. Heavy tests on
`fct_telemetry` only check rows ingested in the last `telemetry_test_window_days`
(3). Right after a full refresh that is every row; afterwards only recently
rewritten races. `assert_lap_telemetry_summary_matches_samples` re-aggregates
the same window from scratch and compares it to the summary.

When to full-refresh: only after changing either model's logic or contract.
Never for late data.

## Vendor B cross-check

Vendor B (`VB_DRIVERS`, `VB_SESSIONS`, `VB_RESULTS`, 2018 onward) shares no ids
with our feed, so ids are matched from the data on every build:

- **Sessions** (`dim_session_crosswalk`): same season and session type, and
  Vendor B's session date equals our `race_date` (Grand Prix) or `sprint_date`
  (sprint). A weekend has one of each, so this is unique. The circuit location
  must also match Vendor B's meeting name (accent- and case-insensitive); it
  breaks ties if a date ever matches twice. Only the date part of `DATE_START`
  is used, because the time is sometimes `\N`.
- **Drivers** (`dim_driver_crosswalk`): candidates are our drivers with an
  entry in the same sessions. Each is scored: surname 3, driver code 2, car
  number 1, forename 1, with names compared case-, accent- and
  space-insensitively. The best candidate wins only if it scores at least 4,
  no other candidate has the same score, and it shares at least half of the
  Vendor B driver's sessions. Codes and numbers get reused across eras (MSC:
  Michael and Mick Schumacher), so they never decide a match on their own.
- **Overrides**: `seeds/vendor_b_driver_overrides.csv` and
  `seeds/vendor_b_session_overrides.csv` (both empty today) take precedence,
  for genuinely ambiguous cases only.
- **Failure**: an unmatched or ambiguous driver or session gets a null id.
  `assert_vendor_b_fully_matched` and the crosswalk `not_null` / `unique` tests
  then fail the build, and `mart_vendor_result_discrepancies` is skipped.

Today all 167 sessions and 41 drivers match automatically: 40 drivers score
7/7, and Albon scores 6 (Vendor B has "Alex", we have "Alexander").

`mart_vendor_result_discrepancies` compares every season Vendor B covers,
keyed on `(race_id, session_type, driver_id)`. Our feed is the system of record.

## Semantic Layer

Semantic models (latest spec, defined on the model YAML):

| Semantic model | Built on | Primary entity | Dimensions |
|---|---|---|---|
| `results` | `fct_results` | `result` | `season`, `round`, `race_date` (time, day), `constructor_name`, `status`, `is_win`, `is_podium`; foreign entities `driver`, `constructor`, `race` |
| `drivers` | `dim_drivers` (latest version, v2) | `driver` | `driver_ref`, `driver_name`, `nationality`, `is_placeholder` |
| `constructors` | `dim_constructors` | `constructor` | `constructor_name`, `nationality` |

`metricflow_time_spine` is the daily time spine (1950 to the end of next year).
`metric_time` is `race_date`.

Metrics (all Grand Prix only; sprints excluded):

| Metric | Definition |
|---|---|
| `race_starts` | count of result entries in `fct_results` (includes DNQ/DNS/withdrawn entries) |
| `wins` | results with `finish_position = 1` |
| `podiums` | results with `finish_position` 1-3 |
| `championship_points` | sum of `points` per result (no drop scores, no sprints; use `mart_driver_season_standings` for official totals) |
| `podium_rate` | `podiums / race_starts` |
| `points_per_start` | `championship_points / race_starts` |

Group-by names: `result__season`, `result__constructor_name`,
`driver__nationality`, `driver__driver_name`, `constructor__constructor_name`,
`constructor__nationality`, and `metric_time__day|week|month|quarter|year`.

Example queries (`dbt sl query` on the dbt platform; `mf query` takes the same flags locally):

```bash
# Wins and podium rate by driver nationality, all time
dbt sl query --metrics wins,podiums,podium_rate --group-by driver__nationality --order-by -wins --limit 10

# A constructor's season-by-season record
dbt sl query --metrics race_starts,wins,championship_points,points_per_start \
  --group-by result__season,constructor__constructor_name \
  --where "{{ Dimension('constructor__constructor_name') }} = 'Ferrari'" --order-by result__season

# Most podiums by driver this decade
dbt sl query --metrics podiums,race_starts,podium_rate --group-by driver__driver_name \
  --where "{{ TimeDimension('metric_time', 'day') }} >= '2020-01-01'" --order-by -podiums --limit 20

# Points per start over time
dbt sl query --metrics points_per_start --group-by metric_time__year --order-by metric_time__year
```

Validation: `dbt parse` writes `target/semantic_manifest.json`. Fusion only runs
`dbt sl validate` when the project is linked to the dbt platform
(`dbt_cloud.yml`). Without that link, validate the manifest with
`dbt-semantic-interfaces`' `SemanticManifestValidator` or with `mf validate-configs`.

## Key definitions

- **Completed round**: a race with at least one Grand Prix result.
  **Complete season**: every race on the calendar is completed (`int_seasons`).
  World championships only count for complete seasons.
- **Standings** come from Ergast's published cumulative standings at the
  latest completed round, not from summing race points. Summing doesn't
  reproduce the official tables: drop scores before 1991, shared drives in the
  1950s and sprint points from 2021. Champions are reconciled against
  `seeds/reference_world_champions.csv` on every build.
- **Sessions**: `fct_results` is Grand Prix only; `fct_session_results` unions
  Grand Prix and sprint entries, keyed by `(session_type, source_result_id)`.
  `dim_drivers.career_wins` counts Grand Prix wins only, `career_sprint_wins` sprints.
- **Standings by round**: `mart_driver_standings_by_round` is the published
  standings after every round; `mart_driver_season_standings` is that model
  filtered to each season's latest completed round.
- **What-if scoring**: `seeds/points_systems.csv` holds points per position for
  each system. `mart_alt_points_standings_by_system` re-scores every season under
  every system; `mart_alt_points_standings` shows one system (var
  `alt_points_system`, default `fia_2010`). To add a system, add seed rows and
  run `dbt build`. No SQL change is needed.
- **Green-flag lap**: not lap 1, not a pit in-lap or the lap after it, and no
  slower than 130% of the race's fastest lap (`vars.green_lap_max_ratio`).
- **Pit stops** over 60 s are red-flag stoppages and excluded (`vars.max_pit_stop_ms`).

## Incremental lap models

`fct_lap_times` and `fct_stints` are incremental and replace data one whole race at
a time (`delete+insert` on `race_id`), so a correction that drops or renumbers
laps is applied cleanly.

- `fct_lap_times` loads races that aren't in the table yet, and reloads the
  `lap_correction_window_races` (2) most recent races already loaded, because the
  timing provider can reissue corrected laps for them. Each reload stamps `loaded_at`.
- `fct_stints` recomputes a race when it is new to the table, when its laps'
  `loaded_at` is newer than the one the stints were built from, or when it is
  one of the two most recent races (covers corrected pit stops).
- `assert_lap_times_match_source` (warn) compares every race against staging.
  If it fires, an older race was corrected outside the window: run
  `dbt build --full-refresh --select fct_lap_times+`.
- A change to either contract needs a `--full-refresh` (`on_schema_change: fail`).

## Driver history and late-arriving drivers

- `snp_drivers` (check strategy, all columns) records a new version whenever a
  driver's number, code, name or other attribute changes. `dim_drivers_history`
  exposes it with `valid_from` / `valid_to`; `dim_drivers.current_number` comes
  from the current version. History only exists from the first snapshot run.
- Results can arrive before the driver's record. `int_driver_ids` collects every
  driver_id referenced by any feed, so `dim_drivers` gets a placeholder row
  (`is_placeholder = true`, `driver_ref = 'unknown_driver_<id>'`) and the results
  flow through `fct_results` and every downstream model. `dim_drivers` is rebuilt
  each run, so real values replace the placeholder as soon as the record lands.
- `audit_orphan_driver_results` lists the orphan results at any time
  (`select count(*)` for the total), and `assert_no_orphan_driver_results`
  raises a build warning while any exist.

## Vendor change protection

The vendor's raw schema is a contract, enforced at three points:

1. **Schema guard (on-run-start).** `macros/check_source_schemas.sql` compares
   every table and column declared in `models/staging/ergast/_ergast__sources.yml`
   with the warehouse before anything runs. If a declared table or column is
   missing (a rename shows up as missing + new), the run stops with
   `VENDOR SCHEMA CHANGE DETECTED. Nothing was built.` and a list. No snapshot
   or incremental table is written. Undeclared new columns produce a warning.
   Emergency bypass: `--vars '{skip_source_schema_check: true}'`.
2. **Format tests on sources.** Every parsed column has a `matches_pattern`
   test (integer, decimal, `m:ss.mmm`, ISO or `DD/MM/YYYY` date, and so on). In
   `dbt build` a failing source test skips everything downstream, so a format
   change can't silently turn values into nulls or wrong numbers.
3. **No format guessing in staging.** Dates go through `parse_date` (explicit
   formats only) and never Snowflake's AUTO detection.
4. **Re-delivered rows.** Every staging model keeps one row per natural key
   (`dedupe` macro), so a resent row can't fan out a join, even under `dbt run`.
   On each source, `no_redelivered_rows` warns when the vendor resends rows, and
   `no_conflicting_duplicates` fails the build when the copies disagree.
   `audit_source_duplicates` shows the current count per table.
5. **Grain and reconciliation tests on the marts.** `fct_results` and
   `fct_qualifying` must have exactly as many rows as their staging model.
   Pit stop totals must reconcile to eligible stops. Constructor points must
   match the vendor's own `CONSTRUCTOR_RESULTS` (1979+, non-sprint weekends).

Run the project with `dbt build`, not `dbt run` followed by `dbt test`. In a
build, a failing source or staging test skips everything downstream, so bad data
never replaces a mart table. With `run` then `test`, the tables are replaced
first and the tests only complain afterwards.

### Vendor changes log

| Date | Change | Handling |
|---|---|---|
| 2026-10-21 | `LAP_TIMES` table renamed `LAP_TIMING` | source `lap_times` now has `identifier: LAP_TIMING` |
| 2026-10-21 | `RESULTS.POSITIONORDER` and `SPRINT_RESULTS.POSITIONORDER` renamed `POSITION_ORDER` | staging reads the new name |
| 2026-10-21 | `PIT_STOPS.DURATION` dropped | unused (we read `MILLISECONDS`) |
| 2026-10-21 | `RACES.DATE` changed from `YYYY-MM-DD` to `DD/MM/YYYY` | `parse_date` accepts both. AUTO detection would have nulled 667 dates and moved 422 to the wrong day |
| 2026-10-21 | `CONSTRUCTORS`: Ferrari (id 6) resent with a trailing space in NAME | collapsed in staging. Without the fix, Ferrari's results doubled in `fct_results` (wins 249 to 498, points 11,091 to 22,182) |
| 2026-10-21 | `DRIVER_STANDINGS`: race 1142 resent (23 rows, ids + 100000, same values) | collapsed in staging; it would have duplicated round 22 in the standings marts |
| 2026-10-21 | `QUALIFYING` Q1-Q3 missing times changed from `\N` to empty string | `clean_text` already treats both as null |

After the 2026-10-21 fix, every mart, the snapshot and the seeds were diffed
row by row against a pre-migration clone: identical, apart from adding the 2024
champion to `reference_world_champions` once 2024 completed.

## Data quirks

- Nulls are the literal `\N`; qualifying Q2/Q3 also contain empty strings.
- 2024 has 24 calendar rounds but only 22 with results. 2024 standings are as
  of round 22 and no 2024 title is counted.
- `RESULTS` grain is `resultid`: 91 race/driver pairs repeat before 1979
  (drivers who raced two cars in one race).
- Race 71 (2005 Australian GP): two lapped finishers have `POSITION = \N` but
  numeric `POSITIONTEXT` (11, 14). They are treated as classified.
- 1997: Michael Schumacher is excluded from the championship (`POSITIONTEXT = 'D'`).
  `championship_position` is null and `is_excluded` is true.
- 19 driver-seasons have results but are absent from the final standings
  (never classified). The official tables omit them too, so we do as well.
- `grid = 0` (1,638 rows) means a pit-lane start or unknown slot.
- Pit stop duration is total pit-lane time, not stationary time. 517 of
  11,283 stops are over 60 s.
- `career_starts` follows the requested definition (distinct Grands Prix
  entered), so it includes did-not-qualify and withdrawn entries.

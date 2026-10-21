# f1_analytics

dbt project for Formula 1 analytics, built on the Ergast/Kaggle F1 data in
`ANALYTICS_DEV.F1_RAW_HB_V2_1` (1950 to 2024 seasons). Models build into
`F1_DBT_HB_V2_1_<layer>` (`_staging`, `_intermediate`, `_marts`, `_reference`).

```bash
dbt build           # run and test everything
dbt build --select +fct_driver_race_pace   # one model and its upstream
```

`profiles.yml` lives in this folder (profile `f1`, target `dev`), so run dbt with it
in place or pass `--profiles-dir .`.

## Public interfaces

Group `f1_core` owns the public models. Everything else is `protected` to this project.

| Model | Access | Contract | Notes |
| --- | --- | --- | --- |
| `fct_results` | public | enforced | One row per Grand Prix result entry |
| `dim_drivers` v2 (latest) | public | enforced | `first_name`, `last_name`. No `full_name` |
| `dim_drivers` v1 | public | enforced | `full_name`. Deprecated 2027-01-01, still built |

Consumers should pin `ref('dim_drivers', v=1)` until they have moved to version 2. Plain
`ref('dim_drivers')` now resolves to version 2, which has no `full_name`. Placeholder rows
(`is_placeholder = true`) appear in both versions. Their `first_name` is null, and their
name reads "Unknown driver <id>" in `last_name` (and `full_name` in v1).

## Semantic Layer

Analysts self-serve metrics through the Semantic Layer (MetricFlow). Definitions are in
`models/marts/_marts__models.yml`, under `fct_results` and `dim_drivers`.

Metrics: `race_starts`, `wins`, `podiums`, `championship_points` (simple), and
`podium_rate`, `points_per_start` (derived). All are Grand Prix only.

Slices: `result__season`, `result__constructor_name`, `result__race_date` (time, day grain)
from `fct_results`. `driver__nationality` and `driver__driver_ref` from `dim_drivers`.
`metric_time` is the time dimension for time series.

Time spine: `time_spine_daily` (1945 to 2030), a fixed range so no history is cut off.

Example queries (`mf` is MetricFlow; `dbt sl query` on dbt Platform takes the same arguments):

```bash
# Wins and podiums by nationality, 2024
mf query --metrics wins,podiums,race_starts --group-by driver__nationality \
  --where "{{ Dimension('result__season') }} = 2024" --order -wins --limit 10

# Podium rate by driver, 2024
mf query --metrics podium_rate,race_starts --group-by driver__driver_ref \
  --where "{{ Dimension('result__season') }} = 2024" --order -podium_rate --limit 10

# Championship points by constructor, 2024
mf query --metrics championship_points,points_per_start --group-by result__constructor_name \
  --where "{{ Dimension('result__season') }} = 2024" --order -championship_points --limit 10

# Points per start by year
mf query --metrics points_per_start --group-by metric_time__year --order -metric_time__year
```

Validate the semantic config with `mf validate-configs` after `dbt parse`. `dbt sl validate` needs
a dbt Platform project. MetricFlow reads the Snowflake profile in this folder, and signs in through
the browser (`externalbrowser`).

## Vendor B cross-check

Vendor B (2018 to 2024) is a second feed that shares no ids with ours. The crosswalks map it onto
our keys. Our feed stays the system of record.

- `dim_driver_crosswalk` (one row per Vendor B driver). Rules, in order:
  1. a manual override in `seeds/vendor_b_driver_overrides.csv`
  2. exactly one of our drivers with the same normalized surname and given name
     (Vendor B writes `SURNAME Given`, and accents are folded)
  3. exactly one of our drivers with the same surname and three-letter code
- `dim_session_crosswalk` (one row per Vendor B session, with `race_id` and `session_type`).
  A session matches our race weekend in the same season, at the same location, where its date
  is within one day of the race date (or the sprint date for sprints). Vendor B dates are UTC.
  If two weekends tie, the session stays unmatched. Manual overrides go in
  `seeds/vendor_b_session_overrides.csv`.
- `mart_vendor_result_discrepancies` lists where the feeds disagree on Grand Prix and sprint
  results: `points`, `position` (an entry unclassified in both feeds is not a discrepancy),
  `missing_in_vendor_b`, and `missing_in_vendor_a`. The season range comes from Vendor B's data.

The build fails if any Vendor B driver or session has no match (not-null tests on the crosswalks),
or if a match is not one-to-one. Test `warn_vendor_b_malformed_session_timestamps` reports
Vendor B timestamps the feed has corrupted. Their dates are still recovered from the first ten
characters.

## Car telemetry

`CAR_TELEMETRY` holds about 20 million samples from 2022 (4 per second per car). Two models:

- `fct_telemetry` (one row per sample). Incremental, merged on (race, driver, lap, sample index).
  Each run reads samples whose `_LOADED_AT` is newer than the newest loaded sample minus
  `telemetry_lookback_hours` (48). It never reads by `RECORDED_AT`, so a late sample that lands
  weeks after its race is picked up on the next run. A corrected sample overwrites its row.
- `mart_lap_telemetry_summary` (one row per driver per lap). Incremental, merged on
  (race, driver, lap). A run finds the laps that received samples since the last run and recomputes
  only those, from `fct_telemetry`. `last_loaded_at` marks the newest sample for each lap.

Cost, measured on this data (19.8M samples, 181 MB):

| Run | Samples read | Bytes scanned | Laps recomputed |
| --- | --- | --- | --- |
| Full rebuild | 19.8M | about 181 MB | 73,368 |
| Routine run, after one race weekend | about 254k (the lookback window) | about 10 MB | about 939 |

A routine run costs about 5% of a full rebuild in bytes and about 1% in rows. Its cost is set by the
lookback window, not by the number of late samples. Shorten `telemetry_lookback_hours` to cut cost
further, at the risk of missing out-of-order commits.

Reconciliation checks scan the whole fact table, so they carry the `reconciliation` tag. Routine
runs exclude them: `dbt build --exclude tag:reconciliation`. Run them on a schedule, for example
weekly, with `dbt test --select tag:reconciliation`. A plain `dbt build` runs everything.

## Targets and CI

Targets in `profiles.yml`:

| Target | Schema | Use |
| --- | --- | --- |
| `dev` (default) | `F1_DBT_HB_v2_1` (models in `_STAGING`, `_MARTS`, and so on) | Day-to-day development |
| `prod` | `F1_DBT_HB_v2_1_PROD` | Production. Its manifest is the CI baseline |
| `ci` | `F1_DBT_HB_v2_1_CI` | Pull request builds |

### The production baseline

`prod-artifacts/manifest.json` (and `run_results.json`) is saved from a full production build. After
a change is merged and built to prod, refresh the baseline:

```bash
dbt seed --target prod --full-refresh
dbt snapshot --target prod
dbt run --target prod --full-refresh
dbt test --target prod
cp target/manifest.json target/run_results.json prod-artifacts/
```

Commit the updated `prod-artifacts/` with the change. `dbt run` must run before `dbt test` in a fresh
schema. A unit test on an incremental model reads its target table, and that table does not exist
until the model has been built.

### Pull request builds

Run `scripts/ci.sh` from the project root (no arguments). It:

1. lists the selection (`state:modified+` against `prod-artifacts/`): changed models, seeds and
   snapshots, plus everything downstream of them
2. builds the seeds and snapshots in the selection into the `ci` target
3. runs the models in the selection into the `ci` target
4. tests the selection, including unit tests, excluding the `reconciliation` tag

Unchanged upstream models are not rebuilt. `--defer --favor-state` resolves them to their production
relations in `F1_DBT_HB_v2_1_PROD`. The script exits non-zero if any step fails.

Costs and limits:

- A changed incremental model (for example `fct_telemetry`) is built in full in the CI schema, because
  the CI schema starts empty. A telemetry change is therefore a full telemetry build (about 20 million
  samples) for that pull request.
- Reconciliation checks are not part of CI. They scan whole tables, so they run on a schedule with
  `dbt test --target prod --select tag:reconciliation`.
- The profiles use `externalbrowser` sign-in, which needs a person at a browser. A CI runner needs
  non-interactive credentials, such as key-pair or OAuth, set in its own environment before the
  profile is used.

## Layers

| Layer | Materialization | Purpose |
| --- | --- | --- |
| `models/staging` | view | One model per raw table. Types are cast, `\N` becomes NULL, lap and qualifying times become milliseconds. No business logic. |
| `models/intermediate` | view | Reusable logic: season completion (`int_season_completion`) and lap-level green flag rules (`int_lap_flags`). |
| `models/marts` | table | The published models that downstream teams use. Each has a unique grain and tests. |
| `seeds/` | table | `official_world_champions`: published champions, used only to test the standings against history. |

### Marts

| Model | Grain |
| --- | --- |
| `fct_results` | one Grand Prix result entry (`result_id`) |
| `dim_drivers` | one driver |
| `mart_driver_season_standings` | driver x season, as of the latest completed round |
| `mart_constructor_season_pit_stops` | constructor x season |
| `fct_qualifying` | one qualifying entry |
| `mart_teammate_head_to_head` | season x constructor x driver x teammate |
| `fct_driver_race_pace` | driver x race with at least one green-flag lap |
| `fct_lap_times` | driver x lap x race (incremental) |
| `fct_stints` | driver x stint x race, races with pit data (incremental) |
| `fct_session_results` | driver x session (Grand Prix or sprint) |
| `mart_driver_standings_by_round` | driver x round in the official standings |
| `mart_alt_points_standings` | points system x driver x season, what-if championships |

Standings: `mart_driver_standings_by_round` is the source. `mart_driver_season_standings`
is derived from it.

What-if points: add a system by adding rows to `seeds/points_systems.csv`
(`points_system, first_season, last_season, position_order, points`). No SQL change is
needed. The countback uses fixed finishing counts for positions 1 to 10.

`fct_lap_times` and `fct_stints` are incremental (`delete+insert` on `race_id`). Each
run rebuilds the two most recent loaded races plus any new races, so corrected lap
times flow through without `--full-refresh`. Laps dropped by a correction are removed
only while the corrected race still has at least one lap. Pit stop corrections for
races older than the two most recent are not picked up incrementally: use
`dbt build --full-refresh` for those.

## Drivers

- `snp_drivers` (snapshot, `F1_DBT_HB_V2_1_SNAPSHOTS`) is a type 2 history of driver
  attributes. Current rows have `dbt_valid_to` null.
- `dim_drivers.current_number` is the permanent car number, null when a driver has none.
- Late-arriving drivers: a result, qualifying entry, pit stop, lap or standing that
  names a driver with no record in `stg_f1__drivers` is kept. `dim_drivers` gets a
  placeholder row (`is_placeholder = true`, `driver_ref = unknown_<id>`) that is replaced
  by the real record on the next run. Nothing has to be done by hand.
- `dq_orphan_driver_results` (view) counts those rows by source table and season. Zero
  rows means no driver records are missing.

## Conventions

- Raw columns are lowercase in staging; `race_id`, `driver_id`, `constructor_id`
  and `season` are used everywhere so models join without renaming.
- `finish_position` is NULL when a result is not classified. `position_order` is
  always populated and is used for ranking.
- Thresholds are variables in `dbt_project.yml` (`red_flag_pit_stop_ms`,
  `slow_lap_multiplier`), not hard-coded values.
- Macros: `clean_null` (the `\N` sentinel), `lap_time_to_ms` (`m:ss.SSS` to ms),
  `position_text_to_int` (POSITIONTEXT to an integer position, NULL for status codes).
- The `unique_combination_of_columns` generic test is the grain check for composite keys.
- `tests/` holds business-rule tests: champions match the official history, grain
  and sprint exclusion, classification rules, gap-to-pole consistency, red-flag
  exclusion, head-to-head symmetry and green-lap rules.

## Vendor changes and guardrails

The raw schema is set by `vars.raw_database` and `vars.raw_schema` in `dbt_project.yml`.

Migration of 2026-10-21 (what the vendor told us: standardised some column and table names,
dropped a redundant column, cleaned up formats). What changed, and what we did:

| Area | Change | Handling |
| --- | --- | --- |
| Table | `LAP_TIMES` renamed `LAP_TIMING` | source identifier updated |
| Column | `RESULTS.POSITIONORDER` and `SPRINT_RESULTS.POSITIONORDER` renamed `POSITION_ORDER` | staging updated |
| Column | `PIT_STOPS.DURATION` dropped (`MILLISECONDS` kept) | not used by any model |
| Format | Missing qualifying times are empty strings, not `\N` | `clean_null` treats both as NULL |
| Format | Race dates changed from `YYYY-MM-DD` to `DD/MM/YYYY` | parsed with `DD/MM/YYYY` |

Guardrails, so a future vendor change fails the build instead of changing numbers quietly:

- `seeds/source_contract.csv` lists every expected raw table and column.
  `tests/assert_raw_matches_source_contract.sql` fails on any missing or unexpected one.
- `tests/assert_parsed_values_are_not_dropped.sql` counts non-blank raw values against
  parsed staging values for every parsed field. A format the parser cannot read fails here,
  not as a silent NULL.

Verification of the migration: every model was rebuilt from the pre-migration commit against a
legacy-shaped copy of the same raw data (old names and formats). Every relation matched the
current build row for row.

## Feed integrity

The vendor feed can carry corruption that the schema checks cannot see. Found so far:

| Date seen | Problem | Effect if unhandled | Handling |
| --- | --- | --- | --- |
| 2026-10-21 13:21 UTC | Ferrari (`constructorid` 6) loaded twice; one copy's name has a trailing space | Joining constructors to results doubles every Ferrari result, so wins, points and pit-stop counts double. Other teams unchanged | Staging trims and dedupes exact copies. Conflicting copies fail the build |
| 2026-10-21 13:21 UTC | 2024 round 22 (race 1142) standings loaded twice under two ids | Standings grain breaks, with two rows per driver | Staging keeps one row per race and driver, and conflicting copies fail the build |
| 2026-10-21 | Trailing spaces in some names and nationalities | Labels split or mismatch | Trimmed in staging. `warn_raw_untrimmed_text` lists them |

Checks that catch these before a dashboard reads them:

- `assert_no_conflicting_duplicate_copies`: duplicate keys whose copies differ fail the build.
- `warn_raw_duplicate_copies`: exact copies are removed and reported, so the vendor sees them.
- `assert_standings_reconcile_with_race_points`: each round's change in championship points must
  equal that round's Grand Prix plus sprint points, from 1991. This catches a standings feed
  that disagrees with the results.
- `unique` tests on every staging and mart key. A join fan-out fails here before a dashboard
  reads it.
- `assert_pit_stop_metrics_exclude_red_flags` counts stops from staging, not from `fct_results`,
  so a fan-out upstream cannot hide.

Known history, not defects: some 1950s races list two result rows with position 1 (shared
entries), and some pre-1979 result pairs repeat. Results are one row per `result_id`, which is
the source's own grain.

## Data notes

Main data points:

- Season completeness: 2024 is incomplete (rounds 23 and 24 have no results).
  Its standings stop at round 22, and its champion is not counted as a title.
- Standings come from the official `DRIVER_STANDINGS` snapshot, not from summing
  Grand Prix points. Sums do not match before 1991 (dropped scores) or from 2021
  (sprint points are included in the official totals).
- `lap_times.milliseconds` is the lap duration. `pit_stops.duration` is seconds
  and `pit_stops.milliseconds` is authoritative.
- Pit stop data starts in 2011. Pre-2011 green-lap rules cannot exclude pit laps;
  `fct_driver_race_pace.has_pit_data` marks this.

# F1 analytics (dbt + Snowflake)

Source: `ANALYTICS_DEV.F1_RAW_SA_v2_1` (Ergast/Kaggle CSVs, all text, read-only).
Target: `F1_DBT_SA_v2_1`.

```
dbt build --profiles-dir .
```

## Layers
| Layer | Folder | Materialization | Rule |
|---|---|---|---|
| Staging | `models/staging/ergast` | view | 1:1 with a source table; cast types, clean `\N`/blank nulls, rename. No joins. |
| Intermediate | `models/intermediate` | view | Reusable logic (season completeness, official standings). |
| Core marts | `models/marts/core` | table | `fct_` / `dim_` models other teams depend on. |
| Analytics marts | `models/marts/analytics` | table | `mart_` / pace models for specific analyses. |

## Conventions and data quirks
- Raw nulls are the text `\N` (qualifying also has empty strings): use `clean_text()`; times use `lap_time_to_ms()`.
- A season is *complete* only if every race on its calendar has results (`int_season_status`). 2024 is truncated (rounds 23-24 have no results), so its standings are as of round 22 and no 2024 title is counted.
- Standings come from the published `driver_standings` snapshot at the last completed round, not a sum of race points (dropped scores before 1991, sprint points from 2021).
- `results` grain is `result_id`; before 1961 shared drives give a driver two rows in one race, so career counts use distinct races.
- 2005 Australian GP: two lapped finishers have blank `position` but numeric `positiontext`; they are classified.
- Pit stop `duration` switches to `m:ss.mmm` over a minute; use `milliseconds`. 517 stops are over 60 s and excluded.
- Snowflake `LEAST` returns null if any argument is null; `least_ignore_nulls` is used for qualifying best time.
- One 1995 Japanese GP Q1 time is `16:42.640` (likely a typo); kept as published, flagged by a warn-severity test.

## Incremental lap models (`models/marts/telemetry`)
`fct_lap_times` and `fct_stints` are incremental with `delete+insert` on `race_id`. Each run
reloads races not yet in the table plus the two most recent races already loaded (the window
in which the timing provider reissues corrected laps); older races are untouched. `fct_stints`
is built from `fct_lap_times`, so corrections flow through to stints. Use `--full-refresh` only
to rebuild history or if a correction is issued for an older race.

## Driver history and late-arriving drivers
- `snp_drivers` (`snapshots/`) is a type-2 snapshot (check strategy on number, code, name, nationality, DOB). Run it with `dbt snapshot` or `dbt build`; history only accrues from the first run. `dim_drivers.current_number` is the current raw number (null if none; a few numbers are shared by different drivers, so it is not unique).
- A driver_id seen in results/qualifying/laps/pits/standings but missing from `drivers` gets a placeholder row in `dim_drivers` (`is_placeholder = true`, `driver_ref = unknown_<id>`). Facts keep those rows. The real values replace the placeholder on the next run.
- `monitor_orphan_driver_results` shows orphan results per driver (`select sum(orphan_results) ...`); a warn-severity test reports when any exist. The staging driver relationship tests are warn-only for the same reason.
- Not covered: late-arriving races, constructors or statuses (fct_results inner-joins those).

## Sprints, standings by round, what-if scoring
- `fct_session_results` unions Grand Prix and sprint entries. Sprint `result_id`s overlap the Grand Prix ones, so the key is `(session_type, source_result_id)`. `dim_drivers.career_wins` is Grand Prix only; `career_sprint_wins` is separate.
- `mart_driver_standings_by_round` is the single source of official standings; `mart_driver_season_standings` is its last completed round (the old `int_driver_season_standings` was removed).
- `seeds/points_systems.csv` holds scoring systems (`points_system, position_order, points`). To add one, append rows. `mart_alt_points_standings_all_systems` scores every system; `mart_alt_points_standings` shows `var('default_points_system')` (currently `current_2010`) at one row per driver-season. Scoring uses `position_order` of classified entries, so races with a disqualification (1983 Brazil: positions shifted vs `position`) score by the adjusted order.

## When the vendor changes the raw schema
- Every dbt invocation starts with `assert_source_contract` (on-run-start). It compares the tables/columns declared in `models/staging/ergast/_ergast__sources.yml` with the warehouse and stops with a readable report if something was renamed or dropped; new columns are logged as warnings. Run it alone with `dbt run-operation assert_source_contract`.
- The source yml also carries `source_value_format` tests for ids, numbers, dates (`DD/MM/YYYY`) and lap-time layouts, so a silent format change fails the build instead of producing wrong numbers.
- Mapping applied after the 2026-10 vendor migration: table `lap_times` is now `lap_timing`; `positionorder` is now `position_order` (results, sprint_results); pit stop `duration` was dropped (we use `milliseconds`); race dates are `DD/MM/YYYY`; qualifying/fastest-lap times are `m:ss.mmm` with a leading `0:` minute and blank strings for missing quali times. Staging models absorb all of this, so mart outputs are unchanged.
- After a vendor change, rebuild the incremental models once (`dbt build --full-refresh --select fct_lap_times+`), since only recent races are reloaded normally.

## Duplicates and fan-out (incident notes)
- The vendor re-delivered rows: constructor 6 (Ferrari) arrived twice (one copy with a trailing space in `name`) and the race 1142 driver standings arrived twice under new surrogate ids. A raw duplicate in a dimension fans out every join to it, which doubled Ferrari's wins/points/pit stops.
- Staging now trims, then `select distinct`s, so exact re-deliveries collapse; the standings surrogate id is no longer carried. Conflicting duplicates are not collapsed and fail the unique tests.
- Detection layers: (1) warn-severity key-uniqueness tests on the raw sources (visible re-delivery), (2) error-severity key tests on staging, (3) reconciliation tests (`assert_fct_results_reconciles_to_staging`, `assert_constructor_totals_match_raw`, `assert_pit_stops_reconcile_to_staging`) that fail if a fact has more/fewer rows or different totals than its staging input.

## Public interfaces and versioning
- `fct_results` and `dim_drivers` are `access: public`, owned by group `f1_analytics`, with enforced contracts (names, types, not-null; `points` is `number(8,2)`, everything else `number(38,0)`). Everything else is `protected` (project default) and not safe to depend on from other projects.
- `dim_drivers` has two versions. **v1** (`full_name`) is deprecated on **2027-01-01** and builds as `dim_drivers_v1`; **v2** (`first_name`, `last_name`, no `full_name`) is the latest and builds as `dim_drivers_v2`. dbt also maintains the unversioned relation `dim_drivers` as a view over the latest version, so direct-SQL readers of `dim_drivers` now get v2 columns: point them at `dim_drivers_v1` until they migrate. `ref('dim_drivers')` resolves to v2; use `ref('dim_drivers', v=1)` to stay on v1 until you migrate.
- Late-arriving drivers: placeholder rows exist in both versions (`is_placeholder = true`). v1: `full_name = 'Unknown driver (<id>)'`; v2: `first_name` is null and `last_name = 'Unknown driver (<id>)'`.
- Migrating v1 -> v2: replace `full_name` with `concat_ws(' ', first_name, last_name)` (nothing else changed).

## Semantic Layer
Defined with the new YAML spec, next to the public models (`models/marts/core/_core_public__models.yml`):
- Semantic model `grand_prix_results` on `fct_results` (time dimension `race_date`, dimensions `season`, `constructor_name`; entities `result`, `race`, `driver`, `constructor`) with metrics `race_starts`, `wins`, `podiums`, `championship_points`.
- Semantic model `drivers` on the latest `dim_drivers` (entity `driver`; dimensions `driver_ref`, `first_name`, `last_name`, `nationality`).
- Ratio metrics `podium_rate` and `points_per_start` live in `models/semantic/_semantic__models.yml`, together with the `metricflow_time_spine` model (daily, 1950-2049).
- Slice with `metric_time` (= race date), `season`, `constructor_name`, `driver__nationality`, `driver__last_name`, `driver__driver_ref`.

Example queries (dbt Platform / MetricFlow CLI):
```
dbt sl query --metrics wins,podium_rate --group-by season,constructor_name --where "{{ Dimension('season') }} = 2023"
dbt sl query --metrics race_starts,wins --group-by driver__nationality --order-by -wins --limit 10
dbt sl query --metrics championship_points,points_per_start --group-by metric_time__year --where "{{ Dimension('driver__last_name') }} = 'Hamilton'"
```

## Vendor B cross-check (`models/marts/vendor_reconciliation`)
Vendor B (`vb_drivers`, `vb_sessions`, `vb_results`, 2018+) shares no ids with the primary feed (system of record), so ids are matched from the data:
- **Sessions** (`dim_session_crosswalk`): race sessions match the primary race in the same season whose date is within one day of the session's UTC date (closest wins); sprint sessions take the race_id of the Vendor B race session with the same season and meeting name that follows within 0-4 days.
- **Drivers** (`dim_driver_crosswalk`): best tier wins - exact accent-folded name, then surname + 3-letter code, code + racing number, surname prefix, finally an identical results fingerprint (position and points across >= 3 entries and >= 80%). Candidates are limited to drivers who raced in the seasons Vendor B covers, so namesakes (Albers/Albon, Vergne/Verstappen, Jan/Kevin Magnussen) do not compete. `results_agreement` shows how well each match's results line up.
- **Loud failure**: an unmatched/ambiguous driver or session keeps a null id, which fails `not_null`/`unique` tests and skips the discrepancy mart. Resolve rare cases with `seeds/vendor_b_driver_overrides.csv` or `seeds/vendor_b_session_overrides.csv` (normally empty); overrides win over automatic matching.
- `mart_vendor_result_discrepancies` lists points / position / missing_in_vendor_a / missing_in_vendor_b differences for the seasons Vendor B covers; values are text.

## Telemetry (`fct_telemetry`, `mart_lap_telemetry_summary`)
~20M raw samples; routine runs must stay cheap and late samples must be picked up.
- `fct_telemetry` is incremental on the raw `_loaded_at` (not the race): a sample that lands weeks late has a new `_loaded_at`, so the next run reads it and merges it into its race by key. Each run reads raw rows loaded since our newest row minus a lookback (`telemetry_lookback_hours`, default 2); rows already held unchanged are filtered out before the merge, so a run with nothing new writes nothing. Re-deliveries: latest `loaded_at` wins. Clustered by `race_id`.
- `mart_lap_telemetry_summary` is incremental by lap: it finds laps whose samples were written (`ingested_at`, our own write time) since its watermark and recomputes only those from the fact. Using our own write time means it also follows reloaded rows.
- Safety net: `assert_telemetry_row_counts_match_raw` compares per-race counts with the raw table (one column each, cheap). If samples ever land with a `_loaded_at` older than our watermark it fails; fix with `dbt build --select fct_telemetry+ --vars '{telemetry_reload_races: [<race_id>]}'`.
- Cost (Snowflake bytes scanned, measured): full build of `fct_telemetry` 683 MB (19.8M rows) + 333 MB for the summary; a routine run with nothing new ~45 MB and 0 rows written; a new race or late samples reads and writes only those rows (plus their laps for the summary, ~20 MB). Row-level tests on the fact only look at the last 3 days of ingested rows.

## Environments and CI
Targets in `profiles.yml`: `dev` (default, `F1_DBT_SA_v2_1`), `prod` (`F1_DBT_SA_v2_1_PROD`), `ci` (`F1_DBT_SA_v2_1_CI`).

- **Production build**: `dbt build --target prod`, then refresh the state CI compares against:
  `dbt parse --target prod && cp target/manifest.json prod-artifacts/` and commit it. `prod-artifacts/manifest.json` is the artifact from the last prod build.
- **First build into an empty schema** (new prod, `--full-refresh`): dbt Fusion types unit tests of *incremental* models from the existing table, so those two unit tests are tagged `needs_built_model`. Bootstrap with
  `dbt build --target prod --exclude tag:needs_built_model && dbt test --target prod --select tag:needs_built_model`. Ordinary builds on an existing schema (dev, routine prod) need no special handling.
- **Pull requests**: `scripts/ci.sh` (project root, no arguments):
  1. recreates the CI schema (`reset_ci_schema`, which refuses to run on any other target);
  2. selects `state:modified+` against `prod-artifacts/` (changed models, tests, seeds, macros, sources and everything downstream);
  3. `dbt build --target ci --defer --favor-state --state prod-artifacts`: only the selection is built and tested into the CI schema; unchanged upstream models are read from prod rather than rebuilt;
  4. runs the tagged incremental-model unit tests for modified models once those models exist;
  5. exits non-zero if anything fails, and with exit code 2 if `prod-artifacts/manifest.json` is missing.
  With no changes nothing is built and it exits 0. A modified *incremental* model is built from scratch in CI (the CI table starts empty); a modified `fct_telemetry` therefore reads the whole raw telemetry table once.
- Keep `prod-artifacts/` current after every prod deploy, otherwise unrelated models can look modified (or changes can be missed) in CI.

## Insights models and write-ups
`models/marts/insights/` answers two leadership questions (teammate-based driver performance with uncertainty, and like-for-like pit stop
trends). Definitions, caveats and the answers are in [docs/leadership_answers.md](docs/leadership_answers.md).

# F1 analytics (dbt)

Formula 1 analytics models for Snowflake, built on the Ergast/Kaggle F1 tables (1950 to 2024).
Raw data is in `ANALYTICS_DEV.F1_RAW_HB_1` and is read-only. Models build into `ANALYTICS_DEV.F1_DBT_HB_1`.

## Layout

| Layer | Schema | Materialization | Models |
| --- | --- | --- | --- |
| staging | `F1_DBT_HB_1_STAGING` | view | `stg_f1__*`: one model per raw table used, with types and `\N` nulls cleaned |
| intermediate | `F1_DBT_HB_1_INTERMEDIATE` | view | `int_seasons`: season completeness and latest completed round |
| marts | `F1_DBT_HB_1` | table (`fct_lap_times` is incremental) | `fct_results`, `fct_session_results`, `fct_lap_times`, `dim_drivers`, `mart_driver_standings_by_round`, `mart_driver_season_standings`, `mart_constructor_season_pit_stops` |

Sources are declared in `models/staging/f1/_f1__sources.yml`. Macros are in `macros/`
(`na_to_null` turns the literal `\N` into null, and `lap_time_to_ms` parses `m:ss.sss`).

## Running

```bash
dbt build
dbt docs generate
```

`profiles.yml` in this folder defines the `f1` profile (target `dev`). Run the commands from this folder.

## Business rules

- **fct_results**: Grand Prix results only. Sprint results are excluded.
  `finish_position` is null when the entry was not classified. `is_win` and `is_podium` are false for unclassified entries.
  `fastest_lap_time_ms` is parsed from `m:ss.sss`.
- **int_seasons**: a season is complete when every race on its calendar has results.
- **dim_drivers**: `world_championships` counts only complete seasons. Career totals come from `fct_results`.
- **mart_driver_season_standings**: one row per driver per season as of the latest round with results.
  Points, position and wins are the official standings values. They are not recomputed from results, because the official
  points include sprint points from 2021 and dropped scores in early seasons.
- **mart_constructor_season_pit_stops**: pit stops longer than 60 seconds are excluded (red-flag stoppages).
  Constructor comes from the driver's result entry for that race.

## Data quirks

- Every raw column is text. Missing values are the literal string `\N`.
- Season 2024 is incomplete in the source: Abu Dhabi (round 24) has no results yet. Qatar (round 23) had none at first profiling and has since loaded.
  2024 standings are as of round 23, and 2024 does not count toward world championships. The raw data has no seasons after 2024.
- The raw tables are still loading. Row counts have grown since the first profile (results 26,719 to 26,739, sprints 340 to 360, laps 587,109 to 588,048).
  Models are written to pick up new rows without changes.
- The results table has about 90 race and driver pairs with two entries, from 1950s seasons where a driver was entered in two cars.
  `result_id` is the unique key, not race and driver.
- The Indianapolis 500 was a World Championship round from 1950 to 1960 and is kept in `fct_results`.
- A driver nationality value has a trailing space ("Argentinian "). Staging trims it.
- Pit stop data starts in 2011. 517 stops are over 60 seconds and are excluded. 481 of those are over two minutes.

## Lap times (incremental)

`fct_lap_times` is incremental with `delete+insert` on `race_id`. Each run rebuilds every race dated within the two most
recent races already loaded, which picks up timing providers' reissued corrections. Then it appends new races. Removed laps
are dropped too, because the whole race is replaced. Use `dbt build --full-refresh` only to rebuild history.

## Sessions and standings history

- **fct_session_results**: one row per driver entry per session (`session_type` = race or sprint).
  Key is (`session_type`, `source_result_id`). `fct_results` remains Grand Prix only.
- **dim_drivers**: `career_wins` counts Grand Prix wins only. `career_sprint_wins` counts sprint wins.
- **mart_driver_standings_by_round**: official standings after every round. The season view is derived from it.
  `mart_driver_season_standings` keeps the same output (checked row for row against its previous output).

## Vendor schema changes

Every raw source table has an `expected_columns` test in `models/staging/f1/_f1__sources.yml`. It lists the columns
the project expects. The test fails, and `dbt build` stops before any model runs, when a column is missing from the
source or present in the source but not in the list. This is how a vendor rename or drop is caught.

When the vendor changes a schema on purpose:
1. Check what changed in the source (`information_schema.columns` for `F1_RAW_HB_1`).
2. Update the staging models that use the changed column.
3. Update that table's `expected_columns` list and add a comment naming the change.
4. Rebuild, and compare the marts against their previous output before you accept the change.

Changes made so far:
- `RESULTS` and `SPRINT_RESULTS`: `POSITIONORDER` renamed to `POSITION_ORDER`.
- `PIT_STOPS`: `DURATION` dropped. The project reads `MILLISECONDS`, so no output changed.
- All marts were checked row for row against their pre-change output after the rebuild. No values changed.

## Snapshot location

`snp_drivers` writes to `F1_DBT_HB_1_SNAPSHOTS`. A bare `target_schema` name skips the target schema prefix, so an
earlier version wrote to the shared `ANALYTICS_DEV.SNAPSHOTS` schema. Its history was copied to the project schema.
The old table `ANALYTICS_DEV.SNAPSHOTS.SNP_DRIVERS` is still there and should be deleted by someone who owns that schema.

## Duplicate rows and the build gate

Use `dbt build`, not `dbt run`. A failing `unique` test in staging stops every model downstream of it. `dbt run` runs
no tests, so it can rebuild marts from bad data without warning.

- The vendor sends some constructors twice. Exact duplicates are removed in `stg_f1__constructors`. The warning test
  `assert_raw_constructors_exact_duplicates` reports them. Rows that share an id but differ in content fail the staging
  unique test, and the build stops before any mart is built.
- `assert_fct_results_row_count_matches_source` and `assert_pit_mart_reconciles_to_source` check that the marts account for
  every source row, so a join that multiplies rows fails the build.
- Source-level `unique` tests are warnings. A failing source test does not stop downstream models, so the staging tests are the gate.

Incident (Ferrari totals doubled): a duplicate Ferrari row appeared in the raw constructors table at 00:04. A build that
joined to it doubled every Ferrari result, win and point. The project's own tables were built before the duplicate
arrived and were not affected. Whatever feeds the dashboard was rebuilt after the duplicate arrived, so the rebuild
probably ran without the tests. That build is not visible from this project.

## Public interfaces for other teams

`fct_results` and `dim_drivers` are public (`access: public`) and have enforced contracts, so column names and types can't change silently.

- **`fct_results`**: no version yet. A rename, removal or type change is breaking and needs a new version.
  `fastest_lap_time_ms` is an integer (it was a float before the contract was added; values are unchanged).
- **`dim_drivers`**: version 2 is the latest, and `ref('dim_drivers')` resolves to it.
  - **Breaking change in v2:** `full_name` is replaced by `first_name` and `last_name`. Otherwise the columns are the same.
  - **Version 1** still builds, to `F1_DBT_HB_1.DIM_DRIVERS_V1`, and is deprecated from 2027-01-01.
  - The physical table `F1_DBT_HB_1.DIM_DRIVERS` is the latest version, so it now holds v2 (`first_name` and `last_name`, no `full_name`).
    Anything that queries that table directly and reads `full_name` must move to `DIM_DRIVERS_V1`.
    Move consumers to v2 with `ref('dim_drivers', v=2)` or `ref('dim_drivers')`.

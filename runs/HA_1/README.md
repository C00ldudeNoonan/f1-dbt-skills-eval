# F1 analytics (dbt)

Warehouse models for Formula 1 results, driver careers, championship standings, and constructor pit stop performance. Built on the Ergast/Kaggle F1 extract (1950 to 2024) loaded into Snowflake as text.

## Running

The Snowflake profile lives in this folder (`profiles.yml`, profile `f1`, target `dev`), so pass the profiles directory on every command:

```bash
dbt build --profiles-dir .
```

Models build into `ANALYTICS_DEV.F1_DBT_HA_1_staging`, `..._intermediate` and `..._marts` (the target schema plus a custom suffix per layer). Raw data is read from `ANALYTICS_DEV.F1_RAW_HA_1` and is never written to.

## Layout

| Layer | Materialization | Models |
| --- | --- | --- |
| `models/staging` | views | `stg_f1__*`: one model per raw table. Casts text to types, turns the `\N` marker into null, converts lap times to milliseconds |
| `models/intermediate` | views | `int_f1__season_completion`: calendar coverage and the latest completed round per season |
| `models/marts` | tables | `fct_results`, `dim_drivers`, `mart_driver_season_standings`, `mart_constructor_season_pit_stops` |

Shared parsing lives in `macros/f1_raw_helpers.sql` (`null_marker`, `lap_time_to_ms`).

## Business rules

- **Grand Prix only.** `fct_results` comes from the GP results table. Sprint results are not used there.
- **Sessions.** `fct_session_results` holds both GP (`session_type = 'race'`) and sprint (`'sprint'`) entries. `source_result_id` is only unique within a session type, so use `session_result_key`. `dim_drivers.career_wins` counts GP wins only, and `career_sprint_wins` counts sprint wins.
- **Standings over time.** `mart_driver_standings_by_round` has the official standings after each round, for charting. `mart_driver_season_standings` is derived from it, filtered to each season's latest completed round.
- **Grain.** `fct_results` is one row per `result_id`. A driver can have two rows in the same race in the early seasons (for example, two cars in one event), so `race_id` plus `driver_id` is not unique.
- **Not classified.** `finish_position` is null when the raw `POSITION` is `\N`.
- **Complete season.** A season is complete only when every race on its calendar has results. Championships (`dim_drivers.world_championships`) count only complete seasons.
- **Standings.** `mart_driver_season_standings` uses the official driver standings snapshot after each season's latest completed round, so historical points (including drop-score rules) match the published tables.
- **Pit stops.** Stops over 60 seconds are red-flag stoppages and are excluded from both `pit_stop_count` and the median.
- **Lap times.** `fct_lap_times` is incremental (delete+insert keyed by `race_id`). Each run rebuilds races not yet loaded and the two most recent loaded races, so the provider's corrections flow through. Corrections to older races need `dbt build -s fct_lap_times --full-refresh`. Lap times use the `MILLISECONDS` column, because red-flag laps are written as `h:mm:ss.sss`.

## Known data quirks

- Missing values are the literal string `\N`, in every table.
- Season completeness depends on the raw data. When the Abu Dhabi 2024 results loaded, 2024 became a complete season and its championship counts (Verstappen). Until then, a season with a missing calendar race is not counted. The raw tables are loaded as new races land, so these counts change over time.
- Raw data ends with the 2024 season. The 2025 and later seasons are not in the extract.
- Lap times are text in `m:ss.sss` form, and are converted to integer milliseconds.
- Pit stop durations are also available in milliseconds, which is the column used.
- 2005 Indianapolis: two cars have a numeric `POSITIONTEXT` but a `\N` `POSITION`. They are treated as not classified.
- `GRID = 0` means the car started from the pit lane. It is kept as 0.

## Vendor schema contract

The raw tables come from a vendor pipeline that can change shape without notice. `seeds/f1_raw_expected_columns.csv` lists every expected raw column. The singular test `tests/assert_raw_schema_matches_contract.sql` compares it with the live `F1_RAW_HA_1` layout and fails the build with the exact table and column that changed:

- `missing from raw`: a column the contract expects is gone (for example, a rename or a drop).
- `new in raw (not in contract)`: the vendor added a column.

When a change is intended, update the seed and any staging models that use the column, then rebuild. Changes so far:

- `RESULTS` and `SPRINT_RESULTS`: `POSITIONORDER` renamed to `POSITION_ORDER`.
- `PIT_STOPS`: `DURATION` dropped. It was redundant with `MILLISECONDS`, which the project uses.

## Duplicate vendor rows

The vendor has sent a duplicate `CONSTRUCTORS` row for Ferrari (`constructor_id` 6). `stg_f1__constructors` keeps one row per constructor, so results are not duplicated. The source unique test reports the duplicate as a warning. Two error-level tests (`assert_fct_results_row_count_matches_staging` and `assert_fct_session_results_row_count_matches_staging`) fail the build if any mart join adds or drops rows.

Note that a failing test does not stop dbt from refreshing tables. Gate the dashboard on a clean `dbt build` (for example, `--fail-fast`) before it reads the marts.

## Public interfaces and versions

`fct_results` and `dim_drivers` are public interfaces for other teams' dbt projects. Both enforce a model contract, so a change to a column name or type fails the build.

`dim_drivers` is versioned:

- **Version 2 (latest)**: `first_name` and `last_name` replace `full_name`. Use `ref('dim_drivers')` to get it.
- **Version 1**: unchanged, with `full_name`. Still builds. Deprecated on 2027-01-01. Reference it with `ref('dim_drivers', v=1)` until then.

Consumers on `ref('dim_drivers')` with no version pick up version 2, which removes `full_name`. Pin `v=1` or move to `first_name`/`last_name` before that happens.

## Unit tests

Unit tests use fixed input rows, so they check logic without touching the warehouse data:

- `stg_f1__results`: fastest lap text (`m:ss.sss`) becomes integer milliseconds, and `\N` becomes null.
- `int_f1__driver_championships`: a title counts only when its season is complete. A position-1 finish in an in-progress season adds nothing.

## Tests

Column tests cover keys, not-null fields and foreign keys. Singular tests in `tests/` check that:

- each complete season has exactly one champion,
- incomplete seasons are excluded from championship counts,
- win and podium flags agree with finishing positions,
- pit stop medians are plausible,
- known champions (1950 Farina, 2008 Hamilton, 2016 Rosberg, 2021 Verstappen) match.

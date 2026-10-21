# F1 analytics dbt project

Builds Formula 1 marts (Ergast/Kaggle data, 1950–2024) from `ANALYTICS_DEV.F1_RAW_SB_1` into `F1_DBT_SB_1`.

| Layer | Schema | Models |
|---|---|---|
| staging (views) | `F1_DBT_SB_1_STAGING` | `stg_f1__*`: typing, `\N` → NULL, renames |
| intermediate (views) | `F1_DBT_SB_1_INTERMEDIATE` | `int_season_completeness` |
| marts (tables) | `F1_DBT_SB_1` | `fct_results`, `dim_drivers`, `mart_driver_season_standings`, `mart_constructor_season_pit_stops` |

Run: `dbt build`.

## Data quirks / decisions
- Raw is all text; NULL is the literal `\N` (see `clean_null` macro).
- `(race_id, driver_id)` is **not** unique in results: 91 shared-drive pairs (1950–78). `fct_results` keeps every row; driver career counts use `count(distinct race_id)`.
- 2024 calendar has 24 races but results/standings only through round 22 (Las Vegas). 2024 is therefore not a completed season (no 2024 title counted) and its standings are as of round 22.
- Standings come from the official `driver_standings` table, not summed results: results sums differ from official points (dropped scores 1950–90, half points, sprint points from 2021).
- Pit stops (2011+) have no constructor; attributed via the driver's result in that race. `duration` is mixed `ss.mmm` / `m:ss.mmm` text, so `milliseconds` is used. 517 stops > 60s are excluded as red-flag stoppages.
- `career_starts` counts Grands Prix *entered* (a results row), which includes "Did not qualify" rows present in the raw results.
- `grid = 0` means pit-lane start / no grid slot.

## Incremental `fct_lap_times`
Merge on `(race_id, driver_id, lap)`. Each run reprocesses races at or after the second-most-recent race already in the table, so new races load and corrected laps for the two latest races overwrite in place. Corrections to older races need `dbt run -s fct_lap_times --full-refresh`.

## Drivers snapshot
`snp_drivers` (schema `F1_DBT_SB_1_SNAPSHOTS`) is a check-strategy type 2 snapshot of raw `drivers` (number, code, name, nationality). History starts at the first snapshot run, so run it on every schedule. `dim_drivers.current_number` is the raw current number (null for 802 drivers without one; numbers are reused across eras).

## Sprints and standings over time
- `fct_session_results` unions Grand Prix (`session_type = 'race'`, from `fct_results`) and sprint entries. Sprint `result_id`s (1–360) collide with Grand Prix ids, so uniqueness is on `(session_type, source_result_id)` / `session_result_id`. `fct_results` stays Grand Prix only; `dim_drivers.career_wins` is Grand Prix wins, `career_sprint_wins` is sprint wins.
- `mart_driver_standings_by_round` holds official standings after every round; `mart_driver_season_standings` is now derived from it (same output, checked by row hash against the previous logic).

## Vendor schema changes
Staging models select raw columns explicitly, and every raw table we read has a `source_has_columns` test listing the columns we depend on. A vendor rename or drop now fails as `<table>: missing expected column <name>` before any model runs, rather than as a SQL error deep in the build. When the vendor changes shape, update the column list in `_f1__sources.yml` together with the staging model.

History: the vendor renamed `positionorder` to `position_order` (`results`, `sprint_results`) and dropped `pit_stops.duration` (we already used `milliseconds`). Output hashes of all marts were verified identical before and after the fix. If dbt reports stale source columns after an upstream change, delete `target/` (schema cache).

## Duplicate dimension rows (Ferrari incident)
The vendor feed added a second `constructors` row for Ferrari (id 6) whose `name` had a trailing space. Joins to constructors fanned out and doubled Ferrari's results. `stg_f1__constructors` now trims text and keeps one row per id. Safeguards: warn-level `unique` on the raw source (visible, not blocking), `assert_no_conflicting_constructor_duplicates` (fails if copies genuinely disagree), and reconciliation tests `assert_fct_results_reconciles_to_staging` and `assert_pit_stop_count_reconciles` (fact/mart row counts and totals must match upstream).

## Public interfaces, contracts and versions
`fct_results` and `dim_drivers` are `access: public` with enforced contracts (names, types, order; not-null on keys).
- `dim_drivers` **v2 (latest)** replaces `full_name` with `first_name` + `last_name`. **v1 is deprecated (2027-01-01)** and is derived from v2 (`full_name` = trimmed `first_name last_name`; verified row-identical to the old table).
- Relations: `dim_drivers_v1`, `dim_drivers_v2`, and a view `dim_drivers` that always points at the latest version (`latest_version_pointer`). Unpinned `ref('dim_drivers')` and the unsuffixed relation therefore now return the v2 shape; pin `ref('dim_drivers', v=1)` / `dim_drivers_v1` until migrated.
- Unit tests cover lap-time parsing (`_f1__unit_tests.yml`) and championship-only-if-season-complete / per-race career counts (`_marts__unit_tests.yml`).

# F1 analytics dbt project

Builds Formula 1 analytics models from the Ergast/Kaggle raw load in `ANALYTICS_DEV.F1_RAW_SC_1` (read-only) into `F1_DBT_SC_1`.

```
dbt build --profiles-dir .
```

## Layout
| Layer | Path | Materialization | Purpose |
|---|---|---|---|
| Sources | `models/staging/f1/_f1__sources.yml` | – | All 14 raw tables, key tests |
| Staging | `models/staging/f1/` | view | Rename, cast text to types, turn `\N` into null (`clean_null`), parse lap times (`lap_time_to_ms`) |
| Intermediate | `models/intermediate/` | view | `int_f1__season_status`: calendar completeness + latest completed round per season |
| Marts | `models/marts/` | table | `fct_results`, `dim_drivers`, `mart_driver_season_standings`, `mart_constructor_season_pit_stops` |
| Tests | `tests/` | – | Reconciliation to raw and anchors against published F1 history |

## Data quirks and decisions
- **Everything is text; nulls are the literal `\N`.** Cleaned once, in staging.
- **`round` is text** and sorts '9' after '16'; cast to int before taking "latest round".
- **The current season is incomplete** (at first build 2024 lacked rounds 23-24; later loads add them one by one). A season only counts as complete once every calendar race has results, so no title is awarded for a partial season, and standings are as of the latest round with results. Results landing in raw flow through automatically.
- **Official standings come from `driver_standings`, not summed results.** Seasons up to 1990 dropped worst results (e.g. 1988: Senna 90 official vs Prost 105 summed), so summing points picks the wrong champion.
- **Shared drives (1950-1978)**: a car driven by two drivers appears as two rows per race. Career starts/wins/podiums count distinct races; shared wins count for both drivers.
- **`results` includes non-starters** (Did not qualify / prequalify / withdrew). `career_starts` follows the spec ("distinct Grands Prix entered") and includes them; `career_race_entries_excl_dnq` is the stricter alternative.
- **Unclassified**: `finish_position` uses raw `position`, null when not classified. Two 2005 US GP rows have a numeric `positiontext` but no classification and are treated as unclassified.
- **1997 Schumacher** is in the standings with position 26 (excluded from the championship).
- **Pit stops** start in 2011; 517 stops over 60s (red flags, max ~51 minutes) are excluded from count and median.
- `grid = 0` means pit-lane start / no grid slot.

## Incremental model: `fct_lap_times`
Lap data is large and grows after every Grand Prix, so the table is incremental (`delete+insert`, `unique_key=race_id`). The raw table has no load timestamp, so each run reloads races dated on/after the *second most recent race already in the table* — i.e. any new races plus the two latest loaded ones, to absorb corrected lap times the timing provider reissues. Older history is not reprocessed. If corrections ever land for older races, or logic changes, run `dbt build --select fct_lap_times --full-refresh`. Verified by corrupting rows in the latest, second-latest and third-latest races: the first two were repaired on the next run, the third was left alone, and a deleted newest race was reloaded.

## Driver history and numbers
- `snp_drivers` (snapshots/) is a type 2 snapshot of raw `drivers` (check strategy, all columns). It only captures a change if a run observes it, so run `dbt snapshot` / `dbt build` on every load. Never drop it; it cannot be rebuilt from raw.
- `dim_drivers.current_number` is the permanent number in raw (null if none). Numbers are not unique across drivers: retired drivers' numbers get reused (e.g. 22 for Button and Tsunoda). Past numbers/codes are in `snp_drivers`.

## Sprints and standings history
- `fct_session_results` unions Grand Prix (`fct_results`) and sprint results with `session_type`. **Raw result ids collide across the two tables** (every sprint `resultid` also exists in `results`), so the unique key is `session_result_id = session_type || '-' || source_result_id`. `fct_results` stays Grand Prix only, and `dim_drivers.career_wins` stays GP-only; `career_sprint_wins` counts sprint wins separately.
- `mart_driver_standings_by_round` holds the official table after every round. `mart_driver_season_standings` is that model filtered to each season's latest completed round (output verified identical before/after the refactor).

## Vendor schema drift
The vendor has changed raw shapes without notice (`positionorder` became `position_order` in `results` and `sprint_results`; `pit_stops.duration` was dropped, which nothing used). Every raw table now declares its full column list in `_f1__sources.yml` as a contract, enforced by two generic tests (`macros/source_column_contract.sql`):
- `source_columns_missing` (error) fails the build, before any model runs, and its failing rows are the missing column names.
- `source_columns_unexpected` (warn) lists new columns the vendor added.
A rename shows as one of each. To adapt: fix staging, update the declared columns, then clear `target/` if Fusion's cached source schema trips unit-test fixtures. After the 2024-10 migration, all marts were diffed row-for-row against the pre-migration tables with zero differences.

## Duplicate dimension rows (Ferrari doubling incident)
Raw `constructors` gained a second row for constructor 6 whose name was `'Ferrari '` (trailing space), so it was not an exact duplicate. Every `inner join` to constructors in `fct_results` then doubled Ferrari's entries (wins 249 to 498, points doubled, 2024 pit stops 75 to 150), and the pit stop mart inherited it. Only Ferrari moved because only it had the duplicate.
- Staging of the four joined dimensions (constructors, drivers, status, races) now trims text and keeps one row per key, so duplicates cannot fan out joins.
- `source_no_conflicting_duplicates` (error) stops the build when rows sharing a key differ after trimming; the plain source `unique` test on those keys is a warning.
- `assert_fct_results_totals_match_raw` (entries, points, wins per constructor) and `assert_session_and_pit_stop_marts_no_fan_out` catch inflation whatever its cause.
- Tests run after a table is built, so a failed mart test still leaves a bad table in place. Run the job as `dbt build` (source and staging tests gate downstream models), never `dbt run` followed by a separate test step, and point dashboards at the last successful build.

## Public interfaces: contracts and `dim_drivers` versions
`fct_results` and `dim_drivers` are `access: public` with **enforced contracts** (every column and type declared in `_marts__public_models.yml`; a build that would change the shape fails and leaves the existing table in place). Breaking changes ship as a new model version.

`dim_drivers` has two versions, both built from `int_f1__driver_profiles`:
| | Relation | Name columns | Status |
|---|---|---|---|
| v1 | `dim_drivers` (table) | `full_name` | **deprecated, `deprecation_date: 2027-01-01`** |
| v2 | `dim_drivers_v2` (table) | `first_name`, `last_name` (no `full_name`) | **latest** |

All other columns are identical. For consumers:
- `ref('dim_drivers')` in dbt now resolves to **v2** (latest). Anything selecting `full_name` through an unpinned ref breaks; pin `ref('dim_drivers', v=1)` until migrated, then move to `v=2` (or reconstruct with `first_name || ' ' || last_name`).
- SQL run directly against the warehouse is unaffected: `dim_drivers` is still v1. The automatic unsuffixed "latest version" view is disabled on purpose (it would collide with v1's table name and silently change the shape for these readers). Switch to `dim_drivers_v2` explicitly.
- v1 stops being maintained after 2027-01-01; dbt warns when a deprecated version is referenced.

## Unit tests
Lap-time parsing (`m:ss.mmm` to ms, including `0:59.999`, `1:00.000`, `10:03.005`, nulls) on race and sprint staging; season completeness (`int_f1__season_status`, including numeric round ordering: round 10 after 9); championship counting only for complete seasons (`int_f1__driver_profiles`); v1/v2 name columns. Unit tests that list expected columns must list *all* the columns they care about, since Fusion compares omitted ones as null.

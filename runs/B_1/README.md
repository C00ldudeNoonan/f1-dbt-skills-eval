# F1 Analytics (dbt)

dbt project modelling the Ergast / Kaggle Formula 1 dataset (1950 to the
latest loaded round) on Snowflake.

- **Source (read-only):** `ANALYTICS_DEV.F1_RAW_B_1`: 14 tables, every column TEXT, nulls as `\N`.
- **Target:** `ANALYTICS_DEV.F1_DBT_B_1_<layer>` (`_STAGING`, `_INTERMEDIATE`, `_MARTS`, `_REFERENCE`).

```bash
dbt build          # models + seeds + data tests + unit tests
dbt docs generate  # lineage and column docs
```

## Layout

| Layer | Path | Materialization | Purpose |
|---|---|---|---|
| Staging | `models/staging/ergast/` | view | 1:1 with each source table: rename to snake_case, convert `\N` to null, cast types. No business logic. |
| Intermediate | `models/intermediate/` | view | Reusable business rules: season completeness, pit stops with constructor. |
| Marts | `models/marts/{core,championship,pit_stops,timing}/` | table (`fct_lap_times`: incremental) | The consumer-facing models. |
| Snapshots | `snapshots/` | snapshot | `snp_drivers`: type 2 history of raw drivers (the source only keeps current numbers/codes). |
| Reference | `seeds/` | seed | Hand-maintained official world champions, used to test the standings mart. |

Shared casting helpers (`ergast_clean`, `ergast_int`, `lap_time_to_ms`, ...) are in `macros/ergast_casts.sql`.

### Marts

- `fct_results`: one row per Grand Prix result entry (no sprints).
- `fct_session_results`: one row per entry across Grand Prix races *and* sprints (`session_type` = 'race' / 'sprint').
- `dim_drivers` (**versioned**, v2 latest): one row per driver with career starts, Grand Prix wins (`career_wins`), sprint wins (`career_sprint_wins`), podiums and world championships.
- `mart_driver_standings_by_round`: official championship standings after every round, for charting how a title fight evolved.
- `mart_driver_season_standings`: official championship standings per driver per season, as of the latest completed round. It is `mart_driver_standings_by_round` filtered to that round.
- `fct_lap_times`: one row per driver per lap per Grand Prix (1996 onwards). Incremental, see below.
- `mart_constructor_season_pit_stops`: pit stop count and median pit lane time per constructor per season (stops over 60s excluded; set by the `max_pit_stop_seconds` var).

## Public interfaces (for other dbt projects)

`fct_results` and `dim_drivers` have `access: public` and **enforced contracts**:
every column's name and data type is declared in `models/marts/core/_core__models.yml`,
and a build fails before writing the table if the SQL no longer matches. Any
breaking change (removing, renaming or retyping a column) must ship as a new
model version. Additive columns are non-breaking but still need adding to the contract.

### `dim_drivers` versions

| Version | Relation | Name columns | Status |
|---|---|---|---|
| **v2** (latest) | `F1_DBT_B_1_MARTS.DIM_DRIVERS_V2` | `first_name`, `last_name` | current |
| v1 | `F1_DBT_B_1_MARTS.DIM_DRIVERS` (original relation, unchanged) | `forename`, `surname`, `full_name` | **deprecated 2027-01-01** |

What a consumer needs to know:

- `ref('f1_analytics', 'dim_drivers')` (unpinned) now resolves to **v2**. If you
  use `full_name`, `forename` or `surname`, pin `ref('f1_analytics', 'dim_drivers', v=1)`
  for now and migrate before 2027-01-01. dbt warns on every reference to v1.
- To migrate: `forename` → `first_name`, `surname` → `last_name`, and
  `full_name` → `first_name || ' ' || last_name`. All other columns, types and values are identical.
- Names are as Ergast records them, so `first_name` is not always the full given
  name (Juan Manuel Fangio is `Juan` / `Fangio`).
- Anyone querying the warehouse directly: `DIM_DRIVERS` is still v1, with the same
  columns, column order and data, until it's removed after 2027-01-01. v2 is `DIM_DRIVERS_V2`.
- v1 is built from v2 (`dim_drivers_v1.sql` only renames columns), so both versions always agree.

## Unit tests

- `test_fastest_lap_time_parsed_to_integer_ms` (stg_ergast__results): 'm:ss.fff', sub-minute,
  multi-minute, whitespace, `\N` and empty input to integer ms.
- `test_championship_counts_only_once_season_is_complete` (dim_drivers v2): leading
  an in-progress season or being excluded never counts as a title.
- `test_season_complete_only_when_every_race_has_results` (int_season_calendar_progress).

## Key business rules

- **Season complete** = every race on that season's calendar has results (`int_season_calendar_progress`). Only complete seasons award a world championship; an in-progress season's leader appears in the standings mart with `is_season_complete = false`. When a season completes, `assert_world_champions_match_official_record` fails until you add its champion to `seeds/official_world_champions.csv`. This is deliberate, so that every new title is checked by a person against the official result.
- **Standings come from the official standings table, not recomputed from results.** Before 1991 only a driver's best N results counted (dropped scores), and Michael Schumacher was excluded from the 1997 championship. The source standings already reflect both. Tests check this against history:
  - `assert_world_champions_match_official_record`: every completed season's P1 matches the seed.
  - `assert_modern_standings_reconcile_with_race_points`: from 1991, standings points = GP + sprint points.
- **Wins/podiums** use the classified finishing position. Shared drives (1950–1964) credit every driver who shared the car, as the official record does.

## Driver history (snapshot)

`snp_drivers` (schema `F1_DBT_B_1_SNAPSHOTS`) snapshots the raw `drivers` table
with the `check` strategy on all columns (the source has no `updated_at`) and
`hard_deletes: invalidate`. History only exists from the first snapshot run
onward, so `dbt build` / `dbt snapshot` must run regularly (e.g. after every
load). `stg_ergast__driver_history` exposes it typed, with
`valid_from` / `valid_to` / `is_current`. `dim_drivers.current_number` is
the driver's current permanent number (null if none).

## Incremental lap times

`fct_lap_times` (~590k rows, growing every race weekend) is incremental with
`delete+insert` on `race_id`. Each run processes races that are not loaded yet,
plus the **two most recently loaded races** (var `lap_times_reprocess_recent_races`),
because the timing provider sometimes reissues corrected lap times for those.
Reprocessed races are deleted and fully re-inserted, so corrected times, added
laps and withdrawn laps all come through. "Most recent" is ordered by
(season, round), because `race_id` is not chronological. History is never re-read. If an
older race is ever corrected, run:

```bash
dbt build --select fct_lap_times --full-refresh
```

## Vendor schema changes (drift detection)

`_ergast__sources.yml` declares every raw column and its type. That file is
the contract with the vendor. Two generic tests on every source table
(`tests/generic/source_schema_drift.sql`) compare it with
`information_schema` on every build:

- `declared_columns_exist` (**error**): a declared column was renamed, dropped or retyped.
  The source test fails and every model downstream of that table is **skipped**, so the
  marts keep their last good data rather than being rebuilt wrong.
- `no_undeclared_columns` (**warn**): the vendor added (or renamed into) a column we
  don't declare.

Failing rows (table, column, issue) are stored in `F1_DBT_B_1_dbt_test__audit`.
To fix, update the YAML and the staging model together.

**2026-10 vendor migration:** `results.positionorder` and `sprint_results.positionorder`
were renamed to `position_order`, and the redundant text `pit_stops.duration` was dropped
(we already derived seconds from `milliseconds`). Only staging changed. Every mart's
row count and full-row hash matched the pre-migration build.

## Duplicate rows from the vendor

Staging models end in `select distinct` over their *cleaned* (trimmed,
null-normalised, typed) columns, so a repeated vendor load collapses to one
row, even if the copy differs only in whitespace. Guards, in run order:

1. **Source `unique` tests (warn):** flag that the vendor sent duplicate keys.
2. **Staging `unique` tests (error):** duplicate keys whose values genuinely differ
   can't be resolved safely, so they fail and **block every mart downstream**.
3. **`assert_fct_results_has_no_join_fanout`** (plus the pit stop and session
   reconciliation tests): rows and points per constructor in the marts must equal
   staging. This catches a fan-out from any cause, including one introduced by a
   model change.

The snapshot reads `base_ergast__drivers` (raw columns, whitespace-duplicates
removed), so a duplicate load can't create two "current" versions of a driver.

Run the scheduled job with `dbt build`, not `dbt run`: only `build` runs the
tests that stop bad data before it reaches the marts.

**2026-10 incident:** the vendor re-sent the Ferrari constructor row
(`constructorid = 6`) as `'Ferrari '`, with a trailing space. Joining results to
constructors doubled every Ferrari row, which doubled Ferrari's wins and points
in `fct_results` and its pit stops in `mart_constructor_season_pit_stops`. No
other team was affected.

## Data quirks found

1. All columns are text, and nulls are the literal string `\N`.
2. **The latest season is incomplete**: 2024 has 24 races scheduled but results for only 22 (up to Las Vegas).
3. **Shared drives (1950–1964)**: 46 races have more than one driver on the same `positionOrder`, including shared wins (e.g. 1951 French GP, Fagioli/Fangio). 91 race/driver pairs appear twice (one driver in two cars).
4. **Dropped scores**: in 26 pre-1991 seasons the official standings points are lower than summed race points. This is expected.
5. **1997 exclusion**: Schumacher's final standings row has `positionText = 'D'` and `position = 26`. We set `championship_position` to null and flag it with `is_excluded_from_championship`.
6. **1983 Brazilian GP**: 2nd place was left vacant after Rosberg's disqualification, so `position` and `positionOrder` differ for 13 rows. `finish_position` keeps the official position.
7. **2005 Australian GP**: Button and Sato have a null `position` but a numeric `positionText` (11, 14) and "+n Laps" status, so they were classified. `finish_position` falls back to `positionText`.
8. **`TRY_TO_NUMBER('E')` returns 0 in Snowflake** (it is read as scientific notation), so excluded entries would have become position 0. The fallback in 7 only applies to purely numeric text.
9. **Nationality**: driver 861 (Colapinto) is `'Argentinian '`, with a trailing space and a different spelling from the other 25 `Argentine` drivers. It is normalised.
10. **Incomplete official standings**: 19 zero-point entrants (e.g. 1997 Sospiri/Rosset, who did not qualify) have results but no standings row, so they have no row in the standings mart.
11. **Pit stops**: data only exists from 2011. 517 stops are over 60s (red flags); seconds are derived from `milliseconds` (the text `duration` column, which switched to `m:ss.fff` over a minute, was dropped by the vendor in 2026-10). Pit stops have no constructor, which is looked up via the driver's result in that race.
12. `fastestLapTime` exists only from 2004. Juan Manuel Fangio is recorded as "Juan Fangio".

# F1 Analytics (dbt)

dbt project over the Ergast/Kaggle Formula 1 dataset (1950 to the current season) in Snowflake.

- **Source:** `ANALYTICS_DEV.F1_RAW_A_1` (read-only; 14 tables, all TEXT, nulls stored as the literal `\N`)
- **Target:** `ANALYTICS_DEV.F1_DBT_A_1_<layer>` (`_STAGING`, `_INTERMEDIATE`, `_MARTS`, `_SEEDS`)

```bash
dbt build          # seeds, models and tests
dbt docs generate  # lineage + column docs
```

> **Schedule `dbt build`, never `dbt run`.** `build` runs each node's tests before
> anything downstream, so a bad raw load stops at staging and the dashboard keeps
> the last good marts. `run` skips tests and publishes whatever the joins produce.

## Layout

```
models/
  staging/ergast/      1:1 with sources: cast types, strip \N and whitespace, rename (views)
  intermediate/        reusable business logic (views)
    int_seasons__completion          calendar progress; defines "completed round" / "complete season"
    int_pit_stops__with_constructor  pit stops attributed to a constructor
  marts/               consumer-facing tables
    core/fct_results                       one row per Grand Prix result entry
    core/fct_session_results               one row per GP or sprint entry
    core/dim_drivers_v1 / _v2              one row per driver + career stats (public, versioned)
    championship/mart_driver_standings_by_round  official standings after every round
    championship/mart_driver_season_standings
    pit_stops/mart_constructor_season_pit_stops
    laps/fct_lap_times                     one row per driver per lap per race (incremental)
snapshots/snp_drivers   type 2 history of raw drivers (F1_DBT_A_1_SNAPSHOTS)
macros/                null/type-cleaning helpers, lap-time parser, generic tests
seeds/historical_world_champions.csv  independent reference list for testing
tests/                 singular data tests (history + reconciliation)
```

## Key definitions

- **Completed round:** a race with at least one Grand Prix result.
- **Complete season:** every round on the calendar is completed. Only complete seasons award a world championship (`dim_drivers.world_championships`).
- **Standings** (`mart_driver_season_standings`): taken from the official standings after the latest completed round of each season, not summed from race results. Summing results can't reproduce official history (dropped scores before 1991, sprint points from 2021, the 1997 exclusion). Two tests check this:
  - `assert_standings_match_historical_champions`: every champion's name and points match an independently sourced list.
  - `assert_standings_reconcile_to_results`: from 1991 on, standings = GP + sprint points exactly.
- **Sessions:** `fct_session_results` unions Grand Prix (`'race'`) and sprint (`'sprint'`) entries. Source result ids overlap between the two tables, so the key is `session_result_id` = `session_type || '-' || source_result_id`. `fct_results` remains the Grand Prix-only fact, and a test keeps the two in step. In `dim_drivers`, `career_wins` counts Grands Prix only and `career_sprint_wins` counts sprints.
- **Standings over time:** `mart_driver_standings_by_round` is the only place the standings logic lives. `mart_driver_season_standings` is its slice at the latest completed round.
- **Career starts:** distinct Grands Prix entered (any results row, DNQs included). This counts races, not rows, so shared drives don't double count.
- **Pit stops:** stops over 60 s are excluded. Durations are pit-lane time (not stationary time).

## Incremental lap times

`fct_lap_times` is incremental (`delete+insert` on `race_id`, so whole races are replaced). Each run:
- loads every race not yet in the table (new Grands Prix, plus any race that arrives late), and
- re-reads the **two most recent races already loaded** (by race date), so corrected lap times reissued by the timing provider flow through, including laps that were removed.

Nothing older is re-read. Run `dbt build --full-refresh -s fct_lap_times` if a correction ever lands for an older race. Note that Ergast `race_id`s are not chronological, so "most recent" is always by `race_date`.

## Driver history

The raw `drivers` table only holds current values, so `snp_drivers` keeps type 2 history:
- strategy `check` on all columns, keyed on `driverid`;
- drivers who disappear from the raw table are closed out (`hard_deletes: invalidate`);
- it stores the raw text verbatim.

History begins from the first snapshot run, so **run `dbt build` (or `dbt snapshot`) after every raw load**, otherwise intermediate values are lost. `dim_drivers.current_number` is the current permanent number. A test checks that it agrees with the open snapshot row.

## Public interfaces (for other dbt projects)

`fct_results` and `dim_drivers` are `access: public` with **enforced contracts**. Every column's name and type is fixed in `models/marts/core/_core__models.yml`, and a build that would change either fails before the table is replaced. Breaking changes ship as a new model version.

### `dim_drivers` v2 (latest) — what consumers need to know

| | v1 (deprecated 2027-01-01) | v2 (latest) |
|---|---|---|
| Relation | `F1_DBT_A_1_MARTS.DIM_DRIVERS` (unchanged) | `F1_DBT_A_1_MARTS.DIM_DRIVERS_V2` |
| Name columns | `full_name`, `forename`, `surname` | `first_name`, `last_name` |
| Everything else | identical | identical (same names, types, values) |

- **An unpinned `ref('f1_analytics', 'dim_drivers')` now resolves to v2.** If you still select `full_name` / `forename` / `surname`, pin `ref('f1_analytics', 'dim_drivers', v=1)` until you migrate. Referencing v1 emits a deprecation warning.
- **Migrating:** `forename` → `first_name`, `surname` → `last_name`, and `full_name` → `first_name || ' ' || last_name` (exactly how v1 builds it).
- **Direct SQL / BI readers** of the `DIM_DRIVERS` table are unaffected until v1 is removed (after 2027-01-01). Point them at `DIM_DRIVERS_V2` before then.
- v1 is a projection of v2, so the two can't diverge. It was verified identical, row for row and column for column, to the pre-versioning table.

### Unit tests
`dbt test --select test_type:unit` runs the logic tests on fixed inputs:
- lap-time parsing;
- `finish_position` nulling;
- season completion;
- championship counting (only complete seasons);
- sprint wins kept separate from GP wins.

## Vendor schema changes

Each raw table has a **schema contract** in `_ergast__sources.yml` (`source_columns_match`), and these tests run before staging:
- `ergast_<table>__schema_breaking` (**error**): an expected column is missing or is no longer TEXT. The failing rows name each column and the problem, and every downstream model is skipped, so the last good marts stay in place instead of being rebuilt from bad input.
- `ergast_<table>__schema_additive` (**warn**): the vendor added a column we don't know about. This is often the new half of a rename.

When the vendor changes shape, update `expected_columns` together with the staging model. Data-level tests then confirm the numbers still match history (champions, reconciliation).

**Change log**
- 2026-10: `results` / `sprint_results`: `POSITIONORDER` renamed to `POSITION_ORDER`. `pit_stops`: `DURATION` dropped (it duplicated `MILLISECONDS`). Fixed in staging. Every mart was diffed row by row against the pre-migration build: identical.

## Duplicate protection

A duplicated key in a lookup table multiplies every fact row it joins to. In 2026-10, a second Ferrari `constructors` row (`name = 'Ferrari '`, trailing space) doubled Ferrari's results, wins, points and pit stop counts. Defences, from the source to the dashboard:
1. **Source** `unique` tests are **warnings**: raw duplicates stay visible but don't block a load that staging can repair.
2. **Staging** uses `select distinct` *after* cleaning, so rows that are identical once trimmed collapse to one. Conflicting duplicates (same id, different values) survive and fail the **error**-level `unique` test on the staging model, which skips every mart.
3. **Marts:** grain tests, plus `assert_marts_have_no_join_fanout`, which reconciles row counts and totals against staging. Fan-out inside an aggregate, such as `pit_stop_count` doubling within one `(season, constructor)` group, passes grain tests; only this reconciliation catches it.

## Data quirks found

| Quirk | Handling |
|---|---|
| Every column is TEXT; nulls are the string `\N` | `clean_text` / `to_int` / `to_decimal` / `to_date` macros in staging |
| Trailing whitespace (e.g. Colapinto's nationality `"Argentinian "`) | all text trimmed in staging |
| 2024 calendar has 24 rounds but only 22 have results | 2024 standings are provisional (`is_season_complete = false`); no 2024 title awarded |
| 91 duplicate (race, driver) result rows: 1950s shared drives | grain is `result_id`; career metrics use `count(distinct race_id)` |
| Shared-drive wins (1951 French, 1956 Argentine, 1957 British GPs) have two P1 rows | both drivers credited, as the official records do |
| `position` is `\N` for two classified finishers (2005 Australian GP, P11/P14) | `finish_position` derived from `positionText` |
| `positionOrder` ≠ `position` at the 1983 Brazilian GP (Rosberg DSQ; P2 left vacant) | `finish_position` keeps the official position; `position_order` exposed separately |
| Schumacher 1997 excluded (`positionText = 'D'`) but given numeric position 26 | `championship_position` null, `is_excluded_from_championship = true` |
| Pre-1991 standings ≠ sum of results (dropped scores) | standings sourced from the official table |
| Some drivers who entered races (mostly DNQ, no points) are missing from the official standings | they are left out of the standings mart, as in the official tables |
| 517 pit stops > 60 s (red flags) | excluded from the pit stop mart |
| ~200 results where `fastestLapTime` disagrees with the minimum in `lap_times` | `fct_results` uses the results value, as specified; worth raising upstream |
| `race_id` order ≠ chronological order | incremental window uses `race_date` |
| Lap `time` text renders laps over an hour as `H:MM:SS.mmm` (43 rows, 2011 Canadian GP red flag) | `lap_time_ms` from `milliseconds` |
| Raw `number` is the *permanent* number: e.g. Verstappen is 33, not the champion's #1 he raced with in 2022–24; pre-2014 drivers are mostly `\N` | `current_number` reflects the raw value; null when absent |
| `resultId` values overlap between `results` and `sprint_results` (360 collisions) | composite / surrogate key in `fct_session_results` |
| 2026-10: duplicate Ferrari row in raw `constructors` (`'Ferrari '`, trailing space) | collapsed in staging; source test warns |
| `grid = 0` means a pit-lane start or no grid position recorded | kept raw, documented |

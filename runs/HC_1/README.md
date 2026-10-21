# F1 analytics (dbt)

Warehouse models for Formula 1 results, built on the Ergast/Kaggle F1 extracts (1950 onwards)
loaded as text into Snowflake `ANALYTICS_DEV.F1_RAW_HC_1`. The raw schema is read-only.
Everything here builds into `ANALYTICS_DEV.F1_DBT_HC_1` (staging and intermediate models go to
the `_STAGING` and `_INTERMEDIATE` suffix schemas).

## Running it

```bash
dbt build --profiles-dir .
```

`profiles.yml` lives in this folder (profile `f1`, target `dev`). Authentication is
`externalbrowser`, so the first run opens a browser sign-in.

## Layout

| Layer | Models | Purpose |
|---|---|---|
| `models/staging/ergast` | `stg_ergast__*` (views) | One model per raw table used. Casts types, turns `\N` into null, parses fastest-lap text into milliseconds. No business logic. |
| `models/intermediate` | `int_season_completeness` (view) | Season calendar vs results. Decides which seasons are complete and the latest completed round. |
| `models/marts/core` | `fct_results`, `dim_drivers` | Race result grain and driver career totals. |
| `models/marts/standings` | `mart_driver_season_standings` | Official championship standings per driver per season, as of the latest completed round. |
| `models/marts/core` | `fct_lap_times` (incremental) | One row per driver per lap. Each run replaces whole races from the second most recent loaded race onward, so provider corrections to the two latest races flow through. `--full-refresh` rebuilds all history. |
| `models/marts/pit_stops` | `mart_constructor_season_pit_stops` | Pit stop count and median duration per constructor per season. |
| `seeds` | `world_champions_reference` | Published champions 1950–2023, used as a regression check on the standings. |
| `macros` | `null_if_sentinel`, `lap_time_to_ms` | Shared cleaning logic. |

## Definitions

- **Grand Prix results only.** `fct_results` is the `RESULTS` table. Sprint results are not used.
- **Grain.** `result_id` is unique. Race-driver pairs are not: before 1979 a driver could enter two cars in one race.
- **Classification.** `finish_position` is `POSITION`, or the numeric `POSITIONTEXT` when `POSITION` is `\N`. It is null for retirements, disqualifications and did-not-qualify entries (text codes R, D, E, W, F, N).
- **`is_race_start`.** False for `Did not qualify`, `Did not prequalify` and `Withdrew` entries. `career_starts` counts distinct races with `is_race_start`.
- **Fastest lap.** `FASTESTLAPTIME` (`m:ss.mmm`) converted to integer milliseconds. The `MILLISECONDS` column is total race time and is not used for this.
- **Championship standings.** Taken from the official `DRIVER_STANDINGS` snapshot rather than summed from results. Summing results does not reproduce history: before 1991 the championship used drop scores, and from 2021 sprint points count toward the title. The raw snapshot already includes both.
- **Complete season.** Every race on the calendar has at least one result. Only complete seasons can have a champion. `mart_driver_season_standings` reports every season as of its latest completed round.
- **Pit stops.** Stops over 60 seconds are excluded from both count and median (red-flag stoppages). Duration is stationary plus pit-lane time.

## Checks

- Unit tests cover the season-completeness logic, the fct_results classification flags, the career totals, and the pit stop median with the 60-second exclusion.
- Singular tests check the champion list against `world_champions_reference`, one champion per complete season, standings coverage, season wins against results, pit stop attribution, and career total consistency.
- Source-level tests are on the staging models, including foreign-key relationships.

## Data quirks found in the source

- Missing values are the literal string `\N` in every table. Staging converts them to null.
- Raw data ends in 2024. There are no 2025 or later seasons.
- **2024 is incomplete.** Rounds 23 and 24 have no results. The 2024 standings are as of round 22 (Verstappen 403 points), no 2024 champion is counted, and career totals for drivers in 2024 are short by those two races.
- The 2005 Australian Grand Prix (race_id 71) has two lapped finishers (`+1 Lap` and `+2 Laps`) with a null `POSITION` but numeric `POSITIONTEXT` 11 and 14. They are classified by status, so staging uses the text value for `finish_position`. Their points are zero, so standings are unaffected.
- Pre-1979 duplicate race-driver pairs (two cars) have no pit stop data, so the pit stop join is one-to-one for the years that have stops.
- Pit stop data starts in 2011.
- Lap times run from 1996. 708 laps are over five minutes; these are red-flag laps and their times include the stoppage. They are kept as provided, so filter them for pace analysis.
- Corrections to races older than the two most recent loaded races do not flow through an incremental run. Use `dbt build --full-refresh -s fct_lap_times` for those.

## Vendor schema changes

The vendor migrated its pipeline and changed raw shapes. Current changes:

- `RESULTS` and `SPRINT_RESULTS`: `POSITIONORDER` renamed to `POSITION_ORDER`. Staging reads the new name. Values are unchanged; mart fingerprints match the pre-migration build.
- `PIT_STOPS`: `DURATION` (text) dropped. The project uses `MILLISECONDS` only, so nothing downstream changed.

How drift is caught:

- `seeds/raw_schema_contract.csv` lists every raw column and whether a model reads it (`required`).
- `tests/assert_raw_schema_has_required_columns.sql` (error): a required column is missing. The build stops.
- `tests/warn_raw_schema_drift.sql` (warn): an unused column disappeared, or a new column appeared. The build still passes but the warning shows up.

When the vendor changes the shape, fix the staging models first, then update the contract seed in the same change so the drift is reviewed.
- `CONSTRUCTORS` (vendor load, 00:32 UTC): Ferrari (id 6) appears twice. The second row's name is `Ferrari ` with a trailing space, so the rows conflict. Joining constructors to results doubled every Ferrari result. Staging now trims the text and collapses identical rows. Two rows that still conflict after cleaning fail the unique test on `constructor_id`, which blocks the marts. `warn_raw_constructor_duplicate_ids` reports the raw duplicates so the vendor can fix the source.

## Public interfaces (for consuming teams)

- **`fct_results`**: model contract enforced. Column names and types are fixed; breaking changes need a new model version.
- **`dim_drivers`**: versioned. Use `ref('dim_drivers', v=2)` (the latest).
  - **v2 (latest)**: `full_name` is replaced by `first_name` and `last_name`. All other columns are the same.
  - **v1**: unchanged, keeps `full_name`. Deprecated from 2027-01-01 but still built. Migrate to v2 with `ref('dim_drivers', v=1)` until then.
  - Both versions return the same career totals, so only the name columns change when you migrate.

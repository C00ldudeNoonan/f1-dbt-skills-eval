# F1 analytics (dbt)

Formula 1 Grand Prix analytics built on the Ergast/Kaggle extract in Snowflake
(`ANALYTICS_DEV.F1_RAW_HA_V2_1`, 1950 to 2024). The raw schema is read-only.

## Feed checks

Every run checks the raw feed before any model builds (`assert_raw_contract`, an `on-run-start`
hook). If a check fails, the run stops with the list of problems, and the dashboards keep the last
good build. The checks are:

| Check | Blocks the run? | Catches |
|---|---|---|
| Schema contract (`macros/raw_contract.sql`) | yes | renamed, dropped, or new tables and columns |
| Value formats (`raw_formats()`) | yes | a column that stops matching its format (for example dates) |
| Conflicting duplicates (`raw_keys()`) | yes | two rows with the same key but different values |
| Truncated load (`raw_row_count_log`) | yes | a raw table with fewer rows than at the last good build |

Exact duplicates are different. They are the same row sent twice, with a different surrogate
id and maybe a trailing space. `dedupe_raw` drops them in staging, so the numbers are right, and
`warn_raw_exact_duplicates` reports how many were dropped on every build. `warn_raw_untrimmed_text`
reports text with extra spaces.

Tests run after the checks and gate downstream models: natural keys are unique in staging
(`unique_together`), values are in range (`in_range`), results point at real constructors and
statuses, a driver wins a race at most once, and each constructor's wins per season match the
official constructor standings (`assert_constructor_wins_match_official`).

### When the vendor changes the feed

1. Run the build. The hook names the change.
2. Update the staging models for the change (renames, dropped columns, format parsing).
3. Update `raw_contract()`, `raw_keys()` and `raw_formats()` to match.
4. Check the numbers before merging: build the previous code against a Time Travel clone of the
   raw schema from before the change, build the new code on the new data, and compare the mart
   tables (row counts, `hash_agg`, and `except` in both directions). Only data arrivals should
   show differences, never the format change alone.

### Incident log: duplicate constructor (Ferrari)

The feed added a second copy of constructor 6 (Ferrari) to `CONSTRUCTORS` about 15 minutes before
the BI report. Every Ferrari result joined to two constructor rows, so entries, wins and points
doubled. Other teams were unaffected. The same window also added 23 duplicate standings rows for
race 1142 (ids offset by 100,000, same content). The old checks missed both: the duplicate-id test
ran only on `RESULTS`, and no build had run since the rows arrived. Now the constructor copy and the
standings copies are dropped in staging, and the pre-build check blocks any conflicting copy.

## Build

```bash
dbt deps            # none required (no packages)
dbt build           # runs models, seeds and tests
```

Targets and output schemas (profile `f1`, database `ANALYTICS_DEV`):

| Layer        | Schema suffix            | Materialization | Models |
|--------------|--------------------------|-----------------|--------|
| staging      | `F1_DBT_HA_v2_1_staging`      | view  | `stg_f1__*` (one per raw table) |
| intermediate | `F1_DBT_HA_v2_1_intermediate` | view  | `int_season_completeness`, `int_lap_flags` |
| marts        | `F1_DBT_HA_v2_1_marts`        | table | `fct_results`, `fct_qualifying`, `fct_driver_race_pace`, `dim_drivers`, `mart_driver_season_standings`, `mart_constructor_season_pit_stops`, `mart_teammate_head_to_head` |
| reference    | `F1_DBT_HA_v2_1_reference`    | seed  | `known_world_champions` (test reference only) |

## Layering

- **Staging** is the only layer that reads `source('f1_raw', ...)`. It clears the `\N`
  null sentinel and empty strings, casts types, and parses `m:ss.mmm` times to milliseconds.
  Nothing downstream touches raw text.
- **Intermediate** holds reusable logic: season completeness and per-lap green-flag flags.
- **Marts** are the public contract. Every public mart is `access: public`.

Business thresholds live in `dbt_project.yml` vars: `max_pit_stop_duration_ms` (60000) and
`slow_lap_threshold_pct` (130).

## Definitions

- **Classified finish**: `position_text` is numeric. `finish_position` is null otherwise
  (`R`, `D`, `E`, `W`, `F`, `N`).
- **Complete season**: every race on the calendar (`RACES`) has at least one result.
  Champions and `world_championships` count only complete seasons.
- **Standings**: taken from the raw `DRIVER_STANDINGS` snapshot at the latest round with
  results. Summing race points would be wrong: drop-score rules apply before 1991, and
  sprint points count from 2021.
- **Pit stops**: stops longer than 60 s are excluded before counting and taking the median.
- **Green-flag lap**: not lap 1, not a pit lap, not the lap after a pit stop, and not slower
  than 130% of the fastest lap in the race (the minimum lap time from `LAP_TIMES`).

## Public interfaces

Two models are public interfaces, owned by the `f1_analytics` group, with enforced contracts
(`access: public`, `contract: enforced`):

- `fct_results`: one row per Grand Prix result entry. Column types are part of the contract.
- `dim_drivers`: one row per driver. Versioned (see below).

Everything else is `protected` (only this project can ref it).

### Consumer guide

- Reference the latest version with `ref('f1', 'dim_drivers')` (version 2). Pin version 1 with
  `ref('f1', 'dim_drivers', v=1)`. Version 1 is deprecated on **2027-01-01**. dbt warns about it from
  then, and it is not removed automatically.
- **Version 2 is a breaking change from version 1.** `full_name` is replaced by `first_name` and
  `last_name`. Rebuild full names with `first_name || ' ' || last_name`. The other columns are
  unchanged.
- Placeholder rows (`is_placeholder = true`, `driver_ref = 'unknown_<driver_id>'`) appear in both
  versions for drivers whose results arrived before their record. Their names and numbers are null,
  and their career counts come from the results. They are replaced automatically once the record arrives.
- `career_wins` and `career_podiums` count Grand Prix only. `career_sprint_wins` counts sprints.
  `world_championships` counts only complete seasons.
- `fct_results.is_orphan_driver` is true for results whose driver has no record yet.
- A cross-project `ref` needs the consuming project to have access to the public model.

### Versioning

- `dim_drivers` version 1 = `models/marts/dim_drivers_v1.sql`. Version 2 = `dim_drivers_v2.sql`. Both
  read `int_dim_drivers`, so the logic exists in one place.
- Version 1 must stay identical to the previous `dim_drivers` until it is removed (checked by hash).

## Tests


- Keys are `unique` and `not_null`. Foreign keys use `relationships`.
- Singular tests in `tests/` check business rules:
  - the standings mart reproduces the published champion for all 74 seasons 1950 to 2023
    (`known_world_champions` seed);
  - the title count in `dim_drivers` matches the number of complete champion seasons;
  - `finish_position` agrees with the raw `POSITION` column;
  - head-to-head rows are symmetric, and ahead counts cannot exceed the shared totals;
  - every season in the feed is complete (`assert_all_seasons_complete`);
  - every raw fastest-lap time parses.

## Data quirks (verified against the raw schema)

1. **Null sentinel.** Missing values are the two-character string `\N` in most tables. Since
   the vendor migration, qualifying `Q1`/`Q2`/`Q3` use empty strings instead. Both become NULL
   in staging.
2. **Dates.** Since the vendor migration `RACES.DATE` is `dd/mm/yyyy`. Staging parses it with
   `to_date(..., 'DD/MM/YYYY')`. `DRIVERS.DOB` is still ISO.
   **Text numbers.** `RACES.ROUND` and `RACES.YEAR` are text. `max(round)` sorts
   lexically (9 beats 22), so round is cast to integer before any ordering.
3. **Lapped finishers with no position.** The 2005 Australian GP has two lapped finishers
   (`+1 Lap`, `+2 Laps`) with `POSITION = \N` but numeric `POSITIONTEXT` (11 and 14). They
   are classified, so they get finish positions 11 and 14, and 0 points.
4. **2024 is complete.** Rounds 23 and 24 both have results in the current feed, so 2024 is a
   complete season: its standings are final and its champion counts. The `assert_all_seasons_complete`
   test fails if any season becomes incomplete.
5. **Repeated race and driver pairs.** Early seasons had two cars for one driver in a race
   (so a driver can appear twice in a race). `result_id` is the grain.
   `position_order` is not unique within a race (105 collisions), so it is never used as a key.
6. **Coverage.** Lap times start in 1996. Pit stops start in 2011, and every pit stop matches
   a result. Before 2011 no pit exclusions can apply to green-flag pace; `fct_driver_race_pace.pit_stop_data_available`
   marks this.
7. **Fastest lap.** Parsed from `FASTESTLAPTIME` (`m:ss.mmm`, 8,215 non-null). It is null for
   18,504 entries. `MILLISECONDS` on `RESULTS` is race time, not fastest lap.
8. **Grid 0** means the car started from the pit lane.
9. **Sprints** are in their own table and are excluded from every Grand Prix mart.

## Drivers

- `snp_drivers` is a type 2 snapshot of the driver reference data (car number, code, name,
  nationality, date of birth). Its history starts at the first snapshot run, because the raw
  feed holds only current values.
- `dim_drivers.current_number` is the permanent car number from the feed (null if none).
- **Orphan results.** A result, qualifying, standings, pit or lap row can reference a driver
  whose record has not arrived yet. These rows are kept in every fact. `dim_drivers` carries a
  placeholder (`is_placeholder = true`, `driver_ref = 'unknown_<driver_id>'`) until the record
  arrives, then the real row replaces it on the next run. `int_orphan_driver_ids` lists the
  orphans with row counts per source. `fct_results.is_orphan_driver` flags their results. The
  `warn_orphan_driver_results` test prints the count on every build without failing it.

## Sessions and standings

- `fct_session_results` has one row per entry across Grand Prix races (`session_type = 'race'`)
  and sprints (`'sprint'`). `source_result_id` is the id in RESULTS or SPRINT_RESULTS.
- `dim_drivers.career_wins` counts Grand Prix wins only. `career_sprint_wins` counts sprint wins.
- `mart_driver_standings_by_round` is the official standings after every round.
  `mart_driver_season_standings` is derived from it at each season's latest completed round.
- `mart_alt_points_standings` re-scores each season under the points systems in the
  `points_systems` seed. Only classified results score, using `position_order`. Ranking is
  points, then countback (wins, 2nds, ... through `countback_max_position`), then lowest
  `driver_id`. To add a system, add its rows to the seed. Against official GP points for
  2010 to 2018, the only differences are the 2014 Abu Dhabi double-points race (the scheme
  scores each race once); from 2019 official totals also include fastest-lap points, which are excluded.

## Incremental models

- `fct_lap_times` and `fct_stints` are incremental by race. Each run rebuilds the two most
  recent races (by `race_date`) and any newer ones, replacing each race whole, so timing
  corrections flow through without a full refresh.

## Feed audit (this incident)

Checked against the raw feed:
- duplicate keys: `CONSTRUCTORS` (Ferrari, one exact copy), `DRIVER_STANDINGS` (23 copies for race 1142);
  none in the other 12 tables.
- text with trailing spaces: `CONSTRUCTORS.NAME` (the Ferrari copy) and `DRIVERS.NATIONALITY`.
- orphans: every result's constructor and status exist. Drivers: as before, the orphan logic handles them.
- values: no negative points or impossible grids. Historical outliers are real: 1950s grids to 34,
  Indianapolis laps above 100, the 2014 Abu Dhabi double-points race (50 points), a 2011 red-flag
  lap of about 2 hours, and three races where two drivers from one team are both recorded as 1st.
- standings: no duplicate position within a race, points never decrease within a season.

## Vendor migration log

- **Renamed:** `LAP_TIMES` is now `LAP_TIMING`. `POSITIONORDER` is now `POSITION_ORDER`
  in `RESULTS` and `SPRINT_RESULTS`.
- **Dropped:** `PIT_STOPS.DURATION`. The project used `MILLISECONDS`, so no output changed.
- **Reformatted:** `RACES.DATE` is `dd/mm/yyyy` (was ISO). Qualifying missing times are empty
  strings (were `\N`). `LAP_TIMING.TIME` and `PIT_STOPS.TIME` changed format; the project stores
  them as text only and does not use them in any output.
- **Verified:** every mart and reference table was rebuilt on the new feed and compared with the
  previous code run against a Time Travel clone of the old feed. Zero rows differed in either direction.

## Known limits

- Championship standings have no current-season rows: the raw data ends in 2024.
- `gap_to_pole_pct` is a percentage in units (0.512 means 0.512%), not a fraction.
- `known_world_champions` is a hand-written reference from published history. It is for tests
  only and must not feed any mart.

## Semantic Layer

Semantic models and metrics are in `models/semantic/_semantic__models.yml`, with the daily time
spine in `metricflow_time_spine.sql`.

- Metrics: `race_starts`, `wins`, `podiums`, `championship_points` (simple); `podium_rate` and
  `points_per_start` (ratios of those).
- Slice by season, constructor name, driver (driver_ref, first and last name), driver nationality,
  and time (race date).
- The YAML is the legacy format. dbt 2 parses it but warns (`SemanticModelDeprecated`). Migrate to
  the new YAML before relying on it in the Semantic Layer service.
- Local `dbt sl validate` and `dbt sl query` need a dbt Cloud project (`dbt_cloud.yaml`), so they
  were not run here. The same numbers were checked with SQL against the marts.

## Vendor B cross-check

Vendor B (`VB_DRIVERS`, `VB_SESSIONS`, `VB_RESULTS`, 2018 to 2024) shares none of our ids. It is
matched to us automatically, and our feed stays the system of record.

- **Drivers** (`dim_driver_crosswalk`): names are normalized (accents folded, letters only). A
  Vendor B name matches our surname plus forename (full_name), else surname plus the forename's first
  letter (surname_initial, which handles nicknames like Alex for Alexander). If several drivers
  still match, the racing number breaks the tie. Anything unmatched fails the build.
- **Sessions** (`dim_session_crosswalk`): a Vendor B session matches our race or sprint in the same
  season, at the same place (meeting name to circuit location), within one day. Sprints match only
  races that had sprint results. Exactly one match is required.
- **Discrepancies** (`mart_vendor_result_discrepancies`): full comparison of 2018 to 2024 GP and
  sprint results, with types `points`, `position`, `missing_in_vendor_a`, `missing_in_vendor_b`.
  An entry unclassified in both feeds is not a position discrepancy.
- No manual overrides were needed. Add a seed of overrides only for a case the rules can't settle.

## Car telemetry (CAR_TELEMETRY)

About 20 million samples (2022 onward, roughly 4 per second per car), with `_LOADED_AT` as the load
time. Routine runs never scan it in full.

- **`fct_telemetry`** is incremental by `_LOADED_AT`. A run reads only raw rows that landed since the
  last run, less a one-day lookback. Late samples carry a recent `_LOADED_AT`, so they are picked up
  whatever their recorded time. The merge is keyed on `sample_id` (race, driver, lap, sample index), so
  reread rows never duplicate. It is clustered by race, driver and lap.
- **`mart_lap_telemetry_summary`** is incremental too. Each run finds the laps touched by recent raw loads
  (raw, not the fact, because the fact's clustering would defeat load-time pruning), then recomputes just
  those laps from all their samples. A recomputed lap replaces its row, so nothing is counted twice.
- Tested on a copy of the raw table: a late sample (recorded in 2023, loaded now) updated its lap
  (270 to 271 samples, top speed and full-throttle share changed), and the incremental summary matched a
  direct aggregation of the fact by hash. A second late sample then matched the same way.
- Cost: a full rebuild reads all 19.8 million raw rows and rewrites both tables. A routine run reads the
  rows loaded since the last run plus one day, and for each touched lap about 270 fact rows (its samples).
  Late data for 100 laps is roughly 27,000 fact rows, about 0.1% of the table. I did not measure bytes
  scanned: query history here does not expose partition counts, so check the warehouse query profile.
- The raw checks skip content scans for this table (`scan: false`): schema and row count are still
  checked each run, but a full duplicate or conflict scan of 20 million rows is not.

## CI (pull requests)

Targets (`profiles.yml`): `dev` (default, your own schema), `prod` (`F1_DBT_HA_v2_1_PROD`), and
`ci` (`F1_DBT_HA_v2_1_CI`). Each target builds into its own schema suffixes.

`scripts/ci.sh` (no arguments, run from the project root):

- Selects models changed relative to `prod-artifacts/manifest.json`, plus everything downstream of
  them (`state:modified+`).
- Builds and tests only that selection, into the `ci` target. `--defer` makes every unselected upstream
  reference resolve to its production relation, so unchanged models are read from prod, not rebuilt.
- Exits non-zero if anything in the selection fails, and exits 1 with a message if the production
  artifacts are missing.

Setup and refresh, after a production build:

```bash
dbt build --target prod
mkdir -p prod-artifacts && cp target/manifest.json prod-artifacts/
```

Commit `prod-artifacts/manifest.json` with the change that produced it, so the baseline matches prod.

Fresh schema bootstrap: the `fct_stints` unit tests read the incremental table, so the first build in a
new schema (prod, ci, or a new dev schema) must create it first:
`dbt run -s fct_stints --target <target>`, then the full build.
Run the production build and save the manifest again whenever prod changes.

Checked: a change to one leaf model selects only that model; a change to `fct_results` selects it and
its nine dependents (including `dim_drivers` v1 and v2). The end-to-end CI run needs a prod build first.

## Leadership questions

### "Which drivers actually overperform their car?"

**Short answer:** this data can't say which drivers overperform their car. The list below is the
best available comparison: who beat their own teammates most consistently in the hybrid era (2014
onward). It is not a car-adjusted rating, and it should not be presented as one.

Definition (`mart_driver_car_performance`): for each driver, the share of shared Grand Prix (and
qualifying sessions) in which they finished ahead of a teammate on the same car. Seasons from 2014
onward (`overperformance_min_season`). A driver is a "trusted overperformer" only with at least 30
shared races and a 95% interval (normal approximation) entirely above 50%.

Current list (2014 onward, in order): Verstappen (73.7%, 209 races), Mick Schumacher (68.2%, 44),
Norris (64.1%, 128), Albon (63.5%, 104), Hamilton (63.4%, 227), Alonso (60.4%, 187), Russell
(60.2%, 128), Leclerc (58.4%, 149).

Why this is not a trustworthy car ranking:
- **Teammates are not equal.** A team's lead driver usually beats the second driver whatever the car,
  so this measures who was the lead driver. Verstappen's teammates (Ricciardo, Gasly, Albon, Perez,
  Sainz, Norris and others) are the reason his number is high, not only his car.
- **The interval captures sampling noise only.** It does not capture team hierarchy, era, or that
  teammates change within a season.
- **Small samples.** Mick Schumacher and Albon have two and five seasons, Piastri and Sargeant (not on the
  list) show how a short stint can swing the rate.
- **No car data.** Nothing in the feed measures a car directly. Telemetry (2022 onward) gives speeds and
  throttle, which could support a car-pace comparison in a later model, but it has not been used here.

What would answer it: a model that estimates driver and car effects together, across teams, with
race-level controls. That needs more than the current marts.

### "Are pit stops really getting faster, or is that a myth?"

**Short answer:** not faster. Stops have not got quicker since 2011. The season median rose from
22.4 seconds (2011) to 23.3 seconds (2024). A linear trend across 2011 to 2024 is +0.065 seconds per
year (R² 0.19), and the lower quartile drifted slower too (+0.033 s per year).

Definition (`mart_pit_stop_trend`): each season's median stop duration across all teams, stops over 60
seconds (red flags) excluded, plus quartiles and stops per race.

What the numbers show: the median jumped about 1.3 seconds in 2014 (from 22.9 in 2013 to 24.2), and
has stayed around 23 to 24 seconds since. The 2024 median (23.3) is still slower than 2011 to 2013.

Why the claim is misleading:
- **The regulations changed.** Stop times depend on pit-lane rules, tyre and fuel rules, and how many
  stops teams make. Stops per race were about 59 in 2011 and between about 25 and 50 in later seasons, so the stops that
  are timed are not the same kind of stop across the period.
- **Averages mislead.** A few very long stops move the mean. The median is used here for that reason.
- **The measure is assumed.** `MILLISECONDS` in `PIT_STOPS` is taken as the stop duration, as the
  feed's column suggests. Whether it is stationary time or pit-lane time is not documented in the data.
- **Coverage.** Pit data starts in 2011, so there is no earlier baseline.

### Tests
- `mart_pit_stop_trend.median_seconds` must sit between 15 and 40 seconds.
- `mart_driver_car_performance`: a unit test checks the interval rule; a singular test checks that every
  trusted overperformer has at least 30 shared races and an interval above 50%.
